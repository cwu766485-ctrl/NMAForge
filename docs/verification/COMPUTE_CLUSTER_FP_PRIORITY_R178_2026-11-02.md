# Mixed FP Parity/Abort same-cycle priority — R178

**Disposition:** PASS for the named accepted-response priority point in BF16 and FP16. This does not close the broader Compute Cluster error ABI/fault-phase matrix; `REQ-CL-019` remains `PARTIAL` and `CL-DV-v1.0` remains **HOLD**. Product RTL/SPEC were unchanged.

| Item | Evidence |
|---|---|
| Test ID / Run ID | `TC-CL-R178-FP-PARITY-ABORT-SAME-CYCLE`; `R178-FP-PARITY-ABORT-CLEAN-3S-20261102` |
| Fixed test SHA/tree | `87e41e4a7ff1802984b2a9e517295bfdec0c5a33` / `c94ad410200e6d20a59e1e68c2e669be1295390d` |
| Clean worktree | `/tmp/nmaforge_r178_fp_parity_abort_clean` |
| Product baseline | RTL/SPEC baseline `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`; SPEC v1.8 |
| Tools | VCS/URG `V-2023.12-SP1_Full64`; UVM 1.2 |
| Seeds | `20261025`, `20261026`, `20261027` |

## Scenario and checks

On the first accepted SPAD response carrying a parity error, the driver asserts Abort before the same rising edge. The sampled-edge checker requires `spad_rsp_valid`, `spad_parity_error`, and Abort together. The independent scoreboard requires `ERR_PARITY=5`, two accepted reads fully drained, and no result write. Both BF16 and FP16 exercise the point on every seed. The regression also retains R176's same-edge result-write Protection+Abort point.

Each seed passes 216/216 bit-exact scoreboard transactions with UVM warning/error/fatal counts `0/0/0`. URG reports the focused FP fault group at 100%: 26/26 fault-mode variables and 52/52 format×fault bins. The new `read_parity_abort_same_cycle` bin is hit three times per format in the merged database. Compile logs contain no `Warning-`, `Error-`, or `TFIPC` diagnostics. These are focused FP-core coverage results, not whole-design coverage closure.

## Reproduction and artifacts

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs \
URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
make -C dv/block/compute/fp/sim dot-uvm-regress \
  DOT_UVM_SEEDS='20261025 20261026 20261027' \
  DOT_UVM_OUT_DIR=/tmp/nmaforge_r178_fp_parity_abort_3seed_clean \
  DOT_RANDOM_COUNT=64
```

Text logs and merged URG coverage are archived outside Git at `/tmp/nmaforge_r178_fp_parity_abort_evidence.tar.gz` (SHA-256 `e42bcb511f58c77c2a2ad8439589e59f3b5a527d1b28e09eb5beefcfcb49ef88`). The archive manifest SHA-256 is `d39eca5350be2690abdc58c081de02a7b21505a56e6a4ca87e1d5d2ca92a5f6d`.

R177's proposed same-edge accepted-read Protection+Abort combination remains a separate unapproved reachability disposition; it is not counted by this run. Full engine × fault × phase × reset and integrated completion/owner closure remain open.
