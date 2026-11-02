# Matrix Line contract clean-source replay — R174

## Identity

- Run ID: `R174-MATRIX-LINE-CLEAN-3S-20261102`
- Executed clean source/test SHA: `8a2d5f85add54f81019df1a8d6a29ad08bbe88d6`
- Tree: `9701bcaa7417c0cb7babdeab4996d6714cbbf04f`
- Tool: Synopsys VCS `V-2023.12-SP1_Full64`
- Result: PASS for the named Matrix core numerical/fault regression and Matrix Line contract.

## Reproduction

```sh
make -C dv/block/compute/matrix/sim core-random-regress \
  SEEDS='20261025 20261026 20261027' \
  CORE_OUT_DIR=/tmp/nmaforge_r174_matrix_line_8a2d5f \
  VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1'
```

All three seeds pass 18 numerical/layout cases and 35 directed fault/recovery cases. Each log contains:

```text
MATRIX_LINE_CONTRACT_PASS full_wstrb=1 aligned=1 stalled_stability=312 unaligned_scalar_fallback=1 protection_error=1 partial_zero_wstrb=unsupported
```

The test checks full `WSTRB=16'hffff` only on 16-byte-aligned Line writes, stable address/data/strobe while stalled, the legal four-write scalar fallback for a 4-byte-aligned but non-Line-aligned chunk, and rejection of a Protection-denied Line transaction. Partial/zero WSTRB are expressly unsupported by SPEC v1.5 and were not generated as invalid stimulus.

Compile diagnostics contain no `Warning-`, `Error-`, or `[TFIPC]` entries. Artifact hashes:

| Artifact | SHA-256 |
|---|---|
| `compile.log` | `8af6ba7731a64e16127ba18c5382dbc860229f297f09f025f51e3431e930df0a` |
| seed `20261025` | `f79ffc76d8bff3cfe1e945c02d404eb56e69613f5334b53f4f324db3ede386e8` |
| seed `20261026` | `94558d0a7c9acbdef023039030c3af45f60917508c231dc8d94e374608dae276` |
| seed `20261027` | `f80100022729891ad7d9701b30c88afec84775134b8d6e57b91f31da17e1d576` |

The logs, coverage database, and run manifest are archived at `/tmp/nmaforge_r174_matrix_line_8a2d5f.tar.gz`; archive SHA-256 is `4fbcf8f8d258b137ea351ccae68933a36606169dc15a0cbb923472ef8fa2ec87`.

## Disposition

This is an exact-source replay of the block-level Matrix Line contract. It confirms the frozen alignment, strobe, fallback, stall-stability and Protection rules on the selected source. It does not exercise the full real-top Engine × Fault × Phase × Reset cross or close all `REQ-CL-010`/`CL-COV-002` obligations. The 38-row requirement disposition remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.
