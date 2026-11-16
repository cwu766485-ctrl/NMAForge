#!/usr/bin/env python3
"""Map TinyNPU's fixed GPT-2 slice export into NMAForge's H64 runtime format.

The result is a GPT-2-derived, truncated and requantized package. It is not an
unmodified GPT-2 graph or a trained H64 language model.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np

TINY_SHA = "8216c22b762011aa20c05fc2768423fd12dda59d"
HF_REVISION = "607a30d783dfa663caf39e06633721c8d4cfcd7e"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def q_i8(value: np.ndarray, scale: int) -> np.ndarray:
    return np.clip(np.rint(value.astype(np.float64) * scale), -128, 127).astype(np.int8)


def import_model(source: Path, out: Path) -> dict:
    out.mkdir(parents=True, exist_ok=False)
    with np.load(source, allow_pickle=False) as z:
        fp = {name: z[name] for name in z.files}
    required = {"wte", "wpe", "ln_f.gamma", "ln_f.beta", "lm_head"}
    for layer in range(4):
        required.update({f"block{layer}.ln1.gamma", f"block{layer}.ln1.beta",
                         f"block{layer}.wq", f"block{layer}.wk", f"block{layer}.wv",
                         f"block{layer}.wo", f"block{layer}.ln2.gamma",
                         f"block{layer}.ln2.beta", f"block{layer}.w1", f"block{layer}.w2"})
    if set(fp) != required:
        raise ValueError(f"source tensor keys differ: missing={sorted(required-set(fp))}, "
                         f"extra={sorted(set(fp)-required)}")

    model: dict[str, np.ndarray] = {
        "embedding": q_i8(fp["wte"], 8),
        "position": q_i8(fp["wpe"], 8),
        # NMAForge stores final LN gamma in an i32 Q5 container, so preserve
        # the source range instead of clipping it to the int8 matrix format.
        "final_gamma": np.rint(fp["ln_f.gamma"].astype(np.float64) * 32).astype(np.int32),
        "final_beta": np.rint(fp["ln_f.beta"].astype(np.float64) * 8).astype(np.int32),
        "lm_head": q_i8(fp["lm_head"].T, 32),
    }
    for layer in range(4):
        prefix = f"block{layer}."
        nma = f"l{layer}."
        for proj in ("q", "k", "v"):
            # TinyNPU exporter stores four [64,16] head panels stacked by row.
            panels = fp[prefix + "w" + proj].reshape(4, 64, 16)
            matrix = np.concatenate([panels[head] for head in range(4)], axis=1)
            model[nma + proj] = q_i8(matrix, 32)
        model[nma + "o"] = q_i8(fp[prefix + "wo"], 32)
        model[nma + "up"] = q_i8(fp[prefix + "w1"], 32)
        model[nma + "down"] = q_i8(fp[prefix + "w2"], 32)
        for ln in ("ln1", "ln2"):
            model[nma + ln + "_gamma"] = np.rint(
                fp[prefix + ln + ".gamma"].astype(np.float64) * 32).astype(np.int32)
            model[nma + ln + "_beta"] = np.rint(
                fp[prefix + ln + ".beta"].astype(np.float64) * 8).astype(np.int32)

    package = out / "canonical_h64_model.npz"
    np.savez_compressed(package, **model)
    manifest = {
        "status": "GPT2_DERIVED_WEIGHT_IMPORT_NOT_LANGUAGE_QUALITY_EVIDENCE",
        "source_model": "openai-community/gpt2",
        "source_revision": HF_REVISION,
        "source_checkpoint_sha256": "248dfc3911869ec493c76e65bf2fcf7f615828b0254c12b473182f0f81d3a707",
        "source_exporter": "TinyNPU export_gpt2_weights.py",
        "tiny_npu_reference_sha": TINY_SHA,
        "tiny_fp32_export_sha256": sha(source),
        "nmaforge_package_sha256": sha(package),
        "shape": {"hidden": 64, "heads": 4, "head_dim": 16,
                  "layers": 4, "ffn": 256, "vocab": 256, "context": 16},
        "quantization": {
            "embedding_position": "round(source_float*8), symmetric int8 saturation",
            "matrix_weights": "round(source_float*32), symmetric int8 saturation",
            "layernorm_gamma": "round(source_float*32) retained in int32 Q5 then Q15 by runtime",
            "layernorm_beta": "round(source_float*8) int32 activation units",
        },
        "graph_mapping": {
            "qkv": "reassembled four TinyNPU head panels into NMAForge [K,N] matrices",
            "lm_head": "transposed from [V,H] to NMAForge [H,V]",
            "position_embedding": "first 16 positions",
            "layers": "first four GPT-2 blocks; first 64 hidden dimensions and first 256 FFN channels",
            "biases": "omitted; NMAForge four-layer GEMM descriptors do not model GPT-2 projection biases",
            "attention": "NMAForge fixed-point Pre-LN/casual attention contract, not TinyNPU arithmetic parity",
            "gelu": "NMAForge bounded integer GELU contract, not exact GPT-2 floating GELU",
        },
        "limitations": [
            "truncating hidden and FFN dimensions changes the network and does not preserve GPT-2 logits",
            "bias terms are not represented by the current runtime model package",
            "no fine-tuning or held-out language-model metric is claimed",
            "TinyNPU and NMAForge fixed-point arithmetic differ; no paired model speedup is valid",
        ],
    }
    (out / "import_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    return manifest


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--source-fp32-npz", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    manifest = import_model(args.source_fp32_npz, args.out)
    print(json.dumps({"package": str(args.out / "canonical_h64_model.npz"),
                      "package_sha256": manifest["nmaforge_package_sha256"],
                      "status": manifest["status"]}, sort_keys=True))


if __name__ == "__main__":
    main()
