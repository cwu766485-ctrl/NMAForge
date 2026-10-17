# FP core formal invariants

Run from the Rocky Linux shell with the VC Formal license environment loaded:

```sh
make -C dv/block/compute/fp/formal run
```

The target proves twelve focused control invariants for the current
`ai_mixed_precision_dot_fp32_core`: read enable is confined to `ST_RUN`,
write-protection failure occurs only in `ST_WRITE`, `ST_WRITE` always presents
a write request, write-protection failure is mutually exclusive with `ST_RUN`,
a valid memory-error cutoff corresponds to a parity/protection error,
outstanding reads never exceed the two-entry contract, a full queue blocks an
unpaired read, zero outstanding reads imply no response, and the active-failure
OR has at least one asserted source. Three additional properties separately
prove that `ERR_ABORT`, `ERR_CONFIG`, and `ERR_WATCHDOG` are not pending while
the FSM is in `ST_WRITE`; these disposition the corresponding prior-error to
`ERR_PROTECTION` transitions as unreachable in this formal model. The full
parity-error-to-writeback disposition remains open because its focused
lifecycle proof did not converge within the bounded exploratory run. A
narrower property now proves that an already-pending parity error blocks a
final-element compute; this does not establish the upstream parity transition
or the full writeback exclusion. Response-related checks use the explicit
registered-SPAD environment assumption (`spad_rsp_valid` only when an
accepted read is outstanding). The flow also covers the legal operand-wait
state. A second cover checks whether an operand pair can already be ready after
the memory-error cutoff suppresses compute; this helps classify the remaining
compute condition outcome.

The Tcl flow creates a 10 ns formal clock, simulates two reset-active clock
edges with deterministic default inputs, and saves the resulting asynchronous
reset state before proving post-reset invariants. Reset is released for formal
analysis; the proof does not establish reset-release behavior or RDC signoff.
The setup gate requires zero reset and clock violations. The harness does not
prove all URG residuals or the prior-error-to-writeback lifecycle. A separate
writeback/error assertion experiment did not converge within the exploratory
runtime budget and was stopped; it is neither a pass nor a DUT failure.

Validated on VC Formal V-2023.12-SP2, Rocky Linux 8.10. The latest run proved
12/12 assertions and reached both covers; its exact command and log path are
recorded in the A10 verification run log. The ready-pair/error-cutoff condition
is also exercised in the late-B protection UVM case, twice per format/seed
(six hits after the three-seed URG merge). A broad `ST_WRITE ->
pending_error_r == ERR_NONE` property did not converge; a parity-only exclusion
also failed to converge within the exploratory time budget. Neither result is
a counterexample. The corresponding parity-to-protection transition and other
URG condition/branch residuals remain open. The reset-initialized proof does
not establish reset-release behavior or RDC signoff.

## URG residuals mapped to proof or protocol

The three-seed merged URG report for the current worktree records six
uncovered condition outcomes and four uncovered branch outcomes in the core.
The condition/branch bins are not all independent bugs; the following map ties
each residual class to the relevant proof or interface constraint:

