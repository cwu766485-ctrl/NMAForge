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

make -C dv/block/compute/matrix/sim core-random-regress \
  SEEDS='20261025 20261026 20261027' \
  CORE_OUT_DIR=/tmp/nmaforge_pending_close_matrix_core_9d9e0f

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

# R31: real CNM + DMA/SPAD subsystem, three randomized seeds and URG merge.
make -C dv/subsystem/dma_spad/sim subsystem_regress \
  SEEDS='20261025 20261026 20261027' COV_TAG=R31 \
  URG_REPORT=/tmp/nmaforge_pending_close_cnm_subsystem_9d9e0f/urg_3seed

# Merge the three passing seed databases after locating the installed URG binary.
make -C dv/subsystem/dma_spad/sim subsystem_coverage \
  SEEDS='20261025 20261026 20261027' COV_TAG=R31 \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg \
  URG_REPORT=/tmp/nmaforge_pending_close_cnm_subsystem_9d9e0f/urg_3seed

# Add the legal delayed-reset timing point (one cycle after CNM parity during DMA abort drain).
cd dv/subsystem/dma_spad/sim
./simv_dma_spad_uvm +UVM_TESTNAME=dma_spad_subsystem_test \
  +ntb_random_seed=20261028 +SPAD_PARITY_ABORT_RESET_DELAY=1 \
  +UVM_VERBOSITY=UVM_MEDIUM -cm line+cond+fsm+tgl+branch+assert \
  -cm_dir coverage/dma_spad_subsystem_test_R31_seed20261028_delay1.vdb \
  -l dma_spad_subsystem_test_R31_seed20261028_delay1.log

# Exercise the three planned AXI RREADY stall lengths and merge all seven VDBs.
make subsystem_rready_stress URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg \
  RREADY_STRESS_TAG=R31_rready
/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg -full64 \
  -dir coverage/dma_spad_subsystem_test_R31_seed20261025.vdb \
  -dir coverage/dma_spad_subsystem_test_R31_seed20261026.vdb \
  -dir coverage/dma_spad_subsystem_test_R31_seed20261027.vdb \
  -dir coverage/dma_spad_subsystem_test_R31_seed20261028_delay1.vdb \
  -dir coverage/R31_rready_16.vdb -dir coverage/R31_rready_64.vdb \
  -dir coverage/R31_rready_300.vdb \
  -report /tmp/nmaforge_pending_close_cnm_subsystem_9d9e0f/urg_full_7runs
