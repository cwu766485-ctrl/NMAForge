# NMAForge A10 Bug Register

This register inventories confirmed failures found while building the A10 DV
evidence. “Fixed” means the documented directed regression passed on the
then-current worktree; it does **not** mean A10 sign-off. Original failing
waveforms/seeds and immutable fix commits are not retained for every historical
issue, so those entries remain incomplete for V5 release closure until replayed
from a fixed commit.

| ID | Area / status | Failure and root cause | Fix | Regression evidence | Remaining evidence gap |
|---|---|---|---|---|---|
| A10-BUG-001 | DMA read-error drain — fixed, historical evidence | After an accepted AXI read burst returned non-OKAY `RRESP` (or malformed `RLAST`/length), the DMA entered `ST_ERROR`; `m_axi_rready` was then low, leaving already-accepted beats/outstanding bursts undrained and allowing completion before bus quiescence. | Stop issuing new ARs, discard uncommitted read slots, enter `ST_ABORT_READ`, consume accepted response beats through each `RLAST`, then retire the error. | `ai_dma_error_stress`, seeds `314159/987654/20261014`: each seed exercised 8 read SLVERR and 8 write SLVERR beat positions. Follow-up DMA UVM 11/11, `ai_smoke`, 20-case `ai_run`, and FP/DMA/SPAD benchmark 24/24 are recorded in the [baseline](A10_DV_BASELINE_2026-10-14.md) and [project update log](../project_update_log.md). | Original failing waveform/seed and fix SHA are absent from the repository. Multi-outstanding simultaneous error and compute/SPAD contention remain outside this regression. |
| A10-BUG-002 | CNM prefetch under arbiter backpressure — fixed, historical evidence | In `ST_WAIT_B`, a B response could coincide with a next-A prefetch request. If the arbiter denied grant, the FSM stayed in `ST_WAIT_B`; the one-cycle response then disappeared and the request was lost, potentially deadlocking the lane. | Add `ST_PREFETCH_A` to hold request/address until grant, preserving the no-backpressure same-cycle path; add request-stability SVA. | Historical DMA/SPAD subsystem regression `COV_TAG=a10cnmcoveragefix`, seeds `12345/987654/20261014`, passed load/store contention; `ai_smoke` and 20-case `ai_run` also passed. Fresh exact-SHA replay at `200448cabf7801fdb1c858b4e3de1ee545a6d790`, seed `20261014`, detected the single-line fallback mutant twice with `ap_cnm_request_stable_when_stalled`, then with CNM timeout/drain failures; baseline and post-restore passed UVM `0/0/0`. See the [baseline](A10_DV_BASELINE_2026-10-14.md) and [exact-SHA replay](A10_DV_RUN_2026-10-19_MAIN200448C_CNM_MUTATION.md). | Initial failing waveform/seed and immutable fix SHA are still not retained. Current V3 workload remains a selected contention slice, not broad fairness or full lifecycle closure. |
| A10-BUG-003 | CNM protection response alignment — fixed, historical evidence | Fabric protection status was derived from the current combinationally selected request, while the CNM consumed it alongside a later registered `cnm_rsp_valid`. An out-of-range response could therefore be tagged using the wrong cycle’s protection status and incorrectly continue computation/writeback. | Latch protection status only when the CNM request is accepted and delay the tag with its registered response; retain sticky protection error in the CNM controller for retirement classification. | Historical DMA/SPAD regression `COV_TAG=a10cnmprot_matrix`, seeds `12345/987654/20261014`, passed OOB A/B reads, denied destination writes, sentinel checks, and no-reset recovery. Fresh exact-SHA replay at `6d97d6511db78f3a177b72decb715505fdaadc7f`, seed `20261014`, detected the one-line current-request-tag mutant with 15 UVM errors: response-tag mismatches, OOB source status failures, and unauthorized result writes/destination corruption. Baseline and post-restore passed `0/0/0`. See the [historical run record](A10_DV_RUN_2026-10-16.md) and [exact-SHA replay](A10_DV_RUN_2026-10-19_MAIN6D97D65_CNM_PROTECTION_MUTATION.md). | Original failure artifact and immutable fix SHA are absent. Protection/parity/abort/reset cross-product and broader address matrix remain open. |
| A10-BUG-004 | DMA/SPAD and DMA block assertion-coverage flow — fixed, verification infrastructure | URG assertion output was empty for a DMA block run because the Makefile passed `-cm/-cm_dir` during VCS compile but omitted them when launching `simv`; DUT assertions were not measured. | Pass the same coverage options to compile and simulation; give regressions a selectable `COV_ROOT`; regenerate isolated VDBs and merge them. | DMA/SPAD corrected three-seed run produced 30 assertions: 28 successes, 0 failures/incomplete, 2 unattempted UVM RAL internals. DMA block runtime-coverage recheck: 11 tests; all 11 DMA SVA had non-empty successes, 0 failure/incomplete; `dma_cmd_cg` 14/14 variables + 5/5 crosses. See [current run record](A10_DV_RUN_2026-10-15.md). | The prior empty URG artifact is not retained. DMA RTL residual code-coverage bins still require review; keep compile/run coverage arguments synchronized in future targets. |
| A10-DV-005 | CP mixed error/abort cross — fixed, verification stimulus | Three random seeds exercised only 3/6 bins of `prefix failure kind × abort delay class`; the UVM tests passed, but the URG acceptance gate correctly failed. | Add optional deterministic plusargs for the mixed prefix kind and abort delay. Expand only `cov-regress` to sweep all six legal kind×class pairs for each regression seed; default non-coverage tests remain randomized. | 2026-10-15: three seeds × six cases passed; `cp_cg` reported 45/45 variables and 10/10 crosses. See [current A10 run record](A10_DV_RUN_2026-10-15.md). | This closes that functional cross only. It is not a DUT defect, nor a substitute for CP RTL/SVA coverage disposition or broader randomized interaction testing. |
| A10-BUG-006 | ABI-v7 macro descriptor high-address alignment — fixed | The CP RTL selected `{src1,src0}` as the 64-bit child-list base for v7 macro descriptors, but the shared descriptor validator also required `src1[1:0]==0`. Since `src1` is the high address word rather than an independent pointer, a legal aligned address such as `0x0000_0001_0000_1040` was rejected before child fetch. | Apply the separate `src1` alignment check only when `src1` is an independent pointer; for macro v7, check the full address alignment through its low word and retain the 64-byte list alignment check on `src0[5:0]`. Update the CP comment and ABI spec. | First focused run exposed failure at the macro success-status checker. After the fix, `CP_ONLY_CASE=22` checks parent fetch at `0x0000_0001_0000_1000`, then three external child fetches at `0x0000_0001_0000_1040/1080/10c0`; UVM severity `0/0/0`. Full CP regression and 3-seed × 6-profile URG campaign passed; 18/18 logs contain the v7 marker, `cp_cg` 49/49 + 10/10. Top `ai_smoke` and 20-case `ai_run` passed. Exact evidence is in the 2026-10-16 run record. | The initial failing simulator log was overwritten by the subsequent fixed run, so original failure artifact is not retained. Clean fixed-SHA replay and wider randomized macro-address/AXI fetch verification remain open; this fix does not close V2/V5. |
| A10-BUG-007 | CP tile launch while scheduler resources busy — fixed | In `ST_IDLE`, the CP state transition honored `scheduler_resources_idle`, but the child `ai_tile_pipeline.start` pin was driven only by `tile_start && state_r == ST_IDLE`. A tile doorbell concurrent with `dma_busy` could therefore start the tile submodule while the parent CP remained idle, creating side effects outside the lifecycle owner's admission guard. | Apply the same `scheduler_resources_idle` predicate to the child tile `start` pin; extend CP submit-guard scenario to pulse tile start while DMA is busy and check no tile/DMA/fetch/compute/head side effect before successful post-idle queue recovery. | Full CP UVM run: 29/29 scenario bins and UVM warning/error/fatal=0/0/0. Ten-seed × six-profile URG campaign: 60/60 logs/VDBs PASS; CP DUT line/condition/toggle/FSM/branch=`100.00/86.51/10.31/100.00/92.54%`; functional `cp_cg` 49/49 variables + 10/10 crosses. Top `ai_smoke` and 20-case seeded `ai_run` passed after the RTL fix. A later extension also covers abort during a completion-writer stall. | The first failing run's log was overwritten by the passing rerun; symptom/root cause/fix are documented, but original failure waveform and immutable fix SHA are absent. Broader CP fault×abort×reset coverage and clean fixed-SHA replay remain open. |

