#!/usr/bin/env python3
"""Prepare a bounded four-layer H64 Product-Top autoregressive session.

The expected next token is derived from the independent software model only
to build/check the run plan.  The testbench must select its own token from
actual Product-Top SPAD logits and compare it with this expected token before
writing only the corresponding embedding and position input rows.
"""
from __future__ import annotations

import argparse
import json
import sys
import tempfile
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "benchmark/gpt2_compat"))
from prepare_h64_four_layer import build, read_pairs, write_pairs, write_words  # noqa: E402


def signed32(word: int) -> int:
    word &= 0xFFFFFFFF
    return word - (1 << 32) if word & 0x80000000 else word


def argmax_lowest(values: list[int]) -> int:
    best = 0
    for index in range(1, len(values)):
        if values[index] > values[best]:
            best = index
    return best


def final_logits(run: Path, row: int) -> list[int]:
    manifest = json.loads((run / "four_layer_manifest.json").read_text())
    logits = next(x for x in manifest["allocation_records"]
                  if x["tensor_id"] == "logits_i32_physical_16x256")
    image = read_pairs(run / "stage3/model_golden.memh")
    values = []
    for index in range(256):
        tile, column = divmod(index, 16)
        address = logits["start"] + (tile * 256 + row * 16 + column) * 4
        if address not in image:
            raise ValueError(f"software Golden lacks final logit at {address:#x}")
        values.append(signed32(image[address]))
    return values


def checkpoint_record(run: Path, layer: int, tensor_id: str) -> dict[int, int]:
    stage = run / f"stage{layer}"
    manifest = json.loads((stage / "manifest.json").read_text())
    specs = {x["tensor_id"]: x for x in manifest["intermediate_checkpoints"]}
    spec = specs[tensor_id]
    words = [int(line, 16) for line in
             (stage / "checkpoint_golden.memh").read_text().splitlines()]
    cursor = 1
    for _ in specs:
        descriptor, count = words[cursor:cursor + 2]
        cursor += 2
        pairs = {words[cursor + i * 2]: words[cursor + i * 2 + 1]
                 for i in range(count)}
        cursor += count * 2
        if descriptor == spec["descriptor_index"] and count == spec["golden_words"]:
            if len(pairs) != count:
                raise ValueError(f"duplicate address in checkpoint {tensor_id}")
            return pairs
    raise ValueError(f"checkpoint record not found: {tensor_id}")


def cache_words_for_layer(run: Path, layer: int) -> dict[str, list[int]]:
    """Reconstruct physical cache words from Product KV_READ Golden records."""
    result = {"k": [], "v": []}
    for kind in ("k", "v"):
        for head in range(4):
            record = checkpoint_record(
                run, layer, f"l0.kv_attention_{kind}_read_h{head}")
            if len(record) != 64:
                raise ValueError(f"KV readback shape invalid: {kind} head {head}")
            result[kind].extend(value for _, value in sorted(record.items()))
    return result


def patch_cache_before(previous: Path, current: Path) -> None:
    current_manifest = json.loads((current / "four_layer_manifest.json").read_text())
    for layer in range(4):
        pairs: dict[int, int] = {}
        cache = cache_words_for_layer(previous, layer)
        for kind in ("k", "v"):
            record = next(x for x in current_manifest["allocation_records"]
                          if x["tensor_id"] == f"l{layer}.kv_{kind}_cache_i8")
            values = cache[kind]
            if len(values) != record["size_bytes"] // 4:
                raise ValueError(f"layer {layer} {kind} cache word count mismatch")
            for index, value in enumerate(values):
                pairs[record["start"] + index * 4] = value
        write_pairs(current / f"stage{layer}/cache_before.memh", pairs)


