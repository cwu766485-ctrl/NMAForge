# Final A/B reproduction

Python3.12 (numpy available), VCS V-2023.12-SP1_Full64. Run at isolated root:

```bash
PHASE4_OUT=/tmp/nma-final bash tools/benchmark/phase4/build_top.sh
python3.12 tools/benchmark/arch_opt_round2/check_mapper.py
python3.12 tools/benchmark/final_ab/run.py --out /tmp/nma-final/revised --simv /tmp/nma-final/top/simv
python3.12 tools/benchmark/final_ab/run.py --out /tmp/nma-final/backpressure --simv /tmp/nma-final/top/simv --backpressure
make -C dv/subsystem/top_smoke/sim ai_smoke
make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345
make -C dv/block/compute/matrix/sim core-random-regress product-opcode-fault-regress SEEDS='20261112 20261113 20261114' CORE_OUT_DIR=/tmp/nma-final/fault
PHASE3_OUT=/tmp/nma-final/sfu PHASE3_PYTHON=python3.12 VERILATOR=verilator bash tools/benchmark/phase3/run_review.sh
```

Results CSV contains hardware edge timestamps, payload/output byte counts,
CPU packing single-sample wall nanoseconds, independent Golden hash and status.
The representative testbench keeps its full SPAD Golden after delivery (outside
timing). Endpoint Golden asserts output words in external consumer array, output
DMA waits for store completion. Active ai_accel_sva checks fail on protocol errors.
For CNN Golden includes all intermediate/sentinel words; only final3328B is delivered.

Archive includes an `initial` experiment before actual-row packing (called suite),
the retained revised runs and stronger deterministic AXI gap suite. `archive.py`
preserves these existing experiments and fault failure records; it is an evidence
bundler, not a prerequisite to fresh reproduction. No csrc,waves,licenses,libraries
or binary simulation artifacts are committed. CPU and silicon timing are not inferred.
