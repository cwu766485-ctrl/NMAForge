# Fault-Causal DV V1 Implementation Status

Round 5 does not claim a completed V1 methodology improvement. The executable
research top now provides the first V1-compatible evidence hooks:

- transaction-level accepted/response/denied counters;
- explicit output write and Matrix Line commit events;
- configurable fault phase inputs;
- epoch abort and dropped-response observation;
- independent Host memory probes for Golden checking;
- non-vacuous local ownership/commit SVA.

The full V0/V1 mutation comparison remains `NOT_MEASURED`. A valid follow-on
experiment must add a new mutation set and held-out set, run the same DUT and
simulation budget, and report detection rate, tests-to-detection, runtime,
coverage closure, false positives, and held-out detection. The prior 7/7 V0
campaign is not used as evidence of V1 improvement.
