# A10 SPAD Arbiter Long-Run Fairness — 2026-10-18

Environment: Rocky Linux 8.10, Synopsys VCS `V-2023.12-SP1_Full64`.

## Commands and result

```sh
cd dv/subsystem/top_smoke/sim
make ai_spad_arb_run
make ai_smoke
```

`ai_spad_arb_run` passed the existing directed checks, the default 300-cycle
seeded request-mode phase, and the new 10,000-cycle phase selected by
`+SPAD_RR_MODE_CYCLES=10000`. The long-run marker was:

```text
Seeded request-mode SPAD RR PASS cycles=10000 grants=3334/3334/3334 max_wait=2/2/2 modes core=1654/1680 banked=1667/1667 dma=1659/1675
```

All six request forms were exercised. Requests remained asserted until grant,
the checker enforced at most one grant per cycle and a maximum of two wait
cycles, and the final pending requests drained. The existing CNM/DMA contention
and response-parity checks also passed. The following `ai_smoke` run ended with
`TEST PASS`.

Logs:

- `dv/subsystem/top_smoke/sim/ai_spad_arb_run.log`
- `dv/subsystem/top_smoke/sim/ai_spad_arb_10k_run.log`
- `dv/subsystem/top_smoke/sim/ai_accel_smoke.log`

## Scope

This verifies prolonged scheduler-admission round-robin fairness under
continuously pending, mode-changing requests. The arbiter has no downstream
ready input; therefore this is not a memory-response backpressure test and
does not close system-level fairness under downstream stalls, broad
fault×abort×reset coverage, or A10/V3 overall closure. Only the testbench,
Makefile target, and verification documentation changed; product RTL, SPEC, and
ABI are unchanged. The run was made in the current worktree after pushed
baseline `4d5b29e`; it is not a clean detached-SHA replay.
