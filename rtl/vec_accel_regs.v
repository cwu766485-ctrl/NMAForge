`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: vec_accel_regs
//
// 功能：
//   AHB-Lite 可访问的向量加速器控制/状态寄存器块。
//
// 地址映射：
//   0x00 CTRL          bit0 start, bit[3:1] op_mode, bit4 irq_en, bit8 soft_reset
//   0x04 STATUS        bit0 busy, bit1 done, bit2 error
//   0x08 SRC0_BASE     输入向量 A 起始地址
//   0x0c SRC1_BASE     输入向量 B 起始地址
//   0x10 DST_BASE      输出向量/累加结果地址
//   0x14 LENGTH        向量长度，单位为 32-bit word
//   0x18 SCALE_SHIFT   VMAC/VMUL 结果右移位数
//   0x1c IRQ_STATUS    bit0 irq_status，写 1 清除
//   0x20 RESULT        最近一次任务结果
//   0x24 VERSION       版本号，只读
//   0x28 CAPABILITY    能力寄存器，只读
//   0x2c ERROR_CODE    最近一次错误码，只读，写 STATUS.error 清除
//   0x30 CYCLE_COUNT   最近一次任务 busy 周期数，只读
//   0x34 ELEMENT_COUNT 最近一次任务处理元素数，只读
//   0x38 SRC0_STRIDE   输入向量 A 地址步长，单位 byte，默认 4
//   0x3c SRC1_STRIDE   输入向量 B 地址步长，单位 byte，默认 4
//   0x40 DST_STRIDE    输出向量地址步长，单位 byte，默认 4
//   0x44 CONFIG        bit0 signed, bit1 saturate, bit2 round, bit[5:4] data_width
//   0x48 IRQ_ENABLE    bit0 interrupt output enable
//   0x4c IRQ_MASK      bit0 interrupt mask, 1 means masked
//   0x50 IRQ_CLEAR     write bit0=1 clears interrupt status
//   0x54 NEURON_COUNT  SOM recall 扫描的 neuron 数量，默认 1
//   0x58 NEURON_STRIDE 相邻 neuron weight vector 的地址间隔，单位 byte，默认 4
//   0x5c NEURON_INDEX  SOM update 目标 neuron index
//   0x60 SOM_BEST_DIST 最近一次 SOM recall 的最小 L1 distance，只读
//   0x64 SOM_WINNER    最近一次 SOM recall 的 winner index，只读
//
// 说明：
//   寄存器访问不插入 wait-state，hready_resp 固定为 1。busy 期间禁止修改
//   配置寄存器，避免软件在任务执行中途破坏 src/dst/length/op/stride 等配置。
//////////////////////////////////////////////////////////////////////////////////

module vec_accel_regs(
    input  wire        hclk,
    input  wire        hresetn,

    input  wire        hsel,
    input  wire        hready,
    input  wire        hwrite,
    input  wire [1:0]  htrans,
    input  wire [2:0]  hsize,
    input  wire [31:0] haddr,
    input  wire [31:0] hwdata,

    input  wire        core_busy,
    input  wire        core_done,
    input  wire        core_error,
    input  wire [31:0] core_result,
    input  wire [3:0]  core_error_code,
    input  wire [31:0] core_cycle_count,
    input  wire [15:0] core_element_count,
    input  wire [31:0] core_som_best_distance,
    input  wire [15:0] core_som_winner_index,

    output wire        hready_resp,
    output wire [1:0]  hresp,
    output reg  [31:0] hrdata,

    output reg         start_pulse,
    output reg         soft_reset_pulse,
    output reg  [2:0]  op_mode,
    output reg         irq_en,
    output reg  [31:0] src0_base,
    output reg  [31:0] src1_base,
    output reg  [31:0] dst_base,
    output reg  [15:0] length,
    output reg  [4:0]  scale_shift,
    output reg  [31:0] src0_stride,
    output reg  [31:0] src1_stride,
    output reg  [31:0] dst_stride,
    output reg         signed_mode,
    output reg         saturate_en,
    output reg         round_en,
    output reg  [1:0]  data_width,
    output reg  [15:0] neuron_count,
    output reg  [31:0] neuron_stride,
    output reg  [15:0] neuron_index,
    output wire        irq
);

    localparam HTRANS_NONSEQ = 2'b10;
    localparam HTRANS_SEQ    = 2'b11;

    localparam HSIZE_WORD = 3'b010;

    localparam HRESP_OKAY  = 2'b00;
    localparam HRESP_ERROR = 2'b01;

    localparam ADDR_CTRL          = 8'h00;
    localparam ADDR_STATUS        = 8'h04;
    localparam ADDR_SRC0_BASE     = 8'h08;
    localparam ADDR_SRC1_BASE     = 8'h0c;
    localparam ADDR_DST_BASE      = 8'h10;
    localparam ADDR_LENGTH        = 8'h14;
    localparam ADDR_SCALE_SHIFT   = 8'h18;
    localparam ADDR_IRQ_STATUS    = 8'h1c;
    localparam ADDR_RESULT        = 8'h20;
    localparam ADDR_VERSION       = 8'h24;
    localparam ADDR_CAPABILITY    = 8'h28;
    localparam ADDR_ERROR_CODE    = 8'h2c;
    localparam ADDR_CYCLE_COUNT   = 8'h30;
    localparam ADDR_ELEMENT_COUNT = 8'h34;
    localparam ADDR_SRC0_STRIDE   = 8'h38;
    localparam ADDR_SRC1_STRIDE   = 8'h3c;
    localparam ADDR_DST_STRIDE    = 8'h40;
    localparam ADDR_CONFIG        = 8'h44;
    localparam ADDR_IRQ_ENABLE    = 8'h48;
    localparam ADDR_IRQ_MASK      = 8'h4c;
    localparam ADDR_IRQ_CLEAR     = 8'h50;
    localparam ADDR_NEURON_COUNT  = 8'h54;
    localparam ADDR_NEURON_STRIDE = 8'h58;
    localparam ADDR_NEURON_INDEX  = 8'h5c;
    localparam ADDR_SOM_BEST_DIST = 8'h60;
    localparam ADDR_SOM_WINNER    = 8'h64;

    localparam [31:0] VERSION_VALUE    = 32'h0004_0000;
    localparam [31:0] CAPABILITY_VALUE = 32'h0003_7f1f;

    localparam [3:0] ERR_NONE          = 4'd0;
    localparam [3:0] ERR_REG_ACCESS    = 4'd6;
    localparam [3:0] ERR_BUSY_WRITE    = 4'd7;
    localparam [3:0] ERR_READONLY_WR   = 4'd8;

    reg        write_phase_r;
    reg        write_error_r;
    reg [7:0]  write_addr_r;
    reg [7:0]  read_addr_r;
    reg        done_r;
    reg        error_r;
    reg        irq_status_r;
    reg        irq_enable_r;
    reg        irq_mask_r;
    reg [31:0] result_r;
    reg [3:0]  error_code_r;
    reg [31:0] cycle_count_r;
    reg [15:0] element_count_r;
    reg [31:0] som_best_distance_r;
    reg [15:0] som_winner_index_r;

    wire       addr_phase_valid;
    wire       word_access;
    wire       known_addr;
    wire       writable_addr;
    wire       busy_cfg_write;
    wire       addr_error;

    assign addr_phase_valid = hsel && hready &&
                              ((htrans == HTRANS_NONSEQ) || (htrans == HTRANS_SEQ));
    assign word_access = (hsize == HSIZE_WORD) && (haddr[1:0] == 2'b00);

    assign known_addr = (haddr[7:0] == ADDR_CTRL)          ||
                        (haddr[7:0] == ADDR_STATUS)        ||
                        (haddr[7:0] == ADDR_SRC0_BASE)     ||
                        (haddr[7:0] == ADDR_SRC1_BASE)     ||
                        (haddr[7:0] == ADDR_DST_BASE)      ||
                        (haddr[7:0] == ADDR_LENGTH)        ||
                        (haddr[7:0] == ADDR_SCALE_SHIFT)   ||
                        (haddr[7:0] == ADDR_IRQ_STATUS)    ||
                        (haddr[7:0] == ADDR_RESULT)        ||
                        (haddr[7:0] == ADDR_VERSION)       ||
                        (haddr[7:0] == ADDR_CAPABILITY)    ||
                        (haddr[7:0] == ADDR_ERROR_CODE)    ||
                        (haddr[7:0] == ADDR_CYCLE_COUNT)   ||
                        (haddr[7:0] == ADDR_ELEMENT_COUNT) ||
                        (haddr[7:0] == ADDR_SRC0_STRIDE)   ||
                        (haddr[7:0] == ADDR_SRC1_STRIDE)   ||
                        (haddr[7:0] == ADDR_DST_STRIDE)    ||
                        (haddr[7:0] == ADDR_CONFIG)        ||
                        (haddr[7:0] == ADDR_IRQ_ENABLE)    ||
                        (haddr[7:0] == ADDR_IRQ_MASK)      ||
                        (haddr[7:0] == ADDR_IRQ_CLEAR)     ||
                        (haddr[7:0] == ADDR_NEURON_COUNT)  ||
                        (haddr[7:0] == ADDR_NEURON_STRIDE) ||
                        (haddr[7:0] == ADDR_NEURON_INDEX)  ||
                        (haddr[7:0] == ADDR_SOM_BEST_DIST) ||
                        (haddr[7:0] == ADDR_SOM_WINNER);

    assign writable_addr = (haddr[7:0] == ADDR_CTRL)        ||
                           (haddr[7:0] == ADDR_STATUS)      ||
                           (haddr[7:0] == ADDR_SRC0_BASE)   ||
                           (haddr[7:0] == ADDR_SRC1_BASE)   ||
                           (haddr[7:0] == ADDR_DST_BASE)    ||
                           (haddr[7:0] == ADDR_LENGTH)      ||
                           (haddr[7:0] == ADDR_SCALE_SHIFT) ||
                           (haddr[7:0] == ADDR_IRQ_STATUS)  ||
                           (haddr[7:0] == ADDR_SRC0_STRIDE) ||
                           (haddr[7:0] == ADDR_SRC1_STRIDE) ||
                           (haddr[7:0] == ADDR_DST_STRIDE)  ||
                           (haddr[7:0] == ADDR_CONFIG)      ||
                           (haddr[7:0] == ADDR_IRQ_ENABLE)  ||
                           (haddr[7:0] == ADDR_IRQ_MASK)    ||
                           (haddr[7:0] == ADDR_IRQ_CLEAR)   ||
                           (haddr[7:0] == ADDR_NEURON_COUNT) ||
                           (haddr[7:0] == ADDR_NEURON_STRIDE) ||
                           (haddr[7:0] == ADDR_NEURON_INDEX);

    assign busy_cfg_write = addr_phase_valid && hwrite && core_busy &&
                            !((haddr[7:0] == ADDR_STATUS) ||
                              (haddr[7:0] == ADDR_IRQ_STATUS) ||
                              (haddr[7:0] == ADDR_IRQ_MASK) ||
                              (haddr[7:0] == ADDR_IRQ_CLEAR));

    assign addr_error = addr_phase_valid &&
                        (!word_access || !known_addr ||
                         (hwrite && !writable_addr) || busy_cfg_write);

    assign hready_resp = 1'b1;
    assign hresp = (addr_error || write_error_r) ? HRESP_ERROR : HRESP_OKAY;
    assign irq = irq_en && irq_enable_r && irq_status_r && !irq_mask_r;

    always @(*) begin
        hrdata = 32'h0000_0000;
        case (read_addr_r)
            ADDR_CTRL: begin
                hrdata = {23'd0, 1'b0, 3'd0, irq_en, op_mode, 1'b0};
            end
            ADDR_STATUS: begin
                hrdata = {29'd0, error_r | core_error, done_r | core_done, core_busy};
            end
            ADDR_SRC0_BASE: begin
                hrdata = src0_base;
            end
            ADDR_SRC1_BASE: begin
                hrdata = src1_base;
            end
            ADDR_DST_BASE: begin
                hrdata = dst_base;
            end
            ADDR_LENGTH: begin
                hrdata = {16'd0, length};
            end
            ADDR_SCALE_SHIFT: begin
                hrdata = {27'd0, scale_shift};
            end
            ADDR_IRQ_STATUS: begin
                hrdata = {31'd0, irq_status_r};
            end
            ADDR_RESULT: begin
                hrdata = result_r;
            end
            ADDR_VERSION: begin
                hrdata = VERSION_VALUE;
            end
            ADDR_CAPABILITY: begin
                hrdata = CAPABILITY_VALUE;
            end
            ADDR_ERROR_CODE: begin
                hrdata = {28'd0, error_code_r};
            end
            ADDR_CYCLE_COUNT: begin
                hrdata = cycle_count_r;
            end
            ADDR_ELEMENT_COUNT: begin
                hrdata = {16'd0, element_count_r};
            end
            ADDR_SRC0_STRIDE: begin
                hrdata = src0_stride;
            end
            ADDR_SRC1_STRIDE: begin
                hrdata = src1_stride;
            end
            ADDR_DST_STRIDE: begin
                hrdata = dst_stride;
            end
            ADDR_CONFIG: begin
                hrdata = {26'd0, data_width, 1'b0, round_en, saturate_en, signed_mode};
            end
            ADDR_IRQ_ENABLE: begin
                hrdata = {31'd0, irq_enable_r};
            end
            ADDR_IRQ_MASK: begin
                hrdata = {31'd0, irq_mask_r};
            end
            ADDR_IRQ_CLEAR: begin
                hrdata = 32'd0;
            end
            ADDR_NEURON_COUNT: begin
                hrdata = {16'd0, neuron_count};
            end
            ADDR_NEURON_STRIDE: begin
                hrdata = neuron_stride;
            end
            ADDR_NEURON_INDEX: begin
                hrdata = {16'd0, neuron_index};
            end
            ADDR_SOM_BEST_DIST: begin
                hrdata = som_best_distance_r;
            end
            ADDR_SOM_WINNER: begin
                hrdata = {16'd0, som_winner_index_r};
            end
            default: begin
                hrdata = 32'h0000_0000;
            end
        endcase
    end

    always @(posedge hclk or negedge hresetn) begin
        if (!hresetn) begin
            write_phase_r    <= 1'b0;
            write_error_r    <= 1'b0;
            write_addr_r     <= 8'd0;
            read_addr_r      <= 8'd0;
            start_pulse      <= 1'b0;
            soft_reset_pulse <= 1'b0;
            op_mode          <= 3'd0;
            irq_en           <= 1'b0;
            src0_base        <= 32'd0;
            src1_base        <= 32'd0;
            dst_base         <= 32'd0;
            length           <= 16'd0;
            scale_shift      <= 5'd0;
            src0_stride      <= 32'd4;
            src1_stride      <= 32'd4;
            dst_stride       <= 32'd4;
            signed_mode      <= 1'b0;
            saturate_en      <= 1'b0;
            round_en         <= 1'b0;
            data_width       <= 2'd0;
            neuron_count     <= 16'd1;
            neuron_stride    <= 32'd4;
            neuron_index     <= 16'd0;
            done_r           <= 1'b0;
            error_r          <= 1'b0;
            irq_status_r     <= 1'b0;
            irq_enable_r     <= 1'b1;
            irq_mask_r       <= 1'b0;
            result_r         <= 32'd0;
            error_code_r     <= ERR_NONE;
            cycle_count_r    <= 32'd0;
            element_count_r  <= 16'd0;
            som_best_distance_r <= 32'd0;
            som_winner_index_r  <= 16'd0;
        end else begin
            start_pulse      <= 1'b0;
            soft_reset_pulse <= 1'b0;

            if (core_done) begin
                done_r          <= 1'b1;
                irq_status_r    <= 1'b1;
                result_r        <= core_result;
                error_code_r    <= core_error_code;
                cycle_count_r   <= core_cycle_count;
                element_count_r <= core_element_count;
                som_best_distance_r <= core_som_best_distance;
                som_winner_index_r  <= core_som_winner_index;
            end

            if (core_error)
                error_r <= 1'b1;

            if (write_phase_r && !write_error_r) begin
                case (write_addr_r)
                    ADDR_CTRL: begin
                        op_mode <= hwdata[3:1];
                        irq_en  <= hwdata[4];
                        irq_enable_r <= hwdata[4];
                        if (hwdata[0] && !core_busy) begin
                            start_pulse     <= 1'b1;
                            done_r          <= 1'b0;
                            error_r         <= 1'b0;
                            irq_status_r    <= 1'b0;
                            error_code_r    <= ERR_NONE;
                            cycle_count_r   <= 32'd0;
                            element_count_r <= 16'd0;
                            som_best_distance_r <= 32'd0;
                            som_winner_index_r  <= 16'd0;
                        end
                        if (hwdata[8])
                            soft_reset_pulse <= 1'b1;
                    end
                    ADDR_STATUS: begin
                        if (hwdata[1])
                            done_r <= 1'b0;
                        if (hwdata[2]) begin
                            error_r      <= 1'b0;
                            error_code_r <= ERR_NONE;
                        end
                    end
                    ADDR_SRC0_BASE: begin
                        src0_base <= hwdata;
                    end
                    ADDR_SRC1_BASE: begin
                        src1_base <= hwdata;
                    end
                    ADDR_DST_BASE: begin
                        dst_base <= hwdata;
                    end
                    ADDR_LENGTH: begin
                        length <= hwdata[15:0];
                    end
                    ADDR_SCALE_SHIFT: begin
                        scale_shift <= hwdata[4:0];
                    end
                    ADDR_IRQ_STATUS: begin
                        if (hwdata[0])
                            irq_status_r <= 1'b0;
                    end
                    ADDR_SRC0_STRIDE: begin
                        src0_stride <= hwdata;
                    end
                    ADDR_SRC1_STRIDE: begin
                        src1_stride <= hwdata;
                    end
                    ADDR_DST_STRIDE: begin
                        dst_stride <= hwdata;
                    end
                    ADDR_CONFIG: begin
                        signed_mode <= hwdata[0];
                        saturate_en <= hwdata[1];
                        round_en    <= hwdata[2];
                        data_width  <= hwdata[5:4];
                    end
                    ADDR_IRQ_ENABLE: begin
                        irq_enable_r <= hwdata[0];
                        irq_en       <= hwdata[0];
                    end
                    ADDR_IRQ_MASK: begin
                        irq_mask_r <= hwdata[0];
                    end
                    ADDR_IRQ_CLEAR: begin
                        if (hwdata[0])
                            irq_status_r <= 1'b0;
                    end
                    ADDR_NEURON_COUNT: begin
                        neuron_count <= hwdata[15:0];
                    end
                    ADDR_NEURON_STRIDE: begin
                        neuron_stride <= hwdata;
                    end
                    ADDR_NEURON_INDEX: begin
                        neuron_index <= hwdata[15:0];
                    end
                    default: begin
                    end
                endcase
            end

            if (addr_phase_valid && hwrite && addr_error) begin
                error_r <= 1'b1;
                if (busy_cfg_write)
                    error_code_r <= ERR_BUSY_WRITE;
                else if (known_addr && !writable_addr)
                    error_code_r <= ERR_READONLY_WR;
                else
                    error_code_r <= ERR_REG_ACCESS;
            end

            write_phase_r <= addr_phase_valid && hwrite;
            write_error_r <= addr_error;
            write_addr_r  <= haddr[7:0];
            if (addr_phase_valid && !hwrite)
                read_addr_r <= haddr[7:0];
        end
    end

endmodule
