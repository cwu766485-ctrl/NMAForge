# Compute Cluster Execution RTM — 2026-10-28

**Scope:** `REQ-CL-001..028` and `REQ-PC-001..010` from Compute Cluster SPEC v1.1.\
**Selected review candidate:** `c0832e5c822de1a03f82751d5ff8f831d0addb98` (`main`).\
**Checkout:** candidate source was clean at review start and replayed in a detached worktree. `rtl/` is unchanged between `fa2b4dd` and this candidate.\
**Evidence status:** exact-SHA clean replay and supplemental campaigns now include the real-top seven-engine UVM, checker-sensitivity mutations, 16-seed AXI/FP E2E, three-seed Matrix size/ablation benchmarks, and matched TinyNPU GEMM/CNN-lowering runs. The added runs close reproducibility and selected checker/benchmark gaps; they do not close every RTM requirement.

## Status summary

| Disposition | Count | Meaning |
|---|---:|---|
| PASS-SCOPED | 23 | Named scenario passed; the status does not claim every legal parameter/fault cross is closed. |
| PARTIAL | 13 | Evidence exists, but one or more stated requirement clauses or legal coverage crosses remain open. |
| BLOCKED_SPEC | 2 | No approved numeric/fault-priority oracle exists; no DUT pass/fail is claimed. |
| NOT_RUN | 0 | Each requirement has an execution disposition; blocked items are not silently called untested passes. |

The PASS-SCOPED count preserves the current candidate review classification. In particular, `REQ-CL-022` has Matrix Golden/fault evidence but its partial Line WSTRB contract remains open under `OPEN-CL-004`; `REQ-PC-001` has all 21 pairs in the real dispatcher test with behavioral Engine agents, not all pairs on seven production datapaths.

## Run and evidence index

All VCS/URG evidence is local under `/tmp`; generated databases are deliberately not checked in. Paths are retained here to make each row resolvable. “Source-equivalent” means the RTL/DV files used by the run match the named committed source files; the run itself did not execute from a clean checkout of that SHA.

