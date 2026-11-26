#!/usr/bin/env python3
"""Replay fixed trained Digits CNN samples through the production Top binary.

Workloads and physical-layout Golden files are generated independently for
each sample/mode. The simulator's completion and word-by-word Golden checks
are mandatory; a zero exit status alone is not treated as a pass.
"""

import argparse
import csv
import hashlib
import json
import re
import shlex
import subprocess
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
GENERATOR = ROOT / "benchmark/representative/generate_trained_3x3_cnn_workload.py"
VERIFIER = ROOT / "benchmark/representative/verify_trained_3x3_cnn_workload.py"
MODES = ("legacy", "first_fused", "both_fused_row_major")
PASS_RE = re.compile(r"^REPRESENTATIVE_MODEL_PASS (.+)$", re.MULTILINE)


def sha256(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def parse_marker(text):
    match = PASS_RE.search(text)
    if not match:
        raise RuntimeError("Top PASS marker missing")
    values = {}
    for token in match.group(1).split():
        key, value = token.split("=", 1)
        values[key] = value
    return values


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--simv", type=Path, required=True)
    parser.add_argument("--python", default=sys.executable)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--ranks", required=True,
                        help="comma-separated held-out test ranks")
    parser.add_argument("--modes", default=",".join(MODES))
    parser.add_argument("--seed", type=int, default=20261119)
    parser.add_argument("--timeout-seconds", type=int, default=120)
    parser.add_argument("--source-sha", required=True)
    parser.add_argument("--run-id", required=True)
    args = parser.parse_args()

    modes = tuple(item for item in args.modes.split(",") if item)
    ranks = tuple(int(item) for item in args.ranks.split(",") if item)
    if not ranks or not modes or any(mode not in MODES for mode in modes):
        parser.error("ranks and known modes are required")
    if len(set(ranks)) != len(ranks):
        parser.error("duplicate test ranks are not allowed")

    args.out_dir.mkdir(parents=True, exist_ok=True)
    model_sha = sha256(args.model)
    rows = []
    total_started = time.monotonic()
    for rank in ranks:
        for mode in modes:
            case_id = f"{args.run_id}-r{rank:03d}-{mode}"
            case_dir = args.out_dir / f"rank_{rank:03d}" / mode
            workload_dir = case_dir / "workload"
            case_dir.mkdir(parents=True, exist_ok=True)
            log_path = case_dir / "top.log"
            generate_cmd = [args.python, str(GENERATOR), "--model", str(args.model),
                            "--out-dir", str(workload_dir), "--fusion-mode", mode,
                            "--test-rank", str(rank)]
            generated = subprocess.run(generate_cmd, cwd=ROOT, text=True,
                                       stdout=subprocess.PIPE,
                                       stderr=subprocess.STDOUT, check=True)
            verify_cmd = [args.python, str(VERIFIER), "--workload-dir",
                          str(workload_dir)]
            verified = subprocess.run(verify_cmd, cwd=ROOT, text=True,
                                      stdout=subprocess.PIPE,
                                      stderr=subprocess.STDOUT, check=True)
            manifest_path = workload_dir / "manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            cmd = [str(args.simv), f"+ntb_random_seed={args.seed}",
                   "+AI_RANDOM_CASES=0", f"+AI_SEED={args.seed}",
                   "+ACLK_PERIOD_NS=4.000", "+AI_REPRESENTATIVE_MODEL",
                   f"+AI_REPRESENTATIVE_MEMORY={workload_dir / 'model_memory.memh'}",
                   f"+AI_REPRESENTATIVE_GOLDEN={workload_dir / 'model_golden.memh'}",
                   f"+AI_REPRESENTATIVE_DESC_BASE={manifest['descriptor_base']}",
                   f"+AI_REPRESENTATIVE_CPL_BASE={manifest['completion_base']}",
                   f"+AI_REPRESENTATIVE_DESC_COUNT={manifest['descriptor_count']}",
                   f"+AI_REPRESENTATIVE_USEFUL_MACS={manifest['useful_macs_per_inference']}",
                   "-l", str(log_path)]
            started = time.monotonic()
            launch = subprocess.run(cmd, cwd=ROOT, text=True,
                                    stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT,
                                    timeout=args.timeout_seconds)
            elapsed = time.monotonic() - started
            text = log_path.read_text(encoding="utf-8", errors="replace") \
                if log_path.exists() else launch.stdout
            if launch.returncode != 0:
                raise RuntimeError(f"{case_id}: simulator exit={launch.returncode}; see {log_path}")
            if re.search(r"\b(?:Fatal|ERROR|FAIL):", text, re.IGNORECASE):
                raise RuntimeError(f"{case_id}: simulator log contains failure; see {log_path}")
            marker = parse_marker(text)
            golden_words = int(marker["golden_words"])
            if golden_words != 20800:
                raise RuntimeError(f"{case_id}: unexpected Golden word count {golden_words}")
            if marker["desc"] != str(manifest["descriptor_count"]):
                raise RuntimeError(f"{case_id}: retired descriptor count mismatch")
            if int(marker["useful_macs"]) != manifest["useful_macs_per_inference"]:
                raise RuntimeError(f"{case_id}: useful-MAC mismatch")
            row = {
                "run_id": case_id,
                "status": "PASS_TOP_GOLDEN",
                "mode": mode,
                "test_rank": rank,
                "sample_index": manifest["sample_index"],
                "true_label": manifest["true_label"],
                "software_prediction": manifest["predicted_label"],
                "classification_correct": manifest["sample_classification"] == "PASS",
                "hardware_prediction_verified": manifest["predicted_label"],
                "prediction_evidence": "all 20800 Top-observed memory words, including class logits, matched the independent integer Golden; global-average/argmax is host postprocessing",
                "source_sha": args.source_sha,
                "model_sha256": model_sha,
                "dataset_sha256": manifest["dataset_sha256"],
                "deployed_weight_sha256": manifest["deployed_weight_sha256"],
                "seed": args.seed,
                "descriptor_count": int(marker["desc"]),
                "useful_macs": int(marker["useful_macs"]),
                "golden_words_checked": golden_words,
                "command_cycles": int(marker["command_cycles"]),
                "preload_axi_cycles": int(marker["preload_axi_cycles"]),
                "preloaded_spad_bytes": int(marker["preloaded_spad_bytes"]),
                "matrix_mac_cycles": int(marker["matrix_mac_cycles"]),
                "matrix_writeback_cycles": int(marker["matrix_writeback"]),
                "matrix_request_wait_cycles": int(marker["matrix_req_wait"]),
                "matrix_response_wait_cycles": int(marker["matrix_rsp_wait"]),
                "sfu_busy_cycles": int(marker["sfu_busy"]),
                "spad_read_bytes": int(marker["spad_read_bytes"]),
                "spad_write_bytes": int(marker["spad_write_bytes"]),
                "golden_sha256": sha256(workload_dir / "model_golden.memh"),
                "memory_sha256": sha256(workload_dir / "model_memory.memh"),
                "manifest_sha256": sha256(manifest_path),
                "top_log_sha256": sha256(log_path),
                "top_log_path_local": str(log_path),
                "elapsed_wall_seconds": round(elapsed, 4),
                "generator_command": shlex.join(generate_cmd),
                "verify_command": shlex.join(verify_cmd),
                "top_command": shlex.join(cmd),
                "generator_marker": generated.stdout.strip().splitlines()[-1],
                "verify_marker": verified.stdout.strip().splitlines()[-1],
            }
            rows.append(row)
            print(f"{case_id} PASS cycles={row['command_cycles']} golden={golden_words} elapsed={elapsed:.2f}s",
                  flush=True)

    payload = {
        "run_id": args.run_id,
        "status": "PASS" if all(row["status"] == "PASS_TOP_GOLDEN" for row in rows) else "FAIL",
        "source_sha": args.source_sha,
        "model_sha256": model_sha,
        "seed": args.seed,
        "modes": list(modes),
        "test_ranks": list(ranks),
        "top_runs": len(rows),
        "golden_word_checks": sum(row["golden_words_checked"] for row in rows),
        "accuracy_numerator_in_subset": sum(row["classification_correct"] for row in rows if row["mode"] == modes[0]),
        "accuracy_denominator_in_subset": len(ranks),
        "elapsed_wall_seconds": round(time.monotonic() - total_started, 3),
        "simulator_binary_sha256": sha256(args.simv),
        "simulator_path": str(args.simv.resolve()),
        "results": rows,
    }
    (args.out_dir / "cnn_top_sample_results.json").write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    fields = list(rows[0]) if rows else []
    with (args.out_dir / "cnn_top_sample_results.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(rows)
    print("ROUND20_CNN_TOP_MATRIX_PASS " + json.dumps({
        "run_id": args.run_id, "runs": len(rows),
        "golden_words": payload["golden_word_checks"],
        "elapsed_wall_seconds": payload["elapsed_wall_seconds"],
        "json": str(args.out_dir / "cnn_top_sample_results.json"),
        "csv": str(args.out_dir / "cnn_top_sample_results.csv")
    }, sort_keys=True))


if __name__ == "__main__":
    main()
