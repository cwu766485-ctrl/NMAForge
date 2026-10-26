# Compute Cluster clean-SHA replay and mutation evidence

- **Run date:** 2026-10-26
- **Tested source SHA:** `827c0052cf589fde676e93e34bf459188956182f`
- **Tool:** Synopsys VCS / URG `V-2023.12-SP1_Full64`
- **Replay checkout:** detached worktree `/tmp/nmaforge_clean_cluster_replay_827c005`
- **Scope:** selected Compute Cluster closeout slice; this is not full C1 or product signoff.

The replay checkout was created at the exact tested SHA. The seven-engine UVM,
Matrix configuration comparison, Transformer, smoke, and seeded top regressions
all completed there. `git status --short` was empty at completion. A temporary
scratchpad data mutation was applied and reverted only in this detached worktree;
its final `rtl/memory/ai_scratchpad.v` SHA256 matches the committed source
(`ae5d0d2339e8fd8e2017a3106607d60e1cb3af17f23690b54be44f4ad72d8822`).
The existing VCS compile warning `Warning-[TFIPC]` about omitted optional top
protocol-SVA inputs remains; the UVM runtime warning/error/fatal counts are all
zero.

## Requirement → Testpoint → Coverage → Run ID → Result

| Requirement | Testpoint / checker | Coverage and observed result | Run ID / artifacts | Result |
|---|---|---|---|---|
| C1-FAULT-001: selected engine/operand/lane parity cross | Real-top `ai_compute_cluster_e2e_test`; 14 seed-shuffled fault cases, expected completion and 16-word no-writeback sentinel | Seeds 20261025/26/27 each hit 14/14 cases; aggregate 42/42. INT8, Matrix, CNM, BF16; A/B; CNM lanes 0–3. This is a parity subset, not the full protection × engine × phase or multi-fault cross. | `CC-CLEAN-827C005-UVM3S`; `/tmp/nmaforge_clean_sha_827c005_cluster_uvm/seed_{20261025,20261026,20261027}/run.log` | **PASS (selected cross)** |
| C1-MEM-001: scratchpad read/write image and response ownership | Byte-addressed reference memory in `ai_compute_cluster_scoreboard`; accepted-read snapshot, client/lane comparison, reset drain | Per seed: 3,584 writes, 3,536 compared words, 0 mismatches, 0 unknown reads, 0 orphan responses; pending queues drain. UVM warning/error/fatal=`0/0/0`. | `CC-CLEAN-827C005-UVM3S`; same per-seed logs; merged URG `/tmp/nmaforge_clean_sha_827c005_cluster_uvm/urg_merged` | **PASS (observed access classes)**; line/partial-WSTRB and all REQ image cases remain open |
| C1-MUTATION-001: checker sensitivity to scratchpad read-data corruption | Temporary bank 0 registered read-data bit-0 inversion in `ai_scratchpad.v`; run the real-top UVM test, restore the file, then replay the same seed | Mutant run produced 192 `[CLUSTER_MEMORY_MISMATCH]` UVM errors and a standalone Matrix Golden fatal. Restored baseline run passed with 0 UVM errors/fatals and 0 memory mismatches/unknown reads. No RTL mutation remains in the worktree. Simulator exit status alone is not used as the mutant verdict because UVM `$finish` returns status 0. | `CC-MUTATION-827C005-SEED20261025`; compile `/tmp/nmaforge_cluster_mutation_827c005/compile.log`; mutant `/tmp/nmaforge_cluster_mutation_827c005/seed_20261025/mutant.log`; restored `/tmp/nmaforge_cluster_mutation_827c005/seed_20261025/restored.log` | **PASS (one targeted sensitivity mutation)**; broader mutation campaign remains open |
| MATRIX-FSM-001: prefetch-disabled fallback transition | Matrix Golden benchmark with `NEXT_K_PREFETCH_ENABLE=0` | The `ST_MAC→ST_A_REQ` fallback is dynamically exercised. This compile-time profile has a different condition shape from the prefetch-enabled profile, so its VDB is kept separate and no merged coverage percentage is claimed. | `MATRIX-NOPREF-CLEAN-827C005`; `/tmp/nmaforge_clean_sha_827c005_matrix_noprefetch/benchmark.log` and `coverage.vdb` | **PASS (transition exercised)** |
| MATRIX-BENCH-001: compare all outstanding/prefetch/cache configurations | `matrix-config-comparison`, fixed seed/workloads, 16×16 physical array, one-cycle behavioral bank response | All 8 configurations pass across five workloads. From depth-2/no-prefetch/no-cache to depth-4/prefetch/cache, cycles: 4×4×32 `99→76`; 8×8×32 `135→116`; 16×16×32 `265→233`; 16×32×32 `504→417` (reads `128→96`); 32×32×64 `1698→1187` (reads `512→384`). These are behavioral cycle/read results, not SRAM timing or PPA. | `MATRIX-8CFG-CLEAN-827C005`; `/tmp/nmaforge_clean_sha_827c005_matrix8/matrix_config_comparison.csv` and each configuration's `run.log` | **PASS (cycle benchmark)** |
| TRANSFORMER-FUNC-001: fixed-weight prefill/decode datapath | Real top `ai_transformer`, generated 86-descriptor workload and software Golden | 86 descriptors, 60 tensors; fixed hand-authored INT8 weights; log ends `TEST PASS`. This does not use a pretrained checkpoint and makes no model-accuracy claim. | `TRANSFORMER-CLEAN-827C005`; `/tmp/nmaforge_clean_sha_827c005_top/ai_transformer.log` | **PASS (fixed-weight function)**; pretrained accuracy **NOT_RUN** |
| TOP-SMOKE-001: integration smoke | `ai_smoke` on the fixed-SHA checkout | Log ends `TEST PASS`; includes the 86-descriptor Transformer sequence and 4 random cases. | `SMOKE-CLEAN-827C005`; `/tmp/nmaforge_clean_sha_827c005_top/ai_smoke.log` | **PASS** |
| TOP-RANDOM-001: seeded integration regression | `ai_run AI_RANDOM_CASES=20 AI_SEED=12345` | Log ends `TEST PASS`; 20 seeded random cases. | `TOP-RANDOM-CLEAN-827C005`; `/tmp/nmaforge_clean_sha_827c005_top/ai_run_20_seed12345.log` | **PASS** |

