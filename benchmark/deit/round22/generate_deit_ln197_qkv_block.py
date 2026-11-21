#!/usr/bin/env python3
"""Build a staged Product-Top workload for DeiT LN(197) -> Q/K/V tile.

The embedding tensor must be a readback dump from a successful Product-Top
patch-embedding run.  This tool checks every dumped Matrix-A word against the
independent embedding Golden before using it as the next run's input image.
The two stages are separate Top sessions; this is not a single-session layer
handoff claim.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
import torch
from transformers import AutoImageProcessor, ViTForImageClassification

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "sw" / "tools"))
sys.path.insert(0, str(ROOT / "dv" / "block" / "compute" / "matrix" / "ref"))
from cimforge_mapper import (  # noqa: E402
    Descriptor, OP_GEMM, OP_LAYERNORM, OP_REQUANT, FLAG_BIAS,
    FLAG_PACK_I8, FLAG_PACK_I8_TILE_A, _pack_matrix_a_physical, _pack_matrix_b_physical,
)
from ai_a3_reference import layernorm_q15  # noqa: E402

SPAD_BYTES = 256 * 1024
QUEUE_SIZE = 512
DESC_BASE = SPAD_BYTES - QUEUE_SIZE * 80
CPL_BASE = DESC_BASE + QUEUE_SIZE * 64
POISON = 0xA55AA55A
INPUT_BASE = 0x2BF00
GAMMA_BASE, BETA_BASE = 0x1000, 0x1300
LN_TEMP_BASE, LN_PACK_BASE = 0x2000, 0x8000
WEIGHT_BASE, BIAS_BASE = 0x12000, 0x15000
Q_BASE, K_BASE, V_BASE = 0x16000, 0x19000, 0x1C000
PHYSICAL_ROWS, LN_OUTPUT_ROWS, HIDDEN, PROJ_TILES = 208, 200, 192, 12


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha_file(path: Path) -> str:
    return sha(path.read_bytes())


def read_pairs(path: Path) -> dict[int, int]:
    words = [int(line, 16) for line in path.read_text().splitlines() if line.strip()]
    count = words[0]
    if len(words) != 1 + 2 * count:
        raise ValueError(f"malformed pair image {path}: count={count}, words={len(words)}")
    return {words[1 + 2 * i]: words[2 + 2 * i] for i in range(count)}


def write_pairs(path: Path, pairs: dict[int, int]) -> None:
    with path.open("w", encoding="ascii") as f:
        f.write(f"{len(pairs):08x}\n")
        for address, value in sorted(pairs.items()):
            f.write(f"{address & 0xffffffff:08x}\n{value & 0xffffffff:08x}\n")


def write_words(path: Path, words: list[int]) -> None:
    path.write_text("".join(f"{value & 0xffffffff:08x}\n" for value in words), encoding="ascii")


def read_dump(path: Path) -> dict[int, int]:
    values: dict[int, int] = {}
    for line in path.read_text().splitlines():
        kind, addr, value = line.split()
        if kind != "A":
            raise ValueError(f"unexpected dump lane {kind!r}")
        address, data = int(addr, 16), int(value, 16)
        if address in values:
            raise ValueError(f"duplicate dump address 0x{address:x}")
        values[address] = data
    return values


def sign8(v: int) -> int:
    v &= 0xff
    return v - 256 if v & 0x80 else v


def get_packed_a_byte(words: list[int], row: int, col: int) -> int:
    tile = (row // 16) * PROJ_TILES + (col // 16)
    r, c = row & 15, col & 15
    word_index = tile * 64 + ((r >> 2) * 16) + ((c >> 2) * 4) + (r & 3)
    return sign8(words[word_index] >> ((c & 3) * 8))



def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model-dir", type=Path, required=True)
    ap.add_argument("--base-manifest", type=Path, required=True)
    ap.add_argument("--base-golden", type=Path, required=True)
    ap.add_argument("--embedding-dump", type=Path, required=True)
    ap.add_argument("--out-dir", type=Path, required=True)
    args = ap.parse_args()

    base = json.loads(args.base_manifest.read_text())
    out_alloc = base["spad"]["allocations"]["embedding_output_matrix_a_i8"]
    if int(out_alloc[0]) != INPUT_BASE or int(out_alloc[1]) - int(out_alloc[0]) != 39936:
        raise SystemExit(f"unexpected embedding allocation {out_alloc}")
    expected_embed = {a: v for a, v in read_pairs(args.base_golden).items()
                      if INPUT_BASE <= a < INPUT_BASE + 39936}
    observed_embed = read_dump(args.embedding_dump)
    if len(expected_embed) != 9984 or len(observed_embed) != 9984:
        raise SystemExit(f"embedding dump/golden count mismatch: {len(observed_embed)}/{len(expected_embed)}")
    mismatch = next(((a, expected_embed.get(a), observed_embed.get(a))
                     for a in sorted(expected_embed)
                     if observed_embed.get(a) != expected_embed[a]), None)
    if mismatch:
        raise SystemExit(f"Product embedding dump mismatch addr/expected/actual={mismatch}")
    if base["checkpoint_sha256"] != {
        "config.json": "e8786a68c993c04b8721c4d379e4f9de6a9564fba5987704dbf8696d53b7972d",
        "preprocessor_config.json": "90d1ae427c27d2b9dcb01f6a62ba96aa67aac2de1697c59cd212055b5035c4a2",
        "pytorch_model.bin": "e1a51b0c81ff812e079d2189352747947879fee56429e4480064a6695cb34b2c",
    }:
        raise SystemExit("base workload is not the pinned official DeiT checkpoint")

    model_dir = args.model_dir.resolve()
    model = ViTForImageClassification.from_pretrained(str(model_dir), local_files_only=True).cpu().eval()
    processor = AutoImageProcessor.from_pretrained(str(model_dir), local_files_only=True)
    torch.set_num_threads(1)
    seed = int(base["seed"])
    image = np.random.default_rng(seed).integers(0, 256, size=(224, 224, 3), dtype=np.uint8)
    pixels = processor(images=image, return_tensors="pt")["pixel_values"]
    with torch.no_grad():
        fp_tokens = model.vit.embeddings(pixels)[0].cpu().numpy().astype(np.float64)
        fp_ln = model.vit.encoder.layer[0].layernorm_before(
            model.vit.embeddings(pixels)[0]).cpu().numpy().astype(np.float64)
    output_scale = float(base["quantization"]["output_scale"])
    ln = model.vit.encoder.layer[0].layernorm_before
    gamma_q15 = np.rint(ln.weight.detach().cpu().numpy().astype(np.float64) /
                        output_scale * 32768.0).astype(np.int64)
    beta_i32 = np.rint(ln.bias.detach().cpu().numpy().astype(np.float64) /
                       output_scale).astype(np.int64)
    if np.any(gamma_q15 < -(1 << 31)) or np.any(gamma_q15 >= (1 << 31)) or \
       np.any(beta_i32 < -(1 << 31)) or np.any(beta_i32 >= (1 << 31)):
        raise SystemExit("LayerNorm affine value exceeds signed INT32 contract")

    embed_words = [observed_embed[INPUT_BASE + 4 * i] for i in range(9984)]
    ln_int = np.zeros((PHYSICAL_ROWS, HIDDEN), dtype=np.int32)
    embed_dense = np.zeros((PHYSICAL_ROWS, HIDDEN), dtype=np.int8)
    for row in range(PHYSICAL_ROWS):
        for col in range(HIDDEN):
            embed_dense[row, col] = get_packed_a_byte(embed_words, row, col)
    # LayerNorm only accepts real token rows 0..196.  The final 8-row
    # Matrix-A pack is padded with explicit zeros below; padded rows must not
    # be sent through the LayerNorm descriptor validator.
    for row in range(197):
        ln_int[row] = np.asarray(layernorm_q15(
            embed_dense[row].astype(int).tolist(), gamma_q15.tolist(), beta_i32.tolist(), epsilon=1),
            dtype=np.int32)
    ln_fp_error = ln_int[:197].astype(np.float64) * output_scale - fp_ln[:197]

    descriptors: list[Descriptor] = []
    golden: dict[int, int] = {}
    pack_descriptor_indices: list[int] = []
    for tile in range(13):
        row0 = tile * 16
        for lane in range(16):
            row = row0 + lane
            if row >= 197:
                break
            index = len(descriptors)
            descriptors.append(Descriptor(
                name=f"deit_ln_token_{row}", task_id=0x7100 + index,
                op=OP_LAYERNORM, src0=INPUT_BASE, src1=GAMMA_BASE,
                bias=BETA_BASE, dst=LN_TEMP_BASE + lane * HIDDEN * 4,
                k_or_length=HIDDEN, m=PHYSICAL_ROWS, n=HIDDEN,
                flags=FLAG_BIAS | 0x40, aux0=1, src0_stride=row,
            ))
        index = len(descriptors)
        pack_descriptor_indices.append(index)
        pack_base = LN_PACK_BASE + tile * 16 * HIDDEN
        pack_rows = 8 if tile == 12 else 16
        descriptors.append(Descriptor(
            name=f"deit_ln_pack_tile_{tile}", task_id=0x7100 + index,
            op=OP_REQUANT, src0=LN_TEMP_BASE, src1=0, dst=pack_base,
            m=pack_rows, n=HIDDEN, k_or_length=pack_rows * HIDDEN,
            flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A, shift=0, aux0=1,
        ))
        packed_values = np.clip(ln_int[row0:row0 + pack_rows], -128, 127).astype(np.int8)
        packed_words = _pack_matrix_a_physical(
            packed_values.astype(np.int32).tolist(), physical_rows=pack_rows)
        for word_index, word in enumerate(packed_words):
            golden[pack_base + word_index * 4] = int(word)

    # QKV operates on the Product LayerNorm output.  Each descriptor computes
    # one 16x16 output-channel tile for the first 16 token rows; weights and
    # biases are staged through fenced AXI DMA immediately before consumption.
    projections = ("query", "key", "value")
    qkv_bases = {"query": Q_BASE, "key": K_BASE, "value": V_BASE}
    # The first two DMA events are the LN affine vectors.  Their source
    # offsets are 0 and HIDDEN*4 bytes, so reserve those payload words before
    # appending any QKV matrix tiles.  Keeping the arrays only in model_memory
    # would make the real late-DMA path copy packed QKV bytes into gamma/beta.
    ext_words: list[int] = [int(v) & 0xffffffff for v in gamma_q15]
    ext_words.extend(int(v) & 0xffffffff for v in beta_i32)
    dma_events: list[tuple[int, int, int, int]] = [
        (0, 0, GAMMA_BASE, HIDDEN), (0, HIDDEN * 4, BETA_BASE, HIDDEN),
    ]
    proj_mats: dict[str, tuple[np.ndarray, np.ndarray, float]] = {}
    for name in projections:
        layer = model.vit.encoder.layer[0].attention.attention
        proj = getattr(layer, name)
        weight_fp = proj.weight.detach().cpu().numpy().astype(np.float64)  # [out,in]
        bias_fp = proj.bias.detach().cpu().numpy().astype(np.float64)
        wscale = max(float(np.max(np.abs(weight_fp))) / 127.0, 2.0 ** -20)
        wq = np.clip(np.rint(weight_fp / wscale), -128, 127).astype(np.int8)
        bq = np.rint(bias_fp / (output_scale * wscale)).astype(np.int64)
        if np.any(bq < -(1 << 31)) or np.any(bq >= (1 << 31)):
            raise SystemExit(f"{name} bias exceeds signed INT32")
        proj_mats[name] = (wq, bq, wscale)

    # Keep 16-row first-query-block projection outputs in separate tile-major
    # areas so every Q/K/V output word is checked after the Top run.
    for name in projections:
        wq, bq, _ = proj_mats[name]
        out_base = qkv_bases[name]
        for ntile in range(PROJ_TILES):
            index = len(descriptors)
            n0 = ntile * 16
            b_tile = wq[n0:n0 + 16, :].T.astype(np.int32).tolist()  # [K,N]
            packed_b = _pack_matrix_b_physical(b_tile)
            if len(packed_b) != 768:
                raise AssertionError(f"unexpected {name} B tile words={len(packed_b)}")
            ext_base = len(ext_words) * 4
            ext_words.extend(packed_b)
            for chunk in range(3):
                dma_events.append((index, ext_base + chunk * 256 * 4,
                                   WEIGHT_BASE + chunk * 256 * 4, 256))
            bias_ext = len(ext_words) * 4
            ext_words.extend(int(v) & 0xffffffff for v in bq[n0:n0 + 16])
            dma_events.append((index, bias_ext, BIAS_BASE, 16))
            descriptors.append(Descriptor(
                name=f"deit_{name}_m0_n{n0}", task_id=0x7100 + index,
                op=OP_GEMM, src0=LN_PACK_BASE, src1=WEIGHT_BASE,
                bias=BIAS_BASE, dst=out_base + ntile * 16 * 16 * 4,
                m=16, n=16, k_or_length=HIDDEN // 4,
                flags=FLAG_BIAS, aux0=1,
            ))
            act = np.clip(ln_int[:16], -128, 127).astype(np.int64)
            expected = act @ wq[n0:n0 + 16, :].astype(np.int64).T
            expected += bq[n0:n0 + 16][None, :]
            for r in range(16):
                for c in range(16):
                    golden[out_base + ntile * 1024 + (r * 16 + c) * 4] = int(expected[r, c])

    # LN_TEMP is a reused tile buffer. The final tile has only five valid
    # rows, but earlier tiles have overwritten its three padding lanes by the
    # time the final pack runs. Clear those INT32 lanes through the real DMA
    # path immediately before the final 8-row pack, rather than relying on the
    # initial SPAD image to survive prior commands.
    pad_words = (LN_OUTPUT_ROWS - 197) * HIDDEN
    pad_dma_ext = len(ext_words) * 4
    ext_words.extend([0] * pad_words)
    pad_dma_desc = pack_descriptor_indices[-1]
    pad_dma_events = []
    for pad_row in range(LN_OUTPUT_ROWS - 197):
        pad_dma_events.append((pad_dma_desc,
                               pad_dma_ext + pad_row * HIDDEN * 4,
                               LN_TEMP_BASE + (5 + pad_row) * HIDDEN * 4,
                               HIDDEN))
    # Late-DMA events must be nondecreasing by trigger descriptor.  The
    # padding clear is triggered at descriptor 209, just before the final
    # pack; QKV weight events start at descriptor 210.
    dma_events[2:2] = pad_dma_events

    if len(descriptors) != 246:
        raise AssertionError(f"descriptor plan expected 246, got {len(descriptors)}")
    if len(dma_events) != 149:
        raise AssertionError(f"DMA plan expected 149, got {len(dma_events)}")
    ln_rows = [int(desc.name.rsplit("_", 1)[1]) for desc in descriptors
               if desc.name.startswith("deit_ln_token_")]
    if ln_rows != list(range(197)):
        raise AssertionError(f"LayerNorm must cover exactly valid rows 0..196, got {ln_rows[-4:]}")
    if any(desc.name == "deit_ln_token_197" for desc in descriptors):
        raise AssertionError("invalid padded LayerNorm row 197 was generated")
    final_pack = descriptors[pack_descriptor_indices[-1]]
    if (final_pack.name != "deit_ln_pack_tile_12" or final_pack.m != 8 or
            final_pack.n != HIDDEN):
        raise AssertionError(f"unexpected final partial pack descriptor: {final_pack}")
    if len(pad_dma_events) != 3 or any(event[0] != pack_descriptor_indices[-1] or
                                      event[3] != HIDDEN for event in pad_dma_events):
        raise AssertionError(f"final pack requires three 192-word zero-fill DMAs: {pad_dma_events}")
    if [event[0] for event in dma_events] != sorted(event[0] for event in dma_events):
        raise AssertionError("late-DMA plan triggers are not monotonic")
    if any(event[3] > 256 for event in dma_events):
        raise AssertionError("late-DMA event exceeds the Top testbench 256-word limit")
    for row in range(197, LN_OUTPUT_ROWS):
        if np.any(ln_int[row] != 0):
            raise AssertionError(f"padded packed output row {row} is not zero")
    desc_bytes = len(descriptors) * 64
    if DESC_BASE + desc_bytes > CPL_BASE:
        raise SystemExit("descriptor ring allocation overlaps completion ring")

    pairs: dict[int, int] = dict(observed_embed)
    for alloc_base, size in ((GAMMA_BASE, 768), (BETA_BASE, 768),
                       (LN_TEMP_BASE, 16 * HIDDEN * 4),
                       (LN_PACK_BASE, LN_OUTPUT_ROWS * HIDDEN),
                       (WEIGHT_BASE, 12288), (BIAS_BASE, 64),
                       (Q_BASE, 16 * HIDDEN * 4), (K_BASE, 16 * HIDDEN * 4),
                       (V_BASE, 16 * HIDDEN * 4)):
        for address in range(alloc_base, alloc_base + size, 4):
            pairs[address] = POISON
    for index, desc in enumerate(descriptors):
        for wi, word in enumerate(desc.words()):
            pairs[DESC_BASE + index * 64 + wi * 4] = word
    for i in range(QUEUE_SIZE * 4):
        pairs[CPL_BASE + i * 4] = POISON
    # Seed deterministic zeroes in the SPAD image for rows 197..199.  Since
    # LN_TEMP is reused, the late-DMA events above are still required to clear
    # these lanes after earlier tiles have overwritten them.  Padding is not a
    # computed model tensor and no invalid LayerNorm descriptor is issued.
    for row in range(197, LN_OUTPUT_ROWS):
        row_lane = row - (12 * 16)
        for col in range(HIDDEN):
            pairs[LN_TEMP_BASE + (row_lane * HIDDEN + col) * 4] = 0

    args.out_dir.mkdir(parents=True, exist_ok=True)
    write_pairs(args.out_dir / "model_memory.memh", pairs)
    write_pairs(args.out_dir / "model_golden.memh", golden)
    write_words(args.out_dir / "dma_payload.memh", ext_words)
    plan = [len(dma_events)]
    for event in dma_events:
        plan.extend(event)
    write_words(args.out_dir / "late_dma_plan.memh", plan)

    allocations = {
        "prior_product_embedding": [INPUT_BASE, INPUT_BASE + 39936],
        "ln_gamma": [GAMMA_BASE, GAMMA_BASE + 768],
        "ln_beta": [BETA_BASE, BETA_BASE + 768],
        "ln_row_tile_int32_reused": [LN_TEMP_BASE, LN_TEMP_BASE + 16 * HIDDEN * 4],
        "ln_matrix_a_int8": [LN_PACK_BASE, LN_PACK_BASE + LN_OUTPUT_ROWS * HIDDEN],
        "weight_tile_reused": [WEIGHT_BASE, WEIGHT_BASE + 12288],
        "bias_tile_reused": [BIAS_BASE, BIAS_BASE + 64],
        "qkv_query_tile_major_i32": [Q_BASE, Q_BASE + 16 * HIDDEN * 4],
        "qkv_key_tile_major_i32": [K_BASE, K_BASE + 16 * HIDDEN * 4],
        "qkv_value_tile_major_i32": [V_BASE, V_BASE + 16 * HIDDEN * 4],
        "cmdq": [DESC_BASE, CPL_BASE], "cplq": [CPL_BASE, SPAD_BYTES],
    }
    for i, (a0, a1) in enumerate((allocations[x] for x in list(allocations)[:-2])):
        for b0, b1 in list((allocations[x] for x in list(allocations)[:-2]))[i + 1:]:
            if max(a0, b0) < min(a1, b1):
                raise AssertionError(f"overlapping live allocations [{a0},{a1}) and [{b0},{b1})")

    # FP32 comparison is reported separately from the exact Product integer Golden.
    ln_mae = float(np.mean(np.abs(ln_fp_error)))
    ln_rmse = float(np.sqrt(np.mean(ln_fp_error ** 2)))
    manifest = {
        "status": "DEIT_LN197_QKV_FIRST_QUERY_BLOCK_WORKLOAD",
        "execution_boundary": "staged_top_sessions; embedding is a prior Product Top SPAD readback, verified against its Golden",
        "checkpoint_sha256": base["checkpoint_sha256"], "seed": seed,
        "embedding_run_dump_sha256": sha_file(args.embedding_dump),
        "embedding_expected_golden_sha256": sha_file(args.base_golden),
        "embedding_words_verified": len(expected_embed),
        "shape": {"tokens_valid": 197, "tokens_physical": 208, "hidden": 192,
                  "heads": 3, "query_rows_executed": 16, "projection_channels": 192},
        "numeric_contract": {
            "layernorm": "opcode 0x38; epsilon=1; truncating mean; floor variance; integer sqrt/Q30 reciprocal; gamma Q15 and beta INT32 scaled by embedding output_scale",
            "layernorm_pack": "opcode 0x36 shift=0, signed INT8 saturation, Matrix-A physical packing",
            "qkv": "opcode 0x30; per-projection symmetric INT8 weights round-even; activation scale=embedding output_scale; bias rounded to accumulator scale; INT32 output",
            "weight_scales": {k: v[2] for k, v in proj_mats.items()},
        },
        "fp32_layernorm_error": {"mae": ln_mae, "rmse": ln_rmse,
                                  "max_abs": float(np.max(np.abs(ln_fp_error))),
                                  "output_scale": output_scale},
        "spad": {"capacity_bytes": SPAD_BYTES, "banks": 4, "words_per_bank": 16384,
                 "descriptor_base": DESC_BASE, "completion_base": CPL_BASE,
                 "queue_entries": QUEUE_SIZE, "queue_bytes": QUEUE_SIZE * 80,
                 "descriptor_count": len(descriptors), "allocations": allocations,
                 "data_high_water": max(a[1] for k, a in allocations.items() if k not in ("cmdq", "cplq")),
                 "live_overlap_check": "PASS; disjoint static intervals; row scratch and weight/bias tiles reused by ordered descriptors"},
        "execution": {"descriptor_count": len(descriptors), "ln_valid_rows": 197,
                      "ln_zero_pad_rows_executed": 0, "ln_rows_executed": 197,
                      "packed_physical_rows": LN_OUTPUT_ROWS,
                      "explicit_zero_pad_rows": LN_OUTPUT_ROWS - 197,
                      "pack_tiles": 13, "qkv_gemm_tiles": 36,
                      "dma_event_count": len(dma_events), "dma_payload_bytes": len(ext_words) * 4,
                      "zero_pad_dma": {"before_descriptor": pad_dma_desc,
                                       "spad_ranges": [[LN_TEMP_BASE + (5 + row) * HIDDEN * 4,
                                                        LN_TEMP_BASE + (6 + row) * HIDDEN * 4]
                                                       for row in range(LN_OUTPUT_ROWS - 197)],
                                       "words": pad_words, "bytes": pad_words * 4,
                                       "events": len(pad_dma_events)},
                      "golden_words": len(golden),
                      "useful_macs": 3 * 16 * 192 * 192,
                      "executed_macs": 3 * 16 * 192 * 192,
                      "note": "Q/K/V projection output covers first 16 query rows and all 192 channels; no attention is executed in this workload"},
        "fp32_reference": {"layernorm_mae": ln_mae, "layernorm_rmse": ln_rmse,
                           "note": "single synthetic fixture image; no classification metric"},
        "artifacts": {},
    }
    for name in ("model_memory.memh", "model_golden.memh", "dma_payload.memh", "late_dma_plan.memh"):
        manifest["artifacts"][name] = sha_file(args.out_dir / name)
    (args.out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print("DEIT_LN197_QKV_WORKLOAD_PASS " + json.dumps({
        "verified_embedding_words": len(expected_embed), "descriptors": len(descriptors),
        "late_dma_events": len(dma_events), "golden_words": len(golden),
        "useful_macs": 3 * 16 * 192 * 192, "ln_fp32_mae": ln_mae,
        "model_memory_sha256": manifest["artifacts"]["model_memory.memh"],
    }, sort_keys=True))


if __name__ == "__main__":
    main()
