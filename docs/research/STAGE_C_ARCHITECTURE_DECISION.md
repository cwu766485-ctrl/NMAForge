# Stage C — Architecture feasibility decision

Final status: **PARTIAL**. Preserve complete NMAForge v2 and ABI. Transparent
CNN A3 is **REJECTED** under the unchanged SRAM fault contract. H32 executes the
full mapped two-layer integer graph in Top RTL, but its independently held-out
model quality is poor and the native TinyNPU system comparison remains unmatched.
**Frontend Architecture Freeze: NO.**

Baseline `nmaforge`: `4e65a2ac2fc176acc5621aebec000874f2c5ab24`.
Candidate `experiment/stage-c-h32`; only verified model/software/test/evidence
artifacts are integrated into `nmaforge`. Product RTL tree remains
`479f24f33af0ccfa87fd7458ac9c43f94aae7398`. The final delivery Git commit is the
Stage C commit in branch history; publication is verified against remote SHA
and separately reported at handoff. No force push or branch deletion occurs.

## Gate decisions

| Gate | Result | Evidence / implication |
|---|---|---|
|0 A3 admission|REJECT|Cancelled A reads lose fresh parity/protection; unchanged Stage B fault counterexample replay PASS|
|1 K64 reference|PARTIAL|4 exact K16 sums match3,328 outputs; early quantization differs1,854;512B does not solve single-array accumulator lifetime|
|2 Safe scheduling|NO RTL ADMITTED|Existing prefetch/cache/outstanding ablation; no additional safe wait removal proven; completed-stage mapper workspace reuse only|
|3 H32 integration|FUNCTIONAL PASS / QUALITY LIMITED|4 full causal prefill +8 persistent decode;12×113descriptors;92,928wordGolden exact; disjoint-test INT8 accuracy3.19%|
|4 Tiny benchmark|PARTIAL|9common raw GEMM/GEMV/H32 subgraphs with clocked service/commit match; native CNN output match; no native-system speedup|
|5 Freeze decision|PARTIAL|Major model-quality, strict-fault forwarding and matched-system gaps remain|

## Answers to the eight architecture questions

1. **A3 satisfies parity/protection? No.** Successful producer commit and correct
   cache parity do not observe a later SRAM upset or changed read permissions.
   No A3 bypass RTL is implemented; no relaxed fault mode is introduced.
2. **512B sufficient for beneficial K64 reuse? Not demonstrated.** Two256B banks
   stream slices; complete16×64 activation is1,024B. Interleaving producer on the
   same array clobbers consumer's2,048B INT64 context. Narrow4row possibilities
   need a separate continuation/layout review and still cannot skip required
   SRAM checks. Ordinary K64 GEMM already works without A3.
3. **Can H32 run completely? Yes within the measured workload.** Both layers,
   heads, attention, residual, length32 LN, FFN128, Logits and per-layer KV execute
   in RTL. Host supplies embeddings only; no injected Transformer intermediates.
   Full16token/wrap/general-prompt validation and model utility are not complete.
4. **Matrix/SFU ratio?** Final8decode: Matrix41,360(11.25%), SFU291,332(79.21%),
   KV20,224, control14,872; sum367,788=45,973.5cycles/token. Reads546,816B,
   writes227,840B. This differs from H16's smaller model, not a regression claim.
5. **Fairly ahead of Tiny?** Under the identical bounded clocked memory-service
   adapter, yes for9 raw linear kernels: NMA178/290/2056 versus Tiny214/358/2584
   on fixed GEMM shapes, with exact outputs and equal traffic. These harness
   schedules do not establish native-controller/full-graph/end-to-end superiority.
6. **Which innovation deserves RTL now? None admitted.** Transparent A3/B2 fail
   strict fault observation; a further schedule change lacks proven safe gain.
   Reuse existing parameters and the new bounded mapper; do not add resources
   solely because arrays differ on unmatched native benchmarks.
7. **Extra hardware? Zero.** No production RTL diff, flops, metadata, mux, buffer,
   MAC or SRAM port. The2,048B accumulator context is a rejected/unimplemented
   full-tile option, not actual added hardware.
