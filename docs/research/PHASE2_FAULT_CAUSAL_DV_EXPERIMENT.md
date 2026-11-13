# Phase 2 Fault-Causal DV Experiment

Date: 2026-11-13  
Candidate branch: `research/phase0-1-memory-dataflow-2026-11-13`  
Candidate SHA: `62733bd9f1fcd1735a080a75c6c0840d1d13fb94`  
Product RTL/ABI change: none

## Scope and contract

This is the first reproducible Phase 2 measurement on the exact Phase 1
candidate. V0 is the existing Compute Cluster UVM test and independent
scoreboard. It uses the production top, seven engines, compute SPAD mux,
arbiter, protection, and four-bank behavioral SPAD. No DUT arithmetic result
is used as a reference model.

The planned V1 additions are the transaction causality graph, explicit
request/response ownership, fault phase model, commit-prefix checker,
epoch/reset/abort model, requirement-guided cross generation, and mutation
guided selection. They are specified in `PHASE2_FAULT_CAUSAL_DV_SPEC.md` but
were not implemented in this run. Therefore no V1 improvement is claimed.

## Exact V0 run

Tool: Synopsys VCS/URG `V-2023.12-SP1_Full64`; UVM 1.2; coverage metrics
`line+cond+branch+fsm+assert`; seeds `20261025 20261026 20261027`.

```bash
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_phase2_v0_62733bd9
```

Result: `COMPUTE_CLUSTER_REAL_UVM_REGRESS_PASS`. Each seed has zero UVM
warning/error/fatal counts. The merged URG report is outside the repository at
`/tmp/nmaforge_phase2_v0_62733bd9/urg_merged`.

| Metric | V0 result | Interpretation |
|---|---:|---|
| Tests | 3 | exact seeds above |
| Total URG line/cond/FSM/branch/assert | 69.46% / 67.13% / 43.47% / 66.26% / 72.00% | full UVM hierarchy, not DUT-only |
| Engine pair bins | 21/21 | observed overlap mask `1fffff` |
| Focused compute cross | 100.0% applicable | completion-read is explicitly N/A |
| Scoreboard orphan responses | 0 | across each seed |
| Scoreboard reset-dropped responses | 43 | accounted by reset epoch behavior |
| Assertion properties | 22 total; 17 success; 5 uncovered | 2 without attempts; 0 failures |

Representative scoreboard counts are stable across seeds: 33,589 accepted
reads, 33,546 responses, 4,208 Matrix responses, 17,878 CNM responses,
pending `{0,0,0,0,0,0}`. The per-seed logs remain the authoritative evidence.

## Real DUT mutation campaign

The campaign mutates a temporary copy of one RTL file at a time and replaces
exactly one file-list entry. The product worktree is never modified.

```bash
python3.12 dv/uvm/sim/run_compute_cluster_dut_mutations.py \
  --out /tmp/nmaforge_phase2_mutations_62733bd9 \
  --seed 20261025 --timeout 600
```

Result: `COMPUTE_CLUSTER_DUT_MUTATION_PASS: 7/7 real RTL mutants caught`.
The mutation set and observed checker are recorded in
`benchmark/research/phase2_fault_causal/RESULTS.csv`.

This is a V0 detection baseline, not a V1 comparison. Tests-to-target,
runtime-normalized detection, false positives, held-out regression, and
causal-edge coverage are `NOT_MEASURED` until a V1 selector/checker is added
without changing the DUT, mutation set, seed budget, or simulator options.

## Disposition

Phase 2 methodology: **REWORK**. The existing V0 is useful and detects the
current seven mutants, but the paired V0/V1 experiment required to support a
methodology claim does not yet exist. Keep the independent Golden, assertions,
fault/reset checks, and existing mutation campaign. Implement the causal graph
and requirement-guided selector next, then rerun this exact campaign and a
held-out mutation set.

## Reproduction evidence

The raw VCS/URG and mutation logs are retained outside the repository at the
paths above. The source candidate is reproducible with:

```bash
git checkout 62733bd9f1fcd1735a080a75c6c0840d1d13fb94
git status --short --branch
git diff --check
```

No PR was merged and no product branch was changed.
