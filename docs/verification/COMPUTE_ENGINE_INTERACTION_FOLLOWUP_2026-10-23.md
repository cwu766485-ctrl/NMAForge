# Compute-engine interaction follow-up — 2026-10-23

## Scope

This follow-up closes selected multi-fault, abort/reset, late-progress, and
CNN/KV address/stride gaps in the five compute groups. It adds simulation
checks and runs the aggregate compute regression with the updated benches.
It does not claim exhaustive cross-product coverage or project signoff.

## Added checks

- **CNM:** inject parity after 128 accepted request slots in a length-256
  operation and check error retirement with no result write. Combine parity
  and protection with abort to check priority; assert reset while faults and
  abort are active; then check recovery.
- **CNN/KV:** index the full 512 KiB scratchpad address space instead of
  aliasing through the low address bits. Sweep 25 CNN cases including normal
  and depthwise modes across separated address windows. KV cases include
  lengths 1–128, zero/minimum/maximum aligned strides, head/token boundary
  values, and placement near the end of SPAD. Inject CNN parity after 9 weight
  and 31 pixel reads, and KV parity after 24 of 64 reads; check the committed
  prefix and suppress later writes. Also check abort+SPAD-error priority,
  reset with faults asserted, and recovery.
- **Matrix:** combine bank/SPAD/line protection, parity, watchdog, and abort;
  check abort classification, no write, and reset while fault inputs remain
  asserted. Inject parity during a 16×16 tile after 20 output lines have
  committed; verify the prefix remains stable and later writes stop.
- **SFU:** inject parity after 8 of 16 read responses and check prefix
  writeback/drain. Combine watchdog, parity, protection, and abort to check
  abort priority; assert reset with faults active and then check recovery.
- **FP:** test parity and abort asserted on the same returned-read cycle. The
  parity classification is retained while accepted reads drain, with no
  writeback. Also test reset while abort/parity are active.

## Reproduction and results

The updated direct benches passed these three-seed regressions:

```sh
make -C dv/subsystem/top_smoke/sim ai_cnm_random_regress \
  CNM_RANDOM_SEEDS='20261021 20261022 20261023' \
  CNM_RANDOM_OUT_DIR=/tmp/nmaforge_cnm_fault_interactions_20261023 \
  VCS='vcs -licwait 1'

make -C dv/block/compute/cnn_kv/sim random-latency-regress \
  SEEDS='20261021 20261022 20261023' \
  OUT_DIR=/tmp/nmaforge_cnn_kv_expanded_20261023 VCS='vcs -licwait 1'

make -C dv/block/compute/matrix/sim core-random-regress \
  SEEDS='20261021 20261022 20261023' \
  CORE_OUT_DIR=/tmp/nmaforge_matrix_fault_interactions_20261023 \
  VCS='vcs -licwait 1'

make -C dv/block/compute/sfu/sim random-latency-regress \
  SEEDS='20261021 20261022 20261023' \
  OUT_DIR=/tmp/nmaforge_sfu_fault_interactions_20261023 \
  VCS='vcs -licwait 1'

make -C dv/block/compute/fp/sim dot-core-test \
  DOT_CORE_OUT_DIR=/tmp/nmaforge_fp_interaction_20261023 \
  DOT_CORE_PARITY_MAX_OUT_DIR=/tmp/nmaforge_fp_interaction_20261023/max_parity \
  VCS='vcs -licwait 1'
```

CNM reported `cases=10 faults=8 late_faults=1 reset_fault_combo=1` for every
seed. CNN/KV reported `conv_cases=25 conv_dw_cases=12 kv_roundtrips=27
conv_faults=6 kv_faults=7 late_faults=2 reset_fault_combo=1`; response counts
matched at 4,130–4,732 per seed with maximum latency 7 cycles. Matrix passed
all three seeds with 12 fault checks, `MATRIX_CORE_LATE_FAULT_PASS` after 20
completed lines, and abort/reset interaction markers. SFU reported
`cases=64 error_cases=8 late_faults=1 fault_abort_combo=1
reset_fault_combo=1` per seed, with 1,038/1,038 reads/responses each. The FP
dot-core gate, including all maximum-length BF16/FP16 A/B parity cases, passed.

The final aggregate is:

