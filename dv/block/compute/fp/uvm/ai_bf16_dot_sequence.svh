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

        task automatic send_reset_case(fp_fault_mode_e mode,
                                       int unsigned expected_reads);
            bf16_dot_item req;
            req = bf16_dot_item::type_id::create($sformatf("reset_inflight_%0d", mode));
            start_item(req);
            req.transaction_id = transactions_loaded;
            req.format_fp16 = 1'b1;
            req.expect_error = 0;
            req.expect_reset = 1;
            req.expected_read_count = expected_reads;
            req.expected_write_count = 0;
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

        virtual task body();
            int fd;
            int fields;
            int unsigned n;
            int unsigned format_code;
            bit format_fp16;
            bit [15:0] a0, a1, a2, a3;
            bit [15:0] b0, b1, b2, b3;
            bit [31:0] expected;
            bf16_dot_item req;

            if (vector_file.len() == 0)
                `uvm_fatal("FP/SEQ", "RANDOM_VECTORS plusarg is required")
            fd = $fopen(vector_file, "r");
            if (fd == 0)
                `uvm_fatal("FP/SEQ", $sformatf("Cannot open vector file: %s", vector_file))

            while (!$feof(fd)) begin
                fields = $fscanf(fd, "%d %d %h %h %h %h %h %h %h %h %h\n",
                                 format_code, n, a0, a1, a2, a3,
                                 b0, b1, b2, b3, expected);
                if (fields == 11) begin
                    if (format_code > 1)
                        `uvm_fatal("FP/SEQ", $sformatf("Invalid format selector %0d", format_code))
                    format_fp16 = (format_code == 1);
                    if ((n < 1) || (n > 4))
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
                    req.fault_mode = FP_FAULT_NONE;
                    req.length = n;
                    req.a_bits[0] = a0; req.a_bits[1] = a1;
                    req.a_bits[2] = a2; req.a_bits[3] = a3;
                    req.b_bits[0] = b0; req.b_bits[1] = b1;
                    req.b_bits[2] = b2; req.b_bits[3] = b3;
                    req.expected_result = expected;
                    finish_item(req);
                    transactions_loaded++;
                end else if (!$feof(fd)) begin
                    $fclose(fd);
                    `uvm_fatal("FP/SEQ", $sformatf("Malformed vector row after transaction %0d (fields=%0d)",
                                                       transactions_loaded, fields))
                end
            end
            $fclose(fd);

            // Directed lifecycle/error cases deliberately follow the legal
            // numeric vectors; they are checked by the same passive monitor
            // and scoreboard, but are excluded from successful-result bins.
            send_fault_case(FP_FAULT_CONFIG, 1'b0, 0, 4'd1, 0, 0);
            send_fault_case(FP_FAULT_READ_PARITY, 1'b1, 1, 4'd5, 1, 0);
            send_fault_case(FP_FAULT_CONFIG, 1'b0, 0, 4'd1, 0, 0);
            send_fault_case(FP_FAULT_READ_B_PARITY, 1'b0, 1, 4'd5, 2, 0);
            send_fault_case(FP_FAULT_READ_PROTECTION, 1'b0, 1, 4'd6, 1, 0);
            send_fault_case(FP_FAULT_CONFIG, 1'b0, 0, 4'd1, 0, 0);
            send_fault_case(FP_FAULT_ABORT_WAIT_A, 1'b1, 1, 4'd3, 1, 0);
            send_fault_case(FP_FAULT_CONFIG, 1'b0, 0, 4'd1, 0, 0);
            send_fault_case(FP_FAULT_WATCHDOG, 1'b0, 1, 4'd4, 1, 0);
            send_fault_case(FP_FAULT_CONFIG, 1'b0, 0, 4'd1, 0, 0);
            send_fault_case(FP_FAULT_ABORT_CALC, 1'b1, 1, 4'd3, 2, 0);
            send_fault_case(FP_FAULT_WRITE_PROTECTION, 1'b0, 1, 4'd6, 2, 1);
            send_fault_case(FP_FAULT_ABORT_UNACCEPTED_A, 1'b1, 1, 4'd3, 0, 0);
            send_fault_case(FP_FAULT_ABORT_UNACCEPTED_B, 1'b0, 1, 4'd3, 1, 0);
            // Exercise asynchronous reset from every active lifecycle state.
            send_reset_case(FP_FAULT_RESET_READ_A, 0);
            send_reset_case(FP_FAULT_RESET_WAIT_A, 1);
            send_reset_case(FP_FAULT_RESET_READ_B, 1);
            send_reset_case(FP_FAULT_RESET_WAIT_B, 2);
            send_reset_case(FP_FAULT_RESET_CALC, 2);
            send_reset_case(FP_FAULT_RESET_WRITE, 2);

            if (transactions_loaded < 20)
                `uvm_fatal("FP/SEQ", $sformatf("Only %0d vectors loaded; expected >= 20",
                                                  transactions_loaded))
            `uvm_info("FP/SEQ", $sformatf("Loaded %0d mixed-dot transactions including directed error cases from %s",
                                             transactions_loaded, vector_file), UVM_LOW)
        endtask
    endclass
