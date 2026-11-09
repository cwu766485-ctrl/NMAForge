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
    reg [31:0] representative_dma_plan_words [0:255];
    integer representative_load_cycles = 0;
    integer representative_load_measure = 1'b0;
    integer representative_dma_window_cycles = 0;
    integer representative_dma_busy_cycles = 0;
    integer representative_dma_window_measure = 1'b0;
    integer representative_dma_busy_measure = 1'b0;
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
    // Round 20: count accepted external AXI DMA traffic during the retained
    // Matrix/DMA serialized and ping-pong probe. These counters observe the
    // real Top AXI interface, not the AXI-Lite host preload path.
    reg r20_dma_monitor_enable = 1'b0;
    integer r20_dma_ar_bursts = 0;
    integer r20_dma_ar_bytes = 0;
    integer r20_dma_r_beats = 0;
    integer r20_dma_aw_bursts = 0;
    integer r20_dma_aw_bytes = 0;
    integer r20_dma_w_beats = 0;
    integer r20_dma_w_strobe_bytes = 0;
    integer r20_dma_b_responses = 0;
    integer r20_dma_cycle_counter = 0;
    integer r20_dma_first_ar_cycle = -1;
    integer r20_dma_last_r_cycle = -1;
    integer r20_dma_first_aw_cycle = -1;
    integer r20_dma_last_b_cycle = -1;
    integer r20_dma_ar_start_q [0:15];
    integer r20_dma_aw_start_q [0:15];
    integer r20_dma_ar_q_head = 0;
    integer r20_dma_ar_q_tail = 0;
    integer r20_dma_aw_q_head = 0;
    integer r20_dma_aw_q_tail = 0;
    integer r20_dma_read_latency_sum = 0;
    integer r20_dma_read_latency_max = 0;
    integer r20_dma_read_latency_count = 0;
    integer r20_dma_write_latency_sum = 0;
    integer r20_dma_write_latency_max = 0;
    integer r20_dma_write_latency_count = 0;
    integer r20_dma_lane = 0;
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
    // Round 17 per-command Matrix/KV observations. These passive counters are
    // enabled only for the staged H16 incremental-decode timing window.
    reg r17_matrix_monitor_active = 1'b0;
    integer r17_matrix_count = 0;
    integer r17_matrix_current_cycles = 0;
    integer r17_matrix_current_mac = 0;
    integer r17_matrix_current_request_wait = 0;
    integer r17_matrix_current_response_wait = 0;
    integer r17_matrix_current_writeback = 0;
    integer r17_matrix_current_other = 0;
    integer r17_matrix_current_read_bytes = 0;
    integer r17_matrix_current_write_bytes = 0;
    integer r17_matrix_cycles [0:127];
    integer r17_matrix_mac [0:127];
    integer r17_matrix_request_wait [0:127];
    integer r17_matrix_response_wait [0:127];
    integer r17_matrix_writeback [0:127];
    integer r17_matrix_other [0:127];
    integer r17_matrix_read_bytes [0:127];
    integer r17_matrix_write_bytes [0:127];
    reg r17_kv_monitor_active = 1'b0;
    integer r17_kv_count = 0;
    integer r17_kv_current_cycles = 0;
    integer r17_kv_current_read_bytes = 0;
    integer r17_kv_current_write_bytes = 0;
    integer r17_kv_cycles [0:127];
    integer r17_kv_read_bytes [0:127];
    integer r17_kv_write_bytes [0:127];
    integer r17_multi_engine_overlap_cycles = 0;

    always @(posedge aclk) begin
        if (transformer_top_timing_enable) begin
            if ((dut.engine_busy & (dut.engine_busy - 1'b1)) != 0)
                r17_multi_engine_overlap_cycles =
                    r17_multi_engine_overlap_cycles + 1;
            if (dut.matrix_busy) begin
                if (!r17_matrix_monitor_active) begin
                    r17_matrix_monitor_active = 1'b1;
                    r17_matrix_current_cycles = 0;
                    r17_matrix_current_mac = 0;
                    r17_matrix_current_request_wait = 0;
                    r17_matrix_current_response_wait = 0;
                    r17_matrix_current_writeback = 0;
                    r17_matrix_current_other = 0;
                    r17_matrix_current_read_bytes = 0;
                    r17_matrix_current_write_bytes = 0;
                end
                r17_matrix_current_cycles = r17_matrix_current_cycles + 1;
                if (dut.matrix_perf_mac_active)
                    r17_matrix_current_mac = r17_matrix_current_mac + 1;
                else if (dut.matrix_banked_read_valid && !dut.arb_banked_ready)
                    r17_matrix_current_request_wait =
                        r17_matrix_current_request_wait + 1;
                else if (dut.matrix_perf_banked_wait)
                    r17_matrix_current_response_wait =
                        r17_matrix_current_response_wait + 1;
                else if (dut.matrix_line_valid)
                    r17_matrix_current_writeback =
                        r17_matrix_current_writeback + 1;
                else
                    r17_matrix_current_other = r17_matrix_current_other + 1;
                if (dut.matrix_banked_read_valid && dut.arb_banked_ready)
                    r17_matrix_current_read_bytes =
                        r17_matrix_current_read_bytes + 16;
                if (dut.matrix_spad_valid && dut.arb_core_ready) begin
                    if (dut.matrix_spad_write)
                        r17_matrix_current_write_bytes =
                            r17_matrix_current_write_bytes + 4;
                    else
                        r17_matrix_current_read_bytes =
                            r17_matrix_current_read_bytes + 4;
                end
                if (dut.matrix_line_valid && dut.arb_core_line_ready)
                    r17_matrix_current_write_bytes =
                        r17_matrix_current_write_bytes + 16;
            end
            if (dut.engine_busy[6]) begin
                if (!r17_kv_monitor_active) begin
                    r17_kv_monitor_active = 1'b1;
                    r17_kv_current_cycles = 0;
                    r17_kv_current_read_bytes = 0;
                    r17_kv_current_write_bytes = 0;
                end
                r17_kv_current_cycles = r17_kv_current_cycles + 1;
                if (dut.compute_engine_req_valid[6] &&
                    dut.compute_engine_ready[6]) begin
                    if (dut.compute_engine_req_write[6])
                        r17_kv_current_write_bytes =
                            r17_kv_current_write_bytes + 4;
                    else
                        r17_kv_current_read_bytes =
                            r17_kv_current_read_bytes + 4;
                end
            end
        end else begin
            r17_matrix_monitor_active = 1'b0;
            r17_kv_monitor_active = 1'b0;
        end
        #0.001;
        if (transformer_top_timing_enable && dut.engine_done[3] &&
            r17_matrix_monitor_active && r17_matrix_count < 128) begin
            r17_matrix_cycles[r17_matrix_count] = r17_matrix_current_cycles;
            r17_matrix_mac[r17_matrix_count] = r17_matrix_current_mac;
            r17_matrix_request_wait[r17_matrix_count] =
                r17_matrix_current_request_wait;
            r17_matrix_response_wait[r17_matrix_count] =
                r17_matrix_current_response_wait;
            r17_matrix_writeback[r17_matrix_count] =
                r17_matrix_current_writeback;
            r17_matrix_other[r17_matrix_count] = r17_matrix_current_other;
            r17_matrix_read_bytes[r17_matrix_count] =
                r17_matrix_current_read_bytes;
            r17_matrix_write_bytes[r17_matrix_count] =
                r17_matrix_current_write_bytes;
            r17_matrix_count = r17_matrix_count + 1;
            r17_matrix_monitor_active = 1'b0;
        end
        if (transformer_top_timing_enable && dut.engine_done[6] &&
            r17_kv_monitor_active && r17_kv_count < 128) begin
            r17_kv_cycles[r17_kv_count] = r17_kv_current_cycles;
            r17_kv_read_bytes[r17_kv_count] = r17_kv_current_read_bytes;
            r17_kv_write_bytes[r17_kv_count] = r17_kv_current_write_bytes;
            r17_kv_count = r17_kv_count + 1;
            r17_kv_monitor_active = 1'b0;
        end
    end

    always @(posedge aclk) begin
        if (representative_load_measure)
            representative_load_cycles = representative_load_cycles + 1;
        if (representative_dma_window_measure)
            representative_dma_window_cycles = representative_dma_window_cycles + 1;
        if (representative_dma_busy_measure && dut.dma_busy)
            representative_dma_busy_cycles = representative_dma_busy_cycles + 1;
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
        r20_dma_cycle_counter = r20_dma_cycle_counter + 1;
        if (!aresetn) begin
            r20_dma_ar_bursts = 0;
            r20_dma_ar_bytes = 0;
            r20_dma_r_beats = 0;
            r20_dma_aw_bursts = 0;
            r20_dma_aw_bytes = 0;
            r20_dma_w_beats = 0;
            r20_dma_w_strobe_bytes = 0;
            r20_dma_b_responses = 0;
            r20_dma_ar_q_head = 0;
            r20_dma_ar_q_tail = 0;
            r20_dma_aw_q_head = 0;
            r20_dma_aw_q_tail = 0;
            r20_dma_read_latency_sum = 0;
            r20_dma_read_latency_max = 0;
            r20_dma_read_latency_count = 0;
            r20_dma_write_latency_sum = 0;
            r20_dma_write_latency_max = 0;
            r20_dma_write_latency_count = 0;
        end else if (r20_dma_monitor_enable) begin
            if (m_axi_arvalid && m_axi_arready) begin
                if (r20_dma_first_ar_cycle < 0)
                    r20_dma_first_ar_cycle = r20_dma_cycle_counter;
                r20_dma_ar_start_q[r20_dma_ar_q_tail % 16] =
                    r20_dma_cycle_counter;
                r20_dma_ar_q_tail = r20_dma_ar_q_tail + 1;
                r20_dma_ar_bursts = r20_dma_ar_bursts + 1;
                r20_dma_ar_bytes = r20_dma_ar_bytes +
                    (m_axi_arlen + 1) * (1 << m_axi_arsize);
            end
            if (m_axi_rvalid && m_axi_rready) begin
                r20_dma_r_beats = r20_dma_r_beats + 1;
                r20_dma_last_r_cycle = r20_dma_cycle_counter;
                if (m_axi_rlast &&
                    r20_dma_ar_q_head < r20_dma_ar_q_tail) begin
                    if (r20_dma_cycle_counter -
                        r20_dma_ar_start_q[r20_dma_ar_q_head % 16] + 1 >
                        r20_dma_read_latency_max)
                        r20_dma_read_latency_max = r20_dma_cycle_counter -
                            r20_dma_ar_start_q[r20_dma_ar_q_head % 16] + 1;
                    r20_dma_read_latency_sum = r20_dma_read_latency_sum +
                        r20_dma_cycle_counter -
                        r20_dma_ar_start_q[r20_dma_ar_q_head % 16] + 1;
                    r20_dma_read_latency_count =
                        r20_dma_read_latency_count + 1;
                    r20_dma_ar_q_head = r20_dma_ar_q_head + 1;
                end
            end
            if (m_axi_awvalid && m_axi_awready) begin
                if (r20_dma_first_aw_cycle < 0)
                    r20_dma_first_aw_cycle = r20_dma_cycle_counter;
                r20_dma_aw_start_q[r20_dma_aw_q_tail % 16] =
                    r20_dma_cycle_counter;
                r20_dma_aw_q_tail = r20_dma_aw_q_tail + 1;
                r20_dma_aw_bursts = r20_dma_aw_bursts + 1;
                r20_dma_aw_bytes = r20_dma_aw_bytes +
                    (m_axi_awlen + 1) * (1 << m_axi_awsize);
            end
            if (m_axi_wvalid && m_axi_wready) begin
                r20_dma_w_beats = r20_dma_w_beats + 1;
                for (r20_dma_lane = 0; r20_dma_lane < 16;
                     r20_dma_lane = r20_dma_lane + 1)
                    if (m_axi_wstrb[r20_dma_lane])
                        r20_dma_w_strobe_bytes = r20_dma_w_strobe_bytes + 1;
            end
            if (m_axi_bvalid && m_axi_bready) begin
                r20_dma_b_responses = r20_dma_b_responses + 1;
                r20_dma_last_b_cycle = r20_dma_cycle_counter;
                if (r20_dma_aw_q_head < r20_dma_aw_q_tail) begin
                    if (r20_dma_cycle_counter -
                        r20_dma_aw_start_q[r20_dma_aw_q_head % 16] + 1 >
                        r20_dma_write_latency_max)
                        r20_dma_write_latency_max = r20_dma_cycle_counter -
                            r20_dma_aw_start_q[r20_dma_aw_q_head % 16] + 1;
                    r20_dma_write_latency_sum = r20_dma_write_latency_sum +
                        r20_dma_cycle_counter -
                        r20_dma_aw_start_q[r20_dma_aw_q_head % 16] + 1;
                    r20_dma_write_latency_count =
                        r20_dma_write_latency_count + 1;
                    r20_dma_aw_q_head = r20_dma_aw_q_head + 1;
                end
            end
        end
    end

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
        .element_count(dut.compute_cluster_u.tensor_sfu_u.element_count)
    );

    ai_compute_activity_sva cnn_activity_sva(
        .clk          (aclk),
        .resetn       (aresetn),
        .wake         (dut.core_start && dut.conv_linebuffer_op),
        .busy         (dut.conv_busy),
        .done         (dut.compute_cluster_u.conv_linebuffer_u.done),
        .error        (dut.compute_cluster_u.conv_linebuffer_u.error),
        .spad_valid   (dut.conv_spad_valid),
        .cycle_count  (dut.compute_cluster_u.conv_linebuffer_u.cycle_count),
        .element_count(dut.compute_cluster_u.conv_linebuffer_u.element_count)
    );

    ai_compute_activity_sva kv_activity_sva(
        .clk          (aclk),
        .resetn       (aresetn),
        .wake         (dut.core_start && dut.kv_cache_op),
        .busy         (dut.kv_busy),
        .done         (dut.compute_cluster_u.kv_cache_u.done),
        .error        (dut.compute_cluster_u.kv_cache_u.error),
        .spad_valid   (dut.kv_spad_valid),
        .cycle_count  (dut.compute_cluster_u.kv_cache_u.cycle_count),
        .element_count(dut.compute_cluster_u.kv_cache_u.element_count)
    );

    ai_compute_activity_sva fp_activity_sva(
        .clk          (aclk),
        .resetn       (aresetn),
        .wake         (dut.core_start && ((dut.launch_op == 8'h50) || (dut.launch_op == 8'h51))),
        .busy         (dut.fp_busy),
        .done         (dut.compute_cluster_u.fp_done),
        .error        (dut.compute_cluster_u.fp_error),
        .spad_valid   (dut.fp_spad_valid),
        .cycle_count  (dut.compute_cluster_u.fp_cycle_count),
        .element_count(dut.compute_cluster_u.fp_element_count)
    );

    initial begin
        aclk = 1'b0;
        begin : clock_setup
            real aclk_period_ns;
            aclk_period_ns = 10.0;
            void'($value$plusargs("ACLK_PERIOD_NS=%f", aclk_period_ns));
            if (aclk_period_ns <= 0.0)
                $fatal(1, "ACLK_PERIOD_NS must be > 0, got %f", aclk_period_ns);
            forever #(aclk_period_ns / 2.0) aclk = ~aclk;
        end
    end

    `include "axi_lite_tasks.svh"

    task wait_done;
        begin
            integer i;
            integer found;
            found = 0;
            // Scratchpad reads are native synchronous BRAM reads.  Scalar
            // operations now include request/response wait cycles and banked
            // operations fetch A then B, so retain ample polling headroom.
            for (i = 0; i < 400; i = i + 1) begin
                if (!found) begin
                    axi_read(REG_STATUS, rd);
                    if (rd[1])
                        found = 1;
                end
            end
            if (!found) begin
                $display("%0t ERROR: timeout waiting done", $time);
                errors = errors + 1;
            end
            if (rd[2]) begin
                axi_read(REG_ERROR_CODE, rd);
                $display("%0t ERROR: core error_code=%0d", $time, rd);
                errors = errors + 1;
            end
        end
    endtask

    task wait_done_expect_error;
        input [3:0] expected_error_code;
        begin
            integer i;
            integer found;
            reg [31:0] status;
            found = 0;
            status = 32'd0;
            for (i = 0; i < 200; i = i + 1) begin
                if (!found) begin
                    axi_read(REG_STATUS, status);
                    if (status[1])
                        found = 1;
                end
            end
            if (!found) begin
                $display("%0t ERROR: timeout waiting expected error done", $time);
                errors = errors + 1;
            end else if (!status[2]) begin
                $display("%0t ERROR: expected STATUS.error for descriptor error", $time);
                errors = errors + 1;
            end
            axi_read(REG_ERROR_CODE, rd);
            if (rd[3:0] !== expected_error_code) begin
                $display("%0t ERROR: expected error_code=%0d actual=%0d",
                         $time, expected_error_code, rd[3:0]);
                errors = errors + 1;
            end else begin
                $display("%0t PASS: expected core error_code = %0d/%08h", $time, rd[3:0], rd);
            end
        end
    endtask

    task clear_done_irq;
        begin
            axi_write(REG_IRQ_STATUS, 32'd1);
            axi_write(REG_STATUS, 32'd2);
        end
    endtask

    `include "ai_dma_tasks.svh"

    // Optional subsystem-level DMA error stress. Each transaction uses the
    // production top DMA/SPAD path and a seeded error location inside a
    // multi-beat AXI burst. The regular smoke stays deterministic and does
    // not enable this additional randomized campaign.
    task run_dma_error_injection_stress;
        input integer seed;
        integer iteration;
        integer beat_index;
        integer word_index;
        reg [31:0] rng;
        reg [31:0] ext_addr;
        reg [31:0] spad_addr;
        begin
            rng = seed;
            for (iteration = 0; iteration < 8; iteration = iteration + 1) begin
                rng = rng * 32'd1664525 + 32'd1013904223;
                beat_index = rng[1:0];
                ext_addr = 32'h0000_1000 + (iteration * 32'h100);
                spad_addr = 32'h0000_3000 + (iteration * 32'h40);
                axi_mem_u.read_gap_cfg = rng[20:19];
                axi_mem_u.ready_gap_cfg = rng[17:16];
                for (word_index = 0; word_index < 16; word_index = word_index + 1)
                    axi_mem_u.mem[(ext_addr >> 2) + word_index] =
                        rng ^ (32'h5a00_0000 + (iteration * 32) + word_index);
                axi_mem_u.inject_read_error_word = (ext_addr >> 2) + (beat_index * 4);
                dma_load_expect_error(ext_addr, spad_addr, 16'd16, 4'd2);
                axi_mem_u.inject_read_error_word = -1;
                if (axi_mem_u.read_active_r || (axi_mem_u.read_q_count_r != 0) ||
                    m_axi_rvalid || m_axi_arvalid) begin
                    $display("%0t ERROR: randomized DMA read error left AXI read traffic active iter=%0d",
                             $time, iteration);
                    errors = errors + 1;
                end

                rng = rng * 32'd1664525 + 32'd1013904223;
                beat_index = rng[1:0];
                ext_addr = 32'h0000_3000 + (iteration * 32'h100);
                spad_addr = 32'h0000_4000 + (iteration * 32'h40);
                axi_mem_u.ready_gap_cfg = rng[17:16];
                for (word_index = 0; word_index < 16; word_index = word_index + 1) begin
                    axi_write(SPAD_BASE + spad_addr + (word_index * 4),
                              rng ^ (32'ha500_0000 + (iteration * 32) + word_index));
                end
                axi_mem_u.inject_write_error_word = (ext_addr >> 2) + (beat_index * 4);
                dma_store_expect_error(ext_addr, spad_addr, 16'd16, 4'd3);
                axi_mem_u.inject_write_error_word = -1;
                if (axi_mem_u.write_active_r || axi_mem_u.bvalid ||
                    m_axi_awvalid || m_axi_wvalid) begin
                    $display("%0t ERROR: randomized DMA write error left AXI write traffic active iter=%0d",
                             $time, iteration);
                    errors = errors + 1;
                end
            end
            axi_mem_u.inject_read_error_word = -1;
            axi_mem_u.inject_write_error_word = -1;
            axi_mem_u.read_gap_cfg = 1;
            axi_mem_u.ready_gap_cfg = 0;
            $display("%0t PASS: DMA randomized burst-error stress seed=%0d cases=8 read=8 write=8",
                     $time, seed);
        end
    endtask

    task write_spad_desc;
        input [31:0] base;
        input [7:0]  op;
        input [15:0] task_id;
        input [31:0] src0;
        input [31:0] src1;
        input [31:0] dst;
        input [15:0] m;
        input [15:0] n;
        input [15:0] k;
        begin
            axi_write(SPAD_BASE + base + 32'h00, {task_id, 8'd0, op});
            axi_write(SPAD_BASE + base + 32'h04, src0);
            axi_write(SPAD_BASE + base + 32'h08, src1);
            axi_write(SPAD_BASE + base + 32'h0c, 32'd0);
            axi_write(SPAD_BASE + base + 32'h10, dst);
            axi_write(SPAD_BASE + base + 32'h14, {n, m});
            axi_write(SPAD_BASE + base + 32'h18, {16'd0, k});
            axi_write(SPAD_BASE + base + 32'h1c, 32'd0);
            axi_write(SPAD_BASE + base + 32'h20, 32'd0);
            axi_write(SPAD_BASE + base + 32'h24, 32'd0);
            axi_write(SPAD_BASE + base + 32'h28, 32'd0);
            axi_write(SPAD_BASE + base + 32'h2c, 32'd0);
            axi_write(SPAD_BASE + base + 32'h30, 32'd0);
            axi_write(SPAD_BASE + base + 32'h34, 32'd0);
            axi_write(SPAD_BASE + base + 32'h38, 32'd0);
            axi_write(SPAD_BASE + base + 32'h3c, 32'd0);
        end
    endtask

    task write_axi_desc;
        input [31:0] base;
        input [7:0]  op;
        input [15:0] task_id;
        input [31:0] src0;
        input [31:0] src1;
        input [31:0] dst;
        input [15:0] m;
        input [15:0] n;
        input [15:0] k;
        integer word_idx;
        begin
            word_idx = base[31:2];
            axi_mem_u.mem[word_idx + 0]  = {task_id, 8'd0, op};
            axi_mem_u.mem[word_idx + 1]  = src0;
            axi_mem_u.mem[word_idx + 2]  = src1;
            axi_mem_u.mem[word_idx + 3]  = 32'd0;
            axi_mem_u.mem[word_idx + 4]  = dst;
            axi_mem_u.mem[word_idx + 5]  = {n, m};
            axi_mem_u.mem[word_idx + 6]  = {16'd0, k};
            axi_mem_u.mem[word_idx + 7]  = 32'd0;
            axi_mem_u.mem[word_idx + 8]  = 32'd0;
            axi_mem_u.mem[word_idx + 9]  = 32'd0;
            axi_mem_u.mem[word_idx + 10] = 32'd0;
            axi_mem_u.mem[word_idx + 11] = 32'd0;
            axi_mem_u.mem[word_idx + 12] = 32'd0;
            axi_mem_u.mem[word_idx + 13] = 32'd0;
            axi_mem_u.mem[word_idx + 14] = 32'd0;
            axi_mem_u.mem[word_idx + 15] = 32'd0;
        end
    endtask

    task write_spad_desc_v3;
        input [31:0] base;
        input [7:0]  op;
        input [15:0] task_id;
        input [31:0] src0;
        input [31:0] src1;
        input [31:0] bias_base_i;
        input [31:0] dst;
        input [15:0] m;
        input [15:0] n;
        input [15:0] k_or_length;
        input [7:0]  flags;
        input [31:0] aux0;
        input [4:0]  shift;
        input [1:0]  activation;
        input [31:0] src0_stride;
        input [31:0] src1_stride;
        input [31:0] dst_stride;
        input [15:0] batch_count;
        input [15:0] head_count;
        input [15:0] wait_mask;
        input [15:0] signal_mask;
        input [15:0] clear_mask;
        begin
            axi_write(SPAD_BASE + base + 32'h00, {task_id, 8'd0, op});
            axi_write(SPAD_BASE + base + 32'h04, src0);
            axi_write(SPAD_BASE + base + 32'h08, src1);
            axi_write(SPAD_BASE + base + 32'h0c, bias_base_i);
            axi_write(SPAD_BASE + base + 32'h10, dst);
            axi_write(SPAD_BASE + base + 32'h14, {n, m});
            axi_write(SPAD_BASE + base + 32'h18, {16'd0, k_or_length});
            axi_write(SPAD_BASE + base + 32'h1c, {24'd0, flags});
            axi_write(SPAD_BASE + base + 32'h20, aux0);
            axi_write(SPAD_BASE + base + 32'h24, {25'd0, activation, shift});
            axi_write(SPAD_BASE + base + 32'h28, src0_stride);
            axi_write(SPAD_BASE + base + 32'h2c, src1_stride);
            axi_write(SPAD_BASE + base + 32'h30, dst_stride);
            axi_write(SPAD_BASE + base + 32'h34, {head_count, batch_count});
            axi_write(SPAD_BASE + base + 32'h38, {signal_mask, wait_mask});
            axi_write(SPAD_BASE + base + 32'h3c, {clear_mask, 8'd0, 8'd3});
        end
    endtask

    task write_parallel_pair_descriptor;
        input [31:0] desc_base;
        input integer engine_id;
        input [15:0] task_id;
        reg [7:0] op;
        reg [7:0] version;
        reg [15:0] m_size;
        reg [15:0] n_size;
        reg [15:0] length_or_k;
        reg [31:0] src0;
        reg [31:0] src1;
        reg [31:0] dst;
        reg [31:0] src0_stride;
        reg [31:0] src1_stride;
        reg [15:0] batch_count;
        reg [15:0] head_count;
        begin
            op = OP_VDOT_INT8;
            version = 8'd3;
            m_size = 16'd1;
            n_size = 16'd1;
            length_or_k = 16'd64;
            // Read-only inputs are shared by all engines.  Outputs use a
            // private page so concurrent descriptors cannot conflict.
            src0 = 32'h0001_0000;
            src1 = 32'h0001_1000;
            dst = 32'h0003_0000 + (engine_id * 32'h1000);
            src0_stride = 32'd0;
            src1_stride = 32'd0;
            batch_count = 16'd1;
            head_count = 16'd1;
            case (engine_id)
                0: op = OP_VDOT_INT8;
                1: begin
                    op = 8'h51;
                    version = 8'd7;
                    m_size = 16'd1;
                    n_size = 16'd1;
                    batch_count = 16'd0;
                    head_count = 16'd0;
                end
                2: op = OP_BANKED_VDOT;
                3: begin
                    op = OP_TENSOR_GEMM;
                    m_size = 16'd4;
                    n_size = 16'd4;
                    length_or_k = 16'd16;
                end
                4: op = OP_GELU_Q8_8;
                5: begin
                    op = 8'h16;
                    version = 8'd5;
                    m_size = 16'd16;
                    n_size = 16'd16;
                    length_or_k = 16'd0;
                end
                6: begin
                    op = 8'h43;
                    version = 8'd5;
                    src0_stride = 32'd64;
                    src1_stride = 32'd16;
                end
                default: $fatal(1, "invalid parallel engine id %0d", engine_id);
            endcase

            write_spad_desc_v3(desc_base, op, task_id, src0, src1, 32'd0, dst,
                               m_size, n_size, length_or_k, 8'd0, 32'd0,
                               5'd0, 2'd0, src0_stride, src1_stride, 32'd0,
                               batch_count, head_count, 16'd0, 16'd0, 16'd0);
            axi_write(SPAD_BASE + desc_base + 32'h3c,
                      {16'd0, 8'd0, version});
        end
    endtask

    task run_parallel_engine_pair;
        input integer engine_a;
        input integer engine_b;
        input integer pair_index;
        reg overlap_found;
        integer poll;
        begin
            write_parallel_pair_descriptor(32'h7d00, engine_a,
                                           16'h7000 + (pair_index * 2));
            write_parallel_pair_descriptor(32'h7d40, engine_b,
                                           16'h7001 + (pair_index * 2));

            axi_write(REG_CMDQ_BASE_LO, 32'h7d00);
            axi_write(REG_CMDQ_SIZE, 32'd4);
            axi_write(REG_CMDQ_HEAD, 32'd0);
            axi_write(REG_CMDQ_TAIL, 32'd2);
            axi_write(REG_CPLQ_BASE_LO, 32'h7d80);
            axi_write(REG_CPLQ_SIZE, 32'd4);
            axi_write(REG_CPLQ_HEAD, 32'd0);
            axi_write(REG_CPLQ_TAIL, 32'd0);

            axi_write(REG_DOORBELL, 32'd1);
            overlap_found = 1'b0;
            for (poll = 0; poll < 2000 && !overlap_found; poll = poll + 1) begin
                @(posedge aclk);
                if (dut.engine_busy[engine_a] && dut.engine_busy[engine_b])
                    overlap_found = 1'b1;
            end
            if (!overlap_found) begin
                $display("%0t ERROR: engine pair %0d/%0d did not overlap",
                         $time, engine_a, engine_b);
                errors = errors + 1;
            end else begin
                parallel_engine_pair_seen[pair_index] = 1'b1;
                $display("%0t PASS: engine pair %0d/%0d overlapped",
                         $time, engine_a, engine_b);
                axi_write(REG_ABORT, 32'd1);
            end
            wait_cpl_tail(32'd2, "all-engine-pair ordered abort drain");
            expect_read(SPAD_BASE + 32'h7d80,
                        {16'd0, (16'h7000 + (pair_index * 2))},
                        "all-engine-pair completion first task");
            axi_read(SPAD_BASE + 32'h7d84, rd);
            if ((rd !== 32'h0000_0001) && (rd !== 32'h0000_0032)) begin
                $display("%0t ERROR: all-engine-pair first completion status=%08h",
                         $time, rd);
                errors = errors + 1;
            end
            expect_read(SPAD_BASE + 32'h7d90,
                        {16'd0, (16'h7001 + (pair_index * 2))},
                        "all-engine-pair completion second task");
            axi_read(SPAD_BASE + 32'h7d94, rd);
            if ((rd !== 32'h0000_0001) && (rd !== 32'h0000_0032)) begin
                $display("%0t ERROR: all-engine-pair second completion status=%08h",
                         $time, rd);
                errors = errors + 1;
            end
            if ((dut.engine_busy != 7'd0) || dut.parallel_compute_dispatcher_u.busy) begin
                $display("%0t ERROR: engine pair %0d/%0d abort returned before drain",
                         $time, engine_a, engine_b);
                errors = errors + 1;
            end
            axi_write(REG_CMDQ_SIZE, 32'd0);
            axi_write(REG_CPLQ_SIZE, 32'd0);
            clear_done_irq();
        end
    endtask

    task run_kv_top_protection_denial;
        integer poll;
        begin
            // Keep one KV_WRITE source word readable/executable while leaving
            // its cache destination outside every permitted region. The
            // descriptor fetch and completion record use a separate RW region.
            axi_write(REG_REGION0_PERM, 32'd0);
            axi_write(REG_REGION1_PERM, 32'd0);
            axi_write(REG_REGION2_PERM, 32'd0);
            axi_write(REG_REGION3_PERM, 32'd0);
            axi_write(SPAD_BASE + 32'h0000_1000, 32'h1357_9bdf);
            axi_write(SPAD_BASE + 32'h0000_2000, 32'hcafe_f00d);
            write_spad_desc_v3(32'h7d00, 8'h43, 16'h7a53,
                               32'h0000_1000, 32'd0, 32'd0, 32'h0000_2000,
                               16'd1, 16'd1, 16'd1, 8'd0, 32'd0,
                               5'd0, 2'd0, 32'd4, 32'd0, 32'd0,
                               16'd0, 16'd0, 16'd0, 16'd0, 16'd0);
            axi_write(SPAD_BASE + 32'h7d3c, {16'd0, 8'd0, 8'd5});

            axi_write(REG_REGION0_BASE, 32'h0000_1000);
            axi_write(REG_REGION0_LIMIT, 32'h0000_1004);
            axi_write(REG_REGION0_PERM, 32'h0000_000d); // enable + read + execute
            axi_write(REG_REGION2_BASE, 32'h0000_7d00);
            axi_write(REG_REGION2_LIMIT, 32'h0000_7d90);
            axi_write(REG_REGION2_PERM, 32'h0000_000b); // enable + read + write

            axi_write(REG_CMDQ_BASE_LO, 32'h7d00);
            axi_write(REG_CMDQ_SIZE, 32'd2);
            axi_write(REG_CMDQ_HEAD, 32'd0);
            axi_write(REG_CMDQ_TAIL, 32'd1);
            axi_write(REG_CPLQ_BASE_LO, 32'h7d80);
            axi_write(REG_CPLQ_SIZE, 32'd2);
            axi_write(REG_CPLQ_HEAD, 32'd0);
            axi_write(REG_CPLQ_TAIL, 32'd0);

            kv_protection_read_accepts = 0;
            kv_protection_write_denied = 1'b0;
            kv_protection_denied_addr = 32'd0;
            kv_protection_case_active = 1'b1;
            axi_write(REG_DOORBELL, 32'd1);
            wait_cpl_tail(32'd1, "KV top-level protection denial completion");
            kv_protection_case_active = 1'b0;

            expect_completion(32'h7d80, 16'h7a53, 4'h2, 4'h7,
                              32'd0, 32'd0,
                              "KV top-level protection denial completion record");
            if ((kv_protection_read_accepts != 1) ||
                !kv_protection_write_denied ||
                (kv_protection_denied_addr !== 32'h0000_2000)) begin
                $display("%0t ERROR: KV protection trace reads=%0d denied=%0b addr=%08h",
                         $time, kv_protection_read_accepts,
                         kv_protection_write_denied, kv_protection_denied_addr);
                errors = errors + 1;
            end else begin
                $display("%0t PASS: KV top protection accepted source read and denied destination write",
                         $time);
            end

            axi_write(REG_REGION0_PERM, 32'd0);
            axi_write(REG_REGION2_PERM, 32'd0);
            expect_read(SPAD_BASE + 32'h0000_1000, 32'h1357_9bdf,
                        "KV protection source preserved");
            expect_read(SPAD_BASE + 32'h0000_2000, 32'hcafe_f00d,
                        "KV protection destination unchanged");
            axi_write(REG_CMDQ_SIZE, 32'd0);
            axi_write(REG_CPLQ_SIZE, 32'd0);
            clear_done_irq();
        end
    endtask

    function [31:0] fp_perf_expected_sum;
        input integer n;
        begin
            case (n)
                1: fp_perf_expected_sum = 32'h3f80_0000;
                2: fp_perf_expected_sum = 32'h4000_0000;
                3: fp_perf_expected_sum = 32'h4040_0000;
                4: fp_perf_expected_sum = 32'h4080_0000;
                16: fp_perf_expected_sum = 32'h4180_0000;
                64: fp_perf_expected_sum = 32'h4280_0000;
                128: fp_perf_expected_sum = 32'h4300_0000;
                256: fp_perf_expected_sum = 32'h4380_0000;
                1024: fp_perf_expected_sum = 32'h4480_0000;
                default: fp_perf_expected_sum = 32'hxxxx_xxxx;
            endcase
        end
    endfunction

    task fp_perf_seed_input_vectors;
        input format_fp16;
        input integer vector_length;
        input integer tile_count;
        integer word_index;
        integer tile_index;
        integer words_per_tile;
        reg [31:0] packed_one;
        begin
            packed_one = format_fp16 ? 32'h3c00_3c00 : 32'h3f80_3f80;
            words_per_tile = (vector_length + 1) >> 1;
            for (tile_index = 0; tile_index < tile_count; tile_index = tile_index + 1)
                for (word_index = 0; word_index < words_per_tile; word_index = word_index + 1)
                    axi_mem_u.mem[12'h400 + tile_index * words_per_tile + word_index] = packed_one;
        end
    endtask

    task fp_perf_load_weights;
        input format_fp16;
        input integer words;
        integer word_index;
        reg [31:0] packed_one;
        begin
            packed_one = format_fp16 ? 32'h3c00_3c00 : 32'h3f80_3f80;
            for (word_index = 0; word_index < words; word_index = word_index + 1)
                axi_mem_u.mem[12'hc00 + word_index] = packed_one;
            axi_mem_u.ready_gap_cfg = 0;
            // The weight vector is loaded once through the real DMA path;
            // tile inputs and outputs then use the existing ping-pong engine.
            fp_perf_dma_load(32'h0000_3000, 32'h0000_3000, words);
        end
    endtask

    task fp_perf_dma_load;
        input [31:0] ext_addr;
        input [31:0] spad_addr;
        input [15:0] words;
        integer poll;
        reg [31:0] status;
        begin
            axi_write(REG_DMA_EXT_ADDR, ext_addr);
            axi_write(REG_DMA_SPAD_ADDR, spad_addr);
            axi_write(REG_DMA_LENGTH, {16'd0, words});
            axi_write(REG_DMA_CTRL, 32'h0000_0001);
            for (poll = 0; poll < 20000 && !dut.dma_done && !dut.dma_error;
                 poll = poll + 1)
                @(posedge aclk);
            if (poll == 20000)
                $fatal(1, "FP benchmark setup DMA cycle timeout ext=%08h spad=%08h words=%0d busy=%b state=%0d",
                       ext_addr, spad_addr, words, dut.dma_busy, dut.dma_u.state_r);
            axi_read(REG_DMA_STATUS, status);
            if (!(dut.dma_done || status[1]) || dut.dma_error || status[2])
                $fatal(1, "FP benchmark setup DMA failed ext=%08h spad=%08h words=%0d status=%08h",
                       ext_addr, spad_addr, words, status);
            axi_write(REG_DMA_STATUS, 32'd2);
        end
    endtask

    task fp_perf_wait_tile_done;
        integer poll;
        integer found;
        reg [31:0] status;
        begin
            found = 0;
            status = 32'd0;
            for (poll = 0; poll < 10000 && !found; poll = poll + 1) begin
                axi_read(REG_STATUS, status);
                if (status[1]) found = 1;
            end
            if (!found || status[2])
                $fatal(1, "FP tile benchmark did not complete cleanly status=%08h processor_busy=%b tile_active=%b dma_busy=%b fp_busy=%b",
                       status, dut.processor_busy, dut.tile_active, dut.dma_busy, dut.fp_busy);
        end
    endtask

    // Round 9 reproducer for the previously non-retained Matrix/DMA ping-pong
    // failure. Three 4x4 INT8 GEMMs share a fixed B matrix and stream distinct
    // A tiles through the production top's two-buffer DMA/compute pipeline.
    task run_matrix_dma_overlap_probe;
        integer tile_index;
        integer row_index;
        integer col_index;
        integer lane_index;
        integer value_i;
        integer expected_i;
        integer word_index;
        integer serial_tile;
        reg [31:0] packed_word;
        reg [31:0] read_value;
        reg [31:0] perf_total;
        reg [31:0] perf_dma;
        reg [31:0] perf_compute;
        reg [31:0] perf_overlap;
        reg [31:0] perf_stall;
        reg [31:0] serial_total;
        reg [31:0] serial_dma;
        reg [31:0] serial_compute;
        reg [31:0] serial_overlap;
        reg [31:0] serial_stall;
        integer serial_ar_bursts;
        integer serial_ar_bytes;
        integer serial_r_beats;
        integer serial_aw_bursts;
        integer serial_aw_bytes;
        integer serial_w_beats;
        integer serial_w_bytes;
        integer serial_b_responses;
        integer serial_first_ar_cycle;
        integer serial_last_r_cycle;
        integer serial_first_aw_cycle;
        integer serial_last_b_cycle;
        integer serial_read_service_cycles;
        integer serial_write_service_cycles;
        integer serial_read_latency_sum;
        integer serial_read_latency_max;
        integer serial_read_latency_count;
        integer serial_write_latency_sum;
        integer serial_write_latency_max;
        integer serial_write_latency_count;
        integer overlap_ar_bursts;
        integer overlap_ar_bytes;
        integer overlap_r_beats;
        integer overlap_aw_bursts;
        integer overlap_aw_bytes;
        integer overlap_w_beats;
        integer overlap_w_bytes;
        integer overlap_b_responses;
        integer overlap_first_ar_cycle;
        integer overlap_last_r_cycle;
        integer overlap_first_aw_cycle;
        integer overlap_last_b_cycle;
        integer overlap_read_service_cycles;
        integer overlap_write_service_cycles;
        integer overlap_read_latency_sum;
        integer overlap_read_latency_max;
        integer overlap_read_latency_count;
        integer overlap_write_latency_sum;
        integer overlap_write_latency_max;
        integer overlap_write_latency_count;
        reg [31:0] input_words [0:11];
        reg [31:0] weight_words [0:3];
        reg [31:0] expected_words [0:47];
        begin
            // B is stored as one four-byte K word for each output column.
            for (col_index = 0; col_index < 4; col_index = col_index + 1) begin
                packed_word = 32'd0;
                for (lane_index = 0; lane_index < 4; lane_index = lane_index + 1) begin
                    value_i = col_index + 1 - lane_index;
                    packed_word[lane_index*8 +: 8] = value_i[7:0];
                end
                weight_words[col_index] = packed_word;
                axi_write(SPAD_BASE + 32'h0000_a000 + col_index*4, packed_word);
            end

            // Each tile has four packed A rows. Values differ by tile/row/lane
            // so swapped buffers, stale contexts, and wrong tile addresses
            // cannot accidentally match the expected output.
            for (tile_index = 0; tile_index < 3; tile_index = tile_index + 1) begin
                for (row_index = 0; row_index < 4; row_index = row_index + 1) begin
                    packed_word = 32'd0;
                    for (lane_index = 0; lane_index < 4; lane_index = lane_index + 1) begin
                        value_i = tile_index + 2 + row_index*2 + lane_index;
                        packed_word[lane_index*8 +: 8] = value_i[7:0];
                    end
                    word_index = tile_index*4 + row_index;
                    input_words[word_index] = packed_word;
                    axi_mem_u.mem[12'h500 + word_index] = packed_word;
                end
            end

            for (tile_index = 0; tile_index < 3; tile_index = tile_index + 1)
                for (row_index = 0; row_index < 4; row_index = row_index + 1)
                    for (col_index = 0; col_index < 4; col_index = col_index + 1) begin
                        expected_i = dot4_i8_sv(input_words[tile_index*4 + row_index],
                                                weight_words[col_index]);
                        expected_words[tile_index*16 + row_index*4 + col_index] = expected_i;
                        axi_mem_u.mem[12'h800 + tile_index*16 + row_index*4 + col_index] =
                            32'hdead_c0de;
                    end

            axi_write(REG_OP_MODE, OP_GEMM_INT8_TILE);
            axi_write(REG_SRC1_BASE, 32'h0000_a000);
            axi_write(REG_LENGTH, 32'd1);
            axi_write(REG_M_SIZE, 32'd4);
            axi_write(REG_N_SIZE, 32'd4);
            axi_write(REG_K_WORDS, 32'd1);
            axi_write(REG_POST_CTRL, 32'd0);
            axi_write(REG_QUANT_ACT, 32'd0);
            axi_write(REG_TILE_EXT_IN_STRIDE, 32'd16);
            axi_write(REG_TILE_EXT_OUT_STRIDE, 32'd64);
            axi_write(REG_TILE_BUF0, 32'h0000_8000);
            axi_write(REG_TILE_BUF1, 32'h0000_9000);
            axi_write(REG_TILE_IN_WORDS, 32'd4);
            axi_write(REG_TILE_OUT_WORDS, 32'd16);
            axi_write(REG_TILE_OUT_OFFSET, 32'h0000_0100);

            serial_total = 0;
            serial_dma = 0;
            serial_compute = 0;
            serial_overlap = 0;
            serial_stall = 0;
            r20_dma_ar_bursts = 0;
            r20_dma_ar_bytes = 0;
            r20_dma_r_beats = 0;
            r20_dma_aw_bursts = 0;
            r20_dma_aw_bytes = 0;
            r20_dma_w_beats = 0;
            r20_dma_w_strobe_bytes = 0;
            r20_dma_b_responses = 0;
            r20_dma_first_ar_cycle = -1;
            r20_dma_last_r_cycle = -1;
            r20_dma_first_aw_cycle = -1;
            r20_dma_last_b_cycle = -1;
            r20_dma_ar_q_head = 0;
            r20_dma_ar_q_tail = 0;
            r20_dma_aw_q_head = 0;
            r20_dma_aw_q_tail = 0;
            r20_dma_read_latency_sum = 0;
            r20_dma_read_latency_max = 0;
            r20_dma_read_latency_count = 0;
            r20_dma_write_latency_sum = 0;
            r20_dma_write_latency_max = 0;
            r20_dma_write_latency_count = 0;
            r20_dma_monitor_enable = 1'b1;
            for (serial_tile = 0; serial_tile < 3; serial_tile = serial_tile + 1) begin
                axi_write(REG_TILE_COUNT, 32'd1);
                axi_write(REG_TILE_EXT_IN, 32'h0000_1400 + serial_tile*16);
                axi_write(REG_TILE_EXT_OUT, 32'h0000_2000 + serial_tile*64);
                axi_write(REG_PERF_CTRL, 32'd1);
                axi_write(REG_TILE_CTRL, 32'd1);
                fp_perf_wait_tile_done();
                axi_read(REG_PERF_TOTAL, perf_total);
                axi_read(REG_PERF_DMA, perf_dma);
                axi_read(REG_PERF_COMPUTE, perf_compute);
                axi_read(REG_PERF_OVERLAP, perf_overlap);
                axi_read(REG_PERF_STALL, perf_stall);
                serial_total = serial_total + perf_total;
                serial_dma = serial_dma + perf_dma;
                serial_compute = serial_compute + perf_compute;
                serial_overlap = serial_overlap + perf_overlap;
                serial_stall = serial_stall + perf_stall;
                expect_read(REG_TILE_COMPLETED, 32'd1,
                            "R9 serialized Matrix/DMA tile completed");
                for (word_index = 0; word_index < 16; word_index = word_index + 1)
                    if (axi_mem_u.mem[12'h800 + serial_tile*16 + word_index] !==
                        expected_words[serial_tile*16 + word_index])
                        $fatal(1, "R9 serialized Matrix/DMA Golden mismatch tile=%0d word=%0d expected=%08h actual=%08h",
                               serial_tile, word_index,
                               expected_words[serial_tile*16 + word_index],
                               axi_mem_u.mem[12'h800 + serial_tile*16 + word_index]);
                clear_done_irq();
            end

            r20_dma_monitor_enable = 1'b0;
            @(negedge aclk);
            serial_ar_bursts = r20_dma_ar_bursts;
            serial_ar_bytes = r20_dma_ar_bytes;
            serial_r_beats = r20_dma_r_beats;
            serial_aw_bursts = r20_dma_aw_bursts;
            serial_aw_bytes = r20_dma_aw_bytes;
            serial_w_beats = r20_dma_w_beats;
            serial_w_bytes = r20_dma_w_strobe_bytes;
            serial_b_responses = r20_dma_b_responses;
            serial_first_ar_cycle = r20_dma_first_ar_cycle;
            serial_last_r_cycle = r20_dma_last_r_cycle;
            serial_first_aw_cycle = r20_dma_first_aw_cycle;
            serial_last_b_cycle = r20_dma_last_b_cycle;
            serial_read_service_cycles = (serial_first_ar_cycle >= 0 &&
                serial_last_r_cycle >= serial_first_ar_cycle) ?
                serial_last_r_cycle - serial_first_ar_cycle + 1 : 0;
            serial_write_service_cycles = (serial_first_aw_cycle >= 0 &&
                serial_last_b_cycle >= serial_first_aw_cycle) ?
                serial_last_b_cycle - serial_first_aw_cycle + 1 : 0;
            serial_read_latency_sum = r20_dma_read_latency_sum;
            serial_read_latency_max = r20_dma_read_latency_max;
            serial_read_latency_count = r20_dma_read_latency_count;
            serial_write_latency_sum = r20_dma_write_latency_sum;
            serial_write_latency_max = r20_dma_write_latency_max;
            serial_write_latency_count = r20_dma_write_latency_count;

            r20_dma_ar_bursts = 0;
            r20_dma_ar_bytes = 0;
            r20_dma_r_beats = 0;
            r20_dma_aw_bursts = 0;
            r20_dma_aw_bytes = 0;
            r20_dma_w_beats = 0;
            r20_dma_w_strobe_bytes = 0;
            r20_dma_b_responses = 0;
            r20_dma_first_ar_cycle = -1;
            r20_dma_last_r_cycle = -1;
            r20_dma_first_aw_cycle = -1;
            r20_dma_last_b_cycle = -1;
            r20_dma_ar_q_head = 0;
            r20_dma_ar_q_tail = 0;
            r20_dma_aw_q_head = 0;
            r20_dma_aw_q_tail = 0;
            r20_dma_read_latency_sum = 0;
            r20_dma_read_latency_max = 0;
            r20_dma_read_latency_count = 0;
            r20_dma_write_latency_sum = 0;
            r20_dma_write_latency_max = 0;
            r20_dma_write_latency_count = 0;
            r20_dma_monitor_enable = 1'b1;
            axi_write(REG_TILE_COUNT, 32'd3);
            axi_write(REG_TILE_EXT_IN, 32'h0000_1400);
            axi_write(REG_TILE_EXT_OUT, 32'h0000_2000);
            axi_write(REG_PERF_CTRL, 32'd1);
            axi_write(REG_TILE_CTRL, 32'd1);
            fp_perf_wait_tile_done();
            r20_dma_monitor_enable = 1'b0;
            @(negedge aclk);
            overlap_ar_bursts = r20_dma_ar_bursts;
            overlap_ar_bytes = r20_dma_ar_bytes;
            overlap_r_beats = r20_dma_r_beats;
            overlap_aw_bursts = r20_dma_aw_bursts;
            overlap_aw_bytes = r20_dma_aw_bytes;
            overlap_w_beats = r20_dma_w_beats;
            overlap_w_bytes = r20_dma_w_strobe_bytes;
            overlap_b_responses = r20_dma_b_responses;
            overlap_first_ar_cycle = r20_dma_first_ar_cycle;
            overlap_last_r_cycle = r20_dma_last_r_cycle;
            overlap_first_aw_cycle = r20_dma_first_aw_cycle;
            overlap_last_b_cycle = r20_dma_last_b_cycle;
            overlap_read_service_cycles = (overlap_first_ar_cycle >= 0 &&
                overlap_last_r_cycle >= overlap_first_ar_cycle) ?
                overlap_last_r_cycle - overlap_first_ar_cycle + 1 : 0;
            overlap_write_service_cycles = (overlap_first_aw_cycle >= 0 &&
                overlap_last_b_cycle >= overlap_first_aw_cycle) ?
                overlap_last_b_cycle - overlap_first_aw_cycle + 1 : 0;
            overlap_read_latency_sum = r20_dma_read_latency_sum;
            overlap_read_latency_max = r20_dma_read_latency_max;
            overlap_read_latency_count = r20_dma_read_latency_count;
            overlap_write_latency_sum = r20_dma_write_latency_sum;
            overlap_write_latency_max = r20_dma_write_latency_max;
            overlap_write_latency_count = r20_dma_write_latency_count;

            axi_read(REG_PERF_TOTAL, perf_total);
            axi_read(REG_PERF_DMA, perf_dma);
            axi_read(REG_PERF_COMPUTE, perf_compute);
            axi_read(REG_PERF_OVERLAP, perf_overlap);
            axi_read(REG_PERF_STALL, perf_stall);
            expect_read(REG_TILE_COMPLETED, 32'd3,
                        "R9 Matrix/DMA pipeline completed tiles");

            for (tile_index = 0; tile_index < 3; tile_index = tile_index + 1)
                for (row_index = 0; row_index < 4; row_index = row_index + 1)
                    for (col_index = 0; col_index < 4; col_index = col_index + 1) begin
                        word_index = tile_index*16 + row_index*4 + col_index;
                        if (axi_mem_u.mem[12'h800 + word_index] !== expected_words[word_index])
                            $fatal(1, "R9 Matrix/DMA DDR Golden mismatch tile=%0d row=%0d col=%0d expected=%08h actual=%08h",
                                   tile_index, row_index, col_index,
                                   expected_words[word_index],
                                   axi_mem_u.mem[12'h800 + word_index]);
                    end
            // Check the last row in both ping-pong buffers independently of
            // the external AXI write image.
            for (tile_index = 0; tile_index < 2; tile_index = tile_index + 1)
                for (col_index = 0; col_index < 4; col_index = col_index + 1) begin
                    axi_read(SPAD_BASE + (tile_index ? 32'h0000_9000 : 32'h0000_8000) +
                             32'h0000_0100 + 48 + col_index*4, read_value);
                    // Tile 2 reuses buffer 0 after tile 0 has been stored.
                    expected_i = expected_words[(tile_index == 0 ? 2 : 1)*16 + 12 + col_index];
                    if (read_value !== expected_i)
                        $fatal(1, "R9 Matrix/DMA SPAD Golden mismatch buffer=%0d word=%0d expected=%08h actual=%08h",
                               tile_index, col_index, expected_i, read_value);
                end

            $display("R20_DMA_SERIALIZED tiles=3 shape=4x4x4 total=%0d dma=%0d compute=%0d overlap=%0d stall=%0d ar_bursts=%0d ar_bytes=%0d r_beats=%0d read_span_cycles=%0d read_latency_avg=%0d read_latency_max=%0d aw_bursts=%0d aw_bytes=%0d w_beats=%0d wstrb_bytes=%0d b_responses=%0d write_span_cycles=%0d write_latency_avg=%0d write_latency_max=%0d golden=bit-exact",
                     serial_total, serial_dma, serial_compute, serial_overlap,
                     serial_stall, serial_ar_bursts, serial_ar_bytes,
                     serial_r_beats, serial_read_service_cycles,
                     serial_read_latency_count != 0 ?
                        serial_read_latency_sum / serial_read_latency_count : 0,
                     serial_read_latency_max,
                     serial_aw_bursts, serial_aw_bytes, serial_w_beats,
                     serial_w_bytes, serial_b_responses,
                     serial_write_service_cycles,
                     serial_write_latency_count != 0 ?
                        serial_write_latency_sum / serial_write_latency_count : 0,
                     serial_write_latency_max);
            $display("R9_MATRIX_DMA_OVERLAP_PASS tiles=3 shape=4x4x4 total=%0d dma=%0d compute=%0d overlap=%0d stall=%0d ddr_and_spad_golden=bit-exact seed=%0d ar_bursts=%0d ar_bytes=%0d r_beats=%0d read_span_cycles=%0d read_latency_avg=%0d read_latency_max=%0d aw_bursts=%0d aw_bytes=%0d w_beats=%0d wstrb_bytes=%0d b_responses=%0d write_span_cycles=%0d write_latency_avg=%0d write_latency_max=%0d",
                     perf_total, perf_dma, perf_compute, perf_overlap, perf_stall,
                     profile_ai_seed, overlap_ar_bursts, overlap_ar_bytes,
                     overlap_r_beats, overlap_read_service_cycles,
                     overlap_read_latency_count != 0 ?
                        overlap_read_latency_sum / overlap_read_latency_count : 0,
                     overlap_read_latency_max,
                     overlap_aw_bursts, overlap_aw_bytes, overlap_w_beats,
                     overlap_w_bytes, overlap_b_responses,
                     overlap_write_service_cycles,
                     overlap_write_latency_count != 0 ?
                        overlap_write_latency_sum / overlap_write_latency_count : 0,
                     overlap_write_latency_max);
            clear_done_irq();
        end
    endtask

    task fp_perf_run_case;
        input format_fp16;
        input integer vector_length;
        // A one-tile job is the no-overlap baseline; three ping-pong tiles
        // create real DMA/compute overlap through the production scheduler.
        input integer tile_count;
        reg [31:0] expected;
        reg [31:0] tile_overlap_cycles;
        reg [31:0] tile_stall_cycles;
        integer seed_for_case;
        integer words_per_tile;
        integer tile_index;
        integer output_word_index;
        begin
            expected = fp_perf_expected_sum(vector_length);
            words_per_tile = (vector_length + 1) >> 1;
            fp_perf_seed_input_vectors(format_fp16, vector_length, tile_count);
            fp_perf_load_weights(format_fp16, words_per_tile);
            axi_write(REG_OP_MODE, format_fp16 ? 32'h51 : 32'h50);
            axi_write(REG_SRC1_BASE, 32'h0000_3000);
            axi_write(REG_LENGTH, vector_length);
            axi_write(REG_M_SIZE, 32'd1);
            axi_write(REG_N_SIZE, 32'd1);
            axi_write(REG_K_WORDS, vector_length);
            axi_write(REG_BIAS_BASE, 32'd0);
            axi_write(REG_POST_CTRL, 32'd0);
            axi_write(REG_QUANT_ACT, 32'd0);
            axi_write(REG_TILE_COUNT, tile_count);
            axi_write(REG_TILE_EXT_IN, 32'h0000_1000);
            axi_write(REG_TILE_EXT_OUT, 32'h0000_3800);
            axi_write(REG_TILE_EXT_IN_STRIDE, words_per_tile * 4);
            axi_write(REG_TILE_EXT_OUT_STRIDE, 32'd4);
            axi_write(REG_TILE_BUF0, 32'h0001_0000);
            axi_write(REG_TILE_BUF1, 32'h0001_3000);
            axi_write(REG_TILE_IN_WORDS, words_per_tile);
            axi_write(REG_TILE_OUT_WORDS, 32'd1);
            axi_write(REG_TILE_OUT_OFFSET, 32'h0000_1000);

            fp_perf_tile_job_cycles = 0;
            fp_perf_active_cycles = 0;
            fp_perf_compute_cycles = 0;
            fp_perf_fetch_stall_cycles = 0;
            fp_perf_response_wait_cycles = 0;
            fp_perf_write_wait_cycles = 0;
            fp_perf_dma_wait_cycles = 0;
            fp_perf_dma_grants = 0;
            seed_for_case = fp_perf_seed ^ vector_length ^ (format_fp16 ? 32'h16 : 32'h50) ^ tile_count;
            fp_perf_rng = seed_for_case;
            fp_perf_random_wready = (tile_count > 1);
            fp_perf_random_rvalid_latency = (tile_count > 1);
            if (tile_count == 1) begin
                axi_mem_u.ready_gap_cfg = 0;
                axi_mem_u.read_gap_cfg = 1;
            end
            fp_perf_measure = 1'b1;
            clear_done_irq();
            axi_write(REG_TILE_CTRL, 32'd1);
            fp_perf_wait_tile_done();
            @(negedge aclk);
            fp_perf_measure = 1'b0;
            fp_perf_random_wready = 1'b0;
            fp_perf_random_rvalid_latency = 1'b0;
            axi_mem_u.ready_gap_cfg = 0;
            axi_mem_u.read_gap_cfg = 1;
            axi_read(REG_PERF_OVERLAP, tile_overlap_cycles);
            axi_read(REG_PERF_STALL, tile_stall_cycles);
            expect_read(REG_RESULT, expected, "FP throughput benchmark result register");
            expect_read(REG_TILE_COMPLETED, tile_count, "FP tile benchmark completed tile count");
            for (tile_index = 0; tile_index < tile_count; tile_index = tile_index + 1) begin
                output_word_index = 12'hE00 + tile_index;
                if (axi_mem_u.mem[output_word_index] !== expected)
                    $fatal(1, "FP tile DDR result mismatch fmt=%0d len=%0d tile=%0d expected=%08h actual=%08h",
                           format_fp16, vector_length, tile_index, expected,
                           axi_mem_u.mem[output_word_index]);
            end
            if (tile_count > 1 && fp_perf_dma_grants == 0)
                $fatal(1, "FP tile ping-pong job showed no actual DMA SPAD grant during compute fmt=%0d len=%0d overlap=%0d",
                       format_fp16, vector_length, tile_overlap_cycles);
            $display("FP_SYSTEM_BENCH,actual_tile_pipeline,%s,%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0.5f,%0.5f,%0d",
                     (tile_count == 1) ? "single_tile" : "pingpong_random_rvalid_wready",
                     format_fp16 ? "FP16" : "BF16", vector_length, tile_count,
                     fp_perf_tile_job_cycles, fp_perf_active_cycles,
                     fp_perf_compute_cycles, fp_perf_fetch_stall_cycles,
                     fp_perf_response_wait_cycles, fp_perf_write_wait_cycles,
                     fp_perf_dma_wait_cycles, fp_perf_dma_grants,
                     tile_overlap_cycles, tile_stall_cycles,
                     (1.0 * tile_count * vector_length) / fp_perf_tile_job_cycles,
                     (1.0 * tile_count * vector_length) / fp_perf_active_cycles,
                     seed_for_case);
            clear_done_irq();
        end
    endtask

    task run_fp_dot_dma_benchmark;
        integer format_index;
        integer length_index;
        integer lengths [0:8];
        begin
            lengths[0]=1; lengths[1]=2; lengths[2]=3; lengths[3]=4;
            lengths[4]=16; lengths[5]=64; lengths[6]=128;
            lengths[7]=256; lengths[8]=1024;
            $display("FP_SYSTEM_BENCH_HEADER,source,mode,format,length,tiles,tile_job_cycles,fp_active_cycles,compute_macs,fp_request_wait_cycles,response_wait_cycles,result_write_wait_cycles,dma_spad_wait_cycles,dma_spad_grants,tile_overlap_cycles,tile_stall_cycles,mac_per_tile_job_cycle,mac_per_fp_active_cycle,seed");
            for (format_index=0; format_index<2; format_index=format_index+1) begin
                for (length_index=0; length_index<9; length_index=length_index+1)
                    fp_perf_run_case(format_index != 0, lengths[length_index], 1);
                // Larger jobs expose DMA/SPAD contention through the real
                // two-context ping-pong pipeline; WREADY uses a seeded LCG.
                fp_perf_run_case(format_index != 0, 64, 3);
                fp_perf_run_case(format_index != 0, 256, 3);
                fp_perf_run_case(format_index != 0, 1024, 3);
            end
            $display("PASS: real ai_tile_pipeline + ai_axi128_dma + ai_spad_arbiter FP benchmark (behavioral AXI memory model)");
        end
    endtask

    task write_spad_desc_v4_macro;
        input [31:0] base;
        input [7:0]  op;
        input [15:0] task_id;
        input [31:0] child_base;
        input [15:0] child_count;
        input        child_external;
        input [15:0] wait_mask;
        input [15:0] signal_mask;
        input [15:0] clear_mask;
        integer i;
        begin
            for (i = 0; i < 16; i = i + 1)
                axi_write(SPAD_BASE + base + (i << 2), 32'd0);
            axi_write(SPAD_BASE + base + 32'h00, {task_id, 8'd0, op});
            axi_write(SPAD_BASE + base + 32'h04, child_base);
            axi_write(SPAD_BASE + base + 32'h18, {16'd0, child_count});
            axi_write(SPAD_BASE + base + 32'h1c, {28'd0, child_external, 3'd0});
            axi_write(SPAD_BASE + base + 32'h38, {signal_mask, wait_mask});
            axi_write(SPAD_BASE + base + 32'h3c, {clear_mask, 8'd0, 8'd4});
        end
    endtask

    task expect_completion;
        input [31:0] base;
        input [15:0] task_id;
        input [3:0]  status;
        input [3:0]  error_code;
        input [31:0] result;
        input [31:0] elements;
        input [511:0] name;
        begin
            expect_read(SPAD_BASE + base + 32'h00, {16'd0, task_id}, name);
            expect_read(SPAD_BASE + base + 32'h04, {24'd0, error_code, status}, name);
            expect_read(SPAD_BASE + base + 32'h08, result, name);
            expect_read(SPAD_BASE + base + 32'h0c, elements, name);
        end
    endtask

    task wait_cpl_tail;
        input [31:0] expected_tail;
        input [511:0] name;
        begin
            integer i;
            integer found;
            found = 0;
            for (i = 0; i < 5000; i = i + 1) begin
                if (!found) begin
                    axi_read(REG_CPLQ_TAIL, rd);
                    if (rd === expected_tail)
                        found = 1;
                end
            end
            if (!found) begin
                $display("%0t ERROR: %0s expected tail=%0d actual=%0d/%08h",
                         $time, name, expected_tail, rd, rd);
                errors = errors + 1;
            end else begin
                $display("%0t PASS: %0s tail=%0d/%08h", $time, name, rd, rd);
            end
        end
    endtask

    task run_ai_digits_inference;
        reg [1023:0] image_file;
        reg [1023:0] expected_file;
        reg [1023:0] hidden_file;
        reg [1023:0] rtl_csv_file;
        integer image_count;
        integer expected_count;
        integer hidden_count;
        integer image_index;
        integer poll_index;
        integer completion_index;
        integer hidden_index;
        integer sample_index;
        integer class_index;
        integer expected_index;
        integer sfu_batch_index;
        integer correct_samples;
        integer sample_label;
        integer prediction;
        integer csv_fd;
        reg completed;
        reg [31:0] read_value;
        reg signed [31:0] best_logit;
        reg [31:0] cmd_head;
        reg [31:0] cpl_tail;
        real mac_count;
        real mac_per_cycle;
        real array_utilization;
        begin
            if (!$value$plusargs("AI_DIGITS_MEMORY=%s", image_file) ||
                !$value$plusargs("AI_DIGITS_EXPECTED=%s", expected_file) ||
                !$value$plusargs("AI_DIGITS_HIDDEN=%s", hidden_file) ||
                !$value$plusargs("AI_DIGITS_RTL_CSV=%s", rtl_csv_file))
                $fatal(1, "AI_DIGITS_INFERENCE requires memory, expected, hidden and RTL CSV paths");

            $readmemh(image_file, ai_digits_image_words);
            $readmemh(expected_file, ai_digits_expected_words);
            $readmemh(hidden_file, ai_digits_hidden_words);
            image_count = ai_digits_image_words[0];
            expected_count = ai_digits_expected_words[0];
            hidden_count = ai_digits_hidden_words[0];
            if (image_count <= 0 || image_count > 16000 ||
                expected_count != AI_DIGITS_TEST_SAMPLES ||
                hidden_count != AI_DIGITS_HIDDEN_WORDS)
                $fatal(1, "digits image sizes invalid image=%0d expected=%0d hidden=%0d",
                       image_count, expected_count, hidden_count);

            $display("DIGITS_LOAD_BEGIN spad_words=%0d samples=%0d", image_count,
                     expected_count);
            for (image_index = 0; image_index < image_count; image_index = image_index + 1) begin
                if (ai_digits_image_words[1 + 2 * image_index] >= SPAD_BYTES ||
                    ai_digits_image_words[1 + 2 * image_index][1:0] != 2'b00) begin
                    $display("ERROR: digits image has invalid SPAD offset index=%0d addr=%08h",
                             image_index, ai_digits_image_words[1 + 2 * image_index]);
                    errors = errors + 1;
                end else begin
                    axi_write(SPAD_BASE + ai_digits_image_words[1 + 2 * image_index],
                              ai_digits_image_words[2 + 2 * image_index]);
                end
            end
            $display("DIGITS_LOAD_DONE spad_words=%0d", image_count);

            // Prove the output region starts with the poison pattern loaded by
            // the host image. The only writer after this point is the DUT.
            axi_read(SPAD_BASE + AI_DIGITS_OUTPUT_BASE, read_value);
            if (read_value !== 32'ha55a_a55a) begin
                $display("ERROR: digits output was not poison before dispatch: %08h", read_value);
                errors = errors + 1;
            end

            axi_write(REG_CMDQ_CTRL, 32'd0);
            axi_write(REG_CMDQ_BASE_LO, AI_DIGITS_DESC_BASE);
            axi_write(REG_CMDQ_SIZE, 32'd128);
            axi_write(REG_CMDQ_HEAD, 32'd0);
            for (sfu_batch_index = 0; sfu_batch_index < 23; sfu_batch_index = sfu_batch_index + 1)
                ai_digits_fused_lines_by_batch[sfu_batch_index] = 0;
            axi_write(REG_CMDQ_TAIL, AI_DIGITS_DESC_COUNT);
            axi_write(REG_CPLQ_BASE_LO, AI_DIGITS_CPL_BASE);
            axi_write(REG_CPLQ_SIZE, 32'd128);
            axi_write(REG_CPLQ_HEAD, 32'd0);
            axi_write(REG_CPLQ_TAIL, 32'd0);

            ai_digits_cycles = 0;
            ai_digits_layout_cycles = 0;
            ai_digits_layout_bytes = 0;
            ai_digits_measure = 1'b1;
            ai_digits_layout_measure = 1'b1;
            axi_write(REG_DOORBELL, 32'd1);
            completed = 1'b0;
            for (poll_index = 0; poll_index < 20000 && !completed; poll_index = poll_index + 1) begin
                repeat (32) @(posedge aclk);
                axi_read(REG_CPLQ_TAIL, cpl_tail);
                if (cpl_tail == AI_DIGITS_DESC_COUNT)
                    completed = 1'b1;
            end
            ai_digits_measure = 1'b0;
            ai_digits_layout_measure = 1'b0;
            if (!completed) begin
                $display("ERROR: digits inference completion timeout tail=%0d", cpl_tail);
                errors = errors + 1;
            end
            axi_read(REG_CMDQ_HEAD, cmd_head);
            if (cmd_head !== AI_DIGITS_DESC_COUNT) begin
                $display("ERROR: digits CMDQ head=%0d expected=%0d", cmd_head,
                         AI_DIGITS_DESC_COUNT);
                errors = errors + 1;
            end

            // The complete workload runs from the real CMDQ. Matrix opcode
            // 0x53 writes the hidden activation directly in Matrix-A tile order.
            for (completion_index = 0; completion_index < AI_DIGITS_DESC_COUNT;
                 completion_index = completion_index + 1) begin
                axi_read(SPAD_BASE + AI_DIGITS_CPL_BASE + completion_index * 16,
                         read_value);
                if (read_value !== (32'h0000_d000 + completion_index)) begin
                    $display("ERROR: digits CPLQ[%0d] task id=%08h", completion_index,
                             read_value);
                    errors = errors + 1;
                end
                axi_read(SPAD_BASE + AI_DIGITS_CPL_BASE + completion_index * 16 + 4,
                         read_value);
                if (read_value !== 32'h0000_0001) begin
                    $display("ERROR: digits CPLQ[%0d] status/error=%08h", completion_index,
                             read_value);
                    errors = errors + 1;
                end
            end

            for (sfu_batch_index = 0; sfu_batch_index < 23; sfu_batch_index = sfu_batch_index + 1) begin
                if (ai_digits_fused_lines_by_batch[sfu_batch_index] != 64) begin
                    $display("ERROR: digits fused tile lines batch=%0d got=%0d expected=64",
                             sfu_batch_index,
                             ai_digits_fused_lines_by_batch[sfu_batch_index]);
                    errors = errors + 1;
                end
            end

            for (hidden_index = 0; hidden_index < AI_DIGITS_HIDDEN_WORDS;
                 hidden_index = hidden_index + 1) begin
                axi_read(SPAD_BASE + AI_DIGITS_HIDDEN_I8_TILE_BASE + hidden_index * 4,
                         read_value);
                if (read_value !== ai_digits_hidden_words[1 + hidden_index]) begin
                    if (errors < 20)
                        $display("ERROR: digits tile hidden word[%0d] rtl=%08h golden=%08h",
                                 hidden_index, read_value,
                                 ai_digits_hidden_words[1 + hidden_index]);
                    errors = errors + 1;
                end
            end

            csv_fd = $fopen(rtl_csv_file, "w");
            if (csv_fd == 0)
                $fatal(1, "cannot open digits RTL CSV %0s", rtl_csv_file);
            expected_index = 1;
            correct_samples = 0;
            for (sample_index = 0; sample_index < AI_DIGITS_TEST_SAMPLES; sample_index = sample_index + 1) begin
                sample_label = ai_digits_expected_words[expected_index];
                expected_index = expected_index + 1;
                best_logit = -32'sh8000_0000;
                prediction = 0;
                for (class_index = 0; class_index < 12; class_index = class_index + 1) begin
                    axi_read(SPAD_BASE + AI_DIGITS_OUTPUT_BASE +
                             ((sample_index * 16 + class_index) * 4), read_value);
                    if (class_index < 12) begin
                        if (read_value !== ai_digits_expected_words[expected_index]) begin
                            if (errors < 20)
                                $display("ERROR: digits logit sample=%0d class=%0d rtl=%08h golden=%08h",
                                         sample_index, class_index, read_value,
                                         ai_digits_expected_words[expected_index]);
                            errors = errors + 1;
                        end
                        if (class_index == 0)
                            $fwrite(csv_fd, "%0d", $signed(read_value));
                        else
                            $fwrite(csv_fd, ",%0d", $signed(read_value));
                        expected_index = expected_index + 1;
                    end else if (read_value !== 32'd0) begin
                        if (errors < 20)
                            $display("ERROR: digits padded logit sample=%0d class=%0d rtl=%08h expected=00000000",
                                     sample_index, class_index, read_value);
                        errors = errors + 1;
                    end
                    if (class_index < 10 && $signed(read_value) > best_logit) begin
                        best_logit = $signed(read_value);
                        prediction = class_index;
                    end
                end
                $fwrite(csv_fd, "\n");
                if (prediction == sample_label)
                    correct_samples = correct_samples + 1;
            end
            $fclose(csv_fd);
            if (expected_index != expected_count * 13 + 1) begin
                $display("ERROR: digits expected vector consumption=%0d count=%0d",
                         expected_index, expected_count);
                errors = errors + 1;
            end

            mac_count = 23.0 * ((16.0 * 64.0 * 64.0) + (16.0 * 64.0 * 16.0));
            if (ai_digits_cycles == 0)
                mac_per_cycle = 0.0;
            else
                mac_per_cycle = mac_count / ai_digits_cycles;
            array_utilization = mac_per_cycle / 256.0;
            $display("DIGITS_RTL_METRICS samples=%0d correct=%0d descriptors=%0d cycles=%0d rtl_fused_matrix_cycles=%0d rtl_fused_tile_write_bytes=%0d mac=%0.0f mac_per_cycle=%0.4f array_utilization=%0.2f%% spad_initialization_bytes=%0d",
                     AI_DIGITS_TEST_SAMPLES, correct_samples, AI_DIGITS_DESC_COUNT,
                     ai_digits_cycles, ai_digits_layout_cycles, ai_digits_layout_bytes,
                     mac_count, mac_per_cycle,
                     array_utilization * 100.0, image_count * 4);
            if (errors == 0)
                $display("DIGITS_INFERENCE_PASS model=sklearn_digits_int8 rtl=top_spad_cmdq_cplq accuracy=%0.2f%%",
                         (100.0 * correct_samples) / AI_DIGITS_TEST_SAMPLES);
            axi_write(REG_CMDQ_SIZE, 32'd0);
            axi_write(REG_CPLQ_SIZE, 32'd0);
            clear_done_irq();
        end
    endtask

    task check_tinynpu_cnn_conv_golden;
        inout integer expected_index;
        integer expected_length;
        integer row_index;
        reg [31:0] read_value;
        begin
            expected_length = ai_tinynpu_cnn_expected_words[expected_index];
            expected_index = expected_index + 1;
            if (expected_length != 144) $fatal(1, "bad conv rounded Golden length");
            for (row_index = 0; row_index < expected_length; row_index = row_index + 1) begin
                axi_read(SPAD_BASE + AI_TINYNPU_CNN_CONV_RAW_BASE + row_index * 4, read_value);
                if (read_value !== ai_tinynpu_cnn_expected_words[expected_index])
                    $fatal(1, "CNN conv rounded output[%0d]=%08h expected=%08h", row_index,
                           read_value, ai_tinynpu_cnn_expected_words[expected_index]);
                expected_index = expected_index + 1;
            end
            expected_length = ai_tinynpu_cnn_expected_words[expected_index];
            expected_index = expected_index + 1;
            if (expected_length != 36) $fatal(1, "bad conv INT8 Golden length");
            for (row_index = 0; row_index < expected_length; row_index = row_index + 1) begin
                axi_read(SPAD_BASE + AI_TINYNPU_CNN_CONV_I8_BASE + row_index * 4, read_value);
                if (read_value !== ai_tinynpu_cnn_expected_words[expected_index])
                    $fatal(1, "CNN conv INT8 packed[%0d]=%08h expected=%08h", row_index,
                           read_value, ai_tinynpu_cnn_expected_words[expected_index]);
                expected_index = expected_index + 1;
            end
            expected_length = ai_tinynpu_cnn_expected_words[expected_index];
            expected_index = expected_index + 1;
            if (expected_length != 144) $fatal(1, "bad conv bias/ReLU Golden length");
            for (row_index = 0; row_index < expected_length; row_index = row_index + 1) begin
                axi_read(SPAD_BASE + AI_TINYNPU_CNN_CONV_BIAS_RELU_BASE + row_index * 4,
                         read_value);
                if (read_value !== ai_tinynpu_cnn_expected_words[expected_index])
                    $fatal(1, "CNN conv bias/ReLU output[%0d]=%08h expected=%08h", row_index,
                           read_value, ai_tinynpu_cnn_expected_words[expected_index]);
                expected_index = expected_index + 1;
            end
            expected_length = ai_tinynpu_cnn_expected_words[expected_index];
            expected_index = expected_index + 1;
            if (expected_length != 36) $fatal(1, "bad conv ReLU packed Golden length");
            for (row_index = 0; row_index < expected_length; row_index = row_index + 1) begin
                axi_read(SPAD_BASE + AI_TINYNPU_CNN_CONV_RELU_I8_BASE + row_index * 4,
                         read_value);
                if (read_value !== ai_tinynpu_cnn_expected_words[expected_index])
                    $fatal(1, "CNN conv ReLU packed[%0d]=%08h expected=%08h", row_index,
                           read_value, ai_tinynpu_cnn_expected_words[expected_index]);
                expected_index = expected_index + 1;
            end
        end
    endtask

    task check_tinynpu_cnn_linearized_golden;
        inout integer expected_index;
        integer expected_length;
        integer row_index;
        reg [31:0] read_value;
        begin
            expected_length = ai_tinynpu_cnn_expected_words[expected_index];
            expected_index = expected_index + 1;
            if (expected_length != 144) $fatal(1, "bad conv rounded Golden length");
            for (row_index = 0; row_index < expected_length; row_index = row_index + 1) begin
                axi_read(SPAD_BASE + AI_TINYNPU_CNN_CONV_RAW_BASE + row_index * 4,
                         read_value);
                if (read_value !== ai_tinynpu_cnn_expected_words[expected_index])
                    $fatal(1, "CNN conv rounded output[%0d]=%08h expected=%08h",
                           row_index, read_value,
                           ai_tinynpu_cnn_expected_words[expected_index]);
                expected_index = expected_index + 1;
            end
            expected_length = ai_tinynpu_cnn_expected_words[expected_index];
            expected_index = expected_index + 1;
            if (expected_length != 36) $fatal(1, "bad conv INT8 Golden length");
            for (row_index = 0; row_index < expected_length; row_index = row_index + 1) begin
                axi_read(SPAD_BASE + AI_TINYNPU_CNN_CONV_I8_BASE + row_index * 4,
                         read_value);
                if (read_value !== ai_tinynpu_cnn_expected_words[expected_index])
                    $fatal(1, "CNN conv INT8 packed[%0d]=%08h expected=%08h",
                           row_index, read_value,
                           ai_tinynpu_cnn_expected_words[expected_index]);
                expected_index = expected_index + 1;
            end
            expected_length = ai_tinynpu_cnn_expected_words[expected_index];
            expected_index = expected_index + 1;
            if (expected_length != 144)
                $fatal(1, "bad fused bias/ReLU source Golden length");
            // This INT32 tensor is intentionally not materialized by 0x53.
            // Its independently generated values are consumed as the Golden
            // source for the fused INT8 output checked below.
            expected_index = expected_index + expected_length;
            expected_length = ai_tinynpu_cnn_expected_words[expected_index];
            expected_index = expected_index + 1;
            if (expected_length != 36)
                $fatal(1, "bad linearized conv output Golden length");
            for (row_index = 0; row_index < expected_length; row_index = row_index + 1) begin
                axi_read(SPAD_BASE + AI_TINYNPU_CNN_FC_A_BASE + row_index * 16,
                         read_value);
                if (read_value !== ai_tinynpu_cnn_expected_words[expected_index])
                    $fatal(1, "CNN linearized fused output[%0d]=%08h expected=%08h",
                           row_index, read_value,
                           ai_tinynpu_cnn_expected_words[expected_index]);
                expected_index = expected_index + 1;
                axi_read(SPAD_BASE + AI_TINYNPU_CNN_FC_A_BASE + row_index * 16 + 4,
                         read_value);
                if (read_value !== 32'd0)
                    $fatal(1, "CNN linearized fused padding[%0d][1]=%08h",
                           row_index, read_value);
                axi_read(SPAD_BASE + AI_TINYNPU_CNN_FC_A_BASE + row_index * 16 + 8,
                         read_value);
                if (read_value !== 32'd0)
                    $fatal(1, "CNN linearized fused padding[%0d][2]=%08h",
                           row_index, read_value);
                axi_read(SPAD_BASE + AI_TINYNPU_CNN_FC_A_BASE + row_index * 16 + 12,
                         read_value);
                if (read_value !== 32'd0)
                    $fatal(1, "CNN linearized fused padding[%0d][3]=%08h",
                           row_index, read_value);
            end
        end
    endtask

    task check_tinynpu_cnn_fused_native_golden;
        inout integer expected_index;
        integer expected_length;
        integer row_index;
        reg [31:0] read_value;
        begin
            expected_length = ai_tinynpu_cnn_expected_words[expected_index];
            expected_index = expected_index + 1;
            if (expected_length != 144) $fatal(1, "bad conv rounded Golden length");
            for (row_index = 0; row_index < expected_length; row_index = row_index + 1) begin
                axi_read(SPAD_BASE + AI_TINYNPU_CNN_CONV_RAW_BASE + row_index * 4,
                         read_value);
                if (read_value !== ai_tinynpu_cnn_expected_words[expected_index])
                    $fatal(1, "CNN conv rounded output[%0d]=%08h expected=%08h",
                           row_index, read_value,
                           ai_tinynpu_cnn_expected_words[expected_index]);
                expected_index = expected_index + 1;
            end
            expected_length = ai_tinynpu_cnn_expected_words[expected_index];
            expected_index = expected_index + 1;
            if (expected_length != 36) $fatal(1, "bad conv INT8 Golden length");
            for (row_index = 0; row_index < expected_length; row_index = row_index + 1) begin
                axi_read(SPAD_BASE + AI_TINYNPU_CNN_CONV_I8_BASE + row_index * 4,
                         read_value);
                if (read_value !== ai_tinynpu_cnn_expected_words[expected_index])
                    $fatal(1, "CNN conv INT8 packed[%0d]=%08h expected=%08h",
                           row_index, read_value,
                           ai_tinynpu_cnn_expected_words[expected_index]);
                expected_index = expected_index + 1;
            end
            expected_length = ai_tinynpu_cnn_expected_words[expected_index];
            expected_index = expected_index + 1;
            if (expected_length != 144)
                $fatal(1, "bad fused bias/ReLU source Golden length");
            // The fused opcode deliberately does not materialize the INT32
            // bias/Requant intermediate; retain its independent Golden entry.
            expected_index = expected_index + expected_length;
            expected_length = ai_tinynpu_cnn_expected_words[expected_index];
            expected_index = expected_index + 1;
            if (expected_length != 36) $fatal(1, "bad fused native output Golden length");
            for (row_index = 0; row_index < expected_length; row_index = row_index + 1) begin
                axi_read(SPAD_BASE + AI_TINYNPU_CNN_CONV_RELU_I8_BASE + row_index * 4,
                         read_value);
                if (read_value !== ai_tinynpu_cnn_expected_words[expected_index])
                    $fatal(1, "CNN fused native output[%0d]=%08h expected=%08h",
                           row_index, read_value,
                           ai_tinynpu_cnn_expected_words[expected_index]);
                expected_index = expected_index + 1;
            end
        end
    endtask

    task check_tinynpu_cnn_fc_group;
        input integer group_index;
        inout integer expected_index;
        integer expected_length;
        integer row_index;
        reg [31:0] read_value;
        begin
            expected_length = ai_tinynpu_cnn_expected_words[expected_index];
            expected_index = expected_index + 1;
            if (expected_length != 16) $fatal(1, "bad FC rounded Golden length");
            for (row_index = 0; row_index < expected_length; row_index = row_index + 1) begin
                axi_read(SPAD_BASE + AI_TINYNPU_CNN_FC_RAW_BASE + row_index * 4, read_value);
                if (read_value !== ai_tinynpu_cnn_expected_words[expected_index])
                    $fatal(1, "CNN FC rounded group=%0d output[%0d]=%08h expected=%08h",
                           group_index, row_index, read_value,
                           ai_tinynpu_cnn_expected_words[expected_index]);
                expected_index = expected_index + 1;
            end
            expected_length = ai_tinynpu_cnn_expected_words[expected_index];
            expected_index = expected_index + 1;
            if (expected_length != 4) $fatal(1, "bad FC INT8 Golden length");
            for (row_index = 0; row_index < expected_length; row_index = row_index + 1) begin
                axi_read(SPAD_BASE + AI_TINYNPU_CNN_FC_I8_BASE + row_index * 4, read_value);
                if (read_value !== ai_tinynpu_cnn_expected_words[expected_index])
                    $fatal(1, "CNN FC INT8 group=%0d packed[%0d]=%08h expected=%08h",
                           group_index, row_index, read_value,
                           ai_tinynpu_cnn_expected_words[expected_index]);
                expected_index = expected_index + 1;
            end
            expected_length = ai_tinynpu_cnn_expected_words[expected_index];
            expected_index = expected_index + 1;
            if (expected_length != 16) $fatal(1, "bad FC bias Golden length");
            for (row_index = 0; row_index < expected_length; row_index = row_index + 1) begin
                axi_read(SPAD_BASE + AI_TINYNPU_CNN_FC_BIASED_BASE + row_index * 4,
                         read_value);
                if (read_value !== ai_tinynpu_cnn_expected_words[expected_index])
                    $fatal(1, "CNN FC biased group=%0d output[%0d]=%08h expected=%08h",
                           group_index, row_index, read_value,
                           ai_tinynpu_cnn_expected_words[expected_index]);
                expected_index = expected_index + 1;
            end
            expected_length = ai_tinynpu_cnn_expected_words[expected_index];
            expected_index = expected_index + 1;
            if (expected_length != 4) $fatal(1, "bad final CNN Golden length");
            for (row_index = 0; row_index < expected_length; row_index = row_index + 1) begin
                axi_read(SPAD_BASE + AI_TINYNPU_CNN_FINAL_I8_BASE +
                         group_index * 16 + row_index * 4, read_value);
                if (read_value !== ai_tinynpu_cnn_expected_words[expected_index])
                    $fatal(1, "CNN final group=%0d packed[%0d]=%08h expected=%08h",
                           group_index, row_index, read_value,
                           ai_tinynpu_cnn_expected_words[expected_index]);
                expected_index = expected_index + 1;
            end
        end
    endtask

    task run_tinynpu_cnn_match;
        reg [1023:0] image_file;
        reg [1023:0] expected_file;
        integer image_count;
        integer expected_count;
        integer image_index;
        integer expected_index;
        integer expected_length;
        integer poll_index;
        integer completion_index;
        integer row_index;
        integer feature_group;
        integer descriptor_index;
        integer group_index;
        integer num_classes;
        integer output_group_count;
        integer descriptor_count;
        integer tail_value;
        integer event_base;
        integer conv_descriptor_count;
        reg completed;
        reg linearized_mode;
        reg fused_native_mode;
        reg [31:0] read_value;
        reg [31:0] cpl_tail;
        reg [31:0] cmd_head;
        begin
            if (!$value$plusargs("AI_TINYNPU_CNN_MEMORY=%s", image_file) ||
                !$value$plusargs("AI_TINYNPU_CNN_EXPECTED=%s", expected_file))
                $fatal(1, "TINYNPU_CNN_MATCH requires memory and expected paths");
            num_classes = 4;
            if (!$value$plusargs("AI_TINYNPU_CNN_CLASSES=%d", num_classes))
                num_classes = 4;
            if (num_classes != 4 && num_classes != 10)
                $fatal(1, "CNN class count must be 4 or 10, got %0d", num_classes);
            linearized_mode = $test$plusargs("AI_TINYNPU_CNN_LINEARIZED");
            fused_native_mode = $test$plusargs("AI_TINYNPU_CNN_FUSED_NATIVE");
            if (linearized_mode && fused_native_mode)
                $fatal(1, "CNN fused output modes are mutually exclusive");
            output_group_count = (num_classes + 3) / 4;
            conv_descriptor_count = (linearized_mode || fused_native_mode) ? 3 : 4;
            descriptor_count = conv_descriptor_count + 4 * output_group_count;
            expected_count = 360 + 40 * output_group_count;
            $readmemh(image_file, ai_tinynpu_cnn_image_words);
            $readmemh(expected_file, ai_tinynpu_cnn_expected_words);
            image_count = ai_tinynpu_cnn_image_words[0];
            if (image_count <= 0 || image_count > 4095 ||
                ai_tinynpu_cnn_expected_words[0] != expected_count)
                $fatal(1, "TinyNPU CNN input sizes invalid image=%0d expected=%0d classes=%0d",
                       image_count, ai_tinynpu_cnn_expected_words[0], num_classes);

            for (image_index = 0; image_index < image_count; image_index = image_index + 1) begin
                if (ai_tinynpu_cnn_image_words[1 + image_index * 2] >= SPAD_BYTES ||
                    ai_tinynpu_cnn_image_words[1 + image_index * 2][1:0] != 2'b00)
                    $fatal(1, "TinyNPU CNN bad SPAD image address index=%0d", image_index);
                axi_write(SPAD_BASE + ai_tinynpu_cnn_image_words[1 + image_index * 2],
                          ai_tinynpu_cnn_image_words[2 + image_index * 2]);
            end

            axi_read(SPAD_BASE + AI_TINYNPU_CNN_FINAL_I8_BASE, read_value);
            if (read_value !== 32'ha55a_a55a)
                $fatal(1, "TinyNPU CNN final output was not poisoned: %08h", read_value);

            write_spad_desc_v3(AI_TINYNPU_CNN_DESC_BASE, OP_TENSOR_GEMM,
                   16'hd500, AI_TINYNPU_CNN_IM2COL_BASE,
                   AI_TINYNPU_CNN_CONV_WEIGHT_BASE,
                   AI_TINYNPU_CNN_CONV_ROUND_BASE, AI_TINYNPU_CNN_CONV_RAW_BASE,
                   16'd36, 16'd4, 16'd3, 8'h01, 32'd0, 5'd4, 2'd0,
                   32'd0, 32'd0, 32'd0, 16'd1, 16'd1, 16'd0, 16'd1, 16'd0);
            write_spad_desc_v3(AI_TINYNPU_CNN_DESC_BASE + 32'h40,
                   OP_REQUANT_I8, 16'hd501, AI_TINYNPU_CNN_CONV_RAW_BASE,
                   32'd0, 32'd0, AI_TINYNPU_CNN_CONV_I8_BASE,
                   16'd0, 16'd0, 16'd144, 8'h10, 32'd0, 5'd0, 2'd0,
                   32'd0, 32'd0, 32'd0, 16'd1, 16'd1, 16'd1, 16'd2, 16'd1);
            if (linearized_mode || fused_native_mode) begin
                write_spad_desc_v3(AI_TINYNPU_CNN_DESC_BASE + 32'h80,
                       OP_TENSOR_GEMM_FUSED, 16'hd502,
                       AI_TINYNPU_CNN_CONV_I8_BASE,
                       AI_TINYNPU_CNN_IDENTITY_B_BASE,
                       AI_TINYNPU_CNN_CONV_BIAS_BASE,
                       linearized_mode ? AI_TINYNPU_CNN_FC_A_BASE :
                                         AI_TINYNPU_CNN_CONV_RELU_I8_BASE,
                       16'd36, 16'd4, 16'd1, 8'h01,
                       linearized_mode ? 32'h0000_0080 : 32'd0,
                       5'd0, 2'd1, 32'd0, 32'd0, 32'd0, 16'd1, 16'd1,
                       16'd2, 16'd8, 16'd2);
                // Opcode 0x53 uses the ABI-v7 descriptor extension in both
                // native and linear-row output modes.
                axi_write(SPAD_BASE + AI_TINYNPU_CNN_DESC_BASE + 32'hbc,
                          {16'd2, 8'd0, 8'd7});
            end else begin
                write_spad_desc_v3(AI_TINYNPU_CNN_DESC_BASE + 32'h80,
                       OP_TENSOR_GEMM, 16'hd502, AI_TINYNPU_CNN_CONV_I8_BASE,
                       AI_TINYNPU_CNN_IDENTITY_B_BASE,
                       AI_TINYNPU_CNN_CONV_BIAS_BASE,
                       AI_TINYNPU_CNN_CONV_BIAS_RELU_BASE,
                       16'd36, 16'd4, 16'd1, 8'h01, 32'd0, 5'd0, 2'd1,
                       32'd0, 32'd0, 32'd0, 16'd1, 16'd1, 16'd2, 16'd4, 16'd2);
                write_spad_desc_v3(AI_TINYNPU_CNN_DESC_BASE + 32'hc0,
                       OP_REQUANT_I8, 16'hd503,
                       AI_TINYNPU_CNN_CONV_BIAS_RELU_BASE,
                       32'd0, 32'd0, AI_TINYNPU_CNN_CONV_RELU_I8_BASE,
                       16'd0, 16'd0, 16'd144, 8'h10, 32'd0, 5'd0, 2'd0,
                       32'd0, 32'd0, 32'd0, 16'd1, 16'd1, 16'd4, 16'd8, 16'd4);
            end

            axi_write(REG_CMDQ_CTRL, 32'd0);
            axi_write(REG_CMDQ_BASE_LO, AI_TINYNPU_CNN_DESC_BASE);
            axi_write(REG_CMDQ_SIZE, 32'd32);
            axi_write(REG_CMDQ_HEAD, 32'd0);
            axi_write(REG_CMDQ_TAIL, 32'd0);
            axi_write(REG_CPLQ_BASE_LO, AI_TINYNPU_CNN_CPL_BASE);
            axi_write(REG_CPLQ_SIZE, 32'd32);
            axi_write(REG_CPLQ_HEAD, 32'd0);
            axi_write(REG_CPLQ_TAIL, 32'd0);
            ai_tinynpu_cnn_cycles = 0;
            ai_tinynpu_cnn_layout_cycles = 0;
            ai_tinynpu_cnn_engine_read_words = 0;
            ai_tinynpu_cnn_engine_write_words = 0;
            ai_tinynpu_cnn_banked_read_lines = 0;
            ai_tinynpu_cnn_line_write_lines = 0;
            ai_tinynpu_cnn_measure = 1'b1;
            axi_write(REG_CMDQ_TAIL, conv_descriptor_count);
            axi_write(REG_DOORBELL, 32'd1);
            completed = 1'b0;
            for (poll_index = 0; poll_index < 10000 && !completed;
                 poll_index = poll_index + 1) begin
                repeat (32) @(posedge aclk);
                axi_read(REG_CPLQ_TAIL, cpl_tail);
                if (cpl_tail == conv_descriptor_count)
                    completed = 1'b1;
            end
            ai_tinynpu_cnn_measure = 1'b0;
            if (!completed)
                $fatal(1, "TinyNPU CNN convolution completion timeout tail=%0d", cpl_tail);

            expected_index = 1;
            if (linearized_mode || fused_native_mode) begin
                axi_read(SPAD_BASE + AI_TINYNPU_CNN_CPL_BASE + 36, read_value);
                if (read_value[3:0] != 4'd1 || read_value[7:4] != 4'd0)
                    $fatal(1, "CNN fused completion status/error=%08h", read_value);
                axi_read(SPAD_BASE + AI_TINYNPU_CNN_CPL_BASE + 44, read_value);
                if (read_value != 32'd144)
                    $fatal(1, "CNN fused completion elements=%0d expected=144",
                           read_value);
                if (linearized_mode) begin
                    axi_read(SPAD_BASE + AI_TINYNPU_CNN_FC_A_BASE, read_value);
                    $display("CNN_LINEARIZED_FC_A0=%08h", read_value);
                    check_tinynpu_cnn_linearized_golden(expected_index);
                end else begin
                    check_tinynpu_cnn_fused_native_golden(expected_index);
                end
            end else
                check_tinynpu_cnn_conv_golden(expected_index);

            // This is only layout conversion of RTL-produced INT8 activations.
            // No convolution, activation, or matrix multiply runs on the host.
            if (!linearized_mode) begin
                ai_tinynpu_cnn_layout_measure = 1'b1;
                for (feature_group = 0; feature_group < 36; feature_group = feature_group + 1) begin
                    axi_read(SPAD_BASE + AI_TINYNPU_CNN_CONV_RELU_I8_BASE +
                             feature_group * 4, read_value);
                    for (row_index = 0; row_index < 4; row_index = row_index + 1) begin
                        if (row_index == 0)
                            axi_write(SPAD_BASE + AI_TINYNPU_CNN_FC_A_BASE +
                                      (feature_group * 4 + row_index) * 4, read_value);
                        else
                            axi_write(SPAD_BASE + AI_TINYNPU_CNN_FC_A_BASE +
                                      (feature_group * 4 + row_index) * 4, 32'd0);
                    end
                end
                ai_tinynpu_cnn_layout_measure = 1'b0;
            end

            event_base = 8;
            for (group_index = 0; group_index < output_group_count;
                 group_index = group_index + 1) begin
                descriptor_index = conv_descriptor_count + group_index * 4;
                write_spad_desc_v3(AI_TINYNPU_CNN_DESC_BASE + descriptor_index * 64,
                       OP_TENSOR_GEMM, 16'hd500 + descriptor_index,
                       AI_TINYNPU_CNN_FC_A_BASE,
                       AI_TINYNPU_CNN_FC_B_BASE + group_index * 32'h240,
                       AI_TINYNPU_CNN_FC_ROUND_BASE,
                       AI_TINYNPU_CNN_FC_RAW_BASE,
                       16'd4, 16'd4, 16'd36, 8'h01, 32'd0, 5'd8, 2'd0,
                       32'd0, 32'd0, 32'd0, 16'd1, 16'd1,
                       event_base, event_base << 1, event_base);
                write_spad_desc_v3(AI_TINYNPU_CNN_DESC_BASE + (descriptor_index + 1) * 64,
                       OP_REQUANT_I8, 16'hd500 + descriptor_index + 1,
                       AI_TINYNPU_CNN_FC_RAW_BASE, 32'd0, 32'd0,
                       AI_TINYNPU_CNN_FC_I8_BASE,
                       16'd0, 16'd0, 16'd16, 8'h10, 32'd0, 5'd0, 2'd0,
                       32'd0, 32'd0, 32'd0, 16'd1, 16'd1,
                       event_base << 1, event_base << 2, event_base << 1);
                write_spad_desc_v3(AI_TINYNPU_CNN_DESC_BASE + (descriptor_index + 2) * 64,
                       OP_TENSOR_GEMM, 16'hd500 + descriptor_index + 2,
                       AI_TINYNPU_CNN_FC_I8_BASE, AI_TINYNPU_CNN_IDENTITY_B_BASE,
                       AI_TINYNPU_CNN_FC_BIAS_BASE + group_index * 32'h10,
                       AI_TINYNPU_CNN_FC_BIASED_BASE,
                       16'd4, 16'd4, 16'd1, 8'h01, 32'd0, 5'd0, 2'd0,
                       32'd0, 32'd0, 32'd0, 16'd1, 16'd1,
                       event_base << 2, event_base << 3, event_base << 2);
                write_spad_desc_v3(AI_TINYNPU_CNN_DESC_BASE + (descriptor_index + 3) * 64,
                       OP_REQUANT_I8, 16'hd500 + descriptor_index + 3,
                       AI_TINYNPU_CNN_FC_BIASED_BASE, 32'd0, 32'd0,
                       AI_TINYNPU_CNN_FINAL_I8_BASE + group_index * 32'h10,
                       16'd0, 16'd0, 16'd16, 8'h10, 32'd0, 5'd0, 2'd0,
                       32'd0, 32'd0, 32'd0, 16'd1, 16'd1,
                       event_base << 3,
                       (group_index + 1 < output_group_count) ? (event_base << 4) : 16'd0,
                       event_base << 3);
                tail_value = descriptor_index + 4;
                ai_tinynpu_cnn_measure = 1'b1;
                axi_write(REG_CMDQ_TAIL, tail_value);
                axi_write(REG_DOORBELL, 32'd1);
                completed = 1'b0;
                for (poll_index = 0; poll_index < 10000 && !completed;
                     poll_index = poll_index + 1) begin
                    repeat (32) @(posedge aclk);
                    axi_read(REG_CPLQ_TAIL, cpl_tail);
                    if (cpl_tail == tail_value)
                        completed = 1'b1;
                end
                ai_tinynpu_cnn_measure = 1'b0;
                if (!completed)
                    $fatal(1, "TinyNPU CNN FC group %0d completion timeout tail=%0d",
                           group_index, cpl_tail);
                check_tinynpu_cnn_fc_group(group_index, expected_index);
                event_base = event_base << 4;
            end

            axi_read(REG_CMDQ_HEAD, cmd_head);
            if (cmd_head !== descriptor_count)
                $fatal(1, "TinyNPU CNN CMDQ head=%0d expected=%0d",
                       cmd_head, descriptor_count);
            for (completion_index = 0; completion_index < descriptor_count;
                 completion_index = completion_index + 1) begin
                axi_read(SPAD_BASE + AI_TINYNPU_CNN_CPL_BASE + completion_index * 16,
                         read_value);
                if (read_value !== (32'h0000_d500 + completion_index))
                    $fatal(1, "TinyNPU CNN CPLQ[%0d] task id=%08h",
                           completion_index, read_value);
                axi_read(SPAD_BASE + AI_TINYNPU_CNN_CPL_BASE + completion_index * 16 + 4,
                         read_value);
                if (read_value !== 32'd1)
                    $fatal(1, "TinyNPU CNN CPLQ[%0d] status=%08h",
                           completion_index, read_value);
            end
            if (expected_index != expected_count + 5 + 4 * output_group_count)
                $fatal(1, "TinyNPU CNN Golden words consumed=%0d expected=%0d",
                       expected_index - 1, expected_count + 4 + 4 * output_group_count);

            $display("NMA_CNN_RTL_METRICS outputs=%0d descriptors=%0d cycles=%0d host_layout_cycles=%0d host_layout_read_bytes=%0d host_layout_write_bytes=%0d compute_spad_read_bytes=%0d compute_spad_write_bytes=%0d bank_read_lines=%0d line_write_lines=%0d model_macs=%0d padded_macs=%0d spad_initialization_bytes=%0d layout_mode=%0d",
                     num_classes, descriptor_count, ai_tinynpu_cnn_cycles,
                     ai_tinynpu_cnn_layout_cycles,
                     linearized_mode ? 0 : 144,
                     linearized_mode ? 0 : 576,
                     ai_tinynpu_cnn_engine_read_words * 4 + ai_tinynpu_cnn_banked_read_lines * 16,
                     ai_tinynpu_cnn_engine_write_words * 4 + ai_tinynpu_cnn_line_write_lines * 16,
                     ai_tinynpu_cnn_banked_read_lines, ai_tinynpu_cnn_line_write_lines,
                     1296 + 144 * num_classes, 1296 + 144 * 4 * output_group_count,
                     image_count * 4, linearized_mode ? 2 :
                                                       (fused_native_mode ? 1 : 0));
            $display("NMA_CNN_INFERENCE_PASS model=trained_int8_conv_relu_flatten_gemm outputs=%0d groups=%0d layout_mode=%0d golden=byte_exact",
                     num_classes, output_group_count,
                     linearized_mode ? 2 : (fused_native_mode ? 1 : 0));
            axi_write(REG_CMDQ_SIZE, 32'd0);
            axi_write(REG_CPLQ_SIZE, 32'd0);
            clear_done_irq();
        end
    endtask

    `include "ai_transformer_workload.svh"

    task run_transformer_only;
        integer prefill_read_snapshot;
        integer prefill_write_snapshot;
        reg [31:0] command_head;
        begin
            load_transformer_workload();
            transformer_spad_read_bytes = 0;
            transformer_spad_write_bytes = 0;
            transformer_prefill_read_bytes = 0;
            transformer_prefill_write_bytes = 0;
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
            transformer_top_profile_matrix_mac = 0;
            transformer_top_profile_matrix_request_wait = 0;
            transformer_top_profile_matrix_response_wait = 0;
            transformer_top_profile_matrix_writeback = 0;
            transformer_top_profile_matrix_other = 0;
            transformer_top_profile_sfu_busy = 0;
            transformer_top_profile_kv_busy = 0;
            transformer_top_profile_conv_busy = 0;
            transformer_top_profile_banked_busy = 0;
            transformer_top_profile_fp_busy = 0;
            transformer_top_profile_scalar_busy = 0;
            transformer_top_profile_no_engine_busy = 0;
            transformer_top_profile_dma_busy = 0;
            for (transformer_top_profile_index = 0;
                 transformer_top_profile_index < 13;
                 transformer_top_profile_index = transformer_top_profile_index + 1)
                transformer_top_prefill_profile[transformer_top_profile_index] = 0;
            transformer_top_last_completion_tail = 0;
            transformer_top_start_cycle = transformer_top_cycle_counter;
            transformer_top_last_completion_cycle = transformer_top_start_cycle;
            transformer_top_timing_enable = 1'b1;
            transformer_traffic_enable = 1'b1;
            axi_write(REG_DOORBELL, 32'd1);
            wait_cpl_tail(TRANSFORMER_PREFILL_DESC_COUNT,
                          "Transformer-only prefill completion");
            prefill_read_snapshot = transformer_spad_read_bytes;
            prefill_write_snapshot = transformer_spad_write_bytes;
            transformer_prefill_read_bytes = prefill_read_snapshot;
            transformer_prefill_write_bytes = prefill_write_snapshot;
            wait_cpl_tail(TRANSFORMER_DESC_COUNT,
                          "Transformer-only decode completion");
            transformer_top_timing_enable = 1'b0;
            transformer_traffic_enable = 1'b0;
            if (!transformer_top_prefill_captured ||
                !transformer_top_final_captured ||
                transformer_top_prefill_end_cycle <= transformer_top_start_cycle ||
                transformer_top_final_end_cycle <= transformer_top_prefill_end_cycle)
                $fatal(1, "Transformer-only timing boundary capture failed");
            $display("TRANSFORMER_TOP_ONLY_TIMING run_endpoint=doorbell_to_cpl_tail total_cycles=%0d prefill_cycles=%0d decode_cycles=%0d",
                     transformer_top_final_end_cycle - transformer_top_start_cycle,
                     transformer_top_prefill_end_cycle - transformer_top_start_cycle,
                     transformer_top_final_end_cycle - transformer_top_prefill_end_cycle);
            $display("TRANSFORMER_TOP_ONLY_PROFILE cycles_closed=%0d matrix_mac=%0d matrix_request_wait=%0d matrix_response_wait=%0d matrix_writeback=%0d matrix_other=%0d sfu_busy=%0d kv_busy=%0d conv_busy=%0d banked_busy=%0d fp_busy=%0d scalar_busy=%0d no_engine_busy_control_or_dispatch=%0d dma_busy_event_cycles=%0d",
                     transformer_top_profile_matrix_mac +
                         transformer_top_profile_matrix_request_wait +
                         transformer_top_profile_matrix_response_wait +
                         transformer_top_profile_matrix_writeback +
                         transformer_top_profile_matrix_other +
                         transformer_top_profile_sfu_busy +
                         transformer_top_profile_kv_busy +
                         transformer_top_profile_conv_busy +
                         transformer_top_profile_banked_busy +
                         transformer_top_profile_fp_busy +
                         transformer_top_profile_scalar_busy +
                         transformer_top_profile_no_engine_busy,
                     transformer_top_profile_matrix_mac,
                     transformer_top_profile_matrix_request_wait,
                     transformer_top_profile_matrix_response_wait,
                     transformer_top_profile_matrix_writeback,
                     transformer_top_profile_matrix_other,
                     transformer_top_profile_sfu_busy,
                     transformer_top_profile_kv_busy,
                     transformer_top_profile_conv_busy,
                     transformer_top_profile_banked_busy,
                     transformer_top_profile_fp_busy,
                     transformer_top_profile_scalar_busy,
                     transformer_top_profile_no_engine_busy,
                     transformer_top_profile_dma_busy);
            $display("TRANSFORMER_TOP_ONLY_PHASE_PROFILE phase=prefill cycles=%0d matrix_mac=%0d matrix_request_wait=%0d matrix_response_wait=%0d matrix_writeback=%0d matrix_other=%0d sfu_busy=%0d kv_busy=%0d conv_busy=%0d banked_busy=%0d fp_busy=%0d scalar_busy=%0d no_engine_busy_control_or_dispatch=%0d dma_busy_event_cycles=%0d",
                     transformer_top_prefill_end_cycle - transformer_top_start_cycle,
                     transformer_top_prefill_profile[0],
                     transformer_top_prefill_profile[1],
                     transformer_top_prefill_profile[2],
                     transformer_top_prefill_profile[3],
                     transformer_top_prefill_profile[4],
                     transformer_top_prefill_profile[5],
                     transformer_top_prefill_profile[6],
                     transformer_top_prefill_profile[7],
                     transformer_top_prefill_profile[8],
                     transformer_top_prefill_profile[9],
                     transformer_top_prefill_profile[10],
                     transformer_top_prefill_profile[11],
                     transformer_top_prefill_profile[12]);
            $display("TRANSFORMER_TOP_ONLY_PHASE_PROFILE phase=decode cycles=%0d matrix_mac=%0d matrix_request_wait=%0d matrix_response_wait=%0d matrix_writeback=%0d matrix_other=%0d sfu_busy=%0d kv_busy=%0d conv_busy=%0d banked_busy=%0d fp_busy=%0d scalar_busy=%0d no_engine_busy_control_or_dispatch=%0d dma_busy_event_cycles=%0d",
                     transformer_top_final_end_cycle - transformer_top_prefill_end_cycle,
                     transformer_top_profile_matrix_mac - transformer_top_prefill_profile[0],
                     transformer_top_profile_matrix_request_wait - transformer_top_prefill_profile[1],
                     transformer_top_profile_matrix_response_wait - transformer_top_prefill_profile[2],
                     transformer_top_profile_matrix_writeback - transformer_top_prefill_profile[3],
                     transformer_top_profile_matrix_other - transformer_top_prefill_profile[4],
                     transformer_top_profile_sfu_busy - transformer_top_prefill_profile[5],
                     transformer_top_profile_kv_busy - transformer_top_prefill_profile[6],
                     transformer_top_profile_conv_busy - transformer_top_prefill_profile[7],
                     transformer_top_profile_banked_busy - transformer_top_prefill_profile[8],
                     transformer_top_profile_fp_busy - transformer_top_prefill_profile[9],
                     transformer_top_profile_scalar_busy - transformer_top_prefill_profile[10],
                     transformer_top_profile_no_engine_busy - transformer_top_prefill_profile[11],
                     transformer_top_profile_dma_busy - transformer_top_prefill_profile[12]);
            for (transformer_top_profile_index = 0;
                 transformer_top_profile_index < TRANSFORMER_DESC_COUNT;
                 transformer_top_profile_index = transformer_top_profile_index + 1)
                $display("TRANSFORMER_COMMAND_RETIRE index=%0d cycles=%0d",
                         transformer_top_profile_index,
                         transformer_top_completion_cycles[transformer_top_profile_index]);
            check_transformer_workload();
            axi_read(REG_CMDQ_HEAD, command_head);
            if (command_head !== TRANSFORMER_DESC_COUNT)
                $fatal(1, "Transformer-only CMDQ head=%0d expected=%0d",
                       command_head, TRANSFORMER_DESC_COUNT);
            expect_completion(TRANSFORMER_CPL_BASE +
                              ((TRANSFORMER_DESC_COUNT-1) * 16),
                              TRANSFORMER_LAST_TASK_ID, 4'h1, 4'd0,
                              TRANSFORMER_LAST_RESULT, 32'd4,
                              "Transformer-only final completion");
            $display("TRANSFORMER_TOP_ONLY_METRICS useful_macs=640 prefill_read_bytes=%0d prefill_write_bytes=%0d decode_read_bytes=%0d decode_write_bytes=%0d total_read_bytes=%0d total_write_bytes=%0d",
                     transformer_prefill_read_bytes,
                     transformer_prefill_write_bytes,
                     transformer_spad_read_bytes - transformer_prefill_read_bytes,
                     transformer_spad_write_bytes - transformer_prefill_write_bytes,
                     transformer_spad_read_bytes,
                     transformer_spad_write_bytes);
        end
    endtask

    function signed [31:0] dot4_i8_sv;
        input [31:0] a;
        input [31:0] b;
        reg signed [7:0] a0;
        reg signed [7:0] a1;
        reg signed [7:0] a2;
        reg signed [7:0] a3;
        reg signed [7:0] b0;
        reg signed [7:0] b1;
        reg signed [7:0] b2;
        reg signed [7:0] b3;
        begin
            a0 = a[7:0];
            a1 = a[15:8];
            a2 = a[23:16];
            a3 = a[31:24];
            b0 = b[7:0];
            b1 = b[15:8];
            b2 = b[23:16];
            b3 = b[31:24];
            dot4_i8_sv = (a0 * b0) + (a1 * b1) + (a2 * b2) + (a3 * b3);
        end
    endfunction

    task gen_random_word;
        output [31:0] word_data;
        begin
            word_data[7:0]   = $urandom_range(0, 15) - 8;
            word_data[15:8]  = $urandom_range(0, 15) - 8;
            word_data[23:16] = $urandom_range(0, 15) - 8;
            word_data[31:24] = $urandom_range(0, 15) - 8;
        end
    endtask

    task run_random_gemv;
        input integer case_idx;
        integer m;
        integer k_words_i;
        integer row;
        integer k;
        reg [31:0] input_word [0:3];
        reg [31:0] weight_word [0:15];
        reg signed [31:0] expected;
        reg [31:0] base_input;
        reg [31:0] base_weight;
        reg [31:0] base_output;
        begin
            m = $urandom_range(1, 4);
            k_words_i = $urandom_range(1, 3);
            base_input  = 32'h1000 + (case_idx * 32'h400);
            base_weight = base_input + 32'h80;
            base_output = base_input + 32'h200;

            for (k = 0; k < k_words_i; k = k + 1) begin
                gen_random_word(input_word[k]);
                axi_write_delayed(SPAD_BASE + base_input + (k * 4), input_word[k],
                                  $urandom_range(0, 2), $urandom_range(0, 2), $urandom_range(0, 2));
            end

            for (row = 0; row < m; row = row + 1) begin
                for (k = 0; k < k_words_i; k = k + 1) begin
                    gen_random_word(weight_word[(row * k_words_i) + k]);
                    axi_write_delayed(SPAD_BASE + base_weight + (((row * k_words_i) + k) * 4),
                                      weight_word[(row * k_words_i) + k],
                                      $urandom_range(0, 2), $urandom_range(0, 2), $urandom_range(0, 2));
                end
            end

            axi_write(REG_OP_MODE, OP_GEMV_INT8);
            axi_write(REG_SRC0_BASE, base_input);
            axi_write(REG_SRC1_BASE, base_weight);
            axi_write(REG_DST_BASE,  base_output);
            axi_write(REG_M_SIZE,    m);
            axi_write(REG_K_WORDS,   k_words_i);
            axi_write(REG_POST_CTRL, 32'd0);
            axi_write(REG_QUANT_ACT, 32'd0);
            axi_write(REG_CTRL,      32'h0000_0003);
            wait_done();

            for (row = 0; row < m; row = row + 1) begin
                expected = 0;
                for (k = 0; k < k_words_i; k = k + 1)
                    expected = expected + dot4_i8_sv(input_word[k], weight_word[(row * k_words_i) + k]);
                expect_read(SPAD_BASE + base_output + (row * 4), expected, "random gemv");
            end
            clear_done_irq();
        end
    endtask

    task run_random_gemm;
        input integer case_idx;
        integer m;
        integer n;
        integer k_words_i;
        integer row;
        integer col;
        integer k;
        reg [31:0] a_word [0:15];
        reg [31:0] b_word [0:15];
        reg signed [31:0] expected;
        reg [31:0] base_a;
        reg [31:0] base_b;
        reg [31:0] base_out;
        begin
            m = $urandom_range(1, 3);
            n = $urandom_range(1, 3);
            k_words_i = $urandom_range(1, 2);
            base_a   = 32'h3000 + (case_idx * 32'h500);
            base_b   = base_a + 32'h100;
            base_out = base_a + 32'h300;

            for (row = 0; row < m; row = row + 1) begin
                for (k = 0; k < k_words_i; k = k + 1) begin
                    gen_random_word(a_word[(row * k_words_i) + k]);
                    axi_write_delayed(SPAD_BASE + base_a + (((row * k_words_i) + k) * 4),
                                      a_word[(row * k_words_i) + k],
                                      $urandom_range(0, 2), $urandom_range(0, 2), $urandom_range(0, 2));
                end
            end

            for (col = 0; col < n; col = col + 1) begin
                for (k = 0; k < k_words_i; k = k + 1) begin
                    gen_random_word(b_word[(col * k_words_i) + k]);
                    axi_write_delayed(SPAD_BASE + base_b + (((col * k_words_i) + k) * 4),
                                      b_word[(col * k_words_i) + k],
                                      $urandom_range(0, 2), $urandom_range(0, 2), $urandom_range(0, 2));
                end
            end

            axi_write(REG_OP_MODE, OP_GEMM_INT8_TILE);
            axi_write(REG_SRC0_BASE, base_a);
            axi_write(REG_SRC1_BASE, base_b);
            axi_write(REG_DST_BASE,  base_out);
            axi_write(REG_M_SIZE,    m);
            axi_write(REG_N_SIZE,    n);
            axi_write(REG_K_WORDS,   k_words_i);
            axi_write(REG_POST_CTRL, 32'd0);
            axi_write(REG_QUANT_ACT, 32'd0);
            axi_write(REG_CTRL,      32'h0000_0003);
            wait_done();

            for (row = 0; row < m; row = row + 1) begin
                for (col = 0; col < n; col = col + 1) begin
                    expected = 0;
                    for (k = 0; k < k_words_i; k = k + 1)
                        expected = expected + dot4_i8_sv(a_word[(row * k_words_i) + k],
                                                         b_word[(col * k_words_i) + k]);
                    expect_read(SPAD_BASE + base_out + (((row * n) + col) * 4), expected, "random gemm");
                end
            end
            clear_done_irq();
        end
    endtask

    function automatic [31:0] model_postprocess;
        input signed [63:0] accumulator;
        input [4:0] shift;
        input [1:0] activation;
        reg signed [63:0] value;
        begin
            value = accumulator >>> shift;
            if ((activation == 2'd1) || (activation == 2'd2)) begin
                if (value < 0)
                    value = 0;
            end
            if ((activation == 2'd2) && (value > 64'sd6))
                value = 64'sd6;
            if (value > 64'sd2147483647)
                model_postprocess = 32'h7fff_ffff;
            else if (value < -64'sd2147483648)
                model_postprocess = 32'h8000_0000;
            else
                model_postprocess = value[31:0];
        end
    endfunction

    task gen_random_3x3_word;
        input integer word_index;
        output [31:0] word_data;
        begin
            gen_random_word(word_data);
            // A 3x3 kernel has nine valid lanes; lanes 9..11 are padding.
            if (word_index == 2)
                word_data[31:8] = 24'd0;
        end
    endtask

    task run_random_conv3x3;
        input integer case_idx;
        integer m;
        integer n;
        integer row;
        integer col;
        integer k;
        integer activation_i;
        integer shift_i;
        integer bias_enable_i;
        reg [31:0] patch_word [0:5];
        reg [31:0] weight_word [0:8];
        reg signed [31:0] bias_word [0:2];
        reg signed [63:0] accumulator;
        reg [31:0] expected;
        reg [31:0] base_patch;
        reg [31:0] base_weight;
        reg [31:0] base_bias;
        reg [31:0] base_output;
        begin
            m = $urandom_range(1, 2);
            n = $urandom_range(1, 3);
            activation_i = case_idx % 3;
            shift_i = case_idx % 4;
            bias_enable_i = case_idx % 2;
            base_patch  = 32'h0000_a000;
            base_weight = 32'h0000_a100;
            base_bias   = 32'h0000_a200;
            base_output = 32'h0000_a300;

            for (row = 0; row < m; row = row + 1) begin
                for (k = 0; k < 3; k = k + 1) begin
                    gen_random_3x3_word(k, patch_word[(row * 3) + k]);
                    axi_write_delayed(SPAD_BASE + base_patch + (((row * 3) + k) * 4),
                                      patch_word[(row * 3) + k],
                                      $urandom_range(0, 2), $urandom_range(0, 2),
                                      $urandom_range(0, 2));
                end
            end
            for (col = 0; col < n; col = col + 1) begin
                for (k = 0; k < 3; k = k + 1) begin
                    gen_random_3x3_word(k, weight_word[(col * 3) + k]);
                    axi_write_delayed(SPAD_BASE + base_weight + (((col * 3) + k) * 4),
                                      weight_word[(col * 3) + k],
                                      $urandom_range(0, 2), $urandom_range(0, 2),
                                      $urandom_range(0, 2));
                end
                bias_word[col] = $urandom_range(0, 127) - 64;
                axi_write(SPAD_BASE + base_bias + (col * 4), bias_word[col]);
            end

            axi_write(REG_OP_MODE, OP_CONV3X3_INT8);
            axi_write(REG_SRC0_BASE, base_patch);
            axi_write(REG_SRC1_BASE, base_weight);
            axi_write(REG_DST_BASE, base_output);
            axi_write(REG_M_SIZE, m);
            axi_write(REG_N_SIZE, n);
            axi_write(REG_K_WORDS, 32'd3);
            axi_write(REG_BIAS_BASE, base_bias);
            axi_write(REG_POST_CTRL, bias_enable_i);
            axi_write(REG_QUANT_ACT, (activation_i << 5) | shift_i);
            axi_write(REG_CTRL, 32'h0000_0003);
            wait_done();

            for (row = 0; row < m; row = row + 1) begin
                for (col = 0; col < n; col = col + 1) begin
                    accumulator = bias_enable_i ? bias_word[col] : 0;
                    for (k = 0; k < 3; k = k + 1)
                        accumulator = accumulator +
                            dot4_i8_sv(patch_word[(row * 3) + k],
                                      weight_word[(col * 3) + k]);
                    expected = model_postprocess(accumulator, shift_i[4:0],
                                                 activation_i[1:0]);
                    expect_read(SPAD_BASE + base_output + (((row * n) + col) * 4),
                                expected, "random conv3x3 post-op");
                end
            end
            clear_done_irq();
        end
    endtask

    task run_random_dwconv3x3;
        input integer case_idx;
        integer m;
        integer n;
        integer row;
        integer col;
        integer k;
        integer activation_i;
        integer shift_i;
        integer bias_enable_i;
        reg [31:0] patch_word [0:17];
        reg [31:0] weight_word [0:8];
        reg signed [31:0] bias_word [0:2];
        reg signed [63:0] accumulator;
        reg [31:0] expected;
        reg [31:0] base_patch;
        reg [31:0] base_weight;
        reg [31:0] base_bias;
        reg [31:0] base_output;
        begin
            m = $urandom_range(1, 2);
            n = $urandom_range(1, 3);
            activation_i = (case_idx + 1) % 3;
            shift_i = (case_idx + 2) % 4;
            bias_enable_i = (case_idx + 1) % 2;
            base_patch  = 32'h0000_b000;
            base_weight = 32'h0000_b100;
            base_bias   = 32'h0000_b200;
            base_output = 32'h0000_b300;

            for (row = 0; row < m; row = row + 1) begin
                for (col = 0; col < n; col = col + 1) begin
                    for (k = 0; k < 3; k = k + 1) begin
                        gen_random_3x3_word(k,
                            patch_word[(((row * n) + col) * 3) + k]);
                        axi_write_delayed(
                            SPAD_BASE + base_patch +
                            (((((row * n) + col) * 3) + k) * 4),
                            patch_word[(((row * n) + col) * 3) + k],
                            $urandom_range(0, 2), $urandom_range(0, 2),
                            $urandom_range(0, 2));
                    end
                end
            end
            for (col = 0; col < n; col = col + 1) begin
                for (k = 0; k < 3; k = k + 1) begin
                    gen_random_3x3_word(k, weight_word[(col * 3) + k]);
                    axi_write_delayed(SPAD_BASE + base_weight + (((col * 3) + k) * 4),
                                      weight_word[(col * 3) + k],
                                      $urandom_range(0, 2), $urandom_range(0, 2),
                                      $urandom_range(0, 2));
                end
                bias_word[col] = $urandom_range(0, 127) - 64;
                axi_write(SPAD_BASE + base_bias + (col * 4), bias_word[col]);
            end

            axi_write(REG_OP_MODE, OP_DWCONV3X3_INT8);
            axi_write(REG_SRC0_BASE, base_patch);
            axi_write(REG_SRC1_BASE, base_weight);
            axi_write(REG_DST_BASE, base_output);
            axi_write(REG_M_SIZE, m);
            axi_write(REG_N_SIZE, n);
            axi_write(REG_K_WORDS, 32'd3);
            axi_write(REG_BIAS_BASE, base_bias);
            axi_write(REG_POST_CTRL, bias_enable_i);
            axi_write(REG_QUANT_ACT, (activation_i << 5) | shift_i);
            axi_write(REG_CTRL, 32'h0000_0003);
            wait_done();

            for (row = 0; row < m; row = row + 1) begin
                for (col = 0; col < n; col = col + 1) begin
                    accumulator = bias_enable_i ? bias_word[col] : 0;
                    for (k = 0; k < 3; k = k + 1)
                        accumulator = accumulator + dot4_i8_sv(
                            patch_word[(((row * n) + col) * 3) + k],
                            weight_word[(col * 3) + k]);
                    expected = model_postprocess(accumulator, shift_i[4:0],
                                                 activation_i[1:0]);
                    expect_read(SPAD_BASE + base_output + (((row * n) + col) * 4),
                                expected, "random dwconv3x3 post-op");
                end
            end
            clear_done_irq();
        end
    endtask

    // Round 16 staged workload: preserve SPAD across five drained CMDQ batches
    // so each KV append consumes the cache state produced by prior Top work.
    task run_h16_incremental_decode;
        reg [1023:0] workload_dir;
        reg [1023:0] initial_file;
        reg [1023:0] stage_desc_file;
        reg [1023:0] stage_golden_file;
        reg [1023:0] stage_poison_file;
        reg [1023:0] stage_observed_file;
        reg [1023:0] stage_label;
        integer image_count;
        integer stage_idx;
        integer stage_count;
        integer desc_count;
        integer descriptor_base;
        integer completion_base;
        integer image_index;
        integer pair_index;
        integer word_index;
        integer completion_index;
        integer poll_index;
        integer stage_cycles;
        integer useful_macs;
        integer useful_macs_extra;
        integer matrix_mac_cycles;
        integer matrix_wait_cycles;
        integer matrix_response_wait_cycles;
        integer matrix_writeback_cycles;
        integer matrix_other_cycles;
        integer sfu_busy_cycles;
        integer kv_busy_cycles;
        integer conv_busy_cycles;
        integer banked_busy_cycles;
        integer fp_busy_cycles;
        integer scalar_busy_cycles;
        integer no_engine_cycles;
        integer dma_busy_cycles;
        integer spad_read_bytes;
        integer spad_write_bytes;
        integer observed_fd;
        integer task_id;
        real mac_per_cycle;
        real array_utilization;
        reg [31:0] read_value;
        reg [31:0] status_value;
        reg [31:0] expected_value;
        reg [31:0] incremental_stage_words [0:131071];
        begin
            if (!$value$plusargs("AI_H16_INCREMENTAL_DIR=%s", workload_dir))
                $fatal(1, "incremental H16 mode requires AI_H16_INCREMENTAL_DIR");
            useful_macs_extra = 0;
            void'($value$plusargs("AI_H16_USEFUL_MACS_EXTRA=%d", useful_macs_extra));
            $sformat(initial_file, "%0s/initial_memory.memh", workload_dir);
            $readmemh(initial_file, representative_image_words);
            image_count = representative_image_words[0];
            if (image_count <= 0 || image_count > 65535)
                $fatal(1, "invalid incremental H16 initial image count=%0d", image_count);
            representative_load_cycles = 0;
            representative_load_measure = 1'b1;
            for (image_index = 0; image_index < image_count; image_index = image_index + 1) begin
                if (representative_image_words[1 + 2 * image_index] >= SPAD_BYTES ||
                    representative_image_words[1 + 2 * image_index][1:0] != 2'b00)
                    $fatal(1, "incremental H16 initial SPAD address invalid index=%0d addr=%08h",
                           image_index, representative_image_words[1 + 2 * image_index]);
                axi_write(SPAD_BASE + representative_image_words[1 + 2 * image_index],
                          representative_image_words[2 + 2 * image_index]);
            end
            representative_load_measure = 1'b0;
            stage_count = 5;
            for (stage_idx = 0; stage_idx < stage_count; stage_idx = stage_idx + 1) begin
                case (stage_idx)
                    0: stage_label = "prefill_kv_0_3";
                    1: stage_label = "decode_t4";
                    2: stage_label = "decode_t5";
                    3: stage_label = "decode_t6";
                    4: stage_label = "decode_t7";
                    default: $fatal(1, "invalid incremental H16 stage index");
                endcase
                $sformat(stage_desc_file, "%0s/stage_%0d_%0s_desc.memh",
                         workload_dir, stage_idx, stage_label);
                $sformat(stage_golden_file, "%0s/stage_%0d_%0s_golden.memh",
                         workload_dir, stage_idx, stage_label);
                $sformat(stage_poison_file, "%0s/stage_%0d_%0s_poison.memh",
                         workload_dir, stage_idx, stage_label);
                $sformat(stage_observed_file, "%0s/stage_%0d_%0s_observed.memh",
                         workload_dir, stage_idx, stage_label);
                $readmemh(stage_desc_file, incremental_stage_words);
                desc_count = incremental_stage_words[0];
                descriptor_base = incremental_stage_words[1];
                completion_base = incremental_stage_words[2];
                if (desc_count <= 0 || desc_count > 128 ||
                    descriptor_base < 0 || completion_base < 0 ||
                    descriptor_base + desc_count * 64 > SPAD_BYTES ||
                    completion_base + desc_count * 16 > SPAD_BYTES)
                    $fatal(1, "invalid incremental H16 stage geometry stage=%0d desc=%0d",
                           stage_idx, desc_count);

                // Poison only outputs produced by this batch. Cache words remain
                // live so this stage consumes the preceding stage's actual state.
                $readmemh(stage_poison_file, representative_image_words);
                image_count = representative_image_words[0];
                if (image_count <= 0 || image_count > 65535)
                    $fatal(1, "invalid incremental H16 poison count stage=%0d", stage_idx);
                for (pair_index = 0; pair_index < image_count; pair_index = pair_index + 1)
                    axi_write(SPAD_BASE + representative_image_words[1 + 2 * pair_index],
                              representative_image_words[2 + 2 * pair_index]);
                for (pair_index = 0; pair_index < image_count; pair_index = pair_index + 1) begin
                    axi_read(SPAD_BASE + representative_image_words[1 + 2 * pair_index], read_value);
                    if (read_value !== 32'ha55a_a55a)
                        $fatal(1, "incremental H16 output poison failed stage=%0d pair=%0d",
                               stage_idx, pair_index);
                end

                for (image_index = 0; image_index < desc_count; image_index = image_index + 1)
                    for (word_index = 0; word_index < 16; word_index = word_index + 1)
                        axi_write(SPAD_BASE + descriptor_base + image_index * 64 + word_index * 4,
                                  incremental_stage_words[3 + image_index * 16 + word_index]);

                $readmemh(stage_golden_file, representative_golden_words);
                image_count = representative_golden_words[0];
                if (image_count <= 0 || image_count > 65535)
                    $fatal(1, "invalid incremental H16 golden count stage=%0d", stage_idx);

                // Re-arm empty queue pointers between batches without resetting SPAD.
                axi_write(REG_CMDQ_CTRL, 32'd0);
                axi_write(REG_CMDQ_SIZE, 32'd0);
                axi_write(REG_CPLQ_SIZE, 32'd0);
                axi_write(REG_CMDQ_BASE_LO, descriptor_base);
                axi_write(REG_CMDQ_BASE_HI, 32'd0);
                axi_write(REG_CMDQ_SIZE, 32'd128);
                axi_write(REG_CMDQ_HEAD, 32'd0);
                axi_write(REG_CMDQ_TAIL, desc_count);
                axi_write(REG_CPLQ_BASE_LO, completion_base);
                axi_write(REG_CPLQ_SIZE, 32'd128);
                axi_write(REG_CPLQ_HEAD, 32'd0);
                axi_write(REG_CPLQ_TAIL, 32'd0);

                ai_tinynpu_cnn_engine_read_words = 0;
                ai_tinynpu_cnn_engine_write_words = 0;
                ai_tinynpu_cnn_banked_read_lines = 0;
                ai_tinynpu_cnn_line_write_lines = 0;
                ai_tinynpu_cnn_measure = 1'b1;
                transformer_top_profile_matrix_mac = 0;
                transformer_top_profile_matrix_request_wait = 0;
                transformer_top_profile_matrix_response_wait = 0;
                transformer_top_profile_matrix_writeback = 0;
                transformer_top_profile_matrix_other = 0;
                transformer_top_profile_sfu_busy = 0;
                transformer_top_profile_kv_busy = 0;
                transformer_top_profile_conv_busy = 0;
                transformer_top_profile_banked_busy = 0;
                transformer_top_profile_fp_busy = 0;
                transformer_top_profile_scalar_busy = 0;
                transformer_top_profile_no_engine_busy = 0;
                transformer_top_profile_dma_busy = 0;
                r17_matrix_count = 0;
                r17_kv_count = 0;
                r17_multi_engine_overlap_cycles = 0;
                transformer_top_last_completion_tail = dut.processor_cplq_tail;
                transformer_top_last_completion_cycle = transformer_top_cycle_counter;
                transformer_top_start_cycle = transformer_top_cycle_counter;
                transformer_top_prefill_target = 0;
                transformer_top_final_target = desc_count;
                transformer_top_prefill_end_cycle = transformer_top_start_cycle;
                transformer_top_prefill_captured = 1'b1;
                transformer_top_final_captured = 1'b0;
                transformer_top_timing_enable = 1'b1;
                axi_write(REG_DOORBELL, 32'd1);
                for (poll_index = 0; poll_index < 2000000 &&
                     !transformer_top_final_captured; poll_index = poll_index + 1)
                    @(posedge aclk);
                transformer_top_timing_enable = 1'b0;
                ai_tinynpu_cnn_measure = 1'b0;
                if (!transformer_top_final_captured)
                    $fatal(1, "incremental H16 completion timeout stage=%0d desc=%0d head=%0d tail=%0d",
                           stage_idx, desc_count, dut.processor_cmdq_head, dut.processor_cplq_tail);
                if (dut.processor_cplq_tail != desc_count || dut.processor_cmdq_head != desc_count)
                    $fatal(1, "incremental H16 queues did not drain stage=%0d head=%0d tail=%0d expected=%0d",
                           stage_idx, dut.processor_cmdq_head, dut.processor_cplq_tail, desc_count);

                $display("R17_STAGE_OVERLAP stage=%0s cycles=%0d",
                         stage_label, r17_multi_engine_overlap_cycles);
                for (completion_index = 0; completion_index < desc_count;
                     completion_index = completion_index + 1) begin
                    $display("R17_DESCRIPTOR_INTERVAL stage=%0s local_index=%0d task_id=%0d opcode=0x%02h cycles=%0d",
                             stage_label, completion_index,
                             incremental_stage_words[3 + completion_index * 16] >> 16,
                             incremental_stage_words[3 + completion_index * 16][7:0],
                             transformer_top_completion_cycles[completion_index]);
                end
                for (completion_index = 0; completion_index < r17_matrix_count;
                     completion_index = completion_index + 1) begin
                    $display("R17_MATRIX_COMMAND stage=%0s index=%0d cycles=%0d mac=%0d request_wait=%0d response_wait=%0d writeback=%0d other=%0d read_bytes=%0d write_bytes=%0d exclusive_closed=%0d",
                             stage_label, completion_index,
                             r17_matrix_cycles[completion_index],
                             r17_matrix_mac[completion_index],
                             r17_matrix_request_wait[completion_index],
                             r17_matrix_response_wait[completion_index],
                             r17_matrix_writeback[completion_index],
                             r17_matrix_other[completion_index],
                             r17_matrix_read_bytes[completion_index],
                             r17_matrix_write_bytes[completion_index],
                             r17_matrix_mac[completion_index] +
                             r17_matrix_request_wait[completion_index] +
                             r17_matrix_response_wait[completion_index] +
                             r17_matrix_writeback[completion_index] +
                             r17_matrix_other[completion_index]);
                end
                for (completion_index = 0; completion_index < r17_kv_count;
                     completion_index = completion_index + 1)
                    $display("R17_KV_COMMAND stage=%0s index=%0d cycles=%0d read_bytes=%0d write_bytes=%0d",
                             stage_label, completion_index,
                             r17_kv_cycles[completion_index],
                             r17_kv_read_bytes[completion_index],
                             r17_kv_write_bytes[completion_index]);

                observed_fd = $fopen(stage_observed_file, "w");
                if (observed_fd == 0)
                    $fatal(1, "could not open incremental observed file %0s", stage_observed_file);
                $fdisplay(observed_fd, "%08h", image_count);
                for (completion_index = 0; completion_index < desc_count;
                     completion_index = completion_index + 1) begin
                    task_id = incremental_stage_words[3 + completion_index * 16] >> 16;
                    axi_read(SPAD_BASE + completion_base + completion_index * 16, read_value);
                    if (read_value !== task_id)
                        $fatal(1, "incremental H16 task ID mismatch stage=%0d desc=%0d expected=%08h actual=%08h",
                               stage_idx, completion_index, task_id, read_value);
                    axi_read(SPAD_BASE + completion_base + completion_index * 16 + 4, status_value);
                    if (status_value !== 32'd1)
                        $fatal(1, "incremental H16 Completion error stage=%0d desc=%0d status=%08h",
                               stage_idx, completion_index, status_value);
                end
                for (pair_index = 0; pair_index < image_count; pair_index = pair_index + 1) begin
                    axi_read(SPAD_BASE + representative_golden_words[1 + 2 * pair_index], read_value);
                    expected_value = representative_golden_words[2 + 2 * pair_index];
                    if (read_value !== expected_value)
                        $fatal(1, "incremental H16 Golden mismatch stage=%0d pair=%0d addr=%08h expected=%08h actual=%08h",
                               stage_idx, pair_index,
                               representative_golden_words[1 + 2 * pair_index],
                               expected_value, read_value);
                    $fdisplay(observed_fd, "%08h", representative_golden_words[1 + 2 * pair_index]);
                    $fdisplay(observed_fd, "%08h", read_value);
                end
                $fclose(observed_fd);

                stage_cycles = transformer_top_final_end_cycle - transformer_top_start_cycle;
                matrix_mac_cycles = transformer_top_profile_matrix_mac;
                matrix_wait_cycles = transformer_top_profile_matrix_request_wait;
                matrix_response_wait_cycles = transformer_top_profile_matrix_response_wait;
                matrix_writeback_cycles = transformer_top_profile_matrix_writeback;
                matrix_other_cycles = transformer_top_profile_matrix_other;
                sfu_busy_cycles = transformer_top_profile_sfu_busy;
                kv_busy_cycles = transformer_top_profile_kv_busy;
                conv_busy_cycles = transformer_top_profile_conv_busy;
                banked_busy_cycles = transformer_top_profile_banked_busy;
                fp_busy_cycles = transformer_top_profile_fp_busy;
                scalar_busy_cycles = transformer_top_profile_scalar_busy;
                no_engine_cycles = transformer_top_profile_no_engine_busy;
                dma_busy_cycles = transformer_top_profile_dma_busy;
                spad_read_bytes = ai_tinynpu_cnn_engine_read_words * 4 +
                                  ai_tinynpu_cnn_banked_read_lines * 16;
                spad_write_bytes = ai_tinynpu_cnn_engine_write_words * 4 +
                                   ai_tinynpu_cnn_line_write_lines * 16;
                if (stage_idx == 0)
                    useful_macs = 3072;
                else
                    // Count logical GEMM/GEMV products only: Q/K/V, output
                    // projection, FFN, optional explicit LM-head MACs, and
                    // the single live query row's causal QK/AV work. The other
                    // physical rows and masked future keys are padding.
                    useful_macs = 1536 + useful_macs_extra +
                                  32 * (stage_idx + 4);
                mac_per_cycle = 0.0;
                array_utilization = 0.0;
                if (stage_cycles > 0)
                    mac_per_cycle = 1.0 * useful_macs / stage_cycles;
                if (matrix_mac_cycles > 0)
                    array_utilization = 100.0 * useful_macs / (256.0 * matrix_mac_cycles);
                $display("INCREMENTAL_H16_STAGE_PASS stage=%0s index=%0d desc=%0d golden_words=%0d useful_macs=%0d cycles=%0d matrix_mac=%0d matrix_wait=%0d matrix_rsp_wait=%0d matrix_writeback=%0d matrix_other=%0d sfu=%0d kv=%0d dma_overlap=%0d spad_read_bytes=%0d spad_write_bytes=%0d mac_per_cycle=%0.4f array_utilization_pct=%0.2f observed=%0s",
                         stage_label, stage_idx, desc_count, image_count, useful_macs,
                         stage_cycles, matrix_mac_cycles, matrix_wait_cycles,
                         matrix_response_wait_cycles, matrix_writeback_cycles,
                         matrix_other_cycles, sfu_busy_cycles, kv_busy_cycles,
                         dma_busy_cycles, spad_read_bytes, spad_write_bytes,
                         mac_per_cycle, array_utilization, stage_observed_file);
                axi_write(REG_CMDQ_SIZE, 32'd0);
                axi_write(REG_CPLQ_SIZE, 32'd0);
                clear_done_irq();
            end
            $display("INCREMENTAL_DECODE_PASS prefill_tokens=4 append_tokens=4 capacity=8 kv_write=0x43 kv_read=0x44 full_block_steps=4 host_supplied_tokens=1");
        end
    endtask

    task run_representative_model;
        reg [1023:0] image_file;
        reg [1023:0] golden_file;
        reg [1023:0] dma_payload_file;
        reg [1023:0] dma_plan_file;
        reg use_dma_preload;
        integer image_count;
        integer golden_count;
        integer image_index;
        integer golden_index;
        integer dma_plan_count;
        integer dma_plan_index;
        integer dma_payload_bytes;
        integer dma_sentinel_setup_bytes;
        integer descriptor_base;
        integer completion_base;
        integer descriptor_count;
        integer prefill_descriptor_count;
        integer useful_macs;
        integer poll_index;
        integer completion_index;
        integer matrix_mac_cycles;
        integer matrix_wait_cycles;
        integer matrix_response_wait_cycles;
        integer matrix_writeback_cycles;
        integer matrix_other_cycles;
        integer sfu_busy_cycles;
        integer kv_busy_cycles;
        integer conv_busy_cycles;
        integer banked_busy_cycles;
        integer fp_busy_cycles;
        integer scalar_busy_cycles;
        integer no_engine_cycles;
        integer dma_busy_cycles;
        integer exclusive_profile_cycles;
        integer command_cycles;
        integer prefill_command_cycles;
        integer decode_command_cycles;
        integer prefill_exclusive_cycles;
        integer decode_exclusive_cycles;
        integer preloaded_spad_bytes;
        integer spad_read_bytes;
        integer spad_write_bytes;
        integer representative_dump_fd;
        integer representative_dump_index;
        integer representative_dump_base_a;
        integer representative_dump_words_a;
        integer representative_dump_base_b;
        integer representative_dump_words_b;
        real mac_per_cycle;
        real array_utilization;
        reg [1023:0] representative_dump_file;
        reg [31:0] read_value;
        reg [31:0] status_value;
        begin
            if (!$value$plusargs("AI_REPRESENTATIVE_MEMORY=%s", image_file) ||
                !$value$plusargs("AI_REPRESENTATIVE_GOLDEN=%s", golden_file) ||
                !$value$plusargs("AI_REPRESENTATIVE_DESC_BASE=%d", descriptor_base) ||
                !$value$plusargs("AI_REPRESENTATIVE_CPL_BASE=%d", completion_base) ||
                !$value$plusargs("AI_REPRESENTATIVE_DESC_COUNT=%d", descriptor_count) ||
                !$value$plusargs("AI_REPRESENTATIVE_USEFUL_MACS=%d", useful_macs))
                $fatal(1, "representative model mode requires memory, golden, queue and MAC plusargs");
            use_dma_preload = $test$plusargs("AI_REPRESENTATIVE_DMA_PRELOAD");
            prefill_descriptor_count = 0;
            void'($value$plusargs("AI_REPRESENTATIVE_PREFILL_DESC_COUNT=%d",
                                  prefill_descriptor_count));

            $readmemh(image_file, representative_image_words);
            $readmemh(golden_file, representative_golden_words);
            image_count = representative_image_words[0];
            golden_count = representative_golden_words[0];
            if (image_count <= 0 || image_count > 65535 ||
                golden_count <= 0 || golden_count > 65535 ||
                descriptor_count < 1 || descriptor_count > 128 ||
                prefill_descriptor_count < 0 ||
                prefill_descriptor_count > descriptor_count ||
                descriptor_base < 0 || completion_base < 0 ||
                descriptor_base[1:0] != 0 || completion_base[1:0] != 0)
                $fatal(1, "representative model image/queue dimensions invalid image=%0d golden=%0d desc=%0d",
                       image_count, golden_count, descriptor_count);

            representative_load_cycles = 0;
            if (use_dma_preload) begin
                if (!$value$plusargs("AI_REPRESENTATIVE_DMA_PAYLOAD=%s", dma_payload_file) ||
                    !$value$plusargs("AI_REPRESENTATIVE_DMA_PLAN=%s", dma_plan_file))
                    $fatal(1, "DMA preload requires payload and plan files");
                $readmemh(dma_payload_file, axi_mem_u.mem);
                $readmemh(dma_plan_file, representative_dma_plan_words);
                dma_plan_count = representative_dma_plan_words[0];
                if (dma_plan_count < 1 || dma_plan_count > 85)
                    $fatal(1, "invalid representative DMA plan count=%0d", dma_plan_count);

                // Output poison is a checker precondition only. Keep its setup
                // outside the production payload and measured DMA interval.
                dma_sentinel_setup_bytes = 0;
                for (image_index = 0; image_index < image_count; image_index = image_index + 1) begin
                    if (representative_image_words[1 + 2 * image_index] >= SPAD_BYTES ||
                        representative_image_words[1 + 2 * image_index][1:0] != 2'b00)
                        $fatal(1, "representative image has invalid SPAD address index=%0d addr=%08h",
                               image_index, representative_image_words[1 + 2 * image_index]);
                    if (representative_image_words[2 + 2 * image_index] == 32'ha55a_a55a) begin
                        axi_write(SPAD_BASE + representative_image_words[1 + 2 * image_index],
                                  32'ha55a_a55a);
                        dma_sentinel_setup_bytes = dma_sentinel_setup_bytes + 4;
                    end
                end

                dma_payload_bytes = 0;
                representative_dma_window_cycles = 0;
                representative_dma_busy_cycles = 0;
                r20_dma_ar_bursts = 0;
                r20_dma_ar_bytes = 0;
                r20_dma_r_beats = 0;
                r20_dma_ar_q_head = 0;
                r20_dma_ar_q_tail = 0;
                r20_dma_read_latency_sum = 0;
                r20_dma_read_latency_max = 0;
                r20_dma_read_latency_count = 0;
                axi_write(REG_DMA_ROW_WORDS, 32'd0);
                axi_write(REG_DMA_ROW_COUNT, 32'd0);
                axi_write(REG_DMA_EXT_STRIDE, 32'd0);
                axi_write(REG_DMA_SPAD_STRIDE, 32'd0);
                axi_write(REG_DMA_GATHER_INDEX, 32'd0);
                axi_write(REG_DMA_CFG, 32'd0);
                representative_dma_window_measure = 1'b1;
                representative_dma_busy_measure = 1'b1;
                r20_dma_monitor_enable = 1'b1;
                for (dma_plan_index = 0; dma_plan_index < dma_plan_count; dma_plan_index = dma_plan_index + 1) begin
                    if (representative_dma_plan_words[1 + dma_plan_index * 3][3:0] != 0 ||
                        representative_dma_plan_words[2 + dma_plan_index * 3][3:0] != 0 ||
                        representative_dma_plan_words[3 + dma_plan_index * 3] == 0 ||
                        representative_dma_plan_words[3 + dma_plan_index * 3][1:0] != 0 ||
                        representative_dma_plan_words[1 + dma_plan_index * 3] +
                            representative_dma_plan_words[3 + dma_plan_index * 3] * 4 >
                            16384 ||
                        representative_dma_plan_words[2 + dma_plan_index * 3] +
                            representative_dma_plan_words[3 + dma_plan_index * 3] * 4 >
                            SPAD_BYTES)
                        $fatal(1, "invalid representative DMA plan index=%0d", dma_plan_index);
                    dma_payload_bytes = dma_payload_bytes +
                        representative_dma_plan_words[3 + dma_plan_index * 3] * 4;
                    axi_write(REG_DMA_EXT_ADDR,
                              representative_dma_plan_words[1 + dma_plan_index * 3]);
                    axi_write(REG_DMA_SPAD_ADDR,
                              representative_dma_plan_words[2 + dma_plan_index * 3]);
                    axi_write(REG_DMA_LENGTH,
                              representative_dma_plan_words[3 + dma_plan_index * 3]);
                    axi_write(REG_DMA_CTRL, 32'h0000_0001);
                    for (poll_index = 0; poll_index < 200000 &&
                         !dut.dma_done && !dut.dma_error; poll_index = poll_index + 1)
                        @(posedge aclk);
                    if (poll_index == 200000)
                        $fatal(1, "representative DMA preload timeout plan_index=%0d ext=%08h spad=%08h words=%0d",
                               dma_plan_index,
                               representative_dma_plan_words[1 + dma_plan_index * 3],
                               representative_dma_plan_words[2 + dma_plan_index * 3],
                               representative_dma_plan_words[3 + dma_plan_index * 3]);
                    axi_read(REG_DMA_STATUS, status_value);
                    if (!(dut.dma_done || status_value[1]) ||
                        dut.dma_error || status_value[2])
                        $fatal(1, "representative DMA preload failed plan_index=%0d status=%08h",
                               dma_plan_index, status_value);
                    axi_write(REG_DMA_STATUS, 32'd2);
                end
                r20_dma_monitor_enable = 1'b0;
                representative_dma_busy_measure = 1'b0;
                representative_dma_window_measure = 1'b0;
                preloaded_spad_bytes = dma_payload_bytes;
                if (r20_dma_ar_bytes != dma_payload_bytes ||
                    r20_dma_ar_bursts == 0 || r20_dma_r_beats == 0)
                    $fatal(1, "representative DMA byte mismatch plan=%0d AXI=%0d bursts=%0d beats=%0d",
                           dma_payload_bytes, r20_dma_ar_bytes,
                           r20_dma_ar_bursts, r20_dma_r_beats);
                $display("REPRESENTATIVE_DMA_PRELOAD_PASS transactions=%0d payload_bytes=%0d axi_read_bytes=%0d ar_bursts=%0d r_beats=%0d read_latency_sum=%0d read_latency_count=%0d read_latency_max=%0d dma_busy_cycles=%0d setup_and_transfer_cycles=%0d test_only_poison_setup_bytes=%0d",
                         dma_plan_count, dma_payload_bytes, r20_dma_ar_bytes,
                         r20_dma_ar_bursts, r20_dma_r_beats,
                         r20_dma_read_latency_sum, r20_dma_read_latency_count,
                         r20_dma_read_latency_max, representative_dma_busy_cycles,
                         representative_dma_window_cycles, dma_sentinel_setup_bytes);
            end else begin
                representative_load_measure = 1'b1;
                for (image_index = 0; image_index < image_count; image_index = image_index + 1) begin
                    if (representative_image_words[1 + 2 * image_index] >= SPAD_BYTES ||
                        representative_image_words[1 + 2 * image_index][1:0] != 2'b00)
                        $fatal(1, "representative image has invalid SPAD address index=%0d addr=%08h",
                               image_index, representative_image_words[1 + 2 * image_index]);
                    axi_write(SPAD_BASE + representative_image_words[1 + 2 * image_index],
                              representative_image_words[2 + 2 * image_index]);
                end
                representative_load_measure = 1'b0;
            end

            // Prove every expected result was poisoned before the first command.
            for (golden_index = 0; golden_index < golden_count; golden_index = golden_index + 1) begin
                axi_read(SPAD_BASE + representative_golden_words[1 + 2 * golden_index],
                         read_value);
                if (read_value !== 32'ha55a_a55a)
                    $fatal(1, "representative output not poisoned index=%0d addr=%08h value=%08h",
                           golden_index, representative_golden_words[1 + 2 * golden_index], read_value);
            end

            axi_write(REG_CMDQ_CTRL, 32'd0);
            axi_write(REG_CMDQ_BASE_LO, descriptor_base);
            axi_write(REG_CMDQ_BASE_HI, 32'd0);
            axi_write(REG_CMDQ_SIZE, 32'd128);
            axi_write(REG_CMDQ_HEAD, 32'd0);
            axi_write(REG_CMDQ_TAIL, descriptor_count);
            axi_write(REG_CPLQ_BASE_LO, completion_base);
            axi_write(REG_CPLQ_SIZE, 32'd128);
            axi_write(REG_CPLQ_HEAD, 32'd0);
            axi_write(REG_CPLQ_TAIL, 32'd0);

            ai_tinynpu_cnn_engine_read_words = 0;
            ai_tinynpu_cnn_engine_write_words = 0;
            ai_tinynpu_cnn_banked_read_lines = 0;
            ai_tinynpu_cnn_line_write_lines = 0;
            ai_tinynpu_cnn_measure = 1'b1;
            transformer_top_profile_matrix_mac = 0;
            transformer_top_profile_matrix_request_wait = 0;
            transformer_top_profile_matrix_response_wait = 0;
            transformer_top_profile_matrix_writeback = 0;
            transformer_top_profile_matrix_other = 0;
            transformer_top_profile_sfu_busy = 0;
            transformer_top_profile_kv_busy = 0;
            transformer_top_profile_conv_busy = 0;
            transformer_top_profile_banked_busy = 0;
            transformer_top_profile_fp_busy = 0;
            transformer_top_profile_scalar_busy = 0;
            transformer_top_profile_no_engine_busy = 0;
            transformer_top_profile_dma_busy = 0;
            transformer_top_last_completion_tail = dut.processor_cplq_tail;
            transformer_top_last_completion_cycle = transformer_top_cycle_counter;
            transformer_top_start_cycle = transformer_top_cycle_counter;
            transformer_top_prefill_target = prefill_descriptor_count;
            transformer_top_final_target = descriptor_count;
            transformer_top_prefill_end_cycle = transformer_top_start_cycle;
            transformer_top_prefill_captured = (prefill_descriptor_count == 0);
            transformer_top_final_captured = 1'b0;
            for (poll_index = 0; poll_index < 13; poll_index = poll_index + 1)
                transformer_top_prefill_profile[poll_index] = 0;
            transformer_top_timing_enable = 1'b1;
            axi_write(REG_DOORBELL, 32'd1);
            for (poll_index = 0; poll_index < 2000000 &&
                 !transformer_top_final_captured; poll_index = poll_index + 1)
                @(posedge aclk);
            transformer_top_timing_enable = 1'b0;
            ai_tinynpu_cnn_measure = 1'b0;
            if (!transformer_top_final_captured)
                $fatal(1, "representative model completion timeout desc_count=%0d cmd_head=%0d cpl_tail=%0d",
                       descriptor_count, dut.processor_cmdq_head, dut.processor_cplq_tail);
            if (dut.processor_cplq_tail != descriptor_count ||
                dut.processor_cmdq_head != descriptor_count)
                $fatal(1, "representative model queue did not retire all commands head=%0d tail=%0d",
                       dut.processor_cmdq_head, dut.processor_cplq_tail);

            for (completion_index = 0; completion_index < descriptor_count;
                 completion_index = completion_index + 1) begin
                axi_read(SPAD_BASE + completion_base + completion_index * 16, read_value);
                if (read_value !== (32'h0000_7100 + completion_index))
                    $fatal(1, "representative completion task ID mismatch index=%0d got=%08h",
                           completion_index, read_value);
                axi_read(SPAD_BASE + completion_base + completion_index * 16 + 4, status_value);
                if (status_value !== 32'd1)
                    $fatal(1, "representative completion failed index=%0d status=%08h",
                           completion_index, status_value);
            end
            for (golden_index = 0; golden_index < golden_count; golden_index = golden_index + 1) begin
                axi_read(SPAD_BASE + representative_golden_words[1 + 2 * golden_index], read_value);
                if (read_value !== representative_golden_words[2 + 2 * golden_index])
                    $fatal(1, "representative Golden mismatch index=%0d addr=%08h expected=%08h actual=%08h",
                           golden_index, representative_golden_words[1 + 2 * golden_index],
                           representative_golden_words[2 + 2 * golden_index], read_value);
            end

            // Optional post-prefix SPAD snapshot for staged descriptor debug.
            // Set DESC_COUNT to stop before the descriptor under investigation;
            // these reads happen after the queue has drained and are outside the
            // measured command window.
            if ($value$plusargs("AI_REPRESENTATIVE_DUMP_FILE=%s",
                                representative_dump_file)) begin
                if (!$value$plusargs("AI_REPRESENTATIVE_DUMP_A_BASE=%d",
                                     representative_dump_base_a) ||
                    !$value$plusargs("AI_REPRESENTATIVE_DUMP_A_WORDS=%d",
                                     representative_dump_words_a) ||
                    !$value$plusargs("AI_REPRESENTATIVE_DUMP_B_BASE=%d",
                                     representative_dump_base_b) ||
                    !$value$plusargs("AI_REPRESENTATIVE_DUMP_B_WORDS=%d",
                                     representative_dump_words_b) ||
                    representative_dump_words_a < 0 ||
                    representative_dump_words_b < 0 ||
                    (representative_dump_base_a[1:0] != 0) ||
                    (representative_dump_base_b[1:0] != 0) ||
                    ((representative_dump_base_a +
                      representative_dump_words_a * 4) > SPAD_BYTES) ||
                    ((representative_dump_base_b +
                      representative_dump_words_b * 4) > SPAD_BYTES))
                    $fatal(1, "invalid representative SPAD dump ranges");
                representative_dump_fd = $fopen(representative_dump_file, "w");
                if (representative_dump_fd == 0)
                    $fatal(1, "could not open representative SPAD dump %0s",
                           representative_dump_file);
                for (representative_dump_index = 0;
                     representative_dump_index < representative_dump_words_a;
                     representative_dump_index = representative_dump_index + 1) begin
                    axi_read(SPAD_BASE + representative_dump_base_a +
                             representative_dump_index * 4, read_value);
                    $fdisplay(representative_dump_fd, "A %08h %08h",
                              representative_dump_base_a +
                              representative_dump_index * 4, read_value);
                end
                for (representative_dump_index = 0;
                     representative_dump_index < representative_dump_words_b;
                     representative_dump_index = representative_dump_index + 1) begin
                    axi_read(SPAD_BASE + representative_dump_base_b +
                             representative_dump_index * 4, read_value);
                    $fdisplay(representative_dump_fd, "B %08h %08h",
                              representative_dump_base_b +
                              representative_dump_index * 4, read_value);
                end
                $fclose(representative_dump_fd);
                $display("REPRESENTATIVE_SPAD_DUMP_PASS file=%0s a_base=%08h a_words=%0d b_base=%08h b_words=%0d",
                         representative_dump_file, representative_dump_base_a,
                         representative_dump_words_a, representative_dump_base_b,
                         representative_dump_words_b);
            end

            matrix_mac_cycles = transformer_top_profile_matrix_mac;
            matrix_wait_cycles = transformer_top_profile_matrix_request_wait;
            matrix_response_wait_cycles = transformer_top_profile_matrix_response_wait;
            matrix_writeback_cycles = transformer_top_profile_matrix_writeback;
            matrix_other_cycles = transformer_top_profile_matrix_other;
            sfu_busy_cycles = transformer_top_profile_sfu_busy;
            kv_busy_cycles = transformer_top_profile_kv_busy;
            conv_busy_cycles = transformer_top_profile_conv_busy;
            banked_busy_cycles = transformer_top_profile_banked_busy;
            fp_busy_cycles = transformer_top_profile_fp_busy;
            scalar_busy_cycles = transformer_top_profile_scalar_busy;
            no_engine_cycles = transformer_top_profile_no_engine_busy;
            dma_busy_cycles = transformer_top_profile_dma_busy;
            command_cycles = transformer_top_final_end_cycle - transformer_top_start_cycle;
            prefill_command_cycles = 0;
            decode_command_cycles = 0;
            prefill_exclusive_cycles = 0;
            decode_exclusive_cycles = 0;
            if (prefill_descriptor_count > 0) begin
                if (!transformer_top_prefill_captured ||
                    transformer_top_prefill_end_cycle <= transformer_top_start_cycle ||
                    transformer_top_prefill_end_cycle > transformer_top_final_end_cycle)
                    $fatal(1, "representative prefill completion boundary was not captured");
                prefill_command_cycles = transformer_top_prefill_end_cycle -
                                         transformer_top_start_cycle;
                decode_command_cycles = transformer_top_final_end_cycle -
                                        transformer_top_prefill_end_cycle;
                for (poll_index = 0; poll_index < 12; poll_index = poll_index + 1)
                    prefill_exclusive_cycles = prefill_exclusive_cycles +
                        transformer_top_prefill_profile[poll_index];
                decode_exclusive_cycles = matrix_mac_cycles + matrix_wait_cycles +
                    matrix_response_wait_cycles + matrix_writeback_cycles +
                    matrix_other_cycles + sfu_busy_cycles + kv_busy_cycles +
                    conv_busy_cycles + banked_busy_cycles + fp_busy_cycles +
                    scalar_busy_cycles + no_engine_cycles - prefill_exclusive_cycles;
                if (prefill_exclusive_cycles != prefill_command_cycles ||
                    decode_exclusive_cycles != decode_command_cycles)
                    $fatal(1, "representative phase profile does not close prefill=%0d/%0d decode=%0d/%0d",
                           prefill_command_cycles, prefill_exclusive_cycles,
                           decode_command_cycles, decode_exclusive_cycles);
            end
            exclusive_profile_cycles = matrix_mac_cycles + matrix_wait_cycles +
                matrix_response_wait_cycles + matrix_writeback_cycles + matrix_other_cycles +
                sfu_busy_cycles + kv_busy_cycles + conv_busy_cycles + banked_busy_cycles +
                fp_busy_cycles + scalar_busy_cycles + no_engine_cycles;
            if (!use_dma_preload)
                preloaded_spad_bytes = image_count * 4;
            if (exclusive_profile_cycles != command_cycles)
                $fatal(1, "representative exclusive profile does not close cycles=%0d buckets=%0d",
                       command_cycles, exclusive_profile_cycles);
            spad_read_bytes = ai_tinynpu_cnn_engine_read_words * 4 +
                              ai_tinynpu_cnn_banked_read_lines * 16;
            spad_write_bytes = ai_tinynpu_cnn_engine_write_words * 4 +
                               ai_tinynpu_cnn_line_write_lines * 16;
            mac_per_cycle = 0.0;
            array_utilization = 0.0;
            if (command_cycles > 0)
                mac_per_cycle = 1.0 * useful_macs / command_cycles;
            if (matrix_mac_cycles > 0)
                array_utilization = 100.0 * useful_macs / (256.0 * matrix_mac_cycles);
            $display("REPRESENTATIVE_MODEL_PASS desc=%0d prefill_desc=%0d decode_desc=%0d golden_words=%0d useful_macs=%0d command_cycles=%0d prefill_command_cycles=%0d decode_command_cycles=%0d prefill_exclusive_cycles=%0d decode_exclusive_cycles=%0d exclusive_profile_cycles=%0d preload_axi_cycles=%0d preload_dma_window_cycles=%0d preload_dma_busy_cycles=%0d preloaded_spad_bytes=%0d mac_per_cycle=%0.4f array_utilization_pct=%0.2f matrix_mac_cycles=%0d matrix_req_wait=%0d matrix_rsp_wait=%0d matrix_writeback=%0d matrix_other=%0d sfu_busy=%0d kv_busy=%0d conv_busy=%0d banked_busy=%0d fp_busy=%0d scalar_busy=%0d no_engine_dispatch_remainder=%0d dma_busy_overlap=%0d spad_read_bytes=%0d spad_write_bytes=%0d",
                     descriptor_count,
                     prefill_descriptor_count > 0 ? prefill_descriptor_count : 0,
                     prefill_descriptor_count > 0 ?
                         descriptor_count - prefill_descriptor_count : 0,
                     golden_count, useful_macs, command_cycles,
                     prefill_command_cycles, decode_command_cycles,
                     prefill_exclusive_cycles, decode_exclusive_cycles,
                     exclusive_profile_cycles, representative_load_cycles,
                     representative_dma_window_cycles,
                     representative_dma_busy_cycles, preloaded_spad_bytes,
                     mac_per_cycle, array_utilization,
                     matrix_mac_cycles, matrix_wait_cycles,
                     matrix_response_wait_cycles, matrix_writeback_cycles,
                     matrix_other_cycles, sfu_busy_cycles, kv_busy_cycles,
                     conv_busy_cycles, banked_busy_cycles, fp_busy_cycles,
                     scalar_busy_cycles, no_engine_cycles, dma_busy_cycles,
                     spad_read_bytes, spad_write_bytes);
            axi_write(REG_CMDQ_SIZE, 32'd0);
            axi_write(REG_CPLQ_SIZE, 32'd0);
            clear_done_irq();
        end
    endtask

    initial begin
        integer pair_engine_a;
        integer pair_engine_b;
        integer pair_index;
        integer pair_setup_i;
        errors = 0;
        seed_arg = 20261014;
        profile_ai_seed = 0;
        $value$plusargs("AI_SEED=%d", profile_ai_seed);
        matrix_line_write_count = 0;
        cp_fetch_done_count = 0;
        last_dma_araddr = 0;
        allow_m_axi_error = 1'b0;
        aresetn = 1'b0;
        axi_idle();
        repeat (8) @(posedge aclk);
        aresetn = 1'b1;
        repeat (4) @(posedge aclk);

        if ($test$plusargs("AI_TRANSFORMER_ONLY")) begin
            run_transformer_only();
            if (errors != 0)
                $fatal(1, "Transformer-only replay had %0d mismatches", errors);
            $display("TRANSFORMER_TOP_ONLY_PASS");
            $finish;
        end

        if ($test$plusargs("AI_H16_INCREMENTAL_DECODE")) begin
            run_h16_incremental_decode();
            if (errors != 0)
                $fatal(1, "H16 incremental decode had %0d mismatches", errors);
            $display("H16_INCREMENTAL_TOP_PASS");
            $finish;
        end

        if ($test$plusargs("AI_REPRESENTATIVE_MODEL")) begin
            run_representative_model();
            $finish;
        end

        if ($test$plusargs("FP_DOT_DMA_BENCH")) begin
            run_fp_dot_dma_benchmark();
            if (errors != 0)
                $fatal(1, "FP benchmark reported %0d errors", errors);
            $finish;
        end

        if ($test$plusargs("R9_MATRIX_DMA_OVERLAP_PROBE")) begin
            run_matrix_dma_overlap_probe();
            $finish;
        end

        if ($test$plusargs("AI_DIGITS_INFERENCE")) begin
            run_ai_digits_inference();
            if (errors != 0)
                $fatal(1, "digits RTL inference reported %0d mismatches", errors);
            $finish;
        end

        if ($test$plusargs("AI_TINYNPU_CNN_MATCH")) begin
            run_tinynpu_cnn_match();
            if (errors != 0)
                $fatal(1, "TinyNPU CNN RTL match reported %0d mismatches", errors);
            $finish;
        end

        expect_read(REG_VERSION, 32'h1000_000a, "version");
        expect_read(FPGA_AXI_BASE + REG_VERSION, 32'h1000_000a,
                    "mapped AXI aperture version");
        expect_read(REG_ABI_INFO, 32'h1040_0407, "ABI v7.4 sizes");
        expect_read(REG_CAP2, 32'h0000_00ff, "architectural capabilities");
        expect_read(REG_ERROR_INFO, 32'h0000_0000, "reset error source");
        axi_write(REG_DMA_EXT_HI, 32'h0000_0001);
        expect_read(REG_DMA_EXT_HI, 32'h0000_0001, "DMA 64-bit address high");
        axi_write(REG_DMA_EXT_HI, 32'd0);
        axi_write(REG_CMDQ_BASE_HI, 32'h0000_0004);
        expect_read(REG_CMDQ_BASE_HI, 32'h0000_0004,
                    "external CMDQ 64-bit address high");
        axi_write(REG_CMDQ_BASE_HI, 32'd0);
        axi_write(REG_TILE_EXT_IN_HI, 32'h0000_0002);
        axi_write(REG_TILE_EXT_OUT_HI, 32'h0000_0003);
        expect_read(REG_TILE_EXT_IN_HI, 32'h0000_0002, "tile input high");
        expect_read(REG_TILE_EXT_OUT_HI, 32'h0000_0003, "tile output high");
        axi_write(REG_TILE_EXT_IN_HI, 32'd0);
        axi_write(REG_TILE_EXT_OUT_HI, 32'd0);
        expect_read(REG_SPAD_INFO, SPAD_BYTES, "512 KiB scratchpad capability");
        axi_write(FPGA_AXI_BASE + SPAD_BASE + 32'h0008, 32'hface_5120);
        expect_read(FPGA_AXI_BASE + SPAD_BASE + 32'h0008, 32'hface_5120,
                    "mapped AXI aperture scratchpad");
        axi_write_bready_preasserted(REG_IRQ_ENABLE, 32'd1);
        expect_read(REG_IRQ_ENABLE, 32'd1, "preasserted-BREADY AXI write");
        axi_write_delayed(SPAD_BASE + 32'h000c, 32'h1234_5678, 3, 0, 2);
        expect_read(SPAD_BASE + 32'h000c, 32'h1234_5678, "split aw/w write");
        expect_slverr_write(REG_VERSION, 32'hdead_beef);
        axi_write(SPAD_BASE + SPAD_BYTES - 32'd4, 32'h5120_cafe);
        expect_read(SPAD_BASE + SPAD_BYTES - 32'd4, 32'h5120_cafe,
                    "scratchpad highest legal word");
        expect_slverr_write(SPAD_BASE + SPAD_BYTES, 32'hdead_beef);
        expect_slverr_read(SPAD_BASE + SPAD_BYTES);

        // VDOT: [1,2,3,4] dot [5,6,7,8] = 70.
        axi_write(SPAD_BASE + 32'h0000, 32'h0403_0201);
        axi_write(SPAD_BASE + 32'h0100, 32'h0807_0605);
        axi_write(REG_OP_MODE, OP_VDOT_INT8);
        axi_write(REG_SRC0_BASE, 32'h0000);
        axi_write(REG_SRC1_BASE, 32'h0100);
        axi_write(REG_DST_BASE,  32'h0200);
        axi_write(REG_LENGTH,    32'd1);
        axi_write(REG_QUANT_ACT, 32'd0);
        axi_write(REG_CTRL,      32'h0000_0003);
        wait_done();
        expect_read(SPAD_BASE + 32'h0200, 32'd70, "vdot output");
        expect_read(REG_RESULT, 32'd70, "vdot result");
        expect_read(REG_CPLQ_TAIL, 32'd0, "direct command does not publish completion");
        if (!irq) begin
            $display("%0t ERROR: irq not asserted after VDOT", $time);
            errors = errors + 1;
        end
        clear_done_irq();

        // GEMV: two rows, one packed INT8 word per row.
        // row0 dot input = 70, row1 dot input = 1+0-3+8 = 6.
        axi_write(SPAD_BASE + 32'h0300, 32'h0403_0201);
        axi_write(SPAD_BASE + 32'h0400, 32'h0807_0605);
        axi_write(SPAD_BASE + 32'h0404, 32'h02ff_0001);
        write_spad_desc(32'h0c00, OP_GEMV_INT8, 16'h0001, 32'h0300, 32'h0400, 32'h0500,
                        16'd2, 16'd0, 16'd1);
        axi_write(REG_CMDQ_SIZE, 32'd0);
        axi_write(REG_CMDQ_BASE_LO, 32'h0c00);
        axi_write(REG_DOORBELL,  32'd1);
        wait_done();
        expect_read(SPAD_BASE + 32'h0500, 32'd70, "gemv row0");
        expect_read(SPAD_BASE + 32'h0504, 32'd6,  "gemv row1");
        expect_read(REG_CMDQ_HEAD, 32'd1, "cmdq head");
        expect_read(REG_CPLQ_TAIL, 32'd0, "disabled completion queue tail after gemv");
        clear_done_irq();

        // Scratchpad command queue ring: size=2, start from entry1, then wrap to entry0.
        write_spad_desc(32'h1000, OP_VDOT_INT8, 16'h0100, 32'h0000, 32'h0100, 32'h1010,
                        16'd0, 16'd0, 16'd1);
        write_spad_desc(32'h1040, OP_VDOT_INT8, 16'h0101, 32'h0000, 32'h0100, 32'h1020,
                        16'd0, 16'd0, 16'd1);
        axi_write(REG_CMDQ_CTRL, 32'd0);
        axi_write(REG_CMDQ_BASE_LO, 32'h1000);
        axi_write(REG_CMDQ_SIZE, 32'd2);
        axi_write(REG_CMDQ_HEAD, 32'd1);
        axi_write(REG_CMDQ_TAIL, 32'd0);
        axi_write(REG_CPLQ_BASE_LO, 32'h1100);
        axi_write(REG_CPLQ_SIZE, 32'd2);
        axi_write(REG_CPLQ_HEAD, 32'd0);
        axi_write(REG_CPLQ_TAIL, 32'd0);
        axi_write(REG_DOORBELL, 32'd1);
        wait_done();
        expect_read(SPAD_BASE + 32'h1020, 32'd70, "ring entry1 vdot");
        expect_read(REG_CMDQ_HEAD, 32'd0, "cmdq head wrap");
        wait_cpl_tail(32'd1, "cplq tail entry1");
        expect_completion(32'h1100, 16'h0101, 4'h1, 4'h0, 32'd70, 32'd1, "cpl entry1");
        // Software consumes completion entry1 before hardware may write the
        // wrapped entry0; otherwise a size-2 ring is intentionally full.
        axi_write(REG_CPLQ_HEAD, 32'd1);
        clear_done_irq();

        // Publish descriptor entry0, then ring once for this submitted work.
        axi_write(REG_CMDQ_TAIL, 32'd1);
        axi_write(REG_DOORBELL, 32'd1);
        wait_done();
        expect_read(SPAD_BASE + 32'h1010, 32'd70, "ring entry0 vdot");
        expect_read(REG_CMDQ_HEAD, 32'd1, "cmdq head next");
        wait_cpl_tail(32'd0, "cplq tail wrap");
        expect_completion(32'h1110, 16'h0100, 4'h1, 4'h0, 32'd70, 32'd1, "cpl entry0");
        axi_write(REG_CPLQ_HEAD, 32'd0);
        clear_done_irq();

        // Empty command queue must be observable and must not issue a fetch.
        axi_read(REG_QUEUE_STATUS, rd);
        if (rd[0] !== 1'b1) begin
            $display("%0t ERROR: expected CMDQ_EMPTY in QUEUE_STATUS", $time);
            errors = errors + 1;
        end
        axi_write(REG_DOORBELL, 32'd1);
        wait_done_expect_error(ERR_CMDQ_EMPTY);
        clear_done_irq();

        // A full completion ring blocks a newly submitted command before its
        // descriptor is fetched, preserving unread completion data.
        axi_write(REG_CMDQ_HEAD, 32'd0);
        axi_write(REG_CMDQ_TAIL, 32'd1);
        axi_write(REG_CPLQ_HEAD, 32'd0);
        axi_write(REG_CPLQ_TAIL, 32'd1);
        axi_read(REG_QUEUE_STATUS, rd);
        if (rd[2] !== 1'b1) begin
            $display("%0t ERROR: expected CPLQ_FULL in QUEUE_STATUS", $time);
            errors = errors + 1;
        end
        axi_write(REG_DOORBELL, 32'd1);
        wait_done_expect_error(ERR_CPLQ_FULL);
        clear_done_irq();
        axi_write(REG_CMDQ_SIZE, 32'd0);
        axi_write(REG_CPLQ_SIZE, 32'd0);

        // GEMM tile: M=2, N=2, K=1 packed word.
        // A row0 [1,2,3,4], row1 [2,0,1,1]
        // B col0 [1,1,1,1], col1 [1,-1,2,0]
        axi_write(SPAD_BASE + 32'h0600, 32'h0403_0201);
        axi_write(SPAD_BASE + 32'h0604, 32'h0101_0002);
        axi_write(SPAD_BASE + 32'h0700, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h0704, 32'h0002_ff01);
        axi_write(REG_OP_MODE, OP_GEMM_INT8_TILE);
        axi_write(REG_SRC0_BASE, 32'h0600);
        axi_write(REG_SRC1_BASE, 32'h0700);
        axi_write(REG_DST_BASE,  32'h0800);
        axi_write(REG_M_SIZE,    32'd2);
        axi_write(REG_N_SIZE,    32'd2);
        axi_write(REG_K_WORDS,   32'd1);
        axi_write(REG_CTRL,      32'h0000_0003);
        wait_done();
        expect_read(SPAD_BASE + 32'h0800, 32'd10, "gemm row0 col0");
        expect_read(SPAD_BASE + 32'h0804, 32'd5,  "gemm row0 col1");
        expect_read(SPAD_BASE + 32'h0808, 32'd4,  "gemm row1 col0");
        expect_read(SPAD_BASE + 32'h080c, 32'd4,  "gemm row1 col1");
        clear_done_irq();

        // NHWC 1x1 convolution: two spatial positions (M=H*W=2), four
        // input channels (K_WORDS=1), and two output channels (N=2).  The
        // packed input/weight layout is the same matrix data flow as GEMM.
        axi_write(REG_OP_MODE, OP_CONV1X1_INT8);
        axi_write(REG_SRC0_BASE, 32'h0600);
        axi_write(REG_SRC1_BASE, 32'h0700);
        axi_write(REG_DST_BASE,  32'h0900);
        axi_write(REG_M_SIZE,    32'd2);
        axi_write(REG_N_SIZE,    32'd2);
        axi_write(REG_K_WORDS,   32'd1);
        axi_write(REG_CTRL,      32'h0000_0003);
        wait_done();
        expect_read(SPAD_BASE + 32'h0900, 32'd10, "conv1x1 pixel0 channel0");
        expect_read(SPAD_BASE + 32'h0904, 32'd5,  "conv1x1 pixel0 channel1");
        expect_read(SPAD_BASE + 32'h0908, 32'd4,  "conv1x1 pixel1 channel0");
        expect_read(SPAD_BASE + 32'h090c, 32'd4,  "conv1x1 pixel1 channel1");
        clear_done_irq();

        // A2 CONV3x3: one im2col patch (9 valid lanes, padded to three
        // words). Channel0 uses +1 weights and bias +5; channel1 uses -1
        // weights and bias +40. ReLU6 clamps the results to 6 and zero.
        axi_write(SPAD_BASE + 32'h3a00, 32'h0403_0201);
        axi_write(SPAD_BASE + 32'h3a04, 32'h0807_0605);
        axi_write(SPAD_BASE + 32'h3a08, 32'h0000_0009);
        axi_write(SPAD_BASE + 32'h3b00, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h3b04, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h3b08, 32'h0000_0001);
        axi_write(SPAD_BASE + 32'h3b0c, 32'hffff_ffff);
        axi_write(SPAD_BASE + 32'h3b10, 32'hffff_ffff);
        axi_write(SPAD_BASE + 32'h3b14, 32'h0000_00ff);
        axi_write(SPAD_BASE + 32'h3c00, 32'd5);
        axi_write(SPAD_BASE + 32'h3c04, 32'd40);
        axi_write(REG_OP_MODE, OP_CONV3X3_INT8);
        axi_write(REG_SRC0_BASE, 32'h3a00);
        axi_write(REG_SRC1_BASE, 32'h3b00);
        axi_write(REG_DST_BASE,  32'h3d00);
        axi_write(REG_M_SIZE,    32'd1);
        axi_write(REG_N_SIZE,    32'd2);
        axi_write(REG_K_WORDS,   32'd3);
        axi_write(REG_BIAS_BASE, 32'h3c00);
        axi_write(REG_POST_CTRL, 32'd1);
        axi_write(REG_QUANT_ACT, 32'h0000_0040);
        axi_write(REG_CTRL,      32'h0000_0003);
        wait_done();
        expect_read(SPAD_BASE + 32'h3d00, 32'd6, "conv3x3 bias relu6 ch0");
        expect_read(SPAD_BASE + 32'h3d04, 32'd0, "conv3x3 bias relu6 ch1");
        clear_done_irq();

        // DWConv3x3 input patches are laid out per {pixel,channel}; each
        // channel consumes only its own packed kernel vector.
        axi_write(SPAD_BASE + 32'h3e00, 32'h0403_0201);
        axi_write(SPAD_BASE + 32'h3e04, 32'h0807_0605);
        axi_write(SPAD_BASE + 32'h3e08, 32'h0000_0009);
        axi_write(SPAD_BASE + 32'h3e0c, 32'h0202_0202);
        axi_write(SPAD_BASE + 32'h3e10, 32'h0202_0202);
        axi_write(SPAD_BASE + 32'h3e14, 32'h0000_0002);
        axi_write(SPAD_BASE + 32'h3b0c, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h3b10, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h3b14, 32'h0000_0001);
        axi_write(REG_OP_MODE, OP_DWCONV3X3_INT8);
        axi_write(REG_SRC0_BASE, 32'h3e00);
        axi_write(REG_SRC1_BASE, 32'h3b00);
        axi_write(REG_DST_BASE,  32'h3f00);
        axi_write(REG_M_SIZE,    32'd1);
        axi_write(REG_N_SIZE,    32'd2);
        axi_write(REG_K_WORDS,   32'd3);
        axi_write(REG_POST_CTRL, 32'd0);
        axi_write(REG_PERF_CTRL, 32'd1);
        axi_write(REG_QUANT_ACT, 32'd0);
        axi_write(REG_CTRL,      32'h0000_0003);
        wait_done();
        expect_read(SPAD_BASE + 32'h3f00, 32'd45, "dwconv3x3 ch0");
        expect_read(SPAD_BASE + 32'h3f04, 32'd18, "dwconv3x3 ch1");
        clear_done_irq();

        // Bank-striped layout: one K group is 16 bytes.  The four words at
        // offsets +0/+4/+8/+c map to bank0..bank3 and are processed in
        // parallel by BANKED_VDOT/BANKED_GEMV.
        axi_write(SPAD_BASE + 32'h3000, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h3004, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h3008, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h300c, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h3100, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h3104, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h3108, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h310c, 32'h0101_0101);
        axi_write(REG_OP_MODE, OP_BANKED_VDOT);
        axi_write(REG_SRC0_BASE, 32'h3000);
        axi_write(REG_SRC1_BASE, 32'h3100);
        axi_write(REG_DST_BASE,  32'h3200);
        axi_write(REG_LENGTH,    32'd1);
        axi_write(REG_CTRL,      32'h0000_0003);
        wait_done();
        expect_read(SPAD_BASE + 32'h3200, 32'd16, "banked vdot");
        expect_read(REG_RESULT, 32'd16, "banked vdot result");
        clear_done_irq();

        // Exercise address bit 18 through the banked datapath.  This catches
        // any accidental retention of the former 12-bit/64 KiB row index.
        axi_write(SPAD_BASE + 32'h0007_ffe0, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h0007_ffe4, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h0007_ffe8, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h0007_ffec, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h0007_fff0, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h0007_fff4, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h0007_fff8, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h0007_fffc, 32'h0101_0101);
        axi_write(REG_OP_MODE, OP_BANKED_VDOT);
        axi_write(REG_SRC0_BASE, 32'h0007_ffe0);
        axi_write(REG_SRC1_BASE, 32'h0007_fff0);
        axi_write(REG_DST_BASE,  32'h0000_3400);
        axi_write(REG_LENGTH,    32'd1);
        axi_write(REG_CTRL,      32'h0000_0003);
        wait_done();
        expect_read(SPAD_BASE + 32'h0000_3400, 32'd16,
                    "banked vdot at 512 KiB boundary");
        clear_done_irq();

        // Two GEMV rows share the bank-striped input; each weight row occupies
        // LENGTH*16 bytes.  Row0 uses all ones, row1 uses all twos.
        axi_write(SPAD_BASE + 32'h3110, 32'h0202_0202);
        axi_write(SPAD_BASE + 32'h3114, 32'h0202_0202);
        axi_write(SPAD_BASE + 32'h3118, 32'h0202_0202);
        axi_write(SPAD_BASE + 32'h311c, 32'h0202_0202);
        axi_write(REG_OP_MODE, OP_BANKED_GEMV);
        axi_write(REG_SRC0_BASE, 32'h3000);
        axi_write(REG_SRC1_BASE, 32'h3100);
        axi_write(REG_DST_BASE,  32'h3300);
        axi_write(REG_LENGTH,    32'd1);
        axi_write(REG_M_SIZE,    32'd2);
        axi_write(REG_CTRL,      32'h0000_0003);
        wait_done();
        expect_read(SPAD_BASE + 32'h3300, 32'd16, "banked gemv row0");
        expect_read(SPAD_BASE + 32'h3304, 32'd32, "banked gemv row1");
        clear_done_irq();

        // CNM integration case: three K-groups use bank-distinct words.  A
        // is +1 throughout; B group values are +1, +2 and -1, giving
        // 16 + 32 - 16 = 32.  Unlike the focused A2.2 unit test, this runs
        // through AXI-Lite, command processor, SPAD arbiter and writeback.
        axi_write(SPAD_BASE + 32'h3500, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h3504, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h3508, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h350c, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h3510, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h3514, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h3518, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h351c, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h3520, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h3524, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h3528, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h352c, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h3600, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h3604, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h3608, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h360c, 32'h0101_0101);
        axi_write(SPAD_BASE + 32'h3610, 32'h0202_0202);
        axi_write(SPAD_BASE + 32'h3614, 32'h0202_0202);
        axi_write(SPAD_BASE + 32'h3618, 32'h0202_0202);
        axi_write(SPAD_BASE + 32'h361c, 32'h0202_0202);
        axi_write(SPAD_BASE + 32'h3620, 32'hffff_ffff);
        axi_write(SPAD_BASE + 32'h3624, 32'hffff_ffff);
        axi_write(SPAD_BASE + 32'h3628, 32'hffff_ffff);
        axi_write(SPAD_BASE + 32'h362c, 32'hffff_ffff);
        axi_write(REG_OP_MODE, OP_BANKED_VDOT);
        axi_write(REG_SRC0_BASE, 32'h3500);
        axi_write(REG_SRC1_BASE, 32'h3600);
        axi_write(REG_DST_BASE,  32'h3700);
        axi_write(REG_LENGTH,    32'd3);
        axi_write(REG_CTRL,      32'h0000_0003);
        wait_done();
        expect_read(SPAD_BASE + 32'h3700, 32'd32, "CNM A2 multi-group vdot");
        expect_read(REG_RESULT, 32'd32, "CNM A2 multi-group result");
        clear_done_irq();

        // DMA load external input/weight into scratchpad, compute VDOT, then DMA store result out.
        axi_mem_u.mem[10'h100] = 32'h0403_0201;
        axi_mem_u.mem[10'h101] = 32'h0807_0605;
        dma_load(32'h0000_0400, 32'h2000, 16'd2);
        expect_read(SPAD_BASE + 32'h2000, 32'h0403_0201, "dma load input");
        expect_read(SPAD_BASE + 32'h2004, 32'h0807_0605, "dma load weight");
        axi_write(REG_OP_MODE, OP_VDOT_INT8);
        axi_write(REG_SRC0_BASE, 32'h2000);
        axi_write(REG_SRC1_BASE, 32'h2004);
        axi_write(REG_DST_BASE,  32'h2010);
        axi_write(REG_LENGTH,    32'd1);
        axi_write(REG_QUANT_ACT, 32'd0);
        axi_write(REG_CTRL,      32'h0000_0003);
        wait_done();
        expect_read(SPAD_BASE + 32'h2010, 32'd70, "dma vdot output");
        dma_store(32'h0000_0500, 32'h2010, 16'd1);
        if (axi_mem_u.mem[10'h140] !== 32'd70) begin
            $display("%0t ERROR: dma store expected=%08h actual=%08h",
                     $time, 32'd70, axi_mem_u.mem[10'h140]);
            errors = errors + 1;
        end else begin
            $display("%0t PASS: dma store output = %0d/%08h", $time,
                     axi_mem_u.mem[10'h140], axi_mem_u.mem[10'h140]);
        end

        // A2 ping-pong pipeline with an odd tile count.  This exercises both
        // buffer contexts, context reuse, and incremental external strides.
        axi_mem_u.mem[11'h600] = 32'h0403_0201;
        axi_mem_u.mem[11'h601] = 32'h0202_0202;
        axi_mem_u.mem[11'h602] = 32'h0303_0303;
        axi_mem_u.mem[11'h680] = 32'd0;
        axi_mem_u.mem[11'h681] = 32'd0;
        axi_mem_u.mem[11'h682] = 32'd0;
        axi_write(SPAD_BASE + 32'h4400, 32'h0101_0101);
        axi_write(REG_OP_MODE, OP_VDOT_INT8);
        axi_write(REG_SRC1_BASE, 32'h4400);
        axi_write(REG_LENGTH, 32'd1);
        axi_write(REG_POST_CTRL, 32'd0);
        axi_write(REG_QUANT_ACT, 32'd0);
        axi_write(REG_TILE_COUNT, 32'd3);
        axi_write(REG_TILE_EXT_IN, 32'h0000_1800);
        axi_write(REG_TILE_EXT_OUT, 32'h0000_1a00);
        axi_write(REG_TILE_EXT_IN_STRIDE, 32'd4);
        axi_write(REG_TILE_EXT_OUT_STRIDE, 32'd4);
        axi_write(REG_TILE_BUF0, 32'h0000_4000);
        axi_write(REG_TILE_BUF1, 32'h0000_4200);
        axi_write(REG_TILE_IN_WORDS, 32'd1);
        axi_write(REG_TILE_OUT_WORDS, 32'd1);
        axi_write(REG_TILE_OUT_OFFSET, 32'h0000_0040);
        axi_write(REG_TILE_CTRL, 32'd1);
        wait_done();
        if ((axi_mem_u.mem[11'h680] !== 32'd10) ||
            (axi_mem_u.mem[11'h681] !== 32'd8) ||
            (axi_mem_u.mem[11'h682] !== 32'd12)) begin
            $display("%0t ERROR: A2 tile outputs expected=10,8,12 actual=%0d,%0d,%0d",
                     $time, axi_mem_u.mem[11'h680], axi_mem_u.mem[11'h681],
                     axi_mem_u.mem[11'h682]);
            errors = errors + 1;
        end else begin
            $display("%0t PASS: A2 ping-pong tile outputs", $time);
        end
        expect_read(REG_TILE_COMPLETED, 32'd3, "A2 completed tiles");
        axi_read(REG_PERF_TOTAL, rd);
        if (rd == 0) begin
            $display("%0t ERROR: A2 total cycle counter is zero", $time);
            errors = errors + 1;
        end
        axi_read(REG_PERF_DMA, rd);
        if (rd == 0) begin
            $display("%0t ERROR: A2 DMA cycle counter is zero", $time);
            errors = errors + 1;
        end
        axi_read(REG_PERF_COMPUTE, rd);
        if (rd == 0) begin
            $display("%0t ERROR: A2 compute cycle counter is zero", $time);
            errors = errors + 1;
        end
        axi_read(REG_PERF_OVERLAP, rd);
        if (rd == 0) begin
            $display("%0t ERROR: A2 pipeline recorded no DMA/compute overlap", $time);
            errors = errors + 1;
        end else begin
            $display("%0t PASS: A2 overlap cycles = %0d", $time, rd);
        end
        clear_done_irq();

        // Multi-burst DMA load with random-ish write back-pressure.
        axi_mem_u.ready_gap_cfg = 1;
        begin : multi_burst_load
            integer i;
            for (i = 0; i < 80; i = i + 1)
                axi_mem_u.mem[11'h200 + i] = 32'ha500_0000 + i;
            fork
                begin : check_dma64
                    @(posedge aclk);
                    while (!(m_axi_arvalid && m_axi_arready)) @(posedge aclk);
                    if (m_axi_arlen !== 8'd15) begin
                        $display("%0t ERROR: expected 16-beat DMA burst, ARLEN=%0d",
                                 $time, m_axi_arlen);
                        errors = errors + 1;
                    end else begin
                        $display("%0t PASS: DMA issued 16-beat burst", $time);
                    end
                end
                begin : check_dma_read_outstanding
                    integer accepted_ar;
                    accepted_ar = 0;
                    while (!(m_axi_rvalid && m_axi_rready && m_axi_rlast)) begin
                        @(posedge aclk);
                        if (m_axi_arvalid && m_axi_arready)
                            accepted_ar = accepted_ar + 1;
                    end
                    if (accepted_ar < 2) begin
                        $display("%0t ERROR: expected multiple outstanding AR, accepted=%0d",
                                 $time, accepted_ar);
                        errors = errors + 1;
                    end else begin
                        $display("%0t PASS: DMA read outstanding accepted=%0d",
                                 $time, accepted_ar);
                    end
                end
                begin
                    dma_load(32'h0000_0800, 32'h2400, 16'd80);
                end
            join
            for (i = 0; i < 80; i = i + 1)
                expect_read(SPAD_BASE + 32'h2400 + (i * 4), 32'ha500_0000 + i, "dma multi load");
        end

        // Unified read-DMA depth-four saturation.  Four 16-beat bursts must be
        // accepted before the first response burst completes.  This checks
        // the actual register-programmed window rather than merely proving
        // that a second AR can coexist with the first response.
        axi_mem_u.ready_gap_cfg = 0;
        begin : dma_read_outstanding_depth4
            integer i;
            integer accepted_ar;
            integer first_rlast_seen;
            accepted_ar = 0;
            first_rlast_seen = 0;
            for (i = 0; i < 256; i = i + 1)
                axi_mem_u.mem[11'h500 + i] = 32'hd400_0000 + i;
            axi_write(REG_DMA_CFG, 32'h0000_0400);
            axi_write(REG_DMA_EXT_ADDR, 32'h0000_1400);
            axi_write(REG_DMA_SPAD_ADDR, 32'h0000_3600);
            axi_write(REG_DMA_LENGTH, 16'd256);
            fork
                begin : observe_depth4_window
                    while (!first_rlast_seen) begin
                        @(posedge aclk);
                        if (m_axi_arvalid && m_axi_arready)
                            accepted_ar = accepted_ar + 1;
                        if (m_axi_rvalid && m_axi_rready && m_axi_rlast)
                            first_rlast_seen = 1;
                    end
                    if (accepted_ar < 4) begin
                        $display("%0t ERROR: A4 expected four AR before first RLAST, accepted=%0d",
                                 $time, accepted_ar);
                        errors = errors + 1;
                    end else begin
                        $display("%0t PASS: A4 DMA read outstanding saturated at %0d", $time,
                                 accepted_ar);
                    end
                end
                begin : issue_depth4_load
                    axi_write(REG_DMA_CTRL, 32'h0000_0001);
                    wait_dma_done();
                    clear_dma_done();
                end
            join
            expect_read(SPAD_BASE + 32'h3600, 32'hd400_0000,
                        "A4 depth4 dma first word");
            expect_read(SPAD_BASE + 32'h36fc, 32'hd400_003f,
                        "A4 depth4 dma burst0 last word");
            expect_read(SPAD_BASE + 32'h3700, 32'hd400_0040,
                        "A4 depth4 dma burst1 first word");
            expect_read(SPAD_BASE + 32'h39fc, 32'hd400_00ff,
                        "A4 depth4 dma final word");
        end

        // 4KB boundary split: starts at 0x0ff8 and transfers across the page.
        axi_mem_u.mem[11'h3fe] = 32'h1111_0000;
        axi_mem_u.mem[11'h3ff] = 32'h2222_0000;
        axi_mem_u.mem[11'h400] = 32'h3333_0000;
        axi_mem_u.mem[11'h401] = 32'h4444_0000;
        dma_load(32'h0000_0ff8, 32'h2600, 16'd4);
        expect_read(SPAD_BASE + 32'h2600, 32'h1111_0000, "dma 4kb split0");
        expect_read(SPAD_BASE + 32'h2604, 32'h2222_0000, "dma 4kb split1");
        expect_read(SPAD_BASE + 32'h2608, 32'h3333_0000, "dma 4kb split2");
        expect_read(SPAD_BASE + 32'h260c, 32'h4444_0000, "dma 4kb split3");

        // 2D DMA load: two 2-word rows, with a 2-word gap in both source and
        // destination.  Each row still uses the normal burst engine.
        axi_mem_u.mem[11'h300] = 32'h1000_0001;
        axi_mem_u.mem[11'h301] = 32'h1000_0002;
        axi_mem_u.mem[11'h304] = 32'h2000_0001;
        axi_mem_u.mem[11'h305] = 32'h2000_0002;
        axi_write(REG_DMA_EXT_ADDR, 32'h0000_0c00);
        axi_write(REG_DMA_SPAD_ADDR, 32'h0000_2c00);
        axi_write(REG_DMA_LENGTH, 32'd0);
        axi_write(REG_DMA_ROW_WORDS, 32'd2);
        axi_write(REG_DMA_ROW_COUNT, 32'd2);
        axi_write(REG_DMA_EXT_STRIDE, 32'd16);
        axi_write(REG_DMA_SPAD_STRIDE, 32'd16);
        axi_write(REG_DMA_CTRL, 32'h0000_0001);
        wait_dma_done();
        clear_dma_done();
        expect_read(SPAD_BASE + 32'h2c00, 32'h1000_0001, "dma 2d row0 word0");
        expect_read(SPAD_BASE + 32'h2c04, 32'h1000_0002, "dma 2d row0 word1");
        expect_read(SPAD_BASE + 32'h2c10, 32'h2000_0001, "dma 2d row1 word0");
        expect_read(SPAD_BASE + 32'h2c14, 32'h2000_0002, "dma 2d row1 word1");
        axi_write(REG_DMA_EXT_ADDR, 32'h0000_0d00);
        axi_write(REG_DMA_SPAD_ADDR, 32'h0000_2c00);
        axi_write(REG_DMA_CTRL, 32'h0000_0003);
        wait_dma_done();
        clear_dma_done();
        if ((axi_mem_u.mem[11'h340] !== 32'h1000_0001) ||
            (axi_mem_u.mem[11'h341] !== 32'h1000_0002) ||
            (axi_mem_u.mem[11'h344] !== 32'h2000_0001) ||
            (axi_mem_u.mem[11'h345] !== 32'h2000_0002)) begin
            $display("%0t ERROR: dma 2d store mismatch", $time);
            errors = errors + 1;
        end else begin
            $display("%0t PASS: dma 2d store", $time);
        end

        // A4 KV-cache gather: the scratchpad index table contains absolute
        // DDR byte addresses.  Rows are gathered into consecutive destination
        // tiles while the configured read window permits four accepted ARs.
        axi_mem_u.mem[11'h440] = 32'h4b56_0001;
        axi_mem_u.mem[11'h441] = 32'h4b56_0002;
        axi_mem_u.mem[11'h480] = 32'h4b56_0011;
        axi_mem_u.mem[11'h481] = 32'h4b56_0012;
        axi_write(SPAD_BASE + 32'h2d00, 32'h0000_1100);
        axi_write(SPAD_BASE + 32'h2d04, 32'h0000_1200);
        axi_write(REG_DMA_SPAD_ADDR, 32'h0000_2d20);
        axi_write(REG_DMA_ROW_WORDS, 32'd2);
        axi_write(REG_DMA_ROW_COUNT, 32'd2);
        axi_write(REG_DMA_SPAD_STRIDE, 32'd16);
        axi_write(REG_DMA_GATHER_INDEX, 32'h0000_2d00);
        axi_write(REG_DMA_CFG, 32'h0000_0401);
        axi_write(REG_DMA_CTRL, 32'h0000_0001);
        wait_dma_done();
        clear_dma_done();
        expect_read(SPAD_BASE + 32'h2d20, 32'h4b56_0001, "A4 KV gather row0 word0");
        expect_read(SPAD_BASE + 32'h2d24, 32'h4b56_0002, "A4 KV gather row0 word1");
        expect_read(SPAD_BASE + 32'h2d30, 32'h4b56_0011, "A4 KV gather row1 word0");
        expect_read(SPAD_BASE + 32'h2d34, 32'h4b56_0012, "A4 KV gather row1 word1");
        axi_write(REG_DMA_CFG, 32'h0000_0400);
        axi_write(REG_DMA_ROW_COUNT, 32'd0);
        axi_write(REG_DMA_ROW_WORDS, 32'd0);
        axi_write(REG_DMA_EXT_STRIDE, 32'd0);
        axi_write(REG_DMA_SPAD_STRIDE, 32'd0);

        // Write response error injection.
        axi_mem_u.inject_write_error_word = 32'h0000_0180;
        dma_store_expect_error(32'h0000_0600, 32'h2010, 16'd1, 4'd3);
        axi_mem_u.inject_write_error_word = -1;

        // Read response error injection.
        axi_mem_u.inject_read_error_word = 32'h0000_0184;
        dma_load_expect_error(32'h0000_0610, 32'h2800, 16'd1, 4'd2);
        expect_read(REG_ERROR_INFO, 32'h0000_0022,
                    "ABI error source DMA/read");
        axi_mem_u.inject_read_error_word = -1;

        // A7 external address path: a non-zero high dword must reach ARADDR.
        // The compact memory model intentionally rejects addresses above 4 GiB.
        axi_write(REG_DMA_EXT_HI, 32'h0000_0001);
        dma_load_expect_error(32'h0000_0620, 32'h2820, 16'd1, 4'd2);
        if (last_dma_araddr != 64'h0000_0001_0000_0620) begin
            $display("%0t ERROR: 64-bit DMA ARADDR truncated to %h",
                     $time, last_dma_araddr);
            errors = errors + 1;
        end
        axi_write(REG_DMA_EXT_HI, 32'd0);

        // Abort an accepted read burst.  The DMA must drain through RLAST,
        // report ERR_ABORT, and leave no external read transaction active.
        begin : dma_load_abort
            integer i;
            integer accepted;
            for (i = 0; i < 20; i = i + 1)
                axi_mem_u.mem[11'h380 + i] = 32'hab00_0000 + i;
            axi_mem_u.ready_gap_cfg = 2;
            axi_write(REG_DMA_EXT_ADDR, 32'h0000_0e00);
            axi_write(REG_DMA_SPAD_ADDR, 32'h0000_2e00);
            axi_write(REG_DMA_LENGTH, 32'd20);
            axi_write(REG_DMA_CTRL, 32'h0000_0001);
            accepted = 0;
            for (i = 0; i < 100 && !accepted; i = i + 1) begin
                @(posedge aclk);
                accepted = axi_mem_u.read_active_r;
            end
            if (!accepted) begin
                $display("%0t ERROR: DMA load abort test observed no accepted AR", $time);
                errors = errors + 1;
            end
            axi_write(REG_ABORT, 32'd1);
            expect_dma_done(1'b1, 4'd5);
            if (axi_mem_u.read_active_r || m_axi_rvalid) begin
                $display("%0t ERROR: DMA load abort left an AXI read active", $time);
                errors = errors + 1;
            end else begin
                $display("%0t PASS: DMA load abort drained accepted AXI burst", $time);
            end
        end

        // Abort an accepted write burst.  AXI4 does not permit truncating an
        // accepted burst, so the DMA must finish WLAST/B before reporting.
        begin : dma_store_abort
            integer i;
            integer accepted;
            for (i = 0; i < 20; i = i + 1)
                axi_write(SPAD_BASE + 32'h3000 + (i * 4), 32'hcd00_0000 + i);
            axi_mem_u.ready_gap_cfg = 2;
            axi_write(REG_DMA_EXT_ADDR, 32'h0000_1000);
            axi_write(REG_DMA_SPAD_ADDR, 32'h0000_3000);
            axi_write(REG_DMA_LENGTH, 32'd20);
            axi_write(REG_DMA_CTRL, 32'h0000_0003);
            accepted = 0;
            for (i = 0; i < 100 && !accepted; i = i + 1) begin
                @(posedge aclk);
                accepted = axi_mem_u.write_active_r;
            end
            if (!accepted) begin
                $display("%0t ERROR: DMA store abort test observed no accepted AW", $time);
                errors = errors + 1;
            end
            @(posedge aclk);
            axi_write(REG_ABORT, 32'd1);
            expect_dma_done(1'b1, 4'd5);
            if (axi_mem_u.write_active_r || m_axi_bvalid || m_axi_wvalid) begin
                $display("%0t ERROR: DMA store abort left an AXI write active", $time);
                errors = errors + 1;
            end else begin
                $display("%0t PASS: DMA store abort completed accepted AXI burst", $time);
            end
        end
        axi_mem_u.ready_gap_cfg = 0;

        // External-memory descriptor v2 fetch through AXI read channel.  Word
        // 3 carries bias_base and word 7 enables per-output bias.
        axi_write(SPAD_BASE + 32'h2b00, 32'd5);
        axi_write(SPAD_BASE + 32'h2b04, 32'hffff_fffa);
        write_axi_desc(32'h0000_0c00, OP_GEMV_INT8, 16'h0200, 32'h0300, 32'h0400, 32'h2900,
                       16'd2, 16'd0, 16'd1);
        axi_mem_u.mem[11'h303] = 32'h0000_2b00;
        axi_mem_u.mem[11'h307] = 32'd1;
        axi_write(REG_CMDQ_CTRL, 32'd1);
        axi_write(REG_CMDQ_SIZE, 32'd0);
        axi_write(REG_CMDQ_BASE_LO, 32'h0000_0c00);
        axi_write(REG_DOORBELL, 32'd1);
        wait_done();
        expect_read(SPAD_BASE + 32'h2900, 32'd75, "external desc v2 bias row0");
        expect_read(SPAD_BASE + 32'h2904, 32'd0, "external desc v2 bias row1");
        axi_write(REG_CMDQ_CTRL, 32'd0);
        clear_done_irq();

        // External-memory command queue ring plus invalid descriptor completion.
        write_axi_desc(32'h0000_0d00, OP_VDOT_INT8, 16'h0201, 32'h0000, 32'h0100, 32'h2a00,
                       16'd0, 16'd0, 16'd1);
        write_axi_desc(32'h0000_0d40, 8'hff, 16'h02ff, 32'h0000, 32'h0100, 32'h2a10,
                       16'd0, 16'd0, 16'd1);
        axi_write(REG_CMDQ_CTRL, 32'd1);
        axi_write(REG_CMDQ_BASE_LO, 32'h0000_0d00);
        axi_write(REG_CMDQ_SIZE, 32'd2);
        axi_write(REG_CMDQ_HEAD, 32'd0);
        axi_write(REG_CMDQ_TAIL, 32'd1);
        axi_write(REG_CPLQ_BASE_LO, 32'h1200);
        axi_write(REG_CPLQ_SIZE, 32'd2);
        axi_write(REG_CPLQ_HEAD, 32'd0);
        axi_write(REG_CPLQ_TAIL, 32'd0);
        axi_write(REG_DOORBELL, 32'd1);
        wait_done();
        expect_read(SPAD_BASE + 32'h2a00, 32'd70, "external ring vdot");
        expect_read(REG_CMDQ_HEAD, 32'd1, "external cmdq head");
        wait_cpl_tail(32'd1, "external cplq tail ok");
        expect_completion(32'h1200, 16'h0201, 4'h1, 4'h0, 32'd70, 32'd1, "external cpl ok");
        axi_write(REG_CPLQ_HEAD, 32'd1);
        clear_done_irq();

        axi_write(REG_CMDQ_TAIL, 32'd0);
        axi_write(REG_DOORBELL, 32'd1);
        wait_done_expect_error(ERR_DESC_INVALID);
        expect_read(REG_ERROR_INFO, 32'h0000_0017,
                    "ABI error source command/descriptor");
        expect_read(REG_CMDQ_HEAD, 32'd0, "external cmdq wrap after bad desc");
        wait_cpl_tail(32'd0, "external cplq wrap after bad desc");
        expect_completion(32'h1210, 16'h02ff, 4'h2, ERR_DESC_INVALID, 32'd0, 32'd0, "external cpl bad");
        axi_write(REG_CMDQ_CTRL, 32'd0);
        axi_write(REG_CMDQ_SIZE, 32'd0);
        axi_write(REG_CPLQ_SIZE, 32'd0);
        clear_done_irq();

        // PACK_I8_TILE_A is legal only when flags[4] is also set and the
        // descriptor length exactly matches the 4x4-compatible MxN shape.
        write_spad_desc_v3(32'h7500, OP_REQUANT_I8, 16'h02f0,
                           32'h7700, 32'd0, 32'd0, 32'h7740,
                           16'd4, 16'd8, 16'd31, 8'h30, 32'd0,
                           5'd0, 2'd0, 32'd0, 32'd0, 32'd0,
                           16'd1, 16'd1, 16'd0, 16'd0, 16'd0);
        axi_write(SPAD_BASE + 32'h7740, 32'hface_cafe);
        axi_write(REG_CMDQ_CTRL, 32'd0);
        axi_write(REG_CMDQ_BASE_LO, 32'h7500);
        axi_write(REG_CMDQ_SIZE, 32'd2);
        axi_write(REG_CMDQ_HEAD, 32'd0);
        axi_write(REG_CMDQ_TAIL, 32'd1);
        axi_write(REG_CPLQ_BASE_LO, 32'h7600);
        axi_write(REG_CPLQ_SIZE, 32'd2);
        axi_write(REG_CPLQ_HEAD, 32'd0);
        axi_write(REG_CPLQ_TAIL, 32'd0);
        axi_write(REG_DOORBELL, 32'd1);
        wait_done_expect_error(ERR_DESC_INVALID);
        wait_cpl_tail(32'd1, "invalid Matrix-A packed requant tail");
        expect_completion(32'h7600, 16'h02f0, 4'h2, ERR_DESC_INVALID,
                          32'd0, 32'd0, "invalid Matrix-A packed requant");
        expect_read(SPAD_BASE + 32'h7740, 32'hface_cafe,
                    "invalid Matrix-A packed requant no write");
        axi_write(REG_CMDQ_SIZE, 32'd0);
        axi_write(REG_CPLQ_SIZE, 32'd0);
        clear_done_irq();

        // A3 4x4 tensor GEMM.  A is multiplied by an identity matrix stored
        // in column-vector tile layout, so the INT32 output must equal A.
        axi_write(SPAD_BASE + 32'h4800, 32'h0403_0201);
        axi_write(SPAD_BASE + 32'h4804, 32'h0807_0605);
        axi_write(SPAD_BASE + 32'h4808, 32'h0000_0001);
        axi_write(SPAD_BASE + 32'h480c, 32'h01ff_01ff);
        axi_write(SPAD_BASE + 32'h4900, 32'h0000_0001);
        axi_write(SPAD_BASE + 32'h4904, 32'h0000_0100);
        axi_write(SPAD_BASE + 32'h4908, 32'h0001_0000);
        axi_write(SPAD_BASE + 32'h490c, 32'h0100_0000);
        axi_write(REG_POST_CTRL, 32'd0);
        axi_write(REG_PERF_CTRL, 32'd1);
        axi_write(REG_QUANT_ACT, 32'd0);
        axi_write(REG_OP_MODE, OP_TENSOR_GEMM);
        axi_write(REG_SRC0_BASE, 32'h4800);
        axi_write(REG_SRC1_BASE, 32'h4900);
        axi_write(REG_DST_BASE,  32'h4a00);
        axi_write(REG_M_SIZE, 32'd4);
        axi_write(REG_N_SIZE, 32'd4);
        axi_write(REG_K_WORDS, 32'd1);
        matrix_line_write_count = 0;
        axi_write(REG_CTRL, 32'h0000_0003);
        wait_done();
        if (matrix_line_write_count != 4) begin
            $display("%0t ERROR: A7 matrix expected 4 line writes, got %0d",
                     $time, matrix_line_write_count);
            errors = errors + 1;
        end
        expect_read(SPAD_BASE + 32'h4a00, 32'd1, "A3 GEMM c00");
        expect_read(SPAD_BASE + 32'h4a0c, 32'd4, "A3 GEMM c03");
        expect_read(SPAD_BASE + 32'h4a10, 32'd5, "A3 GEMM c10");
        expect_read(SPAD_BASE + 32'h4a1c, 32'd8, "A3 GEMM c13");
        expect_read(SPAD_BASE + 32'h4a20, 32'd1, "A3 GEMM c20");
        expect_read(SPAD_BASE + 32'h4a30, 32'hffff_ffff, "A3 GEMM c30");
        expect_read(SPAD_BASE + 32'h4a3c, 32'd1, "A3 GEMM c33");
        axi_read(REG_PERF_MATRIX_CYCLES, rd);
        if (rd == 0) begin
            $display("%0t ERROR: A5 matrix cycle counter is zero", $time);
            errors = errors + 1;
        end
        axi_read(REG_PERF_MATRIX_MAC_CYCLES, rd);
        if (rd == 0) begin
            $display("%0t ERROR: A5 matrix MAC-active counter is zero", $time);
            errors = errors + 1;
        end
        clear_done_irq();

        // Product opcode 0x52 descriptor path: dense row-major signed INT8
        // operands, real CMDQ/validator/dispatcher/SPAD, shared Matrix MAC
        // array with K-fold reduction, and row-major INT32 output.
        begin : product_dense_gemv
            integer rr_g, cc_g, kk_g, bank_g;
            integer a0_g, a1_g, a2_g, a3_g;
            integer b0_g, b1_g, b2_g, b3_g;
            integer accum_g, expected_g, expected_last_g, errors_before_g;
            reg [31:0] desc_result_g;

            errors_before_g = errors;
            for (rr_g = 0; rr_g < 4; rr_g = rr_g + 1)
                for (kk_g = 0; kk_g < 32; kk_g = kk_g + 16)
                    for (bank_g = 0; bank_g < 4; bank_g = bank_g + 1) begin
                        a0_g = ((rr_g + 2*(kk_g + bank_g*4 + 0)) % 13) - 6;
                        a1_g = ((rr_g + 2*(kk_g + bank_g*4 + 1)) % 13) - 6;
                        a2_g = ((rr_g + 2*(kk_g + bank_g*4 + 2)) % 13) - 6;
                        a3_g = ((rr_g + 2*(kk_g + bank_g*4 + 3)) % 13) - 6;
                        axi_write(SPAD_BASE + 32'h5000 + rr_g*32 + kk_g +
                                  bank_g*4,
                                  {a3_g[7:0],a2_g[7:0],a1_g[7:0],a0_g[7:0]});
                    end
            for (kk_g = 0; kk_g < 32; kk_g = kk_g + 1)
                for (bank_g = 0; bank_g < 4; bank_g = bank_g + 1) begin
                    b0_g = ((3*kk_g + bank_g*4 + 0) % 11) - 5;
                    b1_g = ((3*kk_g + bank_g*4 + 1) % 11) - 5;
                    b2_g = ((3*kk_g + bank_g*4 + 2) % 11) - 5;
                    b3_g = ((3*kk_g + bank_g*4 + 3) % 11) - 5;
                    axi_write(SPAD_BASE + 32'h5200 + kk_g*16 + bank_g*4,
                              {b3_g[7:0],b2_g[7:0],b1_g[7:0],b0_g[7:0]});
                end
            for (cc_g = 0; cc_g < 16; cc_g = cc_g + 1)
                axi_write(SPAD_BASE + 32'h6000 + cc_g*4, cc_g-8);
            for (rr_g = 0; rr_g < 4; rr_g = rr_g + 1)
                for (cc_g = 0; cc_g < 16; cc_g = cc_g + 1)
                    axi_write(SPAD_BASE + 32'h5400 + (rr_g*16+cc_g)*4,
                              32'hbad0_5200 + rr_g*16 + cc_g);

            write_spad_desc_v3(32'h4d00, OP_TENSOR_GEMV_KFOLD, 16'h0520,
                               32'h5000, 32'h5200, 32'h6000, 32'h5400,
                               16'd4, 16'd16, 16'd32, 8'h01, 32'd0,
                               5'd1, 2'd1, 32'd0, 32'd0, 32'd0,
                               16'd0, 16'd0, 16'd0, 16'd0, 16'd0);
            // The descriptor helper emits ABI-v3 for legacy tests. Opcode
            // 0x52 is intentionally exercised through its v7 contract.
            axi_write(SPAD_BASE + 32'h4d3c, 32'd7);
            axi_write(REG_CMDQ_CTRL, 32'd0);
            axi_write(REG_CMDQ_BASE_LO, 32'h4d00);
            axi_write(REG_CMDQ_SIZE, 32'd2);
            axi_write(REG_CMDQ_HEAD, 32'd0);
            axi_write(REG_CMDQ_TAIL, 32'd1);
            axi_write(REG_CPLQ_BASE_LO, 32'h4e00);
            axi_write(REG_CPLQ_SIZE, 32'd2);
            axi_write(REG_CPLQ_HEAD, 32'd0);
            axi_write(REG_CPLQ_TAIL, 32'd0);
            matrix_line_write_count = 0;
            axi_write(REG_DOORBELL, 32'd1);
            wait_cpl_tail(32'd1, "product dense GEMV completion");

            expected_last_g = 0;
            for (rr_g = 0; rr_g < 4; rr_g = rr_g + 1)
                for (cc_g = 0; cc_g < 16; cc_g = cc_g + 1) begin
                    accum_g = 0;
                    for (kk_g = 0; kk_g < 32; kk_g = kk_g + 1)
                        accum_g = accum_g +
                            ((((rr_g + 2*kk_g) % 13) - 6) *
                             (((3*kk_g + cc_g) % 11) - 5));
                    accum_g = accum_g + (cc_g - 8);
                    expected_g = accum_g >>> 1;
                    if (expected_g < 0)
                        expected_g = 0;
                    if ((rr_g == 3) && (cc_g == 15))
                        expected_last_g = expected_g;
                    expect_read(SPAD_BASE + 32'h5400 + (rr_g*16+cc_g)*4,
                                expected_g, "product dense GEMV output");
                end
            desc_result_g = expected_last_g;
            if (matrix_line_write_count != 16) begin
                $display("%0t ERROR: product dense GEMV line writes=%0d expected=16",
                         $time, matrix_line_write_count);
                errors = errors + 1;
            end
            expect_completion(32'h4e00, 16'h0520, 4'h1, 4'd0,
                             desc_result_g, 32'd64,
                             "product dense GEMV descriptor");
            if (errors != errors_before_g)
                $fatal(1, "product dense GEMV descriptor path had %0d errors",
                       errors - errors_before_g);
            $display("MATRIX_PRODUCT_GEMV_DESCRIPTOR_PASS opcode=0x52 shape=4x16x32 dense=1 bias=1 shift=1 relu=1 outputs=64 lines=%0d golden=bit-exact",
                     matrix_line_write_count);
            axi_write(REG_CMDQ_SIZE, 32'd0);
            axi_write(REG_CPLQ_SIZE, 32'd0);
            clear_done_irq();

            // Product GEMV shape/tail contract: M=1, N=13, K=17. A is
            // padded to a 32-byte row and B uses 16-byte rows. Padding and
            // N-tail values are nonzero so only explicit DUT masking can
            // produce the expected valid output image.
            for (kk_g = 0; kk_g < 32; kk_g = kk_g + 16)
                for (bank_g = 0; bank_g < 4; bank_g = bank_g + 1) begin
                    a0_g = (kk_g + bank_g*4 + 0 < 17) ?
                        (((kk_g + bank_g*4 + 0)*5 + 1) % 19) - 9 : 7;
                    a1_g = (kk_g + bank_g*4 + 1 < 17) ?
                        (((kk_g + bank_g*4 + 1)*5 + 1) % 19) - 9 : 7;
                    a2_g = (kk_g + bank_g*4 + 2 < 17) ?
                        (((kk_g + bank_g*4 + 2)*5 + 1) % 19) - 9 : 7;
                    a3_g = (kk_g + bank_g*4 + 3 < 17) ?
                        (((kk_g + bank_g*4 + 3)*5 + 1) % 19) - 9 : 7;
                    axi_write(SPAD_BASE + 32'h5000 + kk_g + bank_g*4,
                              {a3_g[7:0],a2_g[7:0],a1_g[7:0],a0_g[7:0]});
                end
            for (kk_g = 0; kk_g < 17; kk_g = kk_g + 1)
                for (bank_g = 0; bank_g < 4; bank_g = bank_g + 1) begin
                    b0_g = ((3*kk_g - (bank_g*4 + 0)*2 + 5) % 17) - 8;
                    b1_g = ((3*kk_g - (bank_g*4 + 1)*2 + 5) % 17) - 8;
                    b2_g = ((3*kk_g - (bank_g*4 + 2)*2 + 5) % 17) - 8;
                    b3_g = ((3*kk_g - (bank_g*4 + 3)*2 + 5) % 17) - 8;
                    axi_write(SPAD_BASE + 32'h5200 + kk_g*16 + bank_g*4,
                              {b3_g[7:0],b2_g[7:0],b1_g[7:0],b0_g[7:0]});
                end
            for (cc_g = 0; cc_g < 16; cc_g = cc_g + 1)
                axi_write(SPAD_BASE + 32'h5600 + cc_g*4,
                          32'hface_5200 + cc_g);
            write_spad_desc_v3(32'h4d40, OP_TENSOR_GEMV_KFOLD, 16'h0521,
                               32'h5000, 32'h5200, 32'd0, 32'h5600,
                               16'd1, 16'd13, 16'd17, 8'd0, 32'd0,
                               5'd0, 2'd0, 32'd0, 32'd0, 32'd0,
                               16'd0, 16'd0, 16'd0, 16'd0, 16'd0);
            axi_write(SPAD_BASE + 32'h4d7c, 32'd7);
            errors_before_g = errors;
            axi_write(REG_CMDQ_BASE_LO, 32'h4d40);
            axi_write(REG_CMDQ_SIZE, 32'd2);
            axi_write(REG_CMDQ_HEAD, 32'd0);
            axi_write(REG_CMDQ_TAIL, 32'd1);
            axi_write(REG_CPLQ_BASE_LO, 32'h4e40);
            axi_write(REG_CPLQ_SIZE, 32'd2);
            axi_write(REG_CPLQ_HEAD, 32'd0);
            axi_write(REG_CPLQ_TAIL, 32'd0);
            matrix_line_write_count = 0;
            axi_write(REG_DOORBELL, 32'd1);
            wait_cpl_tail(32'd1, "product GEMV M/N/K tail completion");
            expected_last_g = 0;
            for (cc_g = 0; cc_g < 16; cc_g = cc_g + 1) begin
                if (cc_g < 13) begin
                    accum_g = 0;
                    for (kk_g = 0; kk_g < 17; kk_g = kk_g + 1)
                        accum_g = accum_g +
                            ((((kk_g*5 + 1) % 19) - 9) *
                             (((3*kk_g - cc_g*2 + 5) % 17) - 8));
                    expected_g = accum_g;
                    expected_last_g = expected_g;
                    expect_read(SPAD_BASE + 32'h5600 + cc_g*4,
                                expected_g, "product GEMV tail output");
                end else begin
                    expect_read(SPAD_BASE + 32'h5600 + cc_g*4,
                                32'hface_5200 + cc_g,
                                "product GEMV N-tail sentinel");
                end
            end
            if (matrix_line_write_count != 3) begin
                $display("%0t ERROR: product GEMV tail line writes=%0d expected=3",
                         $time, matrix_line_write_count);
                errors = errors + 1;
            end
            expect_completion(32'h4e40, 16'h0521, 4'h1, 4'd0,
                              expected_last_g, 32'd13,
                              "product GEMV M/N/K tails");
            if (errors != errors_before_g)
                $fatal(1, "product GEMV tail case had %0d errors",
                       errors - errors_before_g);
            $display("MATRIX_PRODUCT_GEMV_TAIL_DESCRIPTOR_PASS opcode=0x52 shape=1x13x17 valid_outputs=13 line_writes=%0d scalar_tail=1 golden=bit-exact",
                     matrix_line_write_count);
            axi_write(REG_CMDQ_SIZE, 32'd0);
            axi_write(REG_CPLQ_SIZE, 32'd0);
            clear_done_irq();

            // Exercise a multi-row product descriptor through the real CMDQ
            // path. K=19 forces one masked K tail while M=8 uses two row
            // tiles; nonzero A padding catches an accidental padded-lane MAC.
            for (rr_g = 0; rr_g < 8; rr_g = rr_g + 1)
                for (kk_g = 0; kk_g < 32; kk_g = kk_g + 16)
                    for (bank_g = 0; bank_g < 4; bank_g = bank_g + 1) begin
                        a0_g = (kk_g + bank_g*4 + 0 < 19) ?
                            (((rr_g*5 + (kk_g + bank_g*4 + 0)*3 + 1) % 23) - 11) : 17;
                        a1_g = (kk_g + bank_g*4 + 1 < 19) ?
                            (((rr_g*5 + (kk_g + bank_g*4 + 1)*3 + 1) % 23) - 11) : 17;
                        a2_g = (kk_g + bank_g*4 + 2 < 19) ?
                            (((rr_g*5 + (kk_g + bank_g*4 + 2)*3 + 1) % 23) - 11) : 17;
                        a3_g = (kk_g + bank_g*4 + 3 < 19) ?
                            (((rr_g*5 + (kk_g + bank_g*4 + 3)*3 + 1) % 23) - 11) : 17;
                        axi_write(SPAD_BASE + 32'h5000 + rr_g*32 + kk_g +
                                  bank_g*4,
                                  {a3_g[7:0],a2_g[7:0],a1_g[7:0],a0_g[7:0]});
                    end
            for (kk_g = 0; kk_g < 19; kk_g = kk_g + 1)
                for (bank_g = 0; bank_g < 4; bank_g = bank_g + 1) begin
                    b0_g = ((5*kk_g + (bank_g*4 + 0)*2 + 5) % 17) - 8;
                    b1_g = ((5*kk_g + (bank_g*4 + 1)*2 + 5) % 17) - 8;
                    b2_g = ((5*kk_g + (bank_g*4 + 2)*2 + 5) % 17) - 8;
                    b3_g = ((5*kk_g + (bank_g*4 + 3)*2 + 5) % 17) - 8;
                    axi_write(SPAD_BASE + 32'h5200 + kk_g*16 + bank_g*4,
                              {b3_g[7:0],b2_g[7:0],b1_g[7:0],b0_g[7:0]});
                end
            for (rr_g = 0; rr_g < 8; rr_g = rr_g + 1)
                for (cc_g = 0; cc_g < 16; cc_g = cc_g + 1)
                    axi_write(SPAD_BASE + 32'h5800 + (rr_g*16+cc_g)*4,
                              32'hface_5280 + rr_g*16 + cc_g);
            write_spad_desc_v3(32'h4d80, OP_TENSOR_GEMV_KFOLD, 16'h0522,
                               32'h5000, 32'h5200, 32'd0, 32'h5800,
                               16'd8, 16'd16, 16'd19, 8'd0, 32'd0,
                               5'd0, 2'd0, 32'd0, 32'd0, 32'd0,
                               16'd0, 16'd0, 16'd0, 16'd0, 16'd0);
            axi_write(SPAD_BASE + 32'h4dbc, 32'd7);
            errors_before_g = errors;
            axi_write(REG_CMDQ_BASE_LO, 32'h4d80);
            axi_write(REG_CMDQ_SIZE, 32'd2);
            axi_write(REG_CMDQ_HEAD, 32'd0);
            axi_write(REG_CMDQ_TAIL, 32'd1);
            axi_write(REG_CPLQ_BASE_LO, 32'h4e80);
            axi_write(REG_CPLQ_SIZE, 32'd2);
            axi_write(REG_CPLQ_HEAD, 32'd0);
            axi_write(REG_CPLQ_TAIL, 32'd0);
            matrix_line_write_count = 0;
            axi_write(REG_DOORBELL, 32'd1);
            wait_cpl_tail(32'd1, "product GEMV M8 K-tail completion");
            expected_last_g = 0;
            for (rr_g = 0; rr_g < 8; rr_g = rr_g + 1)
                for (cc_g = 0; cc_g < 16; cc_g = cc_g + 1) begin
                    accum_g = 0;
                    for (kk_g = 0; kk_g < 19; kk_g = kk_g + 1)
                        accum_g = accum_g +
                            ((((rr_g*5 + kk_g*3 + 1) % 23) - 11) *
                             (((5*kk_g + cc_g*2 + 5) % 17) - 8));
                    expected_g = accum_g;
                    if ((rr_g == 7) && (cc_g == 15))
                        expected_last_g = expected_g;
                    expect_read(SPAD_BASE + 32'h5800 + (rr_g*16+cc_g)*4,
                                expected_g, "product GEMV M8 output");
                end
            if (matrix_line_write_count != 32) begin
                $display("%0t ERROR: product GEMV M8 line writes=%0d expected=32",
                         $time, matrix_line_write_count);
                errors = errors + 1;
            end
            expect_completion(32'h4e80, 16'h0522, 4'h1, 4'd0,
                              expected_last_g, 32'd128,
                              "product GEMV M8 K-tail descriptor");
            if (errors != errors_before_g)
                $fatal(1, "product GEMV M8 K-tail descriptor had %0d errors",
                       errors - errors_before_g);
            $display("MATRIX_PRODUCT_GEMV_M8_KTAIL_DESCRIPTOR_PASS opcode=0x52 shape=8x16x19 outputs=128 lines=%0d golden=bit-exact",
                     matrix_line_write_count);
            axi_write(REG_CMDQ_SIZE, 32'd0);
            axi_write(REG_CPLQ_SIZE, 32'd0);
            clear_done_irq();
        end

        // End-to-end optional 0x53 fused-tile forwarding through the real
        // descriptor validator, CMDQ, Matrix controller, and SPAD path.  Run
        // the same producer/consumer pair once through SPAD and once through
        // the local tagged tile buffer, then compare the complete result image
        // and directly count accepted reads from the producer tile address.
        begin : fused_tile_forward_cmdq
            integer init_word_f;
            integer output_word_f;
            integer errors_before_f;
            integer cross_engine_word_f;
            integer overlap_poll_f;

            errors_before_f = errors;
            ai_tile_forward_baseline_a_reads = 0;
            ai_tile_forward_enabled_a_reads = 0;
            ai_tile_forward_read_monitor = 1'b0;
            ai_tile_forward_read_phase = 0;

            // Uniform signed INT8 matrices make the independent Golden
            // explicit: producer outputs 16; consumer computes 256 and the
            // fused INT8 requant saturates each output to +127.
            for (init_word_f = 0; init_word_f < 256;
                 init_word_f = init_word_f + 1) begin
                axi_write(SPAD_BASE + 32'h0000_a000 + (init_word_f * 4),
                          32'h0101_0101);
                axi_write(SPAD_BASE + 32'h0000_a800 + (init_word_f * 4),
                          32'h0101_0101);
            end
            for (output_word_f = 0; output_word_f < 64;
                 output_word_f = output_word_f + 1) begin
                axi_write(SPAD_BASE + 32'h0000_b000 + (output_word_f * 4),
                          32'hdead_5300);
                axi_write(SPAD_BASE + 32'h0000_b400 + (output_word_f * 4),
                          32'hdead_5301);
                axi_write(SPAD_BASE + 32'h0000_b800 + (output_word_f * 4),
                          32'hdead_5302);
            end

            write_spad_desc_v3(32'h9000, OP_TENSOR_GEMM_FUSED, 16'h0530,
                               32'h0000_a000, 32'h0000_a800, 32'd0,
                               32'h0000_b000, 16'd16, 16'd16, 16'd4,
                               8'd0, 32'd0, 5'd0, 2'd0,
                               32'd0, 32'd0, 32'd0, 16'd0, 16'd0,
                               16'd0, 16'd0, 16'd0);
            axi_write(SPAD_BASE + 32'h903c, 32'd7);
            write_spad_desc_v3(32'h9040, OP_TENSOR_GEMM_FUSED, 16'h0531,
                               32'h0000_b000, 32'h0000_a800, 32'd0,
                               32'h0000_b400, 16'd16, 16'd16, 16'd4,
                               8'd0, 32'd0, 5'd0, 2'd0,
                               32'd0, 32'd0, 32'd0, 16'd0, 16'd0,
                               16'd0, 16'd0, 16'd0);
            axi_write(SPAD_BASE + 32'h907c, 32'd7);
            write_spad_desc_v3(32'h9080, OP_TENSOR_GEMM_FUSED, 16'h0532,
                               32'h0000_a000, 32'h0000_a800, 32'd0,
                               32'h0000_b000, 16'd16, 16'd16, 16'd4,
                               8'd0, 32'h0000_0020, 5'd0, 2'd0,
                               32'd0, 32'd0, 32'd0, 16'd0, 16'd0,
                               16'd0, 16'd0, 16'd0);
            axi_write(SPAD_BASE + 32'h90bc, 32'd7);
            write_spad_desc_v3(32'h90c0, OP_TENSOR_GEMM_FUSED, 16'h0533,
                               32'h0000_b000, 32'h0000_a800, 32'd0,
                               32'h0000_b800, 16'd16, 16'd16, 16'd4,
                               8'd0, 32'h0000_0060, 5'd0, 2'd0,
                               32'd0, 32'd0, 32'd0, 16'd0, 16'd0,
                               16'd0, 16'd0, 16'd0);
            axi_write(SPAD_BASE + 32'h90fc, 32'd7);

            axi_write(REG_CMDQ_CTRL, 32'd0);
            axi_write(REG_CMDQ_BASE_LO, 32'h9000);
            axi_write(REG_CMDQ_SIZE, 32'd4);
            axi_write(REG_CMDQ_HEAD, 32'd0);
            axi_write(REG_CMDQ_TAIL, 32'd2);
            axi_write(REG_CPLQ_BASE_LO, 32'h9200);
            axi_write(REG_CPLQ_SIZE, 32'd8);
            axi_write(REG_CPLQ_HEAD, 32'd0);
            axi_write(REG_CPLQ_TAIL, 32'd0);

            matrix_line_write_count = 0;
            ai_tile_forward_read_phase = 1;
            ai_tile_forward_read_monitor = 1'b1;
            axi_write(REG_DOORBELL, 32'd1);
            wait_cpl_tail(32'd2, "fused tile forwarding SPAD baseline");
            if (matrix_line_write_count != 32) begin
                $display("%0t ERROR: fused tile SPAD baseline lines=%0d expected=32",
                         $time, matrix_line_write_count);
                errors = errors + 1;
            end
            for (output_word_f = 0; output_word_f < 64;
                 output_word_f = output_word_f + 1) begin
                expect_read(SPAD_BASE + 32'h0000_b000 + (output_word_f * 4),
                            32'h1010_1010, "fused tile baseline producer");
                expect_read(SPAD_BASE + 32'h0000_b400 + (output_word_f * 4),
                            32'h7f7f_7f7f, "fused tile baseline consumer");
            end
            expect_completion(32'h9200, 16'h0530, 4'h1, 4'd0,
                              32'd16, 32'd256, "fused tile baseline producer");
            expect_completion(32'h9210, 16'h0531, 4'h1, 4'd0,
                              32'd127, 32'd256, "fused tile baseline consumer");
            if (ai_tile_forward_baseline_a_reads != 16) begin
                $display("%0t ERROR: fused tile baseline producer-A reads=%0d expected=16",
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
