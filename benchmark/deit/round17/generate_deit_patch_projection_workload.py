#!/usr/bin/env python3
"""Create one real DeiT patch-projection GEMM tile for Product Top.

This deliberately exercises one 16-output tile for the first image patch. It
does not claim a full 197-token patch embedding or an encoder-layer run.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import torch
from transformers import AutoImageProcessor, ViTForImageClassification

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "sw" / "tools"))
sys.path.insert(0, str(ROOT / "dv" / "block" / "compute" / "matrix" / "ref"))
from cimforge_mapper import (  # noqa: E402
    Mapper, OP_GEMM, _pack_matrix_a_physical, _pack_matrix_b_physical,
    add_completion_order_chain,
)
from ai_a3_reference import gemm_i8_i32  # noqa: E402

MODEL_ID = "facebook/deit-tiny-patch16-224"
REVISION = "b3428f18dcc7b543470d07f14b4a4157815d1880"
SEED = 20261117
POISON = 0xA55AA55A


def digest_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_pairs(path: Path, pairs: dict[int, int]) -> None:
    words = [len(pairs)]
    for address, value in sorted(pairs.items()):
        words.extend((address, int(value) & 0xFFFFFFFF))
    path.write_text("".join(f"{word & 0xFFFFFFFF:08x}\n" for word in words),
                     encoding="ascii")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model-dir", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()
    model_dir = args.model_dir.resolve()
    model = ViTForImageClassification.from_pretrained(
        str(model_dir), local_files_only=True
    ).cpu().eval()
    processor = AutoImageProcessor.from_pretrained(
        str(model_dir), local_files_only=True
    )
    torch.set_num_threads(1)

    rng = np.random.default_rng(SEED)
    image = rng.integers(0, 256, size=(224, 224, 3), dtype=np.uint8)
    processed = processor(images=image, return_tensors="pt")["pixel_values"]
    # Conv2d patch order is C,H,W, matching the flattened checkpoint weights.
    patch_fp = processed[0, :, :16, :16].contiguous().numpy().reshape(768)
    input_i8 = np.rint(patch_fp * 127.0).clip(-127, 127).astype(np.int8)

    projection = model.vit.embeddings.patch_embeddings.projection
    weight_fp = projection.weight.detach().cpu().numpy()[:16].reshape(16, 768)
    scales = np.max(np.abs(weight_fp), axis=1) / 127.0
    scales = np.where(scales == 0, 1.0, scales).astype(np.float32)
    weight_i8 = np.rint(weight_fp / scales[:, None]).clip(-127, 127).astype(np.int8)
    # The hardware GEMM contract is A[M,K] * B[K,N].
    b_matrix = weight_i8.T.astype(np.int32).tolist()
    a_matrix = np.zeros((16, 768), dtype=np.int32)
    a_matrix[0] = input_i8.astype(np.int32)

    mapper = Mapper()
    mapper.next_addr = 0x1000
    mapper.task_id = 0x7100
    a = mapper.tensor("deit_patch0_input_i8", (16, 768), "i8_packed",
                      "matrix_a_tile", _pack_matrix_a_physical(a_matrix.tolist()))
    b = mapper.tensor("deit_patch0_weight_n0_i8", (768, 16), "i8_packed",
                      "matrix_b_tile", _pack_matrix_b_physical(b_matrix))
    out = mapper.tensor("deit_patch0_projection_i32", (16, 16), "i32",
                        "row_major", [POISON] * 256, initialized=False)
    mapper.add("deit_patch0_projection_n0", OP_GEMM, a, out, src1=b,
               m=16, n=16, k_or_length=192, batch_count=1, head_count=1)
    add_completion_order_chain(mapper, event_bit=0)

    expected = gemm_i8_i32(a_matrix.astype(np.int8).tolist(), b_matrix)
    golden = {out.addr + 4 * (row * 16 + col): int(expected[row][col]) & 0xFFFFFFFF
              for row in range(16) for col in range(16)}
    image_pairs: dict[int, int] = {}
    for tensor in mapper.tensors.values():
        for index, value in enumerate(tensor.values):
            image_pairs[tensor.addr + 4 * index] = int(value) & 0xFFFFFFFF
    desc_base, cpl_base = 0x8000, 0x9000
    for index, descriptor in enumerate(mapper.descriptors):
        for word_index, value in enumerate(descriptor.words()):
            image_pairs[desc_base + index * 64 + word_index * 4] = int(value) & 0xFFFFFFFF
        for word_index in range(4):
            image_pairs[cpl_base + index * 16 + word_index * 4] = POISON

    args.out_dir.mkdir(parents=True, exist_ok=True)
    write_pairs(args.out_dir / "model_memory.memh", image_pairs)
    write_pairs(args.out_dir / "model_golden.memh", golden)
    fp_projection = torch.nn.functional.conv2d(
        processed, projection.weight[:16], projection.bias[:16], stride=16
    )[0, :, 0, 0].detach().cpu().numpy()
    dequant = (expected[0] * (scales * (1.0 / 127.0))).astype(np.float32)
    dequant += projection.bias[:16].detach().cpu().numpy()
    error = dequant - fp_projection
    manifest = {
        "status": "TOP_WORKLOAD_GENERATED_NOT_YET_SIMULATED",
        "model_id": MODEL_ID,
        "hub_revision": REVISION,
        "scope": "one image patch, first 16 of 192 patch-projection outputs; Product Top INT8xINT8 to INT32 GEMM",
        "model_snapshot_sha256": {
            name: digest_bytes((model_dir / name).read_bytes())
            for name in ("config.json", "preprocessor_config.json", "pytorch_model.bin")
        },
        "seed": SEED,
        "input_image_sha256": digest_bytes(image.tobytes()),
        "input_patch_i8_sha256": digest_bytes(input_i8.tobytes()),
        "weight_tile_i8_sha256": digest_bytes(weight_i8.tobytes()),
        "input_quantization": "official processor then round(norm*127), clamp[-127,127]",
        "weight_quantization": "per-output-channel symmetric absmax/127, round-to-nearest-even, clamp[-127,127]",
        "int32_golden": "independent int64 scalar GEMM over the exported quantized operands; Product output checked bit-exact",
        "float_comparison": {
            "scope": "first patch, first 16 projection channels, includes dequantized GEMM and FP32 bias",
            "mae": float(np.mean(np.abs(error))),
            "max_abs": float(np.max(np.abs(error))),
            "rmse": float(np.sqrt(np.mean(error * error))),
            "warning": "one-tile quantization diagnostic only; not full INT8 DeiT inference or accuracy",
        },
        "descriptor": {
            "opcode": "0x30", "M": 16, "N": 16, "K": 768,
            "k_words": 192, "descriptor_count": 1,
            "src0": a.addr, "src1": b.addr, "dst": out.addr,
            "descriptor_base": desc_base, "completion_base": cpl_base,
            "golden_words": len(golden),
            "useful_macs": 768 * 16,
            "executed_macs": 16 * 16 * 768,
            "spad_high_water_exclusive": cpl_base + 16,
            "spad_capacity_bytes": 131072,
        },
        "limitations": [
            "only one of 196 image patches and one of twelve 16-channel output tiles is executed",
            "class token, position embedding addition, bias application and requantization are not in this Product Top workload",
            "no encoder attention/MLP layer execution is claimed",
            "no ImageNet accuracy is measured",
        ],
    }
    (args.out_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print("DEIT_PATCH_PROJECTION_WORKLOAD_PASS " + json.dumps({
        "descriptor_count": 1,
        "k_words": 192,
        "golden_words": len(golden),
        "useful_macs": 768 * 16,
        "memory_sha256": digest_bytes((args.out_dir / "model_memory.memh").read_bytes()),
        "golden_sha256": digest_bytes((args.out_dir / "model_golden.memh").read_bytes()),
    }, sort_keys=True))


if __name__ == "__main__":
    main()
