# Compute Cluster v1.0 Final Audit

**Review date:** 2026-10-29  
**Selected product/SPEC candidate:** `9d9e0f01e374a7c3a6c33778a3ce20a1d28132c9`  
**Evidence review branch:** `work/phase1-dv-signoff-20261029`  
**Current documentation HEAD:** `d2123ed112f90e43bce96c12e86d2ec967e407f4`  
**Decision:** bounded CL-RC1/CL-RC2 review candidate; **CL-DV-v1.0 is not signed**.

## Executive disposition

The selected candidate has substantial reproducible evidence for Matrix/SPAD and seven-engine Compute Cluster behavior. The inherited Execution RTM accounts for all 38 requirements (`REQ-CL-001..028`, `REQ-PC-001..010`): **24 PASS-SCOPED and 14 PARTIAL**, with no recorded FAIL, BLOCKED_SPEC, or NOT_RUN requirement. PASS-SCOPED means the named scenario passed; it is not full requirement closure.

The complete requirement-by-requirement execution table already lives in the [Compute Cluster Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md). It records, for every requirement, its disposition, testcase/checker or oracle, covered behavior, Run ID, seed, and evidence path. The RTM's [run/evidence index](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md#run-and-evidence-index) maps those runs to source-SHA relationship, tool version, and result. The [clean-candidate replay manifest](COMPUTE_CLUSTER_FINAL_9D9E0F_MANIFEST_2026-10-28.md) provides exact commands and selected artifact hashes. Historical runs whose manifest does not identify an exact source SHA remain historical/source-equivalent evidence; they are not silently upgraded to exact-candidate replay.

The **100%** result is limited to the focused top-compute functional testpoint group reproduced by R35 on three clean seeds (`20261025/26/27`): 29/29 applicable URG variables, with the completion-read bin explicitly excluded as structural N/A and checked to remain zero. It does not mean 100% requirement, DUT code, or complete Compute Cluster coverage. The Matrix default prefetch-enabled FSM remains 49/53 raw transitions; selected guard paths have formal disposition and one edge is exercised in the separate prefetch-disabled profile.

## Version and evidence integrity

- Product/SPEC review candidate is `9d9e0f01e374a7c3a6c33778a3ce20a1d28132c9`; the clean detached checkout and tool runs are indexed in R24–R33. Product RTL is not changed by this audit document.
- R33 ran from clean test commit `cb9717eb853dc507f4a7e4d188c7bd840160c955`, with product RTL/SPEC byte-identical to the selected candidate. Each of its three seeds passed with UVM severity `0/0/0`, 5,094 accepted writes, 5,368 checked words, and zero mismatch/unknown/stale/orphan response.
- R34 (`CLUSTER-COV100-REPLAY-20261029`) was an environment-blocked attempt before VCS license recovery; it produced no simulation or coverage result. R35 (`CLUSTER-COV100-LICENSE-REPLAY-20261029`) reran the exact clean test commit `cb9717e` on seeds `20261025/26/27` after license recovery. All three runs passed, focused applicable compute coverage was 100.0%, and each memory scoreboard checked 5,368 words with zero mismatch/unknown/stale/orphan. Product RTL/SPEC are byte-identical to the selected candidate. R35 supersedes R34 for replay status, not for requirement dispositions.
- VCS/URG version for R33 is `V-2023.12-SP1_Full64`; Matrix formal uses VC Formal `V-2023.12-SP2`. R33's compile has no `Warning-`, `Error-`, or `[TFIPC]` diagnostic. The separate top-smoke fixture retains one `[LOOP-REROLL-ENABLED]` warning, documented in the RTM.

## Checker and coverage review

