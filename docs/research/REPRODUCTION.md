# Stage A reproduction and evidence provenance

Run from the `nmaforge` checkout root; use fresh **absolute** output directories.
Installed environment for this run: VCS `V-2023.12-SP1_Full64`, Verilator5.052,
Python3.12 (`/tmp/nmaforge_arch_v2_py312/bin/python`) with NumPy, scikit-learn,
ONNX and existing model/reference dependencies. EDA skill workflow was applied;
canonical repository Makefiles were used because the project `eda.yaml` generic
simulation adapter does not encode these benchmark modes. No new PDK or license
configuration is required by the scripts. Standard VCS environment must already
be available. Public archive contains tool versions/commands, not license values.

## Validate existing archive without EDA

```bash
python3.12 tools/benchmark/stage_a/validate.py
```

Expected `STAGE_A_MANIFEST_PASS`. Checks all archived/source/model SHA256,
unchanged product RTL Git tree, comparison eligibility, invalid-ratio rejection,
exclusive phase closure and accepted read/write bytes. Gzip content is ordinary
text CSV/logs; no tool-generated executable/database is needed to read evidence.
Run `git diff --check` separately.

## NMA workloads and analysis

```bash
export STAGE_A_PYTHON=/tmp/nmaforge_arch_v2_py312/bin/python
export STAGE_A_OUT=/tmp/nmaforge-stage-a-replay
bash tools/benchmark/stage_a/run_nma.sh
"$STAGE_A_PYTHON" tools/benchmark/stage_a/run_cnn.py \
 --simv "$STAGE_A_OUT/simv" --out /tmp/nmaforge-stage-a-replay-cnn
"$STAGE_A_PYTHON" tools/benchmark/stage_a/analyze.py \
 --run "$STAGE_A_OUT" --cnn /tmp/nmaforge-stage-a-replay-cnn \
 --out /tmp/nmaforge-stage-a-replay-analysis
"$STAGE_A_PYTHON" sw/tools/reference_tiny_gpt2_int8.py \
 --model benchmark/representative/round25/models/tiny_gpt2_h16_qat_gelu16.json \
 --out /tmp/nmaforge-stage-a-replay-quality.json --test-sequences 1024
make -C dv/block/compute/matrix/sim core-tile-forward-ablation \
 TILE_FORWARD_OUT_DIR=/tmp/nmaforge-stage-a-replay-forward
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

Expected H16 total65,771, per-token8,221.375; trained CNN65,429/22,983/12,351
CMDQ cycles; independent exact output words and fixed quality results.
Host wall-clock measurements vary by machine/load; existing archived values are
one measured sample, not stable performance assertions. `analyze.py` measures
100 warmed output GAP/argmax repetitions and checks their result. Large-model
budgets are labeled hypothetical and never invoke training or hardware execution.

The passive monitor is enabled only with `+STAGE_A_PROFILE=<absolute-prefix>`.
Its cycles match the existing Top timing gate; each cycle receives one phase.
No-engine remainder includes responses/control, not just dispatch stalls.
Traffic files count accepted engine scalar and Matrix line/banked accesses;
they exclude descriptor/completion bytes and host/debug traffic. AXI-Lite
accepted address trace is separate. DMA payload/busy/window counters come from
the existing AXI responder. CNN configuration markers cover nine queue writes;
readback markers exclude debug Golden checking. The default smoke compiles the
512 KiB compatibility profile; workload build compiles128 KiB.

## Tiny and matched arrays

```bash
export TINY_NPU_ROOT=/tmp/nmaforge-round28-runs/tiny/source
export VERILATOR=/tmp/nmaforge_verilator_5.052/bin/verilator
# Use a clean external checkout, pinned to:
# 8216c22b762011aa20c05fc2768423fd12dda59d
"$STAGE_A_PYTHON" tools/benchmark/stage_a/run_tiny_native.py \
 --source "$TINY_NPU_ROOT" --out /tmp/nmaforge-stage-a-replay-tiny \
 --verilator "$VERILATOR"
STAGE_A_ARRAY_OUT=/tmp/nmaforge-stage-a-replay-arrays \
 bash tools/benchmark/stage_a/run_arrays.sh
make -C dv/subsystem/top_smoke/sim ai_tinynpu_cnn_match_128k \
 AI_TINYNPU_CNN_PYTHON="$STAGE_A_PYTHON" \
 AI_TINYNPU_CNN_MODEL="$TINY_NPU_ROOT/models/conv1x_mini.onnx" \
 AI_TINYNPU_CNN_GOLDEN=/tmp/nmaforge-stage-a-replay-tiny/graph/golden.bin \
 AI_TINYNPU_CNN_RUN=/tmp/nmaforge-stage-a-replay-common-cnn
```

Expected Tiny native4,742, configuration24, Golden4/4; NMA common CNN1,874 plus
separate modeled host layout1,080, Golden4/4. No matched system ratio. Array
NMA18/34/264, Tiny54/102/792; trainedQ/K/V raw192 words/design match. The new
`run_arrays.sh` consolidates the exact previously run individual build/fixture/
execution commands. Tiny script uses a fresh build to avoid stale executable
reuse; retain clean external source and inspect pinned SHA.

`run_tiny_native.py` derives an instrumented **copy** of the pinned public
wrapper; it adds passive graph/Matrix state and data-SRAM enables only. Third-party
source remains unchanged. Original/instrumented wrapper hashes and full argv are
recorded. Native C++ uses the upstream-style16 MiB DDR image with IO base0x00400000,
7 modeled byte-serial DMA commands and output commit before Golden. This is
explicitly MIXED_MEASURED_MODELED. `tiny_native/upstream_replay.log.gz` retains
the canonical harness result “DONE at4781”, demonstrating the39-clock prestart
offset. The graph compiler's output hashes are archived, not third-party binaries.

## Archive layout and regeneration

`benchmark/research/stage_a/manifest.json` is the machine-readable benchmark
manifest. `analysis/` holds closed profiles, per-token/group costs, forwarding
bounds and allocation budgets. `h16/` holds accepted addresses/cycle CSVs,
descriptors/initial image/Golden/observed snapshots and session logs. `cnn/`
holds all three mapping images/Golden/DMA plans/output/profile/logs. `qkv/` holds
paired raw fixtures and independent checks. `arrays/`, `common_cnn/`,
`tiny_native/`, `forward/`, `validation/` retain the corresponding public evidence.
Old scheduling variants are already preserved separately under
`benchmark/representative/schedule_optimization/`; they are not described as
fresh Stage A product variants.

`collection_inputs.json` records this run's exact input paths. To collect a new
run, create an equivalent JSON mapping to its fresh paths and invoke:

```bash
python3.12 tools/benchmark/stage_a/collect.py \
 --inputs /path/to/new-inputs.json --out /tmp/stage-a-new-archive
python3.12 tools/benchmark/stage_a/validate.py --archive /tmp/stage-a-new-archive
```

Collector refuses to overwrite an existing archive, hashes source/model and
compressed artifacts, uses deterministic gzip timestamps and normalizes CSV to LF, and excludes generated
binaries/databases, libraries and third-party assets. Run after scripts are final
so source hashes match. The manifest pins reviewed product RTL independently of
the later documentation commit; final publishing SHA is reported after push.

Only Stage A was executed. There is no A3/B2 RTL or measured optimization result
in this archive. Stop for the requested architecture review.
