# Compute Cluster v1.0 Final Audit

**Review date:** 2026-10-29  
**Selected product/SPEC candidate:** `6848a414eaeaa05cf9e1411cf55d9d27333208a6`
- **Follow-up evidence branch:** `feat/shape-adaptive-gemv-v2`
- **Follow-up evidence replay SHA:** `6848a414eaeaa05cf9e1411cf55d9d27333208a6`
**Decision:** bounded CL-RC1/CL-RC2 review candidate; **CL-DV-v1.0 is not signed**.

## Executive disposition

The selected candidate has substantial reproducible evidence for Matrix/SPAD and seven-engine Compute Cluster behavior. The inherited Execution RTM accounts for all 38 requirements (`REQ-CL-001..028`, `REQ-PC-001..010`): **24 PASS-SCOPED and 14 PARTIAL**, with no recorded FAIL, BLOCKED_SPEC, or NOT_RUN requirement. PASS-SCOPED means the named scenario passed; it is not full requirement closure.

The complete requirement-by-requirement execution table lives in the [Compute Cluster Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md). It records each requirement's disposition, testcase/checker or oracle, covered behavior, Run ID, seed, and evidence path. The RTM run/evidence index records source-SHA relationship, tool version, and result; R40–R45 replay the selected candidate SHA from a clean worktree. The [9d9e0f replay manifest](COMPUTE_CLUSTER_FINAL_9D9E0F_MANIFEST_2026-10-28.md) is retained as historical evidence for that earlier candidate. Runs without an exact source identity remain historical/source-equivalent and are not silently upgraded to exact-candidate replay.

The **100%** result is limited to the focused top-compute functional testpoint group reproduced by R40 on six clean seeds (`20261025/26/27/29/30/31`): 29/29 applicable URG variables, with the completion-read bin explicitly excluded as structural N/A and checked to remain zero. It does not mean 100% requirement, DUT code, or complete Compute Cluster coverage. The Matrix default prefetch-enabled FSM remains 49/53 raw transitions; selected guard paths have formal disposition and one edge is exercised in the separate prefetch-disabled profile.

## Version and evidence integrity

- Product/SPEC review candidate is `6848a414eaeaa05cf9e1411cf55d9d27333208a6`; the clean detached checkout and tool runs are indexed in R40–R45. The candidate includes the one-line descriptor-validator fix that only applies `PACK_I8_TILE_A` validation to `REQUANT_I8`, preserving ignored flags on VDOT per SPEC.
- R33/R35 are historical replays of the earlier `9d9e0f0` candidate, before the current descriptor-validator correction. They passed their recorded three seeds, but are not byte-identical to the selected `6848a41` source. R40 is the exact six-seed clean replay for the selected source and supersedes them for current-candidate reproducibility.
- R34 (`CLUSTER-COV100-REPLAY-20261029`) was an environment-blocked attempt before VCS license recovery; it produced no simulation or coverage result. R35 (`CLUSTER-COV100-LICENSE-REPLAY-20261029`) supersedes R34 only for the earlier candidate's replay status, not for current-candidate evidence or requirement dispositions.
- VCS/URG version for R33 is `V-2023.12-SP1_Full64`; Matrix formal uses VC Formal `V-2023.12-SP2`. R33's compile has no `Warning-`, `Error-`, or `[TFIPC]` diagnostic. The separate top-smoke fixture retains one `[LOOP-REROLL-ENABLED]` warning, documented in the RTM.
- A first clean replay at `9688429` exposed that the newly assigned `PACK_I8_TILE_A` bit was being rejected on unrelated VDOT descriptors. The validator was corrected according to SPEC and committed as candidate `6848a41`; six-seed R40 then passed, including the failing seed, and R44/R45 passed the top smoke and full Digits inference. R41 caught 25/25 checker mutations; R42/R43 provide Matrix and normalized TinyNPU benchmarks on the same source SHA.

## Checker and coverage review

| Area | Evidence | Audit disposition |
|---|---|---|
| Independent memory/result checks | R25/R32/R35/R36/R40 real-top scoreboard and selected per-engine Golden checks; R40 has zero mismatch/unknown/stale/orphan responses on six seeds | Pass for the named workloads and memory transactions; opcode/shape/fault space remains partial |
| Mutation sensitivity | R26/R37/R41: 25/25 expected catches for address, data, owner, WSTRB and Done/missing/duplicate-Done observation mutations | Pass for checker sensitivity only; this is not DUT fault injection or an RTL mutation score |
| SVA connectivity/non-vacuity | R32 has 17/22 top assertion properties with real successes and no failures/incomplete; R15 supplies real AXI AR/AW/W successes and stall-to-accept hits; compute activity properties are active | No disconnected compute activity ports found in the reviewed clean compile. Unattempted RAL and sequence-specific AXI properties remain scoped dispositions, not passes |
| Functional testpoint coverage | R35/R36/R40: 29/29 applicable variables, 5/5 applicable response-client bins on each of six R40 seeds | 100% only for this focused group; the structural completion-read bin remains excluded/N/A |
| Matrix FSM | R28: 5/5 non-vacuous legal properties proven; `ST_PREFETCH_WAIT` and `ST_ERROR_DRAIN` reachability covers hit; raw default-profile FSM 49/53 | Selected guards dispositioned; no forced states and no 100% FSM claim |
| Whole-top code coverage | Existing URG databases include DUT, checker, UVM and testbench code | Not presented as DUT-only or functional closure |

R36's compute-only AXI SVA observations show 0 matches for AR/AW stall-to-accept and one W match. This sequence does not exercise those AXI request stalls; R15 remains the evidence for real AR/AW/W assertion successes. `OPEN-CL-004`, `CL-COV-006`, external-fabric qualification, and the 24 PASS-SCOPED / 14 PARTIAL disposition remain unchanged.

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
