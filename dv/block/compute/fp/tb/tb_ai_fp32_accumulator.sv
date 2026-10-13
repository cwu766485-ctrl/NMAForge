`timescale 1ns/1ps

module tb_ai_fp32_accumulator;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg rst_n, clear, accumulate;
    reg [31:0] product_bits;
    wire [31:0] accumulator_bits;
    reg [1023:0] vector_path;
    reg [3:0] mode;
    reg [31:0] vector_product, expected_bits;
    integer vector_fd, scan_result, vector_count, failure_count;

    ai_fp32_accumulator dut (
        .clk(clk), .rst_n(rst_n), .clear(clear), .accumulate(accumulate),
        .product_bits(product_bits), .accumulator_bits(accumulator_bits)
    );

    ai_fp32_accumulator_sva control_checks (
        .clk(clk), .rst_n(rst_n), .clear(clear), .accumulate(accumulate),
        .product_bits(product_bits), .accumulator_bits(accumulator_bits)
    );

    task check_value;
        input [31:0] expected;
        input [255:0] context_label;
        begin
            if (accumulator_bits !== expected)
                $fatal(1, "FP32_ACCUM_%0s expected=%08h got=%08h",
                       context_label, expected, accumulator_bits);
        end
    endtask

    initial begin
        rst_n = 1'b1; clear = 1'b0; accumulate = 1'b0; product_bits = 0;
        vector_count = 0; failure_count = 0;
        #2 rst_n = 1'b0;
        #1 check_value(32'h00000000, "async_reset");
        #2 rst_n = 1'b1;
        @(posedge clk); #1 check_value(32'h00000000, "reset_release");

        // Establish nonzero state, then prove idle hold and clear priority.
        product_bits = 32'h3f800000; accumulate = 1'b1;
        @(posedge clk); #1 check_value(32'h3f800000, "seed_accumulate");
        accumulate = 1'b0; product_bits = 32'h7f800000;
        @(posedge clk); #1 check_value(32'h3f800000, "idle_hold");
        clear = 1'b1; accumulate = 1'b1; product_bits = 32'h7f800000;
        @(posedge clk); #1 check_value(32'h00000000, "clear_priority");
        clear = 1'b0; accumulate = 1'b0;

        if (!$value$plusargs("VECTORS=%s", vector_path))
            $fatal(1, "Missing +VECTORS=<path>");
        vector_fd = $fopen(vector_path, "r");
        if (vector_fd == 0) $fatal(1, "Cannot open vector file: %0s", vector_path);
        while (!$feof(vector_fd)) begin
            scan_result = $fscanf(vector_fd, "%h %h %h", mode, vector_product, expected_bits);
            if (scan_result == 3) begin
                @(negedge clk);
                clear = (mode == 1);
                accumulate = (mode == 2);
                product_bits = vector_product;
                @(posedge clk); #1;
                vector_count = vector_count + 1;
                if (accumulator_bits !== expected_bits) begin
                    failure_count = failure_count + 1;
                    if (failure_count <= 20)
                        $display("MISMATCH vector=%0d mode=%0d product=%08h expected=%08h got=%08h",
                                 vector_count - 1, mode, vector_product, expected_bits, accumulator_bits);
                end
            end else if (!$feof(vector_fd)) begin
                $fatal(1, "Malformed vector file after vector %0d", vector_count);
            end
        end
        $fclose(vector_fd);
        if (vector_count == 0) $fatal(1, "No vectors were read");
        if (failure_count != 0)
            $fatal(1, "FP32_ACCUM_FAIL vectors=%0d mismatches=%0d", vector_count, failure_count);
        $display("FP32_ACCUM_PASS vectors=%0d", vector_count);
        $finish;
    end
endmodule
