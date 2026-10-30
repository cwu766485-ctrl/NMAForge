# Compute Cluster Final Clean Replay — R70

Date: 2026-10-30  
Run IDs: `R69-CNM-FSM-PHASE-3S-94C11EF`, `R70-V1-CLEAN-REGRESSION-3S-94C11EF`  
Exact clean code/test SHA: `94c11ef846089784e62ce36db66adbf03870d81d`  
Product RTL SHA: `cc357830923e3dd7beda114b4d761fde839b01a7`  
SPEC contract SHA: `f916874a9ce60741a4516eaf9e33ebcae4a676c2` (v1.7)  
Worktree: detached, clean `/tmp/nmaforge_v1_final_clean_94c11ef`  
Tools: Synopsys VCS `V-2023.12-SP1_Full64`, URG `V-2023.12-SP1`

## Result

All named R70 regression targets pass on this exact SHA: real-top seven-engine UVM on three seeds, Matrix core depth 4, CNN/KV random-latency block regression, CNM phase/reset block regression, Top Smoke, the 20-case seeded top run, and the 28-case checker-sensitivity campaign. This is a reproducible bounded replay, not complete v1.0 requirement closure.

The UVM scoreboard reports, on each seed, 5,940 accepted writes and 5,812 checked words with zero mismatch, unknown read, or stale-epoch response. UVM warning/error/fatal is `0/0/0`. It hits 18/18 selected parity cases and 19/19 Protection phase cases per seed, including source-A, applicable source-B, and writeback denials across real engines. The focused applicable compute testpoint group reports 100%; this percentage does not cover every requirement or every legal cross.

R69 adds a delayed, accepted-request-aware CNM responder; legal bank request backpressure; six Abort phases; and six asynchronous Reset phases with recovery Golden checks. Each of three seeds passes 17 Golden executions, the existing eight fault cases, late parity, six Abort phases, six Reset phases, response drain, and request-stability checking. The CNM local FSM URG reports 8/8 states and 22/23 transitions (95.65%). All 22 legal functional transitions are covered. The sole unhit raw transition is `ST_IDLE→ST_ERROR`, which requires a zero-length local start. The integrated CNM core rejects that descriptor before asserting `local_start`; the test checks `ERR_CONFIG`, no local start/busy, and all four bank-local controllers remain IDLE. The raw 22/23 result is retained; the transition is dispositioned unreachable through the public core contract, not forced or waived as reachable.

## Exact commands

Run from the indicated directory in the detached clean worktree:

```sh
cd /tmp/nmaforge_v1_final_clean_94c11ef/dv/uvm/sim
make uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v1_final_uvm_94c11ef \
  COMPUTE_CLUSTER_UVM_SEEDS='20261030 20261025 20261026'

make uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v1_final_mutation_94c11ef \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_v1_final_mutation_94c11ef/campaign

cd /tmp/nmaforge_v1_final_clean_94c11ef/dv/block/compute/matrix/sim
make core-random-regress \
  SEEDS='20261030 20261025 20261026' \
  CORE_OUT_DIR=/tmp/nmaforge_v1_final_matrix_core_94c11ef \
  PHYSICAL_ARRAY_SIZE=16 OUTSTANDING_DEPTH=4 \
  A_TILE_CACHE_ENABLE=1 NEXT_K_PREFETCH_ENABLE=1

cd /tmp/nmaforge_v1_final_clean_94c11ef/dv/block/compute/cnn_kv/sim
make random-latency-regress \
  SEEDS='20261030 20261025 20261026' \
  OUT_DIR=/tmp/nmaforge_v1_final_cnn_kv_94c11ef

cd /tmp/nmaforge_v1_final_clean_94c11ef/dv/subsystem/top_smoke/sim
make ai_cnm_random_regress \
  CNM_RANDOM_SEEDS='20261030 20261025 20261026' \
  CNM_RANDOM_OUT_DIR=/tmp/nmaforge_v1_final_cnm_94c11ef
make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

All targets exited zero and emitted their expected PASS markers. The command blocks are separate invocations.

## Coverage and scenario evidence

| Area | Three-seed result | URG / checker disposition |
|---|---|---|
| Real-top Compute Cluster UVM | Seven real engines; selected Matrix/CNM overlap and ownership; staged/parallel work; abort/reset recovery; 18 parity and 19 Protection cases per seed; 5,812 checked words | Focused applicable testpoints 100%; UVM severity 0/0/0. Top compute-only AR/AW stall-to-accept assertions remain 0 matches; W has 1 match. R15 remains the separate AXI E2E non-vacuity evidence. |
| Matrix core, 16×16, depth 4, cache and prefetch on | 18 Golden/layout cases and 35 fault/recovery cases per seed; Matrix Line full WSTRB/alignment/stable-stall/fallback/Protection checks pass; partial/zero WSTRB remains unsupported by SPEC | Aggregate block URG: score/line/condition/FSM/branch `93.00/96.10/89.69/93.55/92.66`; raw Matrix FSM remains 49/53. This is block-profile coverage, not whole-Cluster coverage. |
| CNN/KV block | Conv 25 cases including 12 depthwise; KV 27 round trips; 10 KV address-config cases; last legal SPAD word; fault/recovery and response accounting pass | Aggregate block URG: `89.23/100.00/93.63/65.91/97.37` (score/line/condition/FSM/branch). Do not merge this score with other testbenches. |
| CNM banked core | 17 Golden executions, 8 fault cases, six Abort phases, six Reset phases plus recovery on each seed; accepted-read response accounting drains; stalled request address remains stable | Aggregate block URG: `87.82/94.92/83.85/91.82/80.69`; bank-local FSM states 8/8, transitions 22/23. Only zero-length local start is unreachable through the validated core contract and explicitly checked there. |
| Checker sensitivity | Address, data, response owner, WSTRB, completion error, post-error write, response epoch and Done/missing/duplicate Done on all seven engine bits | 28/28 expected checker catches. Passive observation sensitivity only; not DUT mutation score. |
| Top integration | `make ai_smoke`; mapper precheck covers 86 descriptors. `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` | Both `TEST PASS`. Existing fixture warning `[LOOP-REROLL-ENABLED]` remains and is reported. |

## Reproduction artifacts and hashes

Generated simulation and coverage files stay outside Git. SHA-256 values below identify compile, per-seed, and merged URG logs.

| Run family | Artifact root | Compile / merged URG SHA-256 | Per-seed run log SHA-256 (`20261030`, `20261025`, `20261026`) |
|---|---|---|---|
| UVM | `/tmp/nmaforge_v1_final_uvm_94c11ef/` | compile `1b5bf88cf4b870dda1636dcbeaaeb3fff9ec7dab776d141085beaca4d47cccb0`; URG `a6888d25ec5ac2d86d67736534c22f83fb62785568b3cc9d0e71683280bab119` | `a57cc9a2a5ed4fb0222ebf7c6f06c7d657a9a9ebf28b5bcbbe8de0463d36b69e`; `aa768b93547baa3606a9a06080d4780dc6d9fecb37d8e40381bfd88e97b52adf`; `987d3ee14cbdfabfc787ac6d9e738ff4246fa651b64620b2a3ac60f4f9391f5f` |
| Matrix core | `/tmp/nmaforge_v1_final_matrix_core_94c11ef/` | compile `4cbe28cb73b03b0e38c0bab00117e449dc890d15cb2041403d0a6de6a3bccaff`; URG `900b6b5fec20dbd50d0709a8600b7eb78900e3893d10415db39718330f21f648` | `e2e677a904df6d795ab196163e9bddda5504a0aa6c492eb0c49f59fea1c6a2b4`; `65ea2e69ddcd0598ff86c514bade6a5c1c1041f732a5feb3089856659cc771df`; `387bd3e21478c83936759f9c9b15b8d38989ceb4f238b7e27c8479cad52526b` |
| CNN/KV | `/tmp/nmaforge_v1_final_cnn_kv_94c11ef/` | compile `09e8936b81cc91e2112344f7316870cf12fe269c318f86951de17580c3df7cba`; URG `e2c93f6cb7084e52350c657d779ef0813cb92bdfe5dfcd3a0f92b7c95674432a` | `547cdcffc0b7b346d3406a6b9d2b8a4be2c789b8a474825ece2fdac0e4466213`; `e698358b7ae4c8f2d9a7f70ea72b1a5324cbc6389286bf990bab86a9a38dd5b5`; `954587c2098cc3b2c5735263977099d07696c190d25a75e9a40bc6d932426da9` |
| CNM | `/tmp/nmaforge_v1_final_cnm_94c11ef/` | compile `17da08d94e41d2711904e4b5fe750575439a3ab6eadcd89effd2a0f6666ef08e`; URG `28d68a883b6ade4c0044b7b0d40a0f9cb47889c2005195b0abe291241381343e` | `b02d953b0d76ae75eeca2cd9005e3b4cd33fce4a616e4f3b938708185c640d99`; `efb5b0e6b4b968fa637f41d7b3fe1cf3605c9096d5ff89e798eb95863f4eb20c`; `94df4b6140a95085b21532016269399003053c22b5360977fde68e656b06c103` |

Top Smoke compile SHA-256: `8990a672cb36e0b5e0d39586a047dca3bb932e249bda36998c2b617004856e8f`; Top Smoke log: `41ccfb7f2b034f692acd66fdb5552e05b3788aeab887e25dfb4dffdf735056a1`; 20-case top log: `aafe2b84a5c28d2a0d846cfdb713c86b1156658403156d060e4ffa5d33e23f5f`. Mutation compile SHA-256: `e2d74225f6ac778fa991afb10307dc65e86e238b804b33079c73604d96084341`; all 28 campaign log hashes are in `/tmp/nmaforge_v1_final_mutation_94c11ef/SHA256SUMS` (manifest SHA-256 `758bac169c4931c389964eb71b1987555c54d122270799f192a67c4623959183`).

## Requirement and sign-off effect

The RTM remains **24 PASS-SCOPED / 14 PARTIAL / 0 FAIL / 0 BLOCKED_SPEC / 0 NOT_RUN**. R69 closes only the legal CNM local-FSM transition testpoint disposition under `CL-COV-008`; it does not promote the broad CNM/Cluster requirements. R70 advances exact-SHA reproducibility for named checks, not universal requirement closure.

Still open: selected external AXI fabric reset/epoch qualification (`OPEN-CL-003`); complete legal Engine × Fault × Phase × Reset and accepted-write-prefix coverage (`CL-COV-006`); all real-engine pairwise shared-SPAD concurrency (`CL-COV-004`, current dispatcher all-pair test uses behavioral engine agents); remaining per-engine descriptor and numeric boundaries; Matrix raw enabled-profile FSM remains 49/53 with its prior scoped disposition; and SFU/other protocol coverage gaps. The behavioral AXI responder does not qualify an unidentified target fabric.

**Decision: CL-DV-v1.0 remains HOLD / not signed.** This replay does not claim whole-NPU sign-off, trained-model deployment, or ASIC PPA.
