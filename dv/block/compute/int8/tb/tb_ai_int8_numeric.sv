`timescale 1ns/1ps

module tb_ai_int8_numeric;
    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg resetn = 1'b0;
    reg start = 1'b0;
    reg abort = 1'b0;
    reg [7:0] op_mode = 8'h10;
    reg [31:0] src0_base = 0;
    reg [31:0] src1_base = 0;
    reg [31:0] dst_base = 0;
    reg [15:0] length = 0;
    reg [15:0] m_size = 0;
    reg [15:0] n_size = 0;
    reg [15:0] k_words = 0;
    reg [4:0] scale_shift = 0;
    reg [1:0] activation = 0;
    reg [31:0] bias_base = 0;
    reg bias_enable = 0;
    reg [31:0] watchdog_limit = 0;
    reg spad_ready = 0;
    reg spad_rsp_valid = 0;
    reg spad_parity_error = 0;
    reg spad_protection_error = 0;
    reg [31:0] spad_rdata = 0;
    wire spad_valid;
    wire spad_write;
    wire [31:0] spad_addr;
    wire [31:0] spad_wdata;
    wire busy;
    wire done;
    wire error;
    wire [3:0] error_code;
    wire [31:0] result;
    wire [31:0] cycle_count;
    wire [31:0] element_count;

    reg [31:0] spad_mem [0:65535];
    reg [31:0] expected_addr [0:255];
    reg [31:0] expected_data [0:255];
    reg expected_write_seen [0:255];
    integer expected_count = 0;
    integer total_write_stalls = 0;
    integer total_read_stalls = 0;
    integer total_read_responses = 0;
    integer total_read_accepts = 0;
    integer total_cases = 0;
    integer opcode_bins [0:2];
    integer shift_zero_bin = 0;
    integer shift_one_bin = 0;
    integer shift_31_bin = 0;
    integer shift_other_bin = 0;
    integer activation_bins [0:2];
    integer bias_on_bin = 0;
    integer bias_off_bin = 0;
    reg test_active = 1'b0;

    reg [31:0] lfsr = 32'h1;
    reg deterministic_spad = 1'b0;
    reg read_pending = 1'b0;
    integer read_delay = 0;
    reg [31:0] read_pending_data = 0;
    reg previous_stall = 1'b0;
    reg previous_write = 1'b0;
    reg [31:0] previous_addr = 0;
    reg [31:0] previous_wdata = 0;

    integer vector_fd;
    integer scan_result;
    integer case_total;
    integer case_id;
    integer parsed_case_id;
    integer memory_count;
    integer out_count;
    integer index;
    integer slot;
    integer cycle;
    integer read_index;
    integer fill_index;
    integer timeout_limit;
    integer j;
    integer seed;
    integer op_index;
    reg [7:0] case_opcode;
    reg [31:0] case_src0;
    reg [31:0] case_src1;
    reg [31:0] case_dst;
    reg [31:0] case_bias_base;
    integer case_length;
    integer case_m;
    integer case_n;
    integer case_k;
    integer case_shift;
    integer case_activation;
    integer case_bias_enable;
    reg [31:0] file_addr;
    reg [31:0] file_data;
    string vector_path;
    string tag;
    string case_name;

    ai_int8_compute_core dut (
        .clk(clk), .resetn(resetn), .start(start), .abort(abort),
        .op_mode(op_mode), .src0_base(src0_base), .src1_base(src1_base),
        .dst_base(dst_base), .length(length), .m_size(m_size), .n_size(n_size),
        .k_words(k_words), .scale_shift(scale_shift), .activation(activation),
        .bias_base(bias_base), .bias_enable(bias_enable),
        .watchdog_limit(watchdog_limit), .spad_ready(spad_ready),
        .spad_rsp_valid(spad_rsp_valid),
        .spad_parity_error(spad_parity_error),
        .spad_protection_error(spad_protection_error), .spad_rdata(spad_rdata),
        .spad_valid(spad_valid), .spad_write(spad_write),
        .spad_addr(spad_addr), .spad_wdata(spad_wdata), .busy(busy),
        .done(done), .error(error), .error_code(error_code), .result(result),
        .cycle_count(cycle_count), .element_count(element_count)
    );

    always @(negedge clk) begin
        if (!resetn) begin
            lfsr <= (seed == 0) ? 32'h1 : seed;
            spad_ready <= 1'b0;
        end else begin
            lfsr <= {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
            // Deterministic random ready with both accepted cycles and stalls.
            spad_ready <= deterministic_spad ? 1'b1 : (lfsr[0] | lfsr[3]);
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            spad_rsp_valid <= 1'b0;
            spad_rdata <= 32'd0;
            read_pending <= 1'b0;
            read_delay <= 0;
            previous_stall <= 1'b0;
        end else begin
            spad_rsp_valid <= 1'b0;
            if (previous_stall &&
                (!spad_valid || spad_write !== previous_write ||
                 spad_addr !== previous_addr || spad_wdata !== previous_wdata))
                $fatal(1, "request payload changed while stalled");
            previous_stall <= spad_valid && !spad_ready;
            previous_write <= spad_write;
            previous_addr <= spad_addr;
            previous_wdata <= spad_wdata;

            if (spad_valid && !spad_ready) begin
                if (spad_write) total_write_stalls = total_write_stalls + 1;
                else total_read_stalls = total_read_stalls + 1;
            end

            if (read_pending) begin
                if (read_delay <= 1) begin
                    spad_rsp_valid <= 1'b1;
                    spad_rdata <= read_pending_data;
                    read_pending <= 1'b0;
                    total_read_responses = total_read_responses + 1;
                end else begin
                    read_delay <= read_delay - 1;
                end
            end

            if (spad_valid && spad_ready) begin
                if (spad_write) begin
                    slot = -1;
                    for (index = 0; index < expected_count; index = index + 1)
                        if (expected_addr[index] == spad_addr) slot = index;
                    if (!test_active || slot < 0)
                        $fatal(1, "unexpected SPAD write addr=%08x data=%08x", spad_addr, spad_wdata);
                    if (expected_write_seen[slot])
                        $fatal(1, "duplicate SPAD write addr=%08x", spad_addr);
                    expected_write_seen[slot] = 1'b1;
                    spad_mem[spad_addr[17:2]] <= spad_wdata;
                end else begin
                    if (read_pending)
                        $fatal(1, "core issued a second read with a response outstanding");
                    if (spad_addr[1:0] != 2'b00)
                        $fatal(1, "unaligned SPAD read addr=%08x", spad_addr);
                    total_read_accepts = total_read_accepts + 1;
                    read_pending <= 1'b1;
                    read_delay <= deterministic_spad ? 1 : (1 + lfsr[3:2]);
                    read_pending_data <= spad_mem[spad_addr[17:2]];
                end
            end
        end
    end

    task automatic run_one_case(input integer id, input string name);
        integer timeout_cycles;
        begin
            if (op_mode == 8'h10) op_index = 0;
            else if (op_mode == 8'h11) op_index = 1;
            else if (op_mode == 8'h12) op_index = 2;
            else $fatal(1, "unexpected opcode=%02x", op_mode);
            opcode_bins[op_index] = opcode_bins[op_index] + 1;
            case (scale_shift)
                0: shift_zero_bin = shift_zero_bin + 1;
                1: shift_one_bin = shift_one_bin + 1;
                31: shift_31_bin = shift_31_bin + 1;
                default: shift_other_bin = shift_other_bin + 1;
            endcase
            activation_bins[activation] = activation_bins[activation] + 1;
            if (bias_enable) bias_on_bin = bias_on_bin + 1;
            else bias_off_bin = bias_off_bin + 1;

            test_active = 1'b1;
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            timeout_cycles = 0;
            timeout_limit = (id == 100) ? 800000 : 100000;
            while (!done && timeout_cycles < timeout_limit) begin
                @(negedge clk);
                timeout_cycles = timeout_cycles + 1;
            end
            if (!done)
                $fatal(1, "timeout case=%0d name=%s busy=%b", id, name, busy);
            if (error || error_code != 0)
                $fatal(1, "DUT error case=%0d name=%s code=%0d", id, name, error_code);
            if (element_count != expected_count)
                $fatal(1, "write count case=%0d name=%s got=%0d expected=%0d",
                       id, name, element_count, expected_count);
            if (result !== expected_data[expected_count-1])
                $fatal(1, "result case=%0d name=%s got=%08x expected=%08x",
                       id, name, result, expected_data[expected_count-1]);
            for (j = 0; j < expected_count; j = j + 1) begin
                if (!expected_write_seen[j])
                    $fatal(1, "missing output write case=%0d name=%s address=%08x",
                           id, name, expected_addr[j]);
                if (spad_mem[expected_addr[j][17:2]] !== expected_data[j])
                    $fatal(1, "memory image case=%0d name=%s address=%08x got=%08x expected=%08x",
                           id, name, expected_addr[j],
                           spad_mem[expected_addr[j][17:2]], expected_data[j]);
            end
            if (read_pending)
                $fatal(1, "response ledger not drained case=%0d name=%s", id, name);
            test_active = 1'b0;
            total_cases = total_cases + 1;
            $display("SCALAR_INT8_CASE_PASS id=%0d name=%s opcode=%02x outputs=%0d cycles=%0d",
                     id, name, op_mode, expected_count, cycle_count);

            resetn = 1'b0;
            repeat (2) @(negedge clk);
            resetn = 1'b1;
            @(negedge clk);
        end
    endtask

    task automatic run_max_vdot_length;
        integer reads_before;
        integer responses_before;
        begin
            resetn = 1'b0;
            start = 1'b0;
            abort = 1'b0;
            spad_rsp_valid = 1'b0;
            deterministic_spad = 1'b1;
            op_mode = 8'h10;
            src0_base = 32'h0000_0000;
            src1_base = 32'h0000_0000;
            dst_base = 32'h0003_fffc;
            length = 16'hffff;
            m_size = 16'd0;
            n_size = 16'd0;
            k_words = 16'd0;
            scale_shift = 5'd0;
            activation = 2'd0;
            bias_base = 32'd0;
            bias_enable = 1'b0;
            watchdog_limit = 32'd0;
            repeat (3) @(negedge clk);
            for (fill_index = 0; fill_index < 65535; fill_index = fill_index + 1)
                spad_mem[fill_index] = 32'h8080_8080;
            spad_mem[65535] = 32'hdead_beef;

            expected_count = 1;
            expected_addr[0] = dst_base;
            expected_data[0] = 32'h7fff_ffff;
            expected_write_seen[0] = 1'b0;
            reads_before = total_read_accepts;
            responses_before = total_read_responses;
            resetn = 1'b1;
            @(negedge clk);
            run_one_case(100, "vdot_max_encoded_length_33bit_accumulator");
            if (total_read_accepts - reads_before != 131070 ||
                total_read_responses - responses_before != 131070 || read_pending)
                $fatal(1, "maximum VDOT transaction count mismatch reads=%0d responses=%0d pending=%b",
                       total_read_accepts - reads_before,
                       total_read_responses - responses_before, read_pending);
            if (spad_mem[65535] !== 32'h7fff_ffff)
                $fatal(1, "maximum VDOT output memory image mismatch got=%08x",
                       spad_mem[65535]);
            deterministic_spad = 1'b0;
            $display("SCALAR_INT8_MAX_LENGTH_PASS length=65535 accepted_reads=131070 returned_reads=131070 exact_acc=4294901760 saturated=7fffffff output_word=65535 seed=%0d",
                     seed);
        end
    endtask

    task automatic run_abort_watchdog_priority;
        integer wait_cycles;
        integer done_pulses;
        integer responses_before;
        integer reads_before;
        begin
            // Legal VDOT descriptor with deterministic one-cycle reads. Apply
            // Abort at ST_CALC when both reads are retired and the watchdog
            // reaches its threshold on that same sampling edge.
            resetn = 1'b0;
            start = 1'b0;
            abort = 1'b0;
            deterministic_spad = 1'b1;
            op_mode = 8'h10;
            src0_base = 32'h0000_0100;
            src1_base = 32'h0000_0200;
            dst_base = 32'h0000_0300;
            length = 16'd1;
            m_size = 16'd0;
            n_size = 16'd0;
            k_words = 16'd0;
            bias_enable = 1'b0;
            watchdog_limit = 32'd6;
            spad_rsp_valid = 1'b0;
            responses_before = total_read_responses;
            reads_before = total_read_accepts;
            repeat (3) @(negedge clk);
            resetn = 1'b1;
            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            wait_cycles = 0;
            while ((!busy || cycle_count < watchdog_limit ||
                    total_read_responses < responses_before + 2 ||
                    spad_valid || read_pending) && wait_cycles < 16) begin
                @(negedge clk);
                wait_cycles = wait_cycles + 1;
            end
            if (!busy || cycle_count != watchdog_limit ||
                total_read_responses != responses_before + 2 ||
                total_read_accepts != reads_before + 2 ||
                spad_valid || read_pending || element_count != 0 || done)
                $fatal(1, "priority setup invalid busy=%b cycles=%0d reads=%0d/%0d responses=%0d/%0d valid=%b pending=%b elements=%0d done=%b",
                       busy, cycle_count, total_read_accepts, reads_before + 2,
                       total_read_responses, responses_before + 2, spad_valid,
                       read_pending, element_count, done);
            if (dut.watchdog_expired !== 1'b1)
                $fatal(1, "watchdog was not expired at the sampled Abort edge cycles=%0d limit=%0d",
                       cycle_count, watchdog_limit);

            abort = 1'b1;
            @(negedge clk);
            if (done || error_code != 4'd3 || !busy)
                $fatal(1, "Abort did not win simultaneous Abort/Watchdog edge: done=%b busy=%b code=%0d",
                       done, busy, error_code);
            @(negedge clk);
            if (!done || !error || error_code != 4'd3 || busy || element_count != 0)
                $fatal(1, "Abort priority retirement mismatch: done=%b error=%b busy=%b code=%0d elements=%0d",
                       done, error, busy, error_code, element_count);

            done_pulses = 1;
            abort = 1'b0;
            repeat (3) begin
                @(negedge clk);
                if (done) done_pulses = done_pulses + 1;
            end
            if (done_pulses != 1 || total_read_accepts != reads_before + 2 ||
                total_read_responses != responses_before + 2)
                $fatal(1, "Abort priority pulse/response mismatch done_pulses=%0d responses=%0d/%0d",
                       done_pulses, total_read_responses, responses_before + 2);

            resetn = 1'b0;
            repeat (2) @(negedge clk);
            deterministic_spad = 1'b0;
            watchdog_limit = 32'd0;
            resetn = 1'b1;
            @(negedge clk);
            $display("SCALAR_INT8_ABORT_WATCHDOG_PRIORITY_PASS legal_vdot=1 simultaneous=1 winner=ABORT accepted_reads=2 returned_reads=2 accepted_writes=0 completion_pulses=1 seed=%0d",
                     seed);
        end
    endtask

    task automatic run_abort_reset_edge;
        integer wait_cycles;
        integer reads_before;
        integer responses_before;
        integer quiet_cycles;
        begin
            // Reset and Abort are asserted together at a legal calculation
            // boundary after all reads have returned, then a fresh VDOT proves
            // that the old task cannot leak into the next reset epoch.
            resetn = 1'b0;
            start = 1'b0;
            abort = 1'b0;
            deterministic_spad = 1'b1;
            op_mode = 8'h10;
            src0_base = 32'h0000_0100;
            src1_base = 32'h0000_0200;
            dst_base = 32'h0000_0300;
            length = 16'd1;
            m_size = 16'd0;
            n_size = 16'd0;
            k_words = 16'd0;
            scale_shift = 5'd0;
            activation = 2'd0;
            bias_enable = 1'b0;
            watchdog_limit = 32'd0;
            spad_rsp_valid = 1'b0;
            spad_mem[32'h0000_0100 >> 2] = 32'h0403_0201;
            spad_mem[32'h0000_0200 >> 2] = 32'h0807_0605;
            spad_mem[32'h0000_0300 >> 2] = 32'hdead_beef;
            reads_before = total_read_accepts;
            responses_before = total_read_responses;
            repeat (3) @(negedge clk);
            resetn = 1'b1;
            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            wait_cycles = 0;
            while ((!busy || total_read_accepts < reads_before + 2 ||
                    total_read_responses < responses_before + 2 ||
                    spad_valid || read_pending) && wait_cycles < 16) begin
                @(negedge clk);
                wait_cycles = wait_cycles + 1;
            end
            if (!busy || total_read_accepts != reads_before + 2 ||
                total_read_responses != responses_before + 2 || spad_valid ||
                read_pending || element_count != 0 || done)
                $fatal(1, "Abort/Reset setup invalid busy=%b reads=%0d/%0d responses=%0d/%0d valid=%b pending=%b elements=%0d done=%b",
                       busy, total_read_accepts, reads_before + 2,
                       total_read_responses, responses_before + 2,
                       spad_valid, read_pending, element_count, done);

            abort = 1'b1;
            resetn = 1'b0;
            @(negedge clk);
            if (busy || done || error || error_code != 4'd0 || element_count != 0 ||
                spad_mem[32'h0000_0300 >> 2] !== 32'hdead_beef)
                $fatal(1, "Reset did not dominate same-edge Abort: busy=%b done=%b error=%b code=%0d elements=%0d dst=%08x",
                       busy, done, error, error_code, element_count,
                       spad_mem[32'h0000_0300 >> 2]);
            repeat (2) @(negedge clk);
            abort = 1'b0;
            resetn = 1'b1;
            quiet_cycles = 0;
            repeat (4) begin
                @(negedge clk);
                quiet_cycles = quiet_cycles + 1;
                if (busy || done || error || error_code != 4'd0)
                    $fatal(1, "old task leaked after Abort/Reset release cycle=%0d busy=%b done=%b error=%b code=%0d",
                           quiet_cycles, busy, done, error, error_code);
            end

            expected_count = 1;
            expected_addr[0] = 32'h0000_0300;
            expected_data[0] = 32'd70;
            expected_write_seen[0] = 1'b0;
            test_active = 1'b1;
            run_one_case(99, "abort_reset_recovery");
            test_active = 1'b0;
            deterministic_spad = 1'b0;
            $display("SCALAR_INT8_ABORT_RESET_PRIORITY_PASS legal_vdot=1 same_edge=1 winner=RESET old_task_quiet=4 recovery_golden=70 accepted_reads=2 returned_reads=2 seed=%0d",
                     seed);
        end
    endtask

    initial begin
        seed = 20261030;
        if (!$value$plusargs("SEED=%d", seed)) seed = 20261030;
        if (!$value$plusargs("VECTOR_FILE=%s", vector_path))
            $fatal(1, "missing +VECTOR_FILE=<path>");
        for (index = 0; index < 3; index = index + 1) opcode_bins[index] = 0;
        for (index = 0; index < 3; index = index + 1) activation_bins[index] = 0;

        vector_fd = $fopen(vector_path, "r");
        if (vector_fd == 0) $fatal(1, "cannot open vector file %s", vector_path);
        scan_result = $fscanf(vector_fd, "%s %d\n", tag, case_total);
        if (scan_result != 2 || tag != "COUNT")
            $fatal(1, "malformed vector count header");

        resetn = 1'b0;
        repeat (3) @(negedge clk);
        resetn = 1'b1;
        @(negedge clk);

        for (case_id = 0; case_id < case_total; case_id = case_id + 1) begin
            resetn = 1'b0;
            repeat (2) @(negedge clk);
            for (index = 0; index < 65536; index = index + 1)
                spad_mem[index] = 32'd0;
            scan_result = $fscanf(vector_fd,
                "%s %d %s %h %h %h %h %h %d %d %d %d %d %d %d %d %d\n",
                tag, parsed_case_id, case_name, case_opcode, case_src0, case_src1,
                case_dst, case_bias_base, case_length, case_m, case_n, case_k,
                case_shift, case_activation, case_bias_enable, memory_count, out_count);
            if (scan_result != 17 || tag != "CASE")
                $fatal(1, "malformed case header id=%0d scan=%0d", case_id, scan_result);
            if (parsed_case_id != case_id)
                $fatal(1, "vector case order mismatch parsed=%0d loop=%0d", parsed_case_id, case_id);

            op_mode = case_opcode;
            src0_base = case_src0;
            src1_base = case_src1;
            dst_base = case_dst;
            bias_base = case_bias_base;
            length = case_length;
            m_size = case_m;
            n_size = case_n;
            k_words = case_k;
            scale_shift = case_shift;
            activation = case_activation;
            bias_enable = case_bias_enable[0];
            expected_count = out_count;
            if (expected_count <= 0 || expected_count > 256)
                $fatal(1, "invalid expected output count %0d", expected_count);
            for (index = 0; index < expected_count; index = index + 1)
                expected_write_seen[index] = 1'b0;

            for (index = 0; index < memory_count; index = index + 1) begin
                scan_result = $fscanf(vector_fd, "%s %h %h\n", tag, file_addr, file_data);
                if (scan_result != 3 || tag != "M" || file_addr[1:0] != 2'b00)
                    $fatal(1, "malformed memory entry case=%0d entry=%0d", case_id, index);
                if (file_addr[31:18] != 0)
                    $fatal(1, "test memory address outside 256KiB model: %08x", file_addr);
                spad_mem[file_addr[17:2]] = file_data;
            end
            for (index = 0; index < expected_count; index = index + 1) begin
                scan_result = $fscanf(vector_fd, "%s %h %h\n", tag, file_addr, file_data);
                if (scan_result != 3 || tag != "E" || file_addr[1:0] != 2'b00)
                    $fatal(1, "malformed expected entry case=%0d entry=%0d", case_id, index);
                expected_addr[index] = file_addr;
                expected_data[index] = file_data;
            end

            resetn = 1'b1;
            @(negedge clk);
            run_one_case(case_id, case_name);
        end
        run_abort_watchdog_priority();
        run_abort_reset_edge();
        run_max_vdot_length();
        $fclose(vector_fd);

        if (opcode_bins[0] == 0 || opcode_bins[1] == 0 || opcode_bins[2] == 0 ||
            shift_zero_bin == 0 || shift_one_bin == 0 || shift_31_bin == 0 ||
            activation_bins[0] == 0 || activation_bins[1] == 0 ||
            activation_bins[2] == 0 ||
            bias_on_bin == 0 || bias_off_bin == 0 ||
            total_read_stalls == 0 || total_write_stalls == 0 ||
            total_read_responses == 0)
            $fatal(1, "required numeric/handshake bin missing");
        $display("SCALAR_INT8_NUMERIC_PASS cases=%0d opcode_bins={vdot:%0d,gemv:%0d,gemm:%0d} shift_bins={0:%0d,1:%0d,31:%0d,other:%0d} activation_bins={none:%0d,relu:%0d,relu6:%0d} bias={off:%0d,on:%0d} read_stalls=%0d write_stalls=%0d responses=%0d",
                 total_cases, opcode_bins[0], opcode_bins[1], opcode_bins[2],
                 shift_zero_bin, shift_one_bin, shift_31_bin, shift_other_bin,
                 activation_bins[0], activation_bins[1], activation_bins[2],
                 bias_off_bin, bias_on_bin, total_read_stalls, total_write_stalls,
                 total_read_responses);
        $finish;
    end
endmodule
