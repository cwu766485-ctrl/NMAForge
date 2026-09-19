# Hardware repository discovery and migration mapping

## Inspect without mutating

Prefer bounded searches that exclude large output and VCS directories. Useful indicators include:

- instructions: `AGENTS.md`, `README*`, `CONTRIBUTING*`, CI definitions;
- flow configs: `eda.yaml`, `Makefile`, `CMakeLists.txt`, `*.mk`, `*.tcl`, `*.do`, `*.f`, `*.flist`, FuseSoC core files, Bazel/Meson configs;
- design: `*.v`, `*.sv`, `*.svh`, `*.vhd`, `*.vhdl`, `*.bsv`, `*.chisel`, `*.scala`, `*.fir`, `*.lib`;
- verification: UVM packages, tests, sequences, assertions, properties, scoreboards, reference models, cocotb/pytest, coverage and waiver files;
- implementation/signoff: SDC, UPF/CPF, synthesis/APR/STA/power/DFT scripts and reports;
- generated/config sources: IP-XACT, RDL, YAML/JSON/TOML manifests, register generators, templates;
- dependencies: submodules, symlinks, environment modules, containers, license variables, PDK/library references.

Inspect text references to candidate paths before moving them. Account for references assembled dynamically in Tcl, Make, Python, shell, YAML, and environment variables.

## Classify every area

Assign both a role and a handling policy:

| Role | Examples | Default handling |
|---|---|---|
| Authoritative source | RTL, properties, specs, constraints | Hash, preserve, validate |
| Generator input | RDL, templates, configs | Treat as source of truth |
| Generated source | reg RTL, wrappers, netlists | Preserve provenance; regenerate when possible |
| Verification source | TB, UVM, tests, models | Preserve hierarchy and discovery rules |
| Tool/flow source | Tcl, Make, Python, manifests | Preserve CLI and environment behavior |
| Run artifact | logs, waves, coverage DBs, reports | Retain per existing policy; avoid migration noise |
| Third-party/vendor | IP, VIP, PDK, libraries | Do not modify; retain licensing boundary |
| Secret/sensitive | keys, credentials, licensed data | Do not expose, copy, or commit |

## Migration ledger

Before a physical move, record one row per artifact or dependency-closed group:

| Original path | Role/canonical status | Proposed action/path | Known consumers | Required updates | Validation | Result |
|---|---|---|---|---|---|---|

For a user-requested physical reorganization, use only `move`, `retain_protected`, or `compatibility_shim`; see [physical-migration.md](physical-migration.md). `retain/index` is valid only for onboarding-only work, not as a substitute for a requested directory migration.

## Baseline and equivalence matrix

Select checks from evidence already present in the project:

| Layer | Typical evidence |
|---|---|
| Content | Snapshot has no unexplained missing/changed source hashes |
| Resolution | File lists/includes/libraries resolve; generators locate inputs |
| Compile/elaborate | Same tops/configurations compile and elaborate |
| Behavior | Existing smoke/regression tests preserve pass/fail signature |
| Properties | Formal/lint/CDC results preserve status or explain deltas |
| Implementation | Synthesis/STA/APR checks appropriate to changed constraints/paths |
| Operations | CI and canonical local commands still work; logs land predictably |

Do not require every layer for a documentation-only overlay. Do require checks proportionate to every physically migrated functional dependency.
