# BPF-TE PPA Comparison

No legal standard-cell library, SDC, or compatible four-Port SRAM macro is
available in the research worktree. Full synthesis, STA, SRAM area, and
activity-based power are therefore `NOT_MEASURED`.

The logic-level comparison is qualitative and bounded by elaboration:

| Item | H0 product path | H1 research path |
|---|---|---|
| Scheduler | one global `ai_spad_arbiter` | per-bank decode/RR + atomic adapter |
| Response storage | product response/tag registers | three-stage per-bank tags + mode/inflight metadata |
| Additional muxing | none | four-bank request/data mux and output-write arbitration |
| SRAM ports | product scheduler Port-B contract | four independent research Port-B lanes |
| ASIC macro compatibility | existing behavioral contract only | NOT_PROVEN; macro inventory required |
| Area/timing/Fmax | NOT_MEASURED in this run | NOT_MEASURED in this run |

The 128 KiB behavioral array must not be interpreted as physical SRAM area.
Required resources to close Gate C are a legal cell library, SDC clocks and
IO constraints, and a four-bank macro with matching read latency, byte mask,
collision, and parity semantics.
