# Passive SPAD/Dataflow Profile

The existing Top `STAGE_A_PROFILE` monitor was used passively on the same P0/P1 RTL replay. It records accepted scheduler traffic (`profile_traffic.csv`), host snapshot reads (`profile_axi.csv`) and per-cycle phase (`profile_cycles.csv`). No DUT signal, handshake, or scheduling logic was changed. P0 and P1 both passed the same independent Golden before and after profiling.

| Metric | P0 | P1 | Status |
|---|---:|---:|---|
| Accepted scheduler accesses | 5,044 | 5,044 | MEASURED |
| Host snapshot reads | 63,289 | 63,283 | MEASURED, outside command window |
| Cycle samples | 11,376 | 11,376 | MEASURED |
| Line requests (`bank_mask=15`) | 5,044 | 5,044 | MEASURED from accepted line trace |
| Physical bank occupancy | NOT_MEASURED | NOT_MEASURED | Line monitor exposes all-bank mask, not per-bank busy time |
| Response owner/tag | NOT_CAPTURED | NOT_CAPTURED | Existing monitor limitation |
| Outstanding depth | NOT_CAPTURED | NOT_CAPTURED | Existing monitor limitation |
| Stall reason | NOT_CAPTURED | NOT_CAPTURED | FSM counters are not reclassified as conflicts |
| Fault/reset/abort epoch | NOT_CAPTURED | NOT_CAPTURED | Follow-up monitor required |

Normalized traces are in `benchmark/research/phase1_1_a1_a2/raw/profile/{baseline,packed}/accepted_trace.csv.gz`. Each accepted row includes cycle, source, address, byte width, write direction and derived bank mask. Unavailable ownership/epoch fields are literal `NOT_CAPTURED`; no response ownership or bank conflict is inferred from a counter. The current profile therefore establishes passive traffic equivalence and identifies the instrumentation gap required for full Gate 2.

The packed replay changes only address placement and DMA segment grouping. Accepted scheduler count, line traffic and command cycles are identical. The six fewer host snapshot reads are an artifact of the relocated sparse image and are outside the measured command window.

Reproduction uses `tools/benchmark/phase0_1/profile_dataflow.py` after the A1 replay command in `PHASE1_A1_RTL_REPLAY.md`.
