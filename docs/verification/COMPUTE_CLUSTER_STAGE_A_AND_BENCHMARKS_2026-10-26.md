# Compute Cluster Stage A Closure and Benchmarks

- **Run date:** 2026-10-26
- **Tested RTL/DV source SHA:** `03bf257afdca9b0041ff80b6d30cbaf8107cf7e0`
- **Replay:** detached clean worktree `/tmp/nmaforge_stageA_clean_03bf257`; clean at completion.
- **Tools:** Synopsys VCS and URG `V-2023.12-SP1_Full64`.
- **Scope:** Stage A DV evidence and the two requested Matrix/Compute Cluster
  benchmarks. This is selected verification closure, not full Cluster signoff.

## Stage A evidence

| Requirement | Testpoint / checker | Coverage and result | Run ID / evidence | Status |
|---|---|---|---|---|
| DMA response-client bin | Real-top DMA SPAD-to-DDR store; verify client-4 read responses and four DDR words | One observed DMA response-client hit per seed; all four DDR words matched | `CC-STAGEA-UVM-3S`; `/tmp/nmaforge_stageA_clean_03bf257_uvm/seed_{20261025,20261026,20261027}/run.log` | **PASS** |
| Completion response-client bin | Review completion writer traffic and arbiter response behavior | Zero completion read responses is expected: `ai_completion_writer` only issues SPAD writes, so it cannot generate a read-response client event | Same UVM logs, marker `[CLUSTER_RESPONSE_CLIENT_DISPOSITION]` | **WAIVED / N/A**; no synthetic hit added |
| Accepted SPAD memory image, owner, response and reset epoch | Byte-addressed scoreboard snapshots accepted reads, checks returned data and response client, attributes accepted engine requests, applies WSTRB and drains reset epochs | Per seed: 4,444 writes, 4,852 compared words, 0 mismatches, 0 unknown reads, 0 stale-epoch responses; line masks full/partial/zero=`512/0/0`; all four banks and all seven engines had read/write activity. Engine vectors are bit 0 INT8, 1 FP, 2 CNM, 3 Matrix, 4 SFU, 5 Conv, 6 KV. | `CC-STAGEA-UVM-3S`; same per-seed logs, marker `[CLUSTER_MEMORY_SCOREBOARD]` | **PASS (observed traffic classes)**; partial-WSTRB and full REQ image closure remain open |
| Checker sensitivity for address, data, response owner, WSTRB and engine-done lifecycle | Five observation-only mutations alter the monitor's copied transaction; RTL, driver and memory are untouched | All five injected mutations were caught by the expected memory-data, Matrix write-mask or engine lifecycle checker | `CC-STAGEA-MUT-5`; `/tmp/nmaforge_stageA_clean_03bf257_mutations/{address,data,owner,wstrb,done}.log` | **PASS (5/5 checker-sensitivity cases)**; this is not an RTL mutation score |
| Random parity × engine × operand phase | Real-top 14-case seed-shuffled parity sequence | Each seed 14/14; aggregate 42/42 across INT8, Matrix, CNM and BF16, A/B operand phases, and all four CNM lanes | `CC-STAGEA-UVM-3S`; marker `[CLUSTER_RANDOM_FAULT_CROSS_PASS]` | **PASS (selected parity cross)**; the full protection × phase × engine × Abort/Reset cross remains open |
| Matrix core FSM transitions | Three-seed depth-4 core regression plus a separate 4×4 prefetch handoff; URG merges these same-source coverage databases | `state_r`: 15/15 states and 49/53 transitions; prefetch FSM: 9/9 transitions. The four remaining `state_r` misses are reviewed below. | `MATRIX-STAGEA-FSM`; `/tmp/nmaforge_stageA_clean_03bf257_matrix_{recovery,handoff4}/`; merged URG `/tmp/nmaforge_stageA_clean_03bf257_matrix_combined_urg/` | **PARTIAL**; residual misses are dispositioned, not waived unreachable |
| Matrix no-prefetch fallback | Fixed-seed 4×4×32 through 32×32×64 Golden workload, `NEXT_K_PREFETCH_ENABLE=0` | URG dynamically records `ST_MAC→ST_A_REQ`; this compile-time profile is kept separate from the prefetch-enabled aggregate | `MATRIX-STAGEA-NOPREF`; `/tmp/nmaforge_stageA_clean_03bf257_matrix_noprefetch/benchmark.log`, `urg_html/mod0.html` | **PASS (transition exercised)** |
| VCS compile warning `[TFIPC]` | Connect the real per-engine `engine_busy` / `engine_done` signals to the protocol SVA inputs; compile the real-top UVM | Clean top UVM compile reports 0 errors and 0 warnings; runtime UVM warning/error/fatal=`0/0/0` for all three seeds | `CC-STAGEA-UVM-3S`; `/tmp/nmaforge_stageA_clean_03bf257_uvm/compile.log` and per-seed `run.log` | **PASS** |

