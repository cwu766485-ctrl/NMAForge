# BPF-TE RTL Implementation

The prototype is `rtl/research/ai_spad_bank_parallel_arbiter.sv`. It is
deliberately isolated from `ai_spad_arbiter` and the product top so the PR #7
ABI and single global scheduler contract remain unchanged.

The module has four logical request slots and four bank request outputs. Address
bits `[3:2]` select the physical bank. A rotating pointer per bank chooses one
of multiple same-bank requesters, while requests for different banks are
accepted in parallel. `req_accept`, `req_denied`, and `req_backpressure` are
explicitly observable.

Accepted reads carry owner, tile, and epoch through two metadata pipeline
stages. The paired bank interface returns `bank_rsp_valid`, data, and error
after the same two cycles. `epoch_bump` clears the pipeline and increments the
epoch. A stale response therefore cannot be delivered to a new transaction.
Writes are admitted and accounted for but do not create responses.

This is a bank-level port adapter contract, not a drop-in replacement for the
legacy single-transaction SPAD port. A product integration requires a real
four-port SRAM macro or equivalent banking wrapper; that integration is not
claimed here.

## Reproduction

```bash
VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
$VCS_HOME/bin/vcs -full64 -sverilog -timescale=1ns/1ps \
  -debug_access+all -f dv/research/bpf_te/ai_spad_bank_parallel.f \
  -top tb_ai_spad_bank_parallel_arbiter -o /tmp/bpf_te_simv \
  -l /tmp/bpf_te_compile.log
/tmp/bpf_te_simv -l /tmp/bpf_te_run.log
```

The testbench is a synthesizable-interface bank model plus non-vacuous checks
for simultaneous independent-bank admission, same-bank conflict, response
ownership, epoch flushing, error propagation, and fairness.
