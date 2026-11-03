# SFU Numeric Boundary and Randomized-Latency Replay — R239

**Date:** 2026-11-03
**Test source content:** `7a9a750`; R238/R239 descendants through this replay change documentation only.
**Tool:** Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.
**Run ID:** `CL-SFU-NUMERIC-BOUNDARY-R239-3S-20261103`
**Seeds:** `20261025`, `20261026`, `20261027`.

## Command and result

```sh
make -C dv/block/compute/sfu/sim random-latency-regress \
  VCS="/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1" \
  VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  SEEDS='20261025 20261026 20261027' \
  OUT_DIR=/tmp/nmaforge_r239_sfu_numeric_20261103

/tmp/nmaforge_vcs_home_linux_alias/bin/urg -full64 \
  -dir /tmp/nmaforge_r239_sfu_numeric_20261103/coverage.vdb \
  -format text \
  -report /tmp/nmaforge_r239_sfu_numeric_20261103/urg_merged \
  -log /tmp/nmaforge_r239_sfu_numeric_20261103/urg.log
```

All three seeds pass. Each run completes 64 independent-reference vectors, nine error cases, a late fault, Abort/watchdog priority, fault/reset recovery, 39 FSM reset-state probes, 39 FSM Abort-state probes, RMSNorm gamma bypass, Matrix-A tile packing, and a 16-element GELU parameter-latch check. Each seed returns 1,091 responses for 1,091 reads, performs 451 writes, observes response delay up to seven cycles, and has 525–537 ready stalls. Compile log has no `Warning-`, `Error-`, or `[TFIPC]` diagnostics.

The 64 vectors cover all eight SFU opcodes (`0x32`–`0x39`) at lengths `1, 2, 3, 4, 7, 8, 15, 16`. GELU and SiLU include their piecewise boundary values. Outputs are compared bit-exactly against the Python reference implementing the frozen v1.3 integer formulas, so no approximation tolerance is applicable to these fixed-point operations. This is scoped SFU-core evidence; it does not close top-level descriptor shape/address bounds or broader engine/fault/phase/reset interactions.

Merged URG code coverage is 88.85% overall and, for `ai_tensor_sfu_core`, line/condition/FSM/branch is `88.02/85.21/85.00/100.00%`. These code metrics are reported separately from functional testpoint results and do not imply full SFU RTL coverage.

## Evidence archive

- Archive: `/tmp/nmaforge_r239_sfu_numeric_evidence_20261103.tar.gz`
- Archive SHA-256: `b8014ce9b625fd6ca7a70b6411f5bd4e281956a8aab5384a1f8edfaf68bac612`
- Manifest SHA-256: `5a88887e800ac8ad91107c089b90f8175bcce77fa1b0a4d1a4aa6d2125344cfa`
- Compile log SHA-256: `05fa16d8dee5040a644b3912ef177529b776cd4d3f0bcfaf38788b82f5c01656`
- Seed log SHA-256 values: `20261025` `9e4e3bca817ff034733c7d26638cd8191055d1bfda31546fc08850c7e4354e0a`; `20261026` `364b18ce53b43359cf6397d3252c0005bcff76739ce3e11ae20745a98a6f7aff`; `20261027` `338e038388326344977efe7bed8b1a5d8c6cd8284c1e2ca540cdf236c981e520`.

**Disposition:** Adds current exact-source execution evidence to `REQ-CL-023`; the existing `PASS-SCOPED` status remains bounded to these declared opcodes, lengths and core-level interface. No other requirement is promoted. `CL-DV-v1.0` remains **HOLD**.
