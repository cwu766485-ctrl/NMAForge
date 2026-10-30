# Compute Cluster Coverage and Mutation Audit — R81 — 2026-10-30

## Disposition

R81 adds clean replay evidence at exact code/test SHA `e4c1e7a93a0afe1c89128996c6eaf9bff5caf907`. The product RTL and SPEC are unchanged from the preceding R80 candidate. Three real-top UVM seeds pass, the scoped applicable functional covergroup is 31/31 variables (100%), and all 28 checker-sensitivity mutations are detected by the named checker. A separate five-seed Top Smoke DUT code-coverage merge is also recorded.

This is not complete requirement closure. The Execution RTM remains **24 PASS-SCOPED / 14 PARTIAL**, `CL-DV-v1.0` remains **HOLD**, and no requirement status is promoted by this replay.

## Source and tools

| Item | Value |
|---|---|
| Exact code/test SHA | `e4c1e7a93a0afe1c89128996c6eaf9bff5caf907` |
| Repository review HEAD before this report | `825ae6d30f49bd639affb98982162c8911fa9827` (documentation-only descendant) |
| Clean replay worktree | `/tmp/nmaforge_r80_clean_e4c1e7a` |
| Tool | Synopsys VCS/URG `V-2023.12-SP1_Full64` |
| Product RTL/SPEC changes | None in this replay |

## Real-top seven-engine UVM

Command:

```sh
VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r80_uvm_e4c1e7a \
COMPUTE_CLUSTER_UVM_SEEDS='20261021 20261022 20261023' \
make -C dv/uvm/sim uvm_compute_cluster_regress
```

All three seeds pass `COMPUTE_CLUSTER_REAL_UVM_REGRESS_PASS`. Each seed checks the real seven-engine top and complete modeled SPAD image: 13,668 writes, 17,094 checked words, zero mismatch, unknown read, stale-epoch response, orphan response, and zero pending responses at end. The run records nine accepted reads dropped by the specified reset epoch. UVM warning/error/fatal counts are `0/0/0`.

| Seed | Run ID | Log SHA-256 |
|---:|---|---|
| 20261021 | `R81-CLUSTER-UVM-20261021-E4C1E7A` | `9e46a7ed870fc5e1d1c0470749b54c895b36af755444eb250f3371d4e115853f` |
| 20261022 | `R81-CLUSTER-UVM-20261022-E4C1E7A` | `0d25beee0364587240fa42e6b721c98dc68f045aed3716fa4e2e150b2f498e6b` |
| 20261023 | `R81-CLUSTER-UVM-20261023-E4C1E7A` | `4ce2f795eaae99136d65e55734e30cdbf311285b0eeb4889848823c42b923e0a` |

The merged UVM functional group `ai_compute_cluster_coverage::cluster_cg` reports 31 expected, zero uncovered, and 31 covered variables (100%). Per-seed markers report `focused_compute_cg_applicable=100.0%`; the completion-read response remains architectural N/A and is observed at zero. This is coverage of the defined applicable group, not all bins implied by the 38 requirements.

The same UVM URG database reports 22 assertion properties: 17 with real successes, zero failure, zero incomplete, and two without attempts. Three top AXI AR/AW properties have attempts but no successful antecedent in this compute-oriented sequence; the two no-attempt properties are UVM RAL checks. They are not counted as successful coverage. Assertion evidence remains separately bounded by the dedicated AXI E2E runs.

## Checker-sensitivity mutation campaign

Command:

```sh
VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r80_mut_build_e4c1e7a \
COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r80_mut_e4c1e7a \
make -C dv/uvm/sim uvm_compute_cluster_mutation
```

All 28 isolated runs contain one directed observation mutation and a corresponding `[CLUSTER_MUTATION_CAUGHT]` marker from the specified checker:

| Injected observation mutation | Count | Checker |
|---|---:|---|
| Request address, response data, response owner, WSTRB | 4 | Matrix address, memory data, response owner, write mask |
| Completion error code, write after reported error, stale response epoch | 3 | Completion error, accepted-write prefix, response epoch |
| Done, missing Done, duplicate Done | 21 | Engine Done lifecycle; each mutation applied independently to each of seven engine status bits |
| **Total** | **28/28** | **All expected checker detections observed** |

