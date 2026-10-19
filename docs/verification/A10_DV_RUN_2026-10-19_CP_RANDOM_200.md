# A10 CP seeded-random mixed error/abort/reset campaign — 2026-10-19

## Scope and source identity

This is an additive command-processor UVM/coverage increment based on the
pushed `main` baseline `35c7670594c85d471bad1e5a975df7f16369c78f`. The run
used the current checkout with the new `cov-random-regress` Make target in
the working tree. It changed no product RTL, SPEC, register ABI, or command
semantics. The target leaves the existing deterministic `cov-regress`
unchanged.

For each seed, the full `ai_cp_test` runs without `CP_MIXED_KIND`,
`CP_MIXED_DELAY`, or `CP_MIXED_RESET_WORDS` plusargs. The mixed lifecycle
scenario therefore draws its prefix error kind, compute-abort delay, and
accepted completion-word reset point from the simulation seed. The 200-run
campaign plus URG merge checks whether the union covers all 24 combinations.

## Command and environment

Executed through the reviewed Rocky-8.10 bridge with VCS/URG
`V-2023.12-SP1_Full64` and the active local license:

```sh
make -C dv/block/command_processor/uvm cov-random-regress \
  OUT=/tmp/nmaforge_a10_cp_random_20261019_35c7670_v1/cp \
  COV_OUT=/tmp/nmaforge_a10_cp_random_20261019_35c7670_v1/cp/coverage \
  RANDOM_SEED_START=20262021 RANDOM_SEED_COUNT=200 \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg

make -C dv/subsystem/top_smoke/sim ai_smoke \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs
```

## Results

- All 200 full CP runs passed; seeds `20262021..20262220` produced 200 logs
  and 200 coverage databases. Every log passed the existing CP log checker,
  reached `scenario_bins=32/32`, and reported UVM warning/error/fatal=`0/0/0`.
- URG merged `compile.vdb` and all 200 seed databases. The existing hard
  coverage gate passed: `cp_cg` variables 63/63, crosses 34/34, high-payload
  1/1, mixed reset-word bins 4/4, mixed prefix-kind × abort-delay × reset-word
  cross 24/24, and abort timing 7/7.
- Assertions: 13 successes, 0 failures, 0 incomplete; 2 no-attempts are UVM
  RAL `do_read`/`do_write` internals. Cover properties: 4/4 matched.
- Top-level `ai_smoke` passed and printed `TEST PASS`.
- The CP and completion-writer raw toggle results remain 13.21% and 41.81%
  respectively in this merged database. Functional coverage does not waive
  these DUT raw-coverage residuals.

Artifacts: `/tmp/nmaforge_a10_cp_random_20261019_35c7670_v1/`.

## Closure boundary

This closes a bounded seeded-random slice of the CP mixed
front-end-error → compute-abort → partial-completion reset → recovery scenario,
including its 24-point kind/delay/reset cross. It does **not** close all CP
lifecycle interactions, raw DUT toggle coverage, the wider V2 command and
completion plan, or A10/V5. Fetch/compute/DMA endpoints in the CP block test
remain modeled; `ai_smoke` is a separate top smoke, not a top-level UVM
DDR-to-compute end-to-end campaign.
