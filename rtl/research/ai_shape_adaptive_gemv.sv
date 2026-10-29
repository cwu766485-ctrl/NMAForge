`timescale 1ns / 1ps

// Isolated v2 research kernel. It keeps a 16x16 (256 multiplier) budget and
// folds the physical rows across K for small-M GEMV tiles. Operand bytes are
// presented as compile-time packed memories so this block can be characterized
// independently from the v1.0 descriptor and SPAD interfaces.
module ai_shape_adaptive_gemv #(
    parameter integer MAX_M = 16,
    parameter integer MAX_N = 16,
    parameter integer MAX_K = 128,
    parameter integer MAC_COUNT = 256
)(
    input  wire                                  clk,
    input  wire                                  resetn,
    input  wire                                  start,
    input  wire                                  abort,
    input  wire [1:0]                            mode_request,
    input  wire                                  prefetch_enable,
    input  wire [4:0]                            m_size,
    input  wire [4:0]                            n_size,
    input  wire [7:0]                            k_size,
    input  wire [MAX_M*MAX_K*8-1:0]              a_operand,
    input  wire [MAX_K*MAX_N*8-1:0]              b_operand,
    output reg                                   busy,
    output reg                                   done,
    output reg                                   error,
    output reg                                   selected_gemv,
    output reg [4:0]                             selected_k_parallel,
    output reg [31:0]                            cycle_count,
    output reg [31:0]                            useful_mac_count,
    output wire [MAX_M*MAX_N*64-1:0]             result_vector
);
    localparam [1:0] MODE_BASELINE = 2'd0;
    localparam [1:0] MODE_GEMV     = 2'd1;
    localparam [1:0] MODE_STATIC   = 2'd2;

    localparam [1:0] ST_IDLE    = 2'd0;
    localparam [1:0] ST_COMPUTE = 2'd1;
    localparam [1:0] ST_REDUCE  = 2'd2;

    reg [1:0] state_r;
    reg [4:0] m_r, n_r;
    reg [7:0] k_r, k_base_r;
    reg [4:0] k_parallel_r;
    reg gemv_r;
    reg signed [63:0] accumulator [0:MAX_M*MAX_N-1];
    reg signed [15:0] partial_product [0:MAC_COUNT-1];
    reg signed [15:0] product_comb [0:MAC_COUNT-1];
    integer product_active_comb;
    integer pe_row;
    integer pe_col;
    integer out_row;
    integer k_lane;
    integer abs_k;
    integer a_index;
    integer b_index;
    integer idx;
    integer m_iter;
    integer n_iter;
    integer p_iter;
    integer sum_work;
    integer base_tiles_work;
    integer gemv_tiles_work;
    integer base_load_work;
    integer gemv_load_work;
    integer base_cost_work;
    integer gemv_cost_work;
    integer overlap_work;
    integer k_parallel_work;
    integer input_bytes_work;
    integer active_k_work;
    integer reset_i;
    reg auto_gemv_work;
    reg signed [7:0] a_value_work;
    reg signed [7:0] b_value_work;

    function [4:0] fold_for_m;
        input [4:0] rows;
        begin
            if (rows == 0)
                fold_for_m = 1;
            else if (16 / rows < 1)
                fold_for_m = 1;
            else
                fold_for_m = 16 / rows;
        end
    endfunction

    always @* begin
        product_active_comb = 0;
        out_row = 0;
        k_lane = 0;
        abs_k = 0;
        a_index = 0;
        b_index = 0;
        a_value_work = 0;
        b_value_work = 0;
        for (idx = 0; idx < MAC_COUNT; idx = idx + 1)
            product_comb[idx] = 16'sd0;

        for (pe_row = 0; pe_row < MAX_M; pe_row = pe_row + 1) begin
            for (pe_col = 0; pe_col < MAX_N; pe_col = pe_col + 1) begin
                out_row = pe_row;
                k_lane = 0;
                if (gemv_r) begin
                    if (k_parallel_r != 0) begin
                        out_row = pe_row / k_parallel_r;
                        k_lane = pe_row % k_parallel_r;
                    end
                end
                abs_k = k_base_r + k_lane;
                if (out_row < m_r && pe_col < n_r && abs_k < k_r) begin
                    if (gemv_r) begin
                        a_index = out_row * MAX_K + abs_k;
                        b_index = abs_k * MAX_N + pe_col;
                    end else begin
                        a_index = pe_row * MAX_K + k_base_r;
                        b_index = k_base_r * MAX_N + pe_col;
                    end
                    a_value_work = $signed(a_operand[a_index*8 +: 8]);
                    b_value_work = $signed(b_operand[b_index*8 +: 8]);
                    product_comb[pe_row*MAX_N + pe_col] =
                        a_value_work * b_value_work;
                    product_active_comb = product_active_comb + 1;
                end
            end
        end
    end

    // Static policy compares the two execution schedules using the fixed
    // 32-byte/cycle dual-operand supply model. This selector is intentionally
    // shape/timing-parameter based; it does not observe runtime queue state.
    always @* begin
        auto_gemv_work = 1'b0;
        k_parallel_work = 1;
        if (m_size != 0)
            k_parallel_work = 16 / m_size;
        if (k_parallel_work < 1)
            k_parallel_work = 1;

        base_tiles_work = k_size;
        input_bytes_work = m_size + n_size;
        base_load_work = (input_bytes_work + 31) / 32;
        if (base_load_work < 1)
            base_load_work = 1;
        base_cost_work = base_tiles_work * (base_load_work + 1);
        if (prefetch_enable && base_tiles_work > 0) begin
            overlap_work = base_load_work - 1;
            if (overlap_work < 0)
                overlap_work = 0;
            base_cost_work = base_load_work + base_tiles_work +
                             (base_tiles_work - 1) * overlap_work;
        end

        gemv_tiles_work = 0;
        gemv_load_work = 1;
        gemv_cost_work = 32'h7fffffff;
        if (k_parallel_work > 0) begin
            gemv_tiles_work = (k_size + k_parallel_work - 1) /
                              k_parallel_work;
            input_bytes_work = k_parallel_work * (m_size + n_size);
            gemv_load_work = (input_bytes_work + 31) / 32;
            if (gemv_load_work < 1)
                gemv_load_work = 1;
            gemv_cost_work = gemv_tiles_work * (gemv_load_work + 2);
            if (prefetch_enable && gemv_tiles_work > 0) begin
                overlap_work = gemv_load_work - 2;
                if (overlap_work < 0)
                    overlap_work = 0;
                gemv_cost_work = gemv_load_work + 2*gemv_tiles_work +
                                 (gemv_tiles_work - 1) * overlap_work;
            end
        end
        if (m_size < 16 && k_size >= 2*k_parallel_work &&
            n_size >= 8 && gemv_cost_work < base_cost_work)
            auto_gemv_work = 1'b1;
    end

    genvar result_i;
    generate
        for (result_i = 0; result_i < MAX_M*MAX_N; result_i = result_i + 1) begin : g_result
            assign result_vector[result_i*64 +: 64] = accumulator[result_i];
        end
    endgenerate

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state_r <= ST_IDLE;
            m_r <= 0;
            n_r <= 0;
            k_r <= 0;
            k_base_r <= 0;
            k_parallel_r <= 1;
            gemv_r <= 0;
            busy <= 0;
            done <= 0;
            error <= 0;
            selected_gemv <= 0;
            selected_k_parallel <= 1;
            cycle_count <= 0;
            useful_mac_count <= 0;
            for (reset_i = 0; reset_i < MAX_M*MAX_N; reset_i = reset_i + 1)
                accumulator[reset_i] <= 64'sd0;
            for (reset_i = 0; reset_i < MAC_COUNT; reset_i = reset_i + 1)
                partial_product[reset_i] <= 16'sd0;
        end else begin
            done <= 0;
            case (state_r)
                ST_IDLE: begin
                    if (start) begin
                        cycle_count <= 0;
                        useful_mac_count <= 0;
                        error <= 0;
                        for (reset_i = 0; reset_i < MAX_M*MAX_N; reset_i = reset_i + 1)
                            accumulator[reset_i] <= 64'sd0;

                        if (m_size == 0 || m_size > MAX_M ||
                            n_size == 0 || n_size > MAX_N ||
                            k_size == 0 || k_size > MAX_K) begin
                            error <= 1;
                            done <= 1;
                            busy <= 0;
                        end else begin
                            m_r <= m_size;
                            n_r <= n_size;
                            k_r <= k_size;
                            k_base_r <= 0;
                            k_parallel_r <= fold_for_m(m_size);
                            selected_k_parallel <= fold_for_m(m_size);
                            if (mode_request == MODE_GEMV)
                                gemv_r <= 1;
                            else if (mode_request == MODE_STATIC)
                                gemv_r <= auto_gemv_work;
                            else
                                gemv_r <= 0;
                            selected_gemv <= (mode_request == MODE_GEMV) ?
                                1'b1 : ((mode_request == MODE_STATIC) ?
                                auto_gemv_work : 1'b0);
                            busy <= 1;
                            state_r <= ST_COMPUTE;
                        end
                    end
                end
                ST_COMPUTE: begin
                    if (abort) begin
                        busy <= 0;
                        done <= 1;
                        error <= 1;
                        state_r <= ST_IDLE;
                    end else begin
                        cycle_count <= cycle_count + 1;
                        useful_mac_count <= useful_mac_count +
                                             product_active_comb;
                        if (gemv_r) begin
                            for (reset_i = 0; reset_i < MAC_COUNT; reset_i = reset_i + 1)
                                partial_product[reset_i] <= product_comb[reset_i];
                            state_r <= ST_REDUCE;
                        end else begin
                            for (m_iter = 0; m_iter < MAX_M; m_iter = m_iter + 1)
                                for (n_iter = 0; n_iter < MAX_N; n_iter = n_iter + 1)
                                    if (m_iter < m_r && n_iter < n_r)
                                        accumulator[m_iter*MAX_N+n_iter] <=
                                            accumulator[m_iter*MAX_N+n_iter] +
                                            {{48{product_comb[m_iter*MAX_N+n_iter][15]}},
                                               product_comb[m_iter*MAX_N+n_iter]};
                            if (k_base_r + 1 >= k_r) begin
                                busy <= 0;
                                done <= 1;
                                state_r <= ST_IDLE;
                            end else begin
                                k_base_r <= k_base_r + 1;
                            end
                        end
                    end
                end
                ST_REDUCE: begin
                    if (abort) begin
                        busy <= 0;
                        done <= 1;
                        error <= 1;
                        state_r <= ST_IDLE;
                    end else begin
                        cycle_count <= cycle_count + 1;
                        for (m_iter = 0; m_iter < MAX_M; m_iter = m_iter + 1) begin
                            for (n_iter = 0; n_iter < MAX_N; n_iter = n_iter + 1) begin
                                if (m_iter < m_r && n_iter < n_r) begin
                                    sum_work = 0;
                                    for (p_iter = 0; p_iter < MAX_M; p_iter = p_iter + 1) begin
                                        if (p_iter < k_parallel_r)
                                            sum_work = sum_work +
                                                $signed(partial_product[(m_iter*k_parallel_r+p_iter)*MAX_N+n_iter]);
                                    end
                                    accumulator[m_iter*MAX_N+n_iter] <=
                                        accumulator[m_iter*MAX_N+n_iter] +
                                        {{40{sum_work[23]}}, sum_work[23:0]};
                                end
                            end
                        end
                        if (k_base_r + k_parallel_r >= k_r) begin
                            busy <= 0;
                            done <= 1;
                            state_r <= ST_IDLE;
                        end else begin
                            k_base_r <= k_base_r + k_parallel_r;
                            state_r <= ST_COMPUTE;
                        end
                    end
                end
                default: begin
                    state_r <= ST_IDLE;
                    busy <= 0;
                    error <= 1;
                    done <= 1;
                end
            endcase
        end
    end
endmodule
