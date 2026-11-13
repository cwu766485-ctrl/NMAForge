# B Shape-Adaptive Final Decision

The research wrapper at `773a747a` exercised the real four-bank
`ai_spad_arbiter` and behavioral scratchpad across 27 paired cases, nine
shapes, and three seeds. All independent INT32 Golden checks, full SPAD image
checks, sentinel checks, three abort phases, and accepted-read reset checks
passed. The geometric mean baseline/adaptive ratio was `1.0290`; five shapes
were `1.0000`, and the largest gains were `1x8x64=1.1181x`, `1x13x64=1.0763x`,
`4x8x64=1.0434x`, and `4x13x64=1.0302x`.

The earlier 144-row model comparison predicted larger gains, but assumed ideal
bank striping and zero bank stalls. It is not product-top evidence. No
held-out shape set, executable double-buffer candidate, or unified product
Matrix/CMDQ/output endpoint exists. The wrapper also uses INT64 output while
the product Matrix contract is INT32.

**Stage 4: DEFER.** Do not add GEMV hardware or change the product Matrix ABI.
The isolated wrapper remains a research reference. A future re-open requires a
held-out suite covering odd K and N tails, a real-ready/registered-response
double-buffer candidate, and a product endpoint comparison with packing, DMA,
CMDQ, output delivery, protection, parity, abort, and reset included.

Evidence: `benchmark/shape_adaptive_spad_ablation.csv`,
`benchmark/shape_adaptive_spad_summary.json`, and the B section of the
architecture innovation roadmap.
