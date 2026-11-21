# NMAForge Branch Reconciliation Checkpoint — 2026-11-21

## Checkpoint disposition

**READY_FOR_REVIEW; NO BRANCH DELETION OR TAGGING PERFORMED.** A non-destructive integration branch combines the current GPT-2 and DeiT research tips. The branch is pushed and proposed in two review PRs. The repository's `main` and all existing worktrees remain untouched. The next destructive cleanup stage is intentionally pending user review of this checkpoint.

## Snapshot and scope

- Repository: `cwu766485-ctrl/NMAForge`
- Actual remote branch heads: **73**, measured with `git ls-remote --heads origin` on 2026-11-21. The task attachment is an older Round 30 inventory showing 71; it is stale. Symbolic `origin/HEAD` is not a branch head.
- Current research tips used: GPT-2 `f7d15974fc654e58e4e48dce1b8f4c87171e67c8`; DeiT `d9ef7112efb4ffdada75768f07c1f82d09f9200b`.
- Integration branch: `integration/branch-cleanup-20261121`
- Integration merge commit: `40237a296bb9341eb4254ffc1ac7f59254272d4b`
- Main: `3041355528dffe856e2d5384027c6ee5df5d1b42`, unchanged. It is an ancestor of the current Round 31 GPT-2 tip.
- The requested `00_通用规则_先读.md` and repository `BRANCH_RECONCILIATION.md` were not present in the available attachment/repository context. The user-provided task text and repository `AGENTS.md` were used as the applicable rules.

Only remote branch inventory was in scope for reconciliation. Local-only branches/worktrees were preserved: `feature/npu-architecture-v2` (`a3553ee0f11040104c92df79fac05ca31678b0ef`) and `feat/nmaforge-rtl-finalize` (`f2bed3dd7386b1b9cc79c20bb065d06354b1beca`) have no matching remote heads. The existing root worktree is on `feat/shape-adaptive-gemv-v2`; no local worktree was switched or deleted. A stale/prunable worktree entry was also left untouched.

## Integration audit

- The Round 30 branch names in the attachment still exist remotely, but Round 31 tips are newer. Integration was therefore based on Round 31 rather than an outdated snapshot.
- The integration commit has GPT-2 R31 and DeiT R31 as its two parents. The sole add/add conflict was `docs/research/NMAFORGE_V1_2_ROUND21_DV_PREPARATION.md`: the GPT-2 version was retained and the DeiT version preserved as `NMAFORGE_V1_2_ROUND21_DV_PREPARATION.md.from-round31-deit.md`.
- The 7 product RTL files introduced by the DeiT line are byte-identical to DeiT R31. There are no further RTL changes between the integration branch and DeiT R31. Relative to GPT-2 R31, the integrated RTL additions are:
  - `rtl/compute/sfu/ai_tensor_sfu_core.v`
  - `rtl/control/descriptor/ai_accel_opcode_decode.v`
  - `rtl/control/descriptor/ai_desc_fetch.v`
  - `rtl/control/descriptor/ai_descriptor_validator.v`
  - `rtl/control/descriptor/axi_desc_fetch.v`
  - `rtl/control/queue/ai_parallel_compute_dispatcher.v`
  - `rtl/top/fabric/compute/ai_accel_compute_cluster.v`
- `dv/subsystem/top_smoke/sim/Makefile` was checked: `ai_h64_kv_attention_top` has one recipe, and `ai_deit_patch_projection_top` is defined once. Merged JSON/CSV artifacts parsed successfully.
- No `CIMFORGE_*` compatibility prefix was changed. No private PDK/library/license material was added.

## Verification performed

| Check | Result | Evidence |
|---|---|---|
| Python syntax (`sw/tools/*.py`, `tools/*.py`) | PASS | Python 3.12.13; command recorded below |
| JSON/CSV artifact parsing | PASS | 57 files parsed, 0 errors |
| DeiT smoke Make dry-run | PASS | `make -C dv/subsystem/top_smoke/sim -n ai_deit_patch_projection_top` |
| `git diff --check` | PASS | Integration diff against Round 31 GPT-2 base |
| `make -C dv/subsystem/top_smoke/sim ai_smoke` | BLOCKED_ENV | Mapper precheck passed; VCS `V-2023.12-SP1_Full64` exited before compile with “Cannot connect to the license server”; Make exit 255. Log: `/tmp/nmaforge-branch-cleanup-20261121-validation/ai_smoke.log` |
| UVM compile/smoke | NOT_RUN | Same VCS license connectivity blocker; no UVM PASS claimed |
| Verilator/Icarus RTL lint | NOT_RUN | Neither executable is available in this environment |

Python command:

```bash
git ls-files -z 'sw/tools/*.py' 'tools/*.py' | xargs -0 -r env PYTHONPYCACHEPREFIX=/tmp/nmaforge-branch-cleanup-20261121-validation/pycache /usr/bin/python3.12 -m py_compile
```

The failed VCS command was run once in the bounded attempt; this checkpoint does not treat a mapper precheck as a simulation pass. GPT-2 R31 and DeiT R31 model reports remain **PARTIAL**: GPT-2 candidate quality is below Bigram and its new candidate Top run is license-blocked; DeiT has historical continuous Attention evidence, but no continuous Round 31 Encoder Layer 0 run.

## B/C inventory

The attachment's B/C inventory contains 53 branches (B=40, C=13). Of B, 39 tips are ancestry-contained in this prospective integration history. `feat/shape-adaptive-gemv-v2` is not contained here (9 unique commits vs GPT-2 R31) and remains a review/dependency item. The 13 C tips are not ancestry-contained; their content classifications in the machine-readable inventory are not a deletion authorization. **No B/C tags or deletions have been performed.** Recheck ancestry after review PRs are merged before cleanup.

