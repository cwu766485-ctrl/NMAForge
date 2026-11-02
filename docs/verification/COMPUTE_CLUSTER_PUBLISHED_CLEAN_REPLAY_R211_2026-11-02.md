# Compute Cluster published-HEAD clean replay — R211

**Run ID:** `R211-PUB-HEAD-REPLAY-20261102`
**Published branch / HEAD:** `feat/compute-cluster-closeout-audit` / `54db4eefcba06f3af83bef1c76ffb62ea2d2c85f`
**Published tree:** `5d94a8f431d4886120907505f35999753089087f`
**Executable source identity:** RTL, DV, benchmark, and software inputs match code commit `744d99716ce97f92912a4eda490eac27d2d9056a`; HEAD is its documentation-only descendant.
**Checkout:** detached clean worktree `/tmp/nmaforge_r210_published_clean_54db4ee`
**Tools:** VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`

## Runs

| Run | Command / configuration | Result |
|---|---|---|
| Top Smoke | `make ai_smoke AI_RANDOM_CASES=4 AI_SEED=12345` | Mapper precheck: 86 descriptors / 60 tensors; directed and four random cases pass; final `TEST PASS` |
| Seeded Top | `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345 SEED=12345` | 20 random cases plus directed smoke pass |
| Compute Cluster UVM | `make uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_published_54db4ee_uvm_20261102 COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'` | Three real-top seeds pass across all seven production engines |
| Mixed DDR/AXI coverage | `make uvm_mixed_precision_ddr_e2e_cov_regress MIXED_E2E_COV_OUT=/tmp/nmaforge_published_54db4ee_mixed_cov_20261102 MIXED_E2E_COV_SEEDS='20261014 712345 987654 20261015 20261016 20261017 20261018 20261019 20261020 20261021 20261022 20261023 20261024 20261025 20261026 20261027'` | All 16 seeds pass legal FP16/BF16 lengths and ordering, AXI gaps/backpressure, reset/recovery, and first/last-beat DMA SLVERR cases |
| Checker sensitivity | `make uvm_compute_cluster_mutation COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_published_54db4ee_mutation_20261102 COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_published_54db4ee_mutation_20261102/results` | 28/28 passive-observation mutations detected by their assigned checker |
| Combined URG | Merge three Compute Cluster and 16 mixed DDR/AXI seed VDBs with both compile databases | 24/24 declared functional covergroups at 100%; zero assertion failures/incomplete |

## Results

Each real-top UVM seed checks 71,546 Memory Image words with zero mismatch, unknown read, or stale epoch. The response-owner ledger reports 3,113 accepted, 3,094 checked, 19 reset-dropped, zero route/data/error mismatch, and no pending entries. All 21 real-engine overlap pairs are observed. The watchdog × full-CPLQ point passes for all seven engines on each seed.

The combined URG report shows 24/24 declared groups at 100%, including Compute Cluster cluster_cg 64/64, engine-pair coverage 21/21, DMA error position, and all four AXI memory gap/stall groups. Code coverage is line 73.95%, condition 69.39%, FSM 46.69%, and branch 64.95%; these are not functional closure. Of 22 assertions, 20 have real successes, none fail or go incomplete, and two internal UVM RAL read/write properties have no attempts. All three AR/AW/W stall-to-accept covers match (166/70/126). UVM compile logs have no Warning-, Error-, or TFIPC diagnostics. Top Smoke retains the existing [LOOP-REROLL-ENABLED] fixture notice.

The 28/28 campaign changes passive monitor observations; it is checker-sensitivity evidence, not an RTL mutation score. The UVM scoreboard observes full Matrix Line WSTRB only. Partial and zero WSTRB are unsupported by the frozen contract and were not stimulated. Matrix enabled-profile raw FSM remains 49/53, with four existing legal-profile/formal dispositions.

## Sign-off disposition

No requirement is promoted. The 38-row RTM remains 24 PASS-SCOPED / 14 PARTIAL and CL-DV-v1.0 remains HOLD. Broader legal requester × fault × phase × reset/backpressure crossings and requirement-specific open clauses remain. This replay does not qualify an arbitrary external AXI fabric or establish ASIC PPA.

Evidence archive: `/tmp/nmaforge_published_54db4ee_evidence_20261102.tar.gz`
SHA-256: `06b3e8cbb44e3725aee410779df33b7c9c024c8b6dd17d5f9ce0da67a54f90ca`
