# Scalar INT8 Numeric Boundary Clean Replay — R283

## Result

The Scalar INT8 numeric regression passes on three seeds using the exact RTL
and block testbench content of the published Compute Cluster candidate. Each
seed passes 14 arithmetic/lifecycle cases: 12 VDOT, one GEMV, and one GEMM
case, with independent signed-integer Golden checks. Cases include signed
INT8 lane extrema (−128/127), maximum product, K=17, shifts 0/1/31/other,
positive and negative saturation, bias-before-shift, ReLU/ReLU6 boundaries,
GEMV M=3/K=5, and GEMM M=2/N=3/K=4. Read and write stalls are observed on all
seeds.

Abort versus expired Watchdog is sampled simultaneously and Abort wins with
two accepted reads returned, no accepted writes, and exactly one completion.
Reset versus Abort is also sampled on the same edge; Reset suppresses the old
task for four quiet cycles, and a fresh VDOT returns Golden value 70.

This is direct-core evidence. It does not cover all CMDQ descriptor shapes,
engine limits, alias/alignment/overflow contracts, or the full fault × phase ×
reset space. `REQ-CL-020` remains `PASS-SCOPED` for its frozen arithmetic
subset; `REQ-CL-015` remains `PARTIAL`; the overall RTM remains 27
`PASS-SCOPED` / 11 `PARTIAL` and `CL-DV-v1.0` remains **HOLD**.

## Identity and evidence

| Item | Value |
|---|---|
| Test ID | `TC-CL-R283-SCALAR-INT8-NUMERIC-BOUNDARY` |
| Run ID | `R283-SCALAR-INT8-3S-20261104` |
| Executed local commit / tree | `1b4f77b64b92e1521b576f77b4602cb959b756ee` / `c2fd480e5455805270bd8b8ac89fe41a06c222e0` |
| Published source/test candidate | `487794dfa2d931391fd5ac82f16626b7c6f878e5` / `c01a4e15f4f72ca120aa5e7d41094173c011f9ea` |
| Source/test relationship | Differences are documentation-only; the INT8 RTL, generator, testbench, and Makefile are identical. |
| VCS / Python | `V-2023.12-SP1_Full64` / Python `3.12.13` |
| Seeds | `20261025`, `20261026`, `20261027` |
| Evidence archive | `/tmp/nmaforge_r283_scalar_int8_3seed_evidence_20261104.tar.gz` |
| Archive SHA-256 | `c1bbc510adb9c225981d841932f7e0dc5107b9d097956c70c9e4f2c93ad1f01b` |

The archive contains each seed's compile log, run log, and generated Golden
vectors. An initial command using the system default Python 3.6.8 stopped in
the vector generator before VCS compilation. Re-running with Python 3.12.13
completed the full three-seed regression; no Python-3.6 run is counted.

## Command and per-seed results

Executed from `/tmp/nmaforge_r278_rrbanked_clean`:

```sh
for seed in 20261025 20261026 20261027; do
  make -C dv/block/compute/int8/sim numeric-regress \
    VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs \
    PYTHON=/usr/bin/python3.12 \
    SEED=$seed \
    OUT=/tmp/nmaforge_r283_scalar_int8_${seed}_py312
done
```

| Seed | Result | Read stalls | Write stalls | Responses |
|---|---|---:|---:|---:|
| `20261025` | 14/14 cases; Abort/Watchdog and Reset/Abort checks pass | 52 | 1 | 158 |
| `20261026` | 14/14 cases; Abort/Watchdog and Reset/Abort checks pass | 60 | 12 | 158 |
| `20261027` | 14/14 cases; Abort/Watchdog and Reset/Abort checks pass | 39 | 10 | 158 |

All three compile logs have no `Warning-`, `Error-`, or `[TFIPC]` diagnostics.
No RTL or testbench files were modified for this replay.
