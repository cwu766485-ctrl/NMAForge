# A10 DV Run – 2026-10-17 refresh

## V2-T-01: CP-owned tile pipeline ownership

**Environment:** Rocky Linux 8.10, VCS V-2023.12-SP1.

**Command:**

```sh
make -C dv/block/command_processor/uvm regress OUT=/tmp/nmaforge_a10_cp_tile_fullregress_20261018 SEEDS='20261018 20261019 20261020' VCS='vcs -licwait 1'
```

**Result:** PASS, 3/3 seeds; each seed passed 31/31 scenarios with UVM warning/error/fatal=`0/0/0`. CP/TILE markers each reported `tiles=3/3/3 events=1`; buffer markers were `load_buf=2/1 compute_buf=2/1 store_buf=2/1`. DMA/compute overlap was 6, 9, and 10 cycles for seeds `20261018`, `20261019`, and `20261020`, respectively. The read-only audit also passed.

**Artifacts:** `/tmp/nmaforge_a10_cp_tile_fullregress_20261018` (regression output).

**Scope and limits:** This validates the SPEC/RTL-defined direct `tile_start` doorbell and the real `ai_command_processor`-owned `ai_tile_pipeline`; it is not a CMDQ descriptor-path test. V2-T-01 does not require an additional CMDQ tile descriptor lifecycle. This evidence is from a dirty worktree, not a frozen-SHA replay. It closes the tile ownership requirement only; V2 and A10 remain OPEN.

See [A10_DV_RTM.md](A10_DV_RTM.md), requirement V2-T-01.

## V4 top integration smoke and seeded replay

**Environment:** Rocky Linux 8.10, Synopsys VCS `V-2023.12-SP1_Full64`; current dirty worktree.

**Commands:**

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke SEED=20261018 AI_RANDOM_CASES=4 AI_SEED=12345
make -C dv/subsystem/top_smoke/sim ai_run SEED=20261018 AI_RANDOM_CASES=20 AI_SEED=12345
```

**Result:** Both commands printed `TEST PASS`. Scope is the directed top smoke plus 20 seeded random cases.

**Artifacts:** `/tmp/nmaforge_a10_top_smoke_seeded_20261018/` (`ai_comp.log`, `ai_accel_smoke.log`, and `ai_run_20_seed12345.log`).

**Scope and limits:** This is current dirty-worktree top integration evidence, not a frozen-SHA replay. It covers only the top directed smoke and seeded-random replay slice; it does not establish full V4/A10 closure. Overall statuses remain open.

## Top DDR mixed-precision E2E replay

**Environment:** Rocky Linux 8.10, Synopsys VCS+UVM `V-2023.12-SP1_Full64`; current dirty worktree.

**Command:**

```sh
make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_regress MIXED_E2E_SEEDS='20261080 20261081 20261082 20261083 20261084 20261085'
```

**Result:** PASS, exit 0. The six seeds cover six descriptor permutations, FP16/BF16 K=1..4, invalid-descriptor checks, first- and last-beat AXI SLVERR, active reset, independent DDR reset, DMA reset, post-reset recovery, watchdog, and abort. All six logs report UVM_WARNING/ERROR/FATAL=`0/0/0`. Compile/link/simulation and target gates passed.

**Artifacts:** `/tmp/nmaforge_a10_top_e2e_6seed_20261018/`.

**Caveat and scope:** The build emitted a nonfatal WSL make clock-skew/future-mtime warning. This is dirty-worktree evidence, not a frozen-SHA replay, and does not close V4, V5, or A10.

See [A10_DV_RTM.md](A10_DV_RTM.md), requirement V4-UVM-01.

## V5-SEED-01: clean replay at pushed SHA `43dbbbc`

An isolated detached worktree at `43dbbbc498377d852667c4e3eb5880ecf4aaf8f7`
replayed FP dot, DMA, Control, DMA–SPAD subsystem, top smoke, and the 20-case
seeded top run under Rocky Linux 8.10 / VCS+URG `V-2023.12-SP1_Full64`. Every
listed suite passed; details, exact commands, coverage/assertion summaries,
artifact paths, and limitations are recorded in
[A10_DV_CLEAN_SHA_REPLAY_43DBBBC.md](A10_DV_CLEAN_SHA_REPLAY_43DBBBC.md).
This closes the fixed-SHA reproducibility check for those committed suites only;
it does not close V1–V5 or overall A10.

## V4-RAND-02: clean-SHA top E2E replay (license interruption recovered)

**Baseline:** detached worktree at `43dbbbc498377d852667c4e3eb5880ecf4aaf8f7`.

**Command:**

```sh
make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_random_cov_regress \
  MIXED_E2E_RANDOM_OUT=/tmp/nmaforge_clean43_v4_random_20261017
