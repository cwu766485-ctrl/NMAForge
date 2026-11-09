#!/usr/bin/env python3
"""Train and export a deterministic INT8 3x3/pointwise CNN for Top replay.

The model is trained from scikit-learn's bundled Digits data.  Its convolution
is evaluated through the production Matrix GEMM path after host-side Im2col;
the host lowering and transfer costs are recorded separately.
"""

import argparse
import hashlib
import json
import platform
import time
from pathlib import Path

import numpy as np
import sklearn
from sklearn.datasets import load_digits
from sklearn.model_selection import train_test_split


SEED_DEFAULT = 20261119
EPOCHS_DEFAULT = 250
HIDDEN = 63
OUTPUTS = 10
IMAGE_SIZE = 16
CONV_SIZE = 14
POSITIONS = CONV_SIZE * CONV_SIZE


def load_dataset(seed):
    dataset = load_digits()
    labels = dataset.target.astype(np.int64)
    images = dataset.images.astype(np.float32) / 16.0
    images = np.repeat(np.repeat(images, 2, axis=1), 2, axis=2)
    coords = np.linspace(-1.0, 1.0, IMAGE_SIZE, dtype=np.float32)
    yy, xx = np.meshgrid(coords, coords, indexing="ij")
    planes = np.stack(
        (images, np.ones_like(images), np.broadcast_to(yy, images.shape),
         np.broadcast_to(xx, images.shape)), axis=-1
    )
    raw_hash = hashlib.sha256(
        dataset.images.tobytes(order="C") + labels.astype("<i8").tobytes()
    ).hexdigest()
    train_idx, test_idx = train_test_split(
        np.arange(len(labels)), test_size=0.2, random_state=seed,
        stratify=labels
    )
    return planes, labels, train_idx, test_idx, raw_hash


def lower_images(planes):
    # Feature order is [kernel-position][input-channel], with four planes per
    # pixel. This matches the flattened K dimension exported to the Matrix B
    # operand and the Top workload generator's physical Matrix-A layout.
    n = len(planes)
    patches = np.stack(
        [planes[:, y:y + CONV_SIZE, x:x + CONV_SIZE, :].reshape(
            n, POSITIONS, 4
        ) for y in range(3) for x in range(3)], axis=2
    )
    return patches.reshape(n, POSITIONS, 36).astype(np.float32)


def forward_float(columns, w1, w2):
    conv = columns @ w1
    hidden = np.concatenate(
        (np.maximum(conv, 0.0), np.ones((*conv.shape[:2], 1), np.float32)),
        axis=2,
    )
    logits = (hidden @ w2).mean(axis=1)
    return logits


def train(columns, labels, train_idx, seed, epochs):
    rng = np.random.default_rng(seed)
    w1 = rng.normal(0.0, 0.12, (36, HIDDEN)).astype(np.float32)
    w2 = rng.normal(0.0, 0.12, (HIDDEN + 1, OUTPUTS)).astype(np.float32)
    m1, v1 = np.zeros_like(w1), np.zeros_like(w1)
    m2, v2 = np.zeros_like(w2), np.zeros_like(w2)
    step = 0
    batch_size = 32
    learning_rate = 0.005
    for _epoch in range(epochs):
        order = rng.permutation(train_idx)
        for start in range(0, len(order), batch_size):
            ids = order[start:start + batch_size]
            x = columns[ids]
            batch = len(ids)
            conv = x @ w1
            hidden = np.concatenate(
                (np.maximum(conv, 0.0),
                 np.ones((batch, POSITIONS, 1), np.float32)), axis=2
            )
            logits = (hidden @ w2).mean(axis=1)
            logits -= logits.max(axis=1, keepdims=True)
            exp = np.exp(logits)
            prob = exp / exp.sum(axis=1, keepdims=True)
            prob[np.arange(batch), labels[ids]] -= 1.0
            dlogits = np.repeat(
                (prob[:, None, :] / (batch * POSITIONS)), POSITIONS, axis=1
            )
            grad_w2 = np.einsum("bpc,bpn->cn", hidden, dlogits,
                                optimize=True)
            d_hidden = dlogits @ w2.T
            d_conv = d_hidden[:, :, :HIDDEN] * (conv > 0.0)
            grad_w1 = np.einsum("bpk,bpc->kc", x, d_conv, optimize=True)
            step += 1
            for weight, grad, moment, variance in (
                (w1, grad_w1, m1, v1), (w2, grad_w2, m2, v2)
            ):
                moment *= 0.9
                moment += 0.1 * grad
                variance *= 0.999
                variance += 0.001 * grad * grad
                weight -= learning_rate * (moment / (1.0 - 0.9 ** step)) / (
                    np.sqrt(variance / (1.0 - 0.999 ** step)) + 1e-8
                )
    return w1, w2


