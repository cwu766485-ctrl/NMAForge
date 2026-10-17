# Scratchpad protection checker

This focused block test verifies the combinational `ai_spad_protection`
contract independently from the DMA–SPAD integration regression. It covers
all four region selectors; read/write/execute permission combinations; disabled
regions and the all-regions-disabled compatibility mode; zero-length accesses;
inclusive base/exclusive limit boundaries; adjacent regions that must not be
combined; overlapping regions; and 33-bit end-address overflow. A deterministic
512-vector differential sweep compares the RTL to an independent reference
function, with randomized cases biased toward region boundaries.

Run from the repository root:

```bash
make -C dv/block/spad_protection/sim verify VCS='vcs -licwait 1'
```

The flow writes VCS build products and coverage reports below `runs/`. This is
a block-level supplement; it does not replace the real-fabric protection,
error-retirement, sentinel, and recovery scenarios in
`dv/subsystem/dma_spad`.
