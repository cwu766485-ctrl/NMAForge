`timescale 1ns / 1ps

// One bank-local controller for the CNM A2.2 datapath.
//
// The controller owns the address sequence, ping-pong A operand buffer and
// local accumulator for exactly one physical scratchpad bank.  Its request
// interface connects only to the matching lane of the CNM scratchpad port.
// At the B-response/compute boundary it prefetches the following A word,
// which overlaps the next read with the current dot4 accumulation.
module ai_bank_local_controller #(
    parameter [1:0] LANE_ID = 2'd0
)(
    input wire clk, input wire resetn,
    input wire start, input wire abort,
    input wire [31:0] src0_base, input wire [31:0] src1_base,
    input wire [15:0] length,
    output reg req_valid, output reg [31:0] req_addr, input wire req_ready,
    input wire rsp_valid, input wire [31:0] rsp_data, input wire rsp_parity_error,
    output reg busy, output reg done, output reg error,
    output reg signed [63:0] local_sum,
    output reg [31:0] read_issue_events, output reg [31:0] prefetch_events,
    output reg [31:0] compute_events, output reg [31:0] response_wait_cycles
);
    localparam [2:0] ST_IDLE=0, ST_A_REQ=1, ST_B_REQ=2, ST_WAIT_A=3,
                     ST_WAIT_B=4, ST_DONE=5, ST_ERROR=6;
    reg [2:0] state_r;
    reg [31:0] src0_r, src1_r;
    reg [15:0] length_r, k_r;
    reg [31:0] a_buf0_r, a_buf1_r;
    wire [31:0] a_word = k_r[0] ? a_buf1_r : a_buf0_r;
    wire signed [31:0] partial_sum;
    wire signed [63:0] sum_next = local_sum + {{32{partial_sum[31]}},partial_sum};
    wire last_k = k_r == length_r-1'b1;
    wire [31:0] lane_offset = {28'd0,LANE_ID,2'b00};
    wire [31:0] a_addr = src0_r + ({16'd0,k_r} << 4) + lane_offset;
    wire [31:0] b_addr = src1_r + ({16'd0,k_r} << 4) + lane_offset;
    wire [31:0] next_a_addr = src0_r + ({16'd0,k_r+1'b1} << 4) + lane_offset;

    ai_bank_pe local_pe(.act_word(a_word), .weight_word(rsp_data), .partial_sum(partial_sum));

    always @(*) begin
        req_valid = 1'b0;
        req_addr = a_addr;
        case (state_r)
            ST_A_REQ: begin req_valid=1'b1; req_addr=a_addr; end
            ST_B_REQ: begin req_valid=1'b1; req_addr=b_addr; end
            // B response is consumed this cycle.  If more work remains,
            // issue the next A request without a dead scheduler cycle.
            ST_WAIT_B: if (rsp_valid && !last_k) begin
                req_valid=1'b1; req_addr=next_a_addr;
            end
            default: begin end
        endcase
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state_r<=ST_IDLE; src0_r<=0; src1_r<=0; length_r<=0; k_r<=0;
            a_buf0_r<=0; a_buf1_r<=0; busy<=0; done<=0; error<=0; local_sum<=0;
            read_issue_events<=0; prefetch_events<=0; compute_events<=0; response_wait_cycles<=0;
        end else begin
            done<=0;
            if (busy && (state_r==ST_WAIT_A || state_r==ST_WAIT_B) && !rsp_valid)
                response_wait_cycles<=response_wait_cycles+1'b1;
            if (busy && abort) state_r<=ST_ERROR;
            else case (state_r)
                ST_IDLE: if (start) begin
                    src0_r<=src0_base; src1_r<=src1_base; length_r<=length; k_r<=0;
                    local_sum<=0; busy<=1; error<=0;
                    read_issue_events<=0; prefetch_events<=0; compute_events<=0; response_wait_cycles<=0;
                    if (length==0) state_r<=ST_ERROR; else state_r<=ST_A_REQ;
                end
                ST_A_REQ: if (req_ready) begin
                    read_issue_events<=read_issue_events+1'b1;
                    state_r<=ST_B_REQ;
                end
                ST_B_REQ: if (req_ready) begin
                    read_issue_events<=read_issue_events+1'b1;
                    // A may return in the B issue cycle with the registered
                    // scratchpad timing model.
                    if (rsp_valid) begin
                        if (rsp_parity_error) state_r<=ST_ERROR;
                        else begin
                            if (k_r[0]) a_buf1_r<=rsp_data; else a_buf0_r<=rsp_data;
                            state_r<=ST_WAIT_B;
                        end
                    end else state_r<=ST_WAIT_A;
                end
                ST_WAIT_A: if (rsp_valid) begin
                    if (rsp_parity_error) state_r<=ST_ERROR;
                    else begin
                        if (k_r[0]) a_buf1_r<=rsp_data; else a_buf0_r<=rsp_data;
                        state_r<=ST_WAIT_B;
                    end
                end
                ST_WAIT_B: if (rsp_valid) begin
                    if (rsp_parity_error) state_r<=ST_ERROR;
                    else begin
                        local_sum<=sum_next;
                        compute_events<=compute_events+1'b1;
                        if (last_k) state_r<=ST_DONE;
                        else if (req_ready) begin
                            read_issue_events<=read_issue_events+1'b1;
                            prefetch_events<=prefetch_events+1'b1;
                            k_r<=k_r+1'b1;
                            state_r<=ST_B_REQ;
                        end
                    end
                end
                ST_DONE: begin busy<=0; done<=1; state_r<=ST_IDLE; end
                ST_ERROR: begin busy<=0; done<=1; error<=1; state_r<=ST_IDLE; end
                default: state_r<=ST_IDLE;
            endcase
        end
    end
endmodule
