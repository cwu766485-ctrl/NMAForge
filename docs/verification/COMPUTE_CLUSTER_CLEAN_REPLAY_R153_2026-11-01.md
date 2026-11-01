# Compute Cluster clean-candidate replay — R153 — 2026-11-01

## Candidate and result

The replay uses the exact real-top UVM code/test candidate SHA
6e47629f103e3ab36948c5bb4eadc196cd27dfb4, tree
21478d7e4a595e17b27f7b0e89810d3617a4fd82. Its published test-content
commit is 79b84addfb870aa96ef99e5ccff9d4f1b2dba0af, with the same tree.
Synopsys VCS V-2023.12-SP1_Full64 and UVM 1.2 were used.

| Run ID | Command / scope | Result |
|---|---|---|
| R153-UVM-CLUSTER-BENCH-3S-20261101 | Three-seed real-top Compute Cluster UVM regression; see [benchmark report](../benchmark/COMPUTE_CLUSTER_REAL_TOP_BENCHMARK_R153_2026-11-01.md) | PASS for 20261025/26/27; UVM severity 0/0/0; each memory scoreboard checks 63,597 words with zero mismatch, unknown reads, or stale epoch |
| R153-TOP-SMOKE-20261101 | Top Smoke, fixed simulator and AI seeds, four random cases | PASS; mapper precheck reports 86 descriptors and 60 tensors |
| R153-TOP-REGRESS-20-20261101 | Top regression, fixed simulator and AI seeds, 20 random cases | PASS |
| R153-CHECKER-MUTATION-28-20261101 | Address, Data, Owner, WSTRB, Completion Error Code, Write-after-Error, Response Epoch and Done/Missing-Done/Duplicate-Done on all seven engine bits | PASS, 28/28 expected checker catches; target checks both injected/caught markers and expected checker identity |

Commands, run from the indicated directories:

    make -C dv/uvm/sim uvm_compute_cluster_regress COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r153_final_clean/uvm COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'
    cd dv/subsystem/top_smoke/sim && make ai_smoke SEED=20261025 AI_RANDOM_CASES=4 AI_SEED=12345
    cd dv/subsystem/top_smoke/sim && make ai_run SEED=20261025 AI_RANDOM_CASES=20 AI_SEED=12345
    make -C dv/uvm/sim uvm_compute_cluster_mutation COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_r153_top_clean/uvm_mutation COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_r153_top_clean/mutation

The Top Smoke compile retains the existing VCS Warning-[LOOP-REROLL-ENABLED].
The mutation runs intentionally generate UVM checker errors as evidence of
catching the injected passive-observation mutation; the campaign target
returns PASS only when all expected catch markers and checker names are found.
No RTL or SPEC changed in this replay.

## Evidence and limits

The logs-only archive is
/tmp/nmaforge_r153_clean_replay_logs.tar.gz, SHA-256
04002a6b96c1c23233a3abd299c9b8ef1701532b4b250d685212bf1712097b7b.
It includes compile logs, Top Smoke and 20-case logs, plus all 28 mutation
logs and a SHA256SUMS manifest; simulator binaries and coverage databases are
excluded.

This replay validates only its named scenarios. It does not turn the current
24 PASS-SCOPED / 14 PARTIAL RTM into full closure, and Compute Cluster v1.0
remains **HOLD**. The legal engine × fault × phase × reset/backpressure space
and remaining requirement clauses still require review or additional evidence.

The user-selected in-repository memory-fabric targets were also replayed on
this exact candidate tree: shared DMA/CNM reset, banked response reset,
Core/Banked contention, and Core/Banked reset. All four three-seed Make
targets pass with UVM severity 0/0/0; each named functional covergroup is
100%, and the exercised owner/tag assertions have real successes with zero
failures/incomplete. The testbench-driven requester limit is retained in the
[separate fabric replay report](COMPUTE_CLUSTER_MEMORY_FABRIC_CLEAN_REPLAY_R153_2026-11-01.md).
