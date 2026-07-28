`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: vec_accel_top
//
// 功能：
//   AHB-Lite 可配置的片上 SRAM 向量计算加速器顶层。
//
// 地址空间：
//   0x0000_0000 ~ 0x0000_ffff : scratchpad SRAM 窗口
//   0x0001_0000 ~ 0x0001_00ff : 加速器控制寄存器窗口
//
// 工作方式：
//   1. 软件/测试平台先通过 AHB 把输入向量写入 scratchpad SRAM。
//   2. 软件/测试平台配置寄存器：src0_base、src1_base、dst_base、length、op_mode、stride。
//   3. 写 CTRL.start 启动计算。
//   4. 计算核心运行期间接管 SRAM 端口，从 scratchpad 取数、计算、写回结果。
//   5. 完成后 STATUS.done 置位，可选产生 irq。
//
// 仲裁策略：
//   compute core busy 时，AHB 仍可访问寄存器，但不允许访问 scratchpad SRAM。
//   busy 期间访问 SRAM 窗口会返回 ERROR，避免 host 和 compute 同时驱动单端口 SRAM。
//////////////////////////////////////////////////////////////////////////////////

module vec_accel_top #(
    parameter integer SRAM_WAIT_CYCLES = 1,
    parameter [31:0]  COMPUTE_ADDR_MAX = 32'h0000_3ffc
)(
    input  wire          hclk,
    input  wire          sram_clk,
    input  wire          hresetn,

    input  wire          hsel,
    input  wire          hwrite,
    input  wire          hready,
    input  wire [2:0]    hsize,
    input  wire [2:0]    hburst,
    input  wire [1:0]    htrans,
    input  wire [31:0]   hwdata,
    input  wire [31:0]   haddr,

    input  wire          dft_en,
    input  wire          bist_en,

    output wire          hready_resp,
    output wire [1:0]    hresp,
    output wire [31:0]   hrdata,

    output wire          irq,
    output wire          bist_done,
    output wire [7:0]    bist_fail
);

    localparam HTRANS_NONSEQ = 2'b10;
    localparam HTRANS_SEQ    = 2'b11;
    localparam HRESP_OKAY    = 2'b00;
    localparam HRESP_ERROR   = 2'b01;

    wire        addr_phase_valid;
    wire        reg_region;
    wire        sram_region;

    wire        regs_hready_resp;
    wire [1:0]  regs_hresp;
    wire [31:0] regs_hrdata;

    wire        ahb_sram_hready_resp;
    wire [1:0]  ahb_sram_hresp;
    wire [31:0] ahb_sram_hrdata;

    wire        ahb_sram_w_en;
    wire        ahb_bank_sel;
    wire [3:0]  ahb_bank0_csn;
    wire [3:0]  ahb_bank1_csn;
    wire [12:0] ahb_sram_addr;
    wire [31:0] ahb_sram_wdata;

    wire        core_busy;
    wire        core_done;
    wire        core_error;
    wire [31:0] core_result;
    wire [3:0]  core_error_code;
    wire [31:0] core_cycle_count;
    wire [15:0] core_element_count;
    wire [31:0] core_som_best_distance;
    wire [15:0] core_som_winner_index;
    wire        core_start;
    wire        core_soft_reset;
    wire [2:0]  core_op_mode;
    wire [31:0] core_src0_base;
    wire [31:0] core_src1_base;
    wire [31:0] core_dst_base;
    wire [15:0] core_length;
    wire [4:0]  core_scale_shift;
    wire [31:0] core_src0_stride;
    wire [31:0] core_src1_stride;
    wire [31:0] core_dst_stride;
    wire        core_signed_mode;
    wire        core_saturate_en;
    wire        core_round_en;
    wire [1:0]  core_data_width;
    wire [15:0] core_neuron_count;
    wire [31:0] core_neuron_stride;
    wire [15:0] core_neuron_index;

    wire        core_sram_req;
    wire        core_sram_w_en;
    wire [31:0] core_sram_addr_full;
    wire [31:0] core_sram_wdata;
    wire [31:0] core_sram_rdata;

    wire        sram_w_en_mux;
    wire        bank_sel_mux;
    wire [3:0]  bank0_csn_mux;
    wire [3:0]  bank1_csn_mux;
    wire [12:0] sram_addr_mux;
    wire [31:0] sram_wdata_mux;

    wire [7:0] sram_q0;
    wire [7:0] sram_q1;
    wire [7:0] sram_q2;
    wire [7:0] sram_q3;
    wire [7:0] sram_q4;
    wire [7:0] sram_q5;
    wire [7:0] sram_q6;
    wire [7:0] sram_q7;

    reg        target_active_r;
    reg [1:0]  target_sel_r;

    localparam TARGET_SRAM = 2'd0;
    localparam TARGET_REG  = 2'd1;
    localparam TARGET_BUSY = 2'd2;

    assign addr_phase_valid = hsel && hready &&
                              ((htrans == HTRANS_NONSEQ) || (htrans == HTRANS_SEQ));
    assign reg_region  = haddr[16];
    assign sram_region = !haddr[16];

    // 响应通路按地址相位锁存的目标返回，避免 AHB 地址流水变化影响数据相位。
    assign hready_resp = (target_sel_r == TARGET_SRAM) ? ahb_sram_hready_resp :
                         (target_sel_r == TARGET_REG)  ? regs_hready_resp :
                         1'b1;
    assign hresp = (target_sel_r == TARGET_SRAM) ? ahb_sram_hresp :
                   (target_sel_r == TARGET_REG)  ? regs_hresp :
                   (target_sel_r == TARGET_BUSY) ? HRESP_ERROR :
                   HRESP_OKAY;
    assign hrdata = (target_sel_r == TARGET_SRAM) ? ahb_sram_hrdata :
                    (target_sel_r == TARGET_REG)  ? regs_hrdata :
                    32'h0000_0000;

    always @(posedge hclk or negedge hresetn) begin
        if (!hresetn) begin
            target_active_r <= 1'b0;
            target_sel_r    <= TARGET_SRAM;
        end else begin
            if (addr_phase_valid && hready_resp) begin
                target_active_r <= 1'b1;
                if (reg_region)
                    target_sel_r <= TARGET_REG;
                else if (core_busy)
                    target_sel_r <= TARGET_BUSY;
                else
                    target_sel_r <= TARGET_SRAM;
            end else if (target_active_r && hready_resp) begin
                target_active_r <= 1'b0;
            end
        end
    end

    vec_accel_regs regs_u(
        .hclk             (hclk),
        .hresetn          (hresetn),
        .hsel             (hsel && reg_region),
        .hready           (hready),
        .hwrite           (hwrite),
        .htrans           (htrans),
        .hsize            (hsize),
        .haddr            (haddr),
        .hwdata           (hwdata),
        .core_busy        (core_busy),
        .core_done        (core_done),
        .core_error       (core_error),
        .core_result      (core_result),
        .core_error_code  (core_error_code),
        .core_cycle_count (core_cycle_count),
        .core_element_count(core_element_count),
        .core_som_best_distance(core_som_best_distance),
        .core_som_winner_index (core_som_winner_index),
        .hready_resp      (regs_hready_resp),
        .hresp            (regs_hresp),
        .hrdata           (regs_hrdata),
        .start_pulse      (core_start),
        .soft_reset_pulse (core_soft_reset),
        .op_mode          (core_op_mode),
        .irq_en           (),
        .src0_base        (core_src0_base),
        .src1_base        (core_src1_base),
        .dst_base         (core_dst_base),
        .length           (core_length),
        .scale_shift      (core_scale_shift),
        .src0_stride      (core_src0_stride),
        .src1_stride      (core_src1_stride),
        .dst_stride       (core_dst_stride),
        .signed_mode      (core_signed_mode),
        .saturate_en      (core_saturate_en),
        .round_en         (core_round_en),
        .data_width       (core_data_width),
        .neuron_count     (core_neuron_count),
        .neuron_stride    (core_neuron_stride),
        .neuron_index     (core_neuron_index),
        .irq              (irq)
    );

    ahb_slave_if #(
        .SRAM_WAIT_CYCLES(SRAM_WAIT_CYCLES)
    ) ahb_sram_if_u(
        .hclk          (hclk),
        .hresetn       (hresetn),
        .hsel          (hsel && sram_region && !core_busy),
        .hready        (hready),
        .hwrite        (hwrite),
        .hsize         (hsize),
        .htrans        (htrans),
        .hburst        (hburst),
        .hwdata        (hwdata),
        .haddr         (haddr),
        .sram_q0       (sram_q0),
        .sram_q1       (sram_q1),
        .sram_q2       (sram_q2),
        .sram_q3       (sram_q3),
        .sram_q4       (sram_q4),
        .sram_q5       (sram_q5),
        .sram_q6       (sram_q6),
        .sram_q7       (sram_q7),
        .hready_resp   (ahb_sram_hready_resp),
        .hresp         (ahb_sram_hresp),
        .hrdata        (ahb_sram_hrdata),
        .sram_w_en     (ahb_sram_w_en),
        .sram_addr_out (ahb_sram_addr),
        .sram_wdata    (ahb_sram_wdata),
        .bank_sel      (ahb_bank_sel),
        .bank0_csn     (ahb_bank0_csn),
        .bank1_csn     (ahb_bank1_csn)
    );

    vec_accel_core #(
        .SRAM_WAIT_CYCLES(SRAM_WAIT_CYCLES),
        .COMPUTE_ADDR_MAX(COMPUTE_ADDR_MAX)
    ) core_u(
        .hclk        (hclk),
        .hresetn     (hresetn),
        .start       (core_start),
        .soft_reset  (core_soft_reset),
        .op_mode     (core_op_mode),
        .src0_base   (core_src0_base),
        .src1_base   (core_src1_base),
        .dst_base    (core_dst_base),
        .length      (core_length),
        .scale_shift (core_scale_shift),
        .src0_stride (core_src0_stride),
        .src1_stride (core_src1_stride),
        .dst_stride  (core_dst_stride),
        .signed_mode (core_signed_mode),
        .saturate_en (core_saturate_en),
        .round_en    (core_round_en),
        .data_width  (core_data_width),
        .neuron_count(core_neuron_count),
        .neuron_stride(core_neuron_stride),
        .neuron_index(core_neuron_index),
        .sram_rdata  (core_sram_rdata),
        .busy        (core_busy),
        .done        (core_done),
        .error       (core_error),
        .result      (core_result),
        .error_code  (core_error_code),
        .cycle_count (core_cycle_count),
        .element_count(core_element_count),
        .som_best_distance(core_som_best_distance),
        .som_winner_index (core_som_winner_index),
        .sram_req    (core_sram_req),
        .sram_w_en   (core_sram_w_en),
        .sram_addr   (core_sram_addr_full),
        .sram_wdata  (core_sram_wdata)
    );

    assign core_sram_rdata = core_sram_addr_full[13] ?
                             {sram_q7, sram_q6, sram_q5, sram_q4} :
                             {sram_q3, sram_q2, sram_q1, sram_q0};

    assign sram_w_en_mux   = core_sram_req ? core_sram_w_en : ahb_sram_w_en;
    assign sram_addr_mux   = core_sram_req ? core_sram_addr_full[12:0] : ahb_sram_addr;
    assign sram_wdata_mux  = core_sram_req ? core_sram_wdata : ahb_sram_wdata;
    assign bank_sel_mux    = core_sram_req ? (core_sram_addr_full[13] == 1'b0) : ahb_bank_sel;
    assign bank0_csn_mux   = core_sram_req ? ((core_sram_addr_full[13] == 1'b0) ? 4'b0000 : 4'b1111) :
                                             ahb_bank0_csn;
    assign bank1_csn_mux   = core_sram_req ? ((core_sram_addr_full[13] == 1'b1) ? 4'b0000 : 4'b1111) :
                                             ahb_bank1_csn;

    sram_core sram_core_u(
        .hclk          (hclk),
        .sram_clk      (sram_clk),
        .hresetn       (hresetn),
        .sram_addr     (sram_addr_mux),
        .sram_wdata_in (sram_wdata_mux),
        .sram_wen      (sram_w_en_mux),
        .bank_sel      (bank_sel_mux),
        .bank0_csn     (bank0_csn_mux),
        .bank1_csn     (bank1_csn_mux),
        .bist_en       (bist_en),
        .dft_en        (dft_en),
        .sram_q0       (sram_q0),
        .sram_q1       (sram_q1),
        .sram_q2       (sram_q2),
        .sram_q3       (sram_q3),
        .sram_q4       (sram_q4),
        .sram_q5       (sram_q5),
        .sram_q6       (sram_q6),
        .sram_q7       (sram_q7),
        .bist_done     (bist_done),
        .bist_fail     (bist_fail)
    );

endmodule
