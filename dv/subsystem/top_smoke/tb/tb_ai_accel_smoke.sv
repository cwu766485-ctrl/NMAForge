Warning: truncated output (original token count: 74695)
Total output lines: 5911

`timescale 1ns / 1ps

`ifndef AI_SPAD_WORDS_PER_BANK
`define AI_SPAD_WORDS_PER_BANK 32768
`endif
`ifndef AI_TINYNPU_CNN_SPAD_BASE_SHIFT
`define AI_TINYNPU_CNN_SPAD_BASE_SHIFT 0
`endif

module tb_ai_accel_smoke;

    localparam FPGA_AXI_BASE     = 32'ha000_0000;
    localparam REG_CTRL          = 32'h0000_0000;
    localparam REG_STATUS        = 32'h0000_0004;
    localparam REG_OP_MODE       = 32'h0000_0008;
    localparam REG_SRC0_BASE     = 32'h0000_000c;
    localparam REG_SRC1_BASE     = 32'h0000_0010;
    localparam REG_DST_BASE      = 32'h0000_0014;
    localparam REG_LENGTH        = 32'h0000_0018;
    localparam REG_M_SIZE        = 32'h0000_001c;
    localparam REG_N_SIZE        = 32'h0000_0020;
    localparam REG_K_WORDS       = 32'h0000_0024;
    localparam REG_QUANT_ACT     = 32'h0000_0028;
    localparam REG_RESULT        = 32'h0000_002c;
    localparam REG_ERROR_CODE    = 32'h0000_0030;
    localparam REG_IRQ_STATUS    = 32'h0000_003c;
    localparam REG_IRQ_ENABLE    = 32'h0000_0040;
    localparam REG_VERSION       = 32'h0000_0044;
    localparam REG_CMDQ_BASE_LO   = 32'h0000_0080;
    localparam REG_CMDQ_BASE_HI   = 32'h0000_0084;
    localparam REG_CMDQ_SIZE      = 32'h0000_0088;
    localparam REG_CMDQ_HEAD      = 32'h0000_008c;
    localparam REG_CMDQ_TAIL      = 32'h0000_00c8;
    localparam REG_CPLQ_BASE_LO   = 32'h0000_0090;
    localparam REG_CPLQ_SIZE      = 32'h0000_0098;
    localparam REG_CPLQ_TAIL      = 32'h0000_009c;
    localparam REG_CPLQ_HEAD      = 32'h0000_00cc;
    localparam REG_QUEUE_STATUS   = 32'h0000_00d0;
    localparam REG_REGION0_BASE   = 32'h0000_00d4;
    localparam REG_REGION0_LIMIT  = 32'h0000_00d8;
    localparam REG_REGION0_PERM   = 32'h0000_00dc;
    localparam REG_REGION1_BASE   = 32'h0000_00e0;
    localparam REG_REGION1_LIMIT  = 32'h0000_00e4;
    localparam REG_REGION1_PERM   = 32'h0000_00e8;
    localparam REG_REGION2_BASE   = 32'h0000_00ec;
    localparam REG_REGION2_LIMIT  = 32'h0000_00f0;
    localparam REG_REGION2_PERM   = 32'h0000_00f4;
    localparam REG_REGION3_BASE   = 32'h0000_00f8;
    localparam REG_REGION3_LIMIT  = 32'h0000_00fc;
    localparam REG_REGION3_PERM   = 32'h0000_0100;
    localparam REG_DOORBELL      = 32'h0000_00a0;
    localparam REG_ABORT         = 32'h0000_00a4;
    localparam REG_CMDQ_CTRL      = 32'h0000_00ac;
    localparam REG_DMA_CTRL       = 32'h0000_00b0;
    localparam REG_DMA_STATUS     = 32'h0000_00b4;
    localparam REG_DMA_EXT_ADDR   = 32'h0000_00b8;
    localparam REG_DMA_SPAD_ADDR  = 32'h0000_00bc;
    localparam REG_DMA_LENGTH     = 32'h0000_00c0;
    localparam REG_DMA_ERROR_CODE = 32'h0000_00c4;
    localparam REG_DMA_ROW_WORDS  = 32'h0000_0104;
    localparam REG_DMA_ROW_COUNT  = 32'h0000_0108;
    localparam REG_DMA_EXT_STRIDE = 32'h0000_010c;
    localparam REG_DMA_SPAD_STRIDE = 32'h0000_0110;
    localparam REG_DMA_CFG         = 32'h0000_016c;
    localparam REG_DMA_GATHER_INDEX = 32'h0000_0170;
    localparam REG_PERF_CTRL       = 32'h0000_0174;
    localparam REG_PERF_MATRIX_CYCLES = 32'h0000_0178;
    localparam REG_PERF_MATRIX_MAC_CYCLES = 32'h0000_017c;
    localparam REG_PERF_DMA_READ_BYTES = 32'h0000_0184;
    localparam REG_DMA_EXT_HI      = 32'h0000_019c;
    localparam REG_ABI_INFO        = 32'h0000_01a0;
    localparam REG_ERROR_INFO      = 32'h0000_01a4;
    localparam REG_CAP2            = 32'h0000_01a8;
    localparam REG_TILE_EXT_IN_HI  = 32'h0000_01ac;
    localparam REG_TILE_EXT_OUT_HI = 32'h0000_01b0;
    localparam REG_BIAS_BASE       = 32'h0000_0114;
    localparam REG_POST_CTRL       = 32'h0000_0118;
    localparam REG_TILE_CTRL       = 32'h0000_0120;
    localparam REG_TILE_COUNT      = 32'h0000_0124;
    localparam REG_TILE_EXT_IN     = 32'h0000_0128;
    localparam REG_TILE_EXT_OUT    = 32'h0000_012c;
    localparam REG_TILE_EXT_IN_STRIDE  = 32'h0000_0130;
    localparam REG_TILE_EXT_OUT_STRIDE = 32'h0000_0134;
    localparam REG_TILE_BUF0       = 32'h0000_0138;
    localparam REG_TILE_BUF1       = 32'h0000_013c;
    localparam REG_TILE_IN_WORDS   = 32'h0000_0140;
    localparam REG_TILE_OUT_WORDS  = 32'h0000_0144;
    localparam REG_TILE_OUT_OFFSET = 32'h0000_0148;
    localparam REG_PERF_TOTAL      = 32'h0000_014c;
    localparam REG_PERF_DMA        = 32'h0000_0150;
    localparam REG_PERF_COMPUTE    = 32'h0000_0154;
    localparam REG_PERF_OVERLAP    = 32'h0000_0158;
    localparam REG_PERF_STALL      = 32'h0000_015c;
    localparam REG_TILE_COMPLETED  = 32'h0000_0160;
    localparam REG_SPAD_INFO       = 32'h0000_0164;
    localparam REG_EVENT_STATUS    = 32'h0000_0168;
    localparam SPAD_BASE         = 32'h0001_0000;
    localparam [31:0] SPAD_BYTES = 4 * `AI_SPAD_WORDS_PER_BANK * 4;
`ifdef AI_DIGITS_COMPACT_SPAD
    localparam AI_DIGITS_INPUT_BASE = 32'h0001_1000;
    localparam AI_DIGITS_OUTPUT_BASE = 32'h0000_b000;
    localparam AI_DIGITS_HIDDEN_I8_TILE_BASE = 32'h0000_3000;
    localparam AI_DIGITS_DESC_BASE = 32'h0000_9000;
    localparam AI_DIGITS_CPL_BASE = 32'h0000_a000;
`else
    localparam AI_DIGITS_INPUT_BASE = 32'h0005_0000;
    localparam AI_DIGITS_OUTPUT_BASE = 32'h0003_b000;
    localparam AI_DIGITS_HIDDEN_I8_TILE_BASE = 32'h0003_2000;
    localparam AI_DIGITS_DESC_BASE = 32'h0003_8000;
    localparam AI_DIGITS_CPL_BASE = 32'h0003_a000;