```

The initial invocation compiled successfully and passed per-run gates for seeds
`20261101..20261191` (91/91). Seed `20261192` did not complete and the original
Make target stopped before URG. A retry failed before simulation because VCS
could not obtain a license; `SNPSLMD_LICENSE_FILE` and `LM_LICENSE_FILE` were
set, but `lmutil lmstat` returned 241 with an unreachable-server result. This
was an environment/tool interruption, not an RTL/UVM functional failure. This
partial state is historical and has been superseded by the completion below.

After license connectivity recovered (`lmutil lmstat -a` exit 0; VCS feature
status returned), seeds `20261192..20261292` were run using the already compiled
simulator. Each seed used isolated log/VDB paths and the same test/plusargs and
coverage metrics as the Makefile target. The checked-in aggregator then applied
the full per-seed and aggregate gates:

```sh
sim=/tmp/nmaforge_clean43_v4_random_20261017/simv_uvm
out=/tmp/nmaforge_clean43_v4_random_remaining
for seed in $(seq 20261192 20261292); do
  sd="$out/seed_$seed"
  mkdir -p "$sd"
  "$sim" +UVM_TESTNAME=ai_mixed_precision_ddr_e2e_test \
    +MIXED_E2E_SEED=$seed +ntb_random_seed=$seed \
    +MIXED_E2E_AXI_STALLS=1 +MIXED_E2E_AXI_TXN_JITTER=1 \
    -cm line+cond+branch+fsm+assert \
    -cm_dir "$sd/coverage.vdb" -l "$sd/run.log"
done

bash tools/verify_a10_mixed_e2e_shards.sh \
  /tmp/nmaforge_clean43_v4_random_20261017 \
  /tmp/nmaforge_clean43_v4_random_remaining
