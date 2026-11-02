# Mixed FP Read Protection + Abort Reachability Review — R177

**Disposition:** Exploratory test is **not a PASS** and contributes no coverage closure. The proposed same-edge accepted-read Protection + Abort event is structurally unreachable through the current core request interface. `REQ-CL-019` remains `PARTIAL`; `CL-DV-v1.0` remains **HOLD**. No product RTL or SPEC was changed.

| Item | Evidence |
|---|---|
| Review ID | `R177-FP-READ-PROT-ABORT-REACHABILITY-20261102` |
| Attempted test SHA/tree | `b8b3cc9c0084f57ef9bcecb4a8cb0b3eab6de676` / `2a8d90555e1446a027ec393bf0fc9baa318c42b2`; published same-tree commit `2fee842205d10eec61c0c8c3a23f537078dfd46a` |
| Reverted test | Local `0a38116915473b583c013ee0b0b0dadcb7236a8d`; published revert `b8a2bb212fee4cd576e97cfc21c82259483ad6cb` |
| Tool / environment | VCS `V-2023.12-SP1_Full64`, UVM 1.2 |
| Attempted seed | `20261025`; the requested 3-seed target stopped on the first seed, so seeds `20261026/20261027` are `NOT_RUN` |
| Logs | `/tmp/nmaforge_r177_fp_read_priority_3seed/seed_20261025/{compile.log,run.log}` |
| Log SHA-256 | compile `70719cee3efb087e300fcca46f582420e4d9850290446b49d2cd5abfa53c9cc4`; run `fb81b5bbffb5420bd8eae9026684e8d01af30fcd886aef0119efd156e98be31b` |

## Reachability finding

In `rtl/compute/fp/ai_mixed_precision_dot_fp32_core.v`, `read_request_enable` includes `!abort`, and `spad_valid` for a read is asserted only when `read_request_enable` is true. `read_fire` is `spad_valid && spad_ready && !spad_write`. Therefore, once Abort is asserted before the sampling edge, the read request is withdrawn and a Protection indication cannot be a response to an accepted read on that edge. The intended sequence tried to sample both causes at an accepted request; the driver correctly failed its required-sample check instead of recording a hit. The simulation ended with one UVM fatal from that exploratory guard; it did not expose an RTL or scoreboard mismatch.

The design also has legal tests for accepted read Protection and for a later Abort after a previously captured read Protection. R176 separately checks same-edge result-write Protection + Abort, where the result-write request remains asserted. These do not turn the unreachable read combination into a passing test.

## Sign-off handling

Treat same-edge **accepted read** Protection + Abort as a candidate unreachable/N/A cross only after SPEC/verification review confirms the contract means concurrent accepted causes. This review is static RTL reasoning, not a formal proof or approved waiver. Do not inject a fabric Protection response without an accepted read to fill a bin. Keep the item visible for review; the broader fault × phase × reset, completion ABI, owner and recovery obligations remain open.

## Reproduction

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs \
URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
make -C dv/block/compute/fp/sim dot-uvm-regress \
  DOT_UVM_SEEDS='20261025 20261026 20261027' \
  DOT_UVM_OUT_DIR=/tmp/nmaforge_r177_fp_read_priority_3seed \
  DOT_RANDOM_COUNT=64
```
