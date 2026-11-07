# NMAForge v2 Model Benchmark

## Round 10 current-source replay — 2026-11-08

At reviewed source SHA `1cd1bde4d82c457d445f97a7817fc22d407b528b`, the RTL,
software, and test code is unchanged from tested code snapshot
`13f94abf59c3dbea833ad4bbe227ef5cab4df503`. Fresh 396-sample Digits CNN
replays match its fixed model/testset hashes and pass every intermediate and
logit Golden in Legacy, fused-native, and Linear-Row modes. They retain
384/396 (96.9697%) classification accuracy. Measured CMDQ cycles/image are
3,193 / 2,712 / 2,712; testbench-accounted layout intervals are 1,080 / 1,080
/ 0 cycles. The layout interval is not measured host CPU time. Round 10 also
reran the `conv1x_mini.onnx` three-mode ablation and TinyNPU graph smoke; all
model and endpoint details are in the
[Round 10 report](NMAFORGE_V2_ROUND10_ARCHITECTURE_PERFORMANCE.md) and
machine data is in [`Round 10 CNN CSV`](../../benchmark/v2_round10_cnn_ablation.csv).

Round 10 did not produce a representative model: current Transformer mapping
rejects H=16 weights because it requires 4×4 matrices, and neither checked-in
CNN workload reaches 100K useful MAC per inference. The H=4 toy Transformer
remains historical functional/performance evidence only. No H=16 SFU claim,
large CNN utilization claim, or model-level GEMV gain is established.

## Round 7 trained CNN dataflow recheck — 2026-11-07

The trained 10-class CNN was run in three modes on the exact same 396 held-out
samples and fixed trained INT8 weights. Testbench SHA
`7e64344fbb9bdaed0fd4ce14e8cddb19231827f7`, harness SHA
`30ef28b973343acd25ebd62d4df8576c84e8ffb1`, product RTL SHA
`cd0a05d8ecd8cfb6c3f39b559788a2531e324b23`, seed `20261107`, VCS
`V-2023.12-SP1_Full64`. Model SHA-256 is
`ef0e616d09ca0be7956fa8ca900e40c62973f8f06e3ec96af09d888eead73726`;
held-out-set SHA-256 is
`cb851b077542f9bcf42f84938227ba5f1a4750ea0b0fbfe2ba8fcecbb914d107`.

| Mode | CMDQ compute cycles / image | Layout cycles / image | SPAD bytes read / written per image | Top checks | Classification |
|---|---:|---:|---:|---:|---:|
| Legacy | 3,193 | 1,080 | 6,192 / 2,496 (including layout traffic) | 396/396 exact | 384/396 (96.97%) |
| `0x53` fused requant, native Matrix-A layout | 2,712 | 1,080 | 5,616 / 1,920 | 396/396 exact | 384/396 (96.97%) |
| `0x53` fused requant + Linear-Row | 2,712 | 0 | 5,472 / 1,776 | 396/396 exact | 384/396 (96.97%) |

The native-layout mode verifies the middle rung: its fused compute path saves
481 command cycles/image while leaving the same separately modeled layout
phase. Linear-Row then removes that 1,080-cycle phase with 288 additional
bytes read and 144 fewer bytes written than the fused-native path for this
model. The resulting same-harness phase interval is 2,712 vs 4,273 cycles
(1.576×); it is not a full application or TinyNPU system speedup. Useful work
is 2,736 MAC/image. The measured command-window rate rises from 0.857 to
1.009 useful MAC/cycle; this is not active-cycle array utilization. All three
paths preserve exact per-sample intermediate and output Goldens.

Machine-readable aggregates:
[`v2_round7_cnn_fused_modes_20261107.csv`](../../benchmark/v2_round7_cnn_fused_modes_20261107.csv).
Raw 396-row result CSVs and per-sample VCS logs remain outside Git under
`/tmp/nmaforge_round7_10class_{legacy,fused_native,linearized}_s20261107/`;
the CSV SHA-256 values are respectively
`2d649cecf7e92d9a8bd825d62309c24a3685a08fe9fb4d96c2abbcdec22d1963`,
`4124aa1c88e75ee30356b089915303082ff092ea502d6cb5b3ae7d1e3623b3bc`, and
`1b3e0dcaa701a99ba180765cc5dd8bc44386e634b91600238656326f7635bb3d`.

