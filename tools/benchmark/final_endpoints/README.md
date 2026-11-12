# Matched endpoint reproduction

Use Python3.12 with NumPy (the existing `/tmp/nmaforge_arch_v2_py312` environment
was used for CNN), VCS V-2023.12-SP1, and a new absolute output path.

```bash
PHASE4_OUT="$PWD/runs/final_replay" bash tools/benchmark/phase4/build_top.sh
python3.12 tools/benchmark/final_endpoints/run.py --simv "$PWD/runs/final_replay/top/simv" --out "$PWD/runs/final_replay/matrix"
/tmp/nmaforge_arch_v2_py312/bin/python tools/benchmark/final_endpoints/run.py --simv "$PWD/runs/final_replay/top/simv" --out "$PWD/runs/final_replay/cnn" --cnn
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/block/compute/matrix/sim core-random-regress product-opcode-fault-regress SEEDS=20261112 CORE_OUT_DIR="$PWD/runs/final_replay/fault"
```

No product RTL changed. Host-side direct external-array assignment after each
AXI-Lite read models host-visible materialization with zero extra host-store
latency; this deliberately favors the baseline. DMA candidate uses real writes
through the AXI memory model and waits for DMA done/status. Both endpoints use
Golden-order external offsets starting0. Payload hashes and common Golden are
recorded. CPU packing nanoseconds are separate and not hardware cycles.

The final `begin` timestamp is production_begin: checker-only poison setup and
validation are excluded before real DMA configuration/load. CMDQ setup, completion
verification and output delivery remain inside one continuous clock interval.
The earlier final_ab_v3 fixture included checker setup and is retained only under
runs/ as a superseded experiment. No overlap speedup is claimed. CNN strict replay
checks all20,800 Golden words; paired delivery checks832 final words (3328bytes).
