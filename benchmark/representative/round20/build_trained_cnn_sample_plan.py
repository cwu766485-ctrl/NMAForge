#!/usr/bin/env python3
"""Choose a reproducible held-out subset covering every class and errors."""

import argparse
import csv
import hashlib
import json
from pathlib import Path

import numpy as np
from sklearn.datasets import load_digits


def predict_one(image8, weights1, weights2, shift1, shift2):
    image = image8.astype(np.float32) / 16.0
    image = np.repeat(np.repeat(image, 2, axis=0), 2, axis=1)
    coordinate = np.linspace(-1.0, 1.0, 16, dtype=np.float32)
    yy, xx = np.meshgrid(coordinate, coordinate, indexing="ij")
    planes = np.stack((image, np.ones_like(image), yy, xx), axis=-1)
    patches = np.stack([
        planes[y:y + 14, x:x + 14, :].reshape(196, 4)
        for y in range(3) for x in range(3)
    ], axis=2).transpose(0, 2, 1).reshape(196, 36)
    columns = np.zeros((208, 36), dtype=np.int8)
    columns[:196] = np.rint(patches * 127.0).clip(-127, 127).astype(np.int8)
    raw1 = columns.astype(np.int64) @ weights1.astype(np.int64)
    hidden = np.clip(np.maximum(raw1, 0) >> shift1, 0, 127).astype(np.int8)
    raw2 = hidden.astype(np.int64) @ weights2.astype(np.int64)
    logits = np.clip(raw2 >> shift2, -128, 127).astype(np.int8)
    return int(logits[:196, :10].astype(np.int32).mean(axis=0).argmax())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--correct-per-class", type=int, default=2)
    args = parser.parse_args()

    model_bytes = args.model.read_bytes()
    model = json.loads(model_bytes)
    dataset = load_digits()
    dataset_sha = hashlib.sha256(
        dataset.images.tobytes(order="C") +
        dataset.target.astype("<i8").tobytes()
    ).hexdigest()
    if dataset_sha != model["dataset_sha256"]:
        raise ValueError("dataset SHA does not match frozen model")
    test_indices = [int(i) for i in model["test_indices"]]
    labels = dataset.target.astype(int)
    weights1 = np.asarray(model["weights_int8"]["conv1_k36_n64"], dtype=np.int8)
    weights2 = np.asarray(model["weights_int8"]["conv2_k64_n16"], dtype=np.int8)
    shift1 = int(model["quantization"]["conv1_shift"])
    shift2 = int(model["quantization"]["conv2_shift"])
    rows = []
    for rank, index in enumerate(test_indices):
        predicted = predict_one(dataset.images[index], weights1, weights2,
                                shift1, shift2)
        rows.append({"test_rank": rank, "sample_index": index,
                     "true_label": int(labels[index]),
                     "software_prediction": predicted,
                     "correct": predicted == int(labels[index])})
    correct = [row for row in rows if row["correct"]]
    incorrect = [row for row in rows if not row["correct"]]
    if len(correct) != 346 or len(incorrect) != 14:
        raise ValueError("independent INT8 predictions disagree with frozen model summary: %d/%d correct" %
                         (len(correct), len(rows)))
    selected = {row["test_rank"]: row for row in incorrect}
    for label in range(10):
        candidates = [row for row in correct if row["true_label"] == label]
        if len(candidates) < args.correct_per_class:
            raise ValueError("not enough correct samples for class %d" % label)
        for row in candidates[:args.correct_per_class]:
            selected[row["test_rank"]] = row
    selected_rows = [selected[rank] for rank in sorted(selected)]
    if set(row["true_label"] for row in selected_rows) != set(range(10)):
        raise ValueError("selected subset does not cover all ten classes")
    if not any(row["correct"] for row in selected_rows) or not any(not row["correct"] for row in selected_rows):
        raise ValueError("selected subset must include correct and incorrect predictions")

    args.out_dir.mkdir(parents=True, exist_ok=True)
    plan = {
        "run_id": "R20-CNN-STRATIFIED-PLAN",
        "model_sha256": hashlib.sha256(model_bytes).hexdigest(),
        "deployed_weight_sha256": model["deployed_weight_sha256"],
        "dataset_sha256": dataset_sha,
        "heldout_size": len(rows),
        "heldout_correct": len(correct),
        "heldout_incorrect": len(incorrect),
        "heldout_accuracy": len(correct) / len(rows),
        "selection_rule": "all held-out INT8 misclassifications plus the first two correct samples per true class ordered by held-out test rank",
        "selected_count": len(selected_rows),
        "selected_correct": sum(row["correct"] for row in selected_rows),
        "selected_incorrect": sum(not row["correct"] for row in selected_rows),
        "selected_ranks": [row["test_rank"] for row in selected_rows],
        "selected_samples": selected_rows,
    }
    json_path = args.out_dir / "cnn_sample_plan.json"
    csv_path = args.out_dir / "cnn_sample_plan.csv"
    json_path.write_text(json.dumps(plan, indent=2, sort_keys=True) + "\n",
                         encoding="utf-8")
    with csv_path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(selected_rows[0]))
        writer.writeheader()
        writer.writerows(selected_rows)
    print("ROUND20_CNN_SAMPLE_PLAN_PASS samples=%d correct=%d incorrect=%d classes=10 model_sha256=%s plan_sha256=%s" %
          (len(selected_rows), plan["selected_correct"], plan["selected_incorrect"],
           plan["model_sha256"], hashlib.sha256(json_path.read_bytes()).hexdigest()))


if __name__ == "__main__":
    main()
