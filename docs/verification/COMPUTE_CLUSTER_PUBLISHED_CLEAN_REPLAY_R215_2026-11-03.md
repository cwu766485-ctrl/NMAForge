# Compute Cluster Published-Candidate Clean Replay — R215

## Identity and disposition

- Run ID: `CL-R215-PUBLISHED-CLEAN-20261103`
- Published clean candidate: `eb27e716fc40c6e526e479e2472837b165675a97`
- Candidate tree: `35fe4b2b00c44e17e77dce2651de103ab00eec75`
- Branch: `feat/compute-cluster-closeout-audit`
- Tools: Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`; VC Formal `V-2023.12-SP2`
- RTL, UVM, SPEC and ABI were not modified for this replay.
- Result: all named runs below pass on the exact published clean source. This is repeatability and declared-testpoint evidence, not closure of the 38-row RTM. Disposition remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.

## Executed tests and evidence

| Scope / requirement evidence | Test and checker | Coverage / result | Run ID, seeds | Evidence |
|---|---|---|---|---|
| Seven-engine top workloads; `REQ-CL-002/005/006/014/015/017/019/020/027`, `REQ-PC-006/007` | `uvm_compute_cluster_regress`; real CMDQ, `CLUSTER_MEMORY_SCOREBOARD`, response-owner ledger, completion/order/error checkers | 3/3 seeds pass; all seven production engines; engine-pair overlap 21/21; max active engines 7; 2,694 shared-request backpressure cycles; zero scoreboard/owner mismatch and UVM severity 0/0/0 per seed | `CL-R215-COMPUTE-UVM-3S`; `20261025/26/27` | `/tmp/nmaforge_r215_uvm_3seed_20261103/seed_*/run.log` |
| Mixed precision, AXI, DMA/reset; `REQ-CL-018/019/027`, `REQ-PC-006/007/010` | `uvm_mixed_precision_ddr_e2e_cov_regress`; independent numerical/memory scoreboard, reset-epoch, AXI protocol and completion checkers | 16/16 seeds pass; configured AR/AW/R/W stalls, DMA error positions, active reset/recovery and AXI response checks; severity 0/0/0 | `CL-R215-MIXED-E2E-16S`; `20261014`, `712345`, `987654`, `20261015..20261027` | `/tmp/nmaforge_r215_mixed_cov_20261103/seed_*/run.log` |
| Aggregate declared functional testpoints | VCS URG merge over the compute and mixed-E2E databases | 25/25 declared functional groups are 100%; assertions 20/22 have real successes, 2 UVM RAL internals have no attempts, 0 failures/incomplete; 3/3 AXI stall covers match. Raw line/condition/FSM/branch coverage is 73.95/69.39/46.69/64.95%, not 100% | `CL-R215-COMBINED-URG-19S` | `/tmp/nmaforge_r215_combined_urg_20261103/{dashboard,groups,asserts}.txt` |
| Matrix FSM; `REQ-CL-010/022` | `fsm-guards`; five production FSM assertions and two reachability covers | 5/5 assertions proven; 5/5 non-vacuous; 2/2 covers hit at depth 11 (`ST_PREFETCH_WAIT`) and 5 (`ST_ERROR_DRAIN`); no setup issues | `CL-R215-MATRIX-FSM-FORMAL` | `/tmp/nmaforge_r215_matrix_fsm_formal_20261103/vc_formal.log` |
| Matrix enabled profile; `REQ-CL-010/028` | `core-random-regress`; independent Matrix Golden, line contract, fault/recovery checks | 18 numerical/layout and 35 fault/recovery cases per seed; 3/3 seeds pass | `CL-R215-MATRIX-CORE-3S`; `20261025/26/27` | `/tmp/nmaforge_r215_matrix_core_20261103/run_seed_*.log` |
| Matrix prefetch-disabled profile; `REQ-CL-010/028` | `core-no-prefetch-fallback-regress`; legal fallback checker | 3/3 seeds pass; legal `ST_MAC→ST_A_REQ` fallback observed | `CL-R215-MATRIX-NO-PREFETCH-3S`; `20261025/26/27` | `/tmp/nmaforge_r215_matrix_no_prefetch_20261103/run_seed_*.log` |
| Selected in-repo `ai_accel_memory_fabric` reset; `REQ-CL-018`, `REQ-PC-006/007/010` | `subsystem_memory_fabric_reset_regress`; DMA/CNM response-owner, reset flush, quiet-window and recovery checkers | 3/3 seeds pass; 3/3 named reset groups 100%; owner SVA 3,921 real successes and CNM tag SVA 144, 0 failures/incomplete; severity 0/0/0 | `CL-R215-MEM-FABRIC-RESET-3S`; `20261025/26/27` | `/tmp/nmaforge_r215_memory_fabric_reset_20261103/` |
| Banked response owner; `REQ-PC-007` | `subsystem_banked_owner_regress`; `ap_banked_response_tag` and independent four-bank image | 3/3 seeds pass; tag-3 response-owner assertion has real successes, zero failures/incomplete | `CL-R215-BANKED-OWNER-3S`; `20261025/26/27` | `/tmp/nmaforge_r215_banked_owner_20261103/` |
| Banked pending-response reset; `REQ-CL-018`, `REQ-PC-007` | `subsystem_banked_reset_regress`; response flush, reset quiet interval, tagged recovery | 3/3 seeds pass; focused reset group 100%; response-tag SVA non-vacuous with zero failures/incomplete | `CL-R215-BANKED-RESET-3S`; `20261025/26/27` | `/tmp/nmaforge_r215_banked_reset_20261103/` |
| Core/Banked contention; `REQ-PC-006/007` | `subsystem_banked_contention_regress`; production arbiter, tagged response and independent Golden checker | 3/3 seeds pass; focused contention group 100%; zero route/data errors | `CL-R215-BANKED-CONTENTION-3S`; `20261025/26/27` | `/tmp/nmaforge_r215_banked_contention_20261103/` |
| Core/Banked reset interleave; `REQ-CL-018`, `REQ-PC-007` | `subsystem_banked_core_reset_regress`; dual-owner, pending-response reset and recovery checks | 3/3 seeds pass; focused group 100%; core/banked tag SVA each 3 real successes, single-owner SVA 441/471, all with 0 failures/incomplete | `CL-R215-BANKED-CORE-RESET-3S`; `20261025/26/27` | `/tmp/nmaforge_r215_banked_core_reset_20261103/` |
| Checker sensitivity; `REQ-CL-007/008/011/012/013/017/027` | `uvm_compute_cluster_dut_mutation`; seven temporary production-RTL mutants and expected-checker gate | 7/7 caught: Address, Data, Response Owner, Matrix WSTRB, Completion Error, Missing Done, Duplicate Done. Mutant UVM error/fatal outputs are expected detections; no mutant source entered the repository | `CL-R215-DUT-MUTATION-7`; seed `20261025` | `/tmp/nmaforge_r215_dut_mutation_20261103/summary.txt` and per-mutant `run.log` |
| Top integration smoke | `ai_smoke`; mapper precheck and full smoke sequence | 86 descriptors / 60 tensors precheck; `TEST PASS`; existing `Warning-[LOOP-REROLL-ENABLED]` test-fixture warning remains | `CL-R215-TOP-SMOKE`; `AI_SEED=12345` | `dv/subsystem/top_smoke/sim/ai_comp.log`, `ai_accel_smoke.log` |

## Commands

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r215_uvm_3seed_20261103 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_r215_mixed_cov_20261103 \
  MIXED_E2E_COV_SEEDS='20261014 712345 987654 20261015 20261016 20261017 20261018 20261019 20261020 20261021 20261022 20261023 20261024 20261025 20261026 20261027'

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  make -C dv/block/compute/matrix/sim core-random-regress \
  SEEDS='20261025 20261026 20261027' \
  CORE_OUT_DIR=/tmp/nmaforge_r215_matrix_core_20261103 \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1'

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  make -C dv/block/compute/matrix/sim core-no-prefetch-fallback-regress \
  SEEDS='20261025 20261026 20261027' \
  NO_PREFETCH_CORE_OUT_DIR=/tmp/nmaforge_r215_matrix_no_prefetch_20261103 \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1'

make -C dv/block/compute/matrix/formal fsm-guards \
  OUT=/tmp/nmaforge_r215_matrix_fsm_formal_20261103 \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf

make -C dv/uvm/sim uvm_compute_cluster_dut_mutation \
  COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_r215_dut_mutation_20261103

make -C dv/subsystem/top_smoke/sim ai_smoke AI_RANDOM_CASES=20 AI_SEED=12345

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  make -C dv/subsystem/dma_spad/sim subsystem_memory_fabric_reset_regress \
  MEMORY_FABRIC_RESET_OUT=/tmp/nmaforge_r215_memory_fabric_reset_20261103 \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1' \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
  make -C dv/subsystem/dma_spad/sim \
  subsystem_banked_owner_regress subsystem_banked_reset_regress \
  subsystem_banked_contention_regress subsystem_banked_core_reset_regress \
  BANKED_OWNER_OUT=/tmp/nmaforge_r215_banked_owner_20261103 \
  BANKED_RESET_OUT=/tmp/nmaforge_r215_banked_reset_20261103 \
  BANKED_CONTENTION_OUT=/tmp/nmaforge_r215_banked_contention_20261103 \
  BANKED_CORE_RESET_OUT=/tmp/nmaforge_r215_banked_core_reset_20261103 \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1' \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg
```

