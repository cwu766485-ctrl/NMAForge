# A10 exact-SHA DMA RRESP mutation replay

## Scope

This is a fresh mutation-sensitivity replay for the DMA read-response error
checker associated with `A10-BUG-001`. It is not recovery of the original
historical failure waveform or proof of the historical fix commit. Product RTL
in the shared checkout was not changed.

- Source commit: `7f346dd7cf75c97de660c8750f5d7833362fc25a`
- Test: `dma_read_slverr_test`, seed `20261016`
- Environment: Rocky Linux 8.10, VCS `V-2023.12-SP1`
- Detached worktree: `/tmp/nmaforge_clean_7f346dd_rresp_replay_20261019`
- Artifact root: `/tmp/nmaforge_a10_main7f346dd_rresp_replay_20261019`

## Commands

The same test and seed were compiled and run against the clean baseline, a
single-line RRESP-comparator mutant, and the restored source. The mutation was
only `m_axi_rresp != AXI_RESP_OKAY` → `m_axi_rresp == AXI_RESP_OKAY` at
`rtl/dma/ai_axi128_dma.v:521` in the detached worktree.

```bash
# Baseline compile and run.
make -C /tmp/nmaforge_clean_7f346dd_rresp_replay_20261019/dv/block/dma/sim uvm_compile \
  UVM_TEST=dma_read_slverr_test \
  SIMV=/tmp/nmaforge_a10_main7f346dd_rresp_replay_20261019/baseline_retry/simv \
  COV_DIR=/tmp/nmaforge_a10_main7f346dd_rresp_replay_20261019/baseline_retry/compile.vdb \
  VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1 -Mdir=/tmp/nmaforge_a10_main7f346dd_rresp_replay_20261019/baseline_retry/csrc'
/tmp/nmaforge_a10_main7f346dd_rresp_replay_20261019/baseline_retry/simv \
  +UVM_TESTNAME=dma_read_slverr_test +ntb_random_seed=20261016 \
  +UVM_VERBOSITY=UVM_MEDIUM -cm line+cond+fsm+tgl+branch+assert \
  -cm_dir /tmp/nmaforge_a10_main7f346dd_rresp_replay_20261019/baseline_retry/run.vdb \
  -l /tmp/nmaforge_a10_main7f346dd_rresp_replay_20261019/baseline_retry/run.log

# Apply the one-line mutant only in the detached worktree, then compile/run it.
cd /tmp/nmaforge_clean_7f346dd_rresp_replay_20261019
git apply --ignore-whitespace --unidiff-zero \
  /tmp/nmaforge_a10_main7f346dd_rresp_replay_20261019/mutant_retry/one_line.patch
make -C /tmp/nmaforge_clean_7f346dd_rresp_replay_20261019/dv/block/dma/sim uvm_compile \
  UVM_TEST=dma_read_slverr_test \
  SIMV=/tmp/nmaforge_a10_main7f346dd_rresp_replay_20261019/mutant_retry/simv \
  COV_DIR=/tmp/nmaforge_a10_main7f346dd_rresp_replay_20261019/mutant_retry/compile.vdb \
  VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1 -Mdir=/tmp/nmaforge_a10_main7f346dd_rresp_replay_20261019/mutant_retry/csrc'
/tmp/nmaforge_a10_main7f346dd_rresp_replay_20261019/mutant_retry/simv \
  +UVM_TESTNAME=dma_read_slverr_test +ntb_random_seed=20261016 \
  +UVM_VERBOSITY=UVM_MEDIUM -cm line+cond+fsm+tgl+branch+assert \
  -cm_dir /tmp/nmaforge_a10_main7f346dd_rresp_replay_20261019/mutant_retry/run.vdb \
  -l /tmp/nmaforge_a10_main7f346dd_rresp_replay_20261019/mutant_retry/run.log

# Restore the captured one-line diff, then compile/run the same seed again.
git -C /tmp/nmaforge_clean_7f346dd_rresp_replay_20261019 apply -R \
  /tmp/nmaforge_a10_main7f346dd_rresp_replay_20261019/mutant_retry/rtl_mutation.patch
make -C /tmp/nmaforge_clean_7f346dd_rresp_replay_20261019/dv/block/dma/sim uvm_compile \
  UVM_TEST=dma_read_slverr_test \
  SIMV=/tmp/nmaforge_a10_main7f346dd_rresp_replay_20261019/postrestore_retry/simv \
  COV_DIR=/tmp/nmaforge_a10_main7f346dd_rresp_replay_20261019/postrestore_retry/compile.vdb \
  VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1 -Mdir=/tmp/nmaforge_a10_main7f346dd_rresp_replay_20261019/postrestore_retry/csrc'
/tmp/nmaforge_a10_main7f346dd_rresp_replay_20261019/postrestore_retry/simv \
  +UVM_TESTNAME=dma_read_slverr_test +ntb_random_seed=20261016 \
  +UVM_VERBOSITY=UVM_MEDIUM -cm line+cond+fsm+tgl+branch+assert \
  -cm_dir /tmp/nmaforge_a10_main7f346dd_rresp_replay_20261019/postrestore_retry/run.vdb \
  -l /tmp/nmaforge_a10_main7f346dd_rresp_replay_20261019/postrestore_retry/run.log
```

## Results

| Phase | Result |
|---|---|
| Baseline | `DMA_RRESP_DRAIN`; scoreboard matched all 7 recovery words; UVM warning/error/fatal = `0/0/0`. |
| Mutant | Checker killed the mutant with 7 `SB_LOAD_MISSING` errors; UVM warning/error/fatal = `0/9/0`. The mutation decision is based on checker/severity evidence, not simulator process status alone. |
| Post-restore | Same drain and 7-word recovery checks passed; UVM severity = `0/0/0`. |

Source SHA-256 before mutation and after restore matched:
`e5b8055dba552ffc0828c2473b93458f63247f34ccea68df3451ea1b4f8fe6cb`.
The mutant source SHA-256 was
`550fb781ef1c58a7165ed1616e66191911fa1e6bcac071533e8de85bc8917a6f`, and the
mutation diff SHA-256 was
`c1b43902981b895219707ecabaad9c8b09b8dd3013d43eb6697beb00391ea65c`.
The detached worktree was clean after restore, the shared checkout status was
unchanged, and the final audit found no active VCS/simv process.

Logs, VDBs, exact command transcript, summary, and `SHA256SUMS` are under the
artifact root above. This is hash-identified evidence, not an immutable
archive. The replay confirms current test sensitivity for this mutation only;
the original historical failure artifact and immutable fix SHA remain missing,
and V5-BUG-01/V5 remain open.
