# Compute Cluster parity × full Completion Queue — R214

**Result: focused PASS; requirement closure unchanged.** The seven real compute engines each consumed a real SPAD parity-error response while the Completion Queue was full. The test checked that the engine retired without destination writeback, the error completion remained pending, and software release caused one correctly owned completion and one tail wrap. All three VCS seeds passed.

## Source and run identity

- Test-source commit: `8316555c110416c613c1d7c08c5910039ffbfb3f`; tree `0e8c6400928c1780857d3e76f6d051f57a4aed5b`.
- Parent published closeout commit: `a29abf0b54a4762b2e1730bf4d53529484fa35d4`; GitHub equivalent `8b14e2394f9cf402281187e708fa780494eb6bf0` on `feat/compute-cluster-closeout-audit`.
- The R214 change contains only the UVM sequence and its Makefile gate; product RTL, SPEC, and ABI are unchanged.
- Test ID: `TC-CL-R214-ENGINE-PARITY-CPLQ-7`.
- Run ID: `CL-ENGINE-PARITY-CPLQ-R214-CLEAN-3S-20261102`.
- Tool: Synopsys VCS / URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`.
- Command:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r214_parity_cplq_3seed_20261102 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

## Observations

| Check | Result |
|---|---|
| Engine cases | 7/7 for Scalar INT8, FP, CNM, Matrix, SFU, Conv, and KV on each seed |
| Real parity response / blocked completion / release and wrap | 7/7 for each property on every seed |
| Error ABI | `0x52` for INT8/FP/CNM/Matrix/SFU; `0x72` for Conv/KV |
| Destination image | No output writeback on any parity-error case |
| Completion | Held while CPLQ is full; released once after head advance; tail wraps `3→0` |
| Focused URG group | `engine_parity_cplq_cg`: 7/7 bins, 100.00% |
| UVM severity | Warning/Error/Fatal = 0/0/0 for all seeds |
| Memory scoreboard | 72,021 words checked/seed; zero mismatch, unknown read, or stale epoch |
| Response owner ledger | 3,128 accepted / 3,109 checked / 19 reset-dropped; zero route/data/error mismatch; pending=0 |
| WSTRB observed in this run | full=1,461, partial=0, zero=0; this does not add partial/zero-WSTRB support |

Run-log SHA-256 values:

| Seed | SHA-256 |
|---|---|
| `20261025` | `a7ef22f07b46f4530974b0410b5cfdefe6e921bf0303d9648f8b7b44e5292d7d` |
| `20261026` | `2dfbe3b39d66c1ebbd40b59e58de5a577516b387439a747dbf6cf626886b02ab` |
| `20261027` | `8f53d96207fff6d28da42d2ad0c61d4a82f264e9aec68d240039474df36320db` |

Compile log SHA-256: `7dc8c6e1ba2077daf2a2298d9c41481ad1f5dd53f126296ed0bad39943c1124d`.

Merged URG log SHA-256: `edf99da72c7b86b577c8b19c47cf5f71eb6505120d8e0eb2dd0e22cf87baf03e`.

The run-wide URG scores are line/condition/FSM/branch/assert = 70.42/65.51/45.40/60.64/72.00%; total group score is 76.57%. These totals include unrelated groups not exercised by this test and are not coverage closure. Only the explicitly named parity × full-CPLQ group is 100%.

## Fixed-SHA smoke replay

The R214 test-source SHA was checked out in detached clean worktree `/tmp/nmaforge_r214_clean_8316555` and passed:

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke AI_RANDOM_CASES=20 AI_SEED=12345
```

The smoke log contains `TEST PASS`; SHA-256 `7fd9c9283541e63b15c1bc9ab6ac768be89f612e09741d1368c9cdadb69f1018`. The existing VCS loop-reroll fixture warning remains; it was not suppressed.

Text-log/URG evidence archive: `/tmp/nmaforge_r214_parity_cplq_evidence_20261102.tar.gz`, SHA-256 `268a5e49be7dc1ad357a02597c50bbcd324a2ca185834262947647827625efcb`. It contains the compile log, three seed logs, merged URG text reports, and Top Smoke logs. VDB binaries remain outside Git under `/tmp/nmaforge_r214_parity_cplq_3seed_20261102`.

## Requirement trace and remaining limits

| Requirement | Disposition | Bounded evidence from this run |
|---|---|---|
| `REQ-CL-017` | PARTIAL | Real parity response × full CPLQ, no-writeback, and retirement evidence for all seven engines. Other fault classes/phases and reset/backpressure intersections remain open. |
| `REQ-CL-019` | PARTIAL | Error completion wait/release, task owner, error mapping, queue wrap, and exactly-once behavior. Full simultaneous error-priority and lifecycle cross remains open. |
| `REQ-CL-027` | PARTIAL | Correct parity error code and task attribution for all seven engines. Full error ABI/priority matrix remains open. |
| `REQ-PC-006` | PARTIAL | Independent reference memory scoreboard and sentinels report zero data mismatch/unknown/stale. Partial/zero WSTRB and broader requester/fault combinations remain open. |
| `REQ-PC-007` | PARTIAL | The full regression's response ledger drains with zero route/data/error mismatch. This is not a simultaneous seven-production-engine ownership contention proof. |

No other Requirement disposition changes. Matrix raw FSM remains 49/53 with its existing legal-profile disposition. The overall 38-row RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**. This run does not close the broader Engine × Fault × Phase × Reset × Backpressure space, complete Mutation campaign, or global functional coverage target.
