# Compute Cluster P0 Protection × Full-CPLQ Replay — R235

## Fixed candidate and scope

- Published replay HEAD: `3259d4da158d56aebe41c227c426b6b4b74a0f72`.
- Executed RTL/DV source identity: `c5755985b0e5b1e1a850122ece983a37be112272`; the published tree has identical `rtl/`, `dv/`, and `docs/spec/` content.
- Test ID: `TC-CL-R185-ENGINE-PROTECTION-FULL-CPLQ`.
- Run ID: `R232-PUB3259-CLUSTER-UVM-3S-20261103`; seeds `20261025`, `20261026`, `20261027`.
- Tools: VCS `V-2023.12-SP1_Full64`, URG `V-2023.12-SP1`.

This report audits a named P0 testpoint already included in the exact published-head replay. It does not introduce a new test run or change product RTL, DV source, or SPEC.

## Observed result

All three real-top seven-engine UVM seeds pass the writeback Protection × full Completion Queue × ordered release/tail-wrap point. Each seed emits one `CLUSTER_PROTECTION_CPLQ_CROSS_PASS` marker with `engines=7/7 coverage=100.0%`, plus exactly seven per-engine case markers. The mandatory `uvm_compute_cluster_regress` Make gate checks both marker counts and result text.

The scenario occupies the four-entry ring's three usable slots with validator-error completions, then submits one legal descriptor for each production engine. Its operand read is allowed and its destination write is Protection-denied. The checker verifies the error completion remains held while the CPLQ is full, the CMDQ head and processor wait at the expected point, software advances the CPLQ head, the completion retires across the tail wrap, the engine-specific error code and task ID are preserved, and all destination sentinels remain unchanged.

| Engine | Expected retained Protection code | Seeds |
|---|---:|---|
| Scalar | `0x62` | 3/3 |
| FP | `0x62` | 3/3 |
| CNM | `0x62` | 3/3 |
| Matrix | `0x62` | 3/3 |
| SFU | `0x62` | 3/3 |
| Conv | `0x72` | 3/3 |
| KV | `0x72` | 3/3 |

All three complete Cluster runs report UVM warning/error/fatal `0/0/0`; the independent Memory Scoreboard checks 92,871 words per seed with zero mismatch, unknown read, or stale epoch. The response-owner ledger has zero route/data/error mismatches and no pending entries at test end.

| Seed | `run.log` SHA-256 | Result |
|---:|---|---|
| `20261025` | `e661bf470b0e4db5c5dd249322b3f33c6d778ef1f9f831dd4d3d20b52f74c90e` | 7/7 engines, PASS |
| `20261026` | `d90816f1d73bdc063a2618b1afc688c90bd0670d76698437a6e3311b8a3c0c25` | 7/7 engines, PASS |
| `20261027` | `053e0861fb2fc9bc5d6b32169e096ca6a1f24ed6eace7a00367588b39d77d419` | 7/7 engines, PASS |

The logs are in `/tmp/nmaforge_r232_published_compute_20261103/seed_<seed>/run.log` and the logs-only published replay archive, SHA-256 `ac1f659990fd2aef1b044a680170878ac8f327eb848f53be722b9a13801b2e0ba`.

## Requirement impact and remaining gap

This confirms a current-candidate testpoint for `REQ-CL-017` (Protection behavior), `REQ-CL-019` (error retirement under completion pressure), `REQ-CL-027` (error code/task ownership), and the memory/response evidence in `REQ-PC-006/007`. These requirements remain `PARTIAL`: the run does not cover every legal fault × phase × reset × backpressure × engine combination, concurrent response-owner contention during this specific full-CPLQ fault, or every accepted-write prefix. No requirement disposition is promoted, and `CL-DV-v1.0` remains **HOLD**.

The full replay commands and overall SVA/coverage disposition are recorded in the [R232 published-head report](COMPUTE_CLUSTER_PUBLISHED_HEAD_CLEAN_REPLAY_R232_2026-11-03.md). The historical R185 report documents when the testpoint was added; this R235 record binds its result to the later exact published candidate.
