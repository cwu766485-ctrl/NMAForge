#!/usr/bin/env python3
"""Validate the candidate CNN static allocation and compact packing model."""

import csv
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CAPACITY = 128 * 1024
DATA = ROOT / "benchmark/research/phase0_1_compute_cluster"


def read_rows(path):
    with path.open(newline="", encoding="ascii") as stream:
        return list(csv.DictReader(stream))


def validate_intervals(rows, start_field, size_field, align_field=None):
    intervals = []
    for row in rows:
        start = int(row[start_field])
        size = int(row[size_field])
        alignment = int(row[align_field]) if align_field else 16
        assert start % alignment == 0, (row, alignment)
        assert 0 <= start < start + size <= CAPACITY, row
        intervals.append((start, start + size, row))
    intervals.sort(key=lambda item: item[0])
    for previous, current in zip(intervals, intervals[1:]):
        assert previous[1] <= current[0], (previous[2], current[2])
    return max(end for _, end, _ in intervals), sum(
        int(row[size_field]) for row in rows
    )


known = read_rows(DATA / "cnn_known_ranges.csv")
current_high, current_bytes = validate_intervals(
    known, "start", "bytes"
)
model = read_rows(DATA / "cnn_static_pack_model.csv")
packed_high, packed_bytes = validate_intervals(
    model, "packed_start", "bytes", "alignment"
)
modeled_current_high, modeled_bytes = validate_intervals(
    model, "current_start", "bytes", "alignment"
)

assert current_high == modeled_current_high == 107040
assert current_bytes == modeled_bytes == packed_bytes == 94176
assert packed_high == 94176
assert all(row["alias_allowed"] == "no" for row in model)
print(
    "CNN_STATIC_PACK_MODEL_PASS "
    f"capacity={CAPACITY} current_high={current_high} "
    f"packed_high={packed_high} bytes={packed_bytes} "
    f"saved={current_high - packed_high} temporal_alias=0"
)