Run logs and per-run VDBs are at `/tmp/nmaforge_r80_mut_e4c1e7a/`; the SHA-256 manifest for all 28 logs is `/tmp/nmaforge_r80_mut_e4c1e7a/SHA256SUMS.log` (SHA-256 `d360a59c2e2e046d392aaba24c1830a77d4b92709f8c52b4ef3c030be4ba0861`). The compile log is `/tmp/nmaforge_r80_mut_build_e4c1e7a/compile.log` (SHA-256 `6d945a2af685659f51f8f29b13941aec612cbd44fec4cd6e657ff3e160a7cb4d`). These are passive monitor/checker-sensitivity mutations, not DUT RTL fault injection and not an RTL mutation score.

## Five-seed DUT code coverage

Command:

```sh
PATH=/opt/Synopsys/vcs/V-2023.12-SP1/bin:$PATH \
VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
make -C dv/subsystem/top_smoke/sim ai_compute_cluster_cov \
  AI_CLUSTER_COV_RUN=/tmp/nmaforge_r80_cluster_cov_e4c1e7a \
  AI_CLUSTER_COV_SEEDS='20261021 20261022 20261023 20261024 20261025' \
  AI_RANDOM_CASES=20 AI_SEED=12345 \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

All five Top Smoke runs pass. The URG merged dashboard reports **line 86.38%, condition 72.92%, FSM 44.59%, branch 75.36%** for its configured top/hierarchy scope. Its overall code-coverage score is 55.85; this is raw DUT/testbench code coverage, not functional testpoint coverage or sign-off percentage. In this Top Smoke profile the Matrix core raw state FSM is 19/53 transitions; the separately reviewed Matrix enabled-profile campaign and R28 formal dispositions remain separate evidence and are not replaced by this number.

| Seed | Run ID | Log SHA-256 |
|---:|---|---|
| 20261021 | `R81-TOP-COV-20261021-E4C1E7A` | `1c3b886d9b5eaaf0beb57809bcab82bdbe6eb29952ba5f35c2e4fe24ccdd1843` |
| 20261022 | `R81-TOP-COV-20261022-E4C1E7A` | `b42a999deee18d279f0c8a1804fb04ab82ca1f7b4657d9c9e0e1ef639809c7bd` |
| 20261023 | `R81-TOP-COV-20261023-E4C1E7A` | `36b3d066e66a39569ff015d1746e8ff003371d0a3e6649c695d76876b521ad69` |
| 20261024 | `R81-TOP-COV-20261024-E4C1E7A` | `2b9ef9ba2dd8271cb96819e92b6d84f0b30769f8d827f7c3fd16abd235f62959` |
| 20261025 | `R81-TOP-COV-20261025-E4C1E7A` | `12fc28a546d1605fbef1066a860f0e49525dbc244ccdcc078d438f16f3256f1a` |

Coverage artifacts remain outside Git under `/tmp/nmaforge_r80_cluster_cov_e4c1e7a/`. The compile log SHA-256 is `516b23140e0f59033b6de42fa4d0831b0852cdbf218f66c9047e7daccf0db01b`; URG dashboard SHA-256 is `cd17fc0333976571d32664ff235168f2aec552b2cb48204fb70338ef1b98e9ef`.

## Remaining disposition

R81 improves reproducibility and makes code-coverage gaps visible; it does not close a new requirement. The governing open items remain actual target external-fabric reset/epoch qualification (`OPEN-CL-003`), broader legal engine × fault × phase × Abort/Reset crosses, real production-engine contention through memory and completion ownership, and other partial descriptor/opcode coverage. Keep all residual FSM transitions at their existing legal reachability/formal dispositions; do not add illegal state stimulus to inflate coverage. See the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md), [Sign-off Readiness](COMPUTE_CLUSTER_DV_SIGNOFF_READINESS_2026-10-27.md), and [Open Issues](COMPUTE_CLUSTER_OPEN_ISSUES_2026-10-27.md).