8. **Start freeze? No.** Preserve the current implementation while resolving
   open issues in a future separately authorized stage. Smoke alone is not freeze.

## Results and validation

| Workload | Result | Numerical evidence |
|---|---:|---|
|H16 unchanged baseline,8decode|65,771cycles /8,221.375per token|Original independent persistent Golden PASS|
|Final H32 full prefill4tokens|181,391cycles|30,976checkedwords|
|Final H32 persistent decode8tokens|367,788cycles /45,973.5per token|61,952checkedwords, allLogits/KV/tensors|
|Trained CNN legacy/first-fused/both-fused|65,429 /22,983 /12,351CMDQcycles|20,800words per mapping + independent physical-layout Golden|
|CNN best accepted SPAD traffic|64,064read /16,640write B|Required writebacks retained|
|Matrix8config ablation|40/40Golden cases|Same seed/operands per configuration|
|Tiny shared service|9/9exact Golden|Raw GEMM, equalread/write service, no system ratio|
|conv1x_mini native|NMA1874CMDQ +1080layout; Tiny4742|4/4outputbytes; endpoints remain different|
|Top smoke / seeded20|PASS /PASS|VCS V-2023.12-SP1_Full64|

No product RTL experiment means no new combinational path/latch/synthesis delta.
No legal local comparative synthesis was needed/run; no area/Fmax/PPA claim.
Compile preserves the existing LOOP-REROLL fixture notice and environment/tool
warnings; zero new RTL warning/error is asserted only within these named builds,
not a lint signoff.4ns simulated clock is250MHz;400MHz requires2.5ns implementation
constraints and real synthesis/STA evidence.

Model training is deterministic and reproduced byte-identically. A first export
scale error was fixed in model export, then an independent-seed split overlap
was corrected with disjoint trajectories. These are the two directed model fixes;
final low quality is reported rather than tuned away. Neither old product Golden
nor quantization strictness was weakened. Model, descriptor, Golden, observed
snapshots, public source hashes and tool logs are archived below; binaries,
license files and private technology data are excluded.

## Reproduction

Use Python3.12 with numpy/scikit-learn/onnx for mapping; PyTorch2.7.1+cpu for
training. VCS and Verilator5.052 must be available; Tiny checkout must be clean
at the pinned SHA. Every run directory below must be fresh.

```bash
python tools/benchmark/stage_c/train.py --out /tmp/h32_retrained.json
python tools/benchmark/stage_c/reference.py --model benchmark/research/stage_c/models/h32_l2_int8.json --out /tmp/h32_quality.json
python tools/benchmark/stage_c/k64.py --out /tmp/c_k64
STAGE_B_CONTRACT_OUT=/tmp/c_contract bash tools/benchmark/stage_b/run_contract.sh
STAGE_C_OUT=/tmp/c_top STAGE_C_PYTHON=python3 bash tools/benchmark/stage_c/run_top.sh
python tools/benchmark/stage_c/analyze.py --run /tmp/c_top/h32 --out /tmp/c_top/analysis
STAGE_C_BENCH_OUT=/tmp/c_service STAGE_C_PYTHON=python3 TINY_NPU_ROOT=/path/to/pinned/tiny-NPU VERILATOR=verilator bash tools/benchmark/stage_c/run_bench.sh
make -C dv/block/compute/matrix/sim matrix-config-comparison SEED=20261110 MATRIX_CONFIG_OUT=/tmp/c_matrix
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
python tools/benchmark/stage_c/validate.py
```

Detailed companion reports:

- `STAGE_C_CNN_K64_FEASIBILITY.md`
- `STAGE_C_H32_MODEL_GOLDEN_REPORT.md`
- `STAGE_C_SAFE_SCHEDULING_REPORT.md`
- `STAGE_C_TINYNPU_MATCHED_BENCHMARK.md`
- `STAGE_C_ARCHITECTURE_OPEN_ISSUES.md`
- `benchmark/research/stage_c/manifest.json` and `evidence_sha256.json`

Stage C stops here. Do not automatically implement Innovation A3 or enter Stage D.