| Ref / Run ID | Source / tool / seeds | Result and primary evidence path |
|---|---|---|
| **R1 `CLUSTER-S2-UVM-3S-FA2B`** | Test source-equivalent to candidate `c0832e5`; VCS/URG `V-2023.12-SP1_Full64`; seeds `20261025, 20261026, 20261027` | PASS, UVM severity 0/0/0. Logs `/tmp/nmaforge_unverified_cluster_uvm_final3_20261027/seed_{20261025,20261026,20261027}/run.log`; compile `/tmp/nmaforge_unverified_cluster_uvm_final3_20261027/compile.log`; URG `/tmp/nmaforge_unverified_cluster_uvm_final3_20261027/urg_merged/`. Per seed: 4,946 accepted writes, 5,256 compared words, 0 mismatch/unknown/orphan/stale response; line WSTRB full/partial/zero=`512/0/0`; focused covergroup 98.96% (29/30 variables). |
| **R2 `CLUSTER-S2-MUT-25-FA2B`** | Same source-equivalent DV; VCS `V-2023.12-SP1_Full64`; deterministic mutations (seed not applicable) | PASS 25/25 expected checker catches. Logs `/tmp/nmaforge_unverified_cluster_mutations_final_20261027/{address,data,owner,wstrb}.log`, plus `done_engine_{0..6}.log`, `missing_done_engine_{0..6}.log`, `duplicate_done_engine_{0..6}.log`. These mutate passive monitor observations; they are checker-sensitivity tests, not an RTL mutation score. |
| **R3 `MATRIX-S1-DEPTH4-3S`** | Clean detached worktree at `c83ad7463265062d4edb84d57fe4ada8195f9b10`; VCS/URG `V-2023.12-SP1_Full64`; seeds `20261021, 20261022, 20261023` | PASS; 18 Golden/layout + 34 fault/recovery cases per seed. Logs and URG under `/tmp/nmaforge_s1s2_clean_c83ad74_matrix/`. |
| **R4 `MATRIX-S1-NOPREF-3S`** | Same clean source SHA as R3; VCS/URG `V-2023.12-SP1_Full64`; seeds `20261021, 20261022, 20261023` | PASS; fallback observed in all seeds. Logs and URG under `/tmp/nmaforge_s1s2_clean_c83ad74_noprefetch/`. |
| **R5 `MATRIX-CORE-3S-FA2B`** | Test source-equivalent to candidate `c0832e5`; VCS/URG `V-2023.12-SP1_Full64`; seeds `20261021, 20261022, 20261023` | PASS; 18 Golden + 34 fault/recovery cases per seed. Logs `/tmp/nmaforge_unverified_matrix_core_20261027/run_seed_{20261021,20261022,20261023}.log`; URG in the same directory. |
| **R6 `CNN-KV-RAND-3S`** | Supplemental block run; VCS `V-2023.12-SP1_Full64`; seeds `20261021, 20261022, 20261023` | PASS; `/tmp/nmaforge_unverified_cnn_kv_retry_20261027/run_seed_{20261021,20261022,20261023}.log`. Each seed: 25 Conv + 12 depthwise cases, 27 KV round trips, 0–7 cycle response delay, selected fault/reset recovery. |
| **R7 `SFU-RAND-3S`** | Supplemental block run; VCS `V-2023.12-SP1_Full64`; seeds `20261021, 20261022, 20261023` | PASS for the specified vectors/fault scenarios; `/tmp/nmaforge_unverified_sfu_retry_20261027/run_seed_{20261021,20261022,20261023}.log`. Numeric tolerance clauses remain blocked by SPEC. |
| **R8 `FP-UVM-2S`** | Supplemental block run; VCS/URG `V-2023.12-SP1_Full64`; seeds `20261028, 20261029` | PASS; 596/596 bit-exact transactions per seed. Logs and merged URG under `/tmp/nmaforge_unverified_fp_uvm_20261027/`. |
| **R9 `PARALLEL-UVM-3S`** | Real `ai_parallel_compute_dispatcher`/SPAD MUX with behavioral Engine agents; VCS/URG `V-2023.12-SP1_Full64`; seeds `20261024, 20261025, 20261026` | PASS; all 21 unordered engine pairs and selected ordered dispatch/retirement, same-engine queueing, simultaneous Done, full/resume and abort/reset cases. Logs `/tmp/nmaforge_parallel_compute_uvm_20261025_matrix16/run_{20261024,20261025,20261026}.log`; URG `/tmp/nmaforge_parallel_compute_uvm_20261025_matrix16/urg/`. This is dispatcher verification, not seven-real-engine pairwise top coverage. |
| **R10 `MATRIX-SIZE-9-20261025`** | Matrix core; VCS `V-2023.12-SP1_Full64`; seed `20261025`; array parameters 4/8/16 | PASS 9/9 (three physical array sizes × three square GEMM sizes), K=32, one-cycle bank response. Logs `/tmp/nmaforge_matrix_size_benchmark_final_20261025/array_{4,8,16}/run.log`. |
| **R11 `MATRIX-ABLATION-40-FA2B`** | Matrix core; VCS `V-2023.12-SP1_Full64`; seed `20261026`; 16×16 physical array | PASS 40/40 (8 depth/prefetch/cache configurations × 5 workloads), one-cycle behavioral SPAD. CSV `/tmp/nmaforge_unverified_matrix_compare_20261027/matrix_config_comparison.csv`; config run logs in sibling config directories. |
| **R12 `CLUSTER-S2-TOP-SMOKE-FA2B`** | Top smoke on supplemental source; VCS `V-2023.12-SP1_Full64`; fixed workload seed from the make target | PASS (`TEST PASS`), including mapper precheck and 86-descriptor fixed-weight functional flow. See the command/result entry in [S1/S2 candidate review](COMPUTE_CLUSTER_S1_S2_SIGNOFF_CANDIDATE_2026-10-27.md). One `LOOP-REROLL-ENABLED` fixture warning is retained as a disposition. |
| **R13 `CANDIDATE-CLEAN-REPLAY-LICENSE-RETRY`** | Candidate SHA `c0832e5c822de1a03f82751d5ff8f831d0addb98`; initial VCS license retry on 2026-10-27 | BLOCKED_ENV before compile; the license server could not be contacted, including with bounded `-licwait 1`. This historical attempt was superseded by successful R14 after license recovery; it is neither a test failure nor a PASS. |
| **R14 `CLUSTER-S2-CAND-CLEAN-3S`** | Exact candidate SHA `c0832e5c822de1a03f82751d5ff8f831d0addb98`; clean detached worktree; VCS/URG `V-2023.12-SP1_Full64`; seeds `20261025, 20261026, 20261027` | **PASS**. Real-top production seven-engine UVM and memory scoreboard pass on all seeds; UVM warning/error/fatal `0/0/0`; focused compute covergroup `98.96%`; compile has no warnings/errors or `[TFIPC]`. Logs, reports, checksums and `RUN_MANIFEST.md` are under `/tmp/nmaforge_signoff_clean_c0832e5_20261027/`. |
| **R15 `CLUSTER-AXI-E2E-COV-16S-C0832`** | Exact candidate SHA `c0832e5c822de1a03f82751d5ff8f831d0addb98`; detached candidate worktree, no source changes; VCS/URG `V-2023.12-SP1_Full64`; 16 seeds `20261014,712345,987654,20261015..20261027` | **PASS**. All seeded mixed-precision DDR E2E checks and merged functional bins pass. URG: 20/22 assertions succeed, 0 fail/incomplete; only two UVM RAL properties have no attempts. All three AR/AW/W stall-to-accept covers match; AR/AW/W payload and 4KB-bound assertions have real successes. Artifacts `/tmp/nmaforge_c0832e5_axi_cov_20261028/`. |
| **R16 `CLUSTER-MUT-CAND-25-C0832`** | Exact candidate SHA `c0832e5c822de1a03f82751d5ff8f831d0addb98`; detached candidate worktree, no source changes; VCS `V-2023.12-SP1_Full64`; deterministic seed `20261025` | **PASS 25/25 checker-sensitivity cases**: address/data/owner/WSTRB and done/missing/duplicate Done for all seven engine bits. These mutate the passive monitor observation copy, not DUT signals. Logs `/tmp/nmaforge_c0832e5_mutation_artifacts_20261028/`; build `/tmp/nmaforge_c0832e5_mutation_build_20261028/`. |
| **R17 `MATRIX-SIZE-CAND-3S-C0832`** | Exact candidate SHA `c0832e5c822de1a03f82751d5ff8f831d0addb98`; detached candidate worktree, no source changes; VCS `V-2023.12-SP1_Full64`; seeds `20261025, 20261026, 20261027`; physical arrays 4×4/8×8/16×16 | **PASS 45/45**: three arrays × five GEMM workloads × three seeds. All 15-workload-per-seed run markers and each case checker passed. Logs `/tmp/nmaforge_matrix_size_c0832e5_{20261025,20261026,20261027}/array_{4,8,16}/run.log`. |
| **R18 `MATRIX-ABLATION-CAND-3S-C0832`** | Exact candidate SHA `c0832e5c822de1a03f82751d5ff8f831d0addb98`; detached candidate worktree, no source changes; VCS `V-2023.12-SP1_Full64`; seeds `20261025, 20261026, 20261027`; physical array 16×16 | **PASS 120/120**: eight `Depth(2/4) × Prefetch(OFF/ON) × A-Cache(OFF/ON)` configurations × five workloads × three seeds. CSVs `/tmp/nmaforge_matrix_config_c0832e5_{20261025,20261026,20261027}/matrix_config_comparison.csv`; per-configuration logs under the same roots. |
| **R19 `TINYNPU-COMMON-WORKLOAD-C0832-20261028`** | NMAForge product RTL at candidate `c0832e5c822de1a03f82751d5ff8f831d0addb98`; local benchmark-only TB additions; VCS `V-2023.12-SP1_Full64`; seed `20261028`. TinyNPU pinned source `f965fe9462464fc8c9f944c491c3b81d45af1165`; VCS-only DSP48E1 functional model and `always_ff` compatibility copy under `/tmp`. | **PASS (bounded)**: same INT8/INT32 16×16×16 GEMM inputs on both 8×8 arrays; NMAForge `298` cycles to memory-complete `done`, TinyNPU `1,800` to `done` and `2,056` to final streamed output; all 256 results pass. Matched one-channel 3×3 convolution produces `-30` on both: NMAForge native Conv `66` cycles; TinyNPU padded GEMM lowering `1,800` to `done` / `2,056` to final stream. Not an implementation-level speedup comparison. Logs `/tmp/nmaforge_matrix_tinynpu_match_c0832e5_20261028/run.log`, `/tmp/nmaforge_cnn_tinynpu_match_c0832e5_20261028/run.log`, and `/tmp/nmaforge_tinynpu_match_f965fe9/{run.log,cnn_run.log}`. |

