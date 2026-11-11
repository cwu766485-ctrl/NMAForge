# SPAD configuration regression — Gate 1

Date: 2026-11-11 Asia/Singapore. Status: **GATE_0_1_PASS_SCOPED**; archived evidence validation passed. Dedicated branch: `feat/spad-128k-closure`; no merge into `nmaforge`.

Baseline commit is `95c4387bb0ac57ff4fa427fd3c1202320ad0940b`. Evidence is from the candidate source files identified individually in `benchmark/research/spad128/manifest.json`; logs containing the baseline HEAD were generated from an uncommitted candidate and must not be attributed to pristine baseline RTL. The final commit contains this exact recorded source set and evidence. `regression.csv` records each configuration, actual result, evidence file and full SHA-256. `evidence_sha256.json` covers archived artifacts. VCS: V-2023.12-SP1_Full64; Python 3.12; Verilator 5.052.

## Mandatory results

| Configuration | Test | Actual result |
|---|---|---|
| 128 KiB / 8192 words/bank | Full Top Smoke; 20 seeded cases, seed 12345 | PASS; final TEST PASS required |
| 128 KiB | GEMM/GEMV, product 0x52 dense/tails, 0x53 | PASS; existing exact descriptor/line/tail Golden markers |
| 128 KiB | Host/DMA/CMDQ/CPLQ boundary probes | PASS; first/last word/line; OOB/alignment; crossing/error/drain/recovery |
| 128 KiB | DMA error stress | PASS; eight read/eight write injected AXI error cases, accepted-burst drain |
| 128 KiB | SPAD arbiter directed | PASS; RR, control priority, response ownership, parity alignment |
| 128 KiB | Stage B SRAM fault counterexample | PASS; fresh parity error detected, protection/denied write/recovery retained |
| Capacity-independent checker | Protection directed/random | PASS; 25 directed+512 random; not a physical SRAM-capacity test |
| 128 KiB | Reset/abort/backpressure | PASS scoped; accepted read/write drain, compute abort, all 21 engine pairs, reset recovery |
| 128 KiB | Trained 570164-MAC CNN, three mappings | PASS all 20800 Golden words/mapping + independent physical-layout Golden |
| 128 KiB | H16 GELU16, eight persistent decode tokens | PASS logits/KV/intermediates; 65771 cycles =8221.375/token |
| 128 KiB | H32 L2/H2/C16/FFN128/V32 | PASS four prefill+eight decode; 92928 Golden words; 367788 decode cycles =45973.5/token |
| 128 KiB | Digits MLP capacity-aware layout | PASS 360 samples, 46 descriptors, independent hidden/logits; accuracy352/360=97.78% |
| 128 KiB | Ten-class trained MiniCNN capacity-aware layout | PASS 396 RTL runs, all intermediate Golden exact; accuracy384/396=96.97% |
| 512 KiB /32768 words/bank | Basic full Top Smoke+20 seeded cases and capacity boundaries | PASS; SPAD_INFO=524288; same RTL/source list |
| 128/512 KiB | Allocator/tensor/queue overflow rejection | PASS; numerical payload/descriptor values identical across capacities |
| Valid/invalid geometries | 8192/32768 valid, depth12288, banks8, row12, mismatched bytes | PASS; four invalid configurations emit time-zero Fatal |

The pinned four-class conv1x_mini was additionally replayed during bring-up: eight descriptors,1874 compute cycles,1080 host-layout cycles,3360/1600 compute read/write bytes; byte-exact outputs/intermediates. This is not a new TinyNPU matched timing result.

## Performance preservation

| Workload / existing mapping | Baseline → candidate cycles | Accepted compute read/write B | Useful MAC/cycle |
|---|---:|---:|---:|
| CNN legacy | 65429 →65429 CMDQ | 130624 /83200 | 8.7142 |
| CNN first fused | 22983 →22983 CMDQ | 77376 /29952 | 24.8081 |
| CNN both fused row-major | 12351 →12351 CMDQ | 64064 /16640 | 46.1634 |
| H16 eight-token decode | 65771 →65771 | 72448 /42112 | See persistent per-token CSV |
| H32 eight-token decode | 367788 →367788 | 546816 /227840 | 213504/367788=0.5805 |

