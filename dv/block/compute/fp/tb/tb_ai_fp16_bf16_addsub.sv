`timescale 1ns/1ps

module tb_ai_fp16_bf16_addsub;
    reg [15:0] a_bits;
    reg [15:0] b_bits;
    reg subtract;
    wire [15:0] bf16_result_bits;
    wire [15:0] fp16_result_bits;
    reg [1023:0] vector_path;
    reg vector_format, vector_subtract;
    reg [15:0] vector_a, vector_b, expected_bits;
    integer vector_fd, scan_result, vector_count, failure_count;

    ai_bf16_addsub u_bf16 (
        .a_bits(a_bits), .b_bits(b_bits), .subtract(subtract), .result_bits(bf16_result_bits)
    );
    ai_fp16_addsub u_fp16 (
        .a_bits(a_bits), .b_bits(b_bits), .subtract(subtract), .result_bits(fp16_result_bits)
    );

    initial begin
        a_bits = 16'b0;
        b_bits = 16'b0;
        subtract = 1'b0;
        vector_count = 0;
        failure_count = 0;
        if (!$value$plusargs("VECTORS=%s", vector_path))
            $fatal(1, "Missing +VECTORS=<path>");
        vector_fd = $fopen(vector_path, "r");
        if (vector_fd == 0)
            $fatal(1, "Cannot open vector file: %0s", vector_path);
        while (!$feof(vector_fd)) begin
            scan_result = $fscanf(vector_fd, "%h %h %h %h %h",
                                  vector_format, vector_subtract,
                                  vector_a, vector_b, expected_bits);
            if (scan_result == 5) begin
                a_bits = vector_a;
                b_bits = vector_b;
                subtract = vector_subtract;
                #1;
                vector_count = vector_count + 1;
                if ((!vector_format && (bf16_result_bits !== expected_bits)) ||
                    (vector_format && (fp16_result_bits !== expected_bits))) begin
                    failure_count = failure_count + 1;
                    if (failure_count <= 20)
                        $display("MISMATCH vector=%0d format=%0d sub=%0d a=%04h b=%04h expected=%04h got=%04h",
                                 vector_count - 1, vector_format, vector_subtract,
                                 vector_a, vector_b, expected_bits,
                                 vector_format ? fp16_result_bits : bf16_result_bits);
                end
            end else if (!$feof(vector_fd)) begin
                $fatal(1, "Malformed vector file after vector %0d", vector_count);
            end
        end
        $fclose(vector_fd);
        if (vector_count == 0) $fatal(1, "No vectors were read");
        if (failure_count != 0)
            $fatal(1, "FP16_BF16_ADDSUB_FAIL vectors=%0d mismatches=%0d",
                   vector_count, failure_count);
        $display("FP16_BF16_ADDSUB_PASS vectors=%0d", vector_count);
        $finish;
    end
endmodule
