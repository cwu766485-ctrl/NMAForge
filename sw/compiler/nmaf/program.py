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


@dataclass
class Segment:
    dma: list = field(default_factory=list)       # (ext, spad, ctl, rows, ext_stride, spad_stride)
    desc: list = field(default_factory=list)      # Descriptor
    names: list = field(default_factory=list)


class Program:
    def __init__(self, spad_bytes: int = SPAD_TOP, queue_size: int = 256):
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
        self.regions[name] = Region(name, a, size)
        self.next_addr = a + size
        return a

    def ddr_put(self, name: str, words: np.ndarray) -> int:
        words = np.asarray(words, dtype=np.int64) & 0xFFFFFFFF
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
            rows: int = 0, ext_stride: int = 0, spad_stride: int = 0, store: bool = False):
        """Fenced DMA before the next descriptors.  `offset` is a byte offset into
        the DDR blob; rows > 0 makes `words` the per-row length of a 2D transfer."""
        ext, n = self.ddr_index[ddr_name]
        n = n - offset // 4 if words is None else words
        if not 0 < n < 65536 or offset % 4:
            raise ValueError(f"DMA {ddr_name}: illegal length {n} / offset {offset}")
        if self.segments[-1].desc:
            self.segments.append(Segment())
        self.segments[-1].dma.append((ext + offset, spad_addr, (int(store) << 31) | n, rows,
                                      ext_stride, spad_stride))
        self.stats["dma_events"] += 1
        self.stats["dma_stores" if store else "dma_loads"] = \
            self.stats.get("dma_stores" if store else "dma_loads", 0) + 1
        self.stats["dma_bytes"] += 4 * n * max(rows, 1)

    def emit(self, name: str, op: int, src0: int, dst: int, **kw) -> int:
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
    def write(self, out: Path, meta: dict) -> dict:
        out.mkdir(parents=True, exist_ok=True)
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
        (out / "program.memh").write_text("\n".join(f"{w & 0xFFFFFFFF:08x}" for w in words) + "\n")
        ddr = np.concatenate(self.ddr) if self.ddr else np.zeros(4, np.int64)
        (out / "ddr.memh").write_text("\n".join(f"{int(w):08x}" for w in ddr) + "\n")
        man = {
            **meta, **self.stats,
            "segments": len(self.segments), "queue_size": self.queue,
            "desc_base": self.desc_base, "cpl_base": self.cpl_base,
            "spad_high_water": self.next_addr, "spad_bytes": self.spad_bytes,
            "ddr_bytes": int(len(ddr) * 4), "program_words": len(words),
            "checkpoint_words": len(self.ckpt), "final_words": len(self.final),
            "regions": {r.name: [r.addr, r.size] for r in self.regions.values()},
            "program_sha256": hashlib.sha256((out / "program.memh").read_bytes()).hexdigest(),
            "ddr_sha256": hashlib.sha256((out / "ddr.memh").read_bytes()).hexdigest(),
        }
        (out / "manifest.json").write_text(json.dumps(man, indent=2) + "\n")
        return man
