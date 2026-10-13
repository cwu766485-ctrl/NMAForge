"""Deterministic raw-bit tests for :mod:`fp_reference`."""

from __future__ import annotations

import random
import unittest
from fractions import Fraction

import fp_reference as fp


class TestSpecSanityVectors(unittest.TestCase):
    def test_bf16_dot_11(self) -> None:
        self.assertEqual(fp.bf16_dot([0x3F80, 0x4000], [0x4040, 0x4080]), 0x41300000)

    def test_fp16_dot_11(self) -> None:
        self.assertEqual(fp.fp16_dot([0x3C00, 0x4000], [0x4200, 0x4400]), 0x41300000)

    def test_fp16_min_subnormal_dot(self) -> None:
        self.assertEqual(fp.fp16_dot([0x0001], [0x3C00]), 0x33800000)

    def test_fp16_zero_times_infinity_is_canonical_nan(self) -> None:
        self.assertEqual(fp.fp16_dot([0x0000], [0x7C00]), 0x7FC00000)

    def test_bf16_min_subnormal_dot(self) -> None:
        self.assertEqual(fp.bf16_dot([0x0001], [0x3F80]), 0x00010000)

    def test_bf16_zero_times_infinity_is_canonical_nan(self) -> None:
        self.assertEqual(fp.bf16_dot([0x0000], [0x7F80]), 0x7FC00000)

    def test_bf16_add_tie(self) -> None:
        self.assertEqual(fp.bf16_add_bits(0x3F80, 0x3B80), 0x3F80)

    def test_fp16_add_tie(self) -> None:
        self.assertEqual(fp.fp16_add_bits(0x3C00, 0x1000), 0x3C00)


class TestSpecialValuesAndZeroSigns(unittest.TestCase):
    def test_nan_inputs_are_canonicalized_for_both_formats(self) -> None:
        for nan in (0x7FC1, 0x7F81, 0xFFC1, 0xFF81):
            self.assertEqual(fp.bf16_add_bits(nan, 0x3F80), 0x7FC0)
            self.assertEqual(fp.bf16_add_bits(0x3F80, nan), 0x7FC0)
        for nan in (0x7E01, 0x7C01, 0xFE01, 0xFC01):
            self.assertEqual(fp.fp16_add_bits(nan, 0x3C00), 0x7E00)
        self.assertEqual(fp.fp32_add_bits(0x7F800001, 0x3F800000), 0x7FC00000)
        self.assertEqual(fp.fp32_mul_bits(0xFF800001, 0x3F800000), 0x7FC00000)

    def test_infinity_arithmetic(self) -> None:
        self.assertEqual(fp.bf16_add_bits(0x7F80, 0x3F80), 0x7F80)
        self.assertEqual(fp.fp16_add_bits(0xFC00, 0xBC00), 0xFC00)
        self.assertEqual(fp.fp32_add_bits(0x7F800000, 0xFF800000), 0x7FC00000)
        self.assertEqual(fp.fp32_mul_bits(0x00000000, 0x7F800000), 0x7FC00000)
        self.assertEqual(fp.fp32_mul_bits(0x80000000, 0x7F800000), 0x7FC00000)
        self.assertEqual(fp.fp32_mul_bits(0xFF800000, 0x40000000), 0xFF800000)

    def test_signed_zero_rules(self) -> None:
        self.assertEqual(fp.bf16_add_bits(0x8000, 0x8000), 0x8000)
        self.assertEqual(fp.bf16_add_bits(0x8000, 0x0000), 0x0000)
        self.assertEqual(fp.bf16_add_bits(0x3F80, 0xBF80), 0x0000)
        self.assertEqual(fp.fp16_add_bits(0xBC00, 0x3C00), 0x0000)
        self.assertEqual(fp.fp32_add_bits(0x80000000, 0x00000000), 0x00000000)
        self.assertEqual(fp.fp32_add_bits(0x80000000, 0x00000000, subtract=True), 0x80000000)
        self.assertEqual(fp.fp32_mul_bits(0x80000000, 0x3F800000), 0x80000000)
        self.assertEqual(fp.fp32_mul_bits(0x80000000, 0xBF800000), 0x00000000)


