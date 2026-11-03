# Scalar INT8 Numeric Boundary Replay — R230

**Date:** 2026-11-03
**Candidate SHA:** `c5755985b0e5b1e1a850122ece983a37be112272`
**Candidate tree:** `b0ee13ed91399ce0f982c36a6f5e55e9857e2061`
**Tools:** Synopsys VCS `V-2023.12-SP1_Full64`; Python `3.12.13`
**Run ID:** `R230-SCALAR-INT8-NUMERIC-CLOSEOUT-3S-20261103`
**Seeds:** `20261025`, `20261026`, `20261027`

## Result

The standalone Scalar INT8 datapath/core test passes all 13 independent Golden vectors on each of three seeds. The vectors cover signed lane ordering, arithmetic shift behavior (including shifts 0 and 31), product extrema, positive/negative saturation, ReLU/ReLU6 clamps, bias ordering, and representative VDOT/GEMV/GEMM shapes. Read and write stall counters are nonzero across the campaigns.

| Seed | Golden cases | Opcode bins | Responses | Read stalls | Write stalls |
|---|---:|---|---:|---:|---:|
| `20261025` | 13/13 | VDOT 11, GEMV 1, GEMM 1 | 152 | 52 | 1 |
| `20261026` | 13/13 | VDOT 11, GEMV 1, GEMM 1 | 152 | 60 | 12 |
| `20261027` | 13/13 | VDOT 11, GEMV 1, GEMM 1 | 152 | 39 | 10 |

## Reproduction

```sh
for seed in 20261025 20261026 20261027; do
  make -C dv/block/compute/int8/sim numeric-regress \
    SEED=$seed \
    OUT=/tmp/nmaforge_r230_scalar_int8_py312_$seed \
    VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1' \
    PYTHON=python3.12
done
```

The successful vector generation used Python `3.12.13`; an initial invocation with the unqualified `python3` failed before VCS because that interpreter did not support the generator's `__future__.annotations` import. The rerun above is the passing run. VCS compile logs have no `Warning-`, `Error-`, or `[TFIPC]` diagnostics.

Evidence archive: `/tmp/nmaforge_r230_scalar_int8_3seed_20261103.tar.gz`, SHA-256 `ff67d09952c7de0804eb219321aeec3abff115434cb23b8a1635ff05cd3bc3ba`; manifest SHA-256 `012ffd7f1f4c3186ddbdec2351c270bcc59840edd05d3ef49f9947030154ad8d`. It contains generated vectors plus compile/run logs for each seed; simulator binaries are excluded.

## RTM and sign-off impact

This replays the common Scalar INT8 arithmetic point for `REQ-CL-020` at the current closeout candidate. It is standalone block evidence: it does not fetch a CMDQ descriptor, prove all engine-specific shape/address limits, close legacy Conv coverage, or cover the full error/reset cross. `REQ-CL-020` remains PARTIAL; the RTM remains **24 PASS-SCOPED / 14 PARTIAL**, and `CL-DV-v1.0` remains **HOLD**.
