# NMAForge v1.2 — DUT Architecture and DV Mapping

This is an interface/ownership map for the shared Product RTL. It is not a new
sign-off result. Model-level Top Golden passes exercise bounded integration
paths and do not close the complete DV plan.

## Top-level interface contract

| Boundary | RTL interface | Contract and ownership |
|---|---|---|
| Control | `ai_accel_top.s_axi_*`, 32-bit AXI4-Lite | Register configuration, descriptor/queue publication and status/readback. AXI-Lite AW/W may arrive independently; the register interface owns protocol adaptation. |
| External memory | `ai_accel_top.m_axi_*`, 128-bit AXI4, 64-bit address, 4-bit IDs | DMA and optional external descriptor traffic. Product DMA owns burst tracking, completion/error handling and drain. |
| Compute memory | internal four-bank SPAD, `SPAD_WORDS_PER_BANK` parameter | One scheduler admission point through `ai_spad_arbiter`; 8192 words/bank is 128 KiB, 16384 is 256 KiB. The host/debug window is a separate top-level access path, not a scheduler bypass. |
| Command lifecycle | CMDQ/CPLQ registers and 64-byte descriptors | Software publishes CMDQ tail and consumes CPLQ head. Dispatcher/command processor own hardware head/tail progression. `ai_completion_writer` commits four words before advancing CPLQ tail. |
| Interrupt | `irq` | Sticky status/event reporting from the register block; it does not retire commands. |

## Module ownership and dataflow

```text
Host AXI-Lite -> axi_lite_reg_if -> ai_accel_regs -> CMDQ/dispatcher
                                             |             |
                                             |             +-> descriptor validation / engine issue
DDR AXI4 <-> ai_axi128_dma <-> ai_spad_arbiter <-> four-bank SPAD
                                         ^               |
                                         |               +-> Matrix / SFU / KV / CNN / CNM / INT8 / FP
                          compute SPAD mux              |
Dispatcher -> completion writer <- engine result/owner--+
```

| Module | File / boundary | Ownership and review points |
|---|---|---|
| Product integration | `rtl/top/ai_accel_top.v` | Connects AXI-Lite, AXI4, queues, DMA, SPAD, engines, reset and IRQ. Default SPAD is 4 × 8192 × 4 B. |
| Register interface | `rtl/control/axi_lite_reg_if.v`, `rtl/control/ai_accel_regs.v` | AXI-Lite handshake and register state. Register block emits start/abort/DMA controls but does not advance queue pointers. |
| Dispatch/lifecycle | `rtl/control/queue/ai_parallel_compute_dispatcher.v`, `rtl/control/ai_command_processor.v` | Dispatcher owns ordinary CMDQ fetch/issue and in-order retirement; command processor owns direct/tile macro-subtask lifecycle. Check engine owner, exactly-once done, abort and reset epoch. |
| Descriptor/completion | `rtl/control/` descriptor fetch/validator and `ai_completion_writer.v` | Descriptor source/field legality; completion status/result/error and four-word commit-before-tail. |
| DMA | `rtl/dma/ai_axi128_dma.v` and burst/ID helpers | 128-bit data path, burst planning, ID-associated responses and abort drain. Check AR/R/AW/W/B, LAST, WSTRB and backpressure. |
| SPAD arbitration | `rtl/top/fabric/memory/ai_spad_arbiter.v`, `rtl/compute/ai_compute_spad_mux.v` | Arbiter is the sole scheduler-side admission point; compute mux returns responses to their originating engines. Control traffic priority and data-plane round-robin are part of the contract. |
| Matrix | `rtl/compute/matrix/ai_tensor_matrix_core.v`, `ai_tensor_matrix_array.sv` | 16×16 INT8 array, macro tiling, 4×4 tile-major operand/output conventions, banked read metadata, requant and fused writeback. Numeric/shape ABI comes from SPEC, not this summary. |
| SFU | `rtl/compute/sfu/ai_tensor_sfu_core.v` and numeric helpers | Softmax, normalization, residual, requant and activation. `ln_input_cache[0:15]` is only used by the small LayerNorm fast path; longer vectors use the generic multi-pass SPAD/divider path. Do not mistake this optimization cache size for a maximum vector-length limit. |
| KV | `rtl/compute/kv/ai_kv_cache_engine.v` | Token/head/stride address generation and read/write ownership. Validate bounds, aliasing, response and protection behavior against the ABI. |
| Other engines | `rtl/compute/cnn/`, `cnm/`, `int8/`, `fp/` | Engine-specific descriptor contracts and numerics. Shared memory/dispatch/completion rules still apply. |

