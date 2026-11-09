# NMAForge v2 — Round 21 RTL Front-End Sign-off Review

**Disposition: HOLD**

This review records bounded functional, formal, static-analysis, and synthesis-readiness evidence for the reviewed product source. It is not a full design sign-off, tapeout approval, PPA result, or qualification of the 128 KiB ASIC SRAM implementation.

## 1. Frozen candidate and configuration

- Repository / branch: `cwu766485-ctrl/NMAForge`, target `feature/npu-architecture-v2`. Evidence checkout branch: `codex/round21`.
- Reviewed product RTL SHA: `9fb722447f9f249ce7909451fc893c11ec9c3e58`.
- Checkout tree SHA before the formal-harness-only repair: `77606760f14464cd0ffd86610aa5b3f08466c82f`.
- Product RTL changes in this round: **none**. The only source change is an interface-only declaration of two free dependency-event inputs in `dv/block/command_processor/formal/cp_completion_ownership_formal_top.sv`, required for the current command processor formal harness. It does not constrain those inputs or change DUT behavior. File SHA-256: `b99d697b844a58ccf66fc90cb964c2ada219e0cc3d4d82f67ddab5b0c2cc8a45`.
- Top: `ai_accel_top`; 16×16 Matrix, 256 INT8 MACs; four banks, 128-bit line.
- ABI: v7.4 / ABI-v7; focused opcodes include 0x52 GEMV, 0x53 fused GEMM/requant, 0x43/0x44 KV append/read.
- Capacity profiles: RTL default is 32,768 32-bit words/bank = 512 KiB total. Research override is 8,192 words/bank = 128 KiB total. No default parameter was changed.
- Simulation clock period is 10 ns in the cited Top runs; this is a testbench assumption, not a frequency claim.
- Canonical machine manifest: [`NMAFORGE_V2_SIGNOFF_CONFIG.json`](NMAFORGE_V2_SIGNOFF_CONFIG.json), SHA-256 `a3b0da4d139bb95a3179b8d236da845ec81042dc6799eccafc5ad458bb18d2bb`; root pointer [`signoff_config.json`](../../signoff_config.json).

## 2. Exact-source functional regression

Product RTL SHA is the reviewed `9fb7224…` candidate. Tool versions and individual commands/results/log hashes are in [`run_manifest.csv`](run_manifest.csv); historical RTM records are not represented as clean replays at this SHA.

| Test | Result | Key evidence / limit |
|---|---|---|
| Top Smoke, default 512 KiB | PASS | `R21-TOP-SMOKE-9FB7224-20261109-512K`; selected full-top paths including 0x52/0x53 and reset/protection. Existing `[LOOP-REROLL-ENABLED]` fixture warning remains. |
| Seven-engine Compute Cluster UVM, 3 seeds | PASS-SCOPED | Seeds 20261107/08/09; 21/21 pair overlaps per seed, selected ownership/result/fault checks; does not close the whole RTM. |
| Matrix Core targeted regression | PASS-SCOPED | 18 cases, 35 fault/recovery points; six declared GEMV shape cases pass. |
| H16 incremental KV | PASS-SCOPED | Prefill tokens 0–3 plus real 0x43 append / 0x44 read for tokens 4–7, capacity 8. Four-step decode Golden passes; average 8,847.75 cycles/token. Tokens are host-supplied and the H16 weights are a synthetic projection fixture, not trained language-model weights; this is not autonomous token generation or language-model quality evidence. |
| Trained ten-class CNN | PASS-SCOPED | 396/396 output words checked, 384 correct; held-out accuracy 96.9697%. A model run, not Cluster sign-off. |
| 262,144-MAC two-layer 1×1 CNN, 128 KiB behavioral SPAD | PASS-SCOPED | Legacy, first-layer fused, and both-layer fused Row-Major each pass 20,480/20,480 output Golden words. Workload uses deterministic fixed-seed weights and has no trained-model accuracy claim. |
| Generic Top Smoke, 128 KiB override | FAIL | Simulation reports 23 errors. The smoke includes hardcoded 512 KiB boundary addresses and overlap cases outside the smaller range. Dedicated H16 and CNN 128 KiB runs pass, but generic 128 KiB smoke is not qualified. |
| Mixed AXI stall E2E | PASS-SCOPED | Behavioral in-repository fabric: AR/AW gap 2/3; AR/AW/W stall-to-accept 14/5/12. This run has no coverage DB merged with the Cluster UVM. |