Each seed's scoreboard counters are identical: bank hits `{1223,1215,1211,1211}`;
engine read hits `{5,6,576,826,331,18,8}`; engine write hits
`{1,1,64,512,329,1,8}`. The engine vectors use the bit ordering documented in
the scoreboard row above.

### Matrix FSM miss review

The exact-SHA depth-4 profile reports four uncovered transitions. The separate
4×4 handoff run covers `ST_MAC→ST_PREP_MAC`; the separately compiled no-prefetch
profile covers `ST_MAC→ST_A_REQ`. Those profile-specific results are not merged
into the depth-4 prefetch-enabled percentage.

**R111 exact-clean follow-up at code/test SHA `95864f7027ccbec22a09b0a61832c68d3ca08098`:** VC Formal `V-2023.12-SP2` non-vacuously proves all five guard/invariant assertions and reaches both state covers (`ST_PREFETCH_WAIT` depth 11, `ST_ERROR_DRAIN` depth 5). This updates the original Stage A review below: its “no formal proof” statements describe the evidence available at SHA `03bf257`, not the current disposition. The three default-profile guard edges are now formally dispositioned under the assumptions in the [R111 report](COMPUTE_CLUSTER_MATRIX_FSM_R111_FORMAL_2026-10-30.md). The separately compiled no-prefetch profile still supplies the legal `ST_MAC→ST_A_REQ` transition. Raw enabled-profile coverage remains 49/53; there is no full-FSM closure claim.

| Uncovered transition in the original prefetch-enabled aggregate | Original Stage A review at `03bf257` |
|---|---|
| `ST_ERROR→ST_ERROR_DRAIN` | At the original run no formal proof was available. R111 later proves `ap_error_does_not_reenter_error_drain` non-vacuously under the documented legal model. |
| `ST_IDLE→ST_ERROR_DRAIN` | At the original run no formal proof was available. R111 later proves `ap_idle_does_not_enter_error_drain` non-vacuously under the documented legal model. |
| `ST_MAC→ST_A_REQ` | Legal fallback when prefetch is disabled; it is dynamically covered in the separate prefetch-disabled run. |
| `ST_PREFETCH_WAIT→ST_A_REQ` | At the original run no formal proof was available. R111 later proves `ap_prefetch_wait_does_not_fall_back_to_a_req` non-vacuously with prefetch enabled. |

The raw FSM percentage is a review aid, not a sign-off criterion. R111
dispositions the three default-profile guard edges within its bounded legal
model; `ST_MAC→ST_A_REQ` remains profile-specific and is exercised only in the
separate no-prefetch build. The four raw misses remain absent from the enabled
profile, so the 49/53 coverage result is retained.

## Benchmark 1: Matrix architecture ablation

Command:

```sh
make -C dv/block/compute/matrix/sim matrix-config-comparison \
  SEED=20261026 \
  MATRIX_CONFIG_OUT=/tmp/nmaforge_stageA_clean_03bf257_matrix8
```

All eight combinations ran all five workloads (40/40 PASS) at seed `20261026`,
with a fixed 16×16 physical array and one-cycle behavioral bank response. Cells
show `cycles / bank reads`; the columns are outstanding depth / next-K prefetch /
A-tile cache.

| Workload | d2/p0/c0 | d2/p0/c1 | d2/p1/c0 | d2/p1/c1 | d4/p0/c0 | d4/p0/c1 | d4/p1/c0 | d4/p1/c1 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 4×4×32 | 99/16 | 99/16 | 76/16 | 76/16 | 99/16 | 99/16 | 76/16 | 76/16 |
| 8×8×32 | 135/32 | 135/32 | 116/32 | 116/32 | 135/32 | 135/32 | 116/32 | 116/32 |
| 16×16×32 | 265/64 | 265/64 | 248/64 | 248/64 | 242/64 | 242/64 | 233/64 | 233/64 |
| 16×32×32 | 504/128 | 445/96 | 483/128 | 424/96 | 486/128 | 442/96 | 469/128 | 417/96 |
| 32×32×64 | 1698/512 | 1471/384 | 1555/512 | 1294/384 | 1636/512 | 1411/384 | 1443/512 | 1187/384 |