## Reproduction commands

Run these from `/tmp/nmaforge_clean_cluster_replay_827c005`; the top smoke
commands run after changing into `dv/subsystem/top_smoke/sim`.

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_clean_sha_827c005_cluster_uvm

make -C dv/block/compute/matrix/sim matrix-config-comparison \
  SEED=20261026 \
  MATRIX_CONFIG_OUT=/tmp/nmaforge_clean_sha_827c005_matrix8

make -C dv/block/compute/matrix/sim core-random-compile \
  CORE_OUT_DIR=/tmp/nmaforge_clean_sha_827c005_matrix_noprefetch \
  NEXT_K_PREFETCH_ENABLE=0
/tmp/nmaforge_clean_sha_827c005_matrix_noprefetch/simv +SEED=20261026 \
  +MATRIX_BENCHMARK_ONLY -cm line+cond+fsm+branch \
  -cm_dir /tmp/nmaforge_clean_sha_827c005_matrix_noprefetch/coverage.vdb \
  -cm_name clean_no_prefetch_827c005 \
  -l /tmp/nmaforge_clean_sha_827c005_matrix_noprefetch/benchmark.log

cd dv/subsystem/top_smoke/sim
make ai_transformer AI_SEED=20261026
make ai_smoke AI_SEED=20261026
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

The mutation was a temporary one-line test-only source perturbation, compiled
with the same UVM file list and VCS version. The mutant was not committed:

```systemverilog
banked_data0 <= banked_data0_pipe ^ 32'd1;
```

The original assignment was restored before the baseline replay. This single
mutation establishes sensitivity of the reference-memory / Golden checkers to
this data corruption. It does not estimate mutation score across a defined
operator set and does not close a broader mutation campaign. Reproduction uses
the clean replay checkout after applying the one-line mutation above:

```sh
make -C dv/uvm/sim uvm_compute_cluster_compile \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_cluster_mutation_827c005

mkdir -p /tmp/nmaforge_cluster_mutation_827c005/seed_20261025
/tmp/nmaforge_cluster_mutation_827c005/simv_uvm \
  +UVM_TESTNAME=ai_compute_cluster_e2e_test \
  +COMPUTE_CLUSTER_SEED=20261025 +ntb_random_seed=20261025 \
  -cm line+cond+branch+fsm+assert \
  -cm_dir /tmp/nmaforge_cluster_mutation_827c005/seed_20261025/coverage.vdb \
  -l /tmp/nmaforge_cluster_mutation_827c005/seed_20261025/mutant.log
```

## Coverage review and remaining closure

- The focused Cluster functional covergroup remains 97.92%; URG identifies
  `cp_response_client.dma` and `.completion` as unhit because the selected
  sequence does not issue those response-client transactions.
- The merged top code-coverage dashboard mixes DUT, assertions, testbench and
  UVM. It is not a DUT-only closure number.
- Matrix prefetch-enabled core raw coverage remains 49/53 FSM transitions
  (15/15 states; prefetch FSM 9/9). The four misses are:

  | Transition | Review disposition |
  |---|---|
  | `ST_ERROR→ST_ERROR_DRAIN` | Abort/watchdog guards exclude `ST_ERROR`; not reached by the legal sequence. No formal unreachable proof. |
  | `ST_IDLE→ST_ERROR_DRAIN` | Drain requires `busy`, while IDLE is specified/observed with `busy=0`. No formal unreachable proof. |
  | `ST_MAC→ST_A_REQ` | Not hit with prefetch enabled; dynamically hit in a separate prefetch-disabled Golden run. |
  | `ST_PREFETCH_WAIT→ST_A_REQ` | Requires prefetch disabled, but reaching `ST_PREFETCH_WAIT` requires it enabled; no runtime setting takes both. No formal unreachable proof. |

  `ST_MAC→ST_PREP_MAC` is hit by the 4×4 array handoff. Array child raw
  coverage remains partial at line/condition/branch=`82.35/20.00/58.82%`.
  The prefetch-off VDB has a different compile-time condition shape, so it is
  kept separate; no formal unreachable waiver or cross-profile percentage is
  claimed.
- Full protection/fault-phase cross, Matrix line/partial-WSTRB image checking,
  every REQ-CL/REQ-PC obligation, broader mutation campaign, ASIC PPA and
  pretrained-model accuracy remain open. The verified clean-SHA slice is
  reproducible but is not full Cluster signoff.

The tested RTL/DV source is SHA `827c0052cf589fde676e93e34bf459188956182f`.
This report and links added to status documents are documentation-only changes
made after replay; they do not alter the tested source tree.