```

**Result:** all 192 fixed seeds passed the Makefile per-run markers and
zero-severity gates. URG merged the compile-time VDB and all 192 per-seed VDBs;
the E2E covergroup, four per-transaction AXI groups, and all 19 required
functional points reached 100%. URG assertions: 20 successes, 0 failures, 0
incomplete, and 2 UVM RAL internal no-attempts; cover properties matched 3/3.
Aggregate report: `/tmp/nmaforge_clean43_v4_random_20261017/urg_merged/`.
This closes the recorded clean-SHA randomized E2E slice; full V4/V5/A10 closure
remains open for broader system interactions and global coverage disposition.

## DMA AW-stall directed gate and 16-test block regression (run date: 2026-10-17)

**Environment:** Rocky Linux 8.10, Synopsys VCS/URG `V-2023.12-SP1_Full64`; current dirty worktree. The `20261017` seed/artifact tag matches the run date in Asia/Singapore.

**Focused command:**

```sh
make -C dv/block/dma/sim uvm_run UVM_TEST=dma_aw_stall_stability_test SEED=20261017 VCS='vcs -licwait 1'
```

**Focused result:** PASS. Before publishing the four-word store, the test forced AWREADY low. It then checked four full AWVALID stall cycles and stable `{AWID,AWADDR,AWLEN,AWSIZE,AWBURST}` payload, released AWREADY, and observed AW/W/B completion plus four scoreboard-matched words. UVM warning/error/fatal=`0/0/0`.

**Full DMA command:**

```sh
make -C dv/block/dma/sim uvm_regress SEED=20261017 VCS='vcs -licwait 1'
```

**Full DMA result:** PASS, 16/16 Makefile tests. Every test reported scoreboard PASS or expected-abort PASS and UVM warning/error/fatal=`0/0/0`. Merged URG `dma_cmd_cg` is 100%. The assertion report has 14 assertions: 12 successes, zero failures/incomplete, and two UVM RAL `do_read`/`do_write` no-attempts. Instance `tb_ai_axi128_dma_uvm.dma_sva.unnamed$$_1` has six real successes in this merged directed-stall suite. Its source property name is not assigned here because the available evidence does not establish an unambiguous mapping.

**Artifacts:** merged DMA URG `/tmp/nmaforge_a10_dma_16sim_20261017/urg_merged`.

**Scope and limits:** This is a directed AW-payload-stability gate plus bounded DMA block regression, not full DMA/A10 closure. Evidence is from a dirty-worktree snapshot, not a frozen-SHA replay. See [A10_DV_RTM.md](A10_DV_RTM.md) and the [verification matrix](../../dv/VERIFICATION_MATRIX.md).

## V3 DMA–SPAD–CNM 10-seed refresh (run date: 2026-10-17)

**Environment:** Rocky Linux 8.10, Synopsys VCS/URG `V-2023.12-SP1_Full64`; current dirty worktree.

**Command:**

```sh
make -C dv/subsystem/dma_spad/sim subsystem_regress COV_TAG=a10_v3_refresh_20261017_b SEEDS='20261110 20261111 20261112 20261113 20261114 20261115 20261116 20261117 20261118 20261119' URG_REPORT=/tmp/nmaforge_a10_v3_refresh_20261017_b/urg_merged VCS='vcs -licwait 1' URG=urg
```

**Result:** PASS for all ten seeds. Every seed had UVM warning/error/fatal=`0/0/0` and emitted `[SPAD_CNM_DMA_PASS]` and `[DMA_SPAD_ERR_DRAIN_PASS]`; GEMV and parity coverage checks passed. Merged URG `/tmp/nmaforge_a10_v3_refresh_20261017_b/urg_merged` has 13 functional groups at 100%. Of 31 assertions, 28 succeeded with zero failures/incomplete; three had no success: two UVM RAL `do_read`/`do_write` no-attempts and one then-unresolved DUT DMA instance `unnamed$$_1` (119,882 attempts, zero successes, zero failures). The follow-up [AW-stability assertion closure increment](#v3-dma--spad--cnm-aw-payload-assertion-closure-increment-run-date-2026-10-17) resolved this item for its new replay; this historical URG remains unchanged and is not retroactively relabeled.

**Scope and limits:** This initial run is bounded subsystem evidence from a dirty-worktree snapshot, not a frozen-SHA replay. Its then-unresolved DMA assertion was resolved in the follow-up AW-stall increment below and reproduced at frozen SHA `43dbbbc` (see [clean-SHA replay](A10_DV_CLEAN_SHA_REPLAY_43DBBBC.md)). Prolonged/downstream-backpressure fairness, broader fault/abort/reset combinations, residual DUT code coverage, and overall V3/A10 closure remain open.

## V3 DMA–SPAD–CNM AW-payload assertion closure increment (2026-10-17)

**Environment:** Rocky Linux 8.10, Synopsys VCS/URG `V-2023.12-SP1_Full64`; dirty worktree after commit `3414955`.

**Change:** Added explicit labels to the existing DMA SVA properties without changing their conditions. Added a subsystem DMA-store case that holds the responder's AWREADY low for four complete cycles and checks `{AWID, AWADDR, AWLEN, AWSIZE, AWBURST}` remains stable. The backpressure is applied through the responder's clocked configuration, not a testbench `force`; the case runs after the CNM/DMA contention checks so it does not perturb their existing grant assumptions. No product RTL, SPEC, or ABI was changed.

**Commands:**

```sh
make -C dv/subsystem/dma_spad/sim subsystem_compile \
  SIMV=/tmp/nmaforge_a10_v3_aw_stall_subsystem_20261017c/simv_dma_spad \
  COV_DIR=/tmp/nmaforge_a10_v3_aw_stall_subsystem_20261017c/compile.vdb \
  COMPILE_LOG=/tmp/nmaforge_a10_v3_aw_stall_subsystem_20261017c/compile.log \
  VCS='vcs -licwait 1 -Mdir=/tmp/nmaforge_a10_v3_aw_stall_subsystem_20261017c/csrc'
