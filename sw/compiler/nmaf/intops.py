"""Bit-exact numpy models of the NMAForge Product Top operators.

Each function reproduces the RTL contract of one descriptor type and is the
single source of truth for both the compiler Golden and the integer accuracy
model.  All arithmetic is int64; inputs are integer ndarrays.
"""

from __future__ import annotations

import numpy as np

I32_MIN, I32_MAX = -(1 << 31), (1 << 31) - 1


def clamp_i32(x: np.ndarray) -> np.ndarray:
    return np.clip(x, I32_MIN, I32_MAX)


def sat8(x: np.ndarray) -> np.ndarray:
    return np.clip(x, -128, 127)


def gemm(a_i8: np.ndarray, b_i8: np.ndarray, bias: np.ndarray | None, shift: int) -> np.ndarray:
    """Matrix 0x30: (A @ B + bias) >> shift (arithmetic, floor), INT32 result."""
    # float64 BLAS is exact here: |sum| <= K * 128 * 128 << 2^53.
    acc = np.rint(a_i8.astype(np.float64) @ b_i8.astype(np.float64)).astype(np.int64)
    if bias is not None:
        acc = acc + bias.astype(np.int64)[None, :]
    return acc >> shift


def requant(x: np.ndarray, shift: int, round_nearest: bool = False) -> np.ndarray:
    """SFU 0x36: sat8(x >> s), or sat8((x + 2^(s-1)) >> s) with flag[7]."""
    x = x.astype(np.int64)
    if round_nearest and shift:
        x = x + (1 << (shift - 1))
    return sat8(x >> shift)


def lut_act(x: np.ndarray, shift: int, lut: np.ndarray) -> np.ndarray:
    """SFU 0x35 + flag[7]: LUT[sat8((x + 2^(s-1)) >> s) + 128]."""
    code = requant(x, shift, round_nearest=True)
    return lut.astype(np.int64)[code + 128]


def residual(x: np.ndarray, y: np.ndarray, shift: int = 0) -> np.ndarray:
    """SFU 0x34: clamp_i32((x + y) >> shift)."""
    return clamp_i32((x.astype(np.int64) + y.astype(np.int64)) >> shift)


def isqrt(v: np.ndarray) -> np.ndarray:
    r = np.floor(np.sqrt(v.astype(np.float64))).astype(np.int64)
    r = np.where(r * r > v, r - 1, r)
    r = np.where((r + 1) * (r + 1) <= v, r + 1, r)
    return r


