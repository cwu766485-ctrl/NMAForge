# Compute Cluster DV Closure Plan

## Candidate and current status

Candidate: `candidate/frontend-closeout`, `f919bb787dab1a4e3bef44b5308ead56d6e77b72`.
The published R250 replay reports Top Smoke, three-seed seven-engine UVM,
16-seed mixed E2E, and 7/7 named RTL mutations passing. It also reports raw
hierarchy coverage `73.99/69.39/47.24/64.95%` for line/condition/FSM/branch,
`20/22` assertions with real successes, and RTM `24 PASS-SCOPED / 14 PARTIAL`.
The closure state remains **HOLD**, not PASS.

## Closure gates

1. Re-run the exact candidate tree when the VCS license is available; the
   current environment failed Top Smoke at VCS license checkout before DUT
   execution.
2. Preserve the real seven-engine UVM topology: Compute Cluster, SPAD mux,
   real arbiter, four-bank behavioral SPAD, existing monitors, scoreboards and
   reference models.
3. Close the partial RTM rows by cross coverage of engine × phase × fault ×
   reset × abort × backpressure, including accepted-read reset and output
   committed prefix.
4. Maintain response-owner/tag checks for Matrix/CNM, DMA IDs, completion
   four-word commit, ordered retirement, protection/parity priority and no
   stale epoch response.
5. Repeat 7/7 actual RTL mutation sensitivity and retain exact source/test
   SHA, VCS/URG versions, commands, logs and checksums.
6. Run SpyGlass lint/CDC/RDC with the same source list. Current evidence is
   lint `0 errors / 465 warnings`, CDC setup/structural evidence only, and RDC
   timeout/no conclusion. This is not sign-off until warnings and advanced
   reset checks have dispositions.

## Required closure artifacts

`COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md`, the candidate replay report,
functional coverage database, assertion summary, mutation archive, lint/CDC/RDC
summary, and a final signed checklist must all point to one candidate source
identity. Until all partial rows have an explicit PASS, WAIVED, or BLOCKED
disposition with owner and evidence, the final result remains HOLD.

## Reproduction commands

```sh
cd dv/subsystem/top_smoke/sim
make ai_smoke

cd ../../../uvm/sim
make uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

cd ../../spyglass
./run_spyglass_a8.sh lint
./run_spyglass_a8.sh cdc
./run_spyglass_a8.sh rdc
```

The first command was attempted on the exact candidate worktree on
2026-11-13 and stopped at VCS license acquisition; no functional PASS is
claimed from that attempt.