H32 four-token prefill=181391 cycles. H32 resource high-water79872 B; Digits90624 B; MiniCNN18176 B reserved. H16 generated completion queue ends at88064 B for128entries. Traffic here is accepted compute SPAD data traffic, excluding control descriptor/completion transfers and initial host/DMA materialization. CMDQ timing ends after final completion publication and excludes fixture initialization, host setup/Golden readback. CNN's actual DMA preload remains separately recorded; it is not added to compute cycles or presented as a matched system endpoint. H16/H32 use fixed trained model hashes and teacher-forced token sequences. H32 functional support does not improve its previously documented poor held-out generalization (~3.19%); it is not pretrained GPT-2/Qwen support.

## Failures and static review

The pristine baseline explicitly elaborated at128KiB emitted **TEST FAIL errors=23**, while Make returned0 because only a few PASS markers were tested. The eight highest-row host writes, banked boundary operation and parallel result pages used addresses beyond128KiB. Those fixtures were remapped; no tests or expected checks were deleted. Original failure log is preserved.

An initial unified runner used the short smoke assertion watchdog for a large CNN and failed after2000cycles. The corrected runner retains the short smoke build and uses the repository's existing `AI_REPRESENTATIVE_LONG_TASK` bounded200000cycle profile for large CNN/Transformer graphs, with the existing finite TB timeout. Failed log is preserved; no assertion was removed or product timeout changed.

Verilator `--lint-only --timing -Wno-fatal +define+VCS --top-module ai_accel_top` completes with the following **unchanged** counts against pristine baseline explicitly configured for8192words/bank: PINMISSING2, WIDTHTRUNC64, WIDTHEXPAND113, CASEINCOMPLETE4, LATCH10, UNOPTFLAT3. No new warning class/count; this is **not** lint/signoff PASS. LATCH findings concern existing `ai_compute_spad_mux`; UNOPTFLAT includes existing SPAD/protection combinational connectivity. These remain open before architecture freeze. New RTL contains parameter changes/constant geometry guards only; runtime pipelines and state are identical. No valid synthesis/physical timing evidence was collected; no area/Fmax/400MHz claim.

## Reproduction

From repository root, with legal VCS installed and Python containing numpy/sklearn/onnx:

```bash
SPAD128_OUT=/tmp/nmaforge-spad-gate01-replay \
SPAD128_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python \
SPAD128_DATASET=1 bash tools/benchmark/spad128/run.sh
python3.12 tools/benchmark/spad128/validate.py
```

Focused existing Make entry points:

```bash
cd dv/subsystem/top_smoke/sim
make ai_smoke AI_SPAD_WORDS_PER_BANK=8192
make ai_run AI_SPAD_WORDS_PER_BANK=8192 AI_RANDOM_CASES=20 AI_SEED=12345
make ai_spad_capacity_boundaries AI_SPAD_WORDS_PER_BANK=8192
make ai_spad_capacity_boundaries AI_SPAD_WORDS_PER_BANK=32768
```

`ai_run` uses the compiled geometry; rebuild with `ai_comp`/`ai_smoke` when changing depth. The isolated runner builds both explicitly. FPGA settings use environment `SPAD_WORDS_PER_BANK`, with the same value required for synthesis, board build, generated ELF and JTAG validation; hardware was not rebuilt in this gate.

**Stop:** Gate 2 profiling extensions, Candidate A/B/C selection, performance RTL and architecture freeze are deferred to architecture review. Existing passive profiler reuse here checks regression evidence only. TinyNPU source stays pinned to `8216c22b762011aa20c05fc2768423fd12dda59d`; no new system speedup is calculated.
