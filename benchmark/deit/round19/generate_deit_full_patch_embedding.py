#!/usr/bin/env python3
"""Build the full DeiT-Tiny 196-patch projection workload for the Product Top.

The workload uses the pinned, official DeiT-Tiny checkpoint and a deterministic
224x224 input.  Patch projection is tiled 16x16x768.  Weight and positional
correction tiles are loaded through AXI4 DMA immediately before their consumers;
the command stream is incrementally published so those loads cannot race a
consumer.  The output is a 208x192 Matrix-A packed tensor: rows 0..196 are the
CLS plus 196 projected patches, and rows 197..207 are required zero padding.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import numpy as np
import torch
from transformers import AutoImageProcessor, ViTForImageClassification

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "sw" / "tools"))
sys.path.insert(0, str(ROOT / "dv" / "block" / "compute" / "matrix" / "ref"))
from cimforge_mapper import (  # noqa: E402
    Descriptor, OP_GEMM, OP_RESIDUAL, OP_REQUANT,
    FLAG_BIAS, FLAG_PACK_I8, FLAG_PACK_I8_TILE_A,
    _pack_matrix_a_physical, _pack_matrix_b_physical, pack_i8,
)

MODEL_ID = "facebook/deit-tiny-patch16-224"
REVISION = "b3428f18dcc7b543470d07f14b4a4157815d1880"
SEED = 20261117
SPAD_BYTES = 256 * 1024
QUEUE_SIZE = 512
POISON = 0xA55AA55A


def sha_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_pairs(path: Path, pairs: dict[int, int]) -> None:
    with path.open("w", encoding="ascii") as f:
        # The RTL testbench consumes this header with $readmemh, so it must
        # be hexadecimal just like every following address/data word.
        f.write(f"{len(pairs):08x}\n")
        for address, value in sorted(pairs.items()):
            f.write(f"{address & 0xffffffff:08x}\n{value & 0xffffffff:08x}\n")


def write_words(path: Path, words: list[int]) -> None:
    path.write_text("".join(f"{int(word) & 0xffffffff:08x}\n" for word in words),
                    encoding="ascii")


def i8(value: np.ndarray) -> np.ndarray:
    return np.clip(value, -128, 127).astype(np.int8)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model-dir", type=Path, required=True)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--seed", type=int, default=SEED)
    args = ap.parse_args()
    model_dir = args.model_dir.resolve()
    model = ViTForImageClassification.from_pretrained(
        str(model_dir), local_files_only=True).cpu().eval()
    processor = AutoImageProcessor.from_pretrained(str(model_dir), local_files_only=True)
    torch.set_num_threads(1)

    # Fixed pixel fixture, processed by the checkpoint's official image processor.
    rng = np.random.default_rng(args.seed)
    image = rng.integers(0, 256, size=(224, 224, 3), dtype=np.uint8)
    pixels = processor(images=image, return_tensors="pt")["pixel_values"]
    patch_conv = model.vit.embeddings.patch_embeddings.projection
    patch_weights = patch_conv.weight.detach().cpu().numpy().reshape(192, 768).astype(np.float64)
    patch_bias = patch_conv.bias.detach().cpu().numpy().astype(np.float64)
    cls = model.vit.embeddings.cls_token.detach().cpu().numpy()[0, 0].astype(np.float64)
    pos = model.vit.embeddings.position_embeddings.detach().cpu().numpy()[0].astype(np.float64)

    # Deterministic power-of-two input calibration for this fixed conformance image.
    # This is a workload quantization contract, not a general ImageNet calibration.
    x_fp = pixels[0].detach().cpu().numpy().astype(np.float64)
    input_scale = max(float(np.max(np.abs(x_fp))) / 127.0, 2.0 ** -20)
    x_q = i8(np.rint(x_fp / input_scale))
    # ViT's Conv2d patch projection consumes each patch in contiguous C,H,W
    # order, exactly matching projection.weight.reshape(192, 768).
    patch_rows_q = np.stack([
        x_q[:, py * 16:(py + 1) * 16, px * 16:(px + 1) * 16].reshape(768)
        for py in range(14) for px in range(14)
    ])

    weight_scale = max(float(np.max(np.abs(patch_weights))) / 127.0, 2.0 ** -20)
    w_q = i8(np.rint(patch_weights / weight_scale))
    acc_scale = input_scale * weight_scale

    # Independent FP32 embedding reference from the checkpoint's actual patch projection.
    with torch.no_grad():
        fp_emb = model.vit.embeddings(pixels)[0].detach().cpu().numpy().astype(np.float64)
    fp_peak = float(np.max(np.abs(fp_emb)))
    shift = int(np.rint(np.log2(max(fp_peak / (127.0 * acc_scale), 1.0))))
    shift = min(max(shift, 0), 31)
    output_scale = acc_scale * (2 ** shift)

    # Quantized projection accumulation units.  Bias/position/CLS are constants
    # derived from the official checkpoint; runtime tensors remain RTL-produced.
    bias_q = np.rint(patch_bias / acc_scale).astype(np.int64)
    pos_q = np.rint(pos / acc_scale).astype(np.int64)
    cls_q = np.rint(cls / acc_scale).astype(np.int64)

    # 208 physical rows, with row zero reserved for CLS and patch p at row p+1.
    a_dense = np.zeros((208, 768), dtype=np.int32)
    a_dense[1:197] = patch_rows_q.astype(np.int32)
    a_words = _pack_matrix_a_physical(a_dense.tolist(), physical_rows=208)

    # Independent full integer golden: scalar int64 dot product + bias/correction,
    # signed arithmetic shift (the 0x36 contract), then INT8 saturation.
    output_q = np.zeros((208, 192), dtype=np.int32)
    for r in range(208):
        if r == 0:
            input_row = np.zeros(768, dtype=np.int64)
        else:
            input_row = a_dense[r].astype(np.int64)
        for c in range(192):
            acc = int(np.dot(input_row, w_q[c].astype(np.int64))) + int(bias_q[c])
            if r == 0:
                correction = int(cls_q[c] + pos_q[0, c] - bias_q[c])
            elif r <= 196:
                correction = int(pos_q[r, c])
            else:
                correction = -int(bias_q[c])
            shifted = (acc + correction) >> shift
            output_q[r, c] = min(127, max(-128, shifted))

    # Layout and queues are explicitly packed into the 256-KiB Product Top SPAD.
    input_base = 0x1000
    weight_base = input_base + len(a_words) * 4
    bias_base = weight_base + 12288
    raw_base = bias_base + 192 * 4
    residual_base = raw_base + 16 * 16 * 4
    pos_tile_base = residual_base + 16 * 16 * 4
    output_base = pos_tile_base + 16 * 16 * 4
    desc_base = SPAD_BYTES - QUEUE_SIZE * 80
    cpl_base = desc_base + QUEUE_SIZE * 64
    # Keep each 16x16 result tile contiguous.  Within a tile the bytes use the
    # Matrix-A row-group/K-group/row-lane packing.  The macro-tile index is
    # explicit in the manifest; this avoids pretending independently issued
    # N=16 descriptors can create a monolithic N=192 Matrix-A row stride.
    output_words: list[int] = []
    output_word_address: dict[int, int] = {}
    for m0 in range(0, 208, 16):
        for n0 in range(0, 192, 16):
            tile_words = _pack_matrix_a_physical(
                output_q[m0:m0 + 16, n0:n0 + 16].tolist(), physical_rows=16)
            tile_index = (m0 // 16) * 12 + (n0 // 16)
            if len(tile_words) != 64:
                raise AssertionError("each 16x16 output tile must occupy 64 words")
            for local_index, word in enumerate(tile_words):
                output_word_address[tile_index * 64 + local_index] = int(word)
            output_words.extend(tile_words)
    output_bytes = len(output_words) * 4
    if output_base + output_bytes > desc_base:
        raise SystemExit("SPAD layout overflow: live data overlaps 512-entry queues")
    if len(output_words) != 9984:
        raise AssertionError(f"unexpected output words {len(output_words)}")

    pairs: dict[int, int] = {}
    for i, word in enumerate(a_words):
        pairs[input_base + i * 4] = word
    for i, value in enumerate(bias_q.tolist()):
        pairs[bias_base + i * 4] = int(value)
    for base, count in ((raw_base, 256), (residual_base, 256), (pos_tile_base, 256)):
        for i in range(count):
            pairs[base + i * 4] = POISON
    for i in range(len(output_words)):
        pairs[output_base + i * 4] = POISON

    # External DMA payload: 12 weight tiles (each 768x16 INT8, padded/packed)
    # followed by 156 position-correction tiles (16x16 INT32).
    ext_words: list[int] = []
    weight_ext_bases: list[int] = []
    for n0 in range(0, 192, 16):
        w_tile = w_q[n0:n0 + 16].T.astype(np.int32).tolist()
        packed = _pack_matrix_b_physical(w_tile)
        if len(packed) != 3072:
            raise AssertionError("weight tile packing must be 3072 words")
        weight_ext_bases.append(len(ext_words) * 4)
        ext_words.extend(packed)
    position_ext: dict[tuple[int, int], int] = {}
    for m0 in range(0, 208, 16):
        for n0 in range(0, 192, 16):
            tile = np.zeros((16, 16), dtype=np.int32)
            for rr in range(16):
                r = m0 + rr
                for cc in range(16):
                    c = n0 + cc
                    if r == 0:
                        corr = int(cls_q[c] + pos_q[0, c] - bias_q[c])
                    elif r <= 196:
                        corr = int(pos_q[r, c])
                    else:
                        corr = -int(bias_q[c])
                    if not -(1 << 31) <= corr < (1 << 31):
                        raise OverflowError("position correction exceeds signed int32")
                    tile[rr, cc] = corr
            position_ext[(m0, n0)] = len(ext_words) * 4
            ext_words.extend(int(v) & 0xffffffff for v in tile.reshape(-1))

    descriptors: list[Descriptor] = []
    dma_events: list[tuple[int, int, int, int]] = []
    useful_macs = 0
    executed_macs = 0
    for n_index, n0 in enumerate(range(0, 192, 16)):
        # Load each official checkpoint weight tile in 12 legal <=256-word DMA chunks.
        first_tile_index = n_index * 13
        first_desc = first_tile_index * 3
        b_ext = weight_ext_bases[n_index]
        for chunk in range(12):
            dma_events.append((first_desc, b_ext + chunk * 256 * 4,
                               weight_base + chunk * 256 * 4, 256))
        for m_index, m0 in enumerate(range(0, 208, 16)):
            tile_index = n_index * 13 + m_index
            desc_index = tile_index * 3
            a_tile_base = input_base + m0 * 768
            raw_desc = Descriptor(
                name=f"deit_patch_gemm_m{m0}_n{n0}", task_id=0x7100 + desc_index,
                op=OP_GEMM, src0=a_tile_base, src1=weight_base,
                bias=bias_base + n0 * 4, dst=raw_base, m=16, n=16,
                k_or_length=192, flags=FLAG_BIAS, batch_count=1, head_count=1,
            )
            descriptors.append(raw_desc)
            # Position/CLS correction is streamed only after GEMM has retired.
            p_ext = position_ext[(m0, n0)]
            dma_events.append((desc_index + 1, p_ext, pos_tile_base, 256))
            descriptors.append(Descriptor(
                name=f"deit_patch_position_m{m0}_n{n0}", task_id=0x7100 + desc_index + 1,
                op=OP_RESIDUAL, src0=raw_base, src1=pos_tile_base, dst=residual_base,
                k_or_length=256, batch_count=1, head_count=1,
            ))
            # One contiguous 16x16 Matrix-A-packed macro tile.
            out_tile_base = output_base + ((m0 // 16) * 12 + (n0 // 16)) * 256
            descriptors.append(Descriptor(
                name=f"deit_patch_requant_m{m0}_n{n0}", task_id=0x7100 + desc_index + 2,
                op=OP_REQUANT, src0=residual_base, src1=0, dst=out_tile_base,
                m=16, n=16, k_or_length=256,
                flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A, shift=shift,
                aux0=1, batch_count=1, head_count=1,
            ))
            # Row zero is CLS and is injected by the correction path; it is
            # not a patch-projection MAC.  Count only real rows 1..196.
            valid_patch_rows = max(0, min(m0 + 16, 197) - max(m0, 1))
            useful_macs += valid_patch_rows * 16 * 768
            executed_macs += 16 * 16 * 768

    if len(descriptors) != 468 or len(dma_events) != 300:
        raise AssertionError(f"unexpected plan desc={len(descriptors)} dma={len(dma_events)}")
    for index, descriptor in enumerate(descriptors):
        if descriptor.task_id != 0x7100 + index:
            raise AssertionError("descriptor task IDs must be strictly sequential")
        for wi, word in enumerate(descriptor.words()):
            pairs[desc_base + index * 64 + wi * 4] = word
    for i in range(QUEUE_SIZE * 4):
        pairs[cpl_base + i * 4] = POISON

    # INT8 output physical words become the exact Top readback golden.
    golden = {output_base + i * 4: int(word) for i, word in enumerate(output_words)}

    # Reconstruct FP32 DeiT embedding including CLS and position for the 197 valid rows.
    with torch.no_grad():
        fp_tokens = model.vit.embeddings(pixels)[0].detach().cpu().numpy().astype(np.float64)
    q_dequant = output_q[:197].astype(np.float64) * output_scale
    diff = q_dequant - fp_tokens
    max_abs = np.max(np.abs(diff), axis=1)
    mae = float(np.mean(np.abs(diff)))
    rmse = float(np.sqrt(np.mean(diff * diff)))

    args.out_dir.mkdir(parents=True, exist_ok=True)
    write_pairs(args.out_dir / "model_memory.memh", pairs)
    write_pairs(args.out_dir / "model_golden.memh", golden)
    write_words(args.out_dir / "dma_payload.memh", ext_words)
    plan_words = [len(dma_events)]
    for event in dma_events:
        plan_words.extend(event)
    write_words(args.out_dir / "late_dma_plan.memh", plan_words)
    manifest = {
        "status": "FULL_PATCH_EMBEDDING_TOP_WORKLOAD_GENERATED",
        "model_id": MODEL_ID,
        "checkpoint_revision": REVISION,
        "checkpoint_sha256": {name: sha_file(model_dir / name) for name in
                               ("config.json", "preprocessor_config.json", "pytorch_model.bin")},
        "seed": args.seed,
        "input_kind": "deterministic synthetic RGB fixture processed by official checkpoint image processor; no ImageNet accuracy claim",
        "input_image_sha256": sha_bytes(image.tobytes()),
        "official_processed_pixels_sha256": sha_bytes(pixels.numpy().tobytes()),
        "quantization": {
            "input_scale": input_scale, "weight_scale_global": weight_scale,
            "accumulator_scale": acc_scale, "requant_shift": shift,
            "output_scale": output_scale,
            "input": "symmetric int8 round-to-nearest-even, saturate [-128,127]",
            "weights": "symmetric per-tensor int8 round-to-nearest-even, saturate [-128,127]",
            "bias_position_cls": "round-to-nearest-even into int32 accumulator units",
            "requant": "Product 0x36 arithmetic right shift then signed int8 saturation; no rounding",
        },
        "shape": {"patches": 196, "tokens_including_cls": 197, "hidden": 192,
                  "physical_rows": 208, "K": 768, "output_channels": 192},
        "fp32_embedding_comparison": {
            "scope": "all 197 valid tokens x 192 channels; dequantized independent integer projection",
            "mae": mae, "rmse": rmse, "max_abs_by_token_max": float(np.max(max_abs)),
            "note": "quality/accuracy is not measured because the input is a deterministic synthetic image",
        },
        "spad": {
            "capacity_bytes": SPAD_BYTES, "banks": 4, "words_per_bank": 16384,
            "queue_entries": QUEUE_SIZE, "cmdq_bytes": QUEUE_SIZE * 64,
            "cplq_bytes": QUEUE_SIZE * 16, "queue_total_bytes": QUEUE_SIZE * 80,
            "data_arena_start": 0x1000, "descriptor_base": desc_base,
            "completion_base": cpl_base,
            "allocations": {
                "matrix_a_input": [input_base, input_base + len(a_words) * 4],
                "streamed_weight_tile": [weight_base, weight_base + 12288],
                "bias_i32": [bias_base, bias_base + 192 * 4],
                "gemm_output_i32_scratch": [raw_base, raw_base + 1024],
                "residual_output_i32_scratch": [residual_base, residual_base + 1024],
                "position_correction_i32_tile": [pos_tile_base, pos_tile_base + 1024],
                "embedding_output_matrix_a_i8": [output_base, output_base + output_bytes],
            },
            "peak_data_high_water_exclusive": output_base + output_bytes,
            "queue_start": desc_base,
            "free_gap_before_queues": desc_base - (output_base + output_bytes),
        },
        "execution": {
            "descriptor_count": len(descriptors), "dma_event_count": len(dma_events),
            "weight_dma_bytes": 192 * 768, "position_correction_dma_bytes": 156 * 1024,
            "total_dma_payload_bytes": len(ext_words) * 4,
            "useful_macs": useful_macs, "executed_macs": executed_macs,
            "padding_macs": executed_macs - useful_macs,
            "useful_output_elements": 197 * 192,
            "physical_output_elements": 208 * 192,
            "golden_words": len(golden), "output_layout": "16x16 macro-tile-major; each tile uses local Matrix-A packing; logical rows 0..196 are CLS plus 196 patches",
            "descriptor_base": desc_base, "completion_base": cpl_base,
        },
        "limitations": [
            "this workload executes Patch Embedding plus CLS/Position addition only; no Encoder Layer is claimed",
            "input image is a deterministic fixture and no classification accuracy is claimed",
            "Host AXI-Lite fixture initialization and testbench DMA payload staging are reported separately from Product execution",
        ],
        "artifacts": {name: sha_file(args.out_dir / name) for name in
                      ("model_memory.memh", "model_golden.memh", "dma_payload.memh", "late_dma_plan.memh")},
    }
    (args.out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n",
                                                  encoding="utf-8")
    print("DEIT_FULL_PATCH_EMBEDDING_WORKLOAD_PASS " + json.dumps({
        "descriptors": len(descriptors), "late_dma_events": len(dma_events),
        "useful_macs": useful_macs, "golden_words": len(golden),
        "spad_high_water": output_base + output_bytes,
        "queue_start": desc_base, "free_gap": desc_base - (output_base + output_bytes),
        "shift": shift, "fp32_mae": mae,
        "model_memory_sha256": sha_file(args.out_dir / "model_memory.memh"),
        "golden_sha256": sha_file(args.out_dir / "model_golden.memh"),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