R19 source hashes, exact commands, VCS setup, and raw log checksums are recorded in the [R19 benchmark manifest](COMPUTE_CLUSTER_BENCHMARK_R19_MANIFEST_2026-10-28.md). The benchmark TB additions are local working-tree sources; the candidate SHA identifies the product RTL under test.

R14 reruns the same `ai_compute_cluster_e2e_test` and three seeds as R1 from the exact selected source SHA. R15–R18 extend exact-candidate evidence to the AXI protocol assertions, checker-sensitivity mutations and Matrix performance regressions. R19 adds common functional workloads on the selected NMAForge RTL and a pinned external TinyNPU source using a documented VCS-only primitive surrogate. These supplementary runs qualify only their named checks; none turns every partially covered requirement into a PASS.

R15–R18 artifact checksums and command manifest: `/tmp/nmaforge_compute_cluster_closure_c0832e5_20261028/RUN_MANIFEST.md` (82 raw logs/reports/CSV artifacts). The detached worktree had pre-existing untracked run artifacts, but no tracked source changes; all new build, simulation, coverage, and benchmark output was directed to `/tmp`.

### Exact-candidate clean replay record (R14)

Command, run from the detached clean candidate worktree:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_signoff_clean_c0832e5_20261027 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

The command exited `0` and printed `COMPUTE_CLUSTER_REAL_UVM_REGRESS_PASS`. Each seed reports 4,946 accepted writes, 5,256 checked words, zero mismatches/unknown reads/stale epochs/orphan responses, line WSTRB `{full:512,partial:0,zero:0}`, and drained pending ledgers. The retained UVM summary is `0/0/0`; focused group is 29/30 variables (`98.96%`).