The combined URG report merges the R215 compute compile database, mixed-E2E compile database, and all 19 seed databases. Its reports are included in the evidence archive.

## Warnings and interpretation

- VCS compile logs for UVM, mixed E2E, Matrix, mutation, and selected memory-fabric tests contain no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. Top Smoke retains the existing loop-reroll fixture warning.
- VC Formal reports no setup issue, proof failure, or counterexample. Its non-fatal optimization/learning notices are recorded in the raw log.
- The two URG assertions with no attempts are UVM RAL internal read/write properties. The other 20 assertions have real successes; none failed or remained incomplete.
- The five Matrix FSM formal replay properties and prefetch-off fallback resolve only their named state-path disposition. The enabled-profile raw Matrix FSM score remains 49/53.
- Partial/zero Matrix Line WSTRB remain unsupported by SPEC v1.5 and were not driven. The 7/7 mutant campaign checks the WSTRB checker response; it does not make partial WSTRB a supported contract.
- The selected `ai_accel_memory_fabric` suite validates this repository's SPAD fabric. The external AXI responder remains behavioral; this is not arbitrary SoC fabric qualification.
- All 25 declared UVM functional groups reached 100%, but raw RTL/test code coverage and all requirement-level cross products did not. No requirement was promoted by this replay.

## Open issues and exit status

The replay does not close `CL-COV-002` or `CL-COV-006`: the complete legal production-engine × fault × phase × reset/backpressure × response-owner matrix is still incomplete. Descriptor maximum/stride/alias/address-overflow behavior remains partial under `OPEN-CL-002`. Matrix FSM raw transitions remain 49/53, with four profile/guard dispositions rather than a 100% raw score. Therefore 14 RTM rows remain `PARTIAL`, no P0 blocker is declared closed by R215, and Phase A has **not** reached its exit condition.

Logs-only archive: `/tmp/nmaforge_r215_published_clean_evidence_20261103.tar.gz`  
SHA-256: `bb1922cd9b6f66d258dd4bbf4db8690294b15fbed4aecd9aa9b411c5e70f874c`
