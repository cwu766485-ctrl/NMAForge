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

Round 2 adds `tb_ai_spad_bank_parallel_real.sv` and
`tb_ai_bpf_te_atomic_adapter.sv`. Both terminate only after checking actual
accepted bank transactions, returned data, owner/error fields, and non-empty
response valid masks. The real-SPAD regression includes the measured H0/H1
markers and the atomic Matrix/CNM regression includes partial-request rejection.

Final URG summaries are: real-SPAD line 93.88%, condition 51.08%, branch
55.56%, assertion 100.00%; atomic adapter line 90.95%, condition 49.48%, branch
71.43%, assertion 100.00%. FSM is `NOT_APPLICABLE` because these adapters do
not infer an FSM.