URG assertion evidence: 22 properties, 17 successes, 5 uncovered, zero failures/incomplete; two UVM RAL properties have no attempts. The two AXI AR assertions and AW payload-stability assertion have attempts but no real successes; AW burst-bound and W payload-stability assertions each have three successes. Of the three cover properties, W stall-to-accept matched three times while AR/AW stall-to-accept did not match. URG `groups.txt` and `asserts.txt` are retained; this is a mixed testbench/UVM/DUT report, not DUT-only coverage. The report also confirms that clean replay did not change these vacuity dispositions.

SHA-256 evidence:

| Artifact | SHA-256 |
|---|---|
| `compile.log` | `c26e838d359732f5eb3142d2b836a79b12269d94db1b617c6eb681fddb206685` |
| `seed_20261025/run.log` | `e5c5ce5d398f2d43d96ccd19a4309a70e4a14b0e0957494894b3bffec4dc7c4b` |
| `seed_20261026/run.log` | `6a6f7e9a59cbe5e9a00afbc105d8d7a95b78bca4dce3d56907498ff2501b3c49` |
| `seed_20261027/run.log` | `0746b823cc758bb328990b8efa9d99360b5a7e7106c64265470b5fc15ff256dc` |
| `urg_merged.log` | `f5bf73d908ac407e0e5e2573e408fc57274a58f3ea76952f6522badc67d2aa45` |

