# Matrix FSM Clean Replay — R281

## Result

At the exact published closeout source/test SHA `487794dfa2d931391fd5ac82f16626b7c6f878e5` / tree `c01a4e15f4f72ca120aa5e7d41094173c011f9ea`, the Matrix default profile and legal prefetch-disabled fallback pass their focused three-seed regressions. VC Formal proves all five configured guards and reaches both existing cover properties. No FSM state was forced and no illegal response was injected.

This replay confirms the Matrix FSM reachability disposition on the latest published candidate. The default enabled-profile raw transition count remains 49/53; R281 does not convert this into 100% raw FSM coverage and does not promote `REQ-CL-010` or any RTM row. The overall RTM remains 27 `PASS-SCOPED` / 11 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.

## Identity and evidence

| Item | Value |
|---|---|
| Test ID | `TC-CL-R281-MATRIX-FSM-CLEAN-REPLAY` |
| Run ID | `R281-MATRIX-FSM-CLEAN-REPLAY-20261104` |
| Source/test SHA and tree | `487794dfa2d931391fd5ac82f16626b7c6f878e5` / `c01a4e15f4f72ca120aa5e7d41094173c011f9ea` |
| Matrix core SHA-256 | `dedc44406ab9f30b270bde12dbfeb3ab88184bb29af446fa1f119321e5d73aad` |
| Formal harness SHA-256 | `78c292a3f7471b195335cfe61f8a1abd6070c4ae91f6ff80351e4d2a6d06e1db` |
| VCS / VC Formal | `V-2023.12-SP1_Full64` / `V-2023.12-SP2` |
| Seeds | `20261021`, `20261022`, `20261023` |
| Evidence archive | `/tmp/nmaforge_r281_matrix_fsm_evidence.tar.gz` |
| Archive SHA-256 | `533e2763f1c8961c856583f88d5df68981701b491e628f256623fbe31df6f120` |

The Matrix core and formal harness checksums match the earlier R249 reachability review. The Matrix simulation Makefile/testbench has since gained a gated fallback/size-benchmark replay; neither the Matrix core RTL nor formal harness changed.

## Commands and results

```sh
make -C dv/block/compute/matrix/sim core-random-regress \
  CORE_OUT_DIR=/tmp/nmaforge_r281_matrix_core VCS=/usr/local/bin/vcs

make -C dv/block/compute/matrix/sim core-no-prefetch-fallback-regress \
  NO_PREFETCH_CORE_OUT_DIR=/tmp/nmaforge_r281_matrix_no_prefetch \
  VCS=/usr/local/bin/vcs

make -C dv/block/compute/matrix/formal fsm-guards \
  OUT=/tmp/nmaforge_r281_matrix_formal
```

| Check | Result |
|---|---|
| Default 16×16, depth 4, prefetch/cache enabled | All three seeds pass 18 functional cases and 35 fault/recovery cases each. |
| Prefetch-disabled legal fallback | All three seeds pass the fallback marker and five benchmark workloads each. |
| VC Formal guards | 5/5 proven; all five are non-vacuous. |
| VC Formal reachability | 2/2 covers hit: Prefetch Wait at depth 11 and Error Drain at depth 5. |
| Formal setup | `No setup issues found`; no property failure or counterexample. |
| Reset/fault behavior | Seeded Matrix phase-abort, phase-reset, parity, protection, watchdog and outstanding-response checks pass. |

The formal log includes non-fatal `COM_OPT009/010`, `CLOCK_W_UNIT_ADJUST` and `LEARNED_DATA_NOT_FOUND` messages. VC Formal completed successfully; the Make gate checked the five proofs, two covers, clean setup summary, and absence of formal errors. The enabled-profile raw 49/53 result is carried forward from R249, not recomputed as a new URG aggregate in R281. Three misses are guard/invariant-incompatible in that profile; `ST_MAC→ST_A_REQ` is covered only in the legal prefetch-disabled profile.

## Requirement disposition

| Requirement | Status | Evidence | Remaining scope |
|---|---|---|---|
| `REQ-CL-010` | `PARTIAL` | Default-profile Matrix core regression, fallback-profile regression, five non-vacuous formal guards and two reachability covers; full logs/VDBs/formal log are in the archive. | Broader parameter/descriptor integration and legal request/response × fault × phase × reset/backpressure combinations remain open. |

No product RTL was modified. This is focused Matrix evidence, not a full Compute Cluster UVM or top-level replay.