| URG residual | Disposition |
| --- | --- |
| Request predicate true outside `ST_RUN` (conditions at RTL lines 142 and 83) | `ap_read_enable_only_in_run` is non-vacuously proven. |
| Response observed with zero outstanding reads (condition at line 180 and `2'b01` branch) | The registered-SPAD environment assumption forbids this illegal response; `ap_zero_outstanding_has_no_response` is proven under that assumption. This is protocol-constrained, not a standalone product-input guarantee. |
| Error cutoff valid while pending error is neither parity nor protection (line 75) | `ap_cutoff_valid_tracks_memory_error` is non-vacuously proven. |
| `ST_WRITE` with no valid write request (assertion-level invariant; not the raw write-protection predicate) | `ap_write_state_has_valid_write_request` is non-vacuously proven. Do not map this assertion to RTL line 78's `write_protection_failure` expression. |
| Write-protection failure in `ST_RUN` (line 110 and the failure-source priority branch) | The write-protection state/exclusivity assertions are proven. |
| Read issue while both outstanding slots are full and no response retires (the `2'b10` / full-count branch) | `ap_full_outstanding_blocks_unpaired_read` is non-vacuously proven. |
| Failure-active condition with no recognized error source (missing `else` in the priority chain) | `ap_failure_active_has_a_source` is non-vacuously proven. |
| RTL line 78 raw condition tuples | In the dedicated single-seed report `(0,1,1,1)` was `Not Covered`; the current three-seed merged `modinfo.txt` shows `(0,1,1,1)` is `Covered` and `(1,0,1,1)` is raw `Not Covered`. The latter has a formal disposition: `ap_write_state_has_valid_write_request` in `ai_fp_core_formal_top.sv` asserts `(state_r==ST_WRITE) |-> (spad_valid && spad_write)` and was non-vacuously proven in the canonical 12/12 assertion run. This dispositions the raw bin via the proven write-state invariant; it does not change the URG bin to covered and depends on that formal proof. The read-side `cp_read_protection_not_write_failure` cover is not the basis for either tuple's status. V1-FP-04 remains open for other raw/formal residuals, including the inconclusive full-domain parity-to-protection/writeback lifecycle proof. See the [2026-10-17 run record](../../../../../docs/verification/A10_DV_RUN_2026-10-17.md). |

The `pending_error_r` transition bins are separate from these condition/branch
outcomes. The `ERR_ABORT`, `ERR_CONFIG`, and `ERR_WATCHDOG`
prior-error-to-protection transitions are excluded by the three new
non-vacuous assertions. The parity-to-protection transition remains open: its
focused assertion did not converge within the exploratory runtime budget, so
it is not marked unreachable and no URG exclusion is applied.

## 2026-10-17 parity reachability probe

The canonical target was rerun after adding supplemental parity lemmas:

```sh
make -C dv/block/compute/fp/formal run VCF=vcf \
  OUT=/tmp/nmaforge_a10_formal_canonical_replay_20261017
```

The Makefile gates passed: 12/12 selected assertions, both selected covers,
and no formal setup issues. A separate clean-setup cover search for
`ST_WRITE && pending_error_r == ERR_PARITY` used:

```sh
make -C dv/block/compute/fp/formal parity-reach VCF=vcf \
  OUT=/tmp/nmaforge_a10_parity_reach_checked_20261017 \
  FORMAL_PROBE_TIMEOUT=120
```

Setup was clean, but the cover remained in `checking` until the 120-second
timeout (Make exit 124); it produced no trace. This is not an unreachability
proof and not a counterexample. A separate helper-lemma experiment proved only
the accepted-read/returned-read accounting relation before its remaining
properties were interrupted at the resource bound; that run omitted the setup
gate and is not counted as acceptance evidence. No URG exclusion was added,
and no product RTL changed. The parity-to-protection transition remains open.

## 2026-10-17 standalone parity-exclusion proof

To remove solver contention from the earlier helper-property experiment, the
parity-only assertion was also checked by itself with the same reset
initialization and registered-SPAD environment contract:

```sh
make -C dv/block/compute/fp/formal parity-exclusion VCF=vcf \
  OUT=/tmp/nmaforge_a10_parity_exclusion_solo_20261017 \
  FORMAL_PROBE_TIMEOUT=150
```

Setup checks were clean and the assertion was classified non-vacuous, but VC
Formal remained in `checking` until the 150-second timeout (Make exit 124).
There was no counterexample or proof result. The exact child process was
checked after timeout and was no longer running. This standalone attempt is
inconclusive; parity-to-`ST_WRITE` remains open and no URG exclusion is
justified. No product RTL changed.

The follow-up isolated candidate lemma,
`ap_new_memory_error_cutoff_precedes_length`, used the same reset/environment
setup:

```sh
make -C dv/block/compute/fp/formal parity-cutoff-bound VCF=vcf \
  OUT=/tmp/nmaforge_a10_parity_cutoff_bound_20261017 \
  FORMAL_PROBE_TIMEOUT=150
```

Setup was clean and the assertion was non-vacuous, but it remained in
`checking` through the 150-second timeout (Make exit 124). No counterexample
or proof was produced, and no matching VC Formal process remained afterward.
The candidate lemma is therefore not established and is not used as an
assumption; the parity disposition remains open.

A second isolated candidate lemma,
`ap_compute_within_returned_pair_frontier`, was checked with the same
reset/environment setup:

```sh
make -C dv/block/compute/fp/formal parity-frontier VCF=vcf \
  OUT=/tmp/nmaforge_a10_parity_frontier_20261017 \
  FORMAL_PROBE_TIMEOUT=150
```

Setup was clean and the assertion non-vacuous, but the proof also remained in
`checking` until the 150-second timeout (Make exit 124), with no counterexample
or proof result. No matching VC Formal process remained afterward. This
candidate is not established or assumed; simulation/coverage evidence does
not replace the open formal disposition.

## 2026-10-17 bounded short-vector parity proof

Added a separate formal top for representative vector lengths 1 through 4,
covering odd/even tails while retaining the real two-read slots and ordered
registered-SPAD response behavior. The environment constrains accepted starts
to aligned addresses, watchdog disabled, and abort deasserted; response-valid
is only allowed when a read is outstanding.

Command:

    make -C dv/block/compute/fp/formal parity-bounded VCF=vcf \
      OUT=/tmp/nmaforge_a10_parity_bounded_20261017 FORMAL_PROBE_TIMEOUT=180

Result: clean setup; 5/5 assertions proven and non-vacuous. The two covers
(parity response with two reads outstanding, and parity error retirement)
were both reached at depth 5. The Makefile acceptance gate was separately
applied to this fresh log and passed.

This is a bounded-length proof only. It does not establish the parity
writeback exclusion for the full 16-bit product length range, arbitrary abort
or watchdog interaction, reset-release/RDC behavior, or the parity-to-
protection transition across all states. Those remain open; no URG bins are
waived from this result.

## 2026-10-17 corrected harness and full-domain parity refinement

The parameterized harness also contains a direct full-domain top for every
nonzero 16-bit length. A first read-accounting attempt used nonexistent DUT
names `request_is_b`/`response_is_b` and generated XMR elaboration errors; its
depth-1 failure is invalid and was discarded. The references were corrected
to the RTL registers `request_is_b_r`/`response_is_b_r`. The read-accounting
assertion then proved across the full length domain with clean setup and no
XMR errors:

```sh
make -C dv/block/compute/fp/formal parity-full-accounting VCF=vcf \
  OUT=/tmp/nmaforge_a10_parity_full_accounting_20261017 \
  FORMAL_PROBE_TIMEOUT=180
```

The corrected full-domain campaign uses aligned operand/result bases, disables
abort and watchdog, and constrains `spad_rsp_valid` only to require at least
one outstanding read; request back-pressure and response delay remain
otherwise unconstrained. Clean setup and non-vacuity were observed. Three of
six selected assertions proved: read request/response accounting, no compute
at or beyond the first parity cutoff, and transition to `ST_ERROR` after
outstanding reads drain. The other three cutoff/progress/writeback properties
remained in `checking` at the 240-second limit. The isolated full-domain
cutoff inequality also remained in `checking` at 240 seconds. Neither run
produced a counterexample; both timeouts are inconclusive. The full-domain
covers did not complete before timeout. Thus the full 16-bit parity safety
disposition is still open, and no assumption or URG exclusion is justified by
these partial results.

Separately, the request-cursor invariant was proved across the same full
nonzero length domain:

```sh
make -C dv/block/compute/fp/formal parity-full-index-bound VCF=vcf \
  OUT=/tmp/nmaforge_a10_parity_full_index_bound_20261017 \
  FORMAL_PROBE_TIMEOUT=180
```

