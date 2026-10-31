# Seven-engine Abort write cutoff — R120

**Run ID:** `CL-ENGINE-ABORT-CUTOFF-R120-R119`  
**Test baseline:** R119 documentation/source baseline `438447458f214ee5a5a92136b5b3f21f446b0339`; product RTL is unchanged.  
**Tool:** Synopsys VCS/URG `V-2023.12-SP1`, UVM 1.2.  
**Result:** PASS on seeds `20261025`, `20261026`, and `20261027`; UVM warning/error/fatal counts are `0/0/0` on every seed.  
**Disposition:** The seven-engine accepted-read Abort test now checks that no output write is accepted after the engine has sampled Abort, while treating a same-edge accepted transfer as part of the SPEC v1.4 committed prefix. No requirement is closed and the full sign-off remains **HOLD**.

## Command and source identity

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r120_abort_prefix_boundary_4384474 \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

The target exits `0`, including its per-seed marker checks and URG merge. The exact changed source-file SHA-256 values used by the run are:

| File | SHA-256 |
|---|---|
| `dv/uvm/tests/sequences/ai_compute_cluster_e2e_seq.svh` | `4ed4a4555dd9dffa4bca119d1e6aec3465a9d77e97f8bf2ba340103ef83f3231` |
| `dv/uvm/sim/Makefile` | `1ac013882ccc4cf293ca0d215c734534b39fb118e23dc2e16b7bdc037c1c2615` |

Logs are outside Git under `/tmp/nmaforge_r120_abort_prefix_boundary_4384474`; their SHA-256 values are:

| Evidence | SHA-256 |
|---|---|
| `compile.log` | `ca961f1641ff6183e40af26e13387325e2374e299ced3bb373c56a7e55f64bff` |
| `seed_20261025/run.log` | `75a0ea332d90e6c3b30e5798a6cfe4b0f7a8fa8d7c3473d2a0d26f46e788c804` |
| `seed_20261026/run.log` | `ad34f094536ba35a78109bcca1a0dba0ae02c1d3db47173604e74b665afdc415` |
| `seed_20261027/run.log` | `fcb3934d08779a6419b8101724179e92a443d67cbe6653a5172e2793b36f5672` |

## Results

For every seed, the accepted-read Abort sweep passes on all seven real engines (`abort mask=1111111`), every accepted SPAD read is returned to its owner, every completion is `ERR_ABORT`, and every engine is idle before the completion is accepted. No engine accepts an output write on a cycle after it has sampled Abort (`post_abort_output_writes=0` in all `7×3` cases).

In each run, the early-cutoff sweep sees a one-write visible prefix for SFU and KV, and no prefix for Scalar, FP, CNM, Matrix, and Conv. It checks the 40 untouched sentinel words for those zero-prefix cases. The committed SFU/KV data and remaining output suffixes are checked by their dedicated per-engine Golden-prefix tests. The same suite also checks SFU `1/64`, Conv `1/4`, KV `2/8`, Matrix scalar fallback `6/16`, Matrix aligned Line `6/16` (24/64 words, full WSTRB), and CNM `1/16` output prefixes; each drains its accepted reads and completes with `ERR_ABORT`.

The full-memory scoreboard reports `33,510` checked words and zero mismatch, unknown, stale-epoch, or orphan-response errors per seed. Its summary is identical across these deterministic seeds: `writes=33111`, `line_wstrb={full:1030,partial:0,zero:0}`. These counts are testbench workload evidence, not global code coverage.

## Published-SHA clean-worktree replay

The published commit was fetched and run from an empty detached worktree before recording this replay:

| Item | Value |
|---|---|
| Published commit | `894559c0c373dcef667074d304f94164f8514fee` |
| Source tree | `4a3fccfd38ca4f46e0ef325368a7ee8b02b107be` |
| Worktree | `/tmp/nmaforge_r120_clean_894559c` (clean at invocation) |
| Run ID | `CL-ENGINE-ABORT-CUTOFF-R120-CLEAN-894559C` |
| Result | Three seeds completed; each contains the required UVM pass marker and zero warning/error/fatal counts; URG merged all three coverage databases |

Exact command:

```sh
mkdir -p /tmp/nmaforge_r120_tmp2_894559c
TMPDIR=/tmp/nmaforge_r120_tmp2_894559c make \
  -C /tmp/nmaforge_r120_clean_894559c/dv/uvm/sim \
  uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r120_clean_replay2_894559c \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

The isolated `TMPDIR` avoids VCS temporary-directory creation failures seen on the first clean replay attempt. VCS compilation completed with Verdi KDB reporting zero errors and warnings. Each seed repeated the seven-engine post-sampled-Abort suppression check (`7/7`, zero post-Abort output writes), six dedicated accepted-prefix Golden checks, 40/56 zero-prefix sentinel words, and the memory scoreboard (`33,510` checked words, zero mismatch/unknown/stale-epoch errors). The `urg_merged.log` records successful coverage database merge. The run directory is outside the repository at `/tmp/nmaforge_r120_clean_replay2_894559c`.

| Evidence | SHA-256 |
|---|---|
| `compile.log` | `f83680fd1e25c62d66507dd09708de129570ced969c78a333a0e1798b1fe571e` |
| `seed_20261025/run.log` | `045c7d3042457567f1adcb9a54a31e4147250d8087786a934d6a1434aa2b0bbb` |
| `seed_20261026/run.log` | `c095aa553c074a43ccd9940f1117f88fb612fb27345c77dc116e6927f2a64462` |
| `seed_20261027/run.log` | `384a07bf00dd944086334adcdf2b5e27f7fe211cc0f733bd162b0aa18f17703d` |
| `urg_merged.log` | `ab2941ac1506ce4fc8e784c6e958a731a198d04f0b4d0a4d3bbd605ad5cbf1b6` |

This replay verifies the published R120 tree. It does not close additional RTM requirements or change the sign-off disposition.

The original experimental checker treated any output handshake after the AXI-Lite Abort write began as illegal. The observed SFU prefix showed that this boundary did not match SPEC v1.4: an output accepted on the same sampling edge that the engine sees Abort belongs to the committed prefix. The revised checker starts the no-new-write window after that edge. Existing per-engine prefix Golden checks remain mandatory; this change does not relax product behavior or infer that untested prefixes are correct.

## Limits

This closes only the named accepted-read Abort/write-cutoff testpoint. It does not complete legal `Engine × Fault × Phase × Abort/Reset` coverage, all write-prefix cut points, or the 38-row Execution RTM. The overall disposition remains `24 PASS-SCOPED / 14 PARTIAL`; `CL-DV-v1.0` remains **HOLD**. The run used the integrated top and repository behavioral SPAD model, not ASIC SRAM timing or PPA evidence.
