# Compute Cluster FP16 CMDQ Numeric Golden — R256

## Result

At clean source/test commit `2f52008e5bbbc4051fa8f912082ef94d7069cc88` (tree `92f873219161c71368f235f3c1e2751191f32a66`), the real Compute Cluster CMDQ executes supported opcode `0x51` through the FP16 engine and writes an exact FP32 result. Three fixed seeds pass. This adds one numerical point to `REQ-CL-015`; it does not close the full opcode × shape × numeric-class requirement or change the sign-off disposition.

## Testpoint and independent expected result

The packed binary16 source words contain `A=[1.0,-2.0]` and `B=[2.0,-2.0]`. The expected dot product is independently exact: `1×2 + (-2)×(-2) = 6.0`, encoded as FP32 `0x40c00000`. The real CMDQ descriptor uses opcode `0x51`, ABI version 7, and length 2.

The sequence checks that the FP engine becomes active, exactly one launch occurs, the launch snapshot retains opcode/source/destination/length, the destination Memory Image equals `0x40c00000`, and the unique completion contains the expected task ID, success status, FP32 result, and element count 2. The named functional bin `two_term_exact_six` is sampled only after those checks.

## Clean replay evidence

Command:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_fp16_cmdq_r256_clean_2f52008 \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

VCS is `V-2023.12-SP1_Full64`; URG is `V-2023.12-SP1`. All three seeds pass with UVM warning/error/fatal counts `0/0/0`. The compile log has no VCS `Warning-`, `Error-`, or `[TFIPC]` diagnostics. The merged URG count for `two_term_exact_six` is `3`, with `100.00%` focused coverage.

For each seed, the full top-level Memory Scoreboard reports 75,431 writes and 95,043 checked words, with zero mismatch, unknown read, or stale epoch. The response-owner ledger reports 6,139 accepted, 6,119 checked, 20 reset-dropped, zero route/data/error mismatch, and no pending response.

Evidence archive: `/tmp/nmaforge_fp16_cmdq_r256_evidence_20261103.tar.gz`  
SHA-256: `10b572b6dc870483195330ac29eecee5af614551da973983d9ee9cee5527cf97`

The archive contains the compile log, three per-seed run logs, merged URG `grpinfo.txt`, and a manifest with SHA-256 values. It excludes VCS/URG databases, generated simulator binaries, and waveforms.

## Requirement mapping and limits

| Requirement | Test ID | Checker / coverage | Disposition after R256 |
|---|---|---|---|
| `REQ-CL-015` | `TC-CL-R256-FP16-CMDQ-GOLDEN` | Independent exact arithmetic vector, output Memory Image, completion owner/result/elements, launch snapshot; `two_term_exact_six` = 3/3 | `PARTIAL`; one real-top FP16 numeric point is closed, while most opcode/shape/numeric classes remain open |
| `REQ-CL-002` | R255 dispatch suite plus R256 selected launch snapshot | 24 normal opcode dispatch bins remain 24/24; R256 separately checks successful numeric launch for `0x51` | `PASS-SCOPED` |

The Compute Cluster RTM remains 25 `PASS-SCOPED` / 13 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**. No product RTL was modified.
