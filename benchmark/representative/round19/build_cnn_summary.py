#!/usr/bin/env python3
"""Build machine-readable Round 19 Top CNN results from manifests and VCS logs."""

import csv
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "round19"
MODEL = ROOT / "models/r19_trained_digits_3x3_cnn.json"
RUNS = {
    "legacy": Path("/tmp/r19_cnn_legacy"),
    "first_fused": Path("/tmp/r19_cnn_first_fused"),
    "both_fused_row_major": Path("/tmp/r19_cnn_both_fused_row_major"),
}
LOGS = {
    "legacy": Path("/tmp/r19_cnn_top/legacy.log"),
    "first_fused": Path("/tmp/r19_cnn_top/first_fused.log"),
    "both_fused_row_major": Path("/tmp/r19_cnn_top/both_fused_row_major.log"),
}
SOURCE_SHA = "7e38a224bfa9558b8b9145c0a9dd81e2786f202a"
RUN_IDS = {
    "legacy": "R19-CNN-LEGACY-20261109",
    "first_fused": "R19-CNN-FIRST-FUSED-20261109",
    "both_fused_row_major": "R19-CNN-BOTH-FUSED-ROW-20261109",
}


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    model_bytes = MODEL.read_bytes()
    model = json.loads(model_bytes)
    rows = []
    for mode, run_dir in RUNS.items():
        manifest = json.loads((run_dir / "manifest.json").read_text())
        log_path = LOGS[mode]
        log = log_path.read_text()
        matches = re.findall(r"^REPRESENTATIVE_MODEL_PASS (.*)$", log, re.M)
        if len(matches) != 1:
            raise RuntimeError(f"expected one Top PASS line in {log_path}")
        metrics = dict(re.findall(r"([a-z_]+)=([^ ]+)", matches[0]))
        if int(metrics["golden_words"]) != 20800:
            raise RuntimeError(f"unexpected Top Golden count in {mode}")
        desc_count = int(manifest["descriptor_count"])
        if int(metrics["desc"]) != desc_count:
            raise RuntimeError(f"Top descriptor count mismatch in {mode}")
        command = int(metrics["command_cycles"])
        preload = int(metrics["preload_axi_cycles"])
        row = {
            "run_id": RUN_IDS[mode],
            "mode": mode,
            "source_sha": SOURCE_SHA,
            "model": model["model"],
            "model_sha256": sha256(MODEL),
            "dataset_sha256": model["dataset_sha256"],
            "deployed_weight_sha256": model["deployed_weight_sha256"],
            "seed": model["seed"],
            "test_sample_index": manifest["sample_index"],
            "true_label": manifest["true_label"],
            "predicted_label": manifest["predicted_label"],
            "sample_classification": manifest["sample_classification"],
            "quantized_heldout_accuracy_pct": round(100 * manifest["quantized_heldout_accuracy"], 4),
            "useful_macs": int(metrics["useful_macs"]),
            "descriptor_count": desc_count,
            "golden_words_checked": int(metrics["golden_words"]),
            "golden": "PASS",
            "command_cycles": command,
            "host_preload_axi_cycles": preload,
            "preload_plus_command_cycles": preload + command,
            "host_preloaded_spad_bytes_including_poison_and_control": int(metrics["preloaded_spad_bytes"]),
            "valid_im2col_bytes": manifest["valid_im2col_bytes"],
            "padded_im2col_bytes": manifest["host_im2col_payload_bytes"],
            "im2col_generation_seconds_host_measured": manifest["host_im2col_seconds"],
            "integer_golden_seconds_host_measured": manifest["host_integer_golden_seconds"],
            "matrix_mac_active_cycles": int(metrics["matrix_mac_cycles"]),
            "array_utilization_pct_from_top_counter": float(metrics["array_utilization_pct"]),
            "useful_mac_per_command_cycle": round(int(metrics["useful_macs"]) / command, 4),
            "spad_read_bytes": int(metrics["spad_read_bytes"]),
            "spad_write_bytes": int(metrics["spad_write_bytes"]),
            "sfu_busy_cycles": int(metrics["sfu_busy"]),
            "matrix_writeback_cycles": int(metrics["matrix_writeback"]),
            "matrix_request_wait_cycles": int(metrics["matrix_req_wait"]),
            "matrix_response_wait_cycles": int(metrics["matrix_rsp_wait"]),
            "preload_plus_command_scope": "Top behavioral SPAD AXI preload plus CMDQ completion; excludes software training/preprocess wall time and final host Golden readback",
            "preload_is_dma": False,
            "log_path_local": str(log_path),
            "log_sha256": sha256(log_path),
            "memory_image_sha256": manifest["memory_image_sha256"],
            "golden_file_sha256": manifest["golden_file_sha256"],
        }
        rows.append(row)

    json_path = OUT / "cnn_results.json"
    json_path.write_text(json.dumps({
        "run_family": "NMAFORGE-ROUND19-TRAINED-CNN",
        "rtl_source_sha": SOURCE_SHA,
        "model_sha256": sha256(MODEL),
        "model_accuracy_scope": "software INT8 held-out evaluation over 360 samples; Top RTL executed held-out sample index 42 only",
        "runs": rows,
    }, indent=2, sort_keys=True) + "\n")
    csv_path = OUT / "cnn_results.csv"
    with csv_path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    print(f"wrote {json_path} and {csv_path}; rows={len(rows)}")


if __name__ == "__main__":
    main()
