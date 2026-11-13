# Fault-Causal V0/V1 Comparison

V0 from the preceding candidate campaign caught 7/7 simple real RTL mutants.
That result cannot establish a V1 benefit. This sprint adds the BPF-TE
primitive checks, but the full UVM causal graph, ownership tracker, phase-aware
scoreboard, commit-prefix checker, requirement-guided generator, and
mutation-guided selector are **NOT_IMPLEMENTED** in the product UVM.

| Measure | V0 | V1 |
|---|---:|---:|
| Mutation set | 7 simple mutants | NOT_MEASURED |
| Detection | 7/7 | NOT_MEASURED |
| Tests to detection | 1 seed campaign | NOT_MEASURED |
| Runtime | NOT_NORMALIZED | NOT_MEASURED |
| Coverage closure | mixed UVM URG baseline | NOT_MEASURED |
| False positives | 0 observed | NOT_MEASURED |
| Held-out detection | NOT_MEASURED | NOT_MEASURED |

The next valid experiment must use the same DUT, budget, simulator options,
and a harder mutation training/held-out split. No methodology claim is made.
