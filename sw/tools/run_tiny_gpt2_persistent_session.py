#!/usr/bin/env python3
"""Run one persistent Top simulation for prefill plus a bounded KV-ring session."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

from reference_tiny_gpt2_int8 import decode_one, init_cache, read_pairs, signed32


def tensor_logits(observed: dict[int, int], manifest: dict, names: list[str]) -> list[int]:
    values: list[int] = []
    for name in names:
        base = int(manifest["tensors"][name]["address"])
        values.extend(signed32(observed[base + 4 * i]) for i in range(16))
    return values


OPCODE_NAMES = {
    0x30: "GEMM",
    0x34: "Residual",
    0x35: "GELU",
    0x36: "Requant",
    0x38: "LayerNorm",
    0x39: "Softmax",
    0x43: "KV_Write",
    0x44: "KV_Read",
}


def observed_kv_hash(observed: dict[int, int], manifest: dict) -> str:
    """Hash the physical SPAD cache words in the generator's canonical order."""
    cache_words: list[int] = []
    for head in range(2):
        for tensor_name in ("key_cache", "value_cache"):
            base = int(manifest["tensors"][tensor_name]["address"]) + head * 64
            cache_words.extend(observed[base + index * 4] for index in range(16))
    payload = b"".join((word & 0xFFFFFFFF).to_bytes(4, "little")
                       for word in cache_words)
    return hashlib.sha256(payload).hexdigest()


