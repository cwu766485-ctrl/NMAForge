`timescale 1ns/1ps

module tb_tensor_repack;
    localparam integer MEM_WORDS = 16384;
    localparam [31:0] SRC_BASE = 32'h0000_1000;
    localparam [31:0] DST_BASE = 32'h0000_8000;
    // Cross a physical 16-row Matrix-A tile boundary and exercise a partial
    // final tile, as a 197-token DeiT sequence does.
    localparam integer PAD_ROWS = 32;
    localparam integer VALID_ROWS = 29;
    localparam integer TOTAL_CHANNELS = 192;
    localparam integer HEAD_DIM = 64;

    reg clk = 1'b0;
    reg resetn = 1'b0;
    reg start = 1'b0;
    reg abort = 1'b0;
    reg [7:0] op_mode = 8'h3b;
    reg [31:0] src0_base = SRC_BASE;
    reg [31:0] src1_base = 0;
    reg [31:0] beta_base = 0;
    reg beta_enable = 0;
    reg pack_enable = 0;
    reg pack_tile_a = 0;
    reg input_tile_a = 0;
    reg [31:0] src0_stride = 0;
    reg [31:0] dst_base = DST_BASE;
    reg [15:0] length = VALID_ROWS;
    reg [15:0] m_size = PAD_ROWS;
    reg [15:0] n_size = TOTAL_CHANNELS;
    reg [4:0] scale_shift = 0;
    reg [31:0] epsilon = 0;
    reg [31:0] watchdog_limit = 32'd100000;
    wire spad_valid;
    wire spad_write;
    wire [31:0] spad_addr;
    wire [31:0] spad_wdata;
    reg spad_ready = 1'b1;
    reg spad_rsp_valid = 1'b0;
    reg [31:0] spad_rdata = 0;
    reg spad_parity_error = 1'b0;
    reg spad_protection_error = 1'b0;
    wire busy, done, error;
    wire [3:0] error_code;
    wire [31:0] result, cycle_count, element_count;

    reg [31:0] mem [0:MEM_WORDS-1];
    integer cycle_no = 0;
    integer accepted_reads = 0;
    integer accepted_writes = 0;
    integer i, row, col, head, mode, addr, word_index;
    integer mismatch_count;
    integer writes_at_abort;
    reg [31:0] packed_word;
    reg stalled_last = 1'b0;
    reg [64:0] stalled_req;
    reg trace_repack = 1'b0;

    wire [7:0] v_op = 8'h3b;
    wire [7:0] v_version = 8'd7;
    reg [31:0] v_src0 = SRC_BASE;
    wire [31:0] v_src1 = 0;
    reg [31:0] v_dst = DST_BASE;
    wire [31:0] v_bias = 0;
    wire [15:0] v_length = VALID_ROWS;
    wire [15:0] v_m_size = PAD_ROWS;
    wire [15:0] v_n_size = TOTAL_CHANNELS;
    wire [15:0] v_k_words = 0;
    wire v_bias_enable = 0;
    wire [7:0] v_flags = 0;
    wire [4:0] v_shift = 0;
    wire [1:0] v_activation = 0;
    wire [31:0] v_aux0 = epsilon;
    wire [31:0] v_src0_stride = 0;
    wire [31:0] v_src1_stride = 0;
    wire [31:0] v_dst_stride = PAD_ROWS;
    wire [15:0] v_batch_count = 0;
    wire [15:0] v_head_count = 0;
    wire v_macro_child_fetch = 0;
    wire v_op_valid, v_is_macro, v_is_matrix, v_is_sfu, v_version_valid;
    wire v_dimensions_valid, v_alignment_error, v_descriptor_invalid;

    always #5 clk = ~clk;

    ai_tensor_sfu_core dut (
        .clk(clk), .resetn(resetn), .start(start), .abort(abort),
        .op_mode(op_mode), .src0_base(src0_base), .src1_base(src1_base),
        .beta_base(beta_base), .beta_enable(beta_enable),
        .pack_enable(pack_enable), .pack_tile_a(pack_tile_a),
        .input_tile_a(input_tile_a), .src0_stride(src0_stride),
        .dst_base(dst_base), .length(length), .m_size(m_size),
        .n_size(n_size), .scale_shift(scale_shift), .epsilon(epsilon),
        .watchdog_limit(watchdog_limit), .spad_valid(spad_valid),
        .spad_write(spad_write), .spad_addr(spad_addr),
        .spad_wdata(spad_wdata), .spad_ready(spad_ready),
        .spad_rsp_valid(spad_rsp_valid), .spad_rdata(spad_rdata),
        .spad_parity_error(spad_parity_error),
        .spad_protection_error(spad_protection_error), .busy(busy),
        .done(done), .error(error), .error_code(error_code),
        .result(result), .cycle_count(cycle_count),
        .element_count(element_count)
    );

    ai_descriptor_validator repack_validator (
        .op(v_op), .version(v_version), .src0(v_src0), .src1(v_src1),
        .dst(v_dst), .bias_base(v_bias), .length(v_length),
        .m_size(v_m_size), .n_size(v_n_size), .k_words(v_k_words),
        .bias_enable(v_bias_enable), .flags(v_flags), .scale_shift(v_shift),
        .activation(v_activation), .aux0(v_aux0),
        .src0_stride(v_src0_stride), .src1_stride(v_src1_stride),
        .dst_stride(v_dst_stride), .batch_count(v_batch_count),
        .head_count(v_head_count), .macro_child_fetch(v_macro_child_fetch),
        .op_valid(v_op_valid), .is_macro(v_is_macro),
        .is_tensor_matrix(v_is_matrix), .is_tensor_sfu(v_is_sfu),
        .version_valid(v_version_valid), .dimensions_valid(v_dimensions_valid),
        .alignment_error(v_alignment_error),
        .descriptor_invalid(v_descriptor_invalid)
    );

    // Repack must hold a scheduled SPAD request until it is accepted.
    property p_repack_request_stable_under_backpressure;
        @(posedge clk) disable iff (!resetn)
            spad_valid && !spad_ready |=>
                spad_valid && $stable({spad_write, spad_addr, spad_wdata});
    endproperty
    assert property (p_repack_request_stable_under_backpressure)
        else $fatal(1, "repack SPAD request changed under backpressure");

    // Registered read response model with deterministic request backpressure.
    // A held request must keep valid, direction, address, and data stable.
    always @(posedge clk) begin
        cycle_no <= cycle_no + 1;
        spad_ready <= ((cycle_no % 7) != 2) && ((cycle_no % 7) != 5);
        spad_rsp_valid <= 1'b0;
        if (!resetn) begin
            spad_rsp_valid <= 1'b0;
            spad_rdata <= 0;
            accepted_reads <= 0;
            accepted_writes <= 0;
            stalled_last <= 1'b0;
        end else begin
            if (stalled_last && (!spad_valid ||
                {spad_write,spad_addr,spad_wdata} !== stalled_req)) begin
                $fatal(1, "held SPAD request changed under backpressure");
            end
            stalled_last <= spad_valid && !spad_ready;
            if (spad_valid && !spad_ready)
                stalled_req <= {spad_write,spad_addr,spad_wdata};
            if (spad_valid && spad_ready) begin
                if (spad_addr[1:0] != 0)
                    $fatal(1, "unaligned SPAD access address=%08x", spad_addr);
                if ((spad_addr >> 2) >= MEM_WORDS)
                    $fatal(1, "SPAD address out of range address=%08x", spad_addr);
                if (spad_write) begin
                    mem[spad_addr >> 2] <= spad_wdata;
                    accepted_writes <= accepted_writes + 1;
                end else begin
                    spad_rdata <= mem[spad_addr >> 2];
                    if (trace_repack && !spad_write)
                        $display("SPAD_READ cycle=%0d addr=%08x data=%08x", cycle_no, spad_addr, mem[spad_addr >> 2]);
                    spad_rsp_valid <= 1'b1;
                    accepted_reads <= accepted_reads + 1;
                end
            end
        end
    end

    function integer physical_matrix_a_word;
        input integer r;
        input integer c;
        integer tile_base, local_row, local_col, index;
        begin
            tile_base = ((r / 16) * (TOTAL_CHANNELS / 16) + c / 16) * 256;
            local_row = r & 15;
            local_col = c & 15;
            index = (local_row / 4) * 16 + (local_col / 4) * 4 + (local_row & 3);
            physical_matrix_a_word = (SRC_BASE >> 2) + tile_base + index;
        end
    endfunction

    function [7:0] input_value;
        input integer r;
        input integer c;
        integer v;
        begin
            if (r < VALID_ROWS)
                v = ((r * 11 + c * 7) % 101) - 50;
            else
                v = ((r * 17 + c * 5) % 113) - 56;
            input_value = v[7:0];
        end
    endfunction

    function [7:0] read_byte;
        input integer byte_addr;
        integer wi, lane;
        begin
            wi = byte_addr >> 2;
            lane = byte_addr & 3;
            read_byte = mem[wi][lane*8 +: 8];
        end
    endfunction

    function integer matrix_b_byte_address;
        input integer r;
        input integer c;
        integer panel, local_col, col_group, wi;
        begin
            panel = c / 16;
            local_col = c % 16;
            col_group = (local_col / 4) * 4;
            wi = (col_group / 4) * (PAD_ROWS / 4) * 4 +
                 (r / 4) * 4 + (local_col - col_group);
            matrix_b_byte_address = DST_BASE + panel * 4096 + wi * 4 + (r & 3);
        end
    endfunction

    task initialize_memory;
        integer r, c, w, base_index;
        begin
            for (w = 0; w < MEM_WORDS; w = w + 1)
                mem[w] = 32'hA55A_A55A;
            for (r = 0; r < PAD_ROWS; r = r + 1) begin
                for (c = 0; c < TOTAL_CHANNELS; c = c + 4) begin
                    packed_word = {input_value(r,c+3), input_value(r,c+2),
                                   input_value(r,c+1), input_value(r,c)};
                    base_index = physical_matrix_a_word(r,c);
                    mem[base_index] = packed_word;
                end
            end
        end
    endtask

    task run_and_check;
        input integer run_mode;
        input integer run_head;
        integer r, f, expected, observed, expected_reads, a;
        begin
            initialize_memory();
            accepted_reads = 0;
            accepted_writes = 0;
            @(negedge clk);
            epsilon = (run_head << 2) | run_mode;
            #1;
            if (v_descriptor_invalid || !v_op_valid || !v_is_sfu ||
                !v_version_valid || !v_dimensions_valid || v_alignment_error)
                $fatal(1, "legal repack descriptor rejected mode=%0d head=%0d", run_mode, run_head);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            fork
                begin wait(done === 1'b1); end
                begin repeat (200000) @(posedge clk); $fatal(1, "repack timeout mode=%0d head=%0d", run_mode, run_head); end
            join_any
            disable fork;
            #1;
            if (error || error_code != 0)
                $fatal(1, "repack error mode=%0d head=%0d code=%0d", run_mode, run_head, error_code);
            if (accepted_writes != PAD_ROWS * HEAD_DIM / 4 ||
                element_count != PAD_ROWS * HEAD_DIM)
                $fatal(1, "write accounting mode=%0d head=%0d writes=%0d elements=%0d", run_mode, run_head, accepted_writes, element_count);
            // Invalid rows are zero-filled locally and must not be read from
            // SPAD; every mode reads only the valid source rows.
            expected_reads = VALID_ROWS * (HEAD_DIM / 4);
            if (accepted_reads != expected_reads)
                $fatal(1, "read accounting mode=%0d head=%0d reads=%0d expected=%0d", run_mode, run_head, accepted_reads, expected_reads);
            mismatch_count = 0;
            for (r = 0; r < PAD_ROWS; r = r + 1) begin
                for (f = 0; f < HEAD_DIM; f = f + 1) begin
                    if (run_mode == 0)
                        a = DST_BASE + r * HEAD_DIM + f;
                    else if (run_mode == 1)
                        // 0x52's K B operand is transposed and tiled in
                        // 16-key stripes: [tile][feature][key_lane].
                        a = DST_BASE + (r / 16) * HEAD_DIM * 16 +
                            f * 16 + (r & 15);
                    else
                        a = matrix_b_byte_address(r, f);
                    observed = read_byte(a);
                    expected = (r < VALID_ROWS) ? input_value(r, run_head*HEAD_DIM + f) : 0;
                    if (observed !== expected[7:0]) begin
                        if (mismatch_count < 4)
                            $display("MISMATCH mode=%0d head=%0d row=%0d feature=%0d addr=%08x expected=%02x actual=%02x", run_mode, run_head, r, f, a, expected[7:0], observed[7:0]);
                        mismatch_count = mismatch_count + 1;
                    end
                end
            end
            if (mismatch_count != 0)
                $fatal(1, "repack golden mismatch mode=%0d head=%0d count=%0d", run_mode, run_head, mismatch_count);
            $display("REPACK_DIRECTED_PASS mode=%0d head=%0d rows=%0d valid=%0d channels=%0d reads=%0d writes=%0d backpressure=1 golden=bit-exact",
                     run_mode, run_head, PAD_ROWS, VALID_ROWS, HEAD_DIM,
                     accepted_reads, accepted_writes);
        end
    endtask

    initial begin
        trace_repack = $test$plusargs("TRACE_REPACK");
        repeat (4) @(negedge clk);
        resetn = 1'b1;
        for (mode = 0; mode < 3; mode = mode + 1)
            for (head = 0; head < 3; head = head + 1)
                run_and_check(mode, head);

        // Reserved mode is rejected before any SPAD access or write.
        accepted_reads = 0;
        accepted_writes = 0;
        @(negedge clk);
        epsilon = 3;
        #1;
        if (!v_descriptor_invalid)
            $fatal(1, "reserved repack mode accepted by descriptor validator");
        start = 1'b1;
        @(negedge clk);
        start = 1'b0;
        wait(done === 1'b1);
        #1;
        if (!error || error_code != 1 || accepted_writes != 0)
            $fatal(1, "invalid mode did not reject cleanly code=%0d writes=%0d", error_code, accepted_writes);
        $display("REPACK_INVALID_DESCRIPTOR_PASS mode=3 error_code=%0d writes=0", error_code);

        // Descriptor range checks must catch an exact 4 GiB end address as
        // well as an address whose low bits are nonzero after overflow.
        @(negedge clk);
        epsilon = 0;
        v_src0 = 32'hffff_e800; // 0x1800-byte source ends at 0x1_0000_0000.
        #1;
        if (!v_descriptor_invalid)
            $fatal(1, "source range ending exactly at 4 GiB was accepted");
        v_src0 = SRC_BASE;
        v_dst = 32'hffff_f800; // Q destination ends exactly at 4 GiB.
        #1;
        if (!v_descriptor_invalid)
            $fatal(1, "destination range ending exactly at 4 GiB was accepted");
        v_dst = SRC_BASE + 4;
        #1;
        if (!v_descriptor_invalid)
            $fatal(1, "overlapping repack source/destination was accepted");
        v_dst = DST_BASE;
        #1;
        if (v_descriptor_invalid)
            $fatal(1, "restored legal repack descriptor rejected");
        $display("REPACK_DESCRIPTOR_RANGE_PASS exact_4g_wrap=1 alias=1");

        // Abort after source traffic has started. It must retire with the
        // abort error and must not publish a partial destination block.
        initialize_memory();
        accepted_reads = 0;
        accepted_writes = 0;
        @(negedge clk);
        epsilon = 0;
        abort = 0;
        start = 1;
        @(negedge clk);
        start = 0;
        wait(accepted_reads >= 4);
        @(negedge clk);
        writes_at_abort = accepted_writes;
        abort = 1;
        @(negedge clk);
        abort = 0;
        wait(done === 1'b1);
        #1;
        if (!error || error_code != 3 || accepted_writes != writes_at_abort)
            $fatal(1, "abort did not stop writes after abort code=%0d before=%0d after=%0d",
                   error_code, writes_at_abort, accepted_writes);
        $display("REPACK_ABORT_PASS reads=%0d writes_before=%0d writes_after=%0d error_code=%0d",
                 accepted_reads, writes_at_abort, accepted_writes, error_code);

        // Reset during an in-flight read must clear the command state and
        // permit a fresh command to execute afterward.
        initialize_memory();
        accepted_reads = 0;
        accepted_writes = 0;
        @(negedge clk);
        epsilon = 0;
        start = 1;
        @(negedge clk);
        start = 0;
        wait(accepted_reads >= 4);
        @(negedge clk);
        resetn = 0;
        repeat (2) @(negedge clk);
        resetn = 1;
        #1;
        if (busy || done || error)
            $fatal(1, "reset did not clear repack state");
        $display("REPACK_RESET_INFLIGHT_PASS reads_before_reset>=4");
        run_and_check(0, 0);
        $display("TENSOR_REPACK_DIRECTED_TEST_PASS modes=3 heads=3 valid_rows=%0d padded_rows=%0d golden_words=%0d",
                 VALID_ROWS, PAD_ROWS-VALID_ROWS, 3*PAD_ROWS*HEAD_DIM);
        $finish;
    end
endmodule
