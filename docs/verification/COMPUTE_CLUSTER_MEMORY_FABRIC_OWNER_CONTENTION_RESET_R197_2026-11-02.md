# Selected memory-fabric owner, contention, and reset replay — R197

**Run ID:** `CL-MEM-FABRIC-OWNER-CONTENTION-RESET-R197-3S-20261102`
**Fixed code/test SHA:** `f87acc9bca3b3ecece385fadfd5623de6837ea8d`
**Source/test tree:** `cfc7ba4955488ae58d58f36deec368173c6ec98c`
**Worktree:** detached clean checkout `/tmp/nmaforge_r194_clean_f87acc9`
**Tools:** Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`
**Disposition:** all four targeted memory-fabric regressions PASS on three seeds. No requirement is promoted; Compute Cluster remains **HOLD** at 24 `PASS-SCOPED` / 14 `PARTIAL`.

## Executed targets

From the clean worktree, all four existing Make targets were run at the same fixed code/test SHA with seeds `20261025`, `20261026`, and `20261027`:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/subsystem/dma_spad/sim \
  subsystem_banked_owner_regress \
  subsystem_banked_contention_regress \
  subsystem_banked_reset_regress \
  subsystem_banked_core_reset_regress \
  URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
  BANKED_OWNER_OUT=/tmp/nmaforge_r197_clean_banked_owner_20261102 \
  BANKED_CONTENTION_OUT=/tmp/nmaforge_r197_clean_banked_contention_20261102 \
  BANKED_RESET_OUT=/tmp/nmaforge_r197_clean_banked_reset_20261102 \
  BANKED_CORE_RESET_OUT=/tmp/nmaforge_r197_clean_banked_core_reset_20261102 \
  BANKED_OWNER_SEEDS='20261025 20261026 20261027' \
  BANKED_CONTENTION_SEEDS='20261025 20261026 20261027' \
  BANKED_RESET_SEEDS='20261025 20261026 20261027' \
  BANKED_CORE_RESET_SEEDS='20261025 20261026 20261027'
```

All 12 target/seed runs have their required PASS marker and UVM severity `0/0/0`. Compile logs contain no `Warning-`, `Error-`, or `[TFIPC]` diagnostics.

| Test ID | Scenario / checker | Result | URG and assertion evidence |
|---|---|---|---|
| `TC-PC-R197-BANKED-OWNER` | Real `ai_accel_memory_fabric` banked tag-3 request/response and four-word readback against the host-write image | 3/3 seeds PASS | `ap_banked_response_tag`: 3 successes, 0 failures/incomplete; `ap_single_response_owner`: 414 successes, 0 failures/incomplete. The core-tag assertion is not expected to trigger in this owner-only test. |
| `TC-PC-R197-BANKED-CONTENTION` | Simultaneous scalar and four-bank reads; round-robin admission, response owner isolation, Golden data | 3/3 seeds PASS | `banked_core_contention_cg`: 100%; `ap_core_response_tag` / `ap_banked_response_tag`: 3 / 3 successes; single-owner assertion: 417 successes; zero failures/incomplete. |
| `TC-PC-R197-BANKED-RESET` | Accepted banked read interrupted by reset; owner flush, no stale response, tagged read recovery | 3/3 seeds PASS | `banked_reset_epoch_cg`: 100%; banked-tag assertion: 3 successes; single-owner assertion: 429 successes; zero failures/incomplete. |
| `TC-PC-R197-CORE-BANKED-RESET` | Core and banked accepted-response ownership across reset; pending banked response flushed; both clients recover | 3/3 seeds PASS | `banked_core_reset_epoch_cg`: 100%; core/banked tag assertions: 3 / 3 successes; single-owner assertion: 441 successes; zero failures/incomplete. |

The per-target owner assertion merges report attempts of 426, 429, 450, and 471 respectively; the targeted tag assertions have real attempts and successes where expected. The testbench drives clients at the production repository fabric boundary, so this campaign does not claim that all seven production engines are independently driven in every contention/reset case.

## Real Matrix/CNM collision evidence

The same fixed code/test SHA's R194 real-top UVM regression separately exercises production Matrix banked requests while the real CNM lane requests the shared SPAD. In each of its three seeds it reports 333 collision cycles, 320 admitted collisions, 320 Matrix wait cycles and held-payload checks, zero owner/hold violations, 768 Matrix responses, 1,120 CNM responses, and zero route mismatch. This is integrated production-engine evidence; it is distinct from the testbench-driven fabric-level directed tests above. See [R194](COMPUTE_CLUSTER_DUT_MUTATION_R194_2026-11-02.md).

## Requirement traceability and limits

| Requirement | Status | Bounded evidence added by R197 | Remaining gap |
|---|---|---|---|
| `REQ-PC-006` | `PARTIAL` | Selected fabric banked readback, serialization, accepted-response reset flush, recovery, and Golden image checks | Full production requester × fault × phase × backpressure × reset response ledger remains open. |
| `REQ-PC-007` | `PARTIAL` | Non-vacuous Core/Banked owner/tag assertions; R194 also covers the real Matrix/CNM shared-bank collision | Exhaustive production engine-pair ownership and response/error profile under stalls and resets remains open. |
| `REQ-CL-018` | `PARTIAL` | Selected fabric reset epochs and client recovery pass | Legal engine × fault × phase × reset matrix is not complete. |
| `REQ-PC-010` | `PASS-SCOPED` for the defined in-repository fabric reset contract | R196/R197 clean fixed-SHA reset replay | This does not establish compliance of an arbitrary external AXI/DDR fabric. |

R197 adds reproducible scoped evidence and closes no additional requirement. The aggregate remains **24 PASS-SCOPED / 14 PARTIAL**, with `CL-DV-v1.0` **HOLD**. No RTL or test source changed for this replay.

## Evidence archive

Logs-only archive: `/tmp/nmaforge_r197_memory_fabric_evidence_20261102.tar.gz`
SHA-256: `83f03ec53a1e0344e017ccd9b8af20bfab7d0c0c8e2757ad4fe418f10e54d153`

The archive contains the four compile logs, twelve seed logs, focused URG group/assertion reports, a manifest, and per-file SHA-256 checksums. Generated executables and coverage databases are excluded.
