#!/usr/bin/env python3
"""Verify archived Round 27 staged DeiT Product-Top evidence and layout boundary."""
from __future__ import annotations

import csv
import gzip
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = ROOT / "benchmark/deit/round27/evidence"
OUT = ROOT / "benchmark/deit/round27"


def sha(path: Path) -> str:
    data = path.read_bytes()
    if path.suffix == ".gz":
        data = gzip.decompress(data)
    return hashlib.sha256(data).hexdigest()


def read_text(path: Path, errors: str = "strict") -> str:
    data = path.read_bytes()
    if path.suffix == ".gz":
        data = gzip.decompress(data)
    return data.decode(errors=errors)


def load_pairs(path: Path) -> dict[int, int]:
    rows = [line.strip() for line in path.read_text().splitlines() if line.strip()]
    count = int(rows[0], 16)
    if len(rows) != 1 + 2 * count:
        raise ValueError(f"{path}: malformed pair image")
    return {int(rows[1 + 2*i], 16): int(rows[2 + 2*i], 16)
            for i in range(count)}


def load_dump(path: Path) -> dict[int, int]:
    out: dict[int, int] = {}
    for line in path.read_text().splitlines():
        lane, address, value = line.split()
        if lane in ("A", "B") and re.fullmatch(r"[0-9a-fA-F]{1,8}", value):
            out[int(address, 16)] = int(value, 16)
    return out


def check_artifacts(directory: Path, manifest: dict) -> None:
    for name, expected in manifest["artifacts"].items():
        actual = sha(directory / "workload" / name)
        if actual != expected:
            raise SystemExit(f"artifact SHA mismatch: {directory / name}: {actual} != {expected}")


def model_pass_line(path: Path, expected_desc: int, expected_words: int) -> str:
    lines = read_text(path, errors="replace").splitlines()
    marker = next((line for line in lines if line.startswith("REPRESENTATIVE_MODEL_PASS ")), None)
    if marker is None:
        raise SystemExit(f"missing Product Top PASS marker in {path}")
    match_desc = re.search(r"\bdesc=(\d+)\b", marker)
    match_words = re.search(r"\bgolden_words=(\d+)\b", marker)
    if not match_desc or int(match_desc.group(1)) != expected_desc:
        raise SystemExit(f"descriptor count mismatch in {path}: {marker}")
    if not match_words or int(match_words.group(1)) != expected_words:
        raise SystemExit(f"Golden word count mismatch in {path}: {marker}")
    if any("Fatal:" in line or "Error:" in line for line in lines):
        raise SystemExit(f"fatal/error marker in {path}")
    return marker


qdir = EVIDENCE / "qkv197"
adir = EVIDENCE / "attention3_qblock"
qmanifest = json.loads((qdir / "manifest.json").read_text())
amanifest = json.loads((adir / "manifest.json").read_text())
check_artifacts(qdir, qmanifest)
check_artifacts(adir, amanifest)

qkv_golden = load_pairs(qdir / "workload" / "model_golden.memh")
qkv_dump = load_dump(qdir / "qkv_readback.txt")
if sha(qdir / "qkv_readback.txt") != amanifest["qkv_dump_sha256"]:
    raise SystemExit("attention input dump hash does not match archived QKV readback")
if sha(qdir / "workload" / "model_golden.memh") != amanifest["qkv_golden_sha256"]:
    raise SystemExit("attention QKV Golden hash does not match archived QKV Golden")