The dataset replay used the VCS `V-2023.12-SP1_Full64` top binary compiled
from the checked-in `ai_accel.f` and `tb_ai_accel_smoke.sv` at testbench
snapshot `7e64344fbb9bdaed0fd4ce14e8cddb19231827f7`. The recorded compile
command was:

```sh
cd dv/subsystem/top_smoke/sim
vcs -full64 -sverilog -debug_access+all -kdb -timescale=1ns/1ps \
  +define+VCS +define+AI_SPAD_WORDS_PER_BANK=32768 \
  +define+AI_TINYNPU_CNN_SPAD_BASE_SHIFT=0 \
  +incdir+../../../block/control/agent \
  +incdir+../../../block/dma/agent +incdir+../fixtures \
  -Mdir=/tmp/nmaforge_round7_cnn_fused_native_s20261107/fixed/csrc \
  -top tb_ai_accel_smoke -f ai_accel.f \
  ../../../block/dma/env/axi_memory_model.sv ../tb/tb_ai_accel_smoke.sv \
  -o /tmp/nmaforge_round7_cnn_fused_native_s20261107/fixed/simv \
  -l /tmp/nmaforge_round7_cnn_fused_native_s20261107/fixed/compile.log
```

With that compiled binary available as `$SIMV`, the exact dataset replay
invocations are:

```sh
python3 benchmark/tinynpu/run_nma_cnn_demo_dataset.py \
  --simv "$SIMV" \
  --model benchmark/models/nma_tiny_cnn_10class/nma_tiny_cnn_demo_weights.npz \
  --testset benchmark/models/nma_tiny_cnn_10class/nma_tiny_cnn_demo_testset.npz \
  --candidate-sha 7e64344fbb9bdaed0fd4ce14e8cddb19231827f7 \
  --seed 20261107 --out-dir /tmp/nmaforge_round7_10class_legacy_s20261107

python3 benchmark/tinynpu/run_nma_cnn_demo_dataset.py \
  --simv "$SIMV" \
  --model benchmark/models/nma_tiny_cnn_10class/nma_tiny_cnn_demo_weights.npz \
  --testset benchmark/models/nma_tiny_cnn_10class/nma_tiny_cnn_demo_testset.npz \
  --candidate-sha 30ef28b973343acd25ebd62d4df8576c84e8ffb1 \
  --seed 20261107 --fused-native \
  --out-dir /tmp/nmaforge_round7_10class_fused_native_s20261107

python3 benchmark/tinynpu/run_nma_cnn_demo_dataset.py \
  --simv "$SIMV" \
  --model benchmark/models/nma_tiny_cnn_10class/nma_tiny_cnn_demo_weights.npz \
  --testset benchmark/models/nma_tiny_cnn_10class/nma_tiny_cnn_demo_testset.npz \
  --candidate-sha 7e64344fbb9bdaed0fd4ce14e8cddb19231827f7 \
  --seed 20261107 --linearized \
  --out-dir /tmp/nmaforge_round7_10class_linearized_s20261107
```

The output directories and compile logs are local run artifacts, not checked
into Git. The aggregate CSV retains the hashes and run IDs needed to verify
the archived sample tables.

The intermediate 0x53 native-layout mode is a testbench option that retains
the current output layout and performs the same explicit host layout phase.
The Linear-Row descriptor mode uses the existing bounded `0x53` row-write
logic; no product RTL changed in Round 7. This result applies to the tested
four-filter CNN and does not imply every consumer tensor can consume this
layout.

### Four-class mini CNN three-rung replay