def layernorm_rows(x: np.ndarray, gamma_q15: np.ndarray, beta: np.ndarray, eps: int = 1) -> np.ndarray:
    """SFU 0x38 LAYERNORM_Q15 applied independently to each row."""
    x = x.astype(np.int64)
    n = x.shape[-1]
    eps = 1 if eps == 0 else eps
    s = x.sum(-1, keepdims=True)
    mean = np.where(s >= 0, s // n, -((-s) // n))              # truncate toward zero
    d = x - mean
    var = (d * d).sum(-1, keepdims=True) // n
    root = np.maximum(isqrt(var + eps), 1)
    recip = (1 << 30) // root
    scaled = clamp_i32((d * gamma_q15.astype(np.int64)[None, :]) >> 15)
    norm = (scaled * recip) >> 30
    return clamp_i32(norm + beta.astype(np.int64)[None, :])


def exp2_pwl_q15(delta: np.ndarray) -> np.ndarray:
    m = np.maximum(-delta, 0)
    ip = m >> 8
    fr = m & 255
    base = np.where(ip >= 15, 0, np.int64(32768) >> np.minimum(ip, 15))
    nxt = base >> 1
    out = base - (((base - nxt) * fr) >> 8)
    out = np.where(ip >= 15, 0, out)
    return np.where(delta >= 0, 32768, out)


def softmax_rows(scores_q88: np.ndarray, length: int) -> np.ndarray:
    """SFU 0x32 over the first `length` columns of each row (Q15 output)."""
    s = scores_q88[:, :length].astype(np.int64)
    e = exp2_pwl_q15(s - s.max(-1, keepdims=True))
    total = e.sum(-1, keepdims=True)
    return np.clip((e << 15) // total, 0, 32768)


def causal_softmax_rows(scores_q88: np.ndarray, q0: int = 0) -> np.ndarray:
    """SFU 0x39 on each row r with query index q0 + r: columns > q0 + r are
    excluded from max/sum and written as 0 (Q15 output, inclusive mask)."""
    s = scores_q88.astype(np.int64)
    rows, n = s.shape
    keep = np.arange(n)[None, :] <= (q0 + np.arange(rows))[:, None]
    mx = np.where(keep, s, np.iinfo(np.int64).min).max(-1, keepdims=True)
    e = np.where(keep, exp2_pwl_q15(s - mx), 0)
    total = e.sum(-1, keepdims=True)
    return np.where(keep, np.clip((e << 15) // total, 0, 32768), 0)


# ------------------------------------------------------------------ layouts
def pack_a(m: np.ndarray) -> np.ndarray:
    """Matrix-A tile layout: word (r//4)*K + (k//4)*4 + r%4, bytes k%4 (LE)."""
    rows, k = m.shape
    if rows % 4 or k % 4:
        raise ValueError("Matrix-A rows and K must be multiples of four")
    v = (m.astype(np.int64) & 0xFF).reshape(rows // 4, 4, k // 4, 4)   # rg, rl, kg, kl
    w = v[..., 0] | (v[..., 1] << 8) | (v[..., 2] << 16) | (v[..., 3] << 24)
    return w.transpose(0, 2, 1).reshape(-1)                            # rg, kg, rl


def pack_b(m: np.ndarray) -> np.ndarray:
    """Matrix-B layout of [K, N]; identical to pack_a of the transpose."""
    return pack_a(np.ascontiguousarray(m.T))


def words_i32(x: np.ndarray) -> np.ndarray:
    return x.astype(np.int64).reshape(-1) & 0xFFFFFFFF


def pack_lut(lut: np.ndarray) -> np.ndarray:
    v = (lut.astype(np.int64) & 0xFF).reshape(64, 4)
    return v[:, 0] | (v[:, 1] << 8) | (v[:, 2] << 16) | (v[:, 3] << 24)


# ------------------------------------------------ INT4 block-exponent stream
# 0x60 flags[1]: a 256-byte super-block = one shift beat (32 x 4-bit, line
# j uses nibble j) + 15 data beats; data beat b expands into lines 2b, 2b+1
# (low / high 64 bits), byte i = sat8(sext4(nibble i) << min(shift, 4)).
I4_LINES_PER_SB = 30


def i4_line_shift(line: np.ndarray) -> int:
    """Smallest shift s <= 4 with line == (line >> s) << s and line >> s in
    [-8, 7]; raises if the INT8 line is not an INT4 block-exponent image."""
    v = np.asarray(line, dtype=np.int64)
    for s in range(5):
        q = v >> s
        if np.all((q << s) == v) and q.min() >= -8 and q.max() <= 7:
            return s
    raise ValueError("line is not representable as INT4 << shift")


def pack_i4_stream(lines: np.ndarray) -> np.ndarray:
    """INT8 SPAD lines [n, 16] -> DDR words of INT4 super-blocks (the line
    count is padded to a multiple of 30 with zero lines)."""
    lines = np.asarray(lines, dtype=np.int64).reshape(-1, 16)
    n_sb = -(-len(lines) // I4_LINES_PER_SB)
    pad = np.zeros((n_sb * I4_LINES_PER_SB - len(lines), 16), np.int64)
    lines = np.concatenate([lines, pad])
    out = np.zeros((n_sb, 16, 4), np.int64)            # [sb, beat, word]
    for sb in range(n_sb):
        blk = lines[sb * I4_LINES_PER_SB:(sb + 1) * I4_LINES_PER_SB]
        shifts = [i4_line_shift(l) for l in blk]
        sh_bits = 0
        for j, sv in enumerate(shifts):
            sh_bits |= sv << (4 * j)
        for w in range(4):
            out[sb, 0, w] = (sh_bits >> (32 * w)) & 0xFFFFFFFF
        for b in range(15):
            nib = 0
            for h in range(2):
                l = blk[2 * b + h] >> shifts[2 * b + h]
                for i in range(16):
                    nib |= (int(l[i]) & 0xF) << (64 * h + 4 * i)
            for w in range(4):
                out[sb, 1 + b, w] = (nib >> (32 * w)) & 0xFFFFFFFF
    return out.reshape(-1)


def expand_i4_stream(words: np.ndarray) -> np.ndarray:
    """Reference hardware expansion: DDR words -> INT8 SPAD lines [n, 16]."""
    w = np.asarray(words, dtype=np.int64).reshape(-1, 16, 4) & 0xFFFFFFFF
    lines = []
    for sb in w:
        sh = sum(int(sb[0, k]) << (32 * k) for k in range(4))
        for b in range(15):
            beat = sum(int(sb[1 + b, k]) << (32 * k) for k in range(4))
            for h in range(2):
                j = 2 * b + h
                s = min((sh >> (4 * j)) & 0xF, 4)
                half = (beat >> (64 * h)) & ((1 << 64) - 1)
                nib = np.array([(half >> (4 * i)) & 0xF for i in range(16)], np.int64)
                nib = np.where(nib >= 8, nib - 16, nib)
                lines.append(np.clip(nib << s, -128, 127))
    return np.array(lines, np.int64).reshape(-1, 16)


def lines_to_words(lines: np.ndarray) -> np.ndarray:
    """INT8 lines [n, 16] -> little-endian INT32 words [n * 4]."""
    b = (np.asarray(lines, dtype=np.int64).reshape(-1, 4) & 0xFF)
    return b[:, 0] | (b[:, 1] << 8) | (b[:, 2] << 16) | (b[:, 3] << 24)
