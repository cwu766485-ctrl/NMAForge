    class bf16_dot_sequencer extends uvm_sequencer #(bf16_dot_item);
        `uvm_component_utils(bf16_dot_sequencer)
        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction
    endclass

    class bf16_dot_file_sequence extends uvm_sequence #(bf16_dot_item);
        string vector_file;
        int unsigned transactions_loaded;

        `uvm_object_utils(bf16_dot_file_sequence)
        function new(string name = "bf16_dot_file_sequence");
            super.new(name);
            transactions_loaded = 0;
        endfunction

        task automatic send_fault_case(fp_fault_mode_e mode,
                                       bit format_fp16,
                                       int unsigned length,
                                       bit [3:0] expected_error_code,
                                       int unsigned expected_reads,
                                       int unsigned expected_writes);
            bf16_dot_item req;
            req = bf16_dot_item::type_id::create($sformatf("fault_%0d", mode));
            start_item(req);
            req.transaction_id = transactions_loaded;
            req.format_fp16 = format_fp16;
            req.expect_error = 1;
            req.expected_error_code = expected_error_code;
            req.expected_read_count = expected_reads;
            req.expected_write_count = expected_writes;
            req.watchdog_limit = (mode == FP_FAULT_WATCHDOG) ? 1 : 256;
            req.response_jitter_max = 0;
            req.response_latency_override_cycles =
                (mode == FP_FAULT_READ_B_PARITY) ? 4 : 0;
            // Let A0 retire and A1 be accepted before the delayed B0 parity
            // response, so coverage observes two reads outstanding at the
            // parity event itself (not merely earlier in the transaction).
            req.response_latency_second_read_override_cycles =
                (mode == FP_FAULT_READ_B_PARITY) ? 8 : 0;
            req.spad_write_stall_cycles = 0;
            req.write_protection_stall_cycles = 0;
            req.check_element_count =
                (mode == FP_FAULT_READ_PARITY_LATE) ||
                (mode == FP_FAULT_READ_B_PARITY);
            if ((mode == FP_FAULT_READ_B_PROTECTION) ||
                (mode == FP_FAULT_READ_LATE_PROTECTION) ||
                (mode == FP_FAULT_READ_LATE_B_PROTECTION) ||
                (mode == FP_FAULT_READ_LATE_PROTECTION_ABORT))
                req.check_element_count = 1;
            req.expected_element_count =
                ((mode == FP_FAULT_READ_LATE_PROTECTION) ||
                 (mode == FP_FAULT_READ_LATE_B_PROTECTION)) ? 2 :
                ((mode == FP_FAULT_READ_PARITY_LATE) ? 2 :
                 ((mode == FP_FAULT_READ_LATE_PROTECTION_ABORT) ? 1 : 0));
            req.fault_mode = mode;
            req.length = length;
            req.a_bits[0] = format_fp16 ? 16'h3c00 : 16'h3f80;
            req.a_bits[1] = 16'd0; req.a_bits[2] = 16'd0; req.a_bits[3] = 16'd0;
            req.b_bits[0] = format_fp16 ? 16'h4200 : 16'h4040;
            req.b_bits[1] = 16'd0; req.b_bits[2] = 16'd0; req.b_bits[3] = 16'd0;
            req.expected_result = 32'd0;
            finish_item(req);
            transactions_loaded++;
        endtask

        task automatic send_unqualified_parity_case(bit format_fp16);
            bf16_dot_item req;
            req = bf16_dot_item::type_id::create("unqualified_parity_sideband");
            start_item(req);
            req.transaction_id = transactions_loaded;
            req.format_fp16 = format_fp16;
            req.expect_error = 0;
            req.expect_reset = 0;
            req.expected_error_code = 0;
            req.expected_read_count = 2;
            req.expected_write_count = 1;
            req.watchdog_limit = 256;
            req.response_jitter_max = 0;
            req.spad_write_stall_cycles = 0;
            req.write_protection_stall_cycles = 0;
            req.inject_busy_start = 0;
            req.inject_unqualified_parity_error = 1;
            req.fault_mode = FP_FAULT_NONE;
            req.length = 1;
            req.a_bits[0] = format_fp16 ? 16'h3c00 : 16'h3f80;
            req.a_bits[1] = 0; req.a_bits[2] = 0; req.a_bits[3] = 0;
            req.b_bits[0] = format_fp16 ? 16'h3c00 : 16'h3f80;
            req.b_bits[1] = 0; req.b_bits[2] = 0; req.b_bits[3] = 0;
            req.expected_result = 32'h3f800000;
            finish_item(req);
            transactions_loaded++;
        endtask

        task automatic send_reset_case(fp_fault_mode_e mode,
                                       bit format_fp16,
                                       int unsigned expected_reads);
            bf16_dot_item req;
            req = bf16_dot_item::type_id::create($sformatf("reset_inflight_%0d", mode));
            start_item(req);
            req.transaction_id = transactions_loaded;
            req.format_fp16 = format_fp16;
            req.expect_error = 0;
            req.expect_reset = 1;
            req.expected_read_count = expected_reads;
            req.expected_write_count = 0;
            req.watchdog_limit = 256;
            req.response_jitter_max = 0;
            req.spad_write_stall_cycles = 0;
            req.write_protection_stall_cycles = 0;
            req.fault_mode = mode;
            req.length = 2;
            req.a_bits[0] = 16'h3c00; req.a_bits[1] = 16'h3c00;
            req.a_bits[2] = 16'd0; req.a_bits[3] = 16'd0;
            req.b_bits[0] = 16'h3c00; req.b_bits[1] = 16'h3c00;
            req.b_bits[2] = 16'd0; req.b_bits[3] = 16'd0;
            req.expected_result = 32'd0;
            finish_item(req);
            transactions_loaded++;
        endtask

        task automatic send_busy_start_case(bit format_fp16);
            bf16_dot_item req;
            req = bf16_dot_item::type_id::create(
                format_fp16 ? "fp16_busy_start" : "bf16_busy_start");
            start_item(req);
            req.transaction_id = transactions_loaded;
            req.format_fp16 = format_fp16;
            req.expect_error = 0;
            req.expect_reset = 0;
            req.expected_error_code = 0;
            req.expected_read_count = 0;
            req.expected_write_count = 0;
            req.watchdog_limit = 256;
            req.response_jitter_max = 0;
            req.spad_write_stall_cycles = 0;
            req.write_protection_stall_cycles = 0;
            req.check_element_count = 0;
            req.expected_element_count = 0;
            req.inject_busy_start = 1;
            req.fault_mode = FP_FAULT_NONE;
            req.length = 1;
            req.a_bits[0] = format_fp16 ? 16'h3c00 : 16'h3f80;
            req.a_bits[1] = 0; req.a_bits[2] = 0; req.a_bits[3] = 0;
            req.b_bits[0] = format_fp16 ? 16'h3c00 : 16'h3f80;
            req.b_bits[1] = 0; req.b_bits[2] = 0; req.b_bits[3] = 0;
            req.expected_result = 32'h3f800000;
            finish_item(req);
            transactions_loaded++;
        endtask

        task automatic send_slot_reuse_case(bit format_fp16);
            bf16_dot_item req;
            req = bf16_dot_item::type_id::create(
                format_fp16 ? "fp16_slot_reuse" : "bf16_slot_reuse");
            start_item(req);
            req.transaction_id = transactions_loaded;
            req.format_fp16 = format_fp16;
            req.expect_error = 0;
            req.expect_reset = 0;
            req.expected_error_code = 0;
            req.expected_read_count = 6;
            req.expected_write_count = 1;
            req.watchdog_limit = 256;
            req.response_jitter_max = 0;
            req.spad_write_stall_cycles = 0;
            req.write_protection_stall_cycles = 0;
            req.check_element_count = 1;
            req.expected_element_count = 6;
            req.inject_busy_start = 0;
            req.inject_unqualified_parity_error = 0;
            req.force_zero_request_stall = 1;
            req.fault_mode = FP_FAULT_NONE;
            req.length = 6;
            for (int unsigned i = 0; i < req.length; i++) begin
                req.a_bits[i] = format_fp16 ? 16'h3c00 : 16'h3f80;
                req.b_bits[i] = format_fp16 ? 16'h3c00 : 16'h3f80;
            end
            req.expected_result = 32'h40c00000; // six products of 1.0
            finish_item(req);
            transactions_loaded++;
        endtask

        task automatic send_watchdog_boundary_case(bit format_fp16,
                                                    bit disabled_watchdog);
            bf16_dot_item req;
            req = bf16_dot_item::type_id::create(
                disabled_watchdog ? "watchdog_disabled" : "watchdog_masked_writeback");
            start_item(req);
            req.transaction_id = transactions_loaded;
            req.format_fp16 = format_fp16;
            req.expect_error = 0;
            req.expect_reset = 0;
            req.expected_error_code = 0;
            req.expected_read_count = 2;
            req.expected_write_count = 1;
            req.watchdog_limit = disabled_watchdog ? 0 : 16;
            req.response_jitter_max = 0;
            req.spad_write_stall_cycles = disabled_watchdog ? 0 : 20;
            req.write_protection_stall_cycles = disabled_watchdog ? 0 : 4;
            req.check_element_count = 1;
            req.expected_element_count = 1;
            req.inject_busy_start = 0;
            req.fault_mode = FP_FAULT_NONE;
            req.length = 1;
            req.a_bits[0] = format_fp16 ? 16'h3c00 : 16'h3f80;
            req.a_bits[1] = 0; req.a_bits[2] = 0; req.a_bits[3] = 0;
            req.b_bits[0] = format_fp16 ? 16'h3c00 : 16'h3f80;
            req.b_bits[1] = 0; req.b_bits[2] = 0; req.b_bits[3] = 0;
            req.expected_result = 32'h3f800000;
            finish_item(req);
            transactions_loaded++;
        endtask

        virtual task body();
            int fd;
            int fields;
            int unsigned n;
            int unsigned format_code;
            bit format_fp16;
            bit [15:0] a0;
            bit [15:0] a1;
            bit [15:0] a2;
            bit [15:0] a3;
            bit [15:0] a4;
            bit [15:0] a5;
            bit [15:0] a6;
            bit [15:0] a7;
            bit [15:0] a8;
            bit [15:0] a9;
            bit [15:0] a10;
            bit [15:0] a11;
            bit [15:0] a12;
            bit [15:0] a13;
            bit [15:0] a14;
            bit [15:0] a15;
            bit [15:0] b0;
            bit [15:0] b1;
            bit [15:0] b2;
            bit [15:0] b3;
            bit [15:0] b4;
            bit [15:0] b5;
            bit [15:0] b6;
            bit [15:0] b7;
            bit [15:0] b8;
            bit [15:0] b9;
            bit [15:0] b10;
            bit [15:0] b11;
            bit [15:0] b12;
            bit [15:0] b13;
            bit [15:0] b14;
            bit [15:0] b15;
            bit [31:0] expected;
            bf16_dot_item req;

            if (vector_file.len() == 0)
                `uvm_fatal("FP/SEQ", "RANDOM_VECTORS plusarg is required")
            fd = $fopen(vector_file, "r");
            if (fd == 0)
                `uvm_fatal("FP/SEQ", $sformatf("Cannot open vector file: %s", vector_file))

            while (!$feof(fd)) begin
                fields = $fscanf(fd, "%d %d %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h %h\n",
                                 format_code, n,
                                 a0,
                                 a1,
                                 a2,
                                 a3,
                                 a4,
                                 a5,
                                 a6,
                                 a7,
                                 a8,
                                 a9,
                                 a10,
                                 a11,
                                 a12,
                                 a13,
                                 a14,
                                 a15,
                                 b0,
                                 b1,
                                 b2,
                                 b3,
                                 b4,
                                 b5,
                                 b6,
                                 b7,
                                 b8,
                                 b9,
                                 b10,
                                 b11,
                                 b12,
                                 b13,
                                 b14,
                                 b15, expected);
                if (fields == 35) begin
                    if (format_code > 1)
                        `uvm_fatal("FP/SEQ", $sformatf("Invalid format selector %0d", format_code))
                    format_fp16 = (format_code == 1);
                    if ((n < 1) || (n > 16))
                        `uvm_fatal("FP/SEQ", $sformatf("Invalid vector length %0d", n))
                    req = bf16_dot_item::type_id::create(
                        $sformatf("dot_txn_%0d", transactions_loaded));
                    start_item(req);
                    req.transaction_id = transactions_loaded;
                    req.format_fp16 = format_fp16;
                    req.expect_error = 0;
                    req.expected_error_code = 0;
                    req.expected_read_count = 0;
                    req.expected_write_count = 0;
                    req.watchdog_limit = 256;
                    req.response_jitter_max = 4;
                    req.spad_write_stall_cycles = 0;
                    req.write_protection_stall_cycles = 0;
                    req.fault_mode = FP_FAULT_NONE;
                    req.length = n;
                    req.a_bits[0] = a0;
                    req.a_bits[1] = a1;
                    req.a_bits[2] = a2;
                    req.a_bits[3] = a3;
                    req.a_bits[4] = a4;
                    req.a_bits[5] = a5;
                    req.a_bits[6] = a6;
                    req.a_bits[7] = a7;
                    req.a_bits[8] = a8;
                    req.a_bits[9] = a9;
                    req.a_bits[10] = a10;
                    req.a_bits[11] = a11;
                    req.a_bits[12] = a12;
                    req.a_bits[13] = a13;
                    req.a_bits[14] = a14;
                    req.a_bits[15] = a15;
                    req.b_bits[0] = b0;
                    req.b_bits[1] = b1;
                    req.b_bits[2] = b2;
                    req.b_bits[3] = b3;
                    req.b_bits[4] = b4;
                    req.b_bits[5] = b5;
                    req.b_bits[6] = b6;
                    req.b_bits[7] = b7;
                    req.b_bits[8] = b8;
                    req.b_bits[9] = b9;
                    req.b_bits[10] = b10;
                    req.b_bits[11] = b11;
                    req.b_bits[12] = b12;
                    req.b_bits[13] = b13;
                    req.b_bits[14] = b14;
                    req.b_bits[15] = b15;
                    req.expected_result = expected;
                    req.inject_unqualified_parity_error = 0;
                    finish_item(req);
                    transactions_loaded++;
                end else if (!$feof(fd)) begin
                    $fclose(fd);
                    `uvm_fatal("FP/SEQ", $sformatf("Malformed vector row after transaction %0d (fields=%0d)",
                                                       transactions_loaded, fields))
                end
            end
            $fclose(fd);

            // Keep these as ordinary successful dot transactions: the
            // driver pulses a distinct invalid configuration while each
            // format's core is busy, and the scoreboard checks the original
            // result and traffic unchanged.
            send_busy_start_case(1'b0);
            send_busy_start_case(1'b1);
            // Deterministic two-slot fill/reuse: with zero response jitter,
            // the A read for pair 2 must wait while pair 0 is still computing,
            // even though a response frees one outstanding-read entry.
            send_slot_reuse_case(1'b0);
            send_slot_reuse_case(1'b1);
            // A zero limit disables the watchdog. A separate successful
            // command crosses the configured limit only while ST_WRITE is
            // backpressured, where watchdog expiry is intentionally masked.
            send_watchdog_boundary_case(1'b0, 1'b1);
            send_watchdog_boundary_case(1'b1, 1'b1);
            send_watchdog_boundary_case(1'b0, 1'b0);
            send_watchdog_boundary_case(1'b1, 1'b0);
            // A parity sideband without response-valid must be ignored.
            send_unqualified_parity_case(1'b0);
            send_unqualified_parity_case(1'b1);

            // Directed lifecycle/error cases deliberately follow the legal
            // numeric vectors; they are checked by the same passive monitor
            // and scoreboard, but are excluded from successful-result bins.
            send_fault_case(FP_FAULT_CONFIG, 1'b0, 0, 4'd1, 0, 0);
            send_fault_case(FP_FAULT_CONFIG, 1'b1, 0, 4'd1, 0, 0);
            send_fault_case(FP_FAULT_CONFIG_SRC0_ALIGN, 1'b0, 1, 4'd1, 0, 0);
            send_fault_case(FP_FAULT_CONFIG_SRC0_ALIGN, 1'b1, 1, 4'd1, 0, 0);
            send_fault_case(FP_FAULT_CONFIG_SRC1_ALIGN, 1'b0, 1, 4'd1, 0, 0);
            send_fault_case(FP_FAULT_CONFIG_SRC1_ALIGN, 1'b1, 1, 4'd1, 0, 0);
            send_fault_case(FP_FAULT_CONFIG_DST_ALIGN, 1'b0, 1, 4'd1, 0, 0);
            send_fault_case(FP_FAULT_CONFIG_DST_ALIGN, 1'b1, 1, 4'd1, 0, 0);
            // A and B are both already admitted by the time A's fixed-latency
            // parity response arrives; the core must drain both responses.
            // Keep later words in range so a parity response must suppress
            // an otherwise eligible next-pair request on that same cycle.
            send_fault_case(FP_FAULT_READ_PARITY, 1'b1, 4, 4'd5, 2, 0);
            send_fault_case(FP_FAULT_READ_PARITY, 1'b0, 4, 4'd5, 2, 0);
            // Use a longer command so the next pair's A read can be accepted
            // after A0 returns but before the B0 parity response. B0's longer
            // response latency exercises the two-outstanding boundary at the
            // parity event itself.
            send_fault_case(FP_FAULT_READ_B_PARITY, 1'b0, 4, 4'd5, 3, 0);
            send_fault_case(FP_FAULT_READ_B_PARITY, 1'b1, 4, 4'd5, 3, 0);
            // Inject parity on the first word of pair 1. Pair 0 is a valid
            // prefix and must still be accumulated before the error retires.
            send_fault_case(FP_FAULT_READ_PARITY_LATE, 1'b0, 4, 4'd5, 4, 0);
            send_fault_case(FP_FAULT_READ_PARITY_LATE, 1'b1, 4, 4'd5, 4, 0);
            // The same late parity boundary on the final packed word of an
            // odd-length task must retire only the complete valid prefix; the
            // padded high half is not an extra compute element.
            send_fault_case(FP_FAULT_READ_PARITY_LATE, 1'b0, 3, 4'd5, 4, 0);
            send_fault_case(FP_FAULT_READ_PARITY_LATE, 1'b1, 3, 4'd5, 4, 0);
            // Immediately follow a parity completion with a rejected config
            // to exercise the pending-error transition PARITY -> CONFIG.
            send_fault_case(FP_FAULT_CONFIG, 1'b0, 0, 4'd1, 0, 0);
            send_fault_case(FP_FAULT_READ_PROTECTION, 1'b0, 1, 4'd6, 1, 0);
            send_fault_case(FP_FAULT_READ_PROTECTION, 1'b1, 1, 4'd6, 1, 0);
            // Protection on the accepted B word is retained as an error even
            // when both returned words make the operand pair appear ready.
            send_fault_case(FP_FAULT_READ_B_PROTECTION, 1'b0, 1, 4'd6, 2, 0);
            send_fault_case(FP_FAULT_READ_B_PROTECTION, 1'b1, 1, 4'd6, 2, 0);
            // Protect the first request of pair 1 after pair 0 has been
            // admitted. The valid prefix must drain and accumulate before
            // the memory error retires.
            send_fault_case(FP_FAULT_READ_LATE_PROTECTION, 1'b0, 4, 4'd6, 3, 0);
            send_fault_case(FP_FAULT_READ_LATE_PROTECTION, 1'b1, 4, 4'd6, 3, 0);
            // Fail the B word of pair 1 after its A word was accepted. The
            // returned protected response must not let the pair compute past
            // the element cutoff; exactly the valid pair-0 prefix may retire.
            // The driver does not insert admission stall for this case so the
            // ready-but-suppressed condition is exercised before error retire.
            send_fault_case(FP_FAULT_READ_LATE_B_PROTECTION, 1'b0, 4, 4'd6, 4, 0);
            send_fault_case(FP_FAULT_READ_LATE_B_PROTECTION, 1'b1, 4, 4'd6, 4, 0);
            // A later abort stops the remaining prefix, while first-error
            // priority retains the already captured protection error.
            send_fault_case(FP_FAULT_READ_LATE_PROTECTION_ABORT, 1'b0, 4, 4'd6, 3, 0);
            send_fault_case(FP_FAULT_READ_LATE_PROTECTION_ABORT, 1'b1, 4, 4'd6, 3, 0);
            send_fault_case(FP_FAULT_ABORT_WAIT_A, 1'b1, 1, 4'd3, 1, 0);
            send_fault_case(FP_FAULT_ABORT_WAIT_A, 1'b0, 1, 4'd3, 1, 0);
            // No successful command is inserted between these transactions:
            // preserve the retired abort code until the next start validates.
            send_fault_case(FP_FAULT_CONFIG, 1'b1, 0, 4'd1, 0, 0);
            send_fault_case(FP_FAULT_WATCHDOG, 1'b0, 1, 4'd4, 1, 0);
            send_fault_case(FP_FAULT_WATCHDOG, 1'b1, 1, 4'd4, 1, 0);
            // Exercise WATCHDOG -> CONFIG on the next accepted start.
            send_fault_case(FP_FAULT_CONFIG, 1'b0, 0, 4'd1, 0, 0);
            send_fault_case(FP_FAULT_ABORT_CALC, 1'b1, 1, 4'd3, 2, 0);
            send_fault_case(FP_FAULT_ABORT_CALC, 1'b0, 1, 4'd3, 2, 0);
            send_fault_case(FP_FAULT_WRITE_PROTECTION, 1'b0, 1, 4'd6, 2, 1);
            send_fault_case(FP_FAULT_WRITE_PROTECTION, 1'b1, 1, 4'd6, 2, 1);
            // Exercise PROTECTION -> CONFIG after a write-protection retire.
            send_fault_case(FP_FAULT_CONFIG, 1'b1, 0, 4'd1, 0, 0);
            send_fault_case(FP_FAULT_ABORT_UNACCEPTED_A, 1'b1, 1, 4'd3, 0, 0);
            send_fault_case(FP_FAULT_ABORT_UNACCEPTED_A, 1'b0, 1, 4'd3, 0, 0);
            send_fault_case(FP_FAULT_ABORT_UNACCEPTED_B, 1'b0, 1, 4'd3, 1, 0);
            send_fault_case(FP_FAULT_ABORT_UNACCEPTED_B, 1'b1, 1, 4'd3, 1, 0);
            // Exercise asynchronous reset from every active lifecycle state.
            send_reset_case(FP_FAULT_RESET_READ_A, 1'b0, 0);
            send_reset_case(FP_FAULT_RESET_READ_A, 1'b1, 0);
            send_reset_case(FP_FAULT_RESET_WAIT_A, 1'b0, 1);
            send_reset_case(FP_FAULT_RESET_WAIT_A, 1'b1, 1);
            send_reset_case(FP_FAULT_RESET_READ_B, 1'b0, 1);
            send_reset_case(FP_FAULT_RESET_READ_B, 1'b1, 1);
            send_reset_case(FP_FAULT_RESET_WAIT_B, 1'b0, 2);
            send_reset_case(FP_FAULT_RESET_WAIT_B, 1'b1, 2);
            send_reset_case(FP_FAULT_RESET_CALC, 1'b0, 2);
            send_reset_case(FP_FAULT_RESET_CALC, 1'b1, 2);
            send_reset_case(FP_FAULT_RESET_WRITE, 1'b0, 2);
            send_reset_case(FP_FAULT_RESET_WRITE, 1'b1, 2);

            if (transactions_loaded < 20)
                `uvm_fatal("FP/SEQ", $sformatf("Only %0d vectors loaded; expected >= 20",
                                                  transactions_loaded))
            `uvm_info("FP/SEQ", $sformatf("Loaded %0d mixed-dot transactions including directed error cases from %s",
                                             transactions_loaded, vector_file), UVM_LOW)
        endtask
    endclass
