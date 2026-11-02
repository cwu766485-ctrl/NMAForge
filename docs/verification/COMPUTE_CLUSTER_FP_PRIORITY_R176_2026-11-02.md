# Mixed FP same-cycle Protection/Abort priority — R176

**Disposition:** PASS for one named FP-core same-cycle priority testpoint; the broader Compute Cluster fault/phase/error cross remains open. `REQ-CL-019` stays PARTIAL and `CL-DV-v1.0` stays HOLD.

| Item | Evidence |
|---|---|
| Test ID / Run ID | `TC-CL-R176-FP-WRPROT-ABORT-SAME-CYCLE`; `R176-FP-PRIORITY-CLEAN-3S-20261102` |
| Fixed source/test SHA | `546d371107fe1f1ab7dae98a241bb6eaa1b2643c` (tree `ecab1c5d1888bb7ae076414c77d76ba708d76e09`) |
| RTL/SPEC | Product RTL and SPEC unchanged; Matrix/Cluster frozen baseline remains `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`, SPEC v1.8 |
| Tools | VCS/URG `V-2023.12-SP1`; UVM 1.2 |
| Seeds | `20261025`, `20261026`, `20261027` |

## Scenario and checks

The directed FP-core sequence runs both BF16 and FP16. On the result write request, the driver asserts `spad_ready`, `spad_protection_error`, and `abort` together before the same rising edge. A posedge checker requires `valid`, `ready`, `write`, Protection, and Abort to be simultaneously high; a missing sample is fatal. The independent scoreboard then requires two accepted reads, one denied result-write request, no protocol error, and `ERR_PROTECTION=6`, as required by the frozen Mixed FP priority `Write Protection > Abort`.

Each seed passes 214/214 scoreboard transactions, including both same-cycle cases, with UVM warning/error/fatal `0/0/0`. Each seed reports exactly two `FP_SAME_CYCLE_PRIORITY_SAMPLE` observations, one BF16 and one FP16. The merged `fault_cg` is 100% (25/25 bins); `fault_format_cross` is 100% (50/50). The new `write_protection_abort_same_cycle` bin has three BF16 and three FP16 hits in the merged VDB. Compile logs contain no `Warning-`, `Error-`, or `TFIPC` diagnostics.

## Reproduction and artifacts

```sh
VCS_ARCH_OVERRIDE=linux \
VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs \
URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
make -C dv/block/compute/fp/sim dot-uvm-regress \
  DOT_UVM_SEEDS='20261025 20261026 20261027' \
  DOT_UVM_OUT_DIR=/tmp/nmaforge_r176_fp_priority_clean_3seed \
  DOT_RANDOM_COUNT=64
```

The regression ran from the clean test worktree `/tmp/nmaforge_closeout_audit` at the exact SHA above; the archived logs and merged text coverage are in `/tmp/nmaforge_r176_fp_priority_clean_3seed.tar.gz` (SHA-256 `dc24a67407e21e5626bfce99935780280c5514244b43ffaf967f2f4bc8fad6c1`). The archive manifest is `/tmp/nmaforge_r176_fp_priority_evidence/MANIFEST.sha256` (SHA-256 `6cd582a38366a44619cbfe967e5d21b95e7228cab434a07e270ac8d2f069f317`).

This is an FP-core UVM test, not a real CMDQ/`ai_completion_writer` integration test. It closes only this sampled-edge cause-priority point; parity/read-Protection overlaps, Abort/watchdog simultaneity, other fault phases, reset crossings, and the full Engine × Fault × Phase × Reset matrix remain open.
