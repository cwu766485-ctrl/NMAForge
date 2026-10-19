# A10 V2 CP source-identity and tool-access audit — 2026-10-19

## Scope

Read-only audit of the current CP/Completion source baseline and the most recent
reproducible V2 evidence. No RTL, UVM, formal, or specification source was
modified in this audit.

## Source identity

The repository was at `0ea3e8cc3d23efdbe5de8717618348a9d3dac76d` (`main`). The
CP RTL, CP UVM environment, and CP formal harness are byte-identical to the
clean-replay baseline `c500b3daba529d3123ffe250644f3297ae8c16f3`:

```sh
git diff --quiet c500b3daba529d3123ffe250644f3297ae8c16f3..HEAD -- \
  rtl/control/queue/ai_command_processor.v \
  rtl/control/queue/ai_completion_writer.v \
  dv/block/command_processor/uvm \
  dv/block/command_processor/formal
```

Result: exit status 0 (`CP_RTL_UVM_FORMAL_IDENTICAL_TO_C500=YES`). Therefore,
the exact-SHA clean replay recorded for `c500b3d` still applies to the current
CP RTL and verification sources; the rest of the repository was not covered
by this source-identity comparison.

## V2 evidence still applicable

The detached clean replay at `c500b3d` ran the three-seed × 24-profile CP
coverage matrix: 72/72 profiles passed, each with 31/31 scenario bins and UVM
warning/error/fatal=`0/0/0`. Merged functional coverage was `cp_cg` 61/61
variables + 34/34 crosses, reset-word bins 4/4, kind × delay × reset 24/24,
and abort-timing 7/7. Top `ai_smoke` printed `TEST PASS`. This closes the
recorded mixed-reset and tile-load-DMA-error/recovery slices only; it is not
full V2 or A10/V5 acceptance. See the [clean replay record](A10_DV_RUN_2026-10-18_CP_COMPLETION_AVAILABILITY.md#follow-up-tile-load-dma-error-propagation).

The latest documented CP raw-condition result is 237/252 (94.05%). The 15
remaining raw `(0,1)` outcomes are documented as dispositioned using the
integrated configuration contract and formal/producer-ownership evidence; the
URG bins remain raw-uncovered, with no exclusions or rewritten bins. This is
not equivalent to 100% raw condition coverage. CP raw toggle residuals,
broader fault × abort × reset interactions, and the remaining cross-layer
command/completion lifecycle are still open.

## Current EDA access check

Using the existing read-only Rocky task
`a10-license-individual-variable-probe-20261018`, both license environment
variables were present, but `lmutil lmstat` returned exit 241 and classified
the license server as unreachable for each. No VCS, URG, or formal run was
started by this audit. This records current tool access only; it does not
invalidate the prior passing `c500b3d` replay.

## Conclusion

V2 has strong, source-current selected CP/Completion simulation evidence and
formal disposition for its recorded raw condition residuals. V2 remains
**partially complete** until its broader lifecycle requirements and remaining
raw toggle/report review are closed. V1, V3, V4, and V5 status are unchanged.
