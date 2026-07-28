# CIMForge contributor guide

## Scope and working style

The active product track is the AXI-Lite/AXI4 AI accelerator.  The repository
also retains one legacy teaching track:

- The AXI-Lite AI accelerator: `rtl/top/ai_accel_top.v`, its scratchpad, DMA,
  command queue, descriptor path, compute engines, and FPGA wrappers.  All new
  accelerator design work belongs here.
- The original AHB SRAM/vector accelerator: `rtl/legacy/sramc_top.v` and
  `rtl/legacy/vec_accel_top.v`, retained only for history and verification-study
  reference.  Do not connect new AI features to it or use its regression as AI
  sign-off unless the task explicitly names the legacy track.

Before changing RTL, inspect `git status --short`.  The workspace is commonly
used for FPGA experiments and may contain unrelated local edits or generated
Vivado content.  Preserve those changes; do not reset, clean, or edit files
outside the requested scope.

Use `rg`/`rg --files` to locate RTL and test references.  When adding or
renaming a synthesizable AI RTL module, update every applicable source list:

- `verif/sim/ai_accel.f` for the AI smoke simulation;
- `fpga/xilinx_a7_100t/filelists/ai_accel_rtl.tcl` for Artix-7 builds;
- `fpga/xczu15eg/filelists/ai_accel_rtl.tcl` for Zynq UltraScale+ builds.

## AI accelerator architecture

`rtl/top/ai_accel_top.v` is the integration point.  Its intended ownership model
is important:

- `ai_accel_regs` is only the AXI-Lite register file: software configuration,
  control pulses, and sticky status/IRQ reporting.
- `ai_command_processor` owns command lifecycle scheduling: command/completion
  queue pointers, descriptor dispatch and validation, compute launch, and
  completion ordering.
- `ai_spad_arbiter` is the sole owner of the scalar scratchpad scheduler port.
  Its fixed admission priority is descriptor, completion writer, compute core,
  then DMA.  Do not reintroduce an independent mux in `ai_accel_top`.
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

Run VCS commands from `verif/sim` on the team Linux/VNC EDA environment:

```bash
make ai_smoke
make ai_comp
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
make regress
```

`make ai_smoke` compiles `tb_ai_accel_smoke` using `ai_accel.f`.  It requires
the Synopsys VCS environment and uses `+define+VCS` to select behavioural
scratchpad RAM.  The legacy AHB regression is `make regress`; do not substitute
it for AI smoke coverage after touching `ai_*` RTL.

For a focused RTL change, at minimum run the matching compile target and test.
For scheduler, queue, descriptor, DMA, scratchpad, or top-level changes, run
`make ai_smoke`; capture the command and the relevant pass/fail evidence in
your handoff.  Use `git diff --check` before declaring work complete.

## FPGA implementation

Vivado 2024.1 is installed locally at:

```powershell
& 'D:\Xilinx\Vivado\2024.1\bin\vivado.bat' -mode batch -source <script>
```

Run these from the repository root:

```powershell
# Artix-7 AI IP synthesis (default part xc7a100tfgg484-2)
& 'D:\Xilinx\Vivado\2024.1\bin\vivado.bat' -mode batch -source fpga\xilinx_a7_100t\scripts\synth_ai_accel_ip.tcl

# Artix-7 smoke top synthesis / implementation and bitstream
& 'D:\Xilinx\Vivado\2024.1\bin\vivado.bat' -mode batch -source fpga\xilinx_a7_100t\scripts\synth_smoke_top.tcl
& 'D:\Xilinx\Vivado\2024.1\bin\vivado.bat' -mode batch -source fpga\xilinx_a7_100t\scripts\build_smoke_bitstream.tcl

# XCZU15EG standalone AI IP synthesis
& 'D:\Xilinx\Vivado\2024.1\bin\vivado.bat' -mode batch -source fpga\xczu15eg\scripts\synth_ai_accel_ip.tcl
```

Artix scripts accept `FPGA_PART` as an environment override.  Check generated
timing, utilization, and DRC reports under `fpga/**/build/**/reports/`; build
directories and Vivado journals/logs are local artefacts and must not be
committed.

## Synopsys/VNC environment and secrets

The team VNC server provides the Synopsys tools (including VCS and Verdi).
Use the access details supplied out-of-band by the project owner, and follow
the server's environment setup instructions before running commands.

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
