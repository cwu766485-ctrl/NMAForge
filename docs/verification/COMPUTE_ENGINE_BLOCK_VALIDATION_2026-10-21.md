# Compute-engine block validation expansion — 2026-10-21

## Scope

Added direct self-checking test targets for the compute folders under
`dv/block/compute/`:

- **CNN/KV:** 24 signed 3×3 line-buffer dot products plus 24 KV-cache
  write/read round trips. The shared behavioral SPAD model injects ready
  stalls and deterministic ordered read-response latency from 0 through 7
  cycles; accepted reads, responses, writes, element counts and stored words
  are checked.
- **Matrix:** 10,072 randomized combinational datapath cases plus a new full
  `ai_tensor_matrix_core` transaction bench cover signed-byte arithmetic,
  transpose, multi-tile and batch address generation, bias, output formatting,
  randomized ready/response latency, and error recovery. The existing A3 4×4
  core benchmark remains a separate gate.
- **SFU:** 64 reference-generated test cases span all eight implemented
  opcodes and lengths 1, 2, 3, 4, 7, 8, 15 and 16. The direct SPAD model adds
  ready stalls and ordered 0–7-cycle response latency. Softmax, causal
  Softmax, RMSNorm, LayerNorm, residual, GELU, requant and SiLU writes are
  compared with the fixed-point Python model.
- **CNM and FP:** kept their existing dedicated CNM/control/shared-fabric and
  mixed-precision FP UVM/formal flows. The expanded cluster target includes
  the CNM A2.2/GEMV gates, DMA–SPAD–CNM campaign, FP dot-core/parity/UVM gates,
  and FP model unit tests.

The aggregate entry point is:

```sh
make -C dv/subsystem/tensor_datapath/sim cluster_regress
```

## Results

Environment: Rocky Linux 8.10, Synopsys VCS `V-2023.12-SP1_Full64`; the user
restored license-server connectivity before these runs.

All three new direct RTL gates passed:

```text
make -C dv/block/compute/cnn_kv/sim random-latency-test SEED=20261021
CNN_KV_RANDOM_LATENCY_PASS conv_cases=24 kv_roundtrips=24 seed=20261021 reads=596 responses=596 max_rsp_delay=7 ready_stalls=280

make -C dv/block/compute/matrix/sim datapath-random-test SEED=20261021
MATRIX_DATAPATH_RANDOM_PASS cases=10072 seed=20261021

make -C dv/block/compute/sfu/sim random-latency-test SEED=20261021
SFU_RANDOM_LATENCY_PASS cases=64 seed=20261021 reads=1038 responses=1038 writes=426 max_rsp_delay=7 ready_stalls=532
```

The first selected cluster regression passed before the full-core Matrix and
zero-token follow-ups:

```sh
make -C dv/subsystem/tensor_datapath/sim cluster_regress \
  CLUSTER_TAG=multi_engine_20261021_final \
  CLUSTER_OUT=/tmp/nmaforge_compute_cluster_multi_engine_20261021_final
```

The command exited 0 and printed
`MULTI_ENGINE_COMPUTE_CLUSTER_PASS tag=multi_engine_20261021_final`. It ran the
CNM A2.2/GEMV gates, the existing Matrix A3 core gate, 10 DMA–SPAD–CNM seeds,
the FP dot-core/parity gates and three FP UVM seeds, 19 FP reference-model
unit tests, 10,000 A4 reference cases, and top smoke with 20 seeded INT8 cases
(`AI_SEED=12345`). All 10 DMA–SPAD seed logs completed with UVM
warning/error/fatal counts of 0/0/0. Each FP UVM seed reported 212/212
bit-exact transactions and UVM warning/error/fatal counts of 0/0/0. Top smoke
printed `TEST PASS`.
The final SFU summary reports 426 writes across all cases. Detailed artifacts
are under `/tmp/nmaforge_compute_cluster_multi_engine_20261021_final/`; the
DMA–SPAD per-seed transcript and coverage artifacts are under
`dv/subsystem/dma_spad/sim/` with the same tag.

The new block Makefiles direct VCS build directories to each run's `/tmp`
output directory (`-Mdir`), so no generated compile tree is left under the
new `dv/block/compute/*/sim/` paths.

