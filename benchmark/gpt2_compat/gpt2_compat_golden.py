#!/usr/bin/env python3
"""Independent INT8 fixture Golden for the NMAForge GPT-2-compatible shape.

This is a deterministic pseudo-weight fixture, not pretrained GPT-2. It
provides repeatable arithmetic vectors for model-toolchain bring-up and does
not silently replace unsupported hardware operators with host results.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

CONFIG = dict(layers=4, hidden=64, heads=4, ffn=256, vocab=256, context=16)


def q8(x: np.ndarray) -> np.ndarray:
    return np.clip(np.rint(x), -127, 127).astype(np.int8)


def make_model(seed: int = 20261114) -> dict[str, np.ndarray]:
    rng = np.random.default_rng(seed)
    model: dict[str, np.ndarray] = {"embedding": q8(rng.normal(0, 12, (256, 64)))}
    for layer in range(4):
        for name, shape in (
            ("q", (64, 64)), ("k", (64, 64)), ("v", (64, 64)),
            ("o", (64, 64)), ("up", (64, 256)), ("down", (256, 64)),
        ):
            model[f"l{layer}.{name}"] = q8(rng.normal(0, 2.0, shape))
        model[f"l{layer}.ln1_gamma"] = q8(rng.normal(1.0, .04, (64,)))
        model[f"l{layer}.ln2_gamma"] = q8(rng.normal(1.0, .04, (64,)))
        model[f"l{layer}.ln1_beta"] = np.zeros(64, dtype=np.int32)
        model[f"l{layer}.ln2_beta"] = np.zeros(64, dtype=np.int32)
    model["lm_head"] = q8(rng.normal(0, 2.0, (64, 256)))
    return model


def layer_norm(x: np.ndarray, gamma: np.ndarray, beta: np.ndarray) -> np.ndarray:
    # Integer contract: mean truncates toward zero; variance is floor; the
    # output is requantized to signed INT8 after gamma/beta.
    out = np.empty_like(x, dtype=np.int32)
    for i, row in enumerate(x.astype(np.int64)):
        mean = int(np.trunc(np.sum(row) / row.size))
        var = int(np.sum((row - mean) ** 2) // row.size)
        scale = max(1, int(np.sqrt(var + 1)))
        out[i] = np.clip(((row - mean) * gamma.astype(np.int64)) // scale + beta, -127, 127)
    return out.astype(np.int8)


def infer(model: dict[str, np.ndarray], tokens: np.ndarray) -> tuple[np.ndarray, list[np.ndarray]]:
    x = model["embedding"][tokens.astype(np.int64)].astype(np.int8)
    states: list[np.ndarray] = []
    for layer in range(4):
        n1 = layer_norm(x, model[f"l{layer}.ln1_gamma"], model[f"l{layer}.ln1_beta"])
        q = n1.astype(np.int32) @ model[f"l{layer}.q"].astype(np.int32)
        k = n1.astype(np.int32) @ model[f"l{layer}.k"].astype(np.int32)
        v = n1.astype(np.int32) @ model[f"l{layer}.v"].astype(np.int32)
        # Integer attention: causal dot scores and max-score selection.  This
        # keeps the demo deterministic without claiming an unimplemented SFU
        # softmax implementation is equivalent to floating point attention.
        scores = (q @ k.T) // 64
        masked = np.where(np.triu(np.ones(scores.shape, dtype=bool), 1), -2**31, scores)
        weights = np.zeros_like(masked, dtype=np.int32)
        for i in range(masked.shape[0]):
            row = masked[i, : i + 1]
            weights[i, : i + 1] = (row == np.max(row)).astype(np.int32)
        attn = (weights @ v) // max(1, np.max(np.sum(weights, axis=1)))
        x = np.clip(x.astype(np.int32) + (attn @ model[f"l{layer}.o"].astype(np.int32)) // 256, -127, 127).astype(np.int8)
        n2 = layer_norm(x, model[f"l{layer}.ln2_gamma"], model[f"l{layer}.ln2_beta"])
        up = n2.astype(np.int32) @ model[f"l{layer}.up"].astype(np.int32)
        gelu = np.maximum(up, 0)
        down = gelu @ model[f"l{layer}.down"].astype(np.int32)
        x = np.clip(x.astype(np.int32) + down // 256, -127, 127).astype(np.int8)
        states.append(x.copy())
    logits = x.astype(np.int32) @ model["lm_head"].astype(np.int32)
    return logits.astype(np.int32), states


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--seed", type=int, default=20261114)
    ap.add_argument("--tokens", default="1,7,42,3")
    ap.add_argument("--out", type=Path, default=Path("gpt2_compat_golden.json"))
    ap.add_argument("--weights", type=Path, default=Path("gpt2_compat_weights.npz"))
    args = ap.parse_args()
    tokens = np.asarray([int(x) for x in args.tokens.split(",")], dtype=np.int32)
    if len(tokens) == 0 or len(tokens) > CONFIG["context"] or np.any((tokens < 0) | (tokens >= CONFIG["vocab"])):
        raise SystemExit("tokens must be in [0,255] and fit context=16")
    model = make_model(args.seed)
    logits, states = infer(model, tokens)
    args.weights.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(args.weights, **model)
    report = {
        "config": CONFIG, "seed": args.seed, "tokens": tokens.tolist(),
        "next_tokens": np.argmax(logits, axis=1).astype(int).tolist(),
        "logits_sha256": hashlib.sha256(logits.tobytes()).hexdigest(),
        "state_sha256": hashlib.sha256(b"".join(s.tobytes() for s in states)).hexdigest(),
        "fixture_golden": "PASS",
        "weights_kind": "DETERMINISTIC_PSEUDO_WEIGHTS_NOT_PRETRAINED",
        "rtl_execution": "NOT_RUN",
        "unsupported_product_ops": ["causal_attention_softmax", "persistent_decode_controller"],
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
