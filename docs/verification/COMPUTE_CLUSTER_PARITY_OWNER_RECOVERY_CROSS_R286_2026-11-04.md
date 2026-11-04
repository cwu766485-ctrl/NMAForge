# Compute Cluster Parity Owner Recovery Cross — R286

## Result

| Field | Value |
|---|---|
| Test ID | `TC-CL-R286-PARITY-OWNER-RECOVERY-CROSS` |
| Run ID | `R286-FAULT-OWNER-CROSS-3S-20261104` |
| Fixed test SHA | `01a4114118cc0664c52602c6bed6a1e33b76681c` |
| Git tree | `1f4e183723b359b3e3b1eb556619929849df8ea6` |
| Tools | Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1` |

The existing legal seven-engine parity scenario now measures the ordered pair `fault owner × unaffected successful-completion owner`. It declares the 42 legal pairs (seven owners × six non-self owners), samples each pair only after completion owner/status/result/element checks and all six independent output Golden checks pass, and has a Makefile gate that requires exactly 42 pair records and 42/42 functional bins on every seed. Self-pairs are excluded because the parity-faulted task cannot also be an unaffected successful task. No illegal state or response was injected to fill a bin.

## Evidence

| Seed | Pair bins | Memory Scoreboard | Response-owner ledger | UVM warning/error/fatal |
|---|---:|---|---|---|
| `20261025` | 42/42 (100%) | 89,832 writes; 146,755 words checked; 0 mismatch, unknown, or stale | 10,678 accepted; 10,658 checked; 20 reset-dropped; 0 route/data/error mismatch; pending 0 | 0/0/0 |
| `20261026` | 42/42 (100%) | 89,832 writes; 146,755 words checked; 0 mismatch, unknown, or stale | 10,678 accepted; 10,658 checked; 20 reset-dropped; 0 route/data/error mismatch; pending 0 | 0/0/0 |
| `20261027` | 42/42 (100%) | 89,832 writes; 146,755 words checked; 0 mismatch, unknown, or stale | 10,678 accepted; 10,658 checked; 20 reset-dropped; 0 route/data/error mismatch; pending 0 | 0/0/0 |

The existing seven-mutant DUT campaign also passes 7/7 on this fixed test SHA: Address→`CLUSTER_MEMORY_UNKNOWN`, Data→`CLUSTER_GOLDEN`, Response Owner→`CLUSTER_ENGINE_RESPONSE_OWNER`, WSTRB→`CLUSTER_MATRIX_WSTRB`, Completion Error→`CLUSTER_COMPLETION_ERROR_CODE`, Missing Done→`CLUSTER_MISSING_DONE`, and Duplicate Done→`CLUSTER_DONE_WITHOUT_ACTIVE`. These are expected checker detections in intentionally mutated temporary RTL, not failures of the unmodified DUT.

The detached clean worktree additionally passes:

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

Both print `TEST PASS`. Top Smoke reports the existing fixture warning `[LOOP-REROLL-ENABLED]`; VCS KDB reports zero errors and zero warnings. The warning is disclosed, not suppressed.

## Reproduction

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r286_fault_owner_cross_3seed \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

make -C dv/uvm/sim uvm_compute_cluster_dut_mutation \
  COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_r286_dut_mutation \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

Logs, merged URG text summaries, the seven mutation compile/run logs, and Top Smoke/20-case logs are packaged at `/tmp/nmaforge_r286_evidence_20261104.tar.gz` (SHA-256 `c871c8c0e26a53b25de6d25503226b87c615ca68bc6c8980f16b896203714b4b`). The package excludes generated simulator binaries and databases.

## Scope and sign-off effect

The new cross adds specific evidence that each parity-fault owner can coexist with each of the six other engines completing with the expected owner and Golden result. It does not prove that every healthy owner was busy on the exact parity-response edge, nor does it close the general engine × fault × phase × reset × backpressure matrix, arbitrary memory-service fairness, partial/zero-WSTRB contracts, or all accepted-write-prefix cases. Therefore no Requirement disposition is promoted. The controlling 38-row RTM remains **27 `PASS-SCOPED` / 11 `PARTIAL`**, and `CL-DV-v1.0` remains **HOLD**.
