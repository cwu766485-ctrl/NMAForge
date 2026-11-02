# Compute Cluster descriptor dimension-boundary characterization — R187

**Run ID:** `R187-DESC-BOUNDARY-VALIDATOR-20261102`  
**Result:** PASS, scoped to the combinational validator's current dimension predicates.  
**Local source/test SHA:** `cf38ece103afaa2903499018eeb54cb474c1aa38`  
**Published same-tree commit:** `81201e178f6c2147399b563ec9c79f0f7aad796b`  
**Tree:** `a67865073ba2d88ae9b88282e40d4ca8d93916ed`  
**Tool:** Synopsys VCS `V-2023.12-SP1_Full64`.

## Command and result

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
make -C dv/block/control/sim descriptor-validator-regress \
  DESCRIPTOR_VALIDATOR_OUT=/tmp/nmaforge_r187_descriptor_boundary_retry \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1'
```

The Make target exits 0 with:

```text
DESCRIPTOR_VALIDATOR_PASS legal_opcodes=27 tile_pack=1 invalid_rules=21 boundary_accept=38/38 boundary_reject=26/26 opcode_classes_consistent=1 engine_limit_claim=0
```

VCS compile log: `/tmp/nmaforge_r187_descriptor_boundary_retry/compile.log`  
VCS run log: `/tmp/nmaforge_r187_descriptor_boundary_retry/run.log`

| Artifact | SHA-256 |
|---|---|
| `compile.log` | `c78a9c8c3fc41587d5432075634d080c0d1e35489c9d283ea3e4c56141f4eee1` |
| `run.log` | `95b09179c753fe43935b2841a9d42515a608ef2ff5485d637aa36bc4add80a83` |

No `Warning-`, `Error-`, or `TFIPC` compile diagnostics were found.

## Coverage scope

The existing 27-opcode decode, Matrix A tile-pack, and 21 negative-rule checks remain mandatory. Added directed boundaries cover minimum and maximum encoded values for applicable scalar, CNM, Matrix, SFU, Conv, KV, FP-dot, and macro dimension predicates; below-minimum or just-outside values are checked against both `dimensions_valid` and `descriptor_invalid`. The 38 accepted and 26 rejected boundary vectors all execute in this run.

This is a combinational validator test. It does not fetch CMDQ descriptors, launch engines, exercise the SPAD, prove arithmetic/address safety, or validate the full memory image. In particular, the validator accepts some maximum 16-bit field values. Those vectors characterize current validator behavior only; they are **not** claims that an engine or memory map supports those workloads. SPEC v1.8 still leaves per-opcode maximum dimensions, stride, aliasing, and address-overflow contracts open.

No RTL or SPEC changed. `REQ-CL-002`, `REQ-CL-015`, `REQ-CL-020`, and `OPEN-CL-002` remain as previously dispositioned; the total remains 24 `PASS-SCOPED` / 14 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.