def compare_with_prefix_recompute(incremental: Path, seed: int,
                                  tokens: list[int], model_override: dict | None,
                                  numeric_profile: str, active_rows: bool = False) -> int:
    """Check every Product checkpoint against a fresh full-prefix Golden.

    In active-row mode the incremental checkpoints cover only the new token
    row (plus complete KV readbacks); every checked word must still exist in
    and equal the independent fixed-row prefix-recompute Golden.
    """
    with tempfile.TemporaryDirectory(prefix="nmaforge_h64_kv_reference_") as temp:
        reference = Path(temp) / "prefix"
        build(reference, seed, tokens, model_override, numeric_profile)
        compared = 0
        for layer in range(4):
            manifest = json.loads((incremental / f"stage{layer}/manifest.json").read_text())
            for spec in manifest["intermediate_checkpoints"]:
                name = spec["tensor_id"]
                got = checkpoint_record(incremental, layer, name)
                want = checkpoint_record(reference, layer, name)
                if active_rows:
                    if not got:
                        raise ValueError(f"active-row checkpoint is empty: layer={layer} tensor={name}")
                    mismatch = [addr for addr, value in got.items() if want.get(addr) != value]
                    if mismatch:
                        address = mismatch[0]
                        raise ValueError(
                            f"active-row incremental differs from prefix recompute: "
                            f"layer={layer} tensor={name} address={address:#x} "
                            f"incremental={got.get(address)} prefix={want.get(address)}")
                elif got != want:
                    address = next((addr for addr in sorted(set(got) | set(want))
                                    if got.get(addr) != want.get(addr)), None)
                    raise ValueError(
                        f"incremental KV differs from prefix recompute: "
                        f"layer={layer} tensor={name} address={address:#x} "
                        f"incremental={got.get(address)} prefix={want.get(address)}")
                compared += len(got)
        return compared


