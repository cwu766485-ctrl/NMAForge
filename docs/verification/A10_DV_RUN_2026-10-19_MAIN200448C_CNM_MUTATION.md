# A10 exact-SHA CNM request-hold mutation replay

## Scope

This is a fresh mutation-sensitivity replay for the CNM prefetch-under-arbiter-
backpressure defect indexed as `A10-BUG-002`. It tests whether the existing
request-stability assertion and subsystem functional checks detect loss of a
denied prefetch request. It does not recover the original historical failure
waveform or establish the historical fix commit. Product RTL in the shared
checkout was not changed.

- Source commit: `200448cabf7801fdb1c858b4e3de1ee545a6d790`
- Test: `dma_spad_subsystem_test`, seed `20261014`
- Environment: Rocky Linux 8.10, VCS `V-2023.12-SP1`
- Detached worktree: `/tmp/nmaforge_clean_200448c_cnm_prefetch_replay_20261019`
- Artifact root: `/tmp/nmaforge_a10_main200448c_cnm_prefetch_replay_20261019`

## Mutation and commands

The same subsystem test and seed were compiled and run against the clean
baseline, one single-line mutant, and the restored RTL. The mutation changed
only the denied-next-A-prefetch fallback in `ST_WAIT_B` in
`rtl/compute/cnm/ai_bank_local_controller.v`: `ST_PREFETCH_A` back to
`ST_WAIT_B`. This drops a request when the arbiter denies the grant instead of
holding it until acceptance. The diff was exactly one insertion and one
deletion in that file.

Each phase used the `dv/subsystem/dma_spad/sim` `subsystem_compile` flow with
`UVM_TEST=dma_spad_subsystem_test`, `SEED=20261014`, followed by its isolated
`simv` with `+UVM_TESTNAME=dma_spad_subsystem_test`,
`+ntb_random_seed=20261014`, and line/condition/FSM/toggle/branch/assertion
coverage enabled. VCS was `/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1`.
The phase-specific compile/run commands are preserved in
`commands_all.txt` under the artifact root; logs and coverage databases are in
`baseline/`, `mutant/`, and `postrestore/`.

## Results

| Phase | Result |
|---|---|
| Baseline | Passed with UVM warning/error/fatal `0/0/0`. |
| Mutant | Detected: `ap_cnm_request_stable_when_stalled` failed twice. Functional checks reported `SPAD_CNM_TIMEOUT`, missing CNM responses/results (`SPAD_CNM_DRAIN` and related result/writeback failures), then the testbench timed out at `150000000 ps`. VCS returned RC 0, so the mutant is classified as killed by the explicit assertion and functional failure signatures, not by process status. The testbench timeout occurred before a final UVM summary was emitted. |
| Post-restore | Passed the same test and seed with UVM warning/error/fatal `0/0/0`. |

Original/restored/post-restore RTL SHA-256 matched:
`2022fff98d362f99a13eb1ee34b7c3d24ed8720b902e42b98b62fe981710ab8c`.
Mutant RTL SHA-256 was
`68dd32dd62a0dde960c5bf8b6a98839fccd58dffbb417dd3a2740407eefb794f`.
The generated mutation patch SHA-256 was
`6e6614b6a11d31403f65248e10fcb32bfdb9ad66a2f9ab054130996316cde835`; the
captured Git diff SHA-256 was
`e723a5114a10fb637bd5e4ee5c32f1917fb75f091ba2666858affcee766e03a2`.

The detached worktree was clean after restore, shared checkout HEAD/status were
unchanged, and no VCS/simv process remained. `result_summary.txt`, exact
commands, logs/VDBs, source/mutation hashes, and `SHA256SUMS` are under the
artifact root. These are hash-identified artifacts, not an immutable archive.
This fresh replay confirms checker sensitivity only; the historical failing
artifact and immutable fix SHA remain unavailable, so V5-BUG-01 and overall
V5 closure remain open.
