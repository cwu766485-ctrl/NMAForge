# Compute Cluster real-top benchmark — R153 — 2026-11-01

## Result

R153 measures serial, staged, and fully parallel tasks through the real top-level
CMDQ and shared SPAD. The candidate is clean-worktree test SHA
6e47629f103e3ab36948c5bb4eadc196cd27dfb4, tree
21478d7e4a595e17b27f7b0e89810d3617a4fd82. VCS
V-2023.12-SP1_Full64 with UVM 1.2 compiles the testbench and passes three seeds:
20261025, 20261026, and 20261027. All three seeds report UVM warning/error/fatal
0/0/0. Each full sequence checks 63,597 SPAD words with zero mismatch, unknown
read, or stale-epoch observation.

| Mode | Workload | Cycles | Comparable serial cycles | Speedup | SPAD read/write bytes | Completion order |
|---|---|---:|---:|---:|---:|---|
| Serial | Matrix 16×32×64, CNM 16 outputs, two GELU-64 tasks | 1,696 | 1,696 | 1.000× | 4,352 / 2,688 | 05ff → 0601 → 0602 → 0603 |
| Staged | Matrix + CNM together, then one GELU-64 | 1,070 | 1,239 (same three tasks serialized) | 1.158× | 4,032 / 2,416 | 0700 → 0701 → 0702 |
| Parallel | Matrix + CNM + two GELU-64 tasks | 1,137 | 1,696 (same four tasks serialized) | 1.492× | 4,352 / 2,688 | 0600 → 0601 → 0602 → 0603 |

The staged 1,239-cycle comparator is Matrix 565 + CNM 217 + one GELU 457.
The staged concurrent Matrix/CNM segment is 613 cycles and the following GELU
segment is 457 cycles. The full parallel case reduces counted task service
cycles by 32.96% against the four-task serial aggregate. These values were
identical across the three seeds.

Every descriptor completion is checked for ID, status/result and length. The
Matrix output, CNM output and both SFU output images are compared against the
sequence's independent Golden values. The full regression also exercises the
seven-engine real-top sequence, response tags, reset/abort recovery, and its
memory scoreboard; this is a regression result, not evidence that every
requirement is closed.

## Measurement definition

Cycle intervals begin immediately before the doorbell and end when the expected
completion-queue tail is observed. Descriptor setup between serial tasks is
excluded; the serial aggregate is the sum of each task's doorbell-to-tail
interval and does not include software gaps. Staged mode sums its Matrix/CNM
and SFU intervals. Parallel mode measures one shared doorbell-to-final-tail
interval. The reported speedups therefore compare accelerator service cycles,
not host-to-host application latency.

SPAD byte counts include accepted, access-allowed scheduler-side transactions
inside the measured windows. Scalar words count as 4 bytes, Line reads as 16
bytes, Line writes by WSTRB population count, Matrix banked reads as 16 bytes
(four 32-bit banks), and accepted CNM lanes as 4 bytes each. Testbench memory
initialization before the timed windows is excluded. The counters are passive
UVM interface monitors; no product RTL was changed for this measurement.

The staged metric named pair_contention_cycles in the raw log is reported here
as 32 Matrix/CNM joint-admission observations: both request classes were
active and at least one was granted. It is not a stall count. The fully parallel
case records 38 shared-SPAD backpressure cycles, where core and banked requests
were both valid and were not both ready. Other engine wait states are not
broken down by this top-level benchmark.

## Reproduction

From a clean worktree at the candidate SHA:

    make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r153_final_clean/uvm COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

The environment used the behavioral scratchpad and a 10 ns simulation clock.
This is RTL simulation cycle evidence only. It is not ASIC PPA, SRAM timing,
measured silicon throughput, or a TinyNPU common-memory comparison. No GOPS or
frequency-normalized result is claimed.

## Evidence

- [Three-seed result CSV](compute_cluster_cluster_r153.csv), 9 rows.
- Compile, merged URG, and three per-seed run logs are archived at
  /tmp/nmaforge_r153_cluster_benchmark_3seed_logs.tar.gz; SHA-256
  d7e0b58f786f1ce049b334bf0f0a522afb7b1ab65f150e2eb6b9170ae2e8202c.
- Log SHA-256 values are in the archive's SHA256SUMS file.
- Run ID: R153-UVM-CLUSTER-BENCH-3S-20261101.

R153 adds measured real-top concurrency and SPAD traffic evidence for
REQ-CL-028 and bounded Golden/response evidence for REQ-PC-006/007. The overall
38-requirement result remains 24 PASS-SCOPED / 14 PARTIAL; Compute Cluster
v1.0 remains HOLD. Common-memory TinyNPU comparison, broader performance
coverage, and ASIC PPA are still open.
