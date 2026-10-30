# Compute Cluster R72 — Matrix parity cancellation and concurrent CNM ownership

**Result:** PASS for this testpoint only; not a Compute Cluster sign-off.  
**Exact clean verification/test SHA:** `97632332181546d8c08dca95ca244d3cd054b55f`  
**Product RTL SHA:** `cc357830923e3dd7beda114b4d761fde839b01a7` (no RTL changes in R72).  
**Simulator:** Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`.

## Testpoint

R72 runs a real top-level Matrix GEMM and CNM GEMV concurrently with disjoint operand/output regions. A parity error is injected into Matrix's final A-row lane while Matrix has a banked read request held but not accepted. The sequence checks the narrow same-cycle request-cancellation behavior, drains accepted reads, and verifies that the failed Matrix does not write its output. The concurrently dispatched CNM must complete with its independent Golden result.

Each seed checks:

- Matrix completion error `ERR_PARITY=0x52`, CNM success completion, and ordered CPLQ retirement.
- Real Matrix/CNM overlap and shared banked SPAD admission; Matrix/CNM accepted-response counts are `121/1024`, with zero route mismatch.
- Exactly one held-read cancellation on the Matrix parity response, followed by drain of accepted reads and no Matrix output writeback.
- All 16 CNM output words against the independent integer Golden and 512 Matrix destination sentinel words unchanged.
- The full memory scoreboard, including zero mismatch, unknown, stale-epoch, or orphan response.

The behavior is confined to an error-response cycle that terminates Matrix requests. The ordinary `valid && !ready` stability requirement remains in force; the test does not relax request stability for normal backpressure. No product RTL was changed.

## Clean replay evidence

Exact command, from `dv/uvm/sim` in a detached clean worktree at the SHA above:

```sh
make uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r72_clean_replay_9763233 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261030 20261025 20261026'
```

All three seeds pass. Each reports 314 Matrix/CNM overlap cycles, 143 shared banked accepts during the cross, 121 Matrix responses, 1,024 CNM responses, zero route mismatch, one parity cancellation, 15,320 checked words, zero scoreboard mismatch/unknown/stale response, and UVM warning/error/fatal `0/0/0`. Focused applicable compute coverage is 100.0%; URG reports `cp_matrix_banked_fault_cancel` as one expected bin, one covered, zero uncovered (100%). This is a focused testpoint result, not overall functional or code coverage closure.

| Artifact | SHA-256 |
|---|---|
| UVM compile log | `ad97cdd21833b0c7d6e8f63505b3a01eed58f028287413143d44efc32cc707e5` |
| Seed `20261030` log | `d42ce3a7ce05b6d0597fb5b6b0f78006800f94f0dec828efbe3a8df39b505f5e` |
| Seed `20261025` log | `d731625ff90d60680d05eef6e1043b52f4e70655b0a7d104adf4cad9a15ef25b` |
| Seed `20261026` log | `6d6a259dde4f67ea825d50275ae691a7e1eb926c06699d7f6350a572bf1fc46c` |
| Merged URG `grpinfo.txt` | `3f002328554462eff399bf46a0cb422c755bd28f5dd6ec7c1a2a9e3acf65c657` |

The UVM compile log has no `Warning-`, `Error-`, or `[TFIPC]` diagnostics. The clean worktree remained unchanged by generated simulation outputs.

## Related same-SHA gates

```sh
cd dv/subsystem/top_smoke/sim
make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345

cd ../../uvm/sim
make uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r72_clean_replay_9763233 \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r72_clean_mutations_9763233
```

Both top-level targets pass (`TEST PASS`). The smoke compile retains the existing `[LOOP-REROLL-ENABLED]` fixture warning; it is not a VCS elaboration, SVA-connectivity, or `[TFIPC]` warning. The 20-case seeded top run passes. The checker-sensitivity campaign catches all 28/28 expected passive-observation corruptions: address, data, owner, WSTRB, completion error code, post-error write, response epoch, and Done/missing-Done/duplicate-Done across seven engine bits. It is not a DUT mutation score.

Additional log locations and hashes:

- Top Smoke log: `/tmp/nmaforge_r72_clean_replay_9763233/top_smoke.log`, SHA-256 `a9543f5f4a7aeb71883db6dfb0a19d05f22a19c633e070db254b9e16276c8362`.
- Top Smoke compile log: `/tmp/nmaforge_r72_clean_replay_9763233/top_smoke_compile.log`, SHA-256 `ef7080d6021a1582252855dfdb68e246d7996726f3a32a7d82be8bb4164f83f9`.
- 20-case top log: `/tmp/nmaforge_r72_clean_replay_9763233/top_seeded_20.log`, SHA-256 `9777c0b96c896276c73a879ded354321b8621f1d03960c686201e7f57f1ecff4`.
- Mutation console log: `/tmp/nmaforge_r72_clean_mutations_9763233/campaign_stdout.log`, SHA-256 `2d85e32bc1b2fb7e2e2156bc11e20fe407203904b0b927e6a208673df6ec8e52`.
- Per-mutation logs: `/tmp/nmaforge_r72_clean_mutations_9763233/`.

## Requirement and sign-off disposition

This adds one real-top Matrix/CNM shared-SPAD, parity-response, response-owner and completion-order cross to `REQ-CL-006`, `REQ-CL-007`, `REQ-CL-017`, `REQ-CL-019`, `REQ-PC-006`, and `REQ-PC-007`. It does not close any of those requirements globally: the full requester × stall/progress and legal engine × fault × phase × Abort/Reset matrices remain incomplete. The execution RTM remains **24 PASS-SCOPED / 14 PARTIAL / 0 BLOCKED_SPEC / 0 NOT_RUN**.

`CL-DV-v1.0` remains **HOLD**. In particular, `OPEN-CL-003` still requires qualification against the selected target external AXI fabric or an approved fabric compliance review; the behavioral responder evidence is not a substitute. R72 does not resolve descriptor cross gaps or the other partial RTM rows. The checker-sensitivity campaign does not represent injected DUT faults.
