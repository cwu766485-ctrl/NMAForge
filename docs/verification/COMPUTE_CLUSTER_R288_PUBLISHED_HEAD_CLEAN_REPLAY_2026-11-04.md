# Compute Cluster R288 Published-HEAD Clean Replay — 2026-11-04

## Result

The GitHub-published closeout HEAD was checked out in a detached clean worktree
and replayed with the licensed VCS environment. The real seven-engine UVM
regression, selected in-repository memory-fabric reset target, Top Smoke, fixed
20-case Top regression, and seven actual RTL mutation checks all pass.

This confirms reproducibility of the published candidate and its targeted
checkers. It does not close the remaining requirements: the RTM remains 27
`PASS-SCOPED` / 11 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.

## Identity and environment

| Item | Value |
|---|---|
| Published branch | `feat/compute-cluster-closeout-audit` |
| Published commit | `de40cd24d962a1d67bd021da01b5338078c0dd5d` |
| Git tree | `f7333de5b745f49796f242f2f5a5ad5e435351d5` |
| Worktree | Detached clean checkout `/tmp/nmaforge_r288_clean_published` |
| Simulator / coverage | Synopsys VCS / URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1` |
| Evidence archive | `/tmp/nmaforge_r288_clean_published_evidence_20261104.tar.gz` |
| Archive SHA-256 | `c9d60e2971ea874cc929c0953240ce0eee569f97a70979475571c09901d13ab8` |

The published commit and the local review candidate used for this report have
the same Git tree. Generated simulators, coverage databases, and temporary
mutants remain outside the repository; the archive contains logs and URG text
summaries only.

## Commands and evidence

### Real seven-engine Compute Cluster UVM

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r288_clean_published_uvm \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

All three seeds pass. Each seed observes all 42 legal ordered parity-fault
owner × unaffected successful-completion owner pairs (42/42, 100%), after
completion ownership and all six healthy output Golden checks pass. The
Memory Scoreboard checks 146,755 words with zero mismatch, unknown read, or
stale epoch; the response-owner ledger drains 10,678 accepted / 10,658 checked
/ 20 reset-dropped requests with zero route/data/error mismatch and no pending
entries. UVM warning/error/fatal counts are 0/0/0 for every seed. This is a
declared cross only; it does not close the broader legal fault × phase × reset
× backpressure space.

### Selected repository memory-fabric reset

```sh
make -C dv/subsystem/dma_spad/sim subsystem_memory_fabric_reset_regress \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg \
  MEMORY_FABRIC_RESET_OUT=/tmp/nmaforge_r288_clean_published_fabric \
  MEMORY_FABRIC_RESET_SEEDS='20261025 20261026 20261027'
```

The selected in-repository `ai_accel_memory_fabric` target passes all three
seeds, including accepted SPAD response owner flush and post-reset DMA/CNM
recovery. Its three declared reset functional groups are 3/3 at 100%; UVM
severity is 0/0/0 per seed. This does not qualify arbitrary external AXI/DDR
fabrics.

### Top integration

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs
make -C dv/subsystem/top_smoke/sim ai_run \
  AI_RANDOM_CASES=20 AI_SEED=12345 SEED=20261025
```

Both runs print `TEST PASS`; the mapper precheck reports 86 descriptors and 60
tensors. The existing Top Smoke compile warning `[LOOP-REROLL-ENABLED]` remains
visible and is not suppressed.

### Actual RTL checker-sensitivity mutations

```sh
make -C dv/uvm/sim uvm_compute_cluster_dut_mutation \
  COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_r288_clean_published_mutation \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

All seven temporary RTL faults are caught by their assigned production
checkers (7/7): Address, Data, Response Owner, Matrix WSTRB, Completion Error,
Missing Done, and Duplicate Done. The unmodified DUT is not changed by the
campaign.

## TinyNPU distance at this checkpoint

Against pinned TinyNPU SHA `8216c22b762011aa20c05fc2768423fd12dda59d`, the
latest same-vector replay is R273. The NMAForge side passes 4,608 independent
Golden output checks over three seeds. TinyNPU array cycles are its earlier
direct RTL measurements; the endpoint includes a serialized 16-byte/cycle
memory model because its tested wrapper exposes no equivalent SPAD interface.

| INT8 GEMM | NMAForge cycles | TinyNPU array RTL cycles | TinyNPU modeled endpoint | Difference at modeled endpoint |
|---|---:|---:|---:|---:|
| 16×16×16 | 152 | 52 | 151 | NMAForge 0.7% slower |
| 16×16×32 | 231 | 100 | 231 | parity |
| 32×32×64 | 1,198 | 790 | 1,305 | NMAForge 8.2% fewer cycles |

For 32×32×64, NMAForge reads 6,144 bytes versus 4,096 bytes charged by the
TinyNPU model. This is near-parity evidence and a promising larger-shape
modeled-cycle result, not a same-memory-service performance win. GEMV/decode,
matched CNN timing, trained-model inference comparison, and candidate-specific
PPA/Fmax/power remain unmeasured. See the [R273 benchmark report](../benchmark/COMPUTE_CLUSTER_TINY_NPU_MATCHED_CONTROLLER_R273_2026-11-04.md)
and [machine-readable results](../benchmark/tinynpu_matched_controller_r273.csv).

## Sign-off disposition

R288 promotes no RTM item. The remaining 11 `PARTIAL` requirements are
`REQ-CL-006/010/014/015/017/018/019/027/028` and `REQ-PC-006/007`. They retain
open clauses for broad legal requester/stall/fault/phase/reset crosses, Matrix
FSM integration, complete descriptor and numeric dispatch space, accepted
write-prefix/error ABI, general production SPAD service behavior, and a fair
TinyNPU comparison. The complete Requirement → Testpoint → Coverage → Run ID →
Seed → Evidence mapping remains in the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md).

The clean replay does not satisfy Phase A exit conditions by itself. Continue
to hold `CL-DV-v1.0`; do not treat scoped 100% bins as global coverage closure.
