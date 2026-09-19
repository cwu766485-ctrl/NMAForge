---
name: eda-tool-engineering
description: Reproducible Synopsys EDA flows for RTL simulation, debug, lint/CDC, formal, synthesis, DFT/ATPG (including MBIST/LBIST planning), APR, STA, power, and parasitic extraction. Use when a project contains eda.yaml or when Codex must inspect, plan, generate, or run one of these flows.
---

# Synopsys EDA engineering

This skill is a thin, project-independent API over the installed Synopsys tools. Project facts live in `eda.yaml` at the project root; this skill supplies validation, environment discovery, command construction, logs, and normalized results.

The primary quality target is VCS, Verdi, SpyGlass, Design Compiler, VC Formal, and Formality. Their adapters must produce reviewable commands/scripts and machine-readable reports before adding more products.

## Project contract

Look for `<project-root>/eda.yaml` first. Do not put project-specific paths in this skill. The contract and an example are in [references/project-eda-contract.md](references/project-eda-contract.md).

Required early fields are `name`, `top`, and `rtl`; add `filelists`, `defines`, `include_dirs`, `pdk`, `constraints`, and `dft` as the flow needs them. Paths are resolved relative to the project root.

## API

From a project root:

```bash
python3 "$HOME/.codex/skills/eda-tool-engineering/scripts/eda.py" init
python3 "$HOME/.codex/skills/eda-tool-engineering/scripts/eda.py" doctor
python3 "$HOME/.codex/skills/eda-tool-engineering/scripts/eda.py" report
python3 "$HOME/.codex/skills/eda-tool-engineering/scripts/eda.py" validate
python3 "$HOME/.codex/skills/eda-tool-engineering/scripts/eda.py" plan --flow sim
python3 "$HOME/.codex/skills/eda-tool-engineering/scripts/eda.py" run --flow synth --dry-run
```

For a new project, the Skill automatically runs the equivalent of `init` when no `./eda.yaml` exists. It derives a best-effort project name/top from the directory and RTL, and refuses to overwrite an existing file. You can also call `init` explicitly. Review the generated PDK, testbench, filelist, and constraints fields before running a flow.

`plan` and `run` never execute a tool unless `--execute` is supplied. Every run gets an isolated `runs/<timestamp>-<flow>/` directory, a command manifest, and environment snapshot. Use `--tool <name>` only for diagnosis; normal selection comes from the installed product homes in `.bashrc`.

`report` parses existing DFT reports without starting a tool. `validate` returns non-zero when parsed pre/post DFT reports contain violations. This makes an existing project such as `tsmc28_dft_smoke` a regression test for the API.

The API also discovers a configured RTL top while excluding common testbench names (`tb_*`, `test_*`, `testbench`). DFT→ATPG planning prefers explicit `scan_netlist`/`test_protocol` and otherwise selects the newest generated artifact. ATPG report parsing is best-effort and only reports metrics actually found in logs.

Supported flow names: `sim`, `debug`, `lint`, `cdc`, `formal`, `formality`, `synth`, `dft`, `atpg`, `mbist`, `lbist`, `apr`, `sta`, `power`, and `starrc`. Real command/script adapters are included for VCS, Verdi, SpyGlass, VC Formal, Formality, DC, and TestMAX. The DFT manager generates a DC scan-insertion script, TestMAX ATPG command files for stuck-at/transition, and explicit MBIST/LBIST integration templates; APR/STA/power/StarRC remain next-stage adapters.

## Golden regression: tsmc28_dft_smoke

This project is a small scan/ATPG regression, not a real MBIST design: its reports show 25 valid scan cells, one chain of length 25, and zero pre/post-DFT violations; it has no memory macro. Run `report`/`validate` to test report parsing, and `plan --flow dft|atpg|mbist|lbist` to test script generation. Only run with `--execute` after confirming the PDK/library and license setup.

## DFT boundary

The DFT manager API is intentionally separate from a single executable. It models scan insertion, compression, test points, IJTAG/IEEE-1687, MBIST, LBIST, ATPG, fault simulation, pattern export, and post-DFT checks. On this host the initial adapters target TestMAX `dft_shell`/`tmax`; MBIST/LBIST commands are emitted as explicit integration points because their availability and license names vary by TestMAX release and delivered memory/BIST IP. Never claim MBIST/LBIST insertion succeeded without a tool log and generated netlist/report.

## Safety and reproducibility

- Confirm the resolved project root and config before execution.
- Prefer `--dry-run`; require `--execute` for state-changing tool runs.
- Keep generated files below `runs/`; do not overwrite RTL, PDK, or source constraints.
- Preserve tool version, command line, license variables, and exit status in the run manifest.
- Treat license failures and missing PDK/library files as actionable diagnostics, not as successful runs.
