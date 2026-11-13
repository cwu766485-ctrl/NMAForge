# BPF-TE Round 4 Gate 1-5 Evidence

Base: `1646cf5f65427148b5ec1c501736eeef8dac1f0f`
Research branch: `research/bank-parallel-fault-precise-v1`

## Gate 1: Real Datapath Closure

CNM output writeback no longer uses a tied-high sink. The wrapper arbitrates a
CNM single-word write against BPF-TE bank transactions, drives the selected
bank's address/data/byte enables into the shared four-bank SPAD, and only
returns `spad_ready` when the target bank is available and the atomic adapter
has no request in that cycle. Accepted/response/denied counters now count
physical bank lanes.

The real engine test passes:

```text
BPF_TE_REAL_CNM_PASS result=124 cycles=13
CNM writeback commit: address 0x300, data 0x0000007c
BPF_TE_REAL_CNM_MEMORY_GOLDEN_PASS addr=0x300 data=124
BPF_TE_REAL_MATRIX_PASS result=0xfffffffc cycles=19 line_writes=4
Matrix Line data: 0xfffffffc repeated across all four 128-bit output Lines
```

The Matrix input is nonzero signed INT8 (`+1` by `0xff`), so each 4-wide
output is `-4`; all Line writes use full `WSTRB=0xffff`. This checks arithmetic,
signedness, bank response assembly, and real writeback acceptance.

## Gate 2: Epoch and Transaction Lifecycle

An accepted CNM read is flushed with `epoch_bump`. The wrapper now presents the
epoch event as an engine abort in the same synchronous contract; otherwise a
one-cycle `rsp_dropped` pulse would be sampled too late and the engine could
wait forever for a response that was deliberately discarded.

```text
BPF_TE_EPOCH_ABORT_PASS code=3 cycles=3
```

The research-top SVA run reports 2/2 assertions with real attempts/successes,
0 failures/incomplete, and 2/2 cover properties matched. The checks cover
CNM write commit and epoch-time writeback exclusion.

This is a non-vacuous accepted-request case. The existing Atomic regression
continues to pass all-or-none denial, epoch admission blocking, response owner,
and fairness checks. Consecutive reset, Matrix/CNM back-to-back, and abort
during a committed write still need broader coverage; no claim of complete
transaction-lifecycle closure is made.

## Gate 3: Fair H0/H1 Harness

The common four-bank memory geometry, host priority, and two-cycle response
latency are unchanged. H1 real-engine traffic is driven through
`ai_bpf_te_compute_subsystem` and the same research SPAD. The existing matched
bank-disjoint control measurement remains:

| Workload | H0 | H1 | Result |
|---|---:|---:|---|
| Two bank-disjoint physical reads | 6 cycles, 1.00 accepted/cycle | 3 cycles, 2.00 accepted/cycle | protocol capability PASS |
| Real CNM VDOT length=1 | product replay not yet matched | 13 cycles, Golden PASS | H1 datapath evidence |
| Real Matrix 4x4x1, signed | product replay not yet matched | 19 cycles, 4 Line commits, Golden PASS | H1 datapath evidence |

The product H0 uses `ai_spad_arbiter`'s legal `banked_valid` and full CNM
interfaces. It cannot accept four independent BPF-TE Port-B requests because
its scheduler contract has one banked request and one global Port-B path. A
forced four-request conversion would be an unfair H0 and is not performed.
Therefore a product-level speedup, Matrix×CNM overlap, and DMA contention
number remain `BLOCKED_BY_CONTROL_CONTRACT`.

## Gate 4: System A/B Status

| Scenario | H0/H1 status | Reason |
|---|---|---|
| Matrix standalone | H1 PASS; H0 not matched | product replay harness pending |
| CNM standalone | H1 PASS; H0 not matched | product replay harness pending |
| Matrix × CNM | BLOCKED_BY_CONTROL_CONTRACT | product dispatcher/arbiter contract |
| Matrix × Scalar | BLOCKED_BY_CONTROL_CONTRACT | scalar uses global Port-B |
| CNM × Scalar | BLOCKED_BY_CONTROL_CONTRACT | scalar uses global Port-B |
| Scalar × Scalar | NOT_APPLICABLE | no legal independent dual scalar Port-B |
| Same-bank contention | H1 protocol PASS | no illegal parallel admission |
| Representative GEMM/GEMV | H1 basic PASS | no fair product baseline yet |

The 2.00x bank-level result is not reported as system speedup.

## Gate 5: PPA and Decision

VCS elaboration of the isolated research top passes. No legal standard-cell
library, SDC, or compatible four-Port SRAM macro is present in this worktree;
ASIC synthesis, STA, and physical SRAM area are therefore `NOT_MEASURED`.
The shared behavioral SPAD is not used as an SRAM macro area estimate.

Decision: **REWORK / REJECT_FOR_PRODUCT_PENDING_H0**. The datapath prototype is
retained for research and DV, but H2 Ownership and H3 DMA/Compute overlap are
not started until a matched product H0 can demonstrate useful bank-disjoint
system work.

## Reproduction

```bash
cd /tmp/nmaforge-bpf-te
VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
$VCS_HOME/bin/vcs -full64 -sverilog -timescale=1ns/1ps \
  -Mdir=/tmp/r4_compute_mdir8 -f dv/research/bpf_te/compute_subsystem.f \
  -top tb_ai_bpf_te_compute_subsystem -o /tmp/r4_compute8
/tmp/r4_compute8 -l /tmp/r4_compute8_run.log
```
