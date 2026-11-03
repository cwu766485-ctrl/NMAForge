# Compute Cluster Request Stall-Depth Closure — R268 — 2026-11-03

## Result

At fixed test candidate `9b2a38aa634c064516fc693f89d780f9fe85fe8c`
(tree `907e1c5ca7770b45952c1e8dff55edef2177088d`), the real-top seven-engine
UVM regression passes on seeds `20261025`, `20261026`, and `20261027`. Every
seed observes all 51 declared requester/direction × stall-depth bins, with no
missing legal bin. This closes the named request stall-depth testpoint only;
it does not close `REQ-CL-006` or the overall Compute Cluster sign-off.

The testbench creates a bounded, legal scheduler-admission pause while a real
request is pending. It holds the source request stable and prevents SRAM-side
valids, grants, and response tagging during the pause, then checks acceptance
and normal progress after release. Product RTL and external interfaces are not
modified. This injection is a testbench-only admission pause; it is not a claim
that the production arbiter has an external memory-ready input.

## Frozen run identity

| Item | Evidence |
|---|---|
| Test SHA / tree | `9b2a38aa634c064516fc693f89d780f9fe85fe8c` / `907e1c5ca7770b45952c1e8dff55edef2177088d` |
| Run ID | `R268-SPAD-STALL-DEPTH-3S-20261103` |
| Seeds | `20261025`, `20261026`, `20261027` |
| Simulator | Synopsys VCS `V-2023.12-SP1_Full64`; UVM 1.2 |
| Build state | Clean committed source tree; generated output isolated under `/tmp` |
| Product RTL | Unchanged by this R268 change |

## Testpoint and evidence

The 17 classes comprise 11 legal direction combinations observed on the
seven-slot engine request vector, one Matrix banked-read interface, one Matrix
Line-write interface, and four individual CNM lane-read interfaces. Each class
is crossed with 1-cycle, 2-cycle, and 8-or-more consecutive stalled cycles.

| Seed | Observed classes / bins | Directed 8-cycle pause markers | UVM warning/error/fatal | Memory scoreboard | Response owner ledger |
|---|---:|---:|---:|---|---|
| `20261025` | 17/17; 51/51 | 4/4; Scalar, FP, Matrix Line, four-lane CNM | 0/0/0 | 77,501 writes; 96,595 checked words; 0 mismatch, unknown, or stale epoch | 6,139 accepted; 6,119 checked; 20 reset-dropped; 0 route/data/error mismatch; 0 pending |
| `20261026` | 17/17; 51/51 | 4/4; Scalar, FP, Matrix Line, four-lane CNM | 0/0/0 | Same deterministic counts and zero errors | Same deterministic counts and zero errors |
| `20261027` | 17/17; 51/51 | 4/4; Scalar, FP, Matrix Line, four-lane CNM | 0/0/0 | Same deterministic counts and zero errors | Same deterministic counts and zero errors |

The Matrix Line/CNM concurrency point additionally checks 100 Matrix Line
stability samples per seed with zero payload violations, concurrent legal
traffic over 1,855 cycles, independent Matrix/CNM Golden images, and ordered
completions. The four directed pauses each hold the real request unaccepted
for eight cycles, check payload stability, and check that a real handshake
resumes after release. All other bins come from legal observed traffic; no
illegal FSM state or illegal descriptor is used to force coverage.

VCS compile log has no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. Each
seed finishes the full regression and Make gate with UVM severity `0/0/0`.

## Reproduction

```sh
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias VCS_ARCH_OVERRIDE=linux \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r268i_stall_depth_3seed_9b2a38a \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

Logs-only archive:
`/tmp/nmaforge_r268i_stall_depth_3seed_9b2a38a_logs.tar.gz`

SHA-256: `4f6cd3decf62145a10c8cb5647cab9325fccd5f24c981b693e8b81da3c3a7e34`

The archive contains the VCS compile log and three UVM run logs; simulator
binaries, coverage databases, and generated VCS directories are excluded.

## Requirement disposition and open work

`REQ-CL-006` remains `PARTIAL`: R268 closes the declared requester × direction
× `{1,2,8+}` stall-depth point, but it does not close the full operation-phase,
fault, reset, terminal-cancel, and completion interaction space. `REQ-PC-006`
and `REQ-PC-007` remain `PARTIAL` for broader simultaneous requester/fault/
backpressure ownership contracts. The default Matrix FSM raw transition count
and its existing reachability dispositions are unchanged. No one of the 38
Requirement dispositions is promoted. Current totals remain 27
`PASS-SCOPED` / 11 `PARTIAL` / 0 `BLOCKED_SPEC` / 0 `NOT_RUN`, and
`CL-DV-v1.0` remains **HOLD**.

## Current TinyNPU distance

R268 changes no benchmark RTL or workload, so the latest paired evidence is
still R259, not a new R268 comparison. With identical INT8 vectors and a
16-byte/cycle, one-cycle serialized-memory estimate for TinyNPU:

| GEMM | NMAForge Matrix controller | TinyNPU array RTL | TinyNPU normalized endpoint | Interpretation |
|---|---:|---:|---:|---|
| 16×16×16 | 152 cycles | 52 cycles | 151 cycles | NMAForge is 1 cycle (0.7%) slower |
| 16×16×32 | 231 cycles | 100 cycles | 231 cycles | Tie |
| 32×32×64 | 1,198 cycles | 790 cycles | 1,305 cycles | NMAForge uses 107 fewer cycles (8.2%) than the modeled endpoint, but reads 6,144 B vs TinyNPU's modeled 4,096 B |

Thus NMAForge is close on these three measured-controller/model-normalized
GEMMs, with a promising largest-shape cycle result. It has **not** demonstrated
a same-bandwidth product win: TinyNPU has no comparable SPAD request/response
port in the tested array wrapper, and its normalized memory service is a
serialized model. The fixed-weight ONNX CNN passes on both designs, but its
timing boundaries differ and the NMAForge host layout bridge is separate; it
does not establish a fair speedup. GEMV/decode, trained-model inference, and
candidate ASIC PPA/Fmax/power are also not compared. See [the current benchmark
report](../benchmark/NMAFORGE_VS_TINY_NPU.md) and [R259 matched-controller
details](../benchmark/COMPUTE_CLUSTER_TINY_NPU_MATCHED_CONTROLLER_R259_2026-11-03.md).

This is a good review checkpoint: the declared SPAD requester stall-depth
point is closed and reproducible, while the remaining sign-off and fair
TinyNPU common-memory comparison are clearly bounded open work.