`endif
    localparam AI_DIGITS_BATCH = 16;
    localparam AI_DIGITS_DESC_COUNT = 46;
    localparam AI_DIGITS_TEST_SAMPLES = 360;
    localparam AI_DIGITS_HIDDEN_WORDS = 5888;

    localparam [31:0] AI_TINYNPU_CNN_SPAD_SHIFT = `AI_TINYNPU_CNN_SPAD_BASE_SHIFT;
    localparam [31:0] AI_TINYNPU_CNN_IM2COL_BASE = 32'h0001_0000 - AI_TINYNPU_CNN_SPAD_SHIFT;
    localparam [31:0] AI_TINYNPU_CNN_CONV_WEIGHT_BASE = 32'h0001_1000 - AI_TINYNPU_CNN_SPAD_SHIFT;
    localparam [31:0] AI_TINYNPU_CNN_CONV_ROUND_BASE = 32'h0001_1100 - AI_TINYNPU_CNN_SPAD_SHIFT;
    localparam [31:0] AI_TINYNPU_CNN_CONV_RAW_BASE = 32'h0001_2000 - AI_TINYNPU_CNN_SPAD_SHIFT;
    localparam [31:0] AI_TINYNPU_CNN_CONV_I8_BASE = 32'h0001_3000 - AI_TINYNPU_CNN_SPAD_SHIFT;
    localparam [31:0] AI_TINYNPU_CNN_IDENTITY_B_BASE = 32'h0001_4000 - AI_TINYNPU_CNN_SPAD_SHIFT;
    localparam [31:0] AI_TINYNPU_CNN_CONV_BIAS_BASE = 32'h0001_4100 - AI_TINYNPU_CNN_SPAD_SHIFT;
    localparam [31:0] AI_TINYNPU_CNN_CONV_BIAS_RELU_BASE = 32'h0001_5000 - AI_TINYNPU_CNN_SPAD_SHIFT;
    localparam [31:0] AI_TINYNPU_CNN_CONV_RELU_I8_BASE = 32'h0001_6000 - AI_TINYNPU_CNN_SPAD_SHIFT;
    localparam [31:0] AI_TINYNPU_CNN_FC_A_BASE = 32'h0001_8000 - AI_TINYNPU_CNN_SPAD_SHIFT;
    localparam [31:0] AI_TINYNPU_CNN_FC_B_BASE = 32'h0001_9000 - AI_TINYNPU_CNN_SPAD_SHIFT;
    localparam [31:0] AI_TINYNPU_CNN_FC_ROUND_BASE = 32'h0001_a000 - AI_TINYNPU_CNN_SPAD_SHIFT;
    localparam [31:0] AI_TINYNPU_CNN_FC_RAW_BASE = 32'h0001_b000 - AI_TINYNPU_CNN_SPAD_SHIFT;
    localparam [31:0] AI_TINYNPU_CNN_FC_I8_BASE = 32'h0001_c000 - AI_TINYNPU_CNN_SPAD_SHIFT;
    localparam [31:0] AI_TINYNPU_CNN_FC_BIAS_BASE = 32'h0001_c100 - AI_TINYNPU_CNN_SPAD_SHIFT;
    localparam [31:0] AI_TINYNPU_CNN_FC_BIASED_BASE = 32'h0001_d000 - AI_TINYNPU_CNN_SPAD_SHIFT;
    localparam [31:0] AI_TINYNPU_CNN_FINAL_I8_BASE = 32'h0001_e000 - AI_TINYNPU_CNN_SPAD_SHIFT;
    localparam [31:0] AI_TINYNPU_CNN_DESC_BASE = 32'h0002_0000 - AI_TINYNPU_CNN_SPAD_SHIFT;
    localparam [31:0] AI_TINYNPU_CNN_CPL_BASE = 32'h0002_1000 - AI_TINYNPU_CNN_SPAD_SHIFT;

    localparam OP_VDOT_INT8      = 8'h10;
    localparam OP_GEMV_INT8      = 8'h11;
    localparam OP_GEMM_INT8_TILE = 8'h12;
    localparam OP_CONV1X1_INT8   = 8'h13;
    localparam OP_CONV3X3_INT8   = 8'h14;
    localparam OP_DWCONV3X3_INT8 = 8'h15;
    localparam OP_BANKED_VDOT    = 8'h20;
    localparam OP_BANKED_GEMV    = 8'h21;
    localparam OP_TENSOR_GEMM    = 8'h30;
    localparam OP_BATCH_GEMM     = 8'h31;
    localparam OP_TENSOR_GEMM_FUSED = 8'h53;
    localparam OP_TENSOR_GEMV_KFOLD = 8'h52;
    localparam OP_SOFTMAX_Q15    = 8'h32;
    localparam OP_RMSNORM_Q15    = 8'h33;
    localparam OP_RESIDUAL_I32   = 8'h34;
    localparam OP_GELU_Q8_8      = 8'h35;
    localparam OP_REQUANT_I8     = 8'h36;
    localparam OP_SILU_Q8_8      = 8'h37;
    localparam OP_LAYERNORM_Q15  = 8'h38;
    localparam OP_CAUSAL_SOFTMAX_Q15 = 8'h39;
    localparam OP_QKV_PROJ       = 8'h40;
    localparam OP_MHA            = 8'h41;
    localparam OP_FFN            = 8'h42;
    localparam ERR_DESC_INVALID  = 4'd7;
    localparam ERR_CMDQ_EMPTY    = 4'd8;
    localparam ERR_CPLQ_FULL     = 4'd9;
    localparam ERR_PROTECTION    = 4'd6;

    reg         aclk;
    reg         aresetn;
    reg  [31:0] s_axi_awaddr;
    reg         s_axi_awvalid;
    wire        s_axi_awready;
    reg  [31:0] s_axi_wdata;
    reg  [3:0]  s_axi_wstrb;
    reg         s_axi_wvalid;
    wire        s_axi_wready;
    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    reg         s_axi_bready;
    reg  [31:0] s_axi_araddr;
    reg         s_axi_arvalid;
    wire        s_axi_arready;
    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rvalid;
    reg         s_axi_rready;
    wire        irq;

    wire        m_axi_arvalid;
    wire [3:0]  m_axi_arid;
    wire [63:0] m_axi_araddr;
    wire [7:0]  m_axi_arlen;
    wire [2:0]  m_axi_arsize;
    wire [1:0]  m_axi_arburst;
    wire [3:0]  m_axi_arcache;
    wire [2:0]  m_axi_arprot;
    wire [3:0]  m_axi_arqos;
    wire        m_axi_arlock;
    wire        m_axi_arready;
    wire [3:0]  m_axi_rid;
    wire [127:0] m_axi_rdata;
    wire [1:0]  m_axi_rresp;
    wire        m_axi_rvalid;
    wire        m_axi_rlast;
    wire        m_axi_rready;
    wire        m_axi_awvalid;
    wire [3:0]  m_axi_awid;
    wire [63:0] m_axi_awaddr;
    wire [7:0]  m_axi_awlen;
    wire [2:0]  m_axi_awsize;
    wire [1:0]  m_axi_awburst;
    wire [3:0]  m_axi_awcache;
    wire [2:0]  m_axi_awprot;
    wire [3:0]  m_axi_awqos;
    wire        m_axi_awlock;
    wire        m_axi_awready;
    wire        m_axi_wvalid;
    wire [127:0] m_axi_wdata;
    wire [15:0]  m_axi_wstrb;
    wire        m_axi_wlast;
    wire        m_axi_wready;
    wire [3:0]  m_axi_bid;
    wire [1:0]  m_axi_bresp;
    wire        m_axi_bvalid;
    wire        m_axi_bready;

    reg [31:0] rd;
    reg        allow_m_axi_error;
    integer errors;
    integer random_cases;
    integer seed_arg;
    integer profile_ai_seed;
    integer seed_dummy;
    integer matrix_line_write_count;
    integer ai_tile_forward_baseline_a_reads = 0;
    integer ai_tile_forward_enabled_a_reads = 0;
    integer ai_tile_forward_read_phase = 0;
    reg ai_tile_forward_read_monitor = 1'b0;
    reg ai_tile_forward_cross_engine_monitor = 1'b0;
    reg ai_tile_forward_cross_engine_overlap_seen = 1'b0;
    reg ai_tile_forward_source_write_seen = 1'b0;
    reg ai_tile_forward_sfu_destination_write_seen = 1'b0;
    integer ai_tile_forward_sfu_spad_accesses_during_consume = 0;
    integer ai_tile_forward_engine_scan;
    covergroup ai_v2_cross_engine_handoff_cg with function sample(
        bit matrix_sfu_overlap,
        integer sfu_spad_accesses,
        bit source_write_attempt,
        bit output_golden_ok);
        option.per_instance = 1;
        cp_matrix_sfu_overlap: coverpoint matrix_sfu_overlap {
            bins matrix_sfu_parallel = {1'b1};
        }
        cp_sfu_access_during_consume: coverpoint sfu_spad_accesses {
            bins accepted_access = {[1:256]};
        }
        cp_source_immutable: coverpoint source_write_attempt {
            bins no_source_write_attempt = {1'b0};
        }
        cp_output_golden: coverpoint output_golden_ok {
            bins bit_exact_outputs = {1'b1};
        }
        cp_parallel_traffic: cross cp_matrix_sfu_overlap,
                                  cp_sfu_access_during_consume;
    endgroup
    ai_v2_cross_engine_handoff_cg ai_v2_cross_engine_handoff_cg_inst = new();
    integer cp_fetch_done_count;
    reg parallel_engine_overlap_seen = 1'b0;
    reg parallel_same_engine_overlap_violation = 1'b0;
    reg matrix_cnm_case_active = 1'b0;
    reg matrix_cnm_overlap_seen = 1'b0;
    reg matrix_cnm_response_alias_seen = 1'b0;
    integer matrix_cnm_matrix_responses = 0;
    integer matrix_cnm_cnm_responses = 0;
    integer matrix_cnm_profile_window_cycles = 0;
    integer matrix_cnm_matrix_busy_cycles = 0;
    integer matrix_cnm_engine_overlap_cycles = 0;
    integer matrix_cnm_matrix_mac_cycles = 0;
    integer matrix_cnm_matrix_req_wait_cycles = 0;
    integer matrix_cnm_matrix_rsp_wait_cycles = 0;
    integer matrix_cnm_matrix_writeback_cycles = 0;
    integer matrix_cnm_matrix_other_cycles = 0;
    integer matrix_cnm_matrix_rsp_wait_event_cycles = 0;
    integer matrix_cnm_matrix_writeback_stall_cycles = 0;
    integer matrix_cnm_cnm_busy_cycles = 0;
    integer matrix_cnm_cnm_compute_cycles = 0;
    integer matrix_cnm_cnm_req_wait_cycles = 0;
    integer matrix_cnm_cnm_req_wait_lane_cycles = 0;
    integer matrix_cnm_cnm_rsp_wait_cycles = 0;
    integer matrix_cnm_cnm_writeback_cycles = 0;
    integer matrix_cnm_cnm_other_cycles = 0;
    integer matrix_cnm_cnm_rsp_wait_lane_cycles = 0;
    integer matrix_cnm_cnm_writeback_stall_cycles = 0;
    integer matrix_cnm_request_collision_cycles = 0;
    integer matrix_cnm_matrix_read_accepts = 0;
    integer matrix_cnm_cnm_read_words = 0;
    integer matrix_cnm_matrix_line_writes = 0;
    integer matrix_cnm_cnm_scalar_writes = 0;
    integer matrix_cnm_matrix_read_bytes = 0;
    integer matrix_cnm_cnm_read_bytes = 0;
    integer matrix_cnm_matrix_write_bytes = 0;
    integer matrix_cnm_cnm_write_bytes = 0;
    integer matrix_cnm_outstanding_highwater = 0;
    reg [20:0] parallel_engine_pair_seen = 21'd0;
    reg kv_protection_case_active = 1'b0;
    integer kv_protection_read_accepts = 0;
    reg kv_protection_write_denied = 1'b0;
    reg [31:0] kv_protection_denied_addr = 32'd0;
    reg [63:0] last_dma_araddr;
    reg [1023:0] vcd_file;
    reg fp_perf_measure = 1'b0;
    reg fp_perf_random_wready = 1'b0;
    reg fp_perf_random_rvalid_latency = 1'b0;
    integer fp_perf_seed = 20261013;
    reg [31:0] fp_perf_rng = 32'h20261013;
    integer fp_perf_tile_job_cycles = 0;
    integer fp_perf_active_cycles = 0;
    integer fp_perf_compute_cycles = 0;
    integer fp_perf_fetch_stall_cycles = 0;
    integer fp_perf_response_wait_cycles = 0;
    integer fp_perf_write_wait_cycles = 0;
    integer fp_perf_dma_wait_cycles = 0;
    integer fp_perf_dma_grants = 0;
    reg [31:0] ai_digits_image_words [0:32767];
    reg [31:0] ai_digits_expected_words [0:5000];
    reg [31:0] ai_digits_hidden_words [0:6000];
    reg [31:0] ai_tinynpu_cnn_image_words [0:4095];
    reg [31:0] ai_tinynpu_cnn_expected_words [0:1023];
    // Bounded generic Top-CMDQ workload image used by representative model
    // probes. Files are generated under /tmp; no model data is compiled in.
    reg [31:0] representative_image_words [0:131071];
    reg [31:0] representative_golden_words [0:131071];
    integer representative_load_cycles = 0;
    integer representative_load_measure = 1'b0;
    integer ai_digits_cycles = 0;
    reg ai_digits_measure = 1'b0;
    integer ai_digits_layout_cycles = 0;
    integer ai_digits_layout_bytes = 0;
    reg ai_digits_layout_measure = 1'b0;
    integer ai_digits_fused_lines_by_batch [0:22];
    integer ai_digits_sfu_monitor_batch;
    integer ai_tinynpu_cnn_cycles = 0;
    integer ai_tinynpu_cnn_layout_cycles = 0;
    integer ai_tinynpu_cnn_engine_read_words = 0;
    integer ai_tinynpu_cnn_engine_write_words = 0;
    integer ai_tinynpu_cnn_banked_read_lines = 0;
    integer ai_tinynpu_cnn_line_write_lines = 0;
    integer ai_tinynpu_cnn_traffic_lane;
    reg ai_tinynpu_cnn_measure = 1'b0;
    reg ai_tinynpu_cnn_layout_measure = 1'b0;
    integer transformer_top_cycle_counter = 0;
    integer transformer_top_start_cycle = 0;
    integer transformer_top_prefill_end_cycle = 0;
    integer transformer_top_final_end_cycle = 0;
    integer transformer_top_prefill_target = 0;
    integer transformer_top_final_target = 0;
    integer transformer_top_profile_matrix_mac = 0;
    integer transformer_top_profile_matrix_request_wait = 0;
    integer transformer_top_profile_matrix_response_wait = 0;
    integer transformer_top_profile_matrix_writeback = 0;
    integer transformer_top_profile_matrix_other = 0;
    integer transformer_top_profile_sfu_busy = 0;
    integer transformer_top_profile_kv_busy = 0;
    integer transformer_top_profile_conv_busy = 0;
    integer transformer_top_profile_banked_busy = 0;
    integer transformer_top_profile_fp_busy = 0;
    integer transformer_top_profile_scalar_busy = 0;
    integer transformer_top_profile_no_engine_busy = 0;
    integer transformer_top_profile_dma_busy = 0;
    integer transformer_top_prefill_profile [0:12];
    integer transformer_top_last_completion_cycle = 0;
    integer transformer_top_last_completion_tail = 0;
    integer transformer_top_completion_cycles [0:127];
    integer transformer_top_profile_index;
    integer transformer_top_profile_tail;
    integer transformer_top_profile_cycle;
    reg transformer_top_timing_enable = 1'b0;
    reg transformer_top_prefill_captured = 1'b0;
    reg transformer_top_final_captured = 1'b0;
    integer transformer_spad_read_bytes = 0;
    integer transformer_spad_write_bytes = 0;
    integer transformer_prefill_read_bytes = 0;
    integer transformer_prefill_write_bytes = 0;
    integer transformer_traffic_lane;
    reg transformer_traffic_enable = 1'b0;
    integer r9_sfu_command_index = 0;
    reg r9_sfu_command_active = 1'b0;
    integer r9_sfu_command_opcode = 0;
    integer r9_sfu_command_length = 0;
    integer r9_sfu_command_cycles = 0;
    integer r9_sfu_pass0_cycles = 0;
    integer r9_sfu_pass1_cycles = 0;
    integer r9_sfu_pass2_cycles = 0;
    integer r9_sfu_math_cycles = 0;
    integer r9_sfu_other_cycles = 0;
    integer r9_sfu_spad_request_stall_cycles = 0;
    integer r9_sfu_spad_response_wait_cycles = 0;
    integer r9_sfu_spad_read_accepts = 0;
    integer r9_sfu_spad_write_accepts = 0;
    integer r9_sfu_divider_busy_cycles = 0;
    integer r9_sfu_sqrt_busy_cycles = 0;
    integer r9_sfu_state;

    always @(posedge aclk) begin
        if (representative_load_measure)
            representative_load_cycles = representative_load_cycles + 1;
    end

    // Round 9 SFU profiler. Pass buckets are mutually exclusive FSM states;
    // request/response/divider counters are overlapping stall/operation
    // observations and must not be added to the pass totals.
    always @(posedge aclk) begin
        if (!transformer_top_timing_enable) begin
            r9_sfu_command_active = 1'b0;
        end else begin
            if (!r9_sfu_command_active && dut.compute_cluster_u.tensor_sfu_u.busy) begin
                r9_sfu_command_active = 1'b1;
                r9_sfu_command_index = r9_sfu_command_index + 1;
                r9_sfu_command_opcode = dut.compute_cluster_u.tensor_sfu_u.op_r;
                r9_sfu_command_length = dut.compute_cluster_u.tensor_sfu_u.length_r;
                r9_sfu_command_cycles = 0;
                r9_sfu_pass0_cycles = 0;
                r9_sfu_pass1_cycles = 0;
                r9_sfu_pass2_cycles = 0;
                r9_sfu_math_cycles = 0;
                r9_sfu_other_cycles = 0;
                r9_sfu_spad_request_stall_cycles = 0;
                r9_sfu_spad_response_wait_cycles = 0;
                r9_sfu_spad_read_accepts = 0;
                r9_sfu_spad_write_accepts = 0;
                r9_sfu_divider_busy_cycles = 0;
                r9_sfu_sqrt_busy_cycles = 0;
            end
            if (r9_sfu_command_active && dut.compute_cluster_u.tensor_sfu_u.busy) begin
                r9_sfu_state = dut.compute_cluster_u.tensor_sfu_u.state_r;
                r9_sfu_command_cycles = r9_sfu_command_cycles + 1;
                if (dut.compute_cluster_u.tensor_sfu_u.spad_valid &&
                    !dut.compute_cluster_u.tensor_sfu_u.spad_ready)
                    r9_sfu_spad_request_stall_cycles =
                        r9_sfu_spad_request_stall_cycles + 1;
                if (dut.compute_cluster_u.tensor_sfu_u.spad_valid &&
                    dut.compute_cluster_u.tensor_sfu_u.spad_ready) begin
                    if (dut.compute_cluster_u.tensor_sfu_u.spad_write)
                        r9_sfu_spad_write_accepts = r9_sfu_spad_write_accepts + 1;
                    else
                        r9_sfu_spad_read_accepts = r9_sfu_spad_read_accepts + 1;
                end
                if (!dut.compute_cluster_u.tensor_sfu_u.spad_rsp_valid &&
                    ((r9_sfu_state == 6'd2) || (r9_sfu_state == 6'd4) ||
                     (r9_sfu_state == 6'd6) || (r9_sfu_state == 6'd11) ||
                     (r9_sfu_state == 6'd19) || (r9_sfu_state == 6'd21) ||
                     (r9_sfu_state == 6'd24) || (r9_sfu_state == 6'd26) ||
                     (r9_sfu_state == 6'd33) || (r9_sfu_state == 6'd37) ||
                     (r9_sfu_state == 6'd40)))
                    r9_sfu_spad_response_wait_cycles =
                        r9_sfu_spad_response_wait_cycles + 1;
                if (dut.compute_cluster_u.tensor_sfu_u.div_busy)
                    r9_sfu_divider_busy_cycles = r9_sfu_divider_busy_cycles + 1;
                if (dut.compute_cluster_u.tensor_sfu_u.sqrt_busy)
                    r9_sfu_sqrt_busy_cycles = r9_sfu_sqrt_busy_cycles + 1;

                if (r9_sfu_command_opcode == 8'h38) begin
                    if ((r9_sfu_state == 6'd32) || (r9_sfu_state == 6'd33))
                        r9_sfu_pass0_cycles = r9_sfu_pass0_cycles + 1;
                    else if ((r9_sfu_state == 6'd36) || (r9_sfu_state == 6'd37) ||
                             (r9_sfu_state == 6'd38) ||
                             ((r9_sfu_state == 6'd31) &&
                              !dut.compute_cluster_u.tensor_sfu_u.rms_normalize_phase_r))
                        r9_sfu_pass1_cycles = r9_sfu_pass1_cycles + 1;
                    else if (((r9_sfu_state >= 6'd18) && (r9_sfu_state <= 6'd22)) ||
                             ((r9_sfu_state >= 6'd39) && (r9_sfu_state <= 6'd40)) ||
                             ((r9_sfu_state == 6'd31) &&
                              dut.compute_cluster_u.tensor_sfu_u.rms_normalize_phase_r) ||
                             (r9_sfu_state == 6'd27))
                        r9_sfu_pass2_cycles = r9_sfu_pass2_cycles + 1;
                    else if ((r9_sfu_state == 6'd12) || (r9_sfu_state == 6'd13) ||
                             (r9_sfu_state == 6'd14) || (r9_sfu_state == 6'd15) ||
                             (r9_sfu_state == 6'd16) || (r9_sfu_state == 6'd17) ||
                             (r9_sfu_state == 6'd34) || (r9_sfu_state == 6'd35))
                        r9_sfu_math_cycles = r9_sfu_math_cycles + 1;
                    else
                        r9_sfu_other_cycles = r9_sfu_other_cycles + 1;
                end else if ((r9_sfu_command_opcode == 8'h32) ||
                             (r9_sfu_command_opcode == 8'h39)) begin
                    if ((r9_sfu_state == 6'd1) || (r9_sfu_state == 6'd2))
                        r9_sfu_pass0_cycles = r9_sfu_pass0_cycles + 1;
                    else if ((r9_sfu_state == 6'd3) || (r9_sfu_state == 6'd4))
                        r9_sfu_pass1_cycles = r9_sfu_pass1_cycles + 1;
                    else if ((r9_sfu_state >= 6'd5) && (r9_sfu_state <= 6'd9))
                        r9_sfu_pass2_cycles = r9_sfu_pass2_cycles + 1;
                    else
                        r9_sfu_other_cycles = r9_sfu_other_cycles + 1;
                end else if (r9_sfu_command_opcode == 8'h36) begin
                    if ((r9_sfu_state == 6'd23) || (r9_sfu_state == 6'd24))
                        r9_sfu_pass0_cycles = r9_sfu_pass0_cycles + 1;
                    else if (r9_sfu_state == 6'd27)
                        r9_sfu_pass1_cycles = r9_sfu_pass1_cycles + 1;
                    else
                        r9_sfu_other_cycles = r9_sfu_other_cycles + 1;
                end else begin
                    r9_sfu_other_cycles = r9_sfu_other_cycles + 1;
                end

                if ((r9_sfu_state == 6'd28) || (r9_sfu_state == 6'd29)) begin
                    $display("R9_SFU_COMMAND index=%0d opcode=0x%02h length=%0d cycles=%0d pass0=%0d pass1=%0d pass2=%0d math=%0d other=%0d spad_request_stall=%0d spad_response_wait=%0d spad_read_accepts=%0d spad_write_accepts=%0d divider_busy=%0d sqrt_busy=%0d cycles_closed=%0d",
                             r9_sfu_command_index - 1, r9_sfu_command_opcode,
                             r9_sfu_command_length, r9_sfu_command_cycles,
                             r9_sfu_pass0_cycles, r9_sfu_pass1_cycles,
                             r9_sfu_pass2_cycles, r9_sfu_math_cycles,
                             r9_sfu_other_cycles, r9_sfu_spad_request_stall_cycles,
                             r9_sfu_spad_response_wait_cycles, r9_sfu_spad_read_accepts,
                             r9_sfu_spad_write_accepts,
                             r9_sfu_divider_busy_cycles, r9_sfu_sqrt_busy_cycles,
                             r9_sfu_pass0_cycles + r9_sfu_pass1_cycles +
                             r9_sfu_pass2_cycles + r9_sfu_math_cycles +
                             r9_sfu_other_cycles);
                    r9_sfu_command_active = 1'b0;
                end
            end
        end
    end

    // Exact top-clock completion-boundary sampling for the serialized
    // Transformer prefill/decode CMDQ chain. The 1 ps delay observes the
    // completion-tail nonblocking update in the same clock cycle.
    always @(posedge aclk) begin
        transformer_top_cycle_counter = transformer_top_cycle_counter + 1;
        if (transformer_top_timing_enable && !transformer_top_final_captured) begin
            if (dut.matrix_busy) begin
                if (dut.matrix_perf_mac_active)
                    transformer_top_profile_matrix_mac =
                        transformer_top_profile_matrix_mac + 1;
                else if (dut.matrix_banked_read_valid && !dut.arb_banked_ready)
                    transformer_top_profile_matrix_request_wait =
                        transformer_top_profile_matrix_request_wait + 1;
                else if (dut.matrix_perf_banked_wait)
                    transformer_top_profile_matrix_response_wait =
                        transformer_top_profile_matrix_response_wait + 1;
                else if (dut.matrix_line_valid)
                    transformer_top_profile_matrix_writeback =
                        transformer_top_profile_matrix_writeback + 1;
                else
                    transformer_top_profile_matrix_other =
                        transformer_top_profile_matrix_other + 1;
            end else if (dut.engine_busy[4]) begin
                transformer_top_profile_sfu_busy =
                    transformer_top_profile_sfu_busy + 1;
            end else if (dut.engine_busy[6]) begin
                transformer_top_profile_kv_busy =
                    transformer_top_profile_kv_busy + 1;
            end else if (dut.engine_busy[5]) begin
                transformer_top_profile_conv_busy =
                    transformer_top_profile_conv_busy + 1;
            end else if (dut.engine_busy[2]) begin
                transformer_top_profile_banked_busy =
                    transformer_top_profile_banked_busy + 1;
            end else if (dut.engine_busy[1]) begin
                transformer_top_profile_fp_busy =
                    transformer_top_profile_fp_busy + 1;
            end else if (dut.engine_busy[0]) begin
                transformer_top_profile_scalar_busy =
                    transformer_top_profile_scalar_busy + 1;
            end else begin
                transformer_top_profile_no_engine_busy =
                    transformer_top_profile_no_engine_busy + 1;
            end
            if (dut.dma_busy)
                transformer_top_profile_dma_busy =
                    transformer_top_profile_dma_busy + 1;
        end
        #0.001;
        if (transformer_top_timing_enable) begin
            transformer_top_profile_tail = dut.processor_cplq_tail;
            if (transformer_top_profile_tail > transformer_top_last_completion_tail) begin
                for (transformer_top_profile_index =
                         transformer_top_last_completion_tail;
                     transformer_top_profile_index < transformer_top_profile_tail;
                     transformer_top_profile_index = transformer_top_profile_index + 1) begin
                    transformer_top_profile_cycle = transformer_top_cycle_counter -
                        transformer_top_last_completion_cycle;
                    if (transformer_top_profile_index < 128)
                        transformer_top_completion_cycles[transformer_top_profile_index] =
                            transformer_top_profile_cycle;
                    transformer_top_last_completion_cycle =
                        transformer_top_cycle_counter;
                end
                transformer_top_last_completion_tail =
                    transformer_top_profile_tail;
            end
            if (!transformer_top_prefill_captured &&
                dut.processor_cplq_tail == transformer_top_prefill_target) begin
                transformer_top_prefill_end_cycle = transformer_top_cycle_counter;
                transformer_top_prefill_profile[0] = transformer_top_profile_matrix_mac;
                transformer_top_prefill_profile[1] = transformer_top_profile_matrix_request_wait;
                transformer_top_prefill_profile[2] = transformer_top_profile_matrix_response_wait;
                transformer_top_prefill_profile[3] = transformer_top_profile_matrix_writeback;
                transformer_top_prefill_profile[4] = transformer_top_profile_matrix_other;
                transformer_top_prefill_profile[5] = transformer_top_profile_sfu_busy;
                transformer_top_prefill_profile[6] = transformer_top_profile_kv_busy;
                transformer_top_prefill_profile[7] = transformer_top_profile_conv_busy;
                transformer_top_prefill_profile[8] = transformer_top_profile_banked_busy;
                transformer_top_prefill_profile[9] = transformer_top_profile_fp_busy;
                transformer_top_prefill_profile[10] = transformer_top_profile_scalar_busy;
                transformer_top_prefill_profile[11] = transformer_top_profile_no_engine_busy;
                transformer_top_prefill_profile[12] = transformer_top_profile_dma_busy;
                transformer_top_prefill_captured = 1'b1;
            end
            if (!transformer_top_final_captured &&
                dut.processor_cplq_tail == transformer_top_final_target) begin
                transformer_top_final_end_cycle = transformer_top_cycle_counter;
                transformer_top_final_captured = 1'b1;
            end
        end
    end

    always @(posedge aclk) begin
        if (transformer_traffic_enable) begin
            for (transformer_traffic_lane = 0;
                 transformer_traffic_lane < 7;
                 transformer_traffic_lane = transformer_traffic_lane + 1) begin
                if (dut.compute_engine_req_valid[transformer_traffic_lane] &&
                    dut.compute_engine_ready[transformer_traffic_lane]) begin
                    if (dut.compute_engine_req_write[transformer_traffic_lane])
                        transformer_spad_write_bytes =
                            transformer_spad_write_bytes + 4;
                    else
                        transformer_spad_read_bytes =
                            transformer_spad_read_bytes + 4;
                end
            end
            if (dut.banked_read_valid && dut.arb_banked_ready)
                transformer_spad_read_bytes =
                    transformer_spad_read_bytes + 16;
            if (dut.matrix_line_valid && dut.arb_core_line_ready)
                transformer_spad_write_bytes =
                    transformer_spad_write_bytes + 16;
        end
    end

    always @(posedge aclk) begin
        if (ai_tile_forward_read_monitor && dut.matrix_banked_read_valid &&
            dut.arb_banked_ready && dut.matrix_banked_read_addr >= 32'h0000_b000 &&
            dut.matrix_banked_read_addr < 32'h0000_b100) begin
            if (ai_tile_forward_read_phase == 1)
                ai_tile_forward_baseline_a_reads =
                    ai_tile_forward_baseline_a_reads + 1;
            else if (ai_tile_forward_read_phase == 2)
                ai_tile_forward_enabled_a_reads =
                    ai_tile_forward_enabled_a_reads + 1;
        end
        if (ai_tinynpu_cnn_measure)
            ai_tinynpu_cnn_cycles = ai_tinynpu_cnn_cycles + 1;
        if (ai_tinynpu_cnn_layout_measure)
            ai_tinynpu_cnn_layout_cycles = ai_tinynpu_cnn_layout_cycles + 1;
        if (ai_tinynpu_cnn_measure) begin
            for (ai_tinynpu_cnn_traffic_lane = 0;
                 ai_tinynpu_cnn_traffic_lane < 7;
                 ai_tinynpu_cnn_traffic_lane = ai_tinynpu_cnn_traffic_lane + 1) begin
                if (dut.compute_engine_req_valid[ai_tinynpu_cnn_traffic_lane] &&
                    dut.compute_engine_ready[ai_tinynpu_cnn_traffic_lane]) begin
                    if (dut.compute_engine_req_write[ai_tinynpu_cnn_traffic_lane])
                        ai_tinynpu_cnn_engine_write_words =
                            ai_tinynpu_cnn_engine_write_words + 1;
                    else
                        ai_tinynpu_cnn_engine_read_words =
                            ai_tinynpu_cnn_engine_read_words + 1;
                end
            end
            if (dut.banked_read_valid && dut.arb_banked_ready)
                ai_tinynpu_cnn_banked_read_lines =
                    ai_tinynpu_cnn_banked_read_lines + 1;
            if (dut.matrix_line_valid && dut.arb_core_line_ready)
                ai_tinynpu_cnn_line_write_lines =
                    ai_tinynpu_cnn_line_write_lines + 1;
        end
    end

    // The 0x53 forwarding tag is a software-ordered, non-coherent handoff.
    // During a legal Matrix+SFU parallel queue, watch every compute write
    // client for an attempted write into the producer tile and confirm that
    // SFU traffic targets a distinct SPAD range while Matrix consumes it.
    always @(posedge aclk) begin
        if (aresetn && ai_tile_forward_cross_engine_monitor) begin
            if (dut.matrix_busy && dut.sfu_busy)
                ai_tile_forward_cross_engine_overlap_seen <= 1'b1;
            if (dut.matrix_busy &&
                dut.compute_cluster_u.tensor_matrix_u.tile_forward_consume_active_r &&
                dut.compute_engine_req_valid[4] &&
                dut.compute_engine_ready[4])
                ai_tile_forward_sfu_spad_accesses_during_consume <=
                    ai_tile_forward_sfu_spad_accesses_during_consume + 1;
            if (dut.matrix_line_valid && dut.matrix_line_write &&
                (dut.matrix_line_addr >= 32'h0000_b000) &&
                (dut.matrix_line_addr < 32'h0000_b100))
                ai_tile_forward_source_write_seen <= 1'b1;
            for (ai_tile_forward_engine_scan = 0;
                 ai_tile_forward_engine_scan < 7;
                 ai_tile_forward_engine_scan =
                     ai_tile_forward_engine_scan + 1) begin
                if (dut.compute_engine_req_valid[ai_tile_forward_engine_scan] &&
                    dut.compute_engine_req_write[ai_tile_forward_engine_scan] &&
                    (dut.compute_engine_req_addr[
                        ai_tile_forward_engine_scan*32 +: 32] >= 32'h0000_b000) &&
                    (dut.compute_engine_req_addr[
                        ai_tile_forward_engine_scan*32 +: 32] < 32'h0000_b100))
                    ai_tile_forward_source_write_seen <= 1'b1;
                if (dut.compute_engine_req_valid[ai_tile_forward_engine_scan] &&
                    dut.compute_engine_ready[ai_tile_forward_engine_scan] &&
                    dut.compute_engine_req_write[ai_tile_forward_engine_scan] &&
                    (dut.compute_engine_req_addr[
                        ai_tile_forward_engine_scan*32 +: 32] >= 32'h0000_d400) &&
                    (dut.compute_engine_req_addr[
                        ai_tile_forward_engine_scan*32 +: 32] < 32'h0000_d800))
                    ai_tile_forward_sfu_destination_write_seen <= 1'b1;
            end
        end
    end

    always @(posedge aclk) begin
        if (ai_digits_layout_measure && dut.compute_cluster_u.tensor_matrix_u.busy &&
            dut.compute_cluster_u.tensor_matrix_u.fused_output_r)
            ai_digits_layout_cycles = ai_digits_layout_cycles + 1;
        if (ai_digits_layout_measure && dut.matrix_line_valid &&
            dut.arb_core_line_ready &&
            dut.matrix_line_addr >= AI_DIGITS_HIDDEN_I8_TILE_BASE &&
            dut.matrix_line_addr < AI_DIGITS_HIDDEN_I8_TILE_BASE +
                                   23 * AI_DIGITS_BATCH * 64) begin
            ai_digits_sfu_monitor_batch =
                (dut.matrix_line_addr - AI_DIGITS_HIDDEN_I8_TILE_BASE) /
                (AI_DIGITS_BATCH * 64);
            ai_digits_fused_lines_by_batch[ai_digits_sfu_monitor_batch] =
                ai_digits_fused_lines_by_batch[ai_digits_sfu_monitor_batch] + 1;
            ai_digits_layout_bytes = ai_digits_layout_bytes + 16;
        end
    end

    always @(posedge aclk) begin
        if (ai_digits_measure) begin
            if (dut.processor_cplq_tail == AI_DIGITS_DESC_COUNT)
                ai_digits_measure = 1'b0;
            else
                ai_digits_cycles = ai_digits_cycles + 1;
        end
    end

    // During the dedicated FP benchmark, randomize seeded AXI RVALID latency
    // and write-data back-pressure. This is testbench-only and disabled for
    // the ordinary smoke regression.
    initial begin
        void'($value$plusargs("FP_BENCH_SEED=%d", fp_perf_seed));
        fp_perf_rng = fp_perf_seed;
    end

    always @(negedge aclk) begin
        if (aresetn && (fp_perf_random_wready || fp_perf_random_rvalid_latency)) begin
            fp_perf_rng = fp_perf_rng * 32'd1664525 + 32'd1013904223;
            if (fp_perf_random_wready)
                axi_mem_u.ready_gap_cfg = fp_perf_rng[17:16];
            if (fp_perf_random_rvalid_latency)
                axi_mem_u.read_gap_cfg = fp_perf_rng[20:19];
        end
    end

    // These counters look only at the actual top-level FP core, DMA client,
    // and their shared scratchpad arbiter.  No synthetic ready/response model
    // is inserted on this system-level benchmark path.
    always @(posedge aclk) begin
        if (!aresetn) begin
            fp_perf_tile_job_cycles <= 0;
            fp_perf_active_cycles <= 0;
            fp_perf_compute_cycles <= 0;
            fp_perf_fetch_stall_cycles <= 0;
            fp_perf_response_wait_cycles <= 0;
            fp_perf_write_wait_cycles <= 0;
            fp_perf_dma_wait_cycles <= 0;
            fp_perf_dma_grants <= 0;
        end else if (fp_perf_measure) begin
            if (dut.tile_active)
                fp_perf_tile_job_cycles <= fp_perf_tile_job_cycles + 1;
            if (dut.fp_busy) begin
                fp_perf_active_cycles <= fp_perf_active_cycles + 1;
                if (dut.compute_cluster_u.mixed_precision_dot_core_u.compute_fire)
                    fp_perf_compute_cycles <= fp_perf_compute_cycles + 1;
                if (dut.fp_spad_valid && !dut.arb_core_ready)
                    fp_perf_fetch_stall_cycles <= fp_perf_fetch_stall_cycles + 1;
                if ((dut.compute_cluster_u.mixed_precision_dot_core_u.state_r == 4'd1) &&
                    (dut.compute_cluster_u.mixed_precision_dot_core_u.outstanding_reads_r != 0) &&
                    !dut.core_rsp_valid &&
                    !dut.compute_cluster_u.mixed_precision_dot_core_u.compute_fire)
                    fp_perf_response_wait_cycles <= fp_perf_response_wait_cycles + 1;
                if ((dut.compute_cluster_u.mixed_precision_dot_core_u.state_r == 4'd6) &&
                    dut.fp_spad_valid && !dut.arb_core_ready)
                    fp_perf_write_wait_cycles <= fp_perf_write_wait_cycles + 1;
                if ((dut.dma_spad_valid && !dut.arb_dma_ready) ||
                    (dut.dma_spad_line_valid && !dut.arb_dma_line_ready))
                    fp_perf_dma_wait_cycles <= fp_perf_dma_wait_cycles + 1;
                if ((dut.dma_spad_valid && dut.arb_dma_ready) ||
                    (dut.dma_spad_line_valid && dut.arb_dma_line_ready))
                    fp_perf_dma_grants <= fp_perf_dma_grants + 1;
            end
        end
    end

    // Optional switching-activity capture.  It is disabled in the ordinary
    // smoke regression because a whole-chip VCD is large; pass
    // +VCD_FILE=<path> to enable it, then convert the VCD to SAIF for DC.
    initial begin
        if ($value$plusargs("VCD_FILE=%s", vcd_file)) begin
            $dumpfile(vcd_file);
            $dumpvars(0, tb_ai_accel_smoke);
        end
    end

    always @(posedge aclk) begin
        // Keep an aggregate count across the reset-recovery test near the
        // end of this smoke; initialization is owned by the main initial block.
        if (aresetn && dut.desc_done) begin
            if (dut.legacy_queue_active_r) begin
                if (dut.command_processor_u.state_r !== 4'd1)
                    $fatal(1, "legacy descriptor fetch done outside CP ST_FETCH: state=%0d",
                           dut.command_processor_u.state_r);
            end else if (dut.parallel_queue_mode_r) begin
                if (dut.parallel_compute_dispatcher_u.issue_state_r !== 2'd1)
                    $fatal(1, "parallel descriptor fetch done outside ISSUE_FETCH: state=%0d",
                           dut.parallel_compute_dispatcher_u.issue_state_r);
            end else if (dut.command_processor_u.state_r !== 4'd1) begin
                $fatal(1, "descriptor fetch done outside CP ST_FETCH: state=%0d",
                       dut.command_processor_u.state_r);
            end
            cp_fetch_done_count <= cp_fetch_done_count + 1;
        end
    end

    always @(posedge aclk) begin
        if (aresetn && dut.matrix_line_valid && dut.arb_core_line_ready)
            matrix_line_write_count <= matrix_line_write_count + 1;
        if (aresetn && m_axi_arvalid && m_axi_arready &&
            m_axi_arid != 4'd0)
            last_dma_araddr <= m_axi_araddr;
    end

    always @(posedge aclk) begin
        if (aresetn && dut.parallel_queue_mode_r &&
            dut.engine_busy[3] && dut.engine_busy[4])
            parallel_engine_overlap_seen <= 1'b1;
        if (aresetn && dut.parallel_queue_mode_r && dut.launch_valid &&
            (dut.launch_op >= 8'h32) && (dut.launch_op <= 8'h39) &&
            dut.engine_busy[4])
            parallel_same_engine_overlap_violation <= 1'b1;
    end

    always @(posedge aclk) begin
        if (aresetn && matrix_cnm_case_active) begin
            reg cnm_response_wait_any;
            reg cnm_compute_any;
            integer cnm_response_wait_lanes;
            integer cnm_read_words_this_cycle;
            integer cnm_req_stall_lanes;
            cnm_response_wait_any = 1'b0;
            cnm_compute_any = 1'b0;
            cnm_response_wait_lanes = 0;
            cnm_read_words_this_cycle = 0;
            cnm_req_stall_lanes = 0;
            matrix_cnm_profile_window_cycles <= matrix_cnm_profile_window_cycles + 1;

            if (dut.parallel_queue_mode_r && dut.engine_busy[2] && dut.engine_busy[3])
                matrix_cnm_overlap_seen <= 1'b1;
            if (dut.parallel_queue_mode_r && dut.engine_busy[2] && dut.engine_busy[3])
                matrix_cnm_engine_overlap_cycles <= matrix_cnm_engine_overlap_cycles + 1;
            if (dut.banked_rsp_valid && dut.arb_rsp_client == 3'd3)
                matrix_cnm_matrix_responses <= matrix_cnm_matrix_responses + 1;
            if ((|dut.cnm_rsp_valid) && dut.arb_rsp_client == 3'd5)
                matrix_cnm_cnm_responses <= matrix_cnm_cnm_responses + 1;
            if ((|dut.cnm_rsp_valid) && dut.banked_rsp_valid)
                matrix_cnm_response_alias_seen <= 1'b1;

            if (dut.banked_read_valid && (|dut.cnm_read_valid))
                matrix_cnm_request_collision_cycles <= matrix_cnm_request_collision_cycles + 1;
            if (dut.banked_read_valid && dut.arb_banked_ready) begin
                matrix_cnm_matrix_read_accepts <= matrix_cnm_matrix_read_accepts + 1;
                matrix_cnm_matrix_read_bytes <= matrix_cnm_matrix_read_bytes + 16;
            end
            if (dut.cnm_read_valid[0] && dut.arb_cnm_ready[0]) begin
                cnm_read_words_this_cycle = cnm_read_words_this_cycle + 1;
            end
            if (dut.cnm_read_valid[0] && !dut.arb_cnm_ready[0])
                cnm_req_stall_lanes = cnm_req_stall_lanes + 1;
            if (dut.cnm_read_valid[1] && dut.arb_cnm_ready[1]) begin
                cnm_read_words_this_cycle = cnm_read_words_this_cycle + 1;
            end
            if (dut.cnm_read_valid[1] && !dut.arb_cnm_ready[1])
                cnm_req_stall_lanes = cnm_req_stall_lanes + 1;
            if (dut.cnm_read_valid[2] && dut.arb_cnm_ready[2]) begin
                cnm_read_words_this_cycle = cnm_read_words_this_cycle + 1;
            end
            if (dut.cnm_read_valid[2] && !dut.arb_cnm_ready[2])
                cnm_req_stall_lanes = cnm_req_stall_lanes + 1;
            if (dut.cnm_read_valid[3] && dut.arb_cnm_ready[3]) begin
                cnm_read_words_this_cycle = cnm_read_words_this_cycle + 1;
            end
            if (dut.cnm_read_valid[3] && !dut.arb_cnm_ready[3])
                cnm_req_stall_lanes = cnm_req_stall_lanes + 1;
            if (cnm_read_words_this_cycle != 0) begin
                matrix_cnm_cnm_read_words <=
                    matrix_cnm_cnm_read_words + cnm_read_words_this_cycle;
                matrix_cnm_cnm_read_bytes <=
                    matrix_cnm_cnm_read_bytes + (cnm_read_words_this_cycle * 4);
            end
            if (dut.matrix_line_valid && dut.arb_core_line_ready) begin
                matrix_cnm_matrix_line_writes <= matrix_cnm_matrix_line_writes + 1;
                matrix_cnm_matrix_write_bytes <= matrix_cnm_matrix_write_bytes + 16;
            end
            if (dut.banked_spad_valid && dut.compute_engine_ready[2]) begin
                matrix_cnm_cnm_scalar_writes <= matrix_cnm_cnm_scalar_writes + 1;
                matrix_cnm_cnm_write_bytes <= matrix_cnm_cnm_write_bytes + 4;
            end

            if (dut.matrix_busy) begin
                matrix_cnm_matrix_busy_cycles <= matrix_cnm_matrix_busy_cycles + 1;
                if (dut.matrix_perf_mac_active)
                    matrix_cnm_matrix_mac_cycles <= matrix_cnm_matrix_mac_cycles + 1;
                else if (dut.matrix_line_valid) begin
                    matrix_cnm_matrix_writeback_cycles <= matrix_cnm_matrix_writeback_cycles + 1;
                    if (!dut.arb_core_line_ready)
                        matrix_cnm_matrix_writeback_stall_cycles <= matrix_cnm_matrix_writeback_stall_cycles + 1;
                end else if (dut.banked_read_valid && !dut.arb_banked_ready)
                    matrix_cnm_matrix_req_wait_cycles <= matrix_cnm_matrix_req_wait_cycles + 1;
                else if (dut.matrix_perf_banked_wait)
                    matrix_cnm_matrix_rsp_wait_cycles <= matrix_cnm_matrix_rsp_wait_cycles + 1;
                else
                    matrix_cnm_matrix_other_cycles <= matrix_cnm_matrix_other_cycles + 1;
                if (dut.matrix_perf_banked_wait)
                    matrix_cnm_matrix_rsp_wait_event_cycles <= matrix_cnm_matrix_rsp_wait_event_cycles + 1;
                if (dut.compute_cluster_u.tensor_matrix_u.read_outstanding_count >
                    matrix_cnm_outstanding_highwater)
                    matrix_cnm_outstanding_highwater <=
                        dut.compute_cluster_u.tensor_matrix_u.read_outstanding_count;
            end

            cnm_compute_any =
                dut.compute_cluster_u.banked_core_u.lc0.compute_enable ||
                dut.compute_cluster_u.banked_core_u.lc1.compute_enable ||
                dut.compute_cluster_u.banked_core_u.lc2.compute_enable ||
                dut.compute_cluster_u.banked_core_u.lc3.compute_enable;
            if ((dut.compute_cluster_u.banked_core_u.lc0.state_r == 3'd3 ||
                 dut.compute_cluster_u.banked_core_u.lc0.state_r == 3'd4) &&
                !dut.cnm_rsp_valid[0]) begin
                cnm_response_wait_any = 1'b1;
                cnm_response_wait_lanes = cnm_response_wait_lanes + 1;
            end
            if ((dut.compute_cluster_u.banked_core_u.lc1.state_r == 3'd3 ||
                 dut.compute_cluster_u.banked_core_u.lc1.state_r == 3'd4) &&
                !dut.cnm_rsp_valid[1]) begin
                cnm_response_wait_any = 1'b1;
                cnm_response_wait_lanes = cnm_response_wait_lanes + 1;
            end
            if ((dut.compute_cluster_u.banked_core_u.lc2.state_r == 3'd3 ||
                 dut.compute_cluster_u.banked_core_u.lc2.state_r == 3'd4) &&
                !dut.cnm_rsp_valid[2]) begin
                cnm_response_wait_any = 1'b1;
                cnm_response_wait_lanes = cnm_response_wait_lanes + 1;
            end
            if ((dut.compute_cluster_u.banked_core_u.lc3.state_r == 3'd3 ||
                 dut.compute_cluster_u.banked_core_u.lc3.state_r == 3'd4) &&
                !dut.cnm_rsp_valid[3]) begin
                cnm_response_wait_any = 1'b1;
                cnm_response_wait_lanes = cnm_response_wait_lanes + 1;
            end
            if (cnm_response_wait_lanes != 0)
                matrix_cnm_cnm_rsp_wait_lane_cycles <=
                    matrix_cnm_cnm_rsp_wait_lane_cycles + cnm_response_wait_lanes;
            if (cnm_req_stall_lanes != 0)
                matrix_cnm_cnm_req_wait_lane_cycles <=
                    matrix_cnm_cnm_req_wait_lane_cycles + cnm_req_stall_lanes;
            if (dut.banked_busy) begin
                matrix_cnm_cnm_busy_cycles <= matrix_cnm_cnm_busy_cycles + 1;
                if (cnm_compute_any)
                    matrix_cnm_cnm_compute_cycles <= matrix_cnm_cnm_compute_cycles + 1;
                else if (cnm_req_stall_lanes != 0)
                    matrix_cnm_cnm_req_wait_cycles <= matrix_cnm_cnm_req_wait_cycles + 1;
                else if (cnm_response_wait_any)
                    matrix_cnm_cnm_rsp_wait_cycles <= matrix_cnm_cnm_rsp_wait_cycles + 1;
                else if (dut.banked_spad_valid)
                    matrix_cnm_cnm_writeback_cycles <= matrix_cnm_cnm_writeback_cycles + 1;
                else
                    matrix_cnm_cnm_other_cycles <= matrix_cnm_cnm_other_cycles + 1;
                if (dut.banked_spad_valid && !dut.compute_engine_ready[2])
                    matrix_cnm_cnm_writeback_stall_cycles <= matrix_cnm_cnm_writeback_stall_cycles + 1;
            end
        end
    end

    always @(posedge aclk) begin
        if (aresetn && kv_protection_case_active) begin
            if (dut.compute_engine_req_valid[6] &&
                dut.compute_engine_ready[6] &&
                !dut.compute_engine_req_write[6])
                kv_protection_read_accepts = kv_protection_read_accepts + 1;
            if (dut.compute_engine_req_valid[6] &&
                dut.compute_engine_req_write[6] &&
                dut.compute_engine_protection_error[6]) begin
                kv_protection_write_denied = 1'b1;
                kv_protection_denied_addr = dut.compute_engine_req_addr[6*32 +: 32];
            end
        end
    end

    ai_accel_top #(
        .SPAD_WORDS_PER_BANK(`AI_SPAD_WORDS_PER_BANK)
    ) dut(
        .aclk          (aclk),
        .aresetn       (aresetn),
        .s_axi_awaddr  (s_axi_awaddr),
        .s_axi_awvalid (s_axi_awvalid),
        .s_axi_awready (s_axi_awready),
        .s_axi_wdata   (s_axi_wdata),
        .s_axi_wstrb   (s_axi_wstrb),
        .s_axi_wvalid  (s_axi_wvalid),
        .s_axi_wready  (s_axi_wready),
        .s_axi_bresp   (s_axi_bresp),
        .s_axi_bvalid  (s_axi_bvalid),
        .s_axi_bready  (s_axi_bready),
        .s_axi_araddr  (s_axi_araddr),
        .s_axi_arvalid (s_axi_arvalid),
        .s_axi_arready (s_axi_arready),
        .s_axi_rdata   (s_axi_rdata),
        .s_axi_rresp   (s_axi_rresp),
        .s_axi_rvalid  (s_axi_rvalid),
        .s_axi_rready  (s_axi_rready),
        .irq           (irq),
        .m_axi_arvalid (m_axi_arvalid),
        .m_axi_arid    (m_axi_arid),
        .m_axi_araddr  (m_axi_araddr),
        .m_axi_arlen   (m_axi_arlen),
        .m_axi_arsize  (m_axi_arsize),
        .m_axi_arburst (m_axi_arburst),
        .m_axi_arcache (m_axi_arcache),
        .m_axi_arprot  (m_axi_arprot),
        .m_axi_arqos   (m_axi_arqos),
        .m_axi_arlock  (m_axi_arlock),
        .m_axi_arready (m_axi_arready),
        .m_axi_rid     (m_axi_rid),
        .m_axi_rdata   (m_axi_rdata),
        .m_axi_rresp   (m_axi_rresp),
        .m_axi_rvalid  (m_axi_rvalid),
        .m_axi_rlast   (m_axi_rlast),
        .m_axi_rready  (m_axi_rready),
        .m_axi_awvalid (m_axi_awvalid),
        .m_axi_awid    (m_axi_awid),
        .m_axi_awaddr  (m_axi_awaddr),
        .m_axi_awlen   (m_axi_awlen),
        .m_axi_awsize  (m_axi_awsize),
        .m_axi_awburst (m_axi_awburst),
        .m_axi_awcache (m_axi_awcache),
        .m_axi_awprot  (m_axi_awprot),
        .m_axi_awqos   (m_axi_awqos),
        .m_axi_awlock  (m_axi_awlock),
        .m_axi_awready (m_axi_awready),
        .m_axi_wvalid  (m_axi_wvalid),
        .m_axi_wdata   (m_axi_wdata),
        .m_axi_wstrb   (m_axi_wstrb),
        .m_axi_wlast   (m_axi_wlast),
        .m_axi_wready  (m_axi_wready),
        .m_axi_bid     (m_axi_bid),
        .m_axi_bresp   (m_axi_bresp),
        .m_axi_bvalid  (m_axi_bvalid),
        .m_axi_bready  (m_axi_bready)
    );

    axi_memory_model axi_mem_u(
        .clk     (aclk),
        .resetn  (aresetn),
        .arvalid (m_axi_arvalid),
        .arid    (m_axi_arid),
        .araddr  (m_axi_araddr),
        .arlen   (m_axi_arlen),
        .arsize  (m_axi_arsize),
        .arburst (m_axi_arburst),
        .arready (m_axi_arready),
        .rid     (m_axi_rid),
        .rdata   (m_axi_rdata),
        .rresp   (m_axi_rresp),
        .rvalid  (m_axi_rvalid),
        .rlast   (m_axi_rlast),
        .rready  (m_axi_rready),
        .awvalid (m_axi_awvalid),
        .awid    (m_axi_awid),
        .awaddr  (m_axi_awaddr),
        .awlen   (m_axi_awlen),
        .awsize  (m_axi_awsize),
        .awburst (m_axi_awburst),
        .awready (m_axi_awready),
        .wvalid  (m_axi_wvalid),
        .wdata   (m_axi_wdata),
        .wstrb   (m_axi_wstrb),
        .wlast   (m_axi_wlast),
        .wready  (m_axi_wready),
        .bresp   (m_axi_bresp),
        .bid     (m_axi_bid),
        .bvalid  (m_axi_bvalid),
        .bready  (m_axi_bready)
    );

    ai_accel_sva sva_u(
        .clk            (aclk),
        .resetn         (aresetn),
        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awready  (s_axi_awready),
        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wready   (s_axi_wready),
        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bready   (s_axi_bready),
        .s_axi_araddr   (s_axi_araddr),
        .s_axi_arvalid  (s_axi_arvalid),
        .s_axi_arready  (s_axi_arready),
        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (s_axi_rresp),
        .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_rready   (s_axi_rready),
        .m_axi_araddr   (m_axi_araddr),
        .m_axi_arlen    (m_axi_arlen),
        .m_axi_arsize   (m_axi_arsize),
        .m_axi_arburst  (m_axi_arburst),
        .m_axi_arvalid  (m_axi_arvalid),
        .m_axi_arready  (m_axi_arready),
        .m_axi_rresp    (m_axi_rresp),
        .m_axi_rvalid   (m_axi_rvalid),
        .m_axi_rlast    (m_axi_rlast),
        .m_axi_rready   (m_axi_rready),
        .m_axi_awaddr   (m_axi_awaddr),
        .m_axi_awlen    (m_axi_awlen),
        .m_axi_awvalid  (m_axi_awvalid),
        .m_axi_awready  (m_axi_awready),
        .m_axi_wdata    (m_axi_wdata),
        .m_axi_wstrb    (m_axi_wstrb),
        .m_axi_wlast    (m_axi_wlast),
        .m_axi_wvalid   (m_axi_wvalid),
        .m_axi_wready   (m_axi_wready),
        .m_axi_bresp    (m_axi_bresp),
        .m_axi_bvalid   (m_axi_bvalid),
        .m_axi_bready   (m_axi_bready),
        .dma_read_outstanding_cfg(dut.dma_read_outstanding_mux),
        .allow_m_axi_error (allow_m_axi_error),
        .doorbell_pulse (dut.doorbell_pulse),
        .desc_busy      (dut.spad_desc_busy),
        .desc_base      (dut.cmdq_desc_base),
        .host_valid     (dut.spad_req_valid),
        .host_write     (dut.reg_req_write_raw),
        .host_addr      (dut.reg_req_addr_raw - dut.SPAD_BASE),
        .core_busy      (dut.core_busy),
        // Feed pulse-level core state into protocol assertions.  Sticky
        // software STATUS.done/error may legally remain set while a queued
        // successor command is executing.
        .core_done      (dut.core_done),
        .core_error     (dut.core_error),
        .engine_busy    (dut.engine_busy),
        .engine_done    (dut.engine_done),
        .processor_event_valid(dut.processor_event_valid)
    );

    // Per-engine activity checks.  These hierarchical references terminate
    // at the registered engine ports in compute_cluster_u; no DUT logic is
    // modified for observability.
    ai_compute_activity_sva scalar_activity_sva(
        .clk          (aclk),
        .resetn       (aresetn),
        .wake         (dut.core_start && !dut.banked_op && !dut.tensor_matrix_op &&
                       !dut.tensor_sfu_op && !dut.conv_linebuffer_op && !dut.kv_cache_op),
        .busy         (dut.scalar_busy),
        .done         (dut.compute_cluster_u.core_u.done),
        .error        (dut.compute_cluster_u.core_u.error),
        .spad_valid   (dut.scalar_spad_valid),
        .cycle_count  (dut.compute_cluster_u.core_u.cycle_count),
        .element_count(dut.compute_cluster_u.core_u.element_count)
    );

    ai_compute_activity_sva banked_cnm_activity_sva(
        .clk          (aclk),
        .resetn       (aresetn),
        .wake         (dut.core_start && dut.banked_op),
        .busy         (dut.banked_busy),
        .done         (dut.compute_cluster_u.banked_core_u.done),
        .error        (dut.compute_cluster_u.banked_core_u.error),
        .spad_valid   (dut.banked_spad_valid || (|dut.cnm_read_valid)),
        .cycle_count  (dut.compute_cluster_u.banked_core_u.cycle_count),
        .element_count(dut.compute_cluster_u.banked_core_u.element_count)
    );

    ai_compute_activity_sva matrix_activity_sva(
        .clk          (aclk),
        .resetn       (aresetn),
        .wake         (dut.core_start && dut.tensor_matrix_op),
        .busy         (dut.matrix_busy),
        .done         (dut.compute_cluster_u.tensor_matrix_u.done),
        .error        (dut.compute_cluster_u.tensor_matrix_u.error),
        .spad_valid   (dut.matrix_spad_valid || dut.matrix_banked_read_valid || dut.matrix_line_valid),
        .cycle_count  (dut.compute_cluster_u.tensor_matrix_u.cycle_count),
        .element_count(dut.compute_cluster_u.tensor_matrix_u.element_count)
    );

    ai_compute_activity_sva sfu_activity_sva(
        .clk          (aclk),
        .resetn       (aresetn),
        .wake         (dut.core_start && dut.tensor_sfu_op),
        .busy         (dut.sfu_busy),
        .done         (dut.compute_cluster_u.tensor_sfu_u.done),
        .error        (dut.compute_cluster_u.tensor_sfu_u.error),
        .spad_valid   (dut.sfu_spad_valid),
        .cycle_count  (dut.compute_cluster_u.tensor_sfu_u.cycle_count),
…44695 tokens truncated…y("%0t ERROR: fused tile baseline producer-A reads=%0d expected=16",
                         $time, ai_tile_forward_baseline_a_reads);
                errors = errors + 1;
            end

            // Capture the same producer tile, then consume its exact tag and
            // capture the consumer result into the opposite local bank.
            matrix_line_write_count = 0;
            ai_tile_forward_read_phase = 2;
            // The queue has four entries.  After consuming indices 0 and 1,
            // publishing indices 2 and 3 wraps the tail pointer to index 0.
            axi_write(REG_CMDQ_TAIL, 32'd0);
            clear_done_irq();
            axi_write(REG_DOORBELL, 32'd1);
            wait_cpl_tail(32'd4, "fused tile forwarding enabled");
            ai_tile_forward_read_monitor = 1'b0;
            ai_tile_forward_read_phase = 0;
            if (matrix_line_write_count != 32) begin
                $display("%0t ERROR: fused tile forwarding lines=%0d expected=32",
                         $time, matrix_line_write_count);
                errors = errors + 1;
            end
            for (output_word_f = 0; output_word_f < 64;
                 output_word_f = output_word_f + 1) begin
                expect_read(SPAD_BASE + 32'h0000_b000 + (output_word_f * 4),
                            32'h1010_1010, "fused tile forwarded producer");
                expect_read(SPAD_BASE + 32'h0000_b800 + (output_word_f * 4),
                            32'h7f7f_7f7f, "fused tile forwarded consumer");
            end
            expect_completion(32'h9220, 16'h0532, 4'h1, 4'd0,
                              32'd16, 32'd256, "fused tile capture producer");
            expect_completion(32'h9230, 16'h0533, 4'h1, 4'd0,
                              32'd127, 32'd256, "fused tile forwarding consumer");
            if (ai_tile_forward_enabled_a_reads != 0) begin
                $display("%0t ERROR: fused tile forwarded producer-A reads=%0d expected=0",
                         $time, ai_tile_forward_enabled_a_reads);
                errors = errors + 1;
            end
            if (errors != errors_before_f) begin
                $fatal(1, "fused tile CMDQ forwarding had %0d errors",
                       errors - errors_before_f);
            end
            $display("MATRIX_FUSED_TILE_FORWARD_CMDQ_PASS opcode=0x53 shape=16x16x16 baseline_A_reads=%0d forwarded_A_reads=%0d producer=bit-exact consumer=bit-exact legacy_writeback=enabled",
                     ai_tile_forward_baseline_a_reads,
                     ai_tile_forward_enabled_a_reads);
            axi_write(REG_CMDQ_SIZE, 32'd0);
            axi_write(REG_CPLQ_SIZE, 32'd0);
            clear_done_irq();

            // A legal cross-engine handoff: a parallel SFU command reads and
            // writes unrelated SPAD ranges while the 0x53 consumer reads the
            // still-immutable tagged tile. The v2 spec does not promise
            // coherence if another engine overwrites b000.
            for (init_word_f = 0; init_word_f < 256;
                 init_word_f = init_word_f + 1) begin
                axi_write(SPAD_BASE + 32'h0000_a000 + (init_word_f * 4),
                          32'h0101_0101);
                axi_write(SPAD_BASE + 32'h0000_a800 + (init_word_f * 4),
                          32'h0101_0101);
            end
            for (output_word_f = 0; output_word_f < 64;
                 output_word_f = output_word_f + 1) begin
                axi_write(SPAD_BASE + 32'h0000_b400 + (output_word_f * 4),
                          32'hdead_5340);
            end
            for (cross_engine_word_f = 0; cross_engine_word_f < 256;
                 cross_engine_word_f = cross_engine_word_f + 1) begin
                axi_write(SPAD_BASE + 32'h0000_d000 + (cross_engine_word_f * 4),
                          32'd0);
                axi_write(SPAD_BASE + 32'h0000_d400 + (cross_engine_word_f * 4),
                          32'hdead_d400);
            end

            write_spad_desc_v3(32'h9000, OP_TENSOR_GEMM_FUSED, 16'h0534,
                               32'h0000_a000, 32'h0000_a800, 32'd0,
                               32'h0000_b000, 16'd16, 16'd16, 16'd4,
                               8'd0, 32'h0000_0020, 5'd0, 2'd0,
                               32'd0, 32'd0, 32'd0, 16'd0, 16'd0,
                               16'd0, 16'd0, 16'd0);
            axi_write(SPAD_BASE + 32'h903c, 32'd7);
            axi_write(REG_CMDQ_BASE_LO, 32'h9000);
            axi_write(REG_CMDQ_SIZE, 32'd4);
            axi_write(REG_CMDQ_HEAD, 32'd0);
            axi_write(REG_CMDQ_TAIL, 32'd1);
            axi_write(REG_CPLQ_BASE_LO, 32'h9200);
            axi_write(REG_CPLQ_SIZE, 32'd8);
            axi_write(REG_CPLQ_HEAD, 32'd0);
            axi_write(REG_CPLQ_TAIL, 32'd0);
            axi_write(REG_DOORBELL, 32'd1);
            wait_cpl_tail(32'd1, "immutable tile producer completion");
            if (!dut.compute_cluster_u.tensor_matrix_u.tile_forward_valid_r ||
                (dut.compute_cluster_u.tensor_matrix_u.tile_forward_tag_base_r !=
                 32'h0000_b000)) begin
                $display("%0t ERROR: immutable tile producer did not publish b000 tag",
                         $time);
                errors = errors + 1;
            end
            expect_completion(32'h9200, 16'h0534, 4'h1, 4'd0,
                              32'd16, 32'd256,
                              "immutable tile producer completion record");

            write_spad_desc_v3(32'h9040, OP_TENSOR_GEMM_FUSED, 16'h0535,
                               32'h0000_b000, 32'h0000_a800, 32'd0,
                               32'h0000_b400, 16'd16, 16'd16, 16'd4,
                               8'd0, 32'h0000_0040, 5'd0, 2'd0,
                               32'd0, 32'd0, 32'd0, 16'd0, 16'd0,
                               16'd0, 16'd0, 16'd0);
            axi_write(SPAD_BASE + 32'h907c, 32'd7);
            write_spad_desc_v3(32'h9080, OP_GELU_Q8_8, 16'h0536,
                               32'h0000_d000, 32'd0, 32'd0,
                               32'h0000_d400, 16'd0, 16'd0, 16'd256,
                               8'd0, 32'd1, 5'd0, 2'd0,
                               32'd0, 32'd0, 32'd0, 16'd1, 16'd1,
                               16'd0, 16'd0, 16'd0);
            axi_write(SPAD_BASE + 32'h90bc, 32'd7);
            axi_write(REG_CMDQ_HEAD, 32'd1);
            axi_write(REG_CPLQ_TAIL, 32'd1);
            axi_write(REG_CMDQ_TAIL, 32'd3);
            ai_tile_forward_cross_engine_overlap_seen = 1'b0;
            ai_tile_forward_source_write_seen = 1'b0;
            ai_tile_forward_sfu_destination_write_seen = 1'b0;
            ai_tile_forward_sfu_spad_accesses_during_consume = 0;
            ai_tile_forward_cross_engine_monitor = 1'b1;
            clear_done_irq();
            axi_write(REG_DOORBELL, 32'd1);
            overlap_poll_f = 0;
            while (!dut.compute_cluster_u.tensor_matrix_u.tile_forward_consume_active_r &&
                   overlap_poll_f < 2000) begin
                @(posedge aclk);
                overlap_poll_f = overlap_poll_f + 1;
            end
            if (!dut.compute_cluster_u.tensor_matrix_u.tile_forward_consume_active_r) begin
                $display("%0t ERROR: immutable tile consumer did not enter forwarding state",
                         $time);
                errors = errors + 1;
            end
            wait_cpl_tail(32'd3, "immutable tile consumer and SFU completions");
            ai_tile_forward_cross_engine_monitor = 1'b0;
            if (!ai_tile_forward_cross_engine_overlap_seen ||
                !ai_tile_forward_sfu_destination_write_seen ||
                ai_tile_forward_source_write_seen ||
                (ai_tile_forward_sfu_spad_accesses_during_consume == 0)) begin
                $display("%0t ERROR: immutable tile cross-engine overlap failed busy=%b sfu_write=%b source_write=%b sfu_accesses_during_consume=%0d",
                         $time, ai_tile_forward_cross_engine_overlap_seen,
                         ai_tile_forward_sfu_destination_write_seen,
                         ai_tile_forward_source_write_seen,
                         ai_tile_forward_sfu_spad_accesses_during_consume);
                errors = errors + 1;
            end
            for (output_word_f = 0; output_word_f < 64;
                 output_word_f = output_word_f + 1) begin
                expect_read(SPAD_BASE + 32'h0000_b000 + (output_word_f * 4),
                            32'h1010_1010, "immutable tagged source unchanged");
                expect_read(SPAD_BASE + 32'h0000_b400 + (output_word_f * 4),
                            32'h7f7f_7f7f, "immutable tile consumer output");
            end
            for (cross_engine_word_f = 0; cross_engine_word_f < 256;
                 cross_engine_word_f = cross_engine_word_f + 1)
                expect_read(SPAD_BASE + 32'h0000_d400 + (cross_engine_word_f * 4),
                            32'd0, "concurrent SFU Golden output");
            expect_completion(32'h9210, 16'h0535, 4'h1, 4'd0,
                              32'd127, 32'd256,
                              "immutable tile consumer completion record");
            expect_completion(32'h9220, 16'h0536, 4'h1, 4'd0,
                              32'd0, 32'd256,
                              "parallel SFU completion record");
            if (errors != errors_before_f) begin
                $fatal(1, "immutable tile/Matrix-SFU interleave had %0d errors",
                       errors - errors_before_f);
            end
            ai_v2_cross_engine_handoff_cg_inst.sample(
                ai_tile_forward_cross_engine_overlap_seen,
                ai_tile_forward_sfu_spad_accesses_during_consume,
                ai_tile_forward_source_write_seen,
                1'b1);
            if (ai_v2_cross_engine_handoff_cg_inst.get_coverage() < 100.0)
                $fatal(1, "0x53 legal cross-engine functional coverage incomplete: %0.2f%%",
                       ai_v2_cross_engine_handoff_cg_inst.get_coverage());
            $display("MATRIX_FUSED_TILE_FORWARD_CROSS_ENGINE_IMMUTABLE_PASS opcode=0x53 matrix_sfu_overlap=1 sfu_spad_accesses_during_consume=%0d source_unchanged=1 sfu_output=bit-exact golden=bit-exact functional_cov=%0.2f",
                     ai_tile_forward_sfu_spad_accesses_during_consume,
                     ai_v2_cross_engine_handoff_cg_inst.get_coverage());
            axi_write(REG_CMDQ_SIZE, 32'd0);
            axi_write(REG_CPLQ_SIZE, 32'd0);
            clear_done_irq();
        end

        // Numerically defined SFU primitives used by a Transformer chain.
        // Equal Q8.8 log2 scores produce four exact Q0.15 probabilities.
        axi_write(SPAD_BASE + 32'h4b00, 32'd0);
        axi_write(SPAD_BASE + 32'h4b04, 32'd0);
        axi_write(SPAD_BASE + 32'h4b08, 32'd0);
        axi_write(SPAD_BASE + 32'h4b0c, 32'd0);
        axi_write(REG_OP_MODE, OP_SOFTMAX_Q15);
        axi_write(REG_SRC0_BASE, 32'h4b00);
        axi_write(REG_SRC1_BASE, 32'd0);
        axi_write(REG_DST_BASE, 32'h4c00);
        axi_write(REG_LENGTH, 32'd4);
        axi_write(REG_CTRL, 32'h0000_0003);
        wait_done();
        expect_read(SPAD_BASE + 32'h4c00, 32'd8192, "A3 softmax p0");
        expect_read(SPAD_BASE + 32'h4c0c, 32'd8192, "A3 softmax p3");
        clear_done_irq();

        // The direct path supplies aux0=1, therefore columns 2 and 3 are
        // masked.  The two visible equal scores each receive Q0.15 0.5.
        axi_write(REG_OP_MODE, OP_CAUSAL_SOFTMAX_Q15);
        axi_write(REG_DST_BASE, 32'h4c40);
        axi_write(REG_CTRL, 32'h0000_0003);
        wait_done();
        expect_read(SPAD_BASE + 32'h4c40, 32'd16384, "A5 causal softmax p0");
        expect_read(SPAD_BASE + 32'h4c44, 32'd16384, "A5 causal softmax p1");
        expect_read(SPAD_BASE + 32'h4c48, 32'd0, "A5 causal softmax masked p2");
        expect_read(SPAD_BASE + 32'h4c4c, 32'd0, "A5 causal softmax masked p3");
        clear_done_irq();

        axi_write(SPAD_BASE + 32'h4d00, 32'd7);
        axi_write(SPAD_BASE + 32'h4d04, -32'sd3);
        axi_write(SPAD_BASE + 32'h4d40, 32'd5);
        axi_write(SPAD_BASE + 32'h4d44, 32'd3);
        axi_write(REG_OP_MODE, OP_RESIDUAL_I32);
        axi_write(REG_SRC0_BASE, 32'h4d00);
        axi_write(REG_SRC1_BASE, 32'h4d40);
        axi_write(REG_DST_BASE, 32'h4d80);
        axi_write(REG_LENGTH, 32'd2);
        axi_write(REG_QUANT_ACT, 32'd0);
        axi_write(REG_CTRL, 32'h0000_0003);
        wait_done();
        expect_read(SPAD_BASE + 32'h4d80, 32'd12, "A3 residual positive");
        expect_read(SPAD_BASE + 32'h4d84, 32'd0, "A3 residual cancellation");
        clear_done_irq();

        axi_write(SPAD_BASE + 32'h4e00, 32'd1);
        axi_write(SPAD_BASE + 32'h4e04, 32'd1);
        axi_write(SPAD_BASE + 32'h4e08, 32'd1);
        axi_write(SPAD_BASE + 32'h4e0c, 32'd1);
        axi_write(REG_OP_MODE, OP_RMSNORM_Q15);
        axi_write(REG_SRC0_BASE, 32'h4e00);
        axi_write(REG_SRC1_BASE, 32'd0);
        axi_write(REG_DST_BASE, 32'h4e40);
        axi_write(REG_LENGTH, 32'd4);
        axi_write(REG_CTRL, 32'h0000_0003);
        wait_done();
        expect_read(SPAD_BASE + 32'h4e40, 32'd1, "A3 RMSNorm x0");
        expect_read(SPAD_BASE + 32'h4e4c, 32'd1, "A3 RMSNorm x3");
        clear_done_irq();

        axi_write(SPAD_BASE + 32'h5000, 32'd1);
        axi_write(SPAD_BASE + 32'h5004, 32'd2);
        axi_write(SPAD_BASE + 32'h5008, 32'd3);
        axi_write(SPAD_BASE + 32'h500c, 32'd4);
        axi_write(SPAD_BASE + 32'h5040, 32'd10);
        axi_write(SPAD_BASE + 32'h5044, 32'd10);
        axi_write(SPAD_BASE + 32'h5048, 32'd10);
        axi_write(SPAD_BASE + 32'h504c, 32'd10);
        axi_write(REG_OP_MODE, OP_LAYERNORM_Q15);
        axi_write(REG_SRC0_BASE, 32'h5000);
        axi_write(REG_SRC1_BASE, 32'd0);
        axi_write(REG_BIAS_BASE, 32'h5040);
        axi_write(REG_POST_CTRL, 32'd1);
        axi_write(REG_DST_BASE, 32'h5080);
        axi_write(REG_LENGTH, 32'd4);
        axi_write(REG_CTRL, 32'h0000_0003);
        wait_done();
        expect_read(SPAD_BASE + 32'h5080, 32'd9, "A4 LayerNorm x0");
        expect_read(SPAD_BASE + 32'h508c, 32'd12, "A4 LayerNorm x3");
        clear_done_irq();
        axi_write(REG_POST_CTRL, 32'd0);

        axi_write(SPAD_BASE + 32'h4f00, -32'sd256);
        axi_write(SPAD_BASE + 32'h4f04, 32'd0);
        axi_write(SPAD_BASE + 32'h4f08, 32'd256);
        axi_write(SPAD_BASE + 32'h4f0c, 32'd1024);
        axi_write(REG_OP_MODE, OP_GELU_Q8_8);
        axi_write(REG_SRC0_BASE, 32'h4f00);
        axi_write(REG_DST_BASE, 32'h4f40);
        axi_write(REG_LENGTH, 32'd4);
        axi_write(REG_CTRL, 32'h0000_0003);
        wait_done();
        expect_read(SPAD_BASE + 32'h4f40, -32'sd64, "A3 GELU negative");
        expect_read(SPAD_BASE + 32'h4f48, 32'd192, "A3 GELU positive");
        clear_done_irq();

        axi_write(REG_OP_MODE, OP_SILU_Q8_8);
        axi_write(REG_DST_BASE, 32'h4f80);
        axi_write(REG_CTRL, 32'h0000_0003);
        wait_done();
        expect_read(SPAD_BASE + 32'h4f80, -32'sd85, "A3 SiLU negative");
        expect_read(SPAD_BASE + 32'h4f88, 32'd170, "A3 SiLU positive");
        clear_done_irq();

        axi_write(REG_OP_MODE, OP_REQUANT_I8);
        axi_write(REG_DST_BASE, 32'h4fc0);
        axi_write(REG_QUANT_ACT, 32'd2);
        axi_write(REG_CTRL, 32'h0000_0003);
        wait_done();
        expect_read(SPAD_BASE + 32'h4fc0, -32'sd64, "A3 requant negative");
        expect_read(SPAD_BASE + 32'h4fcc, 32'd127, "A3 requant saturation");
        clear_done_irq();

        // Descriptor v3 drives transpose, batch strides and event-token
        // chaining.  The first command produces event0; the dependent
        // requant command waits for it, clears it and produces event1.
        axi_write(SPAD_BASE + 32'h6000, 32'h0000_0001);
        axi_write(SPAD_BASE + 32'h6004, 32'h0000_0100);
        axi_write(SPAD_BASE + 32'h6008, 32'h0001_0000);
        axi_write(SPAD_BASE + 32'h600c, 32'h0100_0000);
        axi_write(SPAD_BASE + 32'h6010, 32'h0000_0002);
        axi_write(SPAD_BASE + 32'h6014, 32'h0000_0200);
        axi_write(SPAD_BASE + 32'h6018, 32'h0002_0000);
        axi_write(SPAD_BASE + 32'h601c, 32'h0200_0000);
        axi_write(SPAD_BASE + 32'h6100, 32'h0000_0001);
        axi_write(SPAD_BASE + 32'h6104, 32'h0000_0100);
        axi_write(SPAD_BASE + 32'h6108, 32'h0001_0000);
        axi_write(SPAD_BASE + 32'h610c, 32'h0100_0000);
        axi_write(SPAD_BASE + 32'h6110, 32'h0000_0001);
        axi_write(SPAD_BASE + 32'h6114, 32'h0000_0100);
        axi_write(SPAD_BASE + 32'h6118, 32'h0001_0000);
        axi_write(SPAD_BASE + 32'h611c, 32'h0100_0000);
        axi_write(SPAD_BASE + 32'h6300, 32'd100);
        write_spad_desc_v3(32'h6400, OP_BATCH_GEMM, 16'h0300,
                           32'h6000, 32'h6100, 32'd0, 32'h6200,
                           16'd4, 16'd4, 16'd1, 8'h06, 32'd1,
                           5'd0, 2'd0, 32'd16, 32'd16, 32'd64,
                           16'd1, 16'd2, 16'd0, 16'h0001, 16'd0);
        // The unified ABI version is valid for every primitive opcode.
        axi_write(SPAD_BASE + 32'h643c, 32'd7);
        write_spad_desc_v3(32'h6440, OP_REQUANT_I8, 16'h0301,
                           32'h6300, 32'd0, 32'd0, 32'h6304,
                           16'd0, 16'd0, 16'd1, 8'd0, 32'd0,
                           5'd2, 2'd0, 32'd0, 32'd0, 32'd0,
                           16'd1, 16'd1, 16'h0001, 16'h0002, 16'h0001);
        axi_write(REG_CMDQ_CTRL, 32'd0);
        axi_write(REG_CMDQ_BASE_LO, 32'h6400);
        axi_write(REG_CMDQ_SIZE, 32'd3);
        axi_write(REG_CMDQ_HEAD, 32'd0);
        axi_write(REG_CMDQ_TAIL, 32'd2);
        axi_write(REG_CPLQ_BASE_LO, 32'h6500);
        axi_write(REG_CPLQ_SIZE, 32'd4);
        axi_write(REG_CPLQ_HEAD, 32'd0);
        axi_write(REG_CPLQ_TAIL, 32'd0);
        axi_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd2, "A3 v3 command chain");
        expect_read(SPAD_BASE + 32'h6200, 32'd1, "A3 head0 transpose c00");
        expect_read(SPAD_BASE + 32'h623c, 32'd1, "A3 head0 transpose c33");
        expect_read(SPAD_BASE + 32'h6240, 32'd2, "A3 head1 transpose c00");
        expect_read(SPAD_BASE + 32'h627c, 32'd2, "A3 head1 transpose c33");
        expect_read(SPAD_BASE + 32'h6304, 32'd25, "A3 dependency requant");
        expect_completion(32'h6500, 16'h0300, 4'h1, 4'd0, 32'd2, 32'd32,
                          "A3 matrix completion");
        expect_completion(32'h6510, 16'h0301, 4'h1, 4'd0, 32'd25, 32'd1,
                          "A3 dependent completion");
        expect_read(REG_EVENT_STATUS, 32'h0000_0002, "A3 dependency events");
        axi_write(REG_CMDQ_SIZE, 32'd0);
        axi_write(REG_CPLQ_SIZE, 32'd0);
        clear_done_irq();

        // Two independent descriptors target different engines and disjoint
        // SPAD regions. Matrix must stay active while SFU begins; completions
        // still publish in CMDQ order.
        axi_write(SPAD_BASE + 32'h7800, 32'd16);
        axi_write(SPAD_BASE + 32'h7804, -32'sd16);
        axi_write(SPAD_BASE + 32'h7808, 32'd32);
        axi_write(SPAD_BASE + 32'h780c, -32'sd32);
        axi_write(SPAD_BASE + 32'h7860, 32'd16);
        axi_write(SPAD_BASE + 32'h7864, -32'sd16);
        axi_write(SPAD_BASE + 32'h7868, 32'd32);
        axi_write(SPAD_BASE + 32'h786c, -32'sd32);
        write_spad_desc_v3(32'h7900, OP_TENSOR_GEMM, 16'h0600,
                           32'h6000, 32'h6100, 32'd0, 32'h30000,
                           16'd16, 16'd16, 16'd16, 8'd0, 32'd1,
                           5'd0, 2'd0, 32'd0, 32'd0, 32'd0,
                           16'd1, 16'd1, 16'd0, 16'd0, 16'd0);
        write_spad_desc_v3(32'h7940, OP_GELU_Q8_8, 16'h0601,
                           32'h7800, 32'd0, 32'd0, 32'h7840,
                           16'd0, 16'd0, 16'd4, 8'd0, 32'd1,
                           5'd0, 2'd0, 32'd0, 32'd0, 32'd0,
                           16'd1, 16'd1, 16'd0, 16'd0, 16'd0);
        write_spad_desc_v3(32'h7980, OP_GELU_Q8_8, 16'h0602,
                           32'h7860, 32'd0, 32'd0, 32'h78a0,
                           16'd0, 16'd0, 16'd4, 8'd0, 32'd1,
                           5'd0, 2'd0, 32'd0, 32'd0, 32'd0,
                           16'd1, 16'd1, 16'd0, 16'd0, 16'd0);
        axi_write(REG_CMDQ_BASE_LO, 32'h7900);
        axi_write(REG_CMDQ_SIZE, 32'd4);
        axi_write(REG_CMDQ_HEAD, 32'd0);
        axi_write(REG_CMDQ_TAIL, 32'd3);
        axi_write(REG_CPLQ_BASE_LO, 32'h7a00);
        axi_write(REG_CPLQ_SIZE, 32'd4);
        axi_write(REG_CPLQ_HEAD, 32'd0);
        axi_write(REG_CPLQ_TAIL, 32'd0);
        parallel_engine_overlap_seen = 1'b0;
        parallel_same_engine_overlap_violation = 1'b0;
        axi_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd3, "parallel matrix + SFU dispatch");
        if (!parallel_engine_overlap_seen) begin
            $display("%0t ERROR: matrix and SFU did not overlap", $time);
            errors = errors + 1;
        end else begin
            $display("%0t PASS: matrix and SFU compute overlapped", $time);
        end
        expect_read(SPAD_BASE + 32'h7a00, 32'h0000_0600,
                    "parallel completion FIFO head task");
        expect_read(SPAD_BASE + 32'h7a04, 32'h0000_0001,
                    "parallel completion FIFO head status");
        expect_read(SPAD_BASE + 32'h7a10, 32'h0000_0601,
                    "parallel completion FIFO next task");
        expect_read(SPAD_BASE + 32'h7a14, 32'h0000_0001,
                    "parallel completion FIFO next status");
        expect_read(SPAD_BASE + 32'h7a1c, 32'd4,
                    "parallel SFU completion element count");
        expect_read(SPAD_BASE + 32'h7a20, 32'h0000_0602,
                    "parallel same-engine queued task");
        expect_read(SPAD_BASE + 32'h7a24, 32'h0000_0001,
                    "parallel same-engine queued status");
        expect_read(SPAD_BASE + 32'h7840, 32'd8,
                    "parallel SFU response-owner output0");
        expect_read(SPAD_BASE + 32'h7844, -32'sd8,
                    "parallel SFU response-owner output1");
        expect_read(SPAD_BASE + 32'h7848, 32'd17,
                    "parallel SFU response-owner output2");
        expect_read(SPAD_BASE + 32'h784c, -32'sd15,
                    "parallel SFU response-owner output3");
        expect_read(SPAD_BASE + 32'h78a0, 32'd8,
                    "parallel second SFU output0");
        expect_read(SPAD_BASE + 32'h78a4, -32'sd8,
                    "parallel second SFU output1");
        expect_read(SPAD_BASE + 32'h78a8, 32'd17,
                    "parallel second SFU output2");
        expect_read(SPAD_BASE + 32'h78ac, -32'sd15,
                    "parallel second SFU output3");
        if (parallel_same_engine_overlap_violation) begin
            $display("%0t ERROR: dispatcher launched two SFU tasks concurrently", $time);
            errors = errors + 1;
        end else begin
            $display("%0t PASS: same-engine descriptor waited for SFU availability", $time);
        end
        axi_write(REG_CMDQ_SIZE, 32'd0);
        axi_write(REG_CPLQ_SIZE, 32'd0);
        clear_done_irq();

        // Run a long CNM GEMV together with a real Matrix GEMM through the
        // product dispatcher, shared arbiter, and four-bank scratchpad. The
        // operands and output regions are disjoint so this checks response
        // ownership without introducing a software SPAD hazard.
        begin : parallel_matrix_cnm_owner
            integer lane;
            integer row;
            integer matrix_word;
            integer matrix_golden_failures;
            integer cnm_golden_failures;
            integer matrix_phase_sum;
            integer cnm_phase_sum;
            // Matrix 16x16x(16 K words) requires 4 row groups x 16 K
            // words x 16 bytes for each operand.  Uniform INT8 ones make
            // every INT32 output independently predictable as 64.
            for (matrix_word=0; matrix_word<256; matrix_word=matrix_word+1) begin
                axi_write(SPAD_BASE + 32'h13000 + (matrix_word * 4),
                          32'h0101_0101);
                axi_write(SPAD_BASE + 32'h13400 + (matrix_word * 4),
                          32'h0101_0101);
            end
            for (lane=0; lane<4; lane=lane+1)
                axi_write(SPAD_BASE + 32'h10000 + (lane * 4), 32'h0202_0202);
            for (row=0; row<16; row=row+1)
                for (lane=0; lane<4; lane=lane+1)
                    axi_write(SPAD_BASE + 32'h11000 + (row * 16) + (lane * 4),
                              32'h0303_0303);

            write_spad_desc_v3(32'h7d00, OP_BANKED_GEMV, 16'h0620,
                               32'h10000, 32'h11000, 32'd0, 32'h12000,
                               16'd16, 16'd1, 16'd1, 8'd0, 32'd0,
                               5'd0, 2'd0, 32'd0, 32'd0, 32'd0,
                               16'd1, 16'd1, 16'd0, 16'd0, 16'd0);
            write_spad_desc_v3(32'h7d40, OP_TENSOR_GEMM, 16'h0621,
                               32'h13000, 32'h13400, 32'd0, 32'h13800,
                               16'd16, 16'd16, 16'd16, 8'd0, 32'd1,
                               5'd0, 2'd0, 32'd0, 32'd0, 32'd0,
                               16'd1, 16'd1, 16'd0, 16'd0, 16'd0);

            axi_write(REG_CMDQ_BASE_LO, 32'h7d00);
            axi_write(REG_CMDQ_SIZE, 32'd4);
            axi_write(REG_CMDQ_HEAD, 32'd0);
            axi_write(REG_CMDQ_TAIL, 32'd2);
            axi_write(REG_CPLQ_BASE_LO, 32'h7d80);
            axi_write(REG_CPLQ_SIZE, 32'd4);
            axi_write(REG_CPLQ_HEAD, 32'd0);
            axi_write(REG_CPLQ_TAIL, 32'd0);
            matrix_line_write_count = 0;
            matrix_cnm_case_active = 1'b1;
            matrix_cnm_overlap_seen = 1'b0;
            matrix_cnm_response_alias_seen = 1'b0;
            matrix_cnm_matrix_responses = 0;
            matrix_cnm_cnm_responses = 0;
            matrix_cnm_profile_window_cycles = 0;
            matrix_cnm_matrix_busy_cycles = 0;
            matrix_cnm_engine_overlap_cycles = 0;
            matrix_cnm_matrix_mac_cycles = 0;
            matrix_cnm_matrix_req_wait_cycles = 0;
            matrix_cnm_matrix_rsp_wait_cycles = 0;
            matrix_cnm_matrix_writeback_cycles = 0;
            matrix_cnm_matrix_other_cycles = 0;
            matrix_cnm_matrix_rsp_wait_event_cycles = 0;
            matrix_cnm_matrix_writeback_stall_cycles = 0;
            matrix_cnm_cnm_busy_cycles = 0;
            matrix_cnm_cnm_compute_cycles = 0;
            matrix_cnm_cnm_req_wait_cycles = 0;
            matrix_cnm_cnm_req_wait_lane_cycles = 0;
            matrix_cnm_cnm_rsp_wait_cycles = 0;
            matrix_cnm_cnm_writeback_cycles = 0;
            matrix_cnm_cnm_other_cycles = 0;
            matrix_cnm_cnm_rsp_wait_lane_cycles = 0;
            matrix_cnm_cnm_writeback_stall_cycles = 0;
            matrix_cnm_request_collision_cycles = 0;
            matrix_cnm_matrix_read_accepts = 0;
            matrix_cnm_cnm_read_words = 0;
            matrix_cnm_matrix_line_writes = 0;
            matrix_cnm_cnm_scalar_writes = 0;
            matrix_cnm_matrix_read_bytes = 0;
            matrix_cnm_cnm_read_bytes = 0;
            matrix_cnm_matrix_write_bytes = 0;
            matrix_cnm_cnm_write_bytes = 0;
            matrix_cnm_outstanding_highwater = 0;
            matrix_line_write_count = 0;
            axi_write(REG_DOORBELL, 32'd1);
            wait_cpl_tail(32'd2, "parallel CNM + Matrix ordered completion");
            @(negedge aclk);
            matrix_cnm_case_active = 1'b0;

            matrix_phase_sum = matrix_cnm_matrix_mac_cycles +
                               matrix_cnm_matrix_req_wait_cycles +
                               matrix_cnm_matrix_rsp_wait_cycles +
                               matrix_cnm_matrix_writeback_cycles +
                               matrix_cnm_matrix_other_cycles;
            cnm_phase_sum = matrix_cnm_cnm_compute_cycles +
                            matrix_cnm_cnm_req_wait_cycles +
                            matrix_cnm_cnm_rsp_wait_cycles +
                            matrix_cnm_cnm_writeback_cycles +
                            matrix_cnm_cnm_other_cycles;
            if ((matrix_cnm_profile_window_cycles == 0) ||
                (matrix_phase_sum != matrix_cnm_matrix_busy_cycles) ||
                (cnm_phase_sum != matrix_cnm_cnm_busy_cycles)) begin
                $fatal(1, "Matrix/CNM profile cycles did not close wall=%0d matrix=%0d/%0d cnm=%0d/%0d",
                       matrix_cnm_profile_window_cycles,
                       matrix_phase_sum, matrix_cnm_matrix_busy_cycles,
                       cnm_phase_sum, matrix_cnm_cnm_busy_cycles);
            end

            if (!matrix_cnm_overlap_seen || (matrix_cnm_engine_overlap_cycles == 0) ||
                (matrix_cnm_request_collision_cycles == 0) ||
                matrix_cnm_matrix_responses < 2 ||
                matrix_cnm_cnm_responses == 0 || matrix_cnm_response_alias_seen) begin
                $display("%0t ERROR: Matrix/CNM owner coverage overlap=%b overlap_cycles=%0d collisions=%0d matrix_rsp=%0d cnm_rsp=%0d alias=%b",
                         $time, matrix_cnm_overlap_seen, matrix_cnm_engine_overlap_cycles,
                         matrix_cnm_request_collision_cycles,
                         matrix_cnm_matrix_responses,
                         matrix_cnm_cnm_responses, matrix_cnm_response_alias_seen);
                errors = errors + 1;
            end else begin
                $display("%0t PASS: Matrix/CNM concurrent response ownership matrix_rsp=%0d cnm_rsp=%0d",
                         $time, matrix_cnm_matrix_responses, matrix_cnm_cnm_responses);
            end
            $display("MATRIX_CNM_PERF_PROFILE_PASS ai_seed=%0d window_cycles=%0d engine_overlap_cycles=%0d matrix_busy=%0d matrix_mac=%0d matrix_req_wait=%0d matrix_rsp_wait=%0d matrix_writeback=%0d matrix_other=%0d matrix_rsp_wait_event_cycles=%0d matrix_writeback_stall_cycles=%0d cnm_busy=%0d cnm_compute=%0d cnm_req_wait=%0d cnm_req_wait_lane_cycles=%0d cnm_rsp_wait=%0d cnm_writeback=%0d cnm_other=%0d cnm_rsp_wait_lane_cycles=%0d cnm_writeback_stall_cycles=%0d request_collision_cycles=%0d matrix_read_accepts=%0d cnm_read_words=%0d matrix_line_writes=%0d cnm_scalar_writes=%0d matrix_read_bytes=%0d cnm_read_bytes=%0d matrix_write_bytes=%0d cnm_write_bytes=%0d outstanding_highwater=%0d matrix_response_cycles=%0d cnm_response_cycles=%0d cycles_closed=1 golden=bit-exact response_alias_seen=%0d",
                     profile_ai_seed, matrix_cnm_profile_window_cycles,
                     matrix_cnm_engine_overlap_cycles,
                     matrix_cnm_matrix_busy_cycles, matrix_cnm_matrix_mac_cycles,
                     matrix_cnm_matrix_req_wait_cycles, matrix_cnm_matrix_rsp_wait_cycles,
                     matrix_cnm_matrix_writeback_cycles, matrix_cnm_matrix_other_cycles,
                     matrix_cnm_matrix_rsp_wait_event_cycles,
                     matrix_cnm_matrix_writeback_stall_cycles,
                     matrix_cnm_cnm_busy_cycles, matrix_cnm_cnm_compute_cycles,
                     matrix_cnm_cnm_req_wait_cycles,
                     matrix_cnm_cnm_req_wait_lane_cycles,
                     matrix_cnm_cnm_rsp_wait_cycles,
                     matrix_cnm_cnm_writeback_cycles, matrix_cnm_cnm_other_cycles,
                     matrix_cnm_cnm_rsp_wait_lane_cycles,
                     matrix_cnm_cnm_writeback_stall_cycles,
                     matrix_cnm_request_collision_cycles,
                     matrix_cnm_matrix_read_accepts, matrix_cnm_cnm_read_words,
                     matrix_cnm_matrix_line_writes, matrix_cnm_cnm_scalar_writes,
                     matrix_cnm_matrix_read_bytes, matrix_cnm_cnm_read_bytes,
                     matrix_cnm_matrix_write_bytes, matrix_cnm_cnm_write_bytes,
                     matrix_cnm_outstanding_highwater,
                     matrix_cnm_matrix_responses, matrix_cnm_cnm_responses,
                     matrix_cnm_response_alias_seen);
            expect_completion(32'h7d80, 16'h0620, 4'h1, 4'h0, 32'd96, 32'd16,
                              "parallel CNM GEMV completion");
            expect_completion(32'h7d90, 16'h0621, 4'h1, 4'h0, 32'd64, 32'd256,
                              "parallel Matrix GEMM completion");
            cnm_golden_failures = 0;
            for (row=0; row<16; row=row+1) begin
                axi_read(SPAD_BASE + 32'h12000 + (row * 4), rd);
                if (rd !== 32'd96)
                    cnm_golden_failures = cnm_golden_failures + 1;
            end
            if (cnm_golden_failures != 0) begin
                $display("%0t ERROR: parallel CNM GEMV Golden mismatches=%0d/16",
                         $time, cnm_golden_failures);
                errors = errors + 1;
            end else begin
                $display("%0t PASS: parallel CNM GEMV all 16 outputs match INT32 Golden",
                         $time);
            end
            matrix_golden_failures = 0;
            for (row=0; row<16; row=row+1)
                for (lane=0; lane<16; lane=lane+1) begin
                    axi_read(SPAD_BASE + 32'h13800 + (row * 64) + (lane * 4), rd);
                    if (rd !== 32'd64)
                        matrix_golden_failures = matrix_golden_failures + 1;
                end
            if (matrix_golden_failures != 0) begin
                $display("%0t ERROR: parallel Matrix GEMM Golden mismatches=%0d/256",
                         $time, matrix_golden_failures);
                errors = errors + 1;
            end else begin
                $display("%0t PASS: parallel Matrix GEMM all 256 outputs match INT32 Golden",
                         $time);
            end
            if (matrix_line_write_count != 64) begin
                $display("%0t ERROR: parallel Matrix GEMM line writes=%0d expected=64",
                         $time, matrix_line_write_count);
                errors = errors + 1;
            end
            axi_write(REG_CMDQ_SIZE, 32'd0);
            axi_write(REG_CPLQ_SIZE, 32'd0);
            clear_done_irq();
        end

        // Abort two concurrently active engines. Both accepted tasks must
        // receive ERR_ABORT, drain their local SPAD traffic, and retire in
        // the original CMDQ order before the dispatcher goes idle.
        begin : parallel_compute_abort
            integer poll;
            reg overlap_found;
            axi_write(SPAD_BASE + 32'h8000, 32'd7);
            axi_write(SPAD_BASE + 32'h8004, -32'sd7);
            write_spad_desc_v3(32'h7b00, OP_TENSOR_GEMM, 16'h0610,
                               32'h6000, 32'h6100, 32'd0, 32'h30000,
                               16'd16, 16'd16, 16'd16, 8'd0, 32'd1,
                               5'd0, 2'd0, 32'd0, 32'd0, 32'd0,
                               16'd1, 16'd1, 16'd0, 16'd0, 16'd0);
            write_spad_desc_v3(32'h7b40, OP_GELU_Q8_8, 16'h0611,
                               32'h8000, 32'd0, 32'd0, 32'ha000,
                               16'd0, 16'd0, 16'd1024, 8'd0, 32'd1,
                               5'd0, 2'd0, 32'd0, 32'd0, 32'd0,
                               16'd1, 16'd1, 16'd0, 16'd0, 16'd0);
            axi_write(REG_CMDQ_BASE_LO, 32'h7b00);
            axi_write(REG_CMDQ_SIZE, 32'd4);
            axi_write(REG_CMDQ_HEAD, 32'd0);
            axi_write(REG_CMDQ_TAIL, 32'd2);
            axi_write(REG_CPLQ_BASE_LO, 32'h7c00);
            axi_write(REG_CPLQ_SIZE, 32'd4);
            axi_write(REG_CPLQ_HEAD, 32'd0);
            axi_write(REG_CPLQ_TAIL, 32'd0);
            parallel_engine_overlap_seen = 1'b0;
            axi_write(REG_DOORBELL, 32'd1);
            overlap_found = 1'b0;
            for (poll = 0; poll < 2000 && !overlap_found; poll = poll + 1) begin
                @(posedge aclk);
                if (dut.engine_busy[3] && dut.engine_busy[4])
                    overlap_found = 1'b1;
            end
            if (!overlap_found) begin
                $display("%0t ERROR: parallel abort did not observe both engines busy", $time);
                errors = errors + 1;
            end else begin
                axi_write(REG_ABORT, 32'd1);
                wait_cpl_tail(32'd2, "parallel abort ordered drain");
                expect_read(SPAD_BASE + 32'h7c00, 32'h0000_0610,
                            "parallel abort first task id");
                expect_read(SPAD_BASE + 32'h7c04, 32'h0000_0032,
                            "parallel abort first ERR_ABORT");
                expect_read(SPAD_BASE + 32'h7c10, 32'h0000_0611,
                            "parallel abort second task id");
                expect_read(SPAD_BASE + 32'h7c14, 32'h0000_0032,
                            "parallel abort second ERR_ABORT");
                if (dut.engine_busy != 7'd0 || dut.parallel_compute_dispatcher_u.busy) begin
                    $display("%0t ERROR: parallel abort returned before all engines drained", $time);
                    errors = errors + 1;
                end else begin
                    $display("%0t PASS: parallel abort drained all engines in CMDQ order", $time);
                end
            end
        end
        axi_write(REG_CMDQ_SIZE, 32'd0);
        axi_write(REG_CPLQ_SIZE, 32'd0);
        clear_done_irq();

        // Exercise every unordered pair of the seven production compute
        // engines.  SPAD grants are stalled during pair observation so the
        // test measures dispatcher overlap, then abort checks ordered drain.
        for (pair_setup_i = 0; pair_setup_i < 256; pair_setup_i = pair_setup_i + 1)
            axi_write(SPAD_BASE + 32'h0001_0000 + (pair_setup_i * 4), 32'd0);
        for (pair_setup_i = 0; pair_setup_i < 16; pair_setup_i = pair_setup_i + 1)
            axi_write(SPAD_BASE + 32'h0001_1000 + (pair_setup_i * 4), 32'd0);
        parallel_engine_pair_seen = 21'd0;
        pair_index = 0;
        for (pair_engine_a = 0; pair_engine_a < 7; pair_engine_a = pair_engine_a + 1) begin
            for (pair_engine_b = pair_engine_a + 1;
                 pair_engine_b < 7; pair_engine_b = pair_engine_b + 1) begin
                run_parallel_engine_pair(pair_engine_a, pair_engine_b, pair_index);
                pair_index = pair_index + 1;
            end
        end
        if ((pair_index != 21) || (parallel_engine_pair_seen !== 21'h1fffff)) begin
            $display("%0t ERROR: parallel engine-pair coverage %0d/21 mask=%h",
                     $time, $countones(parallel_engine_pair_seen), parallel_engine_pair_seen);
            errors = errors + 1;
        end else begin
            $display("%0t PASS: parallel engine-pair overlap coverage 21/21 mask=%h",
                     $time, parallel_engine_pair_seen);
        end

        // A4 macro-fusion: one v4 QKV parent expands three v3 matrix
        // primitives, executes them in order and publishes one aggregated
        // completion.  Intermediate child completions must remain invisible.
        write_spad_desc_v4_macro(32'h6700, OP_QKV_PROJ, 16'h0400,
                                 32'h6800, 16'd3, 1'b0,
                                 16'h0002, 16'h0004, 16'h0002);
        write_spad_desc_v4_macro(32'h6740, OP_MHA, 16'h0401,
                                 32'h6800, 16'd3, 1'b0,
                                 16'h0004, 16'h0008, 16'h0004);
        write_spad_desc_v4_macro(32'h6780, OP_FFN, 16'h0402,
                                 32'h6800, 16'd3, 1'b0,
                                 16'h0008, 16'h0010, 16'h0008);
        write_spad_desc_v3(32'h6800, OP_TENSOR_GEMM, 16'h0410,
                           32'h6000, 32'h6100, 32'd0, 32'h6a00,
                           16'd4, 16'd4, 16'd1, 8'd0, 32'd1,
                           5'd0, 2'd0, 32'd0, 32'd0, 32'd0,
                           16'd1, 16'd1, 16'd0, 16'd0, 16'd0);
        write_spad_desc_v3(32'h6840, OP_TENSOR_GEMM, 16'h0411,
                           32'h6000, 32'h6100, 32'd0, 32'h6a40,
                           16'd4, 16'd4, 16'd1, 8'd0, 32'd1,
                           5'd0, 2'd0, 32'd0, 32'd0, 32'd0,
                           16'd1, 16'd1, 16'd0, 16'd0, 16'd0);
        write_spad_desc_v3(32'h6880, OP_TENSOR_GEMM, 16'h0412,
                           32'h6000, 32'h6100, 32'd0, 32'h6a80,
                           16'd4, 16'd4, 16'd1, 8'd0, 32'd1,
                           5'd0, 2'd0, 32'd0, 32'd0, 32'd0,
                           16'd1, 16'd1, 16'd0, 16'd0, 16'd0);
        axi_write(REG_CMDQ_CTRL, 32'd0);
        axi_write(REG_CMDQ_BASE_LO, 32'h6700);
        axi_write(REG_CMDQ_SIZE, 32'd4);
        axi_write(REG_CMDQ_HEAD, 32'd0);
        axi_write(REG_CMDQ_TAIL, 32'd3);
        axi_write(REG_CPLQ_BASE_LO, 32'h6900);
        axi_write(REG_CPLQ_SIZE, 32'd4);
        axi_write(REG_CPLQ_HEAD, 32'd0);
        axi_write(REG_CPLQ_TAIL, 32'd0);
        axi_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd3, "A4 fused macro completions");
        expect_read(SPAD_BASE + 32'h6a00, 32'd1, "A4 Q child output");
        expect_read(SPAD_BASE + 32'h6a40, 32'd1, "A4 K child output");
        expect_read(SPAD_BASE + 32'h6a80, 32'd1, "A4 V child output");
        expect_completion(32'h6900, 16'h0400, 4'h1, 4'd0, 32'd1, 32'd48,
                          "A4 QKV aggregated completion");
        expect_completion(32'h6910, 16'h0401, 4'h1, 4'd0, 32'd1, 32'd48,
                          "A4 MHA aggregated completion");
        expect_completion(32'h6920, 16'h0402, 4'h1, 4'd0, 32'd1, 32'd48,
                          "A4 FFN aggregated completion");
        expect_read(REG_EVENT_STATUS, 32'h0000_0010, "A4 macro parent event");
        axi_write(REG_CMDQ_SIZE, 32'd0);
        axi_write(REG_CPLQ_SIZE, 32'd0);
        clear_done_irq();

        // A malformed child fails the macro under the parent task ID, does
        // not fetch/launch later children and never publishes the parent
        // success event.
        write_spad_desc_v4_macro(32'h6b00, OP_QKV_PROJ, 16'h04ff,
                                 32'h6b40, 16'd3, 1'b0,
                                 16'h0010, 16'h0020, 16'h0010);
        write_spad_desc_v3(32'h6b40, 8'h7f, 16'h04f0,
                           32'h6000, 32'h6100, 32'd0, 32'h6d00,
                           16'd4, 16'd4, 16'd1, 8'd0, 32'd1,
                           5'd0, 2'd0, 32'd0, 32'd0, 32'd0,
                           16'd1, 16'd1, 16'd0, 16'd0, 16'd0);
        axi_write(REG_CMDQ_BASE_LO, 32'h6b00);
        axi_write(REG_CMDQ_SIZE, 32'd2);
        axi_write(REG_CMDQ_HEAD, 32'd0);
        axi_write(REG_CMDQ_TAIL, 32'd1);
        axi_write(REG_CPLQ_BASE_LO, 32'h6c00);
        axi_write(REG_CPLQ_SIZE, 32'd2);
        axi_write(REG_CPLQ_HEAD, 32'd0);
        axi_write(REG_CPLQ_TAIL, 32'd0);
        axi_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd1, "A4 macro fail-stop completion");
        expect_completion(32'h6c00, 16'h04ff, 4'h2, 4'd7, 32'd0, 32'd0,
                          "A4 macro child error aggregation");
        expect_read(REG_EVENT_STATUS, 32'd0, "A4 failed macro no event");
        axi_write(REG_CMDQ_SIZE, 32'd0);
        axi_write(REG_CPLQ_SIZE, 32'd0);
        clear_done_irq();

        // G2 BF16 dot product: packed BF16 inputs share one 32-bit SPAD port,
        // then the FP32 result and completion traverse the existing command
        // and completion lifecycle.  The second descriptor has one unsupported
        // flag set and must fail validation without touching its output word.
        axi_write(SPAD_BASE + 32'h7f00, 32'h40003f80); // A = {2.0, 1.0}
        axi_write(SPAD_BASE + 32'h7f04, 32'h40804040); // B = {4.0, 3.0}
        axi_write(SPAD_BASE + 32'h7f08, 32'hdead_c0de);
        axi_write(SPAD_BASE + 32'h7f0c, 32'hbad0_f00d);
        write_spad_desc_v3(32'h7e00, 8'h50, 16'h0500,
                           32'h7f00, 32'h7f04, 32'd0, 32'h7f08,
                           16'd1, 16'd1, 16'd2, 8'd0, 32'd0,
                           5'd0, 2'd0, 32'd0, 32'd0, 32'd0,
                           16'd0, 16'd0, 16'd0, 16'd0, 16'd0);
        axi_write(SPAD_BASE + 32'h7e3c, 32'd7);
        write_spad_desc_v3(32'h7e40, 8'h50, 16'h0501,
                           32'h7f00, 32'h7f04, 32'd0, 32'h7f0c,
                           16'd1, 16'd1, 16'd1, 8'h01, 32'd0,
                           5'd0, 2'd0, 32'd0, 32'd0, 32'd0,
                           16'd0, 16'd0, 16'd0, 16'd0, 16'd0);
        axi_write(SPAD_BASE + 32'h7e7c, 32'd7);
        axi_write(REG_CMDQ_CTRL, 32'd0);
        axi_write(REG_CMDQ_BASE_LO, 32'h7e00);
        axi_write(REG_CMDQ_SIZE, 32'd3);
        axi_write(REG_CMDQ_HEAD, 32'd0);
        axi_write(REG_CMDQ_TAIL, 32'd2);
        axi_write(REG_CPLQ_BASE_LO, 32'h7e80);
        axi_write(REG_CPLQ_SIZE, 32'd4);
        axi_write(REG_CPLQ_HEAD, 32'd0);
        axi_write(REG_CPLQ_TAIL, 32'd0);
        axi_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd2, "G2 BF16 dot plus invalid descriptor");
        expect_read(SPAD_BASE + 32'h7f08, 32'h4130_0000,
                    "G2 BF16 dot FP32 result");
        expect_read(SPAD_BASE + 32'h7f0c, 32'hbad0_f00d,
                    "G2 invalid BF16 descriptor no write");
        expect_completion(32'h7e80, 16'h0500, 4'h1, 4'd0,
                          32'h4130_0000, 32'd2,
                          "G2 BF16 dot completion");
        expect_completion(32'h7e90, 16'h0501, 4'h2, 4'd7,
                          32'd0, 32'd0,
                          "G2 invalid BF16 descriptor completion");
        expect_read(REG_CMDQ_HEAD, 32'd2, "G2 BF16 command head");
        axi_write(REG_CMDQ_SIZE, 32'd0);
        axi_write(REG_CPLQ_SIZE, 32'd0);
        clear_done_irq();

        // A10 FP16 dot uses the same queued descriptor, scheduler-owned
        // scratchpad port and shared completion writer as BF16. Packed FP16
        // lanes compute 1*3 + 2*4 = 11.0 (0x41300000).
        axi_write(SPAD_BASE + 32'h7f20, 32'h4000_3c00); // A = {2.0, 1.0}
        axi_write(SPAD_BASE + 32'h7f24, 32'h4400_4200); // B = {4.0, 3.0}
        axi_write(SPAD_BASE + 32'h7f28, 32'hface_f16d);
        write_spad_desc_v3(32'h7e80, 8'h51, 16'h0502,
                           32'h7f20, 32'h7f24, 32'd0, 32'h7f28,
                           16'd1, 16'd1, 16'd2, 8'd0, 32'd0,
                           5'd0, 2'd0, 32'd0, 32'd0, 32'd0,
                           16'd0, 16'd0, 16'd0, 16'd0, 16'd0);
        axi_write(SPAD_BASE + 32'h7ebc, 32'd7);
        axi_write(REG_CMDQ_BASE_LO, 32'h7e80);
        axi_write(REG_CMDQ_SIZE, 32'd2);
        axi_write(REG_CMDQ_HEAD, 32'd0);
        axi_write(REG_CMDQ_TAIL, 32'd1);
        axi_write(REG_CPLQ_BASE_LO, 32'h7ec0);
        axi_write(REG_CPLQ_SIZE, 32'd2);
        axi_write(REG_CPLQ_HEAD, 32'd0);
        axi_write(REG_CPLQ_TAIL, 32'd0);
        axi_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd1, "A10 FP16 dot descriptor");
        expect_read(SPAD_BASE + 32'h7f28, 32'h4130_0000,
                    "A10 FP16 dot FP32 result");
        expect_completion(32'h7ec0, 16'h0502, 4'h1, 4'd0,
                          32'h4130_0000, 32'd2,
                          "A10 FP16 dot shared completion");
        expect_read(REG_CMDQ_HEAD, 32'd1, "A10 FP16 command head");
        axi_write(REG_CMDQ_SIZE, 32'd0);
        axi_write(REG_CPLQ_SIZE, 32'd0);
        clear_done_irq();

        // DDR -> DMA -> SPAD -> queued FP16 dot -> SPAD -> DMA -> DDR.
        // Keep the command and shared completion path in the same transaction
        // so this checks the full data path, not only the standalone engine.
        axi_mem_u.mem[11'h680] = 32'h4000_3c00; // A = {2.0, 1.0}
        axi_mem_u.mem[11'h684] = 32'h4400_4200; // B = {4.0, 3.0}
        dma_load(32'h0000_1a00, 32'h0000_7f20, 16'd1);
        dma_load(32'h0000_1a10, 32'h0000_7f24, 16'd1);
        expect_read(SPAD_BASE + 32'h7f20, 32'h4000_3c00,
                    "A10 DDR FP16 operand A load");
        expect_read(SPAD_BASE + 32'h7f24, 32'h4400_4200,
                    "A10 DDR FP16 operand B load");
        axi_write(SPAD_BASE + 32'h7f28, 32'hface_f16d);
        write_spad_desc_v3(32'h7e80, 8'h51, 16'h0503,
                           32'h7f20, 32'h7f24, 32'd0, 32'h7f28,
                           16'd1, 16'd1, 16'd2, 8'd0, 32'd0,
                           5'd0, 2'd0, 32'd0, 32'd0, 32'd0,
                           16'd0, 16'd0, 16'd0, 16'd0, 16'd0);
        axi_write(SPAD_BASE + 32'h7ebc, 32'd7);
        axi_write(REG_CMDQ_BASE_LO, 32'h7e80);
        axi_write(REG_CMDQ_SIZE, 32'd2);
        axi_write(REG_CMDQ_HEAD, 32'd0);
        axi_write(REG_CMDQ_TAIL, 32'd1);
        axi_write(REG_CPLQ_BASE_LO, 32'h7ec0);
        axi_write(REG_CPLQ_SIZE, 32'd2);
        axi_write(REG_CPLQ_HEAD, 32'd0);
        axi_write(REG_CPLQ_TAIL, 32'd0);
        axi_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd1, "A10 DDR FP16 command completion");
        expect_read(SPAD_BASE + 32'h7f28, 32'h4130_0000,
                    "A10 DDR FP16 scratchpad result");
        expect_completion(32'h7ec0, 16'h0503, 4'h1, 4'd0,
                          32'h4130_0000, 32'd2,
                          "A10 DDR FP16 shared completion");
        dma_store(32'h0000_1a20, 32'h0000_7f28, 16'd1);
        if (axi_mem_u.mem[11'h688] !== 32'h4130_0000) begin
            $display("%0t ERROR: A10 DDR FP16 result store expected=41300000 actual=%08h",
                     $time, axi_mem_u.mem[11'h688]);
            errors = errors + 1;
        end else begin
            $display("%0t PASS: A10 DDR->SPAD->FP16->SPAD->DDR result=41300000", $time);
        end
        axi_write(REG_CMDQ_SIZE, 32'd0);
        axi_write(REG_CPLQ_SIZE, 32'd0);
        clear_done_irq();

        // Direct-register mode is also supported for the first FP opcode.
        // Its configuration has no descriptor word, so unsupported fields
        // must be rejected by the command processor before the engine starts.
        axi_write(SPAD_BASE + 32'h7f10, 32'hface_b00c);
        axi_write(REG_OP_MODE, 8'h50);
        axi_write(REG_SRC0_BASE, 32'h7f00);
        axi_write(REG_SRC1_BASE, 32'h7f04);
        axi_write(REG_DST_BASE, 32'h7f10);
        axi_write(REG_LENGTH, 32'd2);
        axi_write(REG_M_SIZE, 32'd1);
        axi_write(REG_N_SIZE, 32'd1);
        axi_write(REG_K_WORDS, 32'd2);
        axi_write(REG_BIAS_BASE, 32'd0);
        axi_write(REG_POST_CTRL, 32'd0);
        axi_write(REG_QUANT_ACT, 32'd0);
        axi_write(REG_CTRL, 32'h0000_0003);
        wait_done();
        expect_read(SPAD_BASE + 32'h7f10, 32'h4130_0000,
                    "G2 direct BF16 dot output");
        expect_read(REG_RESULT, 32'h4130_0000,
                    "G2 direct BF16 dot result register");
        expect_read(REG_CPLQ_TAIL, 32'd1,
                    "G2 direct BF16 dot has no queue completion");
        clear_done_irq();

        // Direct-register mode also selects the shared FP16 engine.
        axi_write(SPAD_BASE + 32'h7f30, 32'h0bad_f16d);
        axi_write(REG_OP_MODE, 8'h51);
        axi_write(REG_SRC0_BASE, 32'h7f20);
        axi_write(REG_SRC1_BASE, 32'h7f24);
        axi_write(REG_DST_BASE, 32'h7f30);
        axi_write(REG_LENGTH, 32'd2);
        axi_write(REG_M_SIZE, 32'd1);
        axi_write(REG_N_SIZE, 32'd1);
        axi_write(REG_K_WORDS, 32'd2);
        axi_write(REG_BIAS_BASE, 32'd0);
        axi_write(REG_POST_CTRL, 32'd0);
        axi_write(REG_QUANT_ACT, 32'd0);
        axi_write(REG_CTRL, 32'h0000_0003);
        wait_done();
        expect_read(SPAD_BASE + 32'h7f30, 32'h4130_0000,
                    "A10 direct FP16 dot output");
        expect_read(REG_RESULT, 32'h4130_0000,
                    "A10 direct FP16 dot result register");
        clear_done_irq();

        axi_write(SPAD_BASE + 32'h7f14, 32'hface_f00d);
        axi_write(REG_OP_MODE, 8'h50);
        axi_write(REG_DST_BASE, 32'h7f14);
        axi_write(REG_POST_CTRL, 32'd1);
        axi_write(REG_CTRL, 32'h0000_0003);
        wait_done_expect_error(4'd7);
        expect_read(SPAD_BASE + 32'h7f14, 32'hface_f00d,
                    "G2 invalid direct BF16 config no write");
        clear_done_irq();
        axi_write(REG_POST_CTRL, 32'd0);

        // ABI-v7 end-to-end Transformer micro-workload generated by the
        // software mapper.  Unlike the macro smoke above, every intermediate
        // tensor is consumed by the following RTL command.  PACK_I8 closes
        // the INT32-to-packed-INT8 layout boundary between matrix stages.
        load_transformer_workload();
        axi_write(REG_PERF_CTRL, 32'd1);
        axi_write(REG_CMDQ_CTRL, 32'd0);
        axi_write(REG_CMDQ_BASE_LO, TRANSFORMER_DESC_BASE);
        axi_write(REG_CMDQ_BASE_HI, 32'd0);
        axi_write(REG_CMDQ_SIZE, 32'd128);
        axi_write(REG_CMDQ_HEAD, 32'd0);
        axi_write(REG_CMDQ_TAIL, TRANSFORMER_DESC_COUNT);
        axi_write(REG_CPLQ_BASE_LO, TRANSFORMER_CPL_BASE);
        axi_write(REG_CPLQ_SIZE, 32'd128);
        axi_write(REG_CPLQ_HEAD, 32'd0);
        axi_write(REG_CPLQ_TAIL, 32'd0);
        transformer_top_prefill_target = TRANSFORMER_PREFILL_DESC_COUNT;
        transformer_top_final_target = TRANSFORMER_DESC_COUNT;
        transformer_top_prefill_captured = 1'b0;
        transformer_top_final_captured = 1'b0;
        transformer_top_start_cycle = transformer_top_cycle_counter;
        transformer_top_timing_enable = 1'b1;
        axi_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(TRANSFORMER_DESC_COUNT,
                      "A8 end-to-end Transformer descriptor chain");
        transformer_top_timing_enable = 1'b0;
        if (!transformer_top_prefill_captured ||
            !transformer_top_final_captured ||
            transformer_top_prefill_end_cycle <= transformer_top_start_cycle ||
            transformer_top_final_end_cycle <= transformer_top_prefill_end_cycle) begin
            $display("%0t ERROR: Transformer Top timing boundary capture failed prefill=%0d final=%0d",
                     $time, transformer_top_prefill_captured,
                     transformer_top_final_captured);
            errors = errors + 1;
        end else begin
            $display("TRANSFORMER_TOP_TIMING run_endpoint=doorbell_to_cpl_tail total_cycles=%0d prefill_cycles=%0d prefill_tokens=4 prefill_avg_cycles_per_token=%0.2f decode_cycles=%0d decode_tokens=1 decode_cycles_per_token=%0d",
                     transformer_top_final_end_cycle - transformer_top_start_cycle,
                     transformer_top_prefill_end_cycle - transformer_top_start_cycle,
                     (transformer_top_prefill_end_cycle - transformer_top_start_cycle) / 4.0,
                     transformer_top_final_end_cycle - transformer_top_prefill_end_cycle,
                     transformer_top_final_end_cycle - transformer_top_prefill_end_cycle);
        end
        check_transformer_workload();
        expect_read(REG_CMDQ_HEAD, TRANSFORMER_DESC_COUNT,
                    "A8 Transformer command count");
        expect_completion(TRANSFORMER_CPL_BASE +
                          ((TRANSFORMER_DESC_COUNT-1) * 16),
                          TRANSFORMER_LAST_TASK_ID, 4'h1, 4'd0,
                          TRANSFORMER_LAST_RESULT, 32'd4,
                          "A8 Transformer final completion");
        axi_read(REG_PERF_MATRIX_MAC_CYCLES, rd);
        if (rd == 0) begin
            $display("%0t ERROR: Transformer recorded no matrix MAC cycles",
                     $time);
            errors = errors + 1;
        end else begin
            $display("%0t PASS: Transformer matrix MAC cycles=%0d",
                     $time, rd);
        end
        axi_write(REG_CMDQ_SIZE, 32'd0);
        axi_write(REG_CPLQ_SIZE, 32'd0);
        clear_done_irq();

        if (m_axi_arvalid || m_axi_awvalid || m_axi_wvalid) begin
            $display("%0t ERROR: DMA master boundary should be idle in smoke mode", $time);
            errors = errors + 1;
        end

        random_cases = 20;
        if ($value$plusargs("AI_RANDOM_CASES=%d", random_cases))
            $display("%0t INFO: AI_RANDOM_CASES=%0d", $time, random_cases);
        if ($value$plusargs("AI_SEED=%d", seed_arg)) begin
            seed_dummy = $urandom(seed_arg);
            $display("%0t INFO: AI_SEED=%0d", $time, seed_arg);
        end

        begin : random_loop
            integer case_idx;
            for (case_idx = 0; case_idx < random_cases; case_idx = case_idx + 1) begin
                run_random_gemv(case_idx);
                run_random_gemm(case_idx);
                run_random_conv3x3(case_idx);
                run_random_dwconv3x3(case_idx);
            end
        end

        if ($test$plusargs("AI_DMA_ERROR_STRESS"))
            run_dma_error_injection_stress(seed_arg);

        // Region protection is disabled after reset.  A read/execute-only
        // region allows compute inputs but rejects its result write, which
        // must report through the normal core error path.
        axi_write(SPAD_BASE + 32'h0000_0000, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h0000_0004, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h0000_0008, 32'd0);
        axi_write(REG_REGION0_BASE,  32'h0000_0000);
        axi_write(REG_REGION0_LIMIT, 32'h0000_0100);
        axi_write(REG_REGION0_PERM,  32'h0000_000d); // enable + read + execute
        axi_write(REG_OP_MODE, OP_VDOT_INT8);
        axi_write(REG_SRC0_BASE, 32'h0000_0000);
        axi_write(REG_SRC1_BASE, 32'h0000_0004);
        axi_write(REG_DST_BASE,  32'h0000_0008);
        axi_write(REG_LENGTH,    32'd1);
        axi_write(REG_CTRL,      32'h0000_0001);
        wait_done_expect_error(ERR_PROTECTION);
        axi_write(REG_STATUS, 32'h0000_0006);
        axi_write(REG_IRQ_STATUS, 32'd1);

        // The same policy also rejects host writes at AXI-Lite without
        // touching scratchpad storage; disable it again for compatibility.
        expect_slverr_write(SPAD_BASE + 32'h0000_0000, 32'hdead_beef);
        axi_write(REG_REGION0_PERM, 32'h0000_0000);
        axi_write(SPAD_BASE + 32'h0000_0000, 32'hcafe_babe);
        expect_read(SPAD_BASE + 32'h0000_0000, 32'hcafe_babe, "region protection disabled");

        run_kv_top_protection_denial();

        // System reset while a read burst is in flight.  In the board design
        // the same synchronized reset reaches the accelerator and PS AXI
        // fabric, so both endpoints discard the transaction together.
        axi_mem_u.ready_gap_cfg = 2;
        axi_write(REG_DMA_EXT_ADDR, 32'h0000_1400);
        axi_write(REG_DMA_SPAD_ADDR, 32'h0000_3400);
        axi_write(REG_DMA_LENGTH, 32'd20);
        axi_write(REG_DMA_CTRL, 32'h0000_0001);
        begin : reset_wait_for_read
            integer i;
            integer accepted;
            repeat (4) @(posedge aclk);
            accepted = axi_mem_u.read_active_r;
            if (!accepted) begin
                $display("%0t ERROR: reset test observed no accepted AR", $time);
                errors = errors + 1;
            end
        end
        @(posedge aclk);
        aresetn = 1'b0;
        repeat (8) @(posedge aclk);
        aresetn = 1'b1;
        repeat (6) @(posedge aclk);
        axi_mem_u.ready_gap_cfg = 0;
        expect_read(REG_VERSION, 32'h1000_000a, "reset recovery version");
        axi_read(REG_DMA_STATUS, rd);
        if (rd[0] || axi_mem_u.read_active_r || m_axi_arvalid || m_axi_rvalid) begin
            $display("%0t ERROR: reset recovery left DMA/AXI read active", $time);
            errors = errors + 1;
        end else begin
            $display("%0t PASS: reset recovery returned DMA and AXI to idle", $time);
        end

        if (cp_fetch_done_count == 0)
            $fatal(1, "top smoke observed no descriptor fetch done pulse");
        $display("[CP_FETCH_DONE_OWNED] responses=%0d state=ST_FETCH", cp_fetch_done_count);

        if (errors == 0)
            $display("TEST PASS");
        else
            $display("TEST FAIL errors=%0d", errors);
        $finish;
    end

endmodule
