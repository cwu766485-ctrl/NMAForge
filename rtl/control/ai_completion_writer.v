`timescale 1ns / 1ps

// ============================================================================
// ai_completion_writer
// ----------------------------------------------------------------------------
// 向 scratchpad 中的 completion queue 写一条完成记录。
//
// completion entry 当前为 16 byte / 4 word：
//   word0 = task_id
//   word1 = {error_code, status}
//   word2 = result
//   word3 = element_count
//
// ai_accel_regs 在 core_done 或 descriptor error 后启动本模块，并在 cpl_done 后
// 推进 CPLQ_TAIL。当前 completion queue 位于 scratchpad，不直接写 DDR。
// ============================================================================
module ai_completion_writer(
    input  wire        clk,
    input  wire        resetn,
    input  wire        start,
    input  wire [31:0] cplq_base,
    input  wire [31:0] cplq_index,
    input  wire [15:0] task_id,
    input  wire [3:0]  status,
    input  wire [3:0]  error_code,
    input  wire [31:0] result,
    input  wire [31:0] element_count,

    output reg         spad_valid,
    output wire        spad_write,
    output reg  [31:0] spad_addr,
    output reg  [31:0] spad_wdata,
    input  wire        spad_ready,
    output reg         busy,
    output reg         done
);

    localparam ST_IDLE  = 2'd0;
    localparam ST_WRITE = 2'd1;
    localparam ST_DONE  = 2'd2;

    reg [1:0] state_r;
    reg [1:0] word_idx_r;
    reg [31:0] base_addr_r;
    reg [15:0] task_id_r;
    reg [3:0] status_r;
    reg [3:0] error_code_r;
    reg [31:0] result_r;
    reg [31:0] element_count_r;

    // completion writer 只写 scratchpad，因此 spad_write 与 spad_valid 同步拉高。
    assign spad_write = spad_valid;

    // 根据 word_idx 选择当前要写入 completion entry 的哪个 word。
    always @(*) begin
        spad_valid = (state_r == ST_WRITE);
        spad_addr  = base_addr_r + ({30'd0, word_idx_r} << 2);
        case (word_idx_r)
            2'd0: spad_wdata = {16'd0, task_id_r};
            2'd1: spad_wdata = {24'd0, error_code_r, status_r};
            2'd2: spad_wdata = result_r;
            default: spad_wdata = element_count_r;
        endcase
    end

    // FSM：
    //   IDLE  锁存 completion 字段和 base address；
    //   WRITE 连续写 4 个 word；
    //   DONE  给上层一拍完成脉冲。
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state_r         <= ST_IDLE;
            word_idx_r      <= 2'd0;
            base_addr_r     <= 32'd0;
            task_id_r       <= 16'd0;
            status_r        <= 4'd0;
            error_code_r    <= 4'd0;
            result_r        <= 32'd0;
            element_count_r <= 32'd0;
            busy            <= 1'b0;
            done            <= 1'b0;
        end else begin
            done <= 1'b0;

            case (state_r)
                ST_IDLE: begin
                    // 每条 entry 16 byte，所以地址 = cplq_base + cplq_index * 16。
                    busy <= 1'b0;
                    if (start) begin
                        base_addr_r     <= cplq_base + (cplq_index << 4);
                        task_id_r       <= task_id;
                        status_r        <= status;
                        error_code_r    <= error_code;
                        result_r        <= result;
                        element_count_r <= element_count;
                        word_idx_r      <= 2'd0;
                        busy            <= 1'b1;
                        state_r         <= ST_WRITE;
                    end
                end
                ST_WRITE: if (spad_ready) begin
                    if (word_idx_r == 2'd3) begin
                        state_r <= ST_DONE;
                    end else begin
                        word_idx_r <= word_idx_r + 2'd1;
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
