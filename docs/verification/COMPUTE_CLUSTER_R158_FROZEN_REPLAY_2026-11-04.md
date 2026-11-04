# Compute Cluster R158 frozen-candidate replay — 2026-11-04

## Candidate identity

| Item | Value |
|---|---|
| Frozen R158 test SHA | `65699a9bc5a2b9bd7b380ea4c5a8c0253a8e5533` |
| Source tree | `aa1e7b180ca911fbaabec3e963b4523547779c24` |
| Product RTL/SPEC baseline | `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413` (SPEC v1.8) |
| Product/SPEC delta from baseline | None (`git diff c4b3b4f..65699a9 -- rtl docs/spec` is empty) |
| Clean worktree | `/tmp/nmaforge_phasea_r158_frozen_clean` |
| Tool | Synopsys VCS `V-2023.12-SP1_Full64`, UVM 1.2 |

This report records a replay of the frozen test SHA. The run does not move the candidate to a later RTL revision.

## Executed evidence

### Three-seed Compute Cluster UVM

Run ID: `R158-FROZEN-UVM-3S-REPLAY-20261104`
Command:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_phasea_r158_clean_replay_3seed_20261104 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

Result: PASS on all three seeds. Every seed reports `COMPUTE_CLUSTER_REAL_UVM_PASS`, UVM errors/fatals `0/0`, `CLUSTER_ENGINE_PROTECTION_RESET_CROSS_PASS` at 42/42 (seven real engines × six named Source-A Protection/reset/recovery phases), 18/18 parity fault cases, and 100.0% for the declared applicable `focused_compute_cg` bins. Each memory scoreboard checks 68,364 words with zero mismatch, unknown read, stale epoch, or orphan response. The pending owner ledgers drain to zero.

The 42/42 result is the declared Source-A Protection/reset group. It does not claim every fault type crossed with every engine, phase, and reset timing.

### Top Smoke and seeded top run

Run ID: `R158-FROZEN-TOP-20-REPLAY-20261104`
Command:

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke \
  AI_RANDOM_CASES=20 AI_SEED=12345 SEED=12345 \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

Result: PASS; mapper precheck reports 86 descriptors/60 tensors, the 20 seeded random cases complete, and the log ends with `TEST PASS`. Both the VCS `ntb_random_seed` and `AI_SEED` are fixed at `12345`. The compile emits the existing `Warning-[LOOP-REROLL-ENABLED]` fixture/debug warning.

### AXI protocol assertion activity

Run ID: `R158-FROZEN-AXI-STALL-SVA-20261104`
Command:

```sh
make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_axi_stalls \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

Result: PASS. The checked behavioral AXI memory model records both ARREADY and AWREADY stalls; `c_ar_stall_then_accept`, `c_aw_stall_then_accept`, and `c_w_stall_then_accept` have 14, 5, and 12 matches respectively. Mixed-precision end-to-end checking reports UVM warning/error/fatal counts `0/0/0`. This closes the no-hit issue for these three covers in the named mixed-precision run. It does not qualify an arbitrary external AXI fabric implementation.

### Sixteen-seed mixed-precision functional/AXI coverage and SVA audit

Run ID: `R158-FROZEN-AXI-COVERAGE-16S-20261104`
Command:

```sh
make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_phasea_r158_axi_cov_20261104 \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

Result: PASS for all 16 seeds. The merged functional E2E group, four AXI memory-model groups, all 20 declared mixed-precision functional points, and all 16 FP16×BF16 length pairs report 100.00%. Every seed reports UVM `0/0/0`; the compile and URG logs contain no `Warning-`, `Error-`, or `[TFIPC]` diagnostic. URG reports the five AXI master assertions with real successes and zero failures/incomplete: AR burst 176, AR payload stability 166, AW burst 80, AW payload stability 70, and W payload stability 123. The AR/AW/W stall-to-accept covers match 166/70/123 times. Two UVM `uvm_reg_map::do_read/do_write` internal properties have no attempts; they are unrelated to the product AXI protocol assertions.

### Checker-sensitivity mutation campaign

Run ID: `R158-FROZEN-CHECKER-SENSITIVITY-28-20261104`
Command:

```sh
make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_phasea_r158_mutation_compile_20261104 \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_phasea_r158_mutation_20261104 \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

The campaign injects observation-copy changes for address, data, owner, WSTRB, completion error code, write-after-error, and response epoch, plus Done/missing-Done/duplicate-Done on each of the seven engines. Each mutation must be caught by its named checker. This is checker-sensitivity evidence; the injected observation changes are not DUT RTL faults and must not be reported as RTL mutation score.

Result: PASS, 28 injected observations and 28 corresponding checker catches. The per-mutation logs are under `/tmp/nmaforge_phasea_r158_mutation_20261104/`; the campaign target exits zero with `COMPUTE_CLUSTER_MUTATION_CAMPAIGN_PASS`.

## RTM impact and open status

R158 adds evidence to `REQ-CL-017/018/019/027` and `REQ-PC-006/007`; it does not promote those rows. Source-A Protection/reset is exercised across all seven engines, reset suppresses old-epoch side effects, and post-reset work recovers. Remaining partial scope includes fault classes and phases outside this cross, error/priority combinations, broader production requester ownership and contention, and completion behavior across the full legal matrix.

The R158 38-row disposition remains **24 PASS-SCOPED / 14 PARTIAL**. The 14 partial rows are `REQ-CL-002/005/006/010/014/015/017/018/019/020/027/028` and `REQ-PC-006/007`. The Matrix FSM raw enabled-profile result remains 49/53 with its existing formal/profile-specific dispositions. Functional DV sign-off remains **HOLD**; this replay does not assert complete Coverage Closure or whole-NPU sign-off.

## Evidence location and limits

The generated logs and VCS databases are kept outside the repository under the `/tmp` paths shown above. No simulator database, waveform, or private library/model artifact is committed. The logs-only archive is `/tmp/nmaforge_phasea_r158_replay_20261104_logs.tar.gz`, SHA-256 `d3fc68aa6c9cbb914a007d7425e3e3455e7209936bda4f658b53d2104c0b44b1`.
