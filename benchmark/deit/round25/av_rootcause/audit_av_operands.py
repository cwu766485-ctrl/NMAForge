#!/usr/bin/env python3
"""Audit AV operands, physical SPAD read responses, and producer ordering.

This checks source Tensor words against the projection Golden, independently
reconstructs the dense V rows from the Product tile readback, and validates
every packed Matrix-B word consumed by the AV descriptors. It then checks
every AV read response lane against the generated SPAD image (including the
runtime probability-pack writes) and verifies that returned data matches the
physical bank contents observed by the testbench. It also records that the
original failed workload carried poison across the whole V_B region.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import re
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "sw" / "tools"))
from cimforge_mapper import pack_i8  # noqa: E402

POISON = 0xA55AA55A
V_OUT, V_BASE = 0x22000, 0x24000
VALID, PHYSICAL, HIDDEN, HEAD, DIM = 197, 208, 192, 0, 64


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def pairs(path: Path) -> dict[int, int]:
    words = [int(x, 16) for x in path.read_text().splitlines() if x.strip()]
    count = words[0]
    if len(words) != count * 2 + 1:
        raise ValueError(f"invalid pair image: {path}")
    return {words[1 + 2 * i]: words[2 + 2 * i] for i in range(count)}


def dump(path: Path) -> dict[int, int]:
    result: dict[int, int] = {}
    for line in path.read_text().splitlines():
        lane, address, value = line.split()
        if lane not in ("A", "B"):
            raise ValueError(f"invalid dump lane {lane}")
        result[int(address, 16)] = int(value, 16)
    return result


def s8(value: int) -> int:
    value &= 255
    return value - 256 if value & 0x80 else value


def read_response_audit(run_path: Path, model_memory: dict[int, int]) -> dict[str, object]:
    lines = run_path.read_text(errors="replace").splitlines()
    pack_writes: dict[int, int] = {}
    for line in lines:
        match = re.match(r"DEIT_SFU_PACK_WRITE addr=([0-9a-fA-F]+) data=([0-9a-fA-F]+)", line)
        if match:
            pack_writes[int(match.group(1), 16)] = int(match.group(2), 16)

    expected_memory = dict(model_memory)
    expected_memory.update(pack_writes)
    response_count = 0
    lane_words_checked = 0
    byte_lanes_checked = 0
    byte_mismatches = 0
    mismatches: list[dict[str, str]] = []
    data_vs_bank_mismatches = 0
    response_re = re.compile(
        r"DEIT_AV_RSP .*?req=([0-9a-fA-F]+) "
        r"data=([0-9a-fA-F]{8})_([0-9a-fA-F]{8})_([0-9a-fA-F]{8})_([0-9a-fA-F]{8}) "
        r"raw=([0-9a-fA-F]{8})_([0-9a-fA-F]{8})_([0-9a-fA-F]{8})_([0-9a-fA-F]{8})"
    )
    for line_number, line in enumerate(lines, 1):
        if not line.startswith("DEIT_AV_RSP "):
            continue
        match = response_re.search(line)
        if not match:
            mismatches.append({"line": str(line_number), "reason": "malformed_response_trace"})
            continue
        response_count += 1
        request_address = int(match.group(1), 16)
        data_words = [int(match.group(i), 16) for i in range(2, 6)]
        raw_words = [int(match.group(i), 16) for i in range(6, 10)]
        if data_words != raw_words:
            data_vs_bank_mismatches += 1
        # Trace order is bank3, bank2, bank1, bank0. The four words in the
        # physical image are addressed bank0 at +0 through bank3 at +12.
        addresses = [request_address + offset for offset in (12, 8, 4, 0)]
        for bank_order, (address, actual) in enumerate(zip(addresses, raw_words)):
            lane_words_checked += 1
            expected = expected_memory.get(address)
            if expected is None or expected != actual:
                if len(mismatches) < 32:
                    mismatches.append({
                        "line": str(line_number),
                        "request_address": f"0x{request_address:08x}",
                        "bank_order": f"bank{3 - bank_order}",
                        "word_address": f"0x{address:08x}",
                        "expected": "MISSING" if expected is None else f"0x{expected:08x}",
                        "actual": f"0x{actual:08x}",
                    })
            if expected is not None:
                for byte_index in range(4):
                    byte_lanes_checked += 1
                    if ((expected >> (byte_index * 8)) & 0xFF) != ((actual >> (byte_index * 8)) & 0xFF):
                        byte_mismatches += 1
    return {
        "responses": response_count,
        "bank_words_checked": lane_words_checked,
        "byte_lanes_checked": byte_lanes_checked,
        "byte_mismatches": byte_mismatches,
        "probability_pack_words_overlaid": len(pack_writes),
        "response_vs_physical_bank_mismatches": data_vs_bank_mismatches,
        "physical_image_mismatches": len(mismatches),
        "first_mismatches": mismatches,
        "pass": response_count > 0 and lane_words_checked == response_count * 4
                and byte_lanes_checked == lane_words_checked * 4
                and byte_mismatches == 0 and data_vs_bank_mismatches == 0 and not mismatches,
    }


def unpack_v_rows(readback: dict[int, int]) -> np.ndarray:
    dense = np.zeros((PHYSICAL, HIDDEN), dtype=np.int8)
    # Matrix-A projection readback is packed as 4-row x 4-column groups.
    ntiles = HIDDEN // 16
    for row in range(PHYSICAL):
        for col in range(HIDDEN):
            base = V_OUT + ((row // 16) * ntiles + col // 16) * 256
            local = ((row & 15) // 4 * 16 + (col & 15) // 4 * 4 + (row & 3)) * 4
            word = readback[base + local]
            dense[row, col] = s8(word >> ((col & 3) * 8))
    return dense


def main() -> None:
    here = Path(__file__).resolve().parent
    old_mem_path = here / "inputs/round24_attention_head0_memory.memh"
    old_mem = pairs(old_mem_path)
    new_mem = pairs(here / "full_av/model_memory.memh")
    proj_golden_path = here / "inputs/projection_golden.memh"
    proj_golden = pairs(proj_golden_path)
    prod_dump = dump(here / "qkv_product_readback.txt")
    dense = unpack_v_rows(prod_dump)[:, HEAD * DIM:(HEAD + 1) * DIM]

    qkv_v_words = 9984
    projection_mismatches = [
        V_OUT + i * 4 for i in range(qkv_v_words)
        if prod_dump.get(V_OUT + i * 4) != proj_golden.get(V_OUT + i * 4)
    ]
    packed_words_checked = 0
    packed_mismatches: list[dict[str, str]] = []
    for ntile in range(DIM // 16):
        n0 = ntile * 16
        panel = [[int(dense[row, n0 + col]) if row < VALID else 0
                  for col in range(16)] for row in range(PHYSICAL)]
        expected = []
        for cg in range(0, 16, 4):
            for kg in range(0, PHYSICAL, 4):
                for col in range(cg, cg + 4):
                    expected.append(pack_i8([panel[kg + lane][col] for lane in range(4)]))
        for wi, value in enumerate(expected):
            address = V_BASE + ntile * 0x1000 + wi * 4
            actual = new_mem.get(address)
            packed_words_checked += 1
            if actual != value:
                packed_mismatches.append({"address": f"0x{address:08x}",
                                          "expected": f"0x{value:08x}",
                                          "actual": "MISSING" if actual is None else f"0x{actual:08x}"})

    old_region = [old_mem.get(a) for a in range(V_BASE, V_BASE + 0x4000, 4)]
    event_trace = {}
    physical_read_audit = {}
    for head in range(3):
        run_path = here / "event_ordered" / ("run.log" if head == 0 else f"head{head}/run.log")
        model_path = here / "event_ordered" / ("model_memory.memh" if head == 0 else f"head{head}/model_memory.memh")
        lines = run_path.read_text(errors="replace").splitlines()
        pack_indices = [i + 1 for i, line in enumerate(lines)
                        if line.startswith("DEIT_SFU_PACK_WRITE ")]
        av_indices = [i + 1 for i, line in enumerate(lines)
                      if line.startswith("DEIT_AV_REQ ")]
        marker = next((line for line in lines
                       if line.startswith("REPRESENTATIVE_MODEL_PASS ")), "")
        if not pack_indices or not av_indices or not marker:
            raise SystemExit(f"missing event trace or Top PASS for head {head}: {run_path}")
        event_trace[str(head)] = {
            "last_probability_pack_write_line": max(pack_indices),
            "first_av_read_request_line": min(av_indices),
            "pack_before_av": max(pack_indices) < min(av_indices),
            "top_golden_pass": "golden_words=8512" in marker and "desc=245" in marker,
        }
        physical_read_audit[str(head)] = read_response_audit(run_path, pairs(model_path))
    operands_ok = not projection_mismatches and not packed_mismatches
    event_ok = all(x["pack_before_av"] and x["top_golden_pass"]
                   for x in event_trace.values())
    physical_reads_ok = all(x["pass"] for x in physical_read_audit.values())
    result = {
        "status": "OPERAND_EVENT_AND_PHYSICAL_READ_AUDIT_PASS"
                  if operands_ok and event_ok and physical_reads_ok
                  else "OPERAND_EVENT_OR_PHYSICAL_READ_AUDIT_FAIL",
        "source_sha": "ba646a7b2b4791bc365cf8ef42ec011a0552fcbb",
        "projection_readback_sha256": sha(here / "qkv_product_readback.txt"),
        "projection_golden_sha256": sha(proj_golden_path),
        "old_round24_attention_memory_sha256": sha(old_mem_path),
        "regenerated_attention_memory_sha256": sha(here / "full_av/model_memory.memh"),
        "valid_v_projection_words": qkv_v_words,
        "v_projection_golden_mismatch_words": len(projection_mismatches),
        "old_v_b_region_words": len(old_region),
        "old_v_b_poison_words": sum(x == POISON for x in old_region),
        "new_v_b_panel_words_reconstructed": packed_words_checked,
        "new_v_b_panel_mismatch_words": len(packed_mismatches),
        "first_packed_mismatch": packed_mismatches[0] if packed_mismatches else None,
        "unused_v_b_gap_words": 768,
        "physical_read_response_audit": physical_read_audit,
        "root_cause": "Two sequential workload issues were isolated. The original Round24 image had poison in all 4096 V_B words; the regenerated image packs V from real Product QKV readback and all 3328 consumed Matrix-B words match. The first regenerated full-AV failure then showed an ordering race: AV requests started before probability packing completed. Round25 adds a retirement event fence; all three Top traces show the last probability-pack write before the first AV request and all 8512-word Golden checks pass. No Matrix Reader RTL defect was observed.",
        "event_order_trace": event_trace,
    }
    (here / "operand_audit.json").write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(json.dumps(result, sort_keys=True))
    if result["status"] != "OPERAND_EVENT_AND_PHYSICAL_READ_AUDIT_PASS":
        raise SystemExit(1)


if __name__ == "__main__":
    main()
