# Architecture Innovation Decision

Decision for this sprint: **REWORK**.

The BPF-TE primitive is a real, synthesizable bank-level admission and tagged
response prototype. It demonstrates simultaneous admission on independent
banks, explicit same-bank backpressure, two-cycle owner/epoch tags, fault
propagation, and fairness. The directed test passes all of those checks.

Round 2 now has a research four-bank SPAD wrapper, Matrix/CNM all-or-none
adapter, and a bank-level H0/H1 measurement: 6 cycles versus 3 cycles for two
bank-disjoint reads with identical Golden and latency. This is a capability
result, not a product-top speedup claim. Product CNN/GEMV, DMA/compute overlap,
safe tile ownership, and full Fault-Causal V1 remain unimplemented or
unmeasured. Keep the prototype on the research branch and do not merge it into
PR #7/#8. Product retention requires a compatible four-bank SRAM integration,
full product-top H0/H1 replay, and end-to-end benefit without changing legacy
ABI semantics.
