# Compute Cluster descriptor validator boundary regression — R90

**Run ID:** `R90-DESCRIPTOR-VALIDATOR-27OP-21NEG-7837701`  
**Result:** PASS, scoped to the combinational descriptor-validator/opcode-decoder contract.  
**Exact clean source SHA:** `7837701cefe606a01abd517d46788b982da0f2e4`.  
**Tool:** Synopsys VCS `V-2023.12-SP1_Full64`.

## Run

From the clean checkout:

```sh
make -C dv/block/control/sim descriptor-validator-regress \
  DESCRIPTOR_VALIDATOR_OUT=/tmp/nmaforge_descriptor_validator_r90_isolated_7837701
```

The Make target builds in its dedicated `-Mdir` under that output root and exits 0. The run marker is:

```text
DESCRIPTOR_VALIDATOR_PASS legal_opcodes=27 tile_pack=1 invalid_rules=21 opcode_classes_consistent=1
```

Compile and run logs are under `/tmp/nmaforge_descriptor_validator_r90_isolated_7837701/`:

| Artifact | SHA-256 |
|---|---|
| `compile.log` | `1596a9e69cb6db9cd301b030f56394bae5633898800fba2119297e964246cee6` |
| `run.log` | `97c7ce5274f0b72d27a4ddc1ef399be239c574af4519e7b3113dfccc9bdd4d55` |

The compiler log has no `Warning-`, `Error-`, or `[TFIPC]` diagnostics.

## Checked points

- Each of the 27 currently supported opcode values is accepted with a legal representative descriptor and checked against the expected mutually exclusive opcode-decoder class.
- Matrix opcode `0x36` passes its separate A-tile packing case with `M×N == length` and both required flags.
- Twenty-one directed negative cases are rejected: unsupported opcode, zero dimensions/lengths, invalid Matrix tile dimensions, Conv minimum height, FP descriptor version/field/alignment violations, invalid macro child count/alignment/nesting, bias alignment, and invalid Matrix A tile-pack element count.

## Limits and disposition

This test instantiates the production `ai_descriptor_validator` and `ai_accel_opcode_decode` directly. It does not fetch a CMDQ descriptor, observe the top-level launch selection, execute any engine, or check arithmetic/memory results. It therefore adds validator/decode coverage but does **not** close system-level `REQ-CL-002`, the full per-engine descriptor contract in `OPEN-CL-002`, or the 38-requirement sign-off. Requirement dispositions remain 24 PASS-SCOPED / 14 PARTIAL; `CL-DV-v1.0` remains HOLD. Product RTL and SPEC are unchanged.
