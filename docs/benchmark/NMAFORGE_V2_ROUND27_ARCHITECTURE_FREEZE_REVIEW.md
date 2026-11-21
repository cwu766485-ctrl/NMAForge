# Round 27 architecture freeze review — INCOMPLETE

No architecture freeze recommendation is supported by this session. No RTL was changed, no Round 27 functional simulation or synthesis was run, and no independent performance experiment was completed. The requested work remains unfinished.

Current worktree source: `c290eba7697138a4fcf2cbbac9262264849f0aeb`. The requested baseline `800c5b0ab1f0b9de5937c65e7c5f57b6d6fbc92c` exists as a separate Git commit. Selected historical CSV/JSON and its report were extracted unchanged from that commit; they do not establish current-source performance. The historical manifest references additional artifacts that were not restored here.

## Gate status

- Gate 0: historical mean decode is 9,029.75 cycles/token and historical LayerNorm interval is 373 cycles/descriptor. Exclusive phase timings remain UNKNOWN. Earlier unsupported numerical phase allocations were withdrawn. A counter sum matching 373 would not prove measurement validity.
- Gate 1: no candidate was measured or fairly ranked. Repeated input reads exist in the inspected current SFU FSM; buffer reuse may save traffic but needs baseline-matched tracing, alias/error semantics review, implementation and validation. Row batching and optional fusion remain unevaluated. No measured decode speedup is available.
- Gate 2: historical GEMM cycles are 175/263/1,407. Large-case read traffic is 6,144 bytes, including repeated reads. Historical prefetch/bank/arbiter counters overlap and cannot establish causal root cause or removable time. No scheduling candidate was tested.
- Gate 3: historical CNN DMA+CMDQ subtotal is 15,966 simulated cycles. Full host preprocessing, readback, pooling, argmax and consistent legacy/fused endpoints remain open.
- Gate 4: historical common arithmetic Golden results do not establish matched system timing. No new common Transformer subgraph or matched controller endpoint was run.
- Gate 5: no supported freeze decision, current-source PPA assessment or completed ten-question closure is available. Research contributions retain the limitations described in Round 26.

## Artifacts and validation

`benchmark/representative/round27/` contains historical GEMM extraction, explicit UNKNOWN LayerNorm stages, unevaluated candidates and a manifest with hashes. Tool versions in that manifest are historical only. The historical persistent-decode CSV contains logits/KV Golden hashes; no new Golden replay was performed.

Extraction command pattern: `git show 800c5b0:<artifact-path> > <artifact-path>`.

A Python structural check previously passed but verified only arithmetic consistency, not evidence validity. No VCS PASS or synthesis PASS is claimed. Git staging/commit failed because `.git/index.lock` could not be created in the read-only Git directory; the escalation attempt was aborted. Nothing was committed or pushed. Existing untracked `novas.conf` and `novas.rc` were preserved.
