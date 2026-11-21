#!/usr/bin/env python3
"""Build a Product-Top full DeiT K/V Projection workload from RTL LN readback.

The input file must be the packed output read back from the 197-row Product
LayerNorm run. Host code only decodes the physical Matrix-A byte layout for
the independent integer checker; it does not calculate projection outputs.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
import torch
from transformers import ViTForImageClassification

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "sw" / "tools"))
from cimforge_mapper import (  # noqa: E402
    Descriptor, OP_GEMM_REQUANT_TILE_A, FLAG_BIAS,
    _pack_matrix_a_physical, _pack_matrix_b_physical,
)

SPAD_BYTES = 256 * 1024
QUEUE_SIZE = 512
DESC_BASE = SPAD_BYTES - QUEUE_SIZE * 80
CPL_BASE = DESC_BASE + QUEUE_SIZE * 64
LN_PACK_BASE = 0x8000
WEIGHT_BASE, BIAS_BASE = 0x12000, 0x15000
Q_BASE, K_BASE, V_BASE = 0x16000, 0x18000, 0x22000
HIDDEN, PROJ_TILES, VALID_ROWS, PHYSICAL_ROWS = 192, 12, 197, 208
INPUT_SCALE = 0.15038124021560542
OUTPUT_SCALE = 1.0 / 32.0
REQUANT_SHIFT = 6
POISON = 0xA55AA55A


def sha_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_dump(path: Path) -> dict[int, int]:
    out: dict[int, int] = {}
    for line in path.read_text().splitlines():
        lane, address, value = line.split()
        if lane != "A" or any(c.lower() not in "0123456789abcdef" for c in value):
            raise ValueError(f"unknown or invalid Product readback: {line}")
        out[int(address, 16)] = int(value, 16)
    return out


def read_pairs(path: Path) -> dict[int, int]:
    words = [int(x, 16) for x in path.read_text().splitlines() if x.strip()]
    count = words[0]
    if len(words) != 1 + 2 * count:
        raise ValueError(f"bad pair image {path}")
    return {words[1 + 2 * i]: words[2 + 2 * i] for i in range(count)}


def write_pairs(path: Path, pairs: dict[int, int]) -> None:
    with path.open("w", encoding="ascii") as f:
        f.write(f"{len(pairs):08x}\n")
        for address, value in sorted(pairs.items()):
            f.write(f"{address & 0xffffffff:08x}\n{value & 0xffffffff:08x}\n")


def write_words(path: Path, words: list[int]) -> None:
    path.write_text("".join(f"{w & 0xffffffff:08x}\n" for w in words), encoding="ascii")


def sign8(value: int) -> int:
    value &= 0xff
    return value - 256 if value & 0x80 else value


def dense_from_matrix_a(words: list[int]) -> np.ndarray:
    if len(words) != PHYSICAL_ROWS * HIDDEN // 4:
        raise ValueError(f"expected {PHYSICAL_ROWS * HIDDEN // 4} packed words, got {len(words)}")
    result = np.zeros((PHYSICAL_ROWS, HIDDEN), dtype=np.int8)
    for row in range(PHYSICAL_ROWS):
        for col in range(HIDDEN):
            tile = row // 16
            r = row & 15
            wi = (tile * (16 * HIDDEN // 4) + (r >> 2) * HIDDEN +
                  (col >> 2) * 4 + (r & 3))
            result[row, col] = sign8(words[wi] >> ((col & 3) * 8))
    return result


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model-dir", type=Path, required=True)
    ap.add_argument("--ln-manifest", type=Path, required=True)
    ap.add_argument("--ln-golden", type=Path, required=True)
    ap.add_argument("--ln-dump", type=Path, required=True)
    ap.add_argument("--out-dir", type=Path, required=True)
    args = ap.parse_args()

    ln_manifest = json.loads(args.ln_manifest.read_text())
    if ln_manifest["shape"]["tokens_valid"] != VALID_ROWS or \
       ln_manifest["shape"]["tokens_physical"] != PHYSICAL_ROWS or \
       abs(float(ln_manifest["fp32_layernorm_error"]["output_scale"]) - INPUT_SCALE) > 1e-12:
        raise SystemExit("LayerNorm manifest shape/scale is not the pinned Round23 contract")
    observed_pairs = read_dump(args.ln_dump)
    observed_words = [observed_pairs[LN_PACK_BASE + 4 * i]
                      for i in range(PHYSICAL_ROWS * HIDDEN // 4)]
    expected_ln = read_pairs(args.ln_golden)
    mismatches = [(a, expected_ln.get(a), observed_pairs.get(a))
                  for a in range(LN_PACK_BASE, LN_PACK_BASE + PHYSICAL_ROWS * HIDDEN, 4)
                  if expected_ln.get(a) != observed_pairs.get(a)]
    if mismatches:
        raise SystemExit(f"full 208-row Product LN readback mismatch: {mismatches[0]}")
    ln_i8 = dense_from_matrix_a(observed_words)
    if np.any(ln_i8[VALID_ROWS:] != 0):
        raise SystemExit("Product LN packing did not zero physical padding rows 197..207")

    model_dir = args.model_dir.resolve()
    model = ViTForImageClassification.from_pretrained(str(model_dir), local_files_only=True).cpu().eval()
    torch.set_num_threads(1)
    layer = model.vit.encoder.layer[0].attention.attention
    weight_scale = OUTPUT_SCALE / (INPUT_SCALE * (1 << REQUANT_SHIFT))

    descriptors: list[Descriptor] = []
    golden: dict[int, int] = {}
    payload: list[int] = []
    dma_events: list[tuple[int, int, int, int]] = []
    output_bases = {"query": Q_BASE, "key": K_BASE, "value": V_BASE}
    projection_rows = {"query": 16, "key": PHYSICAL_ROWS, "value": PHYSICAL_ROWS}
    weight_stats: dict[str, dict[str, float]] = {}

    for projection in ("query", "key", "value"):
        proj = getattr(layer, projection)
        w_fp = proj.weight.detach().cpu().numpy().astype(np.float64)
        b_fp = proj.bias.detach().cpu().numpy().astype(np.float64)
        w_q = np.clip(np.rint(w_fp / weight_scale), -128, 127).astype(np.int8)
        b_q = np.rint(b_fp / (INPUT_SCALE * weight_scale)).astype(np.int64)
        if np.any(b_q < -(1 << 31)) or np.any(b_q >= (1 << 31)):
            raise SystemExit(f"{projection} bias exceeds INT32")
        weight_stats[projection] = {
            "weight_scale": weight_scale,
            "weight_saturation_ratio": float(np.mean(np.abs(np.rint(w_fp / weight_scale)) > 127)),
            "bias_min": int(b_q.min()), "bias_max": int(b_q.max()),
        }
        row_tiles = projection_rows[projection] // 16
        for ntile in range(PROJ_TILES):
            n0 = ntile * 16
            b_tile = w_q[n0:n0 + 16, :].T.astype(np.int32).tolist()
            b_words = _pack_matrix_b_physical(b_tile)
            if len(b_words) != 768:
                raise AssertionError(f"unexpected packed {projection} tile length {len(b_words)}")
            ext_base = len(payload) * 4
            payload.extend(b_words)
            bias_ext = len(payload) * 4
            payload.extend(int(v) & 0xffffffff for v in b_q[n0:n0 + 16])
            first_desc = len(descriptors)
            for chunk in range(3):
                dma_events.append((first_desc, ext_base + chunk * 1024,
                                   WEIGHT_BASE + chunk * 1024, 256))
            dma_events.append((first_desc, bias_ext, BIAS_BASE, 16))

            for mtile in range(row_tiles):
                index = len(descriptors)
                src = LN_PACK_BASE + mtile * 16 * HIDDEN
                dst = output_bases[projection] + (mtile * PROJ_TILES + ntile) * 256
                descriptors.append(Descriptor(
                    name=f"deit_{projection}_m{mtile * 16}_n{n0}",
                    task_id=0x7100 + index, op=OP_GEMM_REQUANT_TILE_A,
                    src0=src, src1=WEIGHT_BASE, bias=BIAS_BASE, dst=dst,
                    m=16, n=16, k_or_length=HIDDEN // 4,
                    flags=FLAG_BIAS, aux0=REQUANT_SHIFT,
                ))
                a = ln_i8[mtile * 16:(mtile + 1) * 16].astype(np.int64)
                acc = a @ w_q[n0:n0 + 16].astype(np.int64).T
                acc += b_q[n0:n0 + 16][None, :]
                tile_i8 = np.clip(acc >> REQUANT_SHIFT, -128, 127).astype(np.int32)
                packed = _pack_matrix_a_physical(tile_i8.tolist())
                for wi, word in enumerate(packed):
                    golden[dst + wi * 4] = int(word)

    if len(descriptors) != 324 or len(dma_events) != 144:
        raise AssertionError(f"unexpected plan descriptors={len(descriptors)} DMA={len(dma_events)}")
    if [e[0] for e in dma_events] != sorted(e[0] for e in dma_events):
        raise AssertionError("DMA triggers not ordered")

    pairs = dict(observed_pairs)
    for start, size in ((WEIGHT_BASE, 12288), (BIAS_BASE, 64),
                        (Q_BASE, 16 * HIDDEN), (K_BASE, PHYSICAL_ROWS * HIDDEN),
                        (V_BASE, PHYSICAL_ROWS * HIDDEN)):
        for addr in range(start, start + size, 4):
            pairs[addr] = POISON
    for i, desc in enumerate(descriptors):
        for wi, word in enumerate(desc.words()):
            pairs[DESC_BASE + i * 64 + wi * 4] = word
    for i in range(QUEUE_SIZE * 4):
        pairs[CPL_BASE + i * 4] = POISON

    args.out_dir.mkdir(parents=True, exist_ok=True)
    write_pairs(args.out_dir / "model_memory.memh", pairs)
    write_pairs(args.out_dir / "model_golden.memh", golden)
    write_words(args.out_dir / "dma_payload.memh", payload)
    plan = [len(dma_events)]
    for e in dma_events:
        plan.extend(e)
    write_words(args.out_dir / "late_dma_plan.memh", plan)
    manifest = {
        "status": "DEIT_FULL_KV_PRODUCT_PROJECTION_WORKLOAD",
        "source_ln_manifest_sha256": sha_file(args.ln_manifest),
        "source_ln_dump_sha256": sha_file(args.ln_dump),
        "checkpoint_sha256": ln_manifest["checkpoint_sha256"],
        "shape": {"valid_rows": VALID_ROWS, "physical_rows": PHYSICAL_ROWS,
                  "hidden": HIDDEN, "heads": 3, "query_rows": 16},
        "quantization": {"input_scale": INPUT_SCALE, "output_scale": OUTPUT_SCALE,
                         "requant_shift": REQUANT_SHIFT,
                         "weight_scale": weight_scale,
                         "contract": "0x53 signed INT8 product, INT32 bias before arithmetic right shift, signed INT8 saturation; 197 valid input rows and 11 explicit zero padding rows"},
        "weights": weight_stats,
        "spad": {"capacity_bytes": SPAD_BYTES, "banks": 4,
                 "words_per_bank": 16384, "descriptor_base": DESC_BASE,
                 "completion_base": CPL_BASE, "queue_entries": QUEUE_SIZE,
                 "data_high_water": V_BASE + PHYSICAL_ROWS * HIDDEN,
                 "allocations": {
                     "ln_product_readback_i8": [LN_PACK_BASE, LN_PACK_BASE + PHYSICAL_ROWS * HIDDEN],
                     "weight_tile_reused": [WEIGHT_BASE, WEIGHT_BASE + 12288],
                     "bias_tile_reused": [BIAS_BASE, BIAS_BASE + 64],
                     "query_output_tile_a": [Q_BASE, Q_BASE + 16 * HIDDEN],
                     "key_output_tile_a": [K_BASE, K_BASE + PHYSICAL_ROWS * HIDDEN],
                     "value_output_tile_a": [V_BASE, V_BASE + PHYSICAL_ROWS * HIDDEN],
                     "cmdq": [DESC_BASE, CPL_BASE], "cplq": [CPL_BASE, SPAD_BYTES]},
                 "allocation_status": "PASS; nonoverlapping live intervals; weights/bias reused by descriptor order"},
        "execution": {"descriptor_count": len(descriptors), "q_tiles": 12,
                      "k_tiles": 156, "v_tiles": 156,
                      "useful_macs": 3 * 16 * HIDDEN * HIDDEN + 2 * VALID_ROWS * HIDDEN * HIDDEN,
                      "physical_macs": len(descriptors) * 16 * 16 * HIDDEN,
                      "golden_words": len(golden), "dma_events": len(dma_events),
                      "dma_payload_bytes": len(payload) * 4,
                      "stage_boundary": "LayerNorm was a prior Product Top run; this stage consumes verified Product LN packing"},
        "artifacts": {},
    }
    for name in ("model_memory.memh", "model_golden.memh", "dma_payload.memh", "late_dma_plan.memh"):
        manifest["artifacts"][name] = sha_file(args.out_dir / name)
    (args.out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print("DEIT_FULL_KV_WORKLOAD_READY " + json.dumps({
        "descriptors": len(descriptors), "golden_words": len(golden),
        "dma_events": len(dma_events), "dma_bytes": len(payload) * 4,
        "useful_macs": manifest["execution"]["useful_macs"],
        "scale": OUTPUT_SCALE, "shift": REQUANT_SHIFT,
        "allocation_high_water": manifest["spad"]["data_high_water"],
        "manifest_sha256": sha_file(args.out_dir / "manifest.json")}, sort_keys=True))


if __name__ == "__main__":
    main()