### CNN fixed workload results

All three modes use seed 20261109, the same input/weights/Golden, four banks and 128 KiB behavioral SPAD. The workload is `nma_pointwise_cnn_32x16_16ch_2layer_linear_int8`, 262,144 useful MACs, no host Im2col and no host compute fallback. Golden and memory-image hashes are recorded in each generated workload manifest under the external run directories.

| Mode | Descriptors | CMDQ cycles | Preload cycles | Preload + CMDQ | SPAD read / write bytes | Matrix MAC active cycles | SFU busy | Useful MAC / CMDQ cycle |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Legacy | 4 | 61,310 | 136,415 | 197,725 | 98,304 / 81,920 | 1,024 | 53,252 | 4.2757 |
| First-layer fused | 3 | 35,184 | 136,295 | 171,479 | 65,536 / 49,152 | 1,024 | 26,625 | 7.4507 |
| Both-layer fused, compatible Row-Major output | 2 | 9,050 | 136,175 | 145,225 | 32,768 / 16,384 | 1,024 | 0 | 28.9662 |

The command-only reductions relative to Legacy are 42.61% for first-layer fusion and 85.25% for two-layer fused output; preload+command reductions are 13.27% and 26.55%. The preload interval is a testbench AXI-Lite/SPAD initialization measurement, not a measured external DDR bandwidth endpoint. Array utilization printed by this micro-workload is based on its declared Matrix-active accounting and must not be generalized to a trained CNN.

## 3. Requirement and coverage review

The historic 38-row Execution RTM remains **24 PASS-SCOPED / 14 PARTIAL**. This review adds current-SHA evidence only where named; it does not bulk-replay or promote requirements. Four added v2 rows (`REQ-V2-052`, `REQ-V2-053`, `REQ-V2-KV-APPEND`, `REQ-V2-SFU-FAST`) remain PARTIAL because their full invalid-configuration, abort/reset, backpressure, completion, and stale-response matrices are not closed. See [`signoff_requirement_matrix.csv`](signoff_requirement_matrix.csv).

Three-seed merged Compute Cluster URG: group score 83.94%, line 70.03%, condition 67.85%, FSM 44.23%, branch 66.84%, assertion 72%. Module-definition line/condition/FSM/branch is 68.31/65.98/40.16/65.10%. Selected `cluster_cg` is 100%, but that is one selected group only. Of 22 assertions, 17 have real successes, 5 are uncovered, 0 fail/incomplete, and 2 have no attempts as reported by the coverage database. The AR/AW stall-to-accept covers are unhit in Compute Cluster UVM; the separate mixed E2E run exercises them but cannot be merged as same-run URG evidence. Four Matrix default-profile transition bins remain unhit from raw 49/53. Unhit transitions are not automatically unreachable or waived. Full details are in [`coverage_disposition.csv`](coverage_disposition.csv).

The mutation sensitivity probe changes only a passive scoreboard observation copy and is caught by the `memory_data` checker. It is not an RTL mutant. No waveform was captured.

## 4. Lint, CDC, RDC, Formal

- **Lint: BLOCKED_RESOURCE.** SpyGlass V-2023.12-SP1 process exited 137 during Matrix Core elaboration at module 15/51; no current candidate lint report. Historical 0E/465W/5I is SHA `410b81d` and cannot be applied to this candidate.
- **CDC: REVIEW_REQUIRED.** Current run reports 1 clock / 1 reset, zero unsynchronized crossings and zero convergences. There is one `Reset_sync04` warning involving same-domain reset use in the response-owner/protection request registers; it is not waived. `FLAT_504` remains a documented tool-precision risk, not a current report-proven pass.
- **RDC: BLOCKED_RESOURCE.** 600 s timeout at `Ar_resetcross01`, rule 385/478, roughly 7.6 GB peak RSS; no RDC report was produced. This is not a pass.
- **Matrix FSM Formal: PASS_SCOPED.** VC Formal V-2023.12-SP2: 5 proven, 5 non-vacuous, 2 reachability covers hit at depths 5 and 11.
- **Completion ownership Formal: PASS_SCOPED.** 7 proven, 7 non-vacuous, 3 covers hit, after declaring two free event inputs in the harness.
- **KV Append/Fused Layout Formal and whole-design LEC: NOT_RUN.**

