# Compute Cluster banked/core ownership contention — R113

**Run ID:** `SPAD-BANKED-CORE-CONTENTION-R113-3S`  
**Exact clean code/test SHA:** `10601142cf912369b871fa9e5affed8fde5f767b`.  
**Product RTL/SPEC baseline:** R99 `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`; R113 changes the subsystem UVM test and Make gate only.  
**Target:** the in-repository `ai_accel_memory_fabric`, its production `ai_spad_arbiter`, and registered four-bank SPAD.  
**Tools:** VCS `V-2023.12-SP1_Full64`, URG `V-2023.12-SP1`.  
**Seeds:** `20261025`, `20261026`, `20261027`.  
**Result:** PASS for the named simultaneous-request and response-owner point.

## Test and checker result

Each seed begins with simultaneous legal reads from the scalar scheduler port (`0x17c`) and Matrix-like banked port (`0x100`). The address image is initialized independently before the test. From the reset arbitration pointer, the test requires the scalar request to be accepted first and the banked request on the next arbitration turn. It checks each response separately: scalar owner tag 2 and expected word, followed by banked owner tag 3 and all four expected bank words. Each response must be the only active response owner and must have no response error. The test waits through the SVA sampling edge after the banked response.

The three-seed regression exits `0`. All seeds print `[SPAD_BANKED_CORE_CONTENTION_PASS]` and report UVM warning/error/fatal `0/0/0`. URG reports `banked_core_contention_cg` at **100.00%**. `ap_banked_response_tag` has **429 attempts, 3 real successes, 0 failures, 0 incomplete**. The Make target rejects a missing PASS marker, UVM severity, incomplete focused coverage, or a vacuous/failing banked response assertion. `ap_core_grant_owner` also records 429 attempts, 3 real successes, and no failure/incomplete.

The compiler reports only platform notices for Rocky Linux 8.10 and WSL2 kernel 6.6.87.2. These are tool support notices; VCS and URG completed successfully. The Make target exits `0` after validating all three PASS markers, UVM severity summaries, the 100% focused group, and the non-vacuous banked response-owner assertion.

## Reproduction

From a detached clean worktree at the exact SHA above:

```sh
env -u VCS_ARCH_OVERRIDE VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  make -C /tmp/nmaforge_r113_published_106011_clean/dv/subsystem/dma_spad/sim \
  subsystem_banked_contention_regress \
  BANKED_CONTENTION_OUT=/tmp/nmaforge_r113_published_106011_replay2 \
  VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

## Evidence hashes

| Artifact | SHA-256 |
|---|---|
| `make driver log` (exit 0) | `1a18e26e794544bfc7a7e0f06a4741b4f237691e917300894c5af6905b2a56a9` |
| `compile.log` | `f1661e31e1eca15367f5d102f771533392e9672c6e25448964b9719671cc25c7` |
| `seed_20261025/run.log` | `acb7c5cea97b2f42331f358a251e59271b1364d65a1e9105236e2e4fa90fad90` |
| `seed_20261026/run.log` | `4b7b22582070daca37a5aca57bfc85205f8ec6bd7738b78b23265aa1c1a71f9f` |
| `seed_20261027/run.log` | `c7efe21f7e8d7569dc6ce5cac0dfac5ef70a0b3e9afbcc0a9f7b0833dbbdc797` |
| `urg/asserts.html` | `e514077fabe14febb23193e8911438758f0166121e0bd40418c197e965d38901` |
| `urg/groups.html` | `cb670027cd3e89e85c681632c9300f66d66689d083c6d5c6db18e4ab2d782d7a` |
| `urg/grp3.html` (focused bins) | `a2fca73488577c7d2098c0ed982002cb7af050520e96d4424305cd5a10bbd946` |
| `urg/dashboard.html` | `d8ebe9f354c6b893fd43c95009ec80dbccaae759521f3b9f96a5c59c2f0bda99` |

## Scope limits and disposition

The scalar port and Matrix-like banked port are testbench-driven requesters; the test exercises real arbitration, memory access and response demultiplexing but does not run the production Matrix compute engine. It covers one simultaneous read pair and the initial Core-to-Banked arbitration turn. It does not establish starvation bounds, sustained backpressure, error recovery, reset interaction, or the complete seven-engine contention space. This adds bounded evidence to `REQ-PC-007`; that requirement remains **PARTIAL**, the RTM remains **24 PASS-SCOPED / 14 PARTIAL**, and `CL-DV-v1.0` remains **HOLD**. Product RTL and SPEC are unchanged.