def token_sequence(seed_sequence: list[int], total: int = 12) -> list[int]:
    if len(seed_sequence) < 2:
        raise ValueError("model prompt must contain mode and state tokens")
    mode, state = int(seed_sequence[0]), int(seed_sequence[1]) - 4
    result = [mode, state + 4]
    for position in range(2, total):
        state = (state + mode * 5 + position * 3) % 28
        result.append(state + 4)
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--spad-bytes", type=int, default=128 * 1024)
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--simv", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--seed", type=int, default=20261123)
    parser.add_argument("--steps", type=int, choices=(1, 2, 3, 4, 5, 6, 7, 8), default=8)
    args = parser.parse_args()
    model_bytes = args.model.read_bytes()
    model = json.loads(model_bytes)
    args.out.mkdir(parents=True, exist_ok=False)

    sequence = token_sequence(model["prompt_and_targets"], 4 + args.steps)
    prefill = sequence[:4]
    decode_tokens = sequence[4:]
    workload = args.out / "workload"
    generator_cmd = [sys.executable,
                     str(Path(__file__).with_name("generate_h16_incremental_decode.py")),
                     "--model", str(args.model), "--out", str(workload),
                     "--spad-bytes", str(args.spad_bytes),
                     "--prefill-tokens", ",".join(map(str, prefill)),
                     "--decode-tokens", ",".join(map(str, decode_tokens))]
    generator_log = args.out / "generator.log"
    with generator_log.open("w") as stream:
        subprocess.run(generator_cmd, check=True, stdout=stream, stderr=subprocess.STDOUT)

    sim_log = args.out / "top_session.log"
    sim_cmd = [str(args.simv), f"+ntb_random_seed={args.seed}",
               "+AI_RANDOM_CASES=0", f"+AI_SEED={args.seed}",
               "+ACLK_PERIOD_NS=4", "+AI_H16_INCREMENTAL_DECODE",
               f"+AI_H16_DECODE_STEPS={args.steps}",
               "+AI_H16_USEFUL_MACS_EXTRA=512",
               f"+AI_H16_INCREMENTAL_DIR={workload}"]
    with sim_log.open("w") as stream:
        subprocess.run(sim_cmd, check=True, stdout=stream, stderr=subprocess.STDOUT)
    log_text = sim_log.read_text(errors="replace")
    if f"append_tokens={args.steps}" not in log_text or "persistent_session=1" not in log_text:
        raise RuntimeError("Top did not report the requested persistent session length")

    manifest = json.loads((workload / "manifest.json").read_text())
    cache = init_cache(model, prefill)
    rows = []
    opcode_rows = []
    for step, token in enumerate(decode_tokens):
        position = 4 + step
        stage_index = step + 1
        stage_name = f"decode_t{position}"
        record = manifest["tokens"][step]
        observed = read_pairs(workload / f"stage_{stage_index}_{stage_name}_observed.memh")
        if len(observed) != int(record["expected_tensor_words"]):
            raise RuntimeError(
                f"Golden word count mismatch position={position}: "
                f"observed={len(observed)} expected={record['expected_tensor_words']}"
            )
        top_logits = tensor_logits(observed, manifest, record["logits_tensor_names"])
        trace = decode_one(model, cache, token, position)
        reference_logits = [int(value) for value in trace["logits"]]
        if top_logits != reference_logits:
            mismatch = next(i for i, (a, b) in enumerate(zip(top_logits, reference_logits)) if a != b)
            raise RuntimeError(
                f"independent INT8 Golden mismatch position={position} index={mismatch} "
                f"top={top_logits[mismatch]} reference={reference_logits[mismatch]}"
            )
        actual_kv_sha = observed_kv_hash(observed, manifest)
        if actual_kv_sha != record["kv_after_sha256"]:
            raise RuntimeError(
                f"Top KV-cache mismatch position={position}: "
                f"observed={actual_kv_sha} expected={record['kv_after_sha256']}"
            )
        # The independent software cache uses logical arrays; the manifest hash
        # and observed hash above use the packed physical SPAD word order.
        reference_kv_sha = hashlib.sha256(json.dumps(
            trace["kv_cache"], sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        match = re.search(
            rf"INCREMENTAL_H16_STAGE_PASS stage={stage_name} .*?cycles=(\d+).*?"
            rf"matrix_mac=(\d+).*?sfu=(\d+).*?kv=(\d+).*?"
            rf"spad_read_bytes=(\d+).*?spad_write_bytes=(\d+)", log_text)
        if not match:
            raise RuntimeError(f"missing Top profile for {stage_name}")
        cycles, matrix, sfu, kv, read_bytes, write_bytes = map(int, match.groups())
        interval_re = re.compile(
            rf"R17_DESCRIPTOR_INTERVAL stage={stage_name} local_index=(\d+) "
            rf"task_id=(\d+) opcode=0x([0-9a-fA-F]+) cycles=(\d+)"
        )
        intervals = []
        for local_index, task_id, opcode_hex, interval_cycles in interval_re.findall(log_text):
            intervals.append((int(local_index), int(task_id), int(opcode_hex, 16),
                              int(interval_cycles)))
        if len(intervals) != int(record["descriptor_count"]):
            raise RuntimeError(
                f"descriptor profile count mismatch {stage_name}: "
                f"observed={len(intervals)} expected={record['descriptor_count']}"
            )
        if sum(item[3] for item in intervals) != cycles:
            raise RuntimeError(
                f"descriptor cycle closure failed {stage_name}: "
                f"sum={sum(item[3] for item in intervals)} stage={cycles}"
            )
        opcode_totals: dict[int, list[int]] = {}
        for local_index, task_id, opcode, interval_cycles in intervals:
            counts = opcode_totals.setdefault(opcode, [0, 0])
            counts[0] += 1
            counts[1] += interval_cycles
            opcode_rows.append({
                "position": position, "stage": stage_name,
                "local_index": local_index, "task_id": task_id,
                "opcode": f"0x{opcode:02x}",
                "opcode_name": OPCODE_NAMES.get(opcode, "Unknown"),
                "descriptor_cycles": interval_cycles,
            })
        logits_bytes = b"".join(int(value).to_bytes(4, "little", signed=True)
                                 for value in top_logits)
        rows.append({
            "step": step, "absolute_position": position,
            "cache_position": position % 8, "visible_tokens": min(position + 1, 8),
            "host_input_token": token,
            "top_logits_bit_exact": True,
            "top_logits_sha256": hashlib.sha256(logits_bytes).hexdigest(),
            "top_kv_physical_sha256": actual_kv_sha,
            "expected_kv_physical_sha256": record["kv_after_sha256"],
            "reference_kv_logical_json_sha256": reference_kv_sha,
            "reference_logits_i32": reference_logits,
            "cycles": cycles, "matrix_active_cycles": matrix,
            "sfu_busy_cycles": sfu, "kv_busy_cycles": kv,
            "spad_read_bytes": read_bytes, "spad_write_bytes": write_bytes,
            "descriptor_count": record["descriptor_count"],
            "golden_words": record["expected_tensor_words"],
            **{f"opcode_{opcode:02x}_cycles": counts[1]
               for opcode, counts in sorted(opcode_totals.items())},
        })

    csv_path = args.out / "persistent_decode.csv"
    with csv_path.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    opcode_csv = args.out / "opcode_profile.csv"
    with opcode_csv.open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(opcode_rows[0]))
        writer.writeheader()
        writer.writerows(opcode_rows)
    opcode_totals: dict[int, list[int]] = {}
    for row in opcode_rows:
        opcode = int(row["opcode"], 16)
        counts = opcode_totals.setdefault(opcode, [0, 0])
        counts[0] += 1
        counts[1] += int(row["descriptor_cycles"])
    profile = {
        "status": "PASS_CLOSED_DESCRIPTOR_INTERVALS",
        "descriptor_count": len(opcode_rows),
        "decode_cycle_total": sum(row["cycles"] for row in rows),
        "decode_cycle_sum_from_descriptors": sum(
            row["descriptor_cycles"] for row in opcode_rows),
        "cycles_by_opcode": [
            {"opcode": f"0x{opcode:02x}",
             "name": OPCODE_NAMES.get(opcode, "Unknown"),
             "descriptor_count": counts[0], "cycles": counts[1],
             "fraction_of_decode_cycles": counts[1] / sum(row["cycles"] for row in rows)}
            for opcode, counts in sorted(opcode_totals.items())
        ],
        "stage_counter_note": "SFU Busy and Matrix Active are activity counters; they are reported separately and are not added to descriptor interval cycles.",
    }
    (args.out / "opcode_profile.json").write_text(json.dumps(profile, indent=2) + "\n")
    result = {
        "status": "PERSISTENT_TOP_DECODE_PASS",
        "model_sha256": hashlib.sha256(model_bytes).hexdigest(),
        "source_sha": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
        "seed": args.seed, "prefill_tokens": prefill,
        "host_supplied_decode_tokens": decode_tokens,
        "decode_steps": args.steps, "capacity_tokens": 8,
        "window_policy": "8-slot ring; overwrite oldest slot after full; position embedding wraps modulo 8",
        "session_boundary": "one VCS simv process, one initial SPAD/model load, one initial reset; command queues are re-armed between stages without resetting the DUT or clearing KV state",
        "feedback_mode": "teacher-forced host-supplied tokens from deterministic held-out synthetic task; logits are checked but are not dynamically returned to a live host process to choose the next token",
        "host_costs": "token generation/selection is modeled outside Top and excluded from simulated cycles; no embedding or Transformer intermediate is Host-computed",
        "average_decode_cycles": sum(row["cycles"] for row in rows) / len(rows),
        "total_decode_cycles": sum(row["cycles"] for row in rows),
        "runs": 1,
        "generator_command": generator_cmd,
        "sim_command": sim_cmd,
        "generator_log": "generator.log", "top_log": "top_session.log",
        "csv": csv_path.name, "opcode_csv": opcode_csv.name,
        "opcode_profile_json": "opcode_profile.json",
        "steps": rows,
    }
    json_path = args.out / "persistent_decode.json"
    json_path.write_text(json.dumps(result, indent=2) + "\n")
    print("TINY_GPT2_PERSISTENT_TOP_PASS "
          f"steps={args.steps} runs=1 mean_cycles={result['average_decode_cycles']:.2f} "
          f"model_sha256={result['model_sha256']} out={args.out}")


if __name__ == "__main__":
    main()
