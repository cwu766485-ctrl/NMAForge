# NMAForge documentation

[中文文档索引](README_ZH.md) · [Repository README](../README.md)

The public documentation describes the current all-digital near-memory tensor
accelerator. It deliberately excludes licensed PDK collateral, vendor board
files, credentials, generated reports and personal environment instructions.

| Document | Purpose |
|---|---|
| [SPEC.md](spec/SPEC.md) / [SPEC_ZH.md](spec/SPEC_ZH.md) | English/Chinese A10, ABI v7.4 specification: interfaces, queues, DMA, operators and boundaries. |
| [ARCHITECTURE.md](architecture/ARCHITECTURE.md) | Module ownership, control/data flow and digital CNM datapath. |
| [Literature_Review.md](architecture/Literature_Review.md) | Literature-derived ideas, implementation candidates and evidence gates. |
| [RTL_GUIDE.md](RTL_GUIDE.md) | Learning-oriented guide to the RTL hierarchy, transaction boundaries and safe refactoring rules. |
| [VPLAN.md](verification/VPLAN.md) | Verification plan, evidence and remaining closure gates. |
| [A10_DV_RTM.md](verification/A10_DV_RTM.md) | A10 requirement-to-test/checker/coverage/evidence traceability matrix. |
| [A10_DV_BASELINE_2026-10-14.md](verification/A10_DV_BASELINE_2026-10-14.md) | Fixed-commit baseline run results and current tool blockers. |
| [A10_DV_RUN_2026-10-15.md](verification/A10_DV_RUN_2026-10-15.md) | Latest A10 current-worktree VCS/UVM reruns, seeds, URG evidence and remaining closure limits. |
| [A10_BUG_REGISTER.md](verification/A10_BUG_REGISTER.md) | Confirmed A10 RTL/verification-flow defects, root causes, fixes, and evidence gaps. |
| [TSMC28_SYNTHESIS_REPORT.md](verification/TSMC28_SYNTHESIS_REPORT.md) | Sanitized commercial-28-nm pre-layout synthesis evidence and its limits. |
| [XCZU15EG_BRINGUP.md](verification/XCZU15EG_BRINGUP.md) | Board-owner bring-up procedure; vendor collateral is intentionally external. |
| [CNM_EVALUATION_ZH.md](architecture/CNM_EVALUATION_ZH.md) | Chinese CNM architecture evolution, benchmark and research boundaries. |
| [CNM_EVALUATION.md](architecture/CNM_EVALUATION.md) | Public benchmark/evaluation summary and limitations. |
| [PROJECT_EXPERIENCE_ZH.md](architecture/PROJECT_EXPERIENCE_ZH.md) | Evidence-bounded project experience summary. |
| [PUBLIC_RELEASE.md](PUBLIC_RELEASE.md) | What may be published and the safe GitHub-release workflow. |

| [NAMING_COMPATIBILITY.md](spec/NAMING_COMPATIBILITY.md) | Public NMAForge naming and the retained ABI compatibility identifiers. |
## Documentation rules

- Change the specification and ABI header before changing an ABI-visible RTL
  contract.
- Record only tool runs that actually occurred, including PVT/constraints and
  whether a result is pre-layout, post-route or board-measured.
- Keep documents focused: long-lived architecture/evidence belongs in the
  documents above; private change logs, chat exports and tool caches do not
  belong in Git.
- The supported public project name is **NMAForge**. Historical `CIMFORGE_*`
  ABI identifiers are retained only for source compatibility.
