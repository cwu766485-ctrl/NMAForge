"""NMAForge compiled-program builder.

A program is a sequence of segments.  Each segment first runs fenced AXI DMA
transfers (DDR -> SPAD loads or SPAD -> DDR stores, 1D or 2D), then publishes
up to `queue_size - 1` ABI-v7 descriptors as one resident ring batch.  Every descriptor is chained to its predecessor
with completion event bit 0, so ordering is enforced by the hardware
dispatcher.  Checkpoints name a global descriptor index and the SPAD words
that must hold at its retirement (observed passively by the testbench).

File format (`program.memh`, one hex word per line):
  magic 0x4E4D4146, version 2, queue_size, desc_base, cpl_base, n_segments,
  per segment: n_dma, n_desc, n_ckpt,
               (ext, spad, store<<31 | row_words, row_count, ext_stride, spad_stride)*n_dma,
               16 words * n_desc, (desc_index_in_segment, addr, value)*n_ckpt,
  n_final, (addr, value)*n_final.
row_count == 0 is a 1D transfer of `row_words` words.  Version 1 (3-word
load-only DMA entries) is still accepted by the testbench.

Version 3 (`Program(overlap=True)`) moves every DMA into the CMDQ as an
opcode-0x60 DMA_COPY descriptor and replaces the serial event chain with
dependencies derived from SPAD/DDR footprints (RAW, WAR, WAW; implied orders
through same-engine issue are dropped).  DMA loads are hoisted ahead of
independent compute so they overlap it, and the program sets CMD_CTRL[1]
(event-on-complete) with the CMDQ ring in DDR (CMD_CTRL[0]; `desc_base` is
then the DDR byte address of the ring, placed after the image).  Header:
magic, 3, queue_size, desc_base, cpl_base, cmd_ctrl, n_segments; segment entries are as in version 2, but the testbench
streams any number of descriptors through the ring, and checkpoint records
are only placed on the last descriptor of a segment (read after it drains).
`ddr.memh` holds the external memory image (word 0 = byte address 0).
"""

from __future__ import annotations

import hashlib
import json
import sys
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from cimforge_mapper import Descriptor  # noqa: E402

MAGIC = 0x4E4D4146
SPAD_TOP = 512 * 1024


@dataclass
class Region:
    name: str
    addr: int
    size: int


# Engine index per opcode, as in ai_parallel_compute_dispatcher.engine_for_op.
def engine_for_op(op: int) -> int:
    if op in (0x50, 0x51):
        return 1
    if op in (0x20, 0x21):
        return 2
    if op in (0x30, 0x31, 0x52, 0x53):
        return 3
    if 0x32 <= op <= 0x3B:
        return 4
    if op in (0x16, 0x17):
        return 5
    if op in (0x43, 0x44):
        return 6
    if op == OP_DMA_COPY:
        return 7
    return 0


OP_DMA_COPY = 0x60
FLAG_DMA_EXPAND_I4 = 0x02     # 0x60 flags[1]: INT4 block-exponent expansion on load
FLAG_GEMM_ACC = 0x80          # 0x30/0x31 flags[7]: C = sat32(C + A*B epilogue)
DDR_SPACE = 1 << 40           # DDR byte ranges are offset so they never meet SPAD ones


