# Round 27 DeiT staged Product Top evidence

## Environment

- Source/test baseline: `19254b4e6a756ca8bf54ced5b287311214e5e99c`
- Branch: `research/nmaforge-v1.2-round27-deit`
- VCS: `V-2023.12-SP1_Full64`
- Python: `/tmp/nmaforge_deit_round17_venv/bin/python` (Python 3.12.13)
- Official checkpoint snapshot: `facebook/deit-tiny-patch16-224`, local snapshot
  `b3428f18dcc7b543470d07f14b4a4157815d1880`; checkpoint SHA-256
  `e1a51b0c81ff812e079d2189352747947879fee56429e4480064a6695cb34b2c`.
- VCS executable/license environment must be supplied by the licensed host. The
  scripts do not store or print license credentials.

## Replay

From the repository root:

```bash
PYTHON=/tmp/nmaforge_deit_round17_venv/bin/python \
VCS=/usr/local/bin/vcs \
DEIT_MODEL_DIR=/home/ray/.cache/huggingface/hub/models--facebook--deit-tiny-patch16-224/snapshots/b3428f18dcc7b543470d07f14b4a4157815d1880 \
benchmark/deit/round27/reproduce_round27_staged.sh /tmp/nmaforge_deit_round27_replay
```

Set `VCS_HOME` in the shell if required by the authorized local VCS setup. The
output directory contains each stage's `compile.log`, `run.log`, workload,
manifest, and QKV readback. Canonical archived logs are stored losslessly as
`compile.log.gz` and `run.log.gz`; recorded log hashes cover the uncompressed
bytes. The archived evidence can be checked without rerunning VCS using:

```bash
/tmp/nmaforge_deit_round17_venv/bin/python \
  benchmark/deit/round27/audit_round27_staged_runs.py
```

The round26 replay entrypoints each compile and run their own Product Top. They
are intentionally separate sessions. The audit checks source Q/K/V readback
against the QKV integer Golden, all expected Product Top pass markers, workload
hashes, and the attention input hash link.