`ap_request_index_not_past_end` proved non-vacuous with clean setup. This gives
a useful input-word boundary lemma; the full-domain parity cutoff remains
open.

The accepted-read count was then bounded by twice the required packed-word
count over the same full 16-bit nonzero length domain:

```sh
make -C dv/block/compute/fp/formal parity-full-accepted-count-bound VCF=vcf \
  OUT=/tmp/nmaforge_a10_parity_full_accepted_count_bound_20261017 \
  FORMAL_PROBE_TIMEOUT=180
```

Result: PASS with clean setup; the unconditional assertion proved in 94 seconds
of property runtime. Together with the previously proven read-accounting
relation, it establishes that a legal outstanding response cannot be beyond
the accepted-read frontier. A separate assume-guarantee wrapper was added so
these previously proven lemmas do not become assumptions in the canonical
parity campaign. It reuses the same reset, aligned-start, no-abort,
watchdog-disabled, and legal registered-SPAD-response contract, and assumes
only the two independently proven read-count lemmas:

```sh
make -C dv/block/compute/fp/formal parity-full-response-assume VCF=vcf \
  OUT=/tmp/nmaforge_a10_parity_full_response_assume_20261017 \
  FORMAL_PROBE_TIMEOUT=180
```

Result: PASS; the full-domain response-index-within-end assertion was proven
non-vacuous in 3 seconds of property runtime, with clean setup and no XMR
errors. This is a sound layered proof only under those documented and
independently proven lemmas; it does not close parity cutoff, error drain,
writeback exclusion, arbitrary reset/abort/watchdog behavior, or reset-release
RDC. Those remain open and are not waived.

Using that independently proven response-index bound, the full-domain parity
cutoff validity property also proved non-vacuously:

```sh
make -C dv/block/compute/fp/formal parity-full-cutoff-assume VCF=vcf \
  OUT=/tmp/nmaforge_a10_parity_full_cutoff_assume_20261017 \
  FORMAL_PROBE_TIMEOUT=180
```

Result: PASS with clean setup, no XMR errors, and a non-vacuous property in 33
seconds of property runtime. The helper asserts that whenever the DUT records
`ERR_PARITY`, the cutoff-valid bit is set and the cutoff index is strictly
below the task length. The helper assumes only the separately proven
response-index bound plus the same reset/start/SPAD environment; it does not
assume parity retirement or compute/writeback behavior. Full-domain
progress-before-cutoff and writeback exclusion remain open.

An additional refinement selected both full-domain parity progress and
writeback-exclusion properties while assuming the independently proven
response-index and parity-cutoff-bound lemmas under the same environment:

```sh
make -C dv/block/compute/fp/formal parity-full-lifecycle-assume VCF=vcf \
  OUT=/tmp/nmaforge_a10_parity_full_lifecycle_assume_20261017 \
  FORMAL_PROBE_TIMEOUT=180
```

Setup was clean and both properties were non-vacuous, but neither had a proof
result at the 180-second timeout (Make exit 124). No counterexample was
reported, and the timed-out VC Formal process was confirmed stopped. This is
inconclusive, not PASS; the two lifecycle properties remain open.

To rule out solver contention between the two properties, each was then run
alone using the same assumptions and 180-second budget:

```sh
make -C dv/block/compute/fp/formal parity-full-progress-assume VCF=vcf \
  OUT=/tmp/nmaforge_a10_parity_full_progress_assume_20261017 \
  FORMAL_PROBE_TIMEOUT=180
make -C dv/block/compute/fp/formal parity-full-writeback-assume VCF=vcf \
  OUT=/tmp/nmaforge_a10_parity_full_writeback_assume_20261017 \
  FORMAL_PROBE_TIMEOUT=180
```

Both isolated runs again had clean setup and non-vacuous properties, but each
timed out at 180 seconds without a proof result or counterexample. No VC
Formal process remained after cleanup. The timeout is property-specific, not
caused by running the two properties concurrently.

