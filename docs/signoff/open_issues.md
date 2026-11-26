# Round 21 Open Issues

Final disposition: **HOLD**. This is a front-end evidence review, not ASIC/tapeout sign-off.

1. **Coverage / RTM:** Existing 38-row dispositions remain 24 PASS-SCOPED / 14 PARTIAL. No blanket replay or promotion was applied. The four new v2 requirements are PARTIAL. See `signoff_requirement_matrix.csv` and `coverage_disposition.csv`.
2. **128 KiB generic Top Smoke:** FAIL (23 errors), because this generic smoke contains hardcoded 512 KiB boundary addresses and engine-pair overlap cases outside the smaller memory range. It is not a proof that all 128 KiB workloads fail: dedicated H16 incremental KV and CNN fused runs at 128 KiB pass. The generic smoke test must become capacity-aware before it can qualify that profile.
3. **Lint:** Current candidate run exited 137 during Matrix Core elaboration at module 15/51; no current lint database/report exists. Historical 465-warning totals are from older SHA `410b81d` and are not current evidence.
4. **CDC:** Structural run reports 0 unsynchronized crossings and 0 convergences, but `Reset_sync04` remains a review-required warning. `FLAT_504` remains a documented tool precision risk; no waiver/closure is claimed.
5. **RDC:** Bounded 600 s run timed out at `Ar_resetcross01` 385/478 with about 7.6 GB RSS. No RDC result was generated.
6. **Synthesis:** Matrix Core DC mapping failed internally after entering technology mapping, including one retry without the unsupported operating-condition query. The Matrix Array diagnostic run must be finalized; without mapped Matrix Core results, area/timing/Fmax/power are unavailable.
7. **Formal scope:** Matrix FSM and completion ownership are PASS-SCOPED. Dedicated KV append interruption/stale-token and fused output address/word properties were NOT_RUN. No whole-design equivalence was run.
8. **Checker mutation:** R21 mutation probe alters a passive scoreboard observation copy only; it demonstrates checker sensitivity, not a DUT RTL mutant. No waveform was captured.
9. **External reset/fabric:** Mixed AXI stall/reset regression uses the in-repository behavioral fabric and does not qualify arbitrary external fabrics.
10. **128 KiB ASIC SRAM:** No compatible macro adapter or mapped SRAM integration was demonstrated. Behavioral-model capacity results do not establish macro timing/area.
11. **CNN evidence scope:** The 262,144-MAC workload uses fixed-seed deterministic inference weights and is not a trained CNN accuracy result. The separate trained ten-class CNN is a 396-sample held-out top inference run (384 correct, 96.9697%); it is not a full Cluster sign-off.
