# A8 SpyGlass static verification

`a8_static.prj` analyzes only active A8 synthesizable RTL and excludes
testbench/SVA sources.  It uses the TSMC28 scratchpad macro wrapper plus a
port-only declaration of the foundry SRAM, so static analysis checks the
wrapper/control path without synthesizing behavioural simulation arrays.

From a Linux EDA environment with SpyGlass loaded:

```bash
cd <CIMForge>/verif/spyglass
chmod +x run_spyglass_a8.sh
./run_spyglass_a8.sh lint
./run_spyglass_a8.sh cdc
./run_spyglass_a8.sh rdc
```

The current architecture has one functional clock, `aclk`, and active-low
reset `aresetn`.  Expected CDC outcome is no unintentional clock crossing;
this is not a claim that future PS/DDR/accelerator multi-clock integration is
already covered.  RDC is intentionally not waived: an asynchronous reset
release reported by SpyGlass must be classified as either an integration
assumption (reset is synchronously released upstream) or corrected by an
explicit reset synchronizer.

Do not waive lint/CDC/RDC findings globally.  Record every accepted finding
with its rule, instance/path, rationale, owner and review date in a committed
waiver file.

The team server used for the initial A8 run has the structural CDC/RDC goals,
but lacks the `Advanced_CDC` and `rdc_adv_checker` license features.  A report
that says those advanced rules were not run is a tool-coverage limitation, not
an RTL pass or an RTL violation.  Record it explicitly and re-run the same
project in an environment with those features before sign-off.
