# Compute Cluster Request Stability Gate — R126

**Date:** 2026-10-31
**Run ID:** `CLUSTER-REQUEST-STABILITY-R126-3S`
**Executed clean source SHA:** `175673b0930a81a00732ddff2cf825f358465cf9`, tree `6eef8fce6dcd544c9327f5c8921c6dd26ac86068`
**Published same-tree SHA:** `45497791e86468703303542a5961423a0311242c`
**Change scope:** one regression acceptance check in `dv/uvm/sim/Makefile`; no product RTL, SPEC, UVM sequence, or stability checker changed.
**Tools:** VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.

## Regression result

Command:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r126_request_stability_gate \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

PASS for all three seeds. The gate now requires the existing checker summary to show a stalled request for each actual requester class in the regression:

- Six scalar request clients: mask `1110111` and a nonzero stall-cycle count on all six clients. The Matrix scalar slot is zero because Matrix uses its separately checked banked and Line interfaces.
- Matrix banked requests: 3,871 stability checks and one legal parity-response cancellation observation.
- Matrix Line writes: 210 stability checks.
- CNM: all four lanes have 912 stability checks each.

The existing payload-stability checker reports zero violations. This is enforced per seed; it is no longer sufficient for the Make target to see a generic stability marker without the requester counts.

| Seed | UVM severity (warning/error/fatal) | Focused compute functional group | Requester stall summary |
|---|---:|---:|---|
| `20261025` | `0/0/0` | `100.0%` | mask `1110111`; cycles `{1374,1151,98,0,1730,1537,1667}`; banked `3871`; Line `210`; CNM `{912,912,912,912}` |
| `20261026` | `0/0/0` | `100.0%` | mask `1110111`; cycles `{1374,1151,98,0,1730,1537,1667}`; banked `3871`; Line `210`; CNM `{912,912,912,912}` |
| `20261027` | `0/0/0` | `100.0%` | mask `1110111`; cycles `{1374,1151,98,0,1730,1537,1667}`; banked `3871`; Line `210`; CNM `{912,912,912,912}` |

The Make target completed with `COMPUTE_CLUSTER_REAL_UVM_REGRESS_PASS`. Compile output has zero `Warning-`, `Error-`, and `[TFIPC]` diagnostics. The focused `cluster_cg` percentage is scoped to the declared Compute Cluster bins and is not whole-design code coverage.

## Artifact paths and hashes

All raw artifacts are outside Git under `/tmp/nmaforge_r126_request_stability_gate/`.

| Artifact | SHA-256 |
|---|---|
| `compile.log` | `d440c68a9c487fda28ae3564662e1c7d0a6b561b570d5f8c0a131702c3f7d2e5` |
| `seed_20261025/run.log` | `601c7885e7aff6ce3f60866cc602ac8a2336f318d6136dd8b637b1e4db968e20` |
| `seed_20261026/run.log` | `1efbe2b7585c416c375eeb600ad5af7b306604505f89427c962f54177bfd4cf1` |
| `seed_20261027/run.log` | `5dce4aa0abe06713f12b4dbbc07610b6b5fe40c1fc1d197b82991e5c9625316b` |
| `urg_merged.log` | `51f6b8348e4edc8f2f2d98c16b7caeb837c2eb978f63409956ea06ca66993965` |
| `urg_merged/dashboard.txt` | `579ec141efad72cac25d3c8c801f3c75cc769f0275674ba2d659b8a88d25dbcb` |
| `urg_merged/groups.txt` | `cafc9747f38ede2d9488f076e6ea9914961042f4403fef66bdf254851a85177f` |
| `urg_merged/asserts.txt` | `4d0f5c9a9ed68fcb1a9d1801010878fe9f0bc6f550df85573f0fc75301aa8c6e` |

## Requirement disposition

`REQ-CL-006` gains a required three-seed check for scalar clients, Matrix banked/Line, and all CNM lanes. It remains **PARTIAL**: the complete requester × stall class × operation direction/progress matrix is not covered. No other requirement status changes. The full RTM remains 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` remains **HOLD**.
