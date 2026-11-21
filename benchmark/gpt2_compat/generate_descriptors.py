#!/usr/bin/env python3
"""Emit a complete graph lowering audit, never pretending it is CMDQ RTL."""
from __future__ import annotations
import argparse, csv, json
from pathlib import Path

OPS = {"GEMM": 0x30, "RESIDUAL": 0x34, "GELU": 0x35,
       "REQUANT": 0x36, "LAYER_NORM": 0x38, "CAUSAL_SOFTMAX": 0x39,
       "KV_WRITE": 0x43, "KV_READ": 0x44}
SH = {"layers": 4, "hidden": 64, "heads": 4, "ffn": 256, "vocab": 256, "context": 16}

def build(tokens):
    rows = []; task = 0
    def add(layer, phase, op, m, n, k, src0, src1, dst, status="BLOCKED", reason="H64 dimensions exceed current Matrix/SFU descriptor legality"):
        nonlocal task
        rows.append(dict(index=len(rows), task_id=task, layer=layer, phase=phase,
                         opcode=f"0x{OPS[op]:02x}", op=op, m=m, n=n, k=k,
                         src0=f"0x{src0:05x}", src1=f"0x{src1:05x}", dst=f"0x{dst:05x}", status=status, reason=reason)); task += 1
    for layer in range(4):
        base = 0x2000 + layer * 0x5000
        add(layer, "pre_ln", "LAYER_NORM", tokens, 64, 64, base, base+0x1000, base+0x1800)
        for name, off in (("q",0x200), ("k",0x600), ("v",0xa00)):
            add(layer, name, "GEMM", tokens, 64, 64, base+0x1800, base+off, base+0x1000+off)
        add(layer, "attention_scores", "GEMM", tokens*4, tokens, 16, base+0x1200, base+0x600, base+0x1a00)
        add(layer, "attention_softmax", "CAUSAL_SOFTMAX", tokens, tokens, 1, base+0x1a00, 0, base+0x1c00)
        add(layer, "attention_value", "GEMM", tokens*4, 16, tokens, base+0x1c00, base+0xa00, base+0x1e00)
        add(layer, "output_projection", "GEMM", tokens, 64, 64, base+0x1e00, base+0x400, base+0x2200)
        add(layer, "residual1", "RESIDUAL", tokens, 64, 1, base+0x2200, base+0x1800, base+0x2400)
        add(layer, "post_attn_ln", "LAYER_NORM", tokens, 64, 64, base+0x2400, base+0x1000, base+0x2600)
        add(layer, "ffn_up", "GEMM", tokens, 256, 64, base+0x2600, base+0x1200, base+0x2800)
        add(layer, "gelu", "GELU", tokens, 256, 1, base+0x2800, 0, base+0x2c00)
        add(layer, "ffn_down", "GEMM", tokens, 64, 256, base+0x2c00, base+0x1400, base+0x3000)
        add(layer, "residual2", "RESIDUAL", tokens, 64, 1, base+0x3000, base+0x2400, base+0x3200)
        add(layer, "kv_write", "KV_WRITE", tokens, 64, 1, base+0x1800, base+0x3800, base+0x3800)
    add(4, "final_ln", "LAYER_NORM", tokens, 64, 64, 0x22000, 0x23000, 0x24000)
    add(4, "lm_head", "GEMM", tokens, 256, 64, 0x24000, 0x25000, 0x26000)
    return rows

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--tokens", type=int, default=4); ap.add_argument("--out", type=Path, default=Path("gpt2_compat_descriptors.csv")); ap.add_argument("--manifest", type=Path, default=Path("gpt2_compat_descriptor_manifest.json")); args = ap.parse_args()
    if not 1 <= args.tokens <= 16: raise SystemExit("tokens must be 1..16")
    rows = build(args.tokens); args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=rows[0]); w.writeheader(); w.writerows(rows)
    manifest = {"abi": "v7.4", "descriptor_bytes": 64, "completion_bytes": 16, "config": SH, "tokens": args.tokens, "graph_nodes": len(rows), "supported_primitive_count": 0, "blocked_count": len(rows), "rtl_descriptor_execution": "NOT_RUN", "blocked_reason": "H64 shapes exceed current Matrix/SFU descriptor legality; no host fallback"}
    args.manifest.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"); print(json.dumps(manifest, indent=2, sort_keys=True))

if __name__ == "__main__": main()
