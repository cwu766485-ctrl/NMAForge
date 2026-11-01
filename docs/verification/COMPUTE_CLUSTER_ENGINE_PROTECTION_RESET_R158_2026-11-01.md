# R158 Seven-engine Protection/reset/recovery evidence

**Run date:** 2026-11-01

**Decision impact:** scoped evidence added; no requirement disposition promoted; `CL-DV-v1.0` remains **HOLD**.

## Frozen identity

| Item | Identity |
|---|---|
| Product RTL/SPEC baseline | `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`; SPEC v1.8 |
| Exact local test SHA/tree | `65699a9bc5a2b9bd7b380ea4c5a8c0253a8e5533` / `aa1e7b180ca911fbaabec3e963b4523547779c24` |
| Tree-identical published commit | `8e3735e930f01c4a6bbb6a79251e153611dfcda2` on `feat/compute-cluster-closeout-6848a41` |
| Local parent / published parent | `faa064e4072cfef1313eef8e9f9b8fefe6a4577c` / `5b7effbb1750fb17ab07562d80d3bb75e2938845` |
| Tool | Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`, UVM 1.2 |

The change is verification-only: `dv/uvm/tests/sequences/ai_compute_cluster_e2e_seq.svh` adds the real-top sequence and explicit `engine_protection_reset_cg`; `dv/uvm/sim/Makefile` gates all seven engine cases and the 42-bin cross. Product RTL and SPEC are unchanged.

## Testpoint and checker

`TC-CL-R158-ENGINE-SOURCE-A-PROTECTION-RESET` runs a legal descriptor for each production engine (INT8, FP, CNM, Matrix, SFU, Conv, KV), observes the real Source-A request at its denied address, checks the implementation's internal `engine_error_code` mapping, then asserts top reset. It verifies reset/release quiet windows, no stale response, completion-tail movement, or output write, and a successful same-engine task after reset. Matrix recovery checks its full 16-word Golden image; each engine's completion task ID, status, and element count are checked. The complete memory scoreboard checks the resulting Memory Image.

`engine_protection_reset_cg` crosses seven engine bins with six legal phases: launch, Source-A denial, error observed, reset epoch flushed, old side effects suppressed, and recovery completion. The gate requires 42/42 bins; it does not force internal state or create illegal transactions.

The existing internal error mapping observed and checked here is 6 for INT8/FP/CNM/Matrix/SFU and 7 for Conv/KV. Reset is asserted after observing that internal error and before the old task completes. This test does not redefine the external completion error ABI or establish its full cross-engine consistency.

## Reproduction and results

Run ID: `R158-UVM-PROT-RESET-3S-20261101`; seeds `20261025`, `20261026`, `20261027`.

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r158_protection_reset_3seed \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  VCS_UVM='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1 -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS'

make -C dv/subsystem/top_smoke/sim ai_smoke AI_RANDOM_CASES=20 AI_SEED=12345

make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r158_mutation_build \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r158_mutations \
  VCS_UVM='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1 -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS'
```

| Run ID | Result |
|---|---|
| `R158-UVM-PROT-RESET-3S-20261101` | PASS, three seeds. Each seed hits 7/7 engines × 6/6 phases = 42/42 (100.0%); 68,364 scoreboard words, zero mismatch/unknown/stale/orphan, empty pending ledgers, and UVM warning/error/fatal `0/0/0`. Merged URG reports 100.00% for the named group. |
| `R158-TOP-SMOKE-20-20261101` | PASS, 20 random cases and final `TEST PASS`; the pre-existing `[LOOP-REROLL-ENABLED]` fixture notice remains. |
| `R158-MUTATION-28-20261101` | PASS, 28/28 checker-sensitivity observations caught by the assigned checker: Address, Data, Owner, WSTRB, Completion Error Code, Write After Error, Response Epoch, and Done/Missing-Done/Duplicate-Done for all seven engines. The target expects checker UVM errors and verifies the catcher for every injection; this is not an RTL mutation score. |

Logs-only archive (kept outside the repository): `/tmp/nmaforge_r158_evidence_logs.tar.gz`, SHA-256 `ce25a4cd89ffb6e80c65bede19c3667702671e24cf279f7b57df853028ba0380`.

## Requirement trace and limits

| Requirement | Status | Evidence added by R158 |
|---|---|---|
| `REQ-CL-017` | PARTIAL | Real Source-A Protection denial/error observation for all seven engines followed by reset; other fault classes, phases, backpressure and completion ABI combinations remain open. |
| `REQ-CL-018` | PARTIAL | Seven-engine reset/release quiet window and recovery; does not represent all production-engine pairs or independent fabric-reset cases. |
| `REQ-CL-019` | PARTIAL | Old completion/output suppression and new-epoch completion checks; remaining completion backpressure and simultaneous-error ordering space is open. |
| `REQ-CL-027` | PARTIAL | Seven engine recovery task IDs/status/element counts plus Matrix Golden; complete descriptor/error ABI matrix remains open. |
| `REQ-PC-006` | PARTIAL | Full scoreboard Memory Image check per seed; broader legal traffic and write-mask/ownership cases remain open. |
| `REQ-PC-007` | PARTIAL | All seven real engines exercise their production SPAD requester on the tested fault path; the test cases are sequential and do not close pairwise concurrent ownership/arbiter contention. |

R158 closes only the named Source-A Protection/reset/recovery testpoint. The full 38-row disposition remains 24 `PASS-SCOPED` / 14 `PARTIAL`; no `PARTIAL` is promoted by this evidence. Matrix FSM raw enabled-profile coverage remains 49/53 with the existing formal/profile dispositions. Functional coverage, the other unresolved P0 requirement slices, TinyNPU common-resource comparison, and ASIC PPA remain separate work.