The short-vector 1..4 parity target was rerun after correcting the harness and
passed its Makefile gate again: 5/5 selected assertions proven/non-vacuous and
both parity covers reached at depth 5. Product RTL was unchanged. See the
[2026-10-17 A10 run record](../../../../../docs/verification/A10_DV_RUN_2026-10-17.md)
for exact commands and output paths.

## Full-domain pair-slot ghost-tag refinement

To strengthen the full-domain returned-data frontier proof without changing
the product RTL, the lifecycle formal wrapper now tracks a harness-only packed
word tag whenever each A/B pair slot captures a non-parity SPAD response. The
ghost state is reset with task start and does not constrain DUT inputs or
outputs. The paired-slot assertions were run with the same full-domain legal
SPAD, aligned-start, abort-inactive, watchdog-disabled contract and the
separately proven response-index/cutoff assumptions:

```sh
make -C dv/block/compute/fp/formal parity-full-pair-tag-match VCF=vcf \
  OUT=/tmp/nmaforge_a10_parity_full_pair_tag_match_20261017 \
  FORMAL_PROBE_TIMEOUT=180
```

VC Formal V-2023.12-SP2 reported clean setup and proved both non-vacuous
assertions: each pair slot's A and B data are tagged with the same packed-word
index (14 s for slot 0; 18 s for slot 1). This establishes pair assembly, not
that the currently selected pair matches the accumulator element or parity
cutoff.

Two follow-up full-domain properties were non-vacuous with clean setup but
inconclusive at 180 s (Make exit 124), without counterexamples:

```sh
make -C dv/block/compute/fp/formal parity-full-current-pair-tag VCF=vcf \
  OUT=/tmp/nmaforge_a10_parity_full_current_pair_tag_20261017 \
  FORMAL_PROBE_TIMEOUT=180
make -C dv/block/compute/fp/formal parity-full-tag-response-bound VCF=vcf \
  OUT=/tmp/nmaforge_a10_parity_full_tag_response_bound_20261017 \
  FORMAL_PROBE_TIMEOUT=180
```

The first checks the selected ready-pair tag against `element_index >> 1`; the
second checks that its packed word has advanced the response cursor. Neither
result closes the data-frontier or parity-progress/writeback properties. No
URG exclusion or product-RTL conclusion is drawn from these timeouts.

### Arithmetic-free control abstraction probe

To check whether floating-point arithmetic dominated the current-element
pair-tag proof, the formal-only control harness substitutes constant outputs
for the BF16/FP16 multipliers and FP32 accumulator. The abstraction leaves the
FP core's request/response, pair slots, indices, parity state, and FSM intact;
it neither changes product RTL nor constrains legal inputs.

```sh
make -C dv/block/compute/fp/formal parity-full-current-pair-tag-control-abstract \
  VCF=vcf OUT=/tmp/nmaforge_a10_parity_current_pair_tag_control_abstract_20261017 \
  FORMAL_PROBE_TIMEOUT=180
make -C dv/block/compute/fp/formal parity-full-static-slot-tags \
  VCF=vcf OUT=/tmp/nmaforge_a10_parity_static_slot_tags_20261017 \
  FORMAL_PROBE_TIMEOUT=180
```

Both runs reported clean setup and non-vacuous properties, but timed out at
180 seconds with no proof result or counterexample. The control-abstract
current-tag cone remained about 3,331 gates / 238 registers; the two static
slot-tag assertions used about 3,369 gates / 240 registers. Replacing
arithmetic therefore did not materially shrink the difficult proof cone. The
remaining open relation is between the ordered response cursor, pair-slot
ownership tags, and element retirement. These are diagnostic timeouts, not
PASS and not a reason to waive coverage. Avoid further equivalent property
variants until the invariant is decomposed into smaller, independently
provable lemmas.

### 2026-10-17 V1 transition-lemma probe (latest evidence)

