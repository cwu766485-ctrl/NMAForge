#!/usr/bin/env python3
"""Train and export a small H=16, two-head QKV projection workload.

This is a supervised synthetic token-projection task, not a complete
Transformer language model.  A deterministic multiclass perceptron learns
three INT8 projections from token IDs to query, key, and next-token value
classes.  The exported matrices are then consumed by the real Top Matrix GEMM
path through ``cimforge_mapper.py``.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import random
from pathlib import Path


HIDDEN = 16
HEADS = 2
HEAD_DIM = 8
TOKENS = list(range(HIDDEN))
TARGETS = {
    "wq": lambda token: token,
    "wk": lambda token: (token * 5 + 3) % HIDDEN,
    "wv": lambda token: (token + 1) % HIDDEN,
}


def train_projection(target_fn, rng: random.Random, max_epochs: int = 64):
    weights = [[0 for _ in range(HIDDEN)] for _ in range(HIDDEN)]
    order = TOKENS[:]
    epochs = 0
    for epoch in range(max_epochs):
        rng.shuffle(order)
        errors = 0
        for token in order:
            target = target_fn(token)
            scores = weights[token]
            predicted = max(range(HIDDEN), key=lambda index: scores[index])
            if predicted != target:
                scores[target] += 1
                scores[predicted] -= 1
                errors += 1
        epochs = epoch + 1
        if errors == 0:
            break
    accuracy = sum(
        max(range(HIDDEN), key=lambda index: weights[token][index]) == target_fn(token)
        for token in TOKENS
    )
    if accuracy != HIDDEN:
        raise RuntimeError(f"projection training did not converge: {accuracy}/{HIDDEN}")
    if any(value < -128 or value > 127 for row in weights for value in row):
        raise OverflowError("trained projection is outside the INT8 export range")
    return weights, epochs, accuracy


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=20261113)
    args = parser.parse_args()

    rng = random.Random(args.seed)
    weights = {}
    training = {}
    for name, target_fn in TARGETS.items():
        matrix, epochs, accuracy = train_projection(target_fn, rng)
        weights[name] = matrix
        training[name] = {
            "epochs": epochs,
            "samples": HIDDEN,
            "correct": accuracy,
            "accuracy": accuracy / HIDDEN,
        }

    embeddings = [[int(token == column) for column in range(HIDDEN)]
                  for token in range(HIDDEN)]
    model = {
        "model_name": "tiny_transformer_h16_2head_qkv_projection_subgraph",
        "model_scope": "trained QKV projection subgraph only; not full Transformer inference",
        "weight_provenance": "deterministically supervised perceptron training from synthetic token projection labels",
        "seed": args.seed,
        "shape": {
            "hidden": HIDDEN,
            "attention_heads": HEADS,
            "head_dim": HEAD_DIM,
            "layers": 1,
            "sequence_length": 8,
            "dtype": "signed INT8",
        },
        "training": {
            "algorithm": "multiclass perceptron, deterministic seeded sample order, integer update",
            "input_embeddings": "16-dimensional one-hot token embedding",
            "q_label": "current token ID",
            "k_label": "(5 * token ID + 3) modulo 16",
            "v_label": "(token ID + 1) modulo 16",
            "projection_metrics": training,
            "sequence_train_accuracy": 1.0,
            "sequence_train_predictions": 8,
        },
        "prefill_tokens": list(range(8)),
        "embeddings": embeddings,
        "weights": weights,
        "host_fallback": [
            "Attention head split/merge, QK, Softmax, AV, residual, LayerNorm, FFN, and KV-cache are outside this QKV-only Top subgraph."
        ],
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(model, indent=2, sort_keys=True) + "\n",
                        encoding="utf-8")
    digest = hashlib.sha256(args.out.read_bytes()).hexdigest()
    print(
        "TRANSFORMER_H16_QKV_TRAIN_PASS "
        f"hidden={HIDDEN} heads={HEADS} head_dim={HEAD_DIM} sequence=8 "
        f"train_accuracy=48/48 model_sha256={digest} out={args.out}"
    )


if __name__ == "__main__":
    main()
