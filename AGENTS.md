# Project

NMAForge is a synthesizable AXI-Lite/AXI4 digital compute-near-memory AI
accelerator RTL prototype. The active product path is `rtl/top/ai_accel_top.v`
with a 4-bank scratchpad, DMA, command/completion queues, CNM, matrix, CNN,
SFU, KV-cache, and Transformer-style datapaths.

# Sources of Truth

- `docs/spec/SPEC_ZH.md` / `docs/spec/SPEC.md` — register ABI, descriptors, queues,
  opcodes, errors, and fixed-point contracts.
- `docs/architecture/ARCHITECTURE.md` — hierarchy, ownership, and dataflow.
- `dv/VERIFICATION_MATRIX.md` — block/subsystem verification scope and
  acceptance criteria.
- `docs/verification/VPLAN.md` — planned UVM, formal, LEC, DFT, and PPA closure work.
- `docs/verification/TSMC28_SYNTHESIS_REPORT.md` — pre-layout synthesis evidence and limits.
- `docs/verification/STATIC_ANALYSIS_REPORT.md` and `dv/spyglass/LINT_TRIAGE.md` — static
  analysis evidence, warnings, and license limitations.

# Important Paths

- `rtl/top/ai_accel_top.v` — only chip-IP integration top.
- `rtl/control/` — AXI-Lite, queues, descriptors, and command lifecycle.
- `rtl/dma/` — AXI4 DMA lifecycle, IDs, burst planning, and abort drain.
- `rtl/memory/` — scratchpad, protection, and the sole scheduler arbiter.
- `rtl/compute/` — `cnm/`, `matrix/`, `sfu/`, `cnn/`, `kv/`, `int8/`, and
  `pipeline/` compute subsystems.
- `dv/subsystem/top_smoke/sim/` — top-level VCS smoke and microbenchmarks.
- `dv/block/control/` and `dv/block/dma/` — block-level UVM environments.
- `dv/spyglass/` — SpyGlass project and lint/CDC/RDC entry script.
- `syn/` — Synopsys DC scripts; foundry libraries and SRAM macros stay outside
  the public repository.

# Before Work

1. Run `git status --short` and preserve unrelated user changes.
2. Read the applicable sections of `docs/spec/SPEC_ZH.md`, `docs/architecture/ARCHITECTURE.md`,
   and `dv/VERIFICATION_MATRIX.md`.
3. Inspect the relevant source list before moving or adding RTL.
4. Reproduce a failure with the existing command before editing its cause.

# Tool Entry Points

Run commands from the indicated directory in the Linux/VCS or EDA environment.

- Top smoke: `cd dv/subsystem/top_smoke/sim && make ai_smoke`
- Seeded top regression: `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345`
- Reference precheck: `make ai_precheck`
- CNM/matrix focused gates: `make ai_cnm_signoff`
- Control UVM: `cd dv/block/control/sim && make uvm_regress`
- DMA UVM: `cd dv/block/dma/sim && make uvm_regress`
- Shared top UVM bring-up: `cd dv/uvm/sim && make uvm_compile`;
  run only a named test after checking its current environment.
- SpyGlass: `cd dv/spyglass && ./run_spyglass_a8.sh {lint|cdc|rdc|all}`
- TSMC28 DC: configure private `TSMC28_STDCELL_DB`/SRAM variables and run
  `bash syn/run_ai_accel_28nm_dc.sh 4.0` from the repository root.

For RTL changes, run the focused target plus `make ai_smoke`; for queue, DMA,
scratchpad, top, or source-list changes, also run the seeded regression when
the EDA environment is available. Record exact commands and PASS evidence.

# Architecture Invariants

- `ai_spad_arbiter` is the only scheduler-side scratchpad admission point.
- Descriptor/completion traffic has control-plane priority; data-plane clients
  use the defined round-robin policy.
- `ai_command_processor` owns command lifecycle and queue-pointer advancement.
- Software publishes `CMDQ_TAIL` and consumes `CPLQ_HEAD`; hardware reports
  `CMDQ_HEAD` and `CPLQ_TAIL`.
- `ai_completion_writer` commits all four completion words before advancing the
  completion tail.
- Scratchpad reads are registered; AXI `valid/ready`, ID, LAST, back-pressure,
  reset, and abort behavior must remain protocol-correct.
- `+define+VCS` selects behavioral scratchpad RAM; normal Vivado uses XPM.

# Modification Policy

Allowed: synthesizable RTL, checked-in tests, source lists, scripts, and docs
within this repository when the SPEC and ownership rules are preserved.

Do not modify or commit without explicit scope/approval: PDK and foundry
libraries, SRAM macro/timing models, credentials, private server settings,
third-party assets, generated VCS/Vivado/SpyGlass/DC directories, waveforms,
coverage databases, and signoff reports copied from private environments.
When adding or moving RTL, update all applicable lists:
`dv/subsystem/top_smoke/sim/ai_accel.f`, `dv/uvm/sim/ai_accel_uvm.f`,
`dv/spyglass/a8_rtl.f`, and both FPGA `ai_accel_rtl.tcl` files.

# Debug and Review Policy

- Find the root cause; do not delete tests, assertions, scoreboards, lint
  rules, or expected checks to hide a failure.
- Check the SPEC before changing externally visible behavior.
- Treat lint warnings and missing SpyGlass advanced licenses as explicit
  disposition items, not automatic passes.
- Keep generated output out of commits and run `git diff --check` before handoff.

# Definition of Done

- The requested focused test passes with no new prohibited errors or warnings.
- Related smoke/regression checks pass when practical.
- Any RTL move/addition has synchronized source lists and documentation.
- Static-analysis, synthesis, or coverage claims include tool, constraints,
  environment, and whether they are pre-layout or signoff evidence.
- Update the relevant status/frontier note (`docs/project_update_log.md` or
  the owning report) with reproducible command and result.
