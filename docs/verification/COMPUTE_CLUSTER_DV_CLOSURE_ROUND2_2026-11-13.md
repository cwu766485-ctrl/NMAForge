# Compute Cluster DV Closure Round 2: Initial Baseline

## Scope and Evidence Identity

This report uses the exact integrated bugfix source `76805a45d8914ecdc998d98b419c8a19053b1daa` on `bugfix/compact-spad-line-stalled-cnm`, compared with `candidate/frontend-closeout` at `f919bb787dab1a4e3bef44b5308ead56d6e77b72`. The bugfix adds the compact-SPAD line-stall fixture correction, passive UVM observation and report material; it changes no product RTL. The worktree was clean before this round.

Tools: VCS/URG `V-2023.12-SP1_Full64`, Linux, license server available. The following databases are separate by design:

| Evidence | DUT hierarchy | Seeds / workload | Result |
|---|---|---|---|
| Top Smoke code coverage | `ai_accel_compute_cluster`, command-processor tile pipeline, parallel dispatcher, compute SPAD mux, from `ai_compute_cluster_dut.cm_hier` | `20261025`, `20261026`, `20261027`; `AI_RANDOM_CASES=4` | line 85.74%, condition 76.97%, FSM 43.74%, branch 82.09% |
| Compute Cluster UVM URG | Complete `tb_ai_accel_uvm` hierarchy, including UVM/TB code; not DUT-only | `20261025`, `20261026`, `20261027` | line 69.46%, condition 67.13%, FSM 43.47%, branch 66.26%, assertion 72.00%, groups 83.94% |
| Existing AXI stall directed UVM | Complete UVM hierarchy; used only for the AXI master stall SVA | `20261015`, configured AR gap 2 / AW gap 3 | AR/AW/W cover matches 14/5/12; zero UVM warning/error/fatal |

Do not add the UVM URG summary to the DUT-only Top Smoke numbers: the DUT hierarchy, simulator top, test set and source-level instrumentation differ. The Top Smoke database is a three-seed merged VDB generated from one compile at the same source SHA. It measures only the hierarchy entries listed above; it is not coverage for every top-level control, DMA, SPAD or UVM class.

Artifacts are under `/tmp/nmaforge_round2_dutcov_sha76805a45_20261113` and `/tmp/nmaforge_round2_uvm_sha76805a45_20261113`. The raw VDBs and detailed URG reports remain outside Git.

## Gate 1: Bugfix and Compact Allocation

The branch is two commits ahead of the product candidate: `ca53e504` contains the fixture fix and `76805a45` corrects its report. Reviewable diff is limited to `dv/uvm/agent/interfaces/ai_compute_cluster_if.sv`, `dv/uvm/tests/sequences/ai_compute_cluster_e2e_seq.svh`, `docs/verification/COMPUTE_CLUSTER_LINE_STALLED_CNM_FIX_2026-11-13.md` and `docs/project_update_log.md`; no RTL file changes. The original Golden, concurrent workload, completion checks and line-stall assertions remain intact.

The compact aperture is `[0x00000,0x20000)`. Relevant fixed intervals and lifetimes are:

| Region | Range `[start,end)` | Lifetime / disposition |
|---|---|---|
| Base CMDQ / CPLQ | `[0x00100,0x00140)` / `[0x00500,0x00540)` | Serialized queue fixtures |
| Line-stall CMDQ / CPLQ | `[0x00280,0x00300)` / `[0x00680,0x006c0)` | Two ordered Matrix/CNM commands and completions |
| Matrix A / B / Y | `[0x04000,0x04100)` / `[0x06000,0x06200)` / `[0x08000,0x08800)` | Live across Matrix and CNM overlap; pairwise disjoint |
| CNM line-stall A / B / Y | `[0x12000,0x12200)` / `[0x13000,0x15000)` / `[0x16000,0x16040)` | Inputs read-only while pair is active; output disjoint |
| Former CNM Y | `[0x14000,0x14040)` | Invalid: overlapped live CNM B; retained only in failure evidence |
| Protection/reset destinations | `[0x0f000,0x0fc00)` | 12 sequential `0x100`-byte slots; each owner completes before reuse |
| Full-CPLQ sentinels | `[0x0c000,0x0c700)` | Seven sequential slots; CPLQ backpressure and release are checked |
| Abort sentinels | `[0x0e000,0x0e700)` | Seven sequential slots; accepted reads drain before reuse |
| End guard | `[0x1ffff,0x20000)` | Last legal byte; `spad_write()` rejects address `>=0x20000` |

