#!/usr/bin/env python3
"""Append a Product-Top head-partial Wo projection to the Round30 qblock run.

This is a one-query-block integration slice, not Encoder Layer 0 closure. It
uses the pinned HF checkpoint, consumes live Round30 AV outputs, and expresses
the linear head merge as three existing GEMMs followed by INT32 residual adds.
"""

from __future__ import annotations

import argparse
import collections
import dataclasses
import hashlib
import io
import json
import pickle
import sys
import zipfile
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "sw" / "tools"))
from cimforge_mapper import (  # noqa: E402
    Descriptor, FLAG_BIAS, FLAG_PACK_I8, FLAG_PACK_I8_TILE_A,
    OP_GEMM, OP_REQUANT, OP_RESIDUAL, _pack_matrix_a_physical,
    _pack_matrix_b_physical,
)

sys.path.insert(0, str(ROOT / "benchmark" / "deit" / "round30"))
import generate_qkv_attention_continuous as r30  # noqa: E402

QKV_COUNT = 468
HIDDEN = 192
HEADS = 3
HEAD_DIM = 64
QUERY_ROWS = 16
QUEUE_SIZE = 512
SPAD_BYTES = 256 * 1024
AV_I8_BASE = 0x3000
WO_BASE = 0x6400
BIAS_BASE = 0x7000
PARTIAL_BASE = 0x14000
MERGE01_BASE = 0x14C00
MERGED_BASE = 0x15000
OUTPUT_BASE = 0x15400
INPUT_SCALE = 1.0 / 32.0
OUTPUT_SCALE = 0.15038124021560542
REQUANT_SHIFT = 10
CHECKPOINT_SHA256 = "e1a51b0c81ff812e079d2189352747947879fee56429e4480064a6695cb34b2c"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


class StorageRef:
    def __init__(self, key: str, dtype: str, numel: int):
        self.key = key
        self.dtype = dtype
        self.numel = numel


class TensorRef:
    def __init__(self, storage: StorageRef, offset: int, size, stride):
        self.storage = storage
        self.offset = int(offset)
        self.size = tuple(int(value) for value in size)
        self.stride = tuple(int(value) for value in stride)


class CheckpointUnpickler(pickle.Unpickler):
    """Read only OrderedDict and tensor rebuild metadata from the pinned file."""

    def find_class(self, module, name):
        if module == "collections" and name == "OrderedDict":
            return collections.OrderedDict
        if module == "torch" and name in ("FloatStorage", "LongStorage", "IntStorage"):
            return type(name, (), {})
        if module == "torch._utils" and name == "_rebuild_tensor_v2":
            return lambda storage, offset, size, stride, *rest: TensorRef(
                storage, offset, size, stride)
        raise pickle.UnpicklingError("unsupported checkpoint global %s.%s" % (module, name))

    def persistent_load(self, persistent_id):
        if (not isinstance(persistent_id, tuple) or len(persistent_id) < 5 or
                persistent_id[0] != "storage"):
            raise pickle.UnpicklingError("unsupported checkpoint storage reference")
        storage_type = persistent_id[1].__name__
        dtype = storage_type.replace("Storage", "")
        if dtype not in ("Float", "Long", "Int"):
            raise pickle.UnpicklingError("unsupported checkpoint dtype %s" % dtype)
        return StorageRef(str(persistent_id[2]), dtype, int(persistent_id[4]))