# Run dma_spad_subsystem_test with VCS coverage enabled for seeds
# 20261110 through 20261119; merge compile and ten run VDBs with URG.
make -C dv/subsystem/top_smoke/sim ai_smoke
```

**Result:** Compile PASS; 10/10 subsystem seeds PASS, each with UVM warning/error/fatal=`0/0/0`, `[DMA_AW_STALL_PASS]`, `[SPAD_CNM_DMA_PASS]`, and `[DMA_SPAD_ERR_DRAIN_PASS]`. The new AW stability property recorded 50 real successes and zero failures. Merged URG `/tmp/nmaforge_a10_v3_aw_stall_subsystem_20261017c/urg_merged`: 31 assertions, 29 success, 0 failure/incomplete; the only two without attempts are UVM RAL internal `do_read`/`do_write`. All 13 selected functional groups are 100%. Top `ai_smoke` printed `TEST PASS` and exited 0.

**Debug note:** An initial draft used a virtual-interface force and raced the responder's clocked NBA update; seed `20261111` exposed this as 15 test/protocol errors. Replacing it with the existing responder config hook removed the race. A second draft placed the stall inside the CNM contention window and changed the randomized overlap coverage assumptions; moving the directed stall after contention restored the original test's intent. Neither draft changed the DUT. The final 10-seed result above is from the corrected version.

**Scope and limits:** This closes the previously unmapped subsystem DMA AW-stability assertion slice; it is not V3 signoff. The follow-up [clean-SHA replay at `43dbbbc`](A10_DV_CLEAN_SHA_REPLAY_43DBBBC.md) reproduced this ten-seed test. Long/downstream-backpressure fairness, broader randomized fault×abort×reset combinations, DUT-only residual code coverage, full command/completion lifecycle, and overall V3/A10 closure remain open.

## V1 floating-point dot UVM/URG refresh (run date: 2026-10-17)

**Environment:** Rocky Linux 8.10, Synopsys VCS/URG `V-2023.12-SP1_Full64`; current dirty worktree.

**Run date:** 2026-10-17 (`20261018` in the output directory/seed is a reproducible artifact tag, not wall-clock date; Rocky date was `2026-10-17T21:22:39+08:00`).

**Command:**

```sh
make -C dv/block/compute/fp/sim dot-uvm-regress DOT_RANDOM_COUNT=200 DOT_UVM_SEEDS='712345 987654 20261015' DOT_UVM_OUT_DIR=/tmp/nmaforge_a10_fp_refresh_20261018 VCS='vcs -licwait 1'
```

**Result:** PASS, exit 0 for UVM and URG. Each of the three seed logs reports 484/484 scoreboard checks: 430 numeric checks (215 BF16 + 215 FP16) and 54 fault/reset checks; peak outstanding reads=2; UVM warning/error/fatal=`0/0/0`. Numeric, response-latency, fault-format, odd-tail, and parity-two-outstanding functional groups are each 100%. Merged URG format × length cross is 32/32. Two DUT-facing assertions succeeded with zero failure/incomplete; the two properties without attempts are UVM RAL internals. Both cover properties hit: read-protection-not-write-failure (30) and ready-pair-suppressed-after-error (6). No URG waiver was added.

**Independent model check:** `cd dv/block/compute/fp/model && python3.12 -m unittest -v test_fp_reference.py` passed 19/19. An initial invocation from the repository root failed to import the module; rerunning from the model directory passed.

**Artifacts:** `/tmp/nmaforge_a10_fp_refresh_20261018/urg_report_merged` (`20261018` is the artifact tag, not the run date).

**Scope and limits:** Dirty-worktree evidence, not a frozen-SHA replay; this refresh does not close V1 or A10. The separate 600-second full-domain parity-to-writeback formal run remained non-vacuous and in `checking` until SIGTERM, with no proof or counterexample; that obligation remains open. No URG waiver was used.

See [A10_DV_RTM.md](A10_DV_RTM.md), requirements V1-FP-02, V1-FP-03, and V1-FP-05.

## Control and DMA UVM/URG refresh (run date: 2026-10-17)

**Environment:** Rocky Linux 8.10, Synopsys VCS/URG `V-2023.12-SP1_Full64`; current dirty worktree. The `20261018` identifiers below are reproducible artifact/seed tags, not the wall-clock date.

**Control compile command:**

```sh
make -C dv/block/control/sim uvm_compile SIMV=simv_a10_control_20261018 COV_DIR=/tmp/nmaforge_a10_control_refresh_20261018/control.vdb VCS='vcs -licwait 1'
```

The compiled simulator ran each of these nine tests with seed `20261018`: `control_reset_version_test`, `control_register_file_test`, `control_protocol_test`, `control_channel_backpressure_test`, `control_inflight_reset_test`, `control_irq_error_test`, `control_busy_abort_test`, `control_random_rw_test`, and `control_ral_access_test`. Result: 9/9 completed; each log had UVM warning/error/fatal=`0/0/0`. URG `control_env_pkg::control_coverage::cg` was 100%. Ten assertions: 8 success, 0 failure, 0 incomplete, 2 without attempts; the latter are UVM RAL `do_read`/`do_write` internals. DUT-facing assertions had non-empty successes.

**Control artifacts:** `/tmp/nmaforge_a10_control_refresh_20261018/`.

**DMA run:** Independent simulator, per-test VDBs, and logs were produced for the 15 Makefile tests: `dma_load_ooo_smoke_test`, `dma_2d_load_test`, `dma_gather_load_test`, `dma_store_booo_test`, `dma_2d_store_test`, `dma_narrow_load_test`, `dma_4k_load_test`, `dma_abort_read_test`, `dma_read_slverr_test`, `dma_spad_error_drain_test`, `dma_write_slverr_test`, `dma_abort_write_test`, `dma_config_error_test`, `dma_backpressure_test`, and `dma_random_stress_test`. Result: 15/15; every log had UVM warning/error/fatal=`0/0/0`; every transfer/expected-error recovery checker emitted `[SB_PASS]` or `[SB_ABORT_PASS]`, and random stress was 20/20 `[SB_PASS]`. URG `dma_cmd_cg` was 100%. The assertion report has 14 assertions: 11 success, 0 failure, 0 incomplete, and 3 uncovered. Two no-attempt entries are UVM RAL `do_read`/`do_write`; the remaining DUT property is unnamed `$_1`, with 1,166 attempts and no real success. It is not claimed as passing and is not waived; its identity/disposition remains open.

**DMA artifacts:** `/tmp/nmaforge_a10_dma_refresh_20261018/urg_merged`.

**Scope and limits:** These are bounded dirty-worktree results, not a frozen-SHA replay and not Control/DMA or A10 closure. The DMA SVA residual described above remains open. See [A10_DV_RTM.md](A10_DV_RTM.md).

## Top DDR mixed-precision E2E functional coverage sweep

**Environment:** Rocky Linux 8.10, Synopsys VCS/URG `V-2023.12-SP1_Full64`; current dirty worktree.

**Command:**

```sh
make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress MIXED_E2E_COV_OUT=/tmp/nmaforge_a10_top_e2e_cov_20261018 MIXED_E2E_COV_SEEDS='20261090 20261091 20261092 20261093 20261094 20261095 20261096 20261097 20261098 20261099 20261100 20261101 20261102 20261103 20261104 20261105'
```

**Result:** PASS, exit 0, with target marker `MIXED_E2E_FUNCTIONAL_COVERAGE_PASS` and successful URG merge. Read-only audit confirmed all 16 logs contain `MIXED_E2E_PASS` and `TEST_DONE`; UVM warning/error/fatal counts are `0/0/0` in every log. In merged functional coverage, `e2e_cg` and each of the four per-transaction AXI groups (AR stall, AW stall, R gap, W gap) are 100%. Descriptor order and SPAD layout each hit 6/6; bank 4/4; invalid descriptor 6/6; FP16 K and BF16 K each 4/4; each AXI gap point 4/4; length pairs 16/16; lifecycle, fault, and reset points each 1/1. URG assertion report: 22 properties, 20 successful, zero failure/incomplete, and two without attempts (UVM RAL internal `do_read`/`do_write`); all 3/3 AXI backpressure cover properties matched.

**Artifacts:** `/tmp/nmaforge_a10_top_e2e_cov_20261018/urg_merged`.

**Scope and limits:** Dirty-worktree evidence, not a frozen-SHA replay. This selected top E2E functional-coverage sweep does not establish broad code-coverage closure or close V4, V5, or A10.

See [A10_DV_RTM.md](A10_DV_RTM.md), requirement V4-UVM-01.
