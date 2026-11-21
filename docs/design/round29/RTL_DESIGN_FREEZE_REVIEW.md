# Round 29 RTL design freeze review

**DESIGN_PARTIAL / REMOTE_NOT_PUBLISHED.** No unconditional front-end freeze or signoff claim. Functional/numeric evidence supports retaining one bounded SFU optimization; common Transformer subgraph and complete interface-risk disposition remain open.

Candidate branch `feat/nmaforge-rtl-freeze-r29`, worktree `/tmp/nmaforge-round29`, based on Round 28 `f2bed3dd7386b1b9cc79c20bb065d06354b1beca`. RTL implementation commit recorded in `benchmark/representative/round29/manifest.json`; final documentation SHA is the checkout HEAD. Original main/product/research/Round28 worktrees and branches remain unchanged.

Gate 0: worktree/branch/status audited; original only untracked novas files preserved. Round28 RTL diff is one exact-divider acceleration condition. Baseline fresh replay equals archived 8,789.75 cycles/token. Existing SSH key authentication was tried with BatchMode and Git push; GitHub returned Permission denied (publickey). No remote branch SHA could be verified for finalize; no force push or credential changes were attempted. Local commits remain intact.

Gate 1: mutually exclusive states sampled before choosing cache setup/write-commit overlap. Gamma/beta fetch (96 cycles) unchanged because eliminating reads would require additional ports/state/alias contracts; combining multiply stages would lengthen arithmetic path. Selected candidate bypasses 15 cache-setup states/row and saves 120 cycles/token without adding buffers or removing intermediate outputs.

Gate 2: three fixed GEMMs and product GEMV replayed; existing B-cache/prefetch four-way and forwarding ablations pass. No Matrix RTL change; no unsupported causal inference from overlapping counters.

Gate 3: trained CNN and persistent H16 Golden pass; pinned Tiny arithmetic/engine/CNN replay pass. Common CNN mathematical parity exists, but timing endpoints differ. Common full Transformer subgraph remains incomplete. Only same-design paired H16 speed ratio is reported.

Gate 4: architecture, modules/interfaces, ABI, performance, ablation, freeze review and open risks are in this directory. No module moves/additions, so source lists remain unchanged. Synthesizability review covers fixed-width indexing, existing register-array read and synchronous enable, no new latch/port/memory; VCS compiles and Verilator lint/elaboration exits zero with 17 pre-existing warnings, normalized baseline/candidate warning sets equal. This is not DC synthesis or timing/LEC evidence.

Final source passed SFU 64 numeric + 9 error cases, selected 39-state abort/reset/recovery, default smoke and 20-case seed 12345 regression. No new VCS Error- diagnostic; existing LOOP-REROLL-ENABLED notice retained. Physical Fmax, full UVM, SpyGlass, DFT and P&R were not executed. Stop after this round.