def load_checkpoint_tensors(path: Path) -> dict:
    if sha256(path) != CHECKPOINT_SHA256:
        raise ValueError("pinned DeiT checkpoint SHA-256 mismatch")
    with zipfile.ZipFile(str(path)) as archive:
        candidates = [name for name in archive.namelist() if name.endswith("/data.pkl")]
        if len(candidates) != 1:
            raise ValueError("unexpected PyTorch archive data.pkl entries")
        state = CheckpointUnpickler(io.BytesIO(archive.read(candidates[0]))).load()
        root = candidates[0][:-len("data.pkl")]
        dtype_map = {"Float": np.dtype("<f4"), "Long": np.dtype("<i8"),
                     "Int": np.dtype("<i4")}
        arrays = {}
        for name in (
            "vit.encoder.layer.0.attention.output.dense.weight",
            "vit.encoder.layer.0.attention.output.dense.bias",
        ):
            tensor = state.get(name)
            if not isinstance(tensor, TensorRef):
                raise ValueError("pinned checkpoint is missing tensor %s" % name)
            dtype = dtype_map[tensor.storage.dtype]
            storage = np.frombuffer(
                archive.read(root + "data/" + tensor.storage.key),
                dtype=dtype, count=tensor.storage.numel)
            arrays[name] = np.ndarray(
                tensor.size, dtype=dtype, buffer=storage,
                offset=tensor.offset * dtype.itemsize,
                strides=tuple(value * dtype.itemsize for value in tensor.stride),
            ).astype(np.float64)
        return arrays


def read_values(path: Path) -> list[int]:
    return [int(line.strip(), 16) for line in path.read_text(encoding="ascii").splitlines()
            if line.strip()]


def write_values(path: Path, values: list[int]) -> None:
    path.write_text("".join("%08x\n" % (value & 0xFFFFFFFF) for value in values),
                    encoding="ascii")


def signed32(value: int) -> int:
    value &= 0xFFFFFFFF
    return value - (1 << 32) if value & 0x80000000 else value


def pack_pairs(path: Path, pairs: dict[int, int]) -> None:
    r30.write_pairs(path, pairs)


def pair_memh_to_dict(path: Path) -> dict[int, int]:
    return r30.read_pairs(path)


def memory_map_check() -> None:
    ranges = [
        (AV_I8_BASE, AV_I8_BASE + HEADS * 0x400),
        (WO_BASE, WO_BASE + HEADS * 0x400),
        (BIAS_BASE, BIAS_BASE + 64),
        (PARTIAL_BASE, PARTIAL_BASE + HEADS * 0x400),
        (MERGE01_BASE, MERGE01_BASE + 0x400),
        (MERGED_BASE, MERGED_BASE + 0x400),
        (OUTPUT_BASE, OUTPUT_BASE + 12 * 0x100),
    ]
    for start, end in ranges:
        if start < 0 or end > 0x16000 or start % 4:
            raise ValueError("output-projection scratch outside reusable low-SPAD window")
    for index, left in enumerate(ranges):
        for right in ranges[index + 1:]:
            if max(left[0], right[0]) < min(left[1], right[1]):
                raise ValueError("output-projection scratch ranges overlap")


