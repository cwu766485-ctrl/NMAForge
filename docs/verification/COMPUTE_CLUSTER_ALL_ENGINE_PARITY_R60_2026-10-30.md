# Compute Cluster R60 — All-Engine Parity Fault Slice

**Date:** 2026-10-30
**Verification/test SHA:** `2768843da1b3f3a0e988645746000d5befadf12b`
**Product RTL/SPEC SHA:** `f916874a9ce60741a4516eaf9e33ebcae4a676c2` (unchanged by R60)
**Parent replay harness:** `ded9d923a432e869592ec8710a22df5501d8d474`
**Decision impact:** scoped evidence added; all 38 requirement dispositions remain 24 PASS-SCOPED / 14 PARTIAL and `CL-DV-v1.0` remains HOLD.

## What changed

The real-top Compute Cluster UVM sequence extends its seeded SPAD parity-read test from 14 to 18 cases. The cases cover INT8, Matrix, CNM, BF16, SFU, Conv, and KV; A/B operands where defined; and all four CNM lanes. The sequence shuffles the deterministic list with the selected regression seed. For each case it checks the owning engine's error completion, accepted-read drain, and unchanged output sentinel. Conv/KV report their specified merged SPAD parity completion code (`7`); the other tested engines report code `5`.

The scoreboard now records an observed active error by engine and permits that same engine's terminal `Done` in the following sampled cycle. This matches the production Conv/KV error-state timing. The grace is owner-specific and one cycle only; a bare or duplicate `Done` remains an error, and reset/abort clears the pending allowance. No product RTL, SPEC, or error ABI was changed.

## Exact clean-SHA execution

The tests ran from a detached clean worktree at the verification/test SHA above using Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`.

```sh
cd /tmp/nmaforge_cluster_r60_clean_2768843/dv/uvm/sim
make uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_cluster_r60_clean_2768843 \
  COMPUTE_CLUSTER_UVM_SEEDS='20261030 20261025 20261026'

make uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_cluster_r60_clean_2768843 \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_cluster_r60_mutation_2768843

cd /tmp/nmaforge_cluster_r60_clean_2768843/dv/subsystem/top_smoke/sim
make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

### Results

| Run | Result | Evidence |
|---|---|---|
| `R60-CLUSTER-UVM-3S-ALL-PARITY` | PASS, all three seeds; 18/18 parity cases each; UVM warning/error/fatal `0/0/0`; 5,445 checked memory words, zero mismatches/unknown reads/orphan responses; pending queues empty; reset-dropped=9 | `/tmp/nmaforge_cluster_r60_clean_2768843/seed_{20261030,20261025,20261026}/run.log` |
| `R60-MUTATION-25` | PASS 25/25 expected checker-sensitivity catches | `/tmp/nmaforge_cluster_r60_mutation_2768843/`; manifest SHA-256 `999550aa0216bb25acd95238c3da70b5b85edb3725ec99c35595ef90257d0236` |
| `R60-TOP-SMOKE` | PASS | `/tmp/nmaforge_cluster_r60_top_smoke_2768843.log`; SHA-256 `7b20e4aeb6c49e2ae297fb6dacc4a4af07768813dc55de8053c6b6052fb469ee` |
| `R60-TOP-RUN20` | PASS, seed 12345 | `/tmp/nmaforge_cluster_r60_top_run20_2768843.log`; SHA-256 `901f9512a5b0ba93fe744ea50329c12d45460df7387023859a9ffbfb5fc5b9e8` |

Per-seed UVM log SHA-256 values:

| Seed | SHA-256 |
|---:|---|
| 20261030 | `a277971db16b068cdaa09e7ac3aa2316e8bdaa8864456c86ae3d31246fffe0ad` |
| 20261025 | `604ea4ba6f0ba9a0badad5d39164b815f508773703c8a71a8c6063692fa8b296` |
| 20261026 | `83926c3e657c742edbac3ffa27ffd795531a7e990438c5122d90e98e6e8d3ceb` |

Compile log SHA-256 is `9aa647bcc282b6f43f0b0571b98e588066d9f7d335f3e37d4131011d626e9a53`; no VCS warning/error/`TFIPC` diagnostic was found. Merged URG assertion summary SHA-256 is `b591c9a5244df2207fd234c02a58794badc8cf52a5ae78a79961026103b03142`. It reports 17 successes, zero failures, zero incomplete, and five uncovered. The uncovered set includes three AXI AR/AW properties without real successes in this compute-only sequence and two UVM RAL assertions without attempts; only one of three stall-to-accept cover properties matched (W, 3 times). These remain explicit scope limits.

The 25/25 campaign mutates passive monitor observations to measure checker sensitivity; it is not a DUT RTL mutation score. `ai_smoke` still emits the existing `LOOP-REROLL-ENABLED` fixture warning. These evidence files are generated under `/tmp` and are intentionally not committed.

## Requirement and coverage disposition

R60 adds selected parity read-phase evidence to `REQ-CL-017` and `REQ-CL-027`. It does not cover every legal Engine × Fault × Phase × Abort/Reset combination, protection faults, all accepted-write-prefix boundaries, or external-fabric reset behavior. The current focused compute testpoint group is 100% for its applicable bins; that is not a 100% requirement, legal fault-cross, code, or whole-Cluster coverage claim. Matrix raw FSM coverage remains profile-specific at 49/53, with separately documented reachability/formal dispositions; R60 does not change it.

Therefore the all-engine parity read slice is **PASS**, while the affected requirements remain **PARTIAL** and `CL-DV-v1.0` remains **HOLD**. Follow-up verification must add legal phase/abort/reset combinations by engine and retain the frozen per-engine error/priority/prefix contract.
