#!/usr/bin/env python3
"""Independent integer reference for the exported H16 Tiny decoder.

This file intentionally does not import the NMAForge mapper or A3 reference.
It models the declared saturated INT8 GEMM, Q15 causal softmax, LayerNorm,
piecewise GELU, residual and KV append/read contracts in scalar Python.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

I32_MIN, I32_MAX = -(1 << 31), (1 << 31) - 1


def clamp(x: int, low: int, high: int) -> int:
    return min(max(int(x), low), high)


def trunc_div(a: int, b: int) -> int:
    return a // b if a >= 0 else -((-a) // b)


def sat_i8(x: int) -> int:
    return clamp(x, -128, 127)


def dot(a: list[int], b: list[int], shift: int = 0) -> int:
    return clamp(sum(int(x) * int(y) for x, y in zip(a, b)) >> shift,
                 I32_MIN, I32_MAX)


def matvec(x: list[int], w: list[list[int]], shift: int = 0) -> list[int]:
    return [dot(x, [w[k][n] for k in range(len(x))], shift)
            for n in range(len(w[0]))]


def exp2_q15(delta: int) -> int:
    if delta >= 0:
        return 32768
    magnitude = -delta
    integer, fraction = magnitude >> 8, magnitude & 255
    if integer >= 15:
        return 0
    base = 32768 >> integer
    return base - (((base - (base >> 1)) * fraction) >> 8)


def softmax_q15(values: list[int]) -> list[int]:
    peak = max(values)
    terms = [exp2_q15(v - peak) for v in values]
    total = sum(terms)
    if not total:
        raise ArithmeticError("softmax denominator is zero")
    return [clamp((term << 15) // total, 0, 32768) for term in terms]


def layer_norm(x: list[int], gamma_q15: list[int], beta: list[int]) -> list[int]:
    mean = trunc_div(sum(x), len(x))
    variance = sum((v - mean) * (v - mean) for v in x) // len(x)
    root = max(math.isqrt(variance + 1), 1)
    reciprocal_q30 = (1 << 30) // root
    output = []
    for value, gamma, offset in zip(x, gamma_q15, beta):
        scaled = clamp(((value - mean) * gamma) >> 15, I32_MIN, I32_MAX)
        normalized = (scaled * reciprocal_q30) >> 30
        output.append(clamp(normalized + offset, I32_MIN, I32_MAX))
    return output


def gelu_q8_8(v: int) -> int:
    if v <= -512:
        return 0
    if v >= 512:
        return clamp(v, I32_MIN, I32_MAX)
    return clamp((v * (v + 512)) >> 10, I32_MIN, I32_MAX)


def requant(x: list[int], shift: int) -> list[int]:
    return [sat_i8(v >> shift) for v in x]


def word_input(model: dict, token: int, position: int) -> list[int]:
    words = model["embeddings"][token]
    positions = model["position_embeddings"][position]
    return [sat_i8(a + b) for a, b in zip(words, positions)]


def project(x: list[int], weight: list[list[int]], shift: int) -> list[int]:
    return requant(matvec(x, weight, shift), 0)


def qkv_for_token(model: dict, x: list[int]) -> tuple[list[list[int]], list[list[int]], list[list[int]]]:
    w, shifts = model["weights"], model["gemm_shifts"]
    full = {name: project(x, w[f"w{name}"], shifts["qkv"])
            for name in ("q", "k", "v")}
    q_heads = [full["q"][h * 8:(h + 1) * 8] for h in range(2)]
    k_heads = [full["k"][h * 8:(h + 1) * 8] for h in range(2)]
    v_heads = [full["v"][h * 8:(h + 1) * 8] for h in range(2)]
    return q_heads, k_heads, v_heads


def append_kv(model: dict, cache: dict, token: int, position: int) -> tuple[list[list[int]], list[list[int]], list[int]]:
    x = word_input(model, token, position)
    q, k, v = qkv_for_token(model, x)
    for head in range(2):
        cache["k"][head][position] = k[head][:]
        cache["v"][head][position] = v[head][:]
    return q, k, v, x


def init_cache(model: dict, prefill: list[int]) -> dict:
    cache = {"k": [[[0] * 8 for _ in range(8)] for _ in range(2)],
             "v": [[[0] * 8 for _ in range(8)] for _ in range(2)]}
    for position, token in enumerate(prefill):
        append_kv(model, cache, token, position)
    return cache


def decode_one(model: dict, cache: dict, token: int, position: int) -> dict:
    w, shifts = model["weights"], model["gemm_shifts"]
    q_heads, k_heads, v_heads, x = append_kv(model, cache, token, position)
    scores, probabilities, avs, projected = [], [], [], []
    merged = [0] * 16
    for head in range(2):
        score = [dot(q_heads[head], cache["k"][head][t], shifts["qk"])
                 for t in range(position + 1)]
        prob = softmax_q15(score)
        prob8 = requant(prob, 8)
        av = [dot(prob8, [cache["v"][head][t][feature]
                         for t in range(position + 1)], 0)
              for feature in range(8)]
        av8 = requant(av, 7)
        wo_panel = w["wo"][head * 8:(head + 1) * 8]
        # The matrix is [input feature, output feature] in the exported contract.
        out = [dot(av8, [wo_panel[k][n] for k in range(8)], shifts["wo"])
               for n in range(16)]
        scores.append(score)
        probabilities.append(prob)
        avs.append(av)
        projected.append(out)
        merged = [clamp(a + b, I32_MIN, I32_MAX) for a, b in zip(merged, out)]

    residual1 = [clamp(a + b, I32_MIN, I32_MAX) for a, b in zip(merged, x)]
    norm1 = layer_norm(residual1, model["gamma1_q15"], model["beta1"])
    norm1_i8 = requant(norm1, 0)
    ffn_up = matvec(norm1_i8, w["wup"], shifts["wup"])
    gelu = [gelu_q8_8(v) for v in ffn_up]
    gelu_i8 = requant(gelu, 0)
    ffn_down = matvec(gelu_i8, w["wdown"], shifts["wdown"])
    residual2 = [clamp(a + b, I32_MIN, I32_MAX)
                 for a, b in zip(ffn_down, norm1)]
    norm2 = layer_norm(residual2, model["gamma2_q15"], model["beta2"])
    norm2_i8 = requant(norm2, 0)
    logits = matvec(norm2_i8, w["lm_head"], shifts["lm_head"])
    return {
        "input_i8": x, "q_i8": q_heads, "k_i8": k_heads, "v_i8": v_heads,
        "scores": scores, "probabilities_q15": probabilities, "av_i32": avs,
        "head_projection_i32": projected, "merged_i32": merged,
        "residual1_i32": residual1, "layernorm1_i32": norm1,
        "layernorm1_i8": norm1_i8, "ffn_up_i32": ffn_up,
        "gelu_i32": gelu, "gelu_i8": gelu_i8, "ffn_down_i32": ffn_down,
        "residual2_i32": residual2, "layernorm2_i32": norm2,
        "layernorm2_i8": norm2_i8, "logits": logits,
        "kv_cache": cache,
    }


def signed32(word: int) -> int:
    word &= 0xFFFFFFFF
    return word - (1 << 32) if word & 0x80000000 else word


def read_pairs(path: Path) -> dict[int, int]:
    words = [int(line, 16) for line in path.read_text().splitlines()]
    if len(words) != 1 + 2 * words[0]:
        raise ValueError(f"bad address/value image {path}")
    return dict(zip(words[1::2], words[2::2]))


def run_quality(model: dict, sequences: list[list[int]]) -> dict:
    correct = total = 0
    nll = 0.0
    for seq in sequences:
        cache = init_cache(model, seq[:4])
        for position in range(4, 8):
            result = decode_one(model, cache, seq[position], position)
            logits = result["logits"]
            target = seq[position + 1]
            peak = max(logits)
            expv = [math.exp((v - peak) / 8.0) for v in logits]
            nll -= math.log(max(expv[target] / sum(expv), 1.0e-300))
            correct += max(range(len(logits)), key=lambda i: (logits[i], -i)) == target
            total += 1
    return {"tokens": total, "next_token_accuracy": correct / total,
            "cross_entropy_nats": nll / total, "perplexity": math.exp(nll / total)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--seed", type=int, default=20261125)
    parser.add_argument("--test-sequences", type=int, default=1024)
    args = parser.parse_args()
    model = json.loads(args.model.read_text())
    # Generate the held-out sequence split with the trainer's deterministic rule
    # without importing torch or any mapper/Golden implementation.
    import random
    rng = random.Random(model["seed"] + 2)
    sequences = []
    for _ in range(args.test_sequences):
        mode, state = rng.randrange(4), rng.randrange(28)
        seq = [mode, state + 4]
        for position in range(2, 9):
            state = (state + mode * 5 + position * 3) % 28
            seq.append(state + 4)
        sequences.append(seq)
    quality = run_quality(model, sequences)
    sample = model["prompt_and_targets"]
    cache = init_cache(model, sample[:4])
    steps = []
    for position in range(4, 8):
        trace = decode_one(model, cache, sample[position], position)
        predicted = max(range(len(trace["logits"])), key=lambda i: (trace["logits"][i], -i))
        steps.append({"position": position, "input_token": sample[position],
                      "target_token": sample[position + 1], "predicted_token": predicted,
                      "logits": trace["logits"], "trace": trace})
    # Output a compact reference bundle. Full numeric tensors are retained for
    # the fixed prompt and all four incremental steps.
    bundle = {
        "status": "INDEPENDENT_INT8_REFERENCE_PASS",
        "model_sha256": hashlib.sha256(args.model.read_bytes()).hexdigest(),
        "heldout_sequences": len(sequences), "heldout_quality": quality,
        "generation_prompt": sample[:5],
        "generation_tokens": [step["predicted_token"] for step in steps],
        "teacher_forced_steps": steps,
        "reference_contract": "scalar Python implementation; no CIMForge mapper or A3 reference imports",
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(bundle, indent=2) + "\n")
    print("TINY_GPT2_INT8_REFERENCE_PASS "
          f"heldout_accuracy={quality['next_token_accuracy']:.6f} "
          f"heldout_ppl={quality['perplexity']:.4f} "
          f"generation={bundle['generation_tokens']} out={args.out}")


if __name__ == "__main__":
    main()
