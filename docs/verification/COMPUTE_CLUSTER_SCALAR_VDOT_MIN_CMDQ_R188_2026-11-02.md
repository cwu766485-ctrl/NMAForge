# Compute Cluster minimum Scalar VDOT through CMDQ — R188

**Run ID:** R188-SCALAR-VDOT-MIN-CMDQ-3S-20261102  
**Result:** PASS for the minimum encoded Scalar VDOT workload through the real CMDQ/top/compute/memory path. This is a bounded testpoint, not full descriptor-boundary or Compute Cluster sign-off.  
**Local source/test SHA:** 5068af69e5006fdc869d60244df0708c810cf3ea  
**Published same-tree code commit:** 744d560c6402c64517fde47ca278e944e93060ef  
**Tree:** 885200c7b42bd5a13a5ea8e9331988ce3299da60  
**Product RTL/SPEC:** unchanged; product baseline remains c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413, SPEC v1.8.  
**Tools:** Synopsys VCS/URG V-2023.12-SP1_Full64 / V-2023.12-SP1.

## Command and result

The run was made from a clean checkout at the exact local source/test SHA:

    VCS_ARCH_OVERRIDE=linux make -C dv/uvm/sim uvm_compute_cluster_regress       VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias       COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r188_scalar_vdot_min_clean_3seed       COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

The target exits 0 with COMPUTE_CLUSTER_REAL_UVM_REGRESS_PASS for all three seeds. Each seed requires and emits CLUSTER_SCALAR_VDOT_MIN_BOUNDARY_PASS: the real CMDQ dispatches Scalar VDOT opcode 0x10 with minimum nonzero length=1, launches exactly once with the sampled descriptor fields, computes four signed INT8 lanes to independent Golden -16255, writes one completion and preserves the adjacent output guard word.

| Seed | Directed result | Memory Scoreboard | UVM warning/error/fatal |
|---|---|---|---|
| 20261025 | PASS, Golden -16255, completion and guard pass | 63,880 writes; 69,656 checked words; 0 mismatch/unknown/stale epoch | 0/0/0 |
| 20261026 | PASS, Golden -16255, completion and guard pass | 63,880 writes; 69,656 checked words; 0 mismatch/unknown/stale epoch | 0/0/0 |
| 20261027 | PASS, Golden -16255, completion and guard pass | 63,880 writes; 69,656 checked words; 0 mismatch/unknown/stale epoch | 0/0/0 |

The three-seed URG merge reports cluster_cg 64/64 and the named sequence-level groups at 100%. Its total group score is 71.89%; five DMA-only groups are unhit, AXI4 is 50.28%, and AXI-Lite is 87.50%. The compute-only run also leaves AR/AW AXI properties without real successes and AR/AW stall covers unmatched. These are disclosed workload limits, not coverage closure.

## Requirement trace and scope

| Requirement | Disposition | Test ID / checker | Coverage / result | Run ID / seed | Evidence |
|---|---|---|---|---|---|
| REQ-CL-002 | PARTIAL | TC-CL-R188-SCALAR-VDOT-MIN-CMDQ; launch snapshot, independent signed INT8 Golden, completion and adjacent-guard checks | Minimum nonzero VDOT length passes 3/3; larger/per-opcode limits, stride, alias and address-overflow rules remain open | R188-SCALAR-VDOT-MIN-CMDQ-3S-20261102; 20261025/26/27 | /tmp/nmaforge_r188_scalar_vdot_min_clean_3seed/seed_*/run.log |
| REQ-CL-020 | PARTIAL | Same test and checkers | One real-CMDQ Scalar arithmetic boundary passes; legacy Conv, broader legal opcode/shape and numeric combinations remain open | Same | Same |

## Reproduction artifacts

| Artifact | Path | SHA-256 |
|---|---|---|
| VCS compile log | /tmp/nmaforge_r188_scalar_vdot_min_clean_3seed/compile.log | 2bc021554ca46d4a2a10dd479aa611c987da239efee1d353f91222134870ec9f |
| Seed 20261025 log | /tmp/nmaforge_r188_scalar_vdot_min_clean_3seed/seed_20261025/run.log | 19766c06fb0c118a5c603f131044676f61bf31fcec27f6bcac684709d880e91e |
| Seed 20261026 log | /tmp/nmaforge_r188_scalar_vdot_min_clean_3seed/seed_20261026/run.log | 1c4bf41cf6ae9f8cf94cc2958a412eb5ce64c71ad4ac43eecfeca3a650593b40 |
| Seed 20261027 log | /tmp/nmaforge_r188_scalar_vdot_min_clean_3seed/seed_20261027/run.log | 27f7b8fcac681da29846aff089bfd366cbafccd7afe909200f12a0068f5081d3 |
| URG merged functional groups | /tmp/nmaforge_r188_scalar_vdot_min_clean_3seed/urg_merged/groups.txt | 3a1c7544f5b4756da32dc6517695fbf08b6368176338fcbcb9fc4d73f866abab |
| Evidence archive | /tmp/nmaforge_r188_scalar_vdot_min_evidence.tar.gz | 2ebadac686043313ea4a20db7ef81236acaaab1acd6389ec67ad1c0ad433e6a |

No VCS Warning-, Error-, or TFIPC compile diagnostic was found. The archive contains the compile log, three seed logs, and merged URG group/dashboard/assertion summaries. Generated databases and logs remain under /tmp and are not checked in.

This adds only one minimum-size real-CMDQ testpoint. It does not characterize engine maxima or every field accepted by the validator. OPEN-CL-002 stays open; REQ-CL-002 and REQ-CL-020 remain PARTIAL. Overall disposition remains 24 PASS-SCOPED / 14 PARTIAL, and CL-DV-v1.0 remains HOLD.