```

The first R31 regression invocation completed all three simulations but its
wrapper returned nonzero at the merge step because the installed `urg` was not
on `PATH`. The three-seed merge was then run successfully with the separate
`subsystem_coverage` command above and the explicit URG path. All seven
simulation logs report UVM warning/error/fatal `0/0/0`; the compile logs contain
no `Warning-`, `Error-`, or `[TFIPC]`.

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
| R30 Matrix accepted-read fault lifecycle | 3/3 seeds pass 18 functional + 35 fault/recovery cases, including depth-4 outstanding Abort/drain, prefetch Abort/Reset and recovery. Scope is Matrix core; it does not close other-engine top-level drain or external-fabric qualification. |
| R31 CNM/DMA-SPAD fault and backpressure | Three seeds plus directed delayed reset pass CNM accepted-read Abort drain/no-write and recovery; both CNM reset phases; four lane parity under DMA contention; parity during DMA abort followed by same-cycle/delayed shared reset; RREADY stalls 16/64/300. Seven merged VDBs cover all 14 subsystem functional groups (100%). This is subsystem-scoped, not whole-Cluster coverage. |

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
| `/tmp/nmaforge_closure_9d9e0f_clean/dv/subsystem/dma_spad/sim/compile_dma_spad_subsystem_test_R31_seed20261025.log` | `22de6866ad63185c4688f4d1472cefe9113b77617a17e6ff92b916bb36f4e63d` |
| `/tmp/nmaforge_closure_9d9e0f_clean/dv/subsystem/dma_spad/sim/compile_R31_rready_16.log` | `3f165d5491b0b42413afb9aa49587b1c2ca3c02cf88841e6af25ae4ea28327a1` |
| `/tmp/nmaforge_closure_9d9e0f_clean/dv/subsystem/dma_spad/sim/compile_R31_rready_64.log` | `e9504aa42e4cb028df54d362048a9949b47d032d74a2866e12a74b51e1598ae3` |
| `/tmp/nmaforge_closure_9d9e0f_clean/dv/subsystem/dma_spad/sim/compile_R31_rready_300.log` | `4a82b0203d1493cd611592d51c8ec1c25d6e853b9fcc0bf351747e21939e6745` |
| `/tmp/nmaforge_closure_9d9e0f_clean/dv/subsystem/dma_spad/sim/dma_spad_subsystem_test_R31_seed20261025.log` | `ed43e311e9bfa512b7aba064f8095ccd14c45b637e67ee061ca745cf19ba4c0d` |
| `/tmp/nmaforge_closure_9d9e0f_clean/dv/subsystem/dma_spad/sim/dma_spad_subsystem_test_R31_seed20261026.log` | `9029ace3114c586dad35e90d708e4fe4328c5cefa80a40ef9563381969585ddd` |
| `/tmp/nmaforge_closure_9d9e0f_clean/dv/subsystem/dma_spad/sim/dma_spad_subsystem_test_R31_seed20261027.log` | `22df3d4ccfd3c50e774607d42b0b4612af08d78a235931ab536cdbe530e705da` |
| `/tmp/nmaforge_closure_9d9e0f_clean/dv/subsystem/dma_spad/sim/dma_spad_subsystem_test_R31_seed20261028_delay1.log` | `66d0a0a9dfda2c3dd35dbe26f2d3027328e71f97922fe89c9f4de64e93d06daa` |
| `/tmp/nmaforge_closure_9d9e0f_clean/dv/subsystem/dma_spad/sim/R31_rready_16.log` | `7568d986e5060303a43551bf521082f3d148cfa1b95be08645124595826a135c` |
| `/tmp/nmaforge_closure_9d9e0f_clean/dv/subsystem/dma_spad/sim/R31_rready_64.log` | `c1d26a75b370a0934d5a79315e406e01d3cc3cc064fbb9061656b589cc981fdf` |
| `/tmp/nmaforge_closure_9d9e0f_clean/dv/subsystem/dma_spad/sim/R31_rready_300.log` | `d17b5f76191d234e06396478cf18d780645a1cdb80e172c06cc7d5eee64ef447` |
| `/tmp/nmaforge_pending_close_cnm_subsystem_9d9e0f/urg_full_7runs/dashboard.html` | `469e4f8d52752ae4924ae2c0a58c0a15547670a202d5c44294b179e2a861198a` |
| `/tmp/nmaforge_pending_close_cnm_subsystem_9d9e0f/urg_full_7runs/groups.html` | `b8dea8f62b82f83742f04485dc6a57a09bd922d1e1f7206c7c4fc3b60991c52a` |
| `/tmp/nmaforge_pending_close_cnm_subsystem_9d9e0f/urg_full_7runs/asserts.html` | `898125899fdad45584bc45372093487ca65788cc154cab37667397040fd64522` |
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
| `/tmp/nmaforge_pending_close_matrix_core_9d9e0f/compile.log` | `b735e91b99edecf723e51e2c89a82c3fd894f6ffaf15ea039cb3c81e180452aa` |
| `/tmp/nmaforge_pending_close_matrix_core_9d9e0f/run_seed_20261025.log` | `5a3b64cc0e65a54e92022b7d6780b19929200fbdfd2ff853b000988126097c61` |
| `/tmp/nmaforge_pending_close_matrix_core_9d9e0f/run_seed_20261026.log` | `94d809ffc012628572c8d4bffd4439a402e667de5137dc3bd8e006e631d0e774` |
| `/tmp/nmaforge_pending_close_matrix_core_9d9e0f/run_seed_20261027.log` | `f42e00129de63f189cc4b6ab8132246e35359f965909c949fb531c66d921a257` |

These checksums bind the archived result files to the current source-SHA review record. They do not turn the behavioral SRAM/fabric models into silicon timing or external-fabric qualification evidence.

## R32 — all-engine accepted-read reset sweep (clean test commit)

The reset-sweep testbench change is committed at `bb6e3a270ab819c15df0eb993c184c99d13a6d71`. A detached clean worktree at that commit was used for the replay. A tree comparison confirms `rtl/` is byte-identical to source candidate `9d9e0f01e374a7c3a6c33778a3ce20a1d28132c9`; the commit adds the UVM test and its run gate, not product RTL. The worktree is `/tmp/nmaforge_clean_bb6e3a2`.

Run from `/tmp/nmaforge_clean_bb6e3a2/dv/uvm/sim`:

```sh
make uvm_compute_cluster_regress \
  COMPUTE_CLUSTER_UVM_SEEDS='20261025 20261026 20261027' \
  COMPUTE_CLUSTER_UVM_OUT=/tmp/nmaforge_bb6e3a2_clean3s \
  URG=/opt/Synopsys/vcs/V-2023.12-SP1/bin/urg
```

VCS/URG `V-2023.12-SP1_Full64`; 3/3 seeds passed. Each seed reset the real top after accepted SPAD reads from all seven production engines, checked that busy cleared and destination/completion sentinels were preserved, and saw no stale completion or writeback. The memory scoreboard reported 5,094 accepted writes, 5,368 checked words, zero mismatch/unknown/stale/orphan response, and `reset_dropped=9`; UVM warning/error/fatal was `0/0/0`. The focused compute coverage marker was `99.0%` (rounded); the completion read-response bin remains architecturally N/A for the write-only completion writer. This is accepted-read reset evidence, not exhaustive Engine × Fault × Phase × Reset closure.

| Artifact | SHA-256 |
|---|---|
| `/tmp/nmaforge_bb6e3a2_clean3s/compile.log` | `43a8173e19ded8757e933e5d9a40b4072c3aab54bebc5fe91e39f8133db1d981` |
| `/tmp/nmaforge_bb6e3a2_clean3s/seed_20261025/run.log` | `7bba1a9f087b52b7cb8222614de2e442b1ffdf44a76ab325f31571f34beda0fe` |
| `/tmp/nmaforge_bb6e3a2_clean3s/seed_20261026/run.log` | `8c202d4e58c4e8fe01564ac5ac799ae685780838f8067f2f380f89a2b67cbc2c` |
| `/tmp/nmaforge_bb6e3a2_clean3s/seed_20261027/run.log` | `ff9853e8439909b8ad9ec9c85150975a51df8f8187f9dfa3ec8268c8f1ffdd78` |
| `/tmp/nmaforge_bb6e3a2_clean3s/urg_merged/dashboard.txt` | `f21015399951489d8b117906f20fd656365f5b7037b5897b4a4a40e03c5341b1` |
| `/tmp/nmaforge_bb6e3a2_clean3s/urg_merged/groups.txt` | `d1d9b57ef801a1a99483cc35960378dd4a20c19fcf2f6f9492b9f7f3bbc6e248` |
| `/tmp/nmaforge_bb6e3a2_clean3s/urg_merged/asserts.txt` | `1001e31f337917d60e57de56295c36ecaa6269f65bbe2054714855d417de3fe5` |
