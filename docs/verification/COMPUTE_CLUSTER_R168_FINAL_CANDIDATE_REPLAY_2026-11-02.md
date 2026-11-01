# Compute Cluster exact-candidate integration replay — R168

**Replay ID:** `R168-R167-EXACT-SHA-CLEAN-REPLAY-20261102`  
**Replay result:** PASS for the named regression and checker-sensitivity scopes.  
**Executable test source:** R167 `4eb689c866650679d238d1ada955d6b03e68c6ec`, tree `e65fae5d62fc08e468b30ae271438ba6cb215959`.  
**Clean replay checkout:** documentation-only descendant `8f5c3cd5f7749ba5bfee1bb6d485a7b10c67f7d0`, tree `4d078da90be101fc16e638089f2471b6b8ed707e`; product RTL/SPEC and executable UVM sources are unchanged from the R167 candidate.  
**Product RTL/SPEC baseline:** `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`, Compute Cluster SPEC v1.8.

## Executed checks

| Check | Command / configuration | Result |
|---|---|---|
| Top Smoke | `make ai_smoke` in `dv/subsystem/top_smoke/sim` | PASS; mapper precheck and simulation `TEST PASS`. |
| Seeded Top regression | `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` in `dv/subsystem/top_smoke/sim` | PASS; 20 configured random cases; simulation `TEST PASS`. |
| Real-top Compute Cluster UVM | `VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r167_latch_clean_3seed COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'` | PASS on all three seeds; each checks 68,921 Memory Image words with zero mismatch, unknown read, stale epoch, or orphan response and UVM severity `0/0/0`. The FP, Conv, and KV descriptor-latch markers pass on each seed. |
| Checker-sensitivity campaign | `make uvm_compute_cluster_mutation COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r167_mutation_clean_20261102` in `dv/uvm/sim` | PASS, 28/28 expected checker catches: Address, Data, Owner, WSTRB, completion error code, write-after-error, response epoch, and Done/Missing-Done/Duplicate-Done on all seven engines. |

The UVM compile log has zero `Warning-`, `Error-`, or `[TFIPC]` entries. The intentional nonzero UVM error severity in each mutation run is the expected checker response; the campaign verifies the named checker marker and returns success only when the expected error is observed.

## Reproduction artifacts

The clean logs and SHA-256 manifest are archived outside the repository at `/tmp/nmaforge_r167_final_replay_20261102.tar.gz` (395 KiB), SHA-256 `406c36607f9c032bc11329aa08226da0d60ba8d420b599121e17b88754d36e21`. The archive contains the three per-seed UVM logs, compile log, 28 mutation logs, Top Smoke and seeded Top logs, checkout identity, and per-file checksums. Generated logs and coverage databases remain outside Git.

## Sign-off effect and limits

R168 confirms that the R167 test additions preserve the existing integration entry points and checker sensitivity. It does not regenerate the R166 merged URG databases: the latest declared coverage merge remains 17/17 subsystem and 18/18 same-top functional groups. It adds no product RTL or SPEC change and changes no RTM disposition. The 38 requirements remain 24 `PASS-SCOPED` and 14 `PARTIAL`; `CL-DV-v1.0` remains **HOLD**. Broader legal fault × phase × engine × reset combinations, completion/error ABI combinations, and other listed RTM gaps remain open. This is functional VCS evidence, not ASIC PPA or whole-NPU sign-off.
