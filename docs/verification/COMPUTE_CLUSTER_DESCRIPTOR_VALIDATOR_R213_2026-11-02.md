# Compute Cluster Descriptor Validator Exact-SHA Replay R213 — 2026-11-02

## Result

**PASS** on the published closeout branch's current executable RTL/test inputs: 27/27 supported opcode classifications, Matrix A tile-pack predicate, 21/21 invalid-rule cases, 38/38 accepted boundary vectors, and 26/26 rejected boundary vectors. The gate also confirms opcode-class consistency and explicitly reports `engine_limit_claim=0`.

- Run ID: `R213-DESC-BOUNDARY-PUBLISHED-20261102`
- Published branch HEAD: `6f2dd5656de2568232bb6e857ea53018a07a0fd2` (documentation-only relative to the tested executable sources)
- Executable source/test identity: code commit `744d99716ce97f92912a4eda490eac27d2d9056a`
- Tool: Synopsys VCS `V-2023.12-SP1_Full64`
- Command, from `dv/block/control/sim`: `make descriptor-validator-regress DESCRIPTOR_VALIDATOR_OUT=/tmp/nmaforge_r213_descriptor_validator_20261102`
- Compile log: `/tmp/nmaforge_r213_descriptor_validator_20261102/compile.log`, SHA-256 `7417d20f434f5d1409074e1f1585285c77a290a22bcc848c11c40155a8b1217f`
- Run log: `/tmp/nmaforge_r213_descriptor_validator_20261102/run.log`, SHA-256 `52cea68cc0b2c9e8d74393d292a5d33731208f766c67e229aac4520e039746f7`

The compile log has no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. Simulator ASLR informational output is not a design warning.

## Scope and remaining issue

This is a combinational descriptor-validator replay. Encoded dimension values accepted by the validator are not automatically proven legal engine workloads. It does not test CMDQ-to-engine launch, memory-range safety, per-opcode stride/alias constraints, or address-overflow behavior. `OPEN-CL-002` remains open, `REQ-CL-002/015/020` remain `PARTIAL`, and the overall 38-row RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**.
