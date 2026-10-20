# A10 V2 CP exact-main clean replay — environment blocked

- Date: 2026-10-20
- Target commit: `2d8050fcbc4f08accddb92f51dcfd8ec884812c9`
- Checkout: detached clean worktree at `/tmp/nmaforge_clean_2d8050f_cp_payload_20261020`; its `HEAD` matched the target commit and the worktree was clean.
- Output root: `/tmp/nmaforge_a10_clean_2d8050f_cp_payload_20261020`
- Intended scope: CP UVM/URG randomized regression for 200 seeds starting at `20262021`, followed by top `ai_smoke` if the block regression completed.

## Attempt and result

The CP make target reached VCS compilation through Rocky Linux 8.10. VCS
reported `Cannot connect to the license server` and waited for the
`VCS-BASE-COMPILE/VCSCompiler_Net` feature. The compile terminated with
`make: ... cov-compile Hangup` before simulation began.

Consequently, this attempt produced zero seed logs and zero VDBs. No URG merge
or top-level smoke was run. There is no RTL pass/fail result from this replay;
the outcome is **environment blocked**, not a design failure. The agent
stopped after the failed preflight and confirmed there were no remaining VCS,
URG, or `simv` processes. The source checkout, tracked files, and index were
not modified by the run.

A follow-up sanitized license probe found both `SNPSLMD_LICENSE_FILE` and
`LM_LICENSE_FILE` set in Rocky, but `lmutil lmstat` returned exit 241 for both.
The diagnostic classified both as **TCP timeout/pending**, not DNS lookup
failure or immediate connection refusal. The probe intentionally did not print
private license-server values.

## Reproduction command

From the repository root in Rocky Linux 8.10:

```bash
make -C dv/block/command_processor/uvm cov-random-regress \
  OUT=/tmp/nmaforge_a10_clean_2d8050f_cp_payload_20261020 \
  RANDOM_SEED_START=20262021 RANDOM_SEED_COUNT=200 \
  VCS='vcs -licwait 1' URG=urg
```

Restore VCS license-server connectivity, then rerun this exact-SHA campaign.
Only after it passes should URG and `dv/subsystem/top_smoke/sim` `ai_smoke` be
reported as current-main clean-replay evidence. Earlier working-tree campaign
results remain scoped to their own recorded source tree and are not replaced
by this blocked attempt.
