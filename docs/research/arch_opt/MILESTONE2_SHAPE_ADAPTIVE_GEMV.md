# Milestone 2 — Shape-Adaptive GEMV Integration Review

## Decision

**REWORK / NO DUPLICATE PRODUCT ENGINE.** Product opcode `0x52` already accepts
M=1,4,8,16 and runs through the real Matrix controller, four-bank SPAD arbiter,
completion path and Golden checker. The research wrapper is useful for a bounded
mapping comparison, but its cycle numbers cannot be promoted to Product Top
performance because it has a different command path and local buffering.

## Product Top evidence

Source run: `/tmp/nmaforge-archopt-m1-runs/top-suite2`, VCS
`V-2023.12-SP1_Full64`, 4 ns behavioral clock, 128 KiB SPAD and 256 MAC.
All rows have strict signed INT32 Golden PASS and two-cycle registered read
responses:

| Shape | Cycles | Read/Write bytes | Operand wait |
|---|---:|---:|---:|
| M1,N16,K32 | 143 | 544 / 64 | 49 |
| M1,N16,K64 | 213 | 1088 / 64 | 103 |
| M4,N16,K32 | 161 | 640 / 256 | 52 |
| M4,N16,K64 | 237 | 1280 / 256 | 112 |
| M8,N16,K64 | 325 | 1536 / 512 | 147 |
| M16,N16,K64 | 501 | 2048 / 1024 | 217 |
| M16,N16,K128 | 1109 | 7168 / 1024 | 697 |

The product path therefore already provides true M1 support without an ABI
change. M8/M16 remain on the established K-fold/tile path. No second GEMV
engine or free SRAM bandwidth is assumed.

## Research comparison boundary

The existing shape-adaptive SPAD campaign (`benchmark/shape_adaptive_spad_ablation.csv`)
measured M1 530→474 cycles (1.1181x) and M4 770→738 cycles (1.0434x) across
its own wrapper and responder. M8/M16 selected baseline. Those results are
feasibility evidence only: the wrapper is explicitly not connected to the
production Matrix command path. A product-level adaptive mapper would need to
emit the same `0x52` descriptors and use the same request ownership, response
latency, protection, abort and completion behavior.

## Selection

- M1: keep product `0x52`; investigate mapper packing and descriptor scheduling
  before any RTL change.
- M4: same path; only consider a mapping change after paired Top measurements.
- M8/M16: retain current mapping unless a paired Top experiment proves a gain.
- K tails/partial shapes: retain existing validator and directed Golden tests;
  unsupported GEMM layouts are rejected by the current contract.

The current evidence does not demonstrate the required 10% Product Top gain.
Milestone 2 is therefore **PARTIAL**, with a concrete mapper study remaining;
public ABI and product RTL are unchanged.
