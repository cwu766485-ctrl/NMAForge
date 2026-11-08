#!/usr/bin/env python3
"""Independent golden/descriptor checker for the H=16 QKV Top workload."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


POISON = 0xA55AA55A


def load_pairs(path: Path) -> dict[int, int]:
    words = [int(line, 16) for line in path.read_text().splitlines()]
    count = words[0]
    if len(words) != 1 + count * 2:
        raise ValueError(f"malformed pair file: {path}")
    pairs = dict(zip(words[1::2], words[2::2]))
    if len(pairs) != count:
        raise ValueError(f"duplicate pair address: {path}")
    return pairs


def signed_i8(value: int) -> int:
    value &= 0xFF
    return value - 256 if value & 0x80 else value


def decode_a(memory: dict[int, int], base: int, rows: int, k_dim: int) -> list[list[int]]:
    result = [[0] * k_dim for _ in range(rows)]
    for row in range(rows):
        row_group, row_lane = divmod(row, 4)
        for k_group in range(k_dim // 4):
            word_index = row_group * (k_dim // 4) * 4 + k_group * 4 + row_lane
            word = memory[base + word_index * 4]
            for lane in range(4):
                result[row][k_group * 4 + lane] = signed_i8(word >> (lane * 8))
    return result


def decode_b(memory: dict[int, int], base: int, k_dim: int, n_dim: int) -> list[list[int]]:
    result = [[0] * n_dim for _ in range(k_dim)]
    for col_group in range(0, n_dim, 4):
        for k_group in range(0, k_dim, 4):
            for col in range(col_group, col_group + 4):
                col_lane = col - col_group
                word_index = (col_group // 4) * (k_dim // 4) * 4 + \
                             (k_group // 4) * 4 + col_lane
                word = memory[base + word_index * 4]
                for lane in range(4):
                    result[k_group + lane][col] = signed_i8(word >> (lane * 8))
    return result


def scalar_gemm(a: list[list[int]], b: list[list[int]]) -> list[list[int]]:
    return [[sum(int(a[row][k]) * int(b[k][col]) for k in range(len(b)))
             for col in range(len(b[0]))] for row in range(len(a))]


def write_hash_i32(matrix: list[list[int]]) -> str:
    data = b"".join((value & 0xFFFFFFFF).to_bytes(4, "little")
                    for row in matrix for value in row)
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--workload-dir", type=Path, required=True)
    args = parser.parse_args()
    model_bytes = args.model.read_bytes()
    model = json.loads(model_bytes)
    manifest = json.loads((args.workload_dir / "manifest.json").read_text())
    memory = load_pairs(args.workload_dir / "model_memory.memh")
    golden = load_pairs(args.workload_dir / "model_golden.memh")

    shape = model["shape"]
    if (shape["hidden"], shape["attention_heads"], shape["head_dim"],
            shape["layers"], shape["sequence_length"], shape["dtype"]) != \
            (16, 2, 8, 1, 8, "signed INT8"):
        raise ValueError("model shape contract does not describe H16 / 2-head / Seq8")
    if hashlib.sha256(model_bytes).hexdigest() != manifest.get("model_sha256"):
        raise ValueError("model SHA does not match mapper manifest")
    if hashlib.sha256((args.workload_dir / "model_memory.memh").read_bytes()).hexdigest() != \
            manifest["memory_sha256"]:
        raise ValueError("memory image SHA does not match mapper manifest")
    if hashlib.sha256((args.workload_dir / "model_golden.memh").read_bytes()).hexdigest() != \
            manifest["golden_sha256"]:
        raise ValueError("Golden SHA does not match mapper manifest")

    tensors = manifest["tensors"]
    x_base = tensors["h16_qkv_input"]["address"]
    x = decode_a(memory, x_base, 8, 16)
    expected_x = [model["embeddings"][token] for token in model["prefill_tokens"]]
    if x != expected_x:
        raise ValueError("decoded Matrix-A input differs from model token embeddings")

    desc_base = manifest["descriptor_base"]
    specs = (("q", 0x7100, 0), ("k", 0x7101, 1), ("v", 0x7102, 2))
    if manifest["descriptor_count"] != 3 or manifest["useful_macs"] != 6144:
        raise ValueError("H16 QKV mapper shape/count mismatch")
    outputs = {}
    for index, (name, task_id, event_index) in enumerate(specs):
        d = [memory[desc_base + index * 64 + 4 * word] for word in range(16)]
        tensor = tensors[f"h16_{name}_i32"]
        weight = tensors[f"h16_w{name}"]
        wait = 0 if index == 0 else 1 << (index - 1)
        signal = 1 << index if index < 2 else 0
        contract = (d[0], d[1], d[2], d[4], d[5], d[6], d[7],
                    d[13], d[14], d[15])
        expected = (task_id << 16 | 0x30, x_base, weight["address"],
                    tensor["address"], 16 << 16 | 8, 4, 0,
                    1 << 16 | 1, signal << 16 | wait, 7 << 16 | 7)
        if contract != expected:
            raise ValueError(f"Matrix GEMM descriptor {name} mismatch: {contract!r}")
        result = scalar_gemm(x, decode_b(memory, weight["address"], 16, 16))
        outputs[name] = result
        for row_index, row in enumerate(result):
            for col_index, value in enumerate(row):
                address = tensor["address"] + 4 * (row_index * 16 + col_index)
                if golden.get(address) != (value & 0xFFFFFFFF):
                    raise ValueError(f"software Golden mismatch in {name} at {address:#x}")
                if memory.get(address) != POISON:
                    raise ValueError(f"output {name} was not poison before Top execution")

    labels = [(token + 1) % 16 for token in model["prefill_tokens"]]
    predictions = [max(range(16), key=row.__getitem__) for row in outputs["v"]]
    correct = sum(prediction == label for prediction, label in zip(predictions, labels))
    print(
        "TRANSFORMER_H16_QKV_INDEPENDENT_GOLDEN_PASS "
        f"descriptors=3 outputs=384 useful_macs=6144 "
        f"q_sha256={write_hash_i32(outputs['q'])} "
        f"k_sha256={write_hash_i32(outputs['k'])} "
        f"v_sha256={write_hash_i32(outputs['v'])} "
        f"next_token_accuracy={correct}/{len(labels)}"
    )


if __name__ == "__main__":
    main()
