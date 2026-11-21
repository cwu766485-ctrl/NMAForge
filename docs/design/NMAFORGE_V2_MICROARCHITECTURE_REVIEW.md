# Round 28 microarchitecture review

## Selected SFU experiment

Existing LN cache removes the variance and affine X SPAD rereads: length 16 needs 16 X + 16 gamma + 16 beta read accepts and 16 output writes, rather than three X scans. It does not cache gamma/beta or fuse away the visible INT32 output. Measured exclusive buckets in `layernorm_phases.csv` are per SFU busy command, including its done state; request stalls remain inside the owning phase.

| Phase | Baseline | Candidate |
|---|---:|---:|
| Input fetch (sum accumulated on response) | 49 | 49 |
| Mean/variance | 50 | 50 |
| Reciprocal/sqrt | 102 | 72 |
| Gamma/beta fetch | 96 | 96 |
| Affine and cached X setup | 48 | 48 |
| Output writeback | 16 | 16 |
| FSM retirement | 1 | 1 |
| Total busy | 362 | 332 |
| Descriptor interval outside busy | 11 | 11 |

Dispatch remainder = measured descriptor interval minus busy; it is not added from overlapping global activity. The baseline and candidate each contain 64 decode LN commands. The R9 profiler separately records request/response stall overlays and accepted read/write counts. Input accumulation and fetch overlap in the same state; there is no separately additive sum counter.

Candidates: row batching requires new descriptor/multi-row state; extra cache reuse does not remove remaining gamma/beta reads without changing lifetime/alias semantics; residual forwarding requires an observable intermediate/operand contract. Reusing the existing exact divider skip has the smallest scope and measured opportunity. The existing function conservatively retains more leading bits than necessary for some values; for reciprocal dividend 2^30 it performs 34 iterations rather than 64, saving exactly 30 cycles. Skipped bits are zero, so restoring division remainder and quotient are unchanged. No numeric formula or Golden changed.

Hardware delta: combinational LayerNorm-opcode and reciprocal-state decode feeding existing accelerate select. Zero new flops, data arrays or memory ports. The existing priority-detect/shift path remains; additional decode fanout and physical timing are unmeasured. RTL compiles in VCS; no new synthesis/LEC/PPA evidence is claimed.

## Matrix configuration experiment

Same deterministic operands, seed 20261109, behavioral one-cycle bank service, 16×16 array. Raw per-case state/counter rows are in `matrix_ablation.csv`. Depth/prefetch/A-cache best existing configuration is 4/on/on: 175/263/1407 cycles. 2/off/off is 211/316/2118. Large-case read bytes fall from 8192 to 6144 when A cache is enabled. Outstanding occupancy, prefetch request/drain and overlap counters identify bounded request service pressure; counters overlap and cannot be summed into a serial wait budget.

Existing forwarding ablation: consumer 141→118 cycles, reads 512→256 B, producer 153 cycles unchanged; all Golden checks pass. These are existing mechanisms, not Round 28 inventions. B cache is shared with A reuse storage by opcode; product GEMV is independently replayed. No evidence here justifies a new bank port, larger FIFO, second array or second Matrix RTL experiment. Residual prefetch wait is a measured issue, not a proven single root cause.

## SRAM and 400 MHz risks

Behavioral registered response does not prove foundry single-port SRAM read/write turnaround, collision policy, parity timing or macro latency. Integration must preserve backpressure and response metadata ordering, parameterized bank address widths and reset invalidation; memory arrays need macro wrappers and valid-bit handling rather than relying on simulation initialization.

Potential 2.5 ns paths: Matrix bank selection/address/metadata enqueue, array reduction and accumulation, SFU gamma multiply/saturation and reciprocal scaling, divider compare/subtract, leading-zero detect/shift, forwarding tag/mux and high-fanout reset/dispatch controls. These are inspection candidates only; no 400 MHz timing closure or Fmax claim is supported. ASIC SRAM integration and STA remain later work.
