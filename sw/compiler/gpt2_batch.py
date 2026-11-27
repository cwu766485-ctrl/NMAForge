#!/usr/bin/env python3
"""Multi-sequence GPT-2 decode on NMAForge Product Top (Round 40).

The four GEMM rows of a decode step carry four independent sequences (slots)
in lockstep at a common position p, so every weight read (Q/K/V/O, FC1/FC2)
serves four tokens.  Attention stays per sequence.  With --batch 1 only slot 0
is active and the same code path gives the single-stream reference.

Prompts are prefilled by the bit-exact integer Golden on the host and their
per-sequence K/V caches are placed in DDR, so the program measures decode only.

Per head and step (L = p%4, g = p//4, n4 = 4(g+1)):
  Q, K = XP W                        (4 slots as rows)
  V^T_exp = W_v^T XE^T, N = 16       XE: packed-A [16, D], group s lane L = x_s,
                                     built per slot from a 4-row window W4 whose
                                     row L holds LN(x_s); other lanes are zero
  pack -> VTE8: for slot s the cache words of position group g with byte lane
  L = v_s and all other lanes 0.  Cache words (DDR) -> VG, VG += VTE8 (INT32
  add; lanes >= L of a cache word are still zero, so this inserts byte L),
  VG -> DDR.  The K row of slot s is a whole-word store.

--attn-engine matrix (packed-A caches, as gpt2_compile.py):
  K   packed-A [kmax, hd], V^T packed-A [hd, kmax]
  S_s = Q8 K_s^T (row s); causal softmax of row s into PR_s (other rows zero);
  P8_s = pack(PR_s); AVO = sum_s P8_s V_s with the GEMM accumulate epilogue
  (rows != s give (0 + half) >> sh = 0).  Rounded like the prefill path.
--attn-engine cnm (row-major caches, opcode 0x21 on the bank-local CNM):
  K   row-major [kmax, hd], V^T row-major [hd, kmax]
  S_s = (K_s q_s) >> sh_s and AV_s = (V_s^T p8_s) >> sh_a, both floor (the
  CNM has no bias input).  The schedule interleaves the Matrix work of head
  h+1 with the attention of head h (double-buffered head scratch), so the CNM
  and the Matrix run concurrently.

    python sw/compiler/gpt2_batch.py --model-dir <gpt2> --wikitext <parquet> \\
        --layers 12 --batch 4 --prompt-len 30 --decode-steps 4 --out /tmp/gb4
"""

from __future__ import annotations

import argparse
import itertools
import json
import pickle
import sys
import time
from pathlib import Path

import numpy as np
import torch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gpt2_compile as G                                        # noqa: E402
from gpt2_compile import CH, FLAG7, LN_RB, PACK, half           # noqa: E402
from nmaf import intops as I                                     # noqa: E402
from nmaf.program import FLAG_GEMM_ACC, Program                  # noqa: E402
from cimforge_mapper import (FLAG_BIAS, FLAG_PACK_I8, OP_CAUSAL_SOFTMAX,  # noqa: E402
                             OP_GEMM, OP_GELU, OP_LAYERNORM, OP_REQUANT, OP_RESIDUAL)

SLOTS = 4                       # GEMM row granule = sequences per step
XE_N = 16                       # V^T_exp columns: 4 slots x 4 byte lanes
OP_CNM_GEMV = 0x21


