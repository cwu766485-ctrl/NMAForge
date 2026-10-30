# SPAD Arbiter Fairness Evidence — R78 — 2026-10-30

## Result

**PASS for the standalone scheduler testpoints listed below.** Exact code/test SHA: `3fdb22640dc8b3c73e9ff05d3b07c6f0e3e67a28`. Run ID: `R78-SPAD-FAIRNESS-10K-3FDB226`. The harness is deterministic and does not use a configurable seed. This is verification-only evidence; RTL and SPEC are unchanged.

Command, from `dv/subsystem/top_smoke/sim`:

```sh
make ai_spad_arb_cov \
  SPAD_ARB_COV_RUN=/tmp/nmaforge_r78_arb_cov_3fdb226 \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

Tool: Synopsys VCS/URG `V-2023.12-SP1_Full64`.

## Observed checks

- Seeded request-mode arbiter run: 10,000 cycles; core, banked, and DMA clients each received 3,334 grants; maximum observed wait was 2 cycles for each client. Request modes included core `1654/1680`, banked `1667/1667`, and DMA `1659/1675` valid/ready observations.
- Directed three-client round-robin: 10 grants/client, maximum observed wait 2 cycles.
- CNM/DMA contention: 6 grants each.
- Matrix/CNM concurrent banked-response ownership, response-parity alignment, 12 cursor-fallback request forms, descriptor/completion priority and response, and protection-error response alignment all passed.
- URG found 2/2 cover-property bins; both assertions had attempts and real successes, with zero failures, incomplete attempts, uncovered assertions, or assertions without attempts.
- Raw standalone `ai_spad_arbiter` code coverage: line 100.00%, condition 86.89%, toggle 10.73%, branch 100.00%; URG assertion metric is not reported for the module summary. These are block-only metrics, not Compute Cluster functional coverage.

## Evidence and limits

Artifacts are in `/tmp/nmaforge_r78_arb_cov_3fdb226`:

| Artifact | SHA-256 |
|---|---|
| `compile.log` | `744660e9592a77a8d36b61da25ff0b9a820ee6ca20daa0bf84415062e0abd4e7` |
| `run.log` | `43e40e6235a588959791e7b53c8bffda729fe8882c1031e5af3b767d00647130` |
| `urg/asserts.txt` | `64a3b3487931e1df046db52cdacb739109ab157908e5a51bde0bb5892aa56314` |
| `urg/modinfo.txt` | `21d7b2fbb893b820c1f70ffa558ae52f9984f125cc65a51f5f708934636ac727` |

The harness exercises `ai_spad_arbiter` with modeled request patterns. It does not model downstream SRAM backpressure, prove progress through the seven-engine request mux and response path, or provide a per-engine end-to-end fairness bound. Therefore this closes only a bounded standalone arbiter fairness testpoint; `REQ-CL-014` remains PARTIAL and Compute Cluster v1.0 remains HOLD.
