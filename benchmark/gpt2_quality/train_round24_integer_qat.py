#!/usr/bin/env python3
"""Round 24: QAT whose LayerNorm forward matches the Product integer contract.

Training uses the existing frozen model/descriptor contract. The hard forward
is integer exact; the gradient follows a quantized floating LayerNorm STE.
Calibration/validation are sampled only from the first 90% corpus partition.
The last 10% is evaluated only after the candidate checkpoint is selected.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import torch
from torch import nn
from torch.nn import functional as F

from round21_contract_ablation import CONTRACTS, infer as integer_infer
from train_h64_byte_lm import CONTEXT, H64ByteDecoder, LAYERS, VOCAB
from train_round23_product_qat import ProductQAT, ste_quant, qmatrix

VALIDATION_SEED = 2026112401


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class IntegerLayerNormQAT(ProductQAT):
    """Product LN exact forward with a quantized PyTorch surrogate gradient."""

    def _ln(self, x: torch.Tensor, layernorm: nn.LayerNorm) -> torch.Tensor:
        # Product input is Q3 (SPAD receives INT32 representing x*8); gamma is
        # Q5 and package beta resolves to a unit-scale integer.
        xq = torch.round(x * 8.0).to(torch.int64)
        n = xq.shape[-1]
        total = xq.sum(dim=-1, keepdim=True)
        mean = torch.div(total, n, rounding_mode="trunc")
        delta = xq - mean
        variance = torch.div((delta * delta).sum(dim=-1, keepdim=True), n,
                             rounding_mode="floor")
        root = torch.sqrt((variance + 1).to(torch.float64)).floor().to(torch.int64)
        root = root.clamp(min=1)
        inv_q30 = (1 << 30) // root
        gamma_q5 = torch.round(layernorm.weight * 32.0).to(torch.int64)
        beta_i32 = torch.round(layernorm.bias).to(torch.int64)
        g = ((delta * gamma_q5 * 1024) >> 15).clamp(-(1 << 31), (1 << 31) - 1)
        exact = (((g * inv_q30) >> 30) + beta_i32).clamp(
            -(1 << 31), (1 << 31) - 1).to(x.dtype)
        gamma_ste = ste_quant(layernorm.weight, 32.0, rounding="round") / 32.0
        beta_ste = ste_quant(layernorm.bias, 1.0, rounding="round")
        soft = F.layer_norm(x, (n,), gamma_ste, beta_ste, layernorm.eps)
        return soft + (exact - soft).detach()


def export_package(model: H64ByteDecoder, out: Path) -> Path:
    state = model.state_dict()
    pkg: dict[str, np.ndarray] = {
        "embedding": np.clip(np.rint(state["embedding.weight"].cpu().numpy() * 8),
                             -128, 127).astype(np.int8),
        "position": np.clip(np.rint(state["position.weight"].cpu().numpy() * 8),
                            -128, 127).astype(np.int8),
        "final_gamma": np.rint(state["final_ln.weight"].cpu().numpy() * 32).astype(np.int32),
        "final_beta": (np.rint(state["final_ln.bias"].cpu().numpy()) * 8).astype(np.int32),
        "lm_head": qmatrix(model.embedding.weight, 32),
    }
    for li in range(LAYERS):
        p, q = f"layers.{li}.", f"l{li}."
        for name in ("q", "k", "v", "o", "up", "down"):
            scale = 256 if name == "up" else 32
            pkg[q + name] = qmatrix(model.layers[li][name].weight, scale)
        for name in ("ln1", "ln2"):
            pkg[q + name + "_gamma"] = np.rint(
                state[p + name + ".weight"].cpu().numpy() * 32).astype(np.int32)
            pkg[q + name + "_beta"] = (
                np.rint(state[p + name + ".bias"].cpu().numpy()) * 8).astype(np.int32)
    out.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(out, **pkg)
    return out


def windows(data: np.ndarray, starts: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    x = np.stack([data[int(s):int(s) + CONTEXT] for s in starts]).astype(np.int64)
    y = np.stack([data[int(s) + 1:int(s) + CONTEXT + 1] for s in starts]).astype(np.int64)
    return x, y


def metrics(logits: np.ndarray, targets: np.ndarray, is_int: bool) -> dict:
    z = logits.astype(np.float64) / (32.0 if is_int else 1.0)
    z -= z.max(axis=-1, keepdims=True)
    lp = z - np.log(np.exp(z).sum(axis=-1, keepdims=True))
    idx = np.indices(targets.shape)
    ce = -lp[idx[0], idx[1], targets]
    return {"accuracy": float(np.mean(np.argmax(z, axis=-1) == targets)),
            "cross_entropy_nats": float(np.mean(ce)),
            "perplexity": float(np.exp(np.mean(ce)))}


def integer_logits(pkg: dict[str, np.ndarray], xs: np.ndarray) -> np.ndarray:
    result = []
    for row in xs:
        logits, _ = integer_infer(pkg, row.astype(int).tolist(),
                                  CONTRACTS["residual_gelu_aligned"])
        result.append(logits)
    return np.asarray(result)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--fp32", type=Path, required=True)
    ap.add_argument("--corpus", type=Path, required=True)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--seed", type=int, required=True)
    ap.add_argument("--steps", type=int, default=350)
    ap.add_argument("--batch", type=int, default=16)
    ap.add_argument("--lr", type=float, default=5e-5)
    ap.add_argument("--validation-windows", type=int, default=64)
    args = ap.parse_args()
    torch.manual_seed(args.seed)
    torch.set_num_threads(1)
    raw = args.corpus.read_bytes()
    data_np = np.frombuffer(raw, dtype=np.uint8).copy()
    train_end = int(len(data_np) * 0.90)
    train = torch.from_numpy(data_np[:train_end].astype(np.int64))
    model = H64ByteDecoder().cpu()
    checkpoint = torch.load(args.fp32, map_location="cpu", weights_only=False)
    model.load_state_dict(checkpoint["state_dict"])
    qat = IntegerLayerNormQAT(model)
    optimizer = torch.optim.AdamW(qat.parameters(), lr=args.lr, weight_decay=0.001)
    rng = np.random.default_rng(args.seed)
    qat.train()
    for step in range(args.steps):
        starts = rng.integers(0, len(train) - CONTEXT - 1, size=args.batch)
        xs, ys = windows(data_np[:train_end], starts)
        logits = qat(torch.from_numpy(xs))
        loss = F.cross_entropy(logits.reshape(-1, VOCAB), torch.from_numpy(ys).reshape(-1))
        optimizer.zero_grad(set_to_none=True)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(qat.parameters(), 1.0)
        optimizer.step()
        if (step + 1) % 100 == 0 or step + 1 == args.steps:
            print(f"R24_QAT seed={args.seed} step={step+1} ce={float(loss.detach()):.6f}",
                  flush=True)

    # Validation is selected from the development partition; final 10% is not
    # read for candidate selection or training.
    val_rng = np.random.default_rng(VALIDATION_SEED)
    val_starts = val_rng.integers(int(train_end * 0.80), train_end - CONTEXT - 1,
                                  size=args.validation_windows)
    val_x, val_y = windows(data_np[:train_end], val_starts)
    qat.eval()
    with torch.no_grad():
        fp_val = qat(torch.from_numpy(val_x)).cpu().numpy()
    pkg_path = export_package(model, args.out_dir / "round24_integer_qat_model.npz")
    with np.load(pkg_path, allow_pickle=False) as z:
        pkg = {k: z[k].copy() for k in z.files}
    # The Product Top model override ABI has one canonical `up` tensor. The
    # software ablation helper uses a separate alias to select the Q8.8 path.
    for li in range(LAYERS):
        pkg[f"l{li}.up_q8_8"] = pkg[f"l{li}.up"].copy()
    int_val = integer_logits(pkg, val_x)
    val_metrics = metrics(int_val, val_y, True)
    fp_val_metrics = metrics(fp_val, val_y, False)
    state_path = args.out_dir / "round24_integer_qat_fp32.pt"
    torch.save({"state_dict": model.state_dict(), "seed": args.seed,
                "steps": args.steps, "qat_contract": "integer_product_layernorm_forward"},
               state_path)
    manifest = {
        "status": "SOFTWARE_CANDIDATE_REQUIRES_PRODUCT_TOP_QUALIFICATION",
        "seed": args.seed, "steps": args.steps, "batch": args.batch,
        "lr": args.lr, "source_fp32_sha256": sha(args.fp32),
        "corpus_sha256": hashlib.sha256(raw).hexdigest(),
        "split": "training/development first 90%; final test 10% never used for this candidate run",
        "validation": {"windows": args.validation_windows,
                       "int8": val_metrics, "qat_float": fp_val_metrics,
                       "seed": VALIDATION_SEED},
        "layernorm_forward": "Product exact integer: Q3 input; truncating mean; floor variance; integer sqrt and Q30 reciprocal; Q5 gamma; unit-scale integer beta; signed INT32 saturation; STE gradient through quantized PyTorch LayerNorm",
        "other_contract": "inherited Round23 Product Q3/Q5/Q8.8/Q15/GELU/per-K16-down contracts; no RTL or Golden change",
        "package_sha256": sha(pkg_path), "checkpoint_sha256": sha(state_path),
        "package": str(pkg_path), "checkpoint": str(state_path),
    }
    (args.out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print("ROUND24_INTEGER_QAT_CANDIDATE " + json.dumps(manifest, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
