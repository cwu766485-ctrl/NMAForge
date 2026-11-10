# Consolidated nmaforege branch

Created from performance candidate 7bfa652. Merge includes origin/feat/shape-adaptive-gemv-v2 at 3ec0be5, preserving both histories. Product feature/npu-architecture-v2 at 800c5b0 and feat/tinynpu-model-inference at 681d37e are already ancestors; no duplicate migration needed. Round28/29/performance local branches are ancestors as well.

Twenty-two conflicts were reviewed as divergent historical product/research versions. Validated product/performance versions retained in canonical paths; original research versions preserved losslessly with SHA256 in docs/archive/branch-consolidation/resolutions.json and gzip files. No RTL, mapper or DV functional content differs from 7bfa652 after merge. Historical incomplete Round27 notes are imported with their explicit unmeasured limitations.

No branches deleted yet. Remote publication and remote SHA verification must succeed before deleting any merged remote branch. main preserved. AXI VIP, backup and historical verification branches have independent commits and are outside the initially inferred NPU/performance consolidation scope pending user selection. Existing worktrees and their checked-out branches remain intact.

Further optimization priorities: (1) common measured memory/controller boundary for TinyNPU; (2) trace Matrix request issue and prefetch wait by operand/bank before changing scheduling; (3) pipeline SFU transfers within existing SPAD port, preserving alias/error semantics; (4) examine residual response-to-output timing before treating cycle improvement as throughput improvement. Do not duplicate arrays or remove checked intermediates to meet a benchmark.
