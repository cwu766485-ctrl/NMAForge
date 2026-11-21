#!/usr/bin/env python3
"""Verify staged incremental H16 Top observations and emit machine-readable results."""
from __future__ import annotations
import argparse
import csv
import hashlib
import json
import re
import subprocess
from collections import Counter
from pathlib import Path


def read_pairs(path: Path) -> dict[int, int]:
    words = [int(line, 16) for line in path.read_text().splitlines()]
    if not words or len(words) != 1 + 2 * words[0]:
        raise ValueError(f"malformed pair file: {path}")
    pairs = dict(zip(words[1::2], words[2::2]))
    if len(pairs) != words[0]:
        raise ValueError(f"duplicate address in {path}")
    return pairs


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-dir", type=Path, required=True)
    parser.add_argument("--source-sha", default=None,
                        help="exact committed source SHA for this reproduced run")
    args = parser.parse_args()
    run_dir = args.run_dir
    workload = run_dir / "workload"
    manifest = json.loads((workload / "manifest.json").read_text())
    log = (run_dir / "run.log").read_text()
    if "INCREMENTAL_DECODE_PASS " not in log:
        raise SystemExit("Top log lacks incremental decode PASS")
    stage_lines = re.findall(
        r"INCREMENTAL_H16_STAGE_PASS stage=(\S+) index=(\d+) desc=(\d+) "
        r"golden_words=(\d+) useful_macs=(\d+) cycles=(\d+) matrix_mac=(\d+) "
        r"matrix_wait=(\d+) matrix_rsp_wait=(\d+) matrix_writeback=(\d+) "
        r"matrix_other=(\d+) sfu=(\d+) kv=(\d+) dma_overlap=(\d+) "
        r"spad_read_bytes=(\d+) spad_write_bytes=(\d+) mac_per_cycle=([\d.]+) "
        r"array_utilization_pct=([\d.]+) observed=(\S+)", log)
    if len(stage_lines) != 5:
        raise SystemExit(f"expected five stage PASS records, found {len(stage_lines)}")
    qkv_ops = Counter(
        descriptor["opcode"]
        for stage in manifest["stages"][1:]
        for descriptor in stage["descriptor_contract"]
        if any(f"_{projection}_h" in descriptor["name"]
               for projection in ("q", "k", "v"))
    )
    projection_policy = manifest.get("projection_policy")
    if projection_policy is None:
        projection_policy = "gemv_qkv" if qkv_ops.get(0x52, 0) else "gemm"
    results = []
    for stage, line in zip(manifest["stages"], stage_lines):
        (name, index, desc_count, golden_words, useful_macs, cycles, matrix_mac,
         matrix_wait, rsp_wait, writeback, matrix_other, sfu, kv, dma_overlap,
         read_bytes, write_bytes, mac_cycle, utilization, observed_path) = line
        index = int(index)
        if name != stage["name"] or index != stage["index"]:
            raise SystemExit(f"stage order mismatch at {stage['name']}: {line}")
        golden_path = workload / f"stage_{index}_{name}_golden.memh"
        observed = Path(observed_path)
        if not observed.is_absolute():
            observed = run_dir / observed
        expected_pairs, observed_pairs = read_pairs(golden_path), read_pairs(observed)
        if expected_pairs != observed_pairs:
            mismatch = next((addr for addr in expected_pairs
                             if expected_pairs[addr] != observed_pairs.get(addr)), None)
            raise SystemExit(f"observed mismatch stage={name} address={mismatch}")
        if len(expected_pairs) != int(golden_words):
            raise SystemExit(f"Golden word count mismatch stage={name}")
        cache_raw = bytearray()
        for head in range(2):
            for cache_name in ("key_cache", "value_cache"):
                cache_base = manifest["tensors"][cache_name]["address"] + head * 64
                for word_index in range(16):
                    address = cache_base + word_index * 4
                    if address not in observed_pairs:
                        raise SystemExit(
                            f"observed KV word missing stage={name} address={address:#x}"
                        )
                    cache_raw.extend(observed_pairs[address].to_bytes(4, "little"))
        cache_sha = hashlib.sha256(cache_raw).hexdigest()
        if cache_sha != stage["kv_after_sha256"]:
            raise SystemExit(f"observed KV hash mismatch stage={name}")
        results.append({
            "stage": name, "index": index, "descriptor_count": int(desc_count),
            "golden_words": int(golden_words), "useful_macs": int(useful_macs),
            "cycles": int(cycles), "matrix_mac_cycles": int(matrix_mac),
            "matrix_request_wait_cycles": int(matrix_wait),
            "matrix_response_wait_cycles": int(rsp_wait),
            "matrix_writeback_cycles": int(writeback),
            "matrix_other_cycles": int(matrix_other), "sfu_cycles": int(sfu),
            "kv_cycles": int(kv), "dma_busy_overlap_cycles": int(dma_overlap),
            "spad_read_bytes": int(read_bytes), "spad_write_bytes": int(write_bytes),
            "useful_mac_per_cycle": float(mac_cycle),
            "array_utilization_pct": float(utilization),
            "expected_tensor_sha256": sha256(golden_path),
            "observed_tensor_sha256": sha256(observed),
            "kv_before_sha256": stage["kv_before_sha256"],
            "expected_kv_after_sha256": stage["kv_after_sha256"],
            "observed_kv_after_sha256": cache_sha,
        })
    if any(r["expected_tensor_sha256"] != r["observed_tensor_sha256"] for r in results):
        raise SystemExit("Expected/observed tensor-file hashes differ")
    output = {
        "status": "INCREMENTAL_DECODE_PASS",
        "model_sha256": manifest["model_sha256"],
        "source_sha": args.source_sha or subprocess.check_output(
            ["git", "rev-parse", "HEAD"],
            cwd=Path(__file__).resolve().parents[2], text=True).strip(),
        "run_id": run_dir.name,
        "seed": manifest["seed"],
        "host_supplied_tokens": manifest["incremental_decode_token_ids_host_supplied"],
        "projection_policy": projection_policy,
        "qkv_projection_descriptor_counts": {
            f"0x{opcode:02x}": count for opcode, count in sorted(qkv_ops.items())
        },
        "stages": results,
        "decode_steps": results[1:],
        "average_decode_cycles": sum(r["cycles"] for r in results[1:]) / 4,
        "snapshot_replay_is_not_counted": True,
        "tiny_npu_reference_sha256": manifest["tiny_npu_reference_sha256"],
    }
    (run_dir / "results.json").write_text(json.dumps(output, indent=2) + "\n")
    with (run_dir / "results.csv").open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(results[0]))
        writer.writeheader()
        writer.writerows(results)
    print("H16_INCREMENTAL_OBSERVATION_VERIFY_PASS "
          f"stages={len(results)} decode_steps=4 "
          f"average_decode_cycles={output['average_decode_cycles']:.2f} "
          f"results={run_dir / 'results.json'}")


if __name__ == "__main__":
    main()
