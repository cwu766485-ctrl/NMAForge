# BPF-TE Round 3 Gate 1-4 Evidence

Date: 2026-11-14
Branch: `research/bank-parallel-fault-precise-v1`
Base: `4d34c1916e0db3a5ef69b9141eb1ea92e0d64b22`

## Gate 1: Protocol Repair

The atomic adapter now reserves all four physical banks before asserting any
bank request. `line_ready`, `cnm_ready`, and `matrix_ready` are all-or-none
(see [ai_bpf_te_atomic_adapter.sv](../../rtl/research/ai_bpf_te_atomic_adapter.sv):41-65).
The bank adapter exposes availability independently of request address, while
the arbiter performs alignment and 128 KiB bounds checks (see
[ai_spad_bank_parallel_adapter.sv](../../rtl/research/ai_spad_bank_parallel_adapter.sv):64-75
and [ai_spad_bank_parallel_arbiter.sv](../../rtl/research/ai_spad_bank_parallel_arbiter.sv):
the bank decode block). Round-robin state advances from the actual winning
requester.

The atomic VCS test passes line write/read, one- and multi-bank denial with
zero accepted writes, epoch denial, full CNM owner/data response, partial CNM
rejection, and Line-over-CNM priority. Coverage run:

```text
VCS V-2023.12-SP1_Full64
urg /tmp/r3_atomic_cov.vdb
line 93.28%, condition 51.46%, branch 68.25%, assertion 100.00%
8/8 assertions: 8 real successes, 0 failures, 0 incomplete, 0 no-attempt
```

The legacy atomic test is now explicitly connected to the optional Matrix
ports, so there is no unconnected-input X state in the regression.

## Gate 2: Real Compute Subsystem Integration

`ai_bpf_te_compute_subsystem.sv` is an isolated research top. It instantiates
the real `ai_banked_cnm_core`, `ai_tensor_matrix_core`, the BPF-TE atomic
adapter, and the four-bank research SPAD. The product top and product source
lists are unchanged. Matrix banked reads are converted to four aligned bank
slots and Matrix Line writes use the same atomic adapter. CNM four-lane reads
use the same response path. This is a real engine handshake, not a synthetic
request generator.

The executable test passes:

```text
BPF_TE_REAL_CNM_PASS result=124 cycles=13
BPF_TE_REAL_MATRIX_PASS result=0 cycles=19
```

The CNM Golden is four signed INT8 products (2*7 + 3*8 + 4*9 + 5*10 = 124).
The Matrix case is a zero-filled 4x4 GEMM and checks completion without error,
banked reads, and aligned Line writeback. The real-SPAD regression also passes
the existing H0/H1 protocol workload and reports 91.24/52.60/54.55% line/
condition/branch with 100% assertion coverage.

The following Gate 2 items remain explicitly open: CNM output `spad_*` writes
are accepted by a tied-high research sink rather than committed to the SPAD;
the wrapper has no scalar engine, DMA, completion queue, or product protection
decoder; and parity/protection injection is covered in the SPAD adapter tests,
not yet through a full engine completion. Therefore this is an integrated
Matrix/CNM request-path proof, not seven-engine closure.

## Gate 3: Product-Level H0/H1 A/B

The only measured H0/H1 comparison remains the matched four-bank protocol
workload:

| Workload | H0 serial | H1 bank-parallel | Status |
|---|---:|---:|---|
| Two bank-disjoint reads | 6 cycles | 3 cycles | measured, Golden PASS |
| Matrix/CNM real-engine cycles | not run on legacy product top | CNM 13, Matrix 19 | H1 integration evidence only |
| Scalar/DMA contention | not measured | not measured | open |
| Seven-engine workload | not measured | not measured | open |

The 2.00x result is a bank-level capability measurement and is not a product
NPU speedup. A fair product H0 requires the legacy `ai_spad_arbiter` and its
single global scheduler Port B to be replayed with the same real engine traffic;
that port cannot accept four independent BPF-TE bank requests without changing
the product contract. Gate 3 is therefore `BLOCKED_PENDING_PRODUCT_H0`.

## Gate 4: Architecture Decision

No H2 ownership mechanism or H3 DMA/compute overlap mode is started. The real
CNM/Matrix path proves that the H1 request protocol can carry useful engine
traffic, but there is not yet a matched product-level speedup or a complete
output/protection/completion contract. Current decision: **REWORK** as an
independent research prototype; do not enter the product branch.

## Reproduction

```bash
cd /tmp/nmaforge-bpf-te
VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
$VCS_HOME/bin/vcs -full64 -sverilog -timescale=1ns/1ps \
  -Mdir=/tmp/r3_atomic_cov_mdir -cm line+cond+branch+fsm+assert \
  -cm_dir /tmp/r3_atomic_cov -f dv/research/bpf_te/atomic.f \
  -top tb_ai_bpf_te_atomic_adapter -o /tmp/r3_atomic_cov_simv
/tmp/r3_atomic_cov_simv -cm line+cond+branch+fsm+assert -cm_dir /tmp/r3_atomic_cov
$VCS_HOME/bin/urg -dir /tmp/r3_atomic_cov.vdb -report /tmp/r3_atomic_urg -format text

$VCS_HOME/bin/vcs -full64 -sverilog -timescale=1ns/1ps \
  -Mdir=/tmp/r3_compute_mdir3 -f dv/research/bpf_te/compute_subsystem.f \
  -top tb_ai_bpf_te_compute_subsystem -o /tmp/r3_compute_final3
/tmp/r3_compute_final3
```

Tool-generated VCS/URG databases remain outside the repository.
