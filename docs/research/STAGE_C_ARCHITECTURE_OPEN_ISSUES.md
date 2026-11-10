# Stage C — Architecture open issues

Final disposition **PARTIAL**; frontend architecture freeze is not admitted.
Product RTL/ABI remain the baseline. No Stage D work is started.

| Issue | Severity / evidence | Required next decision |
|---|---|---|
|A3 skips current SRAM parity/protection observation|Blocking for transparent bypass; Stage B counterexample replayed|Keep A3 rejected; no relaxed mode without explicit review|
|Existing A2 opt-in ownership/fault boundary|Major; local tag has no external-write snoop or epoch; no certification under strict Stage C contract|Document/enforce software immutability and review fault policy before broad product use|
|K64 interleaved accumulator ownership|Major; full16×16 context2,048B;512B activation banks insufficient for entire1,024B input row tile|Independent narrow schedule or reviewed context/lifetime proposal; no automatic buffer increase|
|H32 model generalization|Major research-quality issue; disjoint84/28 trajectories,3.19% INT8 accuracy|Develop a stronger task/training methodology in a separately authorized stage; not change Golden to hide it|
|H32 scope|Functional limited scope:4 full-prefill +8 teacher-forced decode, slots0..11|Capacity16 boundary, wrap, multiple prompts, autoregressive feedback, numerical edge/fault cases remain open|
|H32 SFU cost|79.21% exclusive cycles; length32 misses existing16word LN fast path; padding4rows|Future exact scheduling/model lowering must preserve fault observation and per-feature normalization|
|Mapper resource generality|H32 emitted with shape-derived dimensions; KV scatter limits4..16feature/context; M4 minimum GEMM|Validate more supported dimensions; reject unsupported model shapes rather than assume portability|
|Common Tiny memory adapter|Nine exact raw kernels, identical modeled128bit line service; conservative wavefront schedule|Native controllers/DMA/graph/endpoints and optimized Tiny schedule still unmatched|
|Native CNN endpoint mismatch|NMA1874CMDQ+1080layout excludes preload; Tiny4742 includes modeled byte-DMA/output commit|Build matched native endpoints before system speedup claims|
|SRAM macro integration|Behavioral registered RAM and fault checks; no new macro evidence|Confirm true macro latency, write commit/error semantics, collision and read-during-write behavior|
|400MHz timing|2.5ns target, no valid Stage C synthesis or STA|Review MAC accumulation, banked routing/mux, shared SFU divide/sqrt and wide fixed-point arithmetic under legal libraries|
|Signoff|No full DV/SpyGlass/DC/DFT/P&R done in this stage|Follow existing verification frontier; named smoke PASS is not signoff|

Hardware resource delta is zero: no additional MAC, data register, metadata,
cache buffer, SRAM port, selector mux or production control state. No area,
power, energy benefit or achieved frequency is claimed. The evidence supports
software/DV/research integration, not a new ASIC performance signoff.
