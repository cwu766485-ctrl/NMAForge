    class bf16_dot_driver extends uvm_driver #(bf16_dot_item);
        virtual ai_bf16_dot_if vif;
        uvm_analysis_port #(bf16_dot_item) expected_ap;
        bit [31:0] spad_mem[0:255];
        int unsigned no_stall_transactions;
        int unsigned stalled_transactions;

        `uvm_component_utils(bf16_dot_driver)
        function new(string name, uvm_component parent);
            super.new(name, parent);
            expected_ap = new("expected_ap", this);
            no_stall_transactions = 0;
            stalled_transactions = 0;
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db #(virtual ai_bf16_dot_if)::get(this, "", "vif", vif))
                `uvm_fatal("BF16/DRV", "Virtual interface ai_bf16_dot_if was not configured")
        endfunction

        task automatic drive_spad_transaction(bf16_dot_item req);
            int unsigned stall_left;
            int unsigned bfm_cycle;
            int unsigned rsp_count;
            int unsigned rsp_head;
            int unsigned rsp_tail;
            int unsigned rsp_due [0:3];
            bit [31:0] rsp_data [0:3];
            bit request_seen;
            int unsigned word_index;
            int unsigned accepted_reads;
            int unsigned responses_delivered;
            bit parity_injected;
            bit read_protection_injected;
            bit write_protection_injected;
            bit abort_injected;
            bit reset_injected;
            bit reset_condition;

            request_seen = 0;
            bfm_cycle = 0;
            rsp_count = 0;
            rsp_head = 0;
            rsp_tail = 0;
            stall_left = 0;
            accepted_reads = 0;
            responses_delivered = 0;
            parity_injected = 0;
            read_protection_injected = 0;
            write_protection_injected = 0;
            abort_injected = 0;
            reset_injected = 0;
            wait (vif.start === 1'b1);
            while ((vif.done !== 1'b1) && !reset_injected) begin
                @(negedge vif.clk);
                vif.abort = 1'b0;
                vif.spad_ready = 1'b0;
                vif.spad_rsp_valid = 1'b0;
                vif.spad_parity_error = 1'b0;
                vif.spad_protection_error = 1'b0;
                bfm_cycle++;

                if (((req.fault_mode == FP_FAULT_ABORT_WAIT_A) &&
                     (accepted_reads == 1) && !abort_injected) ||
                    ((req.fault_mode == FP_FAULT_ABORT_CALC) &&
                     (responses_delivered == 2) && !abort_injected) ||
                    ((req.fault_mode == FP_FAULT_ABORT_UNACCEPTED_A) &&
                     (accepted_reads == 0) && vif.spad_valid &&
                     !vif.spad_write && !abort_injected) ||
                    ((req.fault_mode == FP_FAULT_ABORT_UNACCEPTED_B) &&
                     (accepted_reads == 1) && (responses_delivered == 1) &&
                     vif.spad_valid && !vif.spad_write && !abort_injected)) begin
                    vif.abort = 1'b1;
                    abort_injected = 1;
                end

                reset_condition = 0;
                case (req.fault_mode)
                    FP_FAULT_RESET_READ_A:
                        reset_condition = (accepted_reads == 0) &&
                                          vif.spad_valid && !vif.spad_write;
                    FP_FAULT_RESET_WAIT_A:
                        reset_condition = (accepted_reads == 1) &&
                                          (responses_delivered == 0);
                    FP_FAULT_RESET_READ_B:
                        reset_condition = (accepted_reads == 1) &&
                                          (responses_delivered == 1) &&
                                          vif.spad_valid && !vif.spad_write;
                    FP_FAULT_RESET_WAIT_B:
                        reset_condition = (accepted_reads == 2) &&
                                          (responses_delivered == 1);
                    FP_FAULT_RESET_CALC:
                        reset_condition = (accepted_reads == 2) &&
                                          (responses_delivered == 2);
                    FP_FAULT_RESET_WRITE:
                        reset_condition = vif.spad_valid && vif.spad_write;
                    default: reset_condition = 0;
                endcase
                if (reset_condition && !reset_injected) begin
                    vif.reset_force = 1'b1;
                    reset_injected = 1;
                    #1;
                    if ((vif.busy !== 1'b0) || (vif.done !== 1'b0) ||
                        (vif.spad_valid !== 1'b0))
                        `uvm_error("FP/DRV", "In-flight reset did not clear busy/done/SPAD request")
                    @(posedge vif.clk);
                    @(negedge vif.clk);
                    vif.reset_force = 1'b0;
                    rsp_count = 0;
                    rsp_head = 0;
                    rsp_tail = 0;
                    break;
                end

                if ((rsp_count != 0) && (bfm_cycle >= rsp_due[rsp_head])) begin
                    vif.spad_rsp_valid = 1'b1;
                    vif.spad_rdata = rsp_data[rsp_head];
                        if ((((req.fault_mode == FP_FAULT_READ_PARITY) &&
                              (responses_delivered == 0)) ||
                             ((req.fault_mode == FP_FAULT_READ_B_PARITY) &&
                              (responses_delivered == 1))) &&
                            !parity_injected) begin
                            vif.spad_parity_error = 1'b1;
                            parity_injected = 1;
                        end
                    rsp_head = (rsp_head == 3) ? 0 : rsp_head + 1;
                    rsp_count--;
                end

                if (vif.spad_valid) begin
                    if (!request_seen) begin
                        request_seen = 1;
                        stall_left = ((req.transaction_id % 4) == 0) ? 0 :
                                     $urandom_range(1, 3);
                        if (req.fault_mode == FP_FAULT_WATCHDOG)
                            stall_left = 0;
                        if ((req.fault_mode == FP_FAULT_READ_PARITY) ||
                            (req.fault_mode == FP_FAULT_READ_B_PARITY) ||
                            (req.fault_mode == FP_FAULT_READ_PROTECTION))
                            stall_left = 0;
                        if ((req.fault_mode == FP_FAULT_RESET_READ_B) &&
                            (accepted_reads == 1) &&
                            (responses_delivered == 0))
                            stall_left = 4;
                        if ((req.fault_mode == FP_FAULT_ABORT_UNACCEPTED_A) ||
                            (req.fault_mode == FP_FAULT_ABORT_UNACCEPTED_B))
                            stall_left = 2;
                    end
                    if (stall_left == 0) begin
                        vif.spad_ready = 1'b1;
                        if ((req.fault_mode == FP_FAULT_READ_PROTECTION) &&
                            !vif.spad_write && !read_protection_injected) begin
                            vif.spad_protection_error = 1'b1;
                            read_protection_injected = 1;
                        end
                        if ((req.fault_mode == FP_FAULT_WRITE_PROTECTION) &&
                            vif.spad_write && !write_protection_injected) begin
                            vif.spad_protection_error = 1'b1;
                            write_protection_injected = 1;
                        end
                    end else
                        stall_left--;
                end else begin
                    request_seen = 0;
                end

                @(posedge vif.clk);
                if (vif.spad_valid && vif.spad_ready) begin
                    if (vif.spad_addr[31:2] >= 256)
                        `uvm_fatal("BF16/DRV", $sformatf("SPAD address out of model range: %08x", vif.spad_addr))
                    word_index = vif.spad_addr[9:2];
                    if (vif.spad_write) begin
                        if (!vif.spad_protection_error)
                            spad_mem[word_index] = vif.spad_wdata;
                    end else begin
                        accepted_reads++;
                        if (rsp_count >= 4)
                            `uvm_fatal("BF16/DRV", "Ordered response queue overflow")
                        rsp_data[rsp_tail] = spad_mem[word_index];
                        rsp_due[rsp_tail] = bfm_cycle + 2;
                        rsp_tail = (rsp_tail == 3) ? 0 : rsp_tail + 1;
                        rsp_count++;
                    end
                    request_seen = 0;
                end
                if (vif.spad_rsp_valid)
                    responses_delivered++;
                if (vif.done === 1'b1)
                    break;
            end
            @(negedge vif.clk);
            vif.spad_ready = 1'b0;
            vif.spad_rsp_valid = 1'b0;
        endtask

        virtual task run_phase(uvm_phase phase);
            bf16_dot_item req;
            bf16_dot_item expected;
            int unsigned i;
            int unsigned timeout_cycles;

            vif.start = 0;
            vif.reset_force = 0;
            vif.format_fp16 = 0;
            vif.abort = 0;
            vif.src0_base = BF16_DOT_SRC0_BASE;
            vif.src1_base = BF16_DOT_SRC1_BASE;
            vif.dst_base = BF16_DOT_DST_BASE;
            vif.length = 0;
            vif.watchdog_limit = 0;
            vif.spad_ready = 0;
            vif.spad_rsp_valid = 0;
            vif.spad_rdata = 0;
            vif.spad_parity_error = 0;
            vif.spad_protection_error = 0;
            foreach (spad_mem[i]) spad_mem[i] = 0;

            wait (vif.resetn === 1'b1);
            forever begin
                seq_item_port.get_next_item(req);
                expected = bf16_dot_item::type_id::create("expected_copy");
                expected.copy_fields(req);
                expected_ap.write(expected);

                spad_mem[BF16_DOT_SRC0_BASE[9:2]] = {req.a_bits[1], req.a_bits[0]};
                spad_mem[BF16_DOT_SRC0_BASE[9:2] + 1] = {req.a_bits[3], req.a_bits[2]};
                spad_mem[BF16_DOT_SRC1_BASE[9:2]] = {req.b_bits[1], req.b_bits[0]};
                spad_mem[BF16_DOT_SRC1_BASE[9:2] + 1] = {req.b_bits[3], req.b_bits[2]};

                vif.src0_base = BF16_DOT_SRC0_BASE;
                vif.src1_base = BF16_DOT_SRC1_BASE;
                vif.dst_base = BF16_DOT_DST_BASE;
                vif.length = req.length[15:0];
                vif.format_fp16 = req.format_fp16;
                vif.watchdog_limit = (req.fault_mode == FP_FAULT_WATCHDOG) ?
                                     32'd1 : 32'd256;
                vif.abort = 0;

                fork
                    drive_spad_transaction(req);
                    begin
                        @(negedge vif.clk);
                        vif.start = 1;
                        @(negedge vif.clk);
                        vif.start = 0;
                        timeout_cycles = 0;
                        while ((vif.done !== 1'b1) &&
                               !(req.expect_reset && (vif.resetn === 1'b0)) &&
                               (timeout_cycles < 256)) begin
                            @(posedge vif.clk);
                            timeout_cycles++;
                        end
                        if (req.expect_reset) begin
                            if ((vif.resetn !== 1'b0) || (vif.busy !== 1'b0) ||
                                (vif.done !== 1'b0) || (vif.spad_valid !== 1'b0))
                                `uvm_fatal("FP/DRV", "Reset case did not asynchronously quiesce the core")
                        end else if (vif.done !== 1'b1)
                            `uvm_fatal("BF16/DRV", $sformatf("Timeout on transaction %0d", req.transaction_id))
                    end
                join

                if ((req.transaction_id % 4) == 0) no_stall_transactions++;
                else stalled_transactions++;
                seq_item_port.item_done();
            end
        endtask
    endclass
