# Architecture Innovation Decision

Decision for this sprint: **REWORK**.

The BPF-TE primitive is a real, synthesizable bank-level admission and tagged
response prototype. It demonstrates simultaneous admission on independent
banks, explicit same-bank backpressure, two-cycle owner/epoch tags, fault
propagation, and fairness. The directed test passes all of those checks.

It is not yet a product architecture: Matrix line/CNM atomic adapters, safe
ownership integration with protection and completion retirement, a real system
workload, H0/H1 cycle comparison, and H2/H3 overlap are not implemented or
measured. Keep the prototype on the research branch and do not merge it into
PR #7/#8. Product retention requires a real four-bank SRAM port integration,
UVM V1 causal comparison, and measured end-to-end benefit without changing
legacy ABI semantics.
