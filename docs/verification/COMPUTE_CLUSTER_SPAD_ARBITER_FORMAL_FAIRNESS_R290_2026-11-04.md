# Compute Cluster SPAD Arbiter Formal Fairness — R290

**Disposition:** Supplemental bounded-fairness evidence for `REQ-CL-014`. The requirement remains **PARTIAL** and `CL-DV-v1.0` remains **HOLD**.

## Candidate and reproducibility

| Item | Evidence |
|---|---|
| Candidate/test commit | `042eb6bab91726c4a48a69def07c54ea02abe4e3` |
| Candidate tree | `40b21f1fada238d86ef293dbd2571404cef907b3` |
| GitHub test commit / tree | `db4b184890b56780baf641322d22e78678a225c0` / same tree `40b21f1fada238d86ef293dbd2571404cef907b3` |
| Exact published HEAD clean replay | `e1fcde57c70936f2eb2cd8ed9aea14303a61c717`, tree `b353adf9035d5a45a1575cdbde827773051b5c1e` |
| Frozen R158 ancestry | Ancestor `8e3735e930f01c4a6bbb6a79251e153611dfcda2`, whose tree is the frozen `aa1e7b180ca911fbaabec3e963b4523547779c24` |
| Run ID | `R290-PUBLISHED-HEAD-CLEAN-REPLAY-20261104` |
| Tool | Synopsys VC Formal `V-2023.12-SP2` |
| Execution | Detached clean worktree at the exact published HEAD; formal, UVM, and both Top Smoke targets exited 0 |
| Logs-only evidence archive | `/tmp/nmaforge_r290_spadfairness_clean.tar.gz`, SHA-256 `7a99f715170f3186360172e45010be8e1adbe75145d740e2af3b04738e395516` |
| Published-head formal log SHA-256 | `b6e69e62f6c11ef6ab76acc8448266ec0fd154065b497ffc2c9ab0e831c87860` |

```sh
make -C dv/block/spad_arbiter/formal fairness-bounds \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf \
  FAIR_OUT=/tmp/nmaforge_r290_spadfairness_published
```

The run uses the production `rtl/memory/ai_spad_arbiter.v` and does not modify product RTL. The proof harness and Tcl hashes are recorded in the archive manifest.

The same exact published SHA also passed these clean-worktree VCS checks:

```sh
cd dv/subsystem/top_smoke/sim && make ai_smoke
cd dv/subsystem/top_smoke/sim && make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
make uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r290_published_uvm \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
```

The mapper passed for 86 descriptors / 60 tensors; both Top simulations ended `TEST PASS`. The three UVM seeds also pass: each checks 146,755 Memory Image words with zero mismatch/unknown/stale; the response-owner ledger drains with 10,678 accepted, 10,658 checked, and 20 reset-dropped, with no mismatch/pending. Per-seed UVM severity is 0/0/0, and focused Compute Cluster coverage is 100%.

The three-seed-only URG merge has 36 total group instances and aggregate score 84.38% because this compute-only workload leaves unrelated DDR/AXI groups unexercised. All focused Cluster groups hit. URG reports 17/22 assertions with real successes, zero failures/incomplete; two UVM RAL internal assertions have no attempts, and three AR/AW-related properties have no successes in this compute-only traffic. Only the W stall-to-accept cover matches. R289's separate 19-test merge remains the evidence for broader 37/37 functional-group coverage. The Top Smoke compile has the existing `[LOOP-REROLL-ENABLED]` fixture warning. No RTL, UVM, or Top Smoke source changed relative to the preceding published candidate, confirmed by a source-path diff.

## Proof results

| Test ID / Checker | Bound or property | Result |
|---|---|---|
| `TC-PC-R290-SPAD-ARBITER-DATA-PLANE-BOUNDED-FAIRNESS-FORMAL` / `ap_core_class_progress_within_two` | Held Core scalar or Line request is granted within 2 clocks | Proven, non-vacuous |
| same / `ap_dma_class_progress_within_two` | Held DMA scalar or Line request is granted within 2 clocks | Proven, non-vacuous |
| same / `ap_matrix_banked_progress_within_five` | Held Matrix banked request is granted within 5 clocks | Proven, non-vacuous |
| same / `ap_cnm_progress_within_five` | Held CNM request is granted within 5 clocks | Proven, non-vacuous |
| same / `ap_data_plane_grant_is_exclusive` | At most one data-plane client class is granted per clock | Proven |
| same / six reachability covers | Core scalar/Line, DMA scalar/Line, and both directions of Matrix/CNM contention | 6/6 reached |
| `TC-CL-R290-COMPUTE-CLUSTER-UVM-REGRESSION` / production Memory Scoreboard + response-owner ledger | Three fixed seeds `20261025/26/27`; 146,755 Memory Image words checked per seed; owner ledger `10,678/10,658/20`; focused Cluster coverage | 3/3 PASS; UVM severity 0/0/0 per seed; focused coverage 100% |
| `TC-CL-R290-TOP-SMOKE` and fixed seeded Top run | 86-descriptor mapper; Top Smoke and 20 random cases at seed `12345` | Both simulation targets `TEST PASS` |

VC Formal reports 5/5 assertions proven, all four implication assertions non-vacuous, 6/6 covers reached, and `check_fv_setup` reports no setup issues. The Make target gates all of these results.

For the three-seed Compute Cluster UVM URG merge, the overall score is 84.38% across 36 group instances. This includes unrelated DDR/AXI groups absent from the compute-only workload. The 22-assertion report has 17 with real successes, zero failures/incomplete, two UVM RAL properties without attempts, and three AR/AW-related properties without real success; the W stall cover matches while AR/AW covers do not. These workload gaps remain disclosed and are not considered closed. R289's separate combined UVM/E2E database carries the broader declared-group result.

## Assumptions and limits

- Descriptor and completion requests are tied idle. The proof starts after strict-priority control-plane traffic drains; it does not bound data-plane wait under continuous control-plane traffic.
- Legal ready/valid sources hold each request valid until acceptance. Core scalar/Line and DMA scalar/Line forms are assumed mutually exclusive.
- `ai_spad_arbiter` has no downstream ready input in this interface. Consequently this proves scheduler grant selection, not service progress through SRAM or an external fabric under backpressure.
- The model includes the arbiter's Core, Matrix-banked, CNM, and DMA request classes. It does not instantiate the seven production engines, the complete SPAD/fabric, Protection, parity/error injection, response backpressure, or fault × phase × reset crossings.
- VC Formal emitted `COM_OPT009/010` because `search_path` and `link_library` are unset (the harness has no library cells), a clock-unit adjustment notice, and a first-run learned-data-not-found notice. There were no formal setup issues or proof failures.

This closes one formal bounded-progress testpoint only. General production-cluster fairness and the remaining legal requester/fault/phase/reset/backpressure combinations stay open; no RTM status is promoted.
