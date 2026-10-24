`timescale 1ns / 1ps

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
    localparam SPAD_BYTES        = 32'h0008_0000;

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
    integer seed_dummy;
    integer matrix_line_write_count;
    integer cp_fetch_done_count;
    reg parallel_engine_overlap_seen = 1'b0;
    reg parallel_same_engine_overlap_violation = 1'b0;
    reg [20:0] parallel_engine_pair_seen = 21'd0;
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

    ai_accel_top dut(
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

    `include "ai_transformer_workload.svh"

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

    initial begin
        integer pair_engine_a;
        integer pair_engine_b;
        integer pair_index;
        integer pair_setup_i;
        errors = 0;
        seed_arg = 20261014;
        matrix_line_write_count = 0;
        cp_fetch_done_count = 0;
        last_dma_araddr = 0;
        allow_m_axi_error = 1'b0;
        aresetn = 1'b0;
        axi_idle();
        repeat (8) @(posedge aclk);
        aresetn = 1'b1;
        repeat (4) @(posedge aclk);

        if ($test$plusargs("FP_DOT_DMA_BENCH")) begin
            run_fp_dot_dma_benchmark();
            if (errors != 0)
                $fatal(1, "FP benchmark reported %0d errors", errors);
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
        axi_write(REG_CMDQ_SIZE, 32'd64);
        axi_write(REG_CMDQ_HEAD, 32'd0);
        axi_write(REG_CMDQ_TAIL, TRANSFORMER_DESC_COUNT);
        axi_write(REG_CPLQ_BASE_LO, TRANSFORMER_CPL_BASE);
        axi_write(REG_CPLQ_SIZE, 32'd64);
        axi_write(REG_CPLQ_HEAD, 32'd0);
        axi_write(REG_CPLQ_TAIL, 32'd0);
        axi_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(TRANSFORMER_DESC_COUNT,
                      "A8 end-to-end Transformer descriptor chain");
        check_transformer_workload();
        expect_read(REG_CMDQ_HEAD, TRANSFORMER_DESC_COUNT,
                    "A8 Transformer command count");
        expect_completion(TRANSFORMER_CPL_BASE +
                          ((TRANSFORMER_DESC_COUNT-1) * 16),
                          16'h701d, 4'h1, 4'd0, 32'd1, 32'd4,
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
