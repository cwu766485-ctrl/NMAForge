# A10 DV Run Record — AXI-Lite SLVERR Response Coverage

Date: 2026-10-18
Repository branch: `main`
Base commit under test: `bd3a7cdb9cfd14825a23c12ab9c6ba5fefda8c79`
Environment: Rocky Linux 8.10, Synopsys VCS/URG V-2023.12-SP1

## Scope

This verification-only increment adds explicit AXI-Lite error-response checks
to the mixed-precision DDR end-to-end UVM sequence. There is no RTL, register
ABI, or specification behavior change.

The sequence writes and reads the aligned but unmapped register address
`0x0000_01fc`. It requires `BRESP=SLVERR` and `RRESP=SLVERR`; the read data is
required to be zero. The check runs in every mixed-precision E2E test. The
global scoreboard already permits expected error responses for this test, so
the sequence checks the response directly and emits
`[MIXED_E2E_INVALID_REG_SLVERR_PASS]` only after both operations pass.

AXI-Lite response coverage now includes `OKAY` and `SLVERR`; `EXOKAY` is an
illegal response for AXI4-Lite. `DECERR` is a legal AXI response, but is
excluded from this DUT-facing peripheral coverpoint because this testbench
connects directly to the IP and models no interconnect address decoder. The
peripheral itself reports unmapped register accesses as `SLVERR`.

## Results

| Check | Result |
|---|---|
| Focused mixed-precision DDR E2E, seed `20261018` | PASS; unmapped write/read SLVERR marker and E2E PASS; UVM warning/error/fatal `0/0/0` |
| FP16/BF16 length cross, 16 seeded runs | PASS `16/16`; all new SLVERR markers and E2E PASS markers present; UVM severity `0/0/0` |
| Random mixed-precision DDR E2E, seeds `20261101..20261292` | PASS `192/192`; every seed has both markers; UVM severity `0/0/0`; URG merge passed |
| AXI-Lite response coverpoint | `OKAY` and `SLVERR` bins `2/2`, 100%; `EXOKAY` illegal; `DECERR` excluded as described above |
| Mixed-precision E2E functional covergroup | `64/64`, 100% in both the 16-run and 192-run URG reports |
| Top smoke | PASS (`TEST PASS`) |

## Reproduction

Run on the configured Rocky/VCS environment:

```sh
make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_cov_regress \
  MIXED_E2E_COV_OUT=/tmp/nmaforge_a10_axil_slverr_cov16_final_20261018

make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e_random_cov_regress \
  MIXED_E2E_RANDOM_OUT=/tmp/nmaforge_a10_axil_slverr_random192_final_20261018

make -C dv/subsystem/top_smoke/sim ai_smoke VCS='vcs -licwait 1'
```

The focused run used the same `ai_accel_uvm.f`, test, and coverage metrics as
the campaigns above, with seed `20261018`; its compile/run logs and VDB are in
`/tmp/nmaforge_a10_axil_slverr_focus_20261018`.

## Evidence boundary

Tests ran from a shared worktree based on the pushed `bd3a7cd` commit. Other
unrelated local modifications were present and were not staged or included in
this increment. This is not a clean-checkout replay. The result closes this
AXI-Lite unmapped-register response slice only; it does not close A10 V1–V5,
all top-level functional/code coverage, or interconnect DECERR behavior. Raw
coverage databases and simulator outputs remain in `/tmp` and are not checked
into the public repository.

## Clean pushed-commit replay

After the initial push, all checks were replayed from a detached clean worktree
at commit `438532ce56c149362469832c0221c6a16b231762` (`test(dv): cover AXI-Lite
SLVERR in mixed E2E`) using the same Rocky Linux 8.10 and VCS/URG
V-2023.12-SP1 environment. The worktree was clean before and after simulation.

| Clean-SHA check | Result |
|---|---|
| FP16/BF16 length cross | PASS `16/16`; 16/16 SLVERR markers and E2E PASS markers; nonzero UVM severity `0` |
| Random mixed-precision DDR E2E | PASS `192/192`; 192/192 SLVERR markers and E2E PASS markers; nonzero UVM severity `0` |
| URG AXI-Lite response covergroup | `100%`; `cp_response` has 2/2 bins covered |
| URG mixed-precision E2E covergroup | `100%` in both merged reports |
| Top smoke | PASS (`TEST PASS`) |
| Post-test clean worktree | PASS; no tracked or untracked changes |

Clean replay artifacts are retained outside the repository under
`/tmp/nmaforge_a10_438532c_clean_16cov`,
`/tmp/nmaforge_a10_438532c_clean_random192`, and
`/tmp/nmaforge_a10_438532c_clean`. This replay verifies the pushed commit
reproducibly; it still closes only the AXI-Lite unmapped-register response
slice, not the overall A10 V1-V5 plan.
