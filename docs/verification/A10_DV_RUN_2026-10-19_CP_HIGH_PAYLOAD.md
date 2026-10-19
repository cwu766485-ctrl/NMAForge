# CP high-payload verification slice — 2026-10-19

## Scope and source identity

This is dirty-worktree evidence based on pushed HEAD
`90757f5b75e3642c0f0e0bac3efc21ad4825f972`, not a fixed-SHA replay. It adds
one testbench-only `CP_HIGH_PAYLOAD` case; product RTL, SPEC, and ABI are
unchanged.

Environment: Rocky Linux 8.10, VCS/URG
`V-2023.12-SP1_Full64`.

## Command and result

```text
make -C dv/block/command_processor/uvm cov-regress OUT=/tmp/nmaforge_a10_cp_high_payload_20261019/cp COV_OUT=/tmp/nmaforge_a10_cp_high_payload_20261019/cp/coverage SEEDS='20262014 20262015 20262016 20262017 20262018 20262019 20262020' VCS='/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs -licwait 1' URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

The campaign completed 168/168 mixed profiles. Every profile reported
`scenario_bins=32/32`, the high-payload marker, and UVM warning/error/fatal
`0/0/0`. The initial target stopped only at the final gate because it still
required 62/62 variables; the measured URG result was 63/63. After correcting
the gate, the existing report passed independently:

```text
make -C dv/block/command_processor/uvm check-coverage COV_OUT=/tmp/nmaforge_a10_cp_high_payload_20261019/cp/coverage
```

Measured URG results: `cp_cg` variables 63/63 and crosses 34/34,
`cp_high_payload` 1/1, mixed reset words 4/4, kind×delay×reset 24/24, and
abort timing 7/7. Assertions: 15 total, 13 success, 0 failure/incomplete, and
2 UVM RAL `do_read`/`do_write` no-attempts; 4/4 covers matched.

The top smoke also passed:

```text
make -C dv/subsystem/top_smoke/sim ai_smoke
```

with `TEST PASS`.

## Payload and boundary checked

The valid ABI v7 INT8 VDOT descriptor uses `length=16'hffff`, custom task ID
`16'hc3a5`, completion base `32'h0007_8000`, result `32'h3e12_3456`, cycles
`32'h0001_0023`, and elements `32'h0000_ffff`. The completion base and all four
16-byte record words remain inside the 512 KiB SPAD (`0x0008_0000`). The
testbench checks launch → compute event → completion start → all four word
addresses/data → exactly-once tail advancement.

This is a CP high-payload block slice only. Compute/fetch/DMA endpoints remain
testbench modeled at block level; full lifecycle and top-level integration are
not closed by this evidence. It does not claim V2, A10, or V5 closure.

Artifacts: `/tmp/nmaforge_a10_cp_high_payload_20261019/cp/`, including the
168 run logs, compile output, URG database, and merged reports.
