`timescale 1ns / 1ps

// ============================================================================
// ai_accel_top
// ----------------------------------------------------------------------------
// 当前项目的顶层模块。它把一个“可由 CPU 配置的片上 AI 加速 IP”封装起来：
//
//   1. AXI-Lite slave 作为控制面：
//      CPU 通过该接口读写寄存器，也可以通过 scratchpad window 直接访问片上 SRAM。
//
//   2. AXI master 作为数据面：
//      内部 DMA/外部 descriptor fetch 通过该接口主动访问 DDR/外部 memory。
//
//   3. 内部 scratchpad SRAM：
//      存放 input、weight、output、descriptor 和 completion entry。
//
//   4. INT8 compute core：
//      从 scratchpad 读取 packed INT8 数据，执行 VDOT/GEMV/GEMM_TILE。
//
//   5. descriptor/completion 队列：
//      软件可以提交 descriptor，硬件执行后写 completion，形成更接近真实驱动的
//      “提交任务 -> 硬件执行 -> 完成上报”流程。
// ============================================================================
module ai_accel_top #(
    // Four fixed banks are retained for the bank-local INT8 datapath.  Depth
    // is configurable; 32768 words/bank gives the XCZU15EG default of 512 KiB.
    parameter integer SPAD_WORDS_PER_BANK = 32768,
    parameter integer M_AXI_ADDR_WIDTH = 64
)(
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 ACLK CLK" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME ACLK, ASSOCIATED_BUSIF S_AXI:M_AXI, ASSOCIATED_RESET aresetn" *)
    input  wire        aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 ARESETN RST" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME ARESETN, POLARITY ACTIVE_LOW" *)
    input  wire        aresetn,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWADDR" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S_AXI, PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 32, HAS_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1" *)
    input  wire [31:0] s_axi_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *)
    input  wire        s_axi_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *)
    output wire        s_axi_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WDATA" *)
    input  wire [31:0] s_axi_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *)
    input  wire [3:0]  s_axi_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WVALID" *)
    input  wire        s_axi_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WREADY" *)
    output wire        s_axi_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BRESP" *)
    output wire [1:0]  s_axi_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BVALID" *)
    output wire        s_axi_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BREADY" *)
    input  wire        s_axi_bready,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *)
    input  wire [31:0] s_axi_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *)
    input  wire        s_axi_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *)
    output wire        s_axi_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RDATA" *)
    output wire [31:0] s_axi_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RRESP" *)
    output wire [1:0]  s_axi_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RVALID" *)
    output wire        s_axi_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RREADY" *)
    input  wire        s_axi_rready,

    (* X_INTERFACE_INFO = "xilinx.com:signal:interrupt:1.0 IRQ INTERRUPT" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME IRQ, SENSITIVITY LEVEL_HIGH" *)
    output wire        irq,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARVALID" *)
    (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M_AXI, PROTOCOL AXI4, DATA_WIDTH 128, ADDR_WIDTH 64, ID_WIDTH 4, HAS_BURST 1, MAX_BURST_LENGTH 16, NUM_READ_OUTSTANDING 4, NUM_WRITE_OUTSTANDING 4, SUPPORTS_NARROW_BURST 1" *)
    output wire        m_axi_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARID" *)
    output wire [3:0]  m_axi_arid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARADDR" *)
    output wire [M_AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARLEN" *)
    output wire [7:0]  m_axi_arlen,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARSIZE" *)
    output wire [2:0]  m_axi_arsize,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARBURST" *)
    output wire [1:0]  m_axi_arburst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARCACHE" *)
    output wire [3:0]  m_axi_arcache,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARPROT" *)
    output wire [2:0]  m_axi_arprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARQOS" *)
    output wire [3:0]  m_axi_arqos,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARLOCK" *)
    output wire        m_axi_arlock,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI ARREADY" *)
    input  wire        m_axi_arready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RID" *)
    input  wire [3:0]  m_axi_rid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RDATA" *)
    input  wire [127:0] m_axi_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RRESP" *)
    input  wire [1:0]  m_axi_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RVALID" *)
    input  wire        m_axi_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RLAST" *)
    input  wire        m_axi_rlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI RREADY" *)
    output wire        m_axi_rready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWVALID" *)
    output wire        m_axi_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWID" *)
    output wire [3:0]  m_axi_awid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWADDR" *)
    output wire [M_AXI_ADDR_WIDTH-1:0] m_axi_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWLEN" *)
    output wire [7:0]  m_axi_awlen,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWSIZE" *)
    output wire [2:0]  m_axi_awsize,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWBURST" *)
    output wire [1:0]  m_axi_awburst,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWCACHE" *)
    output wire [3:0]  m_axi_awcache,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWPROT" *)
    output wire [2:0]  m_axi_awprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWQOS" *)
    output wire [3:0]  m_axi_awqos,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWLOCK" *)
    output wire        m_axi_awlock,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI AWREADY" *)
    input  wire        m_axi_awready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WVALID" *)
    output wire        m_axi_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WDATA" *)
    output wire [127:0] m_axi_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WSTRB" *)
    output wire [15:0] m_axi_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WLAST" *)
    output wire        m_axi_wlast,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI WREADY" *)
    input  wire        m_axi_wready,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BID" *)
    input  wire [3:0]  m_axi_bid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BRESP" *)
    input  wire [1:0]  m_axi_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BVALID" *)
    input  wire        m_axi_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXI BREADY" *)
    output wire        m_axi_bready
);

    // AXI-Lite 地址空间划分：
    //   0x0000_0000 ~ 0x0000_00ff  -> 寄存器窗口，由 ai_accel_regs 响应
    //   0x0001_0000 ~ SPAD_LIMIT-1 -> 参数化 scratchpad host window
    localparam [31:0] SPAD_BASE = 32'h0001_0000;
    localparam integer SPAD_BANKS = 4;
    localparam integer SPAD_ROW_BITS = $clog2(SPAD_WORDS_PER_BANK);
    localparam [31:0] SPAD_BYTES = SPAD_BANKS * SPAD_WORDS_PER_BANK * 4;
    localparam [31:0] SPAD_LIMIT = SPAD_BASE + SPAD_BYTES;

    // axi_lite_reg_if 输出的统一内部访问请求。顶层后续根据地址把它分发给
    // “寄存器块”或者“scratchpad host 端口”。
    wire        reg_req_valid_raw;
    wire        reg_req_write_raw;
    wire [31:0] reg_req_addr_raw;
    // AXI interconnects preserve the system address on the slave interface.
    // CIMForge occupies a 1 MiB aperture, so internal register/scratchpad
    // decoding must use the aperture-relative low 20 bits.  Zero-based RTL
    // simulations remain equivalent while mapped FPGA accesses (for example
    // 0xA000_0044) no longer turn a valid read into SLVERR.
    wire [31:0] reg_req_addr_local = {12'd0, reg_req_addr_raw[19:0]};
    wire [31:0] reg_req_wdata_raw;
    wire [3:0]  reg_req_wstrb_raw;
    reg  [31:0] reg_rsp_rdata_mux;
    reg         reg_rsp_error_mux;

    wire        regs_req_valid;
    wire        spad_req_valid;
    wire [31:0] regs_rsp_rdata;
    wire        regs_rsp_error;
    wire [31:0] spad_host_rdata;
    wire        spad_host_error;
    wire        spad_host_parity_error;

    wire        core_start;
    wire        core_abort;
    wire [7:0]  op_mode;
    wire [31:0] src0_base;
    wire [31:0] src1_base;
    wire [31:0] dst_base;
    wire [15:0] length;
    wire [15:0] m_size;
    wire [15:0] n_size;
    wire [15:0] k_words;
    wire [4:0]  scale_shift;
    wire [1:0]  activation;
    wire [31:0] bias_base;
    wire        bias_enable;
    wire [31:0] watchdog_limit;
    wire [31:0] region0_base, region0_limit, region1_base, region1_limit;
    wire [31:0] region2_base, region2_limit, region3_base, region3_limit;
    wire [3:0]  region0_perm, region1_perm, region2_perm, region3_perm;
    wire        direct_start;
    wire        submit;
    wire [63:0] cmdq_base;
    // Compatibility observability aliases used by the existing SVA/testbench.
    wire [31:0] cmdq_desc_base;
    wire        doorbell_pulse;
    wire        cmdq_external;
    wire [31:0] cmdq_size;
    wire [31:0] cmdq_tail;
    wire [31:0] cplq_base_cfg;
    wire [31:0] cplq_size;
    wire [31:0] cplq_head;
    wire        cmdq_head_load;
    wire [31:0] cmdq_head_seed;
    wire        cplq_tail_load;
    wire [31:0] cplq_tail_seed;
    wire        dma_start;
    wire        dma_store;
    wire [63:0] dma_ext_addr;
    wire [31:0] dma_spad_addr;
    wire [15:0] dma_length_words;
    wire [15:0] dma_row_words;
    wire [15:0] dma_row_count;
    wire [31:0] dma_ext_stride;
    wire [31:0] dma_spad_stride;
    wire        dma_gather_enable;
    wire [31:0] dma_gather_index_base;
    wire [2:0]  dma_read_outstanding;
    wire        tile_start;
    wire [15:0] tile_count;
    wire [63:0] tile_ext_input_base, tile_ext_output_base;
    wire [31:0] tile_ext_input_stride, tile_ext_output_stride;
    wire [31:0] tile_buffer0_base, tile_buffer1_base, tile_output_offset;
    wire [15:0] tile_input_words, tile_output_words;
    wire        tile_dma_start, tile_dma_store, tile_active;
    wire [63:0] tile_dma_ext_addr;
    wire [31:0] tile_dma_spad_addr;
    wire [15:0] tile_dma_length_words;
    wire [31:0] tile_perf_total, tile_perf_dma, tile_perf_compute;
    wire [31:0] tile_perf_overlap, tile_perf_stall;
    wire [15:0] tile_completed;
    wire perf_clear;
    wire [31:0] perf_matrix_cycles, perf_matrix_mac_cycles, perf_matrix_banked_stall;
    wire [31:0] perf_dma_read_bytes, perf_dma_write_bytes, perf_dma_ar_count, perf_dma_aw_count;
    wire [31:0] perf_dma_r_stall;
    wire [2:0] perf_dma_rd_outstanding, perf_dma_rd_highwater;
    wire        dma_start_mux, dma_store_mux;
    wire [63:0] dma_ext_addr_mux;
    wire [31:0] dma_spad_addr_mux;
    wire [15:0] dma_length_words_mux;
    wire [15:0] dma_row_words_mux, dma_row_count_mux;
    wire [31:0] dma_ext_stride_mux, dma_spad_stride_mux;
    wire dma_gather_enable_mux;
    wire [31:0] dma_gather_index_base_mux;
    wire [2:0] dma_read_outstanding_mux;

    wire        scalar_spad_valid;
    wire        scalar_spad_write;
    wire [31:0] scalar_spad_addr;
    wire [31:0] scalar_spad_wdata;
    wire        banked_spad_valid;
    wire        banked_spad_write;
    wire [31:0] banked_spad_addr;
    wire [31:0] banked_spad_wdata;
    wire        core_spad_valid;
    wire        core_spad_write;
    wire [31:0] core_spad_addr;
    wire [31:0] core_spad_wdata;
    wire [31:0] core_spad_rdata;
    wire        core_spad_parity_error;
    wire        desc_spad_valid;
    wire [31:0] desc_spad_addr;
    wire        spad_desc_busy;
    wire        spad_desc_done;
    wire        spad_desc_error;
    wire [7:0]  spad_desc_op;
    wire [15:0] spad_desc_task_id;
    wire [31:0] spad_desc_src0_base;
    wire [31:0] spad_desc_src1_base;
    wire [31:0] spad_desc_dst_base;
    wire [15:0] spad_desc_length;
    wire [15:0] spad_desc_m_size;
    wire [15:0] spad_desc_n_size;
    wire [15:0] spad_desc_k_words;
    wire [4:0]  spad_desc_scale_shift;
    wire [1:0]  spad_desc_activation;
    wire [31:0] spad_desc_bias_base;
    wire        spad_desc_bias_enable;
    wire [7:0]  spad_desc_flags;
    wire [31:0] spad_desc_aux0, spad_desc_src0_stride, spad_desc_src1_stride, spad_desc_dst_stride;
    wire [15:0] spad_desc_batch_count, spad_desc_head_count;
    wire [15:0] spad_desc_wait_mask, spad_desc_signal_mask, spad_desc_clear_mask;
    wire [7:0]  spad_desc_version;
    wire        axi_desc_busy;
    wire        axi_desc_done;
    wire        axi_desc_error;
    wire [7:0]  axi_desc_op;
    wire [15:0] axi_desc_task_id;
    wire [31:0] axi_desc_src0_base;
    wire [31:0] axi_desc_src1_base;
    wire [31:0] axi_desc_dst_base;
    wire [15:0] axi_desc_length;
    wire [15:0] axi_desc_m_size;
    wire [15:0] axi_desc_n_size;
    wire [15:0] axi_desc_k_words;
    wire [4:0]  axi_desc_scale_shift;
    wire [1:0]  axi_desc_activation;
    wire [31:0] axi_desc_bias_base;
    wire        axi_desc_bias_enable;
    wire [7:0]  axi_desc_flags;
    wire [31:0] axi_desc_aux0, axi_desc_src0_stride, axi_desc_src1_stride, axi_desc_dst_stride;
    wire [15:0] axi_desc_batch_count, axi_desc_head_count;
    wire [15:0] axi_desc_wait_mask, axi_desc_signal_mask, axi_desc_clear_mask;
    wire [7:0]  axi_desc_version;
    wire        desc_done;
    wire        desc_error;
    wire [7:0]  desc_op;
    wire [15:0] desc_task_id;
    wire [31:0] desc_src0_base;
    wire [31:0] desc_src1_base;
    wire [31:0] desc_dst_base;
    wire [15:0] desc_length;
    wire [15:0] desc_m_size;
    wire [15:0] desc_n_size;
    wire [15:0] desc_k_words;
    wire [4:0]  desc_scale_shift;
    wire [1:0]  desc_activation;
    wire [31:0] desc_bias_base;
    wire        desc_bias_enable;
    wire [7:0]  desc_flags;
    wire [31:0] desc_aux0, desc_src0_stride, desc_src1_stride, desc_dst_stride;
    wire [15:0] desc_batch_count, desc_head_count;
    wire [15:0] desc_wait_mask, desc_signal_mask, desc_clear_mask;
    wire [7:0]  desc_version;
    wire        spad_compute_valid_mux;
    wire        spad_compute_write_mux;
    wire [31:0] spad_compute_addr_mux;
    wire [31:0] spad_compute_wdata_mux;
    wire        cpl_spad_valid;
    wire        cpl_spad_write;
    wire [31:0] cpl_spad_addr;
    wire [31:0] cpl_spad_wdata;
    wire        cpl_busy;
    wire        cpl_done;
    wire        cpl_start;
    wire [31:0] cpl_base;
    wire [31:0] cpl_index;
    wire [15:0] cpl_task_id;
    wire [3:0]  cpl_status;
    wire [3:0]  cpl_error_code;
    wire [31:0] cpl_result;
    wire [31:0] cpl_element_count;
    wire        cpl_prot_allow;
    wire        cpl_protection_error;
    wire [31:0] processor_cmdq_head;
    wire [31:0] processor_cplq_tail;
    wire        processor_busy;
    wire        processor_event_valid;
    wire        processor_event_error;
    wire [3:0]  processor_event_error_code;
    wire [31:0] processor_event_result;
    wire [31:0] processor_event_cycles;
    wire [31:0] processor_event_elements;
    wire        fetch_start;
    wire [63:0] fetch_base;
    wire        fetch_external;
    wire        launch_valid;
    wire [7:0]  launch_op;
    wire [15:0] launch_task_id;
    wire [31:0] launch_src0, launch_src1, launch_dst;
    wire [15:0] launch_length, launch_m, launch_n, launch_k;
    wire [4:0]  launch_shift;
    wire [1:0]  launch_activation;
    wire [31:0] launch_bias_base;
    wire        launch_bias_enable;
    wire [7:0]  launch_flags;
    wire [31:0] launch_aux0, launch_src0_stride, launch_src1_stride, launch_dst_stride;
    wire [15:0] launch_batch_count, launch_head_count;
    wire [31:0] launch_instance_count = launch_batch_count * launch_head_count;
    wire [15:0] dependency_events;
    wire        arb_desc_ready, arb_cpl_ready, arb_core_ready, arb_banked_ready, arb_dma_ready;
    wire        arb_rsp_valid, arb_rsp_error, arb_rsp_is_line;
    wire [2:0]  arb_rsp_client;
    wire [2:0]  arb_request_client;
    wire [31:0] arb_rsp_rdata;
    wire        desc_rsp_valid, core_rsp_valid, banked_rsp_valid, dma_rsp_valid;
    wire        desc_rsp_error, core_rsp_error, dma_rsp_error;
    wire        arb_banked_valid;
    wire [31:0] arb_banked_addr;
    wire [3:0]  arb_cnm_ready;
    wire [3:0]  cnm_rsp_valid;
    wire [3:0]  arb_cnm_valid;
    wire [31:0] arb_cnm_addr0, arb_cnm_addr1, arb_cnm_addr2, arb_cnm_addr3;
    wire [3:0]  cnm_read_valid;
    wire [31:0] cnm_read_addr0, cnm_read_addr1, cnm_read_addr2, cnm_read_addr3;
    wire [31:0] cnm_data0, cnm_data1, cnm_data2, cnm_data3;
    wire [3:0]  cnm_parity;
    wire        cnm_protection_error;
    wire        dma_spad_valid;
    wire        dma_spad_write;
    wire [31:0] dma_spad_addr_o;
    wire [31:0] dma_spad_wdata;
    wire        dma_spad_line_valid, dma_spad_line_write;
    wire [31:0] dma_spad_line_addr;
    wire [127:0] dma_spad_line_wdata;
    wire [15:0] dma_spad_line_wstrb;
    wire        arb_dma_line_ready, dma_line_rsp_valid;
    wire        matrix_line_valid, matrix_line_write;
    wire [31:0] matrix_line_addr;
    wire [127:0] matrix_line_wdata;
    wire [15:0] matrix_line_wstrb;
    wire        arb_core_line_ready;
    wire        spad_line_valid, spad_line_write;
    wire [31:0] spad_line_addr;
    wire [127:0] spad_line_wdata, spad_line_rdata;
    wire [15:0] spad_line_wstrb;
    wire [3:0] spad_line_parity_error;
    wire        spad_line_raw_error, spad_line_error;
    wire        host_prot_allow;
    wire        compute_prot_allow;
    wire        compute_prot_error;
    wire        line_prot_allow;
    wire        line_prot_error;
    wire        banked_prot_allow;
    wire        banked_protection_error;
    wire        core_spad_error;
    wire        compute_req_execute;

    wire        scalar_busy, scalar_done, scalar_error;
    wire [3:0]  scalar_error_code;
    wire [31:0] scalar_result, scalar_cycle_count, scalar_element_count;
    wire        banked_busy, banked_done, banked_error;
    wire [3:0]  banked_error_code;
    wire [31:0] banked_result, banked_cycle_count, banked_element_count;
    wire        matrix_spad_valid, matrix_spad_write;
    wire [31:0] matrix_spad_addr, matrix_spad_wdata;
    wire        matrix_banked_read_valid;
    wire [31:0] matrix_banked_read_addr;
    wire        matrix_busy, matrix_done, matrix_error;
    wire [3:0]  matrix_error_code;
    wire [31:0] matrix_result, matrix_cycle_count, matrix_element_count;
    wire        matrix_perf_mac_active, matrix_perf_banked_wait;
    wire        sfu_spad_valid, sfu_spad_write;
    wire [31:0] sfu_spad_addr, sfu_spad_wdata;
    wire        sfu_busy, sfu_done, sfu_error;
    wire [3:0]  sfu_error_code;
    wire [31:0] sfu_result, sfu_cycle_count, sfu_element_count;
    wire        core_busy;
    wire        core_done;
    wire        core_error;
    wire [3:0]  core_error_code;
    wire [31:0] core_result;
    wire [31:0] core_cycle_count;
    wire [31:0] core_element_count;
    wire        banked_read_valid;
    wire [31:0] banked_read_addr;
    wire        banked_read_valid_legacy;
    wire [31:0] banked_read_addr_legacy;
    wire [31:0] banked_data0, banked_data1, banked_data2, banked_data3;
    wire [3:0] banked_parity;
    wire        banked_op;
    wire        tensor_matrix_op;
    wire        tensor_sfu_op;
    wire        conv_linebuffer_op;
    wire        kv_cache_op;
    wire        conv_spad_valid, conv_spad_write;
    wire [31:0] conv_spad_addr, conv_spad_wdata;
    wire        conv_busy, conv_done, conv_error;
    wire [3:0]  conv_error_code;
    wire [31:0] conv_result, conv_cycle_count, conv_element_count;
    wire        kv_spad_valid, kv_spad_write;
    wire [31:0] kv_spad_addr, kv_spad_wdata;
    wire        kv_busy, kv_done, kv_error;
    wire [3:0]  kv_error_code;
    wire [31:0] kv_result, kv_cycle_count, kv_element_count;
    wire dma_busy, dma_done, dma_error;
    wire [3:0] dma_error_code;
    wire [3:0]  dma_m_axi_arid, dma_m_axi_awid;
    wire        dma_m_axi_arvalid, dma_m_axi_rready;
    wire        dma_m_axi_awvalid, dma_m_axi_wvalid, dma_m_axi_bready;
    wire [M_AXI_ADDR_WIDTH-1:0] dma_m_axi_araddr, dma_m_axi_awaddr;
    wire [7:0] dma_m_axi_arlen, dma_m_axi_awlen;
    wire [2:0] dma_m_axi_arsize, dma_m_axi_awsize;
    wire [1:0] dma_m_axi_arburst, dma_m_axi_awburst;
    wire [127:0] dma_m_axi_wdata;
    wire [15:0] dma_m_axi_wstrb;
    wire dma_m_axi_wlast;
    wire [4:0] dma_r_beat_bytes, dma_w_beat_bytes;
    wire        axi_desc_m_axi_arvalid;
    wire [3:0]  axi_desc_m_axi_arid;
    wire [M_AXI_ADDR_WIDTH-1:0] axi_desc_m_axi_araddr;
    wire [7:0]  axi_desc_m_axi_arlen;
    wire [2:0]  axi_desc_m_axi_arsize;
    wire [1:0]  axi_desc_m_axi_arburst;
    wire        axi_desc_m_axi_arready;
    wire        axi_desc_m_axi_rready;

    // DMA-only handshake events are kept separate from the descriptor AXI
    // fetch mux, making bandwidth measurements attributable to payload DMA.
    wire perf_dma_ar_fire = dma_m_axi_arvalid && !axi_desc_busy &&
                            m_axi_arready;
    wire perf_dma_r_fire = m_axi_rvalid && dma_m_axi_rready;
    wire perf_dma_rlast_fire = perf_dma_r_fire && m_axi_rlast;
    wire perf_dma_aw_fire = m_axi_awvalid && m_axi_awready;
    wire perf_dma_w_fire = m_axi_wvalid && m_axi_wready;
    wire perf_dma_r_wait = m_axi_rvalid && (m_axi_rid != 4'd0) &&
                           !dma_m_axi_rready && dma_busy;

    // 地址译码：同一个 AXI-Lite slave 入口，内部拆成寄存器访问和 SRAM 访问。
    assign regs_req_valid = reg_req_valid_raw &&
                            ((reg_req_addr_local < SPAD_BASE) ||
                             (reg_req_addr_local >= SPAD_LIMIT));
    assign spad_req_valid = reg_req_valid_raw &&
                            (reg_req_addr_local >= SPAD_BASE) &&
                            (reg_req_addr_local < SPAD_LIMIT);

    // scratchpad 的内部 compute 端口只有一套，因此 DMA、descriptor fetch、
    // completion writer、compute core 不能同时直接驱动它。控制面保留严格优先级，
    // 数据面采用轮转仲裁：
    //   descriptor fetch > completion writer > round-robin(core/banked/DMA)
    //
    // 这个优先级保证：
    //   - doorbell 后先取任务描述；
    //   - 任务完成后优先写 completion；
    //   - 连续计算流量下 DMA 仍能获得有界的数据面服务机会。
    ai_spad_arbiter spad_arbiter_u(
        .clk(aclk), .resetn(aresetn),
        .desc_valid(desc_spad_valid), .desc_write(1'b0), .desc_addr(desc_spad_addr), .desc_wdata(32'd0), .desc_ready(arb_desc_ready),
        .cpl_valid(cpl_spad_valid), .cpl_write(cpl_spad_write), .cpl_addr(cpl_spad_addr), .cpl_wdata(cpl_spad_wdata), .cpl_ready(arb_cpl_ready),
        .core_valid(core_spad_valid), .core_write(core_spad_write), .core_addr(core_spad_addr), .core_wdata(core_spad_wdata), .core_ready(arb_core_ready),
        .core_line_valid(matrix_line_valid), .core_line_write(matrix_line_write),
        .core_line_addr(matrix_line_addr), .core_line_wdata(matrix_line_wdata),
        .core_line_wstrb(matrix_line_wstrb), .core_line_ready(arb_core_line_ready),
        .banked_valid(banked_read_valid), .banked_addr(banked_read_addr), .banked_ready(arb_banked_ready),
        .cnm_valid(cnm_read_valid), .cnm_addr0(cnm_read_addr0), .cnm_addr1(cnm_read_addr1),
        .cnm_addr2(cnm_read_addr2), .cnm_addr3(cnm_read_addr3), .cnm_ready(arb_cnm_ready),
        .dma_valid(dma_spad_valid), .dma_write(dma_spad_write), .dma_addr(dma_spad_addr_o), .dma_wdata(dma_spad_wdata), .dma_ready(arb_dma_ready),
        .dma_line_valid(dma_spad_line_valid), .dma_line_write(dma_spad_line_write),
        .dma_line_addr(dma_spad_line_addr), .dma_line_wdata(dma_spad_line_wdata),
        .dma_line_wstrb(dma_spad_line_wstrb), .dma_line_ready(arb_dma_line_ready),
        .spad_valid(spad_compute_valid_mux), .spad_write(spad_compute_write_mux), .spad_addr(spad_compute_addr_mux), .spad_wdata(spad_compute_wdata_mux),
        .spad_line_valid(spad_line_valid), .spad_line_write(spad_line_write),
        .spad_line_addr(spad_line_addr), .spad_line_wdata(spad_line_wdata),
        .spad_line_wstrb(spad_line_wstrb),
        .spad_banked_valid(arb_banked_valid), .spad_banked_addr(arb_banked_addr),
        .spad_cnm_valid(arb_cnm_valid), .spad_cnm_addr0(arb_cnm_addr0),
        .spad_cnm_addr1(arb_cnm_addr1), .spad_cnm_addr2(arb_cnm_addr2), .spad_cnm_addr3(arb_cnm_addr3),
        .spad_rdata(core_spad_rdata), .spad_error(core_spad_error),
        .spad_parity_error(core_spad_parity_error),
        .spad_line_error(spad_line_error),
        .spad_line_parity_error(spad_line_parity_error),
        .rsp_valid(arb_rsp_valid), .rsp_client(arb_rsp_client),
        .rsp_is_line(arb_rsp_is_line), .request_client(arb_request_client),
        .rsp_rdata(arb_rsp_rdata), .rsp_error(arb_rsp_error),
        .cnm_rsp_valid(cnm_rsp_valid)
    );
    assign desc_rsp_valid = arb_rsp_valid && (arb_rsp_client == 3'd0);
    assign core_rsp_valid = arb_rsp_valid && (arb_rsp_client == 3'd2) &&
                            !arb_rsp_is_line;
    assign banked_rsp_valid = arb_rsp_valid && (arb_rsp_client == 3'd3);
    // The arbiter delays the admitted CNM lane mask by the scratchpad read
    // latency; a stalled/idle lane therefore cannot consume another lane's
    // response.
    assign dma_rsp_valid = arb_rsp_valid && (arb_rsp_client == 3'd4) &&
                           !arb_rsp_is_line;
    assign dma_line_rsp_valid = arb_rsp_valid && (arb_rsp_client == 3'd4) &&
                                arb_rsp_is_line;
    assign desc_rsp_error = desc_rsp_valid && arb_rsp_error;
    assign core_rsp_error = core_rsp_valid && arb_rsp_error;
    assign dma_rsp_error = dma_rsp_valid && arb_rsp_error;
    assign cmdq_desc_base = fetch_base[31:0];
    assign doorbell_pulse = submit;
    assign banked_op = (launch_op == 8'h20) || (launch_op == 8'h21);
    assign tensor_matrix_op = (launch_op == 8'h30) || (launch_op == 8'h31);
    assign tensor_sfu_op = (launch_op >= 8'h32) && (launch_op <= 8'h39);
    assign conv_linebuffer_op = (launch_op == 8'h16) || (launch_op == 8'h17);
    assign kv_cache_op = (launch_op == 8'h43) || (launch_op == 8'h44);
    assign core_busy = scalar_busy || banked_busy || matrix_busy || sfu_busy || conv_busy || kv_busy;
    assign core_done = scalar_done || banked_done || matrix_done || sfu_done || conv_done || kv_done;
    assign core_error = conv_done ? conv_error : kv_done ? kv_error : matrix_done ? matrix_error :
                        sfu_done ? sfu_error :
                        banked_done ? banked_error : scalar_error;
    assign core_error_code = conv_done ? conv_error_code : kv_done ? kv_error_code : matrix_done ? matrix_error_code :
                             sfu_done ? sfu_error_code :
                             banked_done ? banked_error_code : scalar_error_code;
    assign core_result = conv_done ? conv_result : kv_done ? kv_result : matrix_done ? matrix_result :
                         sfu_done ? sfu_result :
                         banked_done ? banked_result : scalar_result;
    assign core_cycle_count = conv_done ? conv_cycle_count : kv_done ? kv_cycle_count : matrix_done ? matrix_cycle_count :
                              sfu_done ? sfu_cycle_count :
                              banked_done ? banked_cycle_count : scalar_cycle_count;
    assign core_element_count = conv_done ? conv_element_count : kv_done ? kv_element_count : matrix_done ? matrix_element_count :
                                sfu_done ? sfu_element_count :
                                banked_done ? banked_element_count : scalar_element_count;
    assign core_spad_valid = conv_busy ? conv_spad_valid : kv_busy ? kv_spad_valid : matrix_busy ? matrix_spad_valid :
                             sfu_busy ? sfu_spad_valid :
                             banked_busy ? banked_spad_valid : scalar_spad_valid;
    assign core_spad_write = conv_busy ? conv_spad_write : kv_busy ? kv_spad_write : matrix_busy ? matrix_spad_write :
                             sfu_busy ? sfu_spad_write :
                             banked_busy ? banked_spad_write : scalar_spad_write;
    assign core_spad_addr = conv_busy ? conv_spad_addr : kv_busy ? kv_spad_addr : matrix_busy ? matrix_spad_addr :
                            sfu_busy ? sfu_spad_addr :
                            banked_busy ? banked_spad_addr : scalar_spad_addr;
    assign core_spad_wdata = conv_busy ? conv_spad_wdata : kv_busy ? kv_spad_wdata : matrix_busy ? matrix_spad_wdata :
                             sfu_busy ? sfu_spad_wdata :
                             banked_busy ? banked_spad_wdata : scalar_spad_wdata;
    // 0x20/0x21 now use the independent four-lane CNM port.  The legacy
    // common-row banked port remains exclusively for the matrix engine.
    assign banked_read_valid = matrix_busy ? matrix_banked_read_valid : 1'b0;
    // Legacy common-row banked requests are no longer generated by the top
    // level; keep the compatibility address deterministic rather than leaving
    // an undriven wire that can propagate X values into static analysis.
    assign banked_read_addr_legacy = 32'd0;
    assign banked_read_addr = matrix_busy ? matrix_banked_read_addr : banked_read_addr_legacy;
    assign compute_req_execute = (arb_request_client == 3'd2) ||
                                 (arb_request_client == 3'd3);
    assign compute_prot_error = spad_compute_valid_mux &&
                                (!compute_prot_allow ||
                                 (spad_compute_addr_mux > SPAD_BYTES - 32'd4));
    assign banked_protection_error = arb_banked_valid &&
                                     (!banked_prot_allow ||
                                      (arb_banked_addr > SPAD_BYTES - 32'd16));
    assign cnm_protection_error = (|arb_cnm_valid) &&
                                  ((arb_cnm_addr0 > SPAD_BYTES-32'd4) ||
                                   (arb_cnm_addr1 > SPAD_BYTES-32'd4) ||
                                   (arb_cnm_addr2 > SPAD_BYTES-32'd4) ||
                                   (arb_cnm_addr3 > SPAD_BYTES-32'd4));
    assign core_spad_error = compute_prot_error;
    assign spad_line_error = spad_line_raw_error || line_prot_error;
    assign cpl_protection_error = !cpl_prot_allow ||
                                  ((cpl_base + (cpl_index << 4)) >
                                   SPAD_BYTES - 32'd16);

    ai_spad_protection host_protection_u(
        .region0_base(region0_base), .region0_limit(region0_limit), .region0_perm(region0_perm),
        .region1_base(region1_base), .region1_limit(region1_limit), .region1_perm(region1_perm),
        .region2_base(region2_base), .region2_limit(region2_limit), .region2_perm(region2_perm),
        .region3_base(region3_base), .region3_limit(region3_limit), .region3_perm(region3_perm),
        .req_valid(spad_req_valid), .req_addr(reg_req_addr_local - SPAD_BASE), .req_bytes(32'd4),
        .req_write(reg_req_write_raw), .req_execute(1'b0), .allow(host_prot_allow)
    );

    ai_spad_protection compute_protection_u(
        .region0_base(region0_base), .region0_limit(region0_limit), .region0_perm(region0_perm),
        .region1_base(region1_base), .region1_limit(region1_limit), .region1_perm(region1_perm),
        .region2_base(region2_base), .region2_limit(region2_limit), .region2_perm(region2_perm),
        .region3_base(region3_base), .region3_limit(region3_limit), .region3_perm(region3_perm),
        .req_valid(spad_compute_valid_mux), .req_addr(spad_compute_addr_mux), .req_bytes(32'd4),
        .req_write(spad_compute_write_mux), .req_execute(compute_req_execute), .allow(compute_prot_allow)
    );

    ai_spad_protection line_protection_u(
        .region0_base(region0_base), .region0_limit(region0_limit), .region0_perm(region0_perm),
        .region1_base(region1_base), .region1_limit(region1_limit), .region1_perm(region1_perm),
        .region2_base(region2_base), .region2_limit(region2_limit), .region2_perm(region2_perm),
        .region3_base(region3_base), .region3_limit(region3_limit), .region3_perm(region3_perm),
        .req_valid(spad_line_valid), .req_addr(spad_line_addr), .req_bytes(32'd16),
        .req_write(spad_line_write),
        .req_execute(arb_request_client == 3'd2), .allow(line_prot_allow)
    );
    assign line_prot_error = spad_line_valid &&
                             (!line_prot_allow ||
                              (spad_line_addr > SPAD_BYTES - 32'd16));

    // A banked row is four 32-bit words at one 16-byte tile address.  It is
    // admitted by the same arbiter and must satisfy the complete-region and
    // execute permission checks before any bank is observed by the engine.
    ai_spad_protection banked_protection_u(
        .region0_base(region0_base), .region0_limit(region0_limit), .region0_perm(region0_perm),
        .region1_base(region1_base), .region1_limit(region1_limit), .region1_perm(region1_perm),
        .region2_base(region2_base), .region2_limit(region2_limit), .region2_perm(region2_perm),
        .region3_base(region3_base), .region3_limit(region3_limit), .region3_perm(region3_perm),
        .req_valid(arb_banked_valid),
        .req_addr(arb_banked_addr),
        .req_bytes(32'd16),
        .req_write(1'b0), .req_execute(1'b1), .allow(banked_prot_allow)
    );

    // Completion records are generated internally.  Validate their complete
    // 16-byte destination before the writer is started, so an unread/data
    // region can never be overwritten by a completion entry.
    ai_spad_protection completion_protection_u(
        .region0_base(region0_base), .region0_limit(region0_limit), .region0_perm(region0_perm),
        .region1_base(region1_base), .region1_limit(region1_limit), .region1_perm(region1_perm),
        .region2_base(region2_base), .region2_limit(region2_limit), .region2_perm(region2_perm),
        .region3_base(region3_base), .region3_limit(region3_limit), .region3_perm(region3_perm),
        .req_valid(1'b1), .req_addr(cpl_base + (cpl_index << 4)), .req_bytes(32'd16),
        .req_write(1'b1), .req_execute(1'b0), .allow(cpl_prot_allow)
    );
    // descriptor 可以来自两个地方：
    //   cmdq_external = 0：descriptor 放在 scratchpad，由 ai_desc_fetch 读取；
    //   cmdq_external = 1：descriptor 放在外部 DDR，由 axi_desc_fetch 经 AXI 读取。
    // 下面这些 mux 把两种来源统一成一套 desc_* 信号送给寄存器控制块。
    assign desc_done = fetch_external ? axi_desc_done : spad_desc_done;
    assign desc_error = fetch_external ? axi_desc_error : spad_desc_error;
    assign desc_op = fetch_external ? axi_desc_op : spad_desc_op;
    assign desc_task_id = fetch_external ? axi_desc_task_id : spad_desc_task_id;
    assign desc_src0_base = fetch_external ? axi_desc_src0_base : spad_desc_src0_base;
    assign desc_src1_base = fetch_external ? axi_desc_src1_base : spad_desc_src1_base;
    assign desc_dst_base = fetch_external ? axi_desc_dst_base : spad_desc_dst_base;
    assign desc_length = fetch_external ? axi_desc_length : spad_desc_length;
    assign desc_m_size = fetch_external ? axi_desc_m_size : spad_desc_m_size;
    assign desc_n_size = fetch_external ? axi_desc_n_size : spad_desc_n_size;
    assign desc_k_words = fetch_external ? axi_desc_k_words : spad_desc_k_words;
    assign desc_scale_shift = fetch_external ? axi_desc_scale_shift : spad_desc_scale_shift;
    assign desc_activation = fetch_external ? axi_desc_activation : spad_desc_activation;
    assign desc_bias_base = fetch_external ? axi_desc_bias_base : spad_desc_bias_base;
    assign desc_bias_enable = fetch_external ? axi_desc_bias_enable : spad_desc_bias_enable;
    assign desc_flags = fetch_external ? axi_desc_flags : spad_desc_flags;
    assign desc_aux0 = fetch_external ? axi_desc_aux0 : spad_desc_aux0;
    assign desc_src0_stride = fetch_external ? axi_desc_src0_stride : spad_desc_src0_stride;
    assign desc_src1_stride = fetch_external ? axi_desc_src1_stride : spad_desc_src1_stride;
    assign desc_dst_stride = fetch_external ? axi_desc_dst_stride : spad_desc_dst_stride;
    assign desc_batch_count = fetch_external ? axi_desc_batch_count : spad_desc_batch_count;
    assign desc_head_count = fetch_external ? axi_desc_head_count : spad_desc_head_count;
    assign desc_wait_mask = fetch_external ? axi_desc_wait_mask : spad_desc_wait_mask;
    assign desc_signal_mask = fetch_external ? axi_desc_signal_mask : spad_desc_signal_mask;
    assign desc_clear_mask = fetch_external ? axi_desc_clear_mask : spad_desc_clear_mask;
    assign desc_version = fetch_external ? axi_desc_version : spad_desc_version;

    // A2 tile jobs reuse the existing DMA datapath.  While tile_active, DMA
    // ownership belongs to the command processor's ping-pong sub-scheduler;
    // legacy software-triggered DMA retains the same register interface when
    // no tile job is active.
    assign dma_start_mux = tile_active ? tile_dma_start : dma_start;
    assign dma_store_mux = tile_active ? tile_dma_store : dma_store;
    assign dma_ext_addr_mux = tile_active ? tile_dma_ext_addr : dma_ext_addr;
    assign dma_spad_addr_mux = tile_active ? tile_dma_spad_addr : dma_spad_addr;
    assign dma_length_words_mux = tile_active ? tile_dma_length_words : dma_length_words;
    assign dma_row_words_mux = tile_active ? 16'd0 : dma_row_words;
    assign dma_row_count_mux = tile_active ? 16'd0 : dma_row_count;
    assign dma_ext_stride_mux = tile_active ? 32'd0 : dma_ext_stride;
    assign dma_spad_stride_mux = tile_active ? 32'd0 : dma_spad_stride;
    assign dma_gather_enable_mux = tile_active ? 1'b0 : dma_gather_enable;
    assign dma_gather_index_base_mux = tile_active ? 32'd0 : dma_gather_index_base;
    assign dma_read_outstanding_mux = tile_active ? 3'd1 : dma_read_outstanding;
    // DMA_CFG[1] used to select a second, narrow DMA backend.  It remains a
    // readable compatibility bit in the register file, but all payload modes
    // now use the unified 128-bit tagged DMA.

    // AXI master read channel is shared by two clients:
    //   - axi_desc_fetch 需要从 DDR 读取 descriptor；
    //   - ai_axi128_dma 需要从 DDR 读取 input/weight。
    // 写通道目前只由 DMA 使用。这里读通道优先给 axi_desc_fetch。
    assign m_axi_arvalid = axi_desc_busy ? axi_desc_m_axi_arvalid :
                           dma_m_axi_arvalid;
    // Descriptor fetch reserves ID 0; payload DMA uses IDs 1..4.
    assign m_axi_arid    = axi_desc_busy ? axi_desc_m_axi_arid :
                           dma_m_axi_arid;
    assign m_axi_araddr  = axi_desc_busy ? axi_desc_m_axi_araddr :
                           dma_m_axi_araddr;
    assign m_axi_arlen   = axi_desc_busy ? axi_desc_m_axi_arlen :
                           dma_m_axi_arlen;
    assign m_axi_arsize  = axi_desc_busy ? axi_desc_m_axi_arsize :
                           dma_m_axi_arsize;
    assign m_axi_arburst = axi_desc_busy ? axi_desc_m_axi_arburst :
                           dma_m_axi_arburst;
    assign m_axi_arcache = 4'b0011;
    assign m_axi_arprot  = 3'b000;
    assign m_axi_arqos   = 4'b0000;
    assign m_axi_arlock  = 1'b0;
    assign axi_desc_m_axi_arready = axi_desc_busy ? m_axi_arready : 1'b0;
    assign m_axi_rready = (m_axi_rid == 4'd0) ?
                          axi_desc_m_axi_rready : dma_m_axi_rready;
    assign m_axi_awid = dma_m_axi_awid;
    assign m_axi_awvalid = dma_m_axi_awvalid;
    assign m_axi_awaddr  = dma_m_axi_awaddr;
    assign m_axi_awlen   = dma_m_axi_awlen;
    assign m_axi_awsize  = dma_m_axi_awsize;
    assign m_axi_awburst = dma_m_axi_awburst;
    assign m_axi_awcache = 4'b0011;
    assign m_axi_awprot  = 3'b000;
    assign m_axi_awqos   = 4'b0000;
    assign m_axi_awlock  = 1'b0;
    assign m_axi_wvalid  = dma_m_axi_wvalid;
    assign m_axi_wdata   = dma_m_axi_wdata;
    assign m_axi_wstrb   = dma_m_axi_wstrb;
    assign m_axi_wlast   = dma_m_axi_wlast;
    assign m_axi_bready  = dma_m_axi_bready;

    // AXI-Lite 读响应 mux：
    //   访问 scratchpad window 时返回 SRAM host port 数据；
    //   访问寄存器窗口时返回 ai_accel_regs 数据。
    always @(*) begin
        if (spad_req_valid) begin
            reg_rsp_rdata_mux = spad_host_rdata;
            reg_rsp_error_mux = spad_host_error || spad_host_parity_error || !host_prot_allow;
        end else begin
            reg_rsp_rdata_mux = regs_rsp_rdata;
            reg_rsp_error_mux = regs_rsp_error;
        end
    end

    // AXI-Lite 协议适配层：处理 AW/W/B/AR/R 五个通道，
    // 对内部只暴露一拍 reg_req_valid + 地址/数据/写使能。
    axi_lite_reg_if axi_lite_u(
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
        .reg_req_valid (reg_req_valid_raw),
        .reg_req_write (reg_req_write_raw),
        .reg_req_addr  (reg_req_addr_raw),
        .reg_req_wdata (reg_req_wdata_raw),
        .reg_req_wstrb (reg_req_wstrb_raw),
        .reg_rsp_rdata (reg_rsp_rdata_mux),
        .reg_rsp_error (reg_rsp_error_mux)
    );

    // 控制/状态寄存器块：
    // 保存 OP/SRC/DST/LENGTH/DMA/CMDQ/CPLQ 配置，接收 core/dma done/error，
    // 产生 core_start、dma_start、doorbell_pulse、IRQ 和 completion 写请求。
    ai_accel_regs #(.SPAD_BYTES(SPAD_BYTES)) regs_u(
        .clk                (aclk),
        .resetn             (aresetn),
        .reg_req_valid      (regs_req_valid),
        .reg_req_write      (reg_req_write_raw),
        .reg_req_addr       (reg_req_addr_local),
        .reg_req_wdata      (reg_req_wdata_raw),
        .reg_req_wstrb      (reg_req_wstrb_raw),
        .reg_rsp_rdata      (regs_rsp_rdata),
        .reg_rsp_error      (regs_rsp_error),
        .processor_busy     (processor_busy),
        .processor_event_valid(processor_event_valid),
        .processor_event_error(processor_event_error),
        .processor_event_error_code(processor_event_error_code),
        .processor_event_result(processor_event_result),
        .processor_event_cycles(processor_event_cycles),
        .processor_event_elements(processor_event_elements),
        .processor_dependency_events(dependency_events),
        .processor_cmdq_head(processor_cmdq_head),
        .processor_cplq_tail(processor_cplq_tail),
        .dma_busy           (dma_busy),
        .dma_done           (dma_done),
        .dma_error          (dma_error),
        .dma_error_code     (dma_error_code),
        .direct_start       (direct_start),
        .submit             (submit),
        .core_abort         (core_abort),
        .dma_start          (dma_start),
        .dma_store          (dma_store),
        .dma_ext_addr       (dma_ext_addr),
        .dma_spad_addr      (dma_spad_addr),
        .dma_length_words   (dma_length_words),
        .dma_row_words      (dma_row_words),
        .dma_row_count      (dma_row_count),
        .dma_ext_stride     (dma_ext_stride),
        .dma_spad_stride    (dma_spad_stride),
        .dma_gather_enable  (dma_gather_enable),
        .dma_gather_index_base(dma_gather_index_base),
        .dma_read_outstanding(dma_read_outstanding),
        .op_mode            (op_mode),
        .src0_base          (src0_base),
        .src1_base          (src1_base),
        .dst_base           (dst_base),
        .length             (length),
        .m_size             (m_size),
        .n_size             (n_size),
        .k_words            (k_words),
        .scale_shift        (scale_shift),
        .activation         (activation),
        .watchdog_limit     (watchdog_limit),
        .bias_base          (bias_base),
        .bias_enable        (bias_enable),
        .tile_start         (tile_start),
        .tile_count         (tile_count),
        .tile_ext_input_base(tile_ext_input_base),
        .tile_ext_output_base(tile_ext_output_base),
        .tile_ext_input_stride(tile_ext_input_stride),
        .tile_ext_output_stride(tile_ext_output_stride),
        .tile_buffer0_base  (tile_buffer0_base),
        .tile_buffer1_base  (tile_buffer1_base),
        .tile_output_offset (tile_output_offset),
        .tile_input_words   (tile_input_words),
        .tile_output_words  (tile_output_words),
        .tile_perf_total    (tile_perf_total),
        .tile_perf_dma      (tile_perf_dma),
        .tile_perf_compute  (tile_perf_compute),
        .tile_perf_overlap  (tile_perf_overlap),
        .tile_perf_stall    (tile_perf_stall),
        .tile_completed     (tile_completed),
        .perf_matrix_cycles (perf_matrix_cycles),
        .perf_matrix_mac_cycles(perf_matrix_mac_cycles),
        .perf_matrix_banked_stall(perf_matrix_banked_stall),
        .perf_dma_read_bytes(perf_dma_read_bytes),
        .perf_dma_write_bytes(perf_dma_write_bytes),
        .perf_dma_ar_count (perf_dma_ar_count),
        .perf_dma_aw_count (perf_dma_aw_count),
        .perf_dma_r_stall  (perf_dma_r_stall),
        .perf_dma_rd_outstanding(perf_dma_rd_outstanding),
        .perf_dma_rd_highwater(perf_dma_rd_highwater),
        .perf_clear        (perf_clear),
        .region0_base       (region0_base),
        .region0_limit      (region0_limit),
        .region0_perm       (region0_perm),
        .region1_base       (region1_base),
        .region1_limit      (region1_limit),
        .region1_perm       (region1_perm),
        .region2_base       (region2_base),
        .region2_limit      (region2_limit),
        .region2_perm       (region2_perm),
        .region3_base       (region3_base),
        .region3_limit      (region3_limit),
        .region3_perm       (region3_perm),
        .cmdq_base          (cmdq_base),
        .cmdq_size          (cmdq_size),
        .cmdq_tail          (cmdq_tail),
        .cmdq_external      (cmdq_external),
        .cmdq_head_load     (cmdq_head_load),
        .cmdq_head_seed     (cmdq_head_seed),
        .cplq_base          (cplq_base_cfg),
        .cplq_size          (cplq_size),
        .cplq_head          (cplq_head),
        .cplq_tail_load     (cplq_tail_load),
        .cplq_tail_seed     (cplq_tail_seed),
        .irq                (irq)
    );

    // completion writer：
    // 一次任务结束后，把 task_id/status/error/result/element_count
    // 写成 4 个 word 的 completion entry，放到 scratchpad 的 completion queue。
    ai_completion_writer cpl_writer_u(
        .clk           (aclk),
        .resetn        (aresetn),
        .start         (cpl_start),
        .cplq_base     (cpl_base),
        .cplq_index    (cpl_index),
        .task_id       (cpl_task_id),
        .status        (cpl_status),
        .error_code    (cpl_error_code),
        .result        (cpl_result),
        .element_count (cpl_element_count),
        .spad_valid    (cpl_spad_valid),
        .spad_write    (cpl_spad_write),
        .spad_addr     (cpl_spad_addr),
        .spad_wdata    (cpl_spad_wdata),
        .spad_ready    (arb_cpl_ready),
        .busy          (cpl_busy),
        .done          (cpl_done)
    );

    ai_command_processor command_processor_u(
        .clk(aclk), .resetn(aresetn), .abort(core_abort), .submit(submit), .direct_start(direct_start), .tile_start(tile_start),
        .cmdq_base(cmdq_base), .cmdq_size(cmdq_size), .cmdq_tail(cmdq_tail), .desc_external(cmdq_external), .cmdq_head_load(cmdq_head_load), .cmdq_head_seed(cmdq_head_seed),
        .cplq_base(cplq_base_cfg), .cplq_size(cplq_size), .cplq_head(cplq_head), .completion_protected(cpl_protection_error), .cplq_tail_load(cplq_tail_load), .cplq_tail_seed(cplq_tail_seed),
        .cfg_op(op_mode), .cfg_src0(src0_base), .cfg_src1(src1_base), .cfg_dst(dst_base),
        .cfg_length(length), .cfg_m(m_size), .cfg_n(n_size), .cfg_k(k_words), .cfg_shift(scale_shift), .cfg_activation(activation), .cfg_bias_base(bias_base), .cfg_bias_enable(bias_enable),
        .tile_count(tile_count), .tile_ext_input_base(tile_ext_input_base), .tile_ext_output_base(tile_ext_output_base),
        .tile_ext_input_stride(tile_ext_input_stride), .tile_ext_output_stride(tile_ext_output_stride),
        .tile_buffer0_base(tile_buffer0_base), .tile_buffer1_base(tile_buffer1_base), .tile_output_offset(tile_output_offset),
        .tile_input_words(tile_input_words), .tile_output_words(tile_output_words),
        .fetch_busy(fetch_external ? axi_desc_busy : spad_desc_busy), .fetch_done(desc_done), .fetch_error(desc_error),
        .desc_op(desc_op), .desc_task_id(desc_task_id), .desc_src0(desc_src0_base), .desc_src1(desc_src1_base), .desc_dst(desc_dst_base),
        .desc_length(desc_length), .desc_m(desc_m_size), .desc_n(desc_n_size), .desc_k(desc_k_words), .desc_shift(desc_scale_shift), .desc_activation(desc_activation), .desc_bias_base(desc_bias_base), .desc_bias_enable(desc_bias_enable),
        .desc_flags(desc_flags), .desc_aux0(desc_aux0),
        .desc_src0_stride(desc_src0_stride), .desc_src1_stride(desc_src1_stride), .desc_dst_stride(desc_dst_stride),
        .desc_batch_count(desc_batch_count), .desc_head_count(desc_head_count),
        .desc_wait_mask(desc_wait_mask), .desc_signal_mask(desc_signal_mask),
        .desc_clear_mask(desc_clear_mask), .desc_version(desc_version),
        .compute_busy(core_busy), .compute_done(core_done), .compute_error(core_error), .compute_error_code(core_error_code),
        .compute_result(core_result), .compute_cycles(core_cycle_count), .compute_elements(core_element_count),
        .dma_busy(dma_busy), .dma_done(dma_done), .dma_error(dma_error), .dma_error_code(dma_error_code),
        .completion_busy(cpl_busy), .completion_done(cpl_done), .fetch_start(fetch_start), .fetch_base(fetch_base), .fetch_external(fetch_external),
        .launch_valid(launch_valid), .launch_op(launch_op), .launch_task_id(launch_task_id), .launch_src0(launch_src0), .launch_src1(launch_src1), .launch_dst(launch_dst),
        .launch_length(launch_length), .launch_m(launch_m), .launch_n(launch_n), .launch_k(launch_k), .launch_shift(launch_shift), .launch_activation(launch_activation), .launch_bias_base(launch_bias_base), .launch_bias_enable(launch_bias_enable),
        .launch_flags(launch_flags), .launch_aux0(launch_aux0),
        .launch_src0_stride(launch_src0_stride), .launch_src1_stride(launch_src1_stride), .launch_dst_stride(launch_dst_stride),
        .launch_batch_count(launch_batch_count), .launch_head_count(launch_head_count),
        .tile_dma_start(tile_dma_start), .tile_dma_store(tile_dma_store), .tile_dma_ext_addr(tile_dma_ext_addr), .tile_dma_spad_addr(tile_dma_spad_addr), .tile_dma_length_words(tile_dma_length_words), .tile_active(tile_active),
        .tile_perf_total(tile_perf_total), .tile_perf_dma(tile_perf_dma), .tile_perf_compute(tile_perf_compute), .tile_perf_overlap(tile_perf_overlap), .tile_perf_stall(tile_perf_stall), .tile_completed(tile_completed),
        .completion_start(cpl_start), .completion_base(cpl_base), .completion_index(cpl_index), .completion_task_id(cpl_task_id), .completion_status(cpl_status), .completion_error(cpl_error_code), .completion_result(cpl_result), .completion_elements(cpl_element_count),
        .cmdq_head(processor_cmdq_head), .cplq_tail(processor_cplq_tail), .busy(processor_busy), .event_valid(processor_event_valid), .event_error(processor_event_error), .event_error_code(processor_event_error_code), .event_result(processor_event_result), .event_cycles(processor_event_cycles), .event_elements(processor_event_elements),
        .dependency_events(dependency_events)
    );
    assign core_start = launch_valid;

    ai_perf_monitor perf_monitor_u(
        .clk(aclk), .resetn(aresetn), .clear(perf_clear),
        .matrix_busy(matrix_busy), .matrix_mac_active(matrix_perf_mac_active),
        .matrix_banked_wait(matrix_perf_banked_wait),
        .dma_ar_fire(perf_dma_ar_fire), .dma_r_fire(perf_dma_r_fire),
        .dma_rlast_fire(perf_dma_rlast_fire), .dma_aw_fire(perf_dma_aw_fire),
        .dma_w_fire(perf_dma_w_fire), .dma_r_stall(perf_dma_r_wait),
        .dma_r_beat_bytes(dma_r_beat_bytes),
        .dma_w_beat_bytes(dma_w_beat_bytes),
        .matrix_cycles(perf_matrix_cycles), .matrix_mac_cycles(perf_matrix_mac_cycles),
        .matrix_banked_stall_cycles(perf_matrix_banked_stall),
        .dma_read_bytes(perf_dma_read_bytes), .dma_write_bytes(perf_dma_write_bytes),
        .dma_ar_count(perf_dma_ar_count), .dma_aw_count(perf_dma_aw_count),
        .dma_r_stall_cycles(perf_dma_r_stall),
        .dma_rd_outstanding(perf_dma_rd_outstanding),
        .dma_rd_outstanding_highwater(perf_dma_rd_highwater)
    );

    // Unified payload DMA:
    //   store=0: DDR -> scratchpad for inputs and weights;
    //   store=1: scratchpad -> DDR for results.
    // Direct, 2D, gather, and tile requests share this 128-bit tagged backend.
    ai_axi128_dma #(.AXI_ADDR_WIDTH(M_AXI_ADDR_WIDTH)) dma_u(
        .clk(aclk), .resetn(aresetn), .start(dma_start_mux),
        .abort(core_abort), .store(dma_store_mux), .ext_addr(dma_ext_addr_mux),
        .spad_addr(dma_spad_addr_mux), .length_words(dma_length_words_mux),
        .row_words(dma_row_words_mux), .row_count(dma_row_count_mux),
        .ext_stride(dma_ext_stride_mux), .spad_stride(dma_spad_stride_mux),
        .gather_enable(dma_gather_enable_mux),
        .gather_index_base(dma_gather_index_base_mux),
        .read_outstanding(dma_read_outstanding_mux), .busy(dma_busy),
        .done(dma_done), .error(dma_error), .error_code(dma_error_code),
        .spad_valid(dma_spad_valid), .spad_write(dma_spad_write),
        .spad_addr_o(dma_spad_addr_o), .spad_wdata(dma_spad_wdata),
        .spad_ready(arb_dma_ready), .spad_rsp_valid(dma_rsp_valid), .spad_rdata(arb_rsp_rdata),
        .spad_req_error(compute_prot_error &&
                        (arb_request_client == 3'd4)),
        .spad_rsp_error(dma_rsp_error),
        .spad_line_valid(dma_spad_line_valid),
        .spad_line_write(dma_spad_line_write),
        .spad_line_addr(dma_spad_line_addr),
        .spad_line_wdata(dma_spad_line_wdata),
        .spad_line_wstrb(dma_spad_line_wstrb),
        .spad_line_ready(arb_dma_line_ready),
        .spad_line_rsp_valid(dma_line_rsp_valid),
        .spad_line_rdata(spad_line_rdata),
        .spad_line_req_error((line_prot_error || spad_line_raw_error) &&
                             (arb_request_client == 3'd4)),
        .spad_line_rsp_error(dma_line_rsp_valid && arb_rsp_error),
        .spad_line_parity_error(spad_line_parity_error),
        .m_axi_arid(dma_m_axi_arid), .m_axi_arvalid(dma_m_axi_arvalid), .m_axi_araddr(dma_m_axi_araddr),
        .m_axi_arlen(dma_m_axi_arlen), .m_axi_arsize(dma_m_axi_arsize), .m_axi_arburst(dma_m_axi_arburst),
        // The top-level AR mux gives descriptor ID0 priority.  Do not expose
        // that unrelated handshake to a tagged DMA request.
        .m_axi_arready(m_axi_arready && !axi_desc_busy),
        .m_axi_rid(m_axi_rid), .m_axi_rdata(m_axi_rdata), .m_axi_rresp(m_axi_rresp), .m_axi_rvalid(m_axi_rvalid), .m_axi_rlast(m_axi_rlast), .m_axi_rready(dma_m_axi_rready),
        .m_axi_awid(dma_m_axi_awid), .m_axi_awvalid(dma_m_axi_awvalid), .m_axi_awaddr(dma_m_axi_awaddr), .m_axi_awlen(dma_m_axi_awlen), .m_axi_awsize(dma_m_axi_awsize), .m_axi_awburst(dma_m_axi_awburst), .m_axi_awready(m_axi_awready),
        .m_axi_wvalid(dma_m_axi_wvalid), .m_axi_wdata(dma_m_axi_wdata), .m_axi_wstrb(dma_m_axi_wstrb), .m_axi_wlast(dma_m_axi_wlast), .m_axi_wready(m_axi_wready),
        .m_axi_bid(m_axi_bid), .m_axi_bresp(m_axi_bresp), .m_axi_bvalid(m_axi_bvalid), .m_axi_bready(dma_m_axi_bready),
        .rd_outstanding(), .rd_highwater(),
        .r_beat_bytes(dma_r_beat_bytes), .w_beat_bytes(dma_w_beat_bytes)
    );

    // 片上 scratchpad SRAM：
    // host 端口给 CPU/AXI-Lite 直接调试或填数据；
    // compute 端口给 DMA、descriptor fetch、completion writer、compute core 复用。
    ai_scratchpad #(
        .BANKS          (SPAD_BANKS),
        .WORDS_PER_BANK (SPAD_WORDS_PER_BANK),
        .ROW_BITS       (SPAD_ROW_BITS)
    ) scratchpad_u(
        .clk                  (aclk),
        .resetn               (aresetn),
        .host_valid           (spad_req_valid && host_prot_allow),
        .host_write           (reg_req_write_raw),
        .host_addr            (reg_req_addr_local - SPAD_BASE),
        .host_wdata           (reg_req_wdata_raw),
        .host_wstrb           (reg_req_wstrb_raw),
        .host_rdata           (spad_host_rdata),
        .host_error           (spad_host_error),
        .host_parity_error    (spad_host_parity_error),
        .compute_valid        (spad_compute_valid_mux && compute_prot_allow),
        .compute_write        (spad_compute_write_mux),
        .compute_addr         (spad_compute_addr_mux),
        .compute_wdata        (spad_compute_wdata_mux),
        .compute_rdata        (core_spad_rdata),
        .compute_parity_error (core_spad_parity_error),
        .line_valid           (spad_line_valid && line_prot_allow),
        .line_write           (spad_line_write),
        .line_addr            (spad_line_addr),
        .line_wdata           (spad_line_wdata),
        .line_wstrb           (spad_line_wstrb),
        .line_rdata           (spad_line_rdata),
        .line_parity_error    (spad_line_parity_error),
        .line_error           (spad_line_raw_error),
        .banked_read_valid    (arb_banked_valid),
        .banked_addr          (arb_banked_addr),
        .banked_data0         (banked_data0),
        .banked_data1         (banked_data1),
        .banked_data2         (banked_data2),
        .banked_data3         (banked_data3),
        .banked_parity_error  (banked_parity)
        ,.cnm_read_valid      (arb_cnm_valid)
        ,.cnm_addr0           (arb_cnm_addr0)
        ,.cnm_addr1           (arb_cnm_addr1)
        ,.cnm_addr2           (arb_cnm_addr2)
        ,.cnm_addr3           (arb_cnm_addr3)
        ,.cnm_data0           (cnm_data0)
        ,.cnm_data1           (cnm_data1)
        ,.cnm_data2           (cnm_data2)
        ,.cnm_data3           (cnm_data3)
        ,.cnm_parity_error    (cnm_parity)
    );

    // 从 scratchpad 取 descriptor。descriptor 本质是一条 64-byte 任务描述，
    // 包含 op/src/dst/length/M/N/K/quant/task_id 等字段。
    ai_desc_fetch desc_fetch_u(
        .clk              (aclk),
        .resetn           (aresetn),
        .start            (fetch_start && !fetch_external),
        .desc_base        (fetch_base[31:0]),
        .spad_ready       (arb_desc_ready),
        .spad_rsp_valid   (desc_rsp_valid),
        .spad_rdata       (arb_rsp_rdata),
        .spad_error       (desc_rsp_error),
        .spad_valid       (desc_spad_valid),
        .spad_addr        (desc_spad_addr),
        .busy             (spad_desc_busy),
        .done             (spad_desc_done),
        .error            (spad_desc_error),
        .desc_op          (spad_desc_op),
        .desc_task_id     (spad_desc_task_id),
        .desc_src0_base   (spad_desc_src0_base),
        .desc_src1_base   (spad_desc_src1_base),
        .desc_dst_base    (spad_desc_dst_base),
        .desc_length      (spad_desc_length),
        .desc_m_size      (spad_desc_m_size),
        .desc_n_size      (spad_desc_n_size),
        .desc_k_words     (spad_desc_k_words),
        .desc_scale_shift (spad_desc_scale_shift),
        .desc_activation  (spad_desc_activation),
        .desc_bias_base   (spad_desc_bias_base),
        .desc_bias_enable (spad_desc_bias_enable),
        .desc_flags       (spad_desc_flags),
        .desc_aux0        (spad_desc_aux0),
        .desc_src0_stride (spad_desc_src0_stride),
        .desc_src1_stride (spad_desc_src1_stride),
        .desc_dst_stride  (spad_desc_dst_stride),
        .desc_batch_count (spad_desc_batch_count),
        .desc_head_count  (spad_desc_head_count),
        .desc_wait_mask   (spad_desc_wait_mask),
        .desc_signal_mask (spad_desc_signal_mask),
        .desc_clear_mask  (spad_desc_clear_mask),
        .desc_version     (spad_desc_version)
    );

    // 从外部 DDR/AXI memory 取 descriptor。适合软件把命令队列放在外部 memory
    // 的场景；该模块只使用 AXI read channel。
    axi_desc_fetch #(.AXI_ADDR_WIDTH(M_AXI_ADDR_WIDTH)) axi_desc_fetch_u(
        .clk              (aclk),
        .resetn           (aresetn),
        .start            (fetch_start && fetch_external),
        .desc_base        (fetch_base),
        .m_axi_arid       (axi_desc_m_axi_arid),
        .m_axi_arvalid    (axi_desc_m_axi_arvalid),
        .m_axi_araddr     (axi_desc_m_axi_araddr),
        .m_axi_arlen      (axi_desc_m_axi_arlen),
        .m_axi_arsize     (axi_desc_m_axi_arsize),
        .m_axi_arburst    (axi_desc_m_axi_arburst),
        .m_axi_arready    (axi_desc_m_axi_arready),
        .m_axi_rid        (m_axi_rid),
        .m_axi_rdata      (m_axi_rdata),
        .m_axi_rresp      (m_axi_rresp),
        .m_axi_rvalid     (m_axi_rvalid),
        .m_axi_rlast      (m_axi_rlast),
        .m_axi_rready     (axi_desc_m_axi_rready),
        .busy             (axi_desc_busy),
        .done             (axi_desc_done),
        .error            (axi_desc_error),
        .desc_op          (axi_desc_op),
        .desc_task_id     (axi_desc_task_id),
        .desc_src0_base   (axi_desc_src0_base),
        .desc_src1_base   (axi_desc_src1_base),
        .desc_dst_base    (axi_desc_dst_base),
        .desc_length      (axi_desc_length),
        .desc_m_size      (axi_desc_m_size),
        .desc_n_size      (axi_desc_n_size),
        .desc_k_words     (axi_desc_k_words),
        .desc_scale_shift (axi_desc_scale_shift),
        .desc_activation  (axi_desc_activation),
        .desc_bias_base   (axi_desc_bias_base),
        .desc_bias_enable (axi_desc_bias_enable),
        .desc_flags       (axi_desc_flags),
        .desc_aux0        (axi_desc_aux0),
        .desc_src0_stride (axi_desc_src0_stride),
        .desc_src1_stride (axi_desc_src1_stride),
        .desc_dst_stride  (axi_desc_dst_stride),
        .desc_batch_count (axi_desc_batch_count),
        .desc_head_count  (axi_desc_head_count),
        .desc_wait_mask   (axi_desc_wait_mask),
        .desc_signal_mask (axi_desc_signal_mask),
        .desc_clear_mask  (axi_desc_clear_mask),
        .desc_version     (axi_desc_version)
    );

    // INT8 计算核心：
    // 根据寄存器或 descriptor 解码后的配置，从 scratchpad 读取 packed INT8 数据，
    // 执行 VDOT/GEMV/GEMM_TILE，并把结果写回 scratchpad。
    ai_banked_cnm_core banked_core_u(
        .clk(aclk), .resetn(aresetn), .start(core_start && banked_op), .abort(core_abort), .op_mode(launch_op),
        .src0_base(launch_src0), .src1_base(launch_src1), .dst_base(launch_dst),
        .length(launch_length), .m_size(launch_m), .scale_shift(launch_shift), .activation(launch_activation),
        .watchdog_limit(watchdog_limit),
        .cnm_req_valid(cnm_read_valid), .cnm_addr0(cnm_read_addr0), .cnm_addr1(cnm_read_addr1),
        .cnm_addr2(cnm_read_addr2), .cnm_addr3(cnm_read_addr3), .cnm_req_ready(arb_cnm_ready),
        .cnm_rsp_valid(cnm_rsp_valid), .cnm_data0(cnm_data0), .cnm_data1(cnm_data1),
        .cnm_data2(cnm_data2), .cnm_data3(cnm_data3), .cnm_parity_error(cnm_parity),
        .cnm_protection_error(cnm_protection_error),
        .spad_valid(banked_spad_valid), .spad_write(banked_spad_write), .spad_addr(banked_spad_addr), .spad_wdata(banked_spad_wdata),
        .spad_ready(arb_core_ready),
        .spad_protection_error(compute_prot_error),
        .busy(banked_busy), .done(banked_done), .error(banked_error), .error_code(banked_error_code),
        .result(banked_result), .cycle_count(banked_cycle_count), .element_count(banked_element_count)
    );

    // A3 matrix path: a 4x4 INT8 PE tile consumes the banked-read path and
    // commits each four-word INT32 result row through the 128-bit line port.
    ai_tensor_matrix_core tensor_matrix_u(
        .clk(aclk), .resetn(aresetn),
        .start(core_start && tensor_matrix_op), .abort(core_abort), .op_mode(launch_op),
        .src0_base(launch_src0), .src1_base(launch_src1),
        .bias_base(launch_bias_base), .dst_base(launch_dst),
        .m_size(launch_m), .n_size(launch_n), .k_words(launch_k),
        // Batch and attention-head dimensions are flattened into consecutive
        // tensor instances.  The three descriptor strides advance one
        // flattened instance, avoiding a second set of head-stride fields.
        .instance_count(launch_instance_count),
        .src0_batch_stride(launch_src0_stride), .src1_batch_stride(launch_src1_stride),
        .dst_batch_stride(launch_dst_stride),
        .transpose_a(launch_flags[1]), .transpose_b(launch_flags[2]),
        .bias_enable(launch_bias_enable), .scale_shift(launch_shift),
        .activation(launch_activation), .watchdog_limit(watchdog_limit),
        .bank0_data(banked_data0), .bank1_data(banked_data1),
        .bank2_data(banked_data2), .bank3_data(banked_data3),
        .bank_parity_error(banked_parity),
        .banked_read_valid(matrix_banked_read_valid), .banked_addr(matrix_banked_read_addr),
        .banked_ready(arb_banked_ready), .banked_rsp_valid(banked_rsp_valid),
        .banked_protection_error(banked_protection_error),
        .spad_valid(matrix_spad_valid), .spad_write(matrix_spad_write),
        .spad_addr(matrix_spad_addr), .spad_wdata(matrix_spad_wdata),
        .spad_ready(arb_core_ready), .spad_rsp_valid(core_rsp_valid),
        .spad_rdata(arb_rsp_rdata),
        .spad_parity_error(core_rsp_error || core_spad_parity_error),
        .spad_protection_error(compute_prot_error),
        .line_valid(matrix_line_valid), .line_write(matrix_line_write),
        .line_addr(matrix_line_addr), .line_wdata(matrix_line_wdata),
        .line_wstrb(matrix_line_wstrb), .line_ready(arb_core_line_ready),
        .line_protection_error(line_prot_error || spad_line_raw_error),
        .busy(matrix_busy), .done(matrix_done), .error(matrix_error),
        .error_code(matrix_error_code), .result(matrix_result),
        .cycle_count(matrix_cycle_count), .element_count(matrix_element_count),
        .perf_mac_active(matrix_perf_mac_active),
        .perf_banked_wait(matrix_perf_banked_wait)
    );

    // A3 vector/SFU path executes numerically defined tensor primitives used
    // to assemble attention and FFN command chains.
    ai_tensor_sfu_core tensor_sfu_u(
        .clk(aclk), .resetn(aresetn),
        .start(core_start && tensor_sfu_op), .abort(core_abort), .op_mode(launch_op),
        .src0_base(launch_src0), .src1_base(launch_src1),
        .beta_base(launch_bias_base), .beta_enable(launch_bias_enable),
        .pack_enable(launch_flags[4]), .dst_base(launch_dst),
        .length(launch_length), .scale_shift(launch_shift),
        .epsilon(launch_aux0), .watchdog_limit(watchdog_limit),
        .spad_valid(sfu_spad_valid), .spad_write(sfu_spad_write),
        .spad_addr(sfu_spad_addr), .spad_wdata(sfu_spad_wdata),
        .spad_ready(arb_core_ready), .spad_rsp_valid(core_rsp_valid),
        .spad_rdata(arb_rsp_rdata),
        .spad_parity_error(core_rsp_error || core_spad_parity_error),
        .spad_protection_error(compute_prot_error),
        .busy(sfu_busy), .done(sfu_done), .error(sfu_error),
        .error_code(sfu_error_code), .result(sfu_result),
        .cycle_count(sfu_cycle_count), .element_count(sfu_element_count)
    );

    // A6 raster CNN frontend (0x16/0x17).  Legacy 0x14/0x15 remain the
    // im2col-compatible path; this engine constructs windows in hardware.
    ai_conv3x3_linebuffer_core conv_linebuffer_u(
        .clk(aclk), .resetn(aresetn), .start(core_start && conv_linebuffer_op),
        .abort(core_abort), .op_mode(launch_op), .src0_base(launch_src0),
        .src1_base(launch_src1), .dst_base(launch_dst), .height(launch_m),
        .width(launch_n), .watchdog_limit(watchdog_limit),
        .spad_valid(conv_spad_valid), .spad_write(conv_spad_write),
        .spad_addr(conv_spad_addr), .spad_wdata(conv_spad_wdata),
        .spad_ready(arb_core_ready), .spad_rsp_valid(core_rsp_valid),
        .spad_rdata(arb_rsp_rdata),
        .spad_error(core_rsp_error || core_spad_parity_error || compute_prot_error),
        .busy(conv_busy), .done(conv_done), .error(conv_error), .error_code(conv_error_code),
        .result(conv_result), .cycle_count(conv_cycle_count), .element_count(conv_element_count)
    );

    // A6 KV-cache read/write primitive.  aux0 selects {head,token}; the
    // descriptor's two source stride fields define the cache layout.
    ai_kv_cache_engine kv_cache_u(
        .clk(aclk), .resetn(aresetn), .start(core_start && kv_cache_op),
        .abort(core_abort), .op_mode(launch_op), .src0_base(launch_src0),
        .dst_base(launch_dst), .length(launch_length),
        .src0_stride(launch_src0_stride), .src1_stride(launch_src1_stride),
        .aux0(launch_aux0), .watchdog_limit(watchdog_limit),
        .spad_valid(kv_spad_valid), .spad_write(kv_spad_write),
        .spad_addr(kv_spad_addr), .spad_wdata(kv_spad_wdata),
        .spad_ready(arb_core_ready), .spad_rsp_valid(core_rsp_valid),
        .spad_rdata(arb_rsp_rdata),
        .spad_error(core_rsp_error || core_spad_parity_error || compute_prot_error),
        .busy(kv_busy), .done(kv_done), .error(kv_error), .error_code(kv_error_code),
        .result(kv_result), .cycle_count(kv_cycle_count), .element_count(kv_element_count)
    );

    ai_int8_compute_core core_u(
        .clk                (aclk),
        .resetn             (aresetn),
        .start              (core_start && !banked_op && !tensor_matrix_op && !tensor_sfu_op && !conv_linebuffer_op && !kv_cache_op),
        .abort              (core_abort),
        .op_mode            (launch_op),
        .src0_base          (launch_src0),
        .src1_base          (launch_src1),
        .dst_base           (launch_dst),
        .length             (launch_length),
        .m_size             (launch_m),
        .n_size             (launch_n),
        .k_words            (launch_k),
        .scale_shift        (launch_shift),
        .activation         (launch_activation),
        .bias_base          (launch_bias_base),
        .bias_enable        (launch_bias_enable),
        .watchdog_limit     (watchdog_limit),
        .spad_ready         (arb_core_ready),
        .spad_rsp_valid     (core_rsp_valid),
        .spad_parity_error  (core_rsp_error || core_spad_parity_error),
        .spad_protection_error(compute_prot_error),
        .spad_rdata         (arb_rsp_rdata),
        .spad_valid         (scalar_spad_valid),
        .spad_write         (scalar_spad_write),
        .spad_addr          (scalar_spad_addr),
        .spad_wdata         (scalar_spad_wdata),
        .busy               (scalar_busy),
        .done               (scalar_done),
        .error              (scalar_error),
        .error_code         (scalar_error_code),
        .result             (scalar_result),
        .cycle_count        (scalar_cycle_count),
        .element_count      (scalar_element_count)
    );

endmodule
