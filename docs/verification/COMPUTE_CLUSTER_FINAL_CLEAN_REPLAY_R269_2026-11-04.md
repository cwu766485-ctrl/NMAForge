# Compute Cluster Exact-HEAD Clean Replay — R269 — 2026-11-04

## Result

The current published closeout HEAD was checked out into a detached clean-source
worktree and passed the three-seed Compute Cluster UVM regression, Top Smoke,
20-case randomized Top regression, and seven actual RTL mutation probes. This
confirms the R268-updated published tree is reproducible; it does not close any
additional requirement or change the sign-off status.

## Frozen identity and tools

| Item | Evidence |
|---|---|
| GitHub closeout branch SHA / tree | `cd55d905dc5bd3dd8fbcfa9105c6379408e68693` / `5b9d356a6bce508a6fa346cec65ab086afd9be61` |
| Run ID | `R269-EXACT-HEAD-CLEAN-3S-20261104` |
| UVM seeds | `20261025`, `20261026`, `20261027` |
| Simulator | Synopsys VCS / URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`; UVM 1.2 |
| Product RTL | Unmodified during R269 |
| Worktree | `/tmp/nmaforge_r269_fault_cross`, clean at the exact published SHA before running |

## Results

| Check | Result |
|---|---|
| Real-top seven-engine UVM | 3/3 seeds PASS; each has UVM warning/error/fatal `0/0/0` and the required final pass marker |
| Focused compute testpoints | 100.0% applicable coverage per seed; 17 requester/direction classes × three stall-depth bins = 51/51; completion-read response is explicitly N/A for the write-only completion writer |
| Memory image | 96,595 words checked per seed; zero mismatch, unknown read, or stale epoch |
| Response ownership | Per seed 6,139 accepted / 6,119 checked / 20 reset-dropped; zero route/data/error mismatch and zero pending |
| Top Smoke | PASS; mapper reports 86 descriptors and 60 tensors |
| Randomized Top | 20/20 configured random cases; `TEST PASS` |
| Actual RTL mutation | 7/7 detected by assigned checkers: Address, Data, Response Owner, WSTRB, Completion Error Code, Missing Done, Duplicate Done |

The UVM compile has no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. The
Top Smoke fixture retains its existing `LOOP-REROLL-ENABLED` debug-capacity
warning. Mutation runs intentionally emit the expected checker errors for
each injected RTL defect; they are successful only because the assigned
checker catches each defect.

## Reproduction commands

From the repository root:

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias VCS_ARCH_OVERRIDE=linux \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r269_clean_head_3seed \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

From `dv/subsystem/top_smoke/sim`:

```sh
make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

From the repository root:

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/uvm/sim uvm_compute_cluster_dut_mutation \
  COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_r269_clean_head_mutations
```

Logs-only archive:
`/tmp/nmaforge_r269_exact_head_logs.tar.gz`

SHA-256: `1f7eef287d4c6578d89d6fda14a4dc833d663af22f9b17ecf0401d450154dba9`.
It contains compile/run logs and a manifest, but no simulator binaries,
coverage databases, or generated work directories.

## Requirement disposition

The 38-row Execution RTM remains 27 `PASS-SCOPED` / 11 `PARTIAL` / 0
`BLOCKED_SPEC` / 0 `NOT_RUN`; `CL-DV-v1.0` remains **HOLD**. The eleven
partial rows are `REQ-CL-006/010/014/015/017/018/019/027/028` and
`REQ-PC-006/007`. R269 is replay evidence only. In particular, passing all
declared focused UVM groups does not replace the remaining requirement-level
legal fault/phase/reset/backpressure and production memory-owner analysis.

## Current TinyNPU distance

R269 does not rerun the paired performance workload. The latest paired
evidence remains R259, using NMAForge Matrix controller RTL baseline
`ae2415390a32f58318255a9534fade6467c7f1a8` and TinyNPU
`8216c22b762011aa20c05fc2768423fd12dda59d`, identical signed INT8 vectors,
and a modeled TinyNPU memory endpoint of 16 bytes/cycle, one-cycle response,
serialized load/compute/store:

| GEMM | NMAForge measured controller | TinyNPU array RTL | TinyNPU modeled endpoint | Cycle comparison |
|---|---:|---:|---:|---|
| 16×16×16 | 152 | 52 | 151 | NMAForge +1 cycle / 0.7% |
| 16×16×32 | 231 | 100 | 231 | Tie |
| 32×32×64 | 1,198 | 790 | 1,305 | NMAForge −107 cycles / 8.2% vs modeled endpoint |

At 32×32×64, NMAForge reads 6,144 bytes while TinyNPU's normalized estimate
uses 4,096 bytes. The largest-shape result is promising, but the comparison
does not establish a same-bandwidth product win because TinyNPU's tested array
wrapper lacks the matching SPAD request/response endpoint. The fixed-weight
ONNX CNN passes functionally on both projects, but timing boundaries differ.
GEMV/decode, larger common CNN workloads, trained-model inference, and
candidate ASIC PPA/Fmax/power remain unmeasured. See [R259 paired benchmark](../benchmark/COMPUTE_CLUSTER_TINY_NPU_MATCHED_CONTROLLER_R259_2026-11-03.md)
and [R268 stall-depth report](COMPUTE_CLUSTER_REQUEST_STALL_DEPTH_R268_2026-11-03.md).

## Review checkpoint

The latest published candidate is reproducible and the declared requester
stall-depth testpoint is complete. The remaining 11 partial requirements are
broader cross-contracts and benchmark scope, not a failing regression. Keep the
release at HOLD while those requirement rows are closed or formally dispositioned;
do not infer Compute Cluster sign-off or TinyNPU superiority from this replay.
