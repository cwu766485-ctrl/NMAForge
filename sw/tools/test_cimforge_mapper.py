#!/usr/bin/env python3
"""Unit checks for the ABI-v7 fused Matrix tile-forward descriptor fields."""

import unittest

from cimforge_mapper import (
    Descriptor,
    FLAG_TRANSPOSE_A,
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


if __name__ == "__main__":
    unittest.main(verbosity=2)