| Area | Evidence | Audit disposition |
|---|---|---|
| Independent memory/result checks | R25/R32/R35 real-top scoreboard and selected per-engine Golden checks; R35 has zero mismatch/unknown/stale/orphan responses | Pass for the named workloads and memory transactions; opcode/shape/fault space remains partial |
| Mutation sensitivity | R26: 25/25 expected catches for address, data, owner, WSTRB and Done/missing/duplicate-Done observation mutations | Pass for checker sensitivity only; this is not DUT fault injection or an RTL mutation score |
| SVA connectivity/non-vacuity | R32 has 17/22 top assertion properties with real successes and no failures/incomplete; R15 supplies real AXI AR/AW/W successes and stall-to-accept hits; compute activity properties are active | No disconnected compute activity ports found in the reviewed clean compile. Unattempted RAL and sequence-specific AXI properties remain scoped dispositions, not passes |
| Functional testpoint coverage | R35: 29/29 applicable variables, 5/5 applicable response-client bins on each of three seeds | 100% only for this focused group; the structural completion-read bin remains excluded/N/A |
| Matrix FSM | R28: 5/5 non-vacuous legal properties proven; `ST_PREFETCH_WAIT` and `ST_ERROR_DRAIN` reachability covers hit; raw default-profile FSM 49/53 | Selected guards dispositioned; no forced states and no 100% FSM claim |
| Whole-top code coverage | Existing URG databases include DUT, checker, UVM and testbench code | Not presented as DUT-only or functional closure |

## Remaining closure items

| ID | Affected scope | Remaining evidence or contract |
|---|---|---|
| `OPEN-CL-003` | REQ-CL-018, REQ-PC-009/010 | Qualify coordinated reset/epoch behavior against the selected external AXI fabric, or attach its approved compliance evidence. Current reset evidence uses a behavioral responder. |
| `OPEN-CL-002` | REQ-CL-002/015/020/024/025 | Freeze remaining legal descriptor ranges, aliases/overflow, strides and zero-value rules, then cover their boundaries. |
| `OPEN-CL-004` | REQ-CL-010/022, REQ-PC-007 | Approve Matrix Line alignment, partial/zero WSTRB, protection and partial-commit semantics before adding legal tests. Existing observed masks are full; no unsupported behavior is inferred. |
| `OPEN-NUM-01` | REQ-CL-020 | Freeze scalar INT8 rounding/saturation boundary rules and run the independent edge-vector campaign. |
| `CL-COV-006` | REQ-CL-017/019/027, REQ-PC-006/007/009/010 | Expand legal Engine × Fault × Phase × Reset coverage with completion-code and accepted-write-prefix checkers. The current selected cases do not close the full cross. |
| `CL-COV-004` | REQ-PC-001/006/007 | The 21/21 pair test uses the real dispatcher but behavioral engine agents. Production top pair coverage remains selected, not all real-engine pairs. |
| `CL-COV-002/003` | Dataflow, opcode/shape and protocol coverage | Matrix line-write stall remains unobserved at top; broader legal request/backpressure and opcode × shape × numeric boundaries remain partial. |

The full owner-by-owner issue log is in [Compute Cluster Open Issues](COMPUTE_CLUSTER_OPEN_ISSUES_2026-10-27.md). No FSM state forcing or unsupported fault combinations are accepted as closure evidence.

## Final review outcome

- **CL-RC1 (bounded Matrix + SPAD review):** ready for review with explicit WSTRB and broader legal fault-cross limitations.
- **CL-RC2 (bounded seven-engine review):** ready for evidence review; the RTM remains 24 PASS-SCOPED / 14 PARTIAL.
- **CL-DV-v1.0:** **HOLD / not signed** until the defined P0/P1 gaps above are resolved or formally dispositioned by the project reviewers.
- **Whole NPU sign-off, pretrained-model deployment and ASIC PPA:** not established by this audit.

## Related records

- [Complete Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md)
- [Clean candidate replay manifest](COMPUTE_CLUSTER_FINAL_9D9E0F_MANIFEST_2026-10-28.md)
- [Sign-off readiness report](COMPUTE_CLUSTER_DV_SIGNOFF_READINESS_2026-10-27.md)
- [Open issue list](COMPUTE_CLUSTER_OPEN_ISSUES_2026-10-27.md)
- [Matrix/TinyNPU historical benchmark report](COMPUTE_CLUSTER_TINYNPU_BENCHMARK_2026-10-27.md)
