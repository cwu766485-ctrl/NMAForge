    // Historical component name retained to keep the existing UVM agent
    // stable; samples and bins now cover both BF16 and FP16 dot modes.
    class bf16_dot_coverage extends uvm_subscriber #(bf16_dot_cov_item);
        int unsigned format_hits[2];
        int unsigned format_length_hits[2][5];
        int unsigned format_class_hits[2][5];
        int unsigned format_sign_hits[2][2];
        int unsigned format_stall_hits[2][2];
        int unsigned transactions_sampled;

        covergroup dot_cg with function sample(int unsigned format,
                                                int unsigned length,
                                                int unsigned op_class,
                                                int unsigned sign,
                                                int unsigned stalled);
            cp_format: coverpoint format {
                bins bf16 = {0}; bins fp16 = {1};
            }
            cp_length: coverpoint length {
                bins len1 = {1}; bins len2 = {2}; bins len3 = {3}; bins len4 = {4};
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

        `uvm_component_utils(bf16_dot_coverage)
        function new(string name, uvm_component parent);
            super.new(name, parent);
            dot_cg = new();
            for (int f = 0; f < 2; f++) begin
                format_hits[f] = 0;
                for (int i = 0; i < 5; i++) begin
                    format_length_hits[f][i] = 0;
                    format_class_hits[f][i] = 0;
                end
                for (int i = 0; i < 2; i++) begin
                    format_sign_hits[f][i] = 0;
                    format_stall_hits[f][i] = 0;
                end
            end
            transactions_sampled = 0;
        endfunction

        virtual function void write(bf16_dot_cov_item t);
            bf16_class_e cls;
            int unsigned format;
            int unsigned sign;
            int unsigned stalled;
            format = t.format_fp16 ? 1 : 0;
            stalled = (t.stall_cycles != 0);
            transactions_sampled++;
            format_hits[format]++;
            format_length_hits[format][t.length]++;
            format_stall_hits[format][stalled]++;

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
            for (int f = 0; f < 2; f++) begin
                if (format_hits[f] == 0)
                    `uvm_error("FP/COV", $sformatf("Format bin %0d was not covered", f))
                for (int i = 1; i <= 4; i++) begin
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
            end
            `uvm_info("FP/COV", $sformatf("Mixed dot coverage: transactions=%0d BF16=%0d FP16=%0d covergroup=%0.1f%%",
                                             transactions_sampled, format_hits[0],
                                             format_hits[1], dot_cg.get_coverage()), UVM_LOW)
        endfunction
    endclass
