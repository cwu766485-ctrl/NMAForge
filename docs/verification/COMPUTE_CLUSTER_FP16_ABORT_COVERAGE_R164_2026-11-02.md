# Compute Cluster FP16 Abort Functional Coverage — R164

**Date:** 2026-11-02  
**Exact test SHA:** `db7588be34200ac68ac66072799adca54ad287a5`  
**Tree:** `e0816beba67133fbf6221005f16f97cba63eb2ca`  
**Product RTL/SPEC:** unchanged; product baseline `c4b3b4f676a7ffb5e264d88fca6bb7c9b374a413`, Compute Cluster SPEC v1.8.  
**Tools:** Synopsys VCS/URG `V-2023.12-SP1_Full64` / `V-2023.12-SP1`, UVM 1.2, behavioral SPAD (`+define+VCS`).

## Result

FP16 opcode `0x51` accepted-read Abort now has a real URG covergroup and mandatory regression gate. The coverpoint is sampled only after the production-top test checks accepted-read drain, task/error completion, legal one-word FP32 output prefix, full sentinel region, and no output handshake after Abort sampling.

| Evidence | Result |
|---|---|
| Seeds | `20261025`, `20261026`, `20261027` |
| Accepted / returned FP16 reads | `4 / 4` per seed |
| Completion | task `0x0767`, `ERR_ABORT` / `0x32` |
| Legal FP32 result prefix | `0/1`; eight sentinel words preserved |
| Post-Abort output writes | `0` per seed |
| Dedicated URG bin | `verified_zero_prefix`: 3 hits, `1/1`, `100.00%` |
| Focused `cluster_cg` | `64/64`, `100.00%` |
| Compute Cluster sequence-level functional groups | `9/9` at `100.00%` (including the new FP16 group) |
| Independent memory scoreboard | `68,712` words per seed; zero mismatch, unknown read, stale epoch, or orphan response; pending ledgers empty |
| UVM warning / error / fatal | `0 / 0 / 0` per seed |
| Checker-sensitivity campaign | `28/28` assigned-checker probes caught |
| Top Smoke / seeded top | `TEST PASS`; 20 random cases with `AI_SEED=12345` pass |

The merged URG report contains 17 total groups. Its raw all-group score is `66.93%`; the total dashboard score is `62.94%` (line/condition/FSM/branch/assert/group: `69.74/63.99/44.85/60.10/72.00/66.93%`). Five DMA/AXI responder groups have no hits in this compute-only UVM workload; AXI4 and AXI-Lite groups are `50.28%` and `87.50%`. These raw mixed UVM/code groups are not the Compute Cluster functional testpoint percentage. The named Compute Cluster functional groups above are all 100%; this does not close every RTM requirement or the full subsystem AXI verification scope.

The 28 mutations are passive-observation checker-sensitivity probes, not DUT fault injection or an RTL mutation score. No requirement is promoted: the 38-row RTM remains `24 PASS-SCOPED / 14 PARTIAL`, and `CL-DV-v1.0` remains **HOLD**.

## Exact-SHA replay

All runs used a detached clean worktree at the SHA/tree above. Commands:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r164_clean_db7588b/uvm

make -C dv/uvm/sim uvm_compute_cluster_mutation \
  VCS_HOME=/opt/Synopsys/vcs/V-2023.12-SP1 \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r164_uvm_mut_compile \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r164_mutations

cd dv/subsystem/top_smoke/sim
make ai_smoke
make ai_run AI_RANDOM_CASES=20 AI_SEED=12345
```

The regression gate passes on all three seeds. URG reports the new bin as `100.00%`, with bin hit count three. Top Smoke retains the existing fixture diagnostic `[LOOP-REROLL-ENABLED]`; simulation prints `TEST PASS`.

## Evidence archive

Logs-only archive (UVM, mutation, Top Smoke and Matrix logs, URG text reports, and benchmark CSV; excludes VDBs and simulator binaries): `/tmp/nmaforge_r164_evidence_logs.tar.gz`  
SHA-256: `c784ba44f8e1af5ad0c793fcf644b78ae855d457192825f806fb8552bec1fada`

The Matrix benchmark is separately summarized in [R164 benchmark report](../benchmark/COMPUTE_CLUSTER_MATRIX_BENCHMARK_R164_2026-11-02.md).
