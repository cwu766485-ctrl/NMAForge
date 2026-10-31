# R142 Matrix parity response-consumed reset epoch — 2026-10-31

## Disposition

R142 adds the adjacent legal Matrix reset phase to R141: the Matrix engine samples an accepted parity-error response, then reset arrives before the error completion is published. The test checks reset suppression, memory preservation, and a successful reissued GEMM. It closes no requirement row. The 38-row disposition remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.

## Fixed source and run identity

- Test/source commit: `c87e137aaab2c708beffc1d7bdfb378829dcab1e`
- Source tree: `301ceb34e0eeba231a296ac35f52ea131240c8d3`
- Parent: `a3582ceed0c097ecd112382a2babcf24a28fa2ec`; product RTL and SPEC are unchanged.
- Run ID: `R142-MATRIX-PARITY-RESET-PHASE-3S-20261031`
- Seeds: `20261025`, `20261026`, `20261027`
- Tools: Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.

## Testpoint

The existing real-CMDQ sequence now covers both sides of the Matrix parity-response consume edge. For the R142 point it initializes destination and completion sentinels, launches legal 4×4×4 GEMM task `0x07e6`, injects parity at Matrix A, and waits for both the accepted banked read and `matrix_response_fault` while Matrix is active. The sequence asserts reset 1 ns after that sampled response edge, before the Matrix error path can publish its completion.

It checks no response-valid during reset or the post-reset quiet interval, completion tail remains zero, and destination/completion sentinel images are unchanged. After restoring parity, task `0x07e7` is reissued; its completion and all 16 output words must match the independent Golden value 4. The regression Make target requires both the R141 pre-consume marker and R142 post-consume marker on every seed. No state is forced and no illegal request is used.

## Results

| Seed | UVM warning/error/fatal | Memory words checked | Mismatch / unknown / stale / orphan | Reset-dropped accepted reads | Focused compute coverage |
|---:|---:|---:|---:|---:|---:|
| 20261025 | 0/0/0 | 44,895 | 0/0/0/0 | 12 | 100% applicable |
| 20261026 | 0/0/0 | 44,895 | 0/0/0/0 | 12 | 100% applicable |
| 20261027 | 0/0/0 | 44,895 | 0/0/0/0 | 12 | 100% applicable |

Both required markers appear once per seed. The pending response ledger drains to empty. URG reports `cluster_cg` at 100% (64/64 declared bins), scoped to its declared functional group. Merged mixed URG totals are line 56.07%, condition 69.31%, toggle 63.52%, FSM 42.28%, branch 59.59%, assertion 72.00%, and groups 29.72%. These are mixed code/assertion/group metrics and do not represent whole-design functional closure.

Same-tree Top Smoke passes its mapper precheck (86 descriptors / 60 tensors) and ends `TEST PASS`; the existing `LOOP-REROLL-ENABLED` fixture notice remains. The passive checker-sensitivity campaign catches 28/28 expected mutations. This is checker sensitivity evidence, not DUT fault injection or a mutation score.

## Commands and evidence

Three-seed VCS/URG regression:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r142_parity_reset_3s \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

Same-tree Top Smoke:

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke \
  SEED=20261025 AI_RANDOM_CASES=20 AI_SEED=20261025
```

Checker-sensitivity campaign:

```sh
make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r142_parity_reset_3s \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r142_mutations
```

SHA-256 evidence:

| Artifact | SHA-256 |
|---|---|
| VCS compile log | `4ea961156d87b4d1f6b497c7b2d4c2544c5ffc0f1bff66ad28436ece66fcd697` |
| URG merged log | `b33b1308c6423331c8aac0a814aed1a2ff0d0cf32148ec55230a49ad54158b34` |
| Seed 20261025 UVM log | `e61d2cce5e99cd27c8159b5adb89954d670552198e22bf13498ffc97a64923d7` |
| Seed 20261026 UVM log | `71c8b95d703b5a51ed9d6bc02be84251f3308b559d6dd3aff33ed44a673273b6` |
| Seed 20261027 UVM log | `7ae6d813cc50eca5ff365687b0c7f05b105a21e520895b9677f56678ed04cd51` |
| Mutation `SHA256SUMS` manifest | `a73a4e353ad9a4ffbc4ed425e40d2e41f16ba4da91c9e339216cd97b47d39c9c` |
| Top Smoke log | `fd9af0ab19a37ab46a28a29ea2cdc7e040d86156417c165d23c15833e91980d3` |
| Top compile log | `bc3c73a9a5d7df6dc8b668e1a26e7dbb0c769fbab7e9cc8ac048f8f436cb9ada` |

Raw VCS/URG artifacts are under `/tmp/nmaforge_r142_parity_reset_3s`; mutation logs and the hash manifest are under `/tmp/nmaforge_r142_mutations`. Top Smoke logs are in `dv/subsystem/top_smoke/sim/`.

## Requirement impact and remaining work

| Requirement | Disposition | R142 contribution | Still open |
|---|---|---|---|
| REQ-CL-017 | PARTIAL | Reset after Matrix samples parity response suppresses output side effects and error completion; legal task reissues successfully. | Other engines, accepted-write prefixes, error phases, and full Abort/Reset combinations. |
| REQ-CL-019 | PARTIAL | CPLQ tail remains unchanged when reset precedes error-completion publication. | Full error-priority, completion backpressure, and fault/phase/reset combinations. |
| REQ-CL-027 | PARTIAL | No stale completion for task `0x07e6`; task `0x07e7` completion and Golden are checked. | Complete per-engine error ABI and completion-order matrix. |
| REQ-PC-006 | PARTIAL | The accepted response is consumed by Matrix before reset; reset/recovery ends with no stale or orphan response and an empty ledger. | Full requester × fault × phase × backpressure/reset ownership matrix. |
| REQ-PC-007 | PARTIAL | Production Matrix traverses the shared banked SPAD path through response consumption and reset. | Broader seven-engine contention and error-recovery crossings. |

This is complementary to [R141](COMPUTE_CLUSTER_MATRIX_PARITY_RESET_EPOCH_R141_2026-10-31.md), which resets before response consumption. It does not establish a completed/published parity error followed by external-fabric reset, nor does it close external fabric contract, WSTRB/alignment/protection, broad legal crosses, or all remaining RTM rows. No coverage bin is waived or promoted by R142.
