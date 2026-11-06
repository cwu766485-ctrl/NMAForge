#!/usr/bin/env python3
"""Independent integer Golden for the trained CNN demo."""

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np


def quantize(values):
    values = np.asarray(values, dtype=np.float64)
    peak = float(np.max(np.abs(values)))
    if peak < 1e-10:
        return np.zeros_like(values, dtype=np.int8)
    return np.clip(np.rint(values * (127.0 / peak)), -128, 127).astype(np.int8)


def compute_logits(model_path, input_npz):
    with np.load(model_path) as package:
        conv_w = quantize(package["conv_w"][:, 0].reshape(4, 9)).astype(np.int64)
        conv_b = quantize(package["conv_b"]).astype(np.int64)
        fc_w = quantize(package["fc_w"]).astype(np.int64)
        fc_b = quantize(package["fc_b"]).astype(np.int64)
    with np.load(input_npz) as sample:
        pixels = sample["input_int8"][0, 0].astype(np.int64)
        label = int(sample["label"].item())

    im2col = np.asarray([
        [pixels[row + kr, col + kc] for kr in range(3) for kc in range(3)]
        for row in range(6) for col in range(6)
    ], dtype=np.int64)
    conv_acc = im2col @ conv_w.T
    conv_scaled = (conv_acc + 8) >> 4
    conv_i8 = np.minimum(np.maximum(conv_scaled, -128), 127).astype(np.int8)
    conv_bias_relu = np.maximum(conv_i8.astype(np.int64) + conv_b, 0)
    conv_relu = np.minimum(conv_bias_relu, 127).astype(np.int8)
    fc_acc = conv_relu.reshape(-1).astype(np.int64) @ fc_w.T
    fc_scaled = (fc_acc + 128) >> 8
    fc_i8 = np.minimum(np.maximum(fc_scaled, -128), 127).astype(np.int64)
    logits = np.minimum(np.maximum(fc_i8 + fc_b, -128), 127).astype(np.int8)
    return logits, label


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--input-npz", type=Path, required=True)
    parser.add_argument("--golden", type=Path, required=True)
    args = parser.parse_args()
    logits, label = compute_logits(args.model, args.input_npz)
    prediction = int(np.argmax(logits))
    args.golden.parent.mkdir(parents=True, exist_ok=True)
    output = logits.tobytes()
    args.golden.write_bytes(output)
    record = {
        "model_sha256": hashlib.sha256(args.model.read_bytes()).hexdigest(),
        "input_sha256": hashlib.sha256(args.input_npz.read_bytes()).hexdigest(),
        "independent_integer_logits": [int(value) for value in logits],
        "expected_class": label,
        "predicted_class": prediction,
        "classification": "PASS" if prediction == label else "FAIL",
        "golden_bytes_sha256": hashlib.sha256(output).hexdigest(),
    }
    record_path = args.golden.with_suffix(".json")
    record_path.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    if prediction != label:
        raise SystemExit("trained CNN selected sample does not classify correctly")
    print("NMA_TRAINED_CNN_GOLDEN_PASS class=%d logits=%s golden_sha256=%s" %
          (prediction, record["independent_integer_logits"], record["golden_bytes_sha256"]))


if __name__ == "__main__":
    main()
