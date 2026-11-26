# Round 28 handoff

Candidate `/tmp/nmaforge-round28`, branch `feat/nmaforge-rtl-finalize`, product-based and independent of original research worktree. Status DESIGN_PARTIAL; stop after commit/push, no Round 29 started.

Completed: branch audit, product code inspection, one LN performance change, paired H16 Golden/hash run, 128 KiB trained and mini CNN, 512 KiB smoke and seeded smoke, SFU focused regression, eight Matrix switch tuples on three identical GEMMs, existing forwarding and product GEMV replay, pinned TinyNPU arithmetic/engine/CNN runs. Raw logs and CSV/JSON under benchmark/representative/round28; exact reproduction in Round 28 performance report. Git diff --check required before publishing.

Round29 continuation: independent `feat/nmaforge-rtl-freeze-r29` worktree, fresh baseline and candidate H16, one cache-setup scheduling optimization, 8,789.75→8,669.75 cycles/token with identical Golden. See `docs/design/round29/RTL_DESIGN_FREEZE_REVIEW.md` and raw Round29 manifest. Status DESIGN_PARTIAL / REMOTE_NOT_PUBLISHED. No next round started.
