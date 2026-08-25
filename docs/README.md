# NMAForge documentation

[中文文档索引](README_ZH.md) · [Repository README](../README.md)

The public documentation describes the current all-digital near-memory tensor
accelerator. It deliberately excludes licensed PDK collateral, vendor board
files, credentials, generated reports and personal environment instructions.

| Document | Purpose |
|---|---|
| [SPEC.md](SPEC.md) / [SPEC_ZH.md](SPEC_ZH.md) | English/Chinese ABI v7.2 specification: interfaces, queues, DMA, operators and boundaries. |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Module ownership, control/data flow and digital CNM datapath. |
| [VPLAN.md](VPLAN.md) | Verification plan, evidence and remaining closure gates. |
| [TSMC28_SYNTHESIS_REPORT.md](TSMC28_SYNTHESIS_REPORT.md) | Sanitized commercial-28-nm pre-layout synthesis evidence and its limits. |
| [XCZU15EG_BRINGUP.md](XCZU15EG_BRINGUP.md) | Board-owner bring-up procedure; vendor collateral is intentionally external. |
| [CNM_BANK_LOCAL_PE_RESEARCH_ZH.md](CNM_BANK_LOCAL_PE_RESEARCH_ZH.md) | Chinese design rationale for bank-local digital CNM. |
| [CNM_EVALUATION.md](CNM_EVALUATION.md) | Public benchmark/evaluation summary and limitations. |
| [PUBLIC_RELEASE.md](PUBLIC_RELEASE.md) | What may be published and the safe GitHub-release workflow. |

| [NAMING_COMPATIBILITY.md](NAMING_COMPATIBILITY.md) | Public NMAForge naming and the retained ABI compatibility identifiers. |
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
