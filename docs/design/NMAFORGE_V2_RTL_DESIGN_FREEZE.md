# Front-end design freeze disposition

**DESIGN_PARTIAL.** The consolidated product candidate is usable for continued front-end work; unconditional design freeze is withheld because same-model TinyNPU Transformer comparison, complete scheduling root-cause closure and macro-interface validation remain open. Do not interpret missing backend/UVM signoff as a requirement to run those deferred flows in this round.

Final target branch: `feat/nmaforge-rtl-finalize`. Product baseline: `800c5b0ab1f0b9de5937c65e7c5f57b6d6fbc92c`. RTL implementation commit `3f108df` (full SHA and artifact hashes in Round 28 manifest). The documentation commit is obtained with `git rev-parse HEAD` after checkout; no self-referential commit hash is embedded in its own contents.

No modules added or moved. No filelist changes required. Existing research innovations are implemented in production Matrix RTL: 0x52 shared-array K-fold plus command-local B reuse; 0x53 exact fused postprocess with bounded row-major writeback and optional local tile forwarding. Isolated research wrapper numbers were not substituted for product measurements.

One new bounded RTL experiment retained: LayerNorm reciprocal existing divider acceleration. No new register/buffer/SRAM/port, no second MAC array, no ABI change. Full H16 decode decreases 72,238→70,318 cycles with identical model, logits/KV hashes and tensor Golden; trained CNN performance unchanged. Default smoke, seeded smoke and independent SFU Golden/fault checks pass.

The microarchitecture review documents storage/mux cost, scalar/banked routing, stage timing, reset/abort boundaries, SRAM interface and possible 2.5 ns paths. Performance review documents objective TinyNPU gaps and endpoint limits. Main, product and research branches/worktrees were preserved. See BRANCH_RECONCILIATION.md for exact branch inventory and migration decisions.
