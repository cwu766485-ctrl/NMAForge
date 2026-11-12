# Product candidate integration review

Remote product base: `c93ea144713d5fafe2e8a5509029927cd6859e75`.
Tested RTL checkpoint: `fc60f95d72c0cfb7dfa9df895a30a701c842d21e`.

Ancestry is linear: Phase4 `b1dd75b8d1b6bb0465bdb3452df556a7919f7c4d` → Round2 `56adb1245ecd7de740c4c90c48844f6b88fdd24c` → final A/B `14c3f8a9adbb98070b08d617bb0c953a9abb8d47` → Gate1 `7102485eb966e39398a27d3c9af1815c11276c69`. Each descends from the remote product. No duplicate cherry-pick was used.

Candidate starts at the remote product, selectively imports the final Matrix ping-pong RTL, DMA late-source-error response drain fix, offline Mapper, and required tests. Historical research archives are excluded. Original branches and PR #5 remain intact. Candidate requires review; no merge authorized or performed.

Retained: existing four-lane fused requant/row-major ping-pong line writeback, bounded offline shape dispatch, existing DMA Store output scheduling, independent Golden/accepted-byte scoreboards. Legacy arithmetic, ABI, SRAM permissions and parity remain unchanged.

Rejected from new scope: dynamic opcode rewriting, speculative SFU, transparent Matrix→Requant cache, added SRAM ports/cache capacity. Existing mechanisms inherited from product are not newly approved by these tests.

`isolated=True` is a software precondition, not a hardware lease: operands and permissions must remain stable for the chosen command; dynamic Host/DMA writes/revocation are outside cross-opcode equivalence. Legacy fallback remains available.

Static correction: default-initialize mux search temporary; split request selection, admission/protection return, response routing into separate combinational processes. This eliminates Verilator 10 LATCH and 3 UNOPTFLAT diagnostics without added state or changed port geometry. No clock-frequency claim follows.

Reproduce ancestry: `git merge-base --is-ancestor <older> <newer>` for adjacent SHAs; `git diff c93ea14..HEAD -- rtl sw` for actual product delta. Source lists are unchanged because no RTL module was added or moved.

Bounded hardware cost relative to product: ping-pong adds128data bits+64address bits+2full bits+3pack/commit/done bits=197 explicit register bits before synthesis, plus a128bit2:1 commit mux and control. Existing four postprocess lanes are reused. DMA drain fix adds no registers; mux correction adds no intended state. Mapper/output scheduling add no RTL state or SRAM ports. This is a source inventory, not mapped area/power/timing evidence.
