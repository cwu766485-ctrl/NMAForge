"""Bit-exact software reference for the G1 BF16/FP16 arithmetic contract.

Finite arithmetic is performed with :class:`fractions.Fraction`; Python float
is deliberately not used as an oracle. Supported operations are BF16/FP16
add/sub, exact BF16-to-FP32 conversion, FP32 RNE add/multiply, and the
non-fused, sequentially rounded BF16 dot product.
"""

from __future__ import annotations

from dataclasses import dataclass
from fractions import Fraction
from typing import Iterable, Optional


@dataclass(frozen=True)
class FPFormat:
    name: str
    exponent_bits: int
    fraction_bits: int
    bias: int
    canonical_qnan: int

    @property
    def width(self) -> int:
        return 1 + self.exponent_bits + self.fraction_bits

    @property
    def emin(self) -> int:
        return 1 - self.bias

    @property
    def emax(self) -> int:
        return ((1 << self.exponent_bits) - 2) - self.bias

    @property
    def sign_mask(self) -> int:
        return 1 << (self.width - 1)

    @property
    def fraction_mask(self) -> int:
        return (1 << self.fraction_bits) - 1

    @property
    def exponent_mask(self) -> int:
        return (1 << self.exponent_bits) - 1

    @property
    def infinity(self) -> int:
        return self.exponent_mask << self.fraction_bits


BF16 = FPFormat("BF16", 8, 7, 127, 0x7FC0)
FP16 = FPFormat("FP16", 5, 10, 15, 0x7E00)
FP32 = FPFormat("FP32", 8, 23, 127, 0x7FC00000)


@dataclass(frozen=True)
class Decoded:
    format: FPFormat
    bits: int
    sign: int
    kind: str  # "zero", "finite", "inf", or "nan"
    value: Optional[Fraction]  # signed exact value for finite values; zero is 0


def _check_bits(bits: int, fmt: FPFormat) -> None:
    if not isinstance(bits, int) or bits < 0 or bits >= (1 << fmt.width):
        raise ValueError(f"{fmt.name} raw bits out of range: {bits!r}")


def decode(bits: int, fmt: FPFormat) -> Decoded:
    """Decode a raw IEEE-like bit pattern without converting through float."""
    _check_bits(bits, fmt)
    sign = (bits >> (fmt.width - 1)) & 1
    exponent = (bits >> fmt.fraction_bits) & fmt.exponent_mask
    fraction = bits & fmt.fraction_mask
    if exponent == fmt.exponent_mask:
        kind = "inf" if fraction == 0 else "nan"
        return Decoded(fmt, bits, sign, kind, None)
    if exponent == 0:
        if fraction == 0:
            return Decoded(fmt, bits, sign, "zero", Fraction(0))
        magnitude = Fraction(fraction) * _pow2(fmt.emin - fmt.fraction_bits)
    else:
        significand = (1 << fmt.fraction_bits) | fraction
        unbiased = exponent - fmt.bias
        magnitude = Fraction(significand) * _pow2(unbiased - fmt.fraction_bits)
    return Decoded(fmt, bits, sign, "finite", -magnitude if sign else magnitude)


def decode_bf16(bits: int) -> Decoded:
    return decode(bits, BF16)


def decode_fp16(bits: int) -> Decoded:
    return decode(bits, FP16)


def decode_fp32(bits: int) -> Decoded:
    return decode(bits, FP32)


def _pow2(exponent: int) -> Fraction:
    if exponent >= 0:
        return Fraction(1 << exponent)
    return Fraction(1, 1 << -exponent)


def _floor_log2(value: Fraction) -> int:
    """Return floor(log2(value)) for positive rational ``value`` exactly."""
    if value <= 0:
        raise ValueError("_floor_log2 requires a positive value")
    exponent = value.numerator.bit_length() - value.denominator.bit_length()
    if value < _pow2(exponent):
        exponent -= 1
    elif value >= _pow2(exponent + 1):
        exponent += 1
    return exponent


def _round_scaled_rne(value: Fraction, shift: int) -> int:
    """Round nonnegative ``value * 2**shift`` to integer, ties to even."""
    if value < 0:
        raise ValueError("_round_scaled_rne requires a nonnegative value")
    numerator = value.numerator
    denominator = value.denominator
    if shift >= 0:
        numerator <<= shift
    else:
        denominator <<= -shift
    quotient, remainder = divmod(numerator, denominator)
    twice_remainder = remainder << 1
    if twice_remainder > denominator or (
        twice_remainder == denominator and (quotient & 1)
    ):
        quotient += 1
    return quotient


def encode_fraction(
    value: Fraction,
    fmt: FPFormat,
    *,
    zero_sign: int = 0,
) -> int:
    """Round an exact rational to ``fmt`` using gradual-underflow RNE."""
    value = Fraction(value)
    if zero_sign not in (0, 1):
        raise ValueError("zero_sign must be 0 or 1")
    if value == 0:
        return fmt.sign_mask if zero_sign else 0

    sign = int(value < 0)
    magnitude = abs(value)
    exponent = _floor_log2(magnitude)
    if exponent >= fmt.emin:
        significand = _round_scaled_rne(
            magnitude, fmt.fraction_bits - exponent
        )
        # Rounding can carry from 1.111... to 10.000... .  This carry is
        # also the exact RNE overflow boundary at the largest finite value.
        if significand == (1 << (fmt.fraction_bits + 1)):
            significand >>= 1
            exponent += 1
        if exponent > fmt.emax:
            return (fmt.sign_mask if sign else 0) | fmt.infinity
        exponent_field = exponent + fmt.bias
        fraction_field = significand - (1 << fmt.fraction_bits)
        return (
            (fmt.sign_mask if sign else 0)
            | (exponent_field << fmt.fraction_bits)
            | fraction_field
        )

    # Subnormals use the fixed quantum 2**(emin-fraction_bits).  Rounding may
    # produce zero or carry into the smallest normal; both are intentional.
    subnormal = _round_scaled_rne(
        magnitude, fmt.fraction_bits - fmt.emin
    )
    if subnormal == 0:
        return fmt.sign_mask if sign else 0
    if subnormal >= (1 << fmt.fraction_bits):
        return (fmt.sign_mask if sign else 0) | (1 << fmt.fraction_bits)
    return (fmt.sign_mask if sign else 0) | subnormal


