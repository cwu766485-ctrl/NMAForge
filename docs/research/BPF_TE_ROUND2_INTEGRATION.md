# BPF-TE Round 2 Integration and H0/H1 A/B

Base product candidate: PR #7 head `f919bb787dab1a4e3bef44b5308ead56d6e77b72`  
Research branch: `research/bank-parallel-fault-precise-v1`  
Round 2 commit: recorded in the delivery commit

## M1 protocol repair

The arbiter now has a real `bank_ready` handshake. A bank that is unavailable
or protected is not admitted, and the requester observes `req_denied` and
`req_backpressure`. `epoch_bump` blocks new admission in that cycle, flushes
tag stages, increments the epoch, and pulses `rsp_dropped` for in-flight
reads. Writes have an explicit commit point at the accepted bank request.
The existing SVA bind and standalone regression remain enabled.

## M2 real four-bank research SPAD

`ai_spad_bank_parallel_adapter.sv` implements four 8192 x 32-bit banks, Host
Port A, independent bank Port-B requests, byte writes, read-first behavior,
two-cycle registered responses, and parity. Host valid has priority and blocks
all scheduler bank admission for that cycle, matching the existing protection
contract. `bank_allow` and `inject_parity_error` make protection and parity
faults observable in the testbench.

This is a research wrapper because the product `ai_scratchpad.v` exposes one
global scheduler Port B. Reconnecting four BPF-TE outputs to that single port
would invalidate the experiment. The wrapper is therefore not a claim that a
compatible four-Port SRAM macro exists; macro mapping remains blocked.

## M3 Matrix/CNM atomic adapter

`ai_bpf_te_atomic_adapter.sv` maps a Matrix 128-bit line or a full four-lane
CNM request to four bank slots. Matrix line addresses must be 16-byte aligned;
CNM requires all four lanes and lane-to-bank mapping 0/1/2/3. `line_ready` and
`cnm_ready` are all-or-none and line priority prevents simultaneous partial
acceptance. Response data is reassembled from the four banks and error bits
remain bank-specific.

## Measurements

The real-SPAD test uses the same initialized memory, Golden words, clock, and
two-cycle memory response for both controls:

| Workload | H0 serial admission | H1 bank-parallel | Result |
|---|---:|---:|---|
| Two bank-disjoint scalar reads | 6 cycles, 1.00 accepted/cycle | 3 cycles, 2.00 accepted/cycle | 2.00x, Golden PASS |
| Matrix line write/read | NOT_APPLICABLE | atomic four-bank, Golden PASS | protocol PASS |
| CNM full four-lane read | NOT_APPLICABLE | atomic four-bank, Golden PASS | protocol PASS |
| Same-bank read/write | serialized | serialized | no illegal parallelism |
| Host/scheduler overlap | host priority | host priority | PASS |

H0 is a real single-admission control reference over the same SPAD wrapper; it
is not yet a full product-top replay of `ai_spad_arbiter` plus all engines.
System CNN/GEMV, DMA/compute overlap, useful MAC/cycle, and end-to-end product
latency remain `NOT_MEASURED`. H2/H3 are not started.

Coverage from the final VCS/URG runs is prototype-scoped: real-SPAD test line
93.88%, condition 51.08%, branch 55.56%, assertion 100.00%; atomic-adapter
test line 90.95%, condition 49.48%, branch 71.43%, assertion 100.00%. No FSM
shape was inferred. These numbers do not close product Compute Cluster DV.

## Reproduction

```bash
VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
$VCS_HOME/bin/vcs -full64 -sverilog -timescale=1ns/1ps \
  -f dv/research/bpf_te/real_spad.f \
  -top tb_ai_spad_bank_parallel_real -o /tmp/bpf_te_real_simv
/tmp/bpf_te_real_simv -l /tmp/bpf_te_real.log

$VCS_HOME/bin/vcs -full64 -sverilog -timescale=1ns/1ps \
  -f dv/research/bpf_te/atomic.f \
  -top tb_ai_bpf_te_atomic_adapter -o /tmp/bpf_te_atomic_simv
/tmp/bpf_te_atomic_simv -l /tmp/bpf_te_atomic.log
```

Expected markers: `BPF_TE_REAL_SPAD_PASS`, `BPF_TE_H0_H1_AB_PASS`, and
`BPF_TE_ATOMIC_PASS`.