On Rocky Linux 8.10 / VC Formal `V-2023.12-SP2`, two formal-only helper
properties, `ap_new_parity_blocks_last_compute` and
`ap_last_compute_does_not_set_parity`, were selected with the existing
`ap_writeback_excludes_pending_parity`. The probe used only the independently
proven full-domain response-index/cutoff validity assumptions and the
existing reset/start/SPAD environment; it did not assume parity or `ST_WRITE`
was unreachable.

```sh
make -C dv/block/compute/fp/formal parity-full-transition-lemmas VCF=vcf \
  OUT=/tmp/nmaforge_a10_parity_transition_lemmas_20261017 FORMAL_PROBE_TIMEOUT=120
make -C dv/block/compute/fp/formal parity-full-local-transition-lemmas VCF=vcf \
  OUT=/tmp/nmaforge_a10_parity_local_transition_lemmas_20261017 FORMAL_PROBE_TIMEOUT=90
```

Setup was clean; the combined three-property run and the isolated two-helper
run were non-vacuous and checking at timeout, with no proof result or
counterexample (Make exit 124). No residual `vcf`, `vc_static`, or `simon`
process remained on read-only post-timeout inspection. The result is
inconclusive, not PASS and not a DUT failure; no waiver/URG exclusion was
added. Full-domain parity-to-protection remains OPEN, and product RTL was
unchanged.

### 2026-10-17 fresh short-domain and canonical replay

After adding the odd-length final-packed-word parity UVM cases, reran the
bounded short-vector proof in a fresh output directory. The 180-second replay
proved three of five properties before its cap, with two still checking and no
counterexample; it is inconclusive. Increasing the same run's external solver
budget to 360 seconds allowed the remaining two properties to converge:

```sh
make -C dv/block/compute/fp/formal parity-bounded VCF=vcf \
  OUT=/tmp/nmaforge_a10_fp_odd_tail_parity_bounded_360_20261017 \
  FORMAL_PROBE_TIMEOUT=360
```

Result: clean setup, 5/5 selected assertions proven and non-vacuous, and both
parity covers reached at depth 5. This remains a bounded length-1..4 proof
under the documented aligned-start, no-abort, watchdog-disabled, ordered
registered-SPAD-response contract; it is not a full 16-bit length proof.
The fresh reset-initialized canonical target was also rerun:

```sh
make -C dv/block/compute/fp/formal run VCF=vcf \
  OUT=/tmp/nmaforge_a10_fp_odd_tail_parity_canonical_20261017
```

Result: clean setup, 12/12 selected assertions proven, and 2/2 selected covers
reached. As before, `ap_write_state_excludes_parity_error` and the
`cp_write_pending_parity` reachability probe are not closed by this canonical
run. Full-domain parity progress/writeback disposition and reset-release/RDC
remain open; the two timeouts are not counterexamples and are not used as
assumptions or waivers. Product RTL was unchanged.

### 2026-10-17 isolated full-domain writeback retry

With the Rocky VC Formal license active, reran only
`ap_writeback_excludes_pending_parity` using the independently proved
response-index/cutoff lemmas and the documented reset/start/SPAD assumptions:

```sh
make -C dv/block/compute/fp/formal parity-full-writeback-assume VCF=vcf \
  OUT=/tmp/nmaforge_a10_parity_full_writeback_600_20261017 \
  FORMAL_PROBE_TIMEOUT=600
```

VC Formal `V-2023.12-SP2` reported clean setup and non-vacuous property
activation, but remained in `checking` until the 600-second timeout (Make exit
124). There was no counterexample and no proof result; the formal process was
absent after timeout. This remains inconclusive: parity-to-`ST_WRITE` is still
OPEN, and no URG transition or condition is waived.

A transition-local verification-only assertion was then added to check that a
real final-element `compute_fire` in `ST_RUN` leads to `ST_WRITE` with no
pending parity error on the next sample. It adds no assumption and uses the
same full 16-bit-length environment contract:

