# BPF-TE Round 5 Product A/B

Base: `7390fe5a78c4e729ac924475d2fa191a87954964`

## Native H0

`tb_bpf_te_h0_native.sv` instantiates the product `ai_spad_arbiter` and
`ai_scratchpad` with the native CNM four-lane and Matrix banked interfaces.
It does not split an H1 transaction into four artificial H0 requests. The
native CNM request is admitted as one product transaction and the native
Matrix banked request is admitted as one product transaction.

Observed markers:

```text
BPF_TE_H0_NATIVE_CNM_PASS accept=1 response=1 cycles=5
BPF_TE_H0_NATIVE_BANKED_PASS accept=1 response=1 cycles=5
```

The test checks accepted and response ownership through the product arbiter;
the scratchpad is the product four-bank behavioral SRAM. The request payloads
are legal native requests, but this focused harness does not claim full
product-engine numerical closure.

## H1

The H1 top uses the real Matrix/CNM cores and the research four-bank SPAD:

```text
BPF_TE_REAL_CNM_MEMORY_GOLDEN_PASS addr=0x300 data=124
BPF_TE_REAL_CNM_PASS result=124 cycles=13 accepted_bank_ops=9 response_ops=8 denied_ops=0
BPF_TE_CNM_PARITY_FAULT_PASS code=6
BPF_TE_CNM_WRITE_PROTECTION_PASS code=6
BPF_TE_REAL_MATRIX_PASS result=0xfffffffc cycles=19 line_writes=4 accepted_bank_ops=33 response_ops=16 denied_ops=0
```

The H1 numbers include core execution and writeback. They are not directly
comparable to a product command-level cycle until the same product dispatcher
launch/completion harness is added. The native H0 request replay shows why a
four-bank atomic CNM or Matrix banked request does not create a second legal
H0 opportunity: the product arbiter already accepts that operation as one
native transaction.

## Opportunity Bound

For the tested native paths, the number of simultaneously legal product
requests is one transaction per scheduler cycle. H1's extra physical lanes
are useful only for a workload that exposes multiple independent scalar or
bank-local operations before the product engine/dispatcher serializes them.
The current Matrix/CNM command contract does not expose such a window. Matrix
× Scalar, CNM × Scalar, and DMA × Compute are therefore
`BLOCKED_BY_CONTROL_CONTRACT`, not performance points.

| Scenario | H0 | H1 | Decision |
|---|---:|---:|---|
| Native CNM four-lane request | 1 accepted transaction | atomic four-bank request | no demonstrated speedup |
| Native Matrix banked request | 1 accepted transaction | atomic four-bank request | no demonstrated speedup |
| Real CNM standalone | native engine replay pending | 13 cycles, Golden PASS | no fair speedup yet |
| Real Matrix signed 4x4 | native engine replay pending | 19 cycles, Golden PASS | no fair speedup yet |
| Matrix × CNM | legal serialization | adapter priority serialization | BLOCKED_BY_CONTROL_CONTRACT |