For CNM row 8, the B operand address expression is `B + 0x80 + lane*4`. Its four 32-bit lane words are `0x13080`, `0x13084`, `0x13088`, and `0x1308c`, all within the live B allocation. The output begins at `0x16000`; no row-8 operand aliases it. The former Y at `0x14000` overlapped B and the original trace identified the first destructive transaction.

Added `dv/uvm/tests/check_compact_spad_alloc.py` checks the line-stall A/B/Y and Matrix-Y constants against the 128 KiB aperture, checks pairwise live-range separation, and checks all four row-8 lane addresses. `uvm_compute_cluster_compile` runs it before invoking VCS. Other serial fixture reuse continues to rely on explicit completion/idle sequencing and runtime `spad_write()` bounds; this small checker does not statically prove every dynamic allocation lifetime.

## Gate 1 Regression Evidence

The exact SHA was recompiled and the full Compute Cluster UVM sequence passed on all requested seeds. Each seed reports the line-stall directed case with 92 line-stability checks, zero payload violations, 1840 overlap cycles, exact Golden outputs and ordered completions; all three logs have zero UVM warnings, errors and fatals. The existing AXI stall directed test passed from the same compiled image and reached all three AXI channel cover properties. Top Smoke DUT-only coverage also ran and passed all three seeds. The original fix report records the prior `make ai_smoke` and seeded Top Smoke regression PASS; these broad commands were not rerun in this round because the checked-in Top Smoke targets compile into ignored source-tree `simv`/log paths. The Top Smoke coverage target compiled and ran from an isolated `/tmp` output directory instead.

## Gate 2: Uncovered Bin Triage (Initial)

The current DUT-only summary is **not closed**: FSM is 43.74%, with line/condition/branch also containing uncovered bins. The URG module report includes these initial examples; the classifications are provisional until every raw bin is assigned a requirement and legal trigger:

| RTL / bin example | Logic and trigger condition | Initial class | Follow-up |
|---|---|---|---|
| `rtl/compute/fp/ai_bf16_mul_fp32.v:62-69` | NaN, invalid zero-times-infinity and infinity result selection | Reachable but untested | Add valid BF16 boundary vectors and compare exact FP32 result |
| `rtl/compute/fp/ai_bf16_mul_fp32.v:104-146` | Overflow and subnormal rounding, including underflow-to-zero and carry-to-min-normal | Reachable but untested | Map to numeric Golden cases; no waiver until operands are exercised |
| `rtl/compute/conv/ai_conv3x3_linebuffer_core.v` | Line-buffer FSM and edge/tail branch bins (module line 68.07%) | Reachable but untested / reset corner pending bin review | Expand edge, tail, stall and reset tests against existing convolution contract |
| `rtl/compute/kv/ai_kv_cache_engine.v` | KV state/branch bins (line 67.27%) | Reachable but untested / configuration-dependent pending bin review | Relate uncovered states to supported KV opcodes and legal sequence boundaries |
| `rtl/compute/matrix/ai_tensor_matrix_core.v` | Matrix FSM, protocol and arithmetic branches (line 86.18%) | Reachable-but-untested or fault/reset corner pending per-bin review | Extract exact states/transitions and map to existing Matrix/response tests |
| `rtl/compute/sfu/ai_tensor_sfu_core.v` | SFU control/FSM paths (line 76.91%) | Reachable-but-untested or fault/reset corner pending per-bin review | Analyze operator and iterative termination paths against exact Golden contract |
| `rtl/top/fabric/compute/ai_accel_compute_cluster.v` | Cluster integration branches | Pending detailed hierarchy/bin export | Trace every uncovered line/condition/branch to owner and trigger |

