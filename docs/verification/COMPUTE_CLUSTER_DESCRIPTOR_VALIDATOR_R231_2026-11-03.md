# Descriptor Validator Boundary Replay — R231

**Date:** 2026-11-03
**Fixed product/source candidate:** `c5755985b0e5b1e1a850122ece983a37be112272` (`b0ee13ed91399ce0f982c36a6f5e55e9857e2061` tree)
**Executed checkout:** `f1bf681fad7a49618a2f3afc3924390aed31d551`; validator RTL, opcode decoder, testbench, and Makefile are byte-identical to the fixed candidate.
**Tool:** Synopsys VCS `V-2023.12-SP1_Full64`
**Run ID:** `R231-DESCRIPTOR-VALIDATOR-BOUNDARIES-20261103`

## Result

The combinational descriptor-validator regression passed:

```text
DESCRIPTOR_VALIDATOR_PASS legal_opcodes=27 tile_pack=1 invalid_rules=21 boundary_accept=38/38 boundary_reject=26/26 opcode_classes_consistent=1 engine_limit_claim=0
```

This demonstrates the declared validator decode/rule/boundary vectors only. The test explicitly makes no engine-limit claim. It does not establish per-engine maximum shapes, stride/alias behavior, address-overflow handling, or descriptor-to-engine execution and therefore closes no `REQ-CL-002`, `REQ-CL-015`, or `REQ-CL-020` requirement by itself.

## Reproduction and evidence

```sh
make -C dv/block/control/sim descriptor-validator-regress \
  DESCRIPTOR_VALIDATOR_OUT=/tmp/nmaforge_r231_descriptor_validator_closeout_20261103 \
  VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 1'
```

VCS completed compile and simulation with exit status 0. Compile log SHA-256: `e83d5de7b6de8a84f8dfd80336f0bfa8e32d2ce21a8eec890b456b4d8d557718`; run log SHA-256: `ebe0a98066709b6f585d9cc4628bee14eb69badfa3a7c943c05ea6a9bc319e0a`. Logs-only archive: `/tmp/nmaforge_r231_descriptor_validator_20261103.tar.gz`, SHA-256 `5b1c8035aba6d2998bcdfe9ada62e92409cbbebc32b41f6eb3f39ed1b1c4516e`.

No requirement disposition changes. `OPEN-CL-002` remains open, the RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.
