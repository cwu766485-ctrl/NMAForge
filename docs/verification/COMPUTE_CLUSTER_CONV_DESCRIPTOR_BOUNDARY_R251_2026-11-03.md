# Compute Cluster Conv Descriptor Boundary Replay — R251

Date: 2026-11-03  
Disposition: **focused PASS; `REQ-CL-024` remains PARTIAL; `CL-DV-v1.0` remains HOLD**

## Fixed candidate and run

- Candidate commit: `81372a3aeed8bae23a561f71cb9689e7a5c92920`
- Source/test tree: `19b49b2714cc7c98f546890884648ece2685a164`
- Parent: published R250 `3041355528dffe856e2d5384027c6ee5df5d1b42`
- Clean replay worktree: `/tmp/nmaforge_phasea_r251_clean`
- Run ID: `R251-UVM-CONV-BOUNDARY-CLEAN-3S-20261103`
- Seeds: `20261025`, `20261026`, `20261027`
- Tools: Synopsys VCS and URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`
- Exact command, from `dv/uvm/sim`:

```bash
make uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r251_clean_replay_81372a3_3seed \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1
```

The target exited 0 after compiling the UVM environment, running all three full Compute Cluster seeds, checking the existing regression markers (including the new Conv-boundary markers), and merging coverage with URG. The clean worktree was unmodified at replay. Compilation produced no `Warning-`, `Error-`, `TFIPC`, or Fatal diagnostics. Each run reports UVM Warning/Error/Fatal `0/0/0`.

## Added legal testpoint

`TC-CL-R251-CONV-DESC-SHAPE-BOUNDARY` drives the production command queue with Conv opcode `0x16` and the frozen v1.5 low-byte signed-INT8, 3×3, stride-1, valid/no-padding contract:

| Case | Descriptor M×N×K | Output words checked | Result |
|---|---:|---:|---|
| Minimum legal shape | 3×3×9 | 1 | Full independent signed INT32 Golden, completion and both adjacent sentinels pass |
| Default maximum width | 3×128×9 | 126 | Full independent signed INT32 Golden, completion and both adjacent sentinels pass |

Each seed observes exactly two Conv launches with the expected descriptor snapshot, two ordered completions with matching task IDs/result/element count, 127 output words checked against the software convolution model, and unchanged guard words around both output regions. `conv_descriptor_boundary_cg` reports `minimum_3x3=3`, `maximum_width_3x128=3`, 2/2 bins and 100.00% merged coverage. The full-run scoreboard reports zero orphan responses and zero pending owners on all three seeds.

The per-seed run logs contain both `[CLUSTER_CONV_DESCRIPTOR_BOUNDARY_PASS]` and `[CLUSTER_CONV_DESCRIPTOR_BOUNDARY_COVERAGE_PASS]`. The UVM regression also retained its seven-engine overlap, fault/reset, completion-backpressure, and existing coverage checks.

## Traceability and limits

This test adds descriptor-to-engine evidence for `REQ-CL-002/015` and minimum/max-width functional evidence for `REQ-CL-024`; the complete Golden image check also contributes to `REQ-PC-006`. All four remain `PARTIAL`. It tests Conv opcode `0x16`, with height fixed at the legal minimum. It does not close Depthwise opcode `0x17`, general height limits, descriptor stride/alias/overflow contracts, all formats/layouts, or the broader engine × fault × phase × reset × backpressure matrix. No raw RTL coverage or global requirement-closure claim is made. Overall RTM remains 24 scoped pass dispositions / 14 `PARTIAL`.

## Evidence artifacts

Run directory: `/tmp/nmaforge_r251_clean_replay_81372a3_3seed`

- Compile log SHA-256: `9fe7f803fb815eb01a8feaf9772bc368c50d7127e90aa23999648ac19a27fa14`
- Seed 20261025 log SHA-256: `82ddecd416e99d0211951089bbf59a3a93d673d6fbc09d158d15b56636123b86`
- Seed 20261026 log SHA-256: `ccaa6f5a8d161f1c84c721c49793fb69815d6e5d3d4222a4ebc91bff4c734e54`
- Seed 20261027 log SHA-256: `6e7b7b01c79d4349df8631d31e30b9139d2d2eb9d0316f187f99680893919e40`
- URG merged log SHA-256: `f0137cd5f1e30bf5ab1b65bcada91fea28f469b63f372d06146f2f665030ee0b`
- Logs-only archive: `/tmp/nmaforge_r251_evidence/R251_clean_replay_logs.tar.gz`
- Archive SHA-256: `c7c518f397f2e92058ef9fdb96e2ec6a07b96e7265b8aafb5cd7d2210b12aef3`

Generated simulator and coverage databases remain outside the repository.
