# A10 V1-FP-04 `ST_WRITE` owner lemma and parity/writeback retry

## Scope and source

- Starting `main` SHA: `506e75694860593bb0c4888d9498f35d134867a2`
- Environment: Rocky Linux 8.10, VC Formal `V-2023.12-SP2`
- Artifacts: `/tmp/nmaforge_a10_fp_parity_writeback_owner_composition_retry_20261019/`
- This batch changes only formal harness, Tcl, Makefile, and verification notes.
  Product RTL, SPEC, ABI, and cycle behavior are unchanged.

## FSM entry-owner property

The owner property checks only the edge entering `ST_WRITE`:

```systemverilog
$rose(dut.state_r == ST_WRITE) |-> $past(
  (dut.state_r == ST_RUN) && dut.compute_fire && dut.last_element)
```

This distinction matters because `ST_WRITE` may persist across multiple cycles
while waiting for `spad_ready`. The first diagnostic assertion checked every
cycle spent in `ST_WRITE` and therefore falsified under normal write
back-pressure at depth 7. That was an over-constrained checker, not an RTL
counterexample. The corrected entry-edge assertion was rerun in a fresh output
directory.

Command:

```sh
make -C dv/block/compute/fp/formal parity-full-writeback-owner VCF=vcf \
  OUT=/tmp/nmaforge_a10_fp_parity_writeback_owner_composition_retry_20261019/state_owner \
  FORMAL_PROBE_TIMEOUT=90
```

Result: clean setup; one assertion proven and non-vacuous (`safe_depth=145`);
one `ST_WRITE` reachability cover reached at depth 6. Total VCF wall time was
31.83 s; peak reported process memory was 1295 MB.

## Full-domain parity/writeback composition

The lean control-cone wrapper uses constant arithmetic stubs and the previously
proven response-index/parity-cutoff lemmas plus the new `ST_WRITE` entry-owner
lemma as explicit assumptions. It is not an arithmetic proof. The goal remains
to prove that a pending parity error cannot coexist with a scratchpad result
write.

Command:

```sh
make -C dv/block/compute/fp/formal parity-full-writeback-control-lean VCF=vcf \
  OUT=/tmp/nmaforge_a10_fp_parity_writeback_owner_composition_retry_20261019/writeback \
  FORMAL_PROBE_TIMEOUT=150
```

Result: setup clean and the assertion antecedent non-vacuous, but the property
remained `checking` until the 150 s timeout (Make exit 124). There was no proof
or counterexample. The two cover queries were not reached because the assertion
is checked first. A read-only post-timeout audit found no remaining `vcf`,
`vc_static_shell`, or `Simon` process.

## Disposition

The FSM entry-owner fact is now closed under the stated assumptions. The
full-domain parity/writeback interaction is still inconclusive and remains
open under V1-FP-04; this run is not a formal PASS for the core lifecycle.
No product behavior was modified. Continue with a smaller proof partition or a
proof-friendly invariant that preserves the full 16-bit length and current
ordered-response contract; do not strengthen assumptions with unproven
parity-unreachability claims.
