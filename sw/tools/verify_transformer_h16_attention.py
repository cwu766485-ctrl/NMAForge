#!/usr/bin/env python3
"""Independent contract and tensor Golden for the H16 two-head Top path."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path


POISON = 0xA55AA55A
MASK32 = 0xFFFFFFFF


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


def pack_i8(values: list[int]) -> int:
    if len(values) != 4:
        raise ValueError("INT8 word must contain four lanes")
    return sum((value & 0xFF) << (8 * lane) for lane, value in enumerate(values))


def decode_a(memory: dict[int, int], base: int, rows: int, k_dim: int) -> list[list[int]]:
    result = [[0] * k_dim for _ in range(rows)]
    for row in range(rows):
        row_group, row_lane = divmod(row, 4)
        for k_group in range(k_dim // 4):
            index = row_group * (k_dim // 4) * 4 + k_group * 4 + row_lane
            word = memory[base + index * 4]
            for lane in range(4):
                result[row][k_group * 4 + lane] = signed_i8(word >> (lane * 8))
    return result


def decode_b(memory: dict[int, int], base: int, k_dim: int, n_dim: int) -> list[list[int]]:
    result = [[0] * n_dim for _ in range(k_dim)]
    for col_group in range(0, n_dim, 4):
        for k_group in range(0, k_dim, 4):
            for col in range(col_group, col_group + 4):
                index = (col_group // 4) * (k_dim // 4) * 4 + \
                        (k_group // 4) * 4 + col - col_group
                word = memory[base + index * 4]
                for lane in range(4):
                    result[k_group + lane][col] = signed_i8(word >> (lane * 8))
    return result


def decode_gemv_rhs(memory: dict[int, int], base: int, k_dim: int) -> list[list[int]]:
    """Decode opcode 0x52's K-major rows with N padded to 16 bytes."""
    result = [[0] * 16 for _ in range(k_dim)]
    for k in range(k_dim):
        for col in range(16):
            word = memory[base + (k * 4 + col // 4) * 4]
            result[k][col] = signed_i8(word >> ((col % 4) * 8))
    return result


def gemm(a: list[list[int]], b: list[list[int]]) -> list[list[int]]:
    if not a or not b or len(a[0]) != len(b):
        raise ValueError("incompatible independent Golden matrix shapes")
    return [[sum(a[row][k] * b[k][col] for k in range(len(b)))
             for col in range(len(b[0]))] for row in range(len(a))]


def transpose(matrix: list[list[int]]) -> list[list[int]]:
    return [list(column) for column in zip(*matrix)]


def requant(matrix: list[list[int]], shift: int) -> list[list[int]]:
    return [[max(-128, min(127, value >> shift)) for value in row]
            for row in matrix]


def layernorm_q15(values: list[int], gamma: list[int], beta: list[int]) -> list[int]:
    total = sum(values)
    mean = total // len(values) if total >= 0 else -((-total) // len(values))
    variance = sum((value - mean) ** 2 for value in values) // len(values)
    root = max(math.isqrt(variance + 1), 1)
    reciprocal = (1 << 30) // root
    result = []
    for value, scale, offset in zip(values, gamma, beta):
        scaled = ((value - mean) * scale) >> 15
        scaled = max(-(1 << 31), min((1 << 31) - 1, scaled))
        normalized = (scaled * reciprocal) >> 30
        result.append(max(-(1 << 31), min((1 << 31) - 1, normalized + offset)))
    return result


def residual(lhs: list[int], rhs: list[int]) -> list[int]:
    return [max(-(1 << 31), min((1 << 31) - 1, a + b))
            for a, b in zip(lhs, rhs)]


def gelu_q8_8(value: int) -> int:
    if value <= -512:
        return 0
    if value >= 512:
        return value
    return (value * (value + 512)) >> 10


def softmax_q15(scores: list[int]) -> list[int]:
    maximum = max(scores)
    exponentials = []
    for value in scores:
        delta = value - maximum
        if delta >= 0:
            exp_value = 1 << 15
        else:
            magnitude = -delta
            integer, fraction = magnitude >> 8, magnitude & 0xFF
            if integer >= 15:
                exp_value = 0
            else:
                base = (1 << 15) >> integer
                exp_value = base - (((base - (base >> 1)) * fraction) >> 8)
        exponentials.append(exp_value)
    total = sum(exponentials)
    if total == 0:
        raise ValueError("softmax denominator unexpectedly zero")
    return [min(1 << 15, (value << 15) // total) for value in exponentials]


def pack_matrix_a(matrix: list[list[int]]) -> list[int]:
    words = []
    for row_group in range(0, len(matrix), 4):
        for k_group in range(0, len(matrix[0]), 4):
            for row in range(row_group, row_group + 4):
                words.append(pack_i8(matrix[row][k_group:k_group + 4]))
    return words


def pack_row_major(matrix: list[list[int]]) -> list[int]:
    flat = [value for row in matrix for value in row]
    return [pack_i8(flat[index:index + 4]) for index in range(0, len(flat), 4)]


def add_i32(result: dict[int, int], base: int, matrix: list[list[int]]) -> None:
    for row, values in enumerate(matrix):
        for col, value in enumerate(values):
            result[base + 4 * (row * len(values) + col)] = value & MASK32


def add_i8(result: dict[int, int], base: int, matrix: list[list[int]], tile_a: bool) -> None:
    words = pack_matrix_a(matrix) if tile_a else pack_row_major(matrix)
    for index, word in enumerate(words):
        result[base + 4 * index] = word & MASK32


def descriptor_words(contract: dict[str, int]) -> list[int]:
    words = [0] * 16
    words[0] = (contract["task_id"] << 16) | contract["opcode"]
    words[1], words[2], words[3], words[4] = (
        contract["src0"], contract["src1"], contract["bias"], contract["dst"]
    )
    words[5] = (contract["n"] << 16) | contract["m"]
    words[6], words[7], words[8] = contract["k_words"], contract["flags"], contract["aux0"]
    words[9] = (contract["shift"] & 0x1F) | ((contract["activation"] & 0x3) << 5)
    words[10] = contract["src0_stride"]
    words[11] = contract["src1_stride"]
    words[14] = (contract["signal_mask"] << 16) | contract["wait_mask"]
    words[12] = contract["dst_stride"]
    words[13] = (contract["head_count"] << 16) | contract["batch_count"]
    words[15] = 7
    words[15] = (contract["clear_mask"] << 16) | 7
    return [word & MASK32 for word in words]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--workload-dir", type=Path, required=True)
    args = parser.parse_args()
    model_bytes = args.model.read_bytes()
    model = json.loads(model_bytes)
    manifest = json.loads((args.workload_dir / "manifest.json").read_text())
    memory_path = args.workload_dir / "model_memory.memh"
    golden_path = args.workload_dir / "model_golden.memh"
    memory, actual = load_pairs(memory_path), load_pairs(golden_path)
    if hashlib.sha256(model_bytes).hexdigest() != manifest["model_sha256"]:
        raise ValueError("model hash differs from workload manifest")
    if hashlib.sha256(memory_path.read_bytes()).hexdigest() != manifest["memory_sha256"]:
        raise ValueError("SPAD memory image hash differs from manifest")
    if hashlib.sha256(golden_path.read_bytes()).hexdigest() != manifest["golden_sha256"]:
        raise ValueError("Golden image hash differs from manifest")
    if model["shape"] != {
        "hidden": 16, "attention_heads": 2, "head_dim": 8,
        "layers": 1, "sequence_length": 8, "dtype": "signed INT8",
    }:
        raise ValueError("model shape does not match H16/two-head/Seq8 contract")
    if manifest["descriptor_count"] != len(manifest["descriptor_contract"]):
        raise ValueError("descriptor count and manifest contract disagree")
    if manifest["descriptor_count"] > 128:
        raise ValueError("Top smoke CPLQ supports at most 128 descriptors")
    if manifest.get("runtime_ordering") != (
        "single ABI event-bit completion chain; each descriptor waits for and "
        "clears the preceding descriptor's ordered-retirement event"
    ):
        raise ValueError("H16 attention workload must declare its serialized ordering")

    tensors = manifest["tensors"]
    expected: dict[int, int] = {}
    contracts = manifest["descriptor_contract"]
    for index, contract in enumerate(contracts):
        expected_wait = 0 if index == 0 else 1
        expected_clear = 0 if index == 0 else 1
        expected_signal = 0 if index + 1 == len(contracts) else 1
        if (contract["wait_mask"], contract["clear_mask"],
                contract["signal_mask"]) != (
                    expected_wait, expected_clear, expected_signal):
            raise ValueError(
                f"descriptor {index} violates the ordered completion chain: "
                f"wait={contract['wait_mask']:#x} "
                f"clear={contract['clear_mask']:#x} "
                f"signal={contract['signal_mask']:#x}"
            )
        address = manifest["descriptor_base"] + index * 64
        observed = [memory[address + 4 * word] for word in range(16)]
        if observed != descriptor_words(contract):
            raise ValueError(f"descriptor mismatch at index {index}: {contract}")
        if contract["task_id"] != 0x7100 + index:
            raise ValueError(f"non-monotonic task ID at descriptor {index}")

    x = decode_a(memory, tensors["h16_attention_input"]["address"], 8, 16)
    x_transpose = decode_b(memory, tensors["h16_attention_input_transpose"]["address"], 16, 8)
    token_x = [model["embeddings"][token] for token in model["prefill_tokens"]]
    if x != token_x or x_transpose != transpose(token_x):
        raise ValueError("physical Matrix-A input does not decode to model tokens")

    weights = model["weights"]
    qkv: dict[tuple[str, int], list[list[int]]] = {}
    for projection in ("q", "k", "v"):
        full = gemm(x, weights[f"w{projection}"])
        for head in range(2):
            name = f"h16_{projection}_head{head}"
            if projection == "v":
                wt = decode_a(memory, tensors[f"{name}_weight_transpose"]["address"], 8, 16)
                expected_weight = transpose(
                    [row[head * 8:(head + 1) * 8] for row in weights["wv"]]
                )
                if wt != expected_weight:
                    raise ValueError(f"{name} physical transposed A weight layout mismatch")
                raw = gemm(wt, x_transpose)
                if raw != transpose([[row[head * 8 + col] for col in range(8)]
                                     for row in full]):
                    raise ValueError(f"{name} transposed projection differs from QKV Golden")
            else:
                wt = decode_b(memory, tensors[f"{name}_weight"]["address"], 16, 8)
                expected_weight = [row[head * 8:(head + 1) * 8]
                                   for row in weights[f"w{projection}"]]
                if wt != expected_weight:
                    raise ValueError(f"{name} physical B weight layout mismatch")
                raw = [[row[head * 8 + col] for col in range(8)] for row in full]
            qkv[(projection, head)] = requant(raw, 0)
            add_i32(expected, tensors[f"{name}_i32"]["address"], raw)
            add_i8(expected, tensors[f"{name}_i8"]["address"],
                   qkv[(projection, head)], True)

    key_cache_name, value_cache_name = "h16_key_cache", "h16_value_cache"
    key_cache_addr = tensors[key_cache_name]["address"]
    value_cache_addr = tensors[value_cache_name]["address"]
    merged_expected = [[0] * 16 for _ in range(8)]
    for head in range(2):
        q = qkv[("q", head)]
        k = qkv[("k", head)]
        v_transposed = qkv[("v", head)]
        v = transpose(v_transposed)
        k_roundtrip = [row[:] for row in k]
        v_roundtrip = [row[:] for row in v]
        for index, word in enumerate(pack_matrix_a(k)):
            expected[key_cache_addr + head * 64 + index * 4] = word
        for index, word in enumerate(pack_matrix_a(v_transposed)):
            expected[value_cache_addr + head * 64 + index * 4] = word
        add_i8(expected, tensors[f"h16_k_head{head}_cache_readback"]["address"],
               k_roundtrip, True)
        add_i8(expected, tensors[f"h16_v_head{head}_cache_readback"]["address"],
               v_transposed, True)

        scores = gemm(q, transpose(k_roundtrip))
        score_tensor = tensors[f"h16_attention_head{head}_scores"]["address"]
        add_i32(expected, score_tensor, scores)
        probabilities = []
        for query, score_row in enumerate(scores):
            visible = softmax_q15(score_row[:query + 1])
            probabilities.append(visible + [0] * (8 - len(visible)))
        add_i32(expected,
                tensors[f"h16_attention_head{head}_prob_q15"]["address"],
                probabilities)
        probability_i8 = requant(probabilities, 8)
        add_i8(expected,
               tensors[f"h16_attention_head{head}_prob_i8"]["address"],
               probability_i8, True)
        attended = gemm(probability_i8, v_roundtrip)
        add_i32(expected, tensors[f"h16_attention_head{head}_av_i32"]["address"],
                attended)
        attended_i8 = requant(attended, 7)
        add_i8(expected, tensors[f"h16_attention_head{head}_av_i8"]["address"],
               attended_i8, True)
        if manifest.get("full_block"):
            wo = [row[:] for row in weights["wo"][head * 8:(head + 1) * 8]]
            decoded_wo = decode_b(
                memory, tensors[f"h16_attention_head{head}_wo_identity"]["address"],
                8, 16,
            )
            if decoded_wo != wo:
                raise ValueError(f"head {head} W_o physical Matrix-B layout mismatch")
        else:
            wo = [[0] * 16 for _ in range(8)]
            for lane in range(8):
                wo[lane][head * 8 + lane] = 1
        projected = gemm(attended_i8, wo)
        add_i32(expected,
                tensors[f"h16_attention_head{head}_wo_i32"]["address"],
                projected)
        for row in range(8):
            for col in range(16):
                merged_expected[row][col] += projected[row][col]

    add_i32(expected, tensors["h16_attention_head_merge_i32"]["address"],
            merged_expected)

    if manifest.get("full_block"):
        gamma1 = model.get("gamma1_q15", [32768] * 16)
        beta1 = model.get("beta1", [0] * 16)
        gamma2 = model.get("gamma2_q15", [32768] * 16)
        beta2 = model.get("beta2", [0] * 16)
        input_i32 = [row[:] for row in token_x]
        residual1 = [residual(a, b) for a, b in zip(merged_expected, input_i32)]
        norm1 = [layernorm_q15(row, gamma1, beta1) for row in residual1]
        norm1_i8 = requant(norm1, 0)
        wup_b = decode_b(memory, tensors["h16_wup"]["address"], 16, 16)
        wdown_b = decode_b(memory, tensors["h16_wdown"]["address"], 16, 16)
        if wup_b != weights["wup"] or wdown_b != weights["wdown"]:
            raise ValueError("FFN physical Matrix-B weight layout mismatch")
        ffn_up = gemm(norm1_i8, wup_b)
        gelu = [[gelu_q8_8(value) for value in row] for row in ffn_up]
        gelu_i8 = requant(gelu, 0)
        ffn_down = gemm(gelu_i8, wdown_b)
        residual2 = [residual(a, b) for a, b in zip(ffn_down, norm1)]
        norm2 = [layernorm_q15(row, gamma2, beta2) for row in residual2]
        for name, matrix in (
            ("h16_residual1_i32", residual1),
            ("h16_layernorm1_i32", norm1),
            ("h16_layernorm1_i8", norm1_i8),
            ("h16_ffn_up_i32", ffn_up),
            ("h16_ffn_gelu_i32", gelu),
            ("h16_ffn_gelu_i8", gelu_i8),
            ("h16_ffn_down_i32", ffn_down),
            ("h16_residual2_i32", residual2),
            ("h16_layernorm2_i32", norm2),
        ):
            tensor = tensors[name]
            if tensor["dtype"] == "i8_packed":
                add_i8(expected, tensor["address"], matrix, tile_a=True)
            else:
                add_i32(expected, tensor["address"], matrix)

        decode_token = model.get("decode_token")
        if not isinstance(decode_token, int) or not 0 <= decode_token < 16:
            raise ValueError("full-block model is missing a legal decode token")
        decode_input = model["embeddings"][decode_token]
        decode_merged = [[0] * 16 for _ in range(4)]
        decode_rows_per_head = {}
        for head in range(2):
            q_name = f"h16_decode_q_head{head}"
            q_weight = [row[head * 8:(head + 1) * 8]
                        for row in model["weights"]["wq"]]
            packed_q_weight = decode_gemv_rhs(
                memory, tensors[f"{q_name}_weight_gemv"]["address"], 16
            )
            if packed_q_weight != [row + [0] * 8 for row in q_weight]:
                raise ValueError(f"{q_name} opcode 0x52 RHS pack mismatch")
            q_raw = gemm([decode_input], q_weight)[0]
            q_i8 = requant([q_raw], 0)[0]
            q_rows = [q_i8] + [[0] * 8 for _ in range(3)]
            k_rows = qkv[("k", head)]
            v_rows = transpose(qkv[("v", head)])
            score = gemm(q_rows, transpose(k_rows))
            probability = [softmax_q15(score[0])] + [[0] * 8 for _ in range(3)]
            probability_i8 = requant(probability, 8)
            attended = gemm(probability_i8, v_rows)
            attended_i8 = requant(attended, 7)
            wo = [row[:] for row in model["weights"]["wo"][head * 8:(head + 1) * 8]]
            projected = gemm(attended_i8, wo)
            decode_rows_per_head[head] = {
                "q_raw": q_raw, "q_rows": q_rows, "score": score,
                "probability": probability, "probability_i8": probability_i8,
                "attended": attended, "attended_i8": attended_i8,
                "projected": projected,
            }
            for row in range(4):
                for col in range(16):
                    decode_merged[row][col] += projected[row][col]

        decode_input_rows = [decode_input] + [[0] * 16 for _ in range(3)]
        decode_residual1 = [residual(a, b)
                            for a, b in zip(decode_merged, decode_input_rows)]
        decode_norm1 = [layernorm_q15(row, gamma1, beta1)
                        for row in decode_residual1]
        decode_norm1_i8 = requant(decode_norm1, 0)
        decode_ffn_up = gemm(decode_norm1_i8, wup_b)
        decode_gelu = [[gelu_q8_8(value) for value in row]
                       for row in decode_ffn_up]
        decode_gelu_i8 = requant(decode_gelu, 0)
        decode_ffn_down = gemm(decode_gelu_i8, wdown_b)
        decode_residual2 = [residual(a, b)
                            for a, b in zip(decode_ffn_down, decode_norm1)]
        decode_norm2 = [layernorm_q15(row, gamma2, beta2)
                        for row in decode_residual2]
        if decode_norm2[0] != norm2[7]:
            raise ValueError(
                "single-token decode Golden differs from prefill output for the same token"
            )
        for head, tensors_for_head in decode_rows_per_head.items():
            add_i8(expected,
                   tensors[f"h16_decode_q_head{head}_matrix_a"]["address"],
                   tensors_for_head["q_rows"], tile_a=True)
            add_i32(expected,
                    tensors[f"h16_decode_head{head}_scores_i32"]["address"],
                    tensors_for_head["score"])
            prob_addr = tensors[f"h16_decode_head{head}_prob_q15"]["address"]
            for col, value in enumerate(tensors_for_head["probability"][0]):
                expected[prob_addr + 4 * col] = value & MASK32
            add_i8(expected,
                   tensors[f"h16_decode_head{head}_prob_i8"]["address"],
                   tensors_for_head["probability_i8"], tile_a=True)
            add_i32(expected,
                    tensors[f"h16_decode_head{head}_av_i32"]["address"],
                    tensors_for_head["attended"])
            add_i8(expected,
                   tensors[f"h16_decode_head{head}_av_i8"]["address"],
                   tensors_for_head["attended_i8"], tile_a=True)
            add_i32(expected,
                    tensors[f"h16_decode_head{head}_wo_i32"]["address"],
                    tensors_for_head["projected"])
        for name, matrix in (
            ("h16_decode_attention_merge_i32", decode_merged),
            ("h16_decode_residual1_i32", decode_residual1),
            ("h16_decode_layernorm1_i32", decode_norm1),
            ("h16_decode_layernorm1_i8", decode_norm1_i8),
            ("h16_decode_ffn_up_i32", decode_ffn_up),
            ("h16_decode_ffn_gelu_i32", decode_gelu),
            ("h16_decode_ffn_gelu_i8", decode_gelu_i8),
            ("h16_decode_ffn_down_i32", decode_ffn_down),
            ("h16_decode_residual2_i32", decode_residual2),
            ("h16_decode_layernorm2_i32", decode_norm2),
        ):
            tensor = tensors[name]
            if tensor["dtype"] == "i8_packed":
                add_i8(expected, tensor["address"], matrix, tile_a=True)
            else:
                add_i32(expected, tensor["address"], matrix)
    if actual != expected:
        missing = sorted(set(expected) - set(actual))
        extra = sorted(set(actual) - set(expected))
        mismatch = next(((address, actual[address], expected[address])
                         for address in sorted(set(actual) & set(expected))
                         if actual[address] != expected[address]), None)
        raise ValueError(
            f"independent Golden address/value mismatch: missing={len(missing)} "
            f"extra={len(extra)} first_value={mismatch!r}"
        )
    if any(memory.get(address) != POISON for address in expected):
        address = next(address for address in expected if memory.get(address) != POISON)
        raise ValueError(f"expected Top output was not poisoned before execution at {address:#x}")

    merged_hash = hashlib.sha256(b"".join(
        (value & MASK32).to_bytes(4, "little")
        for row in merged_expected for value in row
    )).hexdigest()
    labels = [(token + 1) % 16 for token in model["prefill_tokens"]]
    value_rows = gemm(x, weights["wv"])
    predictions = [max(range(16), key=row.__getitem__) for row in value_rows]
    accuracy = sum(a == b for a, b in zip(predictions, labels))
    print(
        "TRANSFORMER_H16_ATTENTION_INDEPENDENT_GOLDEN_PASS "
        f"descriptors={manifest['descriptor_count']} outputs={len(expected)} "
        f"useful_macs={manifest['useful_macs']} "
        f"merged_sha256={merged_hash} next_token_metric={accuracy}/8"
    )


if __name__ == "__main__":
    main()