```sh
env -u VCS_ARCH_OVERRIDE make -C dv/subsystem/tensor_datapath/sim cluster_regress \
  CLUSTER_TAG=multi_engine_20261023_interactions_final \
  CLUSTER_OUT=/tmp/nmaforge_compute_cluster_multi_engine_20261023_interactions_final \
  CLUSTER_FORMAL_OUT=/tmp/nmaforge_compute_cluster_multi_engine_20261023_interactions_final/serial_formal \
  CLUSTER_COV_OUT=/tmp/nmaforge_compute_cluster_multi_engine_20261023_interactions_final/dut_coverage \
  COMPUTE_SEEDS='20261021 20261022 20261023' \
  COMPUTE_COV_SEEDS='20261021 20261022 20261023 20261024 20261025' \
  AI_RANDOM_CASES=20 AI_SEED=20261023 \
  VCS='vcs -licwait 1' URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

The aggregate exited 0 and printed `MULTI_ENGINE_COMPUTE_CLUSTER_PASS`. Top
smoke printed `TEST PASS`; serial-cluster formal setup was clean, with 3/3
assertions proven and 7/7 engine covers reached. All ten DMA–SPAD–CNM seed runs
passed with UVM warning/error/fatal `0/0/0`. Each of the three FP UVM seeds
scored 212/212 bit-exact transactions with warning/error/fatal `0/0/0`.

The initial interaction merge had 29 test instances and all 23
`rtl/compute` module definitions. Its figures are retained as historical
evidence; the post-pair-sweep merge and current raw coverage figures are below.

## FP full-length formal status

Command:

```sh
make -C dv/block/compute/fp/formal parity-full-domain \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf \
  OUT=/tmp/nmaforge_fp_parity_full_20261023 FORMAL_PROBE_TIMEOUT=150

make -C dv/block/compute/fp/formal parity-full-cutoff-assume \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf \
  OUT=/tmp/nmaforge_fp_parity_cutoff_assume_20261023 FORMAL_PROBE_TIMEOUT=150

make -C dv/block/compute/fp/formal parity-full-progress-assume \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf \
  OUT=/tmp/nmaforge_fp_parity_progress_assume_20261023 FORMAL_PROBE_TIMEOUT=150

make -C dv/block/compute/fp/formal parity-full-pending-last-compute \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf \
  OUT=/tmp/nmaforge_fp_parity_pending_last_20261023 FORMAL_PROBE_TIMEOUT=150
```

Setup is clean (`No setup issues found`). Three properties prove in the
combined full-domain harness: read/request-response accounting, blocking
compute at the parity cutoff, and draining into the error state. The other
three properties (valid cutoff, progress before cutoff, and writeback
exclusion) remain in `checking` when the 150-second external timeout stops VC
Formal; no counterexample is reported.

Additional compositional runs pass the cutoff-validity lemma
(`parity-full-cutoff-assume`, 1/1 non-vacuous, safe depth 335) and the local
`pending parity blocks last compute` lemma (`parity-full-pending-last-compute`,
1/1 non-vacuous, 3 seconds). The separate full-domain progress-bound proof
still times out at 150 seconds. A later isolated full-domain proof closes the
writeback-exclusion property. Cutoff validity is separately proven under the
response-index bound; the progress-bound proof and the complete unassisted
six-property lifecycle aggregate remain partial.

### Isolated full-domain writeback proof after explicit guard

The FP core now enters `ST_WRITE` only when no error is pending and no new
failure is visible on the final-compute cycle. This makes the intended
fault/writeback exclusion explicit while retaining the existing drain/error
path. The maximum-length BF16/FP16 parity stress was rerun after this RTL
change and passed all four combinations (final packed word A/B): 65,536 reads
accepted and drained, 65,534-element prefix retained, and recovery task
returned `0x3f800000` for each case.

The new target isolates the existing `ap_writeback_excludes_pending_parity`
assertion in the full-domain harness, with production arithmetic RTL present:

```sh
make -C dv/block/compute/fp/formal parity-full-writeback-domain \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf \
  OUT=/tmp/nmaforge_fp_parity_writeback_domain_guard_20261023 \
  FORMAL_PROBE_TIMEOUT=300
```

VC Formal `V-2023.12-SP2` reported clean setup, 1/1 assertion proven and
non-vacuous at safe depth 156 in 2 seconds, plus 2/2 parity reachability covers
at depths 4 and 5. The contract covers every nonzero 16-bit length, aligned
bases, `watchdog_limit=0`, `abort=0`, response-valid only for outstanding
reads; SPAD request backpressure remains unconstrained. The unassisted six-
property run remains partial (3/6 proven). Cutoff validity has a separate
compositional proof under the response-index bound; the progress-bound goal
still needs closure. This proof closes the requested parity-to-
writeback exclusion, not all FP lifecycle properties or arithmetic correctness.

The remaining full-domain progress work was retried with control-only
arithmetic stubs. The direct progress property and its independently needed
parity-response cutoff lemma both remained `checking` after 300 seconds. The
cutoff lemma was extended to 600 seconds and still timed out without a
counterexample or proof:

```sh
make -C dv/block/compute/fp/formal parity-full-event-cutoff-control-abstract \\
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf \\
  OUT=/tmp/nmaforge_fp_event_cutoff_control_abstract_600_20261023 \\
  FORMAL_PROBE_TIMEOUT=600
