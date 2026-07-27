#!/usr/bin/env python
"""Parse a VCS simv.vdb code coverage database into a compact text summary.

This is a lightweight fallback when `urg` is unavailable or unstable. It reads
the XML data files under simv.vdb/snps/coverage/db/testdata/test and reports
hit/total percentages from the VCS instance_data bit vectors.
"""

from __future__ import print_function

import gzip
import glob
import os
import re
import sys


DEFAULT_MAIN_INSTANCES = [
    "ahb_sramc_svtb_top.u_vec_accel_top",
    "ahb_sramc_svtb_top.u_vec_accel_top.regs_u",
    "ahb_sramc_svtb_top.u_vec_accel_top.ahb_sram_if_u",
    "ahb_sramc_svtb_top.u_vec_accel_top.core_u",
    "ahb_sramc_svtb_top.u_vec_accel_top.sram_core_u",
]


def read_text(path):
    data = gzip.open(path, "rb").read()
    try:
        return data.decode("utf-8", "replace")
    except AttributeError:
        return data


def parse_instance_values(path):
    text = read_text(path)
    values = {}
    pattern = r'<instance_data\s+name="([^"]+)"\s+value="([^"]*)"'
    for name, value in re.findall(pattern, text):
        values[name] = value
    return values


def merge_instance_values(value_sets):
    merged = {}
    for values in value_sets:
        for name, value in values.items():
            if name not in merged:
                merged[name] = value
                continue

            old = merged[name]
            width = min(len(old), len(value))
            merged[name] = "".join(
                "1" if old[index] == "1" or value[index] == "1" else "0"
                for index in range(width)
            )
    return merged


def values_to_rows(values):
    rows = []
    for name, value in values.items():
        hit = value.count("1")
        total = value.count("0") + value.count("1")
        pct = (100.0 * hit / total) if total else 100.0
        rows.append((name, hit, total, pct))
    return rows


def print_group(metric, label, rows):
    hit = sum(row[1] for row in rows)
    total = sum(row[2] for row in rows)
    pct = (100.0 * hit / total) if total else 100.0
    print("%-8s %-10s %6.2f%% (%d/%d)" % (metric.upper(), label, pct, hit, total))


def main():
    vdb = sys.argv[1] if len(sys.argv) > 1 else "simv.vdb"
    testdata_dir = os.path.join(vdb, "snps", "coverage", "db", "testdata")
    data_dirs = sorted(
        path for path in glob.glob(os.path.join(testdata_dir, "*"))
        if os.path.isdir(path)
    )
    metrics = ["line", "branch", "cond", "fsm", "tgl"]

    print("Coverage runs: %d" % len(data_dirs))
    print("")

    for metric in metrics:
        paths = [
            os.path.join(data_dir, metric + ".verilog.data.xml")
            for data_dir in data_dirs
        ]
        paths = [path for path in paths if os.path.exists(path)]
        if not paths:
            continue

        values = merge_instance_values([parse_instance_values(path) for path in paths])
        rows = values_to_rows(values)
        main_rows = [row for row in rows if row[0] in DEFAULT_MAIN_INSTANCES]

        print_group(metric, "ALL", rows)
        print_group(metric, "MAIN", main_rows)
        for name, hit, total, pct in main_rows:
            print("  %-72s %6.2f%% (%d/%d)" % (name, pct, hit, total))
        print("")


if __name__ == "__main__":
    main()
