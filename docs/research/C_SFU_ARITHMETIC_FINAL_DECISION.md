# C SFU Arithmetic Final Decision

## Product rebaseline

The research branch phase monitor is not a product result. The product
candidate contains a Divider `accelerate` control and special LayerNorm
length paths; these are absent from the research baseline comparison. Product
source must therefore be measured independently before any optimization is
proposed.

The available product-candidate evidence is bit-exact SFU block and top
coverage, including Softmax, causal Softmax, RMSNorm, LayerNorm, randomized
registered SPAD response, parity/protection, watchdog, abort, reset, and
recovery. The published R250 tree reports the Compute Cluster closure state,
but does not provide a product-side phase counter proving a remaining
arithmetic bottleneck.

## Research signal and decision

The non-product monitor collected 96 instances on three seeds. Divider/sqrt
wait-state fractions were Softmax 75.3%, causal Softmax 62.5%, RMSNorm 54.1%,
and LayerNorm 55.1%. These are FSM wait-state occupancy under a testbench
0–7-cycle response model, not removable-cycle estimates.

**Stage 4: REWORK before any RTL.** First add passive phase counters to the
product candidate and compare existing `accelerate`/special-length paths with
the exact H16/H32 workloads and numeric contracts. Only then compare leading-
zero/effective-width completion against the existing implementation. Do not
duplicate the candidate's optimization. A prototype is allowed only after a
measured end-to-end gain, bit-exact proof, fault-priority proof, and legal
timing/area estimate exist.

Reproduction of the research-only profile is the C command in the roadmap;
product rebaseline remains blocked by the current VCS license outage in this
environment.
