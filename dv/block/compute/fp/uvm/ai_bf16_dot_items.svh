    class bf16_dot_item extends uvm_sequence_item;
        int unsigned transaction_id;
        bit format_fp16;
        bit expect_error;
        bit expect_reset;
        bit [3:0] expected_error_code;
        int unsigned expected_read_count;
        int unsigned expected_write_count;
        int unsigned watchdog_limit;
        int unsigned response_jitter_max;
        int unsigned response_latency_override_cycles;
        int unsigned response_latency_second_read_override_cycles;
        int unsigned spad_write_stall_cycles;
        int unsigned write_protection_stall_cycles;
        bit check_element_count;
        int unsigned expected_element_count;
        bit inject_busy_start;
        bit inject_unqualified_parity_error;
        bit force_zero_request_stall;
        fp_fault_mode_e fault_mode;
        int unsigned length;
        bit [15:0] a_bits[16];
        bit [15:0] b_bits[16];
        bit [31:0] expected_result;

        `uvm_object_utils(bf16_dot_item)
        function new(string name = "bf16_dot_item");
            super.new(name);
        endfunction
        function void copy_fields(bf16_dot_item rhs);
            transaction_id = rhs.transaction_id;
            format_fp16 = rhs.format_fp16;
            expect_error = rhs.expect_error;
            expect_reset = rhs.expect_reset;
            expected_error_code = rhs.expected_error_code;
            expected_read_count = rhs.expected_read_count;
            expected_write_count = rhs.expected_write_count;
            watchdog_limit = rhs.watchdog_limit;
            response_jitter_max = rhs.response_jitter_max;
            response_latency_override_cycles = rhs.response_latency_override_cycles;
            response_latency_second_read_override_cycles =
                rhs.response_latency_second_read_override_cycles;
            spad_write_stall_cycles = rhs.spad_write_stall_cycles;
            write_protection_stall_cycles = rhs.write_protection_stall_cycles;
            check_element_count = rhs.check_element_count;
            expected_element_count = rhs.expected_element_count;
            inject_busy_start = rhs.inject_busy_start;
            inject_unqualified_parity_error = rhs.inject_unqualified_parity_error;
            force_zero_request_stall = rhs.force_zero_request_stall;
            fault_mode = rhs.fault_mode;
            length = rhs.length;
            expected_result = rhs.expected_result;
            foreach (a_bits[i]) begin
                a_bits[i] = rhs.a_bits[i];
                b_bits[i] = rhs.b_bits[i];
            end
        endfunction
    endclass

    class bf16_dot_observed_item extends uvm_sequence_item;
        int unsigned transaction_id;
        bit format_fp16;
        int unsigned length;
        int unsigned read_count;
        int unsigned max_outstanding_reads;
        int unsigned parity_response_outstanding_reads;
        int unsigned max_response_latency;
        int unsigned write_count;
        int unsigned write_stall_cycles;
        int unsigned write_protection_stall_cycles;
        int unsigned element_count;
        int unsigned busy_start_count;
        int unsigned stall_cycles;
        bit [31:0] result;
        bit [31:0] write_address;
        bit [31:0] write_data;
        bit error;
        bit [3:0] error_code;
        bit protocol_error;
        bit reset_abort;

        `uvm_object_utils(bf16_dot_observed_item)
        function new(string name = "bf16_dot_observed_item");
            super.new(name);
        endfunction
        function void copy_fields(bf16_dot_observed_item rhs);
            transaction_id = rhs.transaction_id;
            format_fp16 = rhs.format_fp16;
            length = rhs.length;
            read_count = rhs.read_count;
            max_outstanding_reads = rhs.max_outstanding_reads;
            parity_response_outstanding_reads = rhs.parity_response_outstanding_reads;
            max_response_latency = rhs.max_response_latency;
            write_count = rhs.write_count;
            write_stall_cycles = rhs.write_stall_cycles;
            write_protection_stall_cycles = rhs.write_protection_stall_cycles;
            element_count = rhs.element_count;
            busy_start_count = rhs.busy_start_count;
            stall_cycles = rhs.stall_cycles;
            result = rhs.result;
            write_address = rhs.write_address;
            write_data = rhs.write_data;
            error = rhs.error;
            error_code = rhs.error_code;
            protocol_error = rhs.protocol_error;
            reset_abort = rhs.reset_abort;
        endfunction
    endclass

    class bf16_dot_cov_item extends uvm_sequence_item;
        bit format_fp16;
        int unsigned length;
        bit expect_error;
        bit expect_reset;
        fp_fault_mode_e fault_mode;
        int unsigned busy_start_count;
        bit [15:0] a_bits[16];
        bit [15:0] b_bits[16];
        int unsigned stall_cycles;
        int unsigned max_outstanding_reads;
        int unsigned parity_response_outstanding_reads;
        int unsigned max_response_latency;
        int unsigned watchdog_limit;
        int unsigned expected_write_stall_cycles;
        int unsigned observed_write_stall_cycles;

        `uvm_object_utils(bf16_dot_cov_item)
        function new(string name = "bf16_dot_cov_item");
            super.new(name);
        endfunction
    endclass