The examples above are not waivers and do not claim exhaustive per-bin disposition. Configuration-disabled, proven-unreachable, dead/redundant and tool-artifact bins have **not** been granted. No effective protection logic was removed or excluded. Top Smoke GROUP 20% is a low-level group aggregate and is not used as the UVM functional coverage result.

## Functional Coverage and RTM

The UVM sequence checks all 21 seven-engine pairwise overlaps, but those pair bins alone do not prove every operation, bank conflict, result image, owner routing and fault interaction. For this baseline, each pair's workload and Golden checks pass; line-stall Matrix/CNM also proves actual overlap and backpressure. The UVM monitor covergroup is scoped and excludes only completion-read response as structurally inapplicable because the completion writer emits SPAD writes only.

| Requirement / cross | Evidence | Status |
|---|---|---|
| Seven-engine pair overlap with Golden/completion checks | Three Compute Cluster seeds; `CLUSTER_ALL_ENGINE_PAIR_COVERAGE_PASS` 21/21 | PASS-SCOPED; operation/bank/fault cross remains partial |
| Matrix/CNM response owner and line-stall | Dual-Golden owner checks plus 92 real line-stall stability checks each seed | PASS-SCOPED |
| Fault × reset / accepted-response prefix / full-CPLQ | Directed checks in three UVM seeds, including parity, protection, abort, reset and ordered retirement | PASS-SCOPED; not every legal phase cross is enumerated |
| AXI AR/AW/W stall-to-accept | Existing mixed-precision DDR AXI stall directed target; 14/5/12 cover matches | PASS for AXI master protocol; peripheral to compute-cluster code coverage |
| DUT line/condition/branch/FSM closure | Three Top Smoke seeds, exact scope above | OPEN; uncovered-bin register required |
| RDC and static warnings | Prior bugfix report: RDC stopped during `Ar_resetcross01`; lint has 467 warnings | OPEN; not re-run in this round |

`c_ar_stall_then_accept` and `c_aw_stall_then_accept` are covers with 2,257,254 attempts and zero matches across the three Compute Cluster UVM seeds. Their antecedent requires AXI master `ARVALID && !ARREADY` or `AWVALID && !AWREADY`, followed within eight cycles by a handshake; the compute-cluster workload does not create this DMA-side traffic. `c_w_stall_then_accept` has three matches in the merged three-seed UVM data. The existing deterministic AXI-stall test exercises these cover properties without disabling the protocol assertions. The two properties with zero attempts are UVM RAL internal `do_read`/`do_write` checks, not design assertions.

## Remaining Work and Reproduction

This is an initial closure report, not Compute Cluster DV closure. P0 next steps are: export every DUT-only uncovered line/condition/branch/FSM bin; associate each with RTL line, function, legal trigger, test, requirement and category; add legal tests for reachable P0 bins; review functional crosses with reachability constraints; preserve open bins in a waiver register only after formal/design evidence. SpyGlass/RDC and ASIC readiness remain outside this round's closure claim.

Reproduction from `/tmp/nmaforge-compact-spad`:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_round2_uvm_sha76805a45_20261113

make -C dv/subsystem/top_smoke/sim ai_compute_cluster_cov \
  AI_CLUSTER_COV_RUN=/tmp/nmaforge_round2_dutcov_sha76805a45_20261113 \
  AI_CLUSTER_COV_SEEDS='20261025 20261026 20261027'

python3 dv/uvm/tests/check_compact_spad_alloc.py
```

The dedicated AXI stall run used the just-built UVM simulator with
`+MIXED_E2E_AXI_STALLS=1 +MIXED_E2E_AXI_TXN_JITTER=1 +MIXED_E2E_AR_GAP=2 +MIXED_E2E_AW_GAP=3` and seed `20261015`; its log is `/tmp/nmaforge_round2_uvm_sha76805a45_20261113/axi_stall.log`.
