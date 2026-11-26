#!/usr/bin/env python3
"""Evaluate bounded, explicitly scaled Round 21 Product-contract candidates.

This is software-only evidence. It never edits the frozen package, Golden, or RTL.
Candidate tensors are dequantized at their declared fixed-point scales before
comparison with the trained FP32 model.
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
sys.path.insert(0, str(HERE))
from product_integer_reference import layernorm, softmax_q15, gelu_q8_8  # noqa: E402
from train_h64_byte_lm import H64ByteDecoder, CONTEXT  # noqa: E402


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def sat8(a: np.ndarray) -> np.ndarray:
    return np.clip(a, -128, 127).astype(np.int8)


def gemm(a: np.ndarray, b: np.ndarray, shift: int = 0) -> np.ndarray:
    acc = np.asarray(a, dtype=np.int64) @ np.asarray(b, dtype=np.int64)
    if shift:
        acc = acc >> shift
    return np.clip(acc, -(1 << 31), (1 << 31) - 1).astype(np.int32)


def infer(q: dict[str, np.ndarray], tokens: list[int], contract: dict):
    scales = contract["scales"]
    shifts = contract["matrix_shifts"]
    x = q["embedding"][tokens].astype(np.int32) + q["position"][:len(tokens)].astype(np.int32)
    trace = {"embedding_position": x.copy()}
    for li in range(4):
        p = f"l{li}."
        beta_div = scales["ln_beta_from_package_divisor"]
        ln1 = np.asarray([layernorm(row.tolist(), q[p+"ln1_gamma"].tolist(),
                                    np.rint(q[p+"ln1_beta"].astype(np.float64) / beta_div).astype(np.int64).tolist())
                          for row in x], dtype=np.int32)
        a8 = sat8(ln1)
        qkv = {name: sat8(gemm(a8, q[p+name], shifts["qkv"]))
               for name in ("q", "k", "v")}
        heads = {name: value.reshape(len(tokens), 4, 16).transpose(1, 0, 2)
                 for name, value in qkv.items()}
        attended = np.zeros((len(tokens), 64), dtype=np.int32)
        score_rows, prob_rows = [], []
        for h in range(4):
            scores = gemm(heads["q"][h], heads["k"][h].T, 2)
            probs = np.zeros(scores.shape, dtype=np.int32)
            for r in range(len(tokens)):
                probs[r, :r+1] = softmax_q15(scores[r, :r+1].tolist())
            p8 = sat8(probs >> 8)
            av = gemm(p8, heads["v"][h], 7)
            attended[:, h*16:(h+1)*16] = sat8(av)
            score_rows.append(scores)
            prob_rows.append(probs)
        proj = gemm(attended.astype(np.int8), q[p+"o"], shifts["o"])
        r1 = np.clip(x.astype(np.int64) + proj.astype(np.int64),
                     -(1 << 31), (1 << 31)-1).astype(np.int32)
        ln2 = np.asarray([layernorm(row.tolist(), q[p+"ln2_gamma"].tolist(),
                                    np.rint(q[p+"ln2_beta"].astype(np.float64) / beta_div).astype(np.int64).tolist())
                          for row in r1], dtype=np.int32)
        ffn_in = sat8(ln2)
        up_key = p + contract.get("up_weight_suffix", "up")
        up = gemm(ffn_in, q[up_key], shifts["up"])
        gelu = np.asarray([[gelu_q8_8(int(v)) for v in row] for row in up], dtype=np.int32)
        gelu_i8 = sat8(gelu >> shifts["gelu_to_i8"])
        down = np.zeros((len(tokens), 64), dtype=np.int32)
        dw = q[p+"down"].astype(np.int32)
        for start in range(0, 256, 16):
            down = np.clip(down.astype(np.int64) +
                           gemm(gelu_i8[:, start:start+16], dw[start:start+16], shifts["down"]),
                           -(1 << 31), (1 << 31)-1).astype(np.int32)
        r2 = np.clip(r1.astype(np.int64) + down.astype(np.int64),
                     -(1 << 31), (1 << 31)-1).astype(np.int32)
        for name, value in (("ln1", ln1), ("q", qkv["q"]), ("k", qkv["k"]),
                            ("v", qkv["v"]), ("scores", np.asarray(score_rows)),
                            ("probabilities_q15", np.asarray(prob_rows)),
                            ("attention", attended), ("projection", proj),
                            ("residual1", r1), ("ln2", ln2), ("up", up),
                            ("gelu", gelu), ("gelu_i8", gelu_i8),
                            ("down", down), ("residual2", r2)):
            trace[f"l{li}.{name}"] = np.asarray(value)
        x = r2
    final_ln = np.asarray([layernorm(row.tolist(), q["final_gamma"].tolist(),
                           np.rint(q["final_beta"].astype(np.float64) / beta_div).astype(np.int64).tolist())
                           for row in x], dtype=np.int32)
    logits = gemm(sat8(final_ln), q["lm_head"], shifts["lm_head"])
    trace["final_ln"] = final_ln
    trace["logits"] = logits
    return logits, trace


def fp_trace(model, tokens):
    x = model.embedding(torch.tensor(tokens))[None] + model.position(torch.arange(len(tokens)))[None]
    t = {"embedding_position": x.detach().numpy()[0]}
    with torch.no_grad():
        for li, layer in enumerate(model.layers):
            n1 = layer["ln1"](x)
            q = layer["q"](n1).view(1, len(tokens), 4, 16).transpose(1, 2)
            k = layer["k"](n1).view(1, len(tokens), 4, 16).transpose(1, 2)
            v = layer["v"](n1).view(1, len(tokens), 4, 16).transpose(1, 2)
            scores = q @ k.transpose(-1, -2) / 4.0
            mask = torch.triu(torch.ones(len(tokens), len(tokens), dtype=torch.bool), 1)
            probs = scores.masked_fill(mask[None, None], float("-inf")).softmax(-1)
            att = (probs @ v).transpose(1, 2).contiguous().view(1, len(tokens), 64)
            proj = layer["o"](att)
            r1 = x + proj
            n2 = layer["ln2"](r1)
            up = layer["up"](n2)
            gelu = torch.nn.functional.gelu(up, approximate="tanh")
            down = layer["down"](gelu)
            r2 = r1 + down
            for name, val in (("ln1", n1), ("q", q.transpose(1, 2).reshape(1, len(tokens), 64)),
                              ("k", k.transpose(1, 2).reshape(1, len(tokens), 64)),
                              ("v", v.transpose(1, 2).reshape(1, len(tokens), 64)),
                              ("scores", scores), ("probabilities", probs), ("attention", att),
                              ("projection", proj), ("residual1", r1), ("ln2", n2),
                              ("up", up), ("gelu", gelu), ("down", down), ("residual2", r2)):
                t[f"l{li}.{name}"] = val.detach().numpy()[0]
            x = r2
        t["final_ln"] = model.final_ln(x).detach().numpy()[0]
        t["logits"] = model.lm_head(model.final_ln(x)).detach().numpy()[0]
    return t


CONTRACTS = {
    "frozen": {"scales": {"ln_beta_from_package_divisor": 1, "logit_dequant": 32},
               "matrix_shifts": {"qkv": 0, "o": 0, "up": 0, "gelu_to_i8": 0,
                                  "down": 0, "lm_head": 0}, "up_weight_multiplier": 1},
    "residual_gelu_aligned": {
        "scales": {"ln_beta_from_package_divisor": 8, "logit_dequant": 32},
        # LayerNorm emits unit-scale normalized values; beta therefore uses
        # unit scale. Q5 attention projection is shifted to the embedding's
        # Q3 residual scale. FFN up is independently quantized to Q8.8 so the
        # existing GELU contract is respected, then requantized to Q3 before
        # the down projection returns Q3 residual values.
        "matrix_shifts": {"qkv": 0, "o": 7, "up": 0, "gelu_to_i8": 5,
                          "down": 5, "lm_head": 0},
        "up_weight_suffix": "up_q8_8"},
    "residual_gelu_o10": {
        "scales": {"ln_beta_from_package_divisor": 8, "logit_dequant": 32},
        "matrix_shifts": {"qkv": 0, "o": 10, "up": 0, "gelu_to_i8": 5,
                          "down": 5, "lm_head": 0},
        "up_weight_suffix": "up_q8_8"},
    "residual_gelu_up5": {
        "scales": {"ln_beta_from_package_divisor": 8, "logit_dequant": 32},
        "matrix_shifts": {"qkv": 0, "o": 7, "up": 5, "gelu_to_i8": 5,
                          "down": 5, "lm_head": 0},
        "up_weight_suffix": "up_q8_8"},
    "residual_gelu_o10_up5": {
        "scales": {"ln_beta_from_package_divisor": 8, "logit_dequant": 32},
        "matrix_shifts": {"qkv": 0, "o": 10, "up": 5, "gelu_to_i8": 5,
                          "down": 5, "lm_head": 0},
        "up_weight_suffix": "up_q8_8"},
}


def summarize(refs, got, scales, logits_fp, logits_i8, targets, logit_scale):
    rows = {}
    for name, arrays in got.items():
        if name not in refs:
            continue
        a = np.concatenate([x.reshape(-1) for x in refs[name]])
        b = np.concatenate([x.reshape(-1) for x in arrays]).astype(np.float64) / scales.get(name, 1)
        a = a.astype(np.float64)
        rows[name] = {"count": int(a.size), "ref_range": [float(a.min()), float(a.max())],
                      "int_dequant_range": [float(b.min()), float(b.max())],
                      "mae": float(np.mean(np.abs(a-b))),
                      "rmse": float(np.sqrt(np.mean((a-b)**2)))}
    # Logit dequantization changes CE/PPL but not argmax.
    # The caller passes integer logits only after the same positive scale.
    z = logits_i8.astype(np.float64) / float(logit_scale)
    z -= z.max(axis=-1, keepdims=True)
    ce = np.log(np.exp(z).sum(axis=-1)) - np.take_along_axis(z, targets[..., None], axis=-1)[..., 0]
    return {"trace": rows,
            "quality": {"targets": int(targets.size), "cross_entropy_nats": float(ce.mean()),
                        "perplexity": float(np.exp(ce.mean())),
                        "accuracy": float(np.mean(np.argmax(logits_i8, axis=-1) == targets)),
                        "fp32_accuracy": float(np.mean(np.argmax(logits_fp, axis=-1) == targets)),
                        "fp32_int8_top1_agreement": float(np.mean(np.argmax(logits_fp, axis=-1) ==
                                                                    np.argmax(logits_i8, axis=-1)))}}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--package", type=Path, required=True)
    ap.add_argument("--fp32", type=Path, required=True)
    ap.add_argument("--corpus", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--seed", type=int, default=20261121)
    ap.add_argument("--windows", type=int, default=64)
    args = ap.parse_args()
    torch.set_num_threads(1)
    ckpt = torch.load(args.fp32, map_location="cpu", weights_only=False)
    model = H64ByteDecoder().cpu().eval()
    model.load_state_dict(ckpt["state_dict"])
    with np.load(args.package, allow_pickle=False) as f:
        q = {k: f[k] for k in f.files}
    # A separate Q8.8 FFN-up quantization is required by opcode 0x35. It is
    # generated from the frozen FP32 checkpoint, never by expanding an
    # already-rounded Q5 tensor.
    for li in range(4):
        weight = ckpt["state_dict"][f"layers.{li}.up.weight"].cpu().numpy().T
        q[f"l{li}.up_q8_8"] = np.clip(np.rint(weight.astype(np.float64) * 256), -128, 127).astype(np.int8)
    test = np.frombuffer(args.corpus.read_bytes(), dtype=np.uint8).copy()[int(len(args.corpus.read_bytes())*.9):]
    lo, hi = int(len(test)*.05), len(test)-CONTEXT-1
    starts = np.random.default_rng(args.seed).integers(lo, hi, size=args.windows)
    train = np.frombuffer(args.corpus.read_bytes(), dtype=np.uint8).copy()[:int(len(args.corpus.read_bytes()) * .9)]
    test_targets = np.frombuffer(args.corpus.read_bytes(), dtype=np.uint8).copy()[int(len(args.corpus.read_bytes()) * .9):]
    bigram_counts = np.ones((256, 256), dtype=np.int64)
    np.add.at(bigram_counts, (train[:-1], train[1:]), 1)
    bigram_predictor = np.argmax(bigram_counts, axis=1)
    bigram_accuracy = float(np.mean(bigram_predictor[test_targets[starts + CONTEXT - 1]] ==
                                     test_targets[starts + CONTEXT]))
    results = {}
    for cname, contract in CONTRACTS.items():
        int_refs, int_got, fp_logits, int_logits, ys = {}, {}, [], [], []
        scales = {"embedding_position":8, "final_ln":1, "logits":contract["scales"]["logit_dequant"]}
        for li in range(4):
            p=f"l{li}."
            scales.update({p+"ln1":1,p+"q":32,p+"k":32,p+"v":32,
                           p+"scores":256,p+"probabilities_q15":32768,p+"attention":32,
                           p+"projection":8,p+"residual1":8,p+"ln2":1,p+"up":256,
                           p+"gelu":256,p+"down":8,p+"residual2":8})
        for start in starts:
            toks=test[start:start+CONTEXT].astype(int).tolist()
            ftrace=fp_trace(model,toks)
            ilog,it=infer(q,toks,contract)
            for name,val in ftrace.items(): int_refs.setdefault(name,[]).append(np.asarray(val))
            for name,val in it.items(): int_got.setdefault(name,[]).append(np.asarray(val))
            fp_logits.append(ftrace["logits"][-1]); int_logits.append(ilog[-1]); ys.append(int(test[start+CONTEXT]))
        results[cname]=summarize(int_refs,int_got,scales,np.asarray(fp_logits),
                                 np.asarray(int_logits),np.asarray(ys),
                                 contract["scales"]["logit_dequant"])
    out={"status":"SOFTWARE_ABLATION_ONLY_NO_TOP_RTL_PASS",
         "model_sha256":sha(args.fp32),"package_sha256":sha(args.package),
         "up_q8_8_saturation": {f"l{li}": float(np.mean((q[f"l{li}.up_q8_8"] == -128) |
                                                               (q[f"l{li}.up_q8_8"] == 127)))
                                 for li in range(4)},
         "corpus_sha256":sha(args.corpus),"seed":args.seed,"windows":args.windows,
         "bigram_accuracy_same_windows": bigram_accuracy,
         "contracts":CONTRACTS,"results":results}
    args.out.parent.mkdir(parents=True,exist_ok=True)
    args.out.write_text(json.dumps(out,indent=2,sort_keys=True)+"\n")
    print(json.dumps({k:v["quality"] for k,v in results.items()},sort_keys=True))
    print(args.out)


if __name__=="__main__": main()
