# Round 2 Gate A/B reproduction

Run from an isolated checkout with Python 3.12 and VCS V-2023.12-SP1_Full64:

```bash
PHASE4_OUT=/tmp/nma-r2 bash tools/benchmark/phase4/build_top.sh
python3.12 tools/benchmark/arch_opt_round2/check_mapper.py
python3.12 tools/benchmark/arch_opt_round2/run.py --out /tmp/nma-r2/paired --simv /tmp/nma-r2/top/simv > /tmp/nma-r2/paired-driver.log
make -C dv/block/compute/matrix/sim core-random-regress product-opcode-fault-regress SEEDS='20261112 20261113 20261114' CORE_OUT_DIR=/tmp/nma-r2/fault > /tmp/nma-r2/fault-driver.log 2>&1
make -C dv/subsystem/top_smoke/sim ai_smoke > /tmp/nma-r2/smoke-driver.log 2>&1
python3.12 tools/benchmark/arch_opt_round2/archive.py --runs /tmp/nma-r2 --out /tmp/nma-r2/public
```

The mapper is an imported callable in `sw/tools/shape_aware_dispatch.py`.
`policy='legacy'` is default. `policy='shape-aware', isolated=True` selects
GEMM only for measured M8/M16,N16,K16/32/64/128 inputs. It returns the selected
Descriptor and both correctly packed operand word arrays before publication.
No automatic rewriting of already-published descriptors or graph integration
occurs. The caller must select this execution contract before loading operands.
No dynamic operand or permission equivalence and no hardware lease is claimed.

Evidence archive includes individual accepted SPAD transaction traces, cycle
profiles, packed images, common Golden, invocation JSON and text regression logs.
Packing wall time is diagnostic Python host nanoseconds (single sample), not
RTL cycles or a portable system performance measurement. DMA is not exercised
by this CMDQ microbenchmark; its cycles remain NOT_MEASURED.
