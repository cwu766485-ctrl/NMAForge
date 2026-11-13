#!/usr/bin/env python3
"""Normalize the existing passive Top profile into a research trace.

The checked-in Top monitor records accepted traffic and cycle phase without
touching DUT signals. It does not expose response owner/tag or reset epoch;
those columns are emitted as explicit NOT_CAPTURED values rather than inferred.
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


def read(path: Path):
    with path.open(newline="", encoding="ascii") as stream:
        return list(csv.DictReader(stream))


def bank_mask(address: int, bytes_: int, write: int) -> int:
    if bytes_ >= 16:
        return 0xF
    return 1 << ((address >> 2) & 3)


def emit(case: Path, out: Path) -> dict[str, int | str]:
    out.mkdir(parents=True, exist_ok=True)
    traffic = read(case / "profile_traffic.csv")
    axi = read(case / "profile_axi.csv")
    cycles = read(case / "profile_cycles.csv")
    trace = out / "accepted_trace.csv"
    with trace.open("w", newline="", encoding="ascii") as stream:
        fields = ["cycle", "source", "address", "bytes", "write", "bank_mask",
                  "response_cycle", "response_owner", "response_tag",
                  "outstanding_depth", "stall_reason", "epoch", "event"]
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        for row in traffic:
            address = int(row["address"], 16)
            bytes_ = int(row["bytes"])
            writer.writerow({
                "cycle": row["clock"], "source": row["engine"],
                "address": "0x%08x" % address, "bytes": bytes_,
                "write": row["write"], "bank_mask": bank_mask(address, bytes_, int(row["write"])),
                "response_cycle": "NOT_CAPTURED", "response_owner": "NOT_CAPTURED",
                "response_tag": "NOT_CAPTURED", "outstanding_depth": "NOT_CAPTURED",
                "stall_reason": "NOT_CAPTURED", "epoch": "NOT_CAPTURED",
                "event": "accepted_spad_access",
            })
        for row in axi:
            address = int(row["address"], 16)
            writer.writerow({
                "cycle": row["clock"], "source": "host_axi", "address": "0x%08x" % address,
                "bytes": 4, "write": 0, "bank_mask": bank_mask(address, 4, 0),
                "response_cycle": "NOT_CAPTURED", "response_owner": "NOT_CAPTURED",
                "response_tag": "NOT_CAPTURED", "outstanding_depth": "NOT_CAPTURED",
                "stall_reason": "NOT_CAPTURED", "epoch": "NOT_CAPTURED",
                "event": "host_spad_read_snapshot",
            })
    profile = out / "profile.csv"
    with profile.open("w", newline="", encoding="ascii") as stream:
        fields = ["metric", "value", "status"]
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerow({"metric": "accepted_scheduler_accesses", "value": len(traffic), "status": "MEASURED"})
        writer.writerow({"metric": "host_snapshot_reads", "value": len(axi), "status": "MEASURED"})
        writer.writerow({"metric": "cycle_samples", "value": len(cycles), "status": "MEASURED"})
        writer.writerow({"metric": "response_owner_tag", "value": "NOT_CAPTURED", "status": "GAP"})
        writer.writerow({"metric": "outstanding_depth", "value": "NOT_CAPTURED", "status": "GAP"})
        writer.writerow({"metric": "stall_reason", "value": "NOT_CAPTURED", "status": "GAP"})
        writer.writerow({"metric": "fault_reset_abort_epoch", "value": "NOT_CAPTURED", "status": "GAP"})
    return {"accepted": len(traffic), "host_reads": len(axi), "cycle_samples": len(cycles)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--replay", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    results = {}
    for mode in ("baseline", "packed"):
        results[mode] = emit(args.replay / mode, args.out / mode)
    print("SPAD_DATAFLOW_PROFILE_PASS", results)


if __name__ == "__main__":
    main()
