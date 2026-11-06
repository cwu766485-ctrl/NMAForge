# NMAForge v2 TinyNPU Baseline Summary

**Status:** Fixed benchmark matrix complete; full DV remains paused/HOLD; no
ASIC sign-off claim. **Date:** 2026-11-06.

## Baseline and implementation

- NMAForge branch: `feature/npu-architecture-v2`; measured source SHA
  `219c9f26a85b9661185cd78ab6308ae3f13e3ea7` (tree at audit
  `e2e3f1d1cc7dfa4de3e3d78fd51fab76d6c43f24`).
- Product RTL SHA: `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`.
- Protected baseline: `main` R250
  `3041355528dffe856e2d5384027c6ee5df5d1b42`.
- GitHub v2 branch head at fetch:
  `5d01a88a8a2a7b1add15fbedbb02096d686824ab`; local branch was 77 commits
  ahead and 0 behind (remote tree `bf7306bdeefeca415dd221f0a29305fdcef5b72c`).
  The current task preserves the pre-existing uncommitted
  UVM fairness edit and all other worktrees.
- TinyNPU reference SHA:
  `8216c22b762011aa20c05fc2768423fd12dda59d`.

The product path reuses one 16×16 / 256-INT8-MAC Matrix array. Innovation 1
is Shape-Adaptive GEMM/GEMV (`0x52`) with bounded B-fold reuse and Next-K
prefetch. Innovation 2 is fused requantization/native tile writeback (`0x53`)
with bounded elastic Tile Forwarding. This round changed only the TinyNPU
benchmark driver/marker checks and reports/data; no product RTL was changed.

## Minimum functional evidence

| Function | Evidence | Result |
|---|---|---|
| Normal Top command/completion | Clean Top smoke, test SHA `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0` | PASS for the archived smoke scope; not full DV closure |
| INT8 GEMM | Current matched 3-shape matrix, Run ID `V2-TINY-GEMM-MATCH-S20261106`, seed `20261106` | 3/3 NMAForge Goldens PASS |
| Opcode `0x52` GEMV | Current matched 4-shape matrix, Run ID `V2-TINY-GEMV-MATCH-S20261106`, seed `20261106` | 4/4 NMAForge Goldens PASS |
| Opcode `0x53` / trained Digits MLP | `V2-DIGITS-0x53-360`, source SHA `33e85287fbf37187fccb76e97be6effe888670e9` | 360/360 exact Golden logits; 352/360 classification (97.78%); 34,761 CMDQ cycles |
| ONNX mini CNN | `V2-CNN-4B99D10-S20261029`, source replay `d1867da` | All checked intermediate tensors and 4/4 outputs PASS |

These scoped records establish core function only. Full v2 requirement closure,
coverage, mutation and formal closure are not being pursued in this round.

## TinyNPU comparison

TinyNPU array cycles are measured from its pinned Verilated RTL. TinyNPU has no
memory controller/SPAD in this experiment. Its separate common endpoint uses a
single serialized 16-byte/cycle port, logical INT8 operand bytes, INT32 output
bytes, one read-response cycle, and two initial accumulator-clear cycles.
That endpoint is **estimated, not RTL measured**. Ratios below are
NMAForge-measured cycles divided by this TinyNPU estimate.

| GEMM M×N×K | NMA cycles | Tiny array | Tiny memory estimate | NMA / estimate | NMA utilization |
|---|---:|---:|---:|---:|---:|
| 16×16×16 | 173 | 52 | 151 | 1.1457 | 9.25% |
| 16×16×32 | 259 | 100 | 231 | 1.1212 | 12.36% |
| 32×32×64 | 1,380 | 790 | 1,305 | 1.0575 | 18.55% |

| GEMV M×N×K | NMA cycles | Tiny padded-array cycles | Tiny memory estimate | NMA / estimate | NMA utilization |
|---|---:|---:|---:|---:|---:|
| 1×13×17 | 66 | 100 | 122 | 0.5410 | 1.31% |
| 8×16×19 | 148 | 100 | 164 | 0.9024 | 6.42% |
| 16×16×19 | 264 | 100 | 205 | 1.2878 | 7.20% |
| 16×16×65 | 634 | 244 | 441 | 1.4376 | 10.25% |

Both sides pass all outputs against the same deterministic INT8 operands and
independent INT32 Golden. Tiny GEMV rows are padded direct-array mappings,
not a native TinyNPU GEMV engine. Therefore the ratios do not establish a
system-level performance win. Full bytes, stall observations and run identity
are in the [GEMM](../../benchmark/v2_tinynpu_gemm_current_20261106.csv) and
[GEMV](../../benchmark/v2_tinynpu_gemv_current_20261106.csv) CSVs and matching
JSON files.

## Innovation ablations and bottlenecks