def quantize(w1_float, w2_float, columns, labels, train_idx):
    # A constant input plane implements the learned feature-63 offset without
    # requiring a bias-enabled Matrix descriptor.
    w1_scale = max(1.0, float(np.max(np.abs(w1_float))))
    w1_q = np.zeros((36, 64), dtype=np.int8)
    w1_q[:, :HIDDEN] = np.rint(w1_float * (127.0 / w1_scale)).clip(
        -127, 127
    ).astype(np.int8)
    w1_q[:, HIDDEN] = 0
    w1_q[1, HIDDEN] = int(np.rint(127.0 / w1_scale))

    w2_scale = float(np.max(np.abs(w2_float)))
    w2_q = np.zeros((64, 16), dtype=np.int8)
    w2_q[:, :OUTPUTS] = np.rint(w2_float * (127.0 / w2_scale)).clip(
        -127, 127
    ).astype(np.int8)

    columns_q = np.rint(columns * 127.0).clip(-127, 127).astype(np.int32)
    raw1 = columns_q @ w1_q.astype(np.int32)
    max_raw1 = max(1, int(np.max(np.maximum(raw1[train_idx], 0))))
    shift1 = max(0, min(31, int(np.ceil(np.log2(max_raw1 / 100.0)))))
    hidden_q = np.clip(raw1 >> shift1, 0, 127).astype(np.int8)
    raw2 = hidden_q.astype(np.int32) @ w2_q.astype(np.int32)
    max_raw2 = max(1, int(np.max(np.abs(raw2[train_idx]))))
    shift2 = max(0, min(31, int(np.ceil(np.log2(max_raw2 / 100.0)))))
    logits_q = np.clip(raw2 >> shift2, -128, 127).astype(np.int8)
    return w1_q, w2_q, shift1, shift2, logits_q, hidden_q


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=SEED_DEFAULT)
    parser.add_argument("--epochs", type=int, default=EPOCHS_DEFAULT)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    started = time.perf_counter()

    planes, labels, train_idx, test_idx, dataset_sha = load_dataset(args.seed)
    columns = lower_images(planes)
    w1_float, w2_float = train(columns, labels, train_idx, args.seed,
                               args.epochs)
    float_logits = forward_float(columns, w1_float, w2_float)
    float_pred = float_logits.argmax(axis=1)
    w1_q, w2_q, shift1, shift2, logits_q, hidden_q = quantize(
        w1_float, w2_float, columns, labels, train_idx
    )
    quant_pred = logits_q[test_idx, :, :OUTPUTS].astype(np.int32).mean(axis=1).argmax(axis=1)
    float_test_acc = float(np.mean(float_pred[test_idx] == labels[test_idx]))
    quant_test_acc = float(np.mean(quant_pred == labels[test_idx]))

    artifact = {
        "model": "r19_trained_digits_3x3_pointwise_int8",
        "seed": args.seed,
        "epochs": args.epochs,
        "dataset": "sklearn.datasets.load_digits; 8x8 grayscale; nearest 2x upsample to 16x16",
        "dataset_sha256": dataset_sha,
        "split": "stratified 80/20; sklearn train_test_split random_state=seed",
        "train_count": int(len(train_idx)),
        "test_count": int(len(test_idx)),
        "train_indices": train_idx.tolist(),
        "test_indices": test_idx.tolist(),
        "input_planes": ["intensity", "constant-one", "absolute-y[-1,1]", "absolute-x[-1,1]"],
        "input_shape": [1, 16, 16, 4],
        "conv1": {"kernel": [3, 3], "input_channels": 4, "trained_output_channels": HIDDEN,
                  "exported_output_channels": 64, "padding": "valid", "activation": "ReLU"},
        "conv2": {"kernel": [1, 1], "input_channels": 64, "output_channels": 10,
                  "exported_output_channels": 16, "activation": "none"},
        "training": {"optimizer": "Adam", "batch_size": 32, "learning_rate": 0.005,
                     "framework": "NumPy analytic backpropagation", "float_test_accuracy": float_test_acc},
        "quantization": {
            "weights": "signed INT8 symmetric round-to-nearest, per-layer max-abs scale",
            "activations": "signed INT8; input round-to-nearest after multiplying by 127",
            "accumulation": "signed INT32",
            "conv1_shift": shift1,
            "conv1_activation": "ReLU then signed INT8 saturation",
            "conv2_shift": shift2,
            "conv2_activation": "signed INT8 saturation, no ReLU",
            "logits": "host global-average over 14x14 spatial positions then argmax",
        },
        "quantized_test_accuracy": quant_test_acc,
        "weights_int8": {"conv1_k36_n64": w1_q.astype(int).tolist(),
                         "conv2_k64_n16": w2_q.astype(int).tolist()},
        "weights_float": {"conv1_k36_n63": w1_float.astype(float).tolist(),
                          "conv2_k64_n10": w2_float.astype(float).tolist()},
        "deployed_weight_sha256": hashlib.sha256(
            w1_q.tobytes(order="C") + w2_q.tobytes(order="C")
        ).hexdigest(),
        "training_script_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        "software": {"python": platform.python_version(), "numpy": np.__version__,
                     "scikit_learn": sklearn.__version__},
        "useful_macs_per_inference": 196 * (36 * HIDDEN + 1 + 64 * OUTPUTS),
        "host_im2col": "3x3 valid, 16x16x4 input planes -> 196x36 INT8 matrix; timed by workload generator",
        "float_prediction_count": int(len(test_idx)),
        "quantized_prediction_count": int(len(test_idx)),
        "training_wall_seconds": time.perf_counter() - started,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n",
                        encoding="utf-8")
    print("R19_TRAINED_CNN_PASS seed=%d train=%d test=%d float_test_accuracy=%.6f quantized_test_accuracy=%.6f useful_macs=%d model_sha256=%s" % (
        args.seed, len(train_idx), len(test_idx), float_test_acc,
        quant_test_acc, artifact["useful_macs_per_inference"],
        hashlib.sha256(args.out.read_bytes()).hexdigest()))


if __name__ == "__main__":
    main()