## REQ-CL execution matrix

| Requirement | Disposition | Test ID / checker or oracle | Coverage/result | Run ID / seed | Evidence path |
|---|---|---|---|---|---|
| REQ-CL-001 | PASS-SCOPED | `CLUSTER_ALL_ENGINES_PASS`; command monitor + seven-engine owner/result scoreboard | Seven production engines launched; selected legal cases | R1 / `20261025,26,27` | R1 per-seed `run.log` |
| REQ-CL-002 | PARTIAL | `CLUSTER_ALL_ENGINES_PASS`; descriptor opcode decode vs observed engine launch | Representative opcode-to-engine pairs; not every legal opcode/config tuple | R1 / `20261025,26,27` | R1 per-seed `run.log` |
| REQ-CL-003 | PASS-SCOPED | `CLUSTER_LAUNCH_FIELDS_PASS`; passive launch snapshot vs descriptor | Scalar VDOT source/destination/length/flags/aux/strides checked | R1 / `20261025,26,27` | R1 per-seed `run.log`; candidate report §Requirement disposition |
| REQ-CL-004 | PASS-SCOPED | `CLUSTER_LAUNCH_FIELDS_PASS`; independent VDOT Golden + completion checker | VDOT unused-field perturbations preserve output/completion; other engines not swept | R1 / `20261025,26,27` | R1 per-seed `run.log` |
| REQ-CL-005 | PARTIAL | `CLUSTER_PARAMETER_LATCH_PASS`; launch snapshot + destination/memory-image checker | One 64-word scalar VDOT survived in-flight descriptor src/dst mutation; no all-engine/field cross | R1 / `20261025,26,27` | R1 per-seed `run.log` |
| REQ-CL-006 | PARTIAL | `CLUSTER_REQUEST_STABILITY_PASS`; passive valid/ready payload stability monitor | Stalled engine mask `1110111`; stall cycles `{7,4,23,0,261,8,6}`, Matrix banked 338 checks, CNM lanes 30 each; Matrix line stall count 0 | R1 / `20261025,26,27` | R1 per-seed `run.log` |
| REQ-CL-007 | PASS-SCOPED | `CLUSTER_MEMORY_SCOREBOARD` + owner ledger; accepted-read snapshot/response-owner checker | 0 orphan/stale response, ledgers drain; selected Matrix tag 3/CNM tag 5 routing and four CNM lanes | R1 / `20261025,26,27` | R1 per-seed `run.log` |
| REQ-CL-008 | PASS-SCOPED | `CLUSTER_MEMORY_SCOREBOARD`; byte-addressed independent reference SPAD | 5,256 compared words/seed, 0 mismatch/unknown; observed line masks full/partial/zero=`512/0/0` | R1 / `20261025,26,27` | R1 per-seed `run.log` |
| REQ-CL-009 | PASS-SCOPED | `CLUSTER_CNM_OWNER_PASS`; per-lane address/accept/response and CNM Golden | Four lanes `1111`; Matrix/CNM tags and selected A/B parity cross checked | R1 / `20261025,26,27` | R1 per-seed `run.log` |
| REQ-CL-010 | PARTIAL | `MATRIX-S1-DEPTH4-3S`; ordered-read metadata FIFO checker + top line observer | Depth 2/4 regressions pass; partial line WSTRB unobserved; line mask only full writes in R1 | R3,R5 / `20261021,22,23`; R1 / `20261025,26,27` | R3/R5 logs; R1 scoreboard log; `OPEN-CL-004` in SPEC |
| REQ-CL-011 | PASS-SCOPED | `CLUSTER-S2-MUT-25-FA2B`; completion owner/exactly-once ledger | Done, missing-Done and duplicate-Done observations caught for seven engine bits | R1+R2 / `20261025,26,27` | R2 `done_engine_*`, `missing_done_engine_*`, `duplicate_done_engine_*` logs |
| REQ-CL-012 | PASS-SCOPED | `CLUSTER_ALL_ENGINES_PASS`; per-engine result/error/completion Golden checker | Selected result/error/completion payloads checked; not all code values | R1 / `20261025,26,27` | R1 per-seed `run.log` |
| REQ-CL-013 | PASS-SCOPED | `CLUSTER-S2-MUT-25-FA2B`; start/done lifecycle ledger | Exactly-once and missing/duplicate lifecycle checker sensitivity for all engines | R1+R2 / `20261025,26,27` | R2 lifecycle mutation logs |
| REQ-CL-014 | PARTIAL | `CLUSTER_REQUEST_STABILITY_PASS`; accepted-request ledger + bounded progress observation | Request stalls and subsequent progress observed; no complete fairness/bound matrix per requester | R1 / `20261025,26,27` | R1 per-seed `run.log` |
| REQ-CL-015 | PARTIAL | `CLUSTER_ALL_ENGINES_PASS`; independent per-engine Golden models | Representative numeric task for each of seven engines; not every opcode × shape × numeric class | R1 / `20261025,26,27` | R1 per-seed `run.log`; block logs R5–R8 |
| REQ-CL-016 | PASS-SCOPED | `CLUSTER-S2-UVM-3S-FA2B`; owner epoch and stale-response checker | Selected engine switching and reset epoch; zero stale/orphan responses | R1 / `20261025,26,27` | R1 per-seed `run.log` |
| REQ-CL-017 | PARTIAL | `CLUSTER_RANDOM_FAULT_CROSS_PASS` / `CLUSTER_FAULT_CASE_PASS`; prefix memory + error completion checker | 14 parity cases/seed (42 total), selected prefix/sentinel checks; full engine × phase × fault × abort/reset cross remains open | R1 / `20261025,26,27` | R1 per-seed `run.log` |
| REQ-CL-018 | PARTIAL | `CLUSTER_RESET_RECOVERY_PASS`; reset epoch ledger + post-reset Golden/memory checker | Active Matrix/SFU reset drops 2 accepted reads/seed; old completion/writeback absent; fresh task passes; other reset phases/fabric contract open | R1 / `20261025,26,27` | R1 per-seed `run.log`; `OPEN-CL-003` in SPEC |
| REQ-CL-019 | BLOCKED_SPEC | No approved fault-priority oracle | Same-cycle multi-fault ordering and partial-commit semantics cannot be judged | NONE | `docs/spec/COMPUTE_CLUSTER_SPEC_ZH.md`, `OPEN-CL-007` |
| REQ-CL-020 | PARTIAL | `CLUSTER_ALL_ENGINES_PASS` + scalar block Golden; signed INT8 reference | Selected VDOT/GEMM; complete opcode, saturation and boundary combinations are not closed | R1,R5 / R1 seeds; R5 `20261021,22,23` | R1 logs; `/tmp/nmaforge_unverified_matrix_core_20261027/` |
| REQ-CL-021 | PASS-SCOPED | `CLUSTER_CNM_OWNER_PASS`; independent four-bank CNM integer/reference-memory checker | Selected GEMV/VDOT, lane ownership, parity and reduction/writeback | R1 / `20261025,26,27` | R1 per-seed `run.log` |
| REQ-CL-022 | PASS-SCOPED* | `MATRIX-S1-DEPTH4-3S`; independent int64 GEMM Golden + fault-prefix checker | 16×16/cross-tile, batch/layout/fault selected cases pass 3 seeds; *partial Line WSTRB clause remains open* | R3,R4,R5 / `20261021,22,23` | R3/R4/R5 logs and URG; `OPEN-CL-004` |
| REQ-CL-023 | BLOCKED_SPEC | No frozen per-op SFU tolerance/rounding oracle | Selected vectors run, but undefined approximation/error contract is not a pass/fail target | R7 / `20261021,22,23` (selected tests only) | R7 logs; `OPEN-NUM-01/02` in SPEC |
| REQ-CL-024 | PASS-SCOPED | `CNN-KV-RAND-3S`; independent signed 3×3 valid-window oracle + output image checker | 25 Conv + 12 depthwise cases/seed; H/W 3–6, response delay 0–7; larger widths not swept | R6 / `20261021,22,23` | R6 per-seed `run_seed_*.log` |
| REQ-CL-025 | PASS-SCOPED | `CNN-KV-RAND-3S`; 64-bit token/head/stride address oracle + SPAD image | 27 round trips/seed, lengths 1–128, selected offsets/strides; exhaustive stride products and out-of-range overflow remain open | R6 / `20261021,22,23` | R6 per-seed `run_seed_*.log` |
| REQ-CL-026 | PASS-SCOPED | `FP-UVM-2S`; raw-bit independent FP Golden + FP bus scoreboard | 596/596 transactions/seed; BF16/FP16, odd tails, 2 outstanding, selected parity/reset | R8 / `20261028,29` | R8 seed logs and merged URG |
| REQ-CL-027 | PARTIAL | `CLUSTER_FAULT_CASE_PASS`; engine/fault mapping + prefix/write authorization checker | Selected engine-specific errors detected; complete Engine × Fault/error-code table depends on `OPEN-CL-006` | R1,R6,R7 / listed seeds | R1, R6, R7 logs; `OPEN-CL-006` |
| REQ-CL-028 | PARTIAL | `CLUSTER_SERIAL_BENCH_PASS` + Matrix cycle/event benchmarks + matched TinyNPU workloads | Matrix and selected mixed-task cycles reported; R19 adds common INT8 GEMM and lowered CNN cycles. Counters remain specific to named engines/models, not all engines | R1,R10,R11,R17,R18,R19 / listed seeds | R1 logs; R10/R17 arrays; R11/R18 CSVs; R19 logs |