Comparing baseline `d2/p0/c0` with `d4/p1/c1`, cycles changed `99→76`,
`135→116`, `265→233`, `504→417`, and `1698→1187`; the two larger workloads
also reduced reads `128→96` and `512→384`. The cache had no read reduction for
the small shapes with no reusable A tile. These are behavioral cycle/read
measurements, not SRAM timing, ASIC PPA, or silicon throughput.

CSV and per-configuration logs are under
`/tmp/nmaforge_stageA_clean_03bf257_matrix8/`.

## Benchmark 2: Compute Cluster concurrency and recovery

The three top-UVM seeds use the same descriptors and deterministic engine
service model. Each interval is measured from the doorbell write through the
observed CPLQ tail update; descriptor programming is excluded, while AXI-Lite
issue/poll cycles are included. These are cycle-model comparisons, not
wall-clock timing.

| Mode | Workload | Cycles | Result |
|---|---|---:|---|
| Serial | Matrix → CNM → SFU | `565+217+457=1239` | Baseline; CPL order 0700,0701,0702 |
| Staged parallel | Matrix and CNM overlap, then dependent SFU | `613+457=1070` | 1.158× vs serial; 32 shared-admission contention cycles; order preserved |
| Four-task queued | Matrix, CNM, SFU, SFU submitted as one queue batch; same-engine SFU work remains serialized | `1696→1137` | 1.492× vs sequential execution; completion IDs 0600–0603 in order; 38 shared-SPAD contention cycles |
| Active reset recovery | Reset during active Matrix/SFU work, then submit recovery SFU | 307 cycles to recovery completion | Scoreboard drops 2 accepted reads from the reset epoch; 0 stale responses |

Real CNM+DMA contention was additionally exercised at the DMA–SPAD subsystem
with three seeds. Each primary overlap interval granted CNM/DMA `7/4` requests,
with four stalls and a maximum stall streak of one; SLVERR cases drained all
four accepted DMA reads and immediately recovered. This is pairwise CNM/DMA
arbiter evidence. The exact Matrix+CNM+DMA top contention row is **BLOCKED by
the current legal control path**: `ai_accel_regs` only asserts `dma_start` when
`!processor_busy && !dma_busy`. No internal signal was forced and no product RTL
was changed to bypass that gate.

The depth-4 Matrix fault/recovery suite also passed 18 cases and 25 fault
profiles per seed for seeds `20261021/20261022/20261023`, including outstanding
Abort, outstanding parity, prefetch parity/Abort/watchdog, reset, and recovery.
The top and Matrix results complement each other; they do not establish a full
Cluster fault × phase × engine signoff cross.

## Run index and disposition

| Run ID | Command / log root | Result |
|---|---|---|
| `CC-STAGEA-UVM-3S` | `make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_stageA_clean_03bf257_uvm` | Three seeds PASS; focused functional covergroup 99.0%; UVM severity 0/0/0 |
| `CC-STAGEA-MUT-5` | `make -C dv/uvm/sim uvm_compute_cluster_mutation COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_stageA_clean_03bf257_mut_compile COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_stageA_clean_03bf257_mutations` | Address/data/owner/WSTRB/done checker mutations 5/5 caught |
| `MATRIX-STAGEA-8CFG` | Matrix configuration comparison command above | 40/40 configurations/workloads PASS |
| `MATRIX-STAGEA-DEPTH4` | `make -C dv/block/compute/matrix/sim core-random-regress OUTSTANDING_DEPTH=4 SEEDS='20261021 20261022 20261023' CORE_OUT_DIR=/tmp/nmaforge_stageA_clean_03bf257_matrix_recovery` | Three seeds PASS; URG generated from the VDB |
| `MATRIX-STAGEA-HANDOFF4` | `make -C dv/block/compute/matrix/sim core-prefetch-handoff-regress OUTSTANDING_DEPTH=4 PHYSICAL_ARRAY_SIZE=4 SEEDS='20261021 20261022 20261023' CORE_OUT_DIR=/tmp/nmaforge_stageA_clean_03bf257_matrix_handoff4` | Three seeds PASS; separate 4×4 compile profile |
| `DMA-CNM-STAGEA-3S` | `dv/subsystem/dma_spad/sim`, VCS image `/tmp/nmaforge_stageA_clean_03bf257_dma_cnm/simv`; per seed `+UVM_TESTNAME=dma_spad_subsystem_test +ntb_random_seed=<seed> -cm line+cond+fsm+tgl+branch+assert` | Three seeds PASS; UVM severity 0/0/0 |

## Reproduction commands

Run the following from the tested source SHA. All generated files stay under
`/tmp`.

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_stageA_clean_03bf257_uvm

