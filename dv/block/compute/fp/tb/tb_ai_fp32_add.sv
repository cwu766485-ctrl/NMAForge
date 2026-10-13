`timescale 1ns/1ps

module tb_ai_fp32_add;
    reg [31:0] a_bits;
    reg [31:0] b_bits;
    wire [31:0] result_bits;
    reg [1023:0] vector_path;
    reg [31:0] vector_a, vector_b, expected_bits;
    integer vector_fd, scan_result, vector_count, failure_count;

    ai_fp32_add dut (.a_bits(a_bits), .b_bits(b_bits), .result_bits(result_bits));

    initial begin
        a_bits = 0;
        b_bits = 0;
        vector_count = 0;
        failure_count = 0;
        if (!$value$plusargs("VECTORS=%s", vector_path))
            $fatal(1, "Missing +VECTORS=<path>");
        vector_fd = $fopen(vector_path, "r");
        if (vector_fd == 0)
            $fatal(1, "Cannot open vector file: %0s", vector_path);
        while (!$feof(vector_fd)) begin
            scan_result = $fscanf(vector_fd, "%h %h %h", vector_a, vector_b, expected_bits);
            if (scan_result == 3) begin
                a_bits = vector_a;
                b_bits = vector_b;
                #1;
                vector_count = vector_count + 1;
                if (result_bits !== expected_bits) begin
                    failure_count = failure_count + 1;
                    if (failure_count <= 20)
                        $display("MISMATCH vector=%0d a=%08h b=%08h expected=%08h got=%08h",
                                 vector_count - 1, vector_a, vector_b, expected_bits, result_bits);
                end
            end else if (!$feof(vector_fd)) begin
                $fatal(1, "Malformed vector file after vector %0d", vector_count);
            end
        end
        $fclose(vector_fd);
        if (vector_count == 0) $fatal(1, "No vectors were read");
        if (failure_count != 0)
            $fatal(1, "FP32_ADD_FAIL vectors=%0d mismatches=%0d", vector_count, failure_count);
        $display("FP32_ADD_PASS vectors=%0d", vector_count);
        $finish;
    end
endmodule
