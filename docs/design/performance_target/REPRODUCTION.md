# Reproduction and active frontier

Use fresh output folders. Baseline checkout 5f5291f, Residual-only e62fc34, final RTL 443d46f; current HEAD adds benchmark harness/docs only. Same script `tools/benchmark/run_round28_h16.sh`, R28_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python, R28_OUT=<fresh-absolute-dir>. Actual runs: /tmp/nmaforge-performance-runs/{base,residual,final}.

```sh
R28_OUT=/tmp/perf_h16_replay R28_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python bash tools/benchmark/run_round28_h16.sh
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
make -C dv/block/compute/sfu/sim random-latency-regress PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python SEEDS='20261109 20261110 20261111' OUT_DIR=/tmp/perf_sfu_replay
make -C dv/block/compute/matrix/sim core-random-run CORE_OUT_DIR=/tmp/perf_matrix_replay SEED=20261109
/tmp/perf_matrix_replay/simv +SEED=20261109 +TINY_NPU_MATCH_MULTI -l /tmp/perf_matrix_replay/gemm.log
```

Divider: compile top tb_divider_exact_acceleration with rtl/compute/common/ai_unsigned_divider.v and dv/block/compute/sfu/tb/tb_divider_exact_acceleration.sv using VCS -full64 -sverilog, fresh -Mdir and -o, then run binary. PASS cases=1260.

Shared trained QKV:

```sh
/tmp/nmaforge_arch_v2_py312/bin/python tools/benchmark/generate_shared_h16_qkv.py --model benchmark/representative/round25/models/tiny_gpt2_h16_qat_gelu16.json --out /tmp/perf_qkv
```

For each op=q,k,v, run Matrix core binary with +SEED=20261109 +TRAINED_QKV_MATCH +SHARED_OPERANDS=/tmp/perf_qkv/<op>.memh +SHARED_OUTPUT=/tmp/perf_qkv/nma_<op>.memh. Build pinned Tiny harness with TINYNPU_WORK_ROOT=/tmp/nmaforge-round28-runs/tiny TINYNPU_GEMM_OUT=<fresh-dir> VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator JOBS=2 bash benchmark/tinynpu/run_tinynpu_gemm.sh. Run its obj/Vengine_tb_top with environment SHARED_OPERANDS=/tmp/perf_qkv/<op>.memh SHARED_OUTPUT=/tmp/perf_qkv/tiny_<op>.memh. Then check_shared_h16_qkv.py --run /tmp/perf_qkv. Quantization is common host reference, excluded timing.

CNN uses unchanged Round28 payload with final H16 simv; exact flags retained in existing Round28/29 reproduction docs. Common mini CNN target ai_tinynpu_cnn_match_128k uses pinned source ONNX/golden and fresh output. Basic lint command and environment match Round29. Archive tool --run /tmp/nmaforge-performance-runs records selected public evidence and hashes, never build directories or private material.

Stop state: DESIGN_PARTIAL. Two RTL improvements retained; trained QKV matched arithmetic added. Full cross-system memory/controller timing and complete compatible Transformer graph remain open. No next round started. Local branch feat/nmaforge-tinynpu-performance; original branches preserved.