first_bad = None
checked = 0
for base in (0x16000, 0x20000, 0x2A000):
    for offset in range(208 * 192 // 4):
        address = base + 4 * offset
        expected = qkv_golden.get(address)
        actual = qkv_dump.get(address)
        if expected != actual:
            first_bad = (address, expected, actual)
            break
        checked += 1
    if first_bad:
        break
if first_bad:
    address, expected, actual = first_bad
    raise SystemExit(f"QKV readback Golden mismatch at 0x{address:08x}: {expected} != {actual}")
if checked != 29952:
    raise SystemExit(f"QKV checked count unexpected: {checked}")

qkv_pass = model_pass_line(qdir / "run.log.gz", 468, 29952)
attn_pass = model_pass_line(adir / "run.log.gz", 735, 25536)
attn_lines = read_text(adir / "run.log.gz", errors="replace").splitlines()
dma_line = next((line for line in attn_lines
                 if line.startswith("REPRESENTATIVE_LATE_DMA_SUMMARY ")), None)
if dma_line is None or "payload_bytes=82944" not in dma_line or "checked_words=20736" not in dma_line:
    raise SystemExit("Attention DMA evidence missing or unexpected")

# The consumer operands are not aliases of the producer Matrix-A tensors:
# the builder decodes Matrix-A, extracts heads, transposes K, packs V as Matrix-B,
# and stages those bytes through external DMA before a separate Top run.
layout = {
    "producer": {
        "format": "Matrix-A tiled INT8",
        "shape_physical": [208, 192],
        "valid_tokens": 197,
        "qkv_bases": {"Q": "0x16000", "K": "0x20000", "V": "0x2A000"},
        "physical_output_bytes": 3 * 208 * 192,
        "golden_words_verified": checked,
    },
    "attention_consumer": {
        "Q": {"format": "row-major signed INT8 per head", "shape": [16, 64], "heads": 3},
        "K": {"format": "feature-major signed INT8 [64,208] per head", "transform": "head slice + transpose"},
        "V": {"format": "Matrix-B tiled signed INT8 [208,64] per head", "transform": "head slice + Matrix-B pack"},
        "valid_keys": 197,
        "physical_keys": 208,
        "softmax_opcode": amanifest["softmax"]["opcode"],
        "padding_in_denominator": amanifest["softmax"]["physical_padding_in_denominator"],
        "dma_bytes_per_query_block": amanifest["dma_payload_bytes"],
    },
    "boundary": {
        "same_product_top_invocation": False,
        "host_qkv_readback_repacking": True,
        "host_intermediate_arithmetic": False,
        "attention_qk_softmax_pack_av_in_product_rtl": True,
        "continuous_deployment_gate": "PARTIAL",
    },
}

qkv_log = read_text(qdir / "run.log.gz", errors="replace")
attn_log = read_text(adir / "run.log.gz", errors="replace")
qkv_summary = next(line for line in qkv_log.splitlines()
                   if line.startswith("REPRESENTATIVE_MODEL_PASS "))
attn_summary = next(line for line in attn_log.splitlines()
                    if line.startswith("REPRESENTATIVE_MODEL_PASS "))
record = {
    "status": "STAGED_PRODUCT_TOP_PASS_CONTINUOUS_DEIT_PARTIAL",
    "source_sha": "19254b4e6a756ca8bf54ced5b287311214e5e99c",
    "run_seed": 20261117,
    "vcs": "V-2023.12-SP1_Full64",
    "model": "facebook/deit-tiny-patch16-224, non-distilled",
    "checkpoint_sha256": qmanifest["checkpoint_sha256"],
    "qkv": {
        "descriptors": 468,
        "golden_words": checked,
        "manifest": qmanifest,
        "model_pass_line": qkv_pass,
        "summary_line": qkv_summary,
        "compile_log_sha256": sha(qdir / "compile.log.gz"),
        "run_log_sha256": sha(qdir / "run.log.gz"),
        "readback_sha256": sha(qdir / "qkv_readback.txt"),
    },
    "attention_q0_15": {
        "descriptors": 735,
        "golden_words": 25536,
        "manifest": amanifest,
        "model_pass_line": attn_pass,
        "summary_line": attn_summary,
        "dma_summary_line": dma_line,
        "compile_log_sha256": sha(adir / "compile.log.gz"),
        "run_log_sha256": sha(adir / "run.log.gz"),
    },
    "layout_audit": layout,
    "limitations": [
        "QKV projection and attention are separate Product Top invocations.",
        "The attention workload is generated from QKV Top readback using Host Matrix-A unpack, head slicing, K transpose, and V Matrix-B packing.",
        "The 735-entry attention batch fits the configured 768-entry test queue, but cumulative QKV+attention work and 13 query blocks require runtime refill/retirement not qualified as one continuous model session.",
        "Both end_to_end_cycles counters exclude initial model-memory image loading (dma_preload_included=0); they are not complete host-to-host inference latency.",
        "Only Query rows 0..15 are executed by the three-head attention workload; the other 181 valid query rows, head merge, output projection, residual, LN2, FFN, and classification head are not run here.",
    ],
}
(OUT / "round27_staged_product_top_audit.json").write_text(
    json.dumps(record, indent=2, sort_keys=True) + "\n")

with (OUT / "round27_staged_product_top_metrics.csv").open("w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=[
        "stage", "status", "top_sessions", "descriptors", "golden_words",
        "useful_macs", "command_cycles", "end_to_end_cycles",
        "dma_payload_bytes", "late_dma_setup_cycles", "spad_read_bytes",
        "spad_write_bytes", "data_high_water_bytes", "measurement_note"])
    writer.writeheader()
    writer.writerow({
        "stage": "Full 197-row LN + QKV Projection",
        "status": "PRODUCT_TOP_PASS_STAGED",
        "top_sessions": 1,
        "descriptors": 468,
        "golden_words": 29952,
        "useful_macs": qmanifest["execution"]["useful_macs"],
        "command_cycles": 402889,
        "end_to_end_cycles": 1083365,
        "dma_payload_bytes": qmanifest["execution"]["dma_payload_bytes"],
        "late_dma_setup_cycles": 35058,
        "spad_read_bytes": 2905344,
        "spad_write_bytes": 119808,
        "data_high_water_bytes": qmanifest["spad"]["data_high_water"],
        "measurement_note": "LN is a prior Top run; this Top consumes checked LN output. Initial memory-image loading excluded.",
    })
    writer.writerow({
        "stage": "Three-head Attention Query Block 0 (16x197)",
        "status": "PRODUCT_TOP_PASS_STAGED",
        "top_sessions": 1,
        "descriptors": 735,
        "golden_words": 25536,
        "useful_macs": amanifest["useful_macs_qk_plus_av"],
        "command_cycles": 594012,
        "end_to_end_cycles": 1291324,
        "dma_payload_bytes": amanifest["dma_payload_bytes"],
        "late_dma_setup_cycles": 25074,
        "spad_read_bytes": 914304,
        "spad_write_bytes": 102144,
        "data_high_water_bytes": amanifest["spad"]["data_high_water"],
        "measurement_note": "Separate Top invocation; host-repacked QKV operands are DMA loaded. Initial memory-image loading excluded.",
    })

print(f"ROUND27_STAGED_AUDIT_PASS qkv_words={checked} qkv_desc=468 attention_desc=735 "
      f"attention_dma_bytes={amanifest['dma_payload_bytes']} continuous=PARTIAL")
