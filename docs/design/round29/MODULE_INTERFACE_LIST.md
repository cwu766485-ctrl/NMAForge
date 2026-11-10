# Module and interface list

No module or source-list changes from Round 28. Product top remains `rtl/top/ai_accel_top.v`.

| Module group | Ownership/interface |
|---|---|
| AXI-Lite adapter/registers | 32-bit software register requests, independent channel handshakes |
| Parallel dispatcher/command processor | Ordinary engine slots and ordered retirement / compatibility direct and macro lifecycle |
| Descriptor validator/fetch | 64-byte aligned ABI-v7 descriptors, decode/field checks |
| Completion writer | Four accepted word writes precede CPLQ tail |
| AXI128 DMA | 128-bit AXI4 external movement, tagged responses and drain |
| SPAD arbiter/subsystem | Sole scheduler admission; four registered-read banks, response owner routing |
| Matrix core/array | Ordered outstanding bank metadata, ping-pong operands, shared GEMM/GEMV array, line/scalar write commit |
| SFU core/math/divider/sqrt | Scalar SPAD valid/ready + registered response, signed fixed-point pipeline and bounded cache |
| CNM/scalar/CNN/KV/FP | Existing specialized command clients; no Round 29 interface change |

Reset invalidates active state/local reuse tags. Abort obeys existing accepted-request drain and error completion boundaries. Software owns immutable active operands and inter-engine dependencies. No new cross-engine coherence is provided. Detailed implementation paths and supported subsets are in the parent architecture and existing NPU v2 specification.