## 5. Synthesis readiness

Design Compiler V-2023.12-SP1 and an authorized local TT 0.9 V RVT library were available; no private foundry file or path is included. The existing generic 4.0 ns script is not a product sign-off SDC. Matrix Core analysis/elaboration/link progressed, but `check_design` reported 259 pre-mapping potential issues; technology mapping did not produce a valid mapped netlist. The first attempt encountered an unsupported operating-condition Tcl query and then a DC internal fatal. A bounded retry removing that query still ended in a DC internal fatal (4m44s, peak 3.32 GB). A separate 16×16 Matrix Array diagnostic reached cleanup but hit the 600 s timeout (peak 2.09 GiB).

Therefore **mapped cell area, WNS/TNS, critical paths, Fmax, power and 128 KiB macro area are unavailable**. The 128 KiB SPAD remains a behavioral RAM configuration in this evidence. No Macro Adapter equivalence is claimed. See [`synthesis_readiness.json`](synthesis_readiness.json).

## 6. Commands and run identity

All runs use product RTL SHA `9fb7224…`. The completion-ownership formal rerun alone uses the documented harness-only port declaration; it leaves those inputs unconstrained. Other product test targets use the unchanged RTL and normal harnesses. Representative exact commands:

```bash
make -C dv/subsystem/top_smoke/sim ai_smoke PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python AI_RANDOM_CASES=4 AI_SEED=20261109 AI_SPAD_WORDS_PER_BANK=32768
make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_round21_cluster_uvm_9fb7224 COMPUTE_CLUSTER_UVM_SEEDS='20261107 20261108 20261109'
make -C dv/subsystem/top_smoke/sim ai_h16_incremental_decode AI_H16_INCREMENTAL_RUN=/tmp/nmaforge_round21_h16_inc_9fb7224 AI_H16_INCREMENTAL_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python AI_H16_INCREMENTAL_SEED=20261109 AI_H16_INCREMENTAL_POLICY=gemm
make -C dv/block/compute/matrix/sim core-random-run CORE_OUT_DIR=/tmp/nmaforge_round21_matrix_core_9fb7224 SEED=20261109
make -C dv/block/compute/matrix/formal fsm-guards OUT=/tmp/nmaforge_round21_matrix_fsm_formal_9fb7224 VCF=<VC-Formal-V-2023.12-SP2>
make -C dv/block/command_processor/formal completion-ownership OUT=/tmp/nmaforge_round21_completion_formal_9fb7224_fix1 VCF=<VC-Formal-V-2023.12-SP2> TIMEOUT=180
make -C dv/subsystem/top_smoke/sim ai_representative_cnn AI_REPRESENTATIVE_SEED=20261109 AI_REPRESENTATIVE_SPAD_WORDS_PER_BANK=8192 AI_REPRESENTATIVE_FUSION_MODE=<legacy|first|fused> AI_REPRESENTATIVE_DESC_COUNT=<4|3|2>
```

Full commands, result labels, tool versions, seeds, external log paths and SHA-256 values are in [`run_manifest.csv`](run_manifest.csv). Model/Golden hashes are in [`model_artifact_manifest.csv`](model_artifact_manifest.csv) and generated model manifests; large VCS databases and logs are intentionally not committed.

## 7. Final decision

**HOLD — not front-end sign-off ready.** The tested product paths show useful bounded functional evidence, including real H16 incremental KV append and compatible fused CNN output. Blocking items remain: current lint report unavailable, RDC incomplete, CDC Reset_sync04 review open, v2 exception-path closure incomplete, generic 128 KiB smoke failing its capacity assumptions, and no valid mapped Matrix Core result. Do not infer ASIC PPA, full DV closure, arbitrary external-fabric reset compliance, autonomous language-model generation, or tapeout readiness.
