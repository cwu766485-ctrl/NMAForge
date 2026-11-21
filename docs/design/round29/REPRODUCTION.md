# Round 29 reproduction and handoff

From candidate root, fresh output directories, Python `/tmp/nmaforge_arch_v2_py312/bin/python` and Verilator `/tmp/nmaforge_verilator_5.052/bin/verilator`.

```sh
R28_OUT=/tmp/r29_h16_replay R28_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python bash tools/benchmark/run_round28_h16.sh
make -C dv/block/compute/sfu/sim random-latency-test PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python SEED=20261109 OUT_DIR=/tmp/r29_sfu_replay
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
make -C dv/block/compute/matrix/sim core-random-compile CORE_OUT_DIR=/tmp/r29_matrix_replay SEED=20261109
/tmp/r29_matrix_replay/simv +SEED=20261109 +TINY_NPU_MATCH_MULTI -l /tmp/r29_matrix_replay/gemm.log
/tmp/r29_matrix_replay/simv +SEED=20261109 +MATRIX_PRODUCT_GEMV_ONLY -l /tmp/r29_matrix_replay/gemv.log
make -C dv/block/compute/matrix/sim product-gemv-four-way-ablation SEEDS=20261109 GEMV_FOUR_WAY_OUT=/tmp/r29_gemv_replay
make -C dv/block/compute/matrix/sim core-tile-forward-ablation SEED=20261109 TILE_FORWARD_OUT_DIR=/tmp/r29_forward_replay
```

Baseline uses same H16 command on Round28 checkout. Candidate actual output folder was `/tmp/nmaforge-round29-runs/final`; baseline `/tmp/nmaforge-round29-runs/base`. Read raw session logs for exact simulator plusargs and Golden path. `archive_round29.py --run /tmp/nmaforge-round29-runs` archives public-only selected files and validates paired hashes/state closure. It expects the documented final/base/validation/matrix/mini/tiny outputs, and does not copy builds/libraries.

CNN replay uses existing Round28 generated payload/model/Golen unchanged with Round29 final simv and exact descriptor bases 106496/107008, count 2, useful MACs 570164. Full expanded flags match Round28 performance report and Round26 manifest. Tiny scripts use existing pinned source `/tmp/nmaforge-round28-runs/tiny/source`, fresh outputs `/tmp/nmaforge-round29-runs/tiny/{gemm,cnn}`; run_tinynpu_gemm.sh and run_tinynpu_cnn.sh. Common NMA CNN target is ai_tinynpu_cnn_match_128k using pinned source ONNX and generated golden.bin. All comparisons retain same seeds and model.

Focused basic RTL review command:

```sh
/tmp/nmaforge_verilator_5.052/bin/verilator --lint-only --timing -Wno-fatal --top-module ai_tensor_sfu_core rtl/compute/common/ai_unsigned_divider.v rtl/compute/common/ai_integer_sqrt.v rtl/compute/sfu/ai_tensor_sfu_math.v rtl/compute/sfu/ai_tensor_sfu_core.v
```

No warning suppression was added to RTL or tests; Wno-fatal permits inspecting inherited warnings, explicitly not warning closure. Publication attempts: ssh -o BatchMode=yes -o ConnectTimeout=15 -T git@github.com; git push ssh://git@github.com/cwu766485-ctrl/NMAForge.git feat/nmaforge-rtl-finalize:refs/heads/feat/nmaforge-rtl-finalize. Both authentication attempts rejected. REMOTE_NOT_PUBLISHED.
