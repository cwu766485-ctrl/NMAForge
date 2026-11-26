#!/usr/bin/env python3
"""Emit a model/weight/KV/SPAD execution plan; it is not an RTL run."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

from gpt2_compat_golden import CONFIG, make_model


def tensor_sha(value: np.ndarray) -> str:
    return hashlib.sha256(np.ascontiguousarray(value).tobytes()).hexdigest()


def build_plan(seed: int, output: Path) -> dict:
    model = make_model(seed)
    tensor_manifest = {
        name: {"shape": list(value.shape), "dtype": str(value.dtype),
               "bytes": int(value.nbytes), "sha256": tensor_sha(value)}
        for name, value in sorted(model.items())
    }
    total_model_bytes = sum(item["bytes"] for item in tensor_manifest.values())
    layer_plans = []
    for layer in range(CONFIG["layers"]):
        prefix = f"l{layer}."
        dense_names = [prefix + name for name in ("q", "k", "v", "o", "up", "down")]
        norm_names = [prefix + name for name in
                      ("ln1_gamma", "ln1_beta", "ln2_gamma", "ln2_beta")]
        layer_plans.append({
            "layer": layer,
            "dense_weight_tensors": dense_names,
            "dense_weight_bytes": sum(tensor_manifest[name]["bytes"] for name in dense_names),
            "norm_parameter_tensors": norm_names,
            "norm_parameter_bytes": sum(tensor_manifest[name]["bytes"] for name in norm_names),
            "kv_cache": {
                "K_bytes": CONFIG["context"] * CONFIG["hidden"],
                "V_bytes": CONFIG["context"] * CONFIG["hidden"],
                "total_bytes": 2 * CONFIG["context"] * CONFIG["hidden"],
                "lifetime": "persistent from prefill through all decode steps",
            },
            "execution_order": [
                "LN1", "QKV projections", "head split", "causal QK",
                "Q15 Softmax", "AV", "output projection", "residual1",
                "LN2", "FFN up", "bounded INT8 GELU", "FFN down", "residual2",
            ],
        })
    embedding_names = ["embedding", "position"]
    final_names = ["final_gamma", "final_beta", "lm_head"]
    kv_bytes = sum(layer["kv_cache"]["total_bytes"] for layer in layer_plans)
    per_layer_kv = []
    kv_cursor = 0x10000
    for layer in layer_plans:
        kv_size = layer["kv_cache"]["total_bytes"]
        k_size = layer["kv_cache"]["K_bytes"]
        per_layer_kv.append({
            "layer": layer["layer"],
            "K_range": [hex(kv_cursor), hex(kv_cursor + k_size)],
            "V_range": [hex(kv_cursor + k_size), hex(kv_cursor + kv_size)],
            "combined_range": [hex(kv_cursor), hex(kv_cursor + kv_size)],
            "bytes": kv_size,
            "lifetime": "persistent until session retirement",
        })
        kv_cursor += kv_size
    plan = {
        "status": "STATIC_EXECUTION_PLAN_NOT_RTL_RUN",
        "model": {**CONFIG, "seed": seed,
                  "kind": "deterministic synthetic weights; not pretrained GPT-2",
                  "tensor_manifest": tensor_manifest,
                  "total_serialized_parameter_bytes": total_model_bytes},
        "memory": {
            "product_scratchpad_bytes": 128 * 1024,
            "banks": 4,
            "persistent_layer_kv_bytes_context16": kv_bytes,
            "layer_kv_region_proposal": {
                "base": "0x00010000",
                "end_exclusive": hex(0x10000 + kv_bytes),
                "bytes": kv_bytes,
                "per_layer": 2 * CONFIG["context"] * CONFIG["hidden"],
                "allocations": per_layer_kv,
                "requires_address/protection_contract_review": True,
            },
            "baseline_one_layer_top_high_water_bytes": 130576,
            "naive_four_layer_high_water_estimate_bytes": 130576 + kv_bytes -
                2 * CONFIG["context"] * CONFIG["hidden"],
            "capacity_disposition": "NOT_PROVEN; naive persistent K/V addition exceeds 128 KiB, so temporary tensor lifetime reuse and compact allocation are required before RTL integration",
            "lifetimes": [
                {"object": "token/position embedding row", "lifetime": "input preparation through layer 0 read", "reuse": "release after input row is materialized"},
                {"object": "layer input/output hidden state", "lifetime": "current layer only", "reuse": "ping-pong two hidden buffers across layers"},
                {"object": "layer-specific K/V", "lifetime": "entire prefill/decode session", "reuse": "never alias another layer or temporary tensor"},
                {"object": "Q/K/V projection and attention scratch", "lifetime": "current layer attention only", "reuse": "reuse one scratch region after each consumer completion"},
                {"object": "FFN up/GELU tile", "lifetime": "current FFN tile", "reuse": "stream/tile and release before next layer"},
                {"object": "layer dense weight tile", "lifetime": "last consuming descriptor in current layer", "reuse": "DMA stream next layer into same region after completion fence"},
                {"object": "final LN and logits", "lifetime": "after layer 3 residual output", "reuse": "final LN buffer then 256 INT32 logits"},
            ],
        },
        "weight_streaming": {
            "policy": "load one layer's dense weights, fence, execute layer, then reuse weight region for next layer",
            "dense_weight_bytes_per_layer": [item["dense_weight_bytes"] for item in layer_plans],
            "dense_weight_total_bytes": sum(item["dense_weight_bytes"] for item in layer_plans),
            "norm_parameter_bytes_per_layer": [item["norm_parameter_bytes"] for item in layer_plans],
            "embedding_position_bytes": sum(tensor_manifest[name]["bytes"] for name in embedding_names),
            "final_ln_lm_head_bytes": sum(tensor_manifest[name]["bytes"] for name in final_names),
            "serialized_model_bytes": total_model_bytes,
            "dma_count_and_burst_plan": "NOT_GENERATED; requires runtime planner and Product Top address allocation",
        },
        "layers": layer_plans,
        "final_output": {
            "final_layer_norm": "run after layer 3 residual2; independent INT8 reference contract must match Product SFU",
            "lm_head": {"weight": "lm_head", "shape": [64, 256],
                        "candidate_mapping": "16 output-channel tiles, each K=64 and N=16; M=1 GEMV only if ABI-v7.4 legality is confirmed, otherwise a supported padded Matrix tile",
                        "logits": 256, "argmax_owner": "host may select token after reading checked logits"},
            "greedy_decode": "host-fed next-token loop only after every logits vector matches the independent reference",
        },
        "execution_gates": [
            "single-layer persistent decode PASS",
            "layer-specific cache address and lifetime proof",
            "weight DMA fence and layer handoff proof",
            "per-layer tensor Golden",
            "final LN and all 256 LM logits Golden",
        ],
        "rtl_execution": "NOT_RUN",
        "model_quality": "NOT_MEASURED; current H64 reference uses deterministic pseudo weights",
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(plan, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return plan


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=20261116)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    plan = build_plan(args.seed, args.out)
    print("H64_FOUR_LAYER_EXECUTION_PLAN " + json.dumps({
        "status": plan["status"],
        "total_parameter_bytes": plan["model"]["total_serialized_parameter_bytes"],
        "persistent_kv_bytes": plan["memory"]["persistent_layer_kv_bytes_context16"],
        "naive_high_water_estimate_bytes": plan["memory"]["naive_four_layer_high_water_estimate_bytes"],
        "rtl_execution": plan["rtl_execution"],
    }, sort_keys=True))


if __name__ == "__main__":
    main()
