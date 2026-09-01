# NMAForge contributor guide

## Scope and working style

The active and only product track is the AXI-Lite/AXI4 AI accelerator:
`rtl/top/ai_accel_top.v`, its scratchpad, DMA, command queue, descriptor path,
compute engines, and FPGA wrappers.  All accelerator design work belongs here.

Before changing RTL, inspect `git status --short`.  The workspace is commonly
used for FPGA experiments and may contain unrelated local edits or generated
Vivado content.  Preserve those changes; do not reset, clean, or edit files
outside the requested scope.

## Agent collaboration

- Terra is the orchestrator: it owns architecture decisions, task breakdown,
  integration, review, ambiguous debugging, and the final handoff.
- When GPT-5.6 Luna is available, delegate only clear, low-risk, bounded
  implementation or mechanical tasks to Luna.  Give it the minimum files and
  context needed for that task; do not fork the full conversation by default.
- Keep subagent work on disjoint files.  Terra must inspect every result,
  resolve integration issues, and run or request the relevant verification
  before claiming success.
- If Luna fails twice on the same issue, stop delegating that issue and return
  it to Terra for diagnosis and resolution.
- Do not use a subagent to make an architecture decision or to bypass the RTL
  ownership, verification, safety, or public-release rules in this guide.

Use `rg`/`rg --files` to locate RTL and test references.  When adding or
renaming a synthesizable AI RTL module, update every applicable source list:

- `verif/subsystem/top_smoke/sim/ai_accel.f` for the AI smoke simulation;
- `fpga/xilinx_a7_100t/ai_accel_rtl.tcl` for Artix-7 builds;
- `fpga/xczu15eg/ai_accel_rtl.tcl` for Zynq UltraScale+ builds.

## AI accelerator architecture

`rtl/top/ai_accel_top.v` is the integration point.  Its intended ownership model
is important:

- `ai_accel_regs` is only the AXI-Lite register file: software configuration,
  control pulses, and sticky status/IRQ reporting.
- `ai_command_processor` owns command lifecycle scheduling: command/completion
  queue pointers, descriptor dispatch and validation, compute launch, and
  completion ordering.
- `ai_spad_arbiter` is the sole owner of the scratchpad scheduler port.
  Descriptor and completion traffic retain control-plane priority; scalar/line
  compute, banked compute, and scalar/line DMA use data-plane round-robin
  arbitration.
  Do not reintroduce an independent mux in `ai_accel_top`.
- `ai_desc_fetch` reads scratchpad descriptors; `axi_desc_fetch` reads external
  descriptors.  The command processor selects and holds the source for a
  command.
- `ai_completion_writer` commits all four words of a completion entry before
  `CPLQ_TAIL` advances.
- `ai_scratchpad` has a host/debug port, one arbiter-driven scheduler port, and
  a banked-read path.  The behavioural RAM implementation is selected by
  `+define+VCS`; normal Vivado synthesis uses the XPM branch.

Keep queue ownership intact: software publishes `CMDQ_TAIL` and consumes via
`CPLQ_HEAD`; hardware reports `CMDQ_HEAD` and `CPLQ_TAIL`.  The register map
retains pointer-load writes for reset/debug compatibility, but pointer
advancement must remain in `ai_command_processor`.

## Verification

Run the current directed/smoke VCS commands from `verif/subsystem/top_smoke/sim`
on the team Linux/VNC EDA environment:

```bash
make ai_smoke
make ai_comp
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

`make ai_smoke` compiles `tb_ai_accel_smoke` using `ai_accel.f`.  It requires
the Synopsys VCS environment and uses `+define+VCS` to select behavioural
scratchpad RAM.

For a focused RTL change, at minimum run the matching compile target and test.
For scheduler, queue, descriptor, DMA, scratchpad, or top-level changes, run
`make ai_smoke`; capture the command and the relevant pass/fail evidence in
your handoff.  Use `git diff --check` before declaring work complete.

## FPGA implementation

Invoke Vivado 2024.1 from `PATH`, `VIVADO_HOME`, or an explicit local path:

```powershell
vivado -mode batch -source <script>
```

Run these from the repository root:

```powershell
# Artix-7 AI IP synthesis (default part xc7a100tfgg484-2)
vivado -mode batch -source fpga\xilinx_a7_100t\scripts\synth_ai_accel_ip.tcl

# Artix-7 smoke top synthesis / implementation and bitstream
vivado -mode batch -source fpga\xilinx_a7_100t\scripts\synth_smoke_top.tcl
vivado -mode batch -source fpga\xilinx_a7_100t\scripts\build_smoke_bitstream.tcl

# XCZU15EG standalone AI IP synthesis
vivado -mode batch -source fpga\xczu15eg\scripts\synth_ai_accel_ip.tcl
```

Artix scripts accept `FPGA_PART` as an environment override.  Check generated
timing, utilization, and DRC reports under `fpga/**/build/**/reports/`; build
directories and Vivado journals/logs are local artefacts and must not be
committed.

## Synopsys/VNC environment and secrets

The team EDA environment provides the Synopsys tools (including VCS and Verdi).
Use access details supplied out-of-band by the project owner and follow the
site environment setup instructions before running commands.

Never add server addresses, usernames, passwords, tokens, license strings,
or other credentials to Git, waveforms, logs, TCL scripts, source lists, or
this file.  Keep machine-specific values in ignored local configuration such
as `.env` if they are needed by automation.

## RTL and deliverable hygiene

- Use non-destructive Git commands.  Never run `git reset --hard` or remove
  generated directories unless explicitly requested.
- Preserve protocol timing: scratchpad reads are registered, completion queue
  tail moves only after the four-word write, and AXI/AXI-Lite valid/ready rules
  must remain intact.
- Add or update smoke-test coverage when a register-visible behavior, queue
  behavior, descriptor format, DMA transfer mode, or error code changes.
- Do not claim a synthesis or simulation pass unless it was actually run in
  the appropriate tool environment.  If the local host lacks the tool, state
  the exact command a maintainer should run.
