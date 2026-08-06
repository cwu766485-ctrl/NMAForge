`timescale 1ns / 1ps

// Four-bank near-memory INT8 engine.  The scratchpad exposes one synchronous
// banked read port, therefore each dot product fetches A and B in two separate
// request/response cycles: A_REQ -> A_WAIT -> B_REQ -> B_WAIT.
module ai_banked_compute_core(
    input wire clk, input wire resetn, input wire start, input wire abort,
    input wire [7:0] op_mode,
    input wire [31:0] src0_base, input wire [31:0] src1_base,
    input wire [31:0] dst_base, input wire [15:0] length,
    input wire [15:0] m_size, input wire [4:0] scale_shift,
    input wire [1:0] activation,
    input wire [31:0] watchdog_limit,
    input wire [31:0] bank0_data, input wire [31:0] bank1_data,
    input wire [31:0] bank2_data, input wire [31:0] bank3_data,
    input wire [3:0] bank_parity_error,
    output reg banked_read_valid, output reg [31:0] banked_addr,
    input wire banked_ready, input wire banked_rsp_valid,
    input wire banked_protection_error,
    output reg spad_valid, output reg spad_write, output reg [31:0] spad_addr,
    output reg [31:0] spad_wdata, input wire spad_ready,
    input wire spad_protection_error,
    output reg busy, output reg done, output reg error,
    output reg [3:0] error_code, output reg [31:0] result,
    output reg [31:0] cycle_count, output reg [31:0] element_count,
    // A1 CNM observability.  A local accumulation event represents one
    // bank PE contribution; a global reduction event represents the single
    // output-level merge of four bank-local accumulators.
    output reg [31:0] local_accumulate_events,
    output reg [31:0] global_reduce_events,
    // A2 observability.  These remain internal until a future ABI revision
    // exposes them through ai_perf_monitor/registers.
    output reg [31:0] banked_read_issue_events,
    output reg [31:0] prefetch_events,
    output reg [31:0] pipeline_compute_events,
    output reg [31:0] response_wait_cycles
);
    localparam [7:0] OP_BANKED_VDOT = 8'h20;
    localparam [7:0] OP_BANKED_GEMV = 8'h21;
    localparam [3:0] ERR_CONFIG = 4'd1, ERR_OP = 4'd2, ERR_ABORT = 4'd3,
                     ERR_WATCHDOG = 4'd4, ERR_PARITY = 4'd5, ERR_PROTECTION = 4'd6;
    // A2 pipeline states.  A and B requests are issued back-to-back; while
    // B returns and is consumed, the next K group's A read is prefetched.
    localparam [3:0] ST_IDLE=0, ST_A_REQ=1, ST_B_REQ=2, ST_WAIT_A=3,
                     ST_WAIT_B=4, ST_WRITE=5, ST_NEXT=6, ST_DONE=7, ST_ERROR=8;
    reg [3:0] state_r;
    reg [7:0] op_r;
    reg [31:0] src0_r, src1_r, dst_r;
    reg [31:0] a_row_base_r, b_row_base_r, output_addr_r;
    reg [31:0] watchdog_limit_r;
    reg [4:0] scale_shift_r;
    reg [1:0] activation_r;
    reg [15:0] length_r, m_r, row_r, k_r;
    // Ping-pong A operand buffers.  The current K group's data are consumed
    // from one buffer while the other is available for the next prefetched
    // group.  The four lanes remain bank-local and lockstep for the existing
    // striped VDOT/GEMV layout.
    reg [31:0] a0_buf0_r, a1_buf0_r, a2_buf0_r, a3_buf0_r;
    reg [31:0] a0_buf1_r, a1_buf1_r, a2_buf1_r, a3_buf1_r;
    // A1 bank-local accumulators.  Each PE contributes to its own local
    // accumulator for every K group.  The four values cross into the shared
    // reduction path only when an output is complete.
    reg signed [63:0] local_acc0_r, local_acc1_r;
    reg signed [63:0] local_acc2_r, local_acc3_r;
    wire [31:0] a0_compute = k_r[0] ? a0_buf1_r : a0_buf0_r;
    wire [31:0] a1_compute = k_r[0] ? a1_buf1_r : a1_buf0_r;
    wire [31:0] a2_compute = k_r[0] ? a2_buf1_r : a2_buf0_r;
    wire [31:0] a3_compute = k_r[0] ? a3_buf1_r : a3_buf0_r;
    wire signed [31:0] p0, p1, p2, p3;
    wire signed [63:0] local_acc0_next = local_acc0_r + {{32{p0[31]}},p0};
    wire signed [63:0] local_acc1_next = local_acc1_r + {{32{p1[31]}},p1};
    wire signed [63:0] local_acc2_next = local_acc2_r + {{32{p2[31]}},p2};
    wire signed [63:0] local_acc3_next = local_acc3_r + {{32{p3[31]}},p3};
    // This is intentionally used only at the output boundary in ST_B_WAIT.
    // It replaces the former per-K-group global reduction tree.
    wire signed [63:0] global_sum_next = local_acc0_next + local_acc1_next +
                                         local_acc2_next + local_acc3_next;
    wire signed [63:0] shifted_sum = global_sum_next >>> scale_shift_r;
    wire signed [63:0] activated_sum = (activation_r == 2'd1 && shifted_sum < 0) ? 64'sd0 : shifted_sum;
    wire [31:0] quantized_result = (activated_sum > 64'sh0000_0000_7fff_ffff) ? 32'h7fff_ffff :
                                    (activated_sum < -64'sd2147483648) ? 32'h8000_0000 : activated_sum[31:0];
    wire last_k = (k_r == length_r - 16'd1);
    wire last_row = (op_r == OP_BANKED_VDOT) || (row_r == m_r - 16'd1);
    wire [31:0] vector_bytes = {12'd0, length_r, 4'b0000};

    ai_bank_pe pe0(.act_word(a0_compute), .weight_word(bank0_data), .partial_sum(p0));
    ai_bank_pe pe1(.act_word(a1_compute), .weight_word(bank1_data), .partial_sum(p1));
    ai_bank_pe pe2(.act_word(a2_compute), .weight_word(bank2_data), .partial_sum(p2));
    ai_bank_pe pe3(.act_word(a3_compute), .weight_word(bank3_data), .partial_sum(p3));
    always @(*) begin
        // In ST_WAIT_B the returning data are B for the current group.  The
        // next A request is presented at the same compute boundary.
        banked_read_valid = (state_r == ST_A_REQ) || (state_r == ST_B_REQ) ||
                            ((state_r == ST_WAIT_B) &&
                             banked_rsp_valid && !last_k);
        if (state_r == ST_B_REQ)
            banked_addr = b_row_base_r + ({16'd0, k_r} << 4);
        else if (state_r == ST_WAIT_B)
            banked_addr = a_row_base_r + ({16'd0, k_r + 1'b1} << 4);
        else
            banked_addr = a_row_base_r + ({16'd0, k_r} << 4);
        spad_valid = (state_r == ST_WRITE);
        spad_write = (state_r == ST_WRITE);
        spad_addr = output_addr_r;
        spad_wdata = result;
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state_r<=ST_IDLE; busy<=0; done<=0; error<=0; error_code<=0; result<=0;
            cycle_count<=0; element_count<=0; op_r<=0; src0_r<=0; src1_r<=0; dst_r<=0;
            a_row_base_r<=0; b_row_base_r<=0; output_addr_r<=0; watchdog_limit_r<=0;
            length_r<=0; m_r<=0; row_r<=0; k_r<=0;
            local_acc0_r<=0; local_acc1_r<=0; local_acc2_r<=0; local_acc3_r<=0;
            local_accumulate_events<=0; global_reduce_events<=0;
            scale_shift_r<=0; activation_r<=0;
            a0_buf0_r<=0; a1_buf0_r<=0; a2_buf0_r<=0; a3_buf0_r<=0;
            a0_buf1_r<=0; a1_buf1_r<=0; a2_buf1_r<=0; a3_buf1_r<=0;
            banked_read_issue_events<=0; prefetch_events<=0;
            pipeline_compute_events<=0; response_wait_cycles<=0;
        end else begin
            done <= 1'b0;
            if (busy) cycle_count <= cycle_count + 1'b1;
            if (busy && (state_r==ST_WAIT_A || state_r==ST_WAIT_B) && !banked_rsp_valid)
                response_wait_cycles <= response_wait_cycles + 1'b1;
            if (busy && abort) begin
                error_code <= ERR_ABORT;
                state_r <= ST_ERROR;
            end else if (busy && (watchdog_limit_r != 0) &&
                         (cycle_count >= watchdog_limit_r)) begin
                error_code <= ERR_WATCHDOG;
                state_r <= ST_ERROR;
            end else case (state_r)
                ST_IDLE: if (start) begin
                    op_r<=op_mode; src0_r<=src0_base; src1_r<=src1_base; dst_r<=dst_base;
                    a_row_base_r<=src0_base; b_row_base_r<=src1_base; output_addr_r<=dst_base;
                    watchdog_limit_r<=watchdog_limit;
                    length_r<=length; m_r<=m_size; scale_shift_r<=scale_shift; activation_r<=activation; row_r<=0; k_r<=0;
                    local_acc0_r<=0; local_acc1_r<=0; local_acc2_r<=0; local_acc3_r<=0;
                    cycle_count<=0; element_count<=0; local_accumulate_events<=0; global_reduce_events<=0;
                    banked_read_issue_events<=0; prefetch_events<=0; pipeline_compute_events<=0; response_wait_cycles<=0;
                    busy<=1; error<=0; error_code<=0;
                    if ((op_mode!=OP_BANKED_VDOT && op_mode!=OP_BANKED_GEMV)) begin error_code<=ERR_OP; state_r<=ST_ERROR; end
                    else if (length==0 || (op_mode==OP_BANKED_GEMV && m_size==0) ||
                             (src0_base[3:0]!=0) || (src1_base[3:0]!=0) || (dst_base[1:0]!=0)) begin error_code<=ERR_CONFIG; state_r<=ST_ERROR; end
                    else state_r<=ST_A_REQ;
                end
                ST_A_REQ: if (banked_ready) begin
                    if (banked_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                    else begin
                        banked_read_issue_events <= banked_read_issue_events + 1'b1;
                        state_r <= ST_B_REQ;
                    end
                end
                ST_B_REQ: if (banked_ready) begin
                    if (banked_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                    else begin
                        banked_read_issue_events <= banked_read_issue_events + 1'b1;
                        // The A response can coincide with B admission.
                        if (banked_rsp_valid) begin
                            if (|bank_parity_error) begin error_code<=ERR_PARITY; state_r<=ST_ERROR; end
                            else begin
                                if (k_r[0]) begin a0_buf1_r<=bank0_data; a1_buf1_r<=bank1_data; a2_buf1_r<=bank2_data; a3_buf1_r<=bank3_data; end
                                else begin a0_buf0_r<=bank0_data; a1_buf0_r<=bank1_data; a2_buf0_r<=bank2_data; a3_buf0_r<=bank3_data; end
                                state_r<=ST_WAIT_B;
                            end
                        end else state_r <= ST_WAIT_A;
                    end
                end
                ST_WAIT_A: if (banked_rsp_valid) begin
                    if (|bank_parity_error) begin error_code<=ERR_PARITY; state_r<=ST_ERROR; end
                    else begin
                        // A is always the first response of a back-to-back
                        // request pair. Save it before B arrives.
                        if (k_r[0]) begin a0_buf1_r<=bank0_data; a1_buf1_r<=bank1_data; a2_buf1_r<=bank2_data; a3_buf1_r<=bank3_data; end
                        else begin a0_buf0_r<=bank0_data; a1_buf0_r<=bank1_data; a2_buf0_r<=bank2_data; a3_buf0_r<=bank3_data; end
                        state_r<=ST_WAIT_B;
                    end
                end
                ST_WAIT_B: if (banked_rsp_valid) begin
                    if (|bank_parity_error) begin error_code<=ERR_PARITY; state_r<=ST_ERROR; end
                    else begin
                        // B response: consume the current A buffer and B
                        // data, then prefetch the next A if this is not the
                        // final group.
                        local_accumulate_events <= local_accumulate_events + 32'd4;
                        pipeline_compute_events <= pipeline_compute_events + 1'b1;
                        if (last_k) begin
                            result<=quantized_result;
                            global_reduce_events <= global_reduce_events + 1'b1;
                            state_r<=ST_WRITE;
                        end else if (banked_ready) begin
                            if (banked_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                            else begin
                                banked_read_issue_events <= banked_read_issue_events + 1'b1;
                                prefetch_events <= prefetch_events + 1'b1;
                                local_acc0_r<=local_acc0_next; local_acc1_r<=local_acc1_next;
                                local_acc2_r<=local_acc2_next; local_acc3_r<=local_acc3_next;
                                k_r<=k_r+1'b1; state_r<=ST_B_REQ;
                            end
                        end else begin
                            local_acc0_r<=local_acc0_next; local_acc1_r<=local_acc1_next;
                            local_acc2_r<=local_acc2_next; local_acc3_r<=local_acc3_next;
                            k_r<=k_r+1'b1; state_r<=ST_A_REQ;
                        end
                    end
                end
                ST_WRITE: if (spad_ready) begin
                    if (spad_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end
                    else begin element_count<=element_count+1'b1; state_r<=ST_NEXT; end
                end
                ST_NEXT: if (last_row) state_r<=ST_DONE; else begin
                    row_r<=row_r+1'b1; k_r<=0;
                    local_acc0_r<=0; local_acc1_r<=0; local_acc2_r<=0; local_acc3_r<=0;
                    b_row_base_r<=b_row_base_r+vector_bytes;
                    output_addr_r<=output_addr_r+32'd4;
                    state_r<=ST_A_REQ;
                end
                ST_DONE: begin busy<=0; done<=1; error<=0; state_r<=ST_IDLE; end
                ST_ERROR: begin busy<=0; done<=1; error<=1; state_r<=ST_IDLE; end
                default: state_r<=ST_IDLE;
            endcase
        end
    end
endmodule
