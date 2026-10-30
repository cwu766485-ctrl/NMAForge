# Compute SPAD MUX Fairness Evidence — R79 — 2026-10-30

## Result

**PASS for the standalone seven-client MUX testpoints below.** Exact code/test SHA: `a45864565ace4702783f5c5632c1f13a001c7653`. Product RTL and SPEC were not changed. Run ID: `R79-COMPUTE-SPAD-MUX-FAIRNESS-4096-A458645`.

Focused command, from `dv/subsystem/top_smoke/sim`:

```sh
make ai_compute_spad_mux_fairness \
  COMPUTE_SPAD_MUX_RR_RUN=/tmp/nmaforge_compute_spad_mux_rr_R79_a458645 \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

Exact Top Smoke command:

```sh
PATH=/opt/Synopsys/vcs/V-2023.12-SP1/bin:$PATH \
  make -C dv/subsystem/top_smoke/sim ai_smoke AI_RANDOM_CASES=20 AI_SEED=12345
```

Tool: Synopsys VCS/URG `V-2023.12-SP1_Full64`.

## Checks

- The production `ai_compute_spad_mux` RTL receives seven continuously asserted behavioral requester streams for 4,096 cycles. Deterministic downstream ready gaps include at most three consecutive low cycles.
- 3,233 requests are accepted: per-engine counts are `462/462/462/462/462/462/461`. Maximum observed per-engine wait is 10 cycles against the enforced 32-cycle bound.
- All 2,582 accepted reads receive exactly one response routed to their accepting engine. The checker compares returned data and combined response/parity error, verifies other data lanes remain zero, and ensures writes create no response.
- Three assertions pass with no failure, incomplete attempt, or assertion without attempts: onehot ready (4,101 attempts), stable selected payload while stalled (4,101 attempts, 864 real successes), and onehot response ownership (4,101 attempts, 2,151 real successes).
- URG DUT-only `ai_compute_spad_mux` coverage: line/condition/toggle/branch `100.00/79.17/48.57/92.31%`. These raw block metrics are not a Compute Cluster coverage percentage.
- The same clean SHA passes Top Smoke with `AI_RANDOM_CASES=20`, `AI_SEED=12345`; the run log ends in `TEST PASS`. VCS emits the existing benign `LOOP-REROLL-ENABLED` fixture warning.

## Evidence and limits

Focused artifacts: `/tmp/nmaforge_compute_spad_mux_rr_R79_a458645`.

| Artifact | SHA-256 |
|---|---|
| `compile.log` | `1ea3f5afa5eaa671c5c366c3521e0aa20ce88293bbf31c60e1bdb00044e331e3` |
| `run.log` | `3dba3428551368002dc6607ef2263ae56cc2b67a955d2a2a8c8e0d9129b0299b` |
| `urg/asserts.txt` | `e8a0a88d0e22791cbf1593f18c4b07fccaa436c5c7785d082348c6f5f70e464e` |
| `urg/modinfo.txt` | `fd612d06b2a24343a150f88ddab5ed9f3811f1b038d8eab571806c06a915b79f` |
| Top Smoke `ai_accel_smoke.log` | `0dcaaede12a86eeb8d35318a440161f2b9dc674282cf9bc4e528dea539465b70` |
| Top Smoke `ai_comp.log` | `1494140d33c81ac9b6c44bbf6137281fd3158f9f45cf3575ebb3920b6c67cb31` |

This test instantiates the production MUX with behavioral requesters, ready stalls, and a fixed-latency response model. It does not instantiate all seven production engines or `ai_spad_arbiter`, and it does not test SRAM backpressure, protection denial, or end-to-end completion ownership. R78 separately covers bounded standalone scheduler arbitration. Consequently `REQ-CL-014` remains PARTIAL; this evidence closes only the named seven-client MUX fairness/response-routing testpoints. `CL-DV-v1.0` remains HOLD.
