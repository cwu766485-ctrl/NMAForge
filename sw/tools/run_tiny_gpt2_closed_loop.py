#!/usr/bin/env python3
"""Replay the Top incremental-decode regression as a host-feedback token loop.

The Top still resets between iterations: each pass replays prefill and the
already-produced prefix, then the next input token is selected from the prior
Top logits. This is a bounded functional closed loop, not persistent-session
throughput measurement.
"""
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


def tensor_logits(observed: dict[int, int], manifest: dict,
                  names: list[str]) -> list[int]:
    values: list[int] = []
    for name in names:
        base = int(manifest["tensors"][name]["address"])
        values.extend(signed32(observed[base + 4 * i]) for i in range(16))
    return values


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--simv", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--seed", type=int, default=20261123)
    parser.add_argument("--steps", type=int, choices=(4, 8, 12, 16), default=8)
    args = parser.parse_args()
    model_bytes = args.model.read_bytes()
    model = json.loads(model_bytes)
    args.out.mkdir(parents=True, exist_ok=False)
    prompt = [int(v) for v in model["prompt_and_targets"][:5]]
    input_history = [prompt[4]]
    records = []
    window_outputs: list[int] = []

    for step in range(args.steps):
        local_step = step % 4
        if local_step == 0:
            window_outputs = []
            window_input_token = input_history[-1]
        if step < 4:
            prefill_tokens = prompt[:4]
        else:
            prefill_tokens = input_history[-5:-1]
        if len(prefill_tokens) != 4:
            raise RuntimeError("insufficient token history for the rolling prefill window")
        run_dir = args.out / f"feedback_{step}"
        workload = run_dir / "workload"
        workload.mkdir(parents=True)
        log_path = run_dir / "run.log"
        decode_tokens = [window_input_token] + window_outputs
        decode_tokens += [0] * (4 - len(decode_tokens))
        command = [sys.executable,
                   str(Path(__file__).with_name("generate_h16_incremental_decode.py")),
                   "--model", str(args.model), "--out", str(workload),
                   "--prefill-tokens", ",".join(map(str, prefill_tokens)),
                   "--decode-tokens", ",".join(map(str, decode_tokens))]
        with log_path.open("w") as log:
            subprocess.run(command, check=True, stdout=log, stderr=subprocess.STDOUT)
        sim_command = [str(args.simv), f"+ntb_random_seed={args.seed}",
                       "+AI_RANDOM_CASES=0", f"+AI_SEED={args.seed}",
                       "+ACLK_PERIOD_NS=4", "+AI_H16_INCREMENTAL_DECODE",
                       "+AI_H16_USEFUL_MACS_EXTRA=512",
                       f"+AI_H16_INCREMENTAL_DIR={workload}", "-l", str(log_path)]
        with log_path.open("a") as log:
            subprocess.run(sim_command, check=True, stdout=log, stderr=subprocess.STDOUT)
        log_text = log_path.read_text(errors="replace")
        if "INCREMENTAL_DECODE_PASS" not in log_text:
            raise RuntimeError(f"Top regression did not PASS: {log_path}")

        manifest = json.loads((workload / "manifest.json").read_text())
        position = 4 + local_step
        stage_index = local_step + 1
        stage_name = f"decode_t{position}"
        stage = manifest["stages"][stage_index]
        names = manifest["tokens"][local_step]["logits_tensor_names"]
        observed = read_pairs(workload / f"stage_{stage_index}_{stage_name}_observed.memh")
        top_logits = tensor_logits(observed, manifest, names)

        cache = init_cache(model, prefill_tokens)
        reference_trace = None
        for prior_position in range(4, position + 1):
            token_index = prior_position - 4
            reference_trace = decode_one(
                model, cache, decode_tokens[token_index], prior_position)
        assert reference_trace is not None
        ref_logits = [int(value) for value in reference_trace["logits"]]
        if top_logits != ref_logits:
            mismatch = next(i for i, (a, b) in enumerate(zip(top_logits, ref_logits))
                            if a != b)
            raise RuntimeError(
                f"independent reference mismatch at decode position {position}, "
                f"logit {mismatch}: ref={ref_logits[mismatch]} top={top_logits[mismatch]}"
            )
        next_token = max(range(len(top_logits)), key=lambda i: (top_logits[i], -i))
        logits_bytes = b"".join(int(value).to_bytes(4, "little", signed=True)
                                 for value in top_logits)
        match = re.search(
            rf"INCREMENTAL_H16_STAGE_PASS stage={stage_name} .*?cycles=(\d+).*?"
            rf"matrix_mac=(\d+).*?sfu=(\d+).*?kv=(\d+).*?"
            rf"spad_read_bytes=(\d+).*?spad_write_bytes=(\d+)", log_text)
        if not match:
            raise RuntimeError(f"missing Top profile for {stage_name}: {log_path}")
        cycles, matrix, sfu, kv, read_bytes, write_bytes = map(int, match.groups())
        useful_macs = int(manifest["tokens"][local_step]["useful_macs"])
        records.append({
            "step": step, "window": step // 4, "position_in_window": position,
            "prefill_tokens": prefill_tokens,
            "input_token": decode_tokens[local_step], "generated_token": next_token,
            "top_reference_logits_bit_exact": True,
            "top_logits_i32": top_logits,
            "independent_reference_logits_i32": ref_logits,
            "logits_sha256": hashlib.sha256(logits_bytes).hexdigest(),
            "kv_after_sha256": manifest["tokens"][local_step]["kv_after_sha256"],
            "final_tensor_row0_int32": manifest["tokens"][local_step][
                "final_tensor_row0_int32"],
            "descriptor_sha256": stage["descriptor_sha256"],
            "golden_sha256": stage["golden_sha256"],
            "top_golden": "PASS", "cycles": cycles,
            "useful_macs": useful_macs,
            "useful_macs_per_cycle": round(useful_macs / cycles, 6),
            "matrix_active_cycles": matrix, "sfu_busy_cycles": sfu,
            "kv_busy_cycles": kv, "spad_read_bytes": read_bytes,
            "spad_write_bytes": write_bytes,
            "descriptor_count": stage["descriptor_count"],
            "log_path": f"feedback_{step}/run.log",
        })
        input_history.append(next_token)
        window_outputs.append(next_token)

    payload = {
        "status": "HOST_FEEDBACK_INCREMENTAL_TOP_PASS",
        "model_sha256": hashlib.sha256(model_bytes).hexdigest(),
        "source_sha": subprocess.check_output(
            ["git", "-C", str(Path(__file__).resolve().parents[2]),
             "rev-parse", "HEAD"], text=True).strip(),
        "seed": args.seed,
        "prefill_tokens": prompt[:4],
        "host_supplied_seed_token": prompt[4],
        "generated_tokens": input_history[1:],
        "feedback_input_tokens": input_history,
        "reset_between_steps": True,
        "context_policy": "rolling window: prefill the four preceding input tokens into positions 0..3, then process current token at position 4; this is bounded local-context generation, not full-history context beyond capacity 8",
        "measurement_note": "Per-step Top cycles exclude host feedback and replay; each run replays prefill and prior prefix. A fresh Top run is used for every generated token.",
        "steps": records,
    }
    result_path = args.out / "closed_loop_results.json"
    result_path.write_text(json.dumps(payload, indent=2) + "\n")
    with (args.out / "closed_loop_results.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(records[0]))
        writer.writeheader()
        writer.writerows(records)
    print("TINY_GPT2_CLOSED_LOOP_TOP_PASS "
          f"steps={len(records)} generated={payload['generated_tokens']} "
          f"model_sha256={payload['model_sha256']} out={args.out}")


if __name__ == "__main__":
    main()
