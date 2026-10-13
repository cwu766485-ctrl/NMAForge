    class bf16_dot_scoreboard extends uvm_component;
        uvm_analysis_imp_exp #(bf16_dot_item, bf16_dot_scoreboard) expected_export;
        uvm_analysis_imp_obs #(bf16_dot_observed_item, bf16_dot_scoreboard) observed_export;
        uvm_analysis_port #(bf16_dot_cov_item) coverage_ap;
        bf16_dot_item expected_q[$];
        bf16_dot_observed_item observed_q[$];
        int unsigned expected_seen;
        int unsigned compared;

        `uvm_component_utils(bf16_dot_scoreboard)
        function new(string name, uvm_component parent);
            super.new(name, parent);
            expected_export = new("expected_export", this);
            observed_export = new("observed_export", this);
            coverage_ap = new("coverage_ap", this);
            expected_seen = 0;
            compared = 0;
        endfunction

        virtual function void write_exp(bf16_dot_item t);
            bf16_dot_item copy;
            copy = bf16_dot_item::type_id::create("expected_copy");
            copy.copy_fields(t);
            expected_q.push_back(copy);
            expected_seen++;
            compare_available();
        endfunction

        virtual function void write_obs(bf16_dot_observed_item t);
            bf16_dot_observed_item copy;
            copy = bf16_dot_observed_item::type_id::create("observed_copy");
            copy.copy_fields(t);
            observed_q.push_back(copy);
            compare_available();
        endfunction

        function void compare_available();
            bf16_dot_item exp;
            bf16_dot_observed_item obs;
            bf16_dot_cov_item cov;
            int unsigned required_reads;
            while ((expected_q.size() != 0) && (observed_q.size() != 0)) begin
                exp = expected_q.pop_front();
                obs = observed_q.pop_front();
                if (obs.transaction_id != exp.transaction_id)
                    `uvm_error("BF16/SB", $sformatf("Transaction ID mismatch expected=%0d observed=%0d",
                                                     exp.transaction_id, obs.transaction_id))
                if (obs.length != exp.length)
                    `uvm_error("BF16/SB", $sformatf("tx%0d length mismatch expected=%0d observed=%0d",
                                                     exp.transaction_id, exp.length, obs.length))
                if (obs.format_fp16 != exp.format_fp16)
                    `uvm_error("FP/SB", $sformatf("tx%0d format mismatch expected_fp16=%0d observed_fp16=%0d",
                                                   exp.transaction_id, exp.format_fp16,
                                                   obs.format_fp16))
                if (obs.protocol_error)
                    `uvm_error("BF16/SB", $sformatf("tx%0d SPAD address protocol check failed", exp.transaction_id))
                if (exp.expect_reset) begin
                    if (!obs.reset_abort || obs.error || (obs.error_code != 0) ||
                        (obs.read_count != exp.expected_read_count) ||
                        (obs.write_count != exp.expected_write_count) ||
                        obs.protocol_error)
                        `uvm_error("FP/SB", $sformatf("tx%0d reset outcome mismatch reset=%0d error=%0d code=%0d reads=%0d writes=%0d protocol_error=%0d",
                                                       exp.transaction_id, obs.reset_abort,
                                                       obs.error, obs.error_code,
                                                       obs.read_count, obs.write_count,
                                                       obs.protocol_error))
                    else begin
                        compared++;
                        `uvm_info("FP/SB", $sformatf("PASS in-flight reset tx%0d reads=%0d writes=%0d",
                                                      exp.transaction_id, obs.read_count,
                                                      obs.write_count), UVM_LOW)
                    end
                end else if (exp.expect_error) begin
                    if (!obs.error || (obs.error_code != exp.expected_error_code))
                        `uvm_error("FP/SB", $sformatf("tx%0d expected error code=%0d observed error=%0d code=%0d",
                                                       exp.transaction_id, exp.expected_error_code,
                                                       obs.error, obs.error_code))
                    if ((obs.read_count != exp.expected_read_count) ||
                        (obs.write_count != exp.expected_write_count))
                        `uvm_error("FP/SB", $sformatf("tx%0d error traffic mismatch reads=%0d/%0d writes=%0d/%0d",
                                                       exp.transaction_id, obs.read_count,
                                                       exp.expected_read_count, obs.write_count,
                                                       exp.expected_write_count))
                    if (obs.error && (obs.error_code == exp.expected_error_code) &&
                        !obs.protocol_error &&
                        (obs.read_count == exp.expected_read_count) &&
                        (obs.write_count == exp.expected_write_count)) begin
                        compared++;
                        `uvm_info("FP/SB", $sformatf("PASS expected error tx%0d code=%0d reads=%0d writes=%0d",
                                                      exp.transaction_id, obs.error_code,
                                                      obs.read_count, obs.write_count), UVM_LOW)
                    end
                end else begin
                    required_reads = 2 * ((exp.length + 1) / 2);
                    if (obs.error || (obs.error_code != 0))
                        `uvm_error("BF16/SB", $sformatf("tx%0d unexpected engine error=%0d code=%0d",
                                                         exp.transaction_id, obs.error, obs.error_code))
                    if (obs.read_count != required_reads)
                        `uvm_error("BF16/SB", $sformatf("tx%0d read count=%0d expected=%0d",
                                                         exp.transaction_id, obs.read_count, required_reads))
                    if (obs.write_count != 1)
                        `uvm_error("BF16/SB", $sformatf("tx%0d write count=%0d expected=1",
                                                         exp.transaction_id, obs.write_count))
                    if ((obs.write_address != BF16_DOT_DST_BASE) ||
                        (obs.write_data !== exp.expected_result) ||
                        (obs.result !== exp.expected_result))
                        `uvm_error("BF16/SB", $sformatf("tx%0d result mismatch expected=%08x write=(%08x,%08x) result=%08x",
                                                         exp.transaction_id, exp.expected_result,
                                                         obs.write_address, obs.write_data, obs.result))
                    if (obs.element_count != exp.length)
                        `uvm_error("BF16/SB", $sformatf("tx%0d element_count=%0d expected=%0d",
                                                         exp.transaction_id, obs.element_count, exp.length))
                    if (!obs.error && (obs.error_code == 0) && !obs.protocol_error &&
                        (obs.format_fp16 == exp.format_fp16) &&
                        (obs.read_count == required_reads) && (obs.write_count == 1) &&
                        (obs.write_address == BF16_DOT_DST_BASE) &&
                        (obs.write_data === exp.expected_result) &&
                        (obs.result === exp.expected_result) &&
                        (obs.element_count == exp.length)) begin
                        cov = bf16_dot_cov_item::type_id::create("coverage_sample");
                        cov.format_fp16 = exp.format_fp16;
                        cov.length = exp.length;
                        cov.stall_cycles = obs.stall_cycles;
                        cov.max_outstanding_reads = obs.max_outstanding_reads;
                        foreach (exp.a_bits[i]) begin
                            cov.a_bits[i] = exp.a_bits[i];
                            cov.b_bits[i] = exp.b_bits[i];
                        end
                        coverage_ap.write(cov);
                        compared++;
                        `uvm_info("BF16/SB", $sformatf("PASS tx%0d len=%0d result=%08x stalls=%0d",
                                                         exp.transaction_id, exp.length,
                                                         exp.expected_result, obs.stall_cycles), UVM_LOW)
                    end
                end
            end
        endfunction

        virtual function void check_phase(uvm_phase phase);
            super.check_phase(phase);
            if ((expected_q.size() != 0) || (observed_q.size() != 0))
                `uvm_error("BF16/SB", $sformatf("Unmatched transactions expected_q=%0d observed_q=%0d",
                                                 expected_q.size(), observed_q.size()))
            if ((expected_seen == 0) || (compared != expected_seen))
                `uvm_error("BF16/SB", $sformatf("Scoreboard completion mismatch expected=%0d compared=%0d",
                                                 expected_seen, compared))
            else
                `uvm_info("BF16/SB", $sformatf("Scoreboard PASS: %0d/%0d bit-exact transactions",
                                                compared, expected_seen), UVM_LOW)
        endfunction
    endclass