class TestRoundingAndGradualUnderflow(unittest.TestCase):
    def test_bf16_and_fp16_subnormal_round_trip(self) -> None:
        for raw in (0x0001, 0x0002, 0x003F, 0x007F, 0x8001, 0x807F):
            decoded = fp.decode_bf16(raw)
            self.assertEqual(fp.encode_fraction(decoded.value, fp.BF16, zero_sign=decoded.sign), raw)
        for raw in (0x0001, 0x0002, 0x01FF, 0x03FF, 0x8001, 0x83FF):
            decoded = fp.decode_fp16(raw)
            self.assertEqual(fp.encode_fraction(decoded.value, fp.FP16, zero_sign=decoded.sign), raw)
        self.assertEqual(fp.bf16_to_fp32_bits(0x0001), 0x00010000)
        self.assertEqual(fp.bf16_to_fp32_bits(0x8001), 0x80010000)
        self.assertEqual(fp.fp16_add_bits(0x0001, 0x0001), 0x0002)
        self.assertEqual(fp.bf16_add_bits(0x0001, 0x0001), 0x0002)

    def test_fp32_subnormal_tie_to_even(self) -> None:
        half = 0x3F000000
        self.assertEqual(fp.fp32_mul_bits(0x00000001, half), 0x00000000)
        self.assertEqual(fp.fp32_mul_bits(0x80000001, half), 0x80000000)
        self.assertEqual(fp.fp32_mul_bits(0x00000003, half), 0x00000002)
        self.assertEqual(fp.fp32_mul_bits(0x00000005, half), 0x00000002)

    def test_rounding_carry_at_normal_and_overflow_boundaries(self) -> None:
        # Halfway between largest subnormal and smallest normal rounds to the
        # latter because its trailing significand is even.
        near_normal = Fraction(2) ** fp.FP16.emin - Fraction(1, 2) * (Fraction(2) ** (fp.FP16.emin - fp.FP16.fraction_bits))
        self.assertEqual(fp.encode_fraction(near_normal, fp.FP16), 0x0400)
        self.assertEqual(fp.bf16_add_bits(0x7F7F, 0x7F7F), 0x7F80)
        self.assertEqual(fp.fp16_add_bits(0x7BFF, 0x7BFF), 0x7C00)
        self.assertEqual(fp.fp32_mul_bits(0x7F7FFFFF, 0x40000000), 0x7F800000)

        # For FP32, half an ulp above max finite is the RNE overflow tie.
        self.assertEqual(fp.fp32_add_bits(0x7F7FFFFF, 0x73000000), 0x7F800000)
        self.assertEqual(fp.fp32_add_bits(0x7F7FFFFF, 0x72800000), 0x7F7FFFFF)

    def test_overflow_midpoint_for_each_format(self) -> None:
        for fmt in (fp.BF16, fp.FP16, fp.FP32):
            max_finite = (
                (((1 << fmt.exponent_bits) - 2) << fmt.fraction_bits)
                | fmt.fraction_mask
            )
            exact_max = fp.decode(max_finite, fmt).value
            ulp = Fraction(2) ** (fmt.emax - fmt.fraction_bits)
            self.assertEqual(
                fp.encode_fraction(exact_max + ulp / 4, fmt), max_finite
            )
            self.assertEqual(
                fp.encode_fraction(exact_max + ulp / 2, fmt), fmt.infinity
            )


class TestExactConversionsAndDot(unittest.TestCase):
    def test_bf16_finite_conversion_is_exact(self) -> None:
        for raw in (0x0000, 0x8000, 0x0001, 0x807F, 0x0080, 0x3F80, 0x7F7F, 0xFF7F, 0x7F80, 0xFF80):
            self.assertEqual(fp.bf16_to_fp32_bits(raw), raw << 16)
        self.assertEqual(fp.bf16_to_fp32_bits(0x7F81), 0x7FC00000)
        self.assertEqual(fp.bf16_to_fp32_bits(0xFF81), 0x7FC00000)

    def test_dot_rounds_each_product_and_accumulation(self) -> None:
        self.assertEqual(fp.bf16_dot([], []), 0x00000000)
        self.assertEqual(fp.bf16_dot([0x3F80], [0x4040]), fp.fp32_mul_bits(0x3F800000, 0x40400000))
        self.assertEqual(fp.bf16_dot([0x7F80], [0x0000]), 0x7FC00000)
        with self.assertRaises(ValueError):
            fp.bf16_dot([0x3F80], [])
        with self.assertRaises(ValueError):
            fp.bf16_dot([0x10000], [0x3F80])


class TestDeterministicRandomFiniteVectors(unittest.TestCase):
    def test_random_finite_round_trip_identity_and_commutativity(self) -> None:
        rng = random.Random(0xF16B_F16)
        for fmt, decode_fn, add_fn, exponent_all_ones in (
            (fp.BF16, fp.decode_bf16, fp.bf16_add_bits, 0x7F80),
            (fp.FP16, fp.decode_fp16, fp.fp16_add_bits, 0x7C00),
        ):
            for _ in range(300):
                a = rng.randrange(1 << fmt.width)
                b = rng.randrange(1 << fmt.width)
                if (a & exponent_all_ones) == exponent_all_ones:
                    a ^= 1 << fmt.fraction_bits
                if (b & exponent_all_ones) == exponent_all_ones:
                    b ^= 1 << fmt.fraction_bits
                da, db = decode_fn(a), decode_fn(b)
                self.assertIn(da.kind, ("finite", "zero"))
                self.assertIn(db.kind, ("finite", "zero"))
                self.assertEqual(
                    fp.encode_fraction(da.value, fmt, zero_sign=da.sign), a
                )
                self.assertEqual(
                    fp.encode_fraction(db.value, fmt, zero_sign=db.sign), b
                )
                zero_identity = 0 if a == fmt.sign_mask else a
                self.assertEqual(add_fn(a, 0), zero_identity)
                self.assertEqual(add_fn(0, a), zero_identity)
                self.assertEqual(add_fn(a, b), add_fn(b, a))
                self.assertLessEqual(add_fn(a, b), (1 << fmt.width) - 1)

    def test_random_fp32_round_trip_add_and_multiply(self) -> None:
        rng = random.Random(0x32F00D)
        for _ in range(500):
            a = rng.randrange(1 << 32)
            b = rng.randrange(1 << 32)
            if (a & 0x7F800000) == 0x7F800000:
                a ^= 1 << 23
            if (b & 0x7F800000) == 0x7F800000:
                b ^= 1 << 23
            da, db = fp.decode_fp32(a), fp.decode_fp32(b)
            self.assertIn(da.kind, ("finite", "zero"))
            self.assertIn(db.kind, ("finite", "zero"))
            self.assertEqual(
                fp.encode_fraction(da.value, fp.FP32, zero_sign=da.sign), a
            )
            self.assertEqual(
                fp.encode_fraction(db.value, fp.FP32, zero_sign=db.sign), b
            )
            zero_identity = 0 if a == fp.FP32.sign_mask else a
            self.assertEqual(fp.fp32_add_bits(a, 0), zero_identity)
            self.assertEqual(fp.fp32_add_bits(a, b), fp.fp32_add_bits(b, a))
            self.assertEqual(fp.fp32_mul_bits(a, b), fp.fp32_mul_bits(b, a))


if __name__ == "__main__":
    unittest.main()
