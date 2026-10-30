# Compute Cluster All-Engine SPAD Protection Cross — R64

Date: 2026-10-30  
Run ID: `R64-CLUSTER-PROTECTION-3S-CC35783`  
Code/test SHA: `cc357830923e3dd7beda114b4d761fde839b01a7`  
Worktree: detached clean worktree `/tmp/nmaforge_protection_cross_r64_clean`  
Simulator: Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`

## Scope and result

R64 adds a real top-level denied operand-read test for each production compute engine: Scalar INT8, mixed FP, CNM, Matrix, SFU, Conv, and KV. Each case keeps descriptor fetch and completion writes inside permitted regions while operand addresses remain aligned and physically in range but outside all read/execute regions. The checker observes the selected request, verifies the protection error completion and owner, and compares destination sentinels to prove there was no result writeback.

The RTL fix applies region permission, alignment, and physical-bound checks to the Matrix banked-read SRAM enable and independently to all four CNM lane SRAM enables. The arbiter still accepts and tags the request so the response/error lifecycle drains normally. CNM protection errors are registered with the accepted lane request. The behavioral SRAM now clears inactive parity response slots each cycle, preventing an error-only denied response from inheriting a previous read's parity error.

Across seeds `20261030`, `20261025`, and `20261026`, all seven engine cases pass per seed: 21/21 aggregate. Scalar INT8, FP, CNM, Matrix, and SFU report protection code 6; Conv and KV report their specified merged SPAD code 7. Every test checks 16 destination sentinel words. Descriptor and completion accesses remain permitted during the test. The memory scoreboard reports 5,557 checked words, zero mismatches, zero unknown reads, zero stale-epoch responses, and zero orphans per seed. UVM error/fatal counts are 0/0 per seed.

The focused compute testpoint group reports 100.0% of applicable bins per seed. This is the scoped UVM group only; it does not change the overall 38-requirement disposition or the historical top coverage score. No illegal addresses or unsupported WSTRB values were generated.

## Clean-SHA commands

From the detached worktree at `cc357830923e3dd7beda114b4d761fde839b01a7`:

```sh
cd dv/uvm/sim
make uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_protection_cross_r64_clean_uvm \
  COMPUTE_CLUSTER_UVM_SEEDS='20261030 20261025 20261026'

cd ../../subsystem/top_smoke/sim
make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

All three commands exited 0. The UVM compile/elaboration reported 0 errors and 0 warnings. Top Smoke and the 20-case run ended with `TEST PASS`; the existing VCS fixture warning `LOOP-REROLL-ENABLED` remains in Top Smoke and is not counted as a new RTL warning.

## Evidence paths and hashes

Generated simulator artifacts remain outside the repository.

| Artifact | SHA-256 |
|---|---|
| `/tmp/nmaforge_protection_cross_r64_clean_uvm/compile.log` | `fc01c86e64c463258e25512a288c96036596189954e4191a73cf8adea74780be` |
| `/tmp/nmaforge_protection_cross_r64_clean_uvm/seed_20261030/run.log` | `e2984466582890246770f58f75fdafad7e8fe823da3d8c6105e636f2e810d072` |
| `/tmp/nmaforge_protection_cross_r64_clean_uvm/seed_20261025/run.log` | `66110a3eb1a8c086288793a71f7b98e40ef169ac3d19f1ba3e217a8d2cf16f30` |
| `/tmp/nmaforge_protection_cross_r64_clean_uvm/seed_20261026/run.log` | `085afd4844140059678c422ae7573bdd421642095d6258ed72c1df8289a09c14` |
| `/tmp/nmaforge_protection_cross_r64_clean/dv/subsystem/top_smoke/sim/ai_accel_smoke.log` | `6874135a51edc4185715447e06bf758f30bef095a591bc89cb14047c45865539` |

The clean source worktree was at the recorded SHA before execution. Simulation output is ignored/generated and remains outside version control except the Top Smoke log produced by its in-tree make target; it is not committed.

## Requirement impact and limits

R64 adds evidence for the Protection portion of `REQ-CL-017` and `REQ-CL-027`, and the compute-requester/Protection slice of `REQ-PC-006`. The corresponding test IDs are `CL-PROT-ENGINE-001..007`; checker is the request-access monitor plus completion/error-owner checker and 16-word no-writeback memory-image checker. Run ID and seeds are above.

These requirements remain `PARTIAL`: R64 does not cross all faults with all legal engine phases, Abort/Reset timing, backpressure, alignment/protection subcases, or every accepted-write prefix. `REQ-PC-006` still lacks the complete seven-compute-requester × Protection/error × backpressure matrix. External fabric reset qualification (`OPEN-CL-003`) is untouched. Overall Compute Cluster v1.0 remains **HOLD**.
