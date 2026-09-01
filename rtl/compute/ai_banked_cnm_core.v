`timescale 1ns / 1ps

// CNM A2.2 execution wrapper.  Unlike the legacy banked core, the four
// physical SRAM banks are driven by four ai_bank_local_controller instances.
// They have separate address generators, request signals, response data and
// local accumulators.  The only shared arithmetic point is the final
// output-level reduction.
module ai_banked_cnm_core(
    input wire clk, input wire resetn, input wire start, input wire abort,
    input wire [7:0] op_mode,
    input wire [31:0] src0_base, input wire [31:0] src1_base,
    input wire [31:0] dst_base, input wire [15:0] length,
    input wire [15:0] m_size, input wire [4:0] scale_shift,
    input wire [1:0] activation, input wire [31:0] watchdog_limit,
    output wire [3:0] cnm_req_valid,
    output wire [31:0] cnm_addr0, output wire [31:0] cnm_addr1,
    output wire [31:0] cnm_addr2, output wire [31:0] cnm_addr3,
    input wire [3:0] cnm_req_ready, input wire [3:0] cnm_rsp_valid,
    input wire [31:0] cnm_data0, input wire [31:0] cnm_data1,
    input wire [31:0] cnm_data2, input wire [31:0] cnm_data3,
    input wire [3:0] cnm_parity_error, input wire cnm_protection_error,
    output reg spad_valid, output reg spad_write, output reg [31:0] spad_addr,
    output reg [31:0] spad_wdata, input wire spad_ready,
    input wire spad_protection_error,
    output reg busy, output reg done, output reg error,
    output reg [3:0] error_code, output reg [31:0] result,
    output reg [31:0] cycle_count, output reg [31:0] element_count,
    output reg [31:0] local_accumulate_events,
    output reg [31:0] global_reduce_events,
    output reg [31:0] banked_read_issue_events,
    output reg [31:0] prefetch_events,
    output reg [31:0] pipeline_compute_events,
    output reg [31:0] response_wait_cycles
);
    // Command encodings are shared with the command processor ABI.
    localparam [7:0] OP_BANKED_VDOT = 8'h20;
    localparam [7:0] OP_BANKED_GEMV = 8'h21;

    localparam [3:0] ERR_CONFIG     = 4'd1;
    localparam [3:0] ERR_OP         = 4'd2;
    localparam [3:0] ERR_ABORT      = 4'd3;
    localparam [3:0] ERR_WATCHDOG   = 4'd4;
    localparam [3:0] ERR_PARITY     = 4'd5;
    localparam [3:0] ERR_PROTECTION = 4'd6;

    localparam [2:0] ST_IDLE       = 3'd0;
    localparam [2:0] ST_LAUNCH     = 3'd1;
    localparam [2:0] ST_WAIT_LOCAL = 3'd2;
    localparam [2:0] ST_WRITE      = 3'd3;
    localparam [2:0] ST_NEXT       = 3'd4;
    localparam [2:0] ST_DONE       = 3'd5;
    localparam [2:0] ST_ERROR      = 3'd6;

    localparam [1:0] ACT_RELU = 2'd1;
    reg [2:0] state_r;
    reg [7:0] op_r;
    reg [31:0] src0_r, src1_r, dst_r, b_row_base_r, output_addr_r;
    reg [15:0] length_r, m_r, row_r;
    reg [4:0] scale_shift_r;
    reg [1:0] activation_r;
    reg [31:0] watchdog_limit_r;
    wire local_start = (state_r == ST_LAUNCH);
    wire [3:0] local_busy, local_done, local_error;
    wire signed [63:0] sum0, sum1, sum2, sum3;
    wire signed [63:0] global_sum = sum0 + sum1 + sum2 + sum3;
    wire signed [63:0] shifted_sum = global_sum >>> scale_shift_r;
    wire signed [63:0] activated_sum =
        (activation_r == ACT_RELU && shifted_sum < 0) ? 64'sd0 : shifted_sum;
    wire [31:0] quantized_result = (activated_sum > 64'sh0000_0000_7fff_ffff) ? 32'h7fff_ffff :
                                    (activated_sum < -64'sd2147483648) ? 32'h8000_0000 : activated_sum[31:0];
    wire locals_complete = &local_done;
    wire any_local_error = |local_error;
    wire valid_operation = (op_mode == OP_BANKED_VDOT) || (op_mode == OP_BANKED_GEMV);
    wire invalid_alignment = (src0_base[3:0] != 0) || (src1_base[3:0] != 0) ||
                             (dst_base[1:0] != 0);
    wire invalid_dimensions = (length == 0) ||
                              ((op_mode == OP_BANKED_GEMV) && (m_size == 0));
    wire last_row = (op_r == OP_BANKED_VDOT) || (row_r == m_r - 1'b1);
    wire [31:0] vector_bytes = {12'd0,length_r,4'b0000};
    wire [31:0] l0_reads,l1_reads,l2_reads,l3_reads;
    wire [31:0] l0_prefetch,l1_prefetch,l2_prefetch,l3_prefetch;
    wire [31:0] l0_compute,l1_compute,l2_compute,l3_compute;
    wire [31:0] l0_wait,l1_wait,l2_wait,l3_wait;

    // Four independent controllers intentionally retain four independent
    // request/response channels; no central broadcast datapath is inserted.
    ai_bank_local_controller #(.LANE_ID(2'd0)) lc0(
        .clk(clk), .resetn(resetn), .start(local_start), .abort(abort),
        .src0_base(src0_r), .src1_base(b_row_base_r), .length(length_r),
        .req_valid(cnm_req_valid[0]), .req_addr(cnm_addr0), .req_ready(cnm_req_ready[0]),
        .rsp_valid(cnm_rsp_valid[0]), .rsp_data(cnm_data0),
        .rsp_parity_error(cnm_parity_error[0] | cnm_protection_error),
        .busy(local_busy[0]), .done(local_done[0]), .error(local_error[0]),
        .local_sum(sum0), .read_issue_events(l0_reads), .prefetch_events(l0_prefetch),
        .compute_events(l0_compute), .response_wait_cycles(l0_wait)
    );
    ai_bank_local_controller #(.LANE_ID(2'd1)) lc1(
        .clk(clk), .resetn(resetn), .start(local_start), .abort(abort),
        .src0_base(src0_r), .src1_base(b_row_base_r), .length(length_r),
        .req_valid(cnm_req_valid[1]), .req_addr(cnm_addr1), .req_ready(cnm_req_ready[1]),
        .rsp_valid(cnm_rsp_valid[1]), .rsp_data(cnm_data1),
        .rsp_parity_error(cnm_parity_error[1] | cnm_protection_error),
        .busy(local_busy[1]), .done(local_done[1]), .error(local_error[1]),
        .local_sum(sum1), .read_issue_events(l1_reads), .prefetch_events(l1_prefetch),
        .compute_events(l1_compute), .response_wait_cycles(l1_wait)
    );
    ai_bank_local_controller #(.LANE_ID(2'd2)) lc2(
        .clk(clk), .resetn(resetn), .start(local_start), .abort(abort),
        .src0_base(src0_r), .src1_base(b_row_base_r), .length(length_r),
        .req_valid(cnm_req_valid[2]), .req_addr(cnm_addr2), .req_ready(cnm_req_ready[2]),
        .rsp_valid(cnm_rsp_valid[2]), .rsp_data(cnm_data2),
        .rsp_parity_error(cnm_parity_error[2] | cnm_protection_error),
        .busy(local_busy[2]), .done(local_done[2]), .error(local_error[2]),
        .local_sum(sum2), .read_issue_events(l2_reads), .prefetch_events(l2_prefetch),
        .compute_events(l2_compute), .response_wait_cycles(l2_wait)
    );
    ai_bank_local_controller #(.LANE_ID(2'd3)) lc3(
        .clk(clk), .resetn(resetn), .start(local_start), .abort(abort),
        .src0_base(src0_r), .src1_base(b_row_base_r), .length(length_r),
        .req_valid(cnm_req_valid[3]), .req_addr(cnm_addr3), .req_ready(cnm_req_ready[3]),
        .rsp_valid(cnm_rsp_valid[3]), .rsp_data(cnm_data3),
        .rsp_parity_error(cnm_parity_error[3] | cnm_protection_error),
        .busy(local_busy[3]), .done(local_done[3]), .error(local_error[3]),
        .local_sum(sum3), .read_issue_events(l3_reads), .prefetch_events(l3_prefetch),
        .compute_events(l3_compute), .response_wait_cycles(l3_wait)
    );

    always @(*) begin
        spad_valid = state_r==ST_WRITE;
        spad_write = state_r==ST_WRITE;
        spad_addr = output_addr_r;
        spad_wdata = result;
    end
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state_r<=ST_IDLE; busy<=0; done<=0; error<=0; error_code<=0; result<=0;
            cycle_count<=0; element_count<=0; op_r<=0; src0_r<=0; src1_r<=0; dst_r<=0;
            b_row_base_r<=0; output_addr_r<=0; length_r<=0; m_r<=0; row_r<=0;
            scale_shift_r<=0; activation_r<=0; watchdog_limit_r<=0;
            local_accumulate_events<=0; global_reduce_events<=0; banked_read_issue_events<=0;
            prefetch_events<=0; pipeline_compute_events<=0; response_wait_cycles<=0;
        end else begin
            done<=0;
            if (busy)
                cycle_count<=cycle_count+1'b1;
            if (busy && abort) begin error_code<=ERR_ABORT; state_r<=ST_ERROR; end
            else if (busy && watchdog_limit_r!=0 && cycle_count>=watchdog_limit_r) begin error_code<=ERR_WATCHDOG; state_r<=ST_ERROR; end
            else case (state_r)
                ST_IDLE: if (start) begin
                    op_r<=op_mode; src0_r<=src0_base; src1_r<=src1_base; dst_r<=dst_base;
                    b_row_base_r<=src1_base; output_addr_r<=dst_base; length_r<=length; m_r<=m_size; row_r<=0;
                    scale_shift_r<=scale_shift; activation_r<=activation; watchdog_limit_r<=watchdog_limit;
                    cycle_count<=0; element_count<=0; local_accumulate_events<=0; global_reduce_events<=0;
                    banked_read_issue_events<=0; prefetch_events<=0; pipeline_compute_events<=0; response_wait_cycles<=0;
                    busy<=1; error<=0; error_code<=0;
                    if (!valid_operation) begin error_code<=ERR_OP; state_r<=ST_ERROR; end
                    else if (invalid_dimensions || invalid_alignment) begin error_code<=ERR_CONFIG; state_r<=ST_ERROR; end
                    else state_r<=ST_LAUNCH;
                end
                ST_LAUNCH: state_r<=ST_WAIT_LOCAL;
                ST_WAIT_LOCAL: if (any_local_error) begin error_code<=cnm_protection_error ? ERR_PROTECTION : ERR_PARITY; state_r<=ST_ERROR; end
                               else if (locals_complete) begin
                                   // Local-controller counters restart for each
                                   // GEMV output row.  Retire their completed
                                   // values here so the exported counters
                                   // describe the full command, not only the
                                   // final row.
                                   local_accumulate_events<=local_accumulate_events+l0_compute+l1_compute+l2_compute+l3_compute;
                                   banked_read_issue_events<=banked_read_issue_events+l0_reads+l1_reads+l2_reads+l3_reads;
                                   prefetch_events<=prefetch_events+l0_prefetch+l1_prefetch+l2_prefetch+l3_prefetch;
                                   pipeline_compute_events<=pipeline_compute_events+l0_compute+l1_compute+l2_compute+l3_compute;
                                   response_wait_cycles<=response_wait_cycles+l0_wait+l1_wait+l2_wait+l3_wait;
                                   result<=quantized_result; global_reduce_events<=global_reduce_events+1'b1; state_r<=ST_WRITE;
                               end
                ST_WRITE: if (spad_ready) begin if (spad_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end else begin element_count<=element_count+1'b1; state_r<=ST_NEXT; end end
                ST_NEXT: if (last_row) state_r<=ST_DONE; else begin row_r<=row_r+1'b1; b_row_base_r<=b_row_base_r+vector_bytes; output_addr_r<=output_addr_r+32'd4; state_r<=ST_LAUNCH; end
                ST_DONE: begin busy<=0; done<=1; error<=0; state_r<=ST_IDLE; end
                ST_ERROR: begin busy<=0; done<=1; error<=1; state_r<=ST_IDLE; end
                default: state_r<=ST_IDLE;
            endcase
        end
    end
endmodule