def footprint(d) -> tuple[list, list]:
    """Conservative SPAD byte ranges (lo, hi) read and written by a descriptor
    of the opcodes the model compilers emit."""
    w4 = lambda a, n: (a, a + 4 * n)
    ln = d.k_or_length
    rd, wr = [], []
    if d.op == 0x30:                                   # GEMM, packed A/B, INT32 out
        kb = 4 * d.k_or_length
        for b in range(max(d.batch_count, 1)):
            rd += [(d.src0 + b * d.src0_stride, d.src0 + b * d.src0_stride + d.m * kb),
                   (d.src1 + b * d.src1_stride, d.src1 + b * d.src1_stride + kb * d.n)]
            wr += [w4(d.dst + b * d.dst_stride, d.m * d.n)]
        if d.flags & 1:
            rd.append(w4(d.bias, d.n))
        if d.flags & FLAG_GEMM_ACC:                    # accumulate epilogue reads C
            rd += list(wr)
    elif d.op == 0x21:                                 # CNM banked GEMV, row-major B
        vec = 16 * d.k_or_length                       # bytes per A vector / B row
        rd += [(d.src0, d.src0 + vec), (d.src1, d.src1 + d.m * vec)]
        wr.append(w4(d.dst, d.m))
    elif d.op in (0x35, 0x36):                         # GELU(LUT) / REQUANT
        rd.append(w4(d.src0, ln))
        wr.append((d.dst, d.dst + ln) if d.flags & (1 << 4) else w4(d.dst, ln))
        if d.op == 0x35 and d.flags & 0x80:
            rd.append((d.src1, d.src1 + 256))
    elif d.op == 0x34:                                 # RESIDUAL
        rd += [w4(d.src0, ln), w4(d.src1, ln)]
        wr.append(w4(d.dst, ln))
    elif d.op == 0x38:                                 # LAYERNORM (one row)
        rd += [w4(d.src0, ln), w4(d.src1, ln)]
        if d.flags & 1:
            rd.append(w4(d.bias, ln))
        wr.append(w4(d.dst, ln))
    elif d.op in (0x32, 0x39):                         # SOFTMAX / CAUSAL_SOFTMAX
        rd.append(w4(d.src0, ln))
        wr.append(w4(d.dst, ln))
    elif d.op == OP_DMA_COPY:
        rows = max(d.m, 1)
        sp_hi = d.dst + (rows - 1) * d.dst_stride + 4 * ln
        if d.flags & FLAG_DMA_EXPAND_I4:               # INT4 super-blocks -> 480 B each
            sp_hi = d.dst + (ln // 64) * 480
        ext = d.src0 | (d.src1 << 32)
        ex_hi = ext + (rows - 1) * d.src0_stride + 4 * ln
        spad, ddr = (d.dst, sp_hi), (DDR_SPACE + ext, DDR_SPACE + ex_hi)
        if d.flags & 1:                                # store: SPAD -> DDR
            rd.append(spad); wr.append(ddr)
        else:
            rd.append(ddr); wr.append(spad)
    else:
        raise ValueError(f"{d.name}: no footprint model for opcode 0x{d.op:02x}")
    return rd, wr


def _overlap(a: list, b: list) -> bool:
    return any(lo < bhi and blo < hi for lo, hi in a for blo, bhi in b)


class _AccessTable:
    """Disjoint address intervals, each with its last writer and the readers
    since that write (schedule positions; -1 = initial contents)."""

    def __init__(self):
        import bisect
        self._bisect = bisect
        self.starts = [-(1 << 62)]
        self.vals = [(-1, ())]

    def _split(self, x: int) -> int:
        i = self._bisect.bisect_right(self.starts, x) - 1
        if self.starts[i] != x:
            self.starts.insert(i + 1, x)
            self.vals.insert(i + 1, self.vals[i])
            i += 1
        return i

    def query(self, lo: int, hi: int):
        i = self._bisect.bisect_right(self.starts, lo) - 1
        while i < len(self.starts) and self.starts[i] < hi:
            yield self.vals[i]
            i += 1

    def add_reader(self, lo: int, hi: int, j: int):
        a, b = self._split(lo), self._split(hi)
        for i in range(a, b):
            w, rs = self.vals[i]
            self.vals[i] = (w, rs + (j,))

    def set_writer(self, lo: int, hi: int, j: int):
        a, b = self._split(lo), self._split(hi)
        self.starts[a:b] = [lo]
        self.vals[a:b] = [(j, ())]


@dataclass
class Op:
    ident: int
    desc: object
    reads: list
    writes: list
    engine: int


@dataclass
class Segment:
    dma: list = field(default_factory=list)       # (ext, spad, ctl, rows, ext_stride, spad_stride)
    desc: list = field(default_factory=list)      # Descriptor
    names: list = field(default_factory=list)


class Program:
    def __init__(self, spad_bytes: int = SPAD_TOP, queue_size: int = 256, overlap: bool = False,
                 hoist: int = 48):
        self.overlap = overlap
        self.hoist = hoist
        self.ops: list[Op] = []
        self.spad_bytes = spad_bytes
        self.queue = queue_size
        self.desc_base = spad_bytes - queue_size * 80
        self.cpl_base = self.desc_base + queue_size * 64
        self.next_addr = 0
        self.regions: dict[str, Region] = {}
        self.ddr: list[np.ndarray] = []
        self.ddr_words = 0
        self.ddr_index: dict[str, tuple[int, int]] = {}
        self.segments: list[Segment] = [Segment()]
        self.task = 0
        self.ckpt: list[tuple[int, int, int]] = []    # (global desc index, addr, value)
        self.final: dict[int, int] = {}
        self.stats = {"descriptors": 0, "dma_events": 0, "dma_bytes": 0}

    # ---------------------------------------------------------- memory
    def alloc(self, name: str, size: int, align: int = 64) -> int:
        a = (self.next_addr + align - 1) // align * align
        if a + size > self.desc_base:
            raise ValueError(f"SPAD overflow allocating {name}: {a + size} > {self.desc_base}")
        name = getattr(self, "region_prefix", "") + name
        self.regions[name] = Region(name, a, size)
        self.next_addr = a + size
        return a

    def alloc_reset(self, prefix: str):
        """Start a new SPAD map for a later program phase (its regions may
        alias the previous phase; footprint dependencies order the reuse)."""
        self.high_water = max(getattr(self, "high_water", 0), self.next_addr)
        self.next_addr = 0
        self.region_prefix = prefix

    def ddr_put(self, name: str, words: np.ndarray, align: int = 16) -> int:
        words = np.asarray(words, dtype=np.int64).reshape(-1) & 0xFFFFFFFF
        lead = (-self.ddr_words) % (align // 4)       # e.g. 256 B for INT4 streams
        if lead:
            self.ddr.append(np.zeros(lead, np.int64))
            self.ddr_words += lead
        pad = (-len(words)) % 4                       # keep 16-byte alignment
        if pad:
            words = np.concatenate([words, np.zeros(pad, np.int64)])
        addr = self.ddr_words * 4
        self.ddr.append(words)
        self.ddr_words += len(words)
        self.ddr_index[name] = (addr, len(words))
        return addr

    # ---------------------------------------------------------- program
    def dma(self, ddr_name: str, spad_addr: int, words: int | None = None, *, offset: int = 0,
            rows: int = 0, ext_stride: int = 0, spad_stride: int = 0, store: bool = False,
            expand_i4: bool = False):
        """Fenced DMA before the next descriptors.  `offset` is a byte offset into
        the DDR blob; rows > 0 makes `words` the per-row length of a 2D transfer."""
        ext, n = self.ddr_index[ddr_name]
        n = n - offset // 4 if words is None else words
        if not 0 < n < 65536 or offset % 4:
            raise ValueError(f"DMA {ddr_name}: illegal length {n} / offset {offset}")
        if expand_i4 and (not self.overlap or store or rows or n % 64 or (ext + offset) % 256
                          or spad_addr % 16):
            raise ValueError(f"DMA {ddr_name}: illegal INT4 expansion transfer")
        if self.overlap:
            d = Descriptor(name=f"dma.{ddr_name}", task_id=self.task & 0xFFFF, op=OP_DMA_COPY,
                           src0=(ext + offset) & 0xFFFFFFFF, src1=(ext + offset) >> 32,
                           dst=spad_addr, m=rows, k_or_length=n,
                           flags=int(store) | (FLAG_DMA_EXPAND_I4 if expand_i4 else 0),
                           src0_stride=ext_stride if rows else 0,
                           dst_stride=spad_stride if rows else 0,
                           batch_count=0, head_count=0)
            idx = self._add_op(d)
            self.stats["dma_events"] += 1
            key = "dma_stores" if store else "dma_loads"
            self.stats[key] = self.stats.get(key, 0) + 1
            self.stats["dma_bytes"] += 4 * n * max(rows, 1)
            if expand_i4:
                self.stats["dma_i4"] = self.stats.get("dma_i4", 0) + 1
            return idx
        if self.segments[-1].desc:
            self.segments.append(Segment())
        self.segments[-1].dma.append((ext + offset, spad_addr, (int(store) << 31) | n, rows,
                                      ext_stride, spad_stride))
        self.stats["dma_events"] += 1
        self.stats["dma_stores" if store else "dma_loads"] = \
            self.stats.get("dma_stores" if store else "dma_loads", 0) + 1
        self.stats["dma_bytes"] += 4 * n * max(rows, 1)

    def _add_op(self, d) -> int:
        rd, wr = footprint(d)
        idx = self.task
        self.ops.append(Op(idx, d, rd, wr, engine_for_op(d.op)))
        self.task += 1
        self.stats["descriptors"] += 1
        return idx

    def emit(self, name: str, op: int, src0: int, dst: int, **kw) -> int:
        if self.overlap:
            kw.setdefault("src1", 0)
            return self._add_op(Descriptor(name=name, task_id=self.task & 0xFFFF, op=op,
                                           src0=src0, dst=dst, **kw))
        seg = self.segments[-1]
        if len(seg.desc) >= self.queue - 1:
            seg = Segment()
            self.segments.append(seg)
        kw.setdefault("src1", 0)
        d = Descriptor(name=name, task_id=self.task & 0xFFFF, op=op, src0=src0, dst=dst, **kw)
        idx = self.task
        if idx > 0:
            d.wait_mask |= 1
            d.clear_mask |= 1
        d.signal_mask |= 1                            # cleared on the last one at write()
        seg.desc.append(d)
        seg.names.append(name)
        self.task += 1
        self.stats["descriptors"] += 1
        return idx

    def checkpoint(self, desc_index: int, addr: int, words: np.ndarray):
        for i, v in enumerate(np.asarray(words, dtype=np.int64) & 0xFFFFFFFF):
            self.ckpt.append((desc_index, addr + 4 * i, int(v)))

    def checkpoint_rows(self, desc_index: int, addr: int, values: np.ndarray, row_words: int,
                        rows: int):
        """Check the first `rows` rows of a row-major INT32 matrix region."""
        w = np.asarray(values, dtype=np.int64).reshape(-1, row_words)[:rows]
        self.checkpoint(desc_index, addr, w.reshape(-1))

    def checkpoint_packed_a_rows(self, desc_index: int, addr: int, packed: np.ndarray,
                                 k: int, rows: int):
        """Check only Matrix-A words whose row index < rows (padding is scratch)."""
        packed = np.asarray(packed, dtype=np.int64) & 0xFFFFFFFF
        for w, v in enumerate(packed):
            r = (w // k) * 4 + (w % 4)
            if r < rows:
                self.ckpt.append((desc_index, addr + 4 * w, int(v)))

    def final_rows(self, addr: int, values: np.ndarray, row_words: int, rows: int):
        w = np.asarray(values, dtype=np.int64).reshape(-1, row_words)[:rows].reshape(-1)
        for i, v in enumerate(w & 0xFFFFFFFF):
            self.final[addr + 4 * i] = int(v)

    # ---------------------------------------------------------- output
    # ---------------------------------------------------------- overlap schedule
    def _schedule(self) -> tuple[list, set]:
        """Hoist DMA loads ahead of independent descriptors (compute or other
        DMA with disjoint SPAD and DDR footprints, never past a checkpointed
        descriptor), within `self.hoist` descriptors."""
        barrier = {g for g, _, _ in self.ckpt}
        ops = list(self.ops)
        for j in range(len(ops)):
            op = ops[j]
            if op.engine != 7 or op.desc.flags & 1:
                continue
            k = j
            while k > 0 and j - k < self.hoist:
                p = ops[k - 1]
                if (p.ident in barrier or
                        _overlap(op.writes, p.reads + p.writes) or _overlap(op.reads, p.writes)):
                    break
                k -= 1
            if k != j:
                ops.insert(k, ops.pop(j))
        return ops, barrier

    def _dependencies(self, ops: list) -> list[list[int]]:
        """Per op (schedule position), the earlier positions it must wait for,
        with orders implied by same-engine issue or other waits removed."""
        table = _AccessTable()
        nE = 8
        known = []                     # per position: latest position known complete per engine
        last_on_engine = [-1] * nE
        waits_all = []
        for j, op in enumerate(ops):
            need = set()
            for lo, hi in op.reads:
                for w, _ in table.query(lo, hi):
                    need.add(w)
            for lo, hi in op.writes:
                for w, rs in table.query(lo, hi):
                    need.add(w)
                    need.update(rs)
            need.discard(-1)
            for lo, hi in op.reads:
                table.add_reader(lo, hi, j)
            for lo, hi in op.writes:
                table.set_writer(lo, hi, j)
            k = [-1] * nE
            prev = last_on_engine[op.engine]
            if prev >= 0:
                k = list(known[prev])
                k[op.engine] = max(k[op.engine], prev)
            waits = []
            for i in sorted(need, reverse=True):
                e = ops[i].engine
                if k[e] >= i:
                    continue
                waits.append(i)
                k = [max(a, b) for a, b in zip(k, known[i])]
                k[e] = max(k[e], i)
            known.append(k)
            last_on_engine[op.engine] = j
            waits_all.append(sorted(waits))
        return waits_all

    @staticmethod
    def _assign_events(ops: list, waits_all: list) -> int:
        """Interval-colour producer->last-consumer spans onto the 16 event bits."""
        last_use = {}
        for j, ws in enumerate(waits_all):
            for i in ws:
                last_use[i] = max(last_use.get(i, -1), j)
        bit_free_after = [-1] * 16     # position of the clearing consumer of the bit's last user
        bit_of = {}
        peak, live = 0, []
        for j, op in enumerate(ops):
            d = op.desc
            d.wait_mask = d.signal_mask = d.clear_mask = 0
        for i in sorted(last_use):
            for b in range(16):
                if bit_free_after[b] < i:
                    break
            else:
                raise RuntimeError(f"event bits exhausted at descriptor position {i}")
            bit_of[i] = b
            bit_free_after[b] = last_use[i]
            live = [x for x in live if last_use[x] >= i] + [i]
            peak = max(peak, len(live))
        for j, ws in enumerate(waits_all):
            d = ops[j].desc
            for i in ws:
                b = bit_of[i]
                d.wait_mask |= 1 << b
                if last_use[i] == j:
                    d.clear_mask |= 1 << b
        for i, b in bit_of.items():
            ops[i].desc.signal_mask |= 1 << b
        return peak

    def _write_overlap(self, out: Path, meta: dict) -> dict:
        ops, barrier = self._schedule()
        waits_all = self._dependencies(ops)
        peak = self._assign_events(ops, waits_all)
        pos_of = {op.ident: j for j, op in enumerate(ops)}
        segs, cur = [], []
        for op in ops:
            cur.append(op)
            if op.ident in barrier:
                segs.append(cur)
                cur = []
        if cur:
            segs.append(cur)
        # The CMDQ ring lives in DDR right after the image (CMD_CTRL[0]=1):
        # the host appends descriptors without touching the SPAD host port,
        # which returns SLVERR on a same-cycle conflict with engine traffic.
        ring = (self.ddr_words * 4 + 4095) // 4096 * 4096
        self.stats["cmdq_ddr_base"] = ring
        words = [MAGIC, 3, self.queue, ring, self.cpl_base, 0x3, len(segs)]
        by_ident = {}
        for g, a, v in self.ckpt:
            by_ident.setdefault(g, []).append((a, v))
        for seg in segs:
            ck = by_ident.get(seg[-1].ident, [])
            words += [0, len(seg), len(ck)]
            for op in seg:
                words += op.desc.words()
            for a, v in ck:
                words += [len(seg) - 1, a, v]
        words += [len(self.final)]
        for a, v in sorted(self.final.items()):
            words += [a, v]
        hoisted, seen_max = 0, -1
        for op in ops:
            if op.engine == 7 and op.ident < seen_max:
                hoisted += 1
            seen_max = max(seen_max, op.ident)
        self.stats.update({"queued_dma": sum(op.engine == 7 for op in ops),
                           "hoisted_dma": hoisted, "event_bits_peak": peak,
                           "dependency_waits": sum(len(w) for w in waits_all)})
        self.segments = [Segment(desc=[op.desc for op in seg]) for seg in segs]
        return self._finish(out, meta, words)

    def write(self, out: Path, meta: dict) -> dict:
        out.mkdir(parents=True, exist_ok=True)
        if self.overlap:
            return self._write_overlap(out, meta)
        last = [seg for seg in self.segments if seg.desc][-1].desc[-1]
        last.signal_mask &= ~1
        words = [MAGIC, 2, self.queue, self.desc_base, self.cpl_base, len(self.segments)]
        base = 0
        for seg in self.segments:
            ck = [(g - base, a, v) for g, a, v in sorted(self.ckpt, key=lambda t: t[0])
                  if base <= g < base + len(seg.desc)]
            words += [len(seg.dma), len(seg.desc), len(ck)]
            for e in seg.dma:
                words += list(e)
            for d in seg.desc:
                words += d.words()
            for c in ck:
                words += list(c)
            base += len(seg.desc)
        words += [len(self.final)]
        for a, v in sorted(self.final.items()):
            words += [a, v]
        return self._finish(out, meta, words)

    def _finish(self, out: Path, meta: dict, words: list) -> dict:
        (out / "program.memh").write_text("\n".join(f"{w & 0xFFFFFFFF:08x}" for w in words) + "\n")
        ddr = np.concatenate(self.ddr) if self.ddr else np.zeros(4, np.int64)
        (out / "ddr.memh").write_text("\n".join(f"{int(w):08x}" for w in ddr) + "\n")
        man = {
            **meta, **self.stats,
            "segments": len(self.segments), "queue_size": self.queue,
            "desc_base": self.desc_base, "cpl_base": self.cpl_base,
            "spad_high_water": max(getattr(self, "high_water", 0), self.next_addr),
            "spad_bytes": self.spad_bytes,
            "ddr_bytes": int(len(ddr) * 4), "program_words": len(words),
            "checkpoint_words": len(self.ckpt), "final_words": len(self.final),
            "regions": {r.name: [r.addr, r.size] for r in self.regions.values()},
            "program_sha256": hashlib.sha256((out / "program.memh").read_bytes()).hexdigest(),
            "ddr_sha256": hashlib.sha256((out / "ddr.memh").read_bytes()).hexdigest(),
        }
        (out / "manifest.json").write_text(json.dumps(man, indent=2) + "\n")
        return man
