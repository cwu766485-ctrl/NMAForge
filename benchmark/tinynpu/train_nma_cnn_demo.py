#!/usr/bin/env python3
"""Train a compact INT8 CNN readout over fixed local edge filters."""

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from sklearn.datasets import load_digits
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split


KERNELS = np.asarray([
    [[1, 0, -1], [1, 0, -1], [1, 0, -1]],
    [[1, 1, 1], [0, 0, 0], [-1, -1, -1]],
    [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
    [[0, 0, 1], [0, 1, 0], [1, 0, 0]],
], dtype=np.float32)


def quantize_int8(values):
    values = np.asarray(values, dtype=np.float64)
    peak = float(np.max(np.abs(values)))
    if peak == 0:
        return np.zeros_like(values, dtype=np.int8)
    return np.clip(np.rint(values * (127.0 / peak)), -127, 127).astype(np.int8)


def deployed_conv_features(images):
    weights = quantize_int8(KERNELS).astype(np.int64)
    result = np.zeros((len(images), 144), dtype=np.uint8)
    for image_index, image in enumerate(images):
        pixels = (np.asarray(image, dtype=np.int64) // 4).clip(0, 127)
        acc = np.zeros((36, 4), dtype=np.int64)
        position = 0
        for row in range(6):
            for col in range(6):
                for channel in range(4):
                    total = 0
                    for kr in range(3):
                        for kc in range(3):
                            total += int(pixels[row + kr, col + kc]) * int(weights[channel, kr, kc])
                    acc[position, channel] = total
                position += 1
        rounded = (acc + 8) >> 4
        signed_i8 = np.clip(rounded, -128, 127).astype(np.int8).astype(np.int16)
        result[image_index] = np.clip(np.maximum(signed_i8, 0), 0, 127).astype(np.uint8).reshape(-1)
    return result


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
    train_features = deployed_conv_features(x_train)
    test_features = deployed_conv_features(x_test)

    # The four 3x3 edge kernels are fixed. The dense readout is trained on
    # their actual INT8, rounded, saturated RTL-visible feature values.
    classifier = LogisticRegression(C=1.0, fit_intercept=False, max_iter=2000,
                                    random_state=29, tol=1e-10)
    classifier.fit(train_features.astype(np.float64), y_train)
    fc_weights = classifier.coef_.astype(np.float32)
    test_logits = integer_cnn_logits(test_features, fc_weights)
    predictions = np.argmax(test_logits, axis=1)
    correct = predictions == y_test
    selected_index = int(np.flatnonzero(correct)[0])

    model_path = args.out_dir / "nma_tiny_cnn_demo_weights.npz"
    np.savez(model_path,
             conv_w=KERNELS[:, None, :, :],
             conv_b=np.zeros(4, dtype=np.float32),
             fc_w=fc_weights,
             fc_b=np.zeros(4, dtype=np.float32),
             model_kind=np.asarray("fixed_edge_conv_trained_int8_readout"))
    input_path = args.out_dir / "nma_tiny_cnn_demo_input.npz"
    selected = (x_test[selected_index].astype(np.int16) // 4).astype(np.int8)
    np.savez(input_path,
             input_int8=selected.reshape(1, 1, 8, 8),
             input_scale=np.asarray(0.25, dtype=np.float32),
             label=np.asarray(y_test[selected_index], dtype=np.int32),
             test_index=np.asarray(selected_index, dtype=np.int32))

    dataset_hash = hashlib.sha256(
        images.tobytes() + labels.astype(np.uint8).tobytes()).hexdigest()
    manifest = {
        "model": model_path.name,
        "model_kind": "four fixed edge kernels plus trained four-class INT8 linear readout",
        "training": "scikit-learn LogisticRegression; C=1; no fitted intercept; trained on deployed integer convolution features",
        "dataset": "sklearn.datasets.load_digits restricted to labels 0..3",
        "dataset_sha256": dataset_hash,
        "split": {"train": int(len(y_train)), "test": int(len(y_test)),
                  "test_size": 0.22, "random_state": 29, "stratified": True},
        "input_quantization": "floor(pixel / 4), INT8; hardware input scale recorded as 0.25",
        "conv_contract": "signed INT32 dot, round (acc+8)>>4, clamp INT8, ReLU",
        "fc_contract": "symmetric per-tensor INT8 weights, signed INT32 dot, round (acc+128)>>8, clamp INT8",
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
    }
    (args.out_dir / "nma_tiny_cnn_demo_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("NMA_TRAINED_CNN_PRECHECK_PASS correct=%d/%d accuracy=%.6f selected_label=%d selected_prediction=%d model_sha256=%s" %
          (manifest["test_correct"], manifest["test_count"], manifest["test_accuracy"],
           manifest["rtl_sample"]["label"], manifest["rtl_sample"]["prediction"],
           manifest["model_sha256"]))


if __name__ == "__main__":
    main()
