# Compute Cluster parameter-latch disposition — R261

**Disposition:** `REQ-CL-005` is `PASS-SCOPED` for its frozen P0 testpoint, `engine × mid_task_change`. This does not claim exhaustive descriptor-field, opcode, boundary, or host-write-race closure. `CL-DV-v1.0` remains **HOLD**.

## Evidence

The exact clean candidate is `724d1f0b3774643df35e14d7cb9ff0e3ad534ac8` (tree `7e168fdbc5e90725d4a924f20b7fb2b1b842d03c`). Run `R260-UVM-CLUSTER-3S-724D1F0-20261103` passes through the official `uvm_compute_cluster_regress` target on seeds `20261025`, `20261026`, and `20261027`. The regression gate requires all seven markers in every seed log:

| Engine class | Mandatory marker | Representative in-flight mutation and result checker |
|---|---|---|
| Scalar | `CLUSTER_PARAMETER_LATCH_PASS` | Source/destination descriptor mutation; original task completes correctly |
| Matrix | `CLUSTER_MATRIX_PARAMETER_LATCH_PASS` | Source, destination, shape, transpose; 16×32×64 independent Golden and completion |
| SFU | `CLUSTER_SFU_PARAMETER_LATCH_PASS` | RMSNorm source/destination/length; original four-element result and completion |
| CNM | `CLUSTER_CNM_PARAMETER_LATCH_PASS` | Destination descriptor mutation during legal Scalar/CNM overlap; 16 independent outputs and both completions |
| FP | `CLUSTER_FP_PARAMETER_LATCH_PASS` | BF16-dot operands, destination, length; exact FP32 result 128.0 |
| Conv | `CLUSTER_CONV_PARAMETER_LATCH_PASS` | Input, weights, destination, shape; independent outputs 54/63/90/99 |
| KV | `CLUSTER_KV_PARAMETER_LATCH_PASS` | Source, cache base, length, head/token, strides; eight expected cache words |

Each seed reaches all seven mandatory markers. Each full run checks 95,043 Memory Scoreboard words with zero mismatch, unknown read, or stale epoch; UVM warning/error/fatal is `0/0/0`, and the response-owner ledger drains. The test sequences check launch snapshots, completion, independent numerical or cache-image results, and destination/cache sentinels as applicable. FP/Conv/KV descriptor rewrites use parity-consistent UVM backdoor mutation while the engine is active; this does not exercise a concurrent host write, which the SPAD contract rejects during conflicting compute access.

## Scope boundary

The declared Testplan cross is one representative mid-task launch-parameter mutation for each of the seven engine classes, and all seven are now mandatory regression gates. The evidence does not sweep every field for every opcode, legal descriptor boundary, or fault/recovery phase. Those broader contracts remain tracked under the relevant descriptor and error-handling requirements and `OPEN-CL-002`; no unsupported behavior is waived. The disposition therefore closes only this named P0 testpoint, not the complete Compute Cluster sign-off.

## Reproduction record

- Run report: [R260 clean-candidate replay](COMPUTE_CLUSTER_FINAL_CANDIDATE_REPLAY_R260_2026-11-03.md)
- Logs-only archive: `/tmp/nmaforge_compute_cluster_r260_724d1f0_logs.tar.gz`
- Archive SHA-256: `aabbf232f30e26f732618d312ddad30e115df9fbaeea51a718502ca313a9b4f1`
- VCS: `V-2023.12-SP1_Full64`; URG: `V-2023.12-SP1`
- Frozen testpoint definition: [Compute Cluster UVM Testplan, REQ-CL-005](COMPUTE_CLUSTER_UVM_TESTPLAN_ZH.md)
