# Compute Cluster SPAD Arbiter Formal Fairness — R290

**Disposition:** Supplemental bounded-fairness evidence for `REQ-CL-014`. The requirement remains **PARTIAL** and `CL-DV-v1.0` remains **HOLD**.

## Candidate and reproducibility

| Item | Evidence |
|---|---|
| Candidate/test commit | `042eb6bab91726c4a48a69def07c54ea02abe4e3` |
| Candidate tree | `40b21f1fada238d86ef293dbd2571404cef907b3` |
| Frozen R158 ancestry | Ancestor `8e3735e930f01c4a6bbb6a79251e153611dfcda2`, whose tree is the frozen `aa1e7b180ca911fbaabec3e963b4523547779c24` |
| Run ID | `R290-SPAD-ARBITER-FAIRNESS-VCF-20261104` |
| Tool | Synopsys VC Formal `V-2023.12-SP2` |
| Execution | Detached clean worktree at the candidate commit; command below exited 0 |
| Log archive | `/tmp/nmaforge_r290_spadfairness_clean.tar.gz`, SHA-256 `67d8a3e16261fdb5ab83f6d05f9d01ec39eb0fc54c55450a60e26278f0c0bf77` |
| Raw log SHA-256 | `9c53cdf5e3908c5e0addab492452833a404a8faf6234be2c664f7906a782e17b` |

```sh
make -C dv/block/spad_arbiter/formal fairness-bounds \
  VCF=/opt/Synopsys/vc_formal/V-2023.12-SP2/bin/vcf \
  FAIR_OUT=/tmp/nmaforge_r290_spadfairness_clean
```

The run uses the production `rtl/memory/ai_spad_arbiter.v` and does not modify product RTL. The proof harness and Tcl hashes are recorded in the archive manifest.

## Proof results

| Test ID / Checker | Bound or property | Result |
|---|---|---|
| `TC-PC-R290-SPAD-ARBITER-DATA-PLANE-BOUNDED-FAIRNESS-FORMAL` / `ap_core_class_progress_within_two` | Held Core scalar or Line request is granted within 2 clocks | Proven, non-vacuous |
| same / `ap_dma_class_progress_within_two` | Held DMA scalar or Line request is granted within 2 clocks | Proven, non-vacuous |
| same / `ap_matrix_banked_progress_within_five` | Held Matrix banked request is granted within 5 clocks | Proven, non-vacuous |
| same / `ap_cnm_progress_within_five` | Held CNM request is granted within 5 clocks | Proven, non-vacuous |
| same / `ap_data_plane_grant_is_exclusive` | At most one data-plane client class is granted per clock | Proven |
| same / six reachability covers | Core scalar/Line, DMA scalar/Line, and both directions of Matrix/CNM contention | 6/6 reached |

VC Formal reports 5/5 assertions proven, all four implication assertions non-vacuous, 6/6 covers reached, and `check_fv_setup` reports no setup issues. The Make target gates all of these results.

## Assumptions and limits

- Descriptor and completion requests are tied idle. The proof starts after strict-priority control-plane traffic drains; it does not bound data-plane wait under continuous control-plane traffic.
- Legal ready/valid sources hold each request valid until acceptance. Core scalar/Line and DMA scalar/Line forms are assumed mutually exclusive.
- `ai_spad_arbiter` has no downstream ready input in this interface. Consequently this proves scheduler grant selection, not service progress through SRAM or an external fabric under backpressure.
- The model includes the arbiter's Core, Matrix-banked, CNM, and DMA request classes. It does not instantiate the seven production engines, the complete SPAD/fabric, Protection, parity/error injection, response backpressure, or fault × phase × reset crossings.
- VC Formal emitted `COM_OPT009/010` because `search_path` and `link_library` are unset (the harness has no library cells), a clock-unit adjustment notice, and a first-run learned-data-not-found notice. There were no formal setup issues or proof failures.

This closes one formal bounded-progress testpoint only. General production-cluster fairness and the remaining legal requester/fault/phase/reset/backpressure combinations stay open; no RTM status is promoted.
