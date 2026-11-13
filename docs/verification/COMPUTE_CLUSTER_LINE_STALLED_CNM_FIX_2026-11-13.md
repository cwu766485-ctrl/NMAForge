# Line-Stalled CNM Golden Mismatch Closure

## Root Cause

The failure was a compact-fixture allocation/lifetime bug, not a DUT arithmetic
or response-owner defect. Seed `20261025` reproduced the original failure at
simulation cycle 39390:

```text
line-stalled CNM Golden[8] addr=0x00014020
expected=0x000012c8 actual=0x0000109b
```

The line-stall CNM B image occupies `[0x13000, 0x15000)`. Its row 8 K=0 words
begin at `0x14000`, with four lane words at `0x14000..0x1400c`; row 8 K=2 lane 0
is `0x14020`. The original CNM destination was `0x14000`, so the first CNM
writeback overwrote a still-live B operand. A trace replay with that original
destination restored (Golden and assertions enabled) captured:

| Cycle | Accepted transaction | Result |
|---:|---|---|
| 26977 | Host initialization writes row 8/K0/lane0, `addr=0x14000 data=0x03020100` | Correct operand initialized |
| 27033 | Host initialization writes row 8/K2/lane0, `addr=0x14020 data=0x05040302` | Correct operand initialized |
| 34660 | CNM tag 5 output write, `addr=0x14000 data=0x00000a58 wstrb=1` | First destructive transaction; overwrites row 8/K0/lane0 |
| 35461 | CNM tag 5 lane 0 read accepted, `addr=0x14020` | Request is legal and has no Matrix line stall |
| 35463 | CNM tag 5 lane 0 response, `addr=0x14020 data=0x00000a58` | Returned data equals the earlier row-0 write, not initialized `0x05040302` |
| 35553 | CNM output write accepted, `addr=0x14020 data=0x0000109b` | Corrupt row 8 result becomes externally visible |
| 39415 | Independent Golden check fails at `0x14020` | Expected `0x12c8`, actual `0x109b` |

The output array and B input were simultaneously live. Serialization would have
hidden the intended Matrix/CNM arbitration overlap, so the fix keeps the
workload, shape, Golden, overlap, and line-stall assertions unchanged and moves
only the CNM output image to disjoint memory. No RTL change was needed.

## Compact Allocation Map

All addresses below are byte offsets in the 128 KiB SPAD aperture
`[0x00000, 0x20000)`. Ranges are half-open. Concurrent line-stall workload
regions are disjoint. Other test families reuse slots only after completion,
queue retirement, and `wait_spad_idle()`; those serialized reuses are not live
concurrently.

| Region | Address range | Lifetime / contract |
|---|---|---|
| Base CMDQ/CPLQ | CMDQ `[0x00100,0x00140)`; CPLQ `[0x00500,0x00540)` | Four 16-byte slots; serialized with other queue fixtures |
| Line-stall descriptors | CMDQ `[0x00280,0x00300)`; CPLQ `[0x00680,0x006c0)` | Two descriptors, two ordered completions; live through the line-stall command pair |
| Matrix A/B/Y in line-stall pair | A `[0x04000,0x04100)`; B `[0x06000,0x06200)`; Y `[0x08000,0x08800)` | Matrix `16x32x16`, 512 INT32 outputs; active concurrently with CNM |
| Line-stall CNM A | `[0x12000,0x12200)` | 32 packed K words x four lanes; read-only during pair |
| Line-stall CNM B | `[0x13000,0x15000)` | 16 rows x 32 K words x four packed lane words; read-only during pair |
| Line-stall CNM Y, fixed | `[0x16000,0x16040)` | 16 INT32 outputs; disjoint from every live operand and Matrix output |
| Former conflicting CNM Y | `[0x14000,0x14040)` | Illegal: wholly inside CNM B; original destination retained only as failing replay evidence |
| Protection/reset destination slots | `[0x0f000,0x0fc00)` for slots 32..43 | 12 serial 0x100-byte slots, away from Matrix fault source regions; each case completes before reuse |
| Full-CPLQ protection sentinels | `[0x0c000,0x0c700)` | Seven serial 0x100-byte destinations; separate from each case's CMDQ/CPLQ and operands |
| Engine abort sentinels | `[0x0e000,0x0e700)` | Seven serial 0x100-byte slots; each accepted-read abort drains before next case |
| Compact end guard | `[0x1ffff,0x20000)` | Last legal byte; `spad_write()` now rejects local addresses `>=0x20000` |

