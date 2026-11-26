# NMAForge V1.2 P0 Baseline and Fixture Recovery

**Run ID:** `NMAFORGE-V1.2-P0-C668479-20261124`
**Research branch:** `feat/shape-adaptive-gemv-v2`
**Tested source commit:** `c668479570e182e833146fd4a5f1d15bd06daf6c`
**Source tree:** `b883b40a1ae5a630934160820f17041a9237e7b4`
**Product RTL tree:** `b969dd80ceceb23e086df423515993353092b5ca`
**ABI:** current SPEC ABI v7.4; no ABI change
**Model package:** none loaded; `model_hash=null`
**Tools:** VCS `V-2023.12-SP1_Full64`, URG `V-2023.12-SP1`, VC Formal `V-2023.12-SP2`, Python `3.12.13`

This report records P0 evidence for fixture recovery, configured SPAD capacity,
top smoke, and historical compute-shape replay. The source change is confined
to UVM fixture allocation and test configuration. Product RTL, register ABI,
protection checks and protection policy were not changed. This is not full
NMAForge V1.2 closure.

## Reproducibility package

The machine-readable [`run_manifest.json`](../../benchmark/representative/v1_2/p0/run_manifest.json)
pins the source identities, commands, configurations, exit codes and 53 raw-log
artifacts. Each compressed log and its uncompressed contents have SHA-256
digests in the manifest. The logs are stored under
[`benchmark/representative/v1_2/p0/logs`](../../benchmark/representative/v1_2/p0/logs).
The historical performance rows are in
[`historical_compute_profile.csv`](../../benchmark/representative/v1_2/p0/historical_compute_profile.csv).

## P0 results

### `CLUSTER_MEMORY_EMPTY` and capacity-aware map

The failure was replayed at historical source SHA
`f919bb787dab1a4e3bef44b5308ead56d6e77b72`:

```sh
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS=20261025 \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v1_2_repro_f919_captured
```

Exit code was **2**. Before an engine transaction, a SPAD write to `0x7d000`
returned AXI-Lite `SLVERR`; the fixture had been laid out for a larger memory
than the top's default 128 KiB SPAD. The scoreboard consequently had no returned
compute words to compare. This was an address/configuration mismatch, not a
protection failure.

The fix adds a parameterized UVM memory map. The sequence reads `SPAD_INFO` at
`0x164`, allocates 46 aligned regions from `0x1000`, checks capacity and
pairwise disjointness, and rejects allocation if the map does not fit. For the
tested workload the end is `0x9740`, which fits all tested capacities. The test
top accepts `SPAD_KIB=128|256|512` and configures the corresponding words per
bank (8192, 16384 or 32768). No range/protection condition was weakened.

The real Product Top Compute Cluster UVM regression was run at each capacity:

| SPAD capacity | Seeds | Result | Per-seed memory checker | Focused coverage |
|---:|---|---|---|---|
| 128 KiB | 20261025, 20261026, 20261027 | PASS, exit 0 | 5,094 writes; 5,368 checked words; 0 mismatch, unknown, stale or orphan | 100% applicable; completion read is N/A |
| 256 KiB | 20261025, 20261026, 20261027 | PASS, exit 0 | Same counts and zero-error disposition | 100% applicable; completion read is N/A |
| 512 KiB | 20261025, 20261026, 20261027 | PASS, exit 0 | Same counts and zero-error disposition | 100% applicable; completion read is N/A |

Command template, run from `dv/uvm/sim`:

```sh
for kib in 128 256 512; do
  make uvm_compute_cluster_regress SPAD_KIB="$kib" \
    COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
    COMPUTE_CLUSTER_UVM_OUT="/tmp/nmaforge_v1_2_spad${kib}_c668479"
done
```

All nine seed runs have UVM WARNING/ERROR/FATAL = `0/0/0`. The focused group
reports `cpl_read:0(N/A)` because the completion writer is write-only; this bin
is dispositioned as architectural N/A, not counted as covered. The 100% figure
is only for the applicable focused compute group, not whole-design closure.

### Product Top smoke and seeded regression

Run from `dv/subsystem/top_smoke/sim`:

| Command | Exit | Result |
|---|---:|---|
| `make ai_smoke AI_RANDOM_CASES=4 AI_SEED=12345 SEED=20261124` | 0 | `TEST PASS` |
| `make ai_run AI_RANDOM_CASES=20 AI_SEED=12345` | 0 | `TEST PASS`, 20 seeded cases |