## Issue found and fixed

The first SFU run exposed a real mismatch on GELU opcode `0x35`: for Q8.8
input `1640`, the DUT returned `0x00000d76` while the reference returned
`0x00000668`. The reference model and RTL comments define GELU and SiLU as
bounded piecewise approximations, but the RTL only evaluated the middle
polynomial. The core now applies the documented zero/identity branches at
both thresholds. The SPECs now state the exact signed Q8.8 contracts, and the
SFU vectors include values below, at, and above both thresholds. The rerun
passed all 64 cases. The existing top smoke also passed after this RTL change.

The earlier VCS license-connectivity failures remain only as run history; they
were superseded by these successful license-restored runs. The 2026-10-20
compute-cluster snapshot has been superseded by the expanded 2026-10-21
aggregate below. Current per-engine convergence is summarized in the
[compute-engine status page](COMPUTE_ENGINE_STATUS.md).

## Follow-up closure — causal token zero and full Matrix core

The causal Softmax vector generator now exercises query token zero at lengths 1
and 7. Before changing the RTL, the focused VCS run reproduced the mismatch at
`0x39`, length 7, element 0: the DUT returned `0x00007b03` while the one-visible-
score reference expected `0x00008000`. Opcode `0x39` now preserves zero as its
query index; other SFU operations keep the nonzero epsilon default. Both SPEC
documents define the field as an inclusive, zero-based query index. The rerun
passed 64/64 vectors with 1,038/1,038 read responses, 426 writes, maximum
response latency 7 cycles, and 512 ready stalls.

The full Matrix core bench uses a registered four-bank operand model, a
registered scalar SPAD model for bias/unaligned writes, and the line write port
for aligned rows. It checked five numerical/layout cases (including 8×8×8 with
two batches and padded strides) and ten error cases. The run passed 64/64 bank
read responses and 49/49 SPAD responses, with bank/SPAD/line stalls of
25/30/17. Each injected error was followed by a valid transaction, including
the final post-error recovery run.

The test exposed two Matrix RTL defects and the fixed bench now catches both:

1. During K prefetch, `banked_read_valid` exposed the B request while the A
   response was still pending, although the FSM only accepted B after A had
   been captured. The valid generation now waits for the A-valid flag.
2. After watchdog expiry, `ST_ERROR` was repeatedly preempted by the still-true
   watchdog condition while `busy` remained high. Abort/watchdog preemption is
   now disabled once the core is in `ST_ERROR`, allowing the error completion
   pulse and busy clear.

Commands and final standalone results:

```sh
make -C dv/block/compute/sfu/sim random-latency-test \
  SEED=20261021 OUT_DIR=/tmp/nmaforge_sfu_zero_token_fixed_20261021
make -C dv/block/compute/matrix/sim core-random-test \
  SEED=20261021 CORE_OUT_DIR=/tmp/nmaforge_matrix_core_fixed3_20261021
```

## Full-cluster formal and DUT-only code coverage

`dv/subsystem/tensor_datapath/formal` elaborates the production opcode decoder
and all seven actual compute engines in `ai_accel_compute_cluster`. Under the
command-processor contract that no new launch occurs while any engine is busy,
VC Formal proved 3/3 assertions: opcode classes are mutually exclusive,
cluster busy matches the engine busy reduction, and the engine busy vector is
onehot0. All seven engine-dispatch covers were reached at depth 2. This is a
cluster control-ownership proof with constant memory responses; it does not
claim arithmetic, memory-arbiter, DMA, or unconstrained full-top formal
closure. The production command processor has its separate lifecycle formal
environment. To verify the serial-dispatch contract at its owner, the
production command-processor formal run separately proves (non-vacuously) that
`compute_busy` blocks `launch_valid` in `ST_DECODE`; its busy-release launch
cover is also reached. Combined with the cluster proof and the production top
wiring (`compute_busy=core_busy`, `core_start=launch_valid`), this verifies
serial engine dispatch compositionally. The design does not support starting
multiple compute engines in parallel.

Command and result:

