# Mixed FP Abort/Watchdog same-cycle priority — R179

**Disposition:** PASS for the named BF16/FP16 same-cycle Abort-versus-expired-Watchdog control point. This adds focused FP-core evidence only; `REQ-CL-019` remains `PARTIAL` and `CL-DV-v1.0` remains **HOLD**. Product RTL/SPEC were unchanged.

| Item | Evidence |
|---|---|
| Test ID / Run ID | `TC-CL-R179-FP-ABORT-WATCHDOG-SAME-CYCLE`; `R179-FP-ABORT-WATCHDOG-CLEAN-3S-20261102` |
| Fixed test SHA/tree | `65606bc8a6c17ccee830c1eb3ae64ccc9c32d97d` / `1916c73052dd9f6ad609c4e16cfc642363094dba` |
| Clean worktree | `/tmp/nmaforge_r179_fp_abort_watchdog_clean` |
| Product baseline | RTL/SPEC baseline `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`; SPEC v1.8 |
| Tools | VCS/URG `V-2023.12-SP1_Full64`; UVM 1.2 |
| Seeds | `20261025`, `20261026`, `20261027` |

## Scenario and checks

The directed sequence sets `watchdog_limit=1` and keeps the first read request stalled. At the expiry threshold, the driver asserts Abort before the sampling edge. A mandatory edge checker requires the core to remain busy, the cycle count to have reached the watchdog limit, Abort high, and no accepted SPAD transfer on that edge. The independent scoreboard requires `ERR_ABORT=3`, zero accepted reads, and zero writes. Both BF16 and FP16 exercise the case on each seed.

Each seed passes 218/218 bit-exact scoreboard transactions with UVM warning/error/fatal counts `0/0/0`. The focused FP fault group is 100%: 27/27 fault-mode variables and 54/54 format×fault bins. The `abort_watchdog_same_cycle` bin is hit three times per format in the merged database. Compile logs contain no `Warning-`, `Error-`, or `TFIPC` diagnostics. This is not whole-design coverage closure.

## Reproduction and artifacts

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs \
URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
make -C dv/block/compute/fp/sim dot-uvm-regress \
  DOT_UVM_SEEDS='20261025 20261026 20261027' \
  DOT_UVM_OUT_DIR=/tmp/nmaforge_r179_fp_abort_watchdog_3seed_final \
  DOT_RANDOM_COUNT=64
```

Logs and merged URG text coverage are archived outside Git at `/tmp/nmaforge_r179_fp_abort_watchdog_evidence.tar.gz` (SHA-256 `27ba15375c0dce884bfaa56da698abea3ea810accb4e1c33b916bb7e8b9caad7`). Manifest SHA-256: `7a8452bb86fe013f4299713f4867b4222272922c9b8b4b660590547a0e8745fc`.

R177's proposed accepted-read Protection+Abort combination remains a separate candidate unreachable/N/A disposition pending review/formal proof. Broader engine × fault × phase × reset, completion ABI and ownership closure remain open.
