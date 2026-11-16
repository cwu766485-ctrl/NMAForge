#!/usr/bin/env python3
"""Prepare two H64 invocations for one unreset Product Top instance.

The second invocation publishes fresh descriptors after the first has retired.
It appends only token 1; token 0 K/V must remain in the Product KV cache.
The physical 16-row GEMM tile still recomputes padded rows. This script does
not claim a one-row optimized GEMV implementation or autonomous token choice.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from dataclasses import dataclass
from pathlib import Path

from compare_h64_kv_recompute import (
    COMPARE_TENSORS, load_checkpoint_records, selected_indices,
)
from generate_h64_preln_qkv import generate


@dataclass(frozen=True)
class TokenPlanner:
    """Lazily lower each token invocation against one canonical model seed."""

    seed: int
    token_ids: tuple[int, int]

    def lower(self, out: Path, position: int) -> dict:
        if position not in (0, 1):
            raise ValueError("G1 planner supports only positions 0 and 1")
        # The unused row is physical tile padding for the first invocation.
        selected = [self.token_ids[0], 0] if position == 0 else list(self.token_ids)
        return generate(out, self.seed, True, True, False, True,
                        selected, "qk-compatible-append", position)


class TensorMemoryPlanner:
    """Enforce stable physical addresses and lifetime ownership across calls."""

    @staticmethod
    def validate(first: dict, second: dict) -> dict[str, dict]:
        a = {tensor["name"]: tensor for tensor in first["tensor_allocations"]}
        b = {tensor["name"]: tensor for tensor in second["tensor_allocations"]}
        if a.keys() != b.keys() or any(a[name]["start"] != b[name]["start"] for name in a):
            raise ValueError("two invocations use different physical tensor addresses")
        if (first["descriptor_base"] != second["descriptor_base"] or
                first["completion_base"] != second["completion_base"]):
            raise ValueError("queue address changed between invocations")
        for kind in ("k", "v"):
            name = f"l0.kv_attention_{kind}_cache_i8"
            cache = a[name]
            if not cache["initialized"] or cache["start"] != b[name]["start"]:
                raise ValueError(f"{name}: KV persistence contract violated")
            if any(other["name"] != name and
                   other["start"] < cache["end_exclusive"] and
                   cache["start"] < other["end_exclusive"]
                   for other in a.values()):
                raise ValueError(f"{name}: another tensor may overwrite persistent KV")
        return a


@dataclass(frozen=True)
class Runtime:
    """Host-visible ring contract consumed by the AXI-Lite SV runtime."""

    ring_entries: int
    first_descriptors: int

    def publication(self, second_descriptors: int) -> list[dict[str, int]]:
        if self.ring_entries != 256 or not 0 < self.first_descriptors < self.ring_entries:
            raise ValueError("unsupported ring geometry")
        if not 0 < second_descriptors < self.ring_entries:
            raise ValueError("stage1 descriptor count exceeds a ring")
        return [{"descriptor_index": index,
                 "ring_slot": (self.first_descriptors + index) % self.ring_entries,
                 "tail_after_publication": (self.first_descriptors + index + 1) % self.ring_entries,
                 "completion_retirement_required": True}
                for index in range(second_descriptors)]


def validate_cache_dependencies(manifest: dict, tensors: dict[str, dict]) -> list[dict]:
    """Check the descriptor chain actually consumes persistent Product KV."""
    descriptors = manifest["descriptor_contract"]
    by_name = {item["name"]: (index, item)
               for index, item in enumerate(descriptors)}
    dependencies = []
    for head in range(4):
        k_name = f"kv_attention_k_qk_append_h{head}_t1"
        v_name = f"kv_attention_v_append_h{head}_t1"
        k_read = f"kv_attention_k_read_h{head}"
        v_read = f"kv_attention_v_read_h{head}"
        qk_name = f"attn_h{head}_qkt_scaled"
        av_name = f"attn_h{head}_av_q15"
        if any(name not in by_name for name in
               (k_name, v_name, k_read, v_read, qk_name, av_name)):
            raise ValueError(f"head {head} missing a Product KV producer/consumer")
        ki, kd = by_name[k_name]
        vi, vd = by_name[v_name]
        kri, kr = by_name[k_read]
        vri, vr = by_name[v_read]
        qi, qk = by_name[qk_name]
        ai, av = by_name[av_name]
        if not (ki < kri < qi and vi < vri < ai and qi < ai):
            raise ValueError(f"head {head} cache dependency order is invalid")
        if (kd["dst"] != tensors["l0.kv_attention_k_cache_i8"]["start"] or
                vd["dst"] != tensors["l0.kv_attention_v_cache_i8"]["start"] or
                kr["src0"] != kd["dst"] or vr["src0"] != vd["dst"] or
                qk["src1"] != kr["dst"] or av["src1"] != vr["dst"]):
            raise ValueError(f"head {head} does not consume Product KV readback")
        dependencies.append({"head": head, "k_append": ki, "k_read": kri,
                             "qk": qi, "v_append": vi, "v_read": vri, "av": ai})
    return dependencies


def read_pairs(path: Path) -> dict[int, int]:
    words = [int(line, 16) for line in path.read_text(encoding="ascii").splitlines()]
    if len(words) != 1 + words[0] * 2:
        raise ValueError(f"invalid pair file: {path}")
    return dict(zip(words[1::2], words[2::2]))


def write_words(path: Path, words: list[int]) -> None:
    path.write_text("".join(f"{word & 0xffffffff:08x}\n" for word in words),
                    encoding="ascii")


def compare_reference(run_dir: Path, ref_dir: Path, tokens: int) -> int:
    cache = load_checkpoint_records(run_dir,
                                    json.loads((run_dir / "manifest.json").read_text()))
    full = load_checkpoint_records(ref_dir,
                                   json.loads((ref_dir / "manifest.json").read_text()))
    checked = 0
    for name in COMPARE_TENSORS:
        indices = selected_indices(name, tokens)
        if not indices:
            indices = range(len(full[name]))
        for index in indices:
            if full[name][index] != cache[name][index]:
                raise ValueError(f"full-recompute mismatch {name}[{index}]")
            checked += 1
    return checked


def prepare(out: Path, seed: int, tokens: list[int]) -> dict:
    if len(tokens) != 2:
        raise ValueError("G1 requires exactly two teacher-forced token IDs")
    out.mkdir(parents=True, exist_ok=False)
    stage0, stage1, reference0, reference = (
        out / name for name in ("stage0", "stage1", "reference0", "reference"))
    # Token 1 is an invalid placeholder in stage0. Causal row 0 cannot observe it.
    planner = TokenPlanner(seed, tuple(tokens))
    first = planner.lower(stage0, 0)
    second = planner.lower(stage1, 1)
    generate(reference0, seed, True, True, False, False, tokens[:1])
    full = generate(reference, seed, True, True, False, False, tokens)
    if first["canonical_model_sha256"] != second["canonical_model_sha256"]:
        raise ValueError("model changed between invocations")
    if (first["dma_weight_streaming"]["transactions"] !=
            second["dma_weight_streaming"]["transactions"] or
            first["dma_weight_streaming"]["payload_sha256"] !=
            second["dma_weight_streaming"]["payload_sha256"]):
        raise ValueError("weight DMA plan changed between token invocations")
    a = TensorMemoryPlanner.validate(first, second)
    b = {t["name"]: t for t in second["tensor_allocations"]}
    dependencies = validate_cache_dependencies(second, b)
    names = [d["name"] for d in second["descriptor_contract"]]
    if any("_append_h" in name and "_t0" in name for name in names):
        raise ValueError("second invocation rewrites historical token 0 K/V")
    if sum("_append_h" in name and "_t1" in name for name in names) != 8:
        raise ValueError("second invocation must append new K and V in all four heads")
    if not all(d["opcode"] != 0x43 or "_t0" not in d["name"]
               for d in second["descriptor_contract"]):
        raise ValueError("historical KV write still present")

    # The compact allocator may reuse the previous invocation's embedding,
    # position and constant addresses after their final consumer. Restore all
    # declared initial inputs/constants, never a computed intermediate or KV.
    # Model weights are streamed again by AXI4 DMA with an explicit fence.
    image0 = read_pairs(stage0 / "model_memory.memh")
    image1 = read_pairs(stage1 / "model_memory.memh")
    reload_tensors = [tensor for tensor in b.values()
                      if tensor["initialized"] and "weight" not in tensor["name"]
                      and "kv_attention_" not in tensor["name"]]
    input_pairs = sorted({addr: image1[addr]
                          for tensor in reload_tensors
                          for addr in range(tensor["start"], tensor["end_exclusive"], 4)}.items())
    if any(addr not in image0 for addr, _ in input_pairs):
        raise ValueError("stage0 embedding layout does not match stage1")
    write_words(out / "stage1_input.memh",
                [len(input_pairs), *(word for pair in input_pairs for word in pair)])
    desc_base = second["descriptor_base"]
    desc_words = [image1[desc_base + index * 64 + word * 4]
                  for index in range(second["descriptor_count"])
                  for word in range(16)]
    write_words(out / "stage1_descriptors.memh",
                [second["descriptor_count"], *desc_words])
    cache_words = []
    stage0_golden = read_pairs(stage0 / "model_golden.memh")
    for kind in ("k", "v"):
        base = a[f"l0.kv_attention_{kind}_cache_i8"]["start"]
        cache_words.extend((base + offset, stage0_golden[base + offset])
                           for offset in range(0, 1024, 4))
    write_words(out / "stage0_cache.memh",
                [len(cache_words), *(word for pair in cache_words for word in pair)])
    if first["descriptor_count"] + second["descriptor_count"] <= first["queue_size"]:
        raise ValueError("G1 would not exercise a queue wrap")
    publication = Runtime(first["queue_size"], first["descriptor_count"]).publication(
        second["descriptor_count"])
    if not any(item["ring_slot"] == 0 for item in publication):
        raise ValueError("G1 publication did not wrap CMDQ/CPLQ")
    stage0_checked = compare_reference(stage0, reference0, 1)
    stage1_checked = compare_reference(stage1, reference, 2)
    contract = {
        "status": "PLANNER_READY_NOT_RTL_PASS", "seed": seed, "tokens": tokens,
        "model_sha256": first["canonical_model_sha256"],
        "stage0_descriptors": first["descriptor_count"],
        "stage1_descriptors": second["descriptor_count"],
        "queue_size": first["queue_size"], "descriptor_base": desc_base,
        "completion_base": first["completion_base"],
        "stage1_host_input_words": len(input_pairs),
        "stage1_reloaded_fixture_tensors": [tensor["name"] for tensor in reload_tensors],
        "stage1_dma_weight_bytes": second["dma_weight_streaming"]["payload_bytes"],
        "stage1_host_intermediate_words": 0,
        "stage1_host_kv_words": 0,
        "stage0_valid_tokens": 1,
        "stage1_valid_tokens": 2,
        "stage0_reference_words": stage0_checked,
        "stage1_full_recompute_reference_words": stage1_checked,
        "cache_addresses": {kind: a[f"l0.kv_attention_{kind}_cache_i8"]["start"]
                            for kind in ("k", "v")},
        "initial_image_sha256": first["memory_sha256"],
        "stage1_input_sha256": hashlib.sha256((out / "stage1_input.memh").read_bytes()).hexdigest(),
        "stage1_descriptor_sha256": hashlib.sha256((out / "stage1_descriptors.memh").read_bytes()).hexdigest(),
        "stage0_cache_sha256": hashlib.sha256((out / "stage0_cache.memh").read_bytes()).hexdigest(),
        "execution_boundary": "stage0 complete and all CPLQ entries retired before stage1 publication",
        "cache_dependencies": dependencies,
        "runtime_publication": publication,
        "host_roles": ["teacher-forced token ID", "input embedding/position and initial constants",
                       "AXI4 DMA model-weight reload"],
    }
    (out / "token_plan.json").write_text(json.dumps(contract, indent=2) + "\n")
    return contract


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=20261116)
    parser.add_argument("--tokens", default="1,7")
    args = parser.parse_args()
    plan = prepare(args.out, args.seed, [int(token) for token in args.tokens.split(",")])
    print("H64_TOKEN_PLANNER_PASS " + json.dumps(plan, sort_keys=True))


if __name__ == "__main__":
    main()
