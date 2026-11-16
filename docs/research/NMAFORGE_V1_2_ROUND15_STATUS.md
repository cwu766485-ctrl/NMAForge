# NMAForge v1.2 Round 15 — Persistent Decode Status

## Version and decision

- Research branch: `research/nmaforge-v1.2-round15`, forked from Round 14 commit `a75eb55a08415732ee981ad12f343cbd92ce3ebe` (tree `4268e3c97a24059523b289c72a69123940a55c8a`).
- Round 14 evidence: [Round 14 status](NMAFORGE_V1_2_ROUND14_STATUS.md), `/tmp/nmaforge_round14_runtime_final2/{compile,run}.log` and `/tmp/nmaforge_round14_h64_2token_batch/{compile,run}.log`. Those are successful **ring runtime** and **static batch** runs, not persistent decode.
- Product RTL was not changed in this round. The research testbench, generator, software reference, and Make target changed.
- **Overall: PARTIAL.** The token plan and independent software Golden checks pass. The new Product Top run did not compile because VCS could not connect to its license server. No G1 RTL PASS or measured persistent-token cycles are claimed.

| Gate | Status | Evidence and remaining condition |
| --- | --- | --- |
| G0 Token planner / tensor memory plan | **PARTIAL** | Two separate token invocations, stable cache addresses, per-descriptor ring publication, completion retirement, and DMA-fenced weight reload are generated and checked. The new runtime path awaits VCS. |
| G1 two-token persistent decode | **BLOCKED_ENV** | Stage 0 has 201 descriptors; stage 1 has 193 newly generated descriptors. New testbench keeps one Top instance unreset, checks 512 cache words before stage 1, checks completions and 31 stage-1 tensor checkpoints, and compares 6,912 final words. VCS compilation failed before simulation. |
| G2 token 0–5 and 4+2 | **NOT_RUN** | G1 has not passed. No six-token or 4+2 RTL claim. |
| G3 four-layer readiness | **PARTIAL** | The independent four-layer reference previously used one full-width QK matrix shared by four heads. It now computes per-head FP and INT scores/probabilities; software run passes. Four-layer Product Top graph, layer-specific KV lifetime, weight streaming, and final LN/LM-head RTL integration remain unimplemented. |

## G0/G1 implementation and exact limits

`benchmark/gpt2_compat/prepare_h64_persistent.py` provides `TokenPlanner`, `TensorMemoryPlanner`, and a ring `Runtime` contract. It invokes the existing H64 mapper twice against the same deterministic model. The generator's new `kv_append_from` selects only fresh K/V append descriptors for the second invocation. The second plan contains no token-0 KV write. It statically checks each of four heads for KV append → Product KV read → QK/AV consumption and records descriptor indices in the JSON. Product KV addresses remain K=`0xe000`, V=`0xe400`; queue base addresses and tensor allocations remain stable.

The first invocation uses token IDs `[1,0]`; row 1 is a **physical placeholder**, and only token 0 is semantically valid. It still executes two physical rows and writes the placeholder cache slot. The second invocation uses `[1,7]` and overwrites only token 1's cache slot. This is not a one-row optimized decode and does not produce tokens autonomously. The host supplies token IDs, 3,328 initialized input/constant words (13,312 bytes), and reloads 49,152 weight bytes through AXI4 DMA because the compact allocator reuses some weight addresses. The host does not publish calculated intermediate tensors or K/V.

The Product Top testbench retains CMDQ/CPLQ and SPAD across invocations. It reads and checks the historical cache before loading token 1, publishes each descriptor through AXI-Lite, waits for the hardware completion, reads the completion payload, checks applicable tensor checkpoints, and retires CPLQ before publishing the next descriptor. The 256-entry rings should wrap because 201+193 descriptors are published. A `+AI_H64_PERSISTENT_CORRUPT_CACHE` negative control is provided, but **its expected failure has not been observed in RTL**.