- B-fold Cache reduced cycles 22.3–41.6% and read traffic 35.2–56.5% over
  Cache OFF / Prefetch OFF in the fixed 48-point GEMV ablation. Prefetch with
  Cache ON helps M8 by about 2%, but regresses the measured M16 cases by
  0.6–0.8%.
- Fused Digits reduced the matched doorbell-to-completion window from 110,155
  to 34,761 cycles (68.44%) with byte-identical RTL logits. The R250 and v2
  layout counters have different event semantics and are not compared as
  traffic ratios.
- Tile Forwarding saved 23 cycles (about 8%) and halved source-A bank reads
  in the three-seed Matrix-core directed comparison. It is not a full Top
  CMDQ producer/consumer result.
- Large GEMM remains limited by data service: at 32×32×64 NMA utilization is
  18.55%, with 134 bank-stall, 77 line-stall, 211 arbiter-stall and 77
  writeback-wait observations. These counters overlap. Small-M GEMV remains
  underutilized; M=1 reaches 1.31% array utilization.
- The paired mini CNN is correct on both systems, but NMA's 1,985 compute +
  1,080 host-layout cycles and TinyNPU's 4,781 graph cycles use different
  timing endpoints, so there is no valid CNN speedup ratio.

## Scratchpad capacity assessment

Current organization is four banks of 32-bit words. Counts below are logical
storage only; `relative capacity` is not an actual macro count or area result.

| Total SPAD | Words/bank | Storage bits | Relative capacity |
|---:|---:|---:|---:|
| 512 KiB | 32,768 | 4,194,304 | 1× |
| 256 KiB | 16,384 | 2,097,152 | 1/2× |
| 128 KiB | 8,192 | 1,048,576 | 1/4× |
| 64 KiB | 4,096 | 524,288 | 1/8× |

Digits' fixed map reaches 351,232 bytes from SPAD base; it has at least 79,776
bytes of simultaneously initialized weights, padded inputs, hidden outputs,
logits, descriptors and completions. Its current placement therefore fits
only 512 KiB. A compact 128 KiB placement fits that static byte lower bound;
64 KiB needs streaming/reuse. The mini-CNN fixed descriptor/completion map
reaches 135,296 bytes, so its current placement fits 256/512 KiB only. No
compact remap, reduced-capacity execution, extra DMA traffic, bank-conflict,
or performance impact was measured. The <=5% loss target remains unverified.
See the [machine-readable capacity assessment](../../benchmark/v2_spad_capacity_static_20261106.csv).

The capacity result is currently limited to source/address arithmetic because
the default `python3` is 3.6.8 and cannot run the mapper's type syntax, while
Python 3.12.13 in this environment has no NumPy dependency. No packages or
system setup were changed to force a reduced-SPAD run.

Relevant fixed addresses (offsets from the SPAD base, in bytes):

| Workload | Weights / inputs | Hidden or intermediate | Output | CMDQ descriptors | CPLQ |
|---|---|---|---|---|---|
| Digits MLP | W1 `0x10000`, B1 `0x12000`, W2 `0x13000`, B2 `0x13400`, input `0x50000` | hidden `0x32000` | logits `0x3B000` | `0x38000`, 46 × 64 B | `0x3A000`, 46 × 16 B |
| `conv1x_mini` | im2col `0x10000`, conv weights `0x11000`, FC weights `0x19000` | intermediates `0x12000`–`0x1D000` | final `0x1E000` | `0x20000`, 8 × 64 B | `0x21000`, 8 × 16 B |

## Run identity and open status

- Run IDs: `V2-TINY-GEMM-MATCH-S20261106`,
  `V2-TINY-GEMV-MATCH-S20261106`; seed `20261106`.
- Tools: VCS `V-2023.12-SP1_Full64`; TinyNPU RTL model built with Verilator
  `5.052`; g++ `8.5.0`; Python `3.12.13` for artifact generation.
- NMA raw log archive:
  `/tmp/nmaforge_v2_tinynpu_evidence_20261106.tar.gz`, SHA-256
  `3cf83dea684002740ead224ac1fec60e4710c44b2fa887c718082699b51debb9`.
- Standard `git push` could not authenticate (HTTPS username unavailable,
  `gh` absent, SSH key rejected). The connected GitHub App has repository write
  permission; the final committed tree is being published as a fast-forward
  snapshot based on v2 head `5d01a88a8a2a7b1add15fbedbb02096d686824ab`. This
  preserves remote history and `main`; the local commit sequence remains
  intact locally, while the remote receives the final tree snapshot.
- Full v2 DV sign-off: **PAUSED / PARTIAL**. TinyNPU memory RTL and matched
  system endpoint: **NOT_RUN**. Reduced-SPAD mapping/timing: **NOT_RUN**.
  Current v2 PPA: **BLOCKED_ENV** (private libraries/SDC/macros absent). No
  testchip or ASIC readiness claim is made.

The fixed matrix, static capacity table and reports complete the current
bounded task. No further phase is started by this report.
