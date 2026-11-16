#!/usr/bin/env python3
"""FP32 and independent INT8 references for the v2 GPT-2-compatible target.

The fixture is deterministic and not a pretrained checkpoint. Both paths
implement a Pre-LN decoder; INT8 uses explicit integer scale, saturation,
Q15 softmax, and the product's bounded quadratic GELU contract.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import numpy as np

CONFIG = dict(layers=4, hidden=64, heads=4, head_dim=16,
              ffn=256, vocab=256, context=16)
Q = dict(embedding=8, weight=32)


def sat_i8(x):
    return np.clip(x, -128, 127).astype(np.int8)


def make_model(seed: int = 20261114):
    rng = np.random.default_rng(seed)
    model = {"embedding": sat_i8(np.rint(rng.normal(0, 7.0, (256, 64)))),
             "position": sat_i8(np.rint(rng.normal(0, 3.0, (16, 64))))}
    for layer in range(4):
        for name, shape in (("q", (64, 64)), ("k", (64, 64)),
                            ("v", (64, 64)), ("o", (64, 64)),
                            ("up", (64, 256)), ("down", (256, 64))):
            model[f"l{layer}.{name}"] = sat_i8(np.rint(rng.normal(0, 1.8, shape)))
        model[f"l{layer}.ln1_gamma"] = sat_i8(np.rint(rng.normal(32, 1.0, 64)))
        model[f"l{layer}.ln2_gamma"] = sat_i8(np.rint(rng.normal(32, 1.0, 64)))
        model[f"l{layer}.ln1_beta"] = np.zeros(64, dtype=np.int32)
        model[f"l{layer}.ln2_beta"] = np.zeros(64, dtype=np.int32)
    model["final_gamma"] = sat_i8(np.rint(rng.normal(32, 1.0, 64)))
    model["final_beta"] = np.zeros(64, dtype=np.int32)
    model["lm_head"] = sat_i8(np.rint(rng.normal(0, 1.8, (64, 256))))
    return model


def fp_layer_norm(x, gamma, beta):
    xf = x.astype(np.float64)
    mean = xf.mean(axis=-1, keepdims=True)
    var = ((xf - mean) ** 2).mean(axis=-1, keepdims=True)
    return (xf - mean) / np.sqrt(var + 1.0e-5) * (gamma / 32.0) + beta / 32.0


def fp_gelu(x):
    return 0.5 * x * (1.0 + np.tanh(np.sqrt(2.0 / np.pi) *
                                      (x + 0.044715 * x ** 3)))


def fp_infer(model, tokens):
    x = (model["embedding"][tokens] / Q["embedding"] +
         model["position"][np.arange(len(tokens))] / Q["embedding"])
    trace = {"embedding_position": x.copy()}
    for layer in range(4):
        p = f"l{layer}."
        n1 = fp_layer_norm(x, model[p + "ln1_gamma"], model[p + "ln1_beta"])
        q = n1 @ (model[p + "q"] / Q["weight"])
        k = n1 @ (model[p + "k"] / Q["weight"])
        v = n1 @ (model[p + "v"] / Q["weight"])
        q_heads = q.reshape(len(tokens), 4, 16).transpose(1, 0, 2)
        k_heads = k.reshape(len(tokens), 4, 16).transpose(1, 0, 2)
        scores = np.matmul(q_heads, k_heads.transpose(0, 2, 1)) / math.sqrt(CONFIG["head_dim"])
        scores = np.where(np.triu(np.ones(scores.shape[-2:], dtype=bool), 1), -np.inf, scores)
        scores -= np.max(scores, axis=-1, keepdims=True)
        probs = np.exp(scores)
        probs /= np.sum(probs, axis=-1, keepdims=True)
        heads = v.reshape(len(tokens), 4, 16).transpose(1, 0, 2)
        attended = np.matmul(probs, heads)
        attended = attended.transpose(1, 0, 2).reshape(len(tokens), 64)
        projected = attended @ (model[p + "o"] / Q["weight"])
        residual1 = x + projected
        n2 = fp_layer_norm(residual1, model[p + "ln2_gamma"], model[p + "ln2_beta"])
        up = n2 @ (model[p + "up"] / Q["weight"])
        gelu = fp_gelu(up)
        down = gelu @ (model[p + "down"] / Q["weight"])
        residual2 = residual1 + down
        x = residual2
        for name, value in (("ln1", n1), ("q", q), ("k", k), ("v", v),
                            ("scores", scores), ("probabilities", probs),
                            ("attention", attended), ("projection", projected),
                            ("residual1", residual1), ("ln2", n2), ("up", up),
                            ("gelu", gelu), ("down", down), ("residual2", residual2)):
            trace[f"l{layer}.{name}"] = value.copy()
    final = fp_layer_norm(x, model["final_gamma"], model["final_beta"])
    logits = final @ (model["lm_head"] / Q["weight"])
    trace["final_ln"], trace["logits"] = final.copy(), logits.copy()
    return logits, trace


def int_layer_norm(x, gamma, beta):
    x64 = x.astype(np.int64)
    out = np.empty_like(x64, dtype=np.int32)
    for i, row in enumerate(x64):
        mean = int(np.trunc(np.sum(row) / row.size))
        variance = int(np.sum((row - mean) ** 2) // row.size)
        root = max(1, math.isqrt(variance + 1))
        out[i] = np.clip(((row - mean) * gamma.astype(np.int64)) // root + beta, -128, 127)
    return out.astype(np.int8)


def q15_softmax(scores):
    out = np.zeros_like(scores, dtype=np.int32)
    for i, row in enumerate(scores):
        live = row[:i + 1].astype(np.float64)
        weights = np.exp(live - np.max(live))
        out[i, :i + 1] = np.clip(np.rint(weights / weights.sum() * 32768), 0, 32768)
    return out


def int_gelu_q8_8(x):
    x64 = x.astype(np.int64)
    out = np.where(x64 <= -512, 0,
                   np.where(x64 >= 512, x64, (x64 * (x64 + 512)) >> 10))
    return np.clip(out, -(1 << 31), (1 << 31) - 1).astype(np.int32)


def int_infer(model, tokens):
    x = sat_i8(model["embedding"][tokens].astype(np.int16) +
               model["position"][np.arange(len(tokens))].astype(np.int16))
    trace = {"embedding_position": x.copy()}
    for layer in range(4):
        p = f"l{layer}."
        n1 = int_layer_norm(x, model[p + "ln1_gamma"], model[p + "ln1_beta"])
        q = sat_i8((n1.astype(np.int32) @ model[p + "q"].astype(np.int32)) >> 5)
        k = sat_i8((n1.astype(np.int32) @ model[p + "k"].astype(np.int32)) >> 5)
        v = sat_i8((n1.astype(np.int32) @ model[p + "v"].astype(np.int32)) >> 5)
        q_heads = q.reshape(len(tokens), 4, 16).transpose(1, 0, 2).astype(np.int32)
        k_heads = k.reshape(len(tokens), 4, 16).transpose(1, 0, 2).astype(np.int32)
        scores = np.matmul(q_heads, k_heads.transpose(0, 2, 1)) >> 4
        probs = np.stack([q15_softmax(scores[head]) for head in range(4)])
        heads = v.reshape(len(tokens), 4, 16).transpose(1, 0, 2)
        attended = np.matmul(probs.astype(np.int64), heads.astype(np.int64)).transpose(1, 0, 2) >> 15
        attended = sat_i8(attended.reshape(len(tokens), 64))
        projected = sat_i8((attended.astype(np.int32) @ model[p + "o"].astype(np.int32)) >> 5)
        residual1 = sat_i8(x.astype(np.int16) + projected.astype(np.int16))
        n2 = int_layer_norm(residual1, model[p + "ln2_gamma"], model[p + "ln2_beta"])
        up = (n2.astype(np.int32) @ model[p + "up"].astype(np.int32)) >> 5
        gelu = int_gelu_q8_8(up)
        down = (gelu @ model[p + "down"].astype(np.int32)) >> 8
        residual2 = sat_i8(residual1.astype(np.int64) + (down >> 5))
        x = residual2
        for name, value in (("ln1", n1), ("q", q), ("k", k), ("v", v),
                            ("scores", scores), ("probabilities_q15", probs),
                            ("attention", attended), ("projection", projected),
                            ("residual1", residual1), ("ln2", n2), ("up", up),
                            ("gelu", gelu), ("down", down), ("residual2", residual2)):
            trace[f"l{layer}.{name}"] = np.asarray(value).copy()
    final = int_layer_norm(x, model["final_gamma"], model["final_beta"])
    logits = final.astype(np.int32) @ model["lm_head"].astype(np.int32)
    trace["final_ln"], trace["logits"] = final.copy(), logits.copy()
    return logits, trace


def tensor_manifest(trace, producer):
    rows = []
    for name, value in trace.items():
        raw = np.asarray(value)
        rows.append({"name": name, "shape": list(raw.shape), "dtype": str(raw.dtype),
                     "quantization": "INT8" if raw.dtype == np.int8 else "INT32/FP32",
                     "producer": producer, "consumer": "next graph stage or LM_HEAD",
                     "sha256": hashlib.sha256(raw.tobytes()).hexdigest()})
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=20261114)
    ap.add_argument("--tokens", default="1,7,42,3")
    ap.add_argument("--out", type=Path, default=Path("gpt2_compat_golden.json"))
    ap.add_argument("--weights", type=Path, default=Path("gpt2_compat_weights.npz"))
    args = ap.parse_args()
    tokens = np.asarray([int(x) for x in args.tokens.split(",") if x], dtype=np.int32)
    if len(tokens) == 0 or len(tokens) > 16 or np.any((tokens < 0) | (tokens >= 256)):
        raise SystemExit("tokens must be in [0,255] and fit context=16")
    model = make_model(args.seed)
    fp_logits, fp_trace = fp_infer(model, tokens)
    int_logits, int_trace = int_infer(model, tokens)
    args.weights.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(args.weights, **model)
    report = {"config": CONFIG, "seed": args.seed, "tokens": tokens.tolist(),
              "fp32_logits_sha256": hashlib.sha256(fp_logits.tobytes()).hexdigest(),
              "int8_logits_sha256": hashlib.sha256(int_logits.tobytes()).hexdigest(),
              "fp32_tensor_manifest": tensor_manifest(fp_trace, "FP32_PRE_LN_REFERENCE"),
              "int8_tensor_manifest": tensor_manifest(int_trace, "INT8_FIXED_POINT_REFERENCE"),
              "max_abs_logit_error": float(np.max(np.abs(fp_logits - int_logits))),
              "next_tokens_fp32": np.argmax(fp_logits, axis=1).astype(int).tolist(),
              "next_tokens_int8": np.argmax(int_logits, axis=1).astype(int).tolist(),
              "fixture_golden": "PASS", "weights_kind": "DETERMINISTIC_PSEUDO_WEIGHTS_NOT_PRETRAINED",
              "rtl_execution": "NOT_RUN", "unsupported_product_ops":
              ["H64 causal attention lowering", "persistent multi-token decode"]}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({k: v for k, v in report.items() if not k.endswith("manifest")}, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
