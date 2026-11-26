#!/usr/bin/env python3
"""Software-only per-output-channel INT8 weight + MxShift ablation.

Uses the exact Round 30 QAT checkpoint and the Round 31 validation windows.
The proposed per-channel multiplier is a software candidate, not Product RTL
evidence and not a frozen hardware ABI.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path

import numpy as np
import torch

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
from product_integer_reference import layernorm, softmax_q15, gelu_q8_8  # noqa: E402
from round21_contract_ablation import CONTRACTS, infer  # noqa: E402
from round30_fixed_checkpoint_qat import bigram_logits, metric, sample_starts, windows  # noqa: E402
from train_h64_byte_lm import CONTEXT, H64ByteDecoder  # noqa: E402
from train_round24_integer_qat import IntegerLayerNormQAT  # noqa: E402


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sat8(x: np.ndarray) -> np.ndarray:
    return np.clip(x, -128, 127).astype(np.int8)


def sat32(x: np.ndarray) -> np.ndarray:
    return np.clip(x, -(1 << 31), (1 << 31) - 1).astype(np.int32)


def quantize_output_channels(weight_out_in: np.ndarray, output_scale: float):
    """Quantize [N,K] weights per output channel; return [K,N] codes/scales."""
    w = np.asarray(weight_out_in, dtype=np.float64).T
    maxima = np.max(np.abs(w), axis=0)
    scales = np.where(maxima > 0, maxima / 127.0, 1.0)
    codes = np.clip(np.rint(w / scales[None, :]), -127, 127).astype(np.int8)
    err = codes.astype(np.float64) * scales[None, :] - w
    # For A codes representing A_real * activation_scale, output code must
    # represent Y_real * output_scale.  A@Wcodes is A_real*activation_scale*
    # W_real/weight_scale, so the post-accumulator coefficient is:
    # output_scale * weight_scale / activation_scale.
    coeff = output_scale * scales
    return codes, scales, coeff, {
        "elements": int(w.size), "weight_mae": float(np.mean(np.abs(err))),
        "weight_rmse": float(np.sqrt(np.mean(err * err))),
        "weight_min": float(w.min()), "weight_max": float(w.max()),
        "int8_rail_ratio": float(np.mean((codes == -128) | (codes == 127))),
        "zero_ratio": float(np.mean(codes == 0)),
    }


def encode_multiplier(coeff: np.ndarray):
    """Encode positive coefficient as unsigned Q31 mantissa and signed shift."""
    mant = np.zeros(coeff.shape, dtype=np.int64)
    shift = np.zeros(coeff.shape, dtype=np.int64)
    for i, value in enumerate(coeff):
        if value <= 0 or not np.isfinite(value):
            raise ValueError("requant coefficients must be finite and positive")
        fraction, exponent = math.frexp(float(value))
        mant[i] = min((1 << 31) - 1, int(round(fraction * (1 << 31))))
        shift[i] = 31 - exponent
        if not 0 <= shift[i] <= 62:
            raise ValueError(f"requant shift out of bounded candidate range: {shift[i]}")
    return mant, shift


def linear_pc(a: np.ndarray, wcodes: np.ndarray, coeff: np.ndarray) -> np.ndarray:
    acc = np.asarray(a, dtype=np.int64) @ np.asarray(wcodes, dtype=np.int64)
    mant, shift = encode_multiplier(coeff)
    prod = acc * mant[None, :]
    # Arithmetic right shift matches the signed truncation direction used by
    # the existing fixed-point reference.  The multiplier is a 31-bit value;
    # the shift is output-channel-specific in this software proposal.
    out = np.empty(prod.shape, dtype=np.int64)
    for j, s in enumerate(shift):
        out[:, j] = np.right_shift(prod[:, j], int(s))
    return sat32(out)


def prepare_weights(state: dict[str, torch.Tensor]):
    pc_weights = {}
    wstats = {}
    for li in range(4):
        for name, outscale in (("q", 32), ("k", 32), ("v", 32), ("o", 8),
                               ("up", 256), ("down", 8)):
            source = state[f"layers.{li}.{name}.weight"].detach().cpu().numpy()
            # Activation code units: LN=1, attention=32, GELU input=8.
            activation_scale = {"q": 1, "k": 1, "v": 1, "o": 32,
                                "up": 1, "down": 8}[name]
            codes, scale, coeff, st = quantize_output_channels(source, outscale / activation_scale)
            pc_weights[f"l{li}.{name}"] = (codes, coeff)
            wstats[f"l{li}.{name}"] = {**st, "scale_min": float(scale.min()),
                                       "scale_max": float(scale.max()),
                                       "multiplier_min": int(encode_multiplier(coeff)[0].min()),
                                       "multiplier_max": int(encode_multiplier(coeff)[0].max()),
                                       "shift_min": int(encode_multiplier(coeff)[1].min()),
                                       "shift_max": int(encode_multiplier(coeff)[1].max())}
    lm = state["lm_head.weight"].detach().cpu().numpy()
    codes, scale, coeff, st = quantize_output_channels(lm, 32)
    pc_weights["lm_head"] = (codes, coeff)
    wstats["lm_head"] = {**st, "scale_min": float(scale.min()), "scale_max": float(scale.max()),
                         "multiplier_min": int(encode_multiplier(coeff)[0].min()),
                         "multiplier_max": int(encode_multiplier(coeff)[0].max()),
                         "shift_min": int(encode_multiplier(coeff)[1].min()),
                         "shift_max": int(encode_multiplier(coeff)[1].max())}

    return pc_weights, wstats


def run_model(package: dict[str, np.ndarray], tokens: list[int], pc_weights):
    # Package LN beta is stored at 8x the integer reference beta.  Match the
    # frozen Product Integer Contract instead of using the package value raw.
    beta_divisor = 8
    x = package["embedding"][tokens].astype(np.int32) + package["position"][:len(tokens)].astype(np.int32)
    for li in range(4):
        p = f"l{li}."
        ln1 = np.asarray([layernorm(row.tolist(), package[p+"ln1_gamma"].tolist(),
                         np.rint(package[p+"ln1_beta"].astype(np.float64) / beta_divisor).astype(np.int64).tolist())
                         for row in x], dtype=np.int32)
        a8 = sat8(ln1)
        qkv = {name: sat8(linear_pc(a8, *pc_weights[p+name])) for name in ("q", "k", "v")}
        heads = {name: value.reshape(len(tokens), 4, 16).transpose(1, 0, 2)
                 for name, value in qkv.items()}
        attended = np.zeros((len(tokens), 64), dtype=np.int32)
        for h in range(4):
            scores = np.asarray(heads["q"][h], dtype=np.int64) @ heads["k"][h].T.astype(np.int64)
            scores = sat32(np.right_shift(scores, 2))
            probs = np.zeros(scores.shape, dtype=np.int32)
            for r in range(len(tokens)):
                probs[r, :r+1] = softmax_q15(scores[r, :r+1].tolist())
            p8 = sat8(np.right_shift(probs, 8))
            av = np.asarray(p8, dtype=np.int64) @ heads["v"][h].astype(np.int64)
            attended[:, h*16:(h+1)*16] = sat8(sat32(np.right_shift(av, 7)))
        proj = linear_pc(attended.astype(np.int8), *pc_weights[p+"o"])
        r1 = sat32(x.astype(np.int64) + proj.astype(np.int64))
        ln2 = np.asarray([layernorm(row.tolist(), package[p+"ln2_gamma"].tolist(),
                         np.rint(package[p+"ln2_beta"].astype(np.float64) / beta_divisor).astype(np.int64).tolist())
                         for row in r1], dtype=np.int32)
        up = linear_pc(sat8(ln2), *pc_weights[p+"up"])
        gelu = np.asarray([[gelu_q8_8(int(v)) for v in row] for row in up], dtype=np.int32)
        gelu_i8 = sat8(np.right_shift(gelu, 5))
        down = linear_pc(gelu_i8, *pc_weights[p+"down"])
        x = sat32(r1.astype(np.int64) + down.astype(np.int64))
    final_ln = np.asarray([layernorm(row.tolist(), package["final_gamma"].tolist(),
                          np.rint(package["final_beta"].astype(np.float64) / beta_divisor).astype(np.int64).tolist())
                          for row in x], dtype=np.int32)
    logits = linear_pc(sat8(final_ln), *pc_weights["lm_head"])
    return logits


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus", type=Path, required=True)
    ap.add_argument("--split-manifest", type=Path, required=True)
    ap.add_argument("--source-checkpoint", type=Path, required=True)
    ap.add_argument("--qat-checkpoint", type=Path, required=True)
    ap.add_argument("--package", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--windows", type=int, default=128)
    ap.add_argument("--seed", type=int, default=20263101)
    args = ap.parse_args()
    torch.set_num_threads(1)
    raw_bytes = args.corpus.read_bytes()
    raw = np.frombuffer(raw_bytes, dtype=np.uint8).copy()
    split = json.loads(args.split_manifest.read_text())
    if sha(args.corpus) != split["corpus_sha256"]:
        raise ValueError("corpus/split manifest SHA mismatch")
    train_lo, train_hi = split["ranges_half_open"]["train"]
    val_lo, val_hi = split["ranges_half_open"]["validation"]
    test_lo, test_hi = split["ranges_half_open"]["test"]
    if not (train_hi < val_lo and val_hi < test_lo):
        raise ValueError("split ranges overlap")
    starts = sample_starts(val_lo, val_hi, args.windows, args.seed)
    xs, ys = windows(raw, starts)
    qat = torch.load(args.qat_checkpoint, map_location="cpu", weights_only=False)["state_dict"]
    source = torch.load(args.source_checkpoint, map_location="cpu", weights_only=False)["state_dict"]
    fp = H64ByteDecoder().cpu().eval()
    fp.load_state_dict(source)
    qat_model = H64ByteDecoder().cpu().eval()
    qat_model.load_state_dict(qat)
    fake = IntegerLayerNormQAT(qat_model).eval()
    with np.load(args.package, allow_pickle=False) as data:
        package = {k: data[k].copy() for k in data.files}
    # The Round 21 residual/GELU contract derives a dedicated Q8.8 FFN-up
    # weight tensor from the frozen QAT checkpoint. The deployed Round 30
    # package stores the generic int8 `up` tensor instead, so recreate this
    # *software reference operand* exactly as Round 21 did; this does not
    # alter the package or imply Product RTL support for per-channel M+Shift.
    for li in range(4):
        weight = qat[f"layers.{li}.up.weight"].detach().cpu().numpy().T
        package[f"l{li}.up_q8_8"] = np.clip(
            np.rint(weight.astype(np.float64) * 256), -128, 127
        ).astype(np.int8)
    pc_weights, weight_stats = prepare_weights(qat)
    # Per-window decode uses the identical frozen validation start set.
    all_logits = [run_model(package, row.astype(int).tolist(), pc_weights)[-1] for row in xs]
    all_logits = np.asarray(all_logits, dtype=np.int32)
    with torch.no_grad():
        fp_logits = fp(torch.from_numpy(xs)).cpu().numpy()[:, -1, :]
        qat_logits = qat_model(torch.from_numpy(xs)).cpu().numpy()[:, -1, :]
        fake_logits = fake(torch.from_numpy(xs)).cpu().numpy()[:, -1, :]
    bg = bigram_logits(raw[train_lo:train_hi], xs)[:, -1, :]
    scalar_logits = np.asarray([
        infer(package, row.astype(int).tolist(), CONTRACTS["residual_gelu_aligned"])[0][-1]
        for row in xs
    ], dtype=np.int32)
    frozen_logits = np.asarray([
        infer(package, row.astype(int).tolist(), CONTRACTS["frozen"])[0][-1]
        for row in xs
    ], dtype=np.int32)
    result = {
        "status": "SOFTWARE_ONLY_PER_CHANNEL_MSHIFT_ABLATION_NO_PRODUCT_RTL_PASS",
        "contract": "symmetric_per_output_channel_weight_int8_plus_unsigned_q31_multiplier_and_per_channel_arithmetic_shift",
        "arithmetic": "int64 dot; per-channel Q31 mantissa multiply; signed arithmetic right shift; int32 saturation; no training or test-set selection",
        "model_sha256": sha(args.qat_checkpoint), "package_sha256": sha(args.package),
        "corpus_sha256": sha(args.corpus), "split_manifest_sha256": sha(args.split_manifest),
        "validation_range": [val_lo, val_hi], "test_range_not_read": [test_lo, test_hi],
        "windows": len(xs), "context": CONTEXT, "seed": args.seed,
        "validation_starts_sha256": hashlib.sha256(starts.astype("<i8").tobytes()).hexdigest(),
        "quality": {
            "fp32": metric(fp_logits, ys[:, -1]),
            "qat_float": metric(qat_logits, ys[:, -1]),
            "fake_quant": metric(fake_logits, ys[:, -1]),
            "power_of_two_product_contract": metric(scalar_logits.astype(np.float64) / 32.0, ys[:, -1]),
            "legacy_frozen_contract": metric(frozen_logits.astype(np.float64) / 32.0, ys[:, -1]),
            "per_channel_mshift": metric(all_logits.astype(np.float64) / 32.0, ys[:, -1]),
            "bigram": metric(bg, ys[:, -1]),
            "top1_agreement_vs_fp32": float(np.mean(np.argmax(all_logits, -1) == np.argmax(fp_logits, -1))),
            "top1_agreement_vs_qat_float": float(np.mean(np.argmax(all_logits, -1) == np.argmax(qat_logits, -1))),
        },
        "weight_quantization": weight_stats,
        "tool_versions": {"python": sys.version.split()[0], "numpy": np.__version__, "torch": torch.__version__},
        "limitations": ["software candidate only; no RTL support or synthesis evidence", "validation subset only; frozen test not read", "no mixed-precision candidate in this run", "Q31 post-accumulator multiplier/shift ABI is not present in Product RTL"],
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"status": result["status"], "quality": result["quality"], "output": str(args.out)}, sort_keys=True))


if __name__ == "__main__":
    main()
