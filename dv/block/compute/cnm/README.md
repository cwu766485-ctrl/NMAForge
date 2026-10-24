# CNM block verification

The standalone four-lane check, GEMV benchmark, and seeded oracle coverage are
run through:

```sh
make -C dv/subsystem/top_smoke/sim ai_cnm_a22 ai_cnm_a2_gemv_bench \
  ai_cnm_random_regress CNM_RANDOM_SEEDS='20261021 20261022 20261023'
```

`ai_cnm_a22` checks lane-local input distinction, accumulation, global
reduction, prefetch/ping-pong handoff, event counts, and completion. The GEMV
benchmark compares K lengths 16/64/256. The independent signed INT8 oracle
checks eight lengths on each of three seeds, with DUT-only line/condition/FSM/
branch coverage collected into one VDB. Each seed also checks invalid-length,
bank-parity, bank-protection, SPAD write-protection, watchdog, and abort exits,
then verifies a valid command after reset. The shared-fabric UVM regression at
`dv/subsystem/dma_spad` exercises real CNM and FP requesters with DMA
contention, response stalls, parity/protection errors, abort/drain, and reset
recovery across seeded runs. The top smoke covers software-visible dispatch.

The 2026-10-23 aggregate passed with all three direct seeds and the 10-seed
shared-fabric run. These tests establish the listed functional slices; cross
combinations of multiple faults with abort/reset, global raw-bin closure, and
full-system fairness/formal closure remain tracked separately in
`dv/VERIFICATION_MATRIX.md`.

The follow-up regression adds parity after 128 accepted request slots in a
length-256 task, verifies that no result write occurs, combines parity and
protection faults with abort to check abort priority, and asserts reset while
those fault inputs remain active. Three seeds pass; simultaneous combinations
outside these selected cases and independent per-bank ready-stall coverage
remain open.
