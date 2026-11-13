#!/usr/bin/env python3
"""Run the unchanged trained CNN Golden at current and compact static layouts."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
MODEL = ROOT / "benchmark/representative/models/r19_trained_digits_3x3_cnn.json"
GEN = ROOT / "benchmark/representative/generate_trained_3x3_cnn_workload.py"
PAYLOAD = ROOT / "benchmark/representative/prepare_cnn_dma_payload.py"
CAPACITY = 128 * 1024
POISON = 0xA55AA55A

CURRENT = {
    "input": 0x00000, "w1": 0x02000, "raw1": 0x03000,
    "act1": 0x10000, "w2": 0x14000, "raw2": 0x15000,
    "output": 0x19000, "desc": 0x1A000, "cpl": 0x1A200,
}
PACKED = {
    "input": 0, "w1": 7488, "raw1": 9792, "act1": 63040,
    "w2": 76352, "raw2": 77376, "output": 90688, "desc": 94016,
    "cpl": 94144,
}
SIZES = {
    "input": 7488, "w1": 2304, "raw1": 53248, "act1": 13312,
    "w2": 1024, "raw2": 13312, "output": 3328, "desc": 128, "cpl": 32,
}


def parse_pairs(path: Path) -> dict[int, int]:
    lines = path.read_text(encoding="ascii").splitlines()
    count = int(lines[0], 16)
    assert len(lines) == 1 + count * 2
    return {int(lines[1 + i * 2], 16): int(lines[2 + i * 2], 16)
            for i in range(count)}


def write_pairs(path: Path, words: dict[int, int]) -> None:
    ordered = sorted(words.items())
    path.write_text("%x\n%s" % (
        len(ordered), "".join("%08x\n%08x\n" % pair for pair in ordered)),
        encoding="ascii")


def relocate_address(address: int, source: dict[str, int], target: dict[str, int]) -> int:
    for name, base in source.items():
        if base <= address < base + SIZES[name]:
            return target[name] + address - base
    raise ValueError("address 0x%08x is outside known CNN object ranges" % address)


def relocate_image(path: Path, out: Path, source: dict[str, int], target: dict[str, int]) -> None:
    src = parse_pairs(path)
    dst = {relocate_address(address, source, target): value for address, value in src.items()}
    # Descriptor pointer fields are ABI addresses and must follow their object.
    for index in range(2):
        base = target["desc"] + index * 64
        for offset in (4, 8, 16):
            old = dst[base + offset]
            if old in source.values():
                name = next(name for name, value in source.items() if value == old)
                dst[base + offset] = target[name]
    assert all(0 <= address < CAPACITY for address in dst)
    write_pairs(out, dst)


def relocate_golden(path: Path, out: Path, source: dict[str, int], target: dict[str, int]) -> None:
    src = parse_pairs(path)
    dst = {relocate_address(address, source, target): value for address, value in src.items()}
    write_pairs(out, dst)


def materialize_archived(source: Path, out: Path) -> None:
    if source.suffix == ".gz":
        with gzip.open(source, "rb") as src, out.open("wb") as dst:
            dst.write(src.read())
    else:
        out.write_bytes(source.read_bytes())


def run_case(simv: Path, out_root: Path, mode: str, python: Path, source_workload: Path) -> dict[str, object]:
    generated = out_root / "generated"
    generated.mkdir(parents=True, exist_ok=True)
    materialize_archived(source_workload / "model_memory.memh.gz", generated / "model_memory.memh")
    materialize_archived(source_workload / "model_golden.memh.gz", generated / "model_golden.memh")
    source = CURRENT
    target = CURRENT if mode == "baseline" else PACKED
    image = out_root / "model_memory.memh"
    golden = out_root / "model_golden.memh"
    relocate_image(generated / "model_memory.memh", image, source, target)
    relocate_golden(generated / "model_golden.memh", golden, source, target)
    subprocess.run([str(python), str(PAYLOAD), "--memory-image", str(image),
                    "--out-dir", str(out_root)], check=True, cwd=ROOT,
                   stdout=(out_root / "payload.log").open("w"), stderr=subprocess.STDOUT)
    plus = [str(simv), "+ntb_random_seed=20261119", "+AI_RANDOM_CASES=0",
            "+AI_SEED=20261119", "+ACLK_PERIOD_NS=4", "+AI_REPRESENTATIVE_MODEL",
            "+AI_REPRESENTATIVE_DMA_PRELOAD",
            "+AI_REPRESENTATIVE_DMA_PAYLOAD=" + str(out_root / "dma_payload.memh"),
            "+AI_REPRESENTATIVE_DMA_PLAN=" + str(out_root / "dma_plan.memh"),
            "+AI_REPRESENTATIVE_MEMORY=" + str(image),
            "+AI_REPRESENTATIVE_GOLDEN=" + str(golden),
            "+AI_REPRESENTATIVE_DESC_BASE=%d" % target["desc"],
            "+AI_REPRESENTATIVE_CPL_BASE=%d" % target["cpl"],
            "+AI_REPRESENTATIVE_DESC_COUNT=2", "+AI_REPRESENTATIVE_USEFUL_MACS=570164",
            "+AI_REPRESENTATIVE_DUMP_FILE=" + str(out_root / "output.txt"),
            "+AI_REPRESENTATIVE_DUMP_A_BASE=%d" % target["output"],
            "+AI_REPRESENTATIVE_DUMP_A_WORDS=832", "+AI_REPRESENTATIVE_DUMP_B_BASE=0",
            "+AI_REPRESENTATIVE_DUMP_B_WORDS=0", "+STAGE_A_PROFILE=" + str(out_root / "profile"),
            "+ROUND2_PROFILE"]
    with (out_root / "command.log").open("w", encoding="ascii") as stream:
        json.dump(plus, stream, indent=2)
        stream.write("\n")
    with (out_root / "top.log").open("w") as log:
        subprocess.run(plus, check=True, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    text = (out_root / "top.log").read_text()
    assert "REPRESENTATIVE_DMA_PRELOAD_PASS" in text
    assert "REPRESENTATIVE_MODEL_PASS" in text
    summary = json.loads((out_root / "dma_payload_summary.json").read_text())
    match = re.search(r"REPRESENTATIVE_MODEL_PASS .*?command_cycles=(\d+).*?spad_read_bytes=(\d+) spad_write_bytes=(\d+)", text)
    assert match, text[-2000:]
    return {"mode": mode, "command_cycles": int(match.group(1)),
            "spad_read_bytes": int(match.group(2)), "spad_write_bytes": int(match.group(3)),
            "high_water_exclusive": max(parse_pairs(image)) + 4,
            "payload_bytes": summary["payload_bytes"],
            "golden_sha256": hashlib.sha256(golden.read_bytes()).hexdigest(),
            "status": "PASS"}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--simv", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--python", type=Path, default=Path(sys.executable))
    parser.add_argument("--source-workload", type=Path,
                        default=ROOT / "benchmark/research/phase1/cnn/both_fused_row_major")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    results = [run_case(args.simv, args.out / mode, mode, args.python, args.source_workload)
               for mode in ("baseline", "packed")]
    (args.out / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    print("A1_RTL_REPLAY_PASS " + json.dumps(results, sort_keys=True))


if __name__ == "__main__":
    main()
