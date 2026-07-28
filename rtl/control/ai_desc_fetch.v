`timescale 1ns / 1ps

// ============================================================================
// ai_desc_fetch
// ----------------------------------------------------------------------------
// 从 scratchpad SRAM 中读取一条 64-byte descriptor。
//
// descriptor 是软件提交给硬件的一条“任务描述”，主要字段包括：
//   word0[7:0]    op
//   word0[31:16]  task_id
//   word1         src0_base
//   word2         src1_base
//   word4         dst_base
//   word5[15:0]   m_size
//   word5[31:16]  n_size
//   word6[15:0]   k_words / length
//   word7[7:0]    flags (bias/transpose/precision/fence)
//   word8         aux0 (epsilon/SFU configuration)
//   word9[4:0]    scale_shift
//   word9[6:5]    activation
//   word10~12     src0/src1/dst batch strides
//   word13        batch_count, head_count
//   word14        dependency wait/signal masks
//   word15        descriptor version and event clear mask
//
// 该模块只负责“取出并解析 descriptor 字段”，字段合法性检查和 core_start
// 由 ai_accel_regs 完成。
// ============================================================================
module ai_desc_fetch(
    input  wire        clk,
    input  wire        resetn,
    input  wire        start,
    input  wire [31:0] desc_base,
    input  wire        spad_ready,
    input  wire        spad_rsp_valid,
    input  wire [31:0] spad_rdata,
    input  wire        spad_error,
    output reg         spad_valid,
    output reg  [31:0] spad_addr,
    output reg         busy,
    output reg         done,
    output reg         error,
    output reg  [7:0]  desc_op,
    output reg  [15:0] desc_task_id,
    output reg  [31:0] desc_src0_base,
    output reg  [31:0] desc_src1_base,
    output reg  [31:0] desc_dst_base,
    output reg  [15:0] desc_length,
    output reg  [15:0] desc_m_size,
    output reg  [15:0] desc_n_size,
    output reg  [15:0] desc_k_words,
    output reg  [4:0]  desc_scale_shift,
    output reg  [1:0]  desc_activation,
    output reg  [31:0] desc_bias_base,
    output reg         desc_bias_enable,
    output reg  [7:0]  desc_flags,
    output reg  [31:0] desc_aux0,
    output reg  [31:0] desc_src0_stride,
    output reg  [31:0] desc_src1_stride,
    output reg  [31:0] desc_dst_stride,
    output reg  [15:0] desc_batch_count,
    output reg  [15:0] desc_head_count,
    output reg  [15:0] desc_wait_mask,
    output reg  [15:0] desc_signal_mask,
    output reg  [15:0] desc_clear_mask,
    output reg  [7:0]  desc_version
);

    localparam ST_IDLE = 3'd0;
    localparam ST_READ_REQ = 3'd1;
    localparam ST_READ_WAIT = 3'd2;
    localparam ST_DONE = 3'd3;

    reg [2:0] state_r;
    reg [4:0] word_idx_r;

    // 每拍读取 descriptor 中的一个 32-bit word。
    // word_idx_r 从 0 到 15，共 16 个 word = 64 byte。
    always @(*) begin
        spad_valid = (state_r == ST_READ_REQ);
        spad_addr  = desc_base + ({27'd0, word_idx_r} << 2);
    end

    // 简单三态 FSM：IDLE 等待 start，READ 顺序取 16 个 word，DONE 给上层一拍 done。
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state_r           <= ST_IDLE;
            word_idx_r        <= 5'd0;
            busy              <= 1'b0;
            done              <= 1'b0;
            error             <= 1'b0;
            desc_op           <= 8'd0;
            desc_task_id      <= 16'd0;
            desc_src0_base    <= 32'd0;
            desc_src1_base    <= 32'd0;
            desc_dst_base     <= 32'd0;
            desc_length       <= 16'd0;
            desc_m_size       <= 16'd0;
            desc_n_size       <= 16'd0;
            desc_k_words      <= 16'd0;
            desc_scale_shift  <= 5'd0;
            desc_activation   <= 2'd0;
            desc_bias_base    <= 32'd0;
            desc_bias_enable  <= 1'b0;
            desc_flags        <= 8'd0;
            desc_aux0         <= 32'd0;
            desc_src0_stride  <= 32'd0;
            desc_src1_stride  <= 32'd0;
            desc_dst_stride   <= 32'd0;
            desc_batch_count  <= 16'd0;
            desc_head_count   <= 16'd0;
            desc_wait_mask    <= 16'd0;
            desc_signal_mask  <= 16'd0;
            desc_clear_mask   <= 16'd0;
            desc_version      <= 8'd0;
        end else begin
            done <= 1'b0;

            case (state_r)
                ST_IDLE: begin
                    busy  <= 1'b0;
                    error <= 1'b0;
                    if (start) begin
                        busy       <= 1'b1;
                        word_idx_r <= 5'd0;
                        state_r    <= ST_READ_REQ;
                    end
                end
                ST_READ_REQ: if (spad_ready) begin
                    state_r <= ST_READ_WAIT;
                end
                ST_READ_WAIT: if (spad_rsp_valid) begin
                    // scratchpad 返回错误/parity error 时停止解析，并把 error 交给 regs 处理。
                    if (spad_error) begin
                        error   <= 1'b1;
                        state_r <= ST_DONE;
                    end else begin
                        // 只解析当前硬件需要的字段，保留 word3/word7 等字段供后续扩展。
                        case (word_idx_r)
                            5'd0: begin
                                desc_op      <= spad_rdata[7:0];
                                desc_task_id <= spad_rdata[31:16];
                            end
                            5'd1: desc_src0_base <= spad_rdata;
                            5'd2: desc_src1_base <= spad_rdata;
                            5'd3: desc_bias_base <= spad_rdata;
                            5'd4: desc_dst_base <= spad_rdata;
                            5'd5: begin
                                desc_m_size <= spad_rdata[15:0];
                                desc_n_size <= spad_rdata[31:16];
                            end
                            5'd6: begin
                                desc_k_words <= spad_rdata[15:0];
                                desc_length  <= spad_rdata[15:0];
                            end
                            5'd7: begin
                                desc_bias_enable <= spad_rdata[0];
                                desc_flags <= spad_rdata[7:0];
                            end
                            5'd8: desc_aux0 <= spad_rdata;
                            5'd9: begin
                                desc_scale_shift <= spad_rdata[4:0];
                                desc_activation  <= spad_rdata[6:5];
                            end
                            5'd10: desc_src0_stride <= spad_rdata;
                            5'd11: desc_src1_stride <= spad_rdata;
                            5'd12: desc_dst_stride <= spad_rdata;
                            5'd13: begin
                                desc_batch_count <= spad_rdata[15:0];
                                desc_head_count <= spad_rdata[31:16];
                            end
                            5'd14: begin
                                desc_wait_mask <= spad_rdata[15:0];
                                desc_signal_mask <= spad_rdata[31:16];
                            end
                            5'd15: begin
                                desc_version <= spad_rdata[7:0];
                                desc_clear_mask <= spad_rdata[31:16];
                            end
                            default: begin
                            end
                        endcase

                        if (word_idx_r == 5'd15) begin
                            state_r <= ST_DONE;
                        end else begin
                            word_idx_r <= word_idx_r + 5'd1;
                            state_r <= ST_READ_REQ;
                        end
                    end
                end
                ST_DONE: begin
                    busy    <= 1'b0;
                    done    <= 1'b1;
                    state_r <= ST_IDLE;
                end
                default: begin
                    state_r <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
