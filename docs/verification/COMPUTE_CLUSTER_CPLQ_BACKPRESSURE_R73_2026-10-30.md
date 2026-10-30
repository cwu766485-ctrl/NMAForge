# Compute Cluster R73 — Real-top CPLQ backpressure and recovery

**Disposition:** PASS for the REQ-PC-004 full/hold/consumer-release/wrap testpoint. This does not constitute Compute Cluster sign-off.
**Exact clean source/test SHA:** `9d4e9abdba1f745644a485960620fa6bbc4979db`
**VCS / URG:** Synopsys `V-2023.12-SP1_Full64` / `V-2023.12-SP1`.

## Defect found and corrected

The first real-top run reproduced an AXI-Lite `SLVERR` on `CPLQ_HEAD` (`0x0cc`) while the parallel dispatcher was busy with a full completion ring. The register block's generic `cfg_locked` rule rejected all writes during `processor_busy`, including the software-owned completion consumer pointer. That made the specified full-queue hold unrecoverable until the hardware became idle, while the hardware could not become idle until software freed a completion slot.

The RTL now permits `CPLQ_HEAD` writes while busy; other configuration writes retain the existing lock. The global SPEC and Compute Cluster SPEC v1.8 now explicitly state that software may consume published completion entries during active execution. No completion ordering, descriptor, or arithmetic behavior changed.

## Real-top testpoint

The UVM sequence submits four legal, address-disjoint production tasks: Matrix GEMM, CNM GEMV, SFU GELU, and Scalar INT8 VDOT. A four-entry ring has three usable slots. The test verifies:

- `CPLQ_TAIL` reaches 3 and remains held while the fourth task is pending; the slot-3 sentinel remains intact.
- All four engines become idle while the dispatcher remains busy on the pending ordered completion.
- Software advances `CPLQ_HEAD` to 1 while the dispatcher is busy; the fourth completion then commits in order and wraps tail from 3 to 0.
- The ring is full again after that commit, while the dispatcher is idle; all four completion records and all four output memory images match independent Goldens.
- UVM focused coverage observes `cp_cplq_full.full_completion_queue`.

This test uses no conflicting SPAD addresses and does not force illegal descriptors or illegal state transitions.

## Exact clean replay

The source SHA above was checked out detached in `/tmp/nmaforge_r73_clean_9d4e9ab`. Run the commands from that checkout root. The UVM outputs were moved outside that worktree after the run so the source checkout remained clean; retained artifacts are under `/tmp/nmaforge_r73_clean_9d4e9ab_generated_aux`.

```sh
cd /tmp/nmaforge_r73_clean_9d4e9ab
git rev-parse HEAD  # expected: 9d4e9abdba1f745644a485960620fa6bbc4979db
(cd dv/uvm/sim && make uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r73_clean_9d4e9ab/uvm \
  COMPUTE_CLUSTER_UVM_SEEDS='20261030 20261025 20261026')
(cd dv/subsystem/top_smoke/sim && make ai_smoke)
(cd dv/subsystem/top_smoke/sim && make ai_run AI_RANDOM_CASES=20 AI_SEED=12345)
(cd dv/uvm/sim && make uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r73_clean_9d4e9ab/uvm \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r73_clean_9d4e9ab/mutations)
```

All three UVM seeds pass. Each reports 12,063 modeled SPAD writes, 16,286 checked words, zero mismatch/unknown/stale/orphan response, focused applicable compute coverage 100.0%, `cplq_full=6818`, and UVM warning/error/fatal `0/0/0`. Merged URG reports the new `cp_cplq_full` variable and bin at 1/1 (100%), with 20,454 aggregate bin hits. The clean Top Smoke and fixed-seed 20-case top regression both report `TEST PASS`. The checker-sensitivity campaign catches all 28/28 expected passive-observation corruptions; it is not DUT fault injection or a mutation score.

The UVM compile log has no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. Top Smoke retains the existing `[LOOP-REROLL-ENABLED]` workload-fixture warning.

## Evidence hashes

| Artifact | SHA-256 |
|---|---|
| UVM compile log | `48e7915319311dda5e2ebff023e4dce2d9cde0fe11af2ef7317e55834de8fcef` |
| UVM seed `20261030` | `4d1e17181a5acfee81208c1fdd9c7c724de474180eeab11dd3ef58f9e11ad422` |
| UVM seed `20261025` | `3e5ac49cc1f6779bf5234d7c43f59b2d4661365746ccc08ab4206db725f19a67` |
| UVM seed `20261026` | `23f28464f1b00e1fc1a2a166ae071115ef4ebbb063c06201bea95f728fe3d453` |
| Merged URG `grpinfo.txt` | `a0ff82906b0c2eb8449e75f242ce2d40416115d6b83a656476ec260c3bb003d9` |
| Top Smoke compile log | `0759924380802dd33d70e48b4e1a9e1171a7a2c0830ed9f881102e07c7008946` |
| Top Smoke run log | `ac6d4d4de0650f3682153ab7a2e214c659b5ba96b0d9f517fd822faaaedf6164` |
| Top 20-case seeded run log | `2bf4280bfa25d3a246006936e3bebdb04c3740f5ffaaf3bf589db7635d265c77` |
| 28 mutation-log SHA manifest | `bfe00ca91495b85b2c9489b393200f343cbf7ede539d409c29975fba9b3f3810` |

## Requirement and sign-off disposition

R73 strengthens the `REQ-PC-004` evidence from dispatcher-level behavioral Engine agents to a real-top four-engine test. `REQ-PC-004` remains **PASS-SCOPED**; the RTM remains **24 PASS-SCOPED / 14 PARTIAL / 0 BLOCKED_SPEC / 0 NOT_RUN**. `CL-DV-v1.0` remains **HOLD**: external-fabric reset qualification (`OPEN-CL-003`), legal fault × phase × engine × reset crosses, and other partial requirements remain open. R73 does not change those dispositions.