## REQ-PC execution matrix

| Requirement | Disposition | Test ID / checker | Coverage/result | Run ID / seed | Evidence path |
|---|---|---|---|---|---|
| REQ-PC-001 | PASS-SCOPED | `PARALLEL_UVM_ALL_ENGINE_PAIR_PASS`; real dispatcher launch/overlap bitmap | 21/21 unordered pairs × 3 seeds; Engine agents are behavioral in this test | R9 / `20261024,25,26` | R9 run logs, URG `groups.txt` |
| REQ-PC-002 | PASS-SCOPED | `PARALLEL_UVM_FIFO_PASS`; per-engine active-slot and task owner checker | Same-engine queued behind active task while other engine slots run; selected cases | R9 / `20261024,25,26` | R9 run logs |
| REQ-PC-003 | PASS-SCOPED | `PARALLEL_UVM_FIFO_PASS`; CMDQ head/launch ID monitor | Selected dispatch order preserved | R9 / `20261024,25,26` | R9 run logs |
| REQ-PC-004 | PASS-SCOPED | `PARALLEL_UVM_FIFO_PASS`; completion FIFO payload/tail checker | Variable service order, full hold/release, ordered retirement selected cases | R9 / `20261024,25,26` | R9 run logs |
| REQ-PC-005 | PASS-SCOPED | `PARALLEL_UVM_FIFO_PASS`; per-engine simultaneous-Done owner scoreboard | Simultaneous Done and distinct completion records observed | R9 / `20261024,25,26` | R9 run logs |
| REQ-PC-006 | PARTIAL | `CLUSTER_MEMORY_SCOREBOARD` + R15 AXI protocol SVA; accepted requester/owner/ready/error response ledger | Real-top selected owners/stalls and real DMA AR/AW/W protocol stalls pass; not all seven compute requesters × protection/error × backpressure combinations | R1,R15 / listed seeds | R1 logs; `/tmp/nmaforge_c0832e5_axi_cov_20261028/urg_merged/asserts.txt` |
| REQ-PC-007 | PARTIAL | `CLUSTER_CNM_OWNER_PASS`; banked/tag/line handshake monitor | Matrix tag 3, CNM tag 5 and four lanes observed; broad line/banked fault/backpressure cross absent | R1 / `20261025,26,27` | R1 logs; Matrix logs R3/R5 |
| REQ-PC-008 | PASS-SCOPED | `CLUSTER_SHARED_READONLY_PASS`; dual-engine read-only SPAD access + independent Goldens | Scalar VDOT and SFU GELU concurrently read same immutable 64-word input; distinct outputs/completions | R1 / `20261025,26,27` | R1 per-seed `run.log` |
| REQ-PC-009 | PASS-SCOPED | `CLUSTER_ABORT_CROSS_PASS`; dispatch-stop, owner drain and ordered completion checker | Selected active multi-engine abort drains accepted requests and preserves completion order | R1,R9 / listed seeds | R1 logs; R9 run logs |
| REQ-PC-010 | PASS-SCOPED | `CLUSTER_RESET_RECOVERY_PASS`; reset owner epoch + stale response/completion checker | Active Matrix/SFU reset: two accepted reads dropped/seed, no stale/orphan write/completion, post-reset task passes | R1 / `20261025,26,27` | R1 per-seed `run.log` |

