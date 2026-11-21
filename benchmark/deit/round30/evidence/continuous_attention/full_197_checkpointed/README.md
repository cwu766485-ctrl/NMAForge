# DeiT Round 30 — checkpointed continuous Product Top run

This run supersedes the earlier `full_197` attention evidence for Q/K/V producer proof. That earlier run had no `checkpoint_spad.memh`; the present run generates and checks six chunks (Q/K/V, 8192 + 1792 words each) at producer retirement.

The Product Top uses a 256 KiB, four-bank SPAD and a 512-entry CMDQ/CPLQ geometry. It executes 468 prefix descriptors followed by 9564 streamed descriptors in 159 batches, with 19 ring wraps. One Top instance runs without reset. QKV values are checked through AXI-Lite streamed retirement; attention-side batch outputs are checked against independent Golden using passive behavioral-SPAD observation. No host intermediate tensor readback or writeback is used.

The run verifies 13 query blocks covering 197 valid query rows and all 197 valid keys across three heads; it checks 361920 attention Golden words. It does **not** execute output projection, residual, LN2, FFN, or a full Encoder Layer 0.
