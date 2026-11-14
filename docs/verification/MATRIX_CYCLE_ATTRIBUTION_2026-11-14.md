# Matrix Cycle Attribution, 2026-11-14

Decision: **do not propose an RTL candidate from this profile**. The run
establishes where baseline simulation cycles were spent, but it does not show
which prefetch drain cycles are exposed on the critical path or whether an RTL
change can reduce end-to-end cycles. It is simulation evidence only; no ASIC
PPA or signoff result is claimed.

## Run identity

- NMAForge source revision: `4b62f8e815bb272ab9b727dff4736cec460e6f21`
- Flow adapter revision: `00be752330c4acb56bc019e42be95283edda80b7`
- Run type: Stage Runtime **baseline only**; no candidate patch was applied
- Stage Runtime result: regression, reference model, latency gate, performance all `PASS`
- VCS: `V-2023.12-SP1_Full64`
- Regression seeds: `20261021`, `20261022`, `20261023`
- Performance seed: `20261113`
- Performance workloads: five; aggregate `2010` cycles and `46.10547 MAC/cycle`
- Stage Runtime elapsed time: `14.430263 s`
- Candidate budget consumed: `0`; no candidate patch or RTL comparison was run
- Plan SHA-256: `2b436550bcf7cc99ff957ddd9a412b0337a736e47df85585db9277ca7376e0a5`
- Matrix core SHA-256: `3eeb8809ba79dd4a375b7aa0d58a7ecca37591bb7405afc57d2ee94c1c94a38a`
- Testbench SHA-256: `dc161fbfd737ce84c8acd2887f3ac9e5d501664b075bc28946f39e1fb1120c7e`
- Performance summary SHA-256: `5994d61ab3b8608d5d1b4dc6895b1d04981e6c2daee8fd0570b1fc183458411e`
- Performance log SHA-256: `76610ed7e3d07c042142a95c6c3f1fdb5b6fa00168360119f3457ac72b48f85a`
- Regression log SHA-256: `47d3da32ea5631ad20334236de1d10873327e3440fd0de8ef58fc0519501c3a4`

The exact plan, source and plan manifests, checkpoint, attempts, stage logs,
summaries, runtime inputs/results, and stage contracts are retained in
[`artifacts/MATRIX_CYCLE_ATTRIBUTION_2026-11-14/`](artifacts/MATRIX_CYCLE_ATTRIBUTION_2026-11-14/).
Verify archived files from that directory with `sha256sum -c SHA256SUMS`.
The archived plan records the original workstation-specific adapter path; it
must be adjusted to replay from a different checkout. Source hashes in the
manifest identify the measured RTL and testbench.

## Exclusive cycle partitions

The prefetch buckets are an exclusive primary classification of every cycle
spent in `ST_PREFETCH_WAIT`. Priority is handoff-ready, request denial,
request FIFO full, accepted request, outstanding response drain, then no
request. A cycle can have multiple underlying conditions, so the selected
bucket describes the primary classification, not every concurrent event.

Write-state buckets are exclusive: accepted output write without protection
error (`productive`), accepted write with protection error, or write not
accepted (`writeback_stall`). The testbench checks that both partitions sum to
their FSM state totals and that the legacy `writeback_wait` counter equals the
new writeback-stall counter.

| Workload MxNxK | Total cycles | Prefetch wait | Denial | FIFO full | Request grant | Outstanding drain | Handoff ready | Write | Productive write | Writeback stall |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 4x4x32 | 78 | 22 | 0 | 0 | 1 | 14 | 7 | 8 | 4 | 4 |
| 8x8x32 | 110 | 42 | 1 | 0 | 15 | 19 | 7 | 17 | 16 | 1 |
| 16x16x32 | 230 | 84 | 13 | 0 | 36 | 28 | 7 | 89 | 64 | 25 |
| 16x32x32 | 403 | 129 | 32 | 0 | 41 | 42 | 14 | 163 | 128 | 35 |
| 32x32x64 | 1189 | 500 | 77 | 0 | 183 | 180 | 60 | 320 | 256 | 64 |
| Total | 2010 | 777 | 123 | 0 | 276 | 283 | 95 | 597 | 468 | 129 |

All prefetch wait rows balance to their totals; all write rows also balance to
their write-state cycles. Protection-error and no-request buckets were zero in
these workloads.

## Interpretation

For `32x32x64`, prefetch wait accounts for `500/1189` cycles (42.05%). Request
denial is `77/500` (15.4%) and FIFO-full is zero. The remaining primary
classifications are 183 cycles issuing accepted requests, 180 cycles waiting
for accepted responses to drain, and 60 cycles with the next buffer ready for
handoff. Request-grant and outstanding-drain counts occur while the FSM is in
`ST_PREFETCH_WAIT`; they are not proven avoidable stalls. The global request
denial counters are event counts and may overlap other events or FSM states.

The same workload spends 320 cycles in `ST_WRITE`: 256 accepted productive
writes and 64 unaccepted writes. The 64 line-request denial events align with
the 64 writeback stalls in this workload, which points to `line_ready`
backpressure as the immediate cause. The existing profile does not measure
whether that backpressure can be hidden or changed by RTL.

Across all five workloads, global event counters report 362 arbiter-stall
cycles, 233 banked-request denials, 129 line-request denials, and zero scalar
denials. For `32x32x64`, the corresponding counts are 210, 146, 64, and zero.
These counters span FSM states and are not an additional exclusive partition;
in particular, the 123 prefetch-wait denial buckets count only their primary
classification inside `ST_PREFETCH_WAIT`.

Increasing the outstanding FIFO depth is not supported by this evidence:
FIFO-full was zero in all five workloads. A possible A-to-B prefetch overlap
change at `PF_A_DRAIN` is only a hypothesis. The profile does not cross-tab
`ST_PREFETCH_WAIT` with `PF_A_REQ`, `PF_A_DRAIN`, `PF_B_REQ`, and `PF_B_DRAIN`,
nor does it identify how much response drain was already hidden under MAC
cycles. Therefore it cannot establish an exposed A/B serialization penalty.

## Next measurement

Before proposing RTL, add passive `ST_PREFETCH_WAIT x prefetch_state` cycle
counts and report the intersections with request denial and outstanding
drain. Alternatively, run controlled bank-ready and response-latency variants
with the same workload and seed. Keep assertions, reference-model checks,
fault checks, and public command behavior unchanged. A candidate should be
proposed only if the new evidence isolates exposed cycles and yields a bounded,
falsifiable RTL hypothesis.

No RTL behavior change was made by the attribution commit. The VCS regression
and all four Stage Runtime stages passed; no candidate was evaluated and no
performance improvement is claimed.
