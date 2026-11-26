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