## V5 closure status

- **2026-10-19 exact-SHA replay:** the A10-BUG-001 RRESP comparator mutation
  was rerun at `7f346dd7cf75c97de660c8750f5d7833362fc25a` with
  `dma_read_slverr_test`, seed `20261016`. Baseline and post-restore passed
  with UVM severity `0/0/0` and seven recovery words matched; the inverted
  comparator was killed by seven `SB_LOAD_MISSING` errors (UVM `0/9/0`). The
  restored source hash matches the baseline and the detached worktree is clean.
  Exact commands, hashes, and artifact paths are in the
  [replay record](A10_DV_RUN_2026-10-19_MAIN7F346DD_RRESP_MUTATION.md). This
  is fresh checker-sensitivity evidence, not the missing historical failure
  artifact/fix-SHA provenance; V5-BUG-01 remains **OPEN**.
- **2026-10-19 exact-SHA replay:** the A10-BUG-002 CNM denied-prefetch fallback
  mutation was rerun at `200448cabf7801fdb1c858b4e3de1ee545a6d790` with
  `dma_spad_subsystem_test`, seed `20261014`. Baseline and post-restore passed
  with UVM severity `0/0/0`; the mutant caused two
  `ap_cnm_request_stable_when_stalled` failures, CNM timeout/drain/result
  failures, then the 150,000,000 ps testbench timeout. VCS returned RC 0, so
  explicit checker signatures—not process status—classify it as killed. The
  restored RTL hash matches baseline and the detached worktree is clean. This
  is current checker-sensitivity evidence, not the original historical failure
  artifact/fix SHA. See the [exact-SHA replay record](A10_DV_RUN_2026-10-19_MAIN200448C_CNM_MUTATION.md).
