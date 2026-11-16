#!/usr/bin/env python3
"""Import the pinned, non-distilled Hugging Face DeiT-Tiny and export SW refs.

This is a software/model-import qualification utility. It does not claim Product
Top execution or match the NMAForge fixed-point contracts.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import torch
from PIL import Image
from transformers import AutoImageProcessor, ViTForImageClassification


MODEL_ID = "facebook/deit-tiny-patch16-224"
REVISION = "b3428f18dcc7b543470d07f14b4a4157815d1880"
IMAGE_SEED = 20261117


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def sha256_array(array: np.ndarray) -> str:
    return hashlib.sha256(np.ascontiguousarray(array).tobytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-dir", type=Path, required=True,
                        help="Local snapshot of the pinned Hugging Face revision")
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()
    args.out_dir.mkdir(parents=True, exist_ok=True)
    model_dir = args.model_dir.resolve()
    required = ("config.json", "preprocessor_config.json", "pytorch_model.bin")
    missing = [name for name in required if not (model_dir / name).is_file()]
    if missing:
        raise FileNotFoundError(f"model snapshot missing files: {missing}")

    torch.set_num_threads(1)
    torch.manual_seed(IMAGE_SEED)
    # The pinned checkpoint declares architectures=["ViTForImageClassification"]
    # and model_type="vit". Load the exact files locally so the run is independent
    # of mutable Hub cache state and incomplete Xet downloads.
    model = ViTForImageClassification.from_pretrained(
        str(model_dir), output_hidden_states=True, local_files_only=True
    ).cpu().eval()
    processor = AutoImageProcessor.from_pretrained(
        str(model_dir), local_files_only=True
    )
    checkpoint = model_dir / "pytorch_model.bin"

    rng = np.random.default_rng(IMAGE_SEED)
    pixels = rng.integers(0, 256, size=(224, 224, 3), dtype=np.uint8)
    image = Image.fromarray(pixels, mode="RGB")
    inputs = processor(images=image, return_tensors="pt")
    pixel_values = inputs["pixel_values"].cpu()

    patch_projection: dict[str, np.ndarray] = {}
    patch_module = next(
        module for name, module in model.named_modules()
        if name.endswith("embeddings.patch_embeddings.projection")
    )
    def capture_patch_projection(_module, _inputs, output):
        patch_projection["projection"] = output.detach().cpu().numpy()

    hook = patch_module.register_forward_hook(capture_patch_projection)
    with torch.inference_mode():
        output = model(pixel_values, output_hidden_states=True)
    hook.remove()

    # HF output_hidden_states: embeddings, then encoder output after each layer.
    embedding = output.hidden_states[0].detach().cpu().numpy()
    layer0 = output.hidden_states[1].detach().cpu().numpy()
    logits = output.logits.detach().cpu().numpy()
    arrays = {
        "pixel_values_fp32": pixel_values.numpy(),
        "patch_projection_fp32": patch_projection["projection"],
        "embedding_plus_position_fp32": embedding,
        "encoder_layer0_fp32": layer0,
        "logits_fp32": logits,
    }
    np.savez_compressed(args.out_dir / "deit_tiny_reference.npz", **arrays)

    state = model.state_dict()
    int8_bytes = 0
    quantized_digest = hashlib.sha256()
    for name in sorted(state):
        tensor = state[name].detach().cpu().numpy()
        if not np.issubdtype(tensor.dtype, np.floating):
            continue
        peak = float(np.max(np.abs(tensor))) if tensor.size else 0.0
        scale = peak / 127.0 if peak else 1.0
        quantized = np.clip(np.rint(tensor / scale), -127, 127).astype(np.int8)
        int8_bytes += quantized.nbytes
        quantized_digest.update(name.encode("utf-8") + b"\0")
        quantized_digest.update(np.asarray(scale, dtype="<f4").tobytes())
        quantized_digest.update(quantized.tobytes())

    config = model.config.to_dict()
    result = {
        "status": "SOFTWARE_IMPORT_AND_REFERENCE_PASS_NOT_PRODUCT_RTL",
        "model_id": MODEL_ID,
        "hub_revision": REVISION,
        "model_snapshot_files": {
            name: sha256_file(model_dir / name) for name in required
        },
        "checkpoint_sha256": sha256_file(checkpoint),
        "config": {
            "model_type": config.get("model_type"),
            "hidden_size": config.get("hidden_size"),
            "num_attention_heads": config.get("num_attention_heads"),
            "num_hidden_layers": config.get("num_hidden_layers"),
            "intermediate_size": config.get("intermediate_size"),
            "image_size": config.get("image_size"),
            "patch_size": config.get("patch_size"),
            "num_labels": model.config.num_labels,
            "layer_norm_eps": config.get("layer_norm_eps"),
            "hidden_act": config.get("hidden_act"),
        },
        "parameters": sum(parameter.numel() for parameter in model.parameters()),
        "input": {
            "kind": "deterministic synthetic RGB pixel pattern; no accuracy claim",
            "seed": IMAGE_SEED,
            "shape": list(pixels.shape),
            "uint8_sha256": sha256_array(pixels),
            "processor": processor.to_dict(),
        },
        "fp32_reference": {
            name: {"shape": list(array.shape), "sha256": sha256_array(array)}
            for name, array in arrays.items()
        },
        "candidate_weight_only_symmetric_int8": {
            "status": "SOFTWARE_ESTIMATE_ONLY_NOT_NMAFORGE_CONTRACT",
            "bytes": int8_bytes,
            "sha256": quantized_digest.hexdigest(),
            "rule": "per-tensor absmax/127, round-to-nearest-even, clamp[-127,127]",
        },
        "product_top_status": "NOT_RUN",
        "software": {
            "torch": torch.__version__,
            "numpy": np.__version__,
            "transformers": __import__("transformers").__version__,
        },
    }
    (args.out_dir / "deit_tiny_manifest.json").write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(json.dumps({
        "status": result["status"],
        "checkpoint_sha256": result["checkpoint_sha256"],
        "reference_archive": str(args.out_dir / "deit_tiny_reference.npz"),
        "manifest": str(args.out_dir / "deit_tiny_manifest.json"),
        "parameters": result["parameters"],
        "logits_argmax": int(np.argmax(logits[0])),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
