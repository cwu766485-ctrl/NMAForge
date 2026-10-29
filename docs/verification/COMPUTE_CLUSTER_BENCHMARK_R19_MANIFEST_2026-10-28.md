# R19 Matched TinyNPU Benchmark Manifest — 2026-10-28

## Identity and scope

- NMAForge product RTL candidate: `c0832e5c822de1a03f82751d5ff8f831d0addb98` (`rtl/` matches that commit; no product RTL was edited for R19).
- NMAForge benchmark testbench state: local working-tree additions, identified by the SHA-256 values below. R19 is candidate-RTL evidence, not a clean-commit replay of the new benchmark testbench.
- TinyNPU source: `Atharva-Paranjpe/TinyNPU`, commit `f965fe9462464fc8c9f944c491c3b81d45af1165`.
- Simulator: Synopsys VCS `V-2023.12-SP1_Full64`.
- Seed: `20261028` for NMAForge. TinyNPU's directed test is deterministic and has no random seed.
- Raw build/run outputs are under `/tmp`; they are not checked-in sign-off databases.

## Reproduction commands

NMAForge matched GEMM and native convolution:

```sh
make -C dv/block/compute/matrix/sim tinynpu-matched-benchmark \
  SEED=20261028 \
  TINY_MATCH_OUT=/tmp/nmaforge_matrix_tinynpu_match_c0832e5_20261028 \
  VCS='vcs -licwait 1'

make -C dv/block/compute/cnn_kv/sim tinynpu-cnn-matched-benchmark \
  SEED=20261028 \
  TINYNPU_CNN_OUT=/tmp/nmaforge_cnn_tinynpu_match_c0832e5_20261028 \
  VCS='vcs -licwait 1'
```

TinyNPU was built from its pinned local checkout using a temporary VCS-only primitive model and a compatibility copy of the RTL top. The compile inputs are the pinned `tinynpu_dsp_pe.sv`, `tinynpu_systolic_array.sv`, `tinynpu_matrix_buffer.sv`, and `tinynpu_matrix_engine.sv`, plus the files listed below. The copied `tinynpu_tiled_gemm.sv` changed `always_ff` to `always` because VCS rejects the upstream module's variables written from multiple procedural blocks. `DSP48E1_model.sv` supplies only the configured signed combinational multiply (`MREG=PREG=0`); it is not a Xilinx UNISIM model.

Equivalent invocation from `/tmp/nmaforge_tinynpu_match_f965fe9`:

```sh
vcs -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
  -top tinynpu_tiled_gemm_tb DSP48E1_model.sv \
  /tmp/nmaforge_tiny_npu_reference/TinyNPU/TinyNPU.srcs/sources_1/new/tinynpu_dsp_pe.sv \
  /tmp/nmaforge_tiny_npu_reference/TinyNPU/TinyNPU.srcs/sources_1/new/tinynpu_systolic_array.sv \
  /tmp/nmaforge_tiny_npu_reference/TinyNPU/TinyNPU.srcs/sources_1/new/tinynpu_matrix_buffer.sv \
  /tmp/nmaforge_tiny_npu_reference/TinyNPU/TinyNPU.srcs/sources_1/new/tinynpu_matrix_engine.sv \
  tinynpu_tiled_gemm_vcs.sv \
  /tmp/nmaforge_tiny_npu_reference/verification/tinynpu_tiled_gemm_tb.sv \
  -o simv -l compile.log
./simv -l run.log

vcs -full64 -sverilog -debug_access+all -timescale=1ns/1ps \
  -top tinynpu_tiled_gemm_tb DSP48E1_model.sv \
  /tmp/nmaforge_tiny_npu_reference/TinyNPU/TinyNPU.srcs/sources_1/new/tinynpu_dsp_pe.sv \
  /tmp/nmaforge_tiny_npu_reference/TinyNPU/TinyNPU.srcs/sources_1/new/tinynpu_systolic_array.sv \
  /tmp/nmaforge_tiny_npu_reference/TinyNPU/TinyNPU.srcs/sources_1/new/tinynpu_matrix_buffer.sv \
  /tmp/nmaforge_tiny_npu_reference/TinyNPU/TinyNPU.srcs/sources_1/new/tinynpu_matrix_engine.sv \
  tinynpu_tiled_gemm_vcs.sv tinynpu_tiled_gemm_cnn_tb.sv \
  -o cnn_simv -l cnn_compile.log
./cnn_simv +CONV_IM2COL_ONLY -l cnn_run.log
```

The TinyNPU CNN case places the same 3×3 image/filter values into the first row/column of a zero-padded 16×16×16 GEMM. Its Golden checks all 256 streamed INT32 values and confirms `C[0,0] = -30`; only that output represents the useful convolution result.

## Results

