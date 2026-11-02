Warning: truncated output (original token count: 117221)
Total output lines: 9099

class ai_compute_cluster_e2e_seq extends uvm_sequence #(ai_axil_item);
    `uvm_object_utils(ai_compute_cluster_e2e_seq)

    localparam bit [31:0] REG_CMDQ_CTRL = 32'h0000_00ac;
    localparam bit [31:0] REG_CMDQ_BASE = 32'h0000_0080;
    localparam bit [31:0] REG_CMDQ_SIZE = 32'h0000_0088;
    localparam bit [31:0] REG_CMDQ_HEAD = 32'h0000_008c;
    localparam bit [31:0] REG_CMDQ_TAIL = 32'h0000_00c8;
    localparam bit [31:0] REG_CPLQ_BASE = 32'h0000_0090;
    localparam bit [31:0] REG_CPLQ_SIZE = 32'h0000_0098;
    localparam bit [31:0] REG_CPLQ_TAIL = 32'h0000_009c;
    localparam bit [31:0] REG_CPLQ_HEAD = 32'h0000_00cc;
    localparam bit [31:0] REG_DOORBELL = 32'h0000_00a0;
    localparam bit [31:0] REG_ABORT = 32'h0000_00a4;
    localparam bit [31:0] REG_DMA_CTRL = 32'h0000_00b0;
    localparam bit [31:0] REG_DMA_STATUS = 32'h0000_00b4;
    localparam bit [31:0] REG_DMA_EXT = 32'h0000_00b8;
    localparam bit [31:0] REG_DMA_SPAD = 32'h0000_00bc;
    localparam bit [31:0] REG_DMA_LEN = 32'h0000_00c0;
    localparam bit [31:0] REG_REGION0_BASE = 32'h0000_00d4;
    localparam bit [31:0] REG_REGION0_LIMIT = 32'h0000_00d8;
    localparam bit [31:0] REG_REGION0_PERM = 32'h0000_00dc;
    localparam bit [31:0] REG_REGION1_BASE = 32'h0000_00e0;
    localparam bit [31:0] REG_REGION1_LIMIT = 32'h0000_00e4;
    localparam bit [31:0] REG_REGION1_PERM = 32'h0000_00e8;
    localparam bit [31:0] REG_REGION2_BASE = 32'h0000_00ec;
    localparam bit [31:0] REG_REGION2_LIMIT = 32'h0000_00f0;
    localparam bit [31:0] REG_REGION2_PERM = 32'h0000_00f4;
    localparam bit [31:0] REG_REGION3_BASE = 32'h0000_00f8;
    localparam bit [31:0] REG_REGION3_LIMIT = 32'h0000_00fc;
    localparam bit [31:0] REG_REGION3_PERM = 32'h0000_0100;

    localparam bit [31:0] CMDQ_LOCAL = 32'h0000_4000;
    localparam bit [31:0] CPLQ_LOCAL = 32'h0000_5000;
    localparam bit [31:0] MATRIX_A_LOCAL = 32'h0001_0000;
    localparam bit [31:0] MATRIX_B_LOCAL = 32'h0001_2000;
    localparam bit [31:0] MATRIX_Y_LOCAL = 32'h0003_0000;
    localparam bit [31:0] MATRIX_LINE_STALL_CNM_A_LOCAL = 32'h0005_0000;
    localparam bit [31:0] MATRIX_LINE_STALL_CNM_B_LOCAL = 32'h0005_2000;
    localparam bit [31:0] MATRIX_LINE_STALL_CNM_Y_LOCAL = 32'h0005_6000;
    localparam bit [31:0] GELU_A_LOCAL = 32'h0002_0000;
    localparam bit [31:0] GELU_B_LOCAL = 32'h0002_0100;
    localparam bit [31:0] GELU_Y0_LOCAL = 32'h0002_0200;
    localparam bit [31:0] GELU_Y1_LOCAL = 32'h0002_0300;
    localparam bit [31:0] CNM_A_LOCAL = 32'h0004_8000;
    localparam bit [31:0] CNM_B_LOCAL = 32'h0004_9000;
    localparam bit [31:0] CNM_Y_LOCAL = 32'h0004_a000;
    localparam bit [31:0] CLUSTER_SWEEP_CMDQ = 32'h0000_4400;
    localparam bit [31:0] CLUSTER_SWEEP_CPLQ = 32'h0000_5400;
    localparam bit [31:0] CLUSTER_CONTRACT_CMDQ = 32'h0000_4800;
    localparam bit [31:0] CLUSTER_CONTRACT_CPLQ = 32'h0000_5800;
    localparam bit [31:0] CONTRACT_SHARED_LOCAL = 32'h0004_7000;
    localparam bit [31:0] CONTRACT_B_LOCAL = 32'h0004_7200;
    localparam bit [31:0] CONTRACT_Y0_LOCAL = 32'h0004_7400;
    localparam bit [31:0] CONTRACT_Y1_LOCAL = 32'h0004_7500;
    localparam bit [31:0] CONTRACT_MUTATED_Y_LOCAL = 32'h0004_7600;
    localparam bit [31:0] CONTRACT_SFU_Y_LOCAL = 32'h0004_7800;
    localparam bit [31:0] MATRIX_LATCH_Y_LOCAL = 32'h0003_8000;
    localparam bit [31:0] MATRIX_LATCH_MUTATED_Y_LOCAL = 32'h0003_9000;
    localparam bit [31:0] SFU_LATCH_SRC_LOCAL = 32'h0004_a100;
    localparam bit [31:0] SFU_LATCH_MUTATED_SRC_LOCAL = 32'h0004_a140;
    localparam bit [31:0] SFU_LATCH_Y_LOCAL = 32'h0004_a180;
    localparam bit [31:0] SFU_LATCH_MUTATED_Y_LOCAL = 32'h0004_a1c0;
    localparam bit [31:0] SCALAR_A_LOCAL = 32'h0004_6000;
    localparam bit [31:0] SCALAR_B_LOCAL = 32'h0004_6100;
    localparam bit [31:0] SCALAR_Y_LOCAL = 32'h0004_6200;
    localparam bit [31:0] FP_A_LOCAL = 32'h0004_6400;
    localparam bit [31:0] FP_B_LOCAL = 32'h0004_6404;
    localparam bit [31:0] FP_Y_LOCAL = 32'h0004_6408;
    localparam bit [31:0] CONV_A_LOCAL = 32'h0004_6600;
    localparam bit [31:0] CONV_W_LOCAL = 32'h0004_6640;
    localparam bit [31:0] CONV_Y_LOCAL = 32'h0004_6680;
    localparam bit [31:0] KV_VECTOR_LOCAL = 32'h0004_6800;
    localparam bit [31:0] KV_CACHE_LOCAL = 32'h0004_6840;
    localparam bit [31:0] KV_READ_LOCAL = 32'h0004_6900;
    localparam bit [31:0] SWEEP_MATRIX_Y_LOCAL = 32'h0004_c000;
    localparam bit [31:0] SWEEP_CNM_Y_LOCAL = 32'h0004_c800;
    localparam bit [31:0] SWEEP_SFU_Y_LOCAL = 32'h0004_d000;
    localparam bit [31:0] FAULT_Y_LOCAL = 32'h0004_e000;
    localparam bit [31:0] MATRIX_FAULT_A_LOCAL = 32'h0004_f000;
    localparam bit [31:0] MATRIX_FAULT_B_LOCAL = 32'h0004_f100;
    localparam bit [31:0] CLUSTER_PROT_CMDQ = 32'h0000_6000;
    localparam bit [31:0] CLUSTER_PROT_CPLQ = 32'h0000_7000;
    localparam bit [31:0] C1_CNM_A_LOCAL = 32'h0006_0000;
    localparam bit [31:0] C1_CNM_B_LOCAL = 32'h0006_1000;
    localparam bit [31:0] C1_CNM_Y_LOCAL = 32'h0006_7000;
    localparam bit [31:0] C1_SFU_A_LOCAL = 32'h0006_8000;
    localparam bit [31:0] C1_SFU_Y_LOCAL = 32'h0006_8400;
    localparam bit [31:0] C1_CONV_A_LOCAL = 32'h0006_9000;
    localparam bit [31:0] C1_CONV_W_LOCAL = 32'h0006_9400;
    localparam bit [31:0] C1_CONV_Y_LOCAL = 32'h0006_9800;
    localparam bit [31:0] C1_KV_VECTOR_LOCAL = 32'h0006_a000;
    localparam bit [31:0] C1_KV_CACHE_LOCAL = 32'h0006_a400;
    localparam bit [31:0] C1_KV_READ_LOCAL = 32'h0006_a800;
    localparam bit [31:0] C1_SCALAR_A_LOCAL = 32'h0006_b000;
    localparam bit [31:0] C1_SCALAR_B_LOCAL = 32'h0006_b400;
    localparam bit [31:0] C1_SCALAR_Y_LOCAL = 32'h0006_b800;
    localparam bit [31:0] C1_FP_A_LOCAL = 32'h0006_c000;
    localparam bit [31:0] C1_FP_B_LOCAL = 32'h0006_c100;
    localparam bit [31:0] C1_FP_Y_LOCAL = 32'h0006_c200;
    localparam bit [31:0] FP_LATCH_A_LOCAL = 32'h0006_d000;
    localparam bit [31:0] FP_LATCH_B_LOCAL = 32'h0006_d100;
    localparam bit [31:0] FP_LATCH_MUTATED_A_LOCAL = 32'h0006_d200;
    localparam bit [31:0] FP_LATCH_MUTATED_B_LOCAL = 32'h0006_d300;
    localparam bit [31:0] FP_LATCH_Y_LOCAL = 32'h0006_d400;
    localparam bit [31:0] FP_LATCH_MUTATED_Y_LOCAL = 32'h0006_d500;
    localparam bit [31:0] CONV_LATCH_A_LOCAL = 32'h0006_e000;
    localparam bit [31:0] CONV_LATCH_W_LOCAL = 32'h0006_e100;
    localparam bit [31:0] CONV_LATCH_MUTATED_A_LOCAL = 32'h0006_e200;
    localparam bit [31:0] CONV_LATCH_MUTATED_W_LOCAL = 32'h0006_e300;
    localparam bit [31:0] CONV_LATCH_Y_LOCAL = 32'h0006_e400;
    localparam bit [31:0] CONV_LATCH_MUTATED_Y_LOCAL = 32'h0006_e500;
    localparam bit [31:0] KV_LATCH_SRC_LOCAL = 32'h0006_f000;
    localparam bit [31:0] KV_LATCH_MUTATED_SRC_LOCAL = 32'h0006_f200;
    localparam bit [31:0] KV_LATCH_CACHE_LOCAL = 32'h0006_f400;
    localparam bit [31:0] KV_LATCH_MUTATED_CACHE_LOCAL = 32'h0006_f800;
    localparam bit [31:0] CNM_LATCH_Y_LOCAL = 32'h0004_e300;
    localparam bit [31:0] CNM_LATCH_MUTATED_Y_LOCAL = 32'h0004_e400;
    localparam bit [31:0] SCALAR_OPCODE_CMDQ = 32'h0005_a000;
    localparam bit [31:0] SCALAR_OPCODE_CPLQ = 32'h0005_a400;
    localparam bit [31:0] SCALAR_OPCODE_A_LOCAL = 32'h0007_0000;
    localparam bit [31:0] SCALAR_OPCODE_B_LOCAL = 32'h0007_0040;
    localparam bit [31:0] SCALAR_OPCODE_Y_LOCAL = 32'h0007_0080;

    virtual ai_compute_cluster_if compute_vif;
    bit [31:0] rng_state;
    string mutation_kind;
    int unsigned shared_reset_coverage_phase;
    int unsigned shared_reset_prefix_coverage_phase;
    int unsigned cnm_protection_reset_prefix_coverage_phase;
    int unsigned sfu_reset_prefix_phase;
    int unsigned conv_reset_prefix_phase;
    int unsigned scalar_reset_prefix_phase;
    int unsigned matrix_protection_reset_phase;
    int unsigned matrix_protection_cnm_reset_phase;
    int unsigned engine_protection_reset_engine;
    bit engine_protection_reset_operand_b;
    int unsigned engine_protection_reset_phase;
    int unsigned fp16_abort_zero_prefix_hit;

    covergroup fp16_abort_zero_prefix_cg;
        option.per_instance = 1;
        cp_fp16_abort_zero_prefix: coverpoint fp16_abort_zero_prefix_hit {
            bins verified_zero_prefix = {1};
        }
    endgroup

    covergroup matrix_cnm_shared_reset_cg;
        option.per_instance = 1;
        cp_reset_recovery_phase: coverpoint shared_reset_coverage_phase {
            bins parity_with_cnm_reads_pending = {1};
            bins reset_quiet_window = {2};
            bins release_quiet_window = {3};
            bins full_golden_recovery = {4};
        }
    endgroup

    covergroup matrix_cnm_prefix_reset_cg;
        option.per_instance = 1;
        cp_reset_prefix_recovery_phase: coverpoint shared_reset_prefix_coverage_phase {
            bins nonempty_prefix_with_pending_read = {1};
            bins reset_quiet_window = {2};
            bins release_quiet_window = {3};
            bins prefix_and_suffix_preserved = {4};
            bins full_golden_recovery = {5};
        }
    endgroup

    covergroup cnm_protection_matrix_prefix_reset_cg;
        option.per_instance = 1;
        cp_cnm_protection_matrix_prefix_phase: coverpoint cnm_protection_reset_prefix_coverage_phase {
            bins cnm_protection_consumed_with_matrix_active = {1};
            bins matrix_golden_prefix_after_protection = {2};
            bins reset_quiet_window = {3};
            bins release_quiet_window = {4};
            bins prefix_and_suffix_preserved = {5};
            bins full_golden_recovery = {6};
        }
    endgroup

    covergroup sfu_reset_prefix_cg;
        option.per_instance = 1;
        cp_sfu_reset_prefix_phase: coverpoint sfu_reset_prefix_phase {
            bins sfu_task_busy = {1};
            bins accepted_golden_prefix = {2};
            bins reset_quiet_window = {3};
            bins release_quiet_window = {4};
            bins prefix_suffix_and_completion_preserved = {5};
            bins full_golden_recovery = {6};
        }
    endgroup

    covergroup conv_reset_prefix_cg;
        option.per_instance = 1;
        cp_conv_reset_prefix_phase: coverpoint conv_reset_prefix_phase {
            bins conv_task_busy = {1};
            bins accepted_golden_prefix = {2};
            bins reset_quiet_window = {3};
            bins release_quiet_window = {4};
            bins prefix_suffix_and_completion_preserved = {5};
            bins full_golden_recovery = {6};
        }
    endgroup

    covergroup scalar_reset_prefix_cg;
        option.per_instance = 1;
        cp_scalar_reset_prefix_phase: coverpoint scalar_reset_prefix_phase {
            bins scalar_task_busy = {1};
            bins accepted_golden_prefix = {2};
            bins reset_quiet_window = {3};
            bins release_quiet_window = {4};
            bins prefix_suffix_and_completion_preserved = {5};
            bins full_golden_recovery = {6};
        }
    endgroup

    int unsigned engine_pair_overlap_cov_idx;
    covergroup engine_pair_overlap_cg;
        option.per_instance = 1;
        cp_engine_pair_overlap: coverpoint engine_pair_overlap_cov_idx {
            bins int8_matrix = {0};
            bins int8_cnm = {1};
            bins int8_bf16 = {2};
            bins int8_sfu = {3};
            bins int8_conv = {4};
            bins int8_kv = {5};
            bins matrix_cnm = {6};
            bins matrix_bf16 = {7};
            bins matrix_sfu = {8};
            bins matrix_conv = {9};
            bins matrix_kv = {10};
            bins cnm_bf16 = {11};
            bins cnm_sfu = {12};
            bins cnm_conv = {13};
            bins cnm_kv = {14};
            bins bf16_sfu = {15};
            bins bf16_conv = {16};
            bins bf16_kv = {17};
            bins sfu_conv = {18};
            bins sfu_kv = {19};
            bins conv_kv = {20};
        }
    endgroup

    covergroup matrix_protection_reset_cg;
        option.per_instance = 1;
        cp_matrix_protection_reset_phase: coverpoint matrix_protection_reset_phase {
            bins legal_task_launched = {1};
            bins source_b_protection_denied_after_a_read = {2};
            bins protection_error_code_observed = {3};
            bins reset_suppressed_old_completion_and_writeback = {4};
            bins reset_release_quiet_window = {5};
            bins new_epoch_full_golden_recovery = {6};
        }
    endgroup

    covergroup matrix_protection_cnm_reset_cg;
        option.per_instance = 1;
        cp_matrix_protection_cnm_reset_phase: coverpoint matrix_protection_cnm_reset_phase {
            bins legal_matrix_and_cnm_tasks_launched = {1};
            bins matrix_source_b_protection_observed = {2};
            bins cnm_read_response_pending_at_reset = {3};
            bins reset_quiet_window = {4};
            bins release_quiet_and_old_side_effects_suppressed = {5};
            bins matrix_cnm_golden_recovery = {6};
        }
    endgroup

    covergroup engine_protection_reset_cg;
        option.per_instance = 1;
        cp_engine: coverpoint engine_protection_reset_engine {
            bins scalar = {0};
            bins fp = {1};
            bins cnm = {2};
            bins matrix = {3};
            bins sfu = {4};
            bins conv = {5};
            bins kv = {6};
        }
        cp_operand: coverpoint engine_protection_reset_operand_b {
            bins source_a = {1'b0};
            bins source_b = {1'b1};
        }
        cp_phase: coverpoint engine_protection_reset_phase {
            bins launched = {1};
            bins operand_denied = {2};
            bins protection_error_observed = {3};
            bins reset_epoch_flushed = {4};
            bins old_side_effects_suppressed = {5};
            bins recovery_completion = {6};
        }
        engine_operand_phase_cross: cross cp_engine, cp_operand, cp_phase {
            ignore_bins sfu_has_no_source_b =
                binsof(cp_engine.sfu) && binsof(cp_operand.source_b);
            ignore_bins kv_has_no_source_b =
                binsof(cp_engine.kv) && binsof(cp_operand.source_b);
        }
    endgroup

    function automatic int signed next_small_signed();
        int unsigned value;
        rng_state = rng_state ^ (rng_state << 13);
        rng_state = rng_state ^ (rng_state >> 17);
        rng_state = rng_state ^ (rng_state << 5);
        value = rng_state % 5;
        return int'(value) - 2;
    endfunction

    function new(string name = "ai_compute_cluster_e2e_seq");
        super.new(name);
        shared_reset_coverage_phase = 0;
        shared_reset_prefix_coverage_phase = 0;
        cnm_protection_reset_prefix_coverage_phase = 0;
        sfu_reset_prefix_phase = 0;
        conv_reset_prefix_phase = 0;
        scalar_reset_prefix_phase = 0;
        engine_pair_overlap_cov_idx = 0;
        matrix_protection_reset_phase = 0;
        matrix_protection_cnm_reset_phase = 0;
        engine_protection_reset_engine = 0;
        engine_protection_reset_operand_b = 1'b0;
        engine_protection_reset_phase = 0;
        fp16_abort_zero_prefix_hit = 0;
        fp16_abort_zero_prefix_cg = new();
        matrix_cnm_shared_reset_cg = new();
        matrix_cnm_prefix_reset_cg = new();
        cnm_protection_matrix_prefix_reset_cg = new();
        sfu_reset_prefix_cg = new();
        conv_reset_prefix_cg = new();
        scalar_reset_prefix_cg = new();
        engine_pair_overlap_cg = new();
        matrix_protection_reset_cg = new();
        matrix_protection_cnm_reset_cg = new();
        engine_protection_reset_cg = new();
    endfunction

    task automatic axil_write(input bit [31:0] addr, input bit [31:0] data);
        ai_axil_item req;
        req = ai_axil_item::type_id::create("cluster_axil_write");
        start_item(req);
        req.is_write = 1'b1;
        req.addr = addr;
        req.data = data;
        req.strb = 4'hf;
        finish_item(req);
        if (req.resp !== 2'b00)
            `uvm_fatal("CLUSTER_AXIL", $sformatf("write addr=0x%08h resp=%0h", addr, req.resp))
    endtask

    task automatic axil_read(input bit [31:0] addr, output bit [31:0] data);
        ai_axil_item req;
        req = ai_axil_item::type_id::create("cluster_axil_read");
        start_item(req);
        req.is_write = 1'b0;
        req.addr = addr;
        req.data = '0;
        req.strb = '0;
        finish_item(req);
        if (req.resp !== 2'b00)
            `uvm_fatal("CLUSTER_AXIL", $sformatf("read addr=0x%08h resp=%0h", addr, req.resp))
        data = req.rdata;
    endtask

    task automatic spad_write(input bit [31:0] addr, input bit [31:0] data);
        axil_write(CIMFORGE_SPAD_BASE + addr, data);
    endtask

    task automatic backdoor_write_spad_word(input bit [31:0] addr,
                                             input bit [31:0] data,
                                             input string tag);
        int unsigned word_addr;
        int unsigned bank;
        int unsigned row;
        string data_path;
        string parity_path;
        bit data_ok;
        bit parity_ok;
        // Host-port writes during a compute-port request are contractually
        // rejected by the behavioral SPAD. Use a parity-consistent backdoor
        // mutation to isolate launch-snapshot retention from that collision.
        word_addr = addr >> 2;
        bank = word_addr & 3;
        row = word_addr >> 2;
        data_path = $sformatf(
            "tb_ai_accel_uvm.dut.spad_subsystem_u.scratchpad_u.bank%0d[%0d]",
            bank, row);
        parity_path = $sformatf(
            "tb_ai_accel_uvm.dut.spad_subsystem_u.scratchpad_u.bank%0d_parity[%0d]",
            bank, row);
        data_ok = uvm_hdl_deposit(data_path, data);
        parity_ok = uvm_hdl_deposit(parity_path, ^data);
        if (!data_ok || !parity_ok)
            `uvm_fatal("CLUSTER_DESC_BACKDOOR", $sformatf(
                "%s failed descriptor mutation data_ok=%0b parity_ok=%0b data_path=%s parity_path=%s",
                tag, data_ok, parity_ok, data_path, parity_path))
    endtask

    task automatic expect_spad(input bit [31:0] addr, input bit [31:0] expected, input string tag);
        bit [31:0] actual;
        axil_read(CIMFORGE_SPAD_BASE + addr, actual);
        if (actual !== expected) begin
            if ((mutation_kind == "completion_error_code") &&
                (tag == "random parity case0 ERR_PARITY completion")) begin
                `uvm_info("CLUSTER_MUTATION_CAUGHT",
                    "mutation=completion_error_code checker=completion_error_code", UVM_LOW)
                `uvm_error("CLUSTER_COMPLETION_ERROR_CODE", $sformatf(
                    "%s addr=0x%08h expected=0x%08h actual=0x%08h",
                    tag, addr, expected, actual))
            end else begin
                `uvm_fatal("CLUSTER_GOLDEN", $sformatf(
                    "%s addr=0x%08h expected=0x%08h actual=0x%08h",
                    tag, addr, expected, actual))
            end
        end
    endtask

    task automatic write_v3_desc(
        input bit [31:0] base,
        input bit [7:0] op,
        input bit [15:0] task_id,
        input bit [31:0] src0,
        input bit [31:0] src1,
        input bit [31:0] dst,
        input bit [15:0] m,
        input bit [15:0] n,
        input bit [15:0] length_or_k
    );
        spad_write(base + 32'h00, {task_id, 8'd0, op});
        spad_write(base + 32'h04, src0);
        spad_write(base + 32'h08, src1);
        spad_write(base + 32'h0c, 32'd0);
        spad_write(base + 32'h10, dst);
        spad_write(base + 32'h14, {n, m});
        spad_write(base + 32'h18, {16'd0, length_or_k});
        spad_write(base + 32'h1c, 32'd0);
        spad_write(base + 32'h20, 32'd1);
        spad_write(base + 32'h24, 32'd0);
        spad_write(base + 32'h28, 32'd0);
        spad_write(base + 32'h2c, 32'd0);
        spad_write(base + 32'h30, 32'd0);
        spad_write(base + 32'h34, 32'h0001_0001);
        spad_write(base + 32'h38, 32'd0);
        spad_write(base + 32'h3c, 32'd3);
    endtask

    task automatic write_cluster_desc(
        input bit [31:0] base,
        input bit [7:0] op,
        input bit [15:0] task_id,
        input bit [31:0] src0,
        input bit [31:0] src1,
        input bit [31:0] dst,
        input bit [15:0] m,
        input bit [15:0] n,
        input bit [15:0] length,
        input bit [31:0] aux0,
        input bit [31:0] src0_stride,
        input bit [31:0] src1_stride,
        input bit [31:0] dst_stride,
        input bit [7:0] version
    );
        spad_write(base + 32'h00, {task_id, 8'd0, op});
        spad_write(base + 32'h04, src0);
        spad_write(base + 32'h08, src1);
        spad_write(base + 32'h0c, 32'd0);
        spad_write(base + 32'h10, dst);
        spad_write(base + 32'h14, {n, m});
        spad_write(base + 32'h18, {16'd0, length});
        spad_write(base + 32'h1c, 32'd0);
        spad_write(base + 32'h20, aux0);
        spad_write(base + 32'h24, 32'd0);
        spad_write(base + 32'h28, src0_stride);
        spad_write(base + 32'h2c, src1_stride);
        spad_write(base + 32'h30, dst_stride);
        // FP descriptors require both counts to be zero. Other engines accept
        // zero as the ABI default of one batch/head.
        spad_write(base + 32'h34, 32'd0);
        spad_write(base + 32'h38, 32'd0);
        spad_write(base + 32'h3c, {16'd0, version});
    endtask

    task automatic write_cnm_v3_desc(
        input bit [31:0] base,
        input bit [15:0] task_id,
        input bit [31:0] src0,
        input bit [31:0] src1,
        input bit [31:0] dst
    );
        spad_write(base + 32'h00, {task_id, 8'd0, 8'h21});
        spad_write(base + 32'h04, src0);
        spad_write(base + 32'h08, src1);
        spad_write(base + 32'h0c, 32'd0);
        spad_write(base + 32'h10, dst);
        spad_write(base + 32'h14, {16'd1, 16'd16});
        spad_write(base + 32'h18, 32'd1);
        spad_write(base + 32'h1c, 32'd0);
        spad_write(base + 32'h20, 32'd0);
        spad_write(base + 32'h24, 32'd0);
        spad_write(base + 32'h28, 32'd0);
        spad_write(base + 32'h2c, 32'd0);
        spad_write(base + 32'h30, 32'd0);
        spad_write(base + 32'h34, 32'h0001_0001);
        spad_write(base + 32'h38, 32'd0);
        spad_write(base + 32'h3c, 32'd3);
    endtask

    task automatic expect_completion(
        input bit [31:0] base,
        input bit [15:0] task_id,
        input bit [31:0] result,
        input bit [31:0] elements,
        input string tag
    );
        expect_spad(base + 32'h00, {16'd0, task_id}, {tag, " task_id"});
        expect_spad(base + 32'h04, 32'h0000_0001, {tag, " status"});
        expect_spad(base + 32'h08, result, {tag, " result"});
        expect_spad(base + 32'h0c, elements, {tag, " elements"});
    endtask

    task automatic inject_spad_parity_fault(
        input bit [31:0] addr,
        output string parity_path,
        output uvm_hdl_data_t saved_parity
    );
        int bank;
        int row;
        bit ok;
        uvm_hdl_data_t corrupt_parity;
        bank = (addr >> 2) & 3;
        row = addr >> 4;
        parity_path = $sformatf(
            "tb_ai_accel_uvm.dut.spad_subsystem_u.scratchpad_u.bank%0d_parity[%0d]",
            bank, row);
        if (!uvm_hdl_read(parity_path, saved_parity))
            `uvm_fatal("CLUSTER_FAULT", $sformatf("cannot read parity bit at %s", parity_path))
        corrupt_parity = saved_parity;
        corrupt_parity[0] = ~saved_parity[0];
        ok = uvm_hdl_deposit(parity_path, corrupt_parity);
        if (!ok)
            `uvm_fatal("CLUSTER_FAULT", $sformatf("cannot inject parity fault at %s", parity_path))
    endtask

    task automatic restore_spad_parity(
        input string parity_path,
        input uvm_hdl_data_t saved_parity
    );
        bit ok;
        ok = uvm_hdl_deposit(parity_path, saved_parity);
        if (!ok)
            `uvm_fatal("CLUSTER_FAULT", $sformatf("cannot restore parity bit at %s", parity_path))
    endtask

    task automatic run_random_parity_case(
        input int unsigned case_id,
        input int unsigned seed
    );
        int unsigned fault_engine;
        int unsigned fault_phase;
        int unsigned cnm_lane;
        int unsigned word_idx;
        bit [31:0] src0;
        bit [31:0] src1;
        bit [31:0] dst;
        bit [31:0] desc_addr;
        bit [31:0] cpl_addr;
        bit [31:0] fault_addr;
        bit [7:0] opcode;
        bit [31:0] expected_status_error;
        string parity_path;
        uvm_hdl_data_t saved_parity;

        if (case_id < 2) begin
            fault_engine = 0; // INT8 scalar
            fault_phase = case_id;
            cnm_lane = 0;
        end else if (case_id < 4) begin
            fault_engine = 1; // Matrix banked read
            fault_phase = case_id - 2;
            cnm_lane = 0;
        end else if (case_id < 12) begin
            fault_engine = 2; // CNM lane-local A/B read
            fault_phase = (case_id - 4) % 2;
            cnm_lane = (case_id - 4) / 2;
        end else if (case_id < 14) begin
            fault_engine = 3; // BF16 dot
            fault_phase = case_id - 12;
            cnm_lane = 0;
        end else if (case_id == 14) begin
            fault_engine = 4; // SFU vector input
            fault_phase = 0;
            cnm_lane = 0;
        end else if (case_id < 17) begin
            fault_engine = 5; // Conv input / weight
            fault_phase = case_id - 15;
            cnm_lane = 0;
        end else begin
            fault_engine = 6; // KV source vector
            fault_phase = 0;
            cnm_lane = 0;
        end

        dst = FAULT_Y_LOCAL + (case_id * 32'h100);
        desc_addr = CLUSTER_SWEEP_CMDQ + 32'h200 + (case_id * 32'h40);
        cpl_addr = CLUSTER_SWEEP_CPLQ + 32'h200 + (case_id * 32'h10);
        for (word_idx = 0; word_idx < 16; word_idx++)
            spad_write(dst + (word_idx << 2), 32'hfa17_0000 | (case_id << 8) | word_idx);

        case (fault_engine)
            0: begin
                opcode = 8'h10;
                src0 = SCALAR_A_LOCAL;
                src1 = SCALAR_B_LOCAL;
                fault_addr = fault_phase ? src1 : src0;
                write_cluster_desc(desc_addr, opcode, 16'h0700 + case_id,
                                   src0, src1, dst, 16'd0, 16'd0, 16'd1,
                                   32'd0, 32'd0, 32'd0, 32'd0, 8'd3);
            end
            1: begin
                opcode = 8'h30;
                src0 = MATRIX_FAULT_A_LOCAL;
                src1 = MATRIX_FAULT_B_LOCAL;
                fault_addr = fault_phase ? src1 : src0;
                write_v3_desc(desc_addr, opcode, 16'h0700 + case_id,
                              src0, src1, dst, 16'd4, 16'd4, 16'd1);
            end
            2: begin
                opcode = 8'h21;
                src0 = CNM_A_LOCAL;
                src1 = CNM_B_LOCAL;
                fault_addr = (fault_phase ? src1 : src0) + (cnm_lane << 2);
                write_cnm_v3_desc(desc_addr, 16'h0700 + case_id,
                                  src0, src1, dst);
            end
            default: begin
                case (fault_engine)
                    3: begin
                        opcode = 8'h50;
                        src0 = FP_A_LOCAL;
                        src1 = FP_B_LOCAL;
                        fault_addr = fault_phase ? src1 : src0;
                        write_cluster_desc(desc_addr, opcode, 16'h0700 + case_id,
                                           src0, src1, dst, 16'd1, 16'd1, 16'd2,
                                           32'd0, 32'd0, 32'd0, 32'd0, 8'd7);
                    end
                    4: begin
                        opcode = 8'h35;
                        src0 = GELU_A_LOCAL;
                        src1 = 32'd0;
                        fault_addr = src0;
                        write_v3_desc(desc_addr, opcode, 16'h0700 + case_id,
                                      src0, src1, dst, 16'd0, 16'd0, 16'd4);
                    end
                    5: begin
                        opcode = 8'h16;
                        src0 = CONV_A_LOCAL;
                        src1 = CONV_W_LOCAL;
                        fault_addr = fault_phase ? src1 : src0;
                        write_cluster_desc(desc_addr, opcode, 16'h0700 + case_id,
                                           src0, src1, dst, 16'd3, 16'd3, 16'd9,
                                           32'd0, 32'd0, 32'd0, 32'd0, 8'd5);
                    end
                    default: begin
                        opcode = 8'h43;
                        src0 = KV_VECTOR_LOCAL;
                        src1 = 32'd0;
                        fault_addr = src0;
                        write_cluster_desc(desc_addr, opcode, 16'h0700 + case_id,
                                           src0, src1, dst, 16'd0, 16'd0, 16'd4,
                                           {16'd1,16'd1}, 32'd16, 32'd64,
                                           32'd0, 8'd5);
                    end
                endcase
            end
        endcase

        inject_spad_parity_fault(fault_addr, parity_path, saved_parity);
        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, desc_addr);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd1);
        axil_write(REG_CPLQ_BASE, cpl_addr);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd1);
        wait_spad_idle();
        restore_spad_parity(parity_path, saved_parity);

        expected_status_error = ((fault_engine == 5) || (fault_engine == 6)) ?
                                32'h0000_0072 : 32'h0000_0052;
        if ((mutation_kind == "completion_error_code") && (case_id == 0)) begin
            // Testbench memory-image corruption checks that the directed
            // completion oracle rejects an incorrect error-code word. This
            // is not a DUT RTL mutation.
            spad_write(cpl_addr + 32'h04, expected_status_error ^ 32'd1);
            `uvm_info("CLUSTER_MUTATION_INJECTED",
                "mutation=completion_error_code target=completion_word1", UVM_LOW)
        end
        expect_spad(cpl_addr + 32'h00, 32'h0000_0700 + case_id,
                    $sformatf("random parity case%0d task ID", case_id));
        expect_spad(cpl_addr + 32'h04, expected_status_error,
                    $sformatf("random parity case%0d ERR_PARITY completion", case_id));
        for (word_idx = 0; word_idx < 16; word_idx++)
            expect_spad(dst + (word_idx << 2),
                        32'hfa17_0000 | (case_id << 8) | word_idx,
                        $sformatf("random parity case%0d no-writeback[%0d]", case_id, word_idx));
        `uvm_info("CLUSTER_FAULT_CASE_PASS", $sformatf(
            "case=%0d engine=%0d operand_phase=%0d cnm_lane=%0d address=0x%08h seed=%0d",
            case_id, fault_engine, fault_phase, cnm_lane, fault_addr, seed), UVM_LOW)
        axil_write(REG_CPLQ_HEAD, 32'd1);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
    endtask

    task automatic run_matrix_parity_cnm_owner_cross(
        input int unsigned seed,
        input int unsigned mode,
        input int signed matrix_golden[0:15][0:31]);
        bit [31:0] desc_base;
        bit [31:0] cpl_base;
        bit [31:0] matrix_dst;
        bit [31:0] cnm_dst;
        bit [31:0] parity_addr;
        bit [31:0] packed_word;
        bit [31:0] matrix_rsp_before;
        bit [31:0] cnm_rsp_before;
        bit [31:0] matrix_route_error_before;
        bit [31:0] cnm_route_error_before;
        bit [31:0] overlap_before;
        bit [31:0] shared_accept_before;
        int unsigned fault_cancel_before;
        string parity_path;
        uvm_hdl_data_t saved_parity;
        int signed expected_cnm[0:15];
        int signed a_value;
        int signed b_value;
        int unsigned row_idx;
        int unsigned k_word;
        int unsigned lane;
        int unsigned byte_idx;
        int unsigned word_idx;
        int unsigned cycle;
        int unsigned accepted_cnm_reads;
        int unsigned returned_cnm_reads;
        int unsigned accepted_cnm_writes;
        int unsigned post_abort_cnm_writes;
        bit abort_cnm_after_parity;
        bit reset_both_after_parity;
        bit reset_after_cnm_prefix;
        bit reset_seen;
        bit reset_value;
        bit overlap_seen;
        bit shared_accept_seen;
        bit matrix_response_seen;
        bit cnm_response_seen;
        bit route_mismatch_seen;
        bit abort_issued;
        bit abort_seen;
        bit abort_active_seen;
        bit monitor_done;
        int unsigned dropped_cnm_reads;
        int unsigned poll;
        bit [31:0] value;
        bit [31:0] cnm_write_addr[0:15];
        bit [31:0] cnm_write_data[0:15];

        if (mode > 3)
            `uvm_fatal("CLUSTER_PARITY_OWNER", $sformatf(
                "unsupported Matrix/CNM parity-owner mode %0d", mode))
        abort_cnm_after_parity = (mode == 1);
        reset_after_cnm_prefix = (mode == 3);
        reset_both_after_parity = (mode == 2) || reset_after_cnm_prefix;
        reset_seen = 1'b0;
        overlap_seen = 1'b0;
        shared_accept_seen = 1'b0;
        matrix_response_seen = 1'b0;
        cnm_response_seen = 1'b0;
        route_mismatch_seen = 1'b0;
        desc_base = 32'h0000_7800;
        cpl_base = 32'h0000_7900;
        matrix_dst = 32'h0005_4000;
        cnm_dst = 32'h0005_4800;
        // The baseline point faults the final A-row lane to exercise held-read
        // cancellation. The abort cross faults the first legal operand so the
        // long CNM task is still active when Matrix reports parity.
        parity_addr = reset_after_cnm_prefix ?
                      MATRIX_A_LOCAL + 32'h0000_00fc :
                      ((abort_cnm_after_parity || reset_both_after_parity) ?
                       MATRIX_A_LOCAL : MATRIX_A_LOCAL + 32'h0000_00fc);
        abort_issued = 1'b0;
        abort_seen = 1'b0;
        abort_active_seen = 1'b0;
        monitor_done = 1'b0;
        accepted_cnm_reads = 0;
        returned_cnm_reads = 0;
        accepted_cnm_writes = 0;
        post_abort_cnm_writes = 0;
        dropped_cnm_reads = 0;

        // Prepare a long legal CNM GEMV independently of Matrix's operand
        // image, so the failing Matrix cannot poison CNM's Golden result.
        for (k_word = 0; k_word < 32; k_word++) begin
            for (lane = 0; lane < 4; lane++) begin
                packed_word = '0;
                for (byte_idx = 0; byte_idx < 4; byte_idx++) begin
                    a_value = int'(k_word % 5) + int'(lane * 2) +
                              int'(byte_idx) - 5;
                    packed_word[byte_idx*8 +: 8] = a_value[7:0];
                end
                spad_write(MATRIX_LINE_STALL_CNM_A_LOCAL +
                           (k_word << 4) + (lane << 2), packed_word);
            end
        end
        for (row_idx = 0; row_idx < 16; row_idx++) begin
            expected_cnm[row_idx] = 0;
            for (k_word = 0; k_word < 32; k_word++) begin
                for (lane = 0; lane < 4; lane++) begin
                    packed_word = '0;
                    for (byte_idx = 0; byte_idx < 4; byte_idx++) begin
                        a_value = int'(k_word % 5) + int'(lane * 2) +
                                  int'(byte_idx) - 5;
                        b_value = int'(row_idx % 5) + int'(k_word % 3) +
                                  int'(lane) + int'(byte_idx) - 3;
                        packed_word[byte_idx*8 +: 8] = b_value[7:0];
                        expected_cnm[row_idx] += a_value * b_value;
                    end
                    spad_write(MATRIX_LINE_STALL_CNM_B_LOCAL +
                               ((row_idx * 32 + k_word) << 4) +
                               (lane << 2), packed_word);
                end
            end
        end

        for (word_idx = 0; word_idx < 512; word_idx++)
            spad_write(matrix_dst + (word_idx << 2),
                       32'hfa17_7000 | word_idx);
        for (word_idx = 0; word_idx < 16; word_idx++)
            spad_write(cnm_dst + (word_idx << 2),
                       32'hfa17_7800 | word_idx);
        if (reset_both_after_parity)
            for (word_idx = 0; word_idx < 8; word_idx++)
                spad_write(cpl_base + ((word_idx / 4) * 32'h10) +
                           ((word_idx % 4) * 4),
                           32'hfa17_7900 | word_idx);

        if (abort_cnm_after_parity || reset_both_after_parity) begin
            // Dispatch CNM first so it is observably in flight before Matrix
            // reaches the injected parity response and Abort/reset cancels it.
            write_cluster_desc(desc_base, 8'h21,
                               reset_after_cnm_prefix ? 16'h07ec :
                               (reset_both_after_parity ? 16'h07e8 : 16'h07e3),
                               MATRIX_LINE_STALL_CNM_A_LOCAL,
                               MATRIX_LINE_STALL_CNM_B_LOCAL, cnm_dst,
                               16'd16, 16'd1, 16'd32, 32'd0,
                               32'd0, 32'd0, 32'd0, 8'd3);
            write_v3_desc(desc_base + 32'h40, 8'h30,
                          reset_after_cnm_prefix ? 16'h07ed :
                          (reset_both_after_parity ? 16'h07e9 : 16'h07e2),
                          MATRIX_A_LOCAL, MATRIX_B_LOCAL, matrix_dst,
                          16'd16, 16'd32, 16'd16);
        end else begin
            write_v3_desc(desc_base, 8'h30, 16'h07e0,
                          MATRIX_A_LOCAL, MATRIX_B_LOCAL, matrix_dst,
                          16'd16, 16'd32, 16'd16);
            write_cluster_desc(desc_base + 32'h40, 8'h21, 16'h07e1,
                               MATRIX_LINE_STALL_CNM_A_LOCAL,
                               MATRIX_LINE_STALL_CNM_B_LOCAL, cnm_dst,
                               16'd16, 16'd1, 16'd32, 32'd0,
                               32'd0, 32'd0, 32'd0, 8'd3);
        end

        matrix_rsp_before = compute_vif.matrix_tag_response_count;
        cnm_rsp_before = compute_vif.cnm_tag_response_count;
        matrix_route_error_before = compute_vif.matrix_route_mismatch_count;
        cnm_route_error_before = compute_vif.cnm_route_mismatch_count;
        overlap_before = compute_vif.matrix_cnm_overlap_cycles;
        shared_accept_before = compute_vif.matrix_cnm_shared_accept_cycles;
        fault_cancel_before = compute_vif.matrix_banked_fault_cancel_checks;
        inject_spad_parity_fault(parity_addr, parity_path, saved_parity);

        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, desc_base);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd2);
        axil_write(REG_CPLQ_BASE, cpl_base);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        if (!abort_cnm_after_parity && !reset_both_after_parity) begin
            axil_write(REG_DOORBELL, 32'd1);
            wait_cpl_tail(32'd2);
            wait_spad_idle();
        end else begin
            fork
                begin : matrix_parity_cnm_abort_monitor
                    while (!monitor_done) begin
                        @(posedge compute_vif.aclk);
                        accepted_cnm_reads += $countones(compute_vif.cnm_accept_mask);
                        returned_cnm_reads += $countones(compute_vif.cnm_rsp_valid);
                        if (compute_vif.engine_busy[2] &&
                            compute_vif.engine_busy[3])
                            overlap_seen = 1'b1;
                        if (compute_vif.matrix_cnm_shared_accept_cycles >
                            shared_accept_before)
                            shared_accept_seen = 1'b1;
                        if (compute_vif.matri…97221 tokens truncated…lel_spad_write_bytes = compute_vif.benchmark_spad_write_bytes -
                                    parallel_spad_write_start;
        wait_spad_idle();
        if (parallel_cycles != 0)
            measured_speedup = real'(serial_total_cycles) / real'(parallel_cycles);
        `uvm_info("CLUSTER_PARALLEL_BENCH_PASS", $sformatf(
            "same Matrix/CNM/SFU/SFU work parallel cycles=%0d serial_cycles=%0d speedup=%.3f completion_order=0600,0601,0602,0603 shared_spad_contention_cycles=%0d spad_read_bytes=%0d spad_write_bytes=%0d",
            parallel_cycles, serial_total_cycles, measured_speedup,
            parallel_contention_cycles, parallel_spad_read_bytes,
            parallel_spad_write_bytes), UVM_LOW)

        if (compute_vif.overlap_cycles == 0)
            `uvm_fatal("CLUSTER_OVERLAP", "real Matrix and SFU never overlapped")
        if (compute_vif.shared_spad_contention_cycles == 0)
            `uvm_fatal("CLUSTER_SPAD_CONTENTION", "real core and banked requests never contended at ai_spad_arbiter")
        if (compute_vif.arb_banked_grants == 0 || compute_vif.arb_core_grants == 0)
            `uvm_fatal("CLUSTER_SPAD_TRAFFIC", "expected both banked and core SPAD grants")
        if (compute_vif.same_engine_launch_while_busy != 0)
            `uvm_fatal("CLUSTER_OWNER", $sformatf("same-engine launch while busy count=%0d", compute_vif.same_engine_launch_while_busy))
        if (compute_vif.matrix_a_cache_hits == 0)
            `uvm_fatal("CLUSTER_A_CACHE", "Matrix/CNM contention run recorded no A-tile cache hits")
        `uvm_info("CLUSTER_A_CACHE_CONTENTION", $sformatf(
                  "Matrix/CNM workload retained %0d A-tile cache hits under shared-port contention; standalone baseline was 16",
                  compute_vif.matrix_a_cache_hits), UVM_LOW)
        if (compute_vif.matrix_prefetch_overlap_cycles == 0)
            `uvm_fatal("CLUSTER_PREFETCH", "next-K prefetch did not overlap Matrix MAC")
        if (compute_vif.matrix_cnm_overlap_cycles == 0)
            `uvm_fatal("CLUSTER_CNM_OVERLAP", "Matrix and CNM were not simultaneously active")
        if (compute_vif.matrix_cnm_shared_accept_cycles == 0)
            `uvm_fatal("CLUSTER_CNM_ARBITRATION", "Matrix and CNM did not contend at shared banked admission")
        if (compute_vif.matrix_tag_response_count == 0 || compute_vif.cnm_tag_response_count == 0)
            `uvm_fatal("CLUSTER_CNM_RESPONSE", $sformatf("missing owner responses: Matrix=%0d CNM=%0d", compute_vif.matrix_tag_response_count, compute_vif.cnm_tag_response_count))
        if (compute_vif.matrix_route_mismatch_count != 0 || compute_vif.cnm_route_mismatch_count != 0)
            `uvm_fatal("CLUSTER_CNM_ROUTE", $sformatf("response route mismatches: Matrix=%0d CNM=%0d", compute_vif.matrix_route_mismatch_count, compute_vif.cnm_route_mismatch_count))
        if (compute_vif.cnm_response_lane_seen !== 4'hf)
            `uvm_fatal("CLUSTER_CNM_BANKS", $sformatf("expected responses from all CNM banks, observed lane mask=%b", compute_vif.cnm_response_lane_seen))
        if (compute_vif.matrix_cnm_collision_cycles == 0 ||
            compute_vif.matrix_cnm_collision_grant_cycles == 0 ||
            compute_vif.matrix_cnm_collision_matrix_wait_cycles == 0 ||
            compute_vif.matrix_cnm_collision_hold_checks == 0 ||
            compute_vif.matrix_cnm_collision_owner_violations != 0 ||
            compute_vif.matrix_cnm_collision_stability_violations != 0)
            `uvm_fatal("CLUSTER_MATRIX_CNM_BANKED_COLLISION",
                $sformatf("real Matrix/CNM banked arbitration evidence incomplete: collisions=%0d grants=%0d MatrixWait=%0d stableChecks=%0d ownerViolations=%0d holdViolations=%0d",
                    compute_vif.matrix_cnm_collision_cycles,
                    compute_vif.matrix_cnm_collision_grant_cycles,
                    compute_vif.matrix_cnm_collision_matrix_wait_cycles,
                    compute_vif.matrix_cnm_collision_hold_checks,
                    compute_vif.matrix_cnm_collision_owner_violations,
                    compute_vif.matrix_cnm_collision_stability_violations))
        `uvm_info("CLUSTER_MATRIX_CNM_BANKED_COLLISION_PASS", $sformatf(
            "real Matrix banked and CNM lane collision cycles=%0d admitted collisions=%0d Matrix wait cycles=%0d held-payload checks=%0d owner violations=%0d hold violations=%0d MatrixRsp=%0d CNMRsp=%0d route_mismatch=0",
            compute_vif.matrix_cnm_collision_cycles,
            compute_vif.matrix_cnm_collision_grant_cycles,
            compute_vif.matrix_cnm_collision_matrix_wait_cycles,
            compute_vif.matrix_cnm_collision_hold_checks,
            compute_vif.matrix_cnm_collision_owner_violations,
            compute_vif.matrix_cnm_collision_stability_violations,
            compute_vif.matrix_tag_response_count,
            compute_vif.cnm_tag_response_count), UVM_LOW)
        `uvm_info("CLUSTER_CNM_OWNER_PASS", $sformatf("Matrix tag3 responses=%0d, CNM tag5 responses=%0d, CNM lane mask=%b, overlap cycles=%0d, shared banked grants=%0d", compute_vif.matrix_tag_response_count, compute_vif.cnm_tag_response_count, compute_vif.cnm_response_lane_seen, compute_vif.matrix_cnm_overlap_cycles, compute_vif.matrix_cnm_shared_accept_cycles), UVM_LOW)
        matrix_prefetch_overlap_total = compute_vif.matrix_prefetch_overlap_cycles;
        matrix_cnm_overlap_total = compute_vif.matrix_cnm_overlap_cycles;
        cnm_grants_total = compute_vif.arb_cnm_grants;
        matrix_responses_total = compute_vif.matrix_tag_response_count;
        cnm_responses_total = compute_vif.cnm_tag_response_count;
        cnm_lanes_seen_total = compute_vif.cnm_response_lane_seen;
        overlap_total = compute_vif.overlap_cycles;
        contention_total = compute_vif.shared_spad_contention_cycles;
        banked_grants_total = compute_vif.arb_banked_grants;
        core_grants_total = compute_vif.arb_core_grants;

        for (word_idx = 0; word_idx < 512; word_idx++)
            expect_spad(MATRIX_Y_LOCAL + (word_idx << 2), matrix_golden[word_idx / 32][word_idx % 32], $sformatf("16x32x64 GEMM[%0d]", word_idx));
        for (word_idx = 0; word_idx < 16; word_idx++)
            expect_spad(CNM_Y_LOCAL + (word_idx << 2), 32'd736,
                        $sformatf("CNM GEMV row[%0d]", word_idx));
        for (word_idx = 0; word_idx < 64; word_idx++) begin
            expect_spad(GELU_Y0_LOCAL + (word_idx << 2), gelu_results[word_idx % 4],
                        $sformatf("GELU0 output[%0d]", word_idx));
            expect_spad(GELU_Y1_LOCAL + (word_idx << 2), gelu_results[word_idx % 4],
                        $sformatf("GELU1 output[%0d]", word_idx));
        end

        expect_completion(CPLQ_LOCAL + 32'h00, 16'h0600, matrix_golden[15][31], 32'd512, "Matrix");
        expect_completion(CPLQ_LOCAL + 32'h10, 16'h0601, 32'd736, 32'd16, "CNM GEMV");
        expect_completion(CPLQ_LOCAL + 32'h20, 16'h0602, -32'sd15, 32'd64, "SFU first");
        expect_completion(CPLQ_LOCAL + 32'h30, 16'h0603, -32'sd15, 32'd64, "SFU queued");
        axil_read(REG_CMDQ_HEAD, value);
        if (value !== 32'd4)
            `uvm_fatal("CLUSTER_CMDQ", $sformatf("CMDQ_HEAD expected=4 actual=%0d", value))
        axil_write(REG_CPLQ_HEAD, 32'd4);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);

        // Fill the real four-entry completion ring to its three-entry
        // capacity while four production engines execute legal, disjoint
        // tasks. The final completion must remain pending until software
        // advances CPLQ_HEAD; after release it must wrap the tail in order.
        for (word_idx = 0; word_idx < 4; word_idx++)
            spad_write(CPLQ_LOCAL + 32'h330 + (word_idx << 2),
                       32'hc07f_7200 | word_idx);
        spad_write(SCALAR_A_LOCAL, 32'h0403_0201);
        spad_write(SCALAR_B_LOCAL, 32'h0807_0605);
        write_v3_desc(CMDQ_LOCAL + 32'h300, 8'h30, 16'h0810,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, MATRIX_Y_LOCAL,
                      16'd16, 16'd32, 16'd16);
        write_cnm_v3_desc(CMDQ_LOCAL + 32'h340, 16'h0811,
                          CNM_A_LOCAL, CNM_B_LOCAL, CNM_Y_LOCAL);
        write_v3_desc(CMDQ_LOCAL + 32'h380, 8'h35, 16'h0812,
                      GELU_A_LOCAL, 32'd0, SWEEP_SFU_Y_LOCAL,
                      16'd0, 16'd0, 16'd4);
        write_cluster_desc(CMDQ_LOCAL + 32'h3c0, 8'h10, 16'h0813,
                           SCALAR_A_LOCAL, SCALAR_B_LOCAL, SCALAR_Y_LOCAL,
                           16'd0, 16'd0, 16'd1, 32'd0,
                           32'd0, 32'd0, 32'd0, 8'd3);

        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, CMDQ_LOCAL + 32'h300);
        axil_write(REG_CMDQ_SIZE, 32'd8);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd4);
        axil_write(REG_CPLQ_BASE, CPLQ_LOCAL + 32'h300);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd3);

        cplq_all_engines_idle = 1'b0;
        for (cplq_poll = 0; cplq_poll < 2000; cplq_poll++) begin
            if (compute_vif.engine_busy == 7'd0) begin
                cplq_all_engines_idle = 1'b1;
                break;
            end
            @(posedge compute_vif.aclk);
        end
        if (!cplq_all_engines_idle)
            `uvm_fatal("CLUSTER_CPLQ_BACKPRESSURE",
                $sformatf("engines did not finish while CPLQ was full; busy=%07b",
                          compute_vif.engine_busy))
        if (compute_vif.cplq_full !== 1'b1 ||
            compute_vif.processor_busy !== 1'b1)
            `uvm_fatal("CLUSTER_CPLQ_BACKPRESSURE", $sformatf(
                "full completion queue must retain dispatcher work; cplq_full=%0b processor_busy=%0b",
                compute_vif.cplq_full, compute_vif.processor_busy))

        for (cplq_poll = 0; cplq_poll < 8; cplq_poll++) begin
            axil_read(REG_CPLQ_TAIL, value);
            if (value !== 32'd3 || compute_vif.cplq_full !== 1'b1)
                `uvm_fatal("CLUSTER_CPLQ_BACKPRESSURE", $sformatf(
                    "completion tail escaped full-ring hold: tail=%0d full=%0b poll=%0d",
                    value, compute_vif.cplq_full, cplq_poll))
        end
        for (word_idx = 0; word_idx < 4; word_idx++)
            expect_spad(CPLQ_LOCAL + 32'h330 + (word_idx << 2),
                        32'hc07f_7200 | word_idx,
                        $sformatf("CPLQ full held completion sentinel[%0d]", word_idx));
        axil_read(REG_CMDQ_HEAD, value);
        if (value !== 32'd4)
            `uvm_fatal("CLUSTER_CPLQ_BACKPRESSURE", $sformatf(
                "all four descriptors must dispatch before completion backpressure: CMDQ_HEAD=%0d",
                value))

        expect_completion(CPLQ_LOCAL + 32'h300, 16'h0810,
                          matrix_golden[15][31], 32'd512,
                          "CPLQ-full Matrix head completion");
        expect_completion(CPLQ_LOCAL + 32'h310, 16'h0811, 32'd736, 32'd16,
                          "CPLQ-full CNM completion");
        expect_completion(CPLQ_LOCAL + 32'h320, 16'h0812, -32'sd15, 32'd4,
                          "CPLQ-full SFU completion");

        axil_write(REG_CPLQ_HEAD, 32'd1);
        wait_cpl_tail(32'd0);
        wait_spad_idle();
        if (compute_vif.cplq_full !== 1'b1 ||
            compute_vif.processor_busy !== 1'b0)
            `uvm_fatal("CLUSTER_CPLQ_BACKPRESSURE", $sformatf(
                "released slot must retire the pending completion, wrap tail, refill the ring, and drain dispatcher: cplq_full=%0b processor_busy=%0b",
                compute_vif.cplq_full, compute_vif.processor_busy))
        expect_completion(CPLQ_LOCAL + 32'h330, 16'h0813, 32'd70, 32'd1,
                          "CPLQ-full released Scalar completion");
        for (word_idx = 0; word_idx < 512; word_idx++)
            expect_spad(MATRIX_Y_LOCAL + (word_idx << 2),
                        matrix_golden[word_idx / 32][word_idx % 32],
                        $sformatf("CPLQ full Matrix Golden[%0d]", word_idx));
        for (word_idx = 0; word_idx < 16; word_idx++)
            expect_spad(CNM_Y_LOCAL + (word_idx << 2), 32'd736,
                        $sformatf("CPLQ full CNM Golden[%0d]", word_idx));
        for (word_idx = 0; word_idx < 4; word_idx++)
            expect_spad(SWEEP_SFU_Y_LOCAL + (word_idx << 2),
                        gelu_results[word_idx],
                        $sformatf("CPLQ full SFU Golden[%0d]", word_idx));
        expect_spad(SCALAR_Y_LOCAL, 32'd70, "CPLQ full Scalar Golden");
        `uvm_info("CLUSTER_CPLQ_BACKPRESSURE_PASS",
            "four real engines completed; blocked_tail=3 released_head=1 wrapped_tail=0 all_engines_idle=1; ordered completion, retained sentinel, and four Goldens checked",
            UVM_LOW)
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);

        // C1 real-top sweep: issue one descriptor for every physical engine
        // in one queue window. Each engine gets a legal, long-running workload
        // with disjoint SPAD operands, so every observed busy overlap is real
        // concurrent execution and not an artificial busy signal.
        for (word_idx = 0; word_idx < 128; word_idx++) begin
            spad_write(C1_SCALAR_A_LOCAL + (word_idx << 2), 32'h0101_0101);
            spad_write(C1_SCALAR_B_LOCAL + (word_idx << 2), 32'h0101_0101);
            if ((word_idx % 2) == 0) begin
                spad_write(C1_FP_A_LOCAL + (word_idx << 1), 32'h3f80_3f80);
                spad_write(C1_FP_B_LOCAL + (word_idx << 1), 32'h3f80_3f80);
            end
            spad_write(C1_KV_VECTOR_LOCAL + (word_idx << 2), 32'h0000_0100 + word_idx);
            spad_write(C1_KV_CACHE_LOCAL + 32'h50 + (word_idx << 2), 32'hbad0_6400 + word_idx);
        end
        // Keep the dedicated four-word KV parity-fault operand initialized;
        // its raw parity bit must be known before the directed fault deposit.
        for (word_idx = 0; word_idx < 4; word_idx++)
            spad_write(KV_VECTOR_LOCAL + (word_idx << 2), (word_idx + 1) * 32'h100);
        // Preserve the compact operands used by the independent fault and
        // reset sweeps that follow C1; those tests inject parity into the
        // original low-address regions rather than the long C1 buffers.
        spad_write(SCALAR_A_LOCAL, 32'h0403_0201);
        spad_write(SCALAR_B_LOCAL, 32'h0807_0605);
        spad_write(FP_A_LOCAL, 32'h4000_3f80);
        spad_write(FP_B_LOCAL, 32'h4080_4040);
        spad_write(FP_Y_LOCAL, 32'hdead_cafe);
        for (word_idx = 0; word_idx < 9; word_idx++) begin
            spad_write(CONV_A_LOCAL + (word_idx << 2), word_idx + 1);
            spad_write(CONV_W_LOCAL + (word_idx << 2), 32'd1);
        end
        spad_write(CONV_Y_LOCAL, 32'hdead_c0de);
        for (word_idx = 0; word_idx < 4; word_idx++)
            spad_write(KV_CACHE_LOCAL + 32'h50 + (word_idx << 2),
                       32'hbad0_6400 + word_idx);
        spad_write(C1_SCALAR_Y_LOCAL, 32'hdead_cafe);
        spad_write(C1_FP_Y_LOCAL, 32'hdead_cafe);

        for (c1_k = 0; c1_k < 64; c1_k++) begin
            for (c1_col = 0; c1_col < 4; c1_col++) begin
                case (c1_col)
                    0: packed_word = 32'h0202_0202;
                    1: packed_word = 32'h0303_0303;
                    2: packed_word = 32'h0404_0404;
                    default: packed_word = 32'h0505_0505;
                endcase
                spad_write(C1_CNM_A_LOCAL + (c1_k << 4) + (c1_col << 2), packed_word);
            end
            for (c1_row = 0; c1_row < 16; c1_row++) begin
                for (c1_col = 0; c1_col < 4; c1_col++) begin
                    case (c1_col)
                        0: packed_word = 32'h0707_0707;
                        1: packed_word = 32'h0b0b_0b0b;
                        2: packed_word = 32'h0d0d_0d0d;
                        default: packed_word = 32'h1111_1111;
                    endcase
                    spad_write(C1_CNM_B_LOCAL + (((c1_row * 64) + c1_k) << 4) + (c1_col << 2), packed_word);
                end
            end
        end
        for (word_idx = 0; word_idx < 128; word_idx++) begin
            spad_write(C1_SFU_A_LOCAL + (word_idx << 2), gelu_values[word_idx % 4]);
            spad_write(C1_SFU_Y_LOCAL + (word_idx << 2), 32'hdead_0000 | word_idx);
        end
        for (word_idx = 0; word_idx < 256; word_idx++)
            spad_write(C1_CONV_A_LOCAL + (word_idx << 2), 32'd1);
        for (word_idx = 0; word_idx < 9; word_idx++)
            spad_write(C1_CONV_W_LOCAL + (word_idx << 2), 32'd1);
        spad_write(C1_CONV_Y_LOCAL, 32'hdead_c0de);

        write_v3_desc(CLUSTER_SWEEP_CMDQ + 32'h000, 8'h30, 16'h0640,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, SWEEP_MATRIX_Y_LOCAL,
                      16'd16, 16'd32, 16'd16);
        write_cnm_v3_desc(CLUSTER_SWEEP_CMDQ + 32'h040, 16'h0641,
                          C1_CNM_A_LOCAL, C1_CNM_B_LOCAL, C1_CNM_Y_LOCAL);
        spad_write(CLUSTER_SWEEP_CMDQ + 32'h054, {16'd1, 16'd16});
        spad_write(CLUSTER_SWEEP_CMDQ + 32'h058, 32'd64);
        write_v3_desc(CLUSTER_SWEEP_CMDQ + 32'h080, 8'h35, 16'h0642,
                      C1_SFU_A_LOCAL, 32'd0, C1_SFU_Y_LOCAL,
                      16'd0, 16'd0, 16'd128);
        write_cluster_desc(CLUSTER_SWEEP_CMDQ + 32'h0c0, 8'h10, 16'h0643,
                           C1_SCALAR_A_LOCAL, C1_SCALAR_B_LOCAL, C1_SCALAR_Y_LOCAL,
                           16'd0, 16'd0, 16'd128, 32'd0,
                           32'd0, 32'd0, 32'd0, 8'd3);
        write_cluster_desc(CLUSTER_SWEEP_CMDQ + 32'h100, 8'h50, 16'h0644,
                           C1_FP_A_LOCAL, C1_FP_B_LOCAL, C1_FP_Y_LOCAL,
                           16'd1, 16'd1, 16'd128, 32'd0,
                           32'd0, 32'd0, 32'd0, 8'd7);
        write_cluster_desc(CLUSTER_SWEEP_CMDQ + 32'h140, 8'h16, 16'h0645,
                           C1_CONV_A_LOCAL, C1_CONV_W_LOCAL, C1_CONV_Y_LOCAL,
                           16'd16, 16'd16, 16'd9, 32'd0,
                           32'd0, 32'd0, 32'd0, 8'd5);
        write_cluster_desc(CLUSTER_SWEEP_CMDQ + 32'h180, 8'h43, 16'h0646,
                           C1_KV_VECTOR_LOCAL, 32'd0, C1_KV_CACHE_LOCAL,
                           16'd0, 16'd0, 16'd128, {16'd1,16'd1},
                           32'd16, 32'd64, 32'd0, 8'd5);

        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, CLUSTER_SWEEP_CMDQ);
        axil_write(REG_CMDQ_SIZE, 32'd8);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd7);
        axil_write(REG_CPLQ_BASE, CLUSTER_SWEEP_CPLQ);
        axil_write(REG_CPLQ_SIZE, 32'd8);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        engine_pair_overlap_seen = '0;
        max_active_engines = 0;
        c1_run_started = 1'b0;
        c1_run_complete = 1'b0;
        axil_write(REG_DOORBELL, 32'd1);
        for (pair_poll = 0; pair_poll < 60000; pair_poll++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.processor_busy || (compute_vif.engine_busy != 7'd0) ||
                compute_vif.cpl_valid)
                c1_run_started = 1'b1;
            if ($countones(compute_vif.engine_busy) > max_active_engines)
                max_active_engines = $countones(compute_vif.engine_busy);
            pair_index = 0;
            for (pair_i = 0; pair_i < 7; pair_i++) begin
                for (pair_j = pair_i + 1; pair_j < 7; pair_j++) begin
                    if (compute_vif.engine_busy[pair_i] &&
                        compute_vif.engine_busy[pair_j])
                        engine_pair_overlap_seen[pair_index] = 1'b1;
                    pair_index++;
                end
            end
            if (c1_run_started && !compute_vif.processor_busy &&
                (compute_vif.engine_busy == 7'd0) && !compute_vif.cpl_valid) begin
                c1_run_complete = 1'b1;
                break;
            end
        end
        if (!c1_run_complete)
            `uvm_fatal("CLUSTER_ENGINE_PAIR_CROSS",
                "all-engine C1 queue did not drain before overlap-monitor timeout")
        axil_read(REG_CPLQ_TAIL, value);
        if (value !== 32'd7)
            `uvm_fatal("CLUSTER_ENGINE_PAIR_CROSS", $sformatf(
                "all-engine C1 completion tail expected=7 actual=%0d", value))
        if (engine_pair_overlap_seen !== 21'h1f_ffff)
            `uvm_fatal("CLUSTER_ENGINE_PAIR_CROSS", $sformatf(
                "real-engine overlap incomplete: pair mask=%06h expected=1fffff max_active=%0d",
                engine_pair_overlap_seen, max_active_engines))
        engine_pair_overlap_bins_hit = 0;
        for (pair_index = 0; pair_index < 21; pair_index++) begin
            if (engine_pair_overlap_seen[pair_index]) begin
                engine_pair_overlap_cov_idx = pair_index;
                engine_pair_overlap_cg.sample();
                engine_pair_overlap_bins_hit++;
            end
        end
        if (engine_pair_overlap_bins_hit != 21 ||
            engine_pair_overlap_cg.get_coverage() < 100.0)
            `uvm_fatal("CLUSTER_ENGINE_PAIR_COVERAGE", $sformatf(
                "real engine-pair coverage bins=%0d/21 coverage=%0.1f%% expected=100.0%%",
                engine_pair_overlap_bins_hit, engine_pair_overlap_cg.get_coverage()))
        wait_spad_idle();

        for (word_idx = 0; word_idx < 512; word_idx++)
            expect_spad(SWEEP_MATRIX_Y_LOCAL + (word_idx << 2),
                        matrix_golden[word_idx / 32][word_idx % 32],
                        $sformatf("C1 Matrix Golden[%0d]", word_idx));
        for (word_idx = 0; word_idx < 16; word_idx++)
            expect_spad(C1_CNM_Y_LOCAL + (word_idx << 2), 32'd47104,
                        $sformatf("C1 CNM Golden[%0d]", word_idx));
        for (word_idx = 0; word_idx < 128; word_idx++) begin
            expect_spad(C1_SFU_Y_LOCAL + (word_idx << 2), gelu_results[word_idx % 4],
                        $sformatf("C1 SFU Golden[%0d]", word_idx));
            expect_spad(C1_KV_CACHE_LOCAL + 32'h50 + (word_idx << 2),
                        32'h0000_0100 + word_idx,
                        $sformatf("C1 KV write Golden[%0d]", word_idx));
        end
        expect_spad(C1_SCALAR_Y_LOCAL, 32'd512, "C1 scalar INT8 VDOT Golden");
        expect_spad(C1_FP_Y_LOCAL, 32'h4300_0000, "C1 BF16 dot Golden");
        for (word_idx = 0; word_idx < 196; word_idx++)
            expect_spad(C1_CONV_Y_LOCAL + (word_idx << 2), 32'd9,
                        $sformatf("C1 CONV3x3 Golden[%0d]", word_idx));
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h00, 16'h0640,
                          matrix_golden[15][31], 32'd512, "C1 Matrix");
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h10, 16'h0641,
                          32'd47104, 32'd16, "C1 CNM");
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h20, 16'h0642,
                          -32'sd15, 32'd128, "C1 SFU");
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h30, 16'h0643,
                          32'd512, 32'd1, "C1 scalar INT8");
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h40, 16'h0644,
                          32'h4300_0000, 32'd128, "C1 BF16");
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h50, 16'h0645,
                          32'd9, 32'd196, "C1 CONV3x3");
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h60, 16'h0646,
                          32'h0000_017f, 32'd128, "C1 KV write");
        for (engine_idx = 0; engine_idx < 7; engine_idx++) begin
            if (compute_vif.engine_launch_count[engine_idx] == 0)
                `uvm_fatal("CLUSTER_ENGINE_COVERAGE", $sformatf(
                    "real top did not launch engine %0d", engine_idx))
        end
        if (compute_vif.engine_backpressure_cycles == 0 ||
            compute_vif.engine_backpressure_seen == 0)
            `uvm_fatal("CLUSTER_ENGINE_BACKPRESSURE", "no engine request was denied by the shared compute SPAD mux")
        `uvm_info("CLUSTER_ALL_ENGINES_PASS", $sformatf(
                  "all seven production engines launched and matched SPAD Golden; real pair overlaps=21/21 mask=%06h max_active=%0d compute-request backpressure cycles=%0d stalled-engine-mask=%07b",
                  engine_pair_overlap_seen, max_active_engines,
                  compute_vif.engine_backpressure_cycles,
                  compute_vif.engine_backpressure_seen), UVM_LOW)
        `uvm_info("CLUSTER_ALL_ENGINE_PAIR_COVERAGE_PASS", $sformatf(
            "pair bins=%0d/21 coverage=%0.1f%% sampled only from observed overlap mask=%06h",
            engine_pair_overlap_bins_hit, engine_pair_overlap_cg.get_coverage(),
            engine_pair_overlap_seen), UVM_LOW)
        axil_read(REG_CMDQ_HEAD, value);
        if (value !== 32'd7)
            `uvm_fatal("CLUSTER_ENGINE_COVERAGE", $sformatf("C1 CMDQ_HEAD expected=7 actual=%0d", value))
        axil_write(REG_CPLQ_HEAD, 32'd7);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);

        // Read the head/token entry back through the real KV engine after the
        // KV-write completion, checking both stride address generation and
        // the complete 128-word payload.
        write_cluster_desc(CLUSTER_SWEEP_CMDQ, 8'h44, 16'h0647,
                           C1_KV_CACHE_LOCAL, 32'd0, C1_KV_READ_LOCAL,
                           16'd0, 16'd0, 16'd128, {16'd1,16'd1},
                           32'd16, 32'd64, 32'd0, 8'd5);
        axil_write(REG_CMDQ_BASE, CLUSTER_SWEEP_CMDQ);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd1);
        axil_write(REG_CPLQ_BASE, CLUSTER_SWEEP_CPLQ + 32'h100);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd1);
        wait_spad_idle();
        for (word_idx = 0; word_idx < 128; word_idx++)
            expect_spad(C1_KV_READ_LOCAL + (word_idx << 2),
                        32'h0000_0100 + word_idx,
                        $sformatf("C1 KV read Golden[%0d]", word_idx));
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h100, 16'h0647,
                          32'h0000_017f, 32'd128, "C1 KV read");
        axil_write(REG_CPLQ_HEAD, 32'd1);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);

        // Seeded randomized ordering of the parity fault cross:
        // all seven engines, A/B operand phase where defined, all CNM lanes;
        // every failed operation must retire ERR_PARITY without writeback.
        for (word_idx = 0; word_idx < 4; word_idx++) begin
            spad_write(MATRIX_FAULT_A_LOCAL + (word_idx << 2),
                       32'h1100_0000 | word_idx);
            spad_write(MATRIX_FAULT_B_LOCAL + (word_idx << 2),
                       32'h2200_0000 | word_idx);
        end
        for (word_idx = 0; word_idx < 9; word_idx++) begin
            spad_write(CONV_A_LOCAL + (word_idx << 2), word_idx + 1);
            spad_write(CONV_W_LOCAL + (word_idx << 2), 32'd1);
        end
        for (fault_i = 0; fault_i < 18; fault_i++) fault_order[fault_i] = fault_i;
        for (fault_i = 17; fault_i > 0; fault_i--) begin
            rng_state = rng_state ^ (rng_state << 13);
            rng_state = rng_state ^ (rng_state >> 17);
            rng_state = rng_state ^ (rng_state << 5);
            fault_j = rng_state % (fault_i + 1);
            fault_swap = fault_order[fault_i];
            fault_order[fault_i] = fault_order[fault_j];
            fault_order[fault_j] = fault_swap;
        end
        fault_cases_seen = '0;
        for (fault_i = 0; fault_i < 18; fault_i++) begin
            fault_case_id = fault_order[fault_i];
            if (fault_cases_seen[fault_case_id])
                `uvm_fatal("CLUSTER_FAULT_CROSS", $sformatf("duplicate randomized fault case=%0d", fault_case_id))
            fault_cases_seen[fault_case_id] = 1'b1;
            run_random_parity_case(fault_case_id, seed);
        end
        if (fault_cases_seen !== 18'h3ffff)
            `uvm_fatal("CLUSTER_FAULT_CROSS", $sformatf("fault cross incomplete: seen=%h", fault_cases_seen))
        `uvm_info("CLUSTER_RANDOM_FAULT_CROSS_PASS", $sformatf(
            "parity cases=18/18; engines={INT8,Matrix,CNM,BF16,SFU,Conv,KV}; operand phases={A,B where defined}; CNM lanes=4/4; randomized_order_seed=%0d",
            seed), UVM_LOW)

        run_matrix_parity_cnm_owner_cross(seed, 0, matrix_golden);
        run_matrix_parity_cnm_owner_cross(seed, 1, matrix_golden);
        run_matrix_parity_cnm_owner_cross(seed, 2, matrix_golden);
        run_matrix_parity_cnm_owner_cross(seed, 3, matrix_golden);
        run_matrix_protection_cnm_owner_cross(seed, 1'b0, 1'b0, 1'b0);
        run_matrix_protection_cnm_owner_cross(seed, 1'b1, 1'b0, 1'b0);
        run_matrix_protection_cnm_owner_cross(seed, 1'b0, 1'b1, 1'b0);
        run_matrix_protection_cnm_owner_cross(seed, 1'b0, 1'b1, 1'b1);
        run_cnm_protection_matrix_owner_cross(seed, matrix_golden, 1'b0, 1'b0, 1'b0);
        run_cnm_protection_matrix_owner_cross(seed, matrix_golden, 1'b1, 1'b0, 1'b0);
        run_cnm_protection_matrix_owner_cross(seed, matrix_golden, 1'b0, 1'b1, 1'b0);
        run_cnm_protection_matrix_owner_cross(seed, matrix_golden, 1'b1, 1'b0, 1'b1);

        // Cross source-A, source-B where present, and writeback protection
        // phases on real engines. SFU and KV have no second source operand.
        protection_case_count = 0;
        for (engine_idx = 0; engine_idx < 7; engine_idx++) begin
            run_real_engine_protection_case(engine_idx, 0, seed);
            protection_case_count++;
        end
        for (engine_idx = 0; engine_idx < 7; engine_idx++) begin
            if ((engine_idx == 0) || (engine_idx == 1) || (engine_idx == 2) ||
                (engine_idx == 3) || (engine_idx == 5)) begin
                run_real_engine_protection_case(engine_idx, 1, seed);
                protection_case_count++;
            end
        end
        for (engine_idx = 0; engine_idx < 7; engine_idx++) begin
            run_real_engine_protection_case(engine_idx, 2, seed);
            protection_case_count++;
        end
        if (protection_case_count != 19)
            `uvm_fatal("CLUSTER_PROTECTION", $sformatf(
                "expected 19 engine/phase cases, observed %0d", protection_case_count))
        `uvm_info("CLUSTER_PROTECTION_CROSS_PASS", $sformatf(
            "protection cases=19/19; sourceA=7 sourceB=5 writeback=7 across real engines; descriptor fetch/completion writes permitted; seed=%0d",
            seed), UVM_LOW)

        // Abort two real in-flight engines after their overlap is observed.
        // Sentinels prove the Matrix tile has not started writeback at abort.
        for (word_idx = 0; word_idx < 4; word_idx++)
            spad_write(32'h0003_1000 + (word_idx << 2), 32'hbad0_0600 + word_idx);
        write_v3_desc(CMDQ_LOCAL + 32'h100, 8'h30, 16'h0610,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, 32'h0003_1000,
                      16'd16, 16'd16, 16'd16);
        write_v3_desc(CMDQ_LOCAL + 32'h140, 8'h35, 16'h0611,
                      GELU_A_LOCAL, 32'd0, 32'h0003_1100,
                      16'd0, 16'd0, 16'd1024);
        axil_write(REG_CMDQ_BASE, CMDQ_LOCAL + 32'h100);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd2);
        axil_write(REG_CPLQ_BASE, CPLQ_LOCAL + 32'h100);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        axil_write(REG_DOORBELL, 32'd1);
        wait_matrix_sfu_overlap();
        wait_matrix_prefetch_active();
        axil_write(REG_ABORT, 32'd1);
        wait_cpl_tail(32'd2);
        if (compute_vif.multi_engine_abort_cycles == 0)
            `uvm_fatal("CLUSTER_ABORT_CROSS", "software abort was not sampled while multiple real engines were active")
        `uvm_info("CLUSTER_ABORT_CROSS_PASS", $sformatf(
                  "simultaneous Matrix/SFU abort observed for %0d cycles",
                  compute_vif.multi_engine_abort_cycles), UVM_LOW)
        expect_spad(CPLQ_LOCAL + 32'h100, 32'h0000_0610, "abort Matrix task ID");
        expect_spad(CPLQ_LOCAL + 32'h104, 32'h0000_0032, "abort Matrix status/code");
        expect_spad(CPLQ_LOCAL + 32'h110, 32'h0000_0611, "abort SFU task ID");
        expect_spad(CPLQ_LOCAL + 32'h114, 32'h0000_0032, "abort SFU status/code");
        for (word_idx = 0; word_idx < 4; word_idx++)
            expect_spad(32'h0003_1000 + (word_idx << 2), 32'hbad0_0600 + word_idx,
                        $sformatf("abort Matrix no-writeback[%0d]", word_idx));
        if (compute_vif.engine_busy != 0)
            `uvm_fatal("CLUSTER_ABORT", $sformatf("abort completion published with engine_busy=%07b", compute_vif.engine_busy))
        axil_write(REG_CPLQ_HEAD, 32'd2);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);

        // Reset both real engines while they are active. The behavioral SRAM
        // contents are retained across accelerator reset; the command and
        // completion lifecycle state must be cleared without stale writeback.
        for (word_idx = 0; word_idx < 4; word_idx++)
            spad_write(32'h0003_2000 + (word_idx << 2), 32'hbad0_0620 + word_idx);
        write_v3_desc(CMDQ_LOCAL + 32'h200, 8'h30, 16'h0620,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, 32'h0003_2000,
                      16'd16, 16'd16, 16'd16);
        write_v3_desc(CMDQ_LOCAL + 32'h240, 8'h35, 16'h0621,
                      GELU_A_LOCAL, 32'd0, 32'h0003_2100,
                      16'd0, 16'd0, 16'd1024);
        axil_write(REG_CMDQ_BASE, CMDQ_LOCAL + 32'h200);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd2);
        axil_write(REG_CPLQ_BASE, CPLQ_LOCAL + 32'h200);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        axil_write(REG_DOORBELL, 32'd1);
        wait_matrix_sfu_overlap();
        wait_matrix_read_accept();
        wait_matrix_prefetch_active();
        recovery_start_cycle = compute_vif.sim_cycles;
        #1ns;
        reset_value = 1'b0;
        reset_ok = uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", reset_value);
        if (!reset_ok)
            `uvm_fatal("CLUSTER_RESET", "failed to assert accelerator reset with Matrix and SFU active")
        repeat (4) @(posedge compute_vif.aclk);
        if (compute_vif.engine_busy !== 7'b0)
            `uvm_fatal("CLUSTER_RESET", $sformatf("engines did not clear during reset: %07b", compute_vif.engine_busy))
        reset_value = 1'b1;
        reset_ok = uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", reset_value);
        if (!reset_ok)
            `uvm_fatal("CLUSTER_RESET", "failed to release accelerator reset")
        repeat (8) @(posedge compute_vif.aclk);
        axil_read(REG_CPLQ_TAIL, value);
        if (value !== 32'd0)
            `uvm_fatal("CLUSTER_RESET", $sformatf("stale completion tail after reset: %0d", value))
        for (word_idx = 0; word_idx < 4; word_idx++)
            expect_spad(32'h0003_2000 + (word_idx << 2), 32'hbad0_0620 + word_idx,
                        $sformatf("reset Matrix no-writeback[%0d]", word_idx));

        // Prove the real cluster and queue path recover after reset by
        // executing a fresh SFU task and checking its completion and image.
        write_v3_desc(CMDQ_LOCAL + 32'h300, 8'h35, 16'h0622,
                      GELU_A_LOCAL, 32'd0, GELU_Y0_LOCAL,
                      16'd0, 16'd0, 16'd4);
        axil_write(REG_CMDQ_BASE, CMDQ_LOCAL + 32'h300);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd1);
        axil_write(REG_CPLQ_BASE, CPLQ_LOCAL + 32'h300);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd1);
        recovery_cycles = compute_vif.sim_cycles - recovery_start_cycle;
        expect_completion(CPLQ_LOCAL + 32'h300, 16'h0622, -32'sd15, 32'd4,
                          "post-reset SFU recovery");
        expect_spad(GELU_Y0_LOCAL + 32'h00, 32'd8, "post-reset GELU output0");
        expect_spad(GELU_Y0_LOCAL + 32'h04, -32'sd8, "post-reset GELU output1");
        expect_spad(GELU_Y0_LOCAL + 32'h08, 32'd17, "post-reset GELU output2");
        expect_spad(GELU_Y0_LOCAL + 32'h0c, -32'sd15, "post-reset GELU output3");
        axil_write(REG_CPLQ_HEAD, 32'd1);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
        overlap_total += compute_vif.overlap_cycles;
        contention_total += compute_vif.shared_spad_contention_cycles;
        banked_grants_total += compute_vif.arb_banked_grants;
        core_grants_total += compute_vif.arb_core_grants;
        `uvm_info("CLUSTER_RESET_RECOVERY_PASS", "active Matrix/SFU reset discarded both in-flight tasks, preserved SRAM sentinels, and accepted a fresh post-reset SFU task", UVM_LOW)
        `uvm_info("CLUSTER_RECOVERY_BENCH", $sformatf(
            "active reset-to-recovery completion=%0d cycles; scoreboard later reports reset-dropped accepted SPAD reads",
            recovery_cycles), UVM_LOW)

        run_dma_store_response_test();
        run_banked_vdot_cmdq_dispatch_test(seed);
        run_scalar_gemv_gemm_cmdq_dispatch_test(seed);
        run_scalar_cmdq_numeric_boundary_test(seed);
        run_scalar_legacy_conv_cmdq_test(seed);
        run_scalar_gemv_abort_write_prefix(seed);
        run_cnm_inflight_parameter_latch_test();
        run_launch_snapshot_and_unused_fields_test();
        run_inflight_parameter_latch_test();
        run_matrix_inflight_parameter_latch_test(matrix_golden);
        run_sfu_inflight_parameter_latch_test();
        run_fp_inflight_parameter_latch_test();
        run_conv_inflight_parameter_latch_test();
        run_kv_inflight_parameter_latch_test();
        run_shared_readonly_isolation_test();
        check_request_stability();
        run_engine_abort_drain_sweep();
        run_sfu_abort_write_prefix(seed);
        run_sfu_reset_write_prefix(seed);
        run_conv_abort_write_prefix(seed);
        run_conv_reset_write_prefix(seed);
        run_kv_abort_write_prefix(seed);
        run_matrix_abort_write_prefix(seed);
        run_matrix_line_abort_write_prefix(seed);
        run_cnm_abort_write_prefix(seed);
        run_engine_reset_drain_sweep();
        run_engine_parity_reset_sweep(seed);
        run_matrix_parity_reset_epoch_case(seed);
        run_matrix_protection_reset_epoch_case(seed);
        run_matrix_protection_cnm_pending_reset_case(seed);
        run_engine_protection_reset_sweep(seed);

        `uvm_info("COMPUTE_CLUSTER_REAL_UVM_PASS", $sformatf(
            "standalone Matrix16x32x64 Golden + 16 A-tile reuse hits; parallel Matrix/CNM GEMV with separate response tags and four-bank Golden + next-K prefetch + queued SFU tasks + concurrent abort/reset/recovery seed=%0d; prefetch_overlap=%0d matrix_cnm_overlap=%0d matrix_rsp=%0d cnm_rsp=%0d cnm_lanes=%b overlap=%0d arbiter_contention=%0d banked_grants=%0d cnm_grants=%0d core_grants=%0d",
            seed, matrix_prefetch_overlap_total,
            matrix_cnm_overlap_total, matrix_responses_total, cnm_responses_total,
            cnm_lanes_seen_total,
            overlap_total, contention_total,
            banked_grants_total, cnm_grants_total,
            core_grants_total), UVM_LOW)
    endtask
endclass
