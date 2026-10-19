# A10 exact-SHA CNM protection-response mutation replay

## Scope

This is a fresh mutation-sensitivity replay for the CNM protection response
alignment defect indexed as `A10-BUG-003`. It checks whether the existing
DMA/SPAD/CNM subsystem scoreboard detects a protection error tagged from the
current request instead of the registered response. It does not recover the
original historical failure waveform or establish the historical fix commit.
The shared checkout's product RTL was not changed.

- Source commit: `6d97d6511db78f3a177b72decb715505fdaadc7f`
- Test: `dma_spad_subsystem_test`, seed `20261014`
- Environment: Rocky Linux 8.10, VCS `V-2023.12-SP1`
- Detached worktree: `/tmp/nmaforge_clean_6d97d65_cnm_protection_mutation_20261019`
- Artifact root: `/tmp/nmaforge_a10_main6d97d65_cnm_protection_mutation_20261019`

## Mutation and commands

The same subsystem test and seed were compiled and run on baseline, a
single-line mutant, and restored source. The mutant changed only
`rtl/top/fabric/memory/ai_accel_memory_fabric.v`:

```verilog
assign cnm_protection_error = cnm_protection_error_rsp_r;
```

was replaced with:

```verilog
assign cnm_protection_error = cnm_protection_error_request;
```

This intentionally removes the registered response tag and uses the current
combinational request's protection status. The diff was exactly one insertion
and one deletion in that RTL file.

Each phase used `dv/subsystem/dma_spad/sim`'s `subsystem_compile` flow with
`UVM_TEST=dma_spad_subsystem_test`, `SEED=20261014`, then ran its isolated
`simv` with the same test/seed and line, condition, FSM, toggle, branch, and
assertion coverage enabled. VCS was `/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs
-licwait 1`. Exact phase command transcripts are stored at `baseline/commands.txt`,
`mutant/commands.txt`, and `postrestore/commands.txt` under the artifact root.

## Results

| Phase | Result |
|---|---|
| Baseline | `SPAD_CNM_PROTECTION_PASS` and `TEST_DONE`; UVM warning/error/fatal `0/0/0`. |
| Mutant | Detected by 15 UVM errors: eight `SPAD_CNM_RSP_ERR` response-tag mismatches, two OOB source `ERR_PROTECTION` status failures, and protected-write/sentinel failures including unauthorized result writes and destination corruption. UVM reached `TEST_DONE` but reported `0/15/0`; the normal simulator return code is not a pass criterion. |
| Post-restore | `SPAD_CNM_PROTECTION_PASS` and `TEST_DONE`; UVM warning/error/fatal `0/0/0`. |

Baseline, restored, and post-restore RTL SHA-256 matched:
`9e839d9bc7dcb8ecab5b75211485c37ffe047af71ed4ddec7880fea5087a9db2`.
Mutant RTL SHA-256 was
`9dda8bdd0e96aeb4810ba8e0b83442968c0286e87858ac5cc3497342c2f528ff`.
Mutation patch SHA-256 was
`6bf23fdc6a34511f31fd1af479e1959ae47f1bc36c126f27ee25095ce58d950d`; captured
Git diff SHA-256 was
`9482196d397e6d180131d1eb8d31bda651eb42e7ea7c9a6c9d2ab108c42d4227`.

The detached worktree was clean after restore; shared checkout HEAD/status were
unchanged; and no VCS, simv, or URG process remained. Logs, compile logs, VDBs,
exact command transcripts, source/patch hashes, summary, and `SHA256SUMS` are
under the artifact root. This is hash-identified evidence, not an immutable
archive. It confirms current checker sensitivity only; the historical failing
artifact and immutable fix SHA remain unavailable, so V5-BUG-01 and overall V5
closure remain open.