The independent full-recompute software check compares 388 selected token-0 words and 780 selected two-token words across 16 tensor boundaries. These are **software checks**, not Top RTL results. The generated manifest and hashes are in [the Round 15 plan summary](../../benchmark/gpt2_compat/results/round15_persistent_plan_summary.json). Raw generated images and logs remain outside Git in `/tmp/nmaforge_v12_r15_final_attempt1/`; they can be regenerated from the commands below.

## Run evidence

| Check | Command or artifact | Result |
| --- | --- | --- |
| Planner and software Golden | `/tmp/nmaforge_round10_venv/bin/python benchmark/gpt2_compat/prepare_h64_persistent.py --seed 20261116 --tokens 1,7 --out /tmp/nmaforge_v12_r15_final_attempt1` | PASS: 201/193 descriptors, 388/780 selected words; model SHA-256 `67a89c411254039bab22a7dffc49c64b69233575368503f544ee9f3ec4ab00fc`. |
| Four-head reference | `/tmp/nmaforge_round10_venv/bin/python benchmark/gpt2_compat/gpt2_compat_golden.py --out /tmp/nmaforge_v12_r15_gpt2_reference.json --weights /tmp/nmaforge_v12_r15_gpt2_weights.npz` | PASS software; both FP/INT score tensors are `[4,4,4]`; heads have distinct scores. This does not qualify the four-layer RTL. |
| Python syntax | `/tmp/nmaforge_round10_venv/bin/python -m py_compile benchmark/gpt2_compat/{generate_h64_preln_qkv,prepare_h64_persistent,gpt2_compat_golden}.py` | PASS, Python 3.12.13. |
| Top static lint | Verilator 5.052, `--lint-only -Wno-fatal --timing` with the Top source list and Round 15 defines | **INCOMPLETE**: controlled 180 s timeout (exit 124), `/tmp/nmaforge_v12_r15_lint_final.log`; no observed `%Error` before timeout, but this is not a lint PASS. |
| Product Top | `make -C dv/subsystem/top_smoke/sim ai_h64_persistent_two_token AI_H64_PERSISTENT_RUN=/tmp/nmaforge_v12_r15_final_attempt1` | **BLOCKED_ENV**: VCS V-2023.12-SP1_Full64 reports “Cannot connect to the license server” / “Failed to obtain license”; exit 255; `compile.log` SHA-256 `af50c40b5750101402cf581d159b9c03ab3274d49e9606711047e10d572448c9`; no `run.log`. An earlier targeted baseline qk compile attempt failed for the same reason. No more license retries were made. |

The Round 15 VCS log is a local generated artifact, not a checked-in sign-off report. Its license error appeared on stderr; the `compile.log` itself stops at the VCS banner and CPU-time line. No Product Top syntax, function, cache-dependency negative control, performance, DMA/SPAD traffic, or completion PASS for this code has been established.

## Open issues and G1 exit

1. Restore a valid VCS license connection, then rerun the exact Make target above. Require the stage-0 `REPRESENTATIVE_MODEL_PASS`, `H64_PERSISTENT_KV_BEFORE_PASS`, all stage-1 completion/tensor checks, and `H64_PERSISTENT_TWO_TOKEN_PASS`. Preserve the complete compile/run logs.
2. Run the cache corruption control against the same compiled simulator; require a specific tensor mismatch. Inspect Token-0 historical cache before and after Token-1 and verify all four heads.
3. Only after G1 passes, expand the planner to six successive invocations and 4+2 prefill/decode, then measure per-token cycles, DMA/SPAD bytes, peak live SPAD, wrap and backpressure. Do not count a static six-token graph.
4. The corrected four-head software reference is still not numerically contract-matched to the Product SFU; four-layer RTL integration needs layer-specific caches, intermediate lifetimes, final LN/LM head and weight transfer plan before a PASS can be considered.

The public repository contains no license settings, PDK files, or generated simulator database.
