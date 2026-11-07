#!/usr/bin/env python3
"""Unit checks for the ABI-v7 fused Matrix tile-forward descriptor fields."""

import unittest

from cimforge_mapper import (
    Descriptor,
    FLAG_TRANSPOSE_A,
    OP_GEMM,
    OP_GEMV_KFOLD,
    OP_GEMM_REQUANT_TILE_A,
    build_workload,
    validate_fused_tile_fields,
)


class FusedTileFieldTests(unittest.TestCase):
    def descriptor(self, **changes):
        fields = dict(
            name="fused_tile",
            task_id=1,
            op=OP_GEMM_REQUANT_TILE_A,
            src0=0x1000,
            src1=0x2000,
            dst=0x3000,
            m=16,
            n=16,
            k_or_length=4,
        )
        fields.update(changes)
        return Descriptor(**fields)

    def test_accepts_capture_consume_and_ping_pong(self):
        for aux0 in (0x1F, 0x20, 0x40, 0x60 | 0x1F):
            with self.subTest(aux0=aux0):
                validate_fused_tile_fields(self.descriptor(aux0=aux0))

    def test_rejects_reserved_bits_and_bad_capture_shape(self):
        cases = (
            dict(aux0=0x80),
            dict(aux0=0x20, m=8),
            dict(aux0=0x20, dst_stride=16),
        )
        for changes in cases:
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                validate_fused_tile_fields(self.descriptor(**changes))

    def test_rejects_bad_consume_contract(self):
        cases = (
            dict(aux0=0x40, k_or_length=3),
            dict(aux0=0x40, flags=FLAG_TRANSPOSE_A),
            dict(aux0=0x40, src0_stride=16),
        )
        for changes in cases:
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                validate_fused_tile_fields(self.descriptor(**changes))


class TransformerPhaseBoundaryTests(unittest.TestCase):
    def test_prefill_decode_descriptor_boundary(self):
        mapper, expected = build_workload()

        self.assertEqual(len(mapper.descriptors), 86)
        self.assertEqual(expected["prefill_descriptor_count"], 46)
        self.assertEqual(
            mapper.descriptors[expected["prefill_descriptor_count"]].name,
            "decode_q_projection",
        )
        self.assertEqual(mapper.descriptors[46].op, OP_GEMM)

    def test_optional_decode_gemv_keeps_golden_and_legacy_default(self):
        legacy_mapper, legacy_expected = build_workload()
        gemv_mapper, gemv_expected = build_workload(decode_mapping_policy="gemv_qkv")

        self.assertEqual(len(legacy_mapper.descriptors), 86)
        self.assertEqual(len(gemv_mapper.descriptors), 86)
        self.assertEqual(
            {key: value for key, value in legacy_expected.items()
             if key != "decode_mapping_policy"},
            {key: value for key, value in gemv_expected.items()
             if key != "decode_mapping_policy"},
        )
        self.assertEqual(gemv_expected["decode_mapping_policy"], "gemv_qkv")
        by_name = {descriptor.name: descriptor for descriptor in gemv_mapper.descriptors}
        for name in ("decode_q_projection", "decode_k_projection", "decode_v_projection"):
            descriptor = by_name[name]
            self.assertEqual(descriptor.op, OP_GEMV_KFOLD)
            self.assertEqual((descriptor.m, descriptor.n, descriptor.k_or_length), (1, 4, 4))
            self.assertEqual((descriptor.batch_count, descriptor.head_count), (1, 0))
            self.assertEqual(descriptor.words()[13], 1)
            self.assertEqual(descriptor.flags, 0)
            self.assertEqual(descriptor.aux0, 0)
            self.assertEqual(descriptor.src0 & 0xF, 0)
            self.assertEqual(descriptor.src1 & 0xF, 0)
            self.assertEqual(descriptor.dst & 0x3, 0)

        # First B K-row is [Wq[0,0], Wq[1,0], Wq[2,0], Wq[3,0]],
        # followed by twelve zero output columns to meet the 0x52 contract.
        self.assertEqual(
            gemv_mapper.tensors["decode_wq_gemv"].values[:4],
            [0x00010001, 0, 0, 0],
        )
        for tensor_name in ("decode_q_i32", "decode_k_i32", "decode_v_i32"):
            tensor = gemv_mapper.tensors[tensor_name]
            self.assertTrue(tensor.initialized)
            self.assertEqual(tensor.values, [0] * 16)

    def test_rejects_unknown_decode_mapping_policy(self):
        with self.assertRaises(ValueError):
            build_workload(decode_mapping_policy="gemv_everything")


if __name__ == "__main__":
    unittest.main(verbosity=2)
