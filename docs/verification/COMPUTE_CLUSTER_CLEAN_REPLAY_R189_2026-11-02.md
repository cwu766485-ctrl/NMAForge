# Compute Cluster exact-candidate clean replay — R189

**Run ID:** R189-EXACT-CANDIDATE-MUTATION-SMOKE-20261102  
**Tested source/test SHA:** 5068af69e5006fdc869d60244df0708c810cf3ea  
**Tree:** 885200c7b42bd5a13a5ea8e9331988ce3299da60  
**Published same-tree code commit:** 744d560c6402c64517fde47ca278e944e93060ef  
**Tool:** Synopsys VCS V-2023.12-SP1_Full64.

## Checker-sensitivity campaign

Run from the detached clean worktree at the fixed source/test SHA:

    VCS_ARCH_OVERRIDE=linux make -C /tmp/nmaforge_r188_replay/dv/uvm/sim uvm_compute_cluster_mutation VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r188_replay_mutation/uvm COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r188_replay_mutation/mutations

The target exits 0 and reports COMPUTE_CLUSTER_MUTATION_CAMPAIGN_PASS. All 28 assigned checker-sensitivity probes are injected and caught by the expected checker:

- Address, data, response owner, WSTRB, completion error code, write-after-error prefix, and response epoch: 7/7.
- Done, missing-Done, and duplicate-Done lifecycle mutations across all seven engine bits: 21/21.

These mutations alter passive monitor observations. They demonstrate checker sensitivity, not a DUT RTL mutation score. The expected UVM checker errors in mutation runs are required by the gate; they are not reported as functional regression errors.

## Top Smoke and seeded cases

Run in the same clean worktree, with a fixed simulator seed, mapper input and 20 random cases:

    VCS_ARCH_OVERRIDE=linux make -C /tmp/nmaforge_r188_replay/dv/subsystem/top_smoke/sim ai_smoke VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg PYTHON=python3.11 SEED=20261025 AI_RANDOM_CASES=20 AI_SEED=12345

The 86-descriptor / 60-tensor mapper precheck passes and Top Smoke ends with TEST PASS. The compile reports the existing Warning-[LOOP-REROLL-ENABLED] fixture warning; no Error or TFIPC diagnostic is present. This warning is retained as a disposition item, not hidden.

The same exact test SHA already passes the R188 three-seed real-top UVM (20261025/26/27), including minimum Scalar VDOT CMDQ dispatch, Golden, completion and guard checks. R188 evidence is in [the minimum-VDOT report](COMPUTE_CLUSTER_SCALAR_VDOT_MIN_CMDQ_R188_2026-11-02.md).

## Reproduction artifacts

| Artifact | Path | SHA-256 |
|---|---|---|
| UVM mutation compile log | /tmp/nmaforge_r188_replay_mutation/uvm/compile.log | 7c2353b57ecb7febd715ebc20318fafc51cd7eb0ec3a669da838d3b3a56c925d |
| Top Smoke compile log | /tmp/nmaforge_r188_replay/dv/subsystem/top_smoke/sim/ai_comp.log | 65f8350f59330bac7737f57da9b954fa4715ad4e6e2390a0c22c9b17235ac705 |
| Top Smoke run log | /tmp/nmaforge_r188_replay/dv/subsystem/top_smoke/sim/ai_accel_smoke.log | 488c86c19e30c257fdaea455deae69a809a5bd0ffc31d3a466ea18867af01754 |
| Per-mutation log manifest | /tmp/nmaforge_r189_manifest.txt | 31536417b63a77bb26d19d302a8b5ec5c3354f474c55f577c698883e4777e357 |
| Compressed evidence archive | /tmp/nmaforge_r189_clean_replay_evidence.tar.gz | 9121aa9043c3a2be2732e5e68d0151e79d8e1142baa646a7574bf2aa0f0578d1 |

The archive contains all 28 mutation logs, both compile logs, the Top Smoke run log, and the manifest. Generated files remain outside the repository.

## Sign-off effect

R189 confirms reproducibility and checker sensitivity for the named scopes only. It does not close the remaining legal Engine × Fault × Phase × Reset/backpressure space or promote any requirement. The disposition remains 24 PASS-SCOPED / 14 PARTIAL, and CL-DV-v1.0 remains HOLD.
