# Matrix block verification

From the repository root:

```sh
make -C dv/block/compute/matrix/sim datapath-random-regress \
  SEEDS='20261021 20261022 20261023' OUT_DIR=/tmp/nmaforge_matrix_dp_multi_seed
make -C dv/block/compute/matrix/sim core-random-regress \
  SEEDS='20261021 20261022 20261023' CORE_OUT_DIR=/tmp/nmaforge_matrix_core_multi_seed
make -C dv/block/compute/matrix/sim a3-core-test
```

`datapath-random-regress` checks 10,072 deterministic/random combinations per
seed across three seeds, covering
signed byte extraction, all four K lanes, A/B transpose selection, MAC gating,
post-accumulation bias, arithmetic shift, ReLU/ReLU6, and INT32 saturation
against a separate testbench oracle. `a3-core-test` runs the existing 4×4 GEMM
core throughput gate. The top smoke covers the command-processor integration;
`ai_a3_reference.py` provides additional Python model checks.

`core-random-regress` runs the full `ai_tensor_matrix_core` on three seeds with registered
banked/SPAD responses, randomized request/response latency and output
back-pressure. Five scoreboard cases cover multi-row/column tiles, two batches,
default and padded batch strides, each transpose mode and both together, bias,
shift, ReLU/ReLU6, aligned 128-bit lines and unaligned scalar writeback.
Twelve fault cases check invalid dimensions/opcode, bank/SPAD parity and
protection, line/scalar write protection, abort, and watchdog errors. A valid
transaction after those faults checks recovery without reset. The test then
resets the core while active and checks a separate valid transaction afterward.
The 2026-10-23 three-seed regression passed. Added interaction cases assert
bank/SPAD/line protection, parity, watchdog, and abort together, then verify
abort priority and no write; reset is asserted with the fault inputs active.
An additional 16×16 run injects parity after substantial progress and confirms
20 already committed output lines remain the only writes. Other fault
combinations and late faults at every tile boundary remain open.
