Warning: truncated output (original token count: 168796)
Total output lines: 13127

class ai_compute_cluster_e2e_seq extends uvm_sequence #(ai_axil_item);
    `uvm_object_utils(ai_compute_cluster_e2e_seq)

    // Regression bound for the fixed legal all-engine workload only.  The
    // measured three-seed maximum is 126 cycles; this 2x guard is not a general
    // SRAM-backpressure or platform fairness guarantee.
    localparam int unsigned CLUSTER_ENGINE_WAIT_BOUND_CYCLES = 256;

    localparam bit [31:0] REG_CMDQ_CTRL = 32'h0000_00ac;
    localparam bit [31:0] REG_CMDQ_BASE = 32'h0000_0080;
    localparam bit [31:0] REG_CMDQ_SIZE = 32'h0000_0088;
    localparam bit [31:0] REG_CMDQ_HEAD = 32'h0000_008c;
    localparam bit [31:0] REG_CMDQ_TAIL = 32'h0000_00c8;
    localparam bit [31:0] REG_CPLQ_BASE = 32'h0000_0090;
    localparam bit [31:0] REG_CPLQ_SIZE = 32'h0000_0098;
    localparam bit [31:0] REG_CPLQ_TAIL = 32'h0000_009c;
    localparam bit [31:0] REG_CPLQ_HEAD = 32'h0000_00cc;
    localparam bit [31:0] REG_DOORBELL = 32'h0000_00a0;
    localparam bit [31:0] REG_ABORT = 32'h0000_00a4;
    localparam bit [31:0] REG_WATCHDOG = 32'h0000_00a8;
    localparam bit [31:0] REG_DMA_CTRL = 32'h0000_00b0;
    localparam bit [31:0] REG_DMA_STATUS = 32'h0000_00b4;
    localparam bit [31:0] REG_DMA_EXT = 32'h0000_00b8;
    localparam bit [31:0] REG_DMA_SPAD = 32'h0000_00bc;
    localparam bit [31:0] REG_DMA_LEN = 32'h0000_00c0;
    localparam bit [31:0] REG_REGION0_BASE = 32'h0000_00d4;
    localparam bit [31:0] REG_REGION0_LIMIT = 32'h0000_00d8;
    localparam bit [31:0] REG_REGION0_PERM = 32'h0000_00dc;
    localparam bit [31:0] REG_REGION1_BASE = 32'h0000_00e0;
    localparam bit [31:0] REG_REGION1_LIMIT = 32'h0000_00e4;
    localparam bit [31:0] REG_REGION1_PERM = 32'h0000_00e8;
    localparam bit [31:0] REG_REGION2_BASE = 32'h0000_00ec;
    localparam bit [31:0] REG_REGION2_LIMIT = 32'h0000_00f0;
    localparam bit [31:0] REG_REGION2_PERM = 32'h0000_00f4;
    localparam bit [31:0] REG_REGION3_BASE = 32'h0000_00f8;
    localparam bit [31:0] REG_REGION3_LIMIT = 32'h0000_00fc;
    localparam bit [31:0] REG_REGION3_PERM = 32'h0000_0100;

    localparam bit [31:0] CMDQ_LOCAL = 32'h0000_4000;
    localparam bit [31:0] CPLQ_LOCAL = 32'h0000_5000;
    localparam bit [31:0] MATRIX_A_LOCAL = 32'h0001_0000;
    localparam bit [31:0] MATRIX_B_LOCAL = 32'h0001_2000;
    localparam bit [31:0] MATRIX_Y_LOCAL = 32'h0003_0000;
    localparam bit [31:0] MATRIX_LINE_STALL_CNM_A_LOCAL = 32'h0005_0000;
    localparam bit [31:0] MATRIX_LINE_STALL_CNM_B_LOCAL = 32'h0005_2000;
    localparam bit [31:0] MATRIX_LINE_STALL_CNM_Y_LOCAL = 32'h0005_6000;
    localparam bit [31:0] GELU_A_LOCAL = 32'h0002_0000;
    localparam bit [31:0] GELU_B_LOCAL = 32'h0002_0100;
    localparam bit [31:0] GELU_Y0_LOCAL = 32'h0002_0200;
    localparam bit [31:0] GELU_Y1_LOCAL = 32'h0002_0300;
    localparam bit [31:0] CNM_A_LOCAL = 32'h0004_8000;
    localparam bit [31:0] CNM_B_LOCAL = 32'h0004_9000;
    localparam bit [31:0] CNM_Y_LOCAL = 32'h0004_a000;
    localparam bit [31:0] CLUSTER_SWEEP_CMDQ = 32'h0000_4400;
    localparam bit [31:0] CLUSTER_SWEEP_CPLQ = 32'h0000_5400;
    localparam bit [31:0] CLUSTER_CONTRACT_CMDQ = 32'h0000_4800;
    localparam bit [31:0] CLUSTER_CONTRACT_CPLQ = 32'h0000_5800;
    localparam bit [31:0] CONTRACT_SHARED_LOCAL = 32'h0004_7000;
    localparam bit [31:0] CONTRACT_B_LOCAL = 32'h0004_7200;
    localparam bit [31:0] CONTRACT_Y0_LOCAL = 32'h0004_7400;
    localparam bit [31:0] CONTRACT_Y1_LOCAL = 32'h0004_7500;
    localparam bit [31:0] CONTRACT_MUTATED_Y_LOCAL = 32'h0004_7600;
    localparam bit [31:0] CONTRACT_SFU_Y_LOCAL = 32'h0004_7800;
    localparam bit [31:0] MATRIX_LATCH_Y_LOCAL = 32'h0003_8000;
    localparam bit [31:0] MATRIX_LATCH_MUTATED_Y_LOCAL = 32'h0003_9000;
    localparam bit [31:0] SFU_LATCH_SRC_LOCAL = 32'h0004_a100;
    localparam bit [31:0] SFU_LATCH_MUTATED_SRC_LOCAL = 32'h0004_a140;
    localparam bit [31:0] SFU_LATCH_Y_LOCAL = 32'h0004_a180;
    localparam bit [31:0] SFU_LATCH_MUTATED_Y_LOCAL = 32'h0004_a1c0;
    localparam bit [31:0] SCALAR_A_LOCAL = 32'h0004_6000;
    localparam bit [31:0] SCALAR_B_LOCAL = 32'h0004_6100;
    localparam bit [31:0] SCALAR_Y_LOCAL = 32'h0004_6200;
    localparam bit [31:0] FP_A_LOCAL = 32'h0004_6400;
    localparam bit [31:0] FP_B_LOCAL = 32'h0004_6404;
    localparam bit [31:0] FP_Y_LOCAL = 32'h0004_6408;
    localparam bit [31:0] CONV_A_LOCAL = 32'h0004_6600;
    localparam bit [31:0] CONV_W_LOCAL = 32'h0004_6640;
    localparam bit [31:0] CONV_Y_LOCAL = 32'h0004_6680;
    localparam bit [31:0] KV_VECTOR_LOCAL = 32'h0004_6800;
    localparam bit [31:0] KV_CACHE_LOCAL = 32'h0004_6840;
    localparam bit [31:0] KV_READ_LOCAL = 32'h0004_6900;
    localparam bit [31:0] SWEEP_MATRIX_Y_LOCAL = 32'h0004_c000;
    localparam bit [31:0] SWEEP_CNM_Y_LOCAL = 32'h0004_c800;
    localparam bit [31:0] SWEEP_SFU_Y_LOCAL = 32'h0004_d000;
    localparam bit [31:0] FAULT_Y_LOCAL = 32'h0004_e000;
    localparam bit [31:0] MATRIX_FAULT_A_LOCAL = 32'h0004_f000;
    localparam bit [31:0] MATRIX_FAULT_B_LOCAL = 32'h0004_f100;
    localparam bit [31:0] CLUSTER_PROT_CMDQ = 32'h0000_6000;
    localparam bit [31:0] CLUSTER_PROT_CPLQ = 32'h0000_7000;
    localparam bit [31:0] CLUSTER_WATCHDOG_CMDQ = 32'h0000_7400;
    localparam bit [31:0] CLUSTER_WATCHDOG_CPLQ = 32'h0000_7500;
    localparam bit [31:0] CLUSTER_WATCHDOG_Y_LOCAL = 32'h0007_c000;
    localparam bit [31:0] C1_CNM_A_LOCAL = 32'h0006_0000;
    localparam bit [31:0] C1_CNM_B_LOCAL = 32'h0006_1000;
    localparam bit [31:0] C1_CNM_Y_LOCAL = 32'h0006_7000;
    localparam bit [31:0] C1_SFU_A_LOCAL = 32'h0006_8000;
    localparam bit [31:0] C1_SFU_Y_LOCAL = 32'h0006_8400;
    localparam bit [31:0] C1_CONV_A_LOCAL = 32'h0006_9000;
    localparam bit [31:0] C1_CONV_W_LOCAL = 32'h0006_9400;
    localparam bit [31:0] C1_CONV_Y_LOCAL = 32'h0006_9800;
    localparam bit [31:0] C1_KV_VECTOR_LOCAL = 32'h0006_a000;
    localparam bit [31:0] C1_KV_CACHE_LOCAL = 32'h0006_a400;
    localparam bit [31:0] C1_KV_READ_LOCAL = 32'h0006_a800;
    localparam bit [31:0] C1_SCALAR_A_LOCAL = 32'h0006_b000;
    localparam bit [31:0] C1_SCALAR_B_LOCAL = 32'h0006_b400;
    localparam bit [31:0] C1_SCALAR_Y_LOCAL = 32'h0006_b800;
    localparam bit [31:0] C1_FP_A_LOCAL = 32'h0006_c000;
    localparam bit [31:0] C1_FP_B_LOCAL = 32'h0006_c100;
    localparam bit [31:0] C1_FP_Y_LOCAL = 32'h0006_c200;
    localparam bit [31:0] FP_LATCH_A_LOCAL = 32'h0006_d000;
    localparam bit [31:0] FP_LATCH_B_LOCAL = 32'h0006_d100;
    localparam bit [31:0] FP_LATCH_MUTATED_A_LOCAL = 32'h0006_d200;
    localparam bit [31:0] FP_LATCH_MUTATED_B_LOCAL = 32'h0006_d300;
    localparam bit [31:0] FP_LATCH_Y_LOCAL = 32'h0006_d400;
    localparam bit [31:0] FP_LATCH_MUTATED_Y_LOCAL = 32'h0006_d500;
    localparam bit [31:0] CONV_LATCH_A_LOCAL = 32'h0006_e000;
    localparam bit [31:0] CONV_LATCH_W_LOCAL = 32'h0006_e100;
    localparam bit [31:0] CONV_LATCH_MUTATED_A_LOCAL = 32'h0006_e200;
    localparam bit [31:0] CONV_LATCH_MUTATED_W_LOCAL = 32'h0006_e300;
    localparam bit [31:0] CONV_LATCH_Y_LOCAL = 32'h0006_e400;
    localparam bit [31:0] CONV_LATCH_MUTATED_Y_LOCAL = 32'h0006_e500;
    localparam bit [31:0] KV_LATCH_SRC_LOCAL = 32'h0006_f000;
    localparam bit [31:0] KV_LATCH_MUTATED_SRC_LOCAL = 32'h0006_f200;
    localparam bit [31:0] KV_LATCH_CACHE_LOCAL = 32'h0006_f400;
    localparam bit [31:0] KV_LATCH_MUTATED_CACHE_LOCAL = 32'h0006_f800;
    localparam bit [31:0] CNM_LATCH_Y_LOCAL = 32'h0004_e300;
    localparam bit [31:0] CNM_LATCH_MUTATED_Y_LOCAL = 32'h0004_e400;
    localparam bit [31:0] SCALAR_OPCODE_CMDQ = 32'h0005_a000;
    localparam bit [31:0] SCALAR_OPCODE_CPLQ = 32'h0005_a400;
    localparam bit [31:0] SCALAR_OPCODE_A_LOCAL = 32'h0007_0000;
    localparam bit [31:0] SCALAR_OPCODE_B_LOCAL = 32'h0007_0040;
    localparam bit [31:0] SCALAR_OPCODE_Y_LOCAL = 32'h0007_0080;
    localparam bit [31:0] PARALLEL_FAULT_CMDQ = 32'h0000_4600;
    localparam bit [31:0] PARALLEL_FAULT_CPLQ = 32'h0000_5c00;
    localparam bit [31:0] PARALLEL_FAULT_MATRIX_Y = 32'h0007_d000;
    localparam bit [31:0] PARALLEL_FAULT_CNM_Y = 32'h0007_d800;
    localparam bit [31:0] PARALLEL_FAULT_SFU_Y = 32'h0007_d900;
    localparam bit [31:0] PARALLEL_FAULT_SCALAR_Y = 32'h0007_db00;
    localparam bit [31:0] PARALLEL_FAULT_FP_Y = 32'h0007_db10;
    localparam bit [31:0] PARALLEL_FAULT_CONV_Y = 32'h0007_dc00;
    localparam bit [31:0] PARALLEL_FAULT_KV_CACHE = 32'h0007_e000;
    localparam bit [31:0] MATRIX_MULTI_A_LOCAL = 32'h0000_b000;
    localparam bit [31:0] MATRIX_MULTI_B_LOCAL = 32'h0000_b800;
    localparam bit [31:0] MATRIX_MULTI_Y_LOCAL = 32'h0000_d000;

    virtual ai_compute_cluster_if compute_vif;
    bit [31:0] rng_state;
    string mutation_kind;
    int unsigned shared_reset_coverage_phase;
    int unsigned shared_reset_prefix_coverage_phase;
    int unsigned cnm_protection_reset_prefix_coverage_phase;
    int unsigned sfu_reset_prefix_phase;
    int unsigned conv_reset_prefix_phase;
    int unsigned scalar_reset_prefix_phase;
    int unsigned fp_reset_single_write_phase;
    int unsigned engine_watchdog_cov_idx;
    int unsigned engine_watchdog_cplq_cov_idx;
    int unsigned engine_parity_cplq_cov_idx;
    int unsigned engine_abort_cplq_cov_idx;
    int unsigned matrix_protection_reset_phase;
    int unsigned matrix_protection_cnm_reset_phase;
    int unsigned engine_protection_reset_engine;
    bit engine_protection_reset_operand_b;
    int unsigned engine_protection_reset_phase;
    int unsigned fp16_abort_zero_prefix_hit;

    covergroup fp16_abort_zero_prefix_cg;
        option.per_instance = 1;
        cp_fp16_abort_zero_prefix: coverpoint fp16_abort_zero_prefix_hit {
            bins verified_zero_prefix = {1};
        }
    endgroup

    covergroup matrix_cnm_shared_reset_cg;
        option.per_instance = 1;
        cp_reset_recovery_phase: coverpoint shared_reset_coverage_phase {
            bins parity_with_cnm_reads_pending = {1};
            bins reset_quiet_window = {2};
            bins release_quiet_window = {3};
            bins full_golden_recovery = {4};
        }
    endgroup

    covergroup matrix_cnm_prefix_reset_cg;
        option.per_instance = 1;
        cp_reset_prefix_recovery_phase: coverpoint shared_reset_prefix_coverage_phase {
            bins nonempty_prefix_with_pending_read = {1};
            bins reset_quiet_window = {2};
            bins release_quiet_window = {3};
            bins prefix_and_suffix_preserved = {4};
            bins full_golden_recovery = {5};
        }
    endgroup

    covergroup cnm_protection_matrix_prefix_reset_cg;
        option.per_instance = 1;
        cp_cnm_protection_matrix_prefix_phase: coverpoint cnm_protection_reset_prefix_coverage_phase {
            bins cnm_protection_consumed_with_matrix_active = {1};
            bins matrix_golden_prefix_after_protection = {2};
            bins reset_quiet_window = {3};
            bins release_quiet_window = {4};
            bins prefix_and_suffix_preserved = {5};
            bins full_golden_recovery = {6};
        }
    endgroup

    covergroup sfu_reset_prefix_cg;
        option.per_instance = 1;
        cp_sfu_reset_prefix_phase: coverpoint sfu_reset_prefix_phase {
            bins sfu_task_busy = {1};
            bins accepted_golden_prefix = {2};
            bins reset_quiet_window = {3};
            bins release_quiet_window = {4};
            bins prefix_suffix_and_completion_preserved = {5};
            bins full_golden_recovery = {6};
        }
    endgroup

    covergroup conv_reset_prefix_cg;
        option.per_instance = 1;
        cp_conv_reset_prefix_phase: coverpoint conv_reset_prefix_phase {
            bins conv_task_busy = {1};
            bins accepted_golden_prefix = {2};
            bins reset_quiet_window = {3};
            bins release_quiet_window = {4};
            bins prefix_suffix_and_completion_preserved = {5};
            bins full_golden_recovery = {6};
        }
    endgroup

    covergroup scalar_reset_prefix_cg;
        option.per_instance = 1;
        cp_scalar_reset_prefix_phase: coverpoint scalar_reset_prefix_phase {
            bins scalar_task_busy = {1};
            bins accepted_golden_prefix = {2};
            bins reset_quiet_window = {3};
            bins release_quiet_window = {4};
            bins prefix_suffix_and_completion_preserved = {5};
            bins full_golden_recovery = {6};
        }
    endgroup

    covergroup fp_reset_single_write_cg;
        option.per_instance = 1;
        cp_fp_reset_single_write_phase: coverpoint fp_reset_single_write_phase {
            bins task_busy = {1};
            bins sole_result_accepted = {2};
            bins reset_quiet_window = {3};
            bins release_quiet_window = {4};
            bins old_completion_suppressed_and_result_preserved = {5};
            bins new_epoch_recovery = {6};
        }
    endgroup

    covergroup engine_watchdog_cg;
        option.per_instance = 1;
        cp_engine_watchdog: coverpoint engine_watchdog_cov_idx {
            bins scalar_int8 = {0};
            bins fp = {1};
            bins cnm = {2};
            bins matrix = {3};
            bins sfu = {4};
            bins conv = {5};
            bins kv = {6};
        }
    endgroup

    covergroup engine_watchdog_cplq_cg;
        option.per_instance = 1;
        cp_engine_watchdog_cplq: coverpoint engine_watchdog_cplq_cov_idx {
            bins scalar_int8 = {0};
            bins fp = {1};
            bins cnm = {2};
            bins matrix = {3};
            bins sfu = {4};
            bins conv = {5};
            bins kv = {6};
        }
    endgroup

    covergroup engine_parity_cplq_cg;
        option.per_instance = 1;
        cp_engine_parity_cplq: coverpoint engine_parity_cplq_cov_idx {
            bins scalar_int8 = {0};
            bins fp = {1};
            bins cnm = {2};
            bins matrix = {3};
            bins sfu = {4};
            bins conv = {5};
            bins kv = {6};
        }
    endgroup

    covergroup engine_abort_cplq_cg;
        option.per_instance = 1;
        cp_engine_abort_cplq: coverpoint engine_abort_cplq_cov_idx {
            bins scalar_int8 = {0};
            bins fp = {1};
            bins cnm = {2};
            bins matrix = {3};
            bins sfu = {4};
            bins conv = {5};
            bins kv = {6};
        }
    endgroup

    int unsigned engine_pair_overlap_cov_idx;
    int unsigned cmdq_invalid_descriptor_case;
    int unsigned opcode_dispatch_case;
    int unsigned fp16_cmdq_numeric_case;
    int unsigned conv_descriptor_boundary_case;
    int unsigned depthwise_descriptor_boundary_case;
    int unsigned depthwise_channel_sequence_case;
    int unsigned matrix_multitile_shape_case;
    int unsigned engine_parallel_fault_cov_idx;
    int unsigned engine_parallel_reset_phase;
    covergroup cmdq_invalid_descriptor_cg;
        option.per_instance = 1;
        cp_engine_descriptor_reject: coverpoint cmdq_invalid_descriptor_case {
            bins scalar_zero_length = {0};
            bins cnm_zero_length = {1};
            bins matrix_dimension = {2};
            bins sfu_zero_length = {3};
            bins conv_minimum_dimension = {4};
            bins kv_zero_length = {5};
            bins mixed_fp_reserved_field = {6};
            bins macro_minimum_child_count = {7};
        }
    endgroup

    covergroup opcode_dispatch_cg;
        option.per_instance = 1;
        cp_opcode_dispatch: coverpoint opcode_dispatch_case {
            bins op_10 = {0}; bins op_11 = {1}; bins op_12 = {2}; bins op_13 = {3};
            bins op_14 = {4}; bins op_15 = {5}; bins op_16 = {6}; bins op_17 = {7};
            bins op_20 = {8}; bins op_21 = {9}; bins op_30 = {10}; bins op_31 = {11};
            bins op_32 = {12}; bins op_33 = {13}; bins op_34 = {14}; bins op_35 = {15};
            bins op_36 = {16}; bins op_37 = {17}; bins op_38 = {18}; bins op_39 = {19};
            bins op_43 = {20}; bins op_44 = {21}; bins op_50 = {22}; bins op_51 = {23};
        }
    endgroup

    covergroup fp16_cmdq_numeric_cg;
        option.per_instance = 1;
        cp_fp16_cmdq_numeric: coverpoint fp16_cmdq_numeric_case {
            bins two_term_exact_six = {1};
        }
    endgroup

    covergroup conv_descriptor_boundary_cg;
        option.per_instance = 1;
        cp_conv_descriptor_boundary: coverpoint conv_descriptor_boundary_case {
            bins minimum_3x3 = {0};
            bins maximum_width_3x128 = {1};
        }
    endgroup

    covergroup depthwise_descriptor_boundary_cg;
        option.per_instance = 1;
        cp_depthwise_descriptor_boundary: coverpoint depthwise_descriptor_boundary_case {
            bins minimum_3x3 = {0};
            bins maximum_width_3x128 = {1};
        }
    endgroup

    covergroup depthwise_channel_sequence_cg;
        option.per_instance = 1;
        cp_depthwise_channel_sequence: coverpoint depthwise_channel_sequence_case {
            bins two_channel_descriptors = {1};
        }
    endgroup

    covergroup matrix_multitile_shape_cg;
        option.per_instance = 1;
        cp_matrix_multitile_shape: coverpoint matrix_multitile_shape_case {
            bins two_by_two_array_tiles = {1};
        }
    endgroup

    covergroup engine_parallel_fault_cg;
        option.per_instance = 1;
        cp_engine_fault_with_parallel_recovery: coverpoint engine_parallel_fault_cov_idx {
            bins scalar_parity_with_six_engine_completions = {0};
            bins fp_parity_with_six_engine_completions = {1};
            bins cnm_parity_with_six_engine_completions = {2};
            bins matrix_parity_with_six_engine_completions = {3};
            bins sfu_parity_with_six_engine_completions = {4};
            bins conv_parity_with_six_engine_completions = {5};
            bins kv_parity_with_six_engine_completions = {6};
        }
    endgroup

    covergroup engine_parallel_reset_cg;
        option.per_instance = 1;
        cp_engine_parallel_reset_phase: coverpoint engine_parallel_reset_phase {
            bins seven_engine_overlap_with_pending_reads = {1};
            bins old_epoch_quiet_and_unretired = {2};
            bins seven_engine_golden_recovery = {3};
        }
    endgroup

    covergroup engine_pair_overlap_cg;
        option.per_instance = 1;
        cp_engine_pair_overlap: coverpoint engine_pair_overlap_cov_idx {
            bins int8_matrix = {0};
            bins int8_cnm = {1};
            bins int8_bf16 = {2};
            bins int8_sfu = {3};
            bins int8_conv = {4};
            bins int8_kv = {5};
            bins matrix_cnm = {6};
            bins matrix_bf16 = {7};
            bins matrix_sfu = {8};
            bins matrix_conv = {9};
            bins matrix_kv = {10};
            bins cnm_bf16 = {11};
            bins cnm_sfu = {12};
            bins cnm_conv = {13};
            bins cnm_kv = {14};
            bins bf16_sfu = {15};
            bins bf16_conv = {16};
            bins bf16_kv = {17};
            bins sfu_conv = {18};
            bins sfu_kv = {19};
            bins conv_kv = {20};
        }
    endgroup

    int unsigned c1_shared_read_alias_case;
    covergroup c1_shared_read_alias_cg;
        option.per_instance = 1;
        cp_scalar_kv_shared_read: coverpoint c1_shared_read_alias_case {
            bins scalar_kv_same_source_with_overlapping_reads = {1};
        }
    endgroup

    covergroup engine_progress_bound_cg with function sample(
        bit [6:0] stalled_mask, int unsigned max_wait_cycles);
        option.per_instance = 1;
        cp_expected_stall_mask: coverpoint stalled_mask {
            bins six_contended_engine_ports = {7'b1110111};
        }
        cp_wait_within_bound: coverpoint max_wait_cycles {
            bins observed_wait_within_bound = {[1:256]};
        }
        cp_bounded_progress: cross cp_expected_stall_mask, cp_wait_within_bound;
    endgroup

    covergroup matrix_protection_reset_cg;
        option.per_instance = 1;
        cp_matrix_protection_reset_phase: coverpoint matrix_protection_reset_phase {
            bins legal_task_launched = {1};
            bins source_b_protection_denied_after_a_read = {2};
            bins protection_error_code_observed = {3};
            bins reset_suppressed_old_completion_and_writeback = {4};
            bins reset_release_quiet_window = {5};
            bins new_epoch_full_golden_recovery = {6};
        }
    endgroup

    covergroup matrix_protection_cnm_reset_cg;
        option.per_instance = 1;
        cp_matrix_protection_cnm_reset_phase: coverpoint matrix_protection_cnm_reset_phase {
            bins legal_matrix_and_cnm_tasks_launched = {1};
            bins matrix_source_b_protection_observed = {2};
            bins cnm_read_response_pending_at_reset = {3};
            bins reset_quiet_window = {4};
            bins release_quiet_and_old_side_effects_suppressed = {5};
            bins matrix_cnm_golden_recovery = {6};
        }
    endgroup

    covergroup engine_protection_reset_cg;
        option.per_instance = 1;
        cp_engine: coverpoint engine_protection_reset_engine {
            bins scalar = {0};
            bins fp = {1};
            bins cnm = {2};
            bins matrix = {3};
            bins sfu = {4};
            bins conv = {5};
            bins kv = {6};
        }
        cp_operand: coverpoint engine_protection_reset_operand_b {
            bins source_a = {1'b0};
            bins source_b = {1'b1};
        }
        cp_phase: coverpoint engine_protection_reset_phase {
            bins launched = {1};
            bins operand_denied = {2};
            bins protection_error_observed = {3};
            bins reset_epoch_flushed = {4};
            bins old_side_effects_suppressed = {5};
            bins recovery_completion = {6};
        }
        engine_operand_phase_cross: cross cp_engine, cp_operand, cp_phase {
            ignore_bins sfu_has_no_source_b =
                binsof(cp_engine.sfu) && binsof(cp_operand.source_b);
            ignore_bins kv_has_no_source_b =
                binsof(cp_engine.kv) && binsof(cp_operand.source_b);
        }
    endgroup

    function automatic int signed next_small_signed();
        int unsigned value;
        rng_state = rng_state ^ (rng_state << 13);
        rng_state = rng_state ^ (rng_state >> 17);
        rng_state = rng_state ^ (rng_state << 5);
        value = rng_state % 5;
        return int'(value) - 2;
    endfunction

    // Independent REQ-CL-002 oracle from the frozen opcode-to-engine table.
    // Engine indices match engine_busy[6:0]: Scalar, FP, CNM, Matrix, SFU,
    // Conv, KV.
    function automatic int expected_engine_for_dispatch_opcode(input bit [7:0] opcode);
        if ((opcode >= 8'h10) && (opcode <= 8'h15))
            return 0;
        if ((opcode == 8'h50) || (opcode == 8'h51))
            return 1;
        if ((opcode == 8'h20) || (opcode == 8'h21))
            return 2;
        if ((opcode == 8'h30) || (opcode == 8'h31))
            return 3;
        if ((opcode >= 8'h32) && (opcode <= 8'h39))
            return 4;
        if ((opcode == 8'h16) || (opcode == 8'h17))
            return 5;
        if ((opcode == 8'h43) || (opcode == 8'h44))
            return 6;
        return -1;
    endfunction

    function new(string name = "ai_compute_cluster_e2e_seq");
        super.new(name);
        shared_reset_coverage_phase = 0;
        shared_reset_prefix_coverage_phase = 0;
        cnm_protection_reset_prefix_coverage_phase = 0;
        sfu_reset_prefix_phase = 0;
        conv_reset_prefix_phase = 0;
        scalar_reset_prefix_phase = 0;
        fp_reset_single_write_phase = 0;
        engine_watchdog_cov_idx = 0;
        engine_watchdog_cplq_cov_idx = 0;
        engine_parity_cplq_cov_idx = 0;
        engine_abort_cplq_cov_idx = 0;
        engine_pair_overlap_cov_idx = 0;
        matrix_protection_reset_phase = 0;
        matrix_protection_cnm_reset_phase = 0;
        engine_protection_reset_engine = 0;
        engine_protection_reset_operand_b = 1'b0;
        engine_protection_reset_phase = 0;
        fp16_abort_zero_prefix_hit = 0;
        fp16_abort_zero_prefix_cg = new();
        matrix_cnm_shared_reset_cg = new();
        matrix_cnm_prefix_reset_cg = new();
        cnm_protection_matrix_prefix_reset_cg = new();
        sfu_reset_prefix_cg = new();
        conv_reset_prefix_cg = new();
        scalar_reset_prefix_cg = new();
        fp_reset_single_write_cg = new();
        engine_watchdog_cg = new();
        engine_watchdog_cplq_cg = new();
        engine_parity_cplq_cg = new();
        engine_abort_cplq_cg = new();
        cmdq_invalid_descriptor_cg = new();
        opcode_dispatch_cg = new();
        fp16_cmdq_numeric_case = 0;
        fp16_cmdq_numeric_cg = new();
        conv_descriptor_boundary_cg = new();
        depthwise_descriptor_boundary_cg = new();
        depthwise_channel_sequence_cg = new();
        matrix_multitile_shape_case = 0;
        matrix_multitile_shape_cg = new();
        engine_parallel_fault_cg = new();
        engine_parallel_reset_cg = new();
        engine_pair_overlap_cg = new();
        c1_shared_read_alias_case = 0;
        c1_shared_read_alias_cg = new();
        engine_progress_bound_cg = new();
        matrix_protection_reset_cg = new();
        matrix_protection_cnm_reset_cg = new();
        engine_protection_reset_cg = new();
    endfunction

    task automatic axil_write(input bit [31:0] addr, input bit [31:0] data);
        ai_axil_item req;
        req = ai_axil_item::type_id::create("cluster_axil_write");
        start_item(req);
        req.is_write = 1'b1;
        req.addr = addr;
        req.data = data;
        req.strb = 4'hf;
        finish_item(req);
        if (req.resp !== 2'b00)
            `uvm_fatal("CLUSTER_AXIL", $sformatf("write addr=0x%08h resp=%0h", addr, req.resp))
    endtask

    task automatic axil_read(input bit [31:0] addr, output bit [31:0] data);
        ai_axil_item req;
        uvm_hdl_data_t host_error_state;
        uvm_hdl_data_t host_parity_state;
        uvm_hdl_data_t host_protection_state;
        uvm_hdl_data_t spad_request_state;
        req = ai_axil_item::type_id::create("cluster_axil_read");
        start_item(req);
        req.is_write = 1'b0;
        req.addr = addr;
        req.data = '0;
        req.strb = '0;
        finish_item(req);
        if (req.resp !== 2'b00) begin
            void'(uvm_hdl_read("tb_ai_accel_uvm.dut.spad_host_error", host_error_state));
            void'(uvm_hdl_read("tb_ai_accel_uvm.dut.spad_host_parity_error", host_parity_state));
            void'(uvm_hdl_read("tb_ai_accel_uvm.dut.host_prot_allow", host_protection_state));
            void'(uvm_hdl_read("tb_ai_accel_uvm.dut.spad_req_valid", spad_request_state));
            `uvm_fatal("CLUSTER_AXIL", $sformatf(
                "read addr=0x%08h resp=%0h rdata=0x%08h host_error=%0b host_parity_error=%0b host_prot_allow=%0b spad_req_valid=%0b",
                addr, req.resp, req.rdata, host_error_state[0],
                host_parity_state[0], host_protection_state[0],
                spad_request_state[0]))
        end
        data = req.rdata;
    endtask

    task automatic spad_write(input bit [31:0] addr, input bit [31:0] data);
        axil_write(CIMFORGE_SPAD_BASE + addr, data);
    endtask

    task automatic backdoor_write_spad_word(input bit [31:0] addr,
                                             input bit [31:0] data,
                                             input string tag);
        int unsigned word_addr;
        int unsigned bank;
        int unsigned row;
        string data_path;
        string parity_path;
        bit data_ok;
        bit parity_ok;
        // Host-port writes during a compute-port request are contractually
        // rejected by the behavioral SPAD. Use a parity-consistent backdoor
        // mutation to isolate launch-snapshot retention from that collision.
        word_addr = addr >> 2;
        bank = word_addr & 3;
        row = word_addr >> 2;
        data_path = $sformatf(
            "tb_ai_accel_uvm.dut.spad_subsystem_u.scratchpad_u.bank%0d[%0d]",
            bank, row);
        parity_path = $sformatf(
            "tb_ai_accel_uvm.dut.spad_subsystem_u.scratchpad_u.bank%0d_parity[%0d]",
            bank, row);
        data_ok = uvm_hdl_deposit(data_path, data);
        parity_ok = uvm_hdl_deposit(parity_path, ^data);
        if (!data_ok || !parity_ok)
            `uvm_fatal("CLUSTER_DESC_BACKDOOR", $sformatf(
                "%s failed descriptor mutation data_ok=%0b parity_ok=%0b data_path=%s parity_path=%s",
                tag, data_ok, parity_ok, data_path, parity_path))
    endtask

    task automatic expect_spad(input bit [31:0] addr, input bit [31:0] expected, input string tag);
        bit [31:0] actual;
        int tag_len;
        bit completion_status_or_error;
        axil_read(CIMFORGE_SPAD_BASE + addr, actual);
        tag_len = tag.len();
        completion_status_or_error = (addr[3:0] == 4'h4) &&
            (((tag_len >= 7) && (tag.substr(tag_len - 7, tag_len - 1) == " status")) ||
             ((tag_len >= 11) && (tag.substr(tag_len - 11, tag_len - 1) == " completion")));
        if (actual !== expected) begin
            if ((mutation_kind == "completion_error_code") &&
                (tag == "random parity case0 ERR_PARITY completion")) begin
                `uvm_info("CLUSTER_MUTATION_CAUGHT",
                    "mutation=completion_error_code checker=completion_error_code", UVM_LOW)
                `uvm_error("CLUSTER_COMPLETION_ERROR_CODE", $sformatf(
                    "%s addr=0x%08h expected=0x%08h actual=0x%08h",
                    tag, addr, expected, actual))
            end else if (completion_status_or_error) begin
                `uvm_fatal("CLUSTER_COMPLETION_ERROR_CODE", $sformatf(
                    "%s addr=0x%08h expected=0x%08h actual=0x%08h",
                    tag, addr, expected, actual))
            end else begin
                `uvm_fatal("CLUSTER_GOLDEN", $sformatf(
                    "%s addr=0x%08h expected=0x%08h actual=0x%08h",
                    tag, addr, expected, actual))
            end
        end
    endtask

    task automatic write_v3_desc(
        input bit [31:0] base,
        input bit [7:0] op,
        input bit [15:0] task_id,
        input bit [31:0] src0,
        input bit [31:0] src1,
        input bit [31:0] dst,
        input bit [15:0] m,
        input bit [15:0] n,
        input bit [15:0] length_or_k
    );
        spad_write(base + 32'h00, {task_id, 8'd0, op});
        spad_write(base + 32'h04, src0);
        spad_write(base + 32'h08, src1);
        spad_write(base + 32'h0c, 32'd0);
        spad_write(base + 32'h10, dst);
        spad_write(base + 32'h14, {n, m});
        spad_write(base + 32'h18, {16'd0, length_or_k});
        spad_write(base + 32'h1c, 32'd0);
        spad_write(base + 32'h20, 32'd1);
        spad_write(base + 32'h24, 32'd0);
        spad_write(base + 32'h28, 32'd0);
        spad_write(base + 32'h2c, 32'd0);
        spad_write(base + 32'h30, 32'd0);
        spad_write(base + 32'h34, 32'h0001_0001);
        spad_write(base + 32'h38, 32'd0);
        spad_write(base + 32'h3c, 32'd3);
    endtask

    task automatic write_cluster_desc(
        input bit [31:0] base,
        input bit [7:0] op,
        input bit [15:0] task_id,
        input bit [31:0] src0,
        input bit [31:0] src1,
        input bit [31:0] dst,
        input bit [15:0] m,
        input bit [15:0] n,
        input bit [15:0] length,
        input bit [31:0] aux0,
        input bit [31:0] src0_stride,
        input bit [31:0] src1_stride,
        input bit [31:0] dst_stride,
        input bit [7:0] version
    );
        spad_write(base + 32'h00, {task_id, 8'd0, op});
        spad_write(base + 32'h04, src0);
        spad_write(base + 32'h08, src1);
        spad_write(base + 32'h0c, 32'd0);
        spad_write(base + 32'h10, dst);
        spad_write(base + 32'h14, {n, m});
        spad_write(base + 32'h18, {16'd0, length});
        spad_write(base + 32'h1c, 32'd0);
        spad_write(base + 32'h20, aux0);
        spad_write(base + 32'h24, 32'd0);
        spad_write(base + 32'h28, src0_stride);
        spad_write(base + 32'h2c, src1_stride);
        spad_write(base + 32'h30, dst_stride);
        // FP descriptors require both counts to be zero. Other engines accept
        // zero as the ABI default of one batch/head.
        spad_write(base + 32'h34, 32'd0);
        spad_write(base + 32'h38, 32'd0);
        spad_write(base + 32'h3c, {16'd0, version});
    endtask

    task automatic write_cnm_v3_desc(
        input bit [31:0] base,
        input bit [15:0] task_id,
        input bit [31:0] src0,
        input bit [31:0] src1,
        input bit [31:0] dst
    );
        spad_write(base + 32'h00, {task_id, 8'd0, 8'h21});
        spad_write(base + 32'h04, src0);
        spad_write(base + 32'h08, src1);
        spad_write(base + 32'h0c, 32'd0);
        spad_write(base + 32'h10, dst);
        spad_write(base + 32'h14, {16'd1, 16'd16});
        spad_write(base + 32'h18, 32'd1);
        spad_write(base + 32'h1c, 32'd0);
        spad_write(base + 32'h20, 32'd0);
        spad_write(base + 32'h24, 32'd0);
        spad_write(base + 32'h28, 32'd0);
        spad_write(base + 32'h2c, 32'd0);
        spad_write(base + 32'h30, 32'd0);
        spad_write(base + 32'h34, 32'h0001_0001);
        spad_write(base + 32'h38, 32'd0);
        spad_write(base + 32'h3c, 32'd3);
    endtask

    task automatic expect_completion(
        input bit [31:0] base,
        input bit [15:0] task_id,
        input bit [31:0] result,
        input bit [31:0] elements,
        input string tag
    );
        expect_spad(base + 32'h00, {16'd0, task_id}, {tag, " task_id"});
        expect_spad(base + 32'h04, 32'h0000_0001, {tag, " status"});
        expect_spad(base + 32'h08, result, {tag, " result"});
        expect_spad(base + 32'h0c, elements, {tag, " elements"});
    endtask

    task automatic inject_spad_parity_fault(
        input bit [31:0] addr,
        output string parity_path,
        output uvm_hdl_data_t saved_parity
    );
        int bank;
        int row;
        bit ok;
        uvm_hdl_data_t corrupt_parity;
        bank = (addr >> 2) & 3;
        row = addr >> 4;
        parity_path = $sformatf(
            "tb_ai_accel_uvm.dut.spad_subsystem_u.scratchpad_u.bank%0d_parity[%0d]",
            bank, row);
        if (!uvm_hdl_read(parity_path, saved_parity))
            `uvm_fatal("CLUSTER_FAULT", $sformatf("cannot read parity bit at %s", parity_path))
        corrupt_parity = saved_parity;
        corrupt_parity[0] = ~saved_parity[0];
        ok = uvm_hdl_deposit(parity_path, corrupt_parity);
        if (!ok)
            `uvm_fatal("CLUSTER_FAULT", $sformatf("cannot inject parity fault at %s", parity_path))
    endtask

    task automatic restore_spad_parity(
        input string parity_path,
        input uvm_hdl_data_t saved_parity
    );
        bit ok;
        ok = uvm_hdl_deposit(parity_path, saved_parity);
        if (!ok)
            `uvm_fatal("CLUSTER_FAULT", $sformatf("cannot restore parity bit at %s", parity_path))
    endtask

    task automatic run_random_parity_case(
        input int unsigned case_id,
        input int unsigned seed
    );
        int unsigned fault_engine;
        int unsigned fault_phase;
        int unsigned cnm_lane;
        int unsigned word_idx;
        bit [31:0] src0;
        bit [31:0] src1;
        bit [31:0] dst;
        bit [31:0] desc_addr;
        bit [31:0] cpl_addr;
        bit [31:0] fault_addr;
        bit [7:0] opcode;
        bit [31:0] expected_status_error;
        string parity_path;
        uvm_hdl_data_t saved_parity;

        if (case_id < 2) begin
            fault_engine = 0; // INT8 scalar
            fault_phase = case_id;
            cnm_lane = 0;
        end else if (case_id < 4) begin
            fault_engine = 1; // Matrix banked read
            fault_phase = case_id - 2;
            cnm_lane = 0;
        end else if (case_id < 12) begin
            fault_engine = 2; // CNM lane-local A/B read
            fault_phase = (case_id - 4) % 2;
            cnm_lane = (case_id - 4) / 2;
        end else if (case_id < 14) begin
            fault_engine = 3; // BF16 dot
            fault_phase = case_id - 12;
            cnm_lane = 0;
        end else if (case_id == 14) begin
            fault_engine = 4; // SFU vector input
            fault_phase = 0;
            cnm_lane = 0;
        end else if (case_id < 17) begin
            fault_engine = 5; // Conv input / weight
            fault_phase = case_id - 15;
            cnm_lane = 0;
        end else begin
            fault_engine = 6; // KV source vector
            fault_phase = 0;
            cnm_lane = 0;
        end

        dst = FAULT_Y_LOCAL + (case_id * 32'h100);
        desc_addr = CLUSTER_SWEEP_CMDQ + 32'h200 + (case_id * 32'h40);
        cpl_addr = CLUSTER_SWEEP_CPLQ + 32'h200 + (case_id * 32'h10);
        for (word_idx = 0; word_idx < 16; word_idx++)
            spad_write(dst + (word_idx << 2), 32'hfa17_0000 | (case_id << 8) | word_idx);

        case (fault_engine)
            0: begin
                opcode = 8'h10;
                src0 = SCALAR_A_LOCAL;
                src1 = SCALAR_B_LOCAL;
                fault_addr = fault_phase ? src1 : src0;
                write_cluster_desc(desc_addr, opcode, 16'h0700 + case_id,
                                   src0, src1, dst, 16'd0, 16'd0, 16'd1,
                                   32'd0, 32'd0, 32'd0, 32'd0, 8'd3);
            end
            1: begin
                opcode = 8'h30;
                src0 = MATRIX_FAULT_A_LOCAL;
                src1 = MATRIX_FAULT_B_LOCAL;
                fault_addr = fault_phase ? src1 : src0;
                write_v3_desc(desc_addr, opcode, 16'h0700 + case_id,
                              src0, src1, dst, 16'd4, 16'd4, 16'd1);
            end
            2: begin
                opcode = 8'h21;
                src0 = CNM_A_LOCAL;
                src1 = CNM_B_LOCAL;
                fault_addr = (fault_phase ? src1 : src0) + (cnm_lane << 2);
                write_cnm_v3_desc(desc_addr, 16'h0700 + case_id,
                                  src0, src1, dst);
            end
            default: begin
                case (fault_engine)
                    3: begin
                        opcode = 8'h50;
                        src0 = FP_A_LOCAL;
                        src1 = FP_B_LOCAL;
                        fault_addr = fault_phase ? src1 : src0;
                        write_cluster_desc(desc_addr, opcode, 16'h0700 + case_id,
                                           src0, src1, dst, 16'd1, 16'd1, 16'd2,
                                           32'd0, 32'd0, 32'd0, 32'd0, 8'd7);
                    end
                    4: begin
                        opcode = 8'h35;
                        src0 = GELU_A_LOCAL;
                        src1 = 32'd0;
                        fault_addr = src0;
                        write_v3_desc(desc_addr, opcode, 16'h0700 + case_id,
                                      src0, src1, dst, 16'd0, 16'd0, 16'd4);
                    end
                    5: begin
                        opcode = 8'h16;
                        src0 = CONV_A_LOCAL;
                        src1 = CONV_W_LOCAL;
                        fault_addr = fault_phase ? src1 : src0;
                        write_cluster_desc(desc_addr, opcode, 16'h0700 + case_id,
                                           src0, src1, dst, 16'd3, 16'd3, 16'd9,
                                           32'd0, 32'd0, 32'd0, 32'd0, 8'd5);
                    end
                    default: begin
                        opcode = 8'h43;
                        src0 = KV_VECTOR_LOCAL;
                        src1 = 32'd0;
                        fault_addr = src0;
                        write_cluster_desc(desc_addr, opcode, 16'h0700 + case_id,
                                           src0, src1, dst, 16'd0, 16'd0, 16'd4,
                                           {16'd1,16'd1}, 32'd16, 32'd64,
                                           32'd0, 8'd5);
                    end
                endcase
            end
        endcase

        inject_spad_parity_fault(fault_addr, parity_path, saved_parity);
        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, desc_addr);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd1);
        axil_write(REG_CPLQ_BASE, cpl_addr);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd1);
        wait_spad_idle();
        restore_spad_parity(parity_path, saved_parity);

        expected_status_error = ((fault_engine == 5) || (fault_engine == 6)) ?
                                32'h0000_0072 : 32'h0000_0052;
        if ((mutation_kind == "completion_error_code") && (case_id == 0)) begin
            // Testbench memory-image corruption checks that the directed
            // completion oracle rejects an incorrect error-code word. This
            // is not a DUT RTL mutation.
            spad_write(cpl_addr + 32'h04, expected_status_error ^ 32'd1);
            `uvm_info("CLUSTER_MUTATION_INJECTED",
                "mutation=completion_error_code target=completion_word1", UVM_LOW)
        end
        expect_spad(cpl_addr + 32'h00, 32'h0000_0700 + case_id,
                    $sformatf("random parity case%0d task ID", case_id));
        expect_spad(cpl_addr + 32'h04, expected_status_error,
                    $sformatf("random parity case%0d ERR_PARITY completion", case_id));
        for (word_idx = 0; word_idx < 16; word_idx++)
            expect_spad(dst + (word_idx << 2),
                        32'hfa17_0000 | (case_id << 8) | word_idx,
                        $sformatf("random parity case%0d no-writeback[%0d]", case_id, word_idx));
        `uvm_info("CLUSTER_FAULT_CASE_PASS", $sformatf(
            "case=%0d engine=%0d operand_phase=%0d cnm_lane=%0d address=0x%08h seed=%0d",
            case_id, fault_engine, fault_phase, cnm_lane, fault_addr, seed), UVM_LOW)
        axil_write(REG_CPLQ_HEAD, 32'd1);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
    endtask

    task automatic run_matrix_parity_cnm_owner_cross(
        input int unsigned seed,
        input int unsigned mode,
        input int signed matrix_golden[0:15][0:31]);
        bit [31:0] desc_base;
        bit [31:0] cpl_base;
        bit [31:0] matrix_dst;
        bit [31:0] cnm_dst;
        bit [31:0] parity_addr;
        bit [31:0] packed_word;
        bit [31:0] matrix_rsp_before;
        bit [31:0] cnm_rsp_before;
        bit [31:0] matrix_route_error_before;
        bit [31:0] cnm_route_error_before;
        bit [31:0] overlap_before;
        bit [31:0] shared_accept_before;
        int unsigned fault_cancel_before;
        string parity_path;
        uvm_hdl_data_t saved_parity;
        int signed expected_cnm[0:15];
        int signed a_value;
        int signed b_value;
        int unsigned row_idx;
        int unsigned k_word;
        int unsigned lane;
        int unsigned byte_idx;
        int unsigned word_idx;
        int unsigned cycle;
        int unsigned accepted_cnm_reads;
        int unsigned returned_cnm_reads;
        int unsigned accepted_cnm_writes;
        int unsigned post_abort_cnm_writes;
        bit abort_cnm_after_parity;
        bit reset_both_after_parity;
        bit reset_after_cnm_prefix;
        bit reset_seen;
        bit reset_value;
        bit overlap_seen;
        bit shared_accept_seen;
        bit matrix_response_seen;
        bit cnm_response_seen;
        bit route_mismatch_seen;
        bit abort_issued;
        bit abort_seen;
        bit abort_active_seen;
        bit monitor_done;
        int unsigned dropped_cnm_reads;
        int unsigned poll;
        bit [31:0] value;
        bit [31:0] cnm_write_addr[0:15];
        bit [31:0] cnm_write_data[0:15];

        if (mode > 3)
            `uvm_fatal("CLUSTER_PARITY_OWNER", $sformatf(
                "unsupported Matrix/CNM parity-owner mode %0d", mode))
        abort_cnm_after_parity = (mode == 1);
        reset_after_cnm_prefix = (mode == 3);
        reset_both_after_parity = (mode == 2) || reset_after_cnm_prefix;
        reset_seen = 1'b0;
        overlap_seen = 1'b0;
        shared_accept_seen = 1'b0;
        matrix_response_seen = 1'b0;
        cnm_response_seen = 1'b0;
        route_mismatch_seen = 1'b0;
        desc_base = 32'h0000_7800;
        cpl_base = 32'h0000_7900;
        matrix_dst = 32'h0005_4000;
        cnm_dst = 32'h0005_4800;
        // The baseline point faults the final A-row lane to exercise held-read
        // cancellation. The abort cross faults the first legal operand so the
        // long CNM task is still active when Matrix reports parity.
        parity_addr = reset_after_cnm_prefix ?
                      MATRIX_A_LOCAL + 32'h0000_00fc :
                      ((abort_cnm_after_parity || reset_both_after_parity) ?
                       MATRIX_A_LOCAL : MATRIX_A_LOCAL + 32'h0000_00fc);
        abort_issued = 1'b0;
        abort_seen = 1'b0;
        abort_active_seen = 1'b0;
        monitor_done = 1'b0;
        accepted_cnm_reads = 0;
        returned_cnm_reads = 0;
        accepted_cnm_writes = 0;
        post_abort_cnm_writes = 0;
        dropped_cnm_reads = 0;

        // Prepare a long legal CNM GEMV independently of Matrix's operand
        // image, so the failing Matrix cannot poison CNM's Golden result.
        for (k_word = 0; k_word < 32; k_word++) begin
            for (lane = 0; lane < 4; lane++) begin
                packed_word = '0;
                for (byte_idx = 0; byte_idx < 4; byte_idx++) begin
                    a_value = int'(k_word % 5) + int'(lane * 2) +
                              int'(byte_idx) - 5;
                    packed_word[byte_idx*8 +: 8] = a_value[7:0];
                end
                spad_write(MATRIX_LINE_STALL_CNM_A_LOCAL +
                           (k_word << 4) + (lane << 2), packed_word);
            end
        end
        for (row_idx = 0; row_idx < 16; row_idx++) begin
            expected_cnm[row_idx] = 0;
            for (k_word = 0; k_word < 32; k_word++) begin
                for (lane = 0; lane < 4; lane++) begin
                    packed_word = '0;
                    for (byte_idx = 0; byte_idx < 4; byte_idx++) begin
                        a_value = int'(k_word % 5) + int'(lane * 2) +
                                  int'(byte_idx) - 5;
                        b_value = int'(row_idx % 5) + int'(k_word % 3) +
                                  int'(lane) + int'(byte_idx) - 3;
                        packed_word[byte_idx*8 +: 8] = b_value[7:0];
                        expected_cnm[row_idx] += a_value * b_value;
                    end
                    spad_write(MATRIX_LINE_STALL_CNM_B_LOCAL +
                               ((row_idx * 32 + k_word) << 4) +
                               (lane << 2), packed_word);
                end
            end
        end

        for (word_idx = 0; word_idx < 512; word_idx++)
            spad_write(matrix_dst + (word_idx << 2),
                       32'hfa17_7000 | word_idx);
        for (word_idx = 0; word_idx < 16; word_idx++)
            spad_write(cnm_dst + (word_idx << 2),
                       32'hfa17_7800 | word_idx);
        if (reset_both_after_parity)
            for (word_idx = 0; word_idx < 8; word_idx++)
                spad_write(cpl_base + ((word_idx / 4) * 32'h10) +
                           ((word_idx % 4) * 4),
                           32'hfa17_7900 | word_idx);

        if (abort_cnm_after_parity || reset_both_after_parity) begin
            // Dispatch CNM first so it is observably in flight before Matrix
            // reaches the injected parity response and Abort/reset cancels it.
            write_cluster_desc(desc_base, 8'h21,
                               reset_after_cnm_prefix ? 16'h07ec :
                               (reset_both_after_parity ? 16'h07e8 : 16'h07e3),
                               MATRIX_LINE_STALL_CNM_A_LOCAL,
                               MATRIX_LINE_STALL_CNM_B_LOCAL, cnm_dst,
                               16'd16, 16'd1, 16'd32, 32'd0,
                               32'd0, 32'd0, 32'd0, 8'd3);
            write_v3_desc(desc_base + 32'h40, 8'h30,
                          reset_after_cnm_prefix ? 16'h07ed :
                          (reset_both_after_parity ? 16'h07e9 : 16'h07e2),
                          MATRIX_A_LOCAL, MATRIX_B_LOCAL, matrix_dst,
                          16'd16, 16'd32, 16'd16);
        end else begin
            write_v3_desc(desc_base, 8'h30, 16'h07e0,
                          MATRIX_A_LOCAL, MATRIX_B_LOCAL, matrix_dst,
                          16'd16, 16'd32, 16'd16);
            write_cluster_desc(desc_base + 32'h40, 8'h21, 16'h07e1,
                               MATRIX_LINE_STALL_CNM_A_LOCAL,
                               MATRIX_LINE_STALL_CNM_B_LOCAL, cnm_dst,
                               16'd16, 16'd1, 16'd32, 32'd0,
                               32'd0, 32'd0, 32'd0, 8'd3);
        end

        matrix_rsp_before = compute_vif.matrix_tag_response_count;
        cnm_rsp_before = compute_vif.cnm_tag_response_count;
        matrix_route_error_before = compute_vif.matrix_route_mismatch_count;
        cnm_route_error_before = compute_vif.cnm_route_mismatch_count;
        overlap_before = compute_vif.matrix_cnm_overlap_cycles;
        shared_accept_before = compute_vif.matrix_cnm_shared_accept_cycles;
        fault_cancel_before = compute_vif.matrix_banked_fault_cancel_checks;
        inject_spad_parity_fault(parity_addr, parity_path, saved_parity);

        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, desc_base);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd2);
        axil_write(REG_CPLQ_BASE, cpl_base);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        if (!abort_cnm_after_parity && !reset_both_after_parity) begin
            axil_write(REG_DOORBELL, 32'd1);
            wait_cpl_tail(32'd2);
            wait_spad_idle();
        end else begin
            fork
                begin : matrix_parity_cnm_abort_monitor
                    while (!monitor_done) begin
                        @(posedge compute_vif.aclk);
                        accepted_cnm_reads += $countones(compute_vif.cnm_accept_mask);
                        returned_cnm_reads += $countones(compute_vif.cnm_rsp_valid);
                        if (compute_vif.engine_busy[2] &&
                            compute_vif.engine_busy[3])
                            overlap_seen = 1'b1;
                        if (compute_vif.matrix_cnm_shared_accept_cycles >
                            shared_accept_before)
                            shared_accept_seen = 1'b1;
                        if (compute_vif.matrix_tag_response_count > matrix_rsp_before)
                            matrix_response_seen = 1'b1;
                        if (compute_vif.cnm_tag_response_count > cnm_rsp_before)
                            cnm_response_seen = 1'b1;
                        if (compute_vif.matrix_route_mismatch_count !=
                                matrix_route_error_before ||
                            compute_vif.cnm_route_mismatch_count !=
                                cnm_route_error_before)
                            route_mismatch_seen = 1'b1;
                        if (compute_vif.engine_req_valid[2] &&
                            compute_vif.engine_req_ready[2] &&
                            compute_vif.engine_req_write[2] &&
                            (compute_vif.engine_req_addr[2*32 +: 32] >= cnm_dst) &&
                            (compute_vif.engine_req_addr[2*32 +: 32] < cnm_dst + 32'h40)) begin
                            if (accepted_cnm_writes >= 16)
                                `uvm_fatal("CLUSTER_PARITY_ABORT_OWNER",
                                    "CNM accepted more output writes than its 16-row GEMV")
                            cnm_write_addr[accepted_cnm_writes] =
                                compute_vif.engine_req_addr[2*32 +: 32];
                            cnm_write_data[accepted_cnm_writes] =
                                compute_vif.engine_req_wdata[2*32 +: 32];
                            if (cnm_write_addr[accepted_cnm_writes] !==
                                cnm_dst + (accepted_cnm_writes << 2))
                                `uvm_fatal("CLUSTER_PARITY_ABORT_OWNER", $sformatf(
                                    "CNM Abort output writes are not a contiguous prefix: index=%0d expected=0x%08h actual=0x%08h",
                                    accepted_cnm_writes,
                                    cnm_dst + (accepted_cnm_writes << 2),
                                    cnm_write_addr[accepted_cnm_writes]))
                            accepted_cnm_writes++;
                            if (abort_active_seen)
                                post_abort_cnm_writes++;
                        end
                        if (compute_vif.dut_abort_active) begin
                            abort_seen = 1'b1;
                            abort_active_seen = 1'b1;
                        end
                    end
                end
                begin : matrix_parity_cnm_abort_control
                    axil_write(REG_DOORBELL, 32'd1);
                    for (cycle = 0; cycle < 30000 && !abort_issued; cycle++) begin
                        @(posedge compute_vif.aclk);
                        if ((abort_cnm_after_parity &&
                             compute_vif.matrix_response_fault) ||
                            (reset_both_after_parity &&
                             compute_vif.engine_parity_rsp_error[3])) begin
                            if (!compute_vif.engine_busy[2])
                                `uvm_fatal("CLUSTER_PARITY_ABORT_OWNER",
                                    "Matrix parity was reported after the concurrent CNM engine became idle")
                            if (reset_both_after_parity) begin
                                // Matrix sampled the registered parity response
                                // on this edge. Reset at +1ns while CNM still
                                // has a response outstanding in the shared SPAD.
                                #1ns;
                                if (!compute_vif.engine_busy[3] ||
                                    (accepted_cnm_reads <= returned_cnm_reads))
                                    `uvm_fatal("CLUSTER_PARITY_RESET_OWNER", $sformatf(
                                        "reset point lacks concurrent Matrix/CNM activity or a pending CNM response: busy=%07b accepted=%0d returned=%0d",
                                        compute_vif.engine_busy, accepted_cnm_reads,
                                        returned_cnm_reads))
                                dropped_cnm_reads = accepted_cnm_reads -
                                                   returned_cnm_reads;
                                matrix_response_seen = 1'b1;
                                cnm_response_seen = (returned_cnm_reads != 0);
                                if (!reset_after_cnm_prefix) begin
                                    shared_reset_coverage_phase = 1;
                                    matrix_cnm_shared_reset_cg.sample();
                                end
                                if (accepted_cnm_writes >= 16)
                                    `uvm_fatal("CLUSTER_PARITY_RESET_OWNER",
                                        "CNM completed before the shared-reset point")
                                if (reset_after_cnm_prefix &&
                                    (accepted_cnm_writes == 0 ||
                                     accepted_cnm_writes >= 16))
                                    `uvm_fatal("CLUSTER_PARITY_RESET_PREFIX_OWNER", $sformatf(
                                        "prefix-reset point requires 1..15 accepted Golden writes, observed %0d/16",
                                        accepted_cnm_writes))
                                if (reset_after_cnm_prefix) begin
                                    shared_reset_prefix_coverage_phase = 1;
                                    matrix_cnm_prefix_reset_cg.sample();
                                end
                                reset_value = 1'b0;
                                if (!uvm_hdl_deposit("tb_ai_accel_uvm.aresetn",
                                                     reset_value))
                                    `uvm_fatal("CLUSTER_PARITY_RESET_OWNER",
                                        "failed to assert reset during Matrix/CNM overlap")
                                restore_spad_parity(parity_path, saved_parity);
                                reset_seen = 1'b1;
                                monitor_done = 1'b1;
                                repeat (4) begin
                                    @(posedge compute_vif.aclk);
                                    if (compute_vif.rsp_valid !== 1'b0 ||
                                        compute_vif.matrix_rsp_valid !== 1'b0 ||
                                        compute_vif.cnm_rsp_valid !== 4'b0 ||
                                        compute_vif.engine_parity_rsp_error !== 7'b0)
                                        `uvm_fatal("CLUSTER_PARITY_RESET_OWNER",
                                            "old-epoch response visible while reset is asserted")
                                end
                                if (compute_vif.engine_busy !== 7'b0)
                                    `uvm_fatal("CLUSTER_PARITY_RESET_OWNER", $sformatf(
                                        "compute engines remained active in reset: busy=%07b",
                                        compute_vif.engine_busy))
                                if (!reset_after_cnm_prefix) begin
                                    shared_reset_coverage_phase = 2;
                                    matrix_cnm_shared_reset_cg.sample();
                                end
                                if (reset_after_cnm_prefix) begin
                                    shared_reset_prefix_coverage_phase = 2;
                                    matrix_cnm_prefix_reset_cg.sample();
                                end
                                #1ns;
                                reset_value = 1'b1;
                                if (!uvm_hdl_deposit("tb_ai_accel_uvm.aresetn",
                                                     reset_value))
                                    `uvm_fatal("CLUSTER_PARITY_RESET_OWNER",
                                        "failed to release reset after Matrix/CNM overlap")
                                repeat (8) begin
                                    @(posedge compute_vif.aclk);
                                    if (compute_vif.rsp_valid !== 1'b0 ||
                                        compute_vif.matrix_rsp_valid !== 1'b0 ||
                                        compute_vif.cnm_rsp_valid !== 4'b0 ||
                                        compute_vif.engine_parity_rsp_error !== 7'b0)
                                        `uvm_fatal("CLUSTER_PARITY_RESET_OWNER",
                                            "stale owner response escaped the reset epoch")
                                end
                                if (!reset_after_cnm_prefix) begin
                                    shared_reset_coverage_phase = 3;
                                    matrix_cnm_shared_reset_cg.sample();
                                end
                                if (reset_after_cnm_prefix) begin
                                    shared_reset_prefix_coverage_phase = 3;
                                    matrix_cnm_prefix_reset_cg.sample();
                                end
                            end else begin
                                axil_write(REG_ABORT, 32'd1);
                            end
                            abort_issued = 1'b1;
                        end
                    end
                    if (!abort_issued)
                        `uvm_fatal("CLUSTER_PARITY_ABORT_OWNER",
                            "Matrix parity response was not observed in the concurrent scenario")
                    if (abort_cnm_after_parity)
                        wait_cpl_tail(32'd2);
                    monitor_done = 1'b1;
                end
            join
            wait_spad_idle();
            if (abort_cnm_after_parity && !abort_seen)
                `uvm_fatal("CLUSTER_PARITY_ABORT_OWNER",
                    "CNM did not sample software Abort while draining Matrix parity")
            if (accepted_cnm_reads == 0 ||
                (abort_cnm_after_parity &&
                 returned_cnm_reads != accepted_cnm_reads))
                `uvm_fatal("CLUSTER_PARITY_ABORT_OWNER", $sformatf(
                    "CNM parity/Abort read drain mismatch: accepted=%0d returned=%0d",
                    accepted_cnm_reads, returned_cnm_reads))
            if (reset_both_after_parity && !reset_seen)
                `uvm_fatal("CLUSTER_PARITY_RESET_OWNER",
                    "shared reset did not occur after Matrix sampled the parity response")
            if (post_abort_cnm_writes != 0)
                `uvm_fatal("CLUSTER_PARITY_ABORT_OWNER", $sformatf(
                    "CNM accepted %0d output writes after Abort sampling",
                    post_abort_cnm_writes))
        end
        restore_spad_parity(parity_path, saved_parity);

        if ((!reset_both_after_parity &&
             compute_vif.matrix_cnm_overlap_cycles <= overlap_before) ||
            (reset_both_after_parity && !overlap_seen))
            `uvm_fatal("CLUSTER_PARITY_OWNER",
                "Matrix parity fault and CNM valid task never overlapped on real engines")
        if ((!reset_both_after_parity &&
             compute_vif.matrix_cnm_shared_accept_cycles <= shared_accept_before) ||
            (reset_both_after_parity && !shared_accept_seen))
            `uvm_fatal("CLUSTER_PARITY_OWNER",
                "Matrix/CNM did not contend for shared banked admission in parity-owner cross")
        if (!abort_cnm_after_parity && !reset_both_after_parity &&
            ((compute_vif.matrix_banked_fault_cancel_checks -
              fault_cancel_before) != 1))
            `uvm_fatal("CLUSTER_PARITY_OWNER", $sformatf(
                "expected exactly one Matrix held-read cancellation on parity response, observed %0d",
                compute_vif.matrix_banked_fault_cancel_checks - fault_cancel_before))
        if ((abort_cnm_after_parity || reset_both_after_parity) &&
            ((compute_vif.matrix_banked_fault_cancel_checks -
              fault_cancel_before) > 1))
            `uvm_fatal("CLUSTER_PARITY_ABORT_OWNER", $sformatf(
                "unexpected repeated Matrix fault-cancel observation count=%0d",
                compute_vif.matrix_banked_fault_cancel_checks - fault_cancel_before))
        if ((!reset_both_after_parity &&
             (compute_vif.matrix_tag_response_count <= matrix_rsp_before ||
              compute_vif.cnm_tag_response_count <= cnm_rsp_before)) ||
            (reset_both_after_parity &&
             (!matrix_response_seen || !cnm_response_seen)))
            `uvm_fatal("CLUSTER_PARITY_OWNER", $sformatf(
                "missing response owner activity: Matrix %0d->%0d CNM %0d->%0d",
                matrix_rsp_before, compute_vif.matrix_tag_response_count,
                cnm_rsp_before, compute_vif.cnm_tag_response_count))
        if ((!reset_both_after_parity &&
             (compute_vif.matrix_route_mismatch_count != matrix_route_error_before ||
              compute_vif.cnm_route_mismatch_count != cnm_route_error_before)) ||
            (reset_both_after_parity && route_mismatch_seen))
            `uvm_fatal("CLUSTER_PARITY_OWNER", $sformatf(
                "response owner cross-route mismatch: Matrix %0d->%0d CNM %0d->%0d",
                matrix_route_error_before, compute_vif.matrix_route_mismatch_count,
                cnm_route_error_before, compute_vif.cnm_route_mismatch_count))

        if (abort_cnm_after_parity) begin
            expect_spad(cpl_base, 32'h0000_07e3,
                        "Matrix parity/CNM Abort first CMDQ completion");
            expect_spad(cpl_base + 32'h04, 32'h0000_0032,
                        "Matrix parity/CNM Abort first status");
            expect_spad(cpl_base + 32'h10, 32'h0000_07e2,
                        "Matrix parity second CMDQ completion");
            expect_spad(cpl_base + 32'h14, 32'h0000_0052,
                        "Matrix parity second status");
            for (word_idx = 0; word_idx < 16; word_idx++) begin
                if (word_idx < accepted_cnm_writes) begin
                    if (cnm_write_data[word_idx] !== expected_cnm[word_idx])
                        `uvm_fatal("CLUSTER_PARITY_ABORT_OWNER", $sformatf(
                            "CNM accepted Abort-prefix Golden mismatch index=%0d expected=%0d actual=%0d",
                            word_idx, expected_cnm[word_idx],
                            $signed(cnm_write_data[word_idx])))
                    expect_spad(cnm_dst + (word_idx << 2), expected_cnm[word_idx],
                                $sformatf("parity/Abort CNM Golden prefix[%0d]", word_idx));
                end else
                    expect_spad(cnm_dst + (word_idx << 2),
                                32'hfa17_7800 | word_idx,
                                $sformatf("parity/Abort CNM untouched suffix[%0d]", word_idx));
            end
        end else if (reset_both_after_parity) begin
            axil_read(REG_CPLQ_TAIL, value);
            if (value !== 32'd0)
                `uvm_fatal("CLUSTER_PARITY_RESET_OWNER", $sformatf(
                    "shared reset published old-epoch completion tail=%0d", value))
            for (word_idx = 0; word_idx < 8; word_idx++)
                expect_spad(cpl_base + ((word_idx / 4) * 32'h10) +
                            ((word_idx % 4) * 4),
                            32'hfa17_7900 | word_idx,
                            $sformatf("shared reset completion sentinel[%0d]", word_idx));
            for (word_idx = 0; word_idx < 512; word_idx++)
                expect_spad(matrix_dst + (word_idx << 2),
                            32'hfa17_7000 | word_idx,
                            $sformatf("shared reset Matrix sentinel[%0d]", word_idx));
            for (word_idx = 0; word_idx < 16; word_idx++) begin
                if (word_idx < accepted_cnm_writes) begin
                    if (cnm_write_data[word_idx] !== expected_cnm[word_idx])
                        `uvm_fatal("CLUSTER_PARITY_RESET_OWNER", $sformatf(
                            "pre-reset CNM prefix Golden mismatch index=%0d expected=%0d actual=%0d",
                            word_idx, expected_cnm[word_idx],
                            $signed(cnm_write_data[word_idx])))
                    expect_spad(cnm_dst + (word_idx << 2), expected_cnm[word_idx],
                                $sformatf("shared reset CNM accepted prefix[%0d]", word_idx));
                end else
                    expect_spad(cnm_dst + (word_idx << 2),
                                32'hfa17_7800 | word_idx,
                                $sformatf("shared reset CNM untouched suffix[%0d]", word_idx));
            end
            if (reset_after_cnm_prefix) begin
                shared_reset_prefix_coverage_phase = 4;
                matrix_cnm_prefix_reset_cg.sample();
            end

            // Replay both operations in the clean epoch and compare their
            // complete independently generated Golden images and completions.
            write_cluster_desc(desc_base, 8'h21,
                               reset_after_cnm_prefix ? 16'h07ec : 16'h07ea,
                               MATRIX_LINE_STALL_CNM_A_LOCAL,
                               MATRIX_LINE_STALL_CNM_B_LOCAL, cnm_dst,
                               16'd16, 16'd1, 16'd32, 32'd0,
                               32'd0, 32'd0, 32'd0, 8'd3);
            write_v3_desc(desc_base + 32'h40, 8'h30,
                          reset_after_cnm_prefix ? 16'h07ed : 16'h07eb,
                          MATRIX_A_LOCAL, MATRIX_B_LOCAL, matrix_dst,
                          16'd16, 16'd32, 16'd16);
            configure_contract_queues(cpl_base, 32'd2);
            // This scenario stores descriptors in its private queue at 0x7800;
            // configure_contract_queues() normally points at the shared 0x4800
            // queue used by the surrounding contract tests.
            axil_write(REG_CMDQ_BASE, desc_base);
            axil_write(REG_DOORBELL, 32'd1);
            wait_cpl_tail(32'd2);
            wait_spad_idle();
            expect_completion(cpl_base,
                              reset_after_cnm_prefix ? 16'h07ec : 16'h07ea,
                              expected_cnm[15], 32'd16,
                              "shared-reset recovery CNM");
            expect_completion(cpl_base + 32'h10,
                              reset_after_cnm_prefix ? 16'h07ed : 16'h07eb,
                              matrix_golden[15][31], 32'd512,
                              "shared-reset recovery Matrix");
            for (word_idx = 0; word_idx < 16; word_idx++)
                expect_spad(cnm_dst + (word_idx << 2), expected_cnm[word_idx],
                            $sformatf("shared reset recovery CNM Golden[%0d]", word_idx));
            for (row_idx = 0; row_idx < 16; row_idx++)
                for (word_idx = 0; word_idx < 32; word_idx++)
                    expect_spad(matrix_dst + (((row_idx * 32) + word_idx) << 2),
                                matrix_golden[row_idx][word_idx],
                                $sformatf("shared reset recovery Matrix Golden[%0d,%0d]",
                                          row_idx, word_idx));
            if (reset_after_cnm_prefix) begin
                shared_reset_prefix_coverage_phase = 5;
                matrix_cnm_prefix_reset_cg.sample();
                if (matrix_cnm_prefix_reset_cg.get_coverage() < 100.0)
                    `uvm_fatal("CLUSTER_PARITY_RESET_PREFIX_OWNER", $sformatf(
                        "prefix shared-reset functional bins incomplete: coverage=%0.1f%%",
                        matrix_cnm_prefix_reset_cg.get_coverage()))
                `uvm_info("CLUSTER_PARITY_RESET_PREFIX_COVERAGE_PASS", $sformatf(
                    "Matrix/CNM parity reset with accepted-write prefix phases=5/5 coverage=%0.1f%%",
                    matrix_cnm_prefix_reset_cg.get_coverage()), UVM_LOW)
            end else begin
                shared_reset_coverage_phase = 4;
                matrix_cnm_shared_reset_cg.sample();
                if (matrix_cnm_shared_reset_cg.get_coverage() < 100.0)
                    `uvm_fatal("CLUSTER_PARITY_RESET_OWNER", $sformatf(
                        "named shared-reset functional bins are incomplete: coverage=%0.1f%%",
                        matrix_cnm_shared_reset_cg.get_coverage()))
                `uvm_info("CLUSTER_PARITY_RESET_OWNER_COVERAGE_PASS", $sformatf(
                    "shared Matrix/CNM parity reset phase bins=4/4 coverage=%0.1f%%",
                    matrix_cnm_shared_reset_cg.get_coverage()), UVM_LOW)
            end
        end else begin
            expect_spad(cpl_base, 32'h0000_07e0,
                        "concurrent parity Matrix task ID/order");
            expect_spad(cpl_base + 32'h04, 32'h0000_0052,
                        "concurrent parity Matrix error owner");
            expect_completion(cpl_base + 32'h10, 16'h07e1,
                              expected_cnm[15], 32'd16,
                              "concurrent parity CNM success/order");
        end
        if (!reset_both_after_parity)
            for (word_idx = 0; word_idx < 512; word_idx++)
                expect_spad(matrix_dst + (word_idx << 2),
                            32'hfa17_7000 | word_idx,
                            $sformatf("concurrent parity Matrix no-writeback[%0d]", word_idx));
        if (!abort_cnm_after_parity && !reset_both_after_parity)
            for (word_idx = 0; word_idx < 16; word_idx++)
                expect_spad(cnm_dst + (word_idx << 2), expected_cnm[word_idx],
                            $sformatf("concurrent parity CNM Golden[%0d]", word_idx));

        if (abort_cnm_after_parity)
            `uvm_info("CLUSTER_PARITY_ABORT_OWNER_CROSS_PASS", $sformatf(
                "Matrix ERR_PARITY=0x52 observed while CNM active; software Abort retires CNM ERR_ABORT=0x32 then Matrix parity in CMDQ order; overlap_cycles=%0d shared_banked_accepts=%0d matrix_rsp=%0d cnm_rsp=%0d route_mismatch=0; held-read fault cancellations=%0d CNM accepted_prefix=%0d/16 post_abort_writes=%0d; CNM Golden prefix/suffix and read drain checked; seed=%0d",
                compute_vif.matrix_cnm_overlap_cycles - overlap_before,
                compute_vif.matrix_cnm_shared_accept_cycles - shared_accept_before,
                compute_vif.matrix_tag_response_count - matrix_rsp_before,
                compute_vif.cnm_tag_response_count - cnm_rsp_before,
                compute_vif.matrix_banked_fault_cancel_checks - fault_cancel_before,
                accepted_cnm_writes, post_abort_cnm_writes, seed), UVM_LOW)
        else if (reset_both_after_parity) begin
            `uvm_info("CLUSTER_PARITY_RESET_OWNER_CROSS_PASS", $sformatf(
                "Matrix consumed ERR_PARITY=0x52 while CNM had pending registered reads; shared reset discarded both old-epoch tasks; CNM reads accepted=%0d returned=%0d reset-dropped=%0d accepted-write-prefix=%0d/16; recovery checked complete Matrix/CNM Golden images and ordered completions; seed=%0d",
                accepted_cnm_reads, returned_cnm_reads, dropped_cnm_reads,
                accepted_cnm_writes, seed), UVM_LOW)
            if (reset_after_cnm_prefix)
                `uvm_info("CLUSTER_PARITY_RESET_PREFIX_OWNER_CROSS_PASS", $sformatf(
                    "Matrix consumed ERR_PARITY=0x52 at the final A-row address while CNM had pending reads; shared reset preserved accepted Golden prefix=%0d/16 and untouched suffix; reads accepted=%0d returned=%0d reset-dropped=%0d; full ordered Golden recovery passed; seed=%0d",
                    accepted_cnm_writes, accepted_cnm_reads, returned_cnm_reads,
                    dropped_cnm_reads, seed), UVM_LOW)
        end else
            `uvm_info("CLUSTER_PARITY_OWNER_CROSS_PASS", $sformatf(
                "real Matrix ERR_PARITY=0x52 and concurrent CNM Golden pass; overlap_cycles=%0d shared_banked_accepts=%0d matrix_rsp=%0d cnm_rsp=%0d route_mismatch=0; held-read fault cancellations=%0d; no Matrix writeback; ordered completion; seed=%0d",
                compute_vif.matrix_cnm_overlap_cycles - overlap_before,
                compute_vif.matrix_cnm_shared_accept_cycles - shared_accept_before,
                compute_vif.matrix_tag_response_count - matrix_rsp_before,
                compute_vif.cnm_tag_response_count - cnm_rsp_before,
                compute_vif.matrix_banked_fault_cancel_checks - fault_cancel_before,
                seed), UVM_LOW)

        axil_write(REG_CPLQ_HEAD, 32'd2);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
    endtask

    task automatic run_matrix_protection_cnm_owner_cross(
        input int unsigned seed,
        input bit abort_cnm_after_protection,
        input bit deny_cnm_writeback,
        input bit hold_dual_faults_behind_full_cplq);
        bit [31:0] desc_base;
        bit [31:0] cpl_base;
        bit [31:0] matrix_dst;
        bit [31:0] cnm_dst;
        bit [31:0] matrix_desc_base;
        bit [31:0] cnm_desc_base;
        bit [31:0] cplq_scalar_src0;
        bit [31:0] cplq_scalar_src1;
        bit [31:0] cplq_scalar_dst;
        bit [31:0] cplq_sfu_src;
        bit [31:0] cplq_sfu_dst;
        bit [31:0] cplq_kv_src;
        bit [31:0] cplq_kv_dst;
        bit [31:0] packed_word;
        bit [31:0] matrix_rsp_before;
        bit [31:0] cnm_rsp_before;
        bit [31:0] matrix_route_error_before;
        bit [31:0] cnm_route_error_before;
        bit [31:0] overlap_before;
        bit [31:0] shared_accept_before;
        bit [31:0] queue_pointer;
        bit [31:0] queue_head;
        bit [31:0] queue_size;
        bit [31:0] command_head;
        bit protection_seen;
        bit cnm_protection_seen;
        bit abort_issued;
        bit busy_seen;
        bit monitor_done;
        int unsigned cycle;
        int unsigned cnm_busy_cycles;
        int unsigned matrix_busy_cycles;
        int unsigned both_busy_cycles;
        int unsigned parallel_active_cycles;
        int unsigned cnm_launch_before;
        int unsigned matrix_launch_before;
        int signed expected_cnm[0:15];
        int signed cplq_sfu_input[0:3];
        int signed cplq_sfu_golden[0:3];
        int signed a_value;
        int signed b_value;
        int unsigned row_idx;
        int unsigned k_word;
        int unsigned lane;
        int unsigned byte_idx;
        int unsigned word_idx;
        bit [15:0] matrix_task_id;
        bit [15:0] cnm_task_id;
        bit [31:0] actual_output;

        desc_base = hold_dual_faults_behind_full_cplq ?
                    32'h0000_7600 : 32'h0000_7800;
        cpl_base = 32'h0000_7900;
        matrix_dst = 32'h0000_8000;
        cnm_dst = 32'h0005_4800;
        matrix_desc_base = hold_dual_faults_behind_full_cplq ?
                           desc_base + 32'hc0 : desc_base;
        cnm_desc_base = hold_dual_faults_behind_full_cplq ?
                        desc_base + 32'h100 : desc_base + 32'h40;
        cplq_scalar_src0 = 32'h0000_7a00;
        cplq_scalar_src1 = 32'h0000_7a80;
        cplq_scalar_dst = 32'h0000_7b00;
        cplq_sfu_src = 32'h0000_7b20;
        cplq_sfu_dst = 32'h0000_7c20;
        cplq_kv_src = 32'h0000_7d20;
        cplq_kv_dst = 32'h0000_7da0;
        protection_seen = 1'b0;
        cnm_protection_seen = 1'b0;
        abort_issued = 1'b0;
        busy_seen = 1'b0;
        monitor_done = 1'b0;
        cnm_busy_cycles = 0;
        matrix_busy_cycles = 0;
        both_busy_cycles = 0;
        parallel_active_cycles = 0;
        matrix_task_id = abort_cnm_after_protection ? 16'h07d2 : 16'h07d0;
        cnm_task_id = abort_cnm_after_protection ? 16'h07d3 : 16'h07d1;
        if (hold_dual_faults_behind_full_cplq) begin
            matrix_task_id = 16'h07e0;
            cnm_task_id = 16'h07e1;
        end

        // A legal CNM GEMV uses its own contiguous protected window and an
        // independent output image for concurrent owner/Golden checking.
        for (k_word = 0; k_word < 32; k_word++) begin
            for (lane = 0; lane < 4; lane++) begin
                packed_word = '0;
                for (byte_idx = 0; byte_idx < 4; byte_idx++) begin
                    a_value = int'(k_word % 5) + int'(lane * 2) +
                              int'(byte_idx) - 5;
                    packed_word[byte_idx*8 +: 8] = a_value[7:0];
                end
                spad_write(MATRIX_LINE_STALL_CNM_A_LOCAL +
                           (k_word << 4) + (lane << 2), packed_word);
            end
        end
        for (row_idx = 0; row_idx < 16; row_idx++) begin
            expected_cnm[row_idx] = 0;
            for (k_word = 0; k_word < 32; k_word++) begin
                for (lane = 0; lane < 4; lane++) begin
                    packed_word = '0;
                    for (byte_idx = 0; byte_idx < 4; byte_idx++) begin
                        a_value = int'(k_word % 5) + int'(lane * 2) +
                                  int'(byte_idx) - 5;
                        b_value = int'(row_idx % 5) + int'(k_word % 3) +
                                  int'(lane) + int'(byte_idx) - 3;
                        packed_word[byte_idx*8 +: 8] = b_value[7:0];
                        expected_cnm[row_idx] += a_value * b_value;
                    end
                    spad_write(MATRIX_LINE_STALL_CNM_B_LOCAL +
                               ((row_idx * 32 + k_word) << 4) +
                               (lane << 2), packed_word);
                end
            end
        end

        for (word_idx = 0; word_idx < 512; word_idx++)
            spad_write(matrix_dst + (word_idx << 2),
                       32'hfa17_8000 | word_idx);
        for (word_idx = 0; word_idx < 16; word_idx++)
            spad_write(cnm_dst + (word_idx << 2),
                       32'hfa17_8800 | word_idx);

        // Keep a sentinel in the fourth ring slot. The preceding real
        // completions fill slots 0-2 before the two Protection errors retire.
        if (hold_dual_faults_behind_full_cplq) begin
            for (word_idx = 0; word_idx < 4; word_idx++)
                spad_write(cpl_base + 32'h30 + (word_idx << 2),
                           32'hc07f_7d00 | word_idx);
            for (word_idx = 0; word_idx < 32; word_idx++) begin
                spad_write(cplq_scalar_src0 + (word_idx << 2),
                           32'h0403_0201);
                spad_write(cplq_scalar_src1 + (word_idx << 2),
                           32'h0807_0605);
            end
            spad_write(cplq_scalar_dst, 32'hc07f_7a08);
            cplq_sfu_input[0] = 16;
            cplq_sfu_input[1] = -16;
            cplq_sfu_input[2] = 32;
            cplq_sfu_input[3] = -32;
            cplq_sfu_golden[0] = 8;
            cplq_sfu_golden[1] = -8;
            cplq_sfu_golden[2] = 17;
            cplq_sfu_golden[3] = -15;
            for (word_idx = 0; word_idx < 64; word_idx++) begin
                spad_write(cplq_sfu_src + (word_idx << 2),
                           cplq_sfu_input[word_idx % 4]);
                spad_write(cplq_sfu_dst + (word_idx << 2),
                           32'hc07f_7c20 | word_idx);
            end
            for (word_idx = 0; word_idx < 32; word_idx++) begin
                spad_write(cplq_kv_src + (word_idx << 2),
                           32'hac00_0100 + word_idx);
                spad_write(cplq_kv_dst + (word_idx << 2),
                           32'hc07f_7a80 | word_idx);
            end

            write_contract_vdot_desc(desc_base, 16'h07c0,
                                     cplq_scalar_src0, cplq_scalar_src1,
                                     cplq_scalar_dst, 16'd32, 8'd0,
                                     32'd0, 32'd0, 32'd0, 32'd0);
            write_v3_desc(desc_base + 32'h40, 8'h35, 16'h07c1,
                          cplq_sfu_src, 32'd0, cplq_sfu_dst,
                          16'd0, 16'd0, 16'd64);
            write_cluster_desc(desc_base + 32'h80, 8'h43, 16'h07c2,
                               cplq_kv_src, 32'd0, cplq_kv_dst,
                               16'd0, 16'd0, 16'd32, 32'd0,
                               32'd16, 32'd64, 32'd0, 8'd5);
        end

        // Matrix reads and computes the legal operands before its first
        // output write is denied. This leaves enough execution time for the
        // following CNM task to run concurrently and exercise response-owner
        // isolation through a real Matrix writeback Protection fault.
        write_v3_desc(matrix_desc_base, 8'h30, matrix_task_id,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, matrix_dst,
                      16'd16, 16'd32, 16'd16);
        write_cluster_desc(cnm_desc_base, 8'h21, cnm_task_id,
                           MATRIX_LINE_STALL_CNM_A_LOCAL,
                           MATRIX_LINE_STALL_CNM_B_LOCAL, cnm_dst,
                           16'd16, 16'd1, 16'd32, 32'd0,
                           32'd0, 32'd0, 32'd0, 8'd3);

        // Descriptors and completions have their own legal window. Matrix A/B
        // operands and CNM data are readable, while Matrix's output destination
        // is deliberately outside every writable region.
        axil_write(REG_REGION0_PERM, 32'd0);
        axil_write(REG_REGION1_PERM, 32'd0);
        axil_write(REG_REGION2_PERM, 32'd0);
        axil_write(REG_REGION3_PERM, 32'd0);
        axil_write(REG_REGION0_BASE, desc_base);
        axil_write(REG_REGION0_LIMIT,
                   hold_dual_faults_behind_full_cplq ? 32'h0000_7f00 :
                   desc_base + 32'h200);
        axil_write(REG_REGION0_PERM, 32'h0000_000f);
        axil_write(REG_REGION1_BASE, MATRIX_A_LOCAL);
        axil_write(REG_REGION1_LIMIT, MATRIX_A_LOCAL + 32'h400);
        axil_write(REG_REGION1_PERM, 32'h0000_000d);
        axil_write(REG_REGION2_BASE, MATRIX_B_LOCAL);
        axil_write(REG_REGION2_LIMIT, MATRIX_B_LOCAL + 32'h800);
        axil_write(REG_REGION2_PERM, 32'h0000_000d);
        axil_write(REG_REGION3_BASE, MATRIX_LINE_STALL_CNM_A_LOCAL);
        axil_write(REG_REGION3_LIMIT, 32'h0005_6000);
        // The dual-fault mode keeps CNM operand reads legal while denying its
        // output write. Matrix's output remains outside every writable region.
        axil_write(REG_REGION3_PERM,
                   deny_cnm_writeback ? 32'h0000_000d : 32'h0000_000f);

        matrix_rsp_before = compute_vif.matrix_tag_response_count;
        cnm_rsp_before = compute_vif.cnm_tag_response_count;
        matrix_route_error_before = compute_vif.matrix_route_mismatch_count;
        cnm_route_error_before = compute_vif.cnm_route_mismatch_count;
        overlap_before = compute_vif.matrix_cnm_overlap_cycles;
        shared_accept_before = compute_vif.matrix_cnm_shared_accept_cycles;
        cnm_launch_before = compute_vif.engine_launch_count[2];
        matrix_launch_before = compute_vif.engine_launch_count[3];

        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, desc_base);
        axil_write(REG_CMDQ_SIZE,
                   hold_dual_faults_behind_full_cplq ? 32'd8 : 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL,
                   hold_dual_faults_behind_full_cplq ? 32'd5 : 32'd2);
        axil_write(REG_CPLQ_BASE, cpl_base);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        axil_write(REG_DOORBELL, 32'd1);

        for (cycle = 0; cycle < 30000 && !monitor_done; cycle++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.engine_busy[2]) cnm_busy_cycles++;
            if (compute_vif.engine_busy[3]) matrix_busy_cycles++;
            if (compute_vif.engine_busy[2] && compute_vif.engine_busy[3])
                both_busy_cycles++;
            if (compute_vif.parallel_queue_mode) parallel_active_cycles++;
            if (compute_vif.processor_busy)
                busy_seen = 1'b1;
            if (compute_vif.selected_line_valid &&
                compute_vif.selected_line_write &&
                !compute_vif.selected_line_access_ok &&
                (compute_vif.selected_line_addr >= matrix_dst) &&
                (compute_vif.selected_line_addr < matrix_dst + 32'h800)) begin
                protection_seen = 1'b1;
                if (abort_cnm_after_protection && !abort_issued) begin
                    if (!compute_vif.engine_busy[2])
                        `uvm_fatal("CLUSTER_PROTECTION_ABORT_OWNER",
                            "CNM completed before the concurrent Matrix Protection event")
                    axil_write(REG_ABORT, 32'd1);
                    abort_issued = 1'b1;
                end
            end
            if (deny_cnm_writeback &&
                compute_vif.selected_spad_valid &&
                compute_vif.selected_spad_write &&
                !compute_vif.selected_spad_access_ok &&
                (compute_vif.selected_spad_addr >= cnm_dst) &&
                (compute_vif.selected_spad_addr < cnm_dst + 32'h40)) begin
                if (!compute_vif.engine_busy[2] || !compute_vif.engine_busy[3])
                    `uvm_fatal("CLUSTER_DUAL_PROTECTION_OWNER",
                        "CNM destination Protection denial did not occur while both CNM and Matrix were active")
                cnm_protection_seen = 1'b1;
            end
            if (hold_dual_faults_behind_full_cplq) begin
                if (busy_seen && protection_seen && cnm_protection_seen &&
                    (compute_vif.engine_busy == 7'b0))
                    monitor_done = 1'b1;
            end else if (busy_seen && !compute_vif.processor_busy)
                monitor_done = 1'b1;
        end
        if (!busy_seen || !monitor_done)
            `uvm_fatal("CLUSTER_PROTECTION_OWNER",
                "Matrix output Protection/CNM overlap did not finish in the monitor window")
        if (abort_cnm_after_protection && !abort_issued)
            `uvm_fatal("CLUSTER_PROTECTION_ABORT_OWNER",
                "software Abort was not issued after the Matrix Protection event")
        if (deny_cnm_writeback && !cnm_protection_seen)
            `uvm_fatal("CLUSTER_DUAL_PROTECTION_OWNER",
                "CNM output Protection request was not observed at its destination")
        if (hold_dual_faults_behind_full_cplq) begin
            // Both engines can be idle before the earlier legal descriptors
            // finish ordered retirement. Wait for the visible tail, then
            // sample the full-queue hold state without racing those writes.
            wait_cpl_tail(32'd3);
            axil_read(REG_CPLQ_TAIL, queue_pointer);
            axil_read(REG_CPLQ_HEAD, queue_head);
            axil_read(REG_CPLQ_SIZE, queue_size);
            axil_read(REG_CMDQ_HEAD, command_head);
            if (queue_pointer !== 32'd3 ||
                queue_size !== 32'd4 ||
                compute_vif.cplq_full !== 1'b1 ||
                compute_vif.processor_busy !== 1'b1 ||
                compute_vif.engine_busy !== 7'b0)
                `uvm_fatal("CLUSTER_DUAL_PROTECTION_CPLQ",
                    $sformatf("dual errors did not hold behind a full CPLQ: size=%0d head=%0d tail=%0d CMDQ_HEAD=%0d full=%0b busy=%0b engines=%07b",
                              queue_size, queue_head, queue_pointer, command_head,
                              compute_vif.cplq_full,
                              compute_vif.processor_busy, compute_vif.engine_busy))
            if (command_head !==
                (hold_dual_faults_behind_full_cplq ? 32'd5 : 32'd2))
                `uvm_fatal("CLUSTER_DUAL_PROTECTION_CPLQ", $sformatf(
                    "five legal CMDQ descriptors must dispatch before CPLQ stall: CMDQ_HEAD=%0d",
                    command_head))
            expect_completion(cpl_base, 16'h07c0, 32'd2240, 32'd1,
                              "dual Protection preceding Scalar completion");
            expect_completion(cpl_base + 32'h10, 16'h07c1,
                              cplq_sfu_golden[3], 32'd64,
                              "dual Protection preceding SFU completion");
            expect_completion(cpl_base + 32'h20, 16'h07c2,
                              32'hac00_011f, 32'd32,
                              "dual Protection preceding KV completion");

            // Free one slot. Matrix is first in CMDQ order and must wrap the
            // tail to slot zero. CNM remains pending while the ring is full.
            axil_write(REG_CPLQ_HEAD, 32'd1);
            wait_cpl_tail(32'd0);
            if (compute_vif.cplq_full !== 1'b1 ||
                compute_vif.processor_busy !== 1'b1 ||
                compute_vif.engine_busy !== 7'b0)
                `uvm_fatal("CLUSTER_DUAL_PROTECTION_CPLQ", $sformatf(
                    "CNM error did not remain blocked after Matrix retirement: full=%0b busy=%0b engines=%07b",
                    compute_vif.cplq_full, compute_vif.processor_busy,
                    compute_vif.engine_busy))
            expect_spad(cpl_base + 32'h30, {16'd0, matrix_task_id},
                        "dual Protection Matrix wrapped completion ID");
            expect_spad(cpl_base + 32'h34, 32'h0000_0062,
                        "dual Protection Matrix wrapped error");
            expect_completion(cpl_base, 16'h07c0, 32'd2240, 32'd1,
                              "dual Protection consumed Scalar completion remains intact");

            // Consume another seeded slot to permit CNM's ordered error to
            // retire. The ring remains full after this second completion.
            axil_write(REG_CPLQ_HEAD, 32'd2);
            wait_cpl_tail(32'd1);
            wait_spad_idle();
            if (compute_vif.cplq_full !== 1'b1)
                `uvm_fatal("CLUSTER_DUAL_PROTECTION_CPLQ",
                    "the three-entry completion ring should be full after both ordered error retirements")
            expect_spad(cpl_base, {16'd0, cnm_task_id},
                        "dual Protection CNM wrapped completion ID");
            expect_spad(cpl_base + 32'h04, 32'h0000_0062,
                        "dual Protection CNM wrapped error");
            expect_completion(cpl_base + 32'h10, 16'h07c1,
                              cplq_sfu_golden[3], 32'd64,
                              "dual Protection retained SFU completion");
            expect_completion(cpl_base + 32'h20, 16'h07c2,
                              32'hac00_011f, 32'd32,
                              "dual Protection retained KV completion");
            expect_spad(cplq_scalar_dst, 32'd2240,
                        "dual Protection prefix Scalar Golden");
            for (word_idx = 0; word_idx < 64; word_idx++)
                expect_spad(cplq_sfu_dst + (word_idx << 2),
                            cplq_sfu_golden[word_idx % 4],
                            $sformatf("dual Protection prefix SFU Golden[%0d]", word_idx));
            for (word_idx = 0; word_idx < 32; word_idx++)
                expect_spad(cplq_kv_dst + (word_idx << 2),
                            32'hac00_0100 + word_idx,
                            $sformatf("dual Protection prefix KV Golden[%0d]", word_idx));
        end else begin
            wait_cpl_tail(32'd2);
            wait_spad_idle();
        end

        axil_write(REG_REGION0_PERM, 32'd0);
        axil_write(REG_REGION1_PERM, 32'd0);
        axil_write(REG_REGION2_PERM, 32'd0);
        axil_write(REG_REGION3_PERM, 32'd0);

        if (!protection_seen)
            `uvm_fatal("CLUSTER_PROTECTION_OWNER",
                "Matrix did not issue the expected denied output write after legal operand reads and compute")
        `uvm_info("CLUSTER_PROTECTION_OWNER_TRACE", $sformatf(
            "active_cycles CNM=%0d Matrix=%0d both=%0d parallel_mode=%0d; launches CNM=%0d Matrix=%0d; response_delta CNM=%0d Matrix=%0d",
            cnm_busy_cycles, matrix_busy_cycles, both_busy_cycles,
            parallel_active_cycles,
            compute_vif.engine_launch_count[2] - cnm_launch_before,
            compute_vif.engine_launch_count[3] - matrix_launch_before,
            compute_vif.cnm_tag_response_count - cnm_rsp_before,
            compute_vif.matrix_tag_response_count - matrix_rsp_before), UVM_LOW)
        if (compute_vif.matrix_cnm_overlap_cycles <= overlap_before ||
            compute_vif.matrix_cnm_shared_accept_cycles <= shared_accept_before)
            `uvm_fatal("CLUSTER_PROTECTION_OWNER", $sformatf(
                "Matrix Protection and CNM did not overlap/contend: overlap=%0d shared=%0d both_busy=%0d parallel_mode=%0d",
                compute_vif.matrix_cnm_overlap_cycles - overlap_before,
                compute_vif.matrix_cnm_shared_accept_cycles - shared_accept_before,
                both_busy_cycles, parallel_active_cycles))
        if (compute_vif.matrix_tag_response_count <= matrix_rsp_before ||
            compute_vif.cnm_tag_response_count <= cnm_rsp_before)
            `uvm_fatal("CLUSTER_PROTECTION_OWNER", $sformatf(
                "missing owner response activity: Matrix %0d->%0d CNM %0d->%0d",
                matrix_rsp_before, compute_vif.matrix_tag_response_count,
                cnm_rsp_before, compute_vif.cnm_tag_response_count))
        if (compute_vif.matrix_route_mismatch_count != matrix_route_error_before ||
            compute_vif.cnm_route_mismatch_count != cnm_route_error_before)
            `uvm_fatal("CLUSTER_PROTECTION_OWNER",
                "response from the Protection-faulted Matrix task was routed to the wrong engine")

        // Full-CPLQ mode has already checked the exact wrapped completion
        // slots above. The ordinary case keeps the original base slots.
        if (!hold_dual_faults_behind_full_cplq) begin
            expect_spad(cpl_base, {16'd0, matrix_task_id},
                        "concurrent Protection Matrix task ID/order");
            expect_spad(cpl_base + 32'h04, 32'h0000_0062,
                        "concurrent Protection Matrix error owner");
            if (abort_cnm_after_protection) begin
                expect_spad(cpl_base + 32'h10, {16'd0, cnm_task_id},
                            "concurrent Protection CNM Abort task ID/order");
                expect_spad(cpl_base + 32'h14, 32'h0000_0032,
                            "concurrent Protection CNM ERR_ABORT owner");
            end else if (deny_cnm_writeback) begin
                expect_spad(cpl_base + 32'h10, {16'd0, cnm_task_id},
                            "dual Protection CNM task ID/order");
                expect_spad(cpl_base + 32'h14, 32'h0000_0062,
                            "dual Protection CNM error owner");
            end else begin
                expect_completion(cpl_base + 32'h10, cnm_task_id,
                                  expected_cnm[15], 32'd16,
                                  "concurrent Protection CNM success/order");
            end
        end
        for (word_idx = 0; word_idx < 512; word_idx++)
            expect_spad(matrix_dst + (word_idx << 2),
                        32'hfa17_8000 | word_idx,
                        $sformatf("concurrent Protection Matrix no-writeback[%0d]", word_idx));
        for (word_idx = 0; word_idx < 16; word_idx++) begin
            if (abort_cnm_after_protection) begin
                axil_read(CIMFORGE_SPAD_BASE + cnm_dst + (word_idx << 2),
                          actual_output);
                if ((actual_output !== expected_cnm[word_idx]) &&
                    (actual_output !== (32'hfa17_8800 | word_idx)))
                    `uvm_fatal("CLUSTER_PROTECTION_ABORT_OWNER", $sformatf(
                        "CNM output after Protection/Abort is neither Golden nor untouched: index=%0d expected=0x%08h sentinel=0x%08h actual=0x%08h",
                        word_idx, expected_cnm[word_idx],
                        (32'hfa17_8800 | word_idx), actual_output))
            end else if (deny_cnm_writeback)
                expect_spad(cnm_dst + (word_idx << 2),
                            32'hfa17_8800 | word_idx,
                            $sformatf("dual Protection CNM no-writeback[%0d]", word_idx));
            else
                expect_spad(cnm_dst + (word_idx << 2), expected_cnm[word_idx],
                            $sformatf("concurrent Protection CNM Golden[%0d]", word_idx));
        end

        if (deny_cnm_writeback)
            `uvm_info("CLUSTER_DUAL_PROTECTION_OWNER_CROSS_PASS", $sformatf(
                "parallel Matrix/CNM tasks both retire Protection ERR 0x62 in CMDQ order; both_busy_at_CNM_fault=1 Matrix denied writeback=%0b CNM denied output=%0b overlap_cycles=%0d shared_banked_accepts=%0d MatrixRsp=%0d CNMRsp=%0d route_mismatch=0; both output sentinels preserved; seed=%0d",
                protection_seen, cnm_protection_seen,
                compute_vif.matrix_cnm_overlap_cycles - overlap_before,
                compute_vif.matrix_cnm_shared_accept_cycles - shared_accept_before,
                compute_vif.matrix_tag_response_count - matrix_rsp_before,
                compute_vif.cnm_tag_response_count - cnm_rsp_before, seed), UVM_LOW)
        else if (abort_cnm_after_protection)
            `uvm_info("CLUSTER_PROTECTION_ABORT_OWNER_CROSS_PASS", $sformatf(
                "Matrix Protection ERR 0x62 is preserved before CNM software Abort ERR 0x32; overlap_cycles=%0d shared_banked_accepts=%0d matrix_rsp=%0d cnm_rsp=%0d route_mismatch=0; no Matrix writeback; CNM outputs are Golden or untouched; seed=%0d",
                compute_vif.matrix_cnm_overlap_cycles - overlap_before,
                compute_vif.matrix_cnm_shared_accept_cycles - shared_accept_before,
                compute_vif.matrix_tag_response_count - matrix_rsp_before,
                compute_vif.cnm_tag_response_count - cnm_rsp_before, seed), UVM_LOW)
        else
            `uvm_info("CLUSTER_PROTECTION_OWNER_CROSS_PASS", $sformatf(
                "real Matrix output Protection after legal operand reads/compute and concurrent CNM Golden pass; overlap_cycles=%0d shared_banked_accepts=%0d matrix_rsp=%0d cnm_rsp=%0d route_mismatch=0; no Matrix writeback; ordered completion; seed=%0d",
                compute_vif.matrix_cnm_overlap_cycles - overlap_before,
                compute_vif.matrix_cnm_shared_accept_cycles - shared_accept_before,
                compute_vif.matrix_tag_response_count - matrix_rsp_before,
                compute_vif.cnm_tag_response_count - cnm_rsp_before, seed), UVM_LOW)

        if (hold_dual_faults_behind_full_cplq)
            `uvm_info("CLUSTER_DUAL_PROTECTION_CPLQ_BACKPRESSURE_PASS", $sformatf(
                "blocked_tail=3 released_heads=1,2 wrapped_tails=0,1 engines_idle=1 full_after_each=1 Matrix=0x62 CNM=0x62 completion_order=Matrix,CNM route_mismatch=0; both output sentinels preserved; seed=%0d",
                seed), UVM_LOW)

        axil_write(REG_CPLQ_HEAD,
                   hold_dual_faults_behind_full_cplq ? 32'd1 : 32'd2);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
    endtask

    task automatic run_cnm_protection_matrix_owner_cross(
        input int unsigned seed,
        input int signed expected_matrix[0:15][0:31],
        input bit reset_after_fault,
        input bit abort_matrix_after_fault,
        input bit matrix_prefix_reset_mode);
        bit [31:0] desc_base;
        bit [31:0] cpl_base;
        bit [31:0] matrix_dst;
        bit [31:0] cnm_dst;
        bit [31:0] packed_word;
        bit [31:0] matrix_rsp_before;
        bit [31:0] cnm_rsp_before;
        bit [31:0] matrix_route_error_before;
        bit [31:0] cnm_route_error_before;
        bit [31:0] overlap_before;
        bit [31:0] matrix_line_write_addr[0:127];
        bit [127:0] matrix_line_write_data[0:127];
        bit [15:0] matrix_line_write_wstrb[0:127];
        bit matrix_output_written[0:511];
        bit denied_seen;
        bit matrix_busy_at_fault;
        bit both_busy_at_fault;
        bit matrix_read_accepted;
        bit reset_triggered;
        bit abort_issued;
        bit abort_write_done;
        bit cnm_fault_drained;
        bit abort_active_seen;
        bit busy_seen;
        bit monitor_done;
        bit reset_ok;
        int unsigned cycle;
        int unsigned matrix_busy_cycles;
        int unsigned both_busy_cycles;
        int unsigned matrix_accept_count;
        int unsigned matrix_write_accept_count;
        int unsigned post_abort_matrix_writes;
        int unsigned line_word_idx;
        int unsigned word_idx;
        int unsigned cpl_idx;
        int unsigned k_word;
        int unsigned row_idx;
        int unsigned lane;
        int unsigned byte_idx;
        int signed a_value;
        int signed b_value;
        int signed expected_cnm[0:15];
        bit [31:0] actual_addr;
        bit [31:0] cpl_tail;
        bit [31:0] matrix_rsp_after_reset;
        bit [31:0] cnm_rsp_after_reset;
        bit [15:0] matrix_task_id;
        bit [15:0] cnm_task_id;
        int unsigned cnm_launches_before;
        bit cnm_fault_done_seen;
        uvm_hdl_data_t reset_value;

        desc_base = 32'h0000_7800;
        cpl_base = 32'h0000_7900;
        matrix_dst = MATRIX_Y_LOCAL;
        cnm_dst = MATRIX_LINE_STALL_CNM_Y_LOCAL;
        matrix_task_id = reset_after_fault ? 16'h07d6 : 16'h07d4;
        cnm_task_id = reset_after_fault ? 16'h07d7 : 16'h07d5;
        if (matrix_prefix_reset_mode) begin
            if (!reset_after_fault || abort_matrix_after_fault)
                `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_PREFIX",
                    "Matrix output-prefix reset is only valid for the reset mode")
            matrix_task_id = 16'h07da;
            cnm_task_id = 16'h07db;
        end
        if (abort_matrix_after_fault) begin
            matrix_task_id = 16'h07d8;
            cnm_task_id = 16'h07d9;
        end
        denied_seen = 1'b0;
        matrix_busy_at_fault = 1'b0;
        both_busy_at_fault = 1'b0;
        matrix_read_accepted = 1'b0;
        reset_triggered = 1'b0;
        abort_issued = 1'b0;
        abort_write_done = 1'b0;
        cnm_fault_drained = 1'b0;
        abort_active_seen = 1'b0;
        busy_seen = 1'b0;
        monitor_done = 1'b0;
        matrix_busy_cycles = 0;
        both_busy_cycles = 0;
        matrix_accept_count = 0;
        matrix_write_accept_count = 0;
        post_abort_matrix_writes = 0;
        cnm_fault_done_seen = 1'b0;

        // Initialize a legal CNM GEMV image. The CNM source-A window is the
        // only denied range; Matrix A/B and its writeback remain permitted.
        for (k_word = 0; k_word < 32; k_word++) begin
            for (lane = 0; lane < 4; lane++) begin
                packed_word = '0;
                for (byte_idx = 0; byte_idx < 4; byte_idx++) begin
                    a_value = int'(k_word % 5) + int'(lane * 2) +
                              int'(byte_idx) - 5;
                    packed_word[byte_idx*8 +: 8] = a_value[7:0];
                end
                spad_write(MATRIX_LINE_STALL_CNM_A_LOCAL +
                           (k_word << 4) + (lane << 2), packed_word);
            end
        end
        for (row_idx = 0; row_idx < 16; row_idx++) begin
            expected_cnm[row_idx] = 0;
            for (k_word = 0; k_word < 32; k_word++) begin
                for (lane = 0; lane < 4; lane++) begin
                    packed_word = '0;
                    for (byte_idx = 0; byte_idx < 4; byte_idx++) begin
                        a_value = int'(k_word % 5) + int'(lane * 2) +
                                  int'(byte_idx) - 5;
                        b_value = int'(row_idx % 5) + int'(k_word % 3) +
                                  int'(lane) + int'(byte_idx) - 3;
                        packed_word[byte_idx*8 +: 8] = b_value[7:0];
                        expected_cnm[row_idx] += a_value * b_value;
                    end
                    spad_write(MATRIX_LINE_STALL_CNM_B_LOCAL +
                               ((row_idx * 32 + k_word) << 4) +
                               (lane << 2), packed_word);
                end
            end
        end
        for (word_idx = 0; word_idx < 512; word_idx++)
            spad_write(matrix_dst + (word_idx << 2),
                       32'hfa17_9000 | word_idx);
        for (word_idx = 0; word_idx < 16; word_idx++)
            spad_write(cnm_dst + (word_idx << 2),
                       32'hfa17_9800 | word_idx);
        for (cpl_idx = 0; cpl_idx < 8; cpl_idx++)
            spad_write(cpl_base + (cpl_idx << 2),
                       32'hfa17_a000 | cpl_idx);

        write_v3_desc(desc_base, 8'h30, matrix_task_id,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, matrix_dst,
                      16'd16, 16'd32, 16'd16);
        write_cluster_desc(desc_base + 32'h40, 8'h21, cnm_task_id,
                           MATRIX_LINE_STALL_CNM_A_LOCAL,
                           MATRIX_LINE_STALL_CNM_B_LOCAL, cnm_dst,
                           16'd16, 16'd1, 16'd32, 32'd0,
                           32'd0, 32'd0, 32'd0, 8'd3);

        axil_write(REG_REGION0_PERM, 32'd0);
        axil_write(REG_REGION1_PERM, 32'd0);
        axil_write(REG_REGION2_PERM, 32'd0);
        axil_write(REG_REGION3_PERM, 32'd0);
        axil_write(REG_REGION0_BASE, desc_base);
        axil_write(REG_REGION0_LIMIT, cpl_base + 32'h100);
        axil_write(REG_REGION0_PERM, 32'h0000_000f);
        axil_write(REG_REGION1_BASE, MATRIX_A_LOCAL);
        axil_write(REG_REGION1_LIMIT, matrix_dst + 32'h800);
        axil_write(REG_REGION1_PERM, 32'h0000_000f);
        axil_write(REG_REGION3_BASE, MATRIX_LINE_STALL_CNM_A_LOCAL);
        axil_write(REG_REGION3_LIMIT, cnm_dst + 32'h40);
        axil_write(REG_REGION3_PERM, 32'd0);

        matrix_rsp_before = compute_vif.matrix_tag_response_count;
        cnm_rsp_before = compute_vif.cnm_tag_response_count;
        matrix_route_error_before = compute_vif.matrix_route_mismatch_count;
        cnm_route_error_before = compute_vif.cnm_route_mismatch_count;
        overlap_before = compute_vif.matrix_cnm_overlap_cycles;
        cnm_launches_before = compute_vif.engine_launch_count[2];

        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, desc_base);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd2);
        axil_write(REG_CPLQ_BASE, cpl_base);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        axil_write(REG_DOORBELL, 32'd1);

        for (cycle = 0; cycle < 30000 && !monitor_done; cycle++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.engine_busy[3]) matrix_busy_cycles++;
            if (compute_vif.engine_busy[2] && compute_vif.engine_busy[3])
                both_busy_cycles++;
            if (compute_vif.processor_busy)
                busy_seen = 1'b1;
            if (compute_vif.selected_line_valid &&
                compute_vif.selected_line_ready &&
                compute_vif.selected_line_write &&
                compute_vif.selected_line_access_ok &&
                (compute_vif.selected_line_addr >= matrix_dst) &&
                (compute_vif.selected_line_addr < matrix_dst + 32'h800)) begin
                if (matrix_write_accept_count >= 128)
                    `uvm_fatal("CLUSTER_CNM_PROTECTION_ABORT_OWNER",
                        "Matrix accepted more Line writes than its 16x32 descriptor permits")
                matrix_line_write_addr[matrix_write_accept_count] =
                    compute_vif.selected_line_addr;
                matrix_line_write_data[matrix_write_accept_count] =
                    compute_vif.selected_line_wdata;
                matrix_line_write_wstrb[matrix_write_accept_count] =
                    compute_vif.selected_line_wstrb;
                matrix_write_accept_count++;
                if (abort_active_seen)
                    post_abort_matrix_writes++;
            end
            if (compute_vif.dut_abort_active)
                abort_active_seen = 1'b1;
            for (lane = 0; lane < 4; lane++) begin
                actual_addr = compute_vif.selected_cnm_addr[lane];
                if (compute_vif.selected_cnm_valid[lane] &&
                    !compute_vif.selected_cnm_access_ok[lane] &&
                    (actual_addr >= MATRIX_LINE_STALL_CNM_A_LOCAL) &&
                    (actual_addr < MATRIX_LINE_STALL_CNM_A_LOCAL + 32'h200)) begin
                    denied_seen = 1'b1;
                    matrix_busy_at_fault |= compute_vif.engine_busy[3];
                    if (!compute_vif.engine_busy[3])
                        `uvm_fatal("CLUSTER_CNM_PROTECTION_OWNER",
                            "CNM Protection error arrived after the concurrent Matrix task had completed")
                    if (compute_vif.engine_busy[2]) begin
                        both_busy_at_fault = 1'b1;
                        if (matrix_prefix_reset_mode &&
                            (cnm_protection_reset_prefix_coverage_phase == 0)) begin
                            cnm_protection_reset_prefix_coverage_phase = 1;
                            cnm_protection_matrix_prefix_reset_cg.sample();
                        end
                    end
                end
            end
            if (matrix_prefix_reset_mode && denied_seen && compute_vif.engine_error[2])
                cnm_fault_done_seen = 1'b1;
            if (matrix_prefix_reset_mode && denied_seen &&
                (matrix_write_accept_count != 0) && cnm_fault_done_seen &&
                compute_vif.engine_busy[3] &&
                (cnm_protection_reset_prefix_coverage_phase == 1)) begin
                cnm_protection_reset_prefix_coverage_phase = 2;
                cnm_protection_matrix_prefix_reset_cg.sample();
            end
            if (compute_vif.engine_busy[3] &&
                compute_vif.matrix_request_valid && compute_vif.banked_ready) begin
                matrix_read_accepted = 1'b1;
                matrix_accept_count++;
            end
            if (abort_matrix_after_fault && denied_seen && !abort_issued &&
                !compute_vif.engine_busy[2] && compute_vif.engine_busy[3] &&
                (matrix_write_accept_count != 0)) begin
                if (!matrix_read_accepted || (matrix_accept_count == 0))
                    `uvm_fatal("CLUSTER_CNM_PROTECTION_ABORT_OWNER",
                        "CNM Protection retired before Matrix had accepted a real operand read")
                cnm_fault_drained = 1'b1;
                // Wait until the CNM Protection result has left its engine
                // and Matrix has committed a real output write, then exercise
                // global Abort against the remaining in-flight task.
                abort_issued = 1'b1;
                fork
                    begin : send_matrix_global_abort
                        axil_write(REG_ABORT, 32'd1);
                        abort_write_done = 1'b1;
                    end
                join_none
            end
            if (reset_after_fault && denied_seen && matrix_read_accepted &&
                compute_vif.engine_busy[3] &&
                ((!matrix_prefix_reset_mode && compute_vif.engine_busy[2]) ||
                 (matrix_prefix_reset_mode && cnm_fault_done_seen &&
                  !compute_vif.engine_busy[2] && (matrix_write_accept_count != 0)))) begin
                if (matrix_prefix_reset_mode) begin
                    if ((matrix_write_accept_count == 0) || !cnm_fault_done_seen ||
                        compute_vif.engine_busy[2])
                        `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_PREFIX",
                            "reset must follow a retired CNM Protection error and an accepted Matrix Golden Line while Matrix remains active")
                    if (!both_busy_at_fault)
                        `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_PREFIX",
                            "Protection and Matrix were not active together when the denial was consumed")
                    if ((compute_vif.engine_launch_count[2] - cnm_launches_before) != 1)
                        `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_PREFIX", $sformatf(
                            "expected one CNM fault task launch, observed %0d",
                            compute_vif.engine_launch_count[2] - cnm_launches_before))
                    if (cnm_protection_reset_prefix_coverage_phase != 2)
                        `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_PREFIX",
                            "missing consumed-Protection then accepted-Matrix-prefix coverage phase")
                end else begin
                    both_busy_at_fault = 1'b1;
                end
                // In prefix mode, Matrix is still busy and owns the earlier
                // CMDQ entry, so the consumed CNM Protection completion is
                // pending. Reset suppresses it together with Matrix's old
                // epoch. The post-reset tail and CPLQ sentinel checks prove
                // that neither completion retired.
                // Assert reset without another bus transaction so Matrix
                // cannot advance while the accepted prefix is being sampled.
                #1ns;
                reset_value = 1'b0;
                reset_ok = uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", reset_value);
                if (!reset_ok)
                    `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_OWNER",
                        "failed to assert reset during concurrent CNM Protection and Matrix reads")
                repeat (4) @(posedge compute_vif.aclk);
                if (compute_vif.engine_busy !== 7'b0)
                    `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_OWNER", $sformatf(
                        "engines remained active during reset: busy=%07b",
                        compute_vif.engine_busy))
                if (matrix_prefix_reset_mode) begin
                    cnm_protection_reset_prefix_coverage_phase = 3;
                    cnm_protection_matrix_prefix_reset_cg.sample();
                end
                #1ns;
                reset_value = 1'b1;
                reset_ok = uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", reset_value);
                if (!reset_ok)
                    `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_OWNER",
                        "failed to release reset after concurrent Protection fault")
                repeat (8) @(posedge compute_vif.aclk);
                if (matrix_prefix_reset_mode) begin
                    cnm_protection_reset_prefix_coverage_phase = 4;
                    cnm_protection_matrix_prefix_reset_cg.sample();
                end
                wait_spad_idle();
                axil_read(REG_CPLQ_TAIL, cpl_tail);
                if (cpl_tail !== 32'd0)
                    `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_OWNER", $sformatf(
                        "reset left a stale completion tail: %0d", cpl_tail))
                if (matrix_prefix_reset_mode) begin : check_matrix_reset_prefix_image
                    bit [31:0] actual_word;
                    int unsigned line_base_word;
                    int unsigned check_row;
                    int unsigned check_col;
                    for (word_idx = 0; word_idx < 512; word_idx++)
                        matrix_output_written[word_idx] = 1'b0;
                    if (matrix_write_accept_count == 0 ||
                        matrix_write_accept_count >= 128)
                        `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_PREFIX", $sformatf(
                            "reset did not preserve a proper Matrix Line prefix: lines=%0d",
                            matrix_write_accept_count))
                    for (cpl_idx = 0; cpl_idx < matrix_write_accept_count; cpl_idx++) begin
                        if ((matrix_line_write_addr[cpl_idx] !==
                             matrix_dst + ((cpl_idx / 8) * 32'h80) +
                                          ((cpl_idx % 8) * 32'h10)) ||
                            (matrix_line_write_wstrb[cpl_idx] !== 16'hffff))
                            `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_PREFIX", $sformatf(
                                "Matrix prefix Line address/WSTRB mismatch index=%0d addr=0x%08h WSTRB=%04h",
                                cpl_idx, matrix_line_write_addr[cpl_idx],
                                matrix_line_write_wstrb[cpl_idx]))
                        line_base_word = (matrix_line_write_addr[cpl_idx] - matrix_dst) >> 2;
                        check_row = line_base_word / 32;
                        check_col = line_base_word % 32;
                        for (lane = 0; lane < 4; lane++) begin
                            line_word_idx = line_base_word + lane;
                            if ((check_col + lane) >= 32 ||
                                (line_word_idx >= …108796 tokens truncated…       accepted_reads = 0;
        returned_reads = 0;
        post_reset_writes = 0;
        post_reset_responses = 0;
        first_write_seen = 1'b0;
        reset_monitor_active = 1'b0;
        monitor_done = 1'b0;
        sfu_reset_prefix_phase = 0;

        gelu_inputs[0] = 16;
        gelu_inputs[1] = -16;
        gelu_inputs[2] = 32;
        gelu_inputs[3] = -32;
        gelu_golden[0] = 8;
        gelu_golden[1] = -8;
        gelu_golden[2] = 17;
        gelu_golden[3] = -15;
        for (word_idx = 0; word_idx < 64; word_idx++) begin
            spad_write(GELU_A_LOCAL + (word_idx << 2), gelu_inputs[word_idx % 4]);
            spad_write(dst + (word_idx << 2), sentinel ^ word_idx);
        end
        for (word_idx = 0; word_idx < 4; word_idx++)
            spad_write(completion_base + (word_idx << 2), 32'h77a0_0000 | word_idx);

        write_v3_desc(desc_base, 8'h35, task_id, GELU_A_LOCAL, 32'd0, dst,
                      16'd0, 16'd0, 16'd64);
        configure_contract_queues(completion_base, 32'd1);
        axil_write(REG_DOORBELL, 32'd1);

        fork
            begin : sfu_reset_prefix_monitor
                while (!monitor_done) begin
                    @(posedge compute_vif.aclk);
                    if (compute_vif.engine_req_valid[4] &&
                        compute_vif.engine_req_ready[4]) begin
                        if (compute_vif.engine_req_write[4]) begin
                            if (accepted_write_count >= 64)
                                `uvm_fatal("CLUSTER_SFU_RESET_PREFIX",
                                    "SFU accepted more writes than the 64-element descriptor")
                            write_addr[accepted_write_count] =
                                compute_vif.engine_req_addr[4*32 +: 32];
                            write_data[accepted_write_count] =
                                compute_vif.engine_req_wdata[4*32 +: 32];
                            accepted_write_count++;
                            first_write_seen = 1'b1;
                            if (reset_monitor_active)
                                post_reset_writes++;
                        end else begin
                            accepted_reads++;
                        end
                    end
                    if (compute_vif.rsp_valid &&
                        (compute_vif.rsp_client == 3'd2)) begin
                        returned_reads++;
                        if (reset_monitor_active)
                            post_reset_responses++;
                    end
                end
            end
            begin : reset_after_sfu_prefix
                poll = 0;
                while (!first_write_seen && poll < 50000) begin
                    @(posedge compute_vif.aclk);
                    poll++;
                    if (compute_vif.engine_busy[4] &&
                        (sfu_reset_prefix_phase == 0)) begin
                        sfu_reset_prefix_phase = 1;
                        sfu_reset_prefix_cg.sample();
                    end
                end
                if (!first_write_seen)
                    `uvm_fatal("CLUSTER_SFU_RESET_PREFIX",
                        "SFU did not accept an output before the reset timeout")
                if (accepted_write_count == 0 || accepted_write_count >= 64 ||
                    !compute_vif.engine_busy[4])
                    `uvm_fatal("CLUSTER_SFU_RESET_PREFIX", $sformatf(
                        "reset prefix is not a proper in-flight output prefix: writes=%0d busy=%0b",
                        accepted_write_count, compute_vif.engine_busy[4]))
                if (sfu_reset_prefix_phase == 0) begin
                    sfu_reset_prefix_phase = 1;
                    sfu_reset_prefix_cg.sample();
                end
                sfu_reset_prefix_phase = 2;
                sfu_reset_prefix_cg.sample();
                accepted_write_at_reset = accepted_write_count;
                reset_monitor_active = 1'b1;
                #1ns;
                reset_value = 1'b0;
                reset_ok = uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", reset_value);
                if (!reset_ok)
                    `uvm_fatal("CLUSTER_SFU_RESET_PREFIX",
                        "failed to assert accelerator reset after SFU accepted output prefix")
                repeat (4) @(posedge compute_vif.aclk);
                if (compute_vif.engine_busy !== 7'b0)
                    `uvm_fatal("CLUSTER_SFU_RESET_PREFIX", $sformatf(
                        "engine busy did not clear in reset: busy=%07b",
                        compute_vif.engine_busy))
                sfu_reset_prefix_phase = 3;
                sfu_reset_prefix_cg.sample();
                #1ns;
                reset_value = 1'b1;
                reset_ok = uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", reset_value);
                if (!reset_ok)
                    `uvm_fatal("CLUSTER_SFU_RESET_PREFIX",
                        "failed to release accelerator reset after SFU prefix test")
                repeat (8) @(posedge compute_vif.aclk);
                sfu_reset_prefix_phase = 4;
                sfu_reset_prefix_cg.sample();
                monitor_done = 1'b1;
            end
        join

        wait_spad_idle();
        if (post_reset_writes != 0 || post_reset_responses != 0 ||
            accepted_write_count != accepted_write_at_reset)
            `uvm_fatal("CLUSTER_SFU_RESET_PREFIX", $sformatf(
                "old-epoch SFU activity escaped reset/release: writes=%0d responses=%0d prefix=%0d/%0d",
                post_reset_writes, post_reset_responses,
                accepted_write_count, accepted_write_at_reset))
        if (returned_reads > accepted_reads)
            `uvm_fatal("CLUSTER_SFU_RESET_PREFIX", $sformatf(
                "SFU returned-read count exceeds accepts: accepted=%0d returned=%0d",
                accepted_reads, returned_reads))
        if (accepted_write_at_reset == 0 || accepted_write_at_reset >= 64)
            `uvm_fatal("CLUSTER_SFU_RESET_PREFIX", $sformatf(
                "reset did not preserve a proper accepted-write prefix: %0d/64",
                accepted_write_at_reset))

        axil_read(REG_CPLQ_TAIL, cpl_tail);
        if (cpl_tail !== 32'd0)
            `uvm_fatal("CLUSTER_SFU_RESET_PREFIX", $sformatf(
                "old-epoch SFU task advanced CPLQ_TAIL across reset: %0d", cpl_tail))
        for (word_idx = 0; word_idx < 4; word_idx++)
            expect_spad(completion_base + (word_idx << 2),
                        32'h77a0_0000 | word_idx,
                        $sformatf("SFU reset suppressed old completion[%0d]", word_idx));
        for (word_idx = 0; word_idx < accepted_write_at_reset; word_idx++) begin
            if (write_addr[word_idx] !== dst + (word_idx << 2))
                `uvm_fatal("CLUSTER_SFU_RESET_PREFIX", $sformatf(
                    "accepted SFU prefix address mismatch index=%0d expected=0x%08h actual=0x%08h",
                    word_idx, dst + (word_idx << 2), write_addr[word_idx]))
            if (write_data[word_idx] !== gelu_golden[word_idx % 4])
                `uvm_fatal("CLUSTER_SFU_RESET_PREFIX", $sformatf(
                    "accepted SFU prefix Golden mismatch index=%0d expected=0x%08h actual=0x%08h",
                    word_idx, gelu_golden[word_idx % 4], write_data[word_idx]))
            expect_spad(dst + (word_idx << 2), gelu_golden[word_idx % 4],
                        $sformatf("SFU reset accepted Golden prefix[%0d]", word_idx));
        end
        for (word_idx = accepted_write_at_reset; word_idx < 64; word_idx++)
            expect_spad(dst + (word_idx << 2), sentinel ^ word_idx,
                        $sformatf("SFU reset untouched output suffix[%0d]", word_idx));
        sfu_reset_prefix_phase = 5;
        sfu_reset_prefix_cg.sample();

        write_v3_desc(desc_base, 8'h35, recovery_task_id, GELU_A_LOCAL, 32'd0, dst,
                      16'd0, 16'd0, 16'd64);
        configure_contract_queues(completion_base, 32'd1);
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd1);
        wait_spad_idle();
        expect_completion(completion_base, recovery_task_id, gelu_golden[3],
                          32'd64, "SFU reset accepted-prefix recovery");
        for (word_idx = 0; word_idx < 64; word_idx++)
            expect_spad(dst + (word_idx << 2), gelu_golden[word_idx % 4],
                        $sformatf("SFU reset full Golden recovery[%0d]", word_idx));
        sfu_reset_prefix_phase = 6;
        sfu_reset_prefix_cg.sample();
        if (sfu_reset_prefix_cg.get_coverage() < 100.0)
            `uvm_fatal("CLUSTER_SFU_RESET_PREFIX", $sformatf(
                "SFU reset-prefix functional bins incomplete: %0.1f%%",
                sfu_reset_prefix_cg.get_coverage()))
        `uvm_info("CLUSTER_SFU_RESET_WRITE_PREFIX_PASS", $sformatf(
            "task_id=%04h accepted_output_prefix=%0d/64 old_completion_suppressed=1 reset_dropped_reads=%0d full_golden_recovery=64/64 focused_bins=6/6 seed=%0d",
            task_id, accepted_write_at_reset, accepted_reads - returned_reads, seed), UVM_LOW)
        axil_write(REG_CPLQ_HEAD, 32'd1);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
    endtask

    task automatic run_fp_reset_single_write(input int unsigned seed);
        bit [31:0] src0;
        bit [31:0] src1;
        bit [31:0] dst;
        bit [31:0] completion_base;
        bit [31:0] sentinel;
        bit [31:0] reset_value;
        bit [31:0] cpl_tail;
        bit [31:0] accepted_write_addr;
        bit [31:0] accepted_write_data;
        bit [15:0] task_id;
        bit [15:0] recovery_task_id;
        int unsigned accepted_reads;
        int unsigned returned_reads;
        int unsigned post_reset_writes;
        int unsigned post_reset_responses;
        int unsigned poll;
        int unsigned word_idx;
        bit reset_monitor_active;
        bit monitor_done;
        bit accepted_write_seen;
        bit busy_at_write;
        bit reset_ok;

        src0 = 32'h0006_8800;
        src1 = 32'h0006_8900;
        dst = 32'h0006_8a00;
        completion_base = 32'h0000_5f80;
        sentinel = 32'hbad0_7fc0;
        task_id = 16'h077c;
        recovery_task_id = 16'h077d;
        accepted_reads = 0;
        returned_reads = 0;
        post_reset_writes = 0;
        post_reset_responses = 0;
        accepted_write_addr = '0;
        accepted_write_data = '0;
        reset_monitor_active = 1'b0;
        monitor_done = 1'b0;
        accepted_write_seen = 1'b0;
        busy_at_write = 1'b0;
        fp_reset_single_write_phase = 0;

        // 128 BF16 products of 1.0 produce the exact FP32 result 128.0.
        // Unlike a vector engine, this descriptor has only one output word;
        // reset is therefore taken after its sole write handshake and before
        // ordered completion retirement, not described as a partial prefix.
        for (word_idx = 0; word_idx < 64; word_idx++) begin
            spad_write(src0 + (word_idx << 2), 32'h3f80_3f80);
            spad_write(src1 + (word_idx << 2), 32'h3f80_3f80);
        end
        spad_write(dst, sentinel);
        for (word_idx = 0; word_idx < 4; word_idx++)
            spad_write(completion_base + (word_idx << 2),
                       32'h7fc0_0000 | word_idx);

        write_cluster_desc(CLUSTER_CONTRACT_CMDQ, 8'h50, task_id,
                           src0, src1, dst, 16'd1, 16'd1, 16'd128,
                           32'd0, 32'd0, 32'd0, 32'd0, 8'd7);
        configure_contract_queues(completion_base, 32'd1);
        axil_write(REG_DOORBELL, 32'd1);

        fork
            begin : fp_single_write_reset_monitor
                while (!monitor_done) begin
                    @(posedge compute_vif.aclk);
                    if (compute_vif.engine_req_valid[1] &&
                        compute_vif.engine_req_ready[1]) begin
                        if (compute_vif.engine_req_write[1]) begin
                            if (accepted_write_seen)
                                `uvm_fatal("CLUSTER_FP_RESET_SINGLE_WRITE",
                                    "FP Dot issued more than its one descriptor output")
                            accepted_write_seen = 1'b1;
                            accepted_write_addr =
                                compute_vif.engine_req_addr[1*32 +: 32];
                            accepted_write_data =
                                compute_vif.engine_req_wdata[1*32 +: 32];
                            if (reset_monitor_active)
                                post_reset_writes++;
                        end else begin
                            accepted_reads++;
                        end
                    end
                    if (compute_vif.rsp_valid &&
                        (compute_vif.rsp_client == 3'd2)) begin
                        returned_reads++;
                        if (reset_monitor_active)
                            post_reset_responses++;
                    end
                end
            end
            begin : reset_after_fp_result_before_retirement
                for (poll = 0; poll < 50000; poll++) begin
                    @(posedge compute_vif.aclk);
                    if (compute_vif.engine_req_valid[1] &&
                        compute_vif.engine_req_ready[1] &&
                        compute_vif.engine_req_write[1]) begin
                        busy_at_write = compute_vif.engine_busy[1];
                        if (!busy_at_write)
                            `uvm_fatal("CLUSTER_FP_RESET_SINGLE_WRITE",
                                "FP result handshake was not observed while its engine remained active")
                        fp_reset_single_write_phase = 1;
                        fp_reset_single_write_cg.sample();
                        fp_reset_single_write_phase = 2;
                        fp_reset_single_write_cg.sample();
                        reset_monitor_active = 1'b1;
                        #1ns;
                        reset_value = 1'b0;
                        reset_ok = uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", reset_value);
                        if (!reset_ok)
                            `uvm_fatal("CLUSTER_FP_RESET_SINGLE_WRITE",
                                "failed to assert reset after the FP result write handshake")
                        repeat (4) @(posedge compute_vif.aclk);
                        if (compute_vif.engine_busy !== 7'b0)
                            `uvm_fatal("CLUSTER_FP_RESET_SINGLE_WRITE", $sformatf(
                                "engine busy did not clear in reset: busy=%07b",
                                compute_vif.engine_busy))
                        fp_reset_single_write_phase = 3;
                        fp_reset_single_write_cg.sample();
                        #1ns;
                        reset_value = 1'b1;
                        reset_ok = uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", reset_value);
                        if (!reset_ok)
                            `uvm_fatal("CLUSTER_FP_RESET_SINGLE_WRITE",
                                "failed to release reset after the FP result write")
                        repeat (8) @(posedge compute_vif.aclk);
                        fp_reset_single_write_phase = 4;
                        fp_reset_single_write_cg.sample();
                        monitor_done = 1'b1;
                        break;
                    end
                end
                if (!monitor_done)
                    `uvm_fatal("CLUSTER_FP_RESET_SINGLE_WRITE",
                        "FP Dot did not accept its sole output before the reset timeout")
            end
        join

        wait_spad_idle();
        if (!accepted_write_seen || accepted_write_addr !== dst ||
            accepted_write_data !== 32'h4300_0000)
            `uvm_fatal("CLUSTER_FP_RESET_SINGLE_WRITE", $sformatf(
                "sole BF16 result write mismatch: seen=%0b address=0x%08h data=0x%08h",
                accepted_write_seen, accepted_write_addr, accepted_write_data))
        if (accepted_reads == 0 || returned_reads != accepted_reads)
            `uvm_fatal("CLUSTER_FP_RESET_SINGLE_WRITE", $sformatf(
                "FP read responses were not fully consumed before result write: accepted=%0d returned=%0d",
                accepted_reads, returned_reads))
        if (post_reset_writes != 0 || post_reset_responses != 0)
            `uvm_fatal("CLUSTER_FP_RESET_SINGLE_WRITE", $sformatf(
                "old-epoch FP activity escaped reset/release: writes=%0d responses=%0d",
                post_reset_writes, post_reset_responses))

        axil_read(REG_CPLQ_TAIL, cpl_tail);
        if (cpl_tail !== 32'd0)
            `uvm_fatal("CLUSTER_FP_RESET_SINGLE_WRITE", $sformatf(
                "old-epoch FP task advanced CPLQ_TAIL across reset: %0d", cpl_tail))
        expect_spad(dst, 32'h4300_0000,
                    "FP result remains committed across pre-retirement reset");
        for (word_idx = 0; word_idx < 4; word_idx++)
            expect_spad(completion_base + (word_idx << 2),
                        32'h7fc0_0000 | word_idx,
                        $sformatf("FP reset suppressed old completion[%0d]", word_idx));
        fp_reset_single_write_phase = 5;
        fp_reset_single_write_cg.sample();

        write_cluster_desc(CLUSTER_CONTRACT_CMDQ, 8'h50, recovery_task_id,
                           src0, src1, dst, 16'd1, 16'd1, 16'd128,
                           32'd0, 32'd0, 32'd0, 32'd0, 8'd7);
        configure_contract_queues(completion_base, 32'd1);
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd1);
        wait_spad_idle();
        expect_completion(completion_base, recovery_task_id, 32'h4300_0000,
                          32'd128, "FP reset single-result recovery");
        expect_spad(dst, 32'h4300_0000,
                    "FP reset single-result recovery Golden");
        fp_reset_single_write_phase = 6;
        fp_reset_single_write_cg.sample();
        if (fp_reset_single_write_cg.get_coverage() < 99.99)
            `uvm_fatal("CLUSTER_FP_RESET_SINGLE_WRITE", $sformatf(
                "FP reset single-result functional bins incomplete: %0.1f%%",
                fp_reset_single_write_cg.get_coverage()))
        `uvm_info("CLUSTER_FP_RESET_SINGLE_WRITE_PASS", $sformatf(
            "BF16 sole output committed before reset; old completion suppressed; accepted_reads=%0d returned=%0d post_reset_writes=0 post_reset_responses=0; full Golden recovery=1/1 focused_bins=6/6 seed=%0d",
            accepted_reads, returned_reads, seed), UVM_LOW)
        axil_write(REG_CPLQ_HEAD, 32'd1);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
    endtask

    task automatic check_request_stability();
        int unsigned e;
        int unsigned d;
        int unsigned depth_bin;
        int unsigned legal_class_count;
        int unsigned hit_depth_bin_count;
        int unsigned max_engine_wait_cycles;
        string missing_stall_depth_bins;
        max_engine_wait_cycles = 0;
        if (compute_vif.engine_req_stability_violations != 0 ||
            compute_vif.matrix_banked_stall_violations != 0 ||
            compute_vif.matrix_line_stall_violations != 0 ||
            compute_vif.cnm_stall_violations != 0)
            `uvm_fatal("CLUSTER_REQUEST_STABILITY", $sformatf(
                "stall payload changed: engine=%0d MatrixBanked=%0d MatrixLine=%0d CNM=%0d",
                compute_vif.engine_req_stability_violations,
                compute_vif.matrix_banked_stall_violations,
                compute_vif.matrix_line_stall_violations,
                compute_vif.cnm_stall_violations))
        if (compute_vif.engine_req_stall_seen == 0 ||
            compute_vif.matrix_banked_stall_checks == 0)
            `uvm_fatal("CLUSTER_REQUEST_STABILITY", $sformatf(
                "no stalled compute request was checked: engine_mask=%07b banked_checks=%0d",
                compute_vif.engine_req_stall_seen,
                compute_vif.matrix_banked_stall_checks))
        for (e = 0; e < 7; e++)
            if (compute_vif.engine_req_stall_checks[e] != 0 &&
                compute_vif.engine_req_stall_cycles[e] == 0)
                `uvm_fatal("CLUSTER_REQUEST_STABILITY", $sformatf(
                    "engine%0d stability checks lack a stall sample", e))
        for (e = 0; e < 7; e++)
            if (compute_vif.engine_req_stall_seen[e] &&
                compute_vif.engine_req_max_stall_cycles[e] == 0)
                `uvm_fatal("CLUSTER_REQUEST_PROGRESS", $sformatf(
                    "engine%0d has stalled samples but no measured wait run", e))
        if (compute_vif.engine_req_stall_seen !== 7'b1110111)
            `uvm_fatal("CLUSTER_REQUEST_PROGRESS", $sformatf(
                "fixed legal all-engine workload stall mask changed: observed=%07b expected=1110111",
                compute_vif.engine_req_stall_seen))
        for (e = 0; e < 7; e++) begin
            if (compute_vif.engine_req_stall_seen[e] &&
                compute_vif.engine_req_max_stall_cycles[e] >
                    CLUSTER_ENGINE_WAIT_BOUND_CYCLES)
                `uvm_fatal("CLUSTER_REQUEST_PROGRESS", $sformatf(
                    "engine%0d request wait exceeded fixed-workload regression bound: observed=%0d bound=%0d cycles",
                    e, compute_vif.engine_req_max_stall_cycles[e],
                    CLUSTER_ENGINE_WAIT_BOUND_CYCLES))
            if (compute_vif.engine_req_stall_seen[e] &&
                compute_vif.engine_req_max_stall_cycles[e] >
                    max_engine_wait_cycles)
                max_engine_wait_cycles = compute_vif.engine_req_max_stall_cycles[e];
        end
        engine_progress_bound_cg.sample(compute_vif.engine_req_stall_seen,
                                        max_engine_wait_cycles);
        if (engine_progress_bound_cg.get_coverage() < 99.99)
            `uvm_fatal("CLUSTER_REQUEST_PROGRESS", $sformatf(
                "bounded progress coverage incomplete: mask=%07b max_wait=%0d coverage=%0.1f%%",
                compute_vif.engine_req_stall_seen, max_engine_wait_cycles,
                engine_progress_bound_cg.get_coverage()))
        for (e = 0; e < 7; e++)
            if ((e == 2 && compute_vif.engine_req_stall_dir_seen[e] !== 2'b10) ||
                (e != 2 && e != 3 && compute_vif.engine_req_stall_dir_seen[e] !== 2'b11))
                `uvm_fatal("CLUSTER_REQUEST_STABILITY", $sformatf(
                    "engine%0d stalled direction mask is incomplete for its legal requester interface: read_write_mask=%02b",
                    e, compute_vif.engine_req_stall_dir_seen[e]))
        if (compute_vif.matrix_line_stall_dir_seen[1] !== 1'b1)
            `uvm_fatal("CLUSTER_REQUEST_STABILITY",
                "Matrix Line did not observe a stalled write request")
        legal_class_count = 0;
        hit_depth_bin_count = 0;
        missing_stall_depth_bins = "";
        for (e = 0; e < 7; e++) begin
            for (d = 0; d < 2; d++) begin
                if (compute_vif.engine_req_stall_dir_seen[e][d]) begin
                    legal_class_count++;
                    for (depth_bin = 0; depth_bin < 3; depth_bin++) begin
                        if (compute_vif.engine_req_stall_len_bins[e][d][depth_bin])
                            hit_depth_bin_count++;
                    end
                    if (compute_vif.engine_req_stall_len_bins[e][d] !== 3'b111)
                        missing_stall_depth_bins = {missing_stall_depth_bins,
                            $sformatf("engine%0d_%s:%03b,", e,
                                d ? "write" : "read",
                                compute_vif.engine_req_stall_len_bins[e][d])};
                end
            end
        end
        legal_class_count++;
        for (depth_bin = 0; depth_bin < 3; depth_bin++)
            if (compute_vif.matrix_banked_stall_len_bins[depth_bin])
                hit_depth_bin_count++;
        if (compute_vif.matrix_banked_stall_len_bins !== 3'b111)
            missing_stall_depth_bins = {missing_stall_depth_bins,
                $sformatf("matrix_banked_read:%03b,",
                    compute_vif.matrix_banked_stall_len_bins)};
        legal_class_count++;
        for (depth_bin = 0; depth_bin < 3; depth_bin++)
            if (compute_vif.matrix_line_stall_len_bins[depth_bin])
                hit_depth_bin_count++;
        if (compute_vif.matrix_line_stall_len_bins !== 3'b111)
            missing_stall_depth_bins = {missing_stall_depth_bins,
                $sformatf("matrix_line_write:%03b,",
                    compute_vif.matrix_line_stall_len_bins)};
        for (e = 0; e < 4; e++) begin
            legal_class_count++;
            for (depth_bin = 0; depth_bin < 3; depth_bin++)
                if (compute_vif.cnm_stall_len_bins[e][depth_bin])
                    hit_depth_bin_count++;
            if (compute_vif.cnm_stall_len_bins[e] !== 3'b111)
                missing_stall_depth_bins = {missing_stall_depth_bins,
                    $sformatf("cnm_lane%0d_read:%03b,", e,
                        compute_vif.cnm_stall_len_bins[e])};
        end
        `uvm_info("CLUSTER_REQUEST_STALL_DEPTH_AUDIT", $sformatf(
            "classes=%0d/17 bins=%0d/51 stall depths=1,2,8+ consecutive cycles; missing={%s}; legal observed traffic only",
            legal_class_count, hit_depth_bin_count,
            missing_stall_depth_bins.len() ? missing_stall_depth_bins : "none"), UVM_LOW)
        if (legal_class_count == 17 && hit_depth_bin_count == 51)
            `uvm_info("CLUSTER_REQUEST_STALL_DEPTH_COVERAGE_PASS", $sformatf(
                "classes=%0d/17 bins=%0d/51 stall depths=1,2,8+ consecutive cycles; legal observed traffic only",
                legal_class_count, hit_depth_bin_count), UVM_LOW)
        `uvm_info("CLUSTER_REQUEST_STABILITY_PASS", $sformatf(
            "engine stalled mask=%07b cycles={%0d,%0d,%0d,%0d,%0d,%0d,%0d} direction={%02b,%02b,%02b,%02b,%02b,%02b,%02b}; Matrix banked checks=%0d fault-cancel=%0d, Matrix line checks=%0d direction=%02b, CNM lane checks={%0d,%0d,%0d,%0d}",
            compute_vif.engine_req_stall_seen,
            compute_vif.engine_req_stall_cycles[0], compute_vif.engine_req_stall_cycles[1],
            compute_vif.engine_req_stall_cycles[2], compute_vif.engine_req_stall_cycles[3],
            compute_vif.engine_req_stall_cycles[4], compute_vif.engine_req_stall_cycles[5],
            compute_vif.engine_req_stall_cycles[6],
            compute_vif.engine_req_stall_dir_seen[0],
            compute_vif.engine_req_stall_dir_seen[1],
            compute_vif.engine_req_stall_dir_seen[2],
            compute_vif.engine_req_stall_dir_seen[3],
            compute_vif.engine_req_stall_dir_seen[4],
            compute_vif.engine_req_stall_dir_seen[5],
            compute_vif.engine_req_stall_dir_seen[6],
            compute_vif.matrix_banked_stall_checks,
            compute_vif.matrix_banked_fault_cancel_checks,
            compute_vif.matrix_line_stall_checks,
            compute_vif.matrix_line_stall_dir_seen,
            compute_vif.cnm_stall_checks[0], compute_vif.cnm_stall_checks[1],
            compute_vif.cnm_stall_checks[2], compute_vif.cnm_stall_checks[3]), UVM_LOW)
        `uvm_info("CLUSTER_ENGINE_WAIT_OBSERVED_PASS", $sformatf(
            "max consecutive engine-port wait cycles={%0d,%0d,%0d,%0d,%0d,%0d,%0d}; stalled mask=%07b; metric is observed traffic only, with no injected downstream SRAM stall",
            compute_vif.engine_req_max_stall_cycles[0],
            compute_vif.engine_req_max_stall_cycles[1],
            compute_vif.engine_req_max_stall_cycles[2],
            compute_vif.engine_req_max_stall_cycles[3],
            compute_vif.engine_req_max_stall_cycles[4],
            compute_vif.engine_req_max_stall_cycles[5],
            compute_vif.engine_req_max_stall_cycles[6],
            compute_vif.engine_req_stall_seen), UVM_LOW)
        `uvm_info("CLUSTER_REQUEST_PROGRESS_BOUND_PASS", $sformatf(
            "fixed legal all-engine workload progressed within bound=%0d cycles; stalled mask=%07b max wait={%0d,%0d,%0d,%0d,%0d,%0d,%0d}; progress coverage=%0.1f%%; not a general external-memory fairness claim",
            CLUSTER_ENGINE_WAIT_BOUND_CYCLES,
            compute_vif.engine_req_stall_seen,
            compute_vif.engine_req_max_stall_cycles[0],
            compute_vif.engine_req_max_stall_cycles[1],
            compute_vif.engine_req_max_stall_cycles[2],
            compute_vif.engine_req_max_stall_cycles[3],
            compute_vif.engine_req_max_stall_cycles[4],
            compute_vif.engine_req_max_stall_cycles[5],
            compute_vif.engine_req_max_stall_cycles[6],
            engine_progress_bound_cg.get_coverage()), UVM_LOW)
    endtask

    // Insert a legal scheduler admission pause in the testbench: suppress the
    // arbiter's accepted-valid and all SRAM-side valids together. This keeps
    // the source valids visible, returns ready low, and prevents any commit.
    task automatic force_scheduler_admission_stall();
        bit [1023:0] force_zero;
        force_zero = '0;
        if (!uvm_hdl_force("tb_ai_accel_uvm.dut.spad_arbiter_u.accept_valid", force_zero) ||
            !uvm_hdl_force("tb_ai_accel_uvm.dut.spad_arbiter_u.accept_response", force_zero) ||
            !uvm_hdl_force("tb_ai_accel_uvm.dut.spad_arbiter_u.spad_valid", force_zero) ||
            !uvm_hdl_force("tb_ai_accel_uvm.dut.spad_arbiter_u.spad_line_valid", force_zero) ||
            !uvm_hdl_force("tb_ai_accel_uvm.dut.spad_arbiter_u.spad_banked_valid", force_zero) ||
            !uvm_hdl_force("tb_ai_accel_uvm.dut.spad_arbiter_u.spad_cnm_valid", force_zero))
            `uvm_fatal("CLUSTER_STALL_INJECT",
                "failed to pause scheduler admission and mask SRAM-side request valids")
    endtask

    task automatic release_scheduler_admission_stall();
        bit [1023:0] force_ones;
        force_ones = '1;
        void'(uvm_hdl_release("tb_ai_accel_uvm.dut.spad_arbiter_u.spad_cnm_valid"));
        void'(uvm_hdl_release("tb_ai_accel_uvm.dut.spad_arbiter_u.spad_banked_valid"));
        void'(uvm_hdl_release("tb_ai_accel_uvm.dut.spad_arbiter_u.spad_line_valid"));
        void'(uvm_hdl_release("tb_ai_accel_uvm.dut.spad_arbiter_u.spad_valid"));
        void'(uvm_hdl_release("tb_ai_accel_uvm.dut.spad_arbiter_u.accept_response"));
        void'(uvm_hdl_release("tb_ai_accel_uvm.dut.spad_arbiter_u.accept_valid"));
        // VCS holds a released procedural variable's forced value until the
        // combinational process executes again.  Toggle an inactive DMA address
        // input (DMA valid is zero in these directed compute-only cases) to
        // retrigger the arbiter selection before the next active clock edge.
        if (compute_vif.dma_valid)
            `uvm_fatal("CLUSTER_STALL_INJECT",
                "cannot retrigger arbiter selection while a DMA request is active")
        if (!uvm_hdl_force("tb_ai_accel_uvm.dut.spad_arbiter_u.dma_addr", force_ones))
            `uvm_fatal("CLUSTER_STALL_INJECT",
                "failed to retrigger arbiter combinational selection after stall")
        void'(uvm_hdl_release("tb_ai_accel_uvm.dut.spad_arbiter_u.dma_addr"));
    endtask

    task automatic stall_matrix_banked_read_once(input int unsigned stall_cycles);
        int unsigned poll;
        int unsigned stall_idx;
        bit request_seen;
        bit accepted_after_release;
        bit [31:0] held_addr;

        request_seen = 1'b0;
        for (poll = 0; poll < 10000; poll++) begin
            @(negedge compute_vif.aclk);
            if (compute_vif.matrix_request_valid) begin
                request_seen = 1'b1;
                held_addr = compute_vif.matrix_banked_req_addr;
                break;
            end
        end
        if (!request_seen)
            `uvm_fatal("CLUSTER_STALL_INJECT",
                "Matrix produced no banked read request for directed stall")
        force_scheduler_admission_stall();
        for (stall_idx = 0; stall_idx < stall_cycles; stall_idx++) begin
            @(posedge compute_vif.aclk);
            #1;
            if (!compute_vif.matrix_request_valid ||
                compute_vif.banked_ready !== 1'b0 ||
                compute_vif.matrix_banked_req_addr !== held_addr)
                `uvm_fatal("CLUSTER_STALL_INJECT", $sformatf(
                    "Matrix banked read did not remain unaccepted/stable at injected stall cycle %0d",
                    stall_idx))
        end
        @(negedge compute_vif.aclk);
        release_scheduler_admission_stall();

        accepted_after_release = 1'b0;
        for (poll = 0; poll < 10000 && !accepted_after_release; poll++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.matrix_request_valid && compute_vif.banked_ready &&
                compute_vif.matrix_banked_req_addr === held_addr)
                accepted_after_release = 1'b1;
        end
        if (!accepted_after_release)
            `uvm_fatal("CLUSTER_STALL_INJECT",
                "Matrix banked read made no progress after injected backpressure release")
        `uvm_info("CLUSTER_REQUEST_STALL_INJECT_PASS", $sformatf(
            "Matrix banked read held unaccepted for %0d cycles, then accepted once ready resumed",
            stall_cycles), UVM_LOW)
    endtask

    task automatic stall_core_engine_write_once(
        input int unsigned engine_idx,
        input int unsigned stall_cycles
    );
        int unsigned poll;
        int unsigned stall_idx;
        bit request_seen;
        bit accepted_after_release;

        if (engine_idx >= 7 || stall_cycles < 8)
            `uvm_fatal("CLUSTER_STALL_INJECT", $sformatf(
                "invalid core write stall target engine=%0d cycles=%0d",
                engine_idx, stall_cycles))
        request_seen = 1'b0;
        for (poll = 0; poll < 10000; poll++) begin
            @(negedge compute_vif.aclk);
            if (compute_vif.engine_req_valid[engine_idx] &&
                compute_vif.engine_req_write[engine_idx]) begin
                request_seen = 1'b1;
                break;
            end
        end
        if (!request_seen)
            `uvm_fatal("CLUSTER_STALL_INJECT", $sformatf(
                "engine%0d produced no write request for directed stall", engine_idx))
        force_scheduler_admission_stall();
        for (stall_idx = 0; stall_idx < stall_cycles; stall_idx++) begin
            @(posedge compute_vif.aclk);
            #1;
            if (!compute_vif.engine_req_valid[engine_idx] ||
                !compute_vif.engine_req_write[engine_idx] ||
                compute_vif.engine_req_ready[engine_idx] !== 1'b0)
                `uvm_fatal("CLUSTER_STALL_INJECT", $sformatf(
                    "engine%0d write did not remain unaccepted/stable at injected stall cycle %0d",
                    engine_idx, stall_idx))
        end
        @(negedge compute_vif.aclk);
        release_scheduler_admission_stall();

        accepted_after_release = 1'b0;
        for (poll = 0; poll < 10000 && !accepted_after_release; poll++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.engine_req_valid[engine_idx] &&
                compute_vif.engine_req_write[engine_idx] &&
                compute_vif.engine_req_ready[engine_idx])
                accepted_after_release = 1'b1;
        end
        if (!accepted_after_release)
            `uvm_fatal("CLUSTER_STALL_INJECT", $sformatf(
                "engine%0d write made no progress after releasing injected backpressure",
                engine_idx))
        `uvm_info("CLUSTER_REQUEST_STALL_INJECT_PASS", $sformatf(
            "engine%0d write held unaccepted for %0d cycles, then accepted once ready resumed",
            engine_idx, stall_cycles), UVM_LOW)
    endtask

    task automatic stall_matrix_line_write_once(input int unsigned stall_cycles);
        int unsigned poll;
        int unsigned stall_idx;
        bit request_seen;
        bit accepted_after_release;

        request_seen = 1'b0;
        for (poll = 0; poll < 10000; poll++) begin
            @(negedge compute_vif.aclk);
            if (compute_vif.matrix_line_valid && compute_vif.matrix_line_write) begin
                request_seen = 1'b1;
                break;
            end
        end
        if (!request_seen)
            `uvm_fatal("CLUSTER_STALL_INJECT",
                "Matrix produced no Line write request for directed stall")
        force_scheduler_admission_stall();
        for (stall_idx = 0; stall_idx < stall_cycles; stall_idx++) begin
            @(posedge compute_vif.aclk);
            #1;
            if (!compute_vif.matrix_line_valid ||
                !compute_vif.matrix_line_write ||
                compute_vif.matrix_line_ready !== 1'b0)
                `uvm_fatal("CLUSTER_STALL_INJECT", $sformatf(
                    "Matrix Line write did not remain unaccepted/stable at injected stall cycle %0d",
                    stall_idx))
        end
        @(negedge compute_vif.aclk);
        release_scheduler_admission_stall();

        accepted_after_release = 1'b0;
        for (poll = 0; poll < 10000 && !accepted_after_release; poll++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.matrix_line_valid && compute_vif.matrix_line_write &&
                compute_vif.matrix_line_ready)
                accepted_after_release = 1'b1;
        end
        if (!accepted_after_release)
            `uvm_fatal("CLUSTER_STALL_INJECT",
                "Matrix Line write made no progress after injected backpressure release")
        `uvm_info("CLUSTER_REQUEST_STALL_INJECT_PASS", $sformatf(
            "Matrix Line write held unaccepted for %0d cycles, then accepted once ready resumed",
            stall_cycles), UVM_LOW)
    endtask

    task automatic stall_cnm_four_lane_read_once(input int unsigned stall_cycles);
        int unsigned poll;
        int unsigned stall_idx;
        bit request_seen;
        bit accepted_after_release;

        request_seen = 1'b0;
        for (poll = 0; poll < 10000; poll++) begin
            @(negedge compute_vif.aclk);
            if (compute_vif.cnm_request_valid === 4'hf) begin
                request_seen = 1'b1;
                break;
            end
        end
        if (!request_seen)
            `uvm_fatal("CLUSTER_STALL_INJECT",
                "CNM did not present all four legal lane reads together for directed stall")
        force_scheduler_admission_stall();
        for (stall_idx = 0; stall_idx < stall_cycles; stall_idx++) begin
            @(posedge compute_vif.aclk);
            #1;
            if (compute_vif.cnm_request_valid !== 4'hf ||
                compute_vif.cnm_request_ready !== 4'h0)
                `uvm_fatal("CLUSTER_STALL_INJECT", $sformatf(
                    "four-lane CNM reads did not remain unaccepted/stable at injected stall cycle %0d valid=%h ready=%h",
                    stall_idx,
                    compute_vif.cnm_request_valid, compute_vif.cnm_request_ready))
        end
        @(negedge compute_vif.aclk);
        release_scheduler_admission_stall();

        accepted_after_release = 1'b0;
        for (poll = 0; poll < 10000 && !accepted_after_release; poll++) begin
            @(posedge compute_vif.aclk);
            if (|(compute_vif.cnm_request_valid & compute_vif.cnm_request_ready))
                accepted_after_release = 1'b1;
        end
        if (!accepted_after_release)
            `uvm_fatal("CLUSTER_STALL_INJECT",
                "CNM lane read made no progress after injected backpressure release")
        `uvm_info("CLUSTER_REQUEST_STALL_INJECT_PASS", $sformatf(
            "four CNM lane reads held unaccepted for %0d cycles, then resumed",
            stall_cycles), UVM_LOW)
    endtask

    task automatic wait_matrix_sfu_overlap();
        int unsigned poll;
        for (poll = 0; poll < 3000; poll++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.engine_busy[3] && compute_vif.engine_busy[4]) return;
        end
        `uvm_fatal("CLUSTER_ABORT", "Matrix and SFU did not become active together before abort")
    endtask

    task automatic wait_matrix_read_accept();
        int unsigned poll;
        for (poll = 0; poll < 3000; poll++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.banked_valid && compute_vif.banked_ready) return;
        end
        `uvm_fatal("CLUSTER_RESET", "Matrix did not receive a banked-SPAD grant before reset")
    endtask

    task automatic wait_matrix_prefetch_active();
        int unsigned poll;
        for (poll = 0; poll < 3000; poll++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.matrix_prefetch_active) return;
        end
        `uvm_fatal("CLUSTER_PREFETCH", "Matrix did not enter next-K prefetch before abort/reset")
    endtask

    task automatic check_cnm_address_stream();
        int unsigned lane_count[0:3];
        int unsigned lane;
        int unsigned poll;
        int unsigned matrix_reads;
        bit complete;
        bit [31:0] expected_addr;
        bit [31:0] cpl_tail;
        for (lane = 0; lane < 4; lane++) lane_count[lane] = 0;
        poll = 0;
        matrix_reads = 0;
        complete = 1'b0;
        while (!complete && poll < 10000) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.aresetn) begin
                if (compute_vif.banked_valid && compute_vif.banked_ready) begin
                    if (compute_vif.matrix_banked_req_addr[1:0] != 2'b00 ||
                        !((compute_vif.matrix_banked_req_addr >= MATRIX_A_LOCAL &&
                           compute_vif.matrix_banked_req_addr < MATRIX_A_LOCAL + 32'h400) ||
                          (compute_vif.matrix_banked_req_addr >= MATRIX_B_LOCAL &&
                           compute_vif.matrix_banked_req_addr < MATRIX_B_LOCAL + 32'h800)))
                        `uvm_fatal("CLUSTER_MATRIX_ADDR", $sformatf("Matrix banked read outside aligned A/B tile regions: 0x%08h", compute_vif.matrix_banked_req_addr))
                    matrix_reads++;
                end
                for (lane = 0; lane < 4; lane++) begin
                    if (compute_vif.cnm_accept_mask[lane]) begin
                        if (lane_count[lane][0])
                            expected_addr = CNM_B_LOCAL + ((lane_count[lane] >> 1) << 4) + (lane << 2);
                        else
                            expected_addr = CNM_A_LOCAL + (lane << 2);
                        if (compute_vif.cnm_req_addr[lane] !== expected_addr)
                            `uvm_fatal("CLUSTER_CNM_ADDR", $sformatf("lane%0d read[%0d] expected=0x%08h actual=0x%08h", lane, lane_count[lane], expected_addr, compute_vif.cnm_req_addr[lane]))
                        lane_count[lane]++;
                    end
                end
            end
            complete = 1'b1;
            for (lane = 0; lane < 4; lane++)
                if (lane_count[lane] != 32) complete = 1'b0;
            if (!complete && (compute_vif.engine_done[2] ||
                              compute_vif.engine_error[2]))
                break;
            poll++;
        end
        for (lane = 0; lane < 4; lane++) begin
            if (lane_count[lane] != 32) begin
                axil_read(REG_CPLQ_TAIL, cpl_tail);
                `uvm_fatal("CLUSTER_CNM_ADDR_TIMEOUT", $sformatf(
                    "lane0..3 accepted %0d/%0d/%0d/%0d of 32 A/B requests; engine_busy=%07b done=%07b error=%07b cpl_tail=%0d responses=%0d lanes=%b matrix_rsp=%0d cnm_fsm=%0d lane_fsm=%h req=%b ready=%b rsp=%b",
                    lane_count[0], lane_count[1], lane_count[2], lane_count[3],
                    compute_vif.engine_busy, compute_vif.engine_done,
                    compute_vif.engine_error, cpl_tail,
                    compute_vif.cnm_tag_response_count,
                    compute_vif.cnm_response_lane_seen,
                    compute_vif.matrix_tag_response_count,
                    compute_vif.cnm_core_state, compute_vif.cnm_lane_state,
                    compute_vif.cnm_request_valid, compute_vif.cnm_request_ready,
                    compute_vif.cnm_rsp_valid))
            end
        end
        if (matrix_reads == 0)
            `uvm_fatal("CLUSTER_MATRIX_ADDR", "no accepted Matrix banked reads observed during Matrix/CNM overlap window")
        `uvm_info("CLUSTER_CNM_ADDR_PASS", $sformatf("all four CNM lanes accepted expected A/B addresses; Matrix accepted %0d reads within its A/B tile regions", matrix_reads), UVM_LOW)
    endtask

    task automatic run_matrix_multitile_cmdq_test();
        int signed matrix_a[0:31][0:63];
        int signed matrix_b[0:63][0:31];
        int signed matrix_golden[0:31][0:31];
        int signed accumulator;
        bit [31:0] packed_word;
        int unsigned tile_row;
        int unsigned tile_col;
        int unsigned k_word;
        int unsigned row_lane;
        int unsigned col_lane;
        int unsigned k_lane;
        int unsigned row_idx;
        int unsigned col_idx;
        int unsigned k_idx;
        int unsigned word_idx;
        int unsigned elapsed_cycles;
        real focused_coverage;

        // M=N=32 spans two 16x16 Array tiles on both axes; K=64 is the
        // already-used legal Matrix depth. Operands and output occupy
        // disjoint unused regions of the 512 KiB SPAD.
        for (row_idx = 0; row_idx < 32; row_idx++)
            for (k_idx = 0; k_idx < 64; k_idx++)
                matrix_a[row_idx][k_idx] = next_small_signed();
        for (k_idx = 0; k_idx < 64; k_idx++)
            for (col_idx = 0; col_idx < 32; col_idx++)
                matrix_b[k_idx][col_idx] = next_small_signed();

        for (tile_row = 0; tile_row < 8; tile_row++) begin
            for (k_word = 0; k_word < 16; k_word++) begin
                for (row_lane = 0; row_lane < 4; row_lane++) begin
                    packed_word = '0;
                    for (k_lane = 0; k_lane < 4; k_lane++) begin
                        row_idx = tile_row * 4 + row_lane;
                        k_idx = k_word * 4 + k_lane;
                        packed_word[k_lane*8 +: 8] = matrix_a[row_idx][k_idx];
                    end
                    spad_write(MATRIX_MULTI_A_LOCAL +
                               ((tile_row * 16 + k_word) << 4) +
                               (row_lane << 2), packed_word);
                end
            end
        end
        for (tile_col = 0; tile_col < 8; tile_col++) begin
            for (k_word = 0; k_word < 16; k_word++) begin
                for (col_lane = 0; col_lane < 4; col_lane++) begin
                    packed_word = '0;
                    for (k_lane = 0; k_lane < 4; k_lane++) begin
                        col_idx = tile_col * 4 + col_lane;
                        k_idx = k_word * 4 + k_lane;
                        packed_word[k_lane*8 +: 8] = matrix_b[k_idx][col_idx];
                    end
                    spad_write(MATRIX_MULTI_B_LOCAL +
                               ((tile_col * 16 + k_word) << 4) +
                               (col_lane << 2), packed_word);
                end
            end
        end

        for (row_idx = 0; row_idx < 32; row_idx++) begin
            for (col_idx = 0; col_idx < 32; col_idx++) begin
                accumulator = 0;
                for (k_idx = 0; k_idx < 64; k_idx++)
                    accumulator += matrix_a[row_idx][k_idx] *
                                   matrix_b[k_idx][col_idx];
                matrix_golden[row_idx][col_idx] = accumulator;
            end
        end

        spad_write(MATRIX_MULTI_Y_LOCAL - 32'd4, 32'hb0a0_0001);
        spad_write(MATRIX_MULTI_Y_LOCAL + 32'd4096, 32'hb0a0_0002);
        write_v3_desc(CMDQ_LOCAL, 8'h30, 16'h05f1,
                      MATRIX_MULTI_A_LOCAL, MATRIX_MULTI_B_LOCAL,
                      MATRIX_MULTI_Y_LOCAL, 16'd32, 16'd32, 16'd16);
        run_serial_descriptor(CMDQ_LOCAL, CPLQ_LOCAL, 16'h05f1,
                              matrix_golden[31][31], 32'd1024,
                              "Matrix 32x32x64 multi-tile", elapsed_cycles);
        for (word_idx = 0; word_idx < 1024; word_idx++)
            expect_spad(MATRIX_MULTI_Y_LOCAL + (word_idx << 2),
                        matrix_golden[word_idx / 32][word_idx % 32],
                        $sformatf("Matrix 32x32x64 multi-tile Golden[%0d]",
                                  word_idx));
        expect_spad(MATRIX_MULTI_Y_LOCAL - 32'd4, 32'hb0a0_0001,
                    "Matrix multi-tile lower output guard");
        expect_spad(MATRIX_MULTI_Y_LOCAL + 32'd4096, 32'hb0a0_0002,
                    "Matrix multi-tile upper output guard");

        matrix_multitile_shape_case = 1;
        matrix_multitile_shape_cg.sample();
        focused_coverage = matrix_multitile_shape_cg.get_inst_coverage();
        if (focused_coverage < 100.0)
            `uvm_fatal("CLUSTER_MATRIX_MULTITILE_COVERAGE",
                $sformatf("legal Matrix multi-tile CMDQ bin incomplete: coverage=%0.1f%%",
                          focused_coverage))
        `uvm_info("CLUSTER_MATRIX_MULTITILE_CMDQ_PASS", $sformatf(
            "real CMDQ Matrix M=32 N=32 K=64 across 2x2 Array tiles; Golden outputs=1024/1024, completion=1/1, lower/upper guards=2/2, elapsed_cycles=%0d, focused_bins=1/1 coverage=%0.1f%%",
            elapsed_cycles, focused_coverage), UVM_LOW)
    endtask

    task body();
        bit [31:0] value;
        bit [31:0] packed_word;
        int unsigned seed;
        int unsigned tile_row;
        int unsigned tile_col;
        int unsigned k_word;
        int unsigned row_lane;
        int unsigned col_lane;
        int unsigned k_lane;
        int unsigned row_idx;
        int unsigned col_idx;
        int unsigned k_idx;
        int signed matrix_a[0:15][0:63];
        int signed matrix_b[0:63][0:31];
        int signed matrix_golden[0:15][0:31];
        int signed line_stall_cnm_golden[0:15];
        int signed gelu_values[0:3];
        int signed gelu_results[0:3];
        int signed accumulator;
        int unsigned word_idx;
        int unsigned engine_idx;
        int unsigned cplq_poll;
        int unsigned pair_i;
        int unsigned pair_j;
        int unsigned pair_index;
        int unsigned engine_pair_overlap_bins_hit;
        int unsigned pair_poll;
        int unsigned max_active_engines;
    int unsigned c1_alias_max_read_owners;
        int unsigned c1_k;
        int unsigned c1_row;
        int unsigned c1_col;
        bit cplq_all_engines_idle;
        bit c1_run_started;
        bit c1_run_complete;
        bit [6:0] c1_alias_accept_seen;
        bit [6:0] c1_alias_response_seen;
        bit [6:0] c1_alias_pending;
        bit [20:0] engine_pair_overlap_seen;
        int unsigned protection_case_count;
        int unsigned fault_order[0:17];
        int unsigned fault_i;
        int unsigned fault_j;
        int unsigned fault_swap;
        int unsigned fault_case_id;
        int unsigned cnm_lane;
        int unsigned cnm_byte;
        int signed cnm_a_value;
        int signed cnm_b_value;
        int unsigned matrix_line_stall_checks_before;
        int unsigned matrix_line_stall_violations_before;
        bit [17:0] fault_cases_seen;
        int unsigned overlap_total;
        int unsigned matrix_prefetch_overlap_total;
        int unsigned matrix_cnm_overlap_total;
        int unsigned cnm_grants_total;
        int unsigned matrix_responses_total;
        int unsigned cnm_responses_total;
        bit [3:0] cnm_lanes_seen_total;
        int unsigned contention_total;
        int unsigned banked_grants_total;
        int unsigned core_grants_total;
        int unsigned serial_matrix_cycles;
        int unsigned serial_cnm_cycles;
        int unsigned serial_sfu0_cycles;
        int unsigned serial_sfu1_cycles;
        int unsigned serial_total_cycles;
        int unsigned serial_matrix_cnm_sfu_cycles;
        int unsigned serial_spad_read_start;
        int unsigned serial_spad_write_start;
        int unsigned serial_matrix_spad_read_start;
        int unsigned serial_matrix_spad_write_start;
        int unsigned serial_matrix_spad_read_bytes;
        int unsigned serial_matrix_spad_write_bytes;
        int unsigned serial_spad_read_bytes;
        int unsigned serial_spad_write_bytes;
        int unsigned staged_pair_start_cycle;
        int unsigned staged_pair_cycles;
        int unsigned staged_sfu_start_cycle;
        int unsigned staged_sfu_cycles;
        int unsigned staged_total_cycles;
        int unsigned staged_spad_read_start;
        int unsigned staged_spad_write_start;
        int unsigned staged_spad_read_bytes;
        int unsigned staged_spad_write_bytes;
        int unsigned staged_contention_start;
        int unsigned staged_contention_cycles;
        int unsigned parallel_start_cycle;
        int unsigned parallel_cycles;
        int unsigned parallel_contention_start;
        int unsigned parallel_contention_cycles;
        int unsigned parallel_spad_read_start;
        int unsigned parallel_spad_write_start;
        int unsigned parallel_spad_read_bytes;
        int unsigned parallel_spad_write_bytes;
        int unsigned recovery_start_cycle;
        int unsigned recovery_cycles;
        real measured_speedup;
        bit reset_value;
        bit reset_ok;

        if (compute_vif == null)
            `uvm_fatal("CLUSTER_NOVIF", "real compute cluster sequence requires compute_vif")

        mutation_kind = "";
        void'($value$plusargs("CL_MUTATION=%s", mutation_kind));
        seed = 20261025;
        void'($value$plusargs("COMPUTE_CLUSTER_SEED=%d", seed));
        rng_state = seed ^ 32'h7ac4_01d3;
        if (rng_state == 0) rng_state = 32'h1;
        // Run the long GEMV setup before any CMDQ doorbell in this sequence;
        // the shared top SVA has a bounded task watchdog and must not inherit
        // a pending observation from an earlier command while operands load.
        run_scalar_reset_write_prefix(seed);
        serial_total_cycles = 0;
        serial_matrix_cnm_sfu_cycles = 0;
        serial_spad_read_bytes = 0;
        serial_spad_write_bytes = 0;
        serial_matrix_spad_read_bytes = 0;
        serial_matrix_spad_write_bytes = 0;
        staged_pair_cycles = 0;
        staged_sfu_cycles = 0;
        staged_total_cycles = 0;
        staged_spad_read_bytes = 0;
        staged_spad_write_bytes = 0;
        staged_contention_cycles = 0;
        parallel_cycles = 0;
        parallel_contention_cycles = 0;
        parallel_spad_read_bytes = 0;
        parallel_spad_write_bytes = 0;
        recovery_cycles = 0;
        measured_speedup = 0.0;
        for (row_idx = 0; row_idx < 16; row_idx++)
            for (k_idx = 0; k_idx < 64; k_idx++)
                matrix_a[row_idx][k_idx] = next_small_signed();
        for (k_idx = 0; k_idx < 64; k_idx++)
            for (col_idx = 0; col_idx < 32; col_idx++)
                matrix_b[k_idx][col_idx] = next_small_signed();

        // The matrix controller consumes 4x4 tile-major operands: each K
        // group is one 128-bit bank row, with four packed lanes per bank.
        for (tile_row = 0; tile_row < 4; tile_row++) begin
            for (k_word = 0; k_word < 16; k_word++) begin
                for (row_lane = 0; row_lane < 4; row_lane++) begin
                    packed_word = '0;
                    for (k_lane = 0; k_lane < 4; k_lane++) begin
                        row_idx = tile_row * 4 + row_lane;
                        k_idx = k_word * 4 + k_lane;
                        packed_word[k_lane*8 +: 8] = matrix_a[row_idx][k_idx];
                    end
                    spad_write(MATRIX_A_LOCAL + ((tile_row * 16 + k_word) << 4) + (row_lane << 2), packed_word);
                end
            end
        end
        for (tile_col = 0; tile_col < 8; tile_col++) begin
            for (k_word = 0; k_word < 16; k_word++) begin
                for (col_lane = 0; col_lane < 4; col_lane++) begin
                    packed_word = '0;
                    for (k_lane = 0; k_lane < 4; k_lane++) begin
                        col_idx = tile_col * 4 + col_lane;
                        k_idx = k_word * 4 + k_lane;
                        packed_word[k_lane*8 +: 8] = matrix_b[k_idx][col_idx];
                    end
                    spad_write(MATRIX_B_LOCAL + ((tile_col * 16 + k_word) << 4) + (col_lane << 2), packed_word);
                end
            end
        end
        for (row_idx = 0; row_idx < 16; row_idx++) begin
            for (col_idx = 0; col_idx < 32; col_idx++) begin
                accumulator = 0;
                for (k_idx = 0; k_idx < 64; k_idx++)
                    accumulator += matrix_a[row_idx][k_idx] * matrix_b[k_idx][col_idx];
                matrix_golden[row_idx][col_idx] = accumulator;
            end
        end

        gelu_values[0] = 16;
        gelu_values[1] = -16;
        gelu_values[2] = 32;
        gelu_values[3] = -32;
        gelu_results[0] = 8;
        gelu_results[1] = -8;
        gelu_results[2] = 17;
        gelu_results[3] = -15;
        for (word_idx = 0; word_idx < 64; word_idx++) begin
            spad_write(GELU_A_LOCAL + (word_idx << 2), gelu_values[word_idx % 4]);
            spad_write(GELU_B_LOCAL + (word_idx << 2), gelu_values[word_idx % 4]);
        end
        for (word_idx = 0; word_idx < 4; word_idx++) begin
            case (word_idx)
                0: packed_word = 32'h0202_0202;
                1: packed_word = 32'h0303_0303;
                2: packed_word = 32'h0404_0404;
                default: packed_word = 32'h0505_0505;
            endcase
            spad_write(CNM_A_LOCAL + (word_idx << 2), packed_word);
        end
        for (row_idx = 0; row_idx < 16; row_idx++) begin
            for (col_idx = 0; col_idx < 4; col_idx++) begin
                case (col_idx)
                    0: packed_word = 32'h0707_0707;
                    1: packed_word = 32'h0b0b_0b0b;
                    2: packed_word = 32'h0d0d_0d0d;
                    default: packed_word = 32'h1111_1111;
                endcase
                spad_write(CNM_B_LOCAL + (row_idx << 4) + (col_idx << 2), packed_word);
            end
        end

        // Keep a strict standalone A-tile reuse baseline before adding CNM
        // contention. The parallel workload below separately checks data
        // integrity while the shared banked port is under contention.
        write_v3_desc(CMDQ_LOCAL, 8'h30, 16'h05ff,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, MATRIX_Y_LOCAL,
                      16'd16, 16'd32, 16'd16);
        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, CMDQ_LOCAL);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd1);
        axil_write(REG_CPLQ_BASE, CPLQ_LOCAL);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        serial_matrix_spad_read_start = compute_vif.benchmark_spad_read_bytes;
        serial_matrix_spad_write_start = compute_vif.benchmark_spad_write_bytes;
        parallel_start_cycle = compute_vif.sim_cycles;
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd1);
        serial_matrix_cycles = compute_vif.sim_cycles - parallel_start_cycle;
        wait_spad_idle();
        serial_matrix_spad_read_bytes = compute_vif.benchmark_spad_read_bytes -
                                        serial_matrix_spad_read_start;
        serial_matrix_spad_write_bytes = compute_vif.benchmark_spad_write_bytes -
                                         serial_matrix_spad_write_start;
        expect_completion(CPLQ_LOCAL, 16'h05ff, matrix_golden[15][31],
                          32'd512, "serial Matrix baseline");
        if (compute_vif.matrix_a_cache_hits != 16)
            `uvm_fatal("CLUSTER_A_CACHE_BASELINE", $sformatf(
                "standalone 16x32x64 GEMM expected 16 A-tile cache hits, observed %0d",
                compute_vif.matrix_a_cache_hits))
        for (word_idx = 0; word_idx < 512; word_idx++)
            expect_spad(MATRIX_Y_LOCAL + (word_idx << 2),
                        matrix_golden[word_idx / 32][word_idx % 32],
                        $sformatf("standalone Matrix Golden[%0d]", word_idx));
        `uvm_info("CLUSTER_A_CACHE_BASELINE_PASS",
                  "standalone 16x32x64 Matrix Golden and all 16 A-tile reuse hits passed",
                  UVM_LOW)
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_HEAD, 32'd1);
        run_matrix_multitile_cmdq_test();

        // Same four operations as the parallel run, deliberately submitted
        // and retired one at a time. Capture only doorbell-to-completion-tail
        // cycles; descriptor programming is excluded from both measurements.
        serial_spad_read_start = compute_vif.benchmark_spad_read_bytes;
        serial_spad_write_start = compute_vif.benchmark_spad_write_bytes;
        write_cnm_v3_desc(CMDQ_LOCAL, 16'h0601,
                          CNM_A_LOCAL, CNM_B_LOCAL, CNM_Y_LOCAL);
        run_serial_descriptor(CMDQ_LOCAL, CPLQ_LOCAL, 16'h0601,
                              32'd736, 32'd16, "serial CNM", serial_cnm_cycles);
        write_v3_desc(CMDQ_LOCAL, 8'h35, 16'h0602,
                      GELU_A_LOCAL, 32'd0, GELU_Y0_LOCAL,
                      16'd0, 16'd0, 16'd64);
        run_serial_descriptor(CMDQ_LOCAL, CPLQ_LOCAL, 16'h0602,
                              -32'sd15, 32'd64, "serial SFU0", serial_sfu0_cycles);
        write_v3_desc(CMDQ_LOCAL, 8'h35, 16'h0603,
                      GELU_B_LOCAL, 32'd0, GELU_Y1_LOCAL,
                      16'd0, 16'd0, 16'd64);
        run_serial_descriptor(CMDQ_LOCAL, CPLQ_LOCAL, 16'h0603,
                              -32'sd15, 32'd64, "serial SFU1", serial_sfu1_cycles);
        serial_total_cycles = serial_matrix_cycles + serial_cnm_cycles +
                              serial_sfu0_cycles + serial_sfu1_cycles;
        serial_spad_read_bytes = serial_matrix_spad_read_bytes +
                                 compute_vif.benchmark_spad_read_bytes -
                                 serial_spad_read_start;
        serial_spad_write_bytes = serial_matrix_spad_write_bytes +
                                  compute_vif.benchmark_spad_write_bytes -
                                  serial_spad_write_start;
        serial_matrix_cnm_sfu_cycles = serial_matrix_cycles + serial_cnm_cycles +
                                        serial_sfu0_cycles;
        `uvm_info("CLUSTER_SERIAL_BENCH_PASS", $sformatf(
            "serial Matrix/CNM/SFU cycles=%0d/%0d/%0d total=%0d; extra queued SFU=%0d four-task total=%0d spad_read_bytes=%0d spad_write_bytes=%0d",
            serial_matrix_cycles, serial_cnm_cycles, serial_sfu0_cycles,
            serial_matrix_cnm_sfu_cycles, serial_sfu1_cycles,
            serial_total_cycles, serial_spad_read_bytes,
            serial_spad_write_bytes), UVM_LOW)

        // Benchmark the requested staged mode: Matrix and CNM share the
        // scratchpad concurrently, then SFU starts after both retire. Sum the
        // two doorbell-to-tail intervals so descriptor-programming time stays
        // outside both the serial and staged measurements.
        write_v3_desc(CMDQ_LOCAL + 32'h00, 8'h30, 16'h0700,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, MATRIX_Y_LOCAL,
                      16'd16, 16'd32, 16'd16);
        write_cnm_v3_desc(CMDQ_LOCAL + 32'h40, 16'h0701,
                          CNM_A_LOCAL, CNM_B_LOCAL, CNM_Y_LOCAL);
        write_v3_desc(CMDQ_LOCAL + 32'h80, 8'h35, 16'h0702,
                      GELU_A_LOCAL, 32'd0, GELU_Y0_LOCAL,
                      16'd0, 16'd0, 16'd64);
        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, CMDQ_LOCAL);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd2);
        axil_write(REG_CPLQ_BASE, CPLQ_LOCAL);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        staged_contention_start = compute_vif.matrix_cnm_shared_accept_cycles;
        staged_spad_read_start = compute_vif.benchmark_spad_read_bytes;
        staged_spad_write_start = compute_vif.benchmark_spad_write_bytes;
        staged_pair_start_cycle = compute_vif.sim_cycles;
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd2);
        staged_pair_cycles = compute_vif.sim_cycles - staged_pair_start_cycle;
        staged_contention_cycles = compute_vif.matrix_cnm_shared_accept_cycles -
                                   staged_contention_start;
        if (staged_contention_cycles == 0)
            `uvm_fatal("CLUSTER_STAGED_CONTENTION",
                "Matrix and CNM never contended for a shared banked-SPAD admission during the staged pair")
        wait_spad_idle();
        expect_completion(CPLQ_LOCAL + 32'h00, 16'h0700,
                          matrix_golden[15][31], 32'd512,
                          "staged Matrix completion");
        expect_completion(CPLQ_LOCAL + 32'h10, 16'h0701, 32'd736, 32'd16,
                          "staged CNM completion");
        for (word_idx = 0; word_idx < 512; word_idx++)
            expect_spad(MATRIX_Y_LOCAL + (word_idx << 2),
                        matrix_golden[word_idx / 32][word_idx % 32],
                        $sformatf("staged Matrix Golden[%0d]", word_idx));
        for (word_idx = 0; word_idx < 16; word_idx++)
            expect_spad(CNM_Y_LOCAL + (word_idx << 2), 32'd736,
                        $sformatf("staged CNM Golden[%0d]", word_idx));
        axil_write(REG_CPLQ_HEAD, 32'd2);
        axil_write(REG_CMDQ_TAIL, 32'd3);
        staged_sfu_start_cycle = compute_vif.sim_cycles;
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd3);
        staged_sfu_cycles = compute_vif.sim_cycles - staged_sfu_start_cycle;
        staged_total_cycles = staged_pair_cycles + staged_sfu_cycles;
        staged_spad_read_bytes = compute_vif.benchmark_spad_read_bytes -
                                 staged_spad_read_start;
        staged_spad_write_bytes = compute_vif.benchmark_spad_write_bytes -
                                  staged_spad_write_start;
        wait_spad_idle();
        expect_completion(CPLQ_LOCAL + 32'h20, 16'h0702, -32'sd15, 32'd64,
                          "staged SFU completion");
        for (word_idx = 0; word_idx < 64; word_idx++)
            expect_spad(GELU_Y0_LOCAL + (word_idx << 2),
                        gelu_results[word_idx % 4],
                        $sformatf("staged SFU Golden[%0d]", word_idx));
        measured_speedup = real'(serial_matrix_cnm_sfu_cycles) /
                           real'(staged_total_cycles);
        `uvm_info("CLUSTER_STAGED_BENCH_PASS", $sformatf(
            "serial Matrix/CNM/SFU=%0d cycles; staged Matrix+CNM=%0d then SFU=%0d total=%0d speedup=%.3f pair_contention_cycles=%0d spad_read_bytes=%0d spad_write_bytes=%0d completion_order=0700,0701,0702",
            serial_matrix_cnm_sfu_cycles, staged_pair_cycles,
            staged_sfu_cycles, staged_total_cycles, measured_speedup,
            staged_contention_cycles, staged_spad_read_bytes,
            staged_spad_write_bytes), UVM_LOW)
        axil_write(REG_CPLQ_HEAD, 32'd3);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);

        // Keep a real CNM banked requester active while the long Matrix GEMM
        // reaches its line-writeback phase.  The two operations use disjoint
        // SPAD regions, so this creates legal arbitration pressure without a
        // read/write dependency or conflicting output ownership.
        for (k_word = 0; k_word < 32; k_word++) begin
            for (cnm_lane = 0; cnm_lane < 4; cnm_lane++) begin
                packed_word = '0;
                for (cnm_byte = 0; cnm_byte < 4; cnm_byte++) begin
                    cnm_a_value = int'(k_word % 5) + int'(cnm_lane * 2) +
                                  int'(cnm_byte) - 5;
                    packed_word[cnm_byte*8 +: 8] = cnm_a_value[7:0];
                end
                spad_write(MATRIX_LINE_STALL_CNM_A_LOCAL +
                           (k_word << 4) + (cnm_lane << 2), packed_word);
            end
        end
        for (row_idx = 0; row_idx < 16; row_idx++) begin
            line_stall_cnm_golden[row_idx] = 0;
            for (k_word = 0; k_word < 32; k_word++) begin
                for (cnm_lane = 0; cnm_lane < 4; cnm_lane++) begin
                    packed_word = '0;
                    for (cnm_byte = 0; cnm_byte < 4; cnm_byte++) begin
                        cnm_a_value = int'(k_word % 5) + int'(cnm_lane * 2) +
                                      int'(cnm_byte) - 5;
                        cnm_b_value = int'(row_idx % 5) + int'(k_word % 3) +
                                      int'(cnm_lane) + int'(cnm_byte) - 3;
                        packed_word[cnm_byte*8 +: 8] = cnm_b_value[7:0];
                        line_stall_cnm_golden[row_idx] +=
                            cnm_a_value * cnm_b_value;
                    end
                    spad_write(MATRIX_LINE_STALL_CNM_B_LOCAL +
                               ((row_idx * 32 + k_word) << 4) +
                               (cnm_lane << 2), packed_word);
                end
            end
        end

        write_v3_desc(CMDQ_LOCAL + 32'h180, 8'h30, 16'h0710,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, MATRIX_Y_LOCAL,
                      16'd16, 16'd32, 16'd16);
        write_cluster_desc(CMDQ_LOCAL + 32'h1c0, 8'h21, 16'h0711,
                           MATRIX_LINE_STALL_CNM_A_LOCAL,
                           MATRIX_LINE_STALL_CNM_B_LOCAL,
                           MATRIX_LINE_STALL_CNM_Y_LOCAL,
                           16'd16, 16'd1, 16'd32, 32'd0,
                           32'd0, 32'd0, 32'd0, 8'd3);
        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, CMDQ_LOCAL + 32'h180);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd2);
        axil_write(REG_CPLQ_BASE, CPLQ_LOCAL + 32'h180);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        matrix_line_stall_checks_before = compute_vif.matrix_line_stall_checks;
        matrix_line_stall_violations_before =
            compute_vif.matrix_line_stall_violations;
        parallel_start_cycle = compute_vif.sim_cycles;
        axil_write(REG_DOORBELL, 32'd1);
        fork
            begin
                stall_matrix_line_write_once(8);
                stall_cnm_four_lane_read_once(8);
            end
            begin
                wait_cpl_tail(32'd2);
            end
        join
        parallel_cycles = compute_vif.sim_cycles - parallel_start_cycle;
        wait_spad_idle();
        if ((compute_vif.matrix_line_stall_checks -
             matrix_line_stall_checks_before) == 0)
            `uvm_fatal("CLUSTER_MATRIX_LINE_STALL",
                "legal Matrix/CNM overlap did not exercise Matrix line-write backpressure")
        if ((compute_vif.matrix_line_stall_violations -
             matrix_line_stall_violations_before) != 0)
            `uvm_fatal("CLUSTER_MATRIX_LINE_STALL",
                "Matrix line payload changed while the shared SPAD arbiter denied acceptance")
        for (word_idx = 0; word_idx < 512; word_idx++)
            expect_spad(MATRIX_Y_LOCAL + (word_idx << 2),
                        matrix_golden[word_idx / 32][word_idx % 32],
                        $sformatf("line-stalled Matrix Golden[%0d]", word_idx));
        for (row_idx = 0; row_idx < 16; row_idx++)
            expect_spad(MATRIX_LINE_STALL_CNM_Y_LOCAL + (row_idx << 2),
                        line_stall_cnm_golden[row_idx],
                        $sformatf("line-stalled CNM Golden[%0d]", row_idx));
        expect_completion(CPLQ_LOCAL + 32'h180, 16'h0710,
                          matrix_golden[15][31], 32'd512,
                          "line-stalled Matrix");
        expect_completion(CPLQ_LOCAL + 32'h190, 16'h0711,
                          line_stall_cnm_golden[15], 32'd16,
                          "line-stalled CNM");
        `uvm_info("CLUSTER_MATRIX_LINE_STALL_PASS", $sformatf(
            "legal 16x32x64 Matrix + 16x32 CNM overlap; Matrix line stability checks=%0d violations=%0d; overlap_cycles=%0d; outputs and ordered completions match independent Golden",
            compute_vif.matrix_line_stall_checks -
                matrix_line_stall_checks_before,
            compute_vif.matrix_line_stall_violations -
                matrix_line_stall_violations_before,
            parallel_cycles), UVM_LOW)
        axil_write(REG_CPLQ_HEAD, 32'd2);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);

        write_v3_desc(CMDQ_LOCAL + 32'h00, 8'h30, 16'h0600,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, MATRIX_Y_LOCAL,
                      16'd16, 16'd32, 16'd16);
        write_cnm_v3_desc(CMDQ_LOCAL + 32'h40, 16'h0601,
                          CNM_A_LOCAL, CNM_B_LOCAL, CNM_Y_LOCAL);
        write_v3_desc(CMDQ_LOCAL + 32'h80, 8'h35, 16'h0602,
                      GELU_A_LOCAL, 32'd0, GELU_Y0_LOCAL,
                      16'd0, 16'd0, 16'd64);
        write_v3_desc(CMDQ_LOCAL + 32'hc0, 8'h35, 16'h0603,
                      GELU_B_LOCAL, 32'd0, GELU_Y1_LOCAL,
                      16'd0, 16'd0, 16'd64);

        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, CMDQ_LOCAL);
        // The command ring also reserves one slot to distinguish full from
        // empty, so four outstanding descriptors need an eight-entry ring.
        axil_write(REG_CMDQ_SIZE, 32'd8);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd4);
        axil_write(REG_CPLQ_BASE, CPLQ_LOCAL);
        // This ring keeps one entry empty to distinguish full from empty.
        // Four ordered completions therefore need an eight-entry ring.
        axil_write(REG_CPLQ_SIZE, 32'd8);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        parallel_contention_start = compute_vif.shared_spad_contention_cycles;
        parallel_spad_read_start = compute_vif.benchmark_spad_read_bytes;
        parallel_spad_write_start = compute_vif.benchmark_spad_write_bytes;
        parallel_start_cycle = compute_vif.sim_cycles;
        axil_write(REG_DOORBELL, 32'd1);
        check_cnm_address_stream();
        wait_cpl_tail(32'd4);
        parallel_cycles = compute_vif.sim_cycles - parallel_start_cycle;
        parallel_contention_cycles = compute_vif.shared_spad_contention_cycles -
                                     parallel_contention_start;
        parallel_spad_read_bytes = compute_vif.benchmark_spad_read_bytes -
                                   parallel_spad_read_start;
        parallel_spad_write_bytes = compute_vif.benchmark_spad_write_bytes -
                                    parallel_spad_write_start;
        wait_spad_idle();
        if (parallel_cycles != 0)
            measured_speedup = real'(serial_total_cycles) / real'(parallel_cycles);
        `uvm_info("CLUSTER_PARALLEL_BENCH_PASS", $sformatf(
            "same Matrix/CNM/SFU/SFU work parallel cycles=%0d serial_cycles=%0d speedup=%.3f completion_order=0600,0601,0602,0603 shared_spad_contention_cycles=%0d spad_read_bytes=%0d spad_write_bytes=%0d",
            parallel_cycles, serial_total_cycles, measured_speedup,
            parallel_contention_cycles, parallel_spad_read_bytes,
            parallel_spad_write_bytes), UVM_LOW)

        if (compute_vif.overlap_cycles == 0)
            `uvm_fatal("CLUSTER_OVERLAP", "real Matrix and SFU never overlapped")
        if (compute_vif.shared_spad_contention_cycles == 0)
            `uvm_fatal("CLUSTER_SPAD_CONTENTION", "real core and banked requests never contended at ai_spad_arbiter")
        if (compute_vif.arb_banked_grants == 0 || compute_vif.arb_core_grants == 0)
            `uvm_fatal("CLUSTER_SPAD_TRAFFIC", "expected both banked and core SPAD grants")
        if (compute_vif.same_engine_launch_while_busy != 0)
            `uvm_fatal("CLUSTER_OWNER", $sformatf("same-engine launch while busy count=%0d", compute_vif.same_engine_launch_while_busy))
        if (compute_vif.matrix_a_cache_hits == 0)
            `uvm_fatal("CLUSTER_A_CACHE", "Matrix/CNM contention run recorded no A-tile cache hits")
        `uvm_info("CLUSTER_A_CACHE_CONTENTION", $sformatf(
                  "Matrix/CNM workload retained %0d A-tile cache hits under shared-port contention; standalone baseline was 16",
                  compute_vif.matrix_a_cache_hits), UVM_LOW)
        if (compute_vif.matrix_prefetch_overlap_cycles == 0)
            `uvm_fatal("CLUSTER_PREFETCH", "next-K prefetch did not overlap Matrix MAC")
        if (compute_vif.matrix_cnm_overlap_cycles == 0)
            `uvm_fatal("CLUSTER_CNM_OVERLAP", "Matrix and CNM were not simultaneously active")
        if (compute_vif.matrix_cnm_shared_accept_cycles == 0)
            `uvm_fatal("CLUSTER_CNM_ARBITRATION", "Matrix and CNM did not contend at shared banked admission")
        if (compute_vif.matrix_tag_response_count == 0 || compute_vif.cnm_tag_response_count == 0)
            `uvm_fatal("CLUSTER_CNM_RESPONSE", $sformatf("missing owner responses: Matrix=%0d CNM=%0d", compute_vif.matrix_tag_response_count, compute_vif.cnm_tag_response_count))
        if (compute_vif.matrix_route_mismatch_count != 0 || compute_vif.cnm_route_mismatch_count != 0)
            `uvm_fatal("CLUSTER_CNM_ROUTE", $sformatf("response route mismatches: Matrix=%0d CNM=%0d", compute_vif.matrix_route_mismatch_count, compute_vif.cnm_route_mismatch_count))
        if (compute_vif.cnm_response_lane_seen !== 4'hf)
            `uvm_fatal("CLUSTER_CNM_BANKS", $sformatf("expected responses from all CNM banks, observed lane mask=%b", compute_vif.cnm_response_lane_seen))
        if (compute_vif.matrix_cnm_collision_cycles == 0 ||
            compute_vif.matrix_cnm_collision_grant_cycles == 0 ||
            compute_vif.matrix_cnm_collision_matrix_wait_cycles == 0 ||
            compute_vif.matrix_cnm_collision_hold_checks == 0 ||
            compute_vif.matrix_cnm_collision_owner_violations != 0 ||
            compute_vif.matrix_cnm_collision_stability_violations != 0)
            `uvm_fatal("CLUSTER_MATRIX_CNM_BANKED_COLLISION",
                $sformatf("real Matrix/CNM banked arbitration evidence incomplete: collisions=%0d grants=%0d MatrixWait=%0d stableChecks=%0d ownerViolations=%0d holdViolations=%0d",
                    compute_vif.matrix_cnm_collision_cycles,
                    compute_vif.matrix_cnm_collision_grant_cycles,
                    compute_vif.matrix_cnm_collision_matrix_wait_cycles,
                    compute_vif.matrix_cnm_collision_hold_checks,
                    compute_vif.matrix_cnm_collision_owner_violations,
                    compute_vif.matrix_cnm_collision_stability_violations))
        `uvm_info("CLUSTER_MATRIX_CNM_BANKED_COLLISION_PASS", $sformatf(
            "real Matrix banked and CNM lane collision cycles=%0d admitted collisions=%0d Matrix wait cycles=%0d held-payload checks=%0d owner violations=%0d hold violations=%0d MatrixRsp=%0d CNMRsp=%0d route_mismatch=0",
            compute_vif.matrix_cnm_collision_cycles,
            compute_vif.matrix_cnm_collision_grant_cycles,
            compute_vif.matrix_cnm_collision_matrix_wait_cycles,
            compute_vif.matrix_cnm_collision_hold_checks,
            compute_vif.matrix_cnm_collision_owner_violations,
            compute_vif.matrix_cnm_collision_stability_violations,
            compute_vif.matrix_tag_response_count,
            compute_vif.cnm_tag_response_count), UVM_LOW)
        `uvm_info("CLUSTER_CNM_OWNER_PASS", $sformatf("Matrix tag3 responses=%0d, CNM tag5 responses=%0d, CNM lane mask=%b, overlap cycles=%0d, shared banked grants=%0d", compute_vif.matrix_tag_response_count, compute_vif.cnm_tag_response_count, compute_vif.cnm_response_lane_seen, compute_vif.matrix_cnm_overlap_cycles, compute_vif.matrix_cnm_shared_accept_cycles), UVM_LOW)
        matrix_prefetch_overlap_total = compute_vif.matrix_prefetch_overlap_cycles;
        matrix_cnm_overlap_total = compute_vif.matrix_cnm_overlap_cycles;
        cnm_grants_total = compute_vif.arb_cnm_grants;
        matrix_responses_total = compute_vif.matrix_tag_response_count;
        cnm_responses_total = compute_vif.cnm_tag_response_count;
        cnm_lanes_seen_total = compute_vif.cnm_response_lane_seen;
        overlap_total = compute_vif.overlap_cycles;
        contention_total = compute_vif.shared_spad_contention_cycles;
        banked_grants_total = compute_vif.arb_banked_grants;
        core_grants_total = compute_vif.arb_core_grants;

        for (word_idx = 0; word_idx < 512; word_idx++)
            expect_spad(MATRIX_Y_LOCAL + (word_idx << 2), matrix_golden[word_idx / 32][word_idx % 32], $sformatf("16x32x64 GEMM[%0d]", word_idx));
        for (word_idx = 0; word_idx < 16; word_idx++)
            expect_spad(CNM_Y_LOCAL + (word_idx << 2), 32'd736,
                        $sformatf("CNM GEMV row[%0d]", word_idx));
        for (word_idx = 0; word_idx < 64; word_idx++) begin
            expect_spad(GELU_Y0_LOCAL + (word_idx << 2), gelu_results[word_idx % 4],
                        $sformatf("GELU0 output[%0d]", word_idx));
            expect_spad(GELU_Y1_LOCAL + (word_idx << 2), gelu_results[word_idx % 4],
                        $sformatf("GELU1 output[%0d]", word_idx));
        end

        expect_completion(CPLQ_LOCAL + 32'h00, 16'h0600, matrix_golden[15][31], 32'd512, "Matrix");
        expect_completion(CPLQ_LOCAL + 32'h10, 16'h0601, 32'd736, 32'd16, "CNM GEMV");
        expect_completion(CPLQ_LOCAL + 32'h20, 16'h0602, -32'sd15, 32'd64, "SFU first");
        expect_completion(CPLQ_LOCAL + 32'h30, 16'h0603, -32'sd15, 32'd64, "SFU queued");
        axil_read(REG_CMDQ_HEAD, value);
        if (value !== 32'd4)
            `uvm_fatal("CLUSTER_CMDQ", $sformatf("CMDQ_HEAD expected=4 actual=%0d", value))
        axil_write(REG_CPLQ_HEAD, 32'd4);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);

        // Fill the real four-entry completion ring to its three-entry
        // capacity while four production engines execute legal, disjoint
        // tasks. The final completion must remain pending until software
        // advances CPLQ_HEAD; after release it must wrap the tail in order.
        for (word_idx = 0; word_idx < 4; word_idx++)
            spad_write(CPLQ_LOCAL + 32'h330 + (word_idx << 2),
                       32'hc07f_7200 | word_idx);
        spad_write(SCALAR_A_LOCAL, 32'h0403_0201);
        spad_write(SCALAR_B_LOCAL, 32'h0807_0605);
        write_v3_desc(CMDQ_LOCAL + 32'h300, 8'h30, 16'h0810,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, MATRIX_Y_LOCAL,
                      16'd16, 16'd32, 16'd16);
        write_cnm_v3_desc(CMDQ_LOCAL + 32'h340, 16'h0811,
                          CNM_A_LOCAL, CNM_B_LOCAL, CNM_Y_LOCAL);
        write_v3_desc(CMDQ_LOCAL + 32'h380, 8'h35, 16'h0812,
                      GELU_A_LOCAL, 32'd0, SWEEP_SFU_Y_LOCAL,
                      16'd0, 16'd0, 16'd4);
        write_cluster_desc(CMDQ_LOCAL + 32'h3c0, 8'h10, 16'h0813,
                           SCALAR_A_LOCAL, SCALAR_B_LOCAL, SCALAR_Y_LOCAL,
                           16'd0, 16'd0, 16'd1, 32'd0,
                           32'd0, 32'd0, 32'd0, 8'd3);

        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, CMDQ_LOCAL + 32'h300);
        axil_write(REG_CMDQ_SIZE, 32'd8);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd4);
        axil_write(REG_CPLQ_BASE, CPLQ_LOCAL + 32'h300);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd3);

        cplq_all_engines_idle = 1'b0;
        for (cplq_poll = 0; cplq_poll < 2000; cplq_poll++) begin
            if (compute_vif.engine_busy == 7'd0) begin
                cplq_all_engines_idle = 1'b1;
                break;
            end
            @(posedge compute_vif.aclk);
        end
        if (!cplq_all_engines_idle)
            `uvm_fatal("CLUSTER_CPLQ_BACKPRESSURE",
                $sformatf("engines did not finish while CPLQ was full; busy=%07b",
                          compute_vif.engine_busy))
        if (compute_vif.cplq_full !== 1'b1 ||
            compute_vif.processor_busy !== 1'b1)
            `uvm_fatal("CLUSTER_CPLQ_BACKPRESSURE", $sformatf(
                "full completion queue must retain dispatcher work; cplq_full=%0b processor_busy=%0b",
                compute_vif.cplq_full, compute_vif.processor_busy))

        for (cplq_poll = 0; cplq_poll < 8; cplq_poll++) begin
            axil_read(REG_CPLQ_TAIL, value);
            if (value !== 32'd3 || compute_vif.cplq_full !== 1'b1)
                `uvm_fatal("CLUSTER_CPLQ_BACKPRESSURE", $sformatf(
                    "completion tail escaped full-ring hold: tail=%0d full=%0b poll=%0d",
                    value, compute_vif.cplq_full, cplq_poll))
        end
        for (word_idx = 0; word_idx < 4; word_idx++)
            expect_spad(CPLQ_LOCAL + 32'h330 + (word_idx << 2),
                        32'hc07f_7200 | word_idx,
                        $sformatf("CPLQ full held completion sentinel[%0d]", word_idx));
        axil_read(REG_CMDQ_HEAD, value);
        if (value !== 32'd4)
            `uvm_fatal("CLUSTER_CPLQ_BACKPRESSURE", $sformatf(
                "all four descriptors must dispatch before completion backpressure: CMDQ_HEAD=%0d",
                value))

        expect_completion(CPLQ_LOCAL + 32'h300, 16'h0810,
                          matrix_golden[15][31], 32'd512,
                          "CPLQ-full Matrix head completion");
        expect_completion(CPLQ_LOCAL + 32'h310, 16'h0811, 32'd736, 32'd16,
                          "CPLQ-full CNM completion");
        expect_completion(CPLQ_LOCAL + 32'h320, 16'h0812, -32'sd15, 32'd4,
                          "CPLQ-full SFU completion");

        axil_write(REG_CPLQ_HEAD, 32'd1);
        wait_cpl_tail(32'd0);
        wait_spad_idle();
        if (compute_vif.cplq_full !== 1'b1 ||
            compute_vif.processor_busy !== 1'b0)
            `uvm_fatal("CLUSTER_CPLQ_BACKPRESSURE", $sformatf(
                "released slot must retire the pending completion, wrap tail, refill the ring, and drain dispatcher: cplq_full=%0b processor_busy=%0b",
                compute_vif.cplq_full, compute_vif.processor_busy))
        expect_completion(CPLQ_LOCAL + 32'h330, 16'h0813, 32'd70, 32'd1,
                          "CPLQ-full released Scalar completion");
        for (word_idx = 0; word_idx < 512; word_idx++)
            expect_spad(MATRIX_Y_LOCAL + (word_idx << 2),
                        matrix_golden[word_idx / 32][word_idx % 32],
                        $sformatf("CPLQ full Matrix Golden[%0d]", word_idx));
        for (word_idx = 0; word_idx < 16; word_idx++)
            expect_spad(CNM_Y_LOCAL + (word_idx << 2), 32'd736,
                        $sformatf("CPLQ full CNM Golden[%0d]", word_idx));
        for (word_idx = 0; word_idx < 4; word_idx++)
            expect_spad(SWEEP_SFU_Y_LOCAL + (word_idx << 2),
                        gelu_results[word_idx],
                        $sformatf("CPLQ full SFU Golden[%0d]", word_idx));
        expect_spad(SCALAR_Y_LOCAL, 32'd70, "CPLQ full Scalar Golden");
        `uvm_info("CLUSTER_CPLQ_BACKPRESSURE_PASS",
            "four real engines completed; blocked_tail=3 released_head=1 wrapped_tail=0 all_engines_idle=1; ordered completion, retained sentinel, and four Goldens checked",
            UVM_LOW)
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);

        // C1 real-top sweep: issue one descriptor for every physical engine
        // in one queue window. Each engine gets a legal, long-running workload
        // with disjoint SPAD operands, so every observed busy overlap is real
        // concurrent execution and not an artificial busy signal.
        for (word_idx = 0; word_idx < 128; word_idx++) begin
            spad_write(C1_SCALAR_A_LOCAL + (word_idx << 2), 32'h0101_0101);
            spad_write(C1_SCALAR_B_LOCAL + (word_idx << 2), 32'h0101_0101);
            if ((word_idx % 2) == 0) begin
                spad_write(C1_FP_A_LOCAL + (word_idx << 1), 32'h3f80_3f80);
                spad_write(C1_FP_B_LOCAL + (word_idx << 1), 32'h3f80_3f80);
            end
            spad_write(C1_KV_VECTOR_LOCAL + (word_idx << 2), 32'h0000_0100 + word_idx);
            spad_write(C1_KV_CACHE_LOCAL + 32'h50 + (word_idx << 2), 32'hbad0_6400 + word_idx);
        end
        // Keep the dedicated four-word KV parity-fault operand initialized;
        // its raw parity bit must be known before the directed fault deposit.
        for (word_idx = 0; word_idx < 4; word_idx++)
            spad_write(KV_VECTOR_LOCAL + (word_idx << 2), (word_idx + 1) * 32'h100);
        // Preserve the compact operands used by the independent fault and
        // reset sweeps that follow C1; those tests inject parity into the
        // original low-address regions rather than the long C1 buffers.
        spad_write(SCALAR_A_LOCAL, 32'h0403_0201);
        spad_write(SCALAR_B_LOCAL, 32'h0807_0605);
        spad_write(FP_A_LOCAL, 32'h4000_3f80);
        spad_write(FP_B_LOCAL, 32'h4080_4040);
        spad_write(FP_Y_LOCAL, 32'hdead_cafe);
        for (word_idx = 0; word_idx < 9; word_idx++) begin
            spad_write(CONV_A_LOCAL + (word_idx << 2), word_idx + 1);
            spad_write(CONV_W_LOCAL + (word_idx << 2), 32'd1);
        end
        spad_write(CONV_Y_LOCAL, 32'hdead_c0de);
        for (word_idx = 0; word_idx < 4; word_idx++)
            spad_write(KV_CACHE_LOCAL + 32'h50 + (word_idx << 2),
                       32'hbad0_6400 + word_idx);
        spad_write(C1_SCALAR_Y_LOCAL, 32'hdead_cafe);
        spad_write(C1_FP_Y_LOCAL, 32'hdead_cafe);

        for (c1_k = 0; c1_k < 64; c1_k++) begin
            for (c1_col = 0; c1_col < 4; c1_col++) begin
                case (c1_col)
                    0: packed_word = 32'h0202_0202;
                    1: packed_word = 32'h0303_0303;
                    2: packed_word = 32'h0404_0404;
                    default: packed_word = 32'h0505_0505;
                endcase
                spad_write(C1_CNM_A_LOCAL + (c1_k << 4) + (c1_col << 2), packed_word);
            end
            for (c1_row = 0; c1_row < 16; c1_row++) begin
                for (c1_col = 0; c1_col < 4; c1_col++) begin
                    case (c1_col)
                        0: packed_word = 32'h0707_0707;
                        1: packed_word = 32'h0b0b_0b0b;
                        2: packed_word = 32'h0d0d_0d0d;
                        default: packed_word = 32'h1111_1111;
                    endcase
                    spad_write(C1_CNM_B_LOCAL + (((c1_row * 64) + c1_k) << 4) + (c1_col << 2), packed_word);
                end
            end
        end
        for (word_idx = 0; word_idx < 128; word_idx++) begin
            spad_write(C1_SFU_A_LOCAL + (word_idx << 2), gelu_values[word_idx % 4]);
            spad_write(C1_SFU_Y_LOCAL + (word_idx << 2), 32'hdead_0000 | word_idx);
        end
        for (word_idx = 0; word_idx < 256; word_idx++)
            spad_write(C1_CONV_A_LOCAL + (word_idx << 2), 32'd1);
        for (word_idx = 0; word_idx < 9; word_idx++)
            spad_write(C1_CONV_W_LOCAL + (word_idx << 2), 32'd1);
        spad_write(C1_CONV_Y_LOCAL, 32'hdead_c0de);

        write_v3_desc(CLUSTER_SWEEP_CMDQ + 32'h000, 8'h30, 16'h0640,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, SWEEP_MATRIX_Y_LOCAL,
                      16'd16, 16'd32, 16'd16);
        write_cnm_v3_desc(CLUSTER_SWEEP_CMDQ + 32'h040, 16'h0641,
                          C1_CNM_A_LOCAL, C1_CNM_B_LOCAL, C1_CNM_Y_LOCAL);
        spad_write(CLUSTER_SWEEP_CMDQ + 32'h054, {16'd1, 16'd16});
        spad_write(CLUSTER_SWEEP_CMDQ + 32'h058, 32'd64);
        write_v3_desc(CLUSTER_SWEEP_CMDQ + 32'h080, 8'h35, 16'h0642,
                      C1_SFU_A_LOCAL, 32'd0, C1_SFU_Y_LOCAL,
                      16'd0, 16'd0, 16'd128);
        write_cluster_desc(CLUSTER_SWEEP_CMDQ + 32'h0c0, 8'h10, 16'h0643,
                           C1_KV_VECTOR_LOCAL, C1_SCALAR_B_LOCAL, C1_SCALAR_Y_LOCAL,
                           16'd0, 16'd0, 16'd128, 32'd0,
                           32'd0, 32'd0, 32'd0, 8'd3);
        write_cluster_desc(CLUSTER_SWEEP_CMDQ + 32'h100, 8'h50, 16'h0644,
                           C1_FP_A_LOCAL, C1_FP_B_LOCAL, C1_FP_Y_LOCAL,
                           16'd1, 16'd1, 16'd128, 32'd0,
                           32'd0, 32'd0, 32'd0, 8'd7);
        write_cluster_desc(CLUSTER_SWEEP_CMDQ + 32'h140, 8'h16, 16'h0645,
                           C1_CONV_A_LOCAL, C1_CONV_W_LOCAL, C1_CONV_Y_LOCAL,
                           16'd16, 16'd16, 16'd9, 32'd0,
                           32'd0, 32'd0, 32'd0, 8'd5);
        write_cluster_desc(CLUSTER_SWEEP_CMDQ + 32'h180, 8'h43, 16'h0646,
                           C1_KV_VECTOR_LOCAL, 32'd0, C1_KV_CACHE_LOCAL,
                           16'd0, 16'd0, 16'd128, {16'd1,16'd1},
                           32'd16, 32'd64, 32'd0, 8'd5);

        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, CLUSTER_SWEEP_CMDQ);
        axil_write(REG_CMDQ_SIZE, 32'd8);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd7);
        axil_write(REG_CPLQ_BASE, CLUSTER_SWEEP_CPLQ);
        axil_write(REG_CPLQ_SIZE, 32'd8);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        engine_pair_overlap_seen = '0;
        max_active_engines = 0;
        c1_alias_accept_seen = '0;
        c1_alias_response_seen = '0;
        c1_alias_pending = '0;
        c1_alias_max_read_owners = 0;
        c1_run_started = 1'b0;
        c1_run_complete = 1'b0;
        axil_write(REG_DOORBELL, 32'd1);
        for (pair_poll = 0; pair_poll < 60000; pair_poll++) begin
            @(posedge compute_vif.aclk);
            // Scalar (engine 0) and KV (engine 6) legally share the same
            // read-only vector. Track accepted reads anywhere in that vector
            // and tagged returns while all seven engines use the production mux.
            if (compute_vif.engine_req_valid[0] &&
                compute_vif.engine_req_ready[0] &&
                !compute_vif.engine_req_write[0] &&
                compute_vif.engine_req_addr[0*32 +: 32] >= C1_KV_VECTOR_LOCAL &&
                compute_vif.engine_req_addr[0*32 +: 32] <
                    C1_KV_VECTOR_LOCAL + 32'd512) begin
                c1_alias_accept_seen[0] = 1'b1;
                c1_alias_pending[0] = 1'b1;
            end
            if (compute_vif.engine_req_valid[6] &&
                compute_vif.engine_req_ready[6] &&
                !compute_vif.engine_req_write[6] &&
                compute_vif.engine_req_addr[6*32 +: 32] >= C1_KV_VECTOR_LOCAL &&
                compute_vif.engine_req_addr[6*32 +: 32] <
                    C1_KV_VECTOR_LOCAL + 32'd512) begin
                c1_alias_accept_seen[6] = 1'b1;
                c1_alias_pending[6] = 1'b1;
            end
            if ($countones(c1_alias_pending) > c1_alias_max_read_owners)
                c1_alias_max_read_owners = $countones(c1_alias_pending);
            if (compute_vif.engine_rsp_valid[0] && c1_alias_pending[0]) begin
                c1_alias_pending[0] = 1'b0;
                c1_alias_response_seen[0] = 1'b1;
            end
            if (compute_vif.engine_rsp_valid[6] && c1_alias_pending[6]) begin
                c1_alias_pending[6] = 1'b0;
                c1_alias_response_seen[6] = 1'b1;
            end
            if (compute_vif.processor_busy || (compute_vif.engine_busy != 7'd0) ||
                compute_vif.cpl_valid)
                c1_run_started = 1'b1;
            if ($countones(compute_vif.engine_busy) > max_active_engines)
                max_active_engines = $countones(compute_vif.engine_busy);
            pair_index = 0;
            for (pair_i = 0; pair_i < 7; pair_i++) begin
                for (pair_j = pair_i + 1; pair_j < 7; pair_j++) begin
                    if (compute_vif.engine_busy[pair_i] &&
                        compute_vif.engine_busy[pair_j])
                        engine_pair_overlap_seen[pair_index] = 1'b1;
                    pair_index++;
                end
            end
            if (c1_run_started && !compute_vif.processor_busy &&
                (compute_vif.engine_busy == 7'd0) && !compute_vif.cpl_valid) begin
                c1_run_complete = 1'b1;
                break;
            end
        end
        if (!c1_run_complete)
            `uvm_fatal("CLUSTER_ENGINE_PAIR_CROSS",
                "all-engine C1 queue did not drain before overlap-monitor timeout")
        axil_read(REG_CPLQ_TAIL, value);
        if (value !== 32'd7)
            `uvm_fatal("CLUSTER_ENGINE_PAIR_CROSS", $sformatf(
                "all-engine C1 completion tail expected=7 actual=%0d", value))
        if (engine_pair_overlap_seen !== 21'h1f_ffff)
            `uvm_fatal("CLUSTER_ENGINE_PAIR_CROSS", $sformatf(
                "real-engine overlap incomplete: pair mask=%06h expected=1fffff max_active=%0d",
                engine_pair_overlap_seen, max_active_engines))
        engine_pair_overlap_bins_hit = 0;
        for (pair_index = 0; pair_index < 21; pair_index++) begin
            if (engine_pair_overlap_seen[pair_index]) begin
                engine_pair_overlap_cov_idx = pair_index;
                engine_pair_overlap_cg.sample();
                engine_pair_overlap_bins_hit++;
            end
        end
        if (engine_pair_overlap_bins_hit != 21 ||
            engine_pair_overlap_cg.get_coverage() < 100.0)
            `uvm_fatal("CLUSTER_ENGINE_PAIR_COVERAGE", $sformatf(
                "real engine-pair coverage bins=%0d/21 coverage=%0.1f%% expected=100.0%%",
                engine_pair_overlap_bins_hit, engine_pair_overlap_cg.get_coverage()))
        wait_spad_idle();

        for (word_idx = 0; word_idx < 512; word_idx++)
            expect_spad(SWEEP_MATRIX_Y_LOCAL + (word_idx << 2),
                        matrix_golden[word_idx / 32][word_idx % 32],
                        $sformatf("C1 Matrix Golden[%0d]", word_idx));
        for (word_idx = 0; word_idx < 16; word_idx++)
            expect_spad(C1_CNM_Y_LOCAL + (word_idx << 2), 32'd47104,
                        $sformatf("C1 CNM Golden[%0d]", word_idx));
        for (word_idx = 0; word_idx < 128; word_idx++) begin
            expect_spad(C1_SFU_Y_LOCAL + (word_idx << 2), gelu_results[word_idx % 4],
                        $sformatf("C1 SFU Golden[%0d]", word_idx));
            expect_spad(C1_KV_CACHE_LOCAL + 32'h50 + (word_idx << 2),
                        32'h0000_0100 + word_idx,
                        $sformatf("C1 KV write Golden[%0d]", word_idx));
        end
        expect_spad(C1_SCALAR_Y_LOCAL, 32'd8256,
                    "C1 scalar INT8 VDOT shared-read-only KV source Golden");
        expect_spad(C1_FP_Y_LOCAL, 32'h4300_0000, "C1 BF16 dot Golden");
        for (word_idx = 0; word_idx < 196; word_idx++)
            expect_spad(C1_CONV_Y_LOCAL + (word_idx << 2), 32'd9,
                        $sformatf("C1 CONV3x3 Golden[%0d]", word_idx));
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h00, 16'h0640,
                          matrix_golden[15][31], 32'd512, "C1 Matrix");
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h10, 16'h0641,
                          32'd47104, 32'd16, "C1 CNM");
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h20, 16'h0642,
                          -32'sd15, 32'd128, "C1 SFU");
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h30, 16'h0643,
                          32'd8256, 32'd1, "C1 scalar INT8 shared-source");
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h40, 16'h0644,
                          32'h4300_0000, 32'd128, "C1 BF16");
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h50, 16'h0645,
                          32'd9, 32'd196, "C1 CONV3x3");
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h60, 16'h0646,
                          32'h0000_017f, 32'd128, "C1 KV write");
        for (engine_idx = 0; engine_idx < 7; engine_idx++) begin
            if (compute_vif.engine_launch_count[engine_idx] == 0)
                `uvm_fatal("CLUSTER_ENGINE_COVERAGE", $sformatf(
                    "real top did not launch engine %0d", engine_idx))
        end
        if (compute_vif.engine_backpressure_cycles == 0 ||
            compute_vif.engine_backpressure_seen == 0)
            `uvm_fatal("CLUSTER_ENGINE_BACKPRESSURE", "no engine request was denied by the shared compute SPAD mux")
        if (c1_alias_accept_seen !== 7'b1000001 ||
            c1_alias_response_seen !== 7'b1000001 ||
            c1_alias_pending !== 7'b0 || c1_alias_max_read_owners != 2 ||
            !engine_pair_overlap_seen[5])
            `uvm_fatal("CLUSTER_SHARED_READ_ALIAS", $sformatf(
                "Scalar/KV shared read-only region did not overlap and drain with correct owner: accepted=%07b responses=%07b pending=%07b max_read_owners=%0d scalar_kv_busy_overlap=%0b",
                c1_alias_accept_seen, c1_alias_response_seen,
                c1_alias_pending, c1_alias_max_read_owners,
                engine_pair_overlap_seen[5]))
        c1_shared_read_alias_case = 1;
        c1_shared_read_alias_cg.sample();
        if (c1_shared_read_alias_cg.get_coverage() < 100.0)
            `uvm_fatal("CLUSTER_SHARED_READ_ALIAS_COVERAGE", $sformatf(
                "Scalar/KV shared-source bin coverage=%0.1f%% expected=100.0%%",
                c1_shared_read_alias_cg.get_coverage()))
        `uvm_info("CLUSTER_ALL_ENGINES_PASS", $sformatf(
                  "all seven production engines launched and matched SPAD Golden; real pair overlaps=21/21 mask=%06h max_active=%0d compute-request backpressure cycles=%0d stalled-engine-mask=%07b",
                  engine_pair_overlap_seen, max_active_engines,
                  compute_vif.engine_backpressure_cycles,
                  compute_vif.engine_backpressure_seen), UVM_LOW)
        `uvm_info("CLUSTER_ALL_ENGINE_PAIR_COVERAGE_PASS", $sformatf(
            "pair bins=%0d/21 coverage=%0.1f%% sampled only from observed overlap mask=%06h",
            engine_pair_overlap_bins_hit, engine_pair_overlap_cg.get_coverage(),
            engine_pair_overlap_seen), UVM_LOW)
        `uvm_info("CLUSTER_SHARED_READ_ALIAS_PASS", $sformatf(
            "Scalar/KV read the same read-only SPAD region; accepted request owners=%0d/2 owner-tagged responses=%0d/2 max simultaneous read owners=%0d Scalar/KV busy-overlap=%0b focused bin=1/1 coverage=%.1f%%",
            $countones(c1_alias_accept_seen),
            $countones(c1_alias_response_seen), c1_alias_max_read_owners,
            engine_pair_overlap_seen[5], c1_shared_read_alias_cg.get_coverage()),
            UVM_LOW)
        axil_read(REG_CMDQ_HEAD, value);
        if (value !== 32'd7)
            `uvm_fatal("CLUSTER_ENGINE_COVERAGE", $sformatf("C1 CMDQ_HEAD expected=7 actual=%0d", value))
        axil_write(REG_CPLQ_HEAD, 32'd7);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);

        for (engine_idx = 0; engine_idx < 7; engine_idx++)
            run_all_engine_parallel_parity_case(seed, matrix_golden, engine_idx);
        if (engine_parallel_fault_cg.get_coverage() < 100.0)
            `uvm_fatal("CLUSTER_PARALLEL_ENGINE_FAULT_COVERAGE", $sformatf(
                "seven-engine parallel parity owner bins=%0.1f%% expected=100%%",
                engine_parallel_fault_cg.get_coverage()))
        `uvm_info("CLUSTER_PARALLEL_ENGINE_FAULT_PASS", $sformatf(
            "legal seven-engine parallel parity: each fault owner overlapped other active engines; six healthy outputs matched Golden; 7 completion owners/statuses checked; no-writeback sentinels passed for each fault owner; fault_owners=7/7 focused_bins=7/7 coverage=%.1f%% seed=%0d",
            engine_parallel_fault_cg.get_coverage(), seed), UVM_LOW)
        run_all_engine_parallel_reset_epoch_test(seed, matrix_golden);

        // Read the head/token entry back through the real KV engine after the
        // KV-write completion, checking both stride address generation and
        // the complete 128-word payload.
        write_cluster_desc(CLUSTER_SWEEP_CMDQ, 8'h44, 16'h0647,
                           C1_KV_CACHE_LOCAL, 32'd0, C1_KV_READ_LOCAL,
                           16'd0, 16'd0, 16'd128, {16'd1,16'd1},
                           32'd16, 32'd64, 32'd0, 8'd5);
        axil_write(REG_CMDQ_BASE, CLUSTER_SWEEP_CMDQ);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd1);
        axil_write(REG_CPLQ_BASE, CLUSTER_SWEEP_CPLQ + 32'h100);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd1);
        wait_spad_idle();
        for (word_idx = 0; word_idx < 128; word_idx++)
            expect_spad(C1_KV_READ_LOCAL + (word_idx << 2),
                        32'h0000_0100 + word_idx,
                        $sformatf("C1 KV read Golden[%0d]", word_idx));
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h100, 16'h0647,
                          32'h0000_017f, 32'd128, "C1 KV read");
        axil_write(REG_CPLQ_HEAD, 32'd1);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);

        // Seeded randomized ordering of the parity fault cross:
        // all seven engines, A/B operand phase where defined, all CNM lanes;
        // every failed operation must retire ERR_PARITY without writeback.
        for (word_idx = 0; word_idx < 4; word_idx++) begin
            spad_write(MATRIX_FAULT_A_LOCAL + (word_idx << 2),
                       32'h1100_0000 | word_idx);
            spad_write(MATRIX_FAULT_B_LOCAL + (word_idx << 2),
                       32'h2200_0000 | word_idx);
        end
        for (word_idx = 0; word_idx < 9; word_idx++) begin
            spad_write(CONV_A_LOCAL + (word_idx << 2), word_idx + 1);
            spad_write(CONV_W_LOCAL + (word_idx << 2), 32'd1);
        end
        for (fault_i = 0; fault_i < 18; fault_i++) fault_order[fault_i] = fault_i;
        for (fault_i = 17; fault_i > 0; fault_i--) begin
            rng_state = rng_state ^ (rng_state << 13);
            rng_state = rng_state ^ (rng_state >> 17);
            rng_state = rng_state ^ (rng_state << 5);
            fault_j = rng_state % (fault_i + 1);
            fault_swap = fault_order[fault_i];
            fault_order[fault_i] = fault_order[fault_j];
            fault_order[fault_j] = fault_swap;
        end
        fault_cases_seen = '0;
        for (fault_i = 0; fault_i < 18; fault_i++) begin
            fault_case_id = fault_order[fault_i];
            if (fault_cases_seen[fault_case_id])
                `uvm_fatal("CLUSTER_FAULT_CROSS", $sformatf("duplicate randomized fault case=%0d", fault_case_id))
            fault_cases_seen[fault_case_id] = 1'b1;
            run_random_parity_case(fault_case_id, seed);
        end
        if (fault_cases_seen !== 18'h3ffff)
            `uvm_fatal("CLUSTER_FAULT_CROSS", $sformatf("fault cross incomplete: seen=%h", fault_cases_seen))
        `uvm_info("CLUSTER_RANDOM_FAULT_CROSS_PASS", $sformatf(
            "parity cases=18/18; engines={INT8,Matrix,CNM,BF16,SFU,Conv,KV}; operand phases={A,B where defined}; CNM lanes=4/4; randomized_order_seed=%0d",
            seed), UVM_LOW)

        run_matrix_parity_cnm_owner_cross(seed, 0, matrix_golden);
        run_matrix_parity_cnm_owner_cross(seed, 1, matrix_golden);
        run_matrix_parity_cnm_owner_cross(seed, 2, matrix_golden);
        run_matrix_parity_cnm_owner_cross(seed, 3, matrix_golden);
        run_matrix_protection_cnm_owner_cross(seed, 1'b0, 1'b0, 1'b0);
        run_matrix_protection_cnm_owner_cross(seed, 1'b1, 1'b0, 1'b0);
        run_matrix_protection_cnm_owner_cross(seed, 1'b0, 1'b1, 1'b0);
        run_matrix_protection_cnm_owner_cross(seed, 1'b0, 1'b1, 1'b1);
        run_cnm_protection_matrix_owner_cross(seed, matrix_golden, 1'b0, 1'b0, 1'b0);
        run_cnm_protection_matrix_owner_cross(seed, matrix_golden, 1'b1, 1'b0, 1'b0);
        run_cnm_protection_matrix_owner_cross(seed, matrix_golden, 1'b0, 1'b1, 1'b0);
        run_cnm_protection_matrix_owner_cross(seed, matrix_golden, 1'b1, 1'b0, 1'b1);

        // Cross source-A, source-B where present, and writeback protection
        // phases on real engines. SFU and KV have no second source operand.
        protection_case_count = 0;
        for (engine_idx = 0; engine_idx < 7; engine_idx++) begin
            run_real_engine_protection_case(engine_idx, 0, seed);
            protection_case_count++;
        end
        for (engine_idx = 0; engine_idx < 7; engine_idx++) begin
            if ((engine_idx == 0) || (engine_idx == 1) || (engine_idx == 2) ||
                (engine_idx == 3) || (engine_idx == 5)) begin
                run_real_engine_protection_case(engine_idx, 1, seed);
                protection_case_count++;
            end
        end
        for (engine_idx = 0; engine_idx < 7; engine_idx++) begin
            run_real_engine_protection_case(engine_idx, 2, seed);
            protection_case_count++;
        end
        if (protection_case_count != 19)
            `uvm_fatal("CLUSTER_PROTECTION", $sformatf(
                "expected 19 engine/phase cases, observed %0d", protection_case_count))
        `uvm_info("CLUSTER_PROTECTION_CROSS_PASS", $sformatf(
            "protection cases=19/19; sourceA=7 sourceB=5 writeback=7 across real engines; descriptor fetch/completion writes permitted; seed=%0d",
            seed), UVM_LOW)

        // Abort two real in-flight engines after their overlap is observed.
        // Sentinels prove the Matrix tile has not started writeback at abort.
        for (word_idx = 0; word_idx < 4; word_idx++)
            spad_write(32'h0003_1000 + (word_idx << 2), 32'hbad0_0600 + word_idx);
        write_v3_desc(CMDQ_LOCAL + 32'h100, 8'h30, 16'h0610,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, 32'h0003_1000,
                      16'd16, 16'd16, 16'd16);
        write_v3_desc(CMDQ_LOCAL + 32'h140, 8'h35, 16'h0611,
                      GELU_A_LOCAL, 32'd0, 32'h0003_1100,
                      16'd0, 16'd0, 16'd1024);
        axil_write(REG_CMDQ_BASE, CMDQ_LOCAL + 32'h100);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd2);
        axil_write(REG_CPLQ_BASE, CPLQ_LOCAL + 32'h100);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        axil_write(REG_DOORBELL, 32'd1);
        wait_matrix_sfu_overlap();
        wait_matrix_prefetch_active();
        axil_write(REG_ABORT, 32'd1);
        wait_cpl_tail(32'd2);
        if (compute_vif.multi_engine_abort_cycles == 0)
            `uvm_fatal("CLUSTER_ABORT_CROSS", "software abort was not sampled while multiple real engines were active")
        `uvm_info("CLUSTER_ABORT_CROSS_PASS", $sformatf(
                  "simultaneous Matrix/SFU abort observed for %0d cycles",
                  compute_vif.multi_engine_abort_cycles), UVM_LOW)
        expect_spad(CPLQ_LOCAL + 32'h100, 32'h0000_0610, "abort Matrix task ID");
        expect_spad(CPLQ_LOCAL + 32'h104, 32'h0000_0032, "abort Matrix status/code");
        expect_spad(CPLQ_LOCAL + 32'h110, 32'h0000_0611, "abort SFU task ID");
        expect_spad(CPLQ_LOCAL + 32'h114, 32'h0000_0032, "abort SFU status/code");
        for (word_idx = 0; word_idx < 4; word_idx++)
            expect_spad(32'h0003_1000 + (word_idx << 2), 32'hbad0_0600 + word_idx,
                        $sformatf("abort Matrix no-writeback[%0d]", word_idx));
        if (compute_vif.engine_busy != 0)
            `uvm_fatal("CLUSTER_ABORT", $sformatf("abort completion published with engine_busy=%07b", compute_vif.engine_busy))
        axil_write(REG_CPLQ_HEAD, 32'd2);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);

        // Reset both real engines while they are active. The behavioral SRAM
        // contents are retained across accelerator reset; the command and
        // completion lifecycle state must be cleared without stale writeback.
        for (word_idx = 0; word_idx < 4; word_idx++)
            spad_write(32'h0003_2000 + (word_idx << 2), 32'hbad0_0620 + word_idx);
        write_v3_desc(CMDQ_LOCAL + 32'h200, 8'h30, 16'h0620,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, 32'h0003_2000,
                      16'd16, 16'd16, 16'd16);
        write_v3_desc(CMDQ_LOCAL + 32'h240, 8'h35, 16'h0621,
                      GELU_A_LOCAL, 32'd0, 32'h0003_2100,
                      16'd0, 16'd0, 16'd1024);
        axil_write(REG_CMDQ_BASE, CMDQ_LOCAL + 32'h200);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd2);
        axil_write(REG_CPLQ_BASE, CPLQ_LOCAL + 32'h200);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        axil_write(REG_DOORBELL, 32'd1);
        wait_matrix_sfu_overlap();
        wait_matrix_read_accept();
        wait_matrix_prefetch_active();
        recovery_start_cycle = compute_vif.sim_cycles;
        #1ns;
        reset_value = 1'b0;
        reset_ok = uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", reset_value);
        if (!reset_ok)
            `uvm_fatal("CLUSTER_RESET", "failed to assert accelerator reset with Matrix and SFU active")
        repeat (4) @(posedge compute_vif.aclk);
        if (compute_vif.engine_busy !== 7'b0)
            `uvm_fatal("CLUSTER_RESET", $sformatf("engines did not clear during reset: %07b", compute_vif.engine_busy))
        reset_value = 1'b1;
        reset_ok = uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", reset_value);
        if (!reset_ok)
            `uvm_fatal("CLUSTER_RESET", "failed to release accelerator reset")
        repeat (8) @(posedge compute_vif.aclk);
        axil_read(REG_CPLQ_TAIL, value);
        if (value !== 32'd0)
            `uvm_fatal("CLUSTER_RESET", $sformatf("stale completion tail after reset: %0d", value))
        for (word_idx = 0; word_idx < 4; word_idx++)
            expect_spad(32'h0003_2000 + (word_idx << 2), 32'hbad0_0620 + word_idx,
                        $sformatf("reset Matrix no-writeback[%0d]", word_idx));

        // Prove the real cluster and queue path recover after reset by
        // executing a fresh SFU task and checking its completion and image.
        write_v3_desc(CMDQ_LOCAL + 32'h300, 8'h35, 16'h0622,
                      GELU_A_LOCAL, 32'd0, GELU_Y0_LOCAL,
                      16'd0, 16'd0, 16'd4);
        axil_write(REG_CMDQ_BASE, CMDQ_LOCAL + 32'h300);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd1);
        axil_write(REG_CPLQ_BASE, CPLQ_LOCAL + 32'h300);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd1);
        recovery_cycles = compute_vif.sim_cycles - recovery_start_cycle;
        expect_completion(CPLQ_LOCAL + 32'h300, 16'h0622, -32'sd15, 32'd4,
                          "post-reset SFU recovery");
        expect_spad(GELU_Y0_LOCAL + 32'h00, 32'd8, "post-reset GELU output0");
        expect_spad(GELU_Y0_LOCAL + 32'h04, -32'sd8, "post-reset GELU output1");
        expect_spad(GELU_Y0_LOCAL + 32'h08, 32'd17, "post-reset GELU output2");
        expect_spad(GELU_Y0_LOCAL + 32'h0c, -32'sd15, "post-reset GELU output3");
        axil_write(REG_CPLQ_HEAD, 32'd1);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
        overlap_total += compute_vif.overlap_cycles;
        contention_total += compute_vif.shared_spad_contention_cycles;
        banked_grants_total += compute_vif.arb_banked_grants;
        core_grants_total += compute_vif.arb_core_grants;
        `uvm_info("CLUSTER_RESET_RECOVERY_PASS", "active Matrix/SFU reset discarded both in-flight tasks, preserved SRAM sentinels, and accepted a fresh post-reset SFU task", UVM_LOW)
        `uvm_info("CLUSTER_RECOVERY_BENCH", $sformatf(
            "active reset-to-recovery completion=%0d cycles; scoreboard later reports reset-dropped accepted SPAD reads",
            recovery_cycles), UVM_LOW)

        run_dma_store_response_test();
        run_banked_vdot_cmdq_dispatch_test(seed);
        run_scalar_vdot_minimum_cmdq_boundary_test(seed);
        run_cmdq_invalid_descriptor_matrix_test(seed);
        run_engine_protection_full_cplq_cross(seed);
        run_scalar_gemv_gemm_cmdq_dispatch_test(seed);
        run_scalar_cmdq_numeric_boundary_test(seed);
        run_scalar_legacy_conv_cmdq_test(seed);
        run_conv_cmdq_shape_boundary_test(seed);
        run_depthwise_multichannel_cmdq_test(seed);
        run_scalar_gemv_abort_write_prefix(seed);
        run_cnm_inflight_parameter_latch_test();
        run_launch_snapshot_and_unused_fields_test();
        run_inflight_parameter_latch_test();
        run_matrix_inflight_parameter_latch_test(matrix_golden);
        run_sfu_inflight_parameter_latch_test();
        run_fp_inflight_parameter_latch_test();
        run_fp16_cmdq_numeric_golden_test(seed);
        run_conv_inflight_parameter_latch_test();
        run_kv_inflight_parameter_latch_test();
        run_shared_readonly_isolation_test();
        check_request_stability();
        run_engine_abort_drain_sweep();
        run_engine_abort_full_cplq_cross(seed);
        run_sfu_abort_write_prefix(seed);
        run_sfu_reset_write_prefix(seed);
        run_fp_reset_single_write(seed);
        run_conv_abort_write_prefix(seed);
        run_conv_reset_write_prefix(seed);
        run_kv_abort_write_prefix(seed);
        run_matrix_abort_write_prefix(seed);
        run_matrix_line_abort_write_prefix(seed);
        run_cnm_abort_write_prefix(seed);
        run_engine_reset_drain_sweep();
        run_engine_parity_reset_sweep(seed);
        run_matrix_parity_reset_epoch_case(seed);
        run_matrix_protection_reset_epoch_case(seed);
        run_matrix_protection_cnm_pending_reset_case(seed);
        run_engine_protection_reset_sweep(seed);
        run_real_engine_watchdog_sweep(seed);
        run_engine_watchdog_full_cplq_cross(seed);
        run_engine_parity_full_cplq_cross(seed);
        run_opcode_dispatch_sweep(seed);

        `uvm_info("COMPUTE_CLUSTER_REAL_UVM_PASS", $sformatf(
            "standalone Matrix16x32x64 Golden + 16 A-tile reuse hits; parallel Matrix/CNM GEMV with separate response tags and four-bank Golden + next-K prefetch + queued SFU tasks + concurrent abort/reset/recovery seed=%0d; prefetch_overlap=%0d matrix_cnm_overlap=%0d matrix_rsp=%0d cnm_rsp=%0d cnm_lanes=%b overlap=%0d arbiter_contention=%0d banked_grants=%0d cnm_grants=%0d core_grants=%0d",
            seed, matrix_prefetch_overlap_total,
            matrix_cnm_overlap_total, matrix_responses_total, cnm_responses_total,
            cnm_lanes_seen_total,
            overlap_total, contention_total,
            banked_grants_total, cnm_grants_total,
            core_grants_total), UVM_LOW)
    endtask
endclass
