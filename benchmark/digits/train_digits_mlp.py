#!/usr/bin/env python3
"""Train and quantize a reproducible 64-64-10 MLP on sklearn digits."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from sklearn.datasets import load_digits
from sklearn.model_selection import train_test_split


SEED = 20261029


def split_data(seed: int = SEED):
    dataset = load_digits()
    x = dataset.images.reshape(-1, 64).astype(np.float32) / np.float32(16.0)
    y = dataset.target.astype(np.int64)
    indices = np.arange(y.size)
    train_idx, test_idx = train_test_split(
        indices, test_size=0.2, random_state=seed, stratify=y
    )
    fit_idx, valid_idx = train_test_split(
        train_idx, test_size=0.1, random_state=seed + 1, stratify=y[train_idx]
    )
    return x, y, fit_idx, valid_idx, test_idx


def softmax_loss(logits: np.ndarray, labels: np.ndarray) -> tuple[float, np.ndarray]:
    shifted = logits - logits.max(axis=1, keepdims=True)
    exp_logits = np.exp(shifted)
    probs = exp_logits / exp_logits.sum(axis=1, keepdims=True)
    loss = -np.log(np.maximum(probs[np.arange(labels.size), labels], 1e-12)).mean()
    probs[np.arange(labels.size), labels] -= 1.0
    probs /= labels.size
    return float(loss), probs.astype(np.float32)


def train_float(x: np.ndarray, y: np.ndarray, seed: int = SEED):
    rng = np.random.default_rng(seed)
    w1 = rng.normal(0, np.sqrt(2.0 / 64), size=(64, 64)).astype(np.float32)
    b1 = np.zeros(64, dtype=np.float32)
    w2 = rng.normal(0, np.sqrt(2.0 / 64), size=(64, 10)).astype(np.float32)
    b2 = np.zeros(10, dtype=np.float32)
    params = [w1, b1, w2, b2]
    first = [np.zeros_like(p) for p in params]
    second = [np.zeros_like(p) for p in params]
    beta1, beta2, eps = 0.9, 0.999, 1e-8
    step, batch_size, learning_rate = 0, 64, 1e-3

    for _epoch in range(180):
        order = rng.permutation(y.size)
        for begin in range(0, y.size, batch_size):
            ids = order[begin : begin + batch_size]
            xb, yb = x[ids], y[ids]
            z1 = xb @ w1 + b1
            h1 = np.maximum(z1, 0.0)
            logits = h1 @ w2 + b2
            _loss, dlogits = softmax_loss(logits, yb)
            dw2 = h1.T @ dlogits
            db2 = dlogits.sum(axis=0)
            dh1 = dlogits @ w2.T
            dz1 = dh1 * (z1 > 0)
            dw1 = xb.T @ dz1
            db1 = dz1.sum(axis=0)
            grads = [dw1, db1, dw2, db2]
            step += 1
            for idx, (param, grad) in enumerate(zip(params, grads)):
                first[idx] = beta1 * first[idx] + (1.0 - beta1) * grad
                second[idx] = beta2 * second[idx] + (1.0 - beta2) * grad * grad
                mhat = first[idx] / (1.0 - beta1**step)
                vhat = second[idx] / (1.0 - beta2**step)
                param -= learning_rate * mhat / (np.sqrt(vhat) + eps)
    return w1, b1, w2, b2


def quantize_symmetric(values: np.ndarray) -> tuple[np.ndarray, float]:
    scale = float(np.max(np.abs(values))) / 127.0
    if scale == 0.0:
        scale = 1.0
    quantized = np.clip(np.rint(values / scale), -127, 127).astype(np.int8)
    return quantized, scale


def integer_forward(x_q: np.ndarray, w1_q: np.ndarray, b1_q: np.ndarray,
                    w2_q: np.ndarray, b2_q: np.ndarray, shift1: int):
    acc1 = x_q.astype(np.int64) @ w1_q.astype(np.int64) + b1_q.astype(np.int64)
    hidden = np.clip(np.maximum(acc1 >> shift1, 0), 0, 127).astype(np.int8)
    acc2 = hidden.astype(np.int64) @ w2_q.astype(np.int64) + b2_q.astype(np.int64)
    return hidden, acc2


def accuracy(logits: np.ndarray, labels: np.ndarray) -> float:
    return float(np.mean(np.argmax(logits, axis=1) == labels))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--out-dir", type=Path,
        default=Path(__file__).resolve().parent / "artifacts",
    )
    args = parser.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)

    x, y, fit_idx, valid_idx, test_idx = split_data()
    w1, b1, w2, b2 = train_float(x[fit_idx], y[fit_idx])
    w1_q, w1_scale = quantize_symmetric(w1)
    w2_q10, w2_scale = quantize_symmetric(w2)
    w2_q = np.zeros((64, 12), dtype=np.int8)
    w2_q[:, :10] = w2_q10

    input_scale = 1.0 / 127.0
    x_q = np.clip(np.rint(x / input_scale), 0, 127).astype(np.int8)
    bias1_scale = input_scale * w1_scale
    b1_q64 = np.rint(b1 / bias1_scale).astype(np.int64)
    b2_q10 = np.rint(b2 / (1.0 * w2_scale)).astype(np.int64)

    valid_acc1 = x_q[valid_idx].astype(np.int64) @ w1_q.astype(np.int64)
    valid_acc1 += b1_q64
    max_positive = max(1, int(np.maximum(valid_acc1, 0).max()))
    candidate_shifts = range(max(0, int(np.ceil(np.log2(max_positive / 120.0)))), 32)
    best = None
    for shift1 in candidate_shifts:
        hidden_scale = bias1_scale * (2**shift1)
        b1_q = np.clip(b1_q64, -(1 << 31), (1 << 31) - 1).astype(np.int32)
        b2_q = np.zeros(12, dtype=np.int32)
        b2_q[:10] = np.clip(
            np.rint(b2 / (hidden_scale * w2_scale)),
            -(1 << 31), (1 << 31) - 1,
        ).astype(np.int32)
        _valid_hidden, valid_logits = integer_forward(
            x_q[valid_idx], w1_q, b1_q, w2_q, b2_q, shift1
        )
        score = accuracy(valid_logits[:, :10], y[valid_idx])
        candidate = (score, -shift1, shift1, hidden_scale, b1_q, b2_q)
        if best is None or candidate[:2] > best[:2]:
            best = candidate

    assert best is not None
    _score, _negative_shift, shift1, hidden_scale, b1_q, b2_q = best
    fit_hidden, fit_logits = integer_forward(
        x_q[fit_idx], w1_q, b1_q, w2_q, b2_q, shift1
    )
    valid_hidden, valid_logits = integer_forward(
        x_q[valid_idx], w1_q, b1_q, w2_q, b2_q, shift1
    )
    test_hidden, test_logits = integer_forward(
        x_q[test_idx], w1_q, b1_q, w2_q, b2_q, shift1
    )
    float_test_hidden = np.maximum(x[test_idx] @ w1 + b1, 0)
    float_test_logits = float_test_hidden @ w2 + b2

    metrics = {
        "dataset": "sklearn.datasets.load_digits",
        "architecture": "64-64-ReLU-10 logits (benchmark pads to the 16-column array tile)",
        "seed": SEED,
        "split": {"fit": int(fit_idx.size), "validation": int(valid_idx.size),
                  "test": int(test_idx.size)},
        "epochs": 180,
        "optimizer": "NumPy Adam, batch=64, learning_rate=0.001, FP32",
        "weight_quantization": "symmetric per-layer INT8, round-to-nearest, clamp [-127,127]",
        "input_scale": input_scale,
        "w1_scale": w1_scale,
        "w2_scale": w2_scale,
        "hidden_shift": int(shift1),
        "hidden_scale": float(hidden_scale),
        "fp32_test_accuracy": accuracy(float_test_logits, y[test_idx]),
        "int8_test_accuracy": accuracy(test_logits[:, :10], y[test_idx]),
        "int8_validation_accuracy": accuracy(valid_logits[:, :10], y[valid_idx]),
        "padded_logits": 12,
        "test_samples": int(test_idx.size),
        "hardware_test_batches_of_16": int(np.ceil(test_idx.size / 16)),
        "hardware_integer_rule": "int32 accumulator; bias before arithmetic right shift; ReLU then signed INT8 clamp",
    }
    np.savez_compressed(
        args.out_dir / "digits_mlp_int8.npz",
        w1_fp32=w1.astype(np.float32), b1_fp32=b1.astype(np.float32),
        w2_fp32=w2.astype(np.float32), b2_fp32=b2.astype(np.float32),
        w1_int8=w1_q, b1_acc_int32=b1_q,
        w2_int8=w2_q, b2_acc_int32=b2_q,
        input_scale=np.float64(input_scale), w1_scale=np.float64(w1_scale),
        w2_scale=np.float64(w2_scale), hidden_scale=np.float64(hidden_scale),
        hidden_shift=np.int32(shift1), test_indices=test_idx.astype(np.int32),
        test_images_q=x_q[test_idx], test_labels=y[test_idx].astype(np.int8),
        test_hidden_i8=test_hidden, test_logits_i32=test_logits.astype(np.int32),
        fit_hidden_i8=fit_hidden[:16], fit_logits_i32=fit_logits[:16].astype(np.int32),
        validation_hidden_i8=valid_hidden[:16],
    )
    (args.out_dir / "training_report.json").write_text(
        json.dumps(metrics, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(json.dumps(metrics, indent=2, sort_keys=True))
    if metrics["int8_test_accuracy"] < 0.90:
        raise SystemExit("INT8 digits test accuracy is below the 90% experiment target")


if __name__ == "__main__":
    main()
