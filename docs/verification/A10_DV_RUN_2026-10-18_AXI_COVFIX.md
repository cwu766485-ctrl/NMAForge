# A10 DV AXI4 coverage-model correction — 2026-10-18

## Scope

This is a verification-only correction to `dv/uvm/env/coverage/ai_axi4_coverage.svh`.
The sampled AXI event is kept as the five-value `ai_axi_event_e` instead of
being cast to a 32-bit integer, avoiding meaningless auto-bins. AXI size and
length are sampled only on AR/AW, where those fields are meaningful; the
address-channel kind × size cross is explicit. The edit does not change RTL,
protocol behavior, register ABI, or software ABI.

The tests used an isolated source snapshot at exact pushed-main base
`9e05dfc378b0017ab0cff7098785a3d7b0e719fd`; the active worktree's unrelated
uncommitted changes were not part of the tested snapshot or commit.

Environment: Rocky Linux 8.10, Synopsys VCS/URG `V-2023.12-SP1_Full64`.
Simulation and coverage artifacts are under `/tmp/nmaforge_a10_axi_covfix_*`;
they are local outputs and are not checked into Git.

## Reproducible runs

The logged runs used the isolated worktree described above. Commands below
show the equivalent invocation from a checkout of the committed project root.

Sixteen-seed coverage smoke:

```sh
make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_a10_axi_covfix_16seed_isolated_20261018 \
  VCS_UVM='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS -licwait 1'
```

Result: 16/16 seeds passed with the corrected model. AXI4 `cg` scored 83.33%;
all five event bins hit (AR=160, R=176, AW=48, W=48, B=48). Address kind and
length bins were complete. The workload exercised wide-128-bit transfers but
not narrow-32-bit transfers, so only two of the four address-kind × size
combinations were hit.

Full randomized DDR E2E coverage campaign:

```sh
make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_random_cov_regress \
  MIXED_E2E_RANDOM_OUT=/tmp/nmaforge_a10_axi_covfix_192seed_isolated_20261018 \
  VCS_UVM='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -full64 -sverilog -ntb_opts uvm-1.2 -debug_access+all -kdb -timescale=1ns/1ns +define+VCS -licwait 1'
```

The run completed 192/192 seeds. Every per-seed UVM warning/error/fatal
summary was `0/0/0`; compile diagnostics grep found none; URG merge and its
Makefile gates passed. Aggregate URG coverage was 95.57%. AXI4 `cg` scored
83.33%: all five event bins, all ID bins, both address-channel-kind bins, and
both length bins were hit; `wide128` was hit and `narrow32` was not, leaving
the two narrow-size cross combinations uncovered. The selected E2E functional
group and all four transaction-level AXI AR/AW/R/W gap/backpressure groups
were 100%.

AXI-Lite coverage scored 81.25%; this successful E2E workload sampled only
`OKAY` responses, so non-OKAY response behavior remains unexercised. Assertions
reported 20 successes, zero failures/incomplete, and two no-attempt UVM RAL
internals (`uvm_reg_map::do_read` and `do_write`). The report includes
testbench activity assertions and should not be interpreted as 20 DUT-only
assertions. All three selected AXI stall-to-accept cover properties matched.

Top smoke on the same isolated source snapshot:

```sh
make -C dv/subsystem/top_smoke/sim ai_smoke \
  AI_RANDOM_CASES=4 AI_SEED=12345
```

Result: `TEST PASS`, including reset recovery and DMA/AXI idle checks.

## Remaining coverage work

- Add or identify a specification-valid top-level E2E case that exercises
  narrow-32-bit AXI transfers, then require both read and write size-cross
  bins if both directions are architecturally supported.
- Exercise non-OKAY AXI-Lite response handling in a targeted negative test if
  that response behavior is part of the verified interface contract.
- Keep malformed/oversized AXI traffic in protocol-negative tests; it is not
  evidence of legal-workload coverage and must not be forced into success
  bins.
- Review remaining raw RTL, assertion, and functional coverage and record
  justified exclusions. This result does not close V5 or A10.
