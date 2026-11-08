#!/usr/bin/env python3
"""Train and export deterministic INT8 weights for an H16 Transformer block.

This is a supervised synthetic token task used to exercise a real one-layer
attention/FFN block. It is not a language model or a pretrained checkpoint.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import random
from pathlib import Path

from train_transformer_h16_qkv import HEADS, HEAD_DIM, HIDDEN, TOKENS, train_projection


TARGETS = {
    "wq": lambda token: token,
    "wk": lambda token: (5 * token + 3) % HIDDEN,
    "wv": lambda token: (token + 1) % HIDDEN,
    "wo": lambda token: (3 * token + 2) % HIDDEN,
    "wup": lambda token: (7 * token + 1) % HIDDEN,
    "wdown": lambda token: (9 * token + 5) % HIDDEN,
}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=20261114)
    args = parser.parse_args()

    rng = random.Random(args.seed)
    weights = {}
    metrics = {}
    for name, target in TARGETS.items():
        weights[name], epochs, correct = train_projection(target, rng)
        metrics[name] = {"epochs": epochs, "samples": HIDDEN, "correct": correct,
                         "accuracy": correct / HIDDEN}

    embeddings = [[int(token == column) for column in range(HIDDEN)]
                  for token in range(HIDDEN)]
    model = {
        "model_name": "tiny_transformer_h16_2head_full_block_synthetic",
        "model_scope": "one-layer H16 two-head INT8 Transformer-style prefill block; synthetic supervised task, not language modeling",
        "weight_provenance": "all six INT8 projection matrices deterministically trained by seeded integer multiclass perceptrons on synthetic token projection labels",
        "seed": args.seed,
        "shape": {"hidden": HIDDEN, "attention_heads": HEADS,
                  "head_dim": HEAD_DIM, "layers": 1, "sequence_length": 8,
                  "dtype": "signed INT8"},
        "training": {
            "algorithm": "six deterministic integer multiclass perceptrons; no floating-point training",
            "samples_per_projection": HIDDEN,
            "projection_metrics": metrics,
            "gamma_beta": "LayerNorm affine parameters use fixed identity initialization (gamma=32768 Q15, beta=0), not trained",
        },
        "prefill_tokens": list(range(8)),
        "decode_token": 7,
        "embeddings": embeddings,
        "weights": weights,
        "gamma1_q15": [32768] * HIDDEN,
        "beta1": [0] * HIDDEN,
        "gamma2_q15": [32768] * HIDDEN,
        "beta2": [0] * HIDDEN,
        "host_fallback": ["training and independent software Golden only; runtime activations are produced by Top RTL"],
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(model, indent=2, sort_keys=True) + "\n",
                        encoding="utf-8")
    digest = hashlib.sha256(args.out.read_bytes()).hexdigest()
    print(f"TRANSFORMER_H16_BLOCK_TRAIN_PASS seed={args.seed} "
          f"weights={len(weights)} model_sha256={digest} out={args.out}")


if __name__ == "__main__":
    main()
