# Compute Cluster KV Cache accepted-write Abort prefix — R109

**Date:** 2026-10-30  
**Exact code/test SHA:** `5c212a302b0df6ea0f3815ccdf085e139cb4104f`  
**Product RTL/SPEC baseline:** R99 `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`; R109 changes the UVM sequence and regression gate only.  
**Run IDs:** `CLUSTER-KV-ABORT-WRITE-PREFIX-R109-3S`, `CLUSTER-MUTATION-R109-28`, `TOP-SMOKE-R109`, `TOP-RANDOM-R109-20`  
**Tools:** Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`.

## Testpoint

The real top executes a legal eight-word KV cache write for `head=1`, `token=2`, with token/head strides of 16/64 bytes. The cache slice begins at `dst+96`; source and destination use separate scratchpad ranges. The sequence waits for the first real accepted KV cache write, issues software Abort, and records every accepted read and write. It checks contiguous output addresses, copied Golden data for the committed prefix, all untouched output sentinels, guards immediately before and after the cache slice, `ERR_ABORT` completion ownership, and accepted-read response drain.

Each seed aborts after exactly 2/8 output writes. Three accepted reads return 3/3 responses. The two-word committed prefix is bit-exact; the six-word suffix and both guards remain unchanged.

## Reproduction

Clean detached worktree: `/tmp/nmaforge_r109_clean_5c212a3`, HEAD `5c212a302b0df6ea0f3815ccdf085e139cb4104f`:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r109_clean_replay_20261030 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg

VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat \
make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r109_clean_replay_20261030 \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r109_clean_mutations_20261030 \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg

cd dv/subsystem/top_smoke/sim
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat make ai_smoke
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_linux_compat \
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

All gates exit `0`. Every UVM seed has the `CLUSTER_KV_ABORT_WRITE_PREFIX_PASS` marker, UVM warning/error/fatal `0/0/0`, and `focused_compute_cg_applicable=100.0%`. The memory scoreboard checks 33,510 words per seed with zero mismatch, unknown, stale, or orphan responses; all pending response queues end at zero. Compile has no `Warning-`, `Error-`, or `[TFIPC]` messages. The checker-sensitivity campaign passes 28/28 expected checker catches. Those are passive observation mutations, not DUT fault injection or a DUT mutation score. Top Smoke and the 20-case seeded Top test print `TEST PASS`; the existing `[LOOP-REROLL-ENABLED]` fixture warning remains.

## Results

| Seed | Accepted KV output prefix | Read responses | Scoreboard | Focused applicable coverage | UVM W/E/F |
|---|---:|---:|---:|---:|---:|
| `20261025` | `2/8`, head 1/token 2, offset 96 | `3/3` | 33,510 checked; zero mismatch/unknown/stale/orphan; pending queues empty | `100.0%` | `0/0/0` |
| `20261026` | `2/8`, head 1/token 2, offset 96 | `3/3` | 33,510 checked; zero mismatch/unknown/stale/orphan; pending queues empty | `100.0%` | `0/0/0` |
| `20261027` | `2/8`, head 1/token 2, offset 96 | `3/3` | 33,510 checked; zero mismatch/unknown/stale/orphan; pending queues empty | `100.0%` | `0/0/0` |

Completion task ID is `0x0775`, status/error is `ERR_ABORT=0x32`. The cache output is checked at `dst+96`; address and data are observed at the accepted Engine request boundary and independently read back from the full SPAD image.

## Artifact hashes

Generated logs and databases remain outside Git.

| Artifact | SHA-256 |
|---|---|
| Clean UVM compile log | `6750b690cff330488e1341514ffcc8b1424921385947ea33a4170a0c7839b151` |
| Seed `20261025` log | `bc4fac249f5b768c9fbf3018d4ef53e141d9719f7b89ab6f48daed0c02a64b5e` |
| Seed `20261026` log | `9ce87de58c3c3406095484f4457eef4e7253253cf85298486fd27d5b242f82e2` |
| Seed `20261027` log | `3b3cc48f73a9d56f9d3c22ce72a0f74116e279be855f7fde77b493fb8d4585cb` |
| URG merged log | `1375f7cbf3204a5b6bef4cd1254313df2aa90da6e8931df7632f1d4818766386` |
| 28 mutation log SHA-256 manifest | `/tmp/nmaforge_r109_mutation_SHA256SUMS.txt`, SHA-256 `410893c13d2e9392b98e9e38af0bc7010d5556f18b767b0a00441e1253c329e2` |
| Top Smoke compile log | `dv/subsystem/top_smoke/sim/ai_comp.log`, SHA-256 `933a618c3be89ceda895cc5d83c423334de5fc1b93d428e35472a76b45d94b12` |
| 20-case Top simulation log | `dv/subsystem/top_smoke/sim/ai_accel_smoke.log`, SHA-256 `bad8edec7593c76e300a1d5f81c9069c136dedc0557ffa2faba5987b3cac3fcd` |

## Disposition

R109 adds one legal real-top KV Cache writeback Abort prefix with a nonzero head/token address offset. It strengthens `REQ-CL-017/019` fault-prefix evidence and `REQ-CL-025` address/data checking. It does not close the remaining engine × fault × phase × reset combinations or every KV head/token/stride/Abort cut point. The RTM remains `24 PASS-SCOPED / 14 PARTIAL`; `CL-DV-v1.0` remains **HOLD**. Product RTL, SPEC, and error ABI are unchanged.
