# A10 FP Parity-to-Writeback Formal Effort Experiments — 2026-10-19

## Scope

This run continues V1-FP-04 investigation for
`ap_writeback_excludes_pending_parity`:

```text
ST_WRITE -> pending_error_r != ERR_PARITY
```

The existing lean control-cone harness and its previously justified
assume-guarantee constraints were held constant. The arithmetic modules remain
constant-output stubs. No production RTL, specification, ABI, or assumption
was changed. These runs therefore make no arithmetic-result claim.

## High-effort run

Environment: Rocky Linux 8.10, VC Formal / VC Static `V-2023.12-SP2`.

```sh
make -C dv/block/compute/fp/formal \
  parity-full-writeback-control-lean-high VCF=vcf \
  OUT=/tmp/nmaforge_a10_fp_parity_writeback_high_20261019 \
  FORMAL_PROBE_TIMEOUT=300
```

`check_fv_setup` reported `No setup issues found`. The assertion was
non-vacuous. The tool selected its high-effort orchestration, but the property
remained `checking` until the 300 s external timeout (Make exit 124). There was
no proof and no counterexample; the two cover queries following the assertion
were not reached. VC Formal also emitted a deprecation warning for the `high`
effort value. A post-run process audit found no remaining VCF/VC Static/Simon
process.

## Discovery-effort run

```sh
make -C dv/block/compute/fp/formal \
  parity-full-writeback-control-lean-discovery VCF=vcf \
  OUT=/tmp/nmaforge_a10_fp_parity_writeback_discovery_20261019 \
  FORMAL_PROBE_TIMEOUT=300
```

Setup again reported no issues, and the assertion was non-vacuous. VC Formal
selected its competition-based discovery orchestration. The assertion remained
`checking` until the 300 s external timeout (Make exit 124), with no proof or
counterexample; subsequent covers did not run. The tool emitted the same
deprecation warning for `discovery`. A post-run process audit found no
remaining VCF/VC Static/Simon process.

## Tool-option discrepancy

The installed quick-reference PDF lists `no_decompose_expensive` as an effort
recipe, but this installed executable rejects it as an invalid `fml_effort`
value. It reported the accepted values as `{default, high, bug_hunting,
discovery, userorc}`. This attempt stopped before the property check and is not
a design result; no invalid-option target is retained.

## Conclusion

Both supported non-default strategies are **inconclusive**. Neither is a
PASS, and neither falsified the assertion. V1-FP-04 remains open. Do not add
assumptions or mark this property waived based on these timeouts. The exact
logs are retained under the `/tmp` paths above.
