# Compute Cluster Final Candidate Replay Manifest — 2026-10-28

**Source SHA:** `9d9e0f01e374a7c3a6c33778a3ce20a1d28132c9` (detached clean worktree `/tmp/nmaforge_closure_9d9e0f_clean`).
**Tool versions:** Synopsys VCS/URG `V-2023.12-SP1_Full64`; VC Formal `V-2023.12-SP2`.
**Artifact policy:** simulation logs, VDBs and formal databases remain under `/tmp` and are not checked into Git; this manifest records their locations and SHA-256 while they remain on the host.

## Reproduction commands

Commands were run from the detached worktree at the selected source SHA.

```sh
make -C dv/subsystem/top_smoke/sim ai_cnm_random_regress \
  CNM_RANDOM_SEEDS='20261021 20261022 20261023' \
  CNM_RANDOM_OUT_DIR=/tmp/nmaforge_error_abi_cnm_priority_20261028

make -C dv/block/compute/matrix/sim core-random-regress \
  SEEDS='20261021 20261022 20261023' \
  CORE_OUT_DIR=/tmp/nmaforge_error_abi_matrix_priority_20261028

make -C dv/block/compute/sfu/sim random-latency-regress \
  SEEDS='20261021 20261022 20261023' \
  OUT_DIR=/tmp/nmaforge_error_abi_sfu_priority_20261028

make -C dv/block/compute/cnn_kv/sim random-latency-regress \
  SEEDS='20261021 20261022 20261023' \
  OUT_DIR=/tmp/nmaforge_error_abi_cnn_kv_20261028

make -C dv/uvm/sim uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_final_9d9e0f_uvm \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027'

make -C dv/uvm/sim uvm_compute_cluster_mutation \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_final_9d9e0f_uvm \
  COMPUTE_CLUSTER_MUTATION_OUT=/tmp/nmaforge_final_9d9e0f_mut

make -C dv/uvm/sim uvm_mixed_precision_ddr_e2e

make -C dv/block/compute/matrix/formal fsm-guards \
  OUT=/tmp/nmaforge_final_9d9e0f_matrix_formal

make -C dv/block/compute/matrix/sim matrix-size-benchmark \
  SEED=20261025 BENCH_OUT_DIR=/tmp/nmaforge_final_9d9e0f_matrix_size_20261025
make -C dv/block/compute/matrix/sim matrix-size-benchmark \
  SEED=20261026 BENCH_OUT_DIR=/tmp/nmaforge_final_9d9e0f_matrix_size
make -C dv/block/compute/matrix/sim matrix-size-benchmark \
  SEED=20261027 BENCH_OUT_DIR=/tmp/nmaforge_final_9d9e0f_matrix_size_20261027

make -C dv/block/compute/matrix/sim matrix-config-comparison \
  SEED=20261025 MATRIX_CONFIG_OUT=/tmp/nmaforge_final_9d9e0f_matrix_config_20261025
make -C dv/block/compute/matrix/sim matrix-config-comparison \
  SEED=20261026 MATRIX_CONFIG_OUT=/tmp/nmaforge_final_9d9e0f_matrix_config
make -C dv/block/compute/matrix/sim matrix-config-comparison \
  SEED=20261027 MATRIX_CONFIG_OUT=/tmp/nmaforge_final_9d9e0f_matrix_config_20261027
```

The R24 directed priority/prefix supplemental commands and their three-seed outcomes are indexed in the [Execution RTM](COMPUTE_CLUSTER_EXECUTION_RTM_2026-10-27.md). They ran against files identical to the committed candidate source.

## Result summary

| Run | Result |
|---|---|
| R24 Error ABI / priority / prefix | CNM, Matrix, SFU, Conv and KV selected cases PASS across seeds `20261021/22/23`; broader legal fault-phase matrix remains partial. |
| R25 real seven-engine top UVM | 3/3 seeds PASS; per seed 4,946 accepted writes, 5,256 checked words, zero mismatch/unknown/stale/orphan; UVM severity 0/0/0. |
| R26 checker-sensitivity mutation | 25/25 expected catches; passive-monitor observation mutations, not DUT mutation. |
| R27 coordinated reset | accepted AR/R and AW/W/B windows PASS against behavioral responder; no stale response; DMA idle and recovery pass. |
| R28 Matrix FSM formal | 5/5 non-vacuous properties proved; both reachability covers hit. Raw default FSM remains 49/53. |
| R29 Matrix benchmark | size 45/45 and configuration ablation 120/120; same seed set, one-cycle behavioral SPAD. |

## Artifact SHA-256

