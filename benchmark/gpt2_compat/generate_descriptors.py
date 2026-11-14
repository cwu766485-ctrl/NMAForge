#!/usr/bin/env python3
"""Generate an operator lowering plan for the 4-layer GPT-2-compatible demo.

Records are planning metadata, not executable ABI words. Operators outside
the current product contract are explicitly marked blocked instead of being
hidden behind host-side computation.
"""
from __future__ import annotations
import argparse, csv, json
from pathlib import Path

OPS = {"GEMM": 0x30, "LAYER_NORM": 0x38, "CAUSAL_SOFTMAX": 0x39, "KV_WRITE": 0x43, "KV_READ": 0x44}

def build(tokens: int) -> list[dict]:
    rows = []
    task = 0
    def add(layer, phase, op, m, n, k, src0, src1, dst, status="SUPPORTED_PRIMITIVE"):
        nonlocal task
        rows.append(dict(index=len(rows), task_id=task, layer=layer, phase=phase,
                         opcode=f"0x{OPS[op]:02x}", op=op, m=m, n=n, k=k,
                         src0=f"0x{src0:05x}", src1=f"0x{src1:05x}", dst=f"0x{dst:05x}", status=status))
        task += 1
    for layer in range(4):
        base = 0x2000 + layer * 0x3000
        add(layer, "pre_ln", "LAYER_NORM", tokens, 64, 64, base, base + 0x1000, base + 0x1800)
        for phase, off in (("q", 0x200), ("k", 0x600), ("v", 0xa00)):
            add(layer, phase, "GEMM", tokens, 64, 64, base + 0x1800, base + off, base + 0x1000 + off)
        add(layer, "attention", "CAUSAL_SOFTMAX", tokens, tokens, 64, base + 0x1200, base + 0x1600, base + 0x1a00, "BLOCKED_BY_PRODUCT_CONTRACT")
        add(layer, "attention_value", "GEMM", tokens, 64, tokens, base + 0x1a00, base + 0xa00, base + 0x1c00)
        add(layer, "post_attn_ln", "LAYER_NORM", tokens, 64, 64, base + 0x1c00, base + 0x1000, base + 0x1e00)
        add(layer, "ffn_up", "GEMM", tokens, 256, 64, base + 0x1e00, base + 0x1200, base + 0x2200)
        add(layer, "ffn_down", "GEMM", tokens, 64, 256, base + 0x2200, base + 0x1600, base + 0x1c00)
        add(layer, "kv_write", "KV_WRITE", tokens, 64, 1, base + 0x1000, base + 0x2800, base + 0x2800)
    add(4, "lm_head", "GEMM", tokens, 256, 64, 0x1c00, 0x8000, 0x9000)
    return rows

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--tokens", type=int, default=4); ap.add_argument("--out", type=Path, default=Path("gpt2_compat_descriptors.csv")); ap.add_argument("--manifest", type=Path, default=Path("gpt2_compat_descriptor_manifest.json")); args = ap.parse_args()
    if not 1 <= args.tokens <= 16: raise SystemExit("tokens must be 1..16")
    rows = build(args.tokens); args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=rows[0]); w.writeheader(); w.writerows(rows)
    manifest = {"abi": "v7.4", "descriptor_bytes": 64, "completion_bytes": 16, "config": {"layers": 4, "hidden": 64, "heads": 4, "ffn": 256, "vocab": 256, "context": 16}, "tokens": args.tokens, "descriptor_count": len(rows), "supported_primitive_count": sum(r["status"] == "SUPPORTED_PRIMITIVE" for r in rows), "blocked_count": sum(r["status"] != "SUPPORTED_PRIMITIVE" for r in rows), "blocked_reason": "CAUSAL_SOFTMAX is not a single product descriptor; requires legal macro lowering and ownership contract"}
    args.manifest.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2, sort_keys=True))

if __name__ == "__main__": main()
