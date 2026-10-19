# A10 V1 FP Parity/Writeback Composition Attempt — 2026-10-19

## Scope and source identity

- Branch: `main`; pre-run HEAD: `64d6d386e2f2ca5aaf62abeae2e588a2971cc5e9`.
- Product FP RTL, SPEC, and ABI were unchanged. This increment adds only a
  formal wrapper, Tcl entry point, Make target, and documentation. The two
  helper targets exercise the production FP RTL; the composed target replaces
  arithmetic modules with constant-output stubs and checks control only.
- Tool environment: Rocky Linux 8.10, VC Formal `V-2023.12-SP2`.
- Local `tools/rocky-bridge.tasks.json` is machine-specific and untracked; it
  was used to invoke the reviewed Rocky task and is not part of this evidence
  commit.

## Formal decomposition

The full-domain safety goal is:

```text
ST_WRITE -> pending_error_r != ERR_PARITY
```

The new lean wrapper keeps the existing legal descriptor constraints (nonzero
length, aligned source/destination addresses, watchdog disabled, abort
inactive), reset initialization, and registered-SPAD response contract. It
also uses previously checked response-index and parity-cutoff bounds. To
strengthen the writeback cone, the wrapper assumes two local lemmas which are
proved independently in this run under the matching full-domain lifecycle
contract:

1. If parity is already pending at the final element, `compute_fire` is low.
2. If a parity response arrives at the final element, its memory-error cutoff
   is no later than that element.

These are explicit assume-guarantee proof inputs, not DUT assumptions about
parity being unreachable. The arithmetic stubs mean this target makes no
claim about FP numerical correctness or result data.

## Commands and results

The reviewed bridge task ran the following commands sequentially:

```sh
make -C dv/block/compute/fp/formal parity-full-pending-last-compute \
  VCF=vcf OUT=/tmp/nmaforge_a10_fp_parity_writeback_composition_20261019/pending_parity \
  FORMAL_PROBE_TIMEOUT=180
make -C dv/block/compute/fp/formal parity-full-parity-cutoff-last-element \
  VCF=vcf OUT=/tmp/nmaforge_a10_fp_parity_writeback_composition_20261019/same_cycle_cutoff \
  FORMAL_PROBE_TIMEOUT=90
make -C dv/block/compute/fp/formal parity-full-writeback-control-lean \
  VCF=vcf OUT=/tmp/nmaforge_a10_fp_parity_writeback_composition_20261019/writeback \
  FORMAL_PROBE_TIMEOUT=150
```

Results:

- `ap_pending_parity_blocks_last_compute`: clean setup, non-vacuous, proven.
- `ap_parity_cutoff_not_after_last_element`: clean setup, non-vacuous,
  proven.
- `ap_writeback_excludes_pending_parity`: clean setup, non-vacuous, but still
  `checking` at 150 s; Make exited 124. No proof or counterexample was
  produced. The two subsequent cover queries were not run because assertion
  checking timed out first.
- Post-run process audit found no remaining VCF, VC Static, or Simon process.

The helper proofs are useful local verification results, but the composed
full-domain property remains **inconclusive**. Do not claim parity/writeback
formal closure or add an URG exclusion. V1-FP-04 and A10 remain open. Full logs
are under `/tmp/nmaforge_a10_fp_parity_writeback_composition_20261019/` in the
Rocky environment.