## Requirement-to-testplan trace

The testpoint names and dispositions below are copied as a navigation aid from
`docs/verification/COMPUTE_CLUSTER_UVM_TESTPLAN_ZH.md` and
`dv/VERIFICATION_MATRIX.md` at this branch base. They are not newly rerun in
Round 20. In the source plan, `READY` means the requirement is specified well
enough to implement a test; it does **not** mean PASS. Execution evidence and
the current disposition remain in the dated execution RTM and source report.

| Requirement | Primary RTL ownership | Testpoint / checker in plan | Existing scope disposition |
|---|---|---|---|
| REQ-CL-001 | Dispatcher / command processor | `tc_cl_legal_start`; command monitor + owner tracker | READY test specification |
| REQ-CL-002 | Descriptor validator / dispatcher | `tc_cl_opcode_dispatch`; engine-start observation + independent decode | READY test specification |
| REQ-CL-003 | Register block / launch sampler | `tc_cl_launch_sampling`; config monitor + model | READY test specification |
| REQ-CL-004 | Descriptor validator / engines | `tc_cl_unused_field_noise`; Golden + writeback | READY test specification |
| REQ-CL-005 | Engine launch registers | `tc_cl_config_latched`; input monitor + memory scoreboard | READY test specification |
| REQ-CL-006 | Engines / SPAD interface | `tc_cl_spad_req_stability`; payload-stability checker and requester/stall crosses | PARTIAL; selected line/parity slices pass |
| REQ-CL-007 | SPAD mux / arbiter | `tc_cl_rsp_owner`; accepted-read ledger / response FIFO | READY test specification |
| REQ-CL-008 | SPAD / writeback | `tc_cl_memory_commit`; byte-aware memory scoreboard | READY test specification |
| REQ-CL-009 | CNM bank fabric | `tc_cl_cnm_bank_independent`; per-bank monitor + CNM reference | READY test specification |
| REQ-CL-010 | Matrix core / arbiter | Matrix response metadata FIFO; `MATRIX-LINE-001` | PARTIAL; depth and line slices pass, broader fault crosses open |
| REQ-CL-011 | Dispatcher / completion | `tc_cl_unique_done`; owner scoreboard + onehot SVA | READY test specification |
| REQ-CL-012 | Dispatcher result mux | `tc_cl_result_owner`; done-owner scoreboard | READY test specification |
| REQ-CL-013 | Command lifecycle | `tc_cl_completion_once`; start/done ledger + bounded watchdog | READY test specification |
| REQ-CL-014 | Arbiter / engine requesters | `tc_cl_progress_backpressure`; request ledger + fairness-bounded SVA | READY test specification |
| REQ-CL-015 | All engines | `tc_cl_normal_all_ops`; per-op oracle + memory result checker | READY test specification |
| REQ-CL-016 | Dispatcher / response routing | `tc_cl_engine_switch`; owner + stale-response checker | READY test specification |
| REQ-CL-017 | Engines / completion writer | `tc_cl_error_prefix`; prefix-memory scoreboard | PARTIAL; legal fault/phase crosses open |
| REQ-CL-018 | Top reset / DMA / SPAD | `tc_cl_reset_stale`; reset-epoch ledger + post-reset memory monitor | PARTIAL; selected Top reset slices pass |
| REQ-CL-019 | Fault priority / lifecycle | `tc_cl_fault_races`; fault-priority oracle + owner monitor | PARTIAL; full legal cross open |
| REQ-CL-020 | Scalar INT8 engine | `tb_ai_int8_numeric`, R52; independent integer model + full image | PARTIAL; common arithmetic subset passes |
| REQ-CL-021 | CNM core/reducer | `tc_cl_cnm_numeric`; bank-aware integer Golden | READY test specification |
| REQ-CL-022 | Matrix core/array | Matrix independent INT64 Golden + SPAD image; line checker | PARTIAL; selected macro/read-depth/line cases pass |
| REQ-CL-023 | SFU core/numeric helpers | `tc_cl_sfu_numeric`; Q-domain per-op Golden | PARTIAL; documented selected domain passes |
| REQ-CL-024 | CNN line buffer/core | `tc_cl_conv_window`; independent convolution image | READY test specification |
| REQ-CL-025 | KV engine / protection | `KV-ADDR-001..011`, `KV-PROT-001..004`; address oracle + image | PARTIAL; named address/protection slices pass |
| REQ-CL-026 | Mixed FP core | `tc_cl_fp_numerical`; raw-bit oracle + bus scoreboard | READY test specification |
| REQ-CL-027 | Engine error mapping | `tc_cl_error_code_table`; engine×fault mapping | PARTIAL; ABI mapping frozen, broader crosses open |
| REQ-CL-028 | Performance monitor | `tc_cl_perf_observability`; sampled event-counter scoreboard | READY test specification |
| REQ-PC-001 | Parallel dispatcher | `pair_overlap_seen[20:0]`; 21 unordered engine pairs | C0-P: 3 seeds, 21/21 in that named scope |
| REQ-PC-002 | Parallel dispatcher | Same-engine queue with other engines active; repeated active launch owner error | C0-P: 3 seeds PASS |
| REQ-PC-003 | Dispatcher / CMDQ | Busy-engine blocking and CMDQ launch/completion order comparison | C0-P: 3 seeds PASS |
| REQ-PC-004 | Completion writer / CPLQ | Differing service latency; full hold and software-consume resume | C0-P: 3 seeds PASS |
| REQ-PC-005 | Dispatcher / completion | Two engines complete on same cycle; per-owner result and FIFO order | C0-P: 3 seeds PASS |
| REQ-PC-006 | SPAD mux / arbiter | Seeded ready stalls, registered response, owner-only result/error | C0-P: 3 seeds PASS; full arbiter remains broader |
| REQ-PC-007 | Matrix/CNM banked and line paths | Per-bank/line monitor + response scoreboard | PARTIAL; integrated fault/backpressure and full per-bank UVM open |
| REQ-PC-008 | Memory image / descriptor contract | Shared-read and isolated-output scoreboard | Not covered by C0-P; C1 required |
| REQ-PC-009 | Dispatcher abort/drain | `pc_abort_drain_seq`; no-new-launch + ordered abort completions | PASS in named 3-seed C0-P scope |
| REQ-PC-010 | Top reset / fabric / owner ledger | `pc_active_reset_seq`; pending response isolation and recovery | PASS in named scoped tests; platform fabric contract still needs review |

## Round 20 model evidence boundary

- GPT-2 Track: one trained H64 model ran through the Product Top command path
  with four independent INT32-logit comparisons. This is functional evidence,
  not Compute Cluster sign-off.
- DeiT Track: the pinned official checkpoint's full patch embedding has an
  earlier Product Top pass. No encoder-layer result is claimed. The first
  consumer gap is the 192-element LayerNorm/layout contract described in the
  Round 20 DeiT report.
- The complete requirement disposition remains the owning RTM/testplan. Fault,
  reset, backpressure, concurrency and memory-ownership residuals remain open
  where marked there.