The smoke compile retains the existing VCS `[LOOP-REROLL-ENABLED]` fixture
diagnostic. The raw logs and compile log are archived separately. This UVM
fixture change did not modify the Product RTL tree.

## Historical compute replay and cycle explanation

The requested shape replay was performed in a detached worktree at source SHA
`49441dfafa130731c822c43bf2e500023e58423c`. The operands, 16×16 array and Golden were held constant within each
paired run. These are Matrix-core testbench windows with operands resident in
behavioral SPAD; host layout, DDR transfer and runtime overhead are not timed.

| Shape / profile | Cycles | Useful MAC/cycle | Read bytes | Output bytes | Bank / line stalls | Golden |
|---|---:|---:|---:|---:|---:|---|
| GEMM 64×64×64, fixed one-cycle SPAD | 3,413 | 76.808 | 20,480 | 16,384 | 0 / 0 | 4,096 words PASS |
| GEMM 64×64×64, seeded ready/line backpressure | 4,822 | 54.364 | 20,480 | 16,384 | 538 / 371 | 4,096 words PASS |
| GEMV 1×64×64, prefetch off | 632 | 6.481 | 4,352 | 256 | 0 / 0 | 64 words PASS |
| GEMV 1×64×64, prefetch on | 584 | 7.014 | 4,352 | 256 | 0 / 0 | 64 words PASS |

The 1,409-cycle GEMM delta is from comparing two different behavioral memory
service profiles: fixed always-ready one-cycle responses versus seeded request
ready/line backpressure. It is not a change to the arithmetic workload or RTL.
For GEMV, prefetch reduced the window by 48 cycles (7.6%) with unchanged traffic
and no recorded bank/line stalls. GEMV's 4,096 useful MACs took 584–632 cycles,
while GEMM's 262,144 MACs took 3,413–4,822 cycles: the M=1 workload poorly
utilizes a 16×16 array and has four legal product descriptors, while GEMM fills
the array more effectively. This comparison is specific to the recorded
Matrix-core endpoint.

These rows are **historical SHA-bound evidence**, not current Product Top
measurements. The current branch's tensor Matrix path does not contain the
historical folded GEMV opcode `0x52` mapping. The TinyNPU direct-array figures
from the old Round 27 report are not compared here: their timing endpoint omits
controller/SPAD service. No system speedup or host-inclusive latency claim is
made. The raw profile and paired logs are in the CSV and
`logs/historical_round27/`.

## DV testpoint mapping delta for this run

The complete `REQ-CL-001..028` / `REQ-PC-001..010` mapping and prior dispositions
remain in the [Compute Cluster Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md).
This table adds only evidence from source SHA `c668479`; it does not transfer
results from other source SHAs or close requirements beyond the named tests.