The same `conv1x_mini.onnx` model, input SHA-256
`a74587bfcb5b2dfcd9eed1dbbb4fcf657628264c3b0aae7a4c278f0f70705898`,
Golden SHA-256
`94642359b0fdf8a4b56f8b17346b0385a477d782b4874bb7d1e979a589eab49c`,
seed `20261107`, and Top testbench pass in Legacy / fused-native / Linear-Row
modes. All three check the 4 output bytes and intermediates byte-exactly.
Compute cycles are 1,985 / 1,504 / 1,504; testbench host-layout cycles are
1,080 / 1,080 / 0. These correspond to phase intervals 3,065 / 2,584 /
1,504. The mini workload contains 1,872 useful MACs per four-output group.
Logs are in `/tmp/nmaforge_round7_cnn_fused_native_s20261107/`; the matching
aggregate rows are in the CSV above.

## Round 7 status boundary

This round does not add a larger trained Transformer: the existing H=4,
one-head, one-layer, 86-descriptor fixture remains the only reproducible
Transformer path. GEMM and `0x52` Decode are cycle-neutral at 5,715 cycles;
the B-fold Cache benefit remains demonstrated only on separate batched GEMV
commands. TinyNPU graph cycles and NMAForge Top CMDQ intervals remain
different measurement boundaries and are not ratioed.

---

## Round 6 model refresh — 2026-11-07

The fixed `conv1x_mini.onnx` workload was rerun at NMAForge source/test SHA
`54033ffd3a28378e867947e99598e79d2060fb9d` and TinyNPU SHA
`8216c22b762011aa20c05fc2768423fd12dda59d`. Model/input hashes and exact
Golden status are unchanged. NMAForge Legacy measured 1,985 CMDQ cycles plus
1,080 testbench-emulated host-layout cycles; `0x53` Linear-Row measured 1,504
CMDQ cycles and no layout stage. TinyNPU measured 4,781 ONNX graph cycles.
The graph and CMDQ windows differ, so no TinyNPU speedup is computed.

The NMAForge linear-row path was separately rerun by adding
`+AI_TINYNPU_CNN_LINEARIZED` to the existing `nma_cnn/simv` command. It passed
all intermediate and final Golden checks. Machine data is in
[`Round 6 CNN path CSV`](../../benchmark/v2_round6_cnn_legacy_linearized_20261107.csv)
and [`TinyNPU CNN CSV`](../../benchmark/tinynpu/cnn_results.csv). The Round 6
fixed-weight H=4 Transformer GEMV run also passes all 86 descriptors, but has
the same 5,715 Decode cycles as default GEMM; see the
[`Round 6 decision`](NMAFORGE_V2_ROUND6_DECISION.md).

## Round 5 current-source model evidence — 2026-11-07

