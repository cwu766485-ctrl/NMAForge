# Compute Cluster Matrix Line-Stall Top Verification — R71

Date: 2026-10-30
Run ID: `R71-MATRIX-LINE-TOP-3S-CFCD4DB`
Exact clean verification/test SHA: `cfcd4dbe69d54beaaa93ac2f350279a6b95cb144`
Product RTL SHA: `cc357830923e3dd7beda114b4d761fde839b01a7`
SPEC contract SHA: `f916874a9ce60741a4516eaf9e33ebcae4a676c2` (v1.7)
Tools: Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`

## Scope and result

R71 closes the missing **real-top Matrix Line write-back stall observation** in the selected request-stability test. It runs a legal 16×32×64 Matrix GEMM concurrently with a CNM GEMV (M=16, 32 packed dot4 words per output). Matrix operands/output and CNM operands/output use disjoint SPAD ranges. The production dispatcher, compute SPAD mux, `ai_spad_arbiter`, response routing and four-bank behavioral SPAD remain active.

The passive Top UVM monitor observes the Matrix Line `valid/ready` and checks `write`, address, 128-bit payload and WSTRB stability after each denied cycle. Each seed observes 84 consecutive-stall stability checks and zero violations. The test independently compares all 512 Matrix output words, all 16 CNM outputs, both completion payloads, and ordered retirement. Each run's memory scoreboard checks 10,708 words with zero mismatch, unknown read, or stale response; UVM warning/error/fatal is `0/0/0`.

| Seed | Matrix Line stability checks | Violations | Full memory scoreboard | UVM W/E/F |
|---:|---:|---:|---|---:|
| `20261030` | 84 | 0 | 10,708 words; 0 mismatch/unknown; stale epoch 0 | 0/0/0 |
| `20261025` | 84 | 0 | 10,708 words; 0 mismatch/unknown; stale epoch 0 | 0/0/0 |
| `20261026` | 84 | 0 | 10,708 words; 0 mismatch/unknown; stale epoch 0 | 0/0/0 |

Top Smoke (`make ai_smoke`) and the 20-case seeded Top regression (`make ai_run AI_RANDOM_CASES=20 AI_SEED=12345`) also pass at this exact clean SHA. Top Smoke reports the existing fixture warning `[LOOP-REROLL-ENABLED]`; it is retained as a warning, not counted as a clean compile.

## Exact clean-worktree commands

The detached worktree is `/tmp/nmaforge_line_stall_clean_cfcd4db` and has no source modifications.

```sh
cd /tmp/nmaforge_line_stall_clean_cfcd4db/dv/uvm/sim
make uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_line_stall_clean_cfcd4db_uvm \
  COMPUTE_CLUSTER_UVM_SEEDS='20261030 20261025 20261026'

cd /tmp/nmaforge_line_stall_clean_cfcd4db/dv/subsystem/top_smoke/sim
make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

All three commands exited zero. The UVM Makefile gate requires the new `CLUSTER_MATRIX_LINE_STALL_PASS` marker to report at least one stability check and zero violations for every seed.

## Evidence hashes

| Artifact | SHA-256 |
|---|---|
| UVM compile log | `bb4697139dd2f1818b184e1cdab3c6eabb15126200037c1514157f1d763e4432` |
| UVM seed `20261030` log | `b0b2d148bb7812b725623a7553bdfd4fff16a2af0abd9b0edae39ebee0e12039` |
| UVM seed `20261025` log | `51e40162e34dd1e268d9b1799936bbad0d595418d3b264e8cba4cd312448cb01` |
| UVM seed `20261026` log | `275bf61c54fa742ac1f68e43c01246f2f7b6316bc9c5a30eed86f0a5ae5727eb` |
| Merged URG `asserts.txt` | `61957b987b4883313bd0eec30d32db0a4ec7676d05da34a1a44aa7183e9d5938` |
| Merged URG `groups.txt` | `cafc9747f38ede2d9488f076e6ea9914961042f4403fef66bdf254851a85177f` |
| Top Smoke compile log | `c40fc0a05f70e605e30df358a146263ca3a51815a5f9ac884d9def545689fdfd` |
| Top Smoke run log | `cbf46a99e468fd55db03863b6d0cdeca254b7bf7ab6f3919c65ca94bb26a123c` |
| 20-case Top regression log | `d0625f4aa27abec5cbd0af535b953032273f41b46f6102d5285c2e126a02c1d4` |

Artifacts are local under `/tmp/nmaforge_line_stall_clean_cfcd4db_uvm/` and `/tmp/nmaforge_line_stall_clean_cfcd4db_evidence/`; generated VCS/URG files are not committed.

## Requirement and sign-off effect

The formerly unhit top-level Matrix Line stall point in `REQ-CL-006` / `CL-COV-002` is now exercised on three clean seeds with data-integrity and payload-stability checks. This is a scoped testpoint closure only: `REQ-CL-006` remains `PARTIAL` because the full requester × stall-bin × direction/progress matrix is not closed. The 38-row RTM remains 24 `PASS-SCOPED` / 14 `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**. R71 does not qualify an unidentified external fabric or close the legal Engine × Fault × Phase × Reset cross.

No product RTL, SPEC, Checker strictness, or expected behavior was changed.