| Requirement(s) | This run's testpoint / checker | Current evidence and limit |
|---|---|---|
| REQ-CL-001/002/012/015 | `CLUSTER_ALL_ENGINES_PASS`; observed launch, per-engine expected result/completion checks | Seven production engines ran representative cases; not the full opcode/config/numeric cross. Expectations reside in one sequence and one shared memory scoreboard, not seven independently instantiated Golden/scoreboard components. |
| REQ-CL-006/014; REQ-PC-006 | `CLUSTER_REQUEST_STABILITY_PASS`; ready/valid stability checks and stalled-request mask | Selected stalls and subsequent progress passed. No exhaustive fairness/bound or all requester × protection/error × backpressure cross. |
| REQ-CL-007/008/016 | `CLUSTER_MEMORY_SCOREBOARD`; accepted-read owner/epoch ledger and independent SPAD image | 5,368 words/seed, no mismatch/unknown/stale/orphan. This does not replace full legal owner × fault × phase testing. |
| REQ-CL-009/021; REQ-PC-007 | `CLUSTER_CNM_OWNER_PASS`, `CLUSTER_CNM_ADDR_PASS`; lane and tag checks | Four CNM lanes and selected Matrix/CNM responses overlapped. Matrix line WSTRB observed only full masks; partial/zero semantics remain open. |
| REQ-CL-010/022 | `CLUSTER_A_CACHE_BASELINE_PASS`; standalone 16×32×64 Matrix Golden and 16 A-tile reuse hits | Golden and cache reuse passed. Full Matrix mode/layout and partial Line WSTRB closure remains separate. |
| REQ-CL-011/013 | 25-case checker-sensitivity mutation campaign | Address/data/owner/WSTRB and Done/missing-Done/duplicate-Done observation mutations were caught. Mutations alter passive monitor observations, not DUT RTL. |
| REQ-CL-017/019/027 | `CLUSTER_RANDOM_FAULT_CROSS_PASS`; 14 parity cases | Selected INT8/Matrix/CNM/BF16 operand-phase parity cases passed. Protection injection and the full Engine × Fault × Phase × Reset/error-prefix matrix were not covered by this run. |
| REQ-CL-018; REQ-PC-009/010 | `CLUSTER_ABORT_CROSS_PASS`, `CLUSTER_RESET_RECOVERY_PASS`, `CLUSTER_ENGINE_RESET_PASS` | Selected multi-engine abort, Matrix/SFU reset recovery, and accepted-read reset across seven engines passed. External-fabric qualification and full reset/fault cross remain open. |
| REQ-CL-020..026 | `CLUSTER_ALL_ENGINES_PASS`; per-engine operation Golden points | Representative INT8, CNM, Matrix, SFU, Conv, KV and Mixed-FP operations passed. Detailed opcode/shape boundaries remain as dispositioned in the RTM. |
| REQ-CL-028 | `CLUSTER_SERIAL_BENCH_PASS`, `CLUSTER_STAGED_BENCH_PASS`, `CLUSTER_PARALLEL_BENCH_PASS`, `CLUSTER_RECOVERY_BENCH`; separate historical CSV | Selected top cycle windows and the historical Matrix profiles are recorded. Not a unified Matrix/CNM/GEMV/SFU/DMA/SPAD profile, no CNN fusion A/B, no same-model TinyNPU comparison and no physical PPA. |
| REQ-PC-001..005/008 | Existing dispatcher testpoints in the RTM; selected staged completion order in this run | This run does not re-cover all 21 production-datapath pairs, all same-engine queue/full-completion cases, simultaneous Done, or the full shared-read-only matrix. Keep previous SHA-bound results separate. |

Coverage, assertion/formal, and mutation evidence are separate:

- **Functional coverage:** 100% of the applicable focused group for each run;
  completion reads are N/A. No full design coverage claim.
- **Formal:** `make -C dv/subsystem/tensor_datapath/formal run
  OUT=/tmp/nmaforge_v1_2_cluster_formal_c668479 TIMEOUT=300` exited 0. VC Formal
  proved 3/3 dispatch/ownership assertions and reached 7/7 engine-dispatch
  covers. The harness reports an unresolved/black-boxed Matrix array and port
  connection warnings; arithmetic, SPAD arbitration, DMA and full-top behavior
  are outside this proof scope. Disposition: `PASS_SCOPED`.
- **Mutation:** `make uvm_compute_cluster_mutation SPAD_KIB=512
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v1_2_spad512_c668479
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_v1_2_cluster_mutation_c668479`
  exited 0 with 25/25 expected catches. This is checker sensitivity, not an RTL
  mutation score.

## Remaining V1.2 work

- Fix the current-source performance endpoint for GEMV 1×64×64 and capture
  identical workload counters across Matrix, CNM, SFU, DMA and SPAD arbitration;
  add host/DMA/command/compute timing boundaries and CNN fusion A/B.
- Locate and pin a genuine FP32 GPT-2 checkpoint plus a separate evaluation
  dataset; complete per-operator precision ablation, hardware-aware QAT,
  Product Top full logits and four-layer persistent-KV versus prefix-recompute
  equivalence/performance.
- Continue DeiT from the proven Round 30 three-head/197-query path; complete
  Head Merge through GELU and one uninterrupted Product Top Encoder Layer 0
  without host activation refill, then twelve layers/final LN/classifier and
  official-weight real-image accuracy.
- Split the shared expected-value/memory-checking structure into seven
  independently traceable engine Golden/scoreboard paths, add legal protection
  and owner/fault crosses, and keep coverage/assertion/formal/mutation records
  separate. External-fabric reset, broader requirement closure and ASIC
  synthesis/PPA remain open.
