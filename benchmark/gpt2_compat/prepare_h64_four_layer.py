#!/usr/bin/env python3
"""Prepare four sequential H64 Product-Top layer invocations.

This emits per-layer descriptor/weight files and a first-layer SPAD image.
Later-layer hidden inputs are connected to the prior layer's planned
residual2 address; the generator consumes the software reference tensor only
to build expected Golden records and never places it in a later-layer input
file. Product-Top PASS is established only by the SV runtime.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "benchmark/gpt2_compat"))
from generate_h64_preln_qkv import generate, s32  # noqa: E402
from plan_h64_four_layer_liveness import (  # noqa: E402
    ARENA_BASE, CAPACITY, CPL_BYTES, DESC_BYTES, LAYERS, QUEUE_SLOTS,
    build_template, layer_name, make_records,
)

SEED = 20261116
TOKENS = [1, 7, 42, 3]
SENTINEL = 0xA55AA55A


def read_pairs(path: Path) -> dict[int, int]:
    words = [int(line, 16) for line in path.read_text(encoding="ascii").splitlines()]
    if not words or len(words) != 1 + words[0] * 2:
        raise ValueError(f"invalid address/value file: {path}")
    return dict(zip(words[1::2], words[2::2]))


def write_pairs(path: Path, pairs: dict[int, int]) -> None:
    words = [len(pairs)]
    for address, value in sorted(pairs.items()):
        words.extend((address, value & 0xFFFFFFFF))
    path.write_text("".join(f"{word & 0xFFFFFFFF:08x}\n" for word in words),
                    encoding="ascii")


def write_words(path: Path, words: list[int]) -> None:
    path.write_text("".join(f"{word & 0xFFFFFFFF:08x}\n" for word in words),
                    encoding="ascii")


def parse_checkpoints(run_dir: Path, manifest: dict) -> dict[str, tuple[int, dict[int, int]]]:
    words = [int(line, 16) for line in (run_dir / "checkpoint_golden.memh")
             .read_text(encoding="ascii").splitlines()]
    count = words[0]
    if count != len(manifest["intermediate_checkpoints"]):
        raise ValueError("checkpoint count differs from manifest")
    cursor = 1
    result = {}
    for spec in manifest["intermediate_checkpoints"]:
        desc_index, word_count = words[cursor:cursor + 2]
        cursor += 2
        pairs = {words[cursor + i * 2]: words[cursor + i * 2 + 1]
                 for i in range(word_count)}
        cursor += 2 * word_count
        if desc_index != spec["descriptor_index"] or word_count != spec["golden_words"]:
            raise ValueError(f"checkpoint shape mismatch: {spec['tensor_id']}")
        result[spec["tensor_id"]] = (desc_index, pairs)
    if cursor != len(words):
        raise ValueError("extra checkpoint data")
    return result


def read_dense_tensor(pairs: dict[int, int], start: int, words: int) -> list[int]:
    missing = [start + i * 4 for i in range(words) if start + i * 4 not in pairs]
    if missing:
        raise ValueError(f"Golden is missing tensor word at {missing[0]:#x}")
    return [s32(pairs[start + i * 4]) for i in range(words)]


def write_checkpoint_file(path: Path, records: list[tuple[int, dict[int, int]]]) -> None:
    words = [len(records)]
    for desc_index, pairs in records:
        words.extend((desc_index, len(pairs)))
        for address, value in sorted(pairs.items()):
            words.extend((address, value))
    write_words(path, words)


def resolve_owner(template_records: list[dict], address: int, desc_index: int,
                  role: str) -> dict:
    candidates = [r for r in template_records
                  if r["start"] <= address < r["end_exclusive"] and
                  r["live_start_descriptor"] <= desc_index <= r["live_end_descriptor"]]
    if role == "dst":
        producers = [r for r in candidates if desc_index in r["producer_descriptors"]]
        if producers:
            candidates = producers
    else:
        consumers = [r for r in candidates if desc_index in r["consumer_descriptors"]]
        if consumers:
            candidates = consumers
    if len(candidates) != 1:
        names = [r["tensor_id"] for r in candidates]
        raise ValueError(f"address {address:#x} at descriptor {desc_index} has {len(candidates)} {role} owners: {names}")
    return candidates[0]


def layer_plan_map(plan_records: list[dict], layer: int) -> dict[str, dict]:
    result = {r["template_tensor"]: r for r in plan_records
              if r["layer"] == layer and "template_tensor" in r}
    for kind in ("k", "v"):
        item = next(r for r in plan_records
                    if r["tensor_id"] == f"l{layer}.kv_{kind}_cache_i8")
        result[f"l0.kv_attention_{kind}_cache_i8"] = item
    if layer == LAYERS - 1:
        aliases = {
            "final_ln_gamma_q15_weight": "final_ln_gamma_q15",
            "final_ln_beta_i32_weight": "final_ln_beta_i32",
            "final_ln_i32": "final_ln_i32",
            "final_ln_matrix_a_i8": "final_ln_matrix_a_i8",
            "logits_i32_physical_16x256": "logits_i32_physical_16x256",
        }
        for source, target_id in aliases.items():
            result[source] = next(r for r in plan_records
                                  if r["tensor_id"] == target_id)
        for tile in range(16):
            result[f"lm_head_weight_tile_n{tile}_weight"] = next(
                r for r in plan_records
                if r["tensor_id"] == f"lm_head_weight_tile_n{tile}")
    return result


def remap_descriptor_words(raw_words: list[int], manifest: dict,
                           plan_records: list[dict], layer: int,
                           previous_output_start: int | None,
                           zero_position_start: int,
                           base_descriptor_count: int) -> list[list[int]]:
    descriptors = []
    template_records = manifest["tensor_allocation"]["records"]
    plan_by_template = layer_plan_map(plan_records, layer)
    count = int(manifest["descriptor_count"])
    expected_count = base_descriptor_count + (33 if layer == LAYERS - 1 else 0)
    if count != expected_count:
        raise ValueError(f"unexpected layer {layer} descriptor count {count}; expected {expected_count}")
    for index in range(count):
        words = raw_words[index * 16:(index + 1) * 16]
        if len(words) != 16:
            raise ValueError("truncated descriptor image")
        desc_name = manifest["descriptor_contract"][index]["name"]
        if layer > 0 and index == 0:
            if "embedding_position_residual" not in desc_name or previous_output_start is None:
                raise ValueError("layer handoff descriptor contract mismatch")
            words[1] = previous_output_start
            words[2] = zero_position_start
            # Keep the destination in the current layer's planned activation
            # allocation. Leaving the template address here can alias the
            # shared zero-position source (the original one-layer graph does
            # not have a separate inter-layer source).
            destination = words[4]
            owner = resolve_owner(template_records, destination, index, "dst")
            target = plan_by_template.get(owner["tensor_id"])
            if target is None:
                raise ValueError(f"no layer {layer} allocation for handoff destination {owner['tensor_id']}")
            words[4] = target["start"] + destination - owner["start"]
            if words[4] == words[2]:
                raise ValueError("inter-layer residual destination aliases shared zero input")
        else:
            for field, role in ((1, "src"), (2, "src"), (3, "src"), (4, "dst")):
                address = words[field]
                if address == 0:
                    continue
                owner = resolve_owner(template_records, address, index, role)
                template_name = owner["tensor_id"]
                if template_name in ("embedding_lookup_i32", "position_i32") and layer > 0:
                    raise ValueError(f"later-layer descriptor still reads host fixture tensor {template_name}")
                target = plan_by_template.get(template_name)
                if target is None:
                    raise ValueError(f"no layer {layer} allocation for {template_name}")
                words[field] = target["start"] + address - owner["start"]
        descriptors.append(words)
    return descriptors


def remap_checkpoint(checkpoints: dict[str, tuple[int, dict[int, int]]],
                     manifest: dict, plan_records: list[dict], layer: int
                     ) -> list[tuple[int, dict[int, int]]]:
    by_name = {r["tensor_id"]: r for r in manifest["tensor_allocation"]["records"]}
    target_by_template = layer_plan_map(plan_records, layer)
    result = []
    for spec in manifest["intermediate_checkpoints"]:
        name = spec["tensor_id"]
        desc, pairs = checkpoints[name]
        owner = by_name.get(name)
        if owner is None:
            raise ValueError(f"missing allocation record for checkpoint {name}")
        target = target_by_template.get(name)
        if target is None:
            raise ValueError(f"missing planned checkpoint allocation for {name}")
        relocated = {target["start"] + address - owner["start"]: value
                     for address, value in pairs.items()}
        result.append((desc, relocated))
    return result


def remap_final_golden(run_dir: Path, manifest: dict, plan_records: list[dict],
                       layer: int) -> dict[int, int]:
    source = read_pairs(run_dir / "model_golden.memh")
    records = manifest["tensor_allocation"]["records"]
    target_by_template = layer_plan_map(plan_records, layer)
    result: dict[int, int] = {}
    for address, value in source.items():
        candidates = [r for r in records if r["start"] <= address < r["end_exclusive"]]
        if not candidates:
            raise ValueError(f"Golden address {address:#x} has no tensor owner")
        # The one-layer generator resolves physical aliases by last producer.
        owner = max(candidates, key=lambda r: max(r["producer_descriptors"], default=-1))
        target = target_by_template.get(owner["tensor_id"])
        if target is None:
            raise ValueError(f"no planned final-Golden owner for {owner['tensor_id']}")
        relocated = target["start"] + address - owner["start"]
        result[relocated] = value
    return result


def remap_dma(run_dir: Path, manifest: dict, plan_records: list[dict],
              layer: int, out: Path) -> dict:
    raw = [int(line, 16) for line in (run_dir / "dma_plan.memh")
           .read_text(encoding="ascii").splitlines()]
    transactions = manifest["dma_weight_streaming"]["transactions"]
    if raw[0] != len(transactions):
        raise ValueError("DMA plan and manifest transaction count differ")
    target_by_template = layer_plan_map(plan_records, layer)
    result = [0]
    late = []
    late_transactions = []
    for i, txn in enumerate(transactions):
        ext, _old_spad, words = raw[1 + 3 * i:4 + 3 * i]
        target = target_by_template.get(txn["name"])
        if target is None or target["size_bytes"] != words * 4:
            raise ValueError(f"DMA allocation mismatch for {txn['name']}")
        if txn["name"] in ("final_ln_gamma_q15_weight", "final_ln_beta_i32_weight"):
            trigger = int(manifest["descriptor_count"]) - 33
            late.append((trigger, ext, target["start"], words))
            late_transactions.append(txn["name"])
        elif txn["name"].startswith("lm_head_weight_tile_n"):
            tile = int(txn["name"].rsplit("n", 1)[1].split("_", 1)[0])
            trigger = int(manifest["descriptor_count"]) - 33 + 17 + tile
            late.append((trigger, ext, target["start"], words))
            late_transactions.append(txn["name"])
        else:
            result.extend((ext, target["start"], words))
    result[0] = len(result) // 3
    payload = (run_dir / "dma_payload.memh").read_bytes()
    (out / "dma_payload.memh").write_bytes(payload)
    write_words(out / "dma_plan.memh", result)
    late_words = [len(late)]
    for event in late:
        late_words.extend(event)
    write_words(out / "late_dma_plan.memh", late_words)
    return {"transactions": len(transactions),
            "initial_transactions": result[0],
            "late_transactions": late_transactions,
            "late_event_count": len(late),
            "payload_bytes": sum(t["words"] * 4 for t in transactions),
            "payload_sha256": hashlib.sha256(payload).hexdigest(),
            "plan_sha256": hashlib.sha256((out / "dma_plan.memh").read_bytes()).hexdigest(),
            "late_plan_sha256": hashlib.sha256((out / "late_dma_plan.memh").read_bytes()).hexdigest()}


def build(out: Path, seed: int = SEED, tokens: list[int] = TOKENS) -> dict:
    if not tokens or len(tokens) > 16 or any(token < 0 or token > 255 for token in tokens):
        raise ValueError("four-layer Top prompt must contain 1..16 token IDs in [0,255]")
    out.mkdir(parents=True, exist_ok=False)
    template_manifest = build_template(tokens, seed)
    plan_records, desc_base, cpl_base, kv_map, stats = make_records(template_manifest)
    plan_by_template_layer = {(r["layer"], r.get("template_tensor")): r
                              for r in plan_records if "template_tensor" in r}
    zero_position = next(r for r in plan_records
                         if r["tensor_id"] == "interlayer_zero_position_i32")
    hidden_rows = None
    manifests = []
    stage_roots = []
    for layer in range(LAYERS):
        raw_dir = out / f"raw_layer{layer}"
        manifest = generate(
            raw_dir, seed=seed, include_attention=True, include_ffn=True,
            include_kv_roundtrip=False, include_kv_attention=True,
            token_ids=tokens, kv_k_write_mode="qk-compatible-append",
            kv_append_from=0, layer_index=layer,
            input_hidden_i32=hidden_rows, stream_norm_params=True,
            include_final_lm_head=(layer == LAYERS - 1),
        )
        manifests.append(manifest)
        stage = out / f"stage{layer}"
        stage.mkdir()
        stage_roots.append(stage)

        image = read_pairs(raw_dir / "model_memory.memh")
        base_desc = int(manifest["descriptor_base"])
        desc_count = int(manifest["descriptor_count"])
        raw_desc = [image[base_desc + d * 64 + w * 4]
                    for d in range(desc_count) for w in range(16)]
        prior_start = None
        if layer > 0:
            prior = plan_by_template_layer[(layer - 1, "l0.residual2_i32")]
            prior_start = prior["start"]
        descriptors = remap_descriptor_words(
            raw_desc, manifest, plan_records, layer, prior_start,
            zero_position["start"], int(template_manifest["descriptor_count"]),
        )
        stage_descriptors = []
        for words in descriptors:
            stage_descriptors.extend(words)
        write_words(stage / "descriptors.memh", [desc_count, *stage_descriptors])

        cps = parse_checkpoints(raw_dir, manifest)
        stage_cps = remap_checkpoint(cps, manifest, plan_records, layer)
        write_checkpoint_file(stage / "checkpoint_golden.memh", stage_cps)
        final_tensor_name = ("logits_i32_physical_16x256" if layer == LAYERS - 1
                             else "l0.residual2_i32")
        residual_checkpoint_index = next(
            index for index, spec in enumerate(manifest["intermediate_checkpoints"])
            if spec["tensor_id"] == final_tensor_name)
        final_golden = stage_cps[residual_checkpoint_index][1]
        write_pairs(stage / "model_golden.memh", final_golden)
        dma_info = remap_dma(raw_dir, manifest, plan_records, layer, stage)
        write_words(stage / "inputs.memh", [0])

        # The four causal-softmax commands write only the four valid token
        # rows of a 16x16 physical probability tensor. Clear that output tensor
        # just before its first producer so padded rows do not inherit stale
        # values from the preceding layer. Do not preseed any computed tensor
        # from the software Golden.
        output_init_events: dict[int, set[int]] = {}
        for head in range(4):
            tensor_id = f"attn_h{head}_prob_q15"
            template_tensor = next(r for r in manifest["tensor_allocation"]["records"]
                                   if r["tensor_id"] == tensor_id)
            producer_index = min(template_tensor["producer_descriptors"])
            target = plan_by_template_layer[(layer, tensor_id)]
            after_descriptor = producer_index - 1
            output_init_events.setdefault(after_descriptor, set()).update(
                range(target["start"], target["end_exclusive"], 4))
        output_init_words = [len(output_init_events)]
        for event, addresses in sorted(output_init_events.items()):
            output_init_words.extend((event, len(addresses)))
            for address in sorted(addresses):
                output_init_words.extend((address, 0))
        write_words(stage / "output_init_events.memh", output_init_words)

        cache_before = {}
        for kind in ("k", "v"):
            cache = next(r for r in plan_records
                         if r["tensor_id"] == f"l{layer}.kv_{kind}_cache_i8")
            for offset in range(0, cache["size_bytes"], 4):
                cache_before[cache["start"] + offset] = SENTINEL
        write_pairs(stage / "cache_before.memh", cache_before)

        tensor_map = {r["name"]: r for r in manifest["tensor_allocations"]}
        residual_name = "l0.residual2_i32"
        residual_checkpoint = cps[residual_name][1]
        residual_alloc = tensor_map[residual_name]
        residual_values = read_dense_tensor(
            residual_checkpoint, residual_alloc["start"], 16 * 64)
        residual_relocated = {
            plan_by_template_layer[(layer, residual_name)]["start"] + offset * 4: value & 0xFFFFFFFF
            for offset, value in enumerate(residual_values)
        }
        if layer < LAYERS - 1:
            hidden_rows = [residual_values[row * 64:(row + 1) * 64]
                           for row in range(len(tokens))]
            handoff = out / f"stage{layer + 1}"  # created on the next iteration
            handoff.parent.mkdir(parents=True, exist_ok=True)
            # Keep the predecessor result in memory until the following layer's
            # first residual descriptor reads it. The file is an expectation
            # only; the SV runtime reads SPAD and never writes these words.
            (out / f"handoff_layer{layer}_to_{layer + 1}.memh").write_text(
                "", encoding="ascii")
            stage.joinpath("residual2_handoff.memh").write_text(
                "", encoding="ascii")
            setattr(build, f"_handoff_{layer}", residual_relocated)
        if layer > 0:
            prior_values = getattr(build, f"_handoff_{layer - 1}")
            write_pairs(stage / "handoff_before.memh", prior_values)

        layer_manifest = {
            **manifest,
            "layer": layer, "status": "PLANNER_READY_NOT_PRODUCT_TOP_PASS",
            "input_source": "embedding_plus_position fixture" if layer == 0 else
                            f"Product residual2 from layer {layer - 1}; no later-layer host input words",
            "descriptor_count": desc_count,
            "descriptor_sha256": hashlib.sha256((stage / "descriptors.memh").read_bytes()).hexdigest(),
            "golden_sha256": hashlib.sha256((stage / "model_golden.memh").read_bytes()).hexdigest(),
            "checkpoint_records": len(stage_cps), "dma": dma_info,
            "final_golden_scope": ("all 4096 physical logits words after 16 Product GEMM N tiles"
                                   if layer == LAYERS - 1 else
                                   "full residual2_i32 tensor at descriptor 224; avoids comparing stale aliases from the one-layer memory dump"),
            "input_fixture_words": 0,
            "output_init_event_count": len(output_init_events),
            "output_init_words": sum(len(addresses) for addresses in output_init_events.values()),
            "output_initialization": "AXI-Lite clear of each 16x16 Q15 causal-softmax output immediately before its first producer; only valid token rows are written by Product commands",
            "kv_ranges": {kind: next(r for r in plan_records
                                      if r["tensor_id"] == f"l{layer}.kv_{kind}_cache_i8")["start"]
                          for kind in ("k", "v")},
            "descriptor_base": desc_base, "completion_base": cpl_base,
            "queue_size": QUEUE_SLOTS,
        }
        (stage / "manifest.json").write_text(json.dumps(layer_manifest, indent=2) + "\n")

    # Compose only the layer-0 initial image. Later hidden tensors do not enter
    # the host publication image; weights for each layer are separately DMA'd.
    first_dir = out / "raw_layer0"
    first = manifests[0]
    raw_image = read_pairs(first_dir / "model_memory.memh")
    image0: dict[int, int] = {}
    high_water = int(stats["data_high_water_bytes"])
    for address in range(ARENA_BASE, high_water, 4):
        image0[address] = 0
    tensor_records = first["tensor_allocation"]["records"]
    first_targets = layer_plan_map(plan_records, 0)
    for alloc in first["tensor_allocations"]:
        name = alloc["name"]
        if name not in {"embedding_lookup_i32", "position_i32"}:
            continue
        target = first_targets.get(name)
        if target is None:
            raise ValueError(f"layer-0 initialized tensor has no allocation: {name}")
        old_start, size = alloc["start"], alloc["bytes"]
        for offset in range(0, size, 4):
            if old_start + offset in raw_image:
                image0[target["start"] + offset] = raw_image[old_start + offset]
    for offset in range(0, zero_position["size_bytes"], 4):
        image0[zero_position["start"] + offset] = 0

    desc_count = int(first["descriptor_count"])
    desc_file = (out / "stage0/descriptors.memh").read_text(encoding="ascii").splitlines()
    flat = [int(line, 16) for line in desc_file]
    desc_words = flat[1:]
    for index, value in enumerate(desc_words):
        image0[desc_base + index * 4] = value
    for slot in range(QUEUE_SLOTS):
        for word in range(4):
            image0[cpl_base + slot * CPL_BYTES + word * 4] = SENTINEL
    for layer in range(LAYERS):
        for kind in ("k", "v"):
            cache = next(r for r in plan_records
                         if r["tensor_id"] == f"l{layer}.kv_{kind}_cache_i8")
            for offset in range(0, cache["size_bytes"], 4):
                image0[cache["start"] + offset] = SENTINEL
    write_pairs(out / "stage0/model_memory.memh", image0)
    stage0_manifest_path = out / "stage0/manifest.json"
    stage0_manifest = json.loads(stage0_manifest_path.read_text(encoding="utf-8"))
    stage0_manifest["memory_sha256"] = hashlib.sha256(
        (out / "stage0/model_memory.memh").read_bytes()).hexdigest()
    stage0_manifest["golden_sha256"] = hashlib.sha256(
        (out / "stage0/model_golden.memh").read_bytes()).hexdigest()
    stage0_manifest_path.write_text(json.dumps(stage0_manifest, indent=2) + "\n",
                                    encoding="utf-8")
    # The full initial memory image contains no descriptor entries for later
    # layers; those are published through AXI-Lite after retirement.

    # Move predecessor handoff expectations into the consuming stage.
    for layer in range(1, LAYERS):
        prior_values = getattr(build, f"_handoff_{layer - 1}")
        write_pairs(out / f"stage{layer}/handoff_before.memh", prior_values)
    for path in out.glob("handoff_layer*_to_*.memh"):
        path.unlink()
    for stage in stage_roots:
        placeholder = stage / "residual2_handoff.memh"
        if placeholder.exists():
            placeholder.unlink()

    # Layer 0 queue initialization uses exactly the common fixed ring ranges.
    for layer in range(LAYERS):
        if len(read_pairs(out / f"stage{layer}/model_golden.memh")) <= 0:
            raise ValueError("empty layer golden")
    allocation = {
        "status": "STATIC_ALLOCATION_AND_LAYER_WORKLOADS_READY_PRODUCT_TOP_REQUIRED",
        "planning_base_sha": "995ba340e914d2264b24e1928bcfef09bd675ea3",
        "seed": seed, "tokens": tokens,
        "model_sha256": manifests[0]["canonical_model_sha256"],
        "spad_capacity_bytes": CAPACITY,
        "queue": {"entries": QUEUE_SLOTS, "descriptor_range": [desc_base, cpl_base],
                  "completion_range": [cpl_base, CAPACITY]},
        "schedule": stats,
        "persistent_kv": kv_map,
        "layer_manifests": [json.loads((out / f"stage{i}/manifest.json").read_text())
                            for i in range(LAYERS)],
        "allocation_records": plan_records,
        "handoff_contract": "layer N residual2 -> layer N+1 embedding-position residual src0; shared zero tensor src1; SV verifies old RTL output before publication; later inputs.memh contains zero words",
        "host_hidden_handoff_words": 0,
        "top_status": "NOT_RUN",
    }
    (out / "four_layer_manifest.json").write_text(json.dumps(allocation, indent=2) + "\n")
    with (out / "spad_allocation.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["tensor_id", "layer", "kind", "start_hex",
            "end_exclusive_hex", "size_bytes", "alignment_bytes", "live_start", "live_end",
            "producer", "last_consumer", "reuse"])
        writer.writeheader()
        for r in plan_records:
            writer.writerow({"tensor_id": r["tensor_id"], "layer": r["layer"], "kind": r["kind"],
                "start_hex": f"0x{r['start']:05x}", "end_exclusive_hex": f"0x{r['end_exclusive']:05x}",
                "size_bytes": r["size_bytes"], "alignment_bytes": r["alignment_bytes"],
                "live_start": r["live_start"], "live_end": r["live_end"],
                "producer": r["producer"], "last_consumer": r["last_consumer"],
                "reuse": r["reuse"]})
    print("H64_FOUR_LAYER_WORKLOADS_READY " + json.dumps({
        "layers": LAYERS, "descriptors_per_layer": [m["descriptor_count"] for m in manifests],
        "peak_live_bytes": stats["peak_live_bytes"], "high_water": stats["data_high_water_bytes"],
        "margin": desc_base - stats["data_high_water_bytes"],
        "model_sha256": allocation["model_sha256"], "top_status": "NOT_RUN"}, sort_keys=True))
    return allocation


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=SEED)
    parser.add_argument("--tokens", default=",".join(str(x) for x in TOKENS),
                        help="comma-separated fixed prompt token IDs, 1..16 entries")
    args = parser.parse_args()
    try:
        tokens = [int(item, 0) for item in args.tokens.split(",") if item]
    except ValueError as error:
        raise SystemExit(f"invalid --tokens list: {error}") from error
    build(args.out, args.seed, tokens)


if __name__ == "__main__":
    main()