def bf16_to_fp32_bits(bits: int) -> int:
    """Exactly widen BF16 to FP32; either NaN encoding canonicalizes."""
    value = decode(bits, BF16)
    if value.kind == "nan":
        return FP32.canonical_qnan
    # Every finite BF16 and infinity is exactly representable by the same
    # sign/exponent/fraction fields in FP32; widening the raw word is exact.
    return bits << 16


def fp16_to_fp32_bits(bits: int) -> int:
    """Exactly widen FP16 to FP32; NaNs are canonicalized."""
    value = decode(bits, FP16)
    if value.kind == "nan":
        return FP32.canonical_qnan
    if value.kind == "inf":
        return _infinity(FP32, value.sign)
    return encode_fraction(value.value or Fraction(0), FP32,
                           zero_sign=value.sign)


def _infinity(fmt: FPFormat, sign: int) -> int:
    return (fmt.sign_mask if sign else 0) | fmt.infinity


def add_bits(lhs: int, rhs: int, fmt: FPFormat, *, subtract: bool = False) -> int:
    """Add/subtract two raw values, producing a canonical NaN when required."""
    left = decode(lhs, fmt)
    right = decode(rhs, fmt)
    if left.kind == "nan" or right.kind == "nan":
        return fmt.canonical_qnan

    rhs_sign = right.sign ^ int(subtract)
    if left.kind == "inf" or right.kind == "inf":
        if left.kind == "inf" and right.kind == "inf" and left.sign != rhs_sign:
            return fmt.canonical_qnan
        return _infinity(fmt, left.sign if left.kind == "inf" else rhs_sign)

    left_value = left.value or Fraction(0)
    right_value = right.value or Fraction(0)
    if subtract:
        right_value = -right_value

    if left.kind == "zero" and right.kind == "zero":
        # In RNE, equal-signed zero operands retain their sign; opposite
        # signed zeros produce +0. Subtraction has already flipped rhs_sign.
        return fmt.sign_mask if left.sign == rhs_sign and left.sign else 0

    exact = left_value + right_value
    # Any exact cancellation involving nonzero values is +0 in RNE.
    return encode_fraction(exact, fmt)


def multiply_bits(lhs: int, rhs: int, fmt: FPFormat) -> int:
    """Multiply two raw values with one RNE rounding to ``fmt``."""
    left = decode(lhs, fmt)
    right = decode(rhs, fmt)
    if left.kind == "nan" or right.kind == "nan":
        return fmt.canonical_qnan
    sign = left.sign ^ right.sign
    if (left.kind == "zero" and right.kind == "inf") or (
        left.kind == "inf" and right.kind == "zero"
    ):
        return fmt.canonical_qnan
    if left.kind == "inf" or right.kind == "inf":
        return _infinity(fmt, sign)
    if left.kind == "zero" or right.kind == "zero":
        return fmt.sign_mask if sign else 0
    return encode_fraction(left.value * right.value, fmt)  # type: ignore[operator]


def bf16_add_bits(lhs: int, rhs: int, *, subtract: bool = False) -> int:
    return add_bits(lhs, rhs, BF16, subtract=subtract)


def fp16_add_bits(lhs: int, rhs: int, *, subtract: bool = False) -> int:
    return add_bits(lhs, rhs, FP16, subtract=subtract)


def fp32_add_bits(lhs: int, rhs: int, *, subtract: bool = False) -> int:
    return add_bits(lhs, rhs, FP32, subtract=subtract)


def fp32_mul_bits(lhs: int, rhs: int) -> int:
    return multiply_bits(lhs, rhs, FP32)


def bf16_dot(a_values: Iterable[int], b_values: Iterable[int]) -> int:
    """Sequential BF16 dot with separately rounded FP32 product and sum."""
    a_items = tuple(a_values)
    b_items = tuple(b_values)
    if len(a_items) != len(b_items):
        raise ValueError("BF16 dot operands must have equal lengths")
    accumulator = 0  # FP32 +0
    for a_bits, b_bits in zip(a_items, b_items):
        a32 = bf16_to_fp32_bits(a_bits)
        b32 = bf16_to_fp32_bits(b_bits)
        product = fp32_mul_bits(a32, b32)
        accumulator = fp32_add_bits(accumulator, product)
    return accumulator


def fp16_dot(a_values: Iterable[int], b_values: Iterable[int]) -> int:
    """Sequential FP16 dot with exact FP32 products and rounded FP32 sums."""
    a_items = tuple(a_values)
    b_items = tuple(b_values)
    if len(a_items) != len(b_items):
        raise ValueError("FP16 dot operands must have equal lengths")
    accumulator = 0  # FP32 +0
    for a_bits, b_bits in zip(a_items, b_items):
        a32 = fp16_to_fp32_bits(a_bits)
        b32 = fp16_to_fp32_bits(b_bits)
        product = fp32_mul_bits(a32, b32)
        accumulator = fp32_add_bits(accumulator, product)
    return accumulator
