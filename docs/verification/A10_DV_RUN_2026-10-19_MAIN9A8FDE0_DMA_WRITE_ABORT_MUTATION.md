# A10 V5 exact-SHA DMA accepted-write abort/drain mutation replay

Date: 2026-10-19 (Asia/Singapore)
Source commit: `9a8fde0f05c8082eca4fe9d1552dba0c068a654c`
Scope: one targeted checker-sensitivity replay for accepted AXI write response drain.

## Goal and contract

The DMA must not retire an accepted AXI write while its corresponding B response
is still outstanding. In `ST_WRITE_DRAIN`, the baseline transition waits for
`wr_pending_count_r == 0`; the subsystem test checks accepted/completed B
responses, pending count, DMA idle, shared-SPAD CNM result, and a subsequent
DMA recovery load without reset.

Relevant existing coverage/checkers are in
`dv/subsystem/dma_spad/tests/dma_spad_subsystem_test.svh`, in
`run_cnm_dma_write_abort_drain_case`. No product RTL/testbench source was changed
by this replay; the mutant was applied only in a detached temporary worktree and
reverted before the post-restore run.

## Reproducible setup

- Host/tool environment: Rocky Linux 8.10, VCS
  `V-2023.12-SP1_Full64`.
- Isolated worktree: `E:\tmp\nmaforge_a10_b004_9a8fde0`.
- Worktree HEAD: `9a8fde0f05c8082eca4fe9d1552dba0c068a654c` (detached and clean).
- Focused test: `dma_spad_subsystem_test`, seed `20261016`.
- Per-phase artifacts are under `/tmp/a10b004_{baseline,mutant,restored}*`
  in the Rocky filesystem; no VDB/logs were added to the repository.

Each phase used the same command shape, changing only `<phase>`:

```bash
cd dv/subsystem/dma_spad/sim
make subsystem_run SEED=20261016 \
  COV_TAG=a10b004_<phase> \
  SIMV=simv_a10b004_<phase> \
  COV_DIR=/tmp/a10b004_<phase>.vdb \
  RUN_LOG=/tmp/a10b004_<phase>.log \
  COMPILE_LOG=/tmp/a10b004_<phase>_compile.log \
  VCS='vcs -licwait 1'
```

## Mutation and source hashes

The isolated one-line mutation changed the `ST_WRITE_DRAIN` exit guard:

```diff
- if (wr_pending_count_r == 0)
+ if ((wr_pending_count_r == 0) || abort_pending_r)
```

| Phase | `rtl/dma/ai_axi128_dma.v` SHA-256 | Result |
|---|---|---|
| Baseline | `1213e9e365039a9075f53f10ab028fafd28336466d255b106504c4a9f705f9dc` | PASS |
| Mutant | `e926f0fedf0f38527d3fbaf2c0e4321b1ab38eccd0f810a3a04eb1adfb3bc93c` | KILLED |
| Restored | `1213e9e365039a9075f53f10ab028fafd28336466d255b106504c4a9f705f9dc` | PASS |

Independent audit verified the detached worktree HEAD, clean status, restored
source hash, all three compile/run logs, `TEST_DONE`, severity summaries, and
the scenario-specific checker signatures.

## Results

- **Baseline:** both `SPAD_CNM_DMA_WRITE_ABORT_PASS` and
  `SPAD_CNM_DMA_WRITE_ABORT_RECOVERY_PASS` appeared; UVM
  warning/error/fatal=`0/0/0`.
- **Mutant:** the regression detected the premature retirement with
  `accepted/completed=1/0 pending=1 active_b=0 active_write=0 busy=0`, and the
  `SPAD_CNM_DMA_WRITE_ABORT_COV` bin was missed. UVM severity was `0/2/0`.
  `TEST_DONE` and the later recovery marker appeared, but neither hides the
  drain failure. `make` returned nonzero due to the severity gate; the mutant is
  classified as killed by the explicit functional/coverage checker evidence.
- **Restored:** both focused markers returned and UVM severity was `0/0/0`.

## Disposition

This is a targeted mutation-sensitivity result for one accepted-write
abort/drain condition. It does not close the DMA/SPAD subsystem, global V5
mutation campaign, or A10. The historical first-failure artifact and immutable
fix SHA for the original DMA defect remain unavailable; see
[`A10_BUG_REGISTER.md`](A10_BUG_REGISTER.md) and the V5 row in
[`A10_DV_RTM.md`](A10_DV_RTM.md).
