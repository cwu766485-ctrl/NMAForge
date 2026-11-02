# Mixed FP Parity/Watchdog same-cycle priority — R180

**Disposition:** PASS for the named BF16/FP16 same-cycle parity-response versus expired-watchdog control point. This focused FP-core test result does not close the full Compute Cluster requirement: `REQ-CL-019` remains `PARTIAL`, and `CL-DV-v1.0` remains **HOLD**. Product RTL and SPEC were unchanged.

| Item | Evidence |
|---|---|
| Test ID / Run ID | `TC-CL-R180-FP-PARITY-WATCHDOG-SAME-CYCLE`; `R180-FP-PARITY-WATCHDOG-CLEAN-3S-20261102` |
| Fixed test SHA/tree | `7968b38cf4da3294b175c74a28eaa20e91045005` / `0e51eb22ceaf9b10be470db3fa788cf502b33c2d` |
| Clean worktree | `/tmp/nmaforge_r180_fp_parity_watchdog_clean` |
| Product baseline | RTL/SPEC `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`; SPEC v1.8 |
| Tools | VCS/URG `V-2023.12-SP1_Full64`; UVM 1.2 |
| Seeds | `20261025`, `20261026`, `20261027` |

## Scenario and checks

The directed sequence sets `watchdog_limit=2` and gives the accepted SPAD reads the existing deterministic response latency. On the first response edge, the driver requires `busy=1`, `cycle_count >= watchdog_limit`, parity error asserted, Abort deasserted, and no simultaneous accepted SPAD request. The independent scoreboard requires `ERR_PARITY=5`, both accepted reads drained, and zero writes. BF16 and FP16 each hit the required sampled edge on every seed.

Each seed passed **220/220 bit-exact transactions**, with UVM Warning/Error/Fatal counts **0/0/0**. The merged focused FP fault covergroup is **28/28 fault-mode bins** and **56/56 format×fault bins**; `read_parity_watchdog_same_cycle` has 6 hits total (3 BF16, 3 FP16). VCS compile logs contain no `Warning-`, `Error-`, or `TFIPC` diagnostics. These are scoped covergroup results, not whole-design coverage closure.

## Reproduction and artifacts

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
VCS=/tmp/nmaforge_vcs_home_linux_alias/bin/vcs \
URG=/tmp/nmaforge_vcs_home_linux_alias/bin/urg \
make -C dv/block/compute/fp/sim dot-uvm-regress \
  DOT_UVM_SEEDS='20261025 20261026 20261027' \
  DOT_UVM_OUT_DIR=/tmp/nmaforge_r180_fp_parity_watchdog_3seed \
  DOT_RANDOM_COUNT=64
```

Logs, vector inputs, per-seed VCS coverage databases, merged URG report and SHA-256 manifest are archived outside Git at `/tmp/nmaforge_r180_fp_parity_watchdog_evidence.tar.gz` (SHA-256 `ad1e9b7579a131f313af6a6d9c9a7abdd357707a051eba06534318c209168a08`). Manifest SHA-256: `bbf698dac7aeda985a284d4d5cf178fbfceaa546a1ce6a41e51043cef76dee52`.

The accepted-read Protection+Abort reachability/disposition documented under R177 remains open pending SPEC/reviewer approval or formal proof. Full seven-engine ownership, shared-memory scoreboard, broader engine×fault×phase×reset closure, and complete requirement RTM remain open.
