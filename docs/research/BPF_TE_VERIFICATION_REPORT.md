# BPF-TE Verification Report

Candidate: `f919bb787dab1a4e3bef44b5308ead56d6e77b72`  
Tool: VCS `V-2023.12-SP1_Full64`, plain SystemVerilog testbench  
Test: `dv/research/bpf_te/tb/tb_ai_spad_bank_parallel_arbiter.sv`

The coverage run used `-cm line+cond+branch+fsm+assert`. With the BPF-TE SVA
bind enabled, URG reported line 94.67%, condition 44.44%, branch 57.14%,
assertion 87.50%, and no FSM shape (the primitive has no inferred FSM); this
is prototype-only coverage, not product closure.

The directed test is non-vacuous and terminates with `BPF_TE_PASS` only after
checking all of the following:

| Check | Result |
|---|---|
| Two independent banks admitted in one cycle | PASS |
| Same-bank conflict has exactly one grant and explicit denial | PASS |
| Two-cycle response owner/tag preservation | PASS |
| Epoch bump flushes outstanding response | PASS |
| Fault/error remains attached to bank and owner | PASS |
| Six same-bank requests use rotating fairness | PASS |
| Elaboration | PASS |

The bank model returns data and error through a two-cycle registered interface;
it is not a zero-delay behavioral shortcut. Matrix line atomicity and CNM
all-lane reservation are not yet integrated and remain `NOT_IMPLEMENTED`.
There is no claim of product-level numerical CNN/GEMM improvement from this
primitive.
