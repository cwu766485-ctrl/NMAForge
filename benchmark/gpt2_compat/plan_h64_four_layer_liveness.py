#!/usr/bin/env python3
"""Build an interval/liveness SPAD allocation proof for the H64 four-layer plan.

This is an allocation analysis, not a Product Top execution.  It derives the
per-layer temporary tensor sizes and descriptor lifetimes from the Round 15
four-token full-decoder generator, makes the inter-layer residual handoff live
through the next layer's last input consumer, reserves distinct persistent KV
for all four layers, streams one decoder layer's weights at a time, and then
plans Final LN + a streamed 16x16-tiled LM head.
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "benchmark/gpt2_compat"))
from generate_h64_preln_qkv import generate  # noqa: E402

CAPACITY = 128 * 1024
ALIGN = 64
ARENA_BASE = 0x1000  # retain the existing mapper's low-address guard
QUEUE_SLOTS = 512
DESC_BYTES = 64
CPL_BYTES = 16
LAYERS = 4
TOKENS = [1, 7, 42, 3]
SEED = 20261116


def align_up(value: int, alignment: int = ALIGN) -> int:
    return (value + alignment - 1) & ~(alignment - 1)


def layer_name(layer: int, name: str) -> str:
    if name.startswith("l0."):
        return f"l{layer}." + name[3:]
    if name.startswith("l0_"):
        return f"l{layer}_" + name[3:]
    return f"l{layer}.{name}"


def interval_overlap(a0: int, a1: int, b0: int, b1: int) -> bool:
    return a0 <= b1 and b0 <= a1


def build_template(tokens: list[int] = TOKENS, seed: int = SEED) -> dict:
    with tempfile.TemporaryDirectory(prefix="nmaforge_r16_liveness_") as temp:
        out = Path(temp) / "template"
        manifest = generate(
            out, seed=seed, include_attention=True, include_ffn=True,
            include_kv_roundtrip=False, include_kv_attention=True,
            token_ids=tokens, kv_k_write_mode="qk-compatible-append",
            kv_append_from=0, stream_norm_params=True,
            queue_slots_override=QUEUE_SLOTS,
        )
        # Retain the manifest data after the temporary generated memory image
        # is removed.  The generator already validates Golden and descriptor
        # ownership before returning.
        return manifest


def make_records(template: dict) -> tuple[list[dict], int, int, list[dict], dict]:
    base_alloc = template["tensor_allocation"]["records"]
    desc_count = int(template["descriptor_count"])
    if desc_count <= 0:
        raise ValueError(f"four-layer decoder graph has no descriptors: {desc_count}")
    queue_bytes = QUEUE_SLOTS * (DESC_BYTES + CPL_BYTES)
    desc_base = ((CAPACITY - queue_bytes) // DESC_BYTES) * DESC_BYTES
    cpl_base = desc_base + QUEUE_SLOTS * DESC_BYTES
    if cpl_base + QUEUE_SLOTS * CPL_BYTES != CAPACITY:
        raise ValueError("CMDQ/CPLQ reservation does not end exactly at SPAD capacity")

    # Keep the existing embedding/position residual command in every layer.
    # For layers 1..3 it can become an identity residual: previous RTL residual2
    # is src0 and a session-zero buffer is src1. This preserves the layer's
    # descriptor topology while making the handoff a real Product data edge.
    offsets = [0]
    for _layer in range(1, LAYERS):
        offsets.append(offsets[-1] + desc_count)
    final_start = offsets[-1] + desc_count
    final_end = final_start + 33  # 16 LN rows + pack + 16 streamed LM-head tiles
    records: list[dict] = []
    per_layer_kv = []
    cache_names = {"l0.kv_attention_k_cache_i8", "l0.kv_attention_v_cache_i8"}
    input_name = "embedding_plus_position_i32"
    output_name = "l0.residual2_i32"
    input_record = next(x for x in base_alloc if x["tensor_id"] == input_name)
    if not input_record["consumer_descriptors"]:
        raise ValueError("layer input tensor has no consumers")
    zero_position = {
        "tensor_id": "interlayer_zero_position_i32",
        "layer": "shared",
        "kind": "session_constant",
        "size_bytes": 16 * 64 * 4,
        "alignment_bytes": ALIGN,
        "live_start": 0,
        "live_end": final_end,
        "start": None,
        "end_exclusive": None,
        "producer": "one-time zero initialization before layer 0",
        "last_consumer": "embedding-position residual in layers 1..3",
        "reuse": "reserved for complete session",
    }
    records.append(zero_position)

    # Four cache pairs have session lifetime.  They are placed first in a
    # contiguous, 64-byte-aligned pool and are never eligible for aliasing.
    kv_bytes_each = 0
    for item in base_alloc:
        if item["tensor_id"] == "l0.kv_attention_k_cache_i8":
            kv_bytes_each = int(item["size_bytes"])
            break
    if kv_bytes_each != 1024:
        raise ValueError(f"unexpected K cache physical size {kv_bytes_each}; review layout contract")
    kv_base = ARENA_BASE
    for layer in range(LAYERS):
        for kind in ("k", "v"):
            start = kv_base + layer * 2 * kv_bytes_each + (kv_bytes_each if kind == "v" else 0)
            records.append({
                "tensor_id": f"l{layer}.kv_{kind}_cache_i8",
                "layer": layer, "kind": "persistent_kv",
                "size_bytes": kv_bytes_each, "alignment_bytes": ALIGN,
                "live_start": 0, "live_end": final_end,
                "start": start, "end_exclusive": start + kv_bytes_each,
                "producer": "Product KV_WRITE descriptors in owning layer",
                "last_consumer": "session retirement after final output",
                "reuse": "forbidden across layers and temporary tensors",
            })
            per_layer_kv.append({
                "layer": layer, "kind": kind.upper(),
                "start": start, "end_exclusive": start + kv_bytes_each,
                "bytes": kv_bytes_each, "alignment_bytes": ALIGN,
                "lifetime": [0, final_end],
            })

    persistent_reserved = [
        (r["start"], r["end_exclusive"], r["live_start"], r["live_end"], r["tensor_id"])
        for r in records
    ]

    for layer in range(LAYERS):
        offset = offsets[layer]
        omit_embedding = layer > 0
        for src in base_alloc:
            old_name = src["tensor_id"]
            if old_name in cache_names:
                continue
            if omit_embedding and old_name == "embedding_lookup_i32":
                # The layer's input edge is sourced from the prior RTL residual2.
                continue
            if omit_embedding and old_name == "position_i32":
                # All later embedding-position residuals share one zero tensor.
                continue
            old_start = int(src["live_start_descriptor"])
            old_end = int(src["live_end_descriptor"])
            live_start = offset + old_start
            live_end = offset + old_end
            if src["tensor_id"] == output_name and layer < LAYERS - 1:
                next_offset = offsets[layer + 1]
                # The prior layer result is consumed by the next layer's first
                # identity-residual descriptor, then its destination is live.
                live_end = max(live_end, next_offset)
            if src["tensor_id"] == output_name and layer == LAYERS - 1:
                live_end = max(live_end, final_start + 15)
            records.append({
                "tensor_id": layer_name(layer, old_name),
                "layer": layer,
                "kind": ("weight_tile" if src["dma_write_owner"] == "external_axi4_dma"
                         else "activation_or_scratch"),
                "size_bytes": int(src["size_bytes"]),
                "alignment_bytes": int(src["alignment_bytes"]),
                "live_start": live_start, "live_end": live_end,
                "start": None, "end_exclusive": None,
                "producer": ",".join(src["producer_names"]) or src["initial_owner"] or "external DMA",
                "last_consumer": ",".join(src["consumer_names"]) or "none",
                "reuse": "eligible after last consumer and completion retirement",
                "template_tensor": old_name,
            })

    # Final LayerNorm and LM head use the last hidden state, with tiled
    # weight DMA.  The output allocation conservatively reserves all 16
    # physical rows even though only the first four are semantically valid.
    final_records = [
        ("final_ln_gamma_q15", 256, final_start, final_start + 15, "layer norm parameter"),
        ("final_ln_beta_i32", 256, final_start, final_start + 15, "layer norm parameter"),
        ("final_ln_i32", 16 * 64 * 4, final_start, final_start + 16, "Product SFU output"),
        ("final_ln_matrix_a_i8", 16 * 64, final_start + 16, final_start + 17, "Product REQUANT output"),
        ("logits_i32_physical_16x256", 16 * 256 * 4, final_start + 17, final_end, "Product Matrix output; host reads four valid rows"),
    ]
    for index, (name, size, live_start, live_end, owner) in enumerate(final_records):
        records.append({"tensor_id": name, "layer": 4, "kind": "final_output",
                        "size_bytes": size, "alignment_bytes": ALIGN,
                        "live_start": live_start, "live_end": live_end,
                        "start": None, "end_exclusive": None,
                        "producer": owner, "last_consumer": "host logits/argmax readback",
                        "reuse": "lifetime-scoped"})
    # Sixteen LM head tiles are loaded into one 1 KiB weight buffer in
    # sequence.  This avoids falsely charging all 16 tiles as concurrent SRAM.
    for tile in range(16):
        pos = final_start + 17 + tile
        records.append({"tensor_id": f"lm_head_weight_tile_n{tile}", "layer": 4,
                        "kind": "streamed_weight_tile", "size_bytes": 1024,
                        "alignment_bytes": ALIGN, "live_start": pos,
                        "live_end": pos, "start": None, "end_exclusive": None,
                        "producer": "AXI4 DMA tile load + completion fence",
                        "last_consumer": f"LM_HEAD_N{tile}",
                        "reuse": "same 1 KiB physical tile buffer may be reused after tile retirement"})

    # Ensure the persistent pool and the shared zero tensor are not mistaken
    # for freely reusable holes.
    placed = []
    for fixed in records:
        if fixed["start"] is not None:
            placed.append(fixed)
    movable = [r for r in records if r["start"] is None]
    for item in sorted(movable, key=lambda r: (r["live_start"], -r["size_bytes"], r["tensor_id"])):
        candidate = ARENA_BASE
        while True:
            candidate = align_up(candidate, item["alignment_bytes"])
            conflicts = [other for other in placed
                         if interval_overlap(item["live_start"], item["live_end"],
                                             other["live_start"], other["live_end"])
                         and candidate < other["end_exclusive"]
                         and other["start"] < candidate + item["size_bytes"]]
            if not conflicts:
                break
            # Pack around the earliest conflicting range; restart to handle
            # multiple intervals without relying on tensor names/order.
            candidate = min(other["end_exclusive"] for other in conflicts)
        end = candidate + item["size_bytes"]
        if candidate < ARENA_BASE or end > desc_base:
            live_bytes = max(
                sum(r["size_bytes"] for r in records
                    if r["live_start"] <= event <= r["live_end"])
                for event in range(final_end + 1)
            )
            raise ValueError(
                f"allocation overflow: {item['tensor_id']} [{candidate:#x},{end:#x}) "
                f"before queue {desc_base:#x}; peak live bytes={live_bytes}"
            )
        item["start"], item["end_exclusive"] = candidate, end
        placed.append(item)

    # A closed-interval liveness proof: same-address reuse is legal only when
    # the old and new objects are separated by an explicit completion event.
    for i, a in enumerate(records):
        if a["start"] % a["alignment_bytes"]:
            raise ValueError(f"misaligned allocation: {a['tensor_id']}")
        if a["start"] < ARENA_BASE or a["end_exclusive"] > desc_base:
            raise ValueError(f"out-of-arena allocation: {a['tensor_id']}")
        for b in records[i + 1:]:
            addr_hit = a["start"] < b["end_exclusive"] and b["start"] < a["end_exclusive"]
            live_hit = interval_overlap(a["live_start"], a["live_end"],
                                        b["live_start"], b["live_end"])
            if addr_hit and live_hit:
                raise ValueError(f"live alias: {a['tensor_id']} / {b['tensor_id']}")

    peak_event = max(range(final_end + 1), key=lambda event: sum(
        r["size_bytes"] for r in records if r["live_start"] <= event <= r["live_end"]))
    peak_live = sum(r["size_bytes"] for r in records
                    if r["live_start"] <= peak_event <= r["live_end"])
    data_high_water = max(r["end_exclusive"] for r in records)
    # Fixed queue reservations are address-disjoint from the allocation arena.
    if any(r["start"] < cpl_base + QUEUE_SLOTS * CPL_BYTES and
           desc_base < r["end_exclusive"] for r in records):
        raise ValueError("tensor allocation intersects CMDQ/CPLQ reservation")
    return records, desc_base, cpl_base, per_layer_kv, {
        "descriptor_offsets": offsets, "descriptor_count_by_layer":
            [desc_count] * LAYERS,
        "total_layer_descriptors": desc_count * LAYERS,
        "final_head_start": final_start, "final_event_end": final_end,
        "peak_live_bytes": peak_live, "peak_live_event": peak_event,
        "data_high_water_bytes": data_high_water,
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", type=Path, required=True)
    ap.add_argument("--csv", type=Path, required=True)
    args = ap.parse_args()
    template = build_template()
    records, desc_base, cpl_base, kv_map, stats = make_records(template)
    out = {
        "status": "STATIC_ALLOCATION_PROOF_PASS_NOT_PRODUCT_TOP_EXECUTION",
        "source": {"round15_branch_head": "995ba340e914d2264b24e1928bcfef09bd675ea3",
                   "template_seed": int(template.get("seed", SEED)),
                   "tokens": template.get("tokens", TOKENS),
                   "template_model_sha256": template["canonical_model_sha256"],
                   "template_descriptor_count": template["descriptor_count"],
                   "template_graph_scope": template["scope"]},
        "configuration": {"layers": LAYERS, "hidden": 64, "heads": 4,
                          "head_dim": 16, "context": 16, "ffn": 256,
                          "vocab": 256, "spad_capacity_bytes": CAPACITY,
                          "banks": 4, "matrix_array": "16x16 INT8", "alignment_bytes": ALIGN},
        "assumptions": [
            "Each layer graph is dispatched and fully retired before the next layer's weight DMA starts.",
            "The existing Round 15 full-decoder tensor shapes and descriptor consumer lifetimes are reused.",
            "Each layer retains the existing embedding-position residual descriptor; for layers 1..3 it is an identity residual with prior Product residual2 as src0 and a shared zero tensor as src1.",
            "Layer-specific KV pairs persist for the whole session and are never aliased.",
            "Layer weights stream one layer at a time; LM head weight streams one N=16 tile at a time.",
            "Final output storage reserves all 16 physical Matrix rows; four semantic rows are valid for the selected workload.",
            "Allocation proof covers byte ranges and modeled descriptor lifetimes only; it does not prove RTL descriptor generation or fences.",
        ],
        "memory": {"arena": [ARENA_BASE, desc_base],
                   "cmdq": [desc_base, cpl_base],
                   "cplq": [cpl_base, CAPACITY],
                   "queue_slots": QUEUE_SLOTS,
                   "queue_reuse": "one layer invocation at a time; all prior CPLQ entries retired before next publication",
                   "persistent_kv": kv_map,
                   "persistent_kv_total_bytes": sum(x["bytes"] for x in kv_map),
                   "peak_live_data_bytes": stats["peak_live_bytes"],
                   "peak_event": stats["peak_live_event"],
                   "data_address_high_water_bytes": stats["data_high_water_bytes"],
                   "allocated_data_arena_bytes": stats["data_high_water_bytes"] - ARENA_BASE,
        "capacity_margin_to_queue_base_bytes": desc_base - stats["data_high_water_bytes"],
                   "naive_round15_added_kv_estimate_bytes": 136720,
                   "old_naive_estimate_disposition": "not used as a lower-bound; this interval allocator proves the modeled schedule fits"},
        "schedule": stats,
        "allocations": records,
        "proof": {"status": "PASS", "check": "pairwise address-overlap × closed-lifetime-overlap",
                  "live_alias_violations": 0, "misaligned_allocations": 0,
                  "out_of_arena_allocations": 0, "queue_overlap_violations": 0,
                  "rtl_execution": "NOT_RUN"},
    }
    args.json.parent.mkdir(parents=True, exist_ok=True)
    args.csv.parent.mkdir(parents=True, exist_ok=True)
    args.json.write_text(json.dumps(out, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    with args.csv.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["tensor_id", "layer", "kind", "start_hex",
            "end_exclusive_hex", "size_bytes", "alignment_bytes", "live_start", "live_end",
            "producer", "last_consumer", "reuse"])
        writer.writeheader()
        for r in records:
            writer.writerow({"tensor_id": r["tensor_id"], "layer": r["layer"],
                "kind": r["kind"], "start_hex": f"0x{r['start']:05x}",
                "end_exclusive_hex": f"0x{r['end_exclusive']:05x}",
                "size_bytes": r["size_bytes"], "alignment_bytes": r["alignment_bytes"],
                "live_start": r["live_start"], "live_end": r["live_end"],
                "producer": r["producer"], "last_consumer": r["last_consumer"], "reuse": r["reuse"]})
    print("H64_FOUR_LAYER_LIVENESS_PLAN " + json.dumps({
        "status": out["status"], "peak_live_bytes": stats["peak_live_bytes"],
        "high_water": stats["data_high_water_bytes"], "desc_base": desc_base,
        "margin": desc_base - stats["data_high_water_bytes"],
        "persistent_kv_bytes": sum(x["bytes"] for x in kv_map),
        "allocation_records": len(records), "rtl_execution": "NOT_RUN"}, sort_keys=True))


if __name__ == "__main__":
    main()
