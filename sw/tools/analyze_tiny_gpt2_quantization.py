#!/usr/bin/env python3
"""Layerwise FP32-vs-independent-INT8 analysis for the bounded H16 model.

This diagnostic retrains the documented deterministic FP32 model and runs the
scalar INT8 reference on the same held-out teacher-forced tokens. It does not
import Mapper or RTL scoreboard code.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import importlib.util
import json
import math
import random
from pathlib import Path

import torch
from torch.nn import functional as F


def load_trainer(path: Path):
    spec = importlib.util.spec_from_file_location("round24_tiny_gpt2_trainer", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"cannot import trainer: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def retrain(trainer, seed: int, epochs: int, train_sequences: int):
    torch.manual_seed(seed)
    random.seed(seed)
    torch.set_num_threads(1)
    torch.use_deterministic_algorithms(True)
    sequences = trainer.make_sequences(train_sequences, seed + 1)
    x = torch.tensor([s[:trainer.CONTEXT] for s in sequences], dtype=torch.long)
    y = torch.tensor([s[1:trainer.CONTEXT + 1] for s in sequences], dtype=torch.long)
    model = trainer.TinyPostLNDecoder()
    optimizer = torch.optim.AdamW(model.parameters(), lr=0.012, weight_decay=1.0e-4)
    for _ in range(epochs):
        model.train()
        order = torch.randperm(x.shape[0])
        for start in range(0, x.shape[0], 128):
            index = order[start:start + 128]
            logits = model.forward_float(x[index])
            loss = F.cross_entropy(logits.reshape(-1, trainer.VOCAB), y[index].reshape(-1))
            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimizer.step()
            with torch.no_grad():
                model.up.weight.clamp_(-0.48, 0.48)
    model.eval()
    return model


def float_trace(model, trainer, tokens: torch.Tensor) -> dict[str, torch.Tensor]:
    batch, length = tokens.shape
    positions = torch.arange(length)
    x0 = model.token_embedding(tokens) + model.position_embedding(positions)[None, :, :]
    q = model.q(x0).view(batch, length, trainer.HEADS, trainer.HEAD_DIM).transpose(1, 2)
    k = model.k(x0).view(batch, length, trainer.HEADS, trainer.HEAD_DIM).transpose(1, 2)
    v = model.v(x0).view(batch, length, trainer.HEADS, trainer.HEAD_DIM).transpose(1, 2)
    scores = torch.matmul(q, k.transpose(-1, -2)) / 4.0
    causal = torch.triu(torch.ones(length, length, dtype=torch.bool), diagonal=1)
    scores = scores.masked_fill(causal[None, None, :, :], float("-inf"))
    probs = torch.softmax(scores, dim=-1)
    av = torch.matmul(probs, v)
    merged = av.transpose(1, 2).contiguous().view(batch, length, trainer.HIDDEN)
    projections = []
    for head in range(trainer.HEADS):
        panel = model.wo.weight[:, head * trainer.HEAD_DIM:(head + 1) * trainer.HEAD_DIM]
        projections.append(torch.matmul(av[:, head], panel.transpose(0, 1)))
    head_proj = torch.stack(projections, dim=1)
    res1 = model.wo(merged) + x0
    ln1 = model.ln1(res1)
    up = model.up(ln1)
    gelu = F.gelu(up)
    down = model.down(gelu)
    res2 = down + ln1
    ln2 = model.ln2(res2)
    logits = model.lm_head(ln2)
    return {"embedding_position": x0, "q": q, "k": k, "v": v,
            "scores": scores, "probabilities": probs, "av": av,
            "head_projection": head_proj, "merged": model.wo(merged),
            "residual1": res1, "layernorm1": ln1, "layernorm1_i8": ln1,
            "ffn_up": up, "gelu": gelu, "gelu_i8": gelu,
            "ffn_down": down, "residual2": res2,
            "layernorm2": ln2, "layernorm2_i8": ln2, "logits": logits}


def q_vectors(trace: dict, position: int) -> dict[str, list[list[int]]]:
    result: dict[str, list[list[int]]] = {}
    result["embedding_position"] = [list(map(int, trace["input_i8"]))]
    for key in ("q_i8", "k_i8", "v_i8"):
        result[key[0]] = [list(map(int, row)) for row in trace[key]]
    result["scores"] = [list(map(int, row)) for row in trace["scores"]]
    result["probabilities"] = [list(map(int, row)) for row in trace["probabilities_q15"]]
    result["av"] = [list(map(int, row)) for row in trace["av_i32"]]
    result["head_projection"] = [list(map(int, row)) for row in trace["head_projection_i32"]]
    for key in ("merged_i32", "residual1_i32", "layernorm1_i32", "layernorm1_i8",
                "ffn_up_i32", "gelu_i32", "gelu_i8", "ffn_down_i32",
                "residual2_i32", "layernorm2_i32", "layernorm2_i8", "logits"):
        name = key[:-4] if key.endswith("_i32") else key
        value = trace[key]
        if value and isinstance(value[0], list):
            result[name] = [list(map(int, row)) for row in value]
        else:
            result[name] = [list(map(int, value))]
    return result


BASE_SCALES = {
    "embedding_position": 8, "q": 8, "k": 8, "v": 8,
    "scores": 256, "probabilities": 32768, "av": 1024,
    "head_projection": 8, "merged": 8, "residual1": 8,
    "layernorm1": 1, "layernorm1_i8": 1, "ffn_up": 256,
    "gelu": 256, "gelu_i8": 256, "ffn_down": 1,
    "residual2": 1, "layernorm2": 1, "layernorm2_i8": 1,
    "logits": 8,
}

SATURATION_KEYS = {"q_i8": "q", "k_i8": "k", "v_i8": "v",
                   "layernorm1_i8": "layernorm1_i8", "gelu_i8": "gelu_i8",
                   "layernorm2_i8": "layernorm2_i8"}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--trainer", type=Path, default=Path(__file__).with_name("train_tiny_gpt2.py"))
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--seed", type=int, default=20261123)
    parser.add_argument("--epochs", type=int, default=120)
    parser.add_argument("--train-sequences", type=int, default=4096)
    parser.add_argument("--test-sequences", type=int, default=1024)
    args = parser.parse_args()
    trainer = load_trainer(args.trainer)
    model_bytes = args.model.read_bytes()
    int_model = json.loads(model_bytes)
    float_model = retrain(trainer, args.seed, args.epochs, args.train_sequences)
    tests = trainer.make_sequences(args.test_sequences, args.seed + 2)
    x_test = torch.tensor([s[:trainer.CONTEXT] for s in tests], dtype=torch.long)
    y_test = torch.tensor([s[1:trainer.CONTEXT + 1] for s in tests], dtype=torch.long)
    with torch.no_grad():
        fp_logits = float_model.forward_float(x_test)
        fp_loss = float(F.cross_entropy(fp_logits.reshape(-1, trainer.VOCAB), y_test.reshape(-1)))
        fp_accuracy = float((fp_logits.argmax(-1) == y_test).float().mean())
        fp_decode_logits = fp_logits[:, 4:8]
        fp_decode_targets = y_test[:, 4:8]
        fp_decode_loss = float(F.cross_entropy(
            fp_decode_logits.reshape(-1, trainer.VOCAB), fp_decode_targets.reshape(-1)))
        fp_decode_accuracy = float((fp_decode_logits.argmax(-1) == fp_decode_targets).float().mean())
        fp = float_trace(float_model, trainer, x_test)
    # The reference is imported independently from the Mapper and A3 model.
    from reference_tiny_gpt2_int8 import decode_one, init_cache

    scales = BASE_SCALES.copy()
    activation_scales = int_model.get("activation_scales", {})
    norm_scale = int(activation_scales.get("layernorm_output", 1))
    gelu_scale = int(activation_scales.get("gelu_output", 256))
    for stage in ("layernorm1", "layernorm1_i8", "layernorm2", "layernorm2_i8",
                  "ffn_down", "residual2"):
        scales[stage] = norm_scale
    scales["gelu_i8"] = gelu_scale
    collectors: dict[str, list[tuple[list[float], list[float]]]] = {name: [] for name in scales}
    saturation: dict[str, list[int]] = {key: [] for key in SATURATION_KEYS}
    int_correct = 0
    int_nll = 0.0
    total = 0
    with torch.no_grad():
        for b, sequence in enumerate(tests):
            cache = init_cache(int_model, sequence[:4])
            for position in range(4, 8):
                trace = decode_one(int_model, cache, sequence[position], position)
                qtrace = q_vectors(trace, position)
                target = sequence[position + 1]
                logits = trace["logits"]
                predicted = max(range(len(logits)), key=lambda i: (logits[i], -i))
                int_correct += predicted == target
                peak = max(logits)
                terms = [math.exp((value - peak) / 8.0) for value in logits]
                int_nll -= math.log(max(terms[target] / sum(terms), 1.0e-300))
                total += 1
                for name, groups in qtrace.items():
                    if name not in collectors:
                        continue
                    if name in ("scores", "probabilities"):
                        expected_tensor = fp[name][b, :, position, :position + 1]
                    elif name in ("q", "k", "v", "av", "head_projection"):
                        expected_tensor = fp[name][b, :, position, :]
                    else:
                        expected_tensor = fp[name][b, position, :]
                    expected = expected_tensor.detach().cpu().tolist()
                    if name in ("scores", "probabilities"):
                        expected = [list(map(float, row[:position + 1])) for row in expected]
                    elif name in ("q", "k", "v", "av"):
                        expected = [list(map(float, row)) for row in expected]
                    elif name == "head_projection":
                        expected = [list(map(float, row)) for row in expected]
                    else:
                        expected = [list(map(float, expected))]
                    scale = scales[name]
                    for actual_group, expected_group in zip(groups, expected):
                        collectors[name].append(([float(x) / scale for x in actual_group], expected_group))
                for key, stage in SATURATION_KEYS.items():
                    values = qtrace[stage]
                    saturation[key].extend(int(v) in (-128, 127) for row in values for v in row)

    rows = []
    for name, pairs in collectors.items():
        actual = [x for a, _ in pairs for x in a]
        expected = [x for _, b in pairs for x in b]
        errors = [a - b for a, b in zip(actual, expected)]
        # Top-1 agreement is computed per output vector, where a vector exists.
        top = sum(max(range(len(a)), key=a.__getitem__) == max(range(len(b)), key=b.__getitem__)
                  for a, b in pairs if a and b) / max(1, sum(bool(a and b) for a, b in pairs))
        sat = saturation.get(name)
        rows.append({"stage": name, "fp_min": min(expected), "fp_max": max(expected),
                     "int8_dequant_min": min(actual), "int8_dequant_max": max(actual),
                     "mae": sum(abs(e) for e in errors) / max(1, len(errors)),
                     "rmse": math.sqrt(sum(e * e for e in errors) / max(1, len(errors))),
                     "top1_agreement": top,
                     "saturation_ratio": (sum(sat) / len(sat)) if sat else "N/A",
                     "quant_scale": scales[name]})
    args.out.mkdir(parents=True, exist_ok=False)
    with (args.out / "layerwise_error.csv").open("w", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    report = {
        "status": "PASS_DIAGNOSTIC",
        "model_sha256": hashlib.sha256(model_bytes).hexdigest(),
        "trainer_sha256": hashlib.sha256(args.trainer.read_bytes()).hexdigest(),
        "seed": args.seed, "epochs": args.epochs,
        "train_sequences": args.train_sequences,
        "heldout_sequences": args.test_sequences,
        "fp32_heldout": {"next_token_accuracy": fp_accuracy,
                         "cross_entropy_nats": fp_loss, "perplexity": math.exp(fp_loss)},
        "fp32_decode_positions_4_to_7": {
            "next_token_accuracy": fp_decode_accuracy,
            "cross_entropy_nats": fp_decode_loss,
            "perplexity": math.exp(fp_decode_loss)},
        "int8_heldout": {"next_token_accuracy": int_correct / total,
                         "cross_entropy_nats": int_nll / total,
                         "perplexity": math.exp(min(int_nll / total, 700.0))},
        "analysis_scope": "teacher-forced positions 4..7; FP32 PyTorch trace vs scalar independent INT8 reference; not Top RTL evidence",
        "stage_metrics": rows,
        "root_cause_hypotheses": [
            "FP32 training uses natural-exponential Softmax while the RTL uses Q8.8 exp2 Softmax.",
            "FP32 training uses PyTorch GELU while the RTL uses a bounded Q8.8 piecewise approximation.",
            "LayerNorm outputs are written as integer values and requantized with shift 0, so sub-unit normalized values lose fractional resolution.",
            "Q8.8 GELU values are requantized to INT8 with shift 0, saturating values above +127 and below -128 (about +/-0.5 in Q8.8).",
        ],
    }
    (args.out / "layerwise_error.json").write_text(json.dumps(report, indent=2) + "\n")
    print("TINY_GPT2_LAYERWISE_ANALYSIS_PASS "
          f"fp32_acc={fp_accuracy:.6f} int8_acc={int_correct / total:.6f} "
          f"fp32_ppl={math.exp(fp_loss):.5f} int8_ppl={report['int8_heldout']['perplexity']:.5f} "
          f"model_sha256={report['model_sha256']} out={args.out}")


if __name__ == "__main__":
    main()
