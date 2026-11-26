#!/usr/bin/env python3
"""Round 18 interval/liveness plan for tiled DeiT-Tiny.

This checks a proposed serialized schedule and queue footprint. It is not
evidence that the Product Top executed the full model.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def interval_allocate(capacity: int, queue_entries: int, objects: list[dict]) -> dict:
    if capacity not in (128 * 1024, 256 * 1024):
        raise ValueError("capacity must be 128 KiB or 256 KiB")
    if queue_entries < 2 or queue_entries > 512 or queue_entries & (queue_entries - 1):
        raise ValueError("queue_entries must be a power of two in [2,512]")

    cmdq_bytes = queue_entries * 64
    cplq_bytes = queue_entries * 16
    queue_base = capacity - cmdq_bytes - cplq_bytes
    if queue_base < 0:
        raise ValueError("configured CMDQ/CPLQ exceeds SPAD capacity")

    placed: list[dict] = []
    for obj in sorted(objects, key=lambda x: (-x["size_bytes"], x["live"][0], x["name"])):
        candidate = 0
        while True:
            align = obj["alignment_bytes"]
            candidate = (candidate + align - 1) // align * align
            if candidate + obj["size_bytes"] > queue_base:
                raise ValueError(f"{capacity}-byte data arena cannot place {obj['name']}")
            conflicts = []
            for old in placed:
                addr_overlap = candidate < old["end"] and old["start"] < candidate + obj["size_bytes"]
                life_overlap = obj["live"][0] <= old["live"][1] and old["live"][0] <= obj["live"][1]
                if addr_overlap and life_overlap:
                    conflicts.append(old["end"])
            if not conflicts:
                break
            candidate = max(conflicts)
        placed.append({
            **obj,
            "start": candidate,
            "end": candidate + obj["size_bytes"],
            "address_hex": f"0x{candidate:05x}",
            "end_exclusive_hex": f"0x{candidate + obj['size_bytes']:05x}",
        })

    collisions = []
    for i, left in enumerate(placed):
        for right in placed[i + 1:]:
            addr_overlap = left["start"] < right["end"] and right["start"] < left["end"]
            life_overlap = left["live"][0] <= right["live"][1] and right["live"][0] <= left["live"][1]
            if addr_overlap and life_overlap:
                collisions.append([left["name"], right["name"]])
    if collisions:
        raise AssertionError(f"allocator produced simultaneous live overlap: {collisions}")

    high_water = max((obj["end"] for obj in placed), default=0)
    return {
        "capacity_bytes": capacity,
        "banks": 4,
        "words_per_bank": capacity // 16,
        "host_base": "0x10000",
        "host_limit_exclusive": f"0x{0x10000 + capacity:05x}",
        "queue": {
            "entries_each": queue_entries,
            "cmdq_entry_bytes": 64,
            "cplq_entry_bytes": 16,
            "cmdq_base_offset": queue_base,
            "cmdq_base_absolute": f"0x{0x10000 + queue_base:05x}",
            "cmdq_bytes": cmdq_bytes,
            "cplq_base_offset": queue_base + cmdq_bytes,
            "cplq_base_absolute": f"0x{0x10000 + queue_base + cmdq_bytes:05x}",
            "cplq_bytes": cplq_bytes,
            "total_bytes": cmdq_bytes + cplq_bytes,
        },
        "data_arena": {"base": 0, "end_exclusive": queue_base, "bytes": queue_base},
        "objects": sorted(placed, key=lambda x: (x["start"], x["name"])),
        "sum_declared_object_bytes": sum(obj["size_bytes"] for obj in objects),
        "peak_address_high_water_exclusive": high_water,
        "peak_address_high_water_absolute": f"0x{0x10000 + high_water:05x}",
        "headroom_before_queues": queue_base - high_water,
        "simultaneous_live_address_collisions": collisions,
        "no_collision_proof": "PASS" if not collisions else "FAIL",
        "status": "STATIC_SCHEDULE_CHECK_ONLY_NOT_TOP_EXECUTION",
    }


def make_plan(queue_entries: int) -> dict:
    # Epochs describe command lifetime, not clock cycles.
    # G1 serial streaming: one 16-patch x 16-output tile at a time.
    g1_objects = [
        {"name": "patch_embedding_output_197x192_i8", "size_bytes": 197 * 192,
         "alignment_bytes": 64, "live": [0, 1000], "purpose": "persistent CLS+patch output"},
        {"name": "input_patch_tile_16x768_i8", "size_bytes": 16 * 768,
         "alignment_bytes": 64, "live": [0, 20], "purpose": "DMA-fed operand tile"},
        {"name": "patch_weight_tile_768x16_i8", "size_bytes": 768 * 16,
         "alignment_bytes": 64, "live": [0, 30], "purpose": "one streamed projection weight tile"},
        {"name": "gemm_accumulator_tile_16x16_i32", "size_bytes": 16 * 16 * 4,
         "alignment_bytes": 64, "live": [10, 30], "purpose": "matrix output before requant"},
        {"name": "position_tile_16x16_i8", "size_bytes": 16 * 16,
         "alignment_bytes": 64, "live": [20, 40], "purpose": "position data for current output tile"},
        {"name": "requant_residual_tile_16x16_i32", "size_bytes": 16 * 16 * 4,
         "alignment_bytes": 64, "live": [20, 40], "purpose": "bounded epilogue scratch"},
        {"name": "bias_tile_16_i32", "size_bytes": 16 * 4,
         "alignment_bytes": 16, "live": [0, 40], "purpose": "streamed projection bias"},
        {"name": "class_token_and_position_i32", "size_bytes": 192 * 4,
         "alignment_bytes": 64, "live": [900, 1000], "purpose": "CLS row initialization"},
    ]

    # G2 one-layer tiled encoder. KV is kept for all 197 tokens in this layer;
    # scores are kept for one head/query block so Softmax sees a full 197-key row.
    g2_objects = [
        {"name": "encoder_input_197x192_i8", "size_bytes": 197 * 192,
         "alignment_bytes": 64, "live": [0, 100], "purpose": "layer input"},
        {"name": "encoder_output_197x192_i8", "size_bytes": 197 * 192,
         "alignment_bytes": 64, "live": [80, 120], "purpose": "layer output handoff"},
        {"name": "layer_kv_2x197x192_i8", "size_bytes": 2 * 197 * 192,
         "alignment_bytes": 64, "live": [10, 120], "purpose": "persistent layer K/V"},
        {"name": "attention_score_16x197_i32", "size_bytes": 16 * 197 * 4,
         "alignment_bytes": 64, "live": [30, 50], "purpose": "one head, full-key query block for global Softmax"},
        {"name": "query_block_16x192_i8", "size_bytes": 16 * 192,
         "alignment_bytes": 64, "live": [20, 60], "purpose": "Q tile"},
        {"name": "attention_output_block_16x192_i8", "size_bytes": 16 * 192,
         "alignment_bytes": 64, "live": [45, 75], "purpose": "AV/attention projection tile"},
        {"name": "ffn_hidden_block_16x768_i8", "size_bytes": 16 * 768,
         "alignment_bytes": 64, "live": [70, 100], "purpose": "FFN intermediate tile"},
        {"name": "matrix_accumulator_16x192_i32", "size_bytes": 16 * 192 * 4,
         "alignment_bytes": 64, "live": [20, 100], "purpose": "bounded GEMM accumulator tile"},
        {"name": "streamed_weight_tile_768x16_i8", "size_bytes": 768 * 16,
         "alignment_bytes": 64, "live": [20, 100], "purpose": "one streamed weight tile"},
        {"name": "softmax_probability_16x197_i16", "size_bytes": 16 * 197 * 2,
         "alignment_bytes": 64, "live": [35, 55], "purpose": "full-key normalized row block"},
    ]

    scenarios = {}
    for capacity in (128 * 1024, 256 * 1024):
        scenario = {"G1_patch_embedding": interval_allocate(capacity, queue_entries, g1_objects)}
        try:
            scenario["G2_one_encoder_layer"] = interval_allocate(capacity, queue_entries, g2_objects)
        except ValueError as exc:
            scenario["G2_one_encoder_layer"] = {
                "capacity_bytes": capacity,
                "status": "STATIC_SCHEDULE_DOES_NOT_FIT",
                "reason": str(exc),
            }
        scenarios[f"{capacity // 1024}KiB"] = scenario

    model = {
        "name": "facebook/deit-tiny-patch16-224",
        "checkpoint_revision": "b3428f18dcc7b543470d07f14b4a4157815d1880",
        "checkpoint_sha256": "e1a51b0c81ff812e079d2189352747947879fee56429e4480064a6695cb34b2c",
        "shape": {"image": "224x224x3", "patch": 16, "tokens": 197,
                  "hidden": 192, "heads": 3, "layers": 12, "ffn": 768,
                  "classes": 1000},
        "array": {"macs": 256, "shape": "16x16", "banks": 4,
                  "line_bytes": 16},
    }
    layer_weights_i8 = 3 * 192 * 192 + 3 * 192 + 192 * 192 + 192 + 2 * (192 * 768 + 768 * 192 + 768 + 192) + 4 * 192
    return {
        "status": "STATIC_SCHEDULE_CHECK_ONLY_NOT_TOP_EXECUTION",
        "model": model,
        "queue_contract": {"entries": queue_entries, "cmdq_bytes": queue_entries * 64,
                            "cplq_bytes": queue_entries * 16,
                            "total_bytes": queue_entries * 80,
                            "note": "For 512 entries the real SPAD reservation is 32 KiB CMDQ + 8 KiB CPLQ = 40 KiB."},
        "schedules": {
            "G1": {"patch_tiles": 13, "output_channel_tiles": 12,
                   "gemm_tiles": 156, "command_count_estimate": 312,
                   "input_bytes_external": 196 * 768,
                   "patch_weight_bytes_external": 768 * 192,
                   "position_embedding_bytes_external": 197 * 192,
                   "note": "Input/weights/position are streamed into bounded tiles; no full image/weight tensor is assumed resident."},
            "G2": {"query_block_tokens": 16, "key_tokens_per_softmax_row": 197,
                   "score_scratch_bytes_per_head_block": 16 * 197 * 4,
                   "all_heads_full_score_matrix_bytes": 3 * 197 * 197 * 4,
                   "persistent_kv_bytes_one_layer": 2 * 197 * 192,
                   "persistent_kv_bytes_12_layers": 12 * 2 * 197 * 192,
                   "one_layer_int8_weight_bytes_estimate": layer_weights_i8,
                   "twelve_layer_weight_bytes_estimate": 12 * layer_weights_i8,
                   "note": "The tiled score buffer keeps all 197 keys for each row before Softmax; per-key-block Softmax concatenation is invalid."},
        },
        "capacity_scenarios": scenarios,
        "twelve_layer_readiness": {
            "all_layers_kv_spad_residency_bytes": 12 * 2 * 197 * 192,
            "fits_256k_alone": 12 * 2 * 197 * 192 <= 256 * 1024,
            "status": "PLAN_ONLY; four/layer Top execution is not implied",
            "requirements": ["external or streamed KV backing", "layer-specific K/V addresses",
                             "layer-wise weight DMA", "per-layer activation lifetime", "Final LN + classifier schedule"],
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--queue-entries", type=int, default=512)
    args = parser.parse_args()
    plan = make_plan(args.queue_entries)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(plan, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "status": plan["status"],
        "output": str(args.output),
        "queue_bytes": plan["queue_contract"]["total_bytes"],
        "scenarios": {
            cap: {
                name: ({"status": result["status"],
                       "high_water": result.get("peak_address_high_water_exclusive"),
                       "queue_bytes": result.get("queue", {}).get("total_bytes"),
                       "collision_proof": result.get("no_collision_proof")}
                      if isinstance(result, dict) else result)
                for name, result in items.items()
            }
            for cap, items in plan["capacity_scenarios"].items()
        },
    }, sort_keys=True))


if __name__ == "__main__":
    main()
