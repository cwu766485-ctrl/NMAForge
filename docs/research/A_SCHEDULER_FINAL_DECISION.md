# A Scheduler Final Decision

## Baseline

The product comparison baseline is branch `candidate/frontend-closeout` at
`f919bb787dab1a4e3bef44b5308ead56d6e77b72` (PR #7 lineage). The research
branch is `feat/shape-adaptive-gemv-v2` at `c43cfde3b2d4040467c63737148a08241672b374`.
They were audited in separate worktrees. No RTL from the research branch is
used as product evidence.

The existing `ai_spad_arbiter` remains the sole scheduler-side admission point.
Descriptor/completion traffic has control-plane priority; data-plane traffic
uses the existing round-robin policy. Matrix banked reads and CNM responses
retain separate tags/lanes. `DMA_CTRL` is gated by `!processor_busy &&
!dma_busy`, so compute/DMA overlap is not software-reachable under the current
contract.

## Evidence and decision

The exact-SHA Stage 1/2 monitor reported three real-top seeds with zero
bank-disjoint scalar/CNM opportunities. Matrix requests use all four banks;
the observed staged Matrix/CNM overlap was competing traffic, not an unused
parallel port. Existing staged and queued speedups measure engine overlap, not
a new scheduler policy. No legal representative request stream demonstrated
a scheduler benefit or a fairness regression requiring RTL change.

**Stage 4: DEFER.** Keep the current arbiter, response ownership, priority,
and completion semantics. Re-open only when an approved ABI/control revision
permits compute/DMA overlap or a legal workload demonstrates repeatable
bank-disjoint opportunity. Any future candidate must preserve Matrix tag 3,
CNM tag 5, control priority, ordered retirement, and accepted-write prefix.

Reproduction is recorded in `docs/research/ARCHITECTURE_INNOVATION_STAGE_ROADMAP.md`
and the Stage 1 logs under `/tmp/nmaforge_stage1_a_subsystem` and
`/tmp/nmaforge_stage1_a_cluster_current`.
