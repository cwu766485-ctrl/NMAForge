# CNN and KV-cache block verification

Run the direct three-seed block gate from the repository root:

```sh
make -C dv/block/compute/cnn_kv/sim random-latency-regress \
  SEEDS='20261021 20261022 20261023' \
  OUT_DIR=/tmp/nmaforge_cnn_kv_multi_seed
```

Each seed checks 25 signed convolution cases over 3–6 row and column sizes,
including 12 `DWCONV3X3` opcode cases. The scoreboard checks every sliding
3×3 output while the line buffers wrap rows. It also checks 27 KV-cache
write/read round trips. Both cores exercise invalid configuration, SPAD error,
abort, watchdog, reset while active, and a valid command after reset. The
scratchpad model varies `spad_ready`, applies deterministic 0–7-cycle ordered
read-response latency, checks accepted-read/response accounting, and compares
every written word to its independent testbench oracle. The regress target
accumulates DUT-only line/condition/FSM/branch coverage in one VDB under `/tmp`.

The 2026-10-23 three-seed run passed. Its scratchpad model indexes the full
512 KiB address range, checks CNN windows at separated address regions, and
exercises KV lengths 1–128, aligned token/head strides 0–1020, head/token
boundary values, and placement near the top of SPAD. Late CNN and KV faults
follow substantial read progress; a combined abort+SPAD error and reset under
active fault inputs are also checked. The full top smoke additionally checks
Conv1x1, im2col Conv3x3, depthwise Conv3x3, and KV gather command paths; its
seeded run exercises random Conv3x3 and depthwise cases. The direct block test
covers the actual line-buffer core and KV primitive, not the scalar INT8
convolution implementation or a DDR memory model. Exhaustive stride
cross-products and every long-transaction error/reset combination remain open.

The 2026-10-30 KV address-contract increment adds ten required checker bins:
token-product overflow, product-sum overflow, cache-source/cache-destination
end-address overflow, linear-source/linear-destination end-address overflow,
and unaligned source/destination bases or token/head strides. Every invalid
descriptor must return `ERR_CONFIG` before any SPAD request or side effect.
Each seed also writes and reads the final legal SPAD word (`0x7fffc`) while
checking the preceding sentinel. The SPEC v1.7 contract and three-seed VCS
evidence are recorded in `COMPUTE_CLUSTER_KV_ADDRESS_R53.md`; this does not
close unrelated descriptor rules or the Compute Cluster sign-off.
