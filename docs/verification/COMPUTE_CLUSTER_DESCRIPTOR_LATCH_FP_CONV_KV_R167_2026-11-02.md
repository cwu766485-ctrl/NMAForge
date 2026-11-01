# Compute Cluster FP/Conv/KV descriptor latch — R167

**Result:** PASS for three added real-top directed launch-snapshot testpoints. REQ-CL-005 remains PARTIAL.  
**Exact clean test commit:** 4eb689c866650679d238d1ada955d6b03e68c6ec  
**Source tree:** e65fae5d62fc08e468b30ae271438ba6cb215959  
**Product RTL/SPEC baseline:** c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413, SPEC v1.8 (unchanged).

## Scope and method

R167 extends the production-top REQ-CL-005 parameter-latch testpoint to FP, Conv, and KV. Each legal descriptor is fetched and launched through CMDQ. While the selected engine is active, the sequence mutates the backing descriptor words using uvm_hdl_deposit and updates the corresponding behavioral SRAM parity bit. The engine must finish using its launch-time snapshot. After completion the sequence restores the descriptor through normal host SPAD writes.

This deliberately does not issue concurrent AXI-Lite writes while a compute request is active: the scratchpad contract returns SLVERR for that conflict. The test isolates engine launch-snapshot behavior and does not claim concurrent host-write support or a host-port race test. No product RTL or SPEC changed.

| Test ID | Engine / descriptor | Independent result and checker |
|---|---|---|
| TC-CL-R167-FP-DESC-LATCH | BF16 dot, opcode 0x50, length 128; mutate A, B, destination, and length | 128 pairs of BF16 1.0 produce exact FP32 128.0 (0x43000000); original output and completion pass, mutated destination sentinel is unchanged, and launch snapshot fields match. |
| TC-CL-R167-CONV-DESC-LATCH | Conv, opcode 0x16, 4×4 input and 3×3 unit kernel; mutate input, weights, destination, and shape | Four independent outputs 54, 63, 90, 99 pass; original destination, completion and mutated-destination sentinels pass; launch snapshot fields match. |
| TC-CL-R167-KV-DESC-LATCH | KV_WRITE, opcode 0x43, eight words, head 1/token 2, strides 16/64; mutate source, cache base, length and aux | Eight original words are written at the expected 96-byte cache offset; mutated-cache sentinels, completion, and launch snapshot fields including head/token/strides pass. |

The existing Make regression now requires the FP, Conv and KV PASS markers in every configured seed log, in addition to the prior Scalar/CNM/Matrix/SFU latch checks. These are directed testpoint gates, not new covergroup bins.

## Exact clean-SHA run

The command ran from the repository worktree at the clean committed SHA; generated files remain under /tmp:

    VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r167_latch_clean_3seed COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

VCS is V-2023.12-SP1_Full64, URG is V-2023.12-SP1, and UVM is 1.2. The official target exits 0 and prints COMPUTE_CLUSTER_REAL_UVM_REGRESS_PASS. All three seeds contain each of the three required markers, with UVM severity 0/0/0. Per seed, the Memory Scoreboard checks 68,921 words, with zero mismatches, unknown reads, or stale-epoch responses. The compile log contains no Warning-, Error-, or [TFIPC] diagnostic.

| Seed | Run log | SHA-256 |
|---|---|---|
| 20261025 | /tmp/nmaforge_r167_latch_clean_3seed/seed_20261025/run.log | 5078b7a761add91b1bd8879f1d1007bbd993150aedfc5c19bbf0dcd16bcb3561 |
| 20261026 | /tmp/nmaforge_r167_latch_clean_3seed/seed_20261026/run.log | 2474abb30981d72909b1d5cec8e56ee9dfa5d9e0ca22e32279cee23fe4144847 |
| 20261027 | /tmp/nmaforge_r167_latch_clean_3seed/seed_20261027/run.log | d9da9df48ecf4878044a30021e84a3e321ce5e0f682ecc164d4c0e2ac8834c95 |

## Disposition

This closes only the three named FP/Conv/KV descriptor-latch testpoints. The 38-row RTM remains 24 PASS-SCOPED / 14 PARTIAL, and CL-DV-v1.0 remains HOLD. Remaining REQ-CL-005 descriptor field/opcode/boundary combinations are not inferred from these samples. R167 did not rerun Top Smoke, the separate 28-case checker-sensitivity campaign, or the benchmark suite; their existing evidence retains its own SHA.