```sh
make -C dv/block/compute/fp/formal parity-full-last-compute-write-transition \
  VCF=vcf OUT=/tmp/nmaforge_a10_fp_last_compute_write_transition_20261017
```

VC Formal setup was clean and the property was non-vacuous, but it remained in
`checking` through the 120-second timeout (Make exit 124), with no
counterexample or proof result. The process was absent after timeout. The
property therefore remains inconclusive; the full-domain parity-to-writeback
disposition is still open.

### 2026-10-17 isolated full-domain last-compute state transition

To narrow the preceding combined transition probe, the state-only property
`ap_last_compute_enters_write_state` checks that a real final-element
`compute_fire` in `ST_RUN` is followed by `ST_WRITE`, without checking the
pending parity value and without adding assumptions:

```sh
make -C dv/block/compute/fp/formal parity-full-last-compute-write-state \
  VCF=vcf OUT=/tmp/nmaforge_a10_fp_last_compute_write_state_20261017
```

Rocky Linux 8.10 / VC Formal `V-2023.12-SP2`: setup clean; the property was
non-vacuous, but remained in `checking` through the 120-second timeout (Make
exit 124). There was no counterexample or proof result; post-timeout audit
confirmed no residual VCF process. This is inconclusive, not PASS, and
V1-FP-04 remains OPEN. Exact output artifact directory:
`/tmp/nmaforge_a10_fp_last_compute_write_state_20261017/`. No assumption was
added; production RTL, SPEC, and ABI were unchanged.

### 2026-10-17 full-domain control-abstraction retry

The isolated target `make -C dv/block/compute/fp/formal
parity-full-writeback-control-abstract VCF=vcf` ran with VC Formal
`V-2023.12-SP2` on Rocky Linux 8.10. Its output is
`runs/fp_core_formal_20261017_205021/vc_formal.log`. Setup was clean, no
formal error was reported, and `ap_writeback_excludes_pending_parity` was
non-vacuous under the constant-output arithmetic stubs. It remained in
`checking` until the default 150-second timeout (Make exit 124), with no
counterexample or proof. The assertion query timed out before the two cover
queries, so parity-response-at-two-outstanding and parity-error-retirement
were not executed and have no coverage conclusion. This control abstraction
does not establish arithmetic/data correctness. Linux bridge PID audit found
no VCF child remaining from this target. V1-FP-04 remains OPEN; no product RTL,
SPEC, or ABI changed.

### 2026-10-18 isolated pending-parity final-compute guard

To test a smaller local boundary without repeating the full writeback query,
the existing lifecycle wrapper selected only
`ap_pending_parity_blocks_last_compute`. The property checks that when parity
is already pending and the current element is the final element, the core
does not assert `compute_fire` on that sample. It uses the existing documented
SPAD/reset environment and full-domain cutoff-validity assumption; it does not
assume parity or `ST_WRITE` unreachable.

```sh
make -C dv/block/compute/fp/formal parity-full-pending-last-compute \
  VCF=vcf OUT=/tmp/nmaforge_a10_fp_pending_parity_last_compute_20261018 \
  FORMAL_PROBE_TIMEOUT=180
```

Rocky Linux 8.10 / VC Formal `V-2023.12-SP2`: exit 0; setup reported
`No setup issues found`; the selected assertion was proven and non-vacuous
(safe depth 122, vacuity depth 4). The target also checked its formal-log
error gate. This establishes only the local pending-parity/final-element
compute suppression guard. The full `ST_WRITE -> pending_error_r !=
ERR_PARITY` relation, parity-to-protection disposition, and V1-FP-04 remain
OPEN; no URG exclusion or assumption was added. Product RTL, SPEC, and ABI
were unchanged. Output:
`/tmp/nmaforge_a10_fp_pending_parity_last_compute_20261018/vc_formal.log`.

### 2026-10-18 same-cycle parity/final-compute probe

