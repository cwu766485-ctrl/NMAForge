# BPF-TE Architecture Decision

Decision: **REJECT_FOR_PRODUCT**.

The protocol and real Matrix/CNM datapath remain valuable research artifacts:
nonzero Golden results, real CNM SPAD writeback, configurable parity/fault
inputs, epoch abort, and non-vacuous SVA all pass. However, the native product
H0 replay shows that CNM and Matrix already enter the product scheduler as
legal atomic operations. The additional H1 bank lanes do not create a measured
product-level opportunity under the existing dispatcher/Port-B contract.

The earlier 2.00x result was a bank-level capability test and is excluded from
the architecture performance conclusion. No representative legal workload has
shown the required >=10% reduction in end-to-end cycles, and H0/H1 engine-level
cycles are not yet matched at the same dispatcher endpoint. H2 ownership and
H3 DMA overlap are stopped.

Retain the research RTL for fault-causal DV and future interface exploration;
keep the stable product architecture unchanged.