| Workload | NMAForge | TinyNPU | Checker outcome |
|---|---|---|---|
| 16×16×16 signed INT8 GEMM, 8×8 physical array | 298 cycles to `done`; 4,096 MAC; 13.745 MAC/cycle; 768 B read + 1,024 B write over one-cycle behavioral SPAD; 18 bank stalls + 21 line-write stalls | 1,800 cycles to `done`; 2,056 cycles through final 256-word output stream; 4,096 MAC; internal buffers and no modeled external-memory backpressure | 256/256 INT32 results match the independent Golden on both sides |
| 3×3 single-channel INT8 convolution | Native Conv, 66 cycles; 18 SPAD reads / 72 B and one 4 B write | Padded 16×16×16 GEMM lowering; 1,800 cycles to `done`, 2,056 through 256 output words | Both return `-30`; all TinyNPU padded outputs are checked |

These are RTL testbench cycle counts. The TinyNPU run uses a functional DSP primitive surrogate; it does not validate UNISIM behavior or FPGA timing. Memory ports, buffering, output serialization, and operation lowering differ. Do not claim an implementation speedup or treat these cycle counts as equivalent hardware throughput. No measured Fmax, area, or power is produced; any 250 MHz value in the Matrix run log is a fixed-frequency normalization assumption only.

## Source and artifact SHA-256

| File | SHA-256 |
|---|---|
| NMAForge `rtl/compute/matrix/ai_tensor_matrix_datapath.v` | `c7fc6ab36d39df0f4890dec11c3c39265a0b8efec79ce4806560d96a2fe5aac9` |
| NMAForge `rtl/compute/matrix/ai_tensor_matrix_array.sv` | `83d8e6b170fe3645207ecfd2a82d7290f36a8d8114e4d940bbeb8f94f790594d` |
| NMAForge `rtl/compute/matrix/ai_tensor_matrix_core.v` | `dedc44406ab9f30b270bde12dbfeb3ab88184bb29af446fa1f119321e5d73aad` |
| NMAForge `rtl/compute/cnn/ai_conv3x3_linebuffer_core.v` | `f0cf3821f422156ef6af12b5d9b04459f92bbb65ed45c8cd8cc01993c7325c3b` |
| NMAForge Matrix benchmark TB | `7b13c1901c1bf6052b40cd4501837dcf6d7a658f0055dffbfec7d9e46490e41e` |
| NMAForge Matrix benchmark Makefile | `9cddc3714c3df9775d81c4c30fec7a87073e5a15c0f45ee495efa496d5c7b80f` |
| NMAForge CNN benchmark TB | `a8fee571a37d3e4015cdd3556c3cbb2f2723e0b7f4bf2dd288707e34d1e0d616` |
| NMAForge CNN benchmark Makefile | `2c7bc1b55904a4f07f2eeb1390e7561040804d59cd2e8511a0404272651d758d` |
| TinyNPU original `tinynpu_tiled_gemm.sv` | `aa682d63a34310d88c325cf5f42e48dc7316a372138fac9e65971559e8af19f4` |
| TinyNPU original directed TB | `933f7415af30d94c6535a015819cba64e10eae190c7021fb40b29aaf53c7d665` |
| TinyNPU VCS compatibility top copy | `0f6c7ad4bd0484b1f2f4dab0bbb49e3a2d735386da9e1f115447a37407042ccf` |
| Temporary `DSP48E1_model.sv` | `9849665fdd19bfecd4c72cfd46e7a3ccbdeff9ecdbafe43115b2857fb071726c` |
| Temporary TinyNPU CNN testbench | `d473534984bdb34fc8475073d7fb94e0e1de27db366e1e74faac5636e7e0b2ec` |
| NMAForge Matrix compile log | `029b67a8a7fabd95380533b041c1e2bc57e78cd755365db4cdc422770f92577e` |
| NMAForge Matrix run log | `2ffb93c8f788be5d2e944b0535af25f04fa40c3193aeab8fed9a008defa99111` |
| NMAForge CNN compile log | `f14186126e157ac4ae5f92444a6964291dfadcb45cb9074221a8deae1520925d` |
| NMAForge CNN run log | `664ea3175494db1d8cee0adc160f12de47b262f174b3039ac08df16eb992f00c` |
| TinyNPU GEMM compile log | `5c9336740199edfac36498d3df136dba076ea398098bcc20e9fe5ea20dd1ed94` |
| TinyNPU GEMM run log | `45b5a0145bb3b1e86b9e379e135845c05fc17c2479ad1b952f3f0c086ab2fdd9` |
| TinyNPU CNN compile log | `2e606d994b07e9434c6122a5f13b92baf082381e4e355e1ee4864d5cc6d335b3` |
| TinyNPU CNN run log | `a545d3d86afc8d700b352c6e85bfec6ecee185dcb8a760014b06732378728d82` |

Raw artifacts are under `/tmp/nmaforge_matrix_tinynpu_match_c0832e5_20261028/`, `/tmp/nmaforge_cnn_tinynpu_match_c0832e5_20261028/`, and `/tmp/nmaforge_tinynpu_match_f965fe9/`. Keep temporary compatibility files and their hashes alongside those logs when reproducing R19.
