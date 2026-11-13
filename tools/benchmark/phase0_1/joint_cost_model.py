#!/usr/bin/env python3
"""Small offline cost-model prototype for the Phase 1.2 feasibility gate.

It uses only the first three shapes for calibration and reports the two larger
shapes as held-out. The model is intentionally conservative: it scores existing
controller configurations and does not invent an ABI or RTL feature.
"""

from __future__ import annotations

import argparse
import csv
import statistics
from pathlib import Path


CONFIGS = {
    "B0": ("d2_p0_c0", 2, 0, 0),
    "B1": ("d2_p0_c1", 2, 0, 1),
    "B2": ("d4_p1_c1", 4, 1, 1),
}


def load(path: Path):
    with path.open(newline="", encoding="ascii") as stream:
        return list(csv.DictReader(stream))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", nargs="+", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    rows = [row for path in args.csv for row in load(path)]
    shapes = [row["workload"] for row in rows]
    unique_shapes = list(dict.fromkeys(shapes))
    train_shapes = set(unique_shapes[:3])
    heldout_shapes = set(unique_shapes[3:])
    output = []
    for shape in unique_shapes:
        shape_rows = [row for row in rows if row["workload"] == shape]
        scores = {}
        measured = {}
        for label, (prefix, depth, prefetch, cache) in CONFIGS.items():
            cycles = [int(row[prefix + "_cycles"]) for row in shape_rows]
            macs = (int(shape.split("x")[0]) * int(shape.split("x")[1]) *
                    int(shape.split("x")[2]))
            # Calibration uses only training-shape cycles per useful MAC. This
            # is a deliberately minimal model, not a claimed final mapper.
            train = [r for r in rows if r["workload"] in train_shapes]
            ratio = statistics.mean(
                int(r[prefix + "_cycles"]) /
                (int(r["workload"].split("x")[0]) * int(r["workload"].split("x")[1]) * int(r["workload"].split("x")[2]))
                for r in train
            )
            scores[label] = macs * ratio
            measured[label] = (statistics.mean(cycles), depth, prefetch, cache)
        selected = min(scores, key=scores.get)
        for label, (prefix, depth, prefetch, cache) in CONFIGS.items():
            output.append({"shape": shape, "candidate": label,
                           "train_or_heldout": "TRAIN" if shape in train_shapes else "HELD_OUT",
                           "measured_cycles_mean": round(measured[label][0], 3),
                           "predicted_cycles": round(scores[label], 3),
                           "selected": "1" if label == selected else "0",
                           "depth": depth, "prefetch": prefetch, "a_cache": cache,
                           "status": "MEASURED_CONFIG"})
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="", encoding="ascii") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(output[0]))
        writer.writeheader()
        writer.writerows(output)
    selected_by_shape = {shape: next(row["candidate"] for row in output
                            if row["shape"] == shape and row["selected"] == "1")
                for shape in unique_shapes}
    print("JOINT_COST_MODEL_PASS train=%s held_out=%s selected=%s" %
          (sorted(train_shapes), sorted(heldout_shapes), selected_by_shape))


if __name__ == "__main__":
    main()