## Coverage and assertion disposition

- Focused top functional coverage is 98.96% (29/30 variables). The single raw uncovered `completion` response-client variable is architecturally N/A for the write-only completion writer; DMA response-client traffic was observed in this run. This is a scoped disposition, not a percentage-based sign-off.
- Matrix default prefetch-enabled core FSM is 15/15 states and 49/53 transitions (92.45%). `ST_MAC→ST_A_REQ` is a prefetch-disabled compile profile and is hit in R4; it is not merged into the enabled-profile percentage. `ST_PREFETCH_WAIT→ST_A_REQ` is mutually exclusive with the enabled entry condition. `ST_IDLE→ST_ERROR_DRAIN` and `ST_ERROR→ST_ERROR_DRAIN` have no legal trigger in the reviewed invariants, but no formal unreachable proof exists. They remain review items, not waived bins. The child array remains line/condition/branch `82.35/20.00/58.82%`.
- Exact-candidate R14 compile has no `TFIPC`, `Warning`, or `Error` diagnostic; engine `busy/done` SVA ports are connected. R14 URG counts 22 assertions: 17 success, 5 uncovered, 0 failure/incomplete. Supplemental R15 uses real AXI traffic and reports 20 success, 2 without attempts, 0 failure/incomplete. The two no-attempt properties are UVM RAL checks. All five AXI AR/AW/W payload-stability and 4KB-bound assertions have real successes, and the AR/AW/W stall-to-accept covers match 166/70/107 times. This closes the previously uncovered AXI SVA antecedents for R15 DMA/FP E2E traffic; it does not prove every compute requester × fault/backpressure combination.
- `CLUSTER-S2-TOP-SMOKE-FA2B` retains one `[LOOP-REROLL-ENABLED]` fixture warning; it is not an SVA port warning and is not silently counted as zero-warning.
- Whole-top URG line/condition/FSM/branch/assertion/group figures include DUT, SVA, testbench and UVM. They are not DUT-only coverage. Do not use them as a cluster closure percentage.

## Sign-off interpretation

This RTM supports **CL-RC1 review** and a **bounded CL-RC2 evidence review**. It does not meet CL-DV-v1.0 closure: unresolved P0 spec items `OPEN-CL-003`/`OPEN-CL-006`, 13 partial and 2 blocked requirements, Matrix Line WSTRB, legal fault/reset crosses and incomplete formal reachability evidence remain open. AXI master SVA non-vacuity is now demonstrated by R15. The candidate SHA clean replay plus named supplemental campaigns are complete; see [readiness report](COMPUTE_CLUSTER_DV_SIGNOFF_READINESS_2026-10-27.md) and [open issue list](COMPUTE_CLUSTER_OPEN_ISSUES_2026-10-27.md).
