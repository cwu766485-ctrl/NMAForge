# Architecture-first Gate 0 evidence

This inventory is deliberately evidence-first. It combines the Phase 4 approved
baseline/candidate replay, the checked-in seeded Matrix/GEMV campaign and the
research SPAD wrapper only with provenance labels. It does not run or modify RTL.

```bash
python3.12 tools/benchmark/phase4/validate.py
python3.12 tools/benchmark/arch_opt/generate_gate0.py
```

`baseline_bottlenecks.csv` contains exact measured rows and explicit `NOT_RUN`
rows for requested shapes absent from the checked-in product Top evidence. The
research wrapper is not a product Top claim. `architecture_opportunity_ranking.csv`
separates measured gains from candidates requiring a new closed-loop model.
