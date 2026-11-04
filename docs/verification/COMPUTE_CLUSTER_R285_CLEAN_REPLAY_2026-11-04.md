# Compute Cluster R285 Clean Replay — 2026-11-04

## Result

The latest published closeout candidate reproduced the real seven-engine Cluster UVM, selected in-repository memory-fabric reset, Top Smoke, 20-case seeded Top regression, and actual RTL mutation campaign. The runs used the license-enabled VCS environment.

This is a reproducibility update, not a new functional-coverage campaign. The 38-row RTM remains 27 PASS-SCOPED and 11 PARTIAL; CL-DV-v1.0 remains HOLD.

## Identity

| Item | Value |
|---|---|
| Published closeout input SHA | b61c039bbd9c0515677d34ce178ce219f835d174 |
| RTL/test source identity | 08111970888ae8d84a956827389cd41133baa235 |
| RTL/test tree | 0d6f21126899257d7e7677f3f03d1485692a4ef3 |
| Product RTL/SPEC | Unmodified from the published candidate; this replay changed no source |
| Simulator | Synopsys VCS / URG V-2023.12-SP1_Full64 |
| Evidence archive | /tmp/nmaforge_phasea_b61_r285_evidence.tar.gz |
| Archive SHA-256 | 1b247fb1f90bd9651f314426bbdbe20b39546632fd71adee8dec1fbfa401885e |

The verification source tree at 08111970888ae8d84a956827389cd41133baa235 is byte-identical to the RTL, DV, tools, and SPEC inputs at the published closeout SHA above. The R285 documentation commit is therefore a documentation-only descendant of the executed candidate.

## Commands and results

### Real seven-engine UVM

Command:

    make -C dv/uvm/sim uvm_compute_cluster_regress \
      COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_phasea_b61_r285_clean_3seed \
      VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
      COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

All three seeds pass. Each seed reports UVM severity 0/0/0, checks 146,755 Memory Image words with zero mismatch/unknown/stale, and ends with 10,678 accepted reads, 10,658 checked responses, 20 reset-dropped requests, zero owner/data/error mismatch, and no pending responses. The Memory Scoreboard records 89,832 writes per seed. The required real-top PASS marker is present for every seed. The UVM compile log contains no Warning-, Error-, TFIPC, or Fatal diagnostics.

### Selected memory fabric reset and epoch

Command:

    make -C dv/subsystem/dma_spad/sim subsystem_memory_fabric_reset_regress \
      VCS=/opt/Synopsys/vcs/V-2023.12-SP1/bin/vcs \
      URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg \
      MEMORY_FABRIC_RESET_OUT=/tmp/nmaforge_phasea_b61_r285_memory_fabric_reset \
      MEMORY_FABRIC_RESET_SEEDS='20261025 20261026 20261027'

All three seeds pass through the in-repository ai_accel_memory_fabric. Reset is sampled with a pending accepted SPAD response, the old owner is flushed, DMA/CNM work recovers, and all three declared reset functional groups reach 100%. This qualifies the selected repository fabric path; it does not qualify arbitrary external AXI fabrics.

### Top integration

Commands:

    make -C dv/subsystem/top_smoke/sim ai_smoke
    make -C dv/subsystem/top_smoke/sim ai_run AI_RANDOM_CASES=20 AI_SEED=12345

Both commands print TEST PASS. The mapper precheck covers 86 descriptors and 60 tensors. The existing fixture warning LOOP-REROLL-ENABLED remains visible in the Top Smoke compile.

### Actual RTL mutation campaign

Command:

    make -C dv/uvm/sim uvm_compute_cluster_dut_mutation \
      COMPUTE_CLUSTER_DUT_MUTATION_OUT=/tmp/nmaforge_phasea_b61_r285_dut_mutation \
      VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1

All 7/7 temporary RTL mutants are caught by their assigned checker: address, data, response owner, Matrix WSTRB, completion error code, missing Done, and duplicate Done. The mutation run uses temporary source copies under /tmp and does not modify product RTL.

## Sign-off status

The current 11 PARTIAL requirements are:

- REQ-CL-006, REQ-CL-010, REQ-CL-014, REQ-CL-015
- REQ-CL-017, REQ-CL-018, REQ-CL-019, REQ-CL-027, REQ-CL-028
- REQ-PC-006, REQ-PC-007

The most consequential remaining items are the broader legal requester/stall/fault/phase/reset crosses, Matrix outstanding-response integration with its documented FSM disposition, per-opcode numeric Golden breadth through real CMDQ, and engine/fault-specific error ownership and prefix evidence. The R281 Matrix review retains 49/53 raw transitions in the default enabled profile; five formal guards are proven and two state covers hit, while the legal prefetch-disabled fallback is separately exercised. No illegal state was forced to inflate coverage.

R285 does not promote any requirement. It confirms the published candidate is reproducible and its targeted checkers remain sensitive; the unclosed clauses still prevent Functional DV exit. The detailed Requirement → Testpoint → Coverage → Run ID → Seed → Evidence mapping remains in the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md).

## TinyNPU distance

The latest paired comparison is [R273](../benchmark/COMPUTE_CLUSTER_TINY_NPU_MATCHED_CONTROLLER_R273_2026-11-04.md), using pinned TinyNPU SHA 8216c22b762011aa20c05fc2768423fd12dda59d:

| Workload | NMAForge cycles | TinyNPU comparison endpoint | Difference |
|---|---:|---:|---:|
| 16×16×16 INT8 GEMM | 152 | 151 modeled cycles | NMAForge 0.7% slower |
| 16×16×32 INT8 GEMM | 231 | 231 modeled cycles | parity |
| 32×32×64 INT8 GEMM | 1,198 | 1,305 modeled cycles | NMAForge 8.2% fewer cycles |

NMAForge passed all 4,608 output checks over three seeds. For 32×32×64 it reads 6,144 bytes versus 4,096 bytes in TinyNPU's modeled schedule. TinyNPU's array cycles were measured from its RTL, but the comparison endpoint adds serialized memory service assumptions because its wrapper exposes no comparable SPAD request/response interface. This is near-parity evidence with a model-dependent large-shape result, not a demonstrated same-memory-service win. GEMV/decode, matched CNN, trained-model inference comparison, and comparable PPA remain unmeasured.