| Artifact path | SHA-256 |
|---|---|
| `/tmp/nmaforge_final_9d9e0f_uvm/compile.log` | `4adef3ed6795e86d28f13cba00b6d7e7ef2219f3dcde8114fa02602f89868ff9` |
| `/tmp/nmaforge_final_9d9e0f_uvm/make.log` | `78ff27907c75cf1c9d7a2e0eb94b77d74aa4b700a71d81f465d4836cdfd84ecb` |
| `/tmp/nmaforge_final_9d9e0f_uvm/urg_merged/asserts.txt` | `53c97eebd6c56346ce440097b248f32f9dd5a248bb41161e1eeaf17ce331cfdf` |
| `/tmp/nmaforge_final_9d9e0f_uvm/urg_merged/groups.txt` | `d1d9b57ef801a1a99483cc35960378dd4a20c19fcf2f6f9492b9f7f3bbc6e248` |
| `/tmp/nmaforge_final_9d9e0f_uvm/urg_merged/dashboard.txt` | `e1dabe73515824edfcfd638870e154488de03672ea2e1596ad3f60e02b69a144` |
| `/tmp/nmaforge_final_9d9e0f_mut/make.log` | `f2d1c2b621881cb2a58ecb95899ffb8b26547e0112275c2a03895b2b7072efb4` |
| `/tmp/nmaforge_closure_9d9e0f_clean/dv/uvm/sim/uvm_compile.log` | `02e9d37ac68381aaf4ffb5caeba35ab9a855093253d7a1d3aeb3cb7fc511dd1e` |
| `/tmp/nmaforge_closure_9d9e0f_clean/dv/uvm/sim/uvm_run_ai_mixed_precision_ddr_e2e_test.log` | `77bd315a9d4262d3b18d9ba8aa88f59d9629ab3f9f9c175820688c54a14d8e55` |
| `/tmp/nmaforge_final_9d9e0f_matrix_formal/vc_formal.log` | `dfffd3da82b9264cf9107f7229e32759a817e386caa72884a8099e9d70dbee8a` |
| `/tmp/nmaforge_final_9d9e0f_uvm/seed_20261025/run.log` | `a720bd06f037dbfcc630238f590088e6897d8203813b37e2f15d67b8d893baaf` |
| `/tmp/nmaforge_final_9d9e0f_uvm/seed_20261026/run.log` | `07c813dca528ad950f305affc8e9b749ec74c132a769ecb3f39020c3e7697647` |
| `/tmp/nmaforge_final_9d9e0f_uvm/seed_20261027/run.log` | `1b205b967862b0c97e46d63f0ad420c10f0e62f28ae60f24ff49da38fe29396d` |
| `/tmp/nmaforge_final_9d9e0f_mut/address.log` | `1e1437baf7c90b288863116694fab5de59626a2cb36512a64bc33526b64f513f` |
| `/tmp/nmaforge_final_9d9e0f_mut/data.log` | `25609d6502951a825f2d119d613e458d070bc999ede7c349d3f81d376e7699f1` |
| `/tmp/nmaforge_final_9d9e0f_mut/done_engine_0.log` | `30fca6d460a10ae06be10c9fd9702ec6c9a5b35754b9d784e3f0a1d81fcb65c0` |
| `/tmp/nmaforge_final_9d9e0f_mut/done_engine_1.log` | `531aa1b28f64d83b5255a74d4010f9604a7d739447d4821e906d79e961f7295e` |
| `/tmp/nmaforge_final_9d9e0f_mut/done_engine_2.log` | `067d6c99e39382ce18c9f182b4c8d442920ba72714ffa01dc52c9c11c6da0ae7` |
| `/tmp/nmaforge_final_9d9e0f_mut/done_engine_3.log` | `93b40f6f4cf82bf8a6f3bc5734afe40cb1349f749e23b3ddba797490c0c91673` |
| `/tmp/nmaforge_final_9d9e0f_mut/done_engine_4.log` | `adc209c43c358011e075e3f1a2e91bdad97b244b09333c5c198dc742cd2d47be` |
| `/tmp/nmaforge_final_9d9e0f_mut/done_engine_5.log` | `4a6fcc4f02ab064b833ae1d37e3ab81991614ca5729162dc9106775a5652dd00` |
| `/tmp/nmaforge_final_9d9e0f_mut/done_engine_6.log` | `d2c4a2a5298fda80d4fe555bdb9772202e6ca6e9fef50c6108fdf5bdc1c37b7a` |
| `/tmp/nmaforge_final_9d9e0f_mut/duplicate_done_engine_0.log` | `18860c36406222f63b96939ad9deb1d95b4febd22b5ef2d2b8b42e36b89bb1fb` |
| `/tmp/nmaforge_final_9d9e0f_mut/duplicate_done_engine_1.log` | `2af667855ad20e3c39005fc0c94a28c09df7960d5e1f0f645c2996068582fbf3` |
| `/tmp/nmaforge_final_9d9e0f_mut/duplicate_done_engine_2.log` | `54db72b17ad6cd27dc4893497406b2b791b7c97510dcbb088fc1b581c03c16b4` |
| `/tmp/nmaforge_final_9d9e0f_mut/duplicate_done_engine_3.log` | `30b126dfc6cb415912b61ff0411b9ca426c05082ceb18cf12657a126b390ba95` |
| `/tmp/nmaforge_final_9d9e0f_mut/duplicate_done_engine_4.log` | `9cf27b2376b481d796de0cba915c08a033c1b3d609f8906bb85a0a556deee58d` |
| `/tmp/nmaforge_final_9d9e0f_mut/duplicate_done_engine_5.log` | `c1de784cc54a90822b7a5c2cc4861b0bf561fe02b912d3e4b8e36b12a7bcbd0e` |
| `/tmp/nmaforge_final_9d9e0f_mut/duplicate_done_engine_6.log` | `8b53ee7fc378c1b5e9d13c10dae2e973fe3b552c3fc91df29da912966dced423` |
| `/tmp/nmaforge_final_9d9e0f_mut/missing_done_engine_0.log` | `1b421bf1b10dff93924bd9072cec794116183651f0aa425ec2ac809b05918ef8` |
| `/tmp/nmaforge_final_9d9e0f_mut/missing_done_engine_1.log` | `beec8db07145c4833725b5e8ac9a7491e3857b5731a604ce6cbe30eb43273d41` |
| `/tmp/nmaforge_final_9d9e0f_mut/missing_done_engine_2.log` | `023f658a42f1cc2e7f61696b4b69d1742048500249ff0872a98474adb2b85c46` |
| `/tmp/nmaforge_final_9d9e0f_mut/missing_done_engine_3.log` | `a25ccd7e5798a30b85857d6305222f692843d7d4cfcf21ddb942bec565fefb1b` |
| `/tmp/nmaforge_final_9d9e0f_mut/missing_done_engine_4.log` | `1b77feea466bb0d8bcf6399af2945fa11d1c0f215f9c034d4b225988f9f8cc8a` |
| `/tmp/nmaforge_final_9d9e0f_mut/missing_done_engine_5.log` | `71d0bd60404d5c44c5b834b1aa0bce419d6faaa69c6a41054cfe3567fa375536` |
| `/tmp/nmaforge_final_9d9e0f_mut/missing_done_engine_6.log` | `1ef5a5d76afdbcdf5f368570875b3340c6aded9e6754f24ae82f1356ccf0b4ee` |
| `/tmp/nmaforge_final_9d9e0f_mut/owner.log` | `80fc5bc4b8bcb37dde1f28282945d9c0d2ed80c172ba5466c0ed1697550de02e` |
| `/tmp/nmaforge_final_9d9e0f_mut/wstrb.log` | `fe99b1cfa0acf4ddabedb60cb08337c7114d2ad2985e13016c4c7a9feda5e315` |
| `/tmp/nmaforge_error_abi_cnm_priority_20261028/compile.log` | `058199bdf16158eff36f35cd9333a3e698de455ffad2521ee178204b2c760532` |
| `/tmp/nmaforge_error_abi_cnm_priority_20261028/run_seed_20261021.log` | `754476ec87f3ebe9515e9987274bd0581fb158d46dc8e7c4506bee05252c9f2d` |
| `/tmp/nmaforge_error_abi_cnm_priority_20261028/run_seed_20261022.log` | `24c727c30d4a66b3263eaf4a1a520735a2c1e991110eff543dddf094f3c2da2c` |
| `/tmp/nmaforge_error_abi_cnm_priority_20261028/run_seed_20261023.log` | `6baee9e6352d8b583858b9e475fc2f5c07dab609009a7d8b5b078c1ee2931f61` |
| `/tmp/nmaforge_error_abi_cnm_priority_20261028/simv.daidir/elabcomLog/compiler.log` | `a3001f0882890e3d952bf7a17bde560cf73d937963476c6a3c3abbd4750af5a0` |
| `/tmp/nmaforge_error_abi_cnm_priority_20261028/simv.daidir/elabcomLog/turbo.log` | `30e7b0b68780eaf1e7d061dcbb9ac74a71957aa8ece9d9a3fb91e46e87d9090f` |
| `/tmp/nmaforge_error_abi_matrix_priority_20261028/compile.log` | `adbd81b66a3dbbc68da127298c616d5df60fe54361db67de71b2913ce73da332` |
| `/tmp/nmaforge_error_abi_matrix_priority_20261028/run_seed_20261021.log` | `251fc42271a976b13481987328eae288cbed03867a208d9e975d6d32b49b9c7c` |
| `/tmp/nmaforge_error_abi_matrix_priority_20261028/run_seed_20261022.log` | `55160178e440e6bce7d26b985e2eda91842de5e187302e7922208592c4a2fee8` |
| `/tmp/nmaforge_error_abi_matrix_priority_20261028/run_seed_20261023.log` | `45af83ca329ebf16db4dcda06c1ac84dbb1108357a3766a7d7ae14e4ab9d0e39` |
| `/tmp/nmaforge_error_abi_sfu_priority_20261028/compile.log` | `960300fb982e561b3c5b6752efb5aead06fa3a15dca7b4531b63be4c2bcd98de` |
| `/tmp/nmaforge_error_abi_sfu_priority_20261028/seed_20261021/run.log` | `648e425dce83cc6a47f71ee22771381e458ae940e2af20fdaea52b0c3df88f1e` |
| `/tmp/nmaforge_error_abi_sfu_priority_20261028/seed_20261022/run.log` | `b4f0985de8d7fffe02386a88057eb6d71ccecb660609ca3a167d9725aea79097` |
| `/tmp/nmaforge_error_abi_sfu_priority_20261028/seed_20261023/run.log` | `ed287254971dacbdaa709798cd72ea51df08920fd3fb937a9fda3a3845dd9869` |
| `/tmp/nmaforge_error_abi_cnn_kv_20261028/compile.log` | `80fd1b75d94949b9bb2db071262947bd70a7d332444a6d8f7c2763de3d962825` |
| `/tmp/nmaforge_error_abi_cnn_kv_20261028/run_seed_20261021.log` | `059cf401dce08d71d36b7989716c9ddebd0f3661627cc89a2d1ec37c49838220` |
| `/tmp/nmaforge_error_abi_cnn_kv_20261028/run_seed_20261022.log` | `3ed1873533682100c9f64762b7fe49b95389e3746c8796b10f651c1cabf2ce9e` |
| `/tmp/nmaforge_error_abi_cnn_kv_20261028/run_seed_20261023.log` | `08a5619d260cd3f317177270b924fb9dcb346ce6b1a8c09f25223cb085c656b9` |
| `/tmp/nmaforge_final_9d9e0f_matrix_size_20261025/array_4/run.log` | `e379f00aabcc3d056b433ae7cf93d334e595e0bb524298e77062d142c1046a3a` |
| `/tmp/nmaforge_final_9d9e0f_matrix_size_20261025/array_8/run.log` | `400750e0cb630e4697140a689f5452821ba3debcdebb644544d016c46af91565` |
| `/tmp/nmaforge_final_9d9e0f_matrix_size_20261025/array_16/run.log` | `3f80c9345ce051c8802aa51cc544128338158a6aa2b56be8df5a2563f263edba` |
| `/tmp/nmaforge_final_9d9e0f_matrix_size/array_4/run.log` | `cb0acb1d2e12e5247a0bbb57a065821b93f88ec77177c8b9351dc70a8e9ea78f` |
| `/tmp/nmaforge_final_9d9e0f_matrix_size/array_8/run.log` | `ce80ff30c5f0f40a6fbf054203c6f8e979e6ae4788e15c685463d147faafb9fd` |
| `/tmp/nmaforge_final_9d9e0f_matrix_size/array_16/run.log` | `b1a6d7eceed69ace2e13b617a81a331bd65944af51ddae3a7eda7beec8d38921` |
| `/tmp/nmaforge_final_9d9e0f_matrix_size_20261027/array_4/run.log` | `32eec02568e7f6dc81a9bc46591fc11b93a4a4c1e3d1b6b5f7bdc3d565778ee8` |
| `/tmp/nmaforge_final_9d9e0f_matrix_size_20261027/array_8/run.log` | `c9ff8a8eeb0f1398daee336fa0aca6b92e55cce9c5773fe301cb4d44f0ca2c57` |
| `/tmp/nmaforge_final_9d9e0f_matrix_size_20261027/array_16/run.log` | `e3efb8d71e6cdb41df345886a2f8c04180129898a2a46b5fe8ba7fe8eb9aed72` |
| `/tmp/nmaforge_final_9d9e0f_matrix_config_20261025/matrix_config_comparison.csv` | `ed2bb7f4e4fdfbf20216d2e59ff1eb91bc5fa11fcc4e5fd46ace82e571961554` |
| `/tmp/nmaforge_final_9d9e0f_matrix_config/matrix_config_comparison.csv` | `0314a8df69aa9245e1335942c2ccb00a45b417d0caca23a1e6a4044355e40045` |
| `/tmp/nmaforge_final_9d9e0f_matrix_config_20261027/matrix_config_comparison.csv` | `71c0a85d7298a23dfb9892096de55c2cb32416e77f08f65069e389ba3879d18b` |

These checksums bind the archived result files to the current source-SHA review record. They do not turn the behavioral SRAM/fabric models into silicon timing or external-fabric qualification evidence.