make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_stageA_clean_03bf257_mut_compile \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_stageA_clean_03bf257_mutations

make -C dv/block/compute/matrix/sim matrix-config-comparison \
  SEED=20261026 \
  MATRIX_CONFIG_OUT=/tmp/nmaforge_stageA_clean_03bf257_matrix8

make -C dv/block/compute/matrix/sim core-random-regress \
  OUTSTANDING_DEPTH=4 SEEDS='20261021 20261022 20261023' \
  CORE_OUT_DIR=/tmp/nmaforge_stageA_clean_03bf257_matrix_recovery

make -C dv/block/compute/matrix/sim core-prefetch-handoff-regress \
  OUTSTANDING_DEPTH=4 PHYSICAL_ARRAY_SIZE=4 \
  SEEDS='20261021 20261022 20261023' \
  CORE_OUT_DIR=/tmp/nmaforge_stageA_clean_03bf257_matrix_handoff4

/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg \
  -dir /tmp/nmaforge_stageA_clean_03bf257_matrix_recovery/coverage.vdb \
  -dir /tmp/nmaforge_stageA_clean_03bf257_matrix_handoff4/coverage.vdb \
  -report /tmp/nmaforge_stageA_clean_03bf257_matrix_combined_urg

make -C dv/block/compute/matrix/sim core-random-compile \
  OUTSTANDING_DEPTH=4 NEXT_K_PREFETCH_ENABLE=0 \
  CORE_OUT_DIR=/tmp/nmaforge_stageA_clean_03bf257_matrix_noprefetch
/tmp/nmaforge_stageA_clean_03bf257_matrix_noprefetch/simv \
  +SEED=20261026 +MATRIX_BENCHMARK_ONLY \
  -cm line+cond+fsm+branch \
  -cm_dir /tmp/nmaforge_stageA_clean_03bf257_matrix_noprefetch/coverage.vdb \
  -cm_name matrix_no_prefetch_20261026 \
  -l /tmp/nmaforge_stageA_clean_03bf257_matrix_noprefetch/benchmark.log
/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg \
  -dir /tmp/nmaforge_stageA_clean_03bf257_matrix_noprefetch/coverage.vdb \
  -report /tmp/nmaforge_stageA_clean_03bf257_matrix_noprefetch/urg_html

make -C dv/subsystem/dma_spad/sim subsystem_compile \
  VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1 -Mdir=/tmp/nmaforge_stageA_clean_03bf257_dma_cnm/csrc' \
  SIMV=/tmp/nmaforge_stageA_clean_03bf257_dma_cnm/simv \
  COV_DIR=/tmp/nmaforge_stageA_clean_03bf257_dma_cnm/seed_20261025.vdb \
  COMPILE_LOG=/tmp/nmaforge_stageA_clean_03bf257_dma_cnm/compile.log
cd dv/subsystem/dma_spad/sim
for seed in 20261025 20261026 20261027; do
  /tmp/nmaforge_stageA_clean_03bf257_dma_cnm/simv \
    +UVM_TESTNAME=dma_spad_subsystem_test +ntb_random_seed=$seed \
    +UVM_VERBOSITY=UVM_MEDIUM \
    -cm line+cond+fsm+tgl+branch+assert \
    -cm_dir /tmp/nmaforge_stageA_clean_03bf257_dma_cnm/seed_${seed}.vdb \
    -l /tmp/nmaforge_stageA_clean_03bf257_dma_cnm/seed_${seed}.log
done
```

## Remaining Stage A limits

- The completion response-client event is architecturally N/A for the current
  write-only completion writer; its functional bin is explicitly waived.
- The observed line-write mask mix is full-only (`512/0/0`). Partial WSTRB,
  full opcode/configuration memory-image coverage, and all C1 REQs remain open.
- The fault campaign closes a selected parity cross, not every protection,
  fault-phase, outstanding, Abort, and Reset combination.
- Four Matrix FSM transitions remain absent in the combined prefetch-enabled
  profile. R111 formally dispositions the three guard-incompatible edges under
  stated assumptions; the legal `ST_MAC→ST_A_REQ` fallback is exercised in a
  separate no-prefetch build. The profile databases are not merged, and raw FSM
  coverage remains 49/53.
- Matrix+CNM+DMA simultaneous top contention is blocked by the documented
  `DMA_CTRL` busy gate; pairwise CNM+DMA contention is covered.
- ASIC area/Fmax/power and pretrained-model accuracy are not measured here.
  The merged top code-coverage report contains DUT, SVA, testbench and UVM, and
  must not be presented as DUT-only coverage.