- **2026-10-19 exact-SHA replay:** the A10-BUG-003 CNM protection-response tag
  mutation was rerun at `6d97d6511db78f3a177b72decb715505fdaadc7f` with
  `dma_spad_subsystem_test`, seed `20261014`. Baseline and post-restore passed
  with `SPAD_CNM_PROTECTION_PASS`, `TEST_DONE`, and UVM severity `0/0/0`; the
  mutant produced 15 UVM errors covering response-tag mismatches, OOB status,
  and unauthorized destination writes. The restored source hash matches
  baseline and the detached worktree is clean. This is fresh checker-sensitivity
  evidence only; the original failure artifact/fix SHA remain missing. See the
  [exact-SHA replay record](A10_DV_RUN_2026-10-19_MAIN6D97D65_CNM_PROTECTION_MUTATION.md).
- Five RTL defects, one coverage-collection flow defect, and one CP
  verification-stimulus gap are indexed with symptom, root cause, fix, and
  regression evidence where available. The DMA block instance of the same
  coverage-collection defect is now also fixed and verified.
- The CP stimulus gap has since passed three seeds × six mixed kind/delay cases and URG
  closure; it was a stimulus/coverage gap, not a DUT defect. Original failing
  artifacts and immutable fix commits are still missing for historical RTL
  defects, so this is not yet a complete auditable bug lifecycle.
- Four historical targeted RTL mutations were detected on 2026-10-16. For A10-BUG-001, inverting
  `m_axi_rresp != AXI_RESP_OKAY` to `==` caused `dma_read_slverr_test`'s
  recovery-read scoreboard to report nine UVM errors (seven missing words).
  For A10-BUG-002, changing the denied-prefetch transition from
  `ST_PREFETCH_A` back to `ST_WAIT_B` caused the real DMA/SPAD/CNM test's
  `ap_cnm_request_stable_when_stalled` assertion to fail twice, followed by
  CNM timeout and result/drain checker errors. Each mutant was restored;
  the respective post-restore focused runs passed with UVM warning/error/fatal
  `0/0/0`. The CNM run terminated through the testbench's 150 µs watchdog
  (`150000000 ps`) before
  printing a final UVM summary, so it is classified from explicit SVA and
  functional-checker failures, not a severity-summary grep. For A10-BUG-003,
  replacing the delayed CNM protection response tag with the current
  combinational request caused 15 UVM errors, including source error-status
  mismatches and forbidden destination writes; restoring the tag returned the
  same regression to zero UVM warnings/errors/fatals. A separate DMA write-drain
  mutation challenge changed
  the DMA `ST_WRITE_DRAIN` exit guard so `abort_pending_r` could bypass the
  pending-B count let the abort sequence retire before its accepted B response;
  the new CNM/DMA subsystem checker caught `accepted/completed=1/0`, `pending=1`,
  `busy=0` and missed-coverage errors (2 UVM errors total). The mutant run
  reached `TEST_DONE`; after restoring the original guard, the same focused
  subsystem test passed with UVM warning/error/fatal `0/0/0`. A fifth targeted
  mutation changed the completion writer's final word index from 3 to 2; the
  CP monitor detected early `CPLQ_TAIL`, missing word 3, and failure to accept
  all four words (314 UVM errors); baseline and restore passed. The exact-SHA
  evidence is in the [completion-tail mutation run record](A10_DV_RUN_2026-10-19_MAIN0490A7F_COMPLETION_TAIL_MUTATION.md).
  These five targeted checks are not a complete mutation campaign. V5-BUG-01 and V5 release
  closure remain **OPEN**; the historical RTL defects still lack original
  failure artifacts and immutable fix SHAs. The exact-SHA DMA baseline/mutant/
restore hashes, commands, logs, and return-code disposition are recorded in
[`A10_DV_RUN_2026-10-19_MAIN9A8FDE0_DMA_WRITE_ABORT_MUTATION.md`](A10_DV_RUN_2026-10-19_MAIN9A8FDE0_DMA_WRITE_ABORT_MUTATION.md).
