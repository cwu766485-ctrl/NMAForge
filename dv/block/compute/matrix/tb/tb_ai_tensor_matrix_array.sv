`timescale 1ns / 1ps

`ifndef ARRAY_SIZE
`define ARRAY_SIZE 8
`endif

module tb_ai_tensor_matrix_array;
    localparam integer ARRAY_SIZE = `ARRAY_SIZE;
    localparam integer RESULT_COUNT = ARRAY_SIZE * ARRAY_SIZE;
    localparam integer INDEX_WIDTH = $clog2(RESULT_COUNT);
    localparam integer MAX_K = 32;

    reg clk = 1'b0;
    reg resetn = 1'b0;
    reg clear_accumulators = 1'b0;
    reg buffer_write_valid = 1'b0;
    reg buffer_write_bank = 1'b0;
    reg [ARRAY_SIZE*8-1:0] buffer_write_a = '0;
    reg [ARRAY_SIZE*8-1:0] buffer_write_b = '0;
    reg mac_enable = 1'b0;
    reg mac_bank = 1'b0;
    reg [INDEX_WIDTH-1:0] result_index = '0;
    reg signed [31:0] result_bias = 32'sd0;
    reg [4:0] result_shift = 5'd0;
    reg [1:0] result_activation = 2'd0;
    wire signed [63:0] selected_accumulator;
    wire [31:0] selected_result;
    wire selected_overflow;
    wire [ARRAY_SIZE*ARRAY_SIZE*64-1:0] accumulator_vector;

    reg signed [7:0] logical_a [0:ARRAY_SIZE*MAX_K-1];
    reg signed [7:0] logical_b [0:MAX_K*ARRAY_SIZE-1];
    reg signed [7:0] physical_a [0:ARRAY_SIZE*MAX_K-1];
    reg signed [7:0] physical_b [0:MAX_K*ARRAY_SIZE-1];
    integer rng_seed;
    integer overlap_loads = 0;
    integer cases_run = 0;
    integer saturation_checks = 0;

    ai_tensor_matrix_array #(
        .ARRAY_SIZE(ARRAY_SIZE),
        .RESULT_INDEX_WIDTH(INDEX_WIDTH)
    ) dut (
        .clk(clk),
        .resetn(resetn),
        .clear_accumulators(clear_accumulators),
        .buffer_write_valid(buffer_write_valid),
        .buffer_write_bank(buffer_write_bank),
        .buffer_write_a(buffer_write_a),
        .buffer_write_b(buffer_write_b),
        .mac_enable(mac_enable),
        .mac_bank(mac_bank),
        .result_index(result_index),
        .result_bias(result_bias),
        .result_shift(result_shift),
        .result_activation(result_activation),
        .accumulator_vector(accumulator_vector),
        .selected_accumulator(selected_accumulator),
        .selected_result(selected_result),
        .selected_overflow(selected_overflow)
    );

    always #5 clk = ~clk;

    covergroup matrix_array_cg;
        cp_mac_bank: coverpoint mac_bank iff (mac_enable) {
            bins bank0 = {1'b0};
            bins bank1 = {1'b1};
        }
        cp_load_during_mac: coverpoint
            (mac_enable && buffer_write_valid && (buffer_write_bank != mac_bank)) {
            bins no_overlap = {1'b0};
            bins ping_pong_overlap = {1'b1};
        }
        cp_activation: coverpoint result_activation {
            bins linear = {2'd0};
            bins relu = {2'd1};
            bins relu6 = {2'd2};
        }
        cp_result_saturation: coverpoint selected_overflow {
            bins in_range = {1'b0};
            bins positive_or_negative_clip = {1'b1};
        }
    endgroup
    matrix_array_cg matrix_array_cov = new();

    function automatic signed [7:0] random_byte;
        integer value;
        begin
            value = $urandom(rng_seed);
            random_byte = (value % 255) - 127;
        end
    endfunction

    task automatic clear_accumulator_state;
        begin
            @(negedge clk);
            clear_accumulators = 1'b1;
            buffer_write_valid = 1'b0;
            mac_enable = 1'b0;
            @(posedge clk);
            #1;
            @(negedge clk);
            clear_accumulators = 1'b0;
        end
    endtask

    task automatic load_operand_pair;
        input bank;
        input [ARRAY_SIZE*8-1:0] vector_a;
        input [ARRAY_SIZE*8-1:0] vector_b;
        begin
            @(negedge clk);
            buffer_write_valid = 1'b1;
            buffer_write_bank = bank;
            buffer_write_a = vector_a;
            buffer_write_b = vector_b;
            mac_enable = 1'b0;
            @(posedge clk);
            #1;
            @(negedge clk);
            buffer_write_valid = 1'b0;
        end
    endtask

    task automatic make_k_vectors;
        input integer k_index;
        input integer k_length;
        input integer transpose_a;
        input integer transpose_b;
        output reg [ARRAY_SIZE*8-1:0] vector_a;
        output reg [ARRAY_SIZE*8-1:0] vector_b;
        integer lane;
        begin
            vector_a = '0;
            vector_b = '0;
            for (lane = 0; lane < ARRAY_SIZE; lane = lane + 1) begin
                if (transpose_a != 0)
                    vector_a[lane*8 +: 8] =
                        physical_a[k_index*ARRAY_SIZE + lane];
                else
                    vector_a[lane*8 +: 8] =
                        physical_a[lane*MAX_K + k_index];

                if (transpose_b != 0)
                    vector_b[lane*8 +: 8] =
                        physical_b[lane*MAX_K + k_index];
                else
                    vector_b[lane*8 +: 8] =
                        physical_b[k_index*ARRAY_SIZE + lane];
            end
        end
    endtask

    task automatic expected_postprocess;
        input signed [63:0] accumulated;
        input signed [31:0] bias;
        input [4:0] shift;
        input [1:0] activation;
        output reg [31:0] expected;
        output reg overflow;
        reg signed [63:0] biased;
        reg signed [63:0] shifted;
        reg signed [63:0] activated;
        begin
            biased = accumulated + {{32{bias[31]}}, bias};
            shifted = biased >>> shift;
            if (activation == 2'd1)
                activated = shifted < 0 ? 64'sd0 : shifted;
            else if (activation == 2'd2)
                activated = shifted < 0 ? 64'sd0 :
                            (shifted > 64'sd6 ? 64'sd6 : shifted);
            else
                activated = shifted;
            overflow = 1'b0;
            if (activated > 64'sh0000_0000_7fff_ffff) begin
                expected = 32'h7fff_ffff;
                overflow = 1'b1;
            end else if (activated < -64'sd2147483648) begin
                expected = 32'h8000_0000;
                overflow = 1'b1;
            end else begin
                expected = activated[31:0];
            end
        end
    endtask

    task automatic run_random_gemm_case;
        input integer case_id;
        input integer k_length;
        input integer transpose_a;
        input integer transpose_b;
        reg [ARRAY_SIZE*8-1:0] vector_a;
        reg [ARRAY_SIZE*8-1:0] vector_b;
        reg [ARRAY_SIZE*8-1:0] next_a;
        reg [ARRAY_SIZE*8-1:0] next_b;
        reg signed [63:0] golden_accumulator [0:RESULT_COUNT-1];
        reg [31:0] expected_result;
        reg expected_overflow;
        integer row_index;
        integer col_index;
        integer k_index;
        integer output_index;
        integer bank;
        integer load_count;
        begin
            clear_accumulator_state();
            load_count = 0;
            for (row_index = 0; row_index < ARRAY_SIZE; row_index = row_index + 1) begin
                for (k_index = 0; k_index < k_length; k_index = k_index + 1) begin
                    logical_a[row_index*MAX_K+k_index] = random_byte();
                    if (transpose_a != 0)
                        physical_a[k_index*ARRAY_SIZE+row_index] =
                            logical_a[row_index*MAX_K+k_index];
                    else
                        physical_a[row_index*MAX_K+k_index] =
                            logical_a[row_index*MAX_K+k_index];
                end
            end
            for (k_index = 0; k_index < k_length; k_index = k_index + 1) begin
                for (col_index = 0; col_index < ARRAY_SIZE; col_index = col_index + 1) begin
                    logical_b[k_index*ARRAY_SIZE+col_index] = random_byte();
                    if (transpose_b != 0)
                        physical_b[col_index*MAX_K+k_index] =
                            logical_b[k_index*ARRAY_SIZE+col_index];
                    else
                        physical_b[k_index*ARRAY_SIZE+col_index] =
                            logical_b[k_index*ARRAY_SIZE+col_index];
                end
            end

            for (row_index = 0; row_index < ARRAY_SIZE; row_index = row_index + 1)
                for (col_index = 0; col_index < ARRAY_SIZE; col_index = col_index + 1)
                    golden_accumulator[row_index*ARRAY_SIZE+col_index] = 64'sd0;
            for (row_index = 0; row_index < ARRAY_SIZE; row_index = row_index + 1) begin
                for (col_index = 0; col_index < ARRAY_SIZE; col_index = col_index + 1) begin
                    for (k_index = 0; k_index < k_length; k_index = k_index + 1)
                        golden_accumulator[row_index*ARRAY_SIZE+col_index] =
                            golden_accumulator[row_index*ARRAY_SIZE+col_index] +
                            logical_a[row_index*MAX_K+k_index] *
                            logical_b[k_index*ARRAY_SIZE+col_index];
                end
            end

            make_k_vectors(0, k_length, transpose_a, transpose_b,
                           vector_a, vector_b);
            load_operand_pair(1'b0, vector_a, vector_b);
            bank = 0;
            for (k_index = 0; k_index < k_length; k_index = k_index + 1) begin
                @(negedge clk);
                mac_enable = 1'b1;
                mac_bank = bank[0];
                if (k_index + 1 < k_length) begin
                    make_k_vectors(k_index+1, k_length, transpose_a, transpose_b,
                                   next_a, next_b);
                    buffer_write_valid = 1'b1;
                    buffer_write_bank = !bank[0];
                    buffer_write_a = next_a;
                    buffer_write_b = next_b;
                    load_count = load_count + 1;
                end else begin
                    buffer_write_valid = 1'b0;
                end
                @(posedge clk);
                #1;
                matrix_array_cov.sample();
                @(negedge clk);
                mac_enable = 1'b0;
                buffer_write_valid = 1'b0;
                bank = !bank;
            end
            overlap_loads = overlap_loads + load_count;

            for (output_index = 0; output_index < RESULT_COUNT; output_index = output_index + 1) begin
                @(negedge clk);
                result_index = output_index;
                result_bias = (output_index % 17) - 8;
                result_shift = output_index % 6;
                result_activation = output_index % 3;
                #1;
                expected_postprocess(golden_accumulator[output_index], result_bias,
                                     result_shift, result_activation,
                                     expected_result, expected_overflow);
                if (selected_accumulator !== golden_accumulator[output_index])
                    $fatal(1, "array accumulator mismatch size=%0d case=%0d index=%0d got=%0d expected=%0d",
                           ARRAY_SIZE, case_id, output_index,
                           selected_accumulator, golden_accumulator[output_index]);
                if (selected_result !== expected_result ||
                    selected_overflow !== expected_overflow)
                    $fatal(1, "array post mismatch size=%0d case=%0d index=%0d got=%08x/%b expected=%08x/%b",
                           ARRAY_SIZE, case_id, output_index, selected_result,
                           selected_overflow, expected_result, expected_overflow);
                matrix_array_cov.sample();
            end
            cases_run = cases_run + 1;
            $display("MATRIX_ARRAY_CASE_PASS id=%0d size=%0d k=%0d transpose=%0d%0d overlapped_loads=%0d",
                     case_id, ARRAY_SIZE, k_length, transpose_a, transpose_b, load_count);
        end
    endtask

    task automatic run_saturation_cases;
        reg [ARRAY_SIZE*8-1:0] vector_a;
        reg [ARRAY_SIZE*8-1:0] vector_b;
        integer lane;
        integer term;
        begin
            vector_a = '0;
            vector_b = '0;
            for (lane = 0; lane < ARRAY_SIZE; lane = lane + 1) begin
                vector_a[lane*8 +: 8] = 8'sd127;
                vector_b[lane*8 +: 8] = 8'sd127;
            end
            clear_accumulator_state();
            load_operand_pair(1'b0, vector_a, vector_b);
            for (term = 0; term < 4; term = term + 1) begin
                @(negedge clk);
                mac_enable = 1'b1;
                mac_bank = 1'b0;
                @(posedge clk);
                #1;
                @(negedge clk);
                mac_enable = 1'b0;
            end
            result_index = '0;
            result_bias = 32'sd2147483600;
            result_shift = 0;
            result_activation = 0;
            #1;
            if (selected_accumulator !== 64'sd64516 ||
                selected_result !== 32'h7fff_ffff || !selected_overflow)
                $fatal(1, "positive saturation mismatch acc=%0d result=%08x overflow=%b",
                       selected_accumulator, selected_result, selected_overflow);
            matrix_array_cov.sample();
            saturation_checks = saturation_checks + 1;

            for (lane = 0; lane < ARRAY_SIZE; lane = lane + 1) begin
                vector_a[lane*8 +: 8] = -8'sd128;
                vector_b[lane*8 +: 8] = 8'sd127;
            end
            clear_accumulator_state();
            load_operand_pair(1'b0, vector_a, vector_b);
            for (term = 0; term < 4; term = term + 1) begin
                @(negedge clk);
                mac_enable = 1'b1;
                mac_bank = 1'b0;
                @(posedge clk);
                #1;
                @(negedge clk);
                mac_enable = 1'b0;
            end
            result_index = '0;
            result_bias = -32'sd2147483600;
            result_shift = 0;
            result_activation = 0;
            #1;
            if (selected_accumulator !== -64'sd65024 ||
                selected_result !== 32'h8000_0000 || !selected_overflow)
                $fatal(1, "negative saturation mismatch acc=%0d result=%08x overflow=%b",
                       selected_accumulator, selected_result, selected_overflow);
            matrix_array_cov.sample();
            saturation_checks = saturation_checks + 1;

            result_bias = 0;
            result_activation = 1;
            #1;
            if (selected_result !== 32'd0 || selected_overflow)
                $fatal(1, "ReLU negative clamp mismatch result=%08x overflow=%b",
                       selected_result, selected_overflow);
            matrix_array_cov.sample();
            result_index = 1;
            result_activation = 2;
            #1;
            if (selected_result !== 32'd0 || selected_overflow)
                $fatal(1, "ReLU6 negative clamp mismatch result=%08x overflow=%b",
                       selected_result, selected_overflow);
            matrix_array_cov.sample();
        end
    endtask

    initial begin
        if (!$value$plusargs("SEED=%d", rng_seed)) rng_seed = 20261025;
        repeat (4) @(posedge clk);
        #1;
        resetn = 1'b1;

        run_random_gemm_case(0, 1, 0, 0);
        run_random_gemm_case(1, 3, 1, 0);
        run_random_gemm_case(2, 8, 0, 1);
        run_random_gemm_case(3, 17, 1, 1);
        run_saturation_cases();

        if (cases_run != 4 || saturation_checks != 2 || overlap_loads != 25)
            $fatal(1, "array coverage marker mismatch cases=%0d saturation=%0d overlap=%0d",
                   cases_run, saturation_checks, overlap_loads);
        if (matrix_array_cov.get_coverage() < 100.0)
            $fatal(1, "array functional coverage incomplete: %0.2f%%",
                   matrix_array_cov.get_coverage());
        $display("MATRIX_ARRAY_PASS size=%0d cases=%0d saturation=%0d overlapped_loads=%0d functional_coverage=%0.2f seed=%0d",
                 ARRAY_SIZE, cases_run, saturation_checks, overlap_loads,
                 matrix_array_cov.get_coverage(), rng_seed);
        $finish;
    end
endmodule
