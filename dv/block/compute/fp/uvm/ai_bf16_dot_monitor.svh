    class bf16_dot_monitor extends uvm_component;
        virtual ai_bf16_dot_if vif;
        uvm_analysis_port #(bf16_dot_observed_item) observed_ap;
        int unsigned next_transaction_id;
        int unsigned outstanding_reads;
        bf16_dot_observed_item current;

        `uvm_component_utils(bf16_dot_monitor)
        function new(string name, uvm_component parent);
            super.new(name, parent);
            observed_ap = new("observed_ap", this);
            next_transaction_id = 0;
            outstanding_reads = 0;
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            if (!uvm_config_db #(virtual ai_bf16_dot_if)::get(this, "", "vif", vif))
                `uvm_fatal("BF16/MON", "Virtual interface ai_bf16_dot_if was not configured")
        endfunction

        virtual task run_phase(uvm_phase phase);
            int unsigned expected_word;
            bit [31:0] expected_address;
            wait (vif.resetn === 1'b1);
            forever begin
                @(posedge vif.clk or negedge vif.resetn);
                if (!vif.resetn) begin
                    if (current != null) begin
                        current.reset_abort = 1'b1;
                        observed_ap.write(current);
                        `uvm_info("FP/MON", $sformatf("Observed reset-aborted tx%0d reads=%0d writes=%0d",
                                                       current.transaction_id, current.read_count,
                                                       current.write_count), UVM_HIGH)
                        current = null;
                        outstanding_reads = 0;
                    end
                end else begin
                if (vif.start) begin
                    current = bf16_dot_observed_item::type_id::create(
                        $sformatf("observed_%0d", next_transaction_id));
                    current.transaction_id = next_transaction_id++;
                    current.format_fp16 = vif.format_fp16;
                    current.length = vif.length;
                    current.read_count = 0;
                    current.max_outstanding_reads = 0;
                    current.write_count = 0;
                    current.element_count = 0;
                    current.stall_cycles = 0;
                    current.result = 0;
                    current.write_address = 0;
                    current.write_data = 0;
                    current.error = 0;
                    current.error_code = 0;
                    current.protocol_error = 0;
                    current.reset_abort = 0;
                    outstanding_reads = 0;
                end

                if ((current != null) && vif.spad_valid && !vif.spad_ready)
                    current.stall_cycles++;

                if ((current != null) && vif.spad_rsp_valid) begin
                    if (outstanding_reads == 0) begin
                        current.protocol_error = 1;
                        `uvm_error("BF16/MON", $sformatf("tx%0d response without accepted read",
                                                         current.transaction_id))
                    end else outstanding_reads--;
                end

                if ((current != null) && vif.spad_valid && vif.spad_ready) begin
                    if (vif.spad_write) begin
                        current.write_count++;
                        current.write_address = vif.spad_addr;
                        current.write_data = vif.spad_wdata;
                    end else begin
                        expected_word = current.read_count / 2;
                        if ((current.read_count % 2) == 0)
                            expected_address = BF16_DOT_SRC0_BASE + (expected_word * 4);
                        else
                            expected_address = BF16_DOT_SRC1_BASE + (expected_word * 4);
                        if (vif.spad_addr !== expected_address) begin
                            current.protocol_error = 1;
                            `uvm_error("BF16/MON", $sformatf("tx%0d read[%0d] addr=%08x expected=%08x",
                                                             current.transaction_id, current.read_count,
                                                             vif.spad_addr, expected_address))
                        end
                        current.read_count++;
                        outstanding_reads++;
                        if (outstanding_reads > current.max_outstanding_reads)
                            current.max_outstanding_reads = outstanding_reads;
                    end
                end

                if ((current != null) && vif.done) begin
                    current.result = vif.result;
                    current.element_count = vif.element_count;
                    current.error = vif.error;
                    current.error_code = vif.error_code;
                    observed_ap.write(current);
                    `uvm_info("BF16/MON", $sformatf("Observed tx%0d len=%0d reads=%0d writes=%0d result=%08x error=%0d",
                                                     current.transaction_id, current.length,
                                                     current.read_count, current.write_count,
                                                     current.result, current.error), UVM_HIGH)
                    current = null;
                end
                end
            end
        endtask
    endclass