def generate(source: Path, checkpoint: Path, out_dir: Path) -> dict:
    memory_map_check()
    manifest = r30.generate(source, out_dir, query_blocks=1)
    source_manifest = json.loads((source / "manifest.json").read_text(encoding="utf-8"))
    checkpoint_hash = source_manifest.get("checkpoint_sha256", {}).get("pytorch_model.bin")
    if checkpoint_hash != CHECKPOINT_SHA256:
        raise ValueError("Round30 source manifest does not identify the pinned checkpoint")

    tensors = load_checkpoint_tensors(checkpoint)
    w_fp = tensors["vit.encoder.layer.0.attention.output.dense.weight"]
    b_fp = tensors["vit.encoder.layer.0.attention.output.dense.bias"]
    if w_fp.shape != (HIDDEN, HIDDEN) or b_fp.shape != (HIDDEN,):
        raise ValueError("unexpected official Layer 0 output projection dimensions")

    weight_scale = OUTPUT_SCALE / (INPUT_SCALE * (1 << REQUANT_SHIFT))
    w_rounded = np.rint(w_fp / weight_scale)
    w_q = np.clip(w_rounded, -128, 127).astype(np.int8)
    bias_q = np.rint(b_fp / (INPUT_SCALE * weight_scale)).astype(np.int64)
    if np.any(bias_q < -(1 << 31)) or np.any(bias_q >= (1 << 31)):
        raise ValueError("Layer 0 Wo bias does not fit the INT32 accumulator")

    av_by_head = {}
    for record in manifest["batches"]:
        if record["phase"] != "av":
            continue
        head = int(record["head"])
        expected = pair_memh_to_dict(out_dir / record["golden_file"])
        base = r30.AV_BASE + head * 0x1000
        av = np.zeros((QUERY_ROWS, HEAD_DIM), dtype=np.int64)
        for feature in range(HEAD_DIM):
            panel = feature // 16
            col = feature % 16
            for row in range(QUERY_ROWS):
                address = base + panel * 0x400 + (row * 16 + col) * 4
                if address not in expected:
                    raise ValueError("Round30 AV Golden missing 0x%08x" % address)
                av[row, feature] = signed32(expected[address])
        av_by_head[head] = av
    if set(av_by_head) != set(range(HEADS)):
        raise ValueError("need one Product AV Golden for each of three heads")

    streamed_count = int(manifest["streamed_attention_descriptors"])
    batches = manifest["batches"]
    next_task_id = 0x8000 + streamed_count
    next_batch_index = len(batches)
    added_descriptors = 0

    def add_batch(name: str, descriptors: list[Descriptor], expected: dict[int, int],
                  phase: str, head: int | None = None, output_tile: int | None = None):
        nonlocal next_task_id, next_batch_index, added_descriptors
        task_first = next_task_id
        unique = []
        for descriptor in descriptors:
            unique.append(dataclasses.replace(descriptor, task_id=next_task_id))
            next_task_id += 1
        batch_index = next_batch_index
        desc_path = out_dir / "batches" / ("batch_%02d_desc.memh" % batch_index)
        golden_path = out_dir / "batches" / ("batch_%02d_golden.memh" % batch_index)
        r30.write_descriptors(desc_path, unique)
        r30.write_checkpoint(golden_path, expected)
        record = {
            "batch": batch_index, "name": name, "phase": phase,
            "head": head, "output_tile": output_tile,
            "descriptor_count": len(unique),
            "task_id_first": task_first if unique else None,
            "task_id_last": next_task_id - 1 if unique else None,
            "golden_words": len(expected),
            "descriptor_file": "batches/batch_%02d_desc.memh" % batch_index,
            "golden_file": "batches/batch_%02d_golden.memh" % batch_index,
        }
        batches.append(record)
        next_batch_index += 1
        added_descriptors += len(unique)

    # Convert each checked AV tensor from accumulator scale 1/4096 to INT8
    # Matrix-A tiles at 1/32. AV is stored as four contiguous 16x16 panels,
    # while a full 16x64 Matrix-A tile is row-group interleaved. Requantize
    # one four-row panel at a time and place each block at its full-tile
    # physical address; flattening the 16x64 tensor would read panel-major
    # source words as if they were row-major.
    requant_descs = []
    requant_expected = {}
    av_i8_by_head = {}
    for head in range(HEADS):
        values = np.clip(av_by_head[head] >> 7, -128, 127).astype(np.int32)
        av_i8_by_head[head] = values
        for panel in range(4):
            for row_group in range(4):
                block = values[row_group * 4:(row_group + 1) * 4,
                               panel * 16:(panel + 1) * 16]
                packed = _pack_matrix_a_physical(block.tolist(), physical_rows=4)
                base = AV_I8_BASE + head * 0x400 + \
                    (row_group * 64 + panel * 16) * 4
                for index, word in enumerate(packed):
                    requant_expected[base + index * 4] = int(word) & 0xFFFFFFFF
                requant_descs.append(Descriptor(
                    name="deit_r31_av_h%d_p%d_r%d_requant" %
                         (head, panel, row_group),
                    task_id=0, op=OP_REQUANT,
                    src0=r30.AV_BASE + head * 0x1000 + panel * 0x400 +
                         row_group * 0x100,
                    src1=0, dst=base, m=4, n=16, k_or_length=4 * 16,
                    flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A,
                    shift=7, aux0=1,
                ))
    add_batch("attention_av_to_matrix_a", requant_descs, requant_expected,
              "av_requant")

    original_payload = read_values(source / "dma_payload.memh")
    extension_payload: list[int] = []
    extension_events: list[tuple[int, int, int, int]] = []
    output_golden = np.zeros((QUERY_ROWS, HIDDEN), dtype=np.int64)
    output_quantized = np.zeros((QUERY_ROWS, HIDDEN), dtype=np.int64)
    output_saturation_count = 0

    for output_tile in range(HIDDEN // 16):
        n0 = output_tile * 16
        payload_starts = []
        for head in range(HEADS):
            matrix_b = w_q[n0:n0 + 16, head * HEAD_DIM:(head + 1) * HEAD_DIM].T
            words = _pack_matrix_b_physical(matrix_b.astype(np.int32).tolist())
            if len(words) != 256:
                raise AssertionError("Wo head tile must contain 256 Matrix-B words")
            payload_starts.append(len(original_payload) * 4 + len(extension_payload) * 4)
            extension_payload.extend(int(word) & 0xFFFFFFFF for word in words)
        bias_payload_start = len(original_payload) * 4 + len(extension_payload) * 4
        extension_payload.extend(int(value) & 0xFFFFFFFF
                                 for value in bias_q[n0:n0 + 16])

        first_gemm_stream_index = streamed_count + added_descriptors
        for head in range(HEADS):
            extension_events.append((QKV_COUNT + first_gemm_stream_index,
                                     payload_starts[head], WO_BASE + head * 0x400,
                                     256))
        extension_events.append((QKV_COUNT + first_gemm_stream_index,
                                 bias_payload_start, BIAS_BASE, 16))

        partials = []
        partial_expected = {}
        for head in range(HEADS):
            matrix = av_i8_by_head[head].astype(np.int64) @ \
                w_q[n0:n0 + 16, head * HEAD_DIM:(head + 1) * HEAD_DIM].astype(np.int64).T
            if head == 0:
                matrix += bias_q[n0:n0 + 16][None, :]
            base = PARTIAL_BASE + head * 0x400
            partials.append(matrix)
            for row in range(QUERY_ROWS):
                for col in range(16):
                    partial_expected[base + 4 * (row * 16 + col)] = int(matrix[row, col]) & 0xFFFFFFFF
        projection_descs = [
            Descriptor(
                name="deit_r31_wo_h%d_n%d" % (head, n0), task_id=0,
                op=OP_GEMM, src0=AV_I8_BASE + head * 0x400,
                src1=WO_BASE + head * 0x400,
                dst=PARTIAL_BASE + head * 0x400,
                bias=BIAS_BASE if head == 0 else 0,
                m=16, n=16, k_or_length=HEAD_DIM // 4,
                flags=FLAG_BIAS if head == 0 else 0, shift=0, aux0=1,
            ) for head in range(HEADS)
        ]
        add_batch("wo_n%03d_head_partials" % n0, projection_descs,
                  partial_expected, "wo_partial", output_tile=output_tile)

        merged01 = partials[0] + partials[1]
        expected01 = {
            MERGE01_BASE + 4 * (row * 16 + col): int(merged01[row, col]) & 0xFFFFFFFF
            for row in range(QUERY_ROWS) for col in range(16)
        }
        add_batch("wo_n%03d_merge_h01" % n0, [Descriptor(
            name="deit_r31_wo_n%d_merge_h01" % n0, task_id=0,
            op=OP_RESIDUAL, src0=PARTIAL_BASE, src1=PARTIAL_BASE + 0x400,
            dst=MERGE01_BASE, k_or_length=QUERY_ROWS * 16, aux0=1,
        )], expected01, "head_merge", output_tile=output_tile)

        merged = merged01 + partials[2]
        expected_merged = {
            MERGED_BASE + 4 * (row * 16 + col): int(merged[row, col]) & 0xFFFFFFFF
            for row in range(QUERY_ROWS) for col in range(16)
        }
        add_batch("wo_n%03d_merge_h2" % n0, [Descriptor(
            name="deit_r31_wo_n%d_merge_h2" % n0, task_id=0,
            op=OP_RESIDUAL, src0=MERGE01_BASE, src1=PARTIAL_BASE + 2 * 0x400,
            dst=MERGED_BASE, k_or_length=QUERY_ROWS * 16, aux0=1,
        )], expected_merged, "head_merge", output_tile=output_tile)

        quantized = np.clip(merged >> REQUANT_SHIFT, -128, 127).astype(np.int64)
        output_golden[:, n0:n0 + 16] = merged
        output_quantized[:, n0:n0 + 16] = quantized
        output_saturation_count += int(np.count_nonzero((merged >> REQUANT_SHIFT < -128) |
                                                         (merged >> REQUANT_SHIFT > 127)))
        packed_output = _pack_matrix_a_physical(quantized.astype(np.int32).tolist())
        quant_base = OUTPUT_BASE + output_tile * 0x100
        expected_quant = {quant_base + 4 * index: int(word) & 0xFFFFFFFF
                          for index, word in enumerate(packed_output)}
        add_batch("wo_n%03d_requant" % n0, [Descriptor(
            name="deit_r31_wo_n%d_requant" % n0, task_id=0,
            op=OP_REQUANT, src0=MERGED_BASE, src1=0, dst=quant_base,
            m=16, n=16, k_or_length=QUERY_ROWS * 16,
            flags=FLAG_PACK_I8 | FLAG_PACK_I8_TILE_A,
            shift=REQUANT_SHIFT, aux0=1,
        )], expected_quant, "wo_requant", output_tile=output_tile)

    # Merge QKV prefix transfers and Round31 weight-tile DMA events. Weight
    # bytes are streamed into a reusable Matrix-B window; no host activation
    # readback or writeback is introduced.
    source_events_raw = read_values(source / "late_dma_plan.memh")
    source_event_count = source_events_raw[0]
    source_events = [tuple(source_events_raw[1 + i * 4:5 + i * 4])
                     for i in range(source_event_count)]
    if len(source_events_raw) != 1 + source_event_count * 4:
        raise ValueError("bad Round26 late DMA plan")
    extension_plan_values = [len(extension_events)]
    for event in extension_events:
        extension_plan_values.extend(event)
    write_values(out_dir / "dma_payload.memh", original_payload)
    write_values(out_dir / "late_dma_plan.memh", [source_event_count] +
                 [word for event in source_events for word in event])
    write_values(out_dir / "wo_dma_payload.memh", extension_payload)
    write_values(out_dir / "wo_dma_plan.memh", extension_plan_values)

    # The post-projection INT8 values represent scale OUTPUT_SCALE. Compare
    # against a floating Wo projection of the quantized Attention tensor, so
    # this is an operator-local error measure rather than whole-model accuracy.
    reference = np.zeros((QUERY_ROWS, HIDDEN), dtype=np.float64)
    for head in range(HEADS):
        attention_float = av_by_head[head].astype(np.float64) / 4096.0
        reference += attention_float @ w_fp[:, head * HEAD_DIM:(head + 1) * HEAD_DIM].T
    reference += b_fp[None, :]
    output_float = output_quantized.astype(np.float64) * OUTPUT_SCALE
    error = output_float - reference
    float_weight_scale = weight_scale
    all_output_golden = {
        OUTPUT_BASE + output_tile * 0x100 + index * 4: value
        for output_tile in range(HIDDEN // 16)
        for index, value in enumerate(_pack_matrix_a_physical(
            output_quantized[:, output_tile * 16:(output_tile + 1) * 16].astype(np.int32).tolist()))
    }
    r30.write_pairs(out_dir / "wo_output_golden.memh", all_output_golden)

    manifest["streamed_attention_descriptors"] = streamed_count + added_descriptors
    manifest["total_descriptors"] = QKV_COUNT + streamed_count + added_descriptors
    manifest["batch_count"] = len(batches)
    manifest["batches"] = batches
    manifest["output_projection"] = {
        "status": "GENERATED_ONE_QUERY_BLOCK_PRODUCT_TOP_CANDIDATE",
        "official_checkpoint_sha256": CHECKPOINT_SHA256,
        "weight_tensor": "vit.encoder.layer.0.attention.output.dense.weight",
        "bias_tensor": "vit.encoder.layer.0.attention.output.dense.bias",
        "input_scale": INPUT_SCALE,
        "output_scale": OUTPUT_SCALE,
        "weight_scale": float_weight_scale,
        "requant_shift": REQUANT_SHIFT,
        "weight_saturation_ratio": float(np.mean(np.abs(w_rounded) > 127)),
        "bias_q_min": int(bias_q.min()), "bias_q_max": int(bias_q.max()),
        "output_saturation_count": output_saturation_count,
        "output_elements": QUERY_ROWS * HIDDEN,
        "golden_words": len(all_output_golden),
        "attention_input_scale_derivation": "softmax INT8 probability scale 1/128 times V INT8 scale 1/32 gives AV accumulator scale 1/4096; 0x36 shift 7 maps AV to 1/32",
        "head_merge_contract": "three INT8[16x64] x INT8[64x16] Product GEMMs; add INT32 head partials with opcode 0x34; apply Wo bias once in head-0 GEMM; final 0x36 shift 10 to output scale 0.15038124021560542",
        "reference_error_vs_float_Wo_on_integer_AV": {
            "mae": float(np.mean(np.abs(error))),
            "rmse": float(np.sqrt(np.mean(error * error))),
            "max_abs": float(np.max(np.abs(error))),
        },
        "head_merge_method": "linearity-based partial projection sum; no 192-channel AV tensor materialized",
        "weight_dma": {
            "event_count": len(extension_events),
            "payload_words": len(extension_payload),
            "payload_base_word_after_prefix": len(original_payload),
            "payload_base_byte_after_prefix": len(original_payload) * 4,
        },
        "limitations": [
            "single 16-query block only; the 13-block full attention run is not extended",
            "Residual1/LN2/FFN/GELU/Residual2 and full Encoder Layer 0 are NOT_RUN",
            "one integer activation fixture; no image classification accuracy claim",
        ],
    }
    manifest["allocation"]["output_projection_scratch"] = {
        "AV_INT8": [AV_I8_BASE, AV_I8_BASE + HEADS * 0x400],
        "Wo_Matrix_B_reused": [WO_BASE, WO_BASE + HEADS * 0x400],
        "Wo_bias_reused": [BIAS_BASE, BIAS_BASE + 64],
        "head_partials_reused": [PARTIAL_BASE, PARTIAL_BASE + HEADS * 0x400],
        "head_merge_temp_reused": [MERGE01_BASE, MERGE01_BASE + 0x400],
        "head_merged_output_reused": [MERGED_BASE, MERGED_BASE + 0x400],
        "output_int8_tile_major": [OUTPUT_BASE, OUTPUT_BASE + HIDDEN * QUERY_ROWS],
        "all_below_qkv_sources": True,
        "spad_capacity_bytes": SPAD_BYTES,
    }
    manifest["runtime_contract"]["output_projection"] = (
        "single Product Top session after checked 16-query three-head attention; "
        "weights are streamed by existing late DMA; intermediate activation "
        "host readback/writeback words remain zero")
    manifest["runtime_contract"]["host_intermediate_tensor_readback_words"] = 0
    manifest["runtime_contract"]["host_intermediate_tensor_writeback_words"] = 0
    manifest["artifacts"] = {}
    for path in sorted(out_dir.rglob("*")):
        if path.is_file() and path.name != "manifest.json":
            manifest["artifacts"][str(path.relative_to(out_dir))] = sha256(path)
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2,
                                                         sort_keys=True) + "\n",
                                            encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-workload", type=Path, required=True)
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()
    result = generate(args.source_workload, args.checkpoint, args.out_dir)
    print("DEIT_R31_OUTPUT_PROJECTION_READY " + json.dumps({
        "source_qkv_manifest_sha256": result["source_qkv_manifest_sha256"],
        "checkpoint_sha256": result["output_projection"]["official_checkpoint_sha256"],
        "streamed_descriptors": result["streamed_attention_descriptors"],
        "batch_count": result["batch_count"],
        "output_words": result["output_projection"]["golden_words"],
        "weight_saturation_ratio": result["output_projection"]["weight_saturation_ratio"],
        "max_abs_error": result["output_projection"]["reference_error_vs_float_Wo_on_integer_AV"]["max_abs"],
        "manifest_sha256": sha256(args.out_dir / "manifest.json"),
    }, sort_keys=True), flush=True)


if __name__ == "__main__":
    main()
