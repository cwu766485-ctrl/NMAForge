#!/usr/bin/env python3
"""Static 128/256-KiB capacity lower-bound for DeiT-Tiny execution."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def make_plan() -> dict:
    hidden, heads, seq, ffn, layers = 192, 3, 197, 768, 12
    # INT8 weight bytes (biases included); one encoder layer streamed at a time.
    per_layer_weights = (
        hidden * (3 * hidden) + (3 * hidden) +
        hidden * hidden + hidden +
        hidden * ffn + ffn + ffn * hidden + hidden +
        4 * hidden  # two LayerNorm gamma/beta pairs, INT8 planning only
    )
    patch_weight = 3 * 16 * 16 * hidden
    position_embedding = seq * hidden
    classifier = hidden * 1000 + 1000
    activation = seq * hidden
    qkv = 3 * activation
    query_block = 16
    score_block_per_head = query_block * seq * 4
    score_block_all_heads = heads * score_block_per_head
    ffn_tile = query_block * ffn
    # Leave space for queue/descriptor/control regions (not an RTL allocation).
    fixed_control_bytes = 16 * 1024
    scenarios = {}
    for capacity in (128 * 1024, 256 * 1024):
        # The two full token activation images are conservatively kept live;
        # operation scratch is tiled and streamed rather than materialized whole.
        live = {
            "fixed_control_queue_budget": fixed_control_bytes,
            "two_int8_token_activation_images": 2 * activation,
            "qkv_int8_output_scratch": qkv,
            "16_query_x_197_key_int32_score_block_3_heads": score_block_all_heads,
            "16_token_ffn_int8_tile": ffn_tile,
            "one_16x16_int8_operand_tile": 16 * 16,
        }
        peak_lower_bound = sum(live.values())
        scenarios[f"{capacity // 1024}KiB"] = {
            "capacity_bytes": capacity,
            "estimated_live_bytes_for_this_schedule": peak_lower_bound,
            "headroom_bytes": capacity - peak_lower_bound,
            "fits_this_static_schedule": peak_lower_bound <= capacity,
            "live_components_bytes": live,
            "required_streamed_weight_bytes_per_encoder_layer": per_layer_weights,
            "patch_embedding_weight_bytes": patch_weight,
            "position_embedding_bytes": position_embedding,
            "classifier_weight_and_bias_bytes": classifier,
            "warning": "planning estimate only; no RTL liveness proof, DMA schedule, timing, or Top run",
        }
    return {
        "status": "STATIC_CAPACITY_ESTIMATE_NOT_RTL",
        "model": "facebook/deit-tiny-patch16-224",
        "shape": {"image": "224x224x3", "patch": 16, "tokens_including_cls": seq,
                  "hidden": hidden, "heads": heads, "layers": layers, "ffn": ffn,
                  "classes": 1000},
        "array": {"macs": 256, "shape": "16x16", "spad_banks": 4,
                  "line_bytes": 16},
        "weight_bytes": {
            "one_encoder_layer_int8_estimate": per_layer_weights,
            "all_12_encoder_layers_int8_estimate": layers * per_layer_weights,
            "patch_embedding_int8_estimate": patch_weight,
            "position_embedding_int8_estimate": position_embedding,
            "classifier_int8_estimate": classifier,
        },
        "activation_bytes": {
            "one_197x192_int8_tensor": activation,
            "three_qkv_outputs": qkv,
            "one_16x197_int32_score_block_per_head": score_block_per_head,
            "three_head_score_blocks": score_block_all_heads,
            "one_16x768_int8_ffn_tile": ffn_tile,
        },
        "capacity_scenarios": scenarios,
        "unresolved_hardware_contracts": [
            "197-key causal softmax with 16-query blocking and global normalization",
            "192-hidden GEMM tiling and non-multiple-of-16 tails",
            "FFN=768 tiling and activation lifetime",
            "position/class token and patch embedding descriptor lowering",
            "per-layer streamed weight DMA and 128/256-KiB parameter propagation",
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    plan = make_plan()
    args.output.write_text(json.dumps(plan, indent=2, sort_keys=True) + "\n",
                           encoding="utf-8")
    print(json.dumps({"status": plan["status"], "output": str(args.output),
                      "scenarios": {name: value["estimated_live_bytes_for_this_schedule"]
                                    for name, value in plan["capacity_scenarios"].items()}},
                     sort_keys=True))


if __name__ == "__main__":
    main()