## D-group checkpoint review

The canonical machine-readable audit is [`BRANCH_RECONCILIATION_D_GROUP_2026-11-21.json`](BRANCH_RECONCILIATION_D_GROUP_2026-11-21.json). For every D branch it records the full unique commit SHA/subject list relative to GPT-2 R31 and the complete changed-path list under `rtl`, `dv`, `sw`, and `tools`, with per-path relation to the baseline. The table below summarizes the 15 audited branches.

| Branch | Tip | Unique commits | Changed paths | RTL paths | Disposition | Review note |
|---|---|---:|---:|---:|---|---|
| `feat/output-dma-gate1` | `7102485eb966` | 13 | 35 | 2 | 研究存档 | 其产品 RTL 与当前 GPT-2 R31 基线相同；独有内容是旧架构 benchmark/研究脚本。 |
| `feat/arch-opt-gate0` | `c8457126ddd4` | 5 | 21 | 1 | 研究存档 | 属于 output-dma/architecture optimization 研究线，产品 RTL 内容已被当前基线覆盖。 |
| `feat/arch-opt-m1` | `d8883ed29723` | 8 | 22 | 1 | 研究存档 | 属于 output-dma/architecture optimization 研究线，产品 RTL 内容已被当前基线覆盖。 |
| `feat/arch-opt-round2-dispatch` | `56adb1245ecd` | 10 | 27 | 1 | 研究存档 | 属于 output-dma/architecture optimization 研究线，产品 RTL 内容已被当前基线覆盖。 |
| `feat/final-arch-ab-system` | `14c3f8a9adbb` | 11 | 30 | 1 | 研究存档 | 属于 output-dma/architecture optimization 研究线，产品 RTL 内容已被当前基线覆盖。 |
| `feat/phase3-throughput` | `48345af9c5a4` | 1 | 6 | 0 | 研究存档 | 属于 output-dma/architecture optimization 研究线，产品 RTL 内容已被当前基线覆盖。 |
| `feat/phase4-cnn-writeback` | `b1dd75b8d1b6` | 3 | 19 | 1 | 研究存档 | 属于 output-dma/architecture optimization 研究线，产品 RTL 内容已被当前基线覆盖。 |
| `task/architecture-final-endpoints` | `8ab859770940` | 12 | 29 | 1 | 研究存档 | 产品 RTL 与当前基线相同；独有差异集中在 benchmark/architecture endpoint 研究脚本。 |
| `research/phase0-1-memory-dataflow-2026-11-13` | `2c0d7d14c772` | 4 | 4 | 0 | 研究存档 | 仅有 memory/dataflow 研究脚本，没有产品 RTL 缺口。 |
| `feature/m3-phase-abort-test-contract` | `e6c86374b376` | 16 | 11 | 1 | 建议取回 | Matrix Core 文件仍不同；独有 directed test 覆盖最终输出提交前的 abort 边界。 |
| `codex/r158-frozen-replay-archive` | `0a0d68ebb1c5` | 61 | 10 | 1 | 建议取回 | 旧 SPAD Arbiter RTL 与当前实现不同，分支含 banked round-robin/fairness 回归材料。 |
| `feat/compute-cluster-closeout-audit` | `f7bf57309a62` | 125 | 21 | 1 | 建议取回 | 旧 SPAD Arbiter RTL 与当前实现不同，分支含较新 compute-cluster mutation/公平性审计材料。 |
| `research/bank-parallel-fault-precise-v1` | `e19cb86d9f89` | 6 | 16 | 6 | 研究存档 | Round 5 明确决定 REJECT_FOR_PRODUCT；其价值是未来故障因果研究，不是产品必需功能。 |
| `feature/axi-vip-integration` | `572cd3aa3679` | 22 | 19 | 0 | 建议取回 | 当前 GPT-2 R31 没有其 DMA AXI VIP UVM 集成和 AXI-Lite CSR 时序测试。 |
| `feature/m2-dma-coverage-closure` | `951b4e05c048` | 1 | 3 | 0 | 建议取回 | 当前 GPT-2 R31 不含这组 DMA block 错误覆盖率测试。 |

Classification totals: **10 research archives**, **5 recommended for selective retrieval**. “Recommended” means review only; it does not authorize whole-branch merge. The Matrix abort and older arbiter code are not proposed for direct RTL merge. DMA VIP/error-coverage candidates need focused review and a runnable VCS result before any narrow follow-up PR. The BPF-TE branch's own product decision is `REJECT_FOR_PRODUCT`; preserve it as research evidence only.

## Review PRs and next checkpoint

The integration branch has been pushed without force. GitHub confirms both review PRs are open and unmerged (the API reported them mergeable when checked):

1. [PR #11](https://github.com/cwu766485-ctrl/NMAForge/pull/11): `integration/branch-cleanup-20261121` → `research/nmaforge-v1.2-round31-gpt2` (`22` commits; `314` changed files). Review this focused research-line integration first.
2. [PR #12](https://github.com/cwu766485-ctrl/NMAForge/pull/12): `integration/branch-cleanup-20261121` → `main` (`331` commits; `3,478` changed files; `4,929,305` insertions and `1,255` deletions). This is the accumulated history relative to the older `main` baseline and needs broader review.

Both PRs point at head `49c07cdd553bae07ae795328b36d18c32b1563bc`. Neither PR was merged. No archive tags were created and no remote/local branches were deleted. The later cleanup stage should wait for review and user direction on the 5 D-group selective-retrieval candidates, the B/C archive set, and the unpushed local branches noted above. This report makes no claim of full GPT-2/DeiT model closure or VCS regression PASS.
