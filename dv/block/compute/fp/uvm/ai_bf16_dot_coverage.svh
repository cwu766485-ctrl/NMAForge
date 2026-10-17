    // Historical component name retained to keep the existing UVM agent
    // stable; samples and bins now cover both BF16 and FP16 dot modes.
    class bf16_dot_coverage extends uvm_subscriber #(bf16_dot_cov_item);
        int unsigned format_hits[2];
        int unsigned format_length_hits[2][17];
        int unsigned format_class_hits[2][5];
        int unsigned format_sign_hits[2][2];
        int unsigned format_stall_hits[2][2];
        int unsigned transactions_sampled;
        int unsigned fault_transactions_sampled;
        int unsigned max_outstanding_reads_seen;
        int unsigned watchdog_disabled_hits[2];
        int unsigned watchdog_write_stall_hits[2];
        int unsigned response_latency_hits[2][2];
        int unsigned parity_overlap_hits[2][3];

        covergroup busy_start_cg with function sample(int unsigned format,
                                                       int unsigned busy_start_count);
            cp_busy_start_format: coverpoint format {
                bins bf16 = {0}; bins fp16 = {1};
            }
            cp_busy_start_count: coverpoint busy_start_count {
                bins none = {0}; bins one_ignored_pulse = {1};
                illegal_bins multiple = {[2:$]};
            }
            busy_start_format_cross: cross cp_busy_start_format,
                                          cp_busy_start_count;
        endgroup

        covergroup dot_cg with function sample(int unsigned format,
                                                int unsigned length,
                                                int unsigned op_class,
                                                int unsigned sign,
                                                int unsigned stalled);
            cp_format: coverpoint format {
                bins bf16 = {0}; bins fp16 = {1};
            }
            cp_length: coverpoint length {
                bins length[16] = {[1:16]};
            }
            cp_class: coverpoint op_class {
                bins zero = {0}; bins subnormal = {1}; bins normal = {2};
                bins infinity = {3}; bins nan = {4};
            }
            cp_sign: coverpoint sign { bins positive = {0}; bins negative = {1}; }
            cp_backpressure: coverpoint stalled { bins none = {0}; bins present = {1}; }
            format_length_cross: cross cp_format, cp_length;
            format_class_cross: cross cp_format, cp_class;
        endgroup

        covergroup fault_cg with function sample(int unsigned format,
                                                  int unsigned fault_mode);
            cp_fault_format: coverpoint format {
                bins bf16 = {0}; bins fp16 = {1};
            }
            cp_fault_mode: coverpoint fault_mode {
                bins invalid_config = {FP_FAULT_CONFIG};
                bins misaligned_src0 = {FP_FAULT_CONFIG_SRC0_ALIGN};
                bins misaligned_src1 = {FP_FAULT_CONFIG_SRC1_ALIGN};
                bins misaligned_dst = {FP_FAULT_CONFIG_DST_ALIGN};
                bins read_a_parity = {FP_FAULT_READ_PARITY};
                bins read_b_parity = {FP_FAULT_READ_B_PARITY};
                bins late_word_parity = {FP_FAULT_READ_PARITY_LATE};
                bins read_protection = {FP_FAULT_READ_PROTECTION};
                bins read_b_protection = {FP_FAULT_READ_B_PROTECTION};
                bins late_read_protection = {FP_FAULT_READ_LATE_PROTECTION};
                bins late_read_b_protection = {FP_FAULT_READ_LATE_B_PROTECTION};
                bins late_read_protection_abort = {FP_FAULT_READ_LATE_PROTECTION_ABORT};
                bins abort_wait_a = {FP_FAULT_ABORT_WAIT_A};
                bins watchdog = {FP_FAULT_WATCHDOG};
                bins write_protection = {FP_FAULT_WRITE_PROTECTION};
                bins abort_calc = {FP_FAULT_ABORT_CALC};
                bins reset_read_a = {FP_FAULT_RESET_READ_A};
                bins reset_wait_a = {FP_FAULT_RESET_WAIT_A};
                bins reset_read_b = {FP_FAULT_RESET_READ_B};
                bins reset_wait_b = {FP_FAULT_RESET_WAIT_B};
                bins reset_calc = {FP_FAULT_RESET_CALC};
                bins reset_write = {FP_FAULT_RESET_WRITE};
                bins abort_unaccepted_a = {FP_FAULT_ABORT_UNACCEPTED_A};
                bins abort_unaccepted_b = {FP_FAULT_ABORT_UNACCEPTED_B};
            }
            fault_format_cross: cross cp_fault_format, cp_fault_mode;
        endgroup

        covergroup response_latency_cg with function sample(int unsigned format,
                                                             int unsigned max_latency);
            cp_latency_format: coverpoint format {
                bins bf16 = {0}; bins fp16 = {1};
            }
            cp_response_latency: coverpoint max_latency {
                bins base_latency = {[0:2]};
                bins extended_latency = {[3:64]};
            }
            response_latency_format_cross: cross cp_latency_format,
                                                cp_response_latency;
        endgroup

        covergroup parity_overlap_cg with function sample(int unsigned format,
                                                            int unsigned parity_kind);
            cp_parity_format: coverpoint format {
                bins bf16 = {0}; bins fp16 = {1};
            }
            cp_parity_kind: coverpoint parity_kind {
                bins read_a = {0}; bins read_b = {1}; bins late_word = {2};
            }
            parity_format_kind_cross: cross cp_parity_format, cp_parity_kind;
        endgroup

        covergroup parity_odd_tail_cg with function sample(int unsigned format,
                                                             int unsigned length);
            cp_format: coverpoint format {
                bins bf16 = {0}; bins fp16 = {1};
            }
            cp_odd_tail_length: coverpoint length {
                bins length3 = {3};
            }
            format_odd_tail_cross: cross cp_format, cp_odd_tail_length;
        endgroup

        `uvm_component_utils(bf16_dot_coverage)
        function new(string name, uvm_component parent);
            super.new(name, parent);
            dot_cg = new();
            fault_cg = new();
            response_latency_cg = new();
            parity_overlap_cg = new();
            parity_odd_tail_cg = new();
            busy_start_cg = new();
            for (int f = 0; f < 2; f++) begin
                format_hits[f] = 0;
                for (int i = 0; i <= 16; i++) begin
                    format_length_hits[f][i] = 0;
                end
                for (int i = 0; i < 5; i++) begin
                    format_class_hits[f][i] = 0;
                end
                for (int i = 0; i < 2; i++) begin
                    format_sign_hits[f][i] = 0;
                    format_stall_hits[f][i] = 0;
                end
            end
            transactions_sampled = 0;
            fault_transactions_sampled = 0;
            max_outstanding_reads_seen = 0;
            for (int f = 0; f < 2; f++) begin
                watchdog_disabled_hits[f] = 0;
                watchdog_write_stall_hits[f] = 0;
                response_latency_hits[f][0] = 0;
                response_latency_hits[f][1] = 0;
                for (int p = 0; p < 3; p++)
                    parity_overlap_hits[f][p] = 0;
            end
        endfunction

        virtual function void write(bf16_dot_cov_item t);
            bf16_class_e cls;
            int unsigned format;
            int unsigned sign;
            int unsigned stalled;
            format = t.format_fp16 ? 1 : 0;
            busy_start_cg.sample(format, t.busy_start_count);
            if (t.expect_error || t.expect_reset) begin
                if (t.expect_error && t.expect_reset)
                    `uvm_error("FP/COV", "A coverage transaction cannot be both an error and reset case")
                fault_cg.sample(format, t.fault_mode);
                case (t.fault_mode)
                    FP_FAULT_READ_PARITY,
                    FP_FAULT_READ_B_PARITY,
                    FP_FAULT_READ_PARITY_LATE: begin
                        int unsigned parity_kind;
                        case (t.fault_mode)
                            FP_FAULT_READ_PARITY: parity_kind = 0;
                            FP_FAULT_READ_B_PARITY: parity_kind = 1;
                            default: parity_kind = 2;
                        endcase
                        if (t.parity_response_outstanding_reads != 2) begin
                            `uvm_error("FP/COV", $sformatf(
                                "Parity mode %0d format %0d response observed with outstanding=%0d (expected 2)",
                                t.fault_mode, format,
                                t.parity_response_outstanding_reads))
                        end else begin
                            parity_overlap_hits[format][parity_kind]++;
                            parity_overlap_cg.sample(format, parity_kind);
                        end
                        if ((t.fault_mode == FP_FAULT_READ_PARITY_LATE) &&
                            (t.length == 3))
                            parity_odd_tail_cg.sample(format, t.length);
                    end
                    default: ;
                endcase
                fault_transactions_sampled++;
                return;
            end
            stalled = (t.stall_cycles != 0);
            transactions_sampled++;
            if (t.max_outstanding_reads > max_outstanding_reads_seen)
                max_outstanding_reads_seen = t.max_outstanding_reads;
            format_hits[format]++;
            format_length_hits[format][t.length]++;
            format_stall_hits[format][stalled]++;
            response_latency_cg.sample(format, t.max_response_latency);
            response_latency_hits[format][(t.max_response_latency > 2) ? 1 : 0]++;
            if (t.watchdog_limit == 0)
                watchdog_disabled_hits[format]++;
            if ((t.expected_write_stall_cycles > t.watchdog_limit) &&
                (t.observed_write_stall_cycles == t.expected_write_stall_cycles))
                watchdog_write_stall_hits[format]++;

            for (int unsigned i = 0; i < t.length; i++) begin
                cls = t.format_fp16 ? classify_fp16(t.a_bits[i]) :
                                      classify_bf16(t.a_bits[i]);
                sign = t.a_bits[i][15];
                format_class_hits[format][cls]++;
                format_sign_hits[format][sign]++;
                dot_cg.sample(format, t.length, cls, sign, stalled);

                cls = t.format_fp16 ? classify_fp16(t.b_bits[i]) :
                                      classify_bf16(t.b_bits[i]);
                sign = t.b_bits[i][15];
                format_class_hits[format][cls]++;
                format_sign_hits[format][sign]++;
                dot_cg.sample(format, t.length, cls, sign, stalled);
            end
        endfunction

        virtual function void check_phase(uvm_phase phase);
            super.check_phase(phase);
            if (transactions_sampled == 0)
                `uvm_error("FP/COV", "No passing transactions reached coverage")
            if (fault_transactions_sampled == 0)
                `uvm_error("FP/COV", "No passing fault/reset transactions reached coverage")
            if (fault_cg.get_coverage() < 100.0)
                `uvm_error("FP/COV", $sformatf("Fault/reset format x mode coverage incomplete: %0.1f%%",
                                                 fault_cg.get_coverage()))
            if (parity_overlap_cg.get_coverage() < 100.0)
                `uvm_error("FP/COV", $sformatf(
                    "Parity format x fault-kind coverage with two outstanding reads incomplete: %0.1f%%",
                    parity_overlap_cg.get_coverage()))
            if (parity_odd_tail_cg.get_coverage() < 100.0)
                `uvm_error("FP/COV", $sformatf(
                    "Odd-length final-word parity coverage incomplete: %0.1f%%",
                    parity_odd_tail_cg.get_coverage()))
            if (busy_start_cg.get_coverage() < 100.0)
                `uvm_error("FP/COV", $sformatf("Busy-start format x pulse coverage incomplete: %0.1f%%",
                                                 busy_start_cg.get_coverage()))
            if (max_outstanding_reads_seen < 2)
                `uvm_error("FP/COV", $sformatf("Read overlap not covered: peak outstanding=%0d",
                                                 max_outstanding_reads_seen))
            for (int f = 0; f < 2; f++) begin
                if (format_hits[f] == 0)
                    `uvm_error("FP/COV", $sformatf("Format bin %0d was not covered", f))
                for (int i = 1; i <= 16; i++) begin
                    if (format_length_hits[f][i] == 0)
                        `uvm_error("FP/COV", $sformatf("Format %0d length %0d was not covered", f, i))
                end
                for (int i = 0; i < 5; i++) begin
                    if (format_class_hits[f][i] == 0)
                        `uvm_error("FP/COV", $sformatf("Format %0d operand class %0d was not covered", f, i))
                end
                for (int i = 0; i < 2; i++) begin
                    if (format_sign_hits[f][i] == 0)
                        `uvm_error("FP/COV", $sformatf("Format %0d sign bin %0d was not covered", f, i))
                    if (format_stall_hits[f][i] == 0)
                        `uvm_error("FP/COV", $sformatf("Format %0d backpressure bin %0d was not covered", f, i))
                end
                if (watchdog_disabled_hits[f] == 0)
                    `uvm_error("FP/COV", $sformatf("Format %0d watchdog-disabled case was not covered", f))
                if (watchdog_write_stall_hits[f] == 0)
                    `uvm_error("FP/COV", $sformatf("Format %0d watchdog-masked writeback stall was not covered", f))
                for (int p = 0; p < 3; p++) begin
                    if (parity_overlap_hits[f][p] == 0)
                        `uvm_error("FP/COV", $sformatf(
                            "Format %0d parity-kind %0d was not covered with peak outstanding=2",
                            f, p))
                end
                for (int latency_class = 0; latency_class < 2; latency_class++) begin
                    if (response_latency_hits[f][latency_class] == 0)
                        `uvm_error("FP/COV", $sformatf("Format %0d response-latency bin %0d was not covered",
                                                         f, latency_class))
                end
            end
            if (response_latency_cg.get_coverage() < 100.0)
                `uvm_error("FP/COV", $sformatf("Response latency format cross incomplete: %0.1f%%",
                                                 response_latency_cg.get_coverage()))
            `uvm_info("FP/COV", $sformatf("Mixed dot coverage: transactions=%0d BF16=%0d FP16=%0d peak_outstanding_reads=%0d response_latency(base/extended)=%0d/%0d,%0d/%0d watchdog_disabled=%0d/%0d watchdog_masked_write_stall=%0d/%0d numeric_cg=%0.1f%% response_latency_cg=%0.1f%% fault_reset_transactions=%0d fault_format_mode_cg=%0.1f%% parity_two_outstanding_cg=%0.1f%% parity_odd_tail_cg=%0.1f%% busy_start_format_pulse_cg=%0.1f%%",
                                             transactions_sampled, format_hits[0],
                                             format_hits[1], max_outstanding_reads_seen,
                                             response_latency_hits[0][0], response_latency_hits[0][1],
                                             response_latency_hits[1][0], response_latency_hits[1][1],
                                             watchdog_disabled_hits[0], watchdog_disabled_hits[1],
                                             watchdog_write_stall_hits[0],
                                             watchdog_write_stall_hits[1],
                                             dot_cg.get_coverage(), response_latency_cg.get_coverage(),
                                             fault_transactions_sampled,
                                             fault_cg.get_coverage(),
                                             parity_overlap_cg.get_coverage(),
                                             parity_odd_tail_cg.get_coverage(),
                                             busy_start_cg.get_coverage()), UVM_LOW)
        endfunction
    endclass