```sh
make -C dv/block/command_processor/formal completion-ownership \
  OUT=/tmp/nmaforge_compute_cluster_cp_serial_formal_20261021 \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf
```

VC Formal `V-2023.12-SP2` exited 0: all 7 command-processor assertions were
proven and non-vacuous, including `ap_decode_compute_busy_blocks_launch`; all
3 covers were reached, including the decode wait, busy release, and subsequent
launch trace. The make target printed `CP_COMPLETION_OWNERSHIP_FORMAL_PASS`.
The log is `/tmp/nmaforge_compute_cluster_cp_serial_formal_20261021/vc_formal.log`.

The new VCS code-coverage target uses `-cm_hier` to collect only below
`tb_ai_accel_smoke.dut`, excluding testbench and AXI memory model code. The
20-case top smoke printed `TEST PASS`; the URG report is
`/tmp/nmaforge_compute_cluster_multi_engine_20261021_complete/dut_coverage/urg`.
DUT subtree raw
line/condition/FSM/branch coverage was 81.07%/68.61%/35.59%/71.65%. Selected
engine module coverage was:

| DUT module | Line | Condition | FSM | Branch |
|---|---:|---:|---:|---:|
| `ai_accel_compute_cluster` | 73.48% | n/a | 75.54% | n/a |
| Matrix core | 56.82% | 52.14% | 25.64% | 38.24% |
| SFU core | 80.26% | 77.36% | 42.45% | 66.06% |
| CNM core | 83.33% | 63.04% | 38.89% | 54.84% |
| CNN line buffer | 30.43% | 15.94% | 0.00% | 11.90% |
| KV cache | 36.11% | 27.08% | 0.00% | 14.81% |
| Mixed-precision dot | 82.31% | 54.50% | 14.29% | 69.64% |
| INT8 core | 91.76% | 78.81% | 47.22% | 72.88% |

This is raw one-seed DUT code coverage, not 100% closure or signoff. The report
keeps uncovered bins visible; their per-state/fault disposition and broader
fault×abort×reset interaction matrix remain open. The architecture serializes
compute-engine dispatch; simultaneous compute starts are outside the current
contract. The formal proofs check the one-engine-at-a-time behavior rather
than treating unsupported parallel dispatch as a passing feature. DUT code
coverage was collected and its uncovered bins remain visible; coverage
closure is still open.

The aggregate `cluster_regress` entry point now runs the full-core Matrix test,
cluster serial-dispatch formal, and DUT-only coverage in addition to the
previous selected engine/shared-fabric/top tests.

## Final aggregate replay

Command:

```sh
make -C dv/subsystem/tensor_datapath/sim cluster_regress \
  CLUSTER_TAG=multi_engine_20261021_complete \
  CLUSTER_OUT=/tmp/nmaforge_compute_cluster_multi_engine_20261021_complete \
  AI_SEED=20261021
```

Environment: Rocky Linux 8.10, VCS `V-2023.12-SP1_Full64`, VC Formal
`V-2023.12-SP2`. Exit status was 0 and the final marker was
`MULTI_ENGINE_COMPUTE_CLUSTER_PASS tag=multi_engine_20261021_complete`.
The aggregate includes the existing CNM A2.2/GEMV, CNN/KV randomized tests,
Matrix datapath/A3/core tests, SFU tests, ten DMA–SPAD–CNM seeds, three FP UVM
seeds, Python references, top smoke, the cluster formal proof, and DUT-only
URG collection. New full-core Matrix evidence is at
`/tmp/nmaforge_compute_cluster_multi_engine_20261021_complete/matrix/core/run.log`;
formal evidence is in `serial_formal/vc_formal.log`; the DUT code-coverage
report is under `dut_coverage/urg/`. The ten DMA–SPAD seed logs and coverage
databases were moved from the block simulation directory into
`/tmp/nmaforge_compute_cluster_multi_engine_20261021_complete/dma_spad/repo_artifacts/`
after the run so generated artifacts remain outside the repository.

The additional command-processor serialization formal was run after the
aggregate and passed as recorded above. Together, the two formal runs cover
the production busy/launch contract at the command-processor boundary and
onehot engine ownership in the compute cluster.
