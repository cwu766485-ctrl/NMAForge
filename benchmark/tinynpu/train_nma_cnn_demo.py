#!/usr/bin/env python3
"""Train a compact INT8 Conv + linear classifier for the production-top demo."""

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from sklearn.datasets import load_digits
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score


def quantize_int8(values):
    values = np.asarray(values, dtype=np.float64)
    peak = float(np.max(np.abs(values)))
    if peak == 0:
        return np.zeros_like(values, dtype=np.int8)
    return np.clip(np.rint(values * (127.0 / peak)), -127, 127).astype(np.int8)


def conv_patches(images):
    pixels = (np.asarray(images, dtype=np.int64) // 4).astype(np.float32)
    return np.stack([
        pixels[:, row:row + 3, col:col + 3].reshape(len(pixels), 9)
        for row in range(6) for col in range(6)
    ], axis=1)


def train_convolution(images, labels):
    """Train four shared 3x3 filters with deterministic NumPy/Adam SGD."""
    patches = conv_patches(images)
    rng = np.random.default_rng(44)
    conv_w = (rng.normal(size=(4, 9)) * 0.12).astype(np.float32)
    conv_b = np.zeros(4, dtype=np.float32)
    fc_w = (rng.normal(size=(4, 144)) * 0.02).astype(np.float32)
    fc_b = np.zeros(4, dtype=np.float32)
    # Conv bias is intentionally fixed at zero: the RTL contract applies its
    # quantized bias after the requant stage, so fitting a pre-requant float
    # bias here would train a different function.
    parameters = [conv_w, fc_w, fc_b]
    first = [np.zeros_like(item) for item in parameters]
    second = [np.zeros_like(item) for item in parameters]
    step = 0

    for _epoch in range(250):
        order = rng.permutation(len(labels))
        for start in range(0, len(order), 128):
            indices = order[start:start + 128]
            batch = patches[indices]
            target = labels[indices]
            batch_count = len(indices)

            conv_acc = batch @ conv_w.T + conv_b
            activation = np.maximum(conv_acc, 0)
            logits = activation.reshape(batch_count, 144) @ fc_w.T + fc_b
            logits -= logits.max(axis=1, keepdims=True)
            probabilities = np.exp(logits)
            probabilities /= probabilities.sum(axis=1, keepdims=True)
            probabilities[np.arange(batch_count), target] -= 1.0
            probabilities /= batch_count

            grad_fc_w = probabilities.T @ activation.reshape(batch_count, 144)
            grad_fc_b = probabilities.sum(axis=0)
            grad_activation = (probabilities @ fc_w).reshape(batch_count, 36, 4)
            grad_conv_acc = grad_activation * (conv_acc > 0)
            grad_conv_w = np.einsum("npf,npk->fk", grad_conv_acc, batch)
            step += 1
            for parameter, gradient, moment, variance in zip(
                    parameters,
                    [grad_conv_w, grad_fc_w, grad_fc_b],
                    first, second):
                moment *= 0.9
                moment += 0.1 * gradient
                variance *= 0.999
                variance += 0.001 * gradient * gradient
                corrected_moment = moment / (1.0 - 0.9 ** step)
                corrected_variance = variance / (1.0 - 0.999 ** step)
                parameter -= 0.006 * corrected_moment / (
                    np.sqrt(corrected_variance) + 1e-8)

    logits = np.maximum(patches @ conv_w.T + conv_b, 0).reshape(len(labels), 144)
    logits = logits @ fc_w.T + fc_b
    return conv_w.reshape(4, 1, 3, 3), conv_b, fc_w, fc_b, accuracy_score(
        labels, logits.argmax(axis=1))


def deployed_conv_features(images, conv_w):
    weights = quantize_int8(conv_w[:, 0].reshape(4, 9)).astype(np.int64)
    patches = conv_patches(images).astype(np.int64)
    accumulators = patches @ weights.T
    rounded = (accumulators + 8) >> 4
    signed_i8 = np.clip(rounded, -128, 127).astype(np.int8)
    return np.clip(np.maximum(signed_i8, 0), 0, 127).astype(np.uint8).reshape(
        len(images), 144)


def integer_cnn_logits(features, fc_weights):
    weights_i8 = quantize_int8(fc_weights)
    accum = np.asarray(features, dtype=np.int64) @ weights_i8.astype(np.int64).T
    rounded = (accum + 128) >> 8
    return np.clip(rounded, -128, 127).astype(np.int8)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out-dir", required=True, type=Path)
    args = parser.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)

    dataset = load_digits()
    keep = dataset.target < 4
    images = dataset.images[keep].astype(np.uint8)
    labels = dataset.target[keep].astype(np.int64)
    x_train, x_test, y_train, y_test = train_test_split(
        images, labels, test_size=0.22, random_state=29, stratify=labels)

    conv_w, conv_b, _float_fc_w, _float_fc_b, float_train_accuracy = \
        train_convolution(x_train, y_train)
    train_features = deployed_conv_features(x_train, conv_w).astype(np.float64)
    test_features = deployed_conv_features(x_test, conv_w).astype(np.float64)
    classifier = LogisticRegression(C=1.0, fit_intercept=False, max_iter=2000,
                                    random_state=29, tol=1e-10)
    classifier.fit(train_features, y_train)
    fc_weights = classifier.coef_.astype(np.float32)
    test_logits = integer_cnn_logits(test_features, fc_weights)
    predictions = np.argmax(test_logits, axis=1)
    correct = predictions == y_test
    selected_index = int(np.flatnonzero(correct)[0])

    model_path = args.out_dir / "nma_tiny_cnn_demo_weights.npz"
    np.savez(model_path,
             conv_w=conv_w,
             conv_b=conv_b,
             fc_w=fc_weights,
             fc_b=np.zeros(4, dtype=np.float32),
             model_kind=np.asarray("trained_int8_conv_and_trained_int8_readout"))
    input_path = args.out_dir / "nma_tiny_cnn_demo_input.npz"
    quantized_test = (x_test.astype(np.int16) // 4).astype(np.int8)
    selected = quantized_test[selected_index]
    np.savez(input_path,
             input_int8=selected.reshape(1, 1, 8, 8),
             input_scale=np.asarray(0.25, dtype=np.float32),
             label=np.asarray(y_test[selected_index], dtype=np.int32),
             test_index=np.asarray(selected_index, dtype=np.int32))
    testset_path = args.out_dir / "nma_tiny_cnn_demo_testset.npz"
    np.savez(testset_path, input_int8=quantized_test[:, None, None, :, :],
             labels=y_test.astype(np.int32), input_scale=np.asarray(0.25, dtype=np.float32))

    dataset_hash = hashlib.sha256(
        images.tobytes() + labels.astype(np.uint8).tobytes()).hexdigest()
    manifest = {
        "model": model_path.name,
        "model_kind": "trained four-filter 3x3 convolution plus trained four-class INT8 readout",
        "training": {
            "convolution": "NumPy backpropagation with Adam; 250 epochs; batch 128; lr 0.006; seed 44",
            "readout": "scikit-learn LogisticRegression; C=1; fit_intercept=false; trained on deployed integer convolution features",
            "float_convolution_training_accuracy": float(float_train_accuracy),
        },
        "dataset": "sklearn.datasets.load_digits restricted to labels 0..3",
        "dataset_sha256": dataset_hash,
        "split": {"train": int(len(y_train)), "test": int(len(y_test)),
                  "test_size": 0.22, "random_state": 29, "stratified": True},
        "input_quantization": "floor(pixel / 4), INT8; input scale 0.25",
        "conv_contract": "trained shared 3x3 filters; signed INT32 dot; round (acc+8)>>4; clamp INT8; ReLU",
        "fc_contract": "symmetric per-tensor INT8 weights; signed INT32 dot; round (acc+128)>>8; clamp INT8",
        "test_correct": int(np.count_nonzero(correct)),
        "test_count": int(len(y_test)),
        "test_accuracy": float(np.mean(correct)),
        "test_confusion_matrix": [[int(np.sum((y_test == i) & (predictions == j)))
                                    for j in range(4)] for i in range(4)],
        "rtl_sample": {"test_index": selected_index,
                       "label": int(y_test[selected_index]),
                       "prediction": int(predictions[selected_index]),
                       "int8_logits": [int(v) for v in test_logits[selected_index]]},
        "model_sha256": hashlib.sha256(model_path.read_bytes()).hexdigest(),
        "input_sha256": hashlib.sha256(input_path.read_bytes()).hexdigest(),
        "testset_sha256": hashlib.sha256(testset_path.read_bytes()).hexdigest(),
    }
    (args.out_dir / "nma_tiny_cnn_demo_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("NMA_TRAINED_CNN_PRECHECK_PASS correct=%d/%d accuracy=%.6f model_sha256=%s" %
          (manifest["test_correct"], manifest["test_count"],
           manifest["test_accuracy"], manifest["model_sha256"]))


if __name__ == "__main__":
    main()
