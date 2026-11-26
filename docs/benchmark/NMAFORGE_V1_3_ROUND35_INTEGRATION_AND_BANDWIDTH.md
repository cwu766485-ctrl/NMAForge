# NMAForge V1.3 Round 35 — Branch Integration, 512 KiB Standard SPAD, DMA Bandwidth

**Disposition: `STEP1_PASS`.** This covers integration, the SPAD default and
DMA bandwidth characterization only. DMA/compute overlap, the GPT-2 small /
distilgpt2 deployment, DeiT Layer-0 closure and the Round-35 innovation items
are the next steps.

## 1. Integration line

`integration/nmaforge-v1.3` consolidates the active work:

- It is the Round 34 tip merged with `feat/shape-adaptive-gemv-v2` (Python 3.12
  standardization, P0 evidence, A–E review, shape-adaptive data).
- It is a superset of `main`, `origin/main` and
  `candidate/frontend-closeout`, so no product evidence is lost.

Conflict resolution:

- The UVM fixture map keeps the Round 33/34 implementation. The working
  branch's standalone `ai_compute_cluster_spad_map` class is retained but
  unused.
- Python defaults to 3.12.
- Docs keep both sides.

Validation on the merge commit `d4c29ced`:

| Check | Result |
|---|---|
| `ai_smoke` (seed 20261122) | PASS |
| `ai_run AI_RANDOM_CASES=20 AI_SEED=12345` | PASS |
| SFU stream equivalence (3 seeds) | PASS |
| GPT-2 H64 decode | Bit-exact, 384,617 cycles |
| Compute Cluster UVM, 128/256/512 KiB × 3 seeds | PASS, UVM_ERROR=0, UVM_FATAL=0 |

Branch inventory at this point:

- 197 local branches. 73 are fully merged into the integration line; 124 have
  unique commits (55 `codex/*`, 24 `work/*`, 17 `research/*`, …).
- 349 worktree records, 336 of them prunable.
- `integration/port-missing-fixes-20261121` holds an unmerged
  `ai_spad_arbiter` fairness fix (`daae6b61`: Matrix/CNM banked round-robin),
  its fairness coverage and formal proofs. It should be brought in next.
- No branch was deleted. Deletion and archiving await owner approval.

## 2. 512 KiB standard SPAD

`ai_accel_top.SPAD_WORDS_PER_BANK` now defaults to 32768 (512 KiB). Both SPEC
files were updated. The host aperture is `SPAD_BASE + SPAD_INFO`
(`0x00010000..0x0008ffff`).

Flows that pin a size are unaffected:

- verification flows pass explicit sizes;
- SpyGlass uses 256 words/bank;
- the A7 FPGA flow uses 4096; the ZU15EG flow uses a variable.

The capacity rationale is the DeiT-Tiny per-layer working set with
query-block scheduling and weight streaming, about 445 KB:

| Item | Size |
|---|---:|
| INT32 residual stream | 151 KB |
| K/V | 76 KB |
| Score / probability blocks | 40 KB |
| FFN-hidden block | 49 KB |
| Weight double buffer | 96 KB |
| Queues | 32 KB |

256 KiB cannot hold this; Round 30 attention alone peaked at 212 KB.

## 3. DMA bandwidth

New bench: [`dv/block/dma/perf`](../../dv/block/dma/perf), `make dma-bw-sweep`.

- **DUT:** the production `ai_axi128_dma`.
- **Memory model:** a new performance model with one beat per cycle,
  pipelined first-beat latency, and outstanding admission.
- **Checks:** every loaded word is checked.

The existing `axi_memory_model` is a protocol-stress model. It emits at most
one R beat every two cycles plus inter-burst bubbles, so its 2 GB/s ceiling
must not be read as DMA capability.

Findings:

- **Burst length.** Beat counters were 5 bits wide, so `MAX_BURST_BEATS` above
  16 failed with an RLAST mismatch. They are now sized by
  `$clog2(MAX_BURST_BEATS+1)`; at the default of 16 the logic is identical.
  The top exposes `DMA_MAX_BURST_BEATS`, still 16 per SPEC ("burst 最多 16
  beats").
- **Large transfers.** Percent of the 16 B/cycle peak for ≥64 KiB transfers
  with 4 outstanding reads ([CSV](../../benchmark/performance_dominance/round35/evidence/dma_load_bandwidth_sweep.csv)):

| Memory latency | 16 beats | 32 beats | 64 beats |
|---|---:|---:|---:|
| 25 cycles | 99% | 99% | 98–99% |
| 50 cycles | 76% | 98% | 97–99% |
| 100 cycles | 48% | 77% | 96–99% |

- **Small transfers.** 1 KiB transfers reach only 30–58% at any burst length,
  because the first-beat latency dominates. This is a Little's-law limit
  (≈ outstanding × burst bytes / latency).
- **System effect of 32-beat bursts.** It was measured with the 32-beat build
  on Product Top. GPT-2 H64 per-layer weight DMA went 14,982 → 14,694 cycles
  and the decode total 384,617 → 384,329 cycles. DeiT R31 Wo DMA went
  11,670 → 11,460 cycles. Both are bit-exact.
- **Why the system gain is small.** Workloads issue many 1 KiB host-fenced
  DMAs, so the fixed per-transaction cost dominates.
- **Remaining DMA levers:** coalesced large weight transfers, and DMA
  descriptors in the CMDQ event chain overlapping compute (today a
  compute/DMA gate and register-driven DMA prevent overlap).

Burst-32 validation:

- DMA block UVM regress: PASS, 19 tests, UVM_ERROR/FATAL=0.
- Compute Cluster UVM at 512 and 128 KiB × 3 seeds: PASS.
- GPT-2 and DeiT: PASS.
- `ai_smoke` **fails** three directed checks that encode the SPEC 16-beat
  contract, which is why the product default stays at 16.

16-beat product default validation: `ai_smoke` and the 20-case seeded
regression pass.

**Decision needed.** Moving the product to 32 beats requires a SPEC v7.4 →
v7.5 change (burst limit and `NUM_READ_OUTSTANDING`) and an update to the
three smoke expectations so they are derived from the parameter.

## Not run

- DC/PPA. The 32-beat read buffer is 16 kbit of flops; the 64-beat buffer is
  32 kbit.
- SpyGlass.
- DDR controller modeling beyond fixed latency and throughput.
