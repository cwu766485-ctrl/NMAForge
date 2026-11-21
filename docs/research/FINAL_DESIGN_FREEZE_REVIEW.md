# Stage A review and stop decision

**DESIGN_PARTIAL. Stage A is complete; stop for architecture review.**
No Stage B/C hardware implementation or Stage E/F signoff is authorized by this
completion. Product RTL unchanged from reviewed HEAD
`da5a6691c7582d54c7a2da643e01d296f8da2d68`, latest RTL scheduling commit
`b2b3b0b5942f9218ed574a04e946104109dc2c99`.
Final publication commit is the Git commit containing these reports; it is
reported to the user after remote SHA verification, avoiding self-referential
manifest hashes. Branch `nmaforge` is already correctly named; main/unrelated
branches/worktrees remain untouched.

## Evidence and acceptance

| Item | Stage A disposition |
|---|---|
| Architecture/source/ABI audit | Complete for benchmark and candidate scope; normative SPEC retained |
| Machine-readable benchmark manifest | Source/model/fixture/Golden/arithmetic/memory/clock/boundary hashes and classes frozen; validator closes cycles/bytes and rejects forbidden ratios |
| CNN | Three same-weight mappings Golden PASS; best12,351 CMDQ,46.1634 useful MAC/cycle; input DMA/readback/host partial costs separate |
| Common native conv1x_mini | Both4-byte Golden PASS; Tiny4,742 vs NMA1,874+separate modeled layout; **no system ratio** |
| H16 persistent decode |65,771/8=8,221.375 cycles/token;1,360 Golden words/token and logits/KV PASS; quality independently evaluated |
| Full prefill / pretrained LLM | Not established: prefill is QKV/KV-only; embeddings host-preloaded, synthetic-task model |
| Matched compute | Three GEMMs and trainedQ/K/V pass raw Golden;3× cycle ratio for harness array schedules only |
| Matched controller/memory / matched full systems | NOT_RUN / not qualified; >1.10× CNN/Transformer system targets remain unproven |
| Larger model | Exact defined allocation budget complete; H32 eligible for later training/mapping, H64 does not fit resident128 KiB policy |
| Physical bank conflicts / causal dispatch-only stall | Not isolated; admission stalls and no-engine remainder explicitly labeled |
| A3 feasibility | Defer: prove partial-sum lifetime and512 B live set benefit beyond A1/A2 |
| B2 feasibility | Select128 B Matrix→Requant write-through forwarding for review; parity/protection/all-writer lifetime unresolved |
| Novelty | NOT_ESTABLISHED; scoped related-work screen only |
| ASIC freeze/signoff | Incomplete current-source macro/timing/synthesis and requirement closure; cannot mark DESIGN_FROZEN |

## Replayed checks

VCS V-2023.12-SP1_Full64: passive-profiler H16 persistent session PASS; trained CNN
legacy/first-fused/both-fused row-major PASS with20,800 Golden words each; direct
array3 GEMMs PASS; common128 KiB CNN PASS; existing tile-forward enable0/1 chain,
tag miss/repeated-consumer/abort/reset PASS. `make ai_smoke` and
`make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` PASS (default512 KiB compatibility
configuration). These are functional checks, not broad coverage/signoff closure.
Verilator5.052: pinned Tiny native graph4/4 output bytes PASS; fresh direct-array
7-shape Golden and six upstream engine tests PASS. Python3.12: independentH16
held-out quality and paired trainedQ/K/V192 words/design PASS; archive validator
PASS including invalid-ratio sensitivity. Exact commands in [REPRODUCTION](REPRODUCTION.md).

Tool compile logs preserve existing warning/support notices; no warning closure
or physical SRAM timing is asserted. Testbench adds a disabled-by-default
`STAGE_A_PROFILE` monitor and four timing markers; no DUT force or Golden change.
All original product RTL and source-list contents remain intact.

## Proposed next decision, not automatic execution

Review B2 first:128 B committed-Matrix-output snoop → registered Requant source,
keep visible INT32 writes; resolve authorization/parity and coherence before RTL.
The trace bound is at most8,192 B reads and6,144 zero-cost service clocks over8
tokens; real lookup/control cost reduces this. Reject if correctness/timing cost
is excessive. A3 stays mapper/schedule-first until accumulator continuation and
live-set feasibility are proved; no new cache/port is assumed free. Neither
proposal is an accepted research contribution or measured implementation result.

Stage A limitation is itself a result: there is enough trusted evidence to
choose what to review, but not enough matched-system or ASIC evidence to freeze
the design. Stop here as requested.
