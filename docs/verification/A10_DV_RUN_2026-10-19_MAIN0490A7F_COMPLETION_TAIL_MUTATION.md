# A10 V5 exact-SHA completion-word/tail mutation replay

Date: 2026-10-19
Source commit: `0490a7f33534eada08870a36302e4fef200721ec`
Scope: targeted checker-sensitivity replay of the four-word completion commit contract.

## Contract and mutation

The completion record is four 32-bit words. The completion writer must accept
all four scratchpad writes before asserting `done`; only then may the command
processor advance `CPLQ_TAIL`. This is stated in `SPEC_ZH.md` and
`ARCHITECTURE.md`, implemented by `ai_completion_writer`, and checked by the
existing CP monitor/assertion and word-count scoreboard.

The isolated mutant changed only:

```diff
- localparam [1:0] LAST_COMPLETION_WORD = 2'd3;
+ localparam [1:0] LAST_COMPLETION_WORD = 2'd2;
```

This causes the writer to leave `ST_WRITE` after accepting word 2, omitting
word 3 and asserting completion early. No checker or product source in the
shared checkout was changed.

## Reproduction

- Exact source commit: `0490a7f33534eada08870a36302e4fef200721ec`.
- Isolated detached worktree: `E:\tmp\nmaforge_v5_completion_0490a7f_evidence_wt`.
- Test: `ai_cp_test`, seed `20261019`.
- Environment: Rocky Linux 8.10, VCS `V-2023.12-SP1_Full64`.
- Each phase used the project's `rocky-wsl-bridge` task runner and ran:

```bash
make -C dv/block/command_processor/uvm run \
  OUT=/mnt/e/tmp/nmaforge_v5_completion_0490a7f_evidence/<phase> \
  SEED=20261019
```

`<phase>` was `baseline`, `mutant`, or `restore`. Each compile log, run log,
and simulation coverage database is retained outside the repository at
`E:\tmp\nmaforge_v5_completion_0490a7f_evidence\{baseline,mutant,restore}\`.

## Results

| Phase | Make / bridge result | UVM INFO/WARNING/ERROR/FATAL | Evidence |
|---|---:|---:|---|
| Baseline | 0 / 0 | `67/0/0/0` | `TEST_DONE`, `scenario_bins=31/31`, `fetches=8 launches=8 completions=8` |
| Mutant | 2 / 1 | `67/0/314/0` | `TEST_DONE`; errors include early-tail, fewer-than-four-word, word-3 mismatch; coverage reports word-3 bin missed |
| Restore | 0 / 0 | `67/0/0/0` | Same completion and scenario markers as baseline |

The decisive existing checker messages include:

- `CPLQ tail advanced before all four word handshakes`
- `writer done without four accepted words`
- `word3 element count mismatch`
- `completion word bin 3 not hit`

All three compile logs were independently checked and contained no
`Warning-`/`Error-` diagnostics. The baseline and restored
`ai_completion_writer.v` digests match within the isolated worktree
(`F765FDB1ACCEE57DA3968E6FC5D9BBD84D45DAA9C6B9E144F8CF98CB2A757764`,
CRLF bytes); the equivalent LF checkout digest is
`33BCBE0F52C2E78D6C45EB6A320256C8D2D10E26552B3A94AFDC45C29A794CD4`.
The mutant digest reported by the isolated run is
`8AF8E9F4D64623B4E4E4DD9DFD527D71BDEADA37FB1808FBB10EC6C6DEEE0A17`.
The difference between baseline LF/CRLF digests is line-ending representation,
not RTL content.

The shared checkout remains at the same commit, and its pre-existing untracked
user files were not changed. This proves sensitivity of the current CP
completion checkers to this specific mutation; it does not close all V2
completion lifecycle cases or V5 mutation/coverage closure.