All new measurements use source/test SHA
`73caef0f32140d1635816f1eb4ea28372523e80c` and VCS
`V-2023.12-SP1_Full64`. Machine-readable per-run records are in
[`v2_round5_model_summary_20261107.csv`](../../benchmark/v2_round5_mo��כh��춻�q�^vCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v2_matrix_profile_ac6b83_3seed \
  COMPUTE_CLUSTER_UVM_SEEDS='20261125 20261126 20261127'
```

Exact aggregation command:

```sh
python3 tools/summarize_top_matrix_profile.py \
  --run-root /tmp/nmaforge_v2_matrix_profile_ac6b83_3seed \
  --source-sha 8adf916e4e8a0e3b2f2e01acc85bacb59fbb8f47 \
  --tree-sha a8c232664436c5b1d1f2888eff34439edb40430d \
  --run-id V2-TOP-MATRIX-PERF-PROFILE-8ADF916-3SEED \
  --csv benchmark/v2_top_matrix_profile_8adf916_3seed.csv \
  --json benchmark/v2_top_matrix_profile_8adf916_3seed.json
```

VCS is `V-2023.12-SP1_Full64`; aggregation used Python 3.6.8. The broader
matched serial/parallel task benchmark still lacks the same per-command state
profile, and the eight-configuration and TinyNPU results remain tied to their
own source SHAs and memory endpoints.

## Real-Top Matrix profiles under shared-SPAD contention — `f530fe2`

Extended the passive Matrix profile to three existing Top CMDQ workloads at
fixed test/source SHA `f530fe2c4c98204312b7ed16616cb9d9747670b2` (tree
`919ebb411a7b47e0e0b3dfd2084852a83a2a5034`). The same `16×32×64` Matrix
command was sampled alone, staged with a CNM GEMV, and during a dedicated
Matrix-writeback/CNM contention test. Three Seeds (20261128/29/30) produced
identical values. Every profile's 15 exclusive state buckets equal its Matrix
`cycle_count`; the test also passes the 512-word Matrix Golden and the full
Compute Cluster UVM checks with UVM Warning/Error/Fatal `0/0/0` per Seed.

| Matrix profile | Matrix internal cycles | Full CMDQ doorbell-to-completion cycles | Effective MAC/cycle | Array utilization | Matrix SPAD read/write | Arbiter stall | Response wait | Writeback wait | Prefetch wait / MAC overlap |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Standalone | 490 | 565 | 66.87 | 26.12% | 3,072 / 2,048 B | 0 | 3 | 0 | 180 / 120 |
| Matrix + CNM staged | 533 | 613 | 61.48 | 24.02% | 3,072 / 2,048 B | 43 | 6 | 0 | 219 / 120 |
| Matrix writeback stalled by CNM | 844 | 1,837 | 38.82 | 15.17% | 3,072 / 2,048 B | 354 | 9 | 84 | 440 / 120 |

The three windows have different meanings: standalone completion is Matrix;
the staged case retires Matrix and CNM; the writeback case waits for both
Matrix and CNM completions. Matrix SPAD bytes exclude CNM's bank traffic. The
line-stall profile's 84 `writeback_wait` cycles are included in the 844 Matrix
internal cycles; request-arbiter and response wait counters are diagnostic
events and can overlap state/event counts. These results show measurable
contention cost in the existing legal workloads, but do not compare an
alternate arbitration policy or justify Bank-Aware Issue RTL changes.

Machine data is [CSV](../../benchmark/v2_top_matrix_cluster_profile_f530fe2_3seed.csv)
and [JSON](../../benchmark/v2_top_matrix_cluster_profile_f530fe2_3seed.json).
Text-only logs and URG summaries are archived at
`/tmp/nmaforge_v2_top_matrix_cluster_profile_f530fe2_3seed_text.tar.gz`,
SHA-256 `64f70be1d60805c9898711cfe77f584329e2bd1c285df5b0e99bd5ea8019d542`;
VDBs and simulator binaries are excluded. Exact UVM command:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_v2_matrix_cluster_profile_25873ac_3seed \
  COMPUTE_CLUSTER_UVM_SEEDS='20261128 20261129 20261130'
```

Exact aggregation command:

```sh
python3 tools/summarize_top_matrix_profile.py \
  --run-root /tmp/nmaforge_v2_matrix_cluster_profile_25873ac_3seed \
  --source-sha f530fe2c4c98204312b7ed16616cb9d9747670b2 \
  --tree-sha 919ebb411a7b47e0e0b3dfd2084852a83a2a5034 \
  --run-id V2-TOP-MATRIX-CLUSTER-PROFILE-F530FE2-3SEED \
  --expected-seeds 20261128,20261129,20261130 \
  --required-profiles standalone,staged_matrix_cnm,line_stall_matrix_cnm \
  --csv benchmark/v2_top_matrix_cluster_profile_f530fe2_3seed.csv \
  --json benchmark/v2_top_matrix_cluster_profile_f530fe2_3seed.json
```

The VCS release is `V-2023.12-SP1_Full64`; the checked-in parser runs on Python
3.6.8. CNM, SFU and other engine-internal per-command stalls are not captured
by this Matrix-specific interface, and the broader serial/parallel workload
still lacks a full all-engine timeline. No functional RTM state or product
RTL changed.

### Clean-candidate replay at `839b9af`

The same three-seed Compute Cluster regression and all three profile scenarios
were replayed from a detached clean worktree at source/test SHA
`839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0` (tree
`630e498ba467d84dd5359403cfe1ed1e5879f6e9`) using VCS
`V-2023.12-SP1_Full64`. All 3 seeds pass with UVM Warning/Error/Fatal `0/0/0`;
all 9 profile FSM partitions close exactly, and the values are identical to
the `f530fe2` run. This is a clean-candidate reproducibility check, not a new
workload or a different memory model.

The URG aggregate bounds confidence in this replay: functional group score is
83.94% (the declared `cluster_cg` alone is 100%), line/condition/FSM/branch is
70.74/68.33/46.17/67.70%, and assertions have 17/22 real successes with zero
failures/incomplete; two assertions have no attempts and only 1/3 cover
properties matches. The complete three-seed URG disposition is in the [DV
report](../verification/NMAFORGE_V2_DV_CLOSURE.md).

Machine data: [CSV](../../benchmark/v2_top_matrix_cluster_profile_839b9af_3seed.csv),
[profile JSON](../../benchmark/v2_top_matrix_cluster_profile_839b9af_3seed.json),
and [run metadata](../../benchmark/v2_clean_cluster_uvm_839b9af.json). Text-only
logs/URG archive `/tmp/nmaforge_v2_clean_839b9af_cluster_3seed_text.tar.gz`,
SHA-256 `4d036d428c8e72a10490bb7eaf9534158a8df185d46722453e49038a374993f9`.
The 256-MAC behavioral-SPAD profile remains an RTL simulation result; it is
not ASIC timing, power, or TinyNPU comparison evidence.

## Clean-candidate Cache × Prefetch replay — `839b9af`

The four product-GEMV configurations were rerun from a detached clean worktree
at source/test SHA `839b9af5bcd2ab5f85c52f0d014d8f46e794c1a0` (tree
`630e498ba467d84dd5359403cfe1ed1e5879f6e9`) on Seeds
`20261128/20261129/20261130`. The physical array is 16×16 (256 INT8 MACs),
read outstanding depth is 4, A-Tile Cache is enabled, and the registered
four-bank behavioral SPAD uses seed-controlled randomized ready/response
latency. Four shapes × four Cache/Prefetch configurations × three Seeds
produced 48/48 bit-exact Golden points. All 48 exclusive state partitions
equal command cycles.

| Shape (M×N×K) | B-fold Cache OFF / Prefetch OFF | Cache ON / Prefetch OFF | Cache OFF / Prefetch ON | Cache ON / Prefetch ON | Read bytes OFF→ON |
|---|---:|---:|---:|---:|---:|
| 8×16×19 | 198.3 | 155.0 | 192.3 | 151.3 | 864→560 (−35.2%) |
| 8×16×65 | 541.3 | 388.0 | 522.0 | 379.7 | 2,720→1,696 (−37.6%) |
| 16×16×19 | 407.7 | 266.0 | 394.0 | 257.7 | 1,728→816 (−52.8%) |
| 16×16×65 | 1,077.0 | 639.0 | 1,027.0 | 641.3 | 5,440→2,368 (−56.5%) |

Cycles are means over the three Seeds. At these tested shapes, B-fold Cache
alone reduces command cycles by 21.9–40.7%; Cache ON reduces read traffic by
35.2–56.5%. With Cache ON, Prefetch improves the first three shapes by
2.4%, 2.2%, and 3.1%, while the 16×16×65 result is 0.4% slower. Prefetch
does not reduce read bytes; its measured overlap is 8/32/16/64 cycles for
the four shapes with Cache ON. Command-window utilization is 4.7–10.2% and
useful MAC rate is 11.9–26.0 MAC/cycle, so these small-M cases still leave
substantial array capacity unused. This data supports bounded B-fold reuse
for the measured workload; it does not establish a scheduler RTL change,
full-Top throughput, silicon benefit, or TinyNPU win.

Machine data: [48-point CSV](../../benchmark/v2_gemv_four_way_clean_839b9af_3seed.csv),
[summary JSON](../../benchmark/v2_gemv_four_way_clean_839b9af_3seed_summary.json),
and [configuration chart](../../benchmark/v2_gemv_four_way_clean_839b9af_3seed.svg).
The simulator is Synopsys VCS `V-2023.12-SP1_Full64`; aggregation used Python
`3.12.13`.
Text-only compile/run logs and per-Seed summaries are archived outside Git at
`/tmp/nmaforge_v2_clean_839b9af_gemv_four_way_text.tar.gz`, SHA-256
`4210b6af9cc45212732fa23ae69df1fbfe5ec3ae6d3335f76815fd4b5d9afa58`;
coverage databases and simulator executables are excluded.

Exact replay and aggregation commands:

```sh
VCS_ARCH_OVERRIDE=linux VCS_HOME=/tmp/nmaforge_vcs_home_linux_alias \
PATH=/tmp/nmaforge_vcs_home_linux_alias/bin:$PATH \
VCS='/tmp/nmaforge_vcs_home_linux_alias/bin/vcs -licwait 10' \
make -C dv/block/compute/matrix/sim product-gemv-four-way-ablation \
  SEEDS='20261128 20261129 20261130' \
  GEMV_FOUR_WAY_OUT=/tmp/nmaforge_v2_clean_839b9af_gemv_four_way

python3.12 tools/merge_gemv_four_way_ablation.py \
  --output-prefix benchmark/v2_gemv_four_way_clean_839b9af_3seed \
  /tmp/nmaforge_v2_clean_839b9af_gemv_four_way/summary_seed_20261128.csv \
  /tmp/nmaforge_v2_clean_839b9af_gemv_four_way/summary_seed_20261129.csv \
  /tmp/nmaforge_v2_clean_839b9af_gemv_four_way/summary_seed_20261130.csv
```

The Matrix-core experiment is isolated from the TinyNPU and full-CMDQ
measurement boundaries. The existing same-workload TinyNPU comparison and a
Top-level all-engine performance decomposition remain open.

## Research closure round 2 addendum — model-level boundaries

The bounded 128/512 KiB Digits MLP rerun is on test/source commit
`acfaec281f5414c0e357c1dc7985b79a829c8c30`; product RTL is unchanged. Both
compact-map runs use VCS `V-2023.12-SP1_Full64`, seed `20261029`, four-bank
behavioral SPAD and 16×16/256-MAC Matrix. They produce 34,761 doorbell-to-CPLQ
cycles, 23,552 fused native tile-write bytes, 1,884,160 useful MACs, 54.2033
MAC/cycle, and 21.17% derived array utilization. Output CSV SHA-256 is
`7980fb678505ae0590d13c2f590b9523a98bedee7c3037936ccacb9b10360e9c` for both
capacities; independent integer Golden recheck passes all 360 samples at
97.78% classification accuracy. The compact map high-water is 93,184 B.

The existing trained Digits MLP legacy/fused comparison remains model-level
evidence for Innovation 2: 110,155 versus 34,761 doorbell-to-completion cycles
(68.44% lower in the fused run), exact logits and matching 352/360 accuracy.
The runs have different layout-counter definitions, so their layout-byte
fields are not compared. The 48-point Cache×Prefetch GEMV ablation remains
controlled fixed-shape evidence for Innovation 1; a trained/model-level GEMV
ablation is **NOT_RUN**.

The mini CNN's 1,080 Host Layout cycles are 180 AXI-Lite transfers at six
cycles each: each of 36 convolution feature groups is read once and written
four times to form the flattened FC operand (144 B read, 576 B write). The
current consumer needs a flat K=144 vector, whereas `0x53` writes native
Matrix-A tile layout. Direct forwarding does not preserve that tensor shape;
the same CNN Legacy/Fused comparison is therefore **NOT_RUN** and no speedup
is claimed. Existing mini-CNN cycle values (NMAForge 1,985 compute + 1,080
host layout; TinyNPU 4,781 graph cycles) have different boundaries and remain
unratioed.

The 128 KiB MLP/Transformer records and fixture limitations are listed in the
[round-2 matrix](../../benchmark/v2_round2_research_closure_20261106.json).
No capacity result establishes streamed execution for a >128 KiB live set;
no current checked-in workload with such a live set was identified.
