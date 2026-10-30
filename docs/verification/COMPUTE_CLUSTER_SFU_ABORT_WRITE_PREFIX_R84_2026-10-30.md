# Compute Cluster SFU accepted-write Abort prefix — R84

**Date:** 2026-10-30
**Exact clean test SHA:** `8bc2ee28725d09ac75ecfcb0417e1ba47fd688f2`
**Product RTL/SPEC baseline:** `9d4e9abdba1f745644a485960620fa6bbc4979db`; R84 changes only UVM test/Makefile files.
**Run ID:** `CLUSTER-SFU-ABORT-WRITE-PREFIX-3S-8BC2EE2`
**Tool:** Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`.

## Testpoint

The real top-level SFU runs a 64-element GELU descriptor. The test issues software Abort immediately after observing the first accepted output write. Its memory checker verifies that the committed output is exactly the contiguous one-word golden prefix, every unaccepted output word retains its sentinel, accepted SPAD reads drain, and the task completes with `ERR_ABORT`. The regression gate requires one `CLUSTER_SFU_ABORT_WRITE_PREFIX_PASS` marker for each seed.

This is a single legal SFU timing point. It does not establish accepted-write prefix behavior for the other six engines, other prefix lengths, or the full Engine × Fault × Phase × Reset cross.

## Exact clean replay

Fresh detached worktree: `/tmp/nmaforge_r84_remote_8bc2ee2`, HEAD `8bc2ee28725d09ac75ecfcb0417e1ba47fd688f2`.

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r84_remote_8bc2ee2_uvm
make -C dv/subsystem/top_smoke/sim ai_smoke
```

Both commands exited 0. UVM seeds `20261025`, `20261026`, and `20261027` each reported:

- `accepted_output_prefix=1/64`, `read_drain=2/2`, completion `ERR_ABORT`;
- independent memory scoreboard: 14,889 writes, 17,267 checked words, zero mismatch/unknown/stale response;
- UVM warning/error/fatal `0/0/0`;
- existing focused applicable compute coverage 31/31 (100%); the new directed prefix marker also hit once per seed.

The merged URG report has 17/22 assertion properties with real successes, zero failures/incomplete, five uncovered, and two RAL assertions without attempts. The three AXI AR/AW properties have attempts but no successful antecedent in this compute-only sequence. The two uncovered AR/AW stall-to-accept covers also remain outside this stimulus. The report is not promoted to full assertion closure.

Top Smoke prints `TEST PASS`. Its compile retains the existing fixture warning `[LOOP-REROLL-ENABLED]` at `ai_transformer_workload.svh:9`; this is disclosed and is not an R84 UVM compile warning.

## Evidence hashes

Generated simulator artifacts are retained locally under `/tmp` and are not committed to the repository.

| Artifact | SHA-256 |
|---|---|
| UVM compile log | `1ff4f7098cf5f45139d736419b649c0f49ee8e225115c72991cce24113050fa8` |
| Seed 20261025 run log | `0ef3167a403a922fd6264b1afe66dcac6f5169e8ed76031712cbf1a974b5364b` |
| Seed 20261026 run log | `fb68e0c2a3baa8e459d5bc508716a9dcf8563d2d01286785ec10f6e14522dc6f` |
| Seed 20261027 run log | `b71b23144a181f4f3449e4f07e9a9132077917f07fc85a1e2e584349c9eec1ee` |
| URG merge log | `92eed3732f243f80026871eb2ffa510a11e97cd178f1b496763b136a649e229b` |
| URG assertions report | `873c35b26400776aefce9cb97f6126fcf5e9d10a8701303ddba3d0b3de82adde` |
| Top Smoke compile log | `9f196f899dd24d6938400249b6a0dc3d9a96f7b8faf11ffc9b606016bd1ea755` |
| Top Smoke run log | `cb12f68ea38cbcdb4ea07053d20a4c153122979b65b43dddaf8b223cd2dd1053` |

## Disposition

R84 adds a reproducible SFU accepted-write-prefix point and does not change any requirement disposition. `REQ-CL-017` and `REQ-CL-019` remain PARTIAL: six other engines, other legal Abort timing points, simultaneous faults, and reset cross coverage remain open. RTM remains 24 PASS-SCOPED / 14 PARTIAL; `CL-DV-v1.0` remains HOLD.
