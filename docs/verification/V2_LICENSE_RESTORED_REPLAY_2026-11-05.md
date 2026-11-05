# v2 VCS Checks After License Restoration — 2026-11-05

## Tested source and environment

- Branch: `feature/npu-architecture-v2`
- Tested source/test commit: `cc7c6b23ef0aa34d50033603c3f8f77489b30220`
- Tested tree: `0ec98179bc6c5d2008c13810bc14d73044dac1a2`
- Simulator: Synopsys VCS `V-2023.12-SP1_Full64`
- SPAD model: checked-in behavioral four-bank model; results are RTL simulation,
  not SRAM timing, ASIC PPA, or silicon measurements.

The previous `BLOCKED_ENV / NOT_RUN` records for the tests below are superseded
by these completed runs. No product RTL changed in this replay. Two testbench
expectations were corrected: the four-entry CMDQ tail wraps from entry 2 to 0,
and K-fold MAC/prefetch counts scale with the number of four-row tiles.

## Completed checks

| Scope | Exact command | Result |
|---|---|---|
| Top Smoke, including real-CMDQ `0x52` M8/K-tail and `0x53` tile forwarding, plus 4 random cases | `timeout -k 5s 1200s make ai_smoke AI_RANDOM_CASES=4 AI_SEED=20261105 SEED=20261105` from `dv/subsystem/top_smoke/sim` | PASS, `TEST PASS`. M8/K19 checks 128 INT32 outputs and 32 line writes against the independent Golden. `0x53` checks all output words and four completions; source-A Banked Reads are 16 in the SPAD baseline and 0 with forwarding. Existing VCS notice `[LOOP-REROLL-ENABLED]` remains. |
| Descriptor ABI/range/alias validation | `timeout -k 5s 1200s make descriptor-validator-regress DESCRIPTOR_VALIDATOR_OUT=/tmp/nmaforge_descriptor_validator_gemv_alias_20261105` from `dv/block/control/sim` | PASS: 29 legal opcodes, 33 invalid-rule checks, accepted boundaries 43/43, rejected boundaries 26/26, tile-forward descriptors 3/3, legacy aux compatibility and opcode classification consistent. |
| Product GEMV B-cache OFF/ON multirow ablation | `timeout -k 5s 1200s make product-gemv-b-cache-ablation SEEDS='20261105 20261106 20261107' CORE_OUT_DIR=/tmp/nmaforge_gemv_b_cache_multirow_retry_20261105` from `dv/block/compute/matrix/sim` | PASS: 24/24 shape/configuration/seed cases; all 128/256 outputs match the independent Golden, output-line counts match, and accepted banked reads drain. |

### B-cache multirow results

Each row compares the same three responder seeds with B-cache disabled and
enabled. Cycle and traffic figures are Matrix-core behavioral-SPAD measurements.

| Shape | Command cycles, OFF → ON (mean) | Banked reads, OFF → ON | Read bytes, OFF → ON |
|---|---:|---:|---:|
| M8×16×19 | 195.67 → 152.33 (−22.15%) | 54 → 35 | 864 → 560 (−35.19%) |
| M8×16×65 | 520.00 → 383.00 (−26.35%) | 170 → 106 | 2,720 → 1,696 (−37.65%) |
| M16×16×19 | 382.67 → 262.67 (−31.36%) | 108 → 51 | 1,728 → 816 (−52.78%) |
| M16×16×65 | 1,029.67 → 632.33 (−38.59%) | 340 → 148 | 5,440 → 2,368 (−56.47%) |

All B-cache runs report the expected B-cache hit and bytes-saved counters.
These measurements do not establish bank-aware external-memory performance or
an end-to-end NPU speedup.

## Evidence and scope limits

- Top Smoke output: `/tmp/nmaforge_ai_smoke_fixed_20261105.log`; VCS compile
  output: `dv/subsystem/top_smoke/sim/ai_comp.log`.
- Descriptor logs:
  `/tmp/nmaforge_descriptor_validator_gemv_alias_20261105/{compile,run}.log`.
- GEMV build/run output:
  `/tmp/nmaforge_gemv_b_cache_multirow_retry_20261105.log`; per-seed logs and
  compile logs are under `/tmp/nmaforge_gemv_b_cache_multirow_retry_20261105/b_cache_{0,1}/`.
- Evidence archive:
  `/tmp/nmaforge_v2_license_restored_20261105_evidence.tar.gz`, SHA-256
  `15998a10b932e066723a102ddced0a1c515bcd00e6691cc660496dc737c0e6c8`.

These results close the named blocked test runs only. Opcode `0x53` feature-
specific multi-seed fault/Abort/Reset coverage, cross-engine coherence, full
shape and fault matrices, common-resource TinyNPU comparison, synthesis/PPA,
and v1.0 Compute Cluster requirement closure remain open. `CL-DV-v1.0` remains
**HOLD**.
