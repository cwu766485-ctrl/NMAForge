# A10 DV Current Source Identity Audit — 2026-10-19

**Comparison endpoint:** `main` at `c25652242ca51d1919aaa88ddfa8b5c350920c54`

**Purpose:** Reconcile existing A10 test evidence against the current relevant
RTL and verification sources before planning more licensed-tool runs.

This is a read-only source comparison, not a new simulation, formal, or
coverage run. Each comparison used `git diff --quiet <baseline> HEAD -- <paths>`;
exit status 0 means the listed paths are identical. The repository's later
commits since these baselines are documentation-only in the compared scopes.

## Evidence-to-source map

| A10 scope | Existing tested baseline and evidence | Current source comparison | Interpretation |
|---|---|---|---|
| V1 FP RTL + block UVM | `880c697ca6ed716e2985ac06f3930171b9fa29b4`; three-seed dot UVM replay, 484/484 bit-exact transactions per seed. [Run record](A10_DV_RUN_2026-10-18_MAIN452.md#2026-10-18-exact-current-main-fp-baseline-at-880c697) | `rtl/compute/fp`, `dv/block/compute/fp`: identical | The selected FP RTL/UVM result remains source-current. Full-domain parity-to-writeback formal remains unresolved. |
| V1 Python reference model | Model replay at `2f7b82d448acf3616081407a8261ad4c359582db`; 19/19 passed again on current-main source at `7fd70d8`. [Run record](A10_DV_RUN_2026-10-19_FP_MODEL.md) | `dv/block/compute/fp/model`: identical | License-independent model checks remain current; this is not RTL/UVM evidence. |
| V2 CP/Completion UVM | Clean replay at `c500b3daba529d3123ffe250644f3297ae8c16f3`; 72/72 profiles, 61/61 functional variables, 34/34 crosses, plus top smoke. [Run record](A10_DV_RUN_2026-10-18_CP_COMPLETION_AVAILABILITY.md#follow-up-tile-load-dma-error-propagation) | CP/Completion RTL, UVM, and formal paths: identical | The recorded CP campaign remains source-current for these paths. V2 lifecycle and residual raw toggle review remain open. |
| V2 CP ownership formal | Clean formal replay at `de518464a8669776073b907692908c385c8f04df`; 7/7 assertions proven/non-vacuous and 3/3 covers reached. [Run record](A10_DV_RUN_2026-10-18_CP_COMPLETION_AVAILABILITY.md#follow-up-descriptor-fetch-response-ownership) | CP RTL and formal paths: identical | The formal result remains current for those paths; its producer/configuration assumptions remain compositional, not whole-top proof. |
| V2 Control busy-time `CPL_SIZE` lock | Control UVM all 9 tests passed after adding the rejected busy-time reconfiguration check. [Run record](A10_DV_RUN_2026-10-18_CP_COMPLETION_AVAILABILITY.md) | `dv/block/control`: identical to `c500b3d` | The follow-up result is worktree-based, not part of the earlier `ad88b39` clean replay. Preserve that evidence distinction. |
| V3 DMA-SPAD-CNM subsystem | Clean replay at `7271c548d7ba30457c0b1ce2e11de88358cc54c2`; 10 seeds, RREADY 16/64/300-cycle profiles, four reset cutpoints, and top smoke. [Run record](A10_DV_RUN_2026-10-19_V3_CLEAN_REPLAY.md) | `rtl/dma`, `rtl/memory`, `rtl/compute/cnm`, `dv/subsystem/dma_spad`: identical | The selected V3 run remains source-current. Raw DUT coverage and broader interaction closure remain open. |
| V4 selected clean replay | Clean replay at `ad88b39207ecf34a31eeb058d7802ac70a5bbe70`; selected FP, CP, DMA, Control, top-smoke, seeded top, and mixed-precision DDR E2E suites. [Run record](A10_DV_RUN_2026-10-18_CLEAN_AD88B39.md) | `rtl`, `dv/uvm`, `dv/block/dma`, SPEC, software ABI, and the listed top/FPGA filelists: identical | These selected scopes remain source-current. This does not mean every suite was rerun together at current HEAD. |
| V4 top-smoke follow-up | Current smoke testbench/Makefile follow-ups, including descriptor-fetch ownership monitor, passed at the `c500b3d` replay. [CP follow-up record](A10_DV_RUN_2026-10-18_CP_COMPLETION_AVAILABILITY.md#follow-up-tile-load-dma-error-propagation) | `dv/subsystem/top_smoke`: identical to `c500b3d` | Current top-smoke source is covered by the later recorded smoke run, not only by `ad88b39`. |

The standalone 10,000-cycle SPAD admission-fairness record is a separate
shared-worktree run, not a detached clean-SHA replay. It does not model
downstream response-ready backpressure. Its scope and limits remain as stated
in the [SPAD fairness record](A10_DV_RUN_2026-10-18_SPAD_RR.md).

## Tool access and conclusion

The latest read-only license probe found both configured license variables,
but `lmutil lmstat` returned exit 241 (`SERVER_UNREACHABLE`). No VCS, URG, or
VC Formal run was launched for this audit. This access failure does not
invalidate the historical passing runs above, but it prevents claiming a new
licensed-tool replay at the comparison endpoint.

**Conclusion:** Selected V1–V4 evidence is still applicable to the explicitly
compared source scopes, with worktree-vs-clean-replay distinctions retained.
There is no single current-HEAD full A10 regression. V1–V5 remain open; in
particular, formal parity-to-writeback, residual DUT coverage disposition,
broader reset/fault interactions, top-level closure, and V5 mutation/review
remain to be completed.
