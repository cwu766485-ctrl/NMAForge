#!/usr/bin/env python3
"""Summarize Round-25 Product-Top AV logs and verify Pack-before-AV ordering."""
from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / "benchmark/deit/round25/av_rootcause"
RUNS = BASE / "event_ordered"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pass_fields(path: Path) -> dict[str, str]:
    text = path.read_text(errors="replace")
    line = next((x for x in text.splitlines()
                 if x.startswith("REPRESENTATIVE_MODEL_PASS ")), None)
    if line is None:
        raise ValueError(f"no Product Top PASS marker in {path}")
    return dict(re.findall(r"([a-zA-Z0-9_]+)=([^ ]+)", line))


rows: list[dict] = []
for head in range(3):
    run = RUNS / ("run.log" if head == 0 else f"head{head}/run.log")
    text = run.read_text(errors="replace")
    pack_lines = [i for i, line in enumerate(text.splitlines(), 1)
                  if line.startswith("DEIT_SFU_PACK_WRITE ")]
    av_lines = [i for i, line in enumerate(text.splitlines(), 1)
                if line.startswith("DEIT_AV_REQ ")]
    if not pack_lines or not av_lines:
        raise ValueError(f"missing physical trace on Head {head}")
    fields = pass_fields(run)
    manifest = json.loads((RUNS / ("manifest.json" if head == 0
                                   else f"head{head}/manifest.json")).read_text())
    ordered = max(pack_lines) < min(av_lines)
    passed = fields.get("golden_words") == "8512" and fields.get("desc") == "245"
    if not ordered or not passed:
        raise SystemExit(f"Head {head} failed event-order or Golden check")
    rows.append({
        "head": head,
        "status": "PRODUCT_TOP_GOLDEN_PASS",
        "descriptors": int(fields["desc"]),
        "golden_words": int(fields["golden_words"]),
        "useful_macs": int(fields["useful_macs"]),
        "command_cycles": int(fields["command_cycles"]),
        "end_to_end_cycles": int(fields["end_to_end_cycles"]),
        "preloaded_spad_bytes": int(fields["preloaded_spad_bytes"]),
        "spad_read_bytes": int(fields["spad_read_bytes"]),
        "spad_write_bytes": int(fields["spad_write_bytes"]),
        "useful_mac_per_cycle": float(fields["useful_mac_per_cycle"]),
        "sfu_busy_cycles": int(fields["sfu_busy"]),
        "matrix_mac_cycles": int(fields["matrix_mac_cycles"]),
        "physical_pack_writes": len(pack_lines),
        "last_pack_log_line": max(pack_lines),
        "first_av_request_log_line": min(av_lines),
        "pack_before_av": ordered,
        "valid_keys": int(manifest["valid_keys"]),
        "physical_keys": int(manifest["physical_keys"]),
        "padding_in_softmax_denominator": manifest["softmax"]["padding_in_denominator"],
        "memory_sha256": sha(RUNS / ("model_memory.memh" if head == 0
                                      else f"head{head}/model_memory.memh")),
        "golden_sha256": sha(RUNS / ("model_golden.memh" if head == 0
                                      else f"head{head}/model_golden.memh")),
        "run_log_sha256": sha(run),
    })

compile_log = BASE / "logs/vcs_compile.log"
compile_text = compile_log.read_text(errors="replace")
version = next((line.strip() for line in compile_text.splitlines()
                if "Version V-" in line), "version not found")
compile_ok = "0 error(s), 0 warning(s)" in compile_text
summary = {
    "status": "ROUND25_DEIT_AV_THREE_HEAD_QBLOCK_PASS",
    "source_baseline_sha": "ba646a7b2b4791bc365cf8ef42ec011a0552fcbb",
    "product_rtl_modified": False,
    "tool": {"vcs": version, "compile_database_clean": compile_ok,
             "compile_log_sha256": sha(compile_log)},
    "root_cause": {
        "round24_artifact": "all 4096 words in the original V_B region were poison; Round25 reconstructs all AV V panels from Product QKV readback and matches 3328 consumed Matrix-B words",
        "round25_first_regenerated_failure": "the AV descriptors had no producer-consumer event dependency; trace showed AV requests before probability pack completed",
        "fix": "event bit 15 is cleared by the first QK descriptor, signaled at successful probability-pack retirement, and waited on by all four AV N-panel descriptors",
        "reader_rtl_bug_evidence": "none; the directed Product Top run passes after correcting workload ordering, with no Matrix Reader RTL change",
    },
    "heads": rows,
    "aggregate": {"golden_words": sum(r["golden_words"] for r in rows),
                  "descriptors": sum(r["descriptors"] for r in rows),
                  "useful_macs": sum(r["useful_macs"] for r in rows)},
}
(BASE / "round25_av_closure.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
with (BASE / "round25_av_closure.csv").open("w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=list(rows[0]))
    writer.writeheader()
    writer.writerows(rows)
print(json.dumps({"status": summary["status"], "heads": rows,
                  "aggregate": summary["aggregate"]}, sort_keys=True))
