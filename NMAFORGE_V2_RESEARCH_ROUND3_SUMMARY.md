# NMAForge v2 Research Round 3 — Closeout

**Disposition: `RESEARCH_BASELINE_PARTIAL`.** This bounded round completed the
trained toy Transformer run and the CNN consumer-layout experiment. It does not
close full DV, establish a TinyNPU system-level win, or provide ASIC PPA.

## Fixed source and implementation

- Reviewed branch head: `240ed4106a1b31078cce15e2406d437ca0cde987`.
- RTL/feature commit: `4dab73646989615c5479de0bac76d1488a102758`.
- R250 `main`: `3041355528dffe856e2d5384027c6ee5df5d1b42` (untouched).
- Baseline product RTL: `cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`.
- Product RTL diff is limited to `ai_tensor_matrix_core.v` and
  `ai_descriptor_validator.v`. The opt-in ABI-v7 `0x53 aux0[7]` mode writes
  bounded four-INT8 output rows in the next FC's padded K-line layout. Legacy
  `aux0[7]=0` behavior remains unchanged; no new compute engine or MAC array.

## Fixed experiments

| Work | Result | Evidence |
|---|---|---|
| Trained Tiny Transformer | **PASS for a bounded synthetic task** | One layer/head, hidden 4, 4-token prefill plus one decode; 86 real Top CMDQ descriptors, 301 Golden/KV checks. 68.85% on exhaustive cyclic-next-symbol held-out predictions. Prefill 5,682 cycles; decode 5,715; total 11,397. 640 useful MACs; 3,816 B read / 2,120 B written. Run `V2-TRAINED-TRANSFORMER-TOP-4DAB736-S20261106`, 128 KiB behavioral SPAD. Not pretrained language-model evidence. |
| Ten-class trained CNN, legacy layout | **PASS** | 396/396 Top runs and exact intermediate/output Golden; 384/396 classification. 3,193 CMDQ + 1,080 testbench Host-layout cycles = 4,273 measured interval. 6,048/1,920 B compute SPAD R/W and 144/576 B Host-layout R/W. |
| Ten-class CNN, linear-row fused output | **PASS** | Same 396 samples, weights, seed, and Golden. 2,712 CMDQ cycles; no Host layout; 5,472/1,776 B compute SPAD R/W. 384/396 classification unchanged. Run `V2-TRAINED-CNN-TOP-DATASET-4DAB736-LINEARIZED`. |
| Basic compatibility smoke | **PASS** | `make ai_smoke SEED=20261106 AI_SEED=20261106 AI_RANDOM_CASES=4`, including existing opcode paths; VCS `V-2023.12-SP1_Full64`. |

CNN linear-row output reduced compute cycles 15.1%, the measured task interval
36.5%, and total observed SPAD traffic 16.6%. The combined comparison includes
epilogue fusion and consumer layout, so the total gain cannot be attributed to
either feature alone. Host-layout cycles are simulated AXI transactions, not
software wall time. Input preload and post-run Golden inspection are excluded
on both sides.

## Research conclusions and limits

- Innovation 1's fixed GEMV Cache/Prefetch ablation remains historical,
  SHA-bound evidence. This round's trained Transformer maps to GEMM opcode
  `0x30`, so there is no model-level GEMV ablation result.
- Innovation 2 has the CNN legacy/linear-row comparison above. Existing Digits
  MLP fusion and directed tile-forwarding measurements remain separate; they
  are not combined into a single speedup.
- 128 KiB four-bank behavioral SPAD executed the Transformer and CNN. Existing
  128/512 KiB CNN comparisons show equal cycles for their fixed workload; this
  does not prove universal fit or equal physical SRAM cost.
- TinyNPU remains pinned to
  `8216c22b762011aa20c05fc2768423fd12dda59d`. Existing direct-array and
  estimated common-memory rows are not same-endpoint Top measurements. No
  system-level TinyNPU win is established for the new models.
- Physical area, Fmax, power, and energy are **`BLOCKED_ENV`**: no authorized
  SRAM/standard-cell timing library and matching synthesis environment were
  available. Behavioral SPAD and simulation timing are not ASIC PPA.
- Full DV closure, broad coverage, CDC/RDC/formal closure, and ASIC readiness
  remain out of scope and open.

## Reproduction and reports

Model hashes: Transformer
`55cef19181c84dda9f99e940a0a749c1499fc1ccb176b966b1e13462f8ae3c03`; CNN
`ef0e616d09ca0be7956fa8ca900e40c62973f8f06e3ec96af09d888eead73726`; held-out
CNN set `cb851b077542f9bcf42f84938227ba5f1a4750ea0b0fbfe2ba8fcecbb914d107`.
Exact commands, mapper/training flow, and run boundaries are in the linked
model and performance reports. Runtime logs/396-row CSVs were retained under
`/tmp/nmaforge_round3_4dab_*` in the execution environment and are regenerable
from the committed sources and model assets.

- [Architecture review](docs/architecture/NMAFORGE_V2_ARCHITECTURE_REVIEW.md)
- [Model benchmark](docs/benchmark/NMAFORGE_V2_MODEL_BENCHMARK.md)
- [Performance comparison](docs/benchmark/NMAFORGE_V2_PERFORMANCE_COMPARISON.md)
- [DV closure status](docs/verification/NMAFORGE_V2_DV_CLOSURE.md)
- [ASIC readiness status](docs/verification/NMAFORGE_V2_ASIC_READINESS.md)