The adjacent transition-local property `ap_new_parity_blocks_last_compute`
checks whether a parity failure arriving on the current cycle can coincide
with final-element `compute_fire`. It was selected alone with the same
full-domain lifecycle wrapper and a 90-second cap:

```sh
make -C dv/block/compute/fp/formal parity-full-new-parity-last-compute \
  VCF=vcf OUT=/tmp/nmaforge_a10_fp_new_parity_last_compute_20261018 \
  FORMAL_PROBE_TIMEOUT=90
```

VC Formal `V-2023.12-SP2` reported clean setup and the assertion's antecedent
was non-vacuous, but the proof remained in `checking` until the external
timeout (Make exit 124). The log contains neither a proof result nor a
counterexample. This is inconclusive, not PASS or RTL failure; do not use it
as an assumption or coverage waiver. Do not rerun the same query with a larger
budget absent a changed proof strategy. Log:
`/tmp/nmaforge_a10_fp_new_parity_last_compute_20261018/vc_formal.log`.

The supporting arithmetic boundary was isolated separately as
`ap_parity_cutoff_not_after_last_element`: under the existing full-domain
response-index assumption, a legal parity response while at the final element
must yield `memory_error_cutoff_now <= element_index_r`. This property is
purely a local cutoff/length relation; it does not assert or assume the compute
suppression result.

```sh
make -C dv/block/compute/fp/formal parity-full-parity-cutoff-last-element \
  VCF=vcf OUT=/tmp/nmaforge_a10_fp_parity_cutoff_last_element_20261018 \
  FORMAL_PROBE_TIMEOUT=90
```

It proved non-vacuously with clean setup (safe depth 128, vacuity depth 3).
Using the bounded length-1..4 wrapper did not make the same-cycle compute
property converge:

```sh
make -C dv/block/compute/fp/formal parity-bounded-new-parity-last-compute \
  VCF=vcf OUT=/tmp/nmaforge_a10_fp_bounded_new_parity_last_compute_20261018 \
  FORMAL_PROBE_TIMEOUT=90
```

This attempt also remained non-vacuous/checking through 90 seconds with no
counterexample or proof, so it is inconclusive. Its log is
`/tmp/nmaforge_a10_fp_bounded_new_parity_last_compute_20261018/vc_formal.log`.
The original bounded
parity acceptance target was also rerun after making the Tcl property selector
optional; its default property set was unchanged and passed 5/5 non-vacuous
assertions plus 2/2 covers (depths 4 and 5) in 158.20 seconds. This baseline
does not include the new same-cycle property. Do not retry that property with
an unchanged proof strategy.

### 2026-10-18 ready-pair response-frontier lemma

To isolate the ownership/order relation needed to reason about a parity
response coinciding with the final element, ran the existing
`ap_ready_pair_within_returned_frontier` property in a fresh output directory:

```sh
make -C dv/block/compute/fp/formal parity-full-ready-frontier-assume \
  VCF=vcf OUT=/tmp/nmaforge_a10_parity_full_ready_frontier_rerun_20261018 \
  FORMAL_PROBE_TIMEOUT=180
```

VC Formal `V-2023.12-SP2` reported clean setup and a non-vacuous property, but
remained `checking` until the 180-second external timeout (Make exit 124),
without a proof result or counterexample. The initial run directory had a
stale session lock whose recorded PID was absent; that old artifact was left
untouched and the proof was rerun in a fresh directory. A post-timeout audit
found no active VCF/VC Static/Simon process. This is inconclusive, not PASS or
DUT failure. It does not prove that a parity response at the final element
cannot coincide with a ready operand pair, so it cannot be composed with the
cutoff lemma to claim same-cycle compute suppression. Avoid retrying the same
query unchanged; a next attempt needs a materially different inductive
decomposition or a separately proved abstraction. Log:
`/tmp/nmaforge_a10_parity_full_ready_frontier_rerun_20261018/vc_formal.log`.
No product RTL, SPEC, or ABI changed.
