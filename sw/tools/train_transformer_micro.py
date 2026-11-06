#!/usr/bin/env python3
"""Train/export a bounded INT8 one-layer Transformer toy workload.

Training is deterministic integer simulated annealing against the same
documented fixed-point primitives used by the independent software Golden.
The task is next-token prediction on four-symbol cyclic streams.  This is a
reproducible trained research fixture, not a language model or pretrained
checkpoint.
"""

from __future__ import annotations

import argparse
import hashlib
import itertools
import json
import math
import random
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "dv/block/compute/matrix/ref"))
sys.path.insert(0, str(ROOT / "sw/tools"))

from ai_a3_reference import (  # noqa: E402
    gemm_i8_i32,
    gelu_q8_8,
    layernorm_q15,
    requant_i8,
    residual_i32,
)
import cimforge_mapper  # noqa: E402


WEIGHT_NAMES = ("wq", "wk", "wv", "wo", "wup", "wdown")


def one_hot(token: int) -> list[int]:
    return [int(token == lane) for lane in range(4)]


def forward_prefill(tokens: list[int], weights: dict[str, list[list[int]]]) -> list[list[int]]:
    x = [one_hot(token) for token in tokens]
    q8 = [requant_i8(row, 0) for row in gemm_i8_i32(x, weights["wq"])]
    k8 = [requant_i8(row, 0) for row in gemm_i8_i32(x, weights["wk"])]
    v8 = [requant_i8(row, 0) for row in gemm_i8_i32(x, weights["wv"])]
    scores = gemm_i8_i32(q8, [list(column) for column in zip(*k8)])
    probs8 = [
        requant_i8(cimforge_mapper.causal_softmax_q15(row, index), 8)
        for index, row in enumerate(scores)
    ]
    attention8 = [
        requant_i8(row, 7)
        for row in gemm_i8_i32(probs8, v8)
    ]
    projected = gemm_i8_i32(attention8, weights["wo"])
    norm1 = [
        layernorm_q15(residual_i32(projected_row, input_row), [32768] * 4, [0] * 4)
        for projected_row, input_row in zip(projected, x)
    ]
    expanded = gemm_i8_i32(
        [requant_i8(row, 0) for row in norm1], weights["wup"]
    )
    activated8 = [
        requant_i8([gelu_q8_8(value) for value in row], 0)
        for row in expanded
    ]
    down = gemm_i8_i32(activated8, weights["wdown"])
    return [
        layernorm_q15(residual_i32(down_row, norm1_row), [32768] * 4, [0] * 4)
        for down_row, norm1_row in zip(down, norm1)
    ]


def rows_for(tokens: list[int]) -> tuple[list[list[int]], list[int]]:
    return [one_hot(token) for token in tokens], [(token + 1) % 4 for token in tokens]


def train_score(weights: dict[str, list[list[int]]], samples: list[list[int]]) -> int:
    correct = 0
    margin_sum = 0
    for tokens in samples:
        outputs = forward_prefill(tokens, weights)
        for output, token in zip(outputs, tokens):
            label = (token + 1) % 4
            rival = max(value for index, value in enumerate(output) if index != label)
            margin_sum += output[label] - rival
            correct += int(output.index(max(output)) == label)
    return correct * 100_000 + margin_sum


def copy_weights(weights: dict[str, list[list[int]]]) -> dict[str, list[list[int]]]:
    return {name: [row[:] for row in weights[name]] for name in WEIGHT_NAMES}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=20261106)
    parser.add_argument("--steps", type=int, default=20_000)
    args = parser.parse_args()
    if args.steps < 1:
        raise SystemExit("--steps must be positive")

    train_tokens = [[(rotation + index) % 4 for index in range(4)]
                    for rotation in range(4)]
    rng = random.Random(args.seed)
    weights = {
        name: [[rng.randint(-3, 3) for _ in range(4)] for _ in range(4)]
        for name in WEIGHT_NAMES
    }
    best_weights = copy_weights(weights)
    current = best = train_score(weights, train_tokens)
    for step in range(args.steps):
        name = rng.choice(WEIGHT_NAMES)
        row = rng.randrange(4)
        column = rng.randrange(4)
        previous = weights[name][row][column]
        delta = rng.choice((-3, -2, -1, 1, 2, 3))
        weights[name][row][column] = max(-8, min(8, previous + delta))
        candidate = train_score(weights, train_tokens)
        temperature = max(0.25, 30 * (1 - step / args.steps))
        accept = candidate >= current or rng.random() < math.exp(
            max(-60, (candidate - current) / temperature)
        )
        if accept:
            current = candidate
            if candidate > best:
                best = candidate
                best_weights = copy_weights(weights)
        else:
            weights[name][row][column] = previous
        if best >= len(train_tokens) * 4 * 100_000:
            break

    train_correct = sum(
        int(output.index(max(output)) == (token + 1) % 4)
        for sequence in train_tokens
        for output, token in zip(forward_prefill(sequence, best_weights), sequence)
    )
    heldout = [
        list(sequence)
        for sequence in itertools.product(range(4), repeat=4)
        if sequence not in [tuple(tokens) for tokens in train_tokens]
    ]
    heldout_correct = sum(
        int(output.index(max(output)) == (token + 1) % 4)
        for sequence in heldout
        for output, token in zip(forward_prefill(sequence, best_weights), sequence)
    )
    model = {
        "model_name": "tiny_transformer_h4_cyclic_next_token_int8",
        "weight_provenance": "deterministically trained INT8 weights exported by sw/tools/train_transformer_micro.py",
        "training": {
            "seed": args.seed,
            "optimizer": "integer simulated annealing",
            "steps_requested": args.steps,
            "steps_executed": step + 1,
            "training_sequences": train_tokens,
            "training_correct": train_correct,
            "training_predictions": len(train_tokens) * 4,
            "heldout_sequences": len(heldout),
            "heldout_correct": heldout_correct,
            "heldout_predictions": len(heldout) * 4,
            "heldout_accuracy": heldout_correct / (len(heldout) * 4),
            "weight_range": [
                min(value for matrix in best_weights.values() for row in matrix for value in row),
                max(value for matrix in best_weights.values() for row in matrix for value in row),
            ],
        },
        "task": {
            "description": "predict the next symbol in a four-token cyclic stream",
            "vocabulary_size": 4,
            "label_rule": "(token_id + 1) % 4",
            "host_fallback": [],
        },
        "prefill_tokens": [0, 1, 2, 3],
        "decode_token": 0,
        "weights": best_weights,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    encoded = json.dumps(model, indent=2, sort_keys=True) + "\n"
    args.out.write_text(encoded, encoding="utf-8")
    digest = hashlib.sha256(args.out.read_bytes()).hexdigest()
    _, expected = cimforge_mapper.build_workload(model)
    metrics = expected["task_metrics"]
    print(
        "TRANSFORMER_TRAIN_EXPORT_PASS "
        f"seed={args.seed} steps={step + 1} train_accuracy="
        f"{train_correct}/{len(train_tokens) * 4} "
        f"heldout_accuracy={heldout_correct}/{len(heldout) * 4} "
        f"prefill_accuracy={metrics['prefill_correct']}/{metrics['prefill_count']} "
        f"decode_correct={metrics['decode_correct']} "
        f"model_sha256={digest} out={args.out}"
    )


if __name__ == "__main__":
    main()