# ------------------------------------------------------------------ Golden
def forward_batch(ql: G.QuantLayer, x: np.ndarray, p: int, caches: list, active: list,
                  attn: str = "matrix") -> np.ndarray:
    """x: [4, D] INT32 residual rows, slot s at position p.  caches[s]: per-head
    {"k": [kmax, hd], "v": [kmax, hd]} INT8, updated in place for active slots."""
    HD, n4 = ql.HD, 4 * (p // 4 + 1)
    xp = ql._ln(x, ql.ln1)
    acc = None
    for h in range(ql.H):
        q8 = I.requant(I.gemm(xp, ql.wq[h], ql.bq[h], ql.sh_q[h]), 0)
        k8 = I.requant(I.gemm(xp, ql.wk[h], ql.bk[h], ql.sh_k[h]), 0)
        vt8 = I.requant(I.gemm(ql.wvt[h], xp.T, np.full(SLOTS, half(ql.sh_v[h])), ql.sh_v[h]), 0)
        av8 = np.zeros((SLOTS, HD), np.int64)
        for s in active:
            c = caches[s][h]
            kmax = c["k"].shape[0]
            c["k"][p] = k8[s]
            c["v"][p] = vt8[:, s]
            if attn == "cnm":
                sc = I.gemm(q8[s:s + 1], c["k"][:n4].T, None, ql.sh_s[h])
            else:
                sc = I.gemm(q8[s:s + 1], c["k"][:n4].T, np.full(n4, half(ql.sh_s[h])), ql.sh_s[h])
            pr = I.causal_softmax_rows(sc, p)
            p8 = np.zeros((1, kmax), np.int64)
            p8[:, :n4] = I.requant(pr, 8, round_nearest=True)
            bias = None if attn == "cnm" else np.full(HD, half(ql.sh_a[h]))
            av8[s] = I.requant(I.gemm(p8, c["v"], bias, ql.sh_a[h]), 0)[0]
        acc = ql._acc(acc, I.gemm(av8, ql.wo[h], ql.bo[h], ql.sh_o[h]))
    if ql.stats["acc_peak"] << max(0, -ql.s_o) >= 2 ** 30:
        raise OverflowError("attention accumulator exceeds 2^30")
    x1 = I.residual(x, ql.rescale(acc, ql.s_o))
    x2p = ql._ln(x1, ql.ln2)
    acc = None
    for c in range(ql.NC):
        u = I.gemm(x2p, ql.w1[c], ql.b1[c], 0)
        h8 = I.lut_act(u, ql.sh_l[c], ql.lut[c])
        acc = ql._acc(acc, I.gemm(h8, ql.w2[c], ql.b2[c], ql.sh_2[c]))
    if ql.stats["acc_peak"] << max(0, -ql.s_2) >= 2 ** 30:
        raise OverflowError("FFN accumulator exceeds 2^30")
    return I.residual(x1, ql.rescale(acc, ql.s_2))


# ------------------------------------------------------------------ SPAD map
def allocate_batch(P: Program, D: int, HD: int, kmax: int) -> dict:
    """Decode SPAD map; the weight pool takes what the fixed buffers leave."""
    def build(w_slots):
        P.next_addr, P.regions = 0, {}
        R = {"_rot": {}}
        fixed = [("X", SLOTS * D * 4), ("ACC", SLOTS * D * 4), ("XP", SLOTS * D),
                 ("LNT", SLOTS * D * 4), ("W4", 4 * D * 4), ("ZERO", D * 4), ("XE", XE_N * D),
                 ("AVO", SLOTS * HD * 4), ("AV8", SLOTS * HD),
                 ("H1", SLOTS * CH * 4), ("H8", SLOTS * CH)]
        for nm, sz in fixed:
            R[nm] = P.alloc(nm, sz)
        for b in range(2):                         # head scratch, double-buffered
            for nm, sz in (("PROJ", HD * XE_N * 4), ("Q8", SLOTS * HD), ("K8", SLOTS * HD),
                           ("VTE8", HD * XE_N), ("VG", HD * XE_N)):
                R[f"{nm}{b}"] = P.alloc(f"{nm}{b}", sz)
        for s in range(SLOTS):
            R[f"SC{s}"] = P.alloc(f"SC{s}", SLOTS * kmax * 4)
            R[f"PR{s}"] = P.alloc(f"PR{s}", SLOTS * kmax * 4)
            R[f"P8{s}"] = P.alloc(f"P8{s}", SLOTS * kmax)
        w_bytes = D * HD
        if getattr(P, "weight_i4", ()):
            w_bytes = -(-w_bytes // 480) * 480
        sizes = {"W": w_bytes, "LN": 2 * D * 4, "HB": (HD + HD + kmax + kmax + HD + D) * 4,
                 "CB": (CH + 64 + D) * 4, "KC": kmax * HD, "VC": kmax * HD}
        kv = max(SLOTS, min(8, 512 // kmax))       # one per slot; 2x for the CNM pipeline
        pools = {"W": w_slots, "LN": 2, "HB": 3, "CB": 2, "KC": kv, "VC": kv}
        for kind in ("W", "LN", "HB", "CB", "KC", "VC"):
            R[kind + "_slots"] = [P.alloc(f"{kind}{i}", sizes[kind]) for i in range(pools[kind])]
        return R
    for w in (8, 7, 6, 5, 4, 3, 2):
        try:
            return build(w)
        except ValueError:
            continue
    raise ValueError("decode SPAD map does not fit")


def put_caches(P: Program, li: int, caches: list, active: list, attn: str):
    for s in active:
        for h, c in enumerate(caches[s]):
            vt = np.ascontiguousarray(c["v"].T)
            if attn == "cnm":
                P.ddr_put(f"L{li}.kc{h}s{s}", I.lines_to_words(c["k"].reshape(-1, 16)))
                P.ddr_put(f"L{li}.vc{h}s{s}", I.lines_to_words(vt.reshape(-1, 16)))
            else:
                P.ddr_put(f"L{li}.kc{h}s{s}", I.pack_a(c["k"]))
                P.ddr_put(f"L{li}.vc{h}s{s}", I.pack_a(vt))


# ------------------------------------------------------------------ emission
def emit_layer_batch(P: Program, ql: G.QuantLayer, li: int, R: dict, x_in: np.ndarray, p: int,
                     caches: list, kmax: int, tag: str, active: list,
                     attn: str = "matrix") -> np.ndarray:
    D, H, HD = ql.D, ql.H, ql.HD
    L, g, n4 = p % 4, p // 4, 4 * (p // 4 + 1)
    cnm = attn == "cnm"
    out = forward_batch(ql, x_in, p, caches, active, attn)
    base, mem = f"{tag}.L{li}", f"L{li}"
    ai4 = "attn" in getattr(P, "weight_i4", ())
    fi4 = "ffn" in getattr(P, "weight_i4", ())
    rowpack = FLAG_PACK_I8                     # row-major INT8 bytes (CNM operands)

    def nxt(kind):
        slots, rot = R[kind + "_slots"], R["_rot"]
        rot[kind] = (rot.get(kind, -1) + 1) % len(slots)
        return slots[rot[kind]]

    def layernorm(dst, lnb):
        for r in range(SLOTS):
            P.emit(f"{base}.ln.r{r}", OP_LAYERNORM, R["X"] + r * D * 4, R["LNT"] + r * D * 4,
                   src1=lnb, bias=lnb + D * 4, k_or_length=D, flags=FLAG_BIAS, aux0=1)
        return P.emit(f"{base}.lnpack", OP_REQUANT, R["LNT"], dst, m=4, n=D, k_or_length=4 * D,
                      flags=PACK, shift=LN_RB, aux0=1)

    def pack(name, src, dst, m, n_, shift=0, flags=PACK):
        return P.emit(name, OP_REQUANT, src, dst, m=m, n=n_, k_or_length=m * n_, flags=flags,
                      shift=shift, aux0=1)

    def gemm(name, a, b, dst, bias, m, n_, k, shift, acc=False):
        return P.emit(name, OP_GEMM, a, dst, src1=b, bias=bias,
                      flags=FLAG_BIAS | (FLAG_GEMM_ACC if acc else 0), m=m, n=n_,
                      k_or_length=k // 4, shift=shift, aux0=1)

    def gemv(name, vec, rows_base, dst, rows, nbytes, shift):
        return P.emit(name, OP_CNM_GEMV, vec, dst, src1=rows_base, m=rows,
                      k_or_length=nbytes // 16, shift=shift)

    def copy(name, dst, src, words):
        return P.emit(name, OP_RESIDUAL, src, dst, src1=R["ZERO"], k_or_length=words, shift=0, aux0=1)

    def resid(name, dst, a, b, shift=0):
        return P.emit(name, OP_RESIDUAL, a, dst, src1=b, k_or_length=SLOTS * D, shift=shift, aux0=1)

    def rescale(name, s):
        for j in range(1 if s > 0 else -s):
            resid(f"{name}.rescale{j}", R["ACC"], R["ACC"], R["ACC"], s + 1 if s > 0 else 0)

    # LN1 -> XP (slots as rows) and XE (slot s in group s, byte lane L)
    lnb = nxt("LN")
    P.dma(f"{mem}.ln1", lnb)
    layernorm(R["XP"], lnb)
    copy(f"{base}.w4clr", R["W4"] + ((L + 3) % 4) * D * 4, R["ZERO"], D)
    for s in active:
        copy(f"{base}.w4.s{s}", R["W4"] + L * D * 4, R["LNT"] + s * D * 4, D)
        pack(f"{base}.xe.s{s}", R["W4"], R["XE"] + s * 4 * D, 4, D, shift=LN_RB)
    first = active[0]
    ctx = {}

    def head_matrix(h):
        """Projections and K/V cache update of head h (list of thunks)."""
        b = h % 2
        PROJ, Q8, K8, VTE8, VG = (R[f"{nm}{b}"] for nm in ("PROJ", "Q8", "K8", "VTE8", "VG"))
        ops = []
        st = ctx[h] = {"wq": nxt("W"), "wk": nxt("W"), "wv": nxt("W"), "wo": nxt("W"),
                       "hb": nxt("HB"), "KC": {s: nxt("KC") for s in active},
                       "VC": {s: nxt("VC") for s in active}, "Q8": Q8}
        hb = st["hb"]
        BQ, BK, BVR = hb, hb + HD * 4, hb + 2 * HD * 4
        st["BSR"], st["BAR"] = BVR + kmax * 4, BVR + 2 * kmax * 4
        st["BO"] = st["BAR"] + HD * 4
        qk_flags = rowpack if cnm else PACK
        ops += [lambda: P.dma(f"{mem}.wq{h}", st["wq"], expand_i4=ai4),
                lambda: P.dma(f"{mem}.wk{h}", st["wk"], expand_i4=ai4),
                lambda: P.dma(f"{mem}.hb{h}", hb),
                lambda: gemm(f"{base}.h{h}.q", R["XP"], st["wq"], PROJ, BQ, SLOTS, HD, D, ql.sh_q[h]),
                lambda: pack(f"{base}.h{h}.qpack", PROJ, Q8, SLOTS, HD, flags=qk_flags),
                lambda: gemm(f"{base}.h{h}.k", R["XP"], st["wk"], PROJ, BK, SLOTS, HD, D, ql.sh_k[h]),
                lambda: pack(f"{base}.h{h}.kpack", PROJ, K8, SLOTS, HD, flags=qk_flags),
                lambda: P.dma(f"{mem}.wvt{h}", st["wv"], expand_i4=ai4),
                lambda: P.dma(f"{mem}.wo{h}", st["wo"], expand_i4=ai4),
                lambda: gemm(f"{base}.h{h}.vt", st["wv"], R["XE"], PROJ, BVR, HD, XE_N, D, ql.sh_v[h]),
                lambda: pack(f"{base}.h{h}.vtpack", PROJ, VTE8, HD, XE_N,
                             flags=rowpack if cnm else PACK)]
        for s in active:
            if cnm:   # K row p: 16 contiguous words; V^T word g of each of the 64 rows
                ops += [lambda s=s: P.dma(f"{mem}.kc{h}s{s}", K8 + HD * s, HD // 4,
                                          offset=p * HD, store=True),
                        lambda s=s: P.dma(f"{mem}.vc{h}s{s}", VG + 4 * s, 1, offset=g * 4,
                                          rows=HD, ext_stride=kmax, spad_stride=16)]
            else:     # packed-A: 16 single-word rows; 16 rows of 4 words
                ops += [lambda s=s: P.dma(f"{mem}.kc{h}s{s}", K8 + 4 * s, 1,
                                          offset=(g * HD + L) * 4, rows=HD // 4,
                                          ext_stride=16, spad_stride=16, store=True),
                        lambda s=s: P.dma(f"{mem}.vc{h}s{s}", VG + 16 * s, 4, offset=g * 16,
                                          rows=HD // 4, ext_stride=kmax * 4,
                                          spad_stride=XE_N * 4)]
        ops.append(lambda: P.emit(f"{base}.h{h}.vmerge", OP_RESIDUAL, VG, VG, src1=VTE8,
                                  k_or_length=HD * XE_N // 4, shift=0, aux0=1))
        for s in active:
            if cnm:
                ops.append(lambda s=s: P.dma(f"{mem}.vc{h}s{s}", VG + 4 * s, 1, offset=g * 4,
                                             rows=HD, ext_stride=kmax, spad_stride=16, store=True))
            else:
                ops.append(lambda s=s: P.dma(f"{mem}.vc{h}s{s}", VG + 16 * s, 4, offset=g * 16,
                                             rows=HD // 4, ext_stride=kmax * 4,
                                             spad_stride=XE_N * 4, store=True))
            ops += [lambda s=s: P.dma(f"{mem}.kc{h}s{s}", st["KC"][s], n4 * HD // 4),
                    lambda s=s: P.dma(f"{mem}.vc{h}s{s}", st["VC"][s])]
        return ops

    def head_attention(h):
        """Per-slot attention of head h and its output projection (thunks)."""
        st, ops = ctx[h], []
        for s in active:
            KC, VC, SC, PR, P8 = st["KC"][s], st["VC"][s], R[f"SC{s}"], R[f"PR{s}"], R[f"P8{s}"]
            if cnm:
                ops += [lambda s=s, KC=KC, SC=SC: gemv(f"{base}.h{h}.s.s{s}", st["Q8"] + HD * s,
                                                       KC, SC, n4, HD, ql.sh_s[h]),
                        lambda s=s, SC=SC, PR=PR: P.emit(f"{base}.h{h}.sm.s{s}", OP_CAUSAL_SOFTMAX,
                                                         SC, PR, k_or_length=n4, aux0=p),
                        lambda s=s, PR=PR, P8=P8: pack(f"{base}.h{h}.p8.s{s}", PR, P8, 1, kmax,
                                                       shift=8, flags=rowpack | FLAG7),
                        lambda s=s, VC=VC, P8=P8: gemv(f"{base}.h{h}.av.s{s}", P8, VC,
                                                       R["AVO"] + s * HD * 4, HD, kmax, ql.sh_a[h])]
            else:
                ops += [lambda s=s, KC=KC, SC=SC: gemm(f"{base}.h{h}.s.s{s}", st["Q8"], KC, SC,
                                                       st["BSR"], SLOTS, n4, HD, ql.sh_s[h]),
                        lambda s=s, SC=SC, PR=PR: P.emit(f"{base}.h{h}.sm.s{s}", OP_CAUSAL_SOFTMAX,
                                                         SC + s * n4 * 4, PR + s * kmax * 4,
                                                         k_or_length=n4, aux0=p),
                        lambda s=s, PR=PR, P8=P8: pack(f"{base}.h{h}.p8.s{s}", PR, P8, SLOTS, kmax,
                                                       shift=8, flags=PACK | FLAG7),
                        lambda s=s, VC=VC, P8=P8: gemm(f"{base}.h{h}.av.s{s}", P8, VC, R["AVO"],
                                                       st["BAR"], SLOTS, HD, kmax, ql.sh_a[h],
                                                       acc=s != first)]
        ops += [lambda: pack(f"{base}.h{h}.avpack", R["AVO"], R["AV8"], SLOTS, HD),
                lambda: gemm(f"{base}.h{h}.wo", R["AV8"], st["wo"], R["ACC"], st["BO"], SLOTS, D,
                             HD, ql.sh_o[h], acc=h > 0)]
        return ops

    # The pipeline keeps two heads' caches live, so it needs two cache slots per
    # active sequence; a head always needs one (asserted at allocation time).
    assert len(R["KC_slots"]) >= len(active) and len(R["VC_slots"]) >= len(active)
    pipeline = cnm and len(R["KC_slots"]) >= 2 * len(active)
    if pipeline:  # software pipeline: Matrix work of head h+1 interleaved with attention of h
        for f in head_matrix(0):
            f()
        for h in range(H):
            a_ops = head_matrix(h + 1) if h + 1 < H else []
            for pair in itertools.zip_longest(a_ops, head_attention(h)):
                for f in pair:
                    if f is not None:
                        f()
    else:
        for h in range(H):
            for f in head_matrix(h) + head_attention(h):
                f()
    rescale(f"{base}.attn", ql.s_o)
    resid(f"{base}.res1", R["X"], R["X"], R["ACC"])
    lnb = nxt("LN")
    P.dma(f"{mem}.ln2", lnb)
    layernorm(R["XP"], lnb)
    for c in range(ql.NC):
        w1, w2, cb = nxt("W"), nxt("W"), nxt("CB")
        P.dma(f"{mem}.w1c{c}", w1, expand_i4=fi4); P.dma(f"{mem}.w2c{c}", w2, expand_i4=fi4)
        P.dma(f"{mem}.cb{c}", cb)
        gemm(f"{base}.c{c}.fc1", R["XP"], w1, R["H1"], cb, SLOTS, CH, D, 0)
        P.emit(f"{base}.c{c}.gelu", OP_GELU, R["H1"], R["H8"], src1=cb + CH * 4, m=SLOTS, n=CH,
               k_or_length=SLOTS * CH, flags=PACK | FLAG7, shift=ql.sh_l[c], aux0=1)
        gemm(f"{base}.c{c}.fc2", R["H8"], w2, R["ACC"], cb + (CH + 64) * 4, SLOTS, D, CH,
             ql.sh_2[c], acc=c > 0)
    rescale(f"{base}.ffn", ql.s_2)
    idx = resid(f"{base}.res2", R["X"], R["X"], R["ACC"])
    P.checkpoint(idx, R["X"], I.words_i32(out))
    return out


# ------------------------------------------------------------------ main
def quantize(a) -> tuple:
    """FP32 model, SmoothQuant calibration and integer layers (cached on disk)."""
    i4_kinds = {"none": frozenset(), "ffn": frozenset({"ffn"}),
                "all": frozenset({"ffn", "attn"})}[a.int4_weights]
    key = f"i4={a.int4_weights}.gptq={int(not a.no_gptq)}.cw={a.calib_windows}"
    if a.quant_cache and (a.quant_cache / f"{key}.pkl").exists():
        return pickle.loads((a.quant_cache / f"{key}.pkl").read_bytes()), i4_kinds
    tokens = G.load_tokens(a.model_dir, a.wikitext)
    fm = G.FloatGpt2(a.model_dir)
    calib = G.windows(tokens, 256, a.calib_windows,
                      start=len(tokens) - (a.calib_windows + 1) * 257)
    gptq = a.int4_weights != "none" and not a.no_gptq
    obs = [dict() for _ in range(fm.L)]
    for w in calib:
        fm.forward(w[:-1], obs)
    fm.smooth(obs, 0.5)
    obs = [dict(_hess=gptq) for _ in range(fm.L)]
    for w in calib:
        fm.forward(w[:-1], obs)
    qls = [G.QuantLayer(fm, i, obs[i], int4=i4_kinds) for i in range(fm.L)]
    if a.quant_cache:
        a.quant_cache.mkdir(parents=True, exist_ok=True)
        (a.quant_cache / f"{key}.pkl").write_bytes(pickle.dumps(qls))
    return qls, i4_kinds


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--model-dir", type=Path, required=True)
    ap.add_argument("--wikitext", type=Path, required=True)
    ap.add_argument("--layers", type=int, default=12)
    ap.add_argument("--batch", type=int, choices=(1, 2, 3, 4), default=4)
    ap.add_argument("--attn-engine", choices=("matrix", "cnm"), default="matrix")
    ap.add_argument("--prompt-len", type=int, default=30)
    ap.add_argument("--decode-steps", type=int, default=4)
    ap.add_argument("--kmax", type=int, default=64)
    ap.add_argument("--int4-weights", choices=("none", "ffn", "all"), default="all")
    ap.add_argument("--no-gptq", action="store_true")
    ap.add_argument("--calib-windows", type=int, default=8)
    ap.add_argument("--quant-cache", type=Path, help="pickle cache of the integer layers")
    ap.add_argument("--hoist", type=int, default=48)
    ap.add_argument("--out", type=Path, required=True)
    a = ap.parse_args()
    Lp, S, kmax = a.prompt_len, a.decode_steps, a.kmax
    assert Lp + S <= kmax and kmax % 16 == 0 and Lp >= 1

    t0 = time.time()
    qls, i4_kinds = quantize(a)
    fm = G.FloatGpt2(a.model_dir)                      # embedding / head are not smoothed
    tokens = G.load_tokens(a.model_dir, a.wikitext)
    active = list(range(a.batch))
    prompts = [tokens[4096 * (s + 1): 4096 * (s + 1) + Lp].astype(np.int64) for s in range(SLOTS)]
    print(f"GPT2_BATCH_QUANT_READY s={time.time() - t0:.0f}", flush=True)

    # Host prefill of every slot (bit-exact Golden), caches zeroed from Lp on.
    T = (Lp + 3) // 4 * 4
    caches = [[q.new_cache(kmax) for q in qls] for _ in range(SLOTS)]   # [slot][layer][head]
    seqs = []
    for s in range(SLOTS):
        x = np.zeros((T, fm.D), np.int64)
        x[:Lp] = G.quant_embed(fm, torch.from_numpy(prompts[s]))
        for li, q in enumerate(qls):
            x = q.forward(x, 0, caches[s][li])
            for c in caches[s][li]:
                c["k"][Lp:] = 0
                c["v"][Lp:] = 0
        seqs.append(list(prompts[s]) + [int(G.head_logits(fm, x)[Lp - 1].argmax())])

    P = Program(overlap=True, hoist=a.hoist)
    P.weight_i4 = i4_kinds
    R = allocate_batch(P, fm.D, fm.HD, kmax)
    for li in range(a.layers):
        G.put_layer(P, qls[li], li, kmax)
        put_caches(P, li, [caches[s][li] for s in range(SLOTS)], active, a.attn_engine)
    # Buffers read before (or without) being fully written must start at zero.
    P.ddr_put("zeros", np.zeros(4 * fm.D, np.int64))
    zero_list = [(f"PR{s}", SLOTS * kmax) for s in range(SLOTS)] + [
        ("W4", 4 * fm.D), ("ZERO", fm.D), ("XE", XE_N * fm.D // 4), ("AVO", SLOTS * fm.HD),
        ("VG0", fm.HD * XE_N // 4), ("VG1", fm.HD * XE_N // 4)]
    for nm, words in zero_list:
        P.dma("zeros", R[nm], words)

    x_npu = None
    for st in range(S):
        p = Lp + st
        xb = np.zeros((SLOTS, fm.D), np.int64)
        for s in active:
            xb[s] = G.quant_embed(fm, torch.tensor([seqs[s][p]]), p)[0]
        P.ddr_put(f"x.S{st}", I.words_i32(xb)); P.dma(f"x.S{st}", R["X"])
        x = xb
        for li in range(fm.L):
            lc = [caches[s][li] for s in range(SLOTS)]
            if li < a.layers:
                x = emit_layer_batch(P, qls[li], li, R, x, p, lc, kmax, f"S{st}", active,
                                     a.attn_engine)
                x_npu = x
            else:
                x = forward_batch(qls[li], x, p, lc, active, a.attn_engine)
        logits = G.head_logits(fm, x)
        for s in active:
            seqs[s].append(int(logits[s].argmax()))
    P.final_rows(R["X"], I.words_i32(x_npu), fm.D, SLOTS)

    from transformers import GPT2TokenizerFast
    tok = GPT2TokenizerFast.from_pretrained(str(a.model_dir))
    result = {"model": fm.name, "batch": a.batch, "slots": SLOTS, "attn_engine": a.attn_engine,
              "prompt_len": Lp, "decode_steps": S, "kmax": kmax, "layers_on_npu": a.layers,
              "int4_weights": a.int4_weights, "gptq": not a.no_gptq,
              "decode_tokens": S * a.batch, "weight_slots": len(R["W_slots"]),
              "generated": [tok.decode(seqs[s][Lp:]) for s in active]}
    man = P.write(a.out, result)
    print("GPT2_BATCH_PROGRAM_READY " + json.dumps({k: man.get(k) for k in (
        "descriptors", "segments", "dma_loads", "dma_stores", "dma_bytes", "spad_high_water",
        "checkpoint_words", "weight_slots", "queued_dma", "event_bits_peak")}), flush=True)
    for s in active:
        print(f"GPT2_BATCH_SEQ slot={s} generated={result['generated'][s]!r}")


if __name__ == "__main__":
    main()
