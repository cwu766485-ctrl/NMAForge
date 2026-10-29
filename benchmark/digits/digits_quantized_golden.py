#!/usr/bin/env python3
"""Independent integer golden for the trained digits MLP artifact."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from sklearn.datasets import load_digits
from sklearn.model_selection import train_test_split


SEED = 20261029


def load_test_vectors():
    labels = load_digits().target.astype(np.int64)
    ids = np.arange(labels.size)
    _train_ids, test_ids = train_test_split(
        ids, test_size=0.2, random_state=SEED, stratify=labels
    )
    return test_ids, labels[test_ids]


def integer_infer(images_q: np.ndarray, model: np.lib.npyio.NpzFile):
    # Keep this path independent of the training/calibration implementation:
    # explicit Python integer dot products mirror the Matrix/SFU descriptor work.
    w1 = model["w1_int8"].astype(np.int64)
    b1 = model["b1_acc_int32"].astype(np.int64)
    w2 = model["w2_int8"].astype(np.int64)
    b2 = model["b2_acc_int32"].astype(np.int64)
    shift = int(model["hidden_shift"])
    hidden_rows = []
    logits_rows = []
    for image in images_q.astype(np.int64):
        acc1 = [sum(int(image[k]) * int(w1[k, j]) for k in range(64)) + int(b1[j])
                for j in range(64)]
        hidden = [min(127, max(0, value >> shift)) for value in acc1]
        acc2 = [sum(hidden[k] * int(w2[k, j]) for k in range(64)) + int(b2[j])
                for j in range(12)]
        hidden_rows.append(hidden)
        logits_rows.append(acc2)
    return np.asarray(hidden_rows, dtype=np.int8), np.asarray(logits_rows, dtype=np.int32)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, default=Path(__file__).resolve().parent /
                        "artifacts/digits_mlp_int8.npz")
    parser.add_argument("--rtl-logits", type=Path)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    with np.load(args.model) as model:
        test_ids, labels = load_test_vectors()
        if not np.array_equal(test_ids.astype(np.int32), model["test_indices"]):
            raise SystemExit("test split does not match the trained model artifact")
        images_q = model["test_images_q"]
        hidden, logits = integer_infer(images_q, model)
        if not np.array_equal(hidden, model["test_hidden_i8"]):
            raise SystemExit("independent hidden-layer golden disagrees with training export")
        if not np.array_equal(logits, model["test_logits_i32"]):
            raise SystemExit("independent logits golden disagrees with training export")
        rtl_compared = False
        if args.rtl_logits:
            rtl = np.loadtxt(args.rtl_logits, delimiter=",", dtype=np.int32)
            rtl = np.atleast_2d(rtl)
            valid = labels.size
            if rtl.shape != (valid, 12):
                raise SystemExit(f"RTL output has shape {rtl.shape}, expected {(valid, 12)}")
            if not np.array_equal(rtl, logits[:valid]):
                mismatch = np.argwhere(rtl != logits[:valid])[0]
                raise SystemExit(
                    f"RTL mismatch at sample={mismatch[0]} class={mismatch[1]} "
                    f"rtl={rtl[tuple(mismatch)]} golden={logits[tuple(mismatch)]}"
                )
            rtl_compared = True
        report = {
            "dataset": "sklearn.datasets.load_digits",
            "seed": SEED,
            "test_samples": int(labels.size),
            "independent_integer_golden": "PASS",
            "rtl_output_compared": rtl_compared,
            "int8_accuracy": float(np.mean(np.argmax(logits[:, :10], axis=1) == labels)),
            "golden_logit_sha256": __import__("hashlib").sha256(logits.tobytes()).hexdigest(),
        }
        data = json.dumps(report, indent=2, sort_keys=True) + "\n"
        print(data, end="")
        if args.out:
            args.out.parent.mkdir(parents=True, exist_ok=True)
            args.out.write_text(data, encoding="utf-8")


if __name__ == "__main__":
    main()