Protection/fault cases intentionally install per-test protection regions; the
line-stall workload's accepted request/response trace records protection
allowed and parity clear. No address masking or modulo arithmetic is used.

## Other Fixture Lifetime Corrections Exposed by Full Regression

The full seed exposed adjacent fixture defects that had been hidden behind the
original Golden failure. These were corrected without changing DUT behavior:

- Full-CPLQ protection output slots were moved from beyond the aperture to
  `[0x0c000,0x0c700)`.
- CNM and Matrix parameter-latch tests now restore their reused C1/MATRIX input
  images before launch, preserving the same original data and Golden.
- Descriptor mutation during active scheduler traffic uses the existing
  parity-consistent UVM backdoor helper. The Behavioral SPAD contract rejects
  concurrent Host requests, so this isolates launch-snapshot behavior without
  violating the Host-vs-scheduler collision rule.
- Abort sentinels were compacted to `[0x0e000,0x0e700)`.
- Protection/reset destination slots 32..43 were moved away from the Matrix
  parity-fault source region to `[0x0f000,0x0fc00)`.
- Every `spad_write()` now rejects an out-of-range local address before issuing
  AXI-Lite traffic.

## Fixed Trace and Verification

With CNM Y at `0x16000`, the fixed replay records row 8/K0/lane0 initialization
at cycle 26977 (`0x14000`, `0x03020100`), accepted CNM lane 0/tag 5 read at cycle
35455, and its registered response at cycle 35457 with the same data. The
independent Golden row 8 output is accepted at cycle 35553 as `0x12c8` at
`0x16020`; it cannot alias the B image. The test observes 92 Matrix line
stability checks, zero payload violations, and 1840 cycles of real Matrix/CNM
overlap.

| Check | Result |
|---|---|
| VCS | `V-2023.12-SP1_Full64`; compile and simulation passed |
| Compute Cluster seeds | `20261025`, `20261026`, `20261027`; all full regressions passed |
| UVM severity | 0 warnings, 0 errors, 0 fatals for each passing seed |
| Directed line stall | 92 stability checks, 0 violations; 1840 overlap cycles; Golden and ordered completions passed |
| Seven-engine overlap | 21/21 functional pair bins observed, 100% |
| Fault cross | 18/18 parity cases; protection, abort, reset, owner and completion checks passed |
| Top smoke | `make ai_smoke`, PASS |
| Seeded top regression | `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345`, PASS |
| Coverage databases | VCS line/condition/branch/FSM/assert databases and merged URG report generated under `/tmp`; seeds 20261026/27 merged summary: line 69.46%, condition 67.13%, FSM 43.47%, branch 66.26%, assertions 72.00%, functional groups 83.94% |
| SVA disposition | 17/22 assertions succeeded, 5 uncovered, 0 failures; 2 properties had no attempts. Of three cover properties, W-stall matched twice; AR/AW stall-then-accept did not match. These remain coverage gaps, not vacuous passes |
| SpyGlass lint | 0 errors, 467 warnings, 5 infos; tool completed, warning closure remains open |
| SpyGlass CDC setup | 0 errors, 1 warning, 9 infos; tool completed |
| SpyGlass CDC structural | 0 errors, 2 warnings, 38 infos; tool completed; no sign-off claim |
| SpyGlass RDC | Incomplete: stalled at `Ar_resetcross01` after 385/478 rules while using about 6.6 GB RSS; interrupted, no result |

Reproduction and passing commands (run from the named directories):

```bash
cd dv/uvm/sim
make uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_SEEDS=20261025 COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_line_stalled_fix_seed25_retry9_20261113
make uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_SEEDS='20261026 20261027' COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_line_stalled_fix_seed26_27_20261113
cd ../../subsystem/top_smoke/sim
make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
cd ../../../spyglass
PATH=/opt/Synopsys/spyglass/V-2023.12-SP1/SPYGLASS_HOME/bin:$PATH bash ./run_spyglass_a8.sh all
```

Original failure trace is in
`/tmp/nmaforge_line_stalled_overlap_trace_20261113/seed_20261025/run.log`;
the minimal original failure is retained at
`/tmp/nmaforge_cnm_golden_repro_20261113/seed_20261025/run.log`. Fixed run logs
and VCS/URG databases are under the `/tmp/nmaforge_line_stalled_fix_*` paths
above. No generated EDA report or database is added to Git.