```

The result is inconclusive. The dependent compositional progress proof was
not run because its cutoff lemma is not proven. Keep the production-arithmetic
full-domain aggregate at 3/6; the separate writeback-exclusion proof and
full-length simulation do not close the remaining lifecycle properties.

## Parallel CMDQ dispatch contract

Normal compute descriptors now use `ai_parallel_compute_dispatcher`. It allows
one active command per engine, records each engine's result/error against its
descriptor slot, and commits completion entries in CMDQ order. The SPEC fixes
the software-visible contract: engine execution may overlap, but completion
order remains FIFO; software must avoid conflicting SPAD reads/writes between
commands that can overlap. Macro descriptors hand off to the legacy command
processor only after earlier parallel work drains. Abort stops new issue,
aborts all dispatched engines, and waits for the active records to drain in
order. `ai_compute_spad_mux` arbitrates the seven core-SPAD requesters under
the existing single scheduler-side admission point.

The top smoke contains a Matrix+SFU overlap case that observes both engines
busy in the same cycle, queues a second SFU task behind the first, and checks
all three completion IDs in submission order. It checks the four outputs from
each SFU task (`8, -8, 17, -15`) while Matrix uses the shared core-SPAD path,
validating response-owner routing; a launch monitor confirms the two SFU tasks
do not overlap. A second directed case aborts Matrix and a 1,024-element SFU
task while both are active; both completions report `ERR_ABORT`, retain CMDQ
order, and the dispatcher and all engines are idle after drain. Reproduction:

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke \
  AI_RANDOM_CASES=0 AI_SEED=20261023
make -C dv/subsystem/top_smoke/sim ai_run \
  AI_RANDOM_CASES=20 AI_SEED=20261023
```

Both VCS `V-2023.12-SP1_Full64` runs exited 0 and printed `TEST PASS`; the
seeded run also completed all 20 random top cases. Compilation reported 0
errors and 0 warnings. The 21-pair sweep and dispatcher formal are recorded
below; completion backpressure and project-wide queue formal remain open.

## Residual closure

These are selected directed and seeded cases. Remaining work includes other
multi-fault orderings, all CNN/KV stride/address combinations, Matrix faults at
every tile position, SFU numeric-error reachability, FP lifecycle closure, and
completion backpressure. The aggregate raw code coverage remains partial and
does not represent feature completion. The dispatcher proof targets dispatcher
RTL with abstract engine completion; it complements the integrated top pair
sweep. FP progress formal remains inconclusive after the 600-second control-
only cutoff-lemma attempt; the unassisted lifecycle remains 3/6. Project-wide
UVM, formal, LEC, DFT, and signoff closure remain open.

## All engine pairs and refreshed compute coverage (2026-10-23)

The updated top smoke sweeps all 21 unordered pairs among the seven compute
engines. It observes both real top engine-busy bits together, aborts the pair,
checks the two completion IDs and statuses in CMDQ order, then checks the
dispatcher and all engines idle. All five top DUT-only coverage seed logs
contain `TEST PASS`; seed `20261023` records 21/21 overlap and ordered-drain
checks. The focused `ai_smoke` and `ai_run` commands also pass.

The dispatcher formal gate is:

```sh
make -C dv/subsystem/tensor_datapath/formal dispatcher-pairs \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf \
  OUT=/tmp/nmaforge_parallel_dispatcher_formal_fullproof_20261023 TIMEOUT=360
```

VC Formal `V-2023.12-SP2` reports clean setup, 5/5 assertions proven, four
antecedent properties non-vacuous, and 23/23 covers reached (21 pairs, all
seven engines busy, and abort with active engines). The bounded abort-drain
assertion converged at safe depth 130 in about 305 seconds. This harness uses
seven representative descriptors and abstract engine completion; top smoke
supplies integrated-engine evidence.

The refreshed VCS `V-2023.12-SP1_Full64` / URG `V-2023.12-SP1` report is under
`/tmp/nmaforge_compute_cluster_parallel_final_20261023/dut_coverage/`. Across
29 test instances, weighted `rtl/compute` bin coverage is **92.69% line /
90.00% condition / 54.67% FSM transitions / 87.31% branch** (2,002/2,160;
1,449/1,610; 205/375; 681/780). The five-seed top DUT-only `rtl/compute`
slice is **83.79% / 66.39% / 41.60% / 69.19%**. Dispatcher coverage is
91.70% / 66.91% / 75.00% / 71.43%; shared-SPAD mux coverage is 100.00% /
75.00% / N/A / 100.00%. Of the 23 compute definitions, 20 source modules have
executable bins and three wiring-only wrappers are N/A. Coverage remains
partial.
