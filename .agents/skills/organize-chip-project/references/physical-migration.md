# Physical AI-Native migration

Use this reference when the user requests that an existing project be reorganized, refactored, or migrated. In that mode, documentation-only onboarding is not sufficient: make the target directories the canonical physical homes while retaining behavior.

## Target layout and migration rule

```text
project/
├── AGENTS.md
├── docs/
│   ├── spec/
│   ├── architecture/
│   ├── verification/
│   ├── ai-native/
│   └── exec-plans/
│       ├── active/
│       │   ├── execution-frontier.md
│       │   └── physical-migration-map.json
│       └── completed/
├── rtl/
├── dv/
├── constraints/                  # only where applicable
├── fw/                           # only where applicable
├── config/                       # manifests/config not tool-bound to root
├── skills/                       # project-specific SOPs only
├── tools/
│   └── hw                        # stable dispatcher over existing canonical flow
└── runs/
```

| Legacy content | Canonical destination | Notes |
|---|---|---|
| `src/`, `design/`, handwritten HDL | `rtl/` | Preserve block hierarchy below `rtl/`; update all filelists/includes/manifests. |
| `test/`, `tb/`, `uvm/`, cocotb, properties | `dv/` | Use subtrees such as `dv/testbench`, `dv/uvm`, `dv/formal`, `dv/cocotb` only when present. |
| `doc/`, `docs-old/`, architecture docs | `docs/spec/`, `docs/architecture/`, `docs/verification/` | Classify by authority; do not rename a normative specification into an architectural note. |
| SDC/UPF/CPF and physical constraints | `constraints/` | Keep tool-required root paths only if moving would break a non-configurable external flow; document exception. |
| Tool scripts, wrappers, utility scripts | `tools/` | Retain an unavoidable root `Makefile`, `justfile`, `Bender.yml`, or CI manifest if its ecosystem requires the root location; make it delegate/reference canonical paths. |
| Tool-neutral variants/manifests | `config/` | Do not move a manifest a tool requires at root unless invocation is updated and validated. |
| Project-specific repeated SOP | `skills/<name>/` | Do not copy generic user-level skills. |
| Logs, waves, coverage DBs, reports | `runs/` or established output tree | Normally ignored; do not treat as source migration. |
| PDK, VIP, vendor IP, encrypted/licensed content | retain protected boundary | Do not edit/relicense/copy. Map and document it rather than forcing it into `rtl/` or `dv/`. |

## Mandatory migration map

Create `docs/exec-plans/active/physical-migration-map.json` before the first `git mv`:

```json
{
  "format": 1,
  "project_root": ".",
  "entries": [
    {
      "from": "src/core/top.sv",
      "to": "rtl/core/top.sv",
      "role": "rtl",
      "action": "move",
      "consumers": ["Bender.yml", "sim/rtl.f", ".github/workflows/sim.yml"],
      "validation": ["just compile vcs tb_top", "just run-batch vcs tb_top"],
      "status": "planned"
    },
    {
      "from": "vendor/secure_ip",
      "role": "vendor IP",
      "action": "retain_protected",
      "reason": "licensed external collateral",
      "status": "planned"
    }
  ]
}
```

Use `action: move` for every ordinary RTL, DV, and project documentation artifact. Use `retain_protected` only for generated/vendor/PDK/encrypted/licensed/external-tool boundaries, with a specific reason. Use `compatibility_shim` only when an external consumer is proven to require the old path; test the shim and record its removal condition.

## Execution order

1. Create before snapshot, discover existing commands, and run baseline smoke checks.
2. Write the migration map; group entries into dependency-closed slices.
3. Move documentation first, update internal links, and validate links/indexes.
4. Move RTL, packages, includes, generator inputs, and constraints as a closed slice; update manifests/filelists/include paths and compile/elaborate.
5. Move DV as a closed slice; update test discovery, configs, sequences, wave scripts, regressions, and CI; run targeted simulation.
6. Move tools/configuration where feasible; retain only root/tool-constrained entry files with explicit mapping.
7. Refresh `AGENTS.md`, the AI-native indexes, execution frontier, and migration-map statuses.
8. Run final snapshot comparison, map verification, and baseline regression/signoff-proportionate checks.

Do not leave a migrated source tree duplicated at both old and new paths. This creates two plausible truths and is a failed migration unless the old path is a documented, tested compatibility shim.

## Acceptance criteria

Call physical reorganization complete only when:

- applicable canonical paths (`rtl/`, `dv/`, `docs/{spec,architecture,verification}`) exist and contain the formerly legacy project content;
- every old path is absent after a `move`, or has an explicit protected/compatibility disposition;
- `verify_physical_migration.py` confirms every completed move retained identical source content;
- all references consumers are updated, and the appropriate original flow checks pass or retain their documented baseline failure;
- `AGENTS.md` and `docs/ai-native/` point to final canonical paths, not stale legacy paths.
