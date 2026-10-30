# Compute Cluster real-top all-engine pairwise overlap — R93

**Run ID:** `R93-C1-PAIR-3S-20261030`

**Exact code/test SHA:** `d66431b8905ef7c1cccecef16a3cd34f4d62f9b0`

**Product RTL/SPEC baseline:** `9d4e9abdba1f745644a485960620fa6bbc4979db` (RTL and SPEC unchanged by R93)

**Decision impact:** closes the `CL-COV-004` real-top engine-pair overlap testpoint, scoped to legal, disjoint-memory workloads; overall v1.0 status remains **HOLD**.

## Purpose and scope

The earlier dispatcher pair matrix exercised behavioral engine agents. R93 extends the production-top C1 test so that all seven production compute engines run concurrently from legal CMDQ descriptors and every unordered engine pair is observed overlapping in `compute_vif.engine_busy`. The test uses disjoint SPAD source/destination regions, checks each operation against its Golden output in the final memory image, and checks ordered completions. No DUT RTL, SPEC, or Checker was weakened or changed.

The seven engines are Matrix, CNM, SFU, Scalar INT8, mixed-precision FP, Conv, and KV. The directed workloads are deliberately long enough to overlap: Matrix 16×32×64; CNM M=16/K=64; SFU GELU length 128; Scalar VDOT length 128; BF16 dot length 128; Conv 16×16 image; and KV write/read length 128. Pair observation covers all 21 unordered pairs and reaches seven simultaneous busy engines. These are concurrency/Golden checks, not the complete requester × owner × fault × phase × reset contract.

## Reproduction

Clean detached worktree: `/tmp/nmaforge_r93_clean_d66431b`, at exact SHA above, clean before and after the run. Tool versions: Synopsys VCS `V-2023.12-SP1_Full64`; URG `V-2023.12-SP1`.

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r93_clean_d66431b_3seed_final_20261030
```

The command exited **0** and printed `COMPUTE_CLUSTER_REAL_UVM_REGRESS_PASS` for all three seeds. The Make target now requires the real-top `21/21` marker. All three seeds report `mask=1fffff`, `max_active=7`, and `compute-request backpressure cycles=2694`.

| Seed | Pair overlap | Focused applicable compute group | Memory scoreboard | UVM severity |
|---:|---|---:|---|---|
| 20261025 | 21/21, mask `1fffff`, max active 7 | 100.0% | 26,451 words; 0 mismatch, unknown, stale response | 0/0/0 |
| 20261026 | 21/21, mask `1fffff`, max active 7 | 100.0% | 26,451 words; 0 mismatch, unknown, stale response | 0/0/0 |
| 20261027 | 21/21, mask `1fffff`, max active 7 | 100.0% | 26,451 words; 0 mismatch, unknown, stale response | 0/0/0 |

Per seed, the scoreboard records 21,238 writes, epoch 9, zero orphan responses, and no pending transactions at end of test. Golden images cover all seven operations and ordered completion payloads. The 100% number refers only to the existing applicable focused compute covergroup; it is not overall UVM/RTL coverage or requirement closure. The clean URG merge covers three tests; its aggregate code/assert/group percentage is not used as a functional sign-off metric.

## Evidence artifacts

Artifacts are outside Git at `/tmp/nmaforge_r93_clean_d66431b_3seed_final_20261030`:

| Artifact | SHA-256 |
|---|---|
| `compile.log` | `a96136680042a09d89d70810adc2d4b1aa818da43396326fb937d37248aeb380` |
| `seed_20261025/run.log` | `c2002dedfa272de8658cd7c7d17ff470f89ea254e3f9dc90e2e65c644083b502` |
| `seed_20261026/run.log` | `3a1215984ba79ff8df3ffd4c872e228725bb6a970649ad6ab7e93688dca2a03e` |
| `seed_20261027/run.log` | `ed68ebc85e218dfe8e88f5c6235c6cb88d85978faa7e33b6e14c109a6d932d1e` |
| `urg_merged.log` | `b03ad97a4e8a2e87ccab36a9bd01b88bd4a53c5080b2f80cf3cb4862d1878ee1` |

The compile log's Verdi KDB elaboration reports 0 errors and 0 warnings. Each simulation ends normally and reports `UVM_WARNING=0`, `UVM_ERROR=0`, `UVM_FATAL=0`.

## Requirement and remaining-scope disposition

`REQ-PC-001` remains **PASS-SCOPED** and now includes all real-top production engine pairs as well as the historical behavioral-dispatcher matrix. `REQ-PC-006/007` remain **PARTIAL**: this run does not exhaustively cross response ownership with every owner, shared bank, request backpressure, fault, Abort, and Reset phase. `CL-COV-004` is closed for the real-top all-pair overlap criterion only. The 38-row RTM remains 24 PASS-SCOPED / 14 PARTIAL; `OPEN-CL-003`, broader `CL-COV-002/006`, unsupported partial/zero WSTRB, and the existing descriptor/FSM/numeric scope gaps remain open. No Compute Cluster v1.0 sign-off is declared.
