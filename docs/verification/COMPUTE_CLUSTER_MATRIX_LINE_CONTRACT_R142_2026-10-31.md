# Matrix Line contract clean replay — R142

**Date:** 2026-10-31  
**Run ID:** `R142-MATRIX-LINE-CONTRACT-3S-20261031`  
**Executed checkout:** local docs commit `cd2dc0da3162c147db075c098a5b3bbff720544b`, tree `980bac931d5c87cf91ddf577a97ca5e8d05c427d`. The Matrix RTL, block testbench, and Make inputs are unchanged from R142 test commit `c87e137aaab2c708beffc1d7bdfb378829dcab1e`; intervening changes only update verification records.  
**Tool:** Synopsys VCS `V-2023.12-SP1_Full64`.

## Contract and result

The SPEC v1.5 Matrix Line contract accepts only a complete 128-bit Line write with a 16-byte-aligned address. Partial and zero WSTRB are unsupported. The core uses its scalar SPAD path for a legal 4-byte-aligned destination that is not 16-byte aligned.

The existing `core-random-regress` target passes on three seeds. Each run checks 18 independent numerical/layout cases and 35 directed fault/recovery cases. The mandatory line-contract marker confirms full WSTRB, 16-byte alignment, payload stability across 312 stalled cycles, unaligned scalar fallback, and a Line Protection error. The marker explicitly records partial/zero WSTRB as unsupported; those invalid masks are not generated as stimulus.

| Seed | Numerical cases | Fault/recovery cases | Line stall stability checks | Contract result |
|---:|---:|---:|---:|---|
| 20261025 | 18 | 35 | 312 | PASS |
| 20261026 | 18 | 35 | 312 | PASS |
| 20261027 | 18 | 35 | 312 | PASS |

Each seed also records 11 Matrix FSM reset-phase checks and the regression gate's required outstanding, prefetch fault, Abort, watchdog, and recovery markers. This is a Matrix block-level verification with injected interface Protection responses; the top-level Protection and shared-fabric scenarios remain separately evidenced.

## Reproduction

```sh
make -C dv/block/compute/matrix/sim core-random-regress \
  SEEDS='20261025 20261026 20261027' \
  CORE_OUT_DIR=/tmp/nmaforge_r142_matrix_contract_c87_20261031
```

SHA-256 evidence:

| Artifact | SHA-256 |
|---|---|
| VCS compile log | `ceca271e8b7612b6fb59721060ee462b6ab137a8f683fdb6bb265265941c3fcd` |
| Seed 20261025 | `87a7c3b3eddc57ad23828b84d8202e4dcfc1fbddb6d0e48f7fd85aa59eb44bf0` |
| Seed 20261026 | `3e1862af137ae5e4815756411745c6271f7848668a02bbd06470d1e54ed08e48` |
| Seed 20261027 | `d133425c13eab9f4e70a70a101fa019955e302ad3c86446acbbe4f0d71993f8b` |

Raw logs and the VCS coverage database remain under `/tmp/nmaforge_r142_matrix_contract_c87_20261031`.

## Requirement effect

This is a same-content replay of the existing `MATRIX-LINE-001` evidence; it does not add unsupported partial-WSTRB behavior or promote requirements. `REQ-CL-010` remains `PARTIAL` for the broader legal Matrix request/response and fault-phase combinations; `REQ-CL-022` retains `PASS-SCOPED*` with its existing qualification. The 38-row disposition remains 24 `PASS-SCOPED` / 14 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.
