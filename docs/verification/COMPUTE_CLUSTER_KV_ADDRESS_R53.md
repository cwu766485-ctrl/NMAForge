# Compute Cluster KV Address Boundary — R53

**Run ID:** `KV-ADDR-CONTRACT-F916874-3S`  
**Date:** 2026-10-30  
**Product/test SHA:** `f916874a9ce60741a4516eaf9e33ebcae4a676c2`  
**Parent published closeout SHA:** `fc370aad6b8360af9affb52cb30909ec97d79be3`  
**Clean checkout:** `/tmp/nmaforge_kv_r53_clean_f916874` (detached at the exact SHA)  
**SPEC:** Compute Cluster v1.7; this run covers the new KV byte-address alignment and overflow contract.  
**Tools:** Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.

## Result

PASS on seeds `20261030`, `20261025`, and `20261026`. Each seed passed the
existing CNN/KV random-latency suite and all eleven new KV address testpoints:
ten invalid-address/configuration cases plus one legal final-SPAD-word
read/write case. The Makefile gate requires every marker `case=0..9` and the
boundary marker; omission or duplication cannot silently count as closure.

The invalid cases check the completion error code `ERR_CONFIG=1`, no asserted
SPAD request, no accepted read, and no write side effect. The legal boundary
case copies a word to and from address `0x0007fffc`, the last 32-bit word in
the modeled 512 KiB SPAD, and checks the adjacent sentinel.

| Testpoint | Stimulus / expected checker result |
|---|---|
| `KV-ADDR-001` | `token_index × token_stride` exceeds 32 bits; reject before SPAD |
| `KV-ADDR-002` | Individually representable token/head products overflow when summed; reject |
| `KV-ADDR-003` | KV_WRITE cache destination plus final word offset overflows; reject |
| `KV-ADDR-004` | KV_WRITE linear source plus final word offset overflows; reject |
| `KV-ADDR-005` | KV_READ cache source plus final word offset overflows; reject |
| `KV-ADDR-006` | KV_READ linear destination plus final word offset overflows; reject |
| `KV-ADDR-007` | Unaligned source base; reject |
| `KV-ADDR-008` | Unaligned token byte stride; reject |
| `KV-ADDR-009` | Unaligned destination base; reject |
| `KV-ADDR-010` | Unaligned head byte stride; reject |
| `KV-ADDR-011` | Legal `0x7fffc` cache write/read round trip; data and adjacent sentinel match |

## Per-seed evidence

| Seed | Result | Accepted SPAD reads / responses | Ready-stall cycles | Max response delay | Address testpoints |
|---:|---|---:|---:|---:|---:|
| 20261030 | PASS | 4,034 / 4,034 | 2,510 | 7 | 11/11 |
| 20261025 | PASS | 4,442 / 4,442 | 2,790 | 7 | 11/11 |
| 20261026 | PASS | 4,581 / 4,581 | 2,876 | 7 | 11/11 |

Each run also passed 25 convolution cases (12 depthwise), 27 KV round trips,
the existing Conv/KV fault cases, two late-fault prefix checks, reset/recovery,
and response accounting. No read response was orphaned or left pending.

## Coverage and diagnostics

The address-contract directed testpoint group is **11/11 per seed** (33/33
seeded observations). This is a testbench marker/checker gate, not an URG
functional-coverage percentage.

The DUT-only URG scope is the instantiated CNN and KV engines. The KV engine
reports line/condition/FSM/branch coverage `100.00/98.77/73.33/96.97%`; the
combined two-engine dashboard reports `100.00/93.63/65.91/97.37%`. The raw
KV FSM has 11/15 transitions. Four remain unhit:
`ST_DONE→ST_ERROR`, `ST_READ_WAIT→ST_IDLE`, `ST_WRITE→ST_ERROR`, and
`ST_WRITE→ST_IDLE`. No state forcing or formal-unreachable claim was used;
these remain open coverage dispositions. The condition miss includes a
start pulse while the engine is non-idle, which this legal workload does not
apply. No SVA, formal, mutation, full UVM, or ASIC PPA result is claimed by R53.

The KV block compile log has no `Warning-`, `Error-`, `[TFIPC]`, or `Fatal`.
Clean-SHA `make ai_smoke` and `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345`
both report `TEST PASS`. Top Smoke retains the previously known
`LOOP-REROLL-ENABLED` fixture warning; the KV change introduces no additional
warning.

## Reproduction and artifacts

```sh
make -C dv/block/compute/cnn_kv/sim random-latency-regress \
  SEEDS='20261030 20261025 20261026' \
  OUT_DIR=/tmp/nmaforge_kv_r53_clean_f916874 \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs

/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg -full64 \
  -dir /tmp/nmaforge_kv_r53_clean_f916874/coverage.vdb \
  -format text -report /tmp/nmaforge_kv_r53_urg_report_f916874 \
  -log /tmp/nmaforge_kv_r53_urg_report_f916874.log

make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

The last two commands run from `dv/subsystem/top_smoke/sim` in the same clean
worktree. Logs and reports are under `/tmp`; no generated VCS/URG database is
checked in. The selected SHA, command, seeds and evidence directory are
reproducible from a fresh checkout.

## Remaining scope

R53 closes the new KV 32-bit arithmetic and alignment contract slice. It does
not close `OPEN-CL-002` for every Engine's descriptor ranges, aliasing and
zero-value rules, nor does this block-level test replace a top-level SPAD
Protection-region denial test for KV. The overall RTM remains 24
PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` remains HOLD.