def build_session(out: Path, seed: int, prompt: list[int], generated: int,
                  model_override: dict | None = None,
                  numeric_profile: str = "frozen",
                  kv_mode: str = "prefix_recompute",
                  active_rows: bool = False) -> dict:
    if len(prompt) != 4 or generated < 1 or len(prompt) + generated > 16:
        raise ValueError("requires a four-token prompt and 1..12 generated tokens")
    if kv_mode not in {"prefix_recompute", "persistent_incremental"}:
        raise ValueError("invalid KV execution mode")
    if any(token < 0 or token > 255 for token in prompt):
        raise ValueError("token IDs must be in [0,255]")
    current_tokens = list(prompt)
    current_dir = out
    current_manifest = build(current_dir, seed, current_tokens, model_override,
                             numeric_profile, kv_append_from=0,
                             active_rows=active_rows)
    raw_model = np.load(current_dir / "raw_layer0/canonical_h64_model.npz")
    embedding = raw_model["embedding"].astype(np.int32)
    position = raw_model["position"].astype(np.int32)
    generated_tokens: list[int] = []
    records = []
    feedback_words = [generated]

    for step in range(generated):
        logits_row = len(current_tokens) - 1
        context_snapshot = list(current_tokens)
        logits = final_logits(current_dir, logits_row)
        selected = argmax_lowest(logits)
        generated_tokens.append(selected)
        input_position = len(current_tokens)
        if input_position >= position.shape[0]:
            raise ValueError("position table does not cover requested generation")
        next_tokens = current_tokens + [selected]
        feedback_words.extend((selected, input_position, len(next_tokens)))
        # Prefix-recompute reuses the embedding scratch allocation for later
        # LayerNorm/KV tensors. Restore every valid input row before the next
        # run; publishing only the newly generated row would leave the prompt
        # rows overwritten by the previous Product-Top invocation.
        for input_row, token in enumerate(next_tokens):
            feedback_words.extend(int(x) & 0xFFFFFFFF for x in embedding[token])
            feedback_words.extend(int(x) & 0xFFFFFFFF for x in position[input_row])
        records.append({"step": step, "context_tokens": context_snapshot,
                        "logits_row": logits_row, "expected_argmax_token": selected,
                        "argmax_rule": "signed INT32; lowest token ID wins ties"})
        if step + 1 == generated:
            break
        current_tokens.append(selected)
        next_dir = out / f"context{step + 1}"
        if kv_mode == "persistent_incremental":
            cache_before = {layer: cache_words_for_layer(current_dir, layer)
                            for layer in range(4)}
            append_from = len(current_tokens) - 1
        else:
            cache_before = None
            append_from = 0
        next_manifest = build(
            next_dir, seed, current_tokens, model_override, numeric_profile,
            kv_append_from=append_from,
            kv_cache_before_by_layer=cache_before,
            active_rows=active_rows,
        )
        previous_allocations = {item["tensor_id"]: item
                                for item in current_manifest["allocation_records"]}
        next_allocations = {item["tensor_id"]: item
                            for item in next_manifest["allocation_records"]}
        for layer in range(4):
            for kind in ("k", "v"):
                tensor_id = f"l{layer}.kv_{kind}_cache_i8"
                if previous_allocations[tensor_id]["start"] != next_allocations[tensor_id]["start"]:
                    raise ValueError(f"persistent KV address moved between contexts: {tensor_id}")
        equivalent_words = 0
        if kv_mode == "persistent_incremental":
            equivalent_words = compare_with_prefix_recompute(
                next_dir, seed, current_tokens, model_override, numeric_profile,
                active_rows)
        patch_cache_before(current_dir, next_dir)
        records[-1]["next_context"] = str(next_dir.relative_to(out))
        records[-1]["kv_append_from"] = append_from
        records[-1]["prefix_recompute_equivalent_words"] = equivalent_words
        records[-1]["cache_before_sha256"] = {
            f"layer{layer}": __import__("hashlib").sha256(
                (next_dir / f"stage{layer}/cache_before.memh").read_bytes()).hexdigest()
            for layer in range(4)}
        current_dir, current_manifest = next_dir, next_manifest

    feedback_path = out / "feedback_plan.memh"
    write_words(feedback_path, feedback_words)
    plan = {
        "status": "PLANNER_READY_REQUIRES_PRODUCT_TOP_AUTOREGRESSIVE_PASS",
        "mode": ("four_layer_persistent_incremental_kv_same_top_instance"
                 if kv_mode == "persistent_incremental" else
                 "four_layer_prefix_recompute_same_top_instance"),
        "kv_mode": kv_mode,
        "row_mapping": ("active_rows_new_token_only" if active_rows else "fixed_16_row_tiles"),
        "seed": seed,
        "prompt_tokens": prompt,
        "expected_generated_tokens": generated_tokens,
        "model_sha256": current_manifest["model_sha256"],
        "numeric_profile": numeric_profile,
        "generated_steps": records,
        "feedback_plan": feedback_path.name,
        "host_roles": ["read actual RTL logits", "signed INT32 argmax with lowest-ID tie break",
                       "token embedding/position input lookup only"],
        "host_intermediate_tensor_writes": 0,
        "cache_policy": ("each decode context imports no KV data from host, verifies all prior physical KV words, appends only the newly generated token K/V in Product Top, and checks every layer checkpoint against an independent prefix-recompute Golden"
                         if kv_mode == "persistent_incremental" else
                         "each next-context run verifies all prior physical KV words before prefix recompute; Product KV_READ checkpoints verify recomputed cache contents"),
        "quality_scope": ("deterministic synthetic weights; functional autoregressive loop only, no language-model quality claim"
                          if model_override is None else
                          "GPT-2-derived truncated/requantized weights; functional autoregressive loop only, no language-model quality claim"),
    }
    (out / "autoregressive_plan.json").write_text(json.dumps(plan, indent=2) + "\n")
    print("H64_AUTOREGRESSIVE_PLAN_READY " + json.dumps({
        "prompt": prompt, "generated": generated_tokens,
        "contexts": generated, "model_sha256": plan["model_sha256"],
        "status": plan["status"]}, sort_keys=True))
    return plan


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=20261116)
    parser.add_argument("--prompt", default="1,7,42,3")
    parser.add_argument("--generated", type=int, default=4)
    parser.add_argument("--model-npz", type=Path,
                        help="optional canonical H64 model package; omit for synthetic regression")
    parser.add_argument("--numeric-profile", choices=("frozen", "round21_residual_gelu_aligned"),
                        default="frozen", help="fixed-point projection/GELU contract")
    parser.add_argument("--kv-mode", choices=("prefix_recompute", "persistent_incremental"),
                        default="prefix_recompute")
    parser.add_argument("--active-rows", action="store_true",
                        help="map row-wise SFU work to the context's new token rows only")
    args = parser.parse_args()
    prompt = [int(item, 0) for item in args.prompt.split(",") if item]
    model_override = None
    if args.model_npz is not None:
        with np.load(args.model_npz, allow_pickle=False) as archive:
            model_override = {name: archive[name] for name in archive.files}
    build_session(args.out, args.seed, prompt, args.generated, model_override,
                  args.numeric_profile, args.kv_mode, args.active_rows)


if __name__ == "__main__":
    main()
