`timescale 1ns / 1ps

// Completion queue writer protocol:
// - captures one immutable 16-byte record at `start`;
// - waits for all four scratchpad write handshakes;
// - asserts `done` only after the final word is accepted.
// The command processor relies on this contract before advancing CPLQ_TAIL.

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

    localparam [1:0] ST_IDLE  = 2'd0;
    localparam [1:0] ST_WRITE = 2'd1;
    localparam [1:0] ST_DONE  = 2'd2;
    localparam [1:0] LAST_COMPLETION_WORD = 2'd3;

    reg [1:0] state_r;
    reg [1:0] word_idx_r;
    reg [31:0] base_addr_r;
    reg [15:0] task_id_r;
    reg [3:0] status_r;
    reg [3:0] error_code_r;
    reg [31:0] result_r;
    reg [31:0] element_count_r;

    // This client only issues writes, so request valid also defines write
    // intent for the scratchpad arbiter.
    assign spad_write = spad_valid;

    // Select the current completion-entry word.
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

    // FSM:
    //   IDLE  : capture one immutable completion record.
    //   WRITE : wait for four scratchpad write acceptances.
    //   DONE  : return a one-cycle completion pulse to the owner.
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
                    // Each entry is 16 bytes: cplq_base + cplq_index * 16.
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
                    if (word_idx_r == LAST_COMPLETION_WORD) begin
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
