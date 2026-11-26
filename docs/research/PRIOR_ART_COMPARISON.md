# Prior art and differentiation audit

Stage A conclusion: **neither A3 nor B2 is an established novel contribution**.
No literature speedup, PPA or benchmark is imported as an NMAForge result.
A small cache, operator fusion or tiling alone is conventional. The following
comparison identifies what a later experiment would need to distinguish.

| Related work | Established idea relevant here | Candidate distinction to prove | Current evidence / limitation |
|---|---|---|---|
| Chen et al., Eyeriss: A Spatial Architecture for Energy-Efficient Dataflow for Convolutional Neural Networks, JSSC2017, [DOI](https://doi.org/10.1109/JSSC.2016.2616357) | Spatial reuse and movement-aware CNN dataflow | A3 bounded tile-lifetime leases in a shared multi-engine SPAD with visible writes and exact partial-sum ownership | Current A1/A2 micro evidence only; no A3 implementation or area/energy evidence |
| Parashar et al., Timeloop: A Systematic Approach to DNN Accelerator Evaluation, ISPASS2019, [DOI](https://doi.org/10.1109/ISPASS.2019.00042) | Explicit mapping, memory hierarchy and dataflow evaluation | Trace-verified capacity/ownership/port-constrained mapper eligibility, with actual RTL end-to-end cycles | Budget and traces exist; schedule feasibility/physical cost not established |
| Genc et al., [Gemmini: Enabling Systematic Deep-Learning Architecture Evaluation via Full-Stack Integration](https://arxiv.org/abs/1911.09925) | Full-stack accelerator/memory/software evaluation, system effects | Same boundary and arithmetic pairing; quantify cost of required materialization and coherent cross-engine reuse | Stage A methodology improves traceability; no claim of inventing full-stack benchmarking |
| Dao et al., [FlashAttention: Fast and Memory-Efficient Exact Attention with IO-Awareness](https://arxiv.org/abs/2205.14135) | Exact attention with IO-aware tiling and reduced intermediate movement | B2 preserves architecturally observable INT32 writes, forwards committed small tensors across engines under existing command lifecycle | Different layer/scale and contract; no claim to replace FlashAttention or transfer its GPU speedups |
| Pinned TinyNPU source and graph compiler | Systolic compute plus graph dispatch, scratch/accumulator memories, host-emulated DMA harness | Exact common tensors, controller/memory scope, shared fixed-point architecture and honest capacity normalization | Matched array and common native graph Golden exist; full matched systems absent |
| Conventional write-through buffers / producer-consumer forwarding | Cached committed data, tags, masks, invalidation and registered bypass | B2 bounded all-writer coherence plus parity/protection and abort semantics without lost INT32 visibility | A hypothesis, not a new primitive; needs broader focused literature search |

Access scope: Eyeriss/Timeloop DOI landing metadata and existing repository
literature notes; no newly read full text is claimed. Public arXiv title/author/
abstract pages were read for Gemmini/FlashAttention; metadata is archived in
`benchmark/research/stage_a/related_work_metadata.json`. This is a scoped prior-art
screen, not an exhaustive novelty review. Before publication, read full papers,
search accelerator operator-fusion/streaming-buffer and coherent scratchpad work,
and document concrete closest implementations, not only broad architecture papers.

Each proposed contribution still needs mechanism + actual RTL + independent
Golden + matched ablation + end-to-end performance + area/timing/resource cost +
limitations. Current A3/B2 have hypotheses, traffic bounds, proposed ownership and
risk envelopes only. Reported array3× and existing opcode fusion are baseline
characterization; they do not validate either research contribution.
