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
        matrix_cnm_shared_reset_cg = new();
        matrix_cnm_prefix_reset_cg = new();
        cnm_protection_matrix_prefix_reset_cg = new();
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
                        if (compute_vif.matrix_tag_response_count > matrix_rsp_before)
                            matrix_response_seen = 1'b1;
                        if (compute_vif.cnm_tag_response_count > cnm_rsp_before)
                            cnm_response_seen = 1'b1;
                        if (compute_vif.matrix_route_mismatch_count !=
                                matrix_route_error_before ||
                            compute_vif.cnm_route_mismatch_count !=
                                cnm_route_error_before)
                            route_mismatch_seen = 1'b1;
                        if (compute_vif.engine_req_valid[2] &&
                            compute_vif.engine_req_ready[2] &&
                            compute_vif.engine_req_write[2] &&
                            (compute_vif.engine_req_addr[2*32 +: 32] >= cnm_dst) &&
                            (compute_vif.engine_req_addr[2*32 +: 32] < cnm_dst + 32'h40)) begin
                            if (accepted_cnm_writes >= 16)
                                `uvm_fatal("CLUSTER_PARITY_ABORT_OWNER",
                                    "CNM accepted more output writes than its 16-row GEMV")
                            cnm_write_addr[accepted_cnm_writes] =
                                compute_vif.engine_req_addr[2*32 +: 32];
                            cnm_write_data[accepted_cnm_writes] =
                                compute_vif.engine_req_wdata[2*32 +: 32];
                            if (cnm_write_addr[accepted_cnm_writes] !==
                                cnm_dst + (accepted_cnm_writes << 2))
                                `uvm_fatal("CLUSTER_PARITY_ABORT_OWNER", $sformatf(
                                    "CNM Abort output writes are not a contiguous prefix: index=%0d expected=0x%08h actual=0x%08h",
                                    accepted_cnm_writes,
                                    cnm_dst + (accepted_cnm_writes << 2),
                                    cnm_write_addr[accepted_cnm_writes]))
                            accepted_cnm_writes++;
                            if (abort_active_seen)
                                post_abort_cnm_writes++;
                        end
                        if (compute_vif.dut_abort_active) begin
                            abort_seen = 1'b1;
                            abort_active_seen = 1'b1;
                        end
                    end
                end
                begin : matrix_parity_cnm_abort_control
                    axil_write(REG_DOORBELL, 32'd1);
                    for (cycle = 0; cycle < 30000 && !abort_issued; cycle++) begin
                        @(posedge compute_vif.aclk);
                        if ((abort_cnm_after_parity &&
                             compute_vif.matrix_response_fault) ||
                            (reset_both_after_parity &&
                             compute_vif.engine_parity_rsp_error[3])) begin
                            if (!compute_vif.engine_busy[2])
                                `uvm_fatal("CLUSTER_PARITY_ABORT_OWNER",
                                    "Matrix parity was reported after the concurrent CNM engine became idle")
                            if (reset_both_after_parity) begin
                                // Matrix sampled the registered parity response
                                // on this edge. Reset at +1ns while CNM still
                                // has a response outstanding in the shared SPAD.
                                #1ns;
                                if (!compute_vif.engine_busy[3] ||
                                    (accepted_cnm_reads <= returned_cnm_reads))
                                    `uvm_fatal("CLUSTER_PARITY_RESET_OWNER", $sformatf(
                                        "reset point lacks concurrent Matrix/CNM activity or a pending CNM response: busy=%07b accepted=%0d returned=%0d",
                                        compute_vif.engine_busy, accepted_cnm_reads,
                                        returned_cnm_reads))
                                dropped_cnm_reads = accepted_cnm_reads -
                                                   returned_cnm_reads;
                                matrix_response_seen = 1'b1;
                                cnm_response_seen = (returned_cnm_reads != 0);
                                if (!reset_after_cnm_prefix) begin
                                    shared_reset_coverage_phase = 1;
                                    matrix_cnm_shared_reset_cg.sample();
                                end
                                if (accepted_cnm_writes >= 16)
                                    `uvm_fatal("CLUSTER_PARITY_RESET_OWNER",
                                        "CNM completed before the shared-reset point")
                                if (reset_after_cnm_prefix &&
                                    (accepted_cnm_writes == 0 ||
                                     accepted_cnm_writes >= 16))
                                    `uvm_fatal("CLUSTER_PARITY_RESET_PREFIX_OWNER", $sformatf(
                                        "prefix-reset point requires 1..15 accepted Golden writes, observed %0d/16",
                                        accepted_cnm_writes))
                                if (reset_after_cnm_prefix) begin
                                    shared_reset_prefix_coverage_phase = 1;
                                    matrix_cnm_prefix_reset_cg.sample();
                                end
                                reset_value = 1'b0;
                                if (!uvm_hdl_deposit("tb_ai_accel_uvm.aresetn",
                                                     reset_value))
                                    `uvm_fatal("CLUSTER_PARITY_RESET_OWNER",
                                        "failed to assert reset during Matrix/CNM overlap")
                                restore_spad_parity(parity_path, saved_parity);
                                reset_seen = 1'b1;
                                monitor_done = 1'b1;
                                repeat (4) begin
                                    @(posedge compute_vif.aclk);
                                    if (compute_vif.rsp_valid !== 1'b0 ||
                                        compute_vif.matrix_rsp_valid !== 1'b0 ||
                                        compute_vif.cnm_rsp_valid !== 4'b0 ||
                                        compute_vif.engine_parity_rsp_error !== 7'b0)
                                        `uvm_fatal("CLUSTER_PARITY_RESET_OWNER",
                                            "old-epoch response visible while reset is asserted")
                                end
                                if (compute_vif.engine_busy !== 7'b0)
                                    `uvm_fatal("CLUSTER_PARITY_RESET_OWNER", $sformatf(
                                        "compute engines remained active in reset: busy=%07b",
                                        compute_vif.engine_busy))
                                if (!reset_after_cnm_prefix) begin
                                    shared_reset_coverage_phase = 2;
                                    matrix_cnm_shared_reset_cg.sample();
                                end
                                if (reset_after_cnm_prefix) begin
                                    shared_reset_prefix_coverage_phase = 2;
                                    matrix_cnm_prefix_reset_cg.sample();
                                end
                                #1ns;
                                reset_value = 1'b1;
                                if (!uvm_hdl_deposit("tb_ai_accel_uvm.aresetn",
                                                     reset_value))
                                    `uvm_fatal("CLUSTER_PARITY_RESET_OWNER",
                                        "failed to release reset after Matrix/CNM overlap")
                                repeat (8) begin
                                    @(posedge compute_vif.aclk);
                                    if (compute_vif.rsp_valid !== 1'b0 ||
                                        compute_vif.matrix_rsp_valid !== 1'b0 ||
                                        compute_vif.cnm_rsp_valid !== 4'b0 ||
                                        compute_vif.engine_parity_rsp_error !== 7'b0)
                                        `uvm_fatal("CLUSTER_PARITY_RESET_OWNER",
                                            "stale owner response escaped the reset epoch")
                                end
                                if (!reset_after_cnm_prefix) begin
                                    shared_reset_coverage_phase = 3;
                                    matrix_cnm_shared_reset_cg.sample();
                                end
                                if (reset_after_cnm_prefix) begin
                                    shared_reset_prefix_coverage_phase = 3;
                                    matrix_cnm_prefix_reset_cg.sample();
                                end
                            end else begin
                                axil_write(REG_ABORT, 32'd1);
                            end
                            abort_issued = 1'b1;
                        end
                    end
                    if (!abort_issued)
                        `uvm_fatal("CLUSTER_PARITY_ABORT_OWNER",
                            "Matrix parity response was not observed in the concurrent scenario")
                    if (abort_cnm_after_parity)
                        wait_cpl_tail(32'd2);
                    monitor_done = 1'b1;
                end
            join
            wait_spad_idle();
            if (abort_cnm_after_parity && !abort_seen)
                `uvm_fatal("CLUSTER_PARITY_ABORT_OWNER",
                    "CNM did not sample software Abort while draining Matrix parity")
            if (accepted_cnm_reads == 0 ||
                (abort_cnm_after_parity &&
                 returned_cnm_reads != accepted_cnm_reads))
                `uvm_fatal("CLUSTER_PARITY_ABORT_OWNER", $sformatf(
                    "CNM parity/Abort read drain mismatch: accepted=%0d returned=%0d",
                    accepted_cnm_reads, returned_cnm_reads))
            if (reset_both_after_parity && !reset_seen)
                `uvm_fatal("CLUSTER_PARITY_RESET_OWNER",
                    "shared reset did not occur after Matrix sampled the parity response")
            if (post_abort_cnm_writes != 0)
                `uvm_fatal("CLUSTER_PARITY_ABORT_OWNER", $sformatf(
                    "CNM accepted %0d output writes after Abort sampling",
                    post_abort_cnm_writes))
        end
        restore_spad_parity(parity_path, saved_parity);

        if ((!reset_both_after_parity &&
             compute_vif.matrix_cnm_overlap_cycles <= overlap_before) ||
            (reset_both_after_parity && !overlap_seen))
            `uvm_fatal("CLUSTER_PARITY_OWNER",
                "Matrix parity fault and CNM valid task never overlapped on real engines")
        if ((!reset_both_after_parity &&
             compute_vif.matrix_cnm_shared_accept_cycles <= shared_accept_before) ||
            (reset_both_after_parity && !shared_accept_seen))
            `uvm_fatal("CLUSTER_PARITY_OWNER",
                "Matrix/CNM did not contend for shared banked admission in parity-owner cross")
        if (!abort_cnm_after_parity && !reset_both_after_parity &&
            ((compute_vif.matrix_banked_fault_cancel_checks -
              fault_cancel_before) != 1))
            `uvm_fatal("CLUSTER_PARITY_OWNER", $sformatf(
                "expected exactly one Matrix held-read cancellation on parity response, observed %0d",
                compute_vif.matrix_banked_fault_cancel_checks - fault_cancel_before))
        if ((abort_cnm_after_parity || reset_both_after_parity) &&
            ((compute_vif.matrix_banked_fault_cancel_checks -
              fault_cancel_before) > 1))
            `uvm_fatal("CLUSTER_PARITY_ABORT_OWNER", $sformatf(
                "unexpected repeated Matrix fault-cancel observation count=%0d",
                compute_vif.matrix_banked_fault_cancel_checks - fault_cancel_before))
        if ((!reset_both_after_parity &&
             (compute_vif.matrix_tag_response_count <= matrix_rsp_before ||
              compute_vif.cnm_tag_response_count <= cnm_rsp_before)) ||
            (reset_both_after_parity &&
             (!matrix_response_seen || !cnm_response_seen)))
            `uvm_fatal("CLUSTER_PARITY_OWNER", $sformatf(
                "missing response owner activity: Matrix %0d->%0d CNM %0d->%0d",
                matrix_rsp_before, compute_vif.matrix_tag_response_count,
                cnm_rsp_before, compute_vif.cnm_tag_response_count))
        if ((!reset_both_after_parity &&
             (compute_vif.matrix_route_mismatch_count != matrix_route_error_before ||
              compute_vif.cnm_route_mismatch_count != cnm_route_error_before)) ||
            (reset_both_after_parity && route_mismatch_seen))
            `uvm_fatal("CLUSTER_PARITY_OWNER", $sformatf(
                "response owner cross-route mismatch: Matrix %0d->%0d CNM %0d->%0d",
                matrix_route_error_before, compute_vif.matrix_route_mismatch_count,
                cnm_route_error_before, compute_vif.cnm_route_mismatch_count))

        if (abort_cnm_after_parity) begin
            expect_spad(cpl_base, 32'h0000_07e3,
                        "Matrix parity/CNM Abort first CMDQ completion");
            expect_spad(cpl_base + 32'h04, 32'h0000_0032,
                        "Matrix parity/CNM Abort first status");
            expect_spad(cpl_base + 32'h10, 32'h0000_07e2,
                        "Matrix parity second CMDQ completion");
            expect_spad(cpl_base + 32'h14, 32'h0000_0052,
                        "Matrix parity second status");
            for (word_idx = 0; word_idx < 16; word_idx++) begin
                if (word_idx < accepted_cnm_writes) begin
                    if (cnm_write_data[word_idx] !== expected_cnm[word_idx])
                        `uvm_fatal("CLUSTER_PARITY_ABORT_OWNER", $sformatf(
                            "CNM accepted Abort-prefix Golden mismatch index=%0d expected=%0d actual=%0d",
                            word_idx, expected_cnm[word_idx],
                            $signed(cnm_write_data[word_idx])))
                    expect_spad(cnm_dst + (word_idx << 2), expected_cnm[word_idx],
                                $sformatf("parity/Abort CNM Golden prefix[%0d]", word_idx));
                end else
                    expect_spad(cnm_dst + (word_idx << 2),
                                32'hfa17_7800 | word_idx,
                                $sformatf("parity/Abort CNM untouched suffix[%0d]", word_idx));
            end
        end else if (reset_both_after_parity) begin
            axil_read(REG_CPLQ_TAIL, value);
            if (value !== 32'd0)
                `uvm_fatal("CLUSTER_PARITY_RESET_OWNER", $sformatf(
                    "shared reset published old-epoch completion tail=%0d", value))
            for (word_idx = 0; word_idx < 8; word_idx++)
                expect_spad(cpl_base + ((word_idx / 4) * 32'h10) +
                            ((word_idx % 4) * 4),
                            32'hfa17_7900 | word_idx,
                            $sformatf("shared reset completion sentinel[%0d]", word_idx));
            for (word_idx = 0; word_idx < 512; word_idx++)
                expect_spad(matrix_dst + (word_idx << 2),
                            32'hfa17_7000 | word_idx,
                            $sformatf("shared reset Matrix sentinel[%0d]", word_idx));
            for (word_idx = 0; word_idx < 16; word_idx++) begin
                if (word_idx < accepted_cnm_writes) begin
                    if (cnm_write_data[word_idx] !== expected_cnm[word_idx])
                        `uvm_fatal("CLUSTER_PARITY_RESET_OWNER", $sformatf(
                            "pre-reset CNM prefix Golden mismatch index=%0d expected=%0d actual=%0d",
                            word_idx, expected_cnm[word_idx],
                            $signed(cnm_write_data[word_idx])))
                    expect_spad(cnm_dst + (word_idx << 2), expected_cnm[word_idx],
                                $sformatf("shared reset CNM accepted prefix[%0d]", word_idx));
                end else
                    expect_spad(cnm_dst + (word_idx << 2),
                                32'hfa17_7800 | word_idx,
                                $sformatf("shared reset CNM untouched suffix[%0d]", word_idx));
            end
            if (reset_after_cnm_prefix) begin
                shared_reset_prefix_coverage_phase = 4;
                matrix_cnm_prefix_reset_cg.sample();
            end

            // Replay both operations in the clean epoch and compare their
            // complete independently generated Golden images and completions.
            write_cluster_desc(desc_base, 8'h21,
                               reset_after_cnm_prefix ? 16'h07ec : 16'h07ea,
                               MATRIX_LINE_STALL_CNM_A_LOCAL,
                               MATRIX_LINE_STALL_CNM_B_LOCAL, cnm_dst,
                               16'd16, 16'd1, 16'd32, 32'd0,
                               32'd0, 32'd0, 32'd0, 8'd3);
            write_v3_desc(desc_base + 32'h40, 8'h30,
                          reset_after_cnm_prefix ? 16'h07ed : 16'h07eb,
                          MATRIX_A_LOCAL, MATRIX_B_LOCAL, matrix_dst,
                          16'd16, 16'd32, 16'd16);
            configure_contract_queues(cpl_base, 32'd2);
            // This scenario stores descriptors in its private queue at 0x7800;
            // configure_contract_queues() normally points at the shared 0x4800
            // queue used by the surrounding contract tests.
            axil_write(REG_CMDQ_BASE, desc_base);
            axil_write(REG_DOORBELL, 32'd1);
            wait_cpl_tail(32'd2);
            wait_spad_idle();
            expect_completion(cpl_base,
                              reset_after_cnm_prefix ? 16'h07ec : 16'h07ea,
                              expected_cnm[15], 32'd16,
                              "shared-reset recovery CNM");
            expect_completion(cpl_base + 32'h10,
                              reset_after_cnm_prefix ? 16'h07ed : 16'h07eb,
                              matrix_golden[15][31], 32'd512,
                              "shared-reset recovery Matrix");
            for (word_idx = 0; word_idx < 16; word_idx++)
                expect_spad(cnm_dst + (word_idx << 2), expected_cnm[word_idx],
                            $sformatf("shared reset recovery CNM Golden[%0d]", word_idx));
            for (row_idx = 0; row_idx < 16; row_idx++)
                for (word_idx = 0; word_idx < 32; word_idx++)
                    expect_spad(matrix_dst + (((row_idx * 32) + word_idx) << 2),
                                matrix_golden[row_idx][word_idx],
                                $sformatf("shared reset recovery Matrix Golden[%0d,%0d]",
                                          row_idx, word_idx));
            if (reset_after_cnm_prefix) begin
                shared_reset_prefix_coverage_phase = 5;
                matrix_cnm_prefix_reset_cg.sample();
                if (matrix_cnm_prefix_reset_cg.get_coverage() < 100.0)
                    `uvm_fatal("CLUSTER_PARITY_RESET_PREFIX_OWNER", $sformatf(
                        "prefix shared-reset functional bins incomplete: coverage=%0.1f%%",
                        matrix_cnm_prefix_reset_cg.get_coverage()))
                `uvm_info("CLUSTER_PARITY_RESET_PREFIX_COVERAGE_PASS", $sformatf(
                    "Matrix/CNM parity reset with accepted-write prefix phases=5/5 coverage=%0.1f%%",
                    matrix_cnm_prefix_reset_cg.get_coverage()), UVM_LOW)
            end else begin
                shared_reset_coverage_phase = 4;
                matrix_cnm_shared_reset_cg.sample();
                if (matrix_cnm_shared_reset_cg.get_coverage() < 100.0)
                    `uvm_fatal("CLUSTER_PARITY_RESET_OWNER", $sformatf(
                        "named shared-reset functional bins are incomplete: coverage=%0.1f%%",
                        matrix_cnm_shared_reset_cg.get_coverage()))
                `uvm_info("CLUSTER_PARITY_RESET_OWNER_COVERAGE_PASS", $sformatf(
                    "shared Matrix/CNM parity reset phase bins=4/4 coverage=%0.1f%%",
                    matrix_cnm_shared_reset_cg.get_coverage()), UVM_LOW)
            end
        end else begin
            expect_spad(cpl_base, 32'h0000_07e0,
                        "concurrent parity Matrix task ID/order");
            expect_spad(cpl_base + 32'h04, 32'h0000_0052,
                        "concurrent parity Matrix error owner");
            expect_completion(cpl_base + 32'h10, 16'h07e1,
                              expected_cnm[15], 32'd16,
                              "concurrent parity CNM success/order");
        end
        if (!reset_both_after_parity)
            for (word_idx = 0; word_idx < 512; word_idx++)
                expect_spad(matrix_dst + (word_idx << 2),
                            32'hfa17_7000 | word_idx,
                            $sformatf("concurrent parity Matrix no-writeback[%0d]", word_idx));
        if (!abort_cnm_after_parity && !reset_both_after_parity)
            for (word_idx = 0; word_idx < 16; word_idx++)
                expect_spad(cnm_dst + (word_idx << 2), expected_cnm[word_idx],
                            $sformatf("concurrent parity CNM Golden[%0d]", word_idx));

        if (abort_cnm_after_parity)
            `uvm_info("CLUSTER_PARITY_ABORT_OWNER_CROSS_PASS", $sformatf(
                "Matrix ERR_PARITY=0x52 observed while CNM active; software Abort retires CNM ERR_ABORT=0x32 then Matrix parity in CMDQ order; overlap_cycles=%0d shared_banked_accepts=%0d matrix_rsp=%0d cnm_rsp=%0d route_mismatch=0; held-read fault cancellations=%0d CNM accepted_prefix=%0d/16 post_abort_writes=%0d; CNM Golden prefix/suffix and read drain checked; seed=%0d",
                compute_vif.matrix_cnm_overlap_cycles - overlap_before,
                compute_vif.matrix_cnm_shared_accept_cycles - shared_accept_before,
                compute_vif.matrix_tag_response_count - matrix_rsp_before,
                compute_vif.cnm_tag_response_count - cnm_rsp_before,
                compute_vif.matrix_banked_fault_cancel_checks - fault_cancel_before,
                accepted_cnm_writes, post_abort_cnm_writes, seed), UVM_LOW)
        else if (reset_both_after_parity) begin
            `uvm_info("CLUSTER_PARITY_RESET_OWNER_CROSS_PASS", $sformatf(
                "Matrix consumed ERR_PARITY=0x52 while CNM had pending registered reads; shared reset discarded both old-epoch tasks; CNM reads accepted=%0d returned=%0d reset-dropped=%0d accepted-write-prefix=%0d/16; recovery checked complete Matrix/CNM Golden images and ordered completions; seed=%0d",
                accepted_cnm_reads, returned_cnm_reads, dropped_cnm_reads,
                accepted_cnm_writes, seed), UVM_LOW)
            if (reset_after_cnm_prefix)
                `uvm_info("CLUSTER_PARITY_RESET_PREFIX_OWNER_CROSS_PASS", $sformatf(
                    "Matrix consumed ERR_PARITY=0x52 at the final A-row address while CNM had pending reads; shared reset preserved accepted Golden prefix=%0d/16 and untouched suffix; reads accepted=%0d returned=%0d reset-dropped=%0d; full ordered Golden recovery passed; seed=%0d",
                    accepted_cnm_writes, accepted_cnm_reads, returned_cnm_reads,
                    dropped_cnm_reads, seed), UVM_LOW)
        end else
            `uvm_info("CLUSTER_PARITY_OWNER_CROSS_PASS", $sformatf(
                "real Matrix ERR_PARITY=0x52 and concurrent CNM Golden pass; overlap_cycles=%0d shared_banked_accepts=%0d matrix_rsp=%0d cnm_rsp=%0d route_mismatch=0; held-read fault cancellations=%0d; no Matrix writeback; ordered completion; seed=%0d",
                compute_vif.matrix_cnm_overlap_cycles - overlap_before,
                compute_vif.matrix_cnm_shared_accept_cycles - shared_accept_before,
                compute_vif.matrix_tag_response_count - matrix_rsp_before,
                compute_vif.cnm_tag_response_count - cnm_rsp_before,
                compute_vif.matrix_banked_fault_cancel_checks - fault_cancel_before,
                seed), UVM_LOW)

        axil_write(REG_CPLQ_HEAD, 32'd2);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
    endtask

    task automatic run_matrix_protection_cnm_owner_cross(
        input int unsigned seed,
        input bit abort_cnm_after_protection,
        input bit deny_cnm_writeback,
        input bit hold_dual_faults_behind_full_cplq);
        bit [31:0] desc_base;
        bit [31:0] cpl_base;
        bit [31:0] matrix_dst;
        bit [31:0] cnm_dst;
        bit [31:0] matrix_desc_base;
        bit [31:0] cnm_desc_base;
        bit [31:0] cplq_scalar_src0;
        bit [31:0] cplq_scalar_src1;
        bit [31:0] cplq_scalar_dst;
        bit [31:0] cplq_sfu_src;
        bit [31:0] cplq_sfu_dst;
        bit [31:0] cplq_kv_src;
        bit [31:0] cplq_kv_dst;
        bit [31:0] packed_word;
        bit [31:0] matrix_rsp_before;
        bit [31:0] cnm_rsp_before;
        bit [31:0] matrix_route_error_before;
        bit [31:0] cnm_route_error_before;
        bit [31:0] overlap_before;
        bit [31:0] shared_accept_before;
        bit [31:0] queue_pointer;
        bit [31:0] queue_head;
        bit [31:0] queue_size;
        bit [31:0] command_head;
        bit protection_seen;
        bit cnm_protection_seen;
        bit abort_issued;
        bit busy_seen;
        bit monitor_done;
        int unsigned cycle;
        int unsigned cnm_busy_cycles;
        int unsigned matrix_busy_cycles;
        int unsigned both_busy_cycles;
        int unsigned parallel_active_cycles;
        int unsigned cnm_launch_before;
        int unsigned matrix_launch_before;
        int signed expected_cnm[0:15];
        int signed cplq_sfu_input[0:3];
        int signed cplq_sfu_golden[0:3];
        int signed a_value;
        int signed b_value;
        int unsigned row_idx;
        int unsigned k_word;
        int unsigned lane;
        int unsigned byte_idx;
        int unsigned word_idx;
        bit [15:0] matrix_task_id;
        bit [15:0] cnm_task_id;
        bit [31:0] actual_output;

        desc_base = hold_dual_faults_behind_full_cplq ?
                    32'h0000_7600 : 32'h0000_7800;
        cpl_base = 32'h0000_7900;
        matrix_dst = 32'h0000_8000;
        cnm_dst = 32'h0005_4800;
        matrix_desc_base = hold_dual_faults_behind_full_cplq ?
                           desc_base + 32'hc0 : desc_base;
        cnm_desc_base = hold_dual_faults_behind_full_cplq ?
                        desc_base + 32'h100 : desc_base + 32'h40;
        cplq_scalar_src0 = 32'h0000_7a00;
        cplq_scalar_src1 = 32'h0000_7a80;
        cplq_scalar_dst = 32'h0000_7b00;
        cplq_sfu_src = 32'h0000_7b20;
        cplq_sfu_dst = 32'h0000_7c20;
        cplq_kv_src = 32'h0000_7d20;
        cplq_kv_dst = 32'h0000_7da0;
        protection_seen = 1'b0;
        cnm_protection_seen = 1'b0;
        abort_issued = 1'b0;
        busy_seen = 1'b0;
        monitor_done = 1'b0;
        cnm_busy_cycles = 0;
        matrix_busy_cycles = 0;
        both_busy_cycles = 0;
        parallel_active_cycles = 0;
        matrix_task_id = abort_cnm_after_protection ? 16'h07d2 : 16'h07d0;
        cnm_task_id = abort_cnm_after_protection ? 16'h07d3 : 16'h07d1;
        if (hold_dual_faults_behind_full_cplq) begin
            matrix_task_id = 16'h07e0;
            cnm_task_id = 16'h07e1;
        end

        // A legal CNM GEMV uses its own contiguous protected window and an
        // independent output image for concurrent owner/Golden checking.
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
                       32'hfa17_8000 | word_idx);
        for (word_idx = 0; word_idx < 16; word_idx++)
            spad_write(cnm_dst + (word_idx << 2),
                       32'hfa17_8800 | word_idx);

        // Keep a sentinel in the fourth ring slot. The preceding real
        // completions fill slots 0-2 before the two Protection errors retire.
        if (hold_dual_faults_behind_full_cplq) begin
            for (word_idx = 0; word_idx < 4; word_idx++)
                spad_write(cpl_base + 32'h30 + (word_idx << 2),
                           32'hc07f_7d00 | word_idx);
            for (word_idx = 0; word_idx < 32; word_idx++) begin
                spad_write(cplq_scalar_src0 + (word_idx << 2),
                           32'h0403_0201);
                spad_write(cplq_scalar_src1 + (word_idx << 2),
                           32'h0807_0605);
            end
            spad_write(cplq_scalar_dst, 32'hc07f_7a08);
            cplq_sfu_input[0] = 16;
            cplq_sfu_input[1] = -16;
            cplq_sfu_input[2] = 32;
            cplq_sfu_input[3] = -32;
            cplq_sfu_golden[0] = 8;
            cplq_sfu_golden[1] = -8;
            cplq_sfu_golden[2] = 17;
            cplq_sfu_golden[3] = -15;
            for (word_idx = 0; word_idx < 64; word_idx++) begin
                spad_write(cplq_sfu_src + (word_idx << 2),
                           cplq_sfu_input[word_idx % 4]);
                spad_write(cplq_sfu_dst + (word_idx << 2),
                           32'hc07f_7c20 | word_idx);
            end
            for (word_idx = 0; word_idx < 32; word_idx++) begin
                spad_write(cplq_kv_src + (word_idx << 2),
                           32'hac00_0100 + word_idx);
                spad_write(cplq_kv_dst + (word_idx << 2),
                           32'hc07f_7a80 | word_idx);
            end

            write_contract_vdot_desc(desc_base, 16'h07c0,
                                     cplq_scalar_src0, cplq_scalar_src1,
                                     cplq_scalar_dst, 16'd32, 8'd0,
                                     32'd0, 32'd0, 32'd0, 32'd0);
            write_v3_desc(desc_base + 32'h40, 8'h35, 16'h07c1,
                          cplq_sfu_src, 32'd0, cplq_sfu_dst,
                          16'd0, 16'd0, 16'd64);
            write_cluster_desc(desc_base + 32'h80, 8'h43, 16'h07c2,
                               cplq_kv_src, 32'd0, cplq_kv_dst,
                               16'd0, 16'd0, 16'd32, 32'd0,
                               32'd16, 32'd64, 32'd0, 8'd5);
        end

        // Matrix reads and computes the legal operands before its first
        // output write is denied. This leaves enough execution time for the
        // following CNM task to run concurrently and exercise response-owner
        // isolation through a real Matrix writeback Protection fault.
        write_v3_desc(matrix_desc_base, 8'h30, matrix_task_id,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, matrix_dst,
                      16'd16, 16'd32, 16'd16);
        write_cluster_desc(cnm_desc_base, 8'h21, cnm_task_id,
                           MATRIX_LINE_STALL_CNM_A_LOCAL,
                           MATRIX_LINE_STALL_CNM_B_LOCAL, cnm_dst,
                           16'd16, 16'd1, 16'd32, 32'd0,
                           32'd0, 32'd0, 32'd0, 8'd3);

        // Descriptors and completions have their own legal window. Matrix A/B
        // operands and CNM data are readable, while Matrix's output destination
        // is deliberately outside every writable region.
        axil_write(REG_REGION0_PERM, 32'd0);
        axil_write(REG_REGION1_PERM, 32'd0);
        axil_write(REG_REGION2_PERM, 32'd0);
        axil_write(REG_REGION3_PERM, 32'd0);
        axil_write(REG_REGION0_BASE, desc_base);
        axil_write(REG_REGION0_LIMIT,
                   hold_dual_faults_behind_full_cplq ? 32'h0000_7f00 :
                   desc_base + 32'h200);
        axil_write(REG_REGION0_PERM, 32'h0000_000f);
        axil_write(REG_REGION1_BASE, MATRIX_A_LOCAL);
        axil_write(REG_REGION1_LIMIT, MATRIX_A_LOCAL + 32'h400);
        axil_write(REG_REGION1_PERM, 32'h0000_000d);
        axil_write(REG_REGION2_BASE, MATRIX_B_LOCAL);
        axil_write(REG_REGION2_LIMIT, MATRIX_B_LOCAL + 32'h800);
        axil_write(REG_REGION2_PERM, 32'h0000_000d);
        axil_write(REG_REGION3_BASE, MATRIX_LINE_STALL_CNM_A_LOCAL);
        axil_write(REG_REGION3_LIMIT, 32'h0005_6000);
        // The dual-fault mode keeps CNM operand reads legal while denying its
        // output write. Matrix's output remains outside every writable region.
        axil_write(REG_REGION3_PERM,
                   deny_cnm_writeback ? 32'h0000_000d : 32'h0000_000f);

        matrix_rsp_before = compute_vif.matrix_tag_response_count;
        cnm_rsp_before = compute_vif.cnm_tag_response_count;
        matrix_route_error_before = compute_vif.matrix_route_mismatch_count;
        cnm_route_error_before = compute_vif.cnm_route_mismatch_count;
        overlap_before = compute_vif.matrix_cnm_overlap_cycles;
        shared_accept_before = compute_vif.matrix_cnm_shared_accept_cycles;
        cnm_launch_before = compute_vif.engine_launch_count[2];
        matrix_launch_before = compute_vif.engine_launch_count[3];

        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, desc_base);
        axil_write(REG_CMDQ_SIZE,
                   hold_dual_faults_behind_full_cplq ? 32'd8 : 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL,
                   hold_dual_faults_behind_full_cplq ? 32'd5 : 32'd2);
        axil_write(REG_CPLQ_BASE, cpl_base);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        axil_write(REG_DOORBELL, 32'd1);

        for (cycle = 0; cycle < 30000 && !monitor_done; cycle++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.engine_busy[2]) cnm_busy_cycles++;
            if (compute_vif.engine_busy[3]) matrix_busy_cycles++;
            if (compute_vif.engine_busy[2] && compute_vif.engine_busy[3])
                both_busy_cycles++;
            if (compute_vif.parallel_queue_mode) parallel_active_cycles++;
            if (compute_vif.processor_busy)
                busy_seen = 1'b1;
            if (compute_vif.selected_line_valid &&
                compute_vif.selected_line_write &&
                !compute_vif.selected_line_access_ok &&
                (compute_vif.selected_line_addr >= matrix_dst) &&
                (compute_vif.selected_line_addr < matrix_dst + 32'h800)) begin
                protection_seen = 1'b1;
                if (abort_cnm_after_protection && !abort_issued) begin
                    if (!compute_vif.engine_busy[2])
                        `uvm_fatal("CLUSTER_PROTECTION_ABORT_OWNER",
                            "CNM completed before the concurrent Matrix Protection event")
                    axil_write(REG_ABORT, 32'd1);
                    abort_issued = 1'b1;
                end
            end
            if (deny_cnm_writeback &&
                compute_vif.selected_spad_valid &&
                compute_vif.selected_spad_write &&
                !compute_vif.selected_spad_access_ok &&
                (compute_vif.selected_spad_addr >= cnm_dst) &&
                (compute_vif.selected_spad_addr < cnm_dst + 32'h40)) begin
                if (!compute_vif.engine_busy[2] || !compute_vif.engine_busy[3])
                    `uvm_fatal("CLUSTER_DUAL_PROTECTION_OWNER",
                        "CNM destination Protection denial did not occur while both CNM and Matrix were active")
                cnm_protection_seen = 1'b1;
            end
            if (hold_dual_faults_behind_full_cplq) begin
                if (busy_seen && protection_seen && cnm_protection_seen &&
                    (compute_vif.engine_busy == 7'b0))
                    monitor_done = 1'b1;
            end else if (busy_seen && !compute_vif.processor_busy)
                monitor_done = 1'b1;
        end
        if (!busy_seen || !monitor_done)
            `uvm_fatal("CLUSTER_PROTECTION_OWNER",
                "Matrix output Protection/CNM overlap did not finish in the monitor window")
        if (abort_cnm_after_protection && !abort_issued)
            `uvm_fatal("CLUSTER_PROTECTION_ABORT_OWNER",
                "software Abort was not issued after the Matrix Protection event")
        if (deny_cnm_writeback && !cnm_protection_seen)
            `uvm_fatal("CLUSTER_DUAL_PROTECTION_OWNER",
                "CNM output Protection request was not observed at its destination")
        if (hold_dual_faults_behind_full_cplq) begin
            // Both engines can be idle before the earlier legal descriptors
            // finish ordered retirement. Wait for the visible tail, then
            // sample the full-queue hold state without racing those writes.
            wait_cpl_tail(32'd3);
            axil_read(REG_CPLQ_TAIL, queue_pointer);
            axil_read(REG_CPLQ_HEAD, queue_head);
            axil_read(REG_CPLQ_SIZE, queue_size);
            axil_read(REG_CMDQ_HEAD, command_head);
            if (queue_pointer !== 32'd3 ||
                queue_size !== 32'd4 ||
                compute_vif.cplq_full !== 1'b1 ||
                compute_vif.processor_busy !== 1'b1 ||
                compute_vif.engine_busy !== 7'b0)
                `uvm_fatal("CLUSTER_DUAL_PROTECTION_CPLQ",
                    $sformatf("dual errors did not hold behind a full CPLQ: size=%0d head=%0d tail=%0d CMDQ_HEAD=%0d full=%0b busy=%0b engines=%07b",
                              queue_size, queue_head, queue_pointer, command_head,
                              compute_vif.cplq_full,
                              compute_vif.processor_busy, compute_vif.engine_busy))
            if (command_head !==
                (hold_dual_faults_behind_full_cplq ? 32'd5 : 32'd2))
                `uvm_fatal("CLUSTER_DUAL_PROTECTION_CPLQ", $sformatf(
                    "five legal CMDQ descriptors must dispatch before CPLQ stall: CMDQ_HEAD=%0d",
                    command_head))
            expect_completion(cpl_base, 16'h07c0, 32'd2240, 32'd1,
                              "dual Protection preceding Scalar completion");
            expect_completion(cpl_base + 32'h10, 16'h07c1,
                              cplq_sfu_golden[3], 32'd64,
                              "dual Protection preceding SFU completion");
            expect_completion(cpl_base + 32'h20, 16'h07c2,
                              32'hac00_011f, 32'd32,
                              "dual Protection preceding KV completion");

            // Free one slot. Matrix is first in CMDQ order and must wrap the
            // tail to slot zero. CNM remains pending while the ring is full.
            axil_write(REG_CPLQ_HEAD, 32'd1);
            wait_cpl_tail(32'd0);
            if (compute_vif.cplq_full !== 1'b1 ||
                compute_vif.processor_busy !== 1'b1 ||
                compute_vif.engine_busy !== 7'b0)
                `uvm_fatal("CLUSTER_DUAL_PROTECTION_CPLQ", $sformatf(
                    "CNM error did not remain blocked after Matrix retirement: full=%0b busy=%0b engines=%07b",
                    compute_vif.cplq_full, compute_vif.processor_busy,
                    compute_vif.engine_busy))
            expect_spad(cpl_base + 32'h30, {16'd0, matrix_task_id},
                        "dual Protection Matrix wrapped completion ID");
            expect_spad(cpl_base + 32'h34, 32'h0000_0062,
                        "dual Protection Matrix wrapped error");
            expect_completion(cpl_base, 16'h07c0, 32'd2240, 32'd1,
                              "dual Protection consumed Scalar completion remains intact");

            // Consume another seeded slot to permit CNM's ordered error to
            // retire. The ring remains full after this second completion.
            axil_write(REG_CPLQ_HEAD, 32'd2);
            wait_cpl_tail(32'd1);
            wait_spad_idle();
            if (compute_vif.cplq_full !== 1'b1)
                `uvm_fatal("CLUSTER_DUAL_PROTECTION_CPLQ",
                    "the three-entry completion ring should be full after both ordered error retirements")
            expect_spad(cpl_base, {16'd0, cnm_task_id},
                        "dual Protection CNM wrapped completion ID");
            expect_spad(cpl_base + 32'h04, 32'h0000_0062,
                        "dual Protection CNM wrapped error");
            expect_completion(cpl_base + 32'h10, 16'h07c1,
                              cplq_sfu_golden[3], 32'd64,
                              "dual Protection retained SFU completion");
            expect_completion(cpl_base + 32'h20, 16'h07c2,
                              32'hac00_011f, 32'd32,
                              "dual Protection retained KV completion");
            expect_spad(cplq_scalar_dst, 32'd2240,
                        "dual Protection prefix Scalar Golden");
            for (word_idx = 0; word_idx < 64; word_idx++)
                expect_spad(cplq_sfu_dst + (word_idx << 2),
                            cplq_sfu_golden[word_idx % 4],
                            $sformatf("dual Protection prefix SFU Golden[%0d]", word_idx));
            for (word_idx = 0; word_idx < 32; word_idx++)
                expect_spad(cplq_kv_dst + (word_idx << 2),
                            32'hac00_0100 + word_idx,
                            $sformatf("dual Protection prefix KV Golden[%0d]", word_idx));
        end else begin
            wait_cpl_tail(32'd2);
            wait_spad_idle();
        end

        axil_write(REG_REGION0_PERM, 32'd0);
        axil_write(REG_REGION1_PERM, 32'd0);
        axil_write(REG_REGION2_PERM, 32'd0);
        axil_write(REG_REGION3_PERM, 32'd0);

        if (!protection_seen)
            `uvm_fatal("CLUSTER_PROTECTION_OWNER",
                "Matrix did not issue the expected denied output write after legal operand reads and compute")
        `uvm_info("CLUSTER_PROTECTION_OWNER_TRACE", $sformatf(
            "active_cycles CNM=%0d Matrix=%0d both=%0d parallel_mode=%0d; launches CNM=%0d Matrix=%0d; response_delta CNM=%0d Matrix=%0d",
            cnm_busy_cycles, matrix_busy_cycles, both_busy_cycles,
            parallel_active_cycles,
            compute_vif.engine_launch_count[2] - cnm_launch_before,
            compute_vif.engine_launch_count[3] - matrix_launch_before,
            compute_vif.cnm_tag_response_count - cnm_rsp_before,
            compute_vif.matrix_tag_response_count - matrix_rsp_before), UVM_LOW)
        if (compute_vif.matrix_cnm_overlap_cycles <= overlap_before ||
            compute_vif.matrix_cnm_shared_accept_cycles <= shared_accept_before)
            `uvm_fatal("CLUSTER_PROTECTION_OWNER", $sformatf(
                "Matrix Protection and CNM did not overlap/contend: overlap=%0d shared=%0d both_busy=%0d parallel_mode=%0d",
                compute_vif.matrix_cnm_overlap_cycles - overlap_before,
                compute_vif.matrix_cnm_shared_accept_cycles - shared_accept_before,
                both_busy_cycles, parallel_active_cycles))
        if (compute_vif.matrix_tag_response_count <= matrix_rsp_before ||
            compute_vif.cnm_tag_response_count <= cnm_rsp_before)
            `uvm_fatal("CLUSTER_PROTECTION_OWNER", $sformatf(
                "missing owner response activity: Matrix %0d->%0d CNM %0d->%0d",
                matrix_rsp_before, compute_vif.matrix_tag_response_count,
                cnm_rsp_before, compute_vif.cnm_tag_response_count))
        if (compute_vif.matrix_route_mismatch_count != matrix_route_error_before ||
            compute_vif.cnm_route_mismatch_count != cnm_route_error_before)
            `uvm_fatal("CLUSTER_PROTECTION_OWNER",
                "response from the Protection-faulted Matrix task was routed to the wrong engine")

        // Full-CPLQ mode has already checked the exact wrapped completion
        // slots above. The ordinary case keeps the original base slots.
        if (!hold_dual_faults_behind_full_cplq) begin
            expect_spad(cpl_base, {16'd0, matrix_task_id},
                        "concurrent Protection Matrix task ID/order");
            expect_spad(cpl_base + 32'h04, 32'h0000_0062,
                        "concurrent Protection Matrix error owner");
            if (abort_cnm_after_protection) begin
                expect_spad(cpl_base + 32'h10, {16'd0, cnm_task_id},
                            "concurrent Protection CNM Abort task ID/order");
                expect_spad(cpl_base + 32'h14, 32'h0000_0032,
                            "concurrent Protection CNM ERR_ABORT owner");
            end else if (deny_cnm_writeback) begin
                expect_spad(cpl_base + 32'h10, {16'd0, cnm_task_id},
                            "dual Protection CNM task ID/order");
                expect_spad(cpl_base + 32'h14, 32'h0000_0062,
                            "dual Protection CNM error owner");
            end else begin
                expect_completion(cpl_base + 32'h10, cnm_task_id,
                                  expected_cnm[15], 32'd16,
                                  "concurrent Protection CNM success/order");
            end
        end
        for (word_idx = 0; word_idx < 512; word_idx++)
            expect_spad(matrix_dst + (word_idx << 2),
                        32'hfa17_8000 | word_idx,
                        $sformatf("concurrent Protection Matrix no-writeback[%0d]", word_idx));
        for (word_idx = 0; word_idx < 16; word_idx++) begin
            if (abort_cnm_after_protection) begin
                axil_read(CIMFORGE_SPAD_BASE + cnm_dst + (word_idx << 2),
                          actual_output);
                if ((actual_output !== expected_cnm[word_idx]) &&
                    (actual_output !== (32'hfa17_8800 | word_idx)))
                    `uvm_fatal("CLUSTER_PROTECTION_ABORT_OWNER", $sformatf(
                        "CNM output after Protection/Abort is neither Golden nor untouched: index=%0d expected=0x%08h sentinel=0x%08h actual=0x%08h",
                        word_idx, expected_cnm[word_idx],
                        (32'hfa17_8800 | word_idx), actual_output))
            end else if (deny_cnm_writeback)
                expect_spad(cnm_dst + (word_idx << 2),
                            32'hfa17_8800 | word_idx,
                            $sformatf("dual Protection CNM no-writeback[%0d]", word_idx));
            else
                expect_spad(cnm_dst + (word_idx << 2), expected_cnm[word_idx],
                            $sformatf("concurrent Protection CNM Golden[%0d]", word_idx));
        end

        if (deny_cnm_writeback)
            `uvm_info("CLUSTER_DUAL_PROTECTION_OWNER_CROSS_PASS", $sformatf(
                "parallel Matrix/CNM tasks both retire Protection ERR 0x62 in CMDQ order; both_busy_at_CNM_fault=1 Matrix denied writeback=%0b CNM denied output=%0b overlap_cycles=%0d shared_banked_accepts=%0d MatrixRsp=%0d CNMRsp=%0d route_mismatch=0; both output sentinels preserved; seed=%0d",
                protection_seen, cnm_protection_seen,
                compute_vif.matrix_cnm_overlap_cycles - overlap_before,
                compute_vif.matrix_cnm_shared_accept_cycles - shared_accept_before,
                compute_vif.matrix_tag_response_count - matrix_rsp_before,
                compute_vif.cnm_tag_response_count - cnm_rsp_before, seed), UVM_LOW)
        else if (abort_cnm_after_protection)
            `uvm_info("CLUSTER_PROTECTION_ABORT_OWNER_CROSS_PASS", $sformatf(
                "Matrix Protection ERR 0x62 is preserved before CNM software Abort ERR 0x32; overlap_cycles=%0d shared_banked_accepts=%0d matrix_rsp=%0d cnm_rsp=%0d route_mismatch=0; no Matrix writeback; CNM outputs are Golden or untouched; seed=%0d",
                compute_vif.matrix_cnm_overlap_cycles - overlap_before,
                compute_vif.matrix_cnm_shared_accept_cycles - shared_accept_before,
                compute_vif.matrix_tag_response_count - matrix_rsp_before,
                compute_vif.cnm_tag_response_count - cnm_rsp_before, seed), UVM_LOW)
        else
            `uvm_info("CLUSTER_PROTECTION_OWNER_CROSS_PASS", $sformatf(
                "real Matrix output Protection after legal operand reads/compute and concurrent CNM Golden pass; overlap_cycles=%0d shared_banked_accepts=%0d matrix_rsp=%0d cnm_rsp=%0d route_mismatch=0; no Matrix writeback; ordered completion; seed=%0d",
                compute_vif.matrix_cnm_overlap_cycles - overlap_before,
                compute_vif.matrix_cnm_shared_accept_cycles - shared_accept_before,
                compute_vif.matrix_tag_response_count - matrix_rsp_before,
                compute_vif.cnm_tag_response_count - cnm_rsp_before, seed), UVM_LOW)

        if (hold_dual_faults_behind_full_cplq)
            `uvm_info("CLUSTER_DUAL_PROTECTION_CPLQ_BACKPRESSURE_PASS", $sformatf(
                "blocked_tail=3 released_heads=1,2 wrapped_tails=0,1 engines_idle=1 full_after_each=1 Matrix=0x62 CNM=0x62 completion_order=Matrix,CNM route_mismatch=0; both output sentinels preserved; seed=%0d",
                seed), UVM_LOW)

        axil_write(REG_CPLQ_HEAD,
                   hold_dual_faults_behind_full_cplq ? 32'd1 : 32'd2);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
    endtask

    task automatic run_cnm_protection_matrix_owner_cross(
        input int unsigned seed,
        input int signed expected_matrix[0:15][0:31],
        input bit reset_after_fault,
        input bit abort_matrix_after_fault,
        input bit matrix_prefix_reset_mode);
        bit [31:0] desc_base;
        bit [31:0] cpl_base;
        bit [31:0] matrix_dst;
        bit [31:0] cnm_dst;
        bit [31:0] packed_word;
        bit [31:0] matrix_rsp_before;
        bit [31:0] cnm_rsp_before;
        bit [31:0] matrix_route_error_before;
        bit [31:0] cnm_route_error_before;
        bit [31:0] overlap_before;
        bit [31:0] matrix_line_write_addr[0:127];
        bit [127:0] matrix_line_write_data[0:127];
        bit [15:0] matrix_line_write_wstrb[0:127];
        bit matrix_output_written[0:511];
        bit denied_seen;
        bit matrix_busy_at_fault;
        bit both_busy_at_fault;
        bit matrix_read_accepted;
        bit reset_triggered;
        bit abort_issued;
        bit abort_write_done;
        bit cnm_fault_drained;
        bit abort_active_seen;
        bit busy_seen;
        bit monitor_done;
        bit reset_ok;
        int unsigned cycle;
        int unsigned matrix_busy_cycles;
        int unsigned both_busy_cycles;
        int unsigned matrix_accept_count;
        int unsigned matrix_write_accept_count;
        int unsigned post_abort_matrix_writes;
        int unsigned line_word_idx;
        int unsigned word_idx;
        int unsigned cpl_idx;
        int unsigned k_word;
        int unsigned row_idx;
        int unsigned lane;
        int unsigned byte_idx;
        int signed a_value;
        int signed b_value;
        int signed expected_cnm[0:15];
        bit [31:0] actual_addr;
        bit [31:0] cpl_tail;
        bit [31:0] matrix_rsp_after_reset;
        bit [31:0] cnm_rsp_after_reset;
        bit [15:0] matrix_task_id;
        bit [15:0] cnm_task_id;
        int unsigned cnm_launches_before;
        bit cnm_fault_done_seen;
        uvm_hdl_data_t reset_value;

        desc_base = 32'h0000_7800;
        cpl_base = 32'h0000_7900;
        matrix_dst = MATRIX_Y_LOCAL;
        cnm_dst = MATRIX_LINE_STALL_CNM_Y_LOCAL;
        matrix_task_id = reset_after_fault ? 16'h07d6 : 16'h07d4;
        cnm_task_id = reset_after_fault ? 16'h07d7 : 16'h07d5;
        if (matrix_prefix_reset_mode) begin
            if (!reset_after_fault || abort_matrix_after_fault)
                `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_PREFIX",
                    "Matrix output-prefix reset is only valid for the reset mode")
            matrix_task_id = 16'h07da;
            cnm_task_id = 16'h07db;
        end
        if (abort_matrix_after_fault) begin
            matrix_task_id = 16'h07d8;
            cnm_task_id = 16'h07d9;
        end
        denied_seen = 1'b0;
        matrix_busy_at_fault = 1'b0;
        both_busy_at_fault = 1'b0;
        matrix_read_accepted = 1'b0;
        reset_triggered = 1'b0;
        abort_issued = 1'b0;
        abort_write_done = 1'b0;
        cnm_fault_drained = 1'b0;
        abort_active_seen = 1'b0;
        busy_seen = 1'b0;
        monitor_done = 1'b0;
        matrix_busy_cycles = 0;
        both_busy_cycles = 0;
        matrix_accept_count = 0;
        matrix_write_accept_count = 0;
        post_abort_matrix_writes = 0;
        cnm_fault_done_seen = 1'b0;

        // Initialize a legal CNM GEMV image. The CNM source-A window is the
        // only denied range; Matrix A/B and its writeback remain permitted.
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
                       32'hfa17_9000 | word_idx);
        for (word_idx = 0; word_idx < 16; word_idx++)
            spad_write(cnm_dst + (word_idx << 2),
                       32'hfa17_9800 | word_idx);
        for (cpl_idx = 0; cpl_idx < 8; cpl_idx++)
            spad_write(cpl_base + (cpl_idx << 2),
                       32'hfa17_a000 | cpl_idx);

        write_v3_desc(desc_base, 8'h30, matrix_task_id,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, matrix_dst,
                      16'd16, 16'd32, 16'd16);
        write_cluster_desc(desc_base + 32'h40, 8'h21, cnm_task_id,
                           MATRIX_LINE_STALL_CNM_A_LOCAL,
                           MATRIX_LINE_STALL_CNM_B_LOCAL, cnm_dst,
                           16'd16, 16'd1, 16'd32, 32'd0,
                           32'd0, 32'd0, 32'd0, 8'd3);

        axil_write(REG_REGION0_PERM, 32'd0);
        axil_write(REG_REGION1_PERM, 32'd0);
        axil_write(REG_REGION2_PERM, 32'd0);
        axil_write(REG_REGION3_PERM, 32'd0);
        axil_write(REG_REGION0_BASE, desc_base);
        axil_write(REG_REGION0_LIMIT, cpl_base + 32'h100);
        axil_write(REG_REGION0_PERM, 32'h0000_000f);
        axil_write(REG_REGION1_BASE, MATRIX_A_LOCAL);
        axil_write(REG_REGION1_LIMIT, matrix_dst + 32'h800);
        axil_write(REG_REGION1_PERM, 32'h0000_000f);
        axil_write(REG_REGION3_BASE, MATRIX_LINE_STALL_CNM_A_LOCAL);
        axil_write(REG_REGION3_LIMIT, cnm_dst + 32'h40);
        axil_write(REG_REGION3_PERM, 32'd0);

        matrix_rsp_before = compute_vif.matrix_tag_response_count;
        cnm_rsp_before = compute_vif.cnm_tag_response_count;
        matrix_route_error_before = compute_vif.matrix_route_mismatch_count;
        cnm_route_error_before = compute_vif.cnm_route_mismatch_count;
        overlap_before = compute_vif.matrix_cnm_overlap_cycles;
        cnm_launches_before = compute_vif.engine_launch_count[2];

        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, desc_base);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd2);
        axil_write(REG_CPLQ_BASE, cpl_base);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        axil_write(REG_DOORBELL, 32'd1);

        for (cycle = 0; cycle < 30000 && !monitor_done; cycle++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.engine_busy[3]) matrix_busy_cycles++;
            if (compute_vif.engine_busy[2] && compute_vif.engine_busy[3])
                both_busy_cycles++;
            if (compute_vif.processor_busy)
                busy_seen = 1'b1;
            if (compute_vif.selected_line_valid &&
                compute_vif.selected_line_ready &&
                compute_vif.selected_line_write &&
                compute_vif.selected_line_access_ok &&
                (compute_vif.selected_line_addr >= matrix_dst) &&
                (compute_vif.selected_line_addr < matrix_dst + 32'h800)) begin
                if (matrix_write_accept_count >= 128)
                    `uvm_fatal("CLUSTER_CNM_PROTECTION_ABORT_OWNER",
                        "Matrix accepted more Line writes than its 16x32 descriptor permits")
                matrix_line_write_addr[matrix_write_accept_count] =
                    compute_vif.selected_line_addr;
                matrix_line_write_data[matrix_write_accept_count] =
                    compute_vif.selected_line_wdata;
                matrix_line_write_wstrb[matrix_write_accept_count] =
                    compute_vif.selected_line_wstrb;
                matrix_write_accept_count++;
                if (abort_active_seen)
                    post_abort_matrix_writes++;
            end
            if (compute_vif.dut_abort_active)
                abort_active_seen = 1'b1;
            for (lane = 0; lane < 4; lane++) begin
                actual_addr = compute_vif.selected_cnm_addr[lane];
                if (compute_vif.selected_cnm_valid[lane] &&
                    !compute_vif.selected_cnm_access_ok[lane] &&
                    (actual_addr >= MATRIX_LINE_STALL_CNM_A_LOCAL) &&
                    (actual_addr < MATRIX_LINE_STALL_CNM_A_LOCAL + 32'h200)) begin
                    denied_seen = 1'b1;
                    matrix_busy_at_fault |= compute_vif.engine_busy[3];
                    if (!compute_vif.engine_busy[3])
                        `uvm_fatal("CLUSTER_CNM_PROTECTION_OWNER",
                            "CNM Protection error arrived after the concurrent Matrix task had completed")
                    if (compute_vif.engine_busy[2]) begin
                        both_busy_at_fault = 1'b1;
                        if (matrix_prefix_reset_mode &&
                            (cnm_protection_reset_prefix_coverage_phase == 0)) begin
                            cnm_protection_reset_prefix_coverage_phase = 1;
                            cnm_protection_matrix_prefix_reset_cg.sample();
                        end
                    end
                end
            end
            if (matrix_prefix_reset_mode && denied_seen && compute_vif.engine_error[2])
                cnm_fault_done_seen = 1'b1;
            if (matrix_prefix_reset_mode && denied_seen &&
                (matrix_write_accept_count != 0) && cnm_fault_done_seen &&
                compute_vif.engine_busy[3] &&
                (cnm_protection_reset_prefix_coverage_phase == 1)) begin
                cnm_protection_reset_prefix_coverage_phase = 2;
                cnm_protection_matrix_prefix_reset_cg.sample();
            end
            if (compute_vif.engine_busy[3] &&
                compute_vif.matrix_request_valid && compute_vif.banked_ready) begin
                matrix_read_accepted = 1'b1;
                matrix_accept_count++;
            end
            if (abort_matrix_after_fault && denied_seen && !abort_issued &&
                !compute_vif.engine_busy[2] && compute_vif.engine_busy[3] &&
                (matrix_write_accept_count != 0)) begin
                if (!matrix_read_accepted || (matrix_accept_count == 0))
                    `uvm_fatal("CLUSTER_CNM_PROTECTION_ABORT_OWNER",
                        "CNM Protection retired before Matrix had accepted a real operand read")
                cnm_fault_drained = 1'b1;
                // Wait until the CNM Protection result has left its engine
                // and Matrix has committed a real output write, then exercise
                // global Abort against the remaining in-flight task.
                abort_issued = 1'b1;
                fork
                    begin : send_matrix_global_abort
                        axil_write(REG_ABORT, 32'd1);
                        abort_write_done = 1'b1;
                    end
                join_none
            end
            if (reset_after_fault && denied_seen && matrix_read_accepted &&
                compute_vif.engine_busy[3] &&
                ((!matrix_prefix_reset_mode && compute_vif.engine_busy[2]) ||
                 (matrix_prefix_reset_mode && cnm_fault_done_seen &&
                  !compute_vif.engine_busy[2] && (matrix_write_accept_count != 0)))) begin
                if (matrix_prefix_reset_mode) begin
                    if ((matrix_write_accept_count == 0) || !cnm_fault_done_seen ||
                        compute_vif.engine_busy[2])
                        `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_PREFIX",
                            "reset must follow a retired CNM Protection error and an accepted Matrix Golden Line while Matrix remains active")
                    if (!both_busy_at_fault)
                        `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_PREFIX",
                            "Protection and Matrix were not active together when the denial was consumed")
                    if ((compute_vif.engine_launch_count[2] - cnm_launches_before) != 1)
                        `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_PREFIX", $sformatf(
                            "expected one CNM fault task launch, observed %0d",
                            compute_vif.engine_launch_count[2] - cnm_launches_before))
                    if (cnm_protection_reset_prefix_coverage_phase != 2)
                        `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_PREFIX",
                            "missing consumed-Protection then accepted-Matrix-prefix coverage phase")
                end else begin
                    both_busy_at_fault = 1'b1;
                end
                // In prefix mode, Matrix is still busy and owns the earlier
                // CMDQ entry, so the consumed CNM Protection completion is
                // pending. Reset suppresses it together with Matrix's old
                // epoch. The post-reset tail and CPLQ sentinel checks prove
                // that neither completion retired.
                // Assert reset without another bus transaction so Matrix
                // cannot advance while the accepted prefix is being sampled.
                #1ns;
                reset_value = 1'b0;
                reset_ok = uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", reset_value);
                if (!reset_ok)
                    `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_OWNER",
                        "failed to assert reset during concurrent CNM Protection and Matrix reads")
                repeat (4) @(posedge compute_vif.aclk);
                if (compute_vif.engine_busy !== 7'b0)
                    `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_OWNER", $sformatf(
                        "engines remained active during reset: busy=%07b",
                        compute_vif.engine_busy))
                if (matrix_prefix_reset_mode) begin
                    cnm_protection_reset_prefix_coverage_phase = 3;
                    cnm_protection_matrix_prefix_reset_cg.sample();
                end
                #1ns;
                reset_value = 1'b1;
                reset_ok = uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", reset_value);
                if (!reset_ok)
                    `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_OWNER",
                        "failed to release reset after concurrent Protection fault")
                repeat (8) @(posedge compute_vif.aclk);
                if (matrix_prefix_reset_mode) begin
                    cnm_protection_reset_prefix_coverage_phase = 4;
                    cnm_protection_matrix_prefix_reset_cg.sample();
                end
                wait_spad_idle();
                axil_read(REG_CPLQ_TAIL, cpl_tail);
                if (cpl_tail !== 32'd0)
                    `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_OWNER", $sformatf(
                        "reset left a stale completion tail: %0d", cpl_tail))
                if (matrix_prefix_reset_mode) begin : check_matrix_reset_prefix_image
                    bit [31:0] actual_word;
                    int unsigned line_base_word;
                    int unsigned check_row;
                    int unsigned check_col;
                    for (word_idx = 0; word_idx < 512; word_idx++)
                        matrix_output_written[word_idx] = 1'b0;
                    if (matrix_write_accept_count == 0 ||
                        matrix_write_accept_count >= 128)
                        `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_PREFIX", $sformatf(
                            "reset did not preserve a proper Matrix Line prefix: lines=%0d",
                            matrix_write_accept_count))
                    for (cpl_idx = 0; cpl_idx < matrix_write_accept_count; cpl_idx++) begin
                        if ((matrix_line_write_addr[cpl_idx] !==
                             matrix_dst + ((cpl_idx / 8) * 32'h80) +
                                          ((cpl_idx % 8) * 32'h10)) ||
                            (matrix_line_write_wstrb[cpl_idx] !== 16'hffff))
                            `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_PREFIX", $sformatf(
                                "Matrix prefix Line address/WSTRB mismatch index=%0d addr=0x%08h WSTRB=%04h",
                                cpl_idx, matrix_line_write_addr[cpl_idx],
                                matrix_line_write_wstrb[cpl_idx]))
                        line_base_word = (matrix_line_write_addr[cpl_idx] - matrix_dst) >> 2;
                        check_row = line_base_word / 32;
                        check_col = line_base_word % 32;
                        for (lane = 0; lane < 4; lane++) begin
                            line_word_idx = line_base_word + lane;
                            if ((check_col + lane) >= 32 ||
                                (line_word_idx >= 512) ||
                                matrix_output_written[line_word_idx])
                                `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_PREFIX", $sformatf(
                                    "invalid/duplicate Matrix prefix output word=%0d", line_word_idx))
                            if (matrix_line_write_data[cpl_idx][lane*32 +: 32] !==
                                expected_matrix[check_row][check_col + lane])
                                `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_PREFIX", $sformatf(
                                    "accepted Matrix prefix is not Golden line=%0d lane=%0d actual=0x%08h expected=0x%08h",
                                    cpl_idx, lane,
                                    matrix_line_write_data[cpl_idx][lane*32 +: 32],
                                    expected_matrix[check_row][check_col + lane]))
                            matrix_output_written[line_word_idx] = 1'b1;
                        end
                    end
                    for (word_idx = 0; word_idx < 512; word_idx++) begin
                        axil_read(CIMFORGE_SPAD_BASE + matrix_dst + (word_idx << 2),
                                  actual_word);
                        if (matrix_output_written[word_idx]) begin
                            if (actual_word !== expected_matrix[word_idx / 32][word_idx % 32])
                                `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_PREFIX", $sformatf(
                                    "accepted Matrix prefix was not committed word=%0d actual=0x%08h expected=0x%08h",
                                    word_idx, actual_word,
                                    expected_matrix[word_idx / 32][word_idx % 32]))
                        end else if (actual_word !== (32'hfa17_9000 | word_idx))
                            `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_PREFIX", $sformatf(
                                "unaccepted Matrix suffix changed word=%0d actual=0x%08h sentinel=0x%08h",
                                word_idx, actual_word, 32'hfa17_9000 | word_idx))
                    end
                    cnm_protection_reset_prefix_coverage_phase = 5;
                    cnm_protection_matrix_prefix_reset_cg.sample();
                end else begin
                    for (word_idx = 0; word_idx < 512; word_idx++)
                        expect_spad(matrix_dst + (word_idx << 2),
                                    32'hfa17_9000 | word_idx,
                                    $sformatf("reset Matrix no-writeback sentinel[%0d]", word_idx));
                end
                for (word_idx = 0; word_idx < 16; word_idx++)
                    expect_spad(cnm_dst + (word_idx << 2),
                                32'hfa17_9800 | word_idx,
                                $sformatf("reset CNM no-writeback sentinel[%0d]", word_idx));
                for (cpl_idx = 0; cpl_idx < 8; cpl_idx++)
                    expect_spad(cpl_base + (cpl_idx << 2),
                                32'hfa17_a000 | cpl_idx,
                                $sformatf("reset no-completion image[%0d]", cpl_idx));
                matrix_rsp_after_reset = compute_vif.matrix_tag_response_count;
                cnm_rsp_after_reset = compute_vif.cnm_tag_response_count;
                repeat (4) @(posedge compute_vif.aclk);
                if (compute_vif.matrix_tag_response_count != matrix_rsp_after_reset ||
                    compute_vif.cnm_tag_response_count != cnm_rsp_after_reset ||
                    compute_vif.matrix_route_mismatch_count != matrix_route_error_before ||
                    compute_vif.cnm_route_mismatch_count != cnm_route_error_before)
                    `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_OWNER", $sformatf(
                        "stale response/owner activity after reset: MatrixRsp=%0d CNMRsp=%0d routeMismatch=%0d/%0d",
                        compute_vif.matrix_tag_response_count - matrix_rsp_after_reset,
                        compute_vif.cnm_tag_response_count - cnm_rsp_after_reset,
                        compute_vif.matrix_route_mismatch_count - matrix_route_error_before,
                        compute_vif.cnm_route_mismatch_count - cnm_route_error_before))
                reset_triggered = 1'b1;
                monitor_done = 1'b1;
            end
            if (busy_seen && !compute_vif.processor_busy)
                monitor_done = 1'b1;
        end
        if (!busy_seen || !monitor_done)
            `uvm_fatal("CLUSTER_CNM_PROTECTION_OWNER",
                "CNM source Protection/Matrix Golden pair did not complete in the monitor window")
        if (!denied_seen || !matrix_busy_at_fault || (matrix_busy_cycles == 0) ||
            (both_busy_cycles == 0))
            `uvm_fatal("CLUSTER_CNM_PROTECTION_OWNER", $sformatf(
                "missing concurrent denied CNM source read: denied=%0b Matrix-active-at-fault=%0b Matrix-cycles=%0d both-busy=%0d",
                denied_seen, matrix_busy_at_fault, matrix_busy_cycles,
                both_busy_cycles))

        if (reset_after_fault) begin
            if (!reset_triggered || !both_busy_at_fault || (matrix_accept_count == 0))
                `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_OWNER", $sformatf(
                    "missing Protection/reset overlap: reset=%0b both_busy=%0b Matrix_accepts=%0d",
                    reset_triggered, both_busy_at_fault, matrix_accept_count))
            if (matrix_prefix_reset_mode) begin
                // Recovery is a fresh legal CMDQ epoch. Restore unrestricted
                // SPAD permissions, republish both descriptors, and check
                // ordered completions plus complete independent Golden images.
                axil_write(REG_REGION0_PERM, 32'd0);
                axil_write(REG_REGION1_PERM, 32'd0);
                axil_write(REG_REGION2_PERM, 32'd0);
                axil_write(REG_REGION3_PERM, 32'd0);
                write_v3_desc(desc_base, 8'h30, 16'h07de,
                              MATRIX_A_LOCAL, MATRIX_B_LOCAL, matrix_dst,
                              16'd16, 16'd32, 16'd16);
                write_cluster_desc(desc_base + 32'h40, 8'h21, 16'h07df,
                                   MATRIX_LINE_STALL_CNM_A_LOCAL,
                                   MATRIX_LINE_STALL_CNM_B_LOCAL, cnm_dst,
                                   16'd16, 16'd1, 16'd32, 32'd0,
                                   32'd0, 32'd0, 32'd0, 8'd3);
                axil_write(REG_CMDQ_CTRL, 32'd0);
                axil_write(REG_CMDQ_BASE, desc_base);
                axil_write(REG_CMDQ_SIZE, 32'd4);
                axil_write(REG_CMDQ_HEAD, 32'd0);
                axil_write(REG_CMDQ_TAIL, 32'd2);
                axil_write(REG_CPLQ_BASE, cpl_base);
                axil_write(REG_CPLQ_SIZE, 32'd4);
                axil_write(REG_CPLQ_HEAD, 32'd0);
                axil_write(REG_CPLQ_TAIL, 32'd0);
                axil_write(REG_DOORBELL, 32'd1);
                wait_cpl_tail(32'd2);
                wait_spad_idle();
                expect_completion(cpl_base, 16'h07de, expected_matrix[15][31],
                                  32'd512, "protection-reset Matrix recovery");
                expect_completion(cpl_base + 32'h10, 16'h07df, expected_cnm[15],
                                  32'd16, "protection-reset CNM recovery");
                for (word_idx = 0; word_idx < 512; word_idx++)
                    expect_spad(matrix_dst + (word_idx << 2),
                                expected_matrix[word_idx / 32][word_idx % 32],
                                $sformatf("protection-reset Matrix recovery Golden[%0d]", word_idx));
                for (word_idx = 0; word_idx < 16; word_idx++)
                    expect_spad(cnm_dst + (word_idx << 2), expected_cnm[word_idx],
                                $sformatf("protection-reset CNM recovery Golden[%0d]", word_idx));
                cnm_protection_reset_prefix_coverage_phase = 6;
                cnm_protection_matrix_prefix_reset_cg.sample();
                if (cnm_protection_matrix_prefix_reset_cg.get_coverage() < 100.0)
                    `uvm_fatal("CLUSTER_CNM_PROTECTION_RESET_PREFIX", $sformatf(
                        "accepted-prefix reset coverage incomplete: %0.1f%%",
                        cnm_protection_matrix_prefix_reset_cg.get_coverage()))
                `uvm_info("CLUSTER_CNM_PROTECTION_MATRIX_PREFIX_RESET_PASS", $sformatf(
                    "CNM source-A Protection 0x62 consumed during Matrix activity; reset after Matrix accepted Golden Line prefix=%0d/128 while Matrix remained active; untouched suffix, old-epoch completion suppression, quiet reset/release, and full ordered Matrix/CNM Golden recovery pass; focused_bins=6/6 seed=%0d",
                    matrix_write_accept_count, seed), UVM_LOW)
                axil_write(REG_CPLQ_HEAD, 32'd2);
                axil_write(REG_CMDQ_SIZE, 32'd0);
                axil_write(REG_CPLQ_SIZE, 32'd0);
            end else begin
                `uvm_info("CLUSTER_CNM_PROTECTION_RESET_OWNER_CROSS_PASS", $sformatf(
                "CNM source-A Protection denial concurrent with active Matrix; reset flushed both engines after %0d accepted Matrix reads, no completion/writeback or post-reset stale response; overlap=%0d seed=%0d",
                matrix_accept_count,
                both_busy_cycles, seed), UVM_LOW)
            end
            return;
        end

        if (abort_matrix_after_fault) begin
            if (!abort_issued || !abort_write_done || !cnm_fault_drained || !abort_active_seen ||
                !matrix_read_accepted || (matrix_accept_count == 0) ||
                (matrix_write_accept_count == 0))
                `uvm_fatal("CLUSTER_CNM_PROTECTION_ABORT_OWNER", $sformatf(
                    "missing CNM Protection/Matrix Abort sequence: issued=%0b write-done=%0b CNM-drained=%0b abort-active=%0b Matrix-reads=%0d Matrix-writes=%0d",
                    abort_issued, abort_write_done, cnm_fault_drained, abort_active_seen,
                    matrix_accept_count, matrix_write_accept_count))
            wait_cpl_tail(32'd2);
            wait_spad_idle();
            axil_write(REG_REGION0_PERM, 32'd0);
            axil_write(REG_REGION1_PERM, 32'd0);
            axil_write(REG_REGION2_PERM, 32'd0);
            axil_write(REG_REGION3_PERM, 32'd0);

            expect_spad(cpl_base, {16'd0, matrix_task_id},
                        "CNM Protection/Matrix Abort ordered Matrix task ID");
            expect_spad(cpl_base + 32'h04, 32'h0000_0032,
                        "CNM Protection/Matrix Abort Matrix ERR_ABORT");
            expect_spad(cpl_base + 32'h10, {16'd0, cnm_task_id},
                        "CNM Protection/Matrix Abort ordered CNM task ID");
            expect_spad(cpl_base + 32'h14, 32'h0000_0062,
                        "CNM Protection/Matrix Abort CNM ERR_PROTECTION");

            begin : check_matrix_abort_write_image
                bit [31:0] actual_word;
                int unsigned line_base_word;
                int unsigned row_idx;
                int unsigned col_idx;
                for (word_idx = 0; word_idx < 512; word_idx++)
                    matrix_output_written[word_idx] = 1'b0;
                for (cpl_idx = 0; cpl_idx < matrix_write_accept_count; cpl_idx++) begin
                    if ((matrix_line_write_addr[cpl_idx][3:0] != 0) ||
                        (matrix_line_write_addr[cpl_idx] < matrix_dst) ||
                        (matrix_line_write_addr[cpl_idx] >= matrix_dst + 32'h800) ||
                        (matrix_line_write_wstrb[cpl_idx] != 16'hffff))
                        `uvm_fatal("CLUSTER_CNM_PROTECTION_ABORT_OWNER", $sformatf(
                            "Matrix Abort committed malformed output Line: index=%0d addr=0x%08h WSTRB=%04h",
                            cpl_idx, matrix_line_write_addr[cpl_idx],
                            matrix_line_write_wstrb[cpl_idx]))
                    line_base_word = (matrix_line_write_addr[cpl_idx] - matrix_dst) >> 2;
                    for (lane = 0; lane < 4; lane++) begin
                        line_word_idx = line_base_word + lane;
                        if (line_word_idx >= 512)
                            `uvm_fatal("CLUSTER_CNM_PROTECTION_ABORT_OWNER",
                                "Matrix Abort output Line exceeds the descriptor destination")
                        if (matrix_output_written[line_word_idx])
                            `uvm_fatal("CLUSTER_CNM_PROTECTION_ABORT_OWNER", $sformatf(
                                "Matrix Abort accepted duplicate output word %0d",
                                line_word_idx))
                        row_idx = line_word_idx / 32;
                        col_idx = line_word_idx % 32;
                        if (matrix_line_write_data[cpl_idx][lane*32 +: 32] !==
                            expected_matrix[row_idx][col_idx])
                            `uvm_fatal("CLUSTER_CNM_PROTECTION_ABORT_OWNER", $sformatf(
                                "Matrix Abort accepted non-Golden output: word=%0d actual=0x%08h expected=0x%08h",
                                line_word_idx,
                                matrix_line_write_data[cpl_idx][lane*32 +: 32],
                                expected_matrix[row_idx][col_idx]))
                        matrix_output_written[line_word_idx] = 1'b1;
                    end
                end
                for (word_idx = 0; word_idx < 512; word_idx++) begin
                    axil_read(CIMFORGE_SPAD_BASE + matrix_dst + (word_idx << 2),
                              actual_word);
                    if (matrix_output_written[word_idx]) begin
                        if (actual_word !==
                            expected_matrix[word_idx / 32][word_idx % 32])
                            `uvm_fatal("CLUSTER_CNM_PROTECTION_ABORT_OWNER", $sformatf(
                                "Matrix Abort accepted output did not commit Golden data: word=%0d actual=0x%08h expected=0x%08h",
                                word_idx, actual_word,
                                expected_matrix[word_idx / 32][word_idx % 32]))
                    end else if (actual_word !== (32'hfa17_9000 | word_idx)) begin
                        `uvm_fatal("CLUSTER_CNM_PROTECTION_ABORT_OWNER", $sformatf(
                            "Matrix Abort changed an output word without an accepted Line: word=%0d actual=0x%08h sentinel=0x%08h",
                            word_idx, actual_word,
                            (32'hfa17_9000 | word_idx)))
                    end
                end
            end
            for (word_idx = 0; word_idx < 16; word_idx++)
                expect_spad(cnm_dst + (word_idx << 2),
                            32'hfa17_9800 | word_idx,
                            $sformatf("Protection-faulted CNM no-writeback[%0d]", word_idx));

            if (post_abort_matrix_writes != 0 ||
                compute_vif.matrix_tag_response_count - matrix_rsp_before !=
                    matrix_accept_count ||
                compute_vif.cnm_tag_response_count <= cnm_rsp_before ||
                compute_vif.matrix_route_mismatch_count != matrix_route_error_before ||
                compute_vif.cnm_route_mismatch_count != cnm_route_error_before)
                `uvm_fatal("CLUSTER_CNM_PROTECTION_ABORT_OWNER", $sformatf(
                    "Abort/drain/owner check failed: accepted Matrix reads=%0d responses=%0d Matrix writes=%0d post-Abort writes=%0d CNM responses=%0d routeMismatch=%0d/%0d",
                    matrix_accept_count,
                    compute_vif.matrix_tag_response_count - matrix_rsp_before,
                    matrix_write_accept_count, post_abort_matrix_writes,
                    compute_vif.cnm_tag_response_count - cnm_rsp_before,
                    compute_vif.matrix_route_mismatch_count - matrix_route_error_before,
                    compute_vif.cnm_route_mismatch_count - cnm_route_error_before))

            `uvm_info("CLUSTER_CNM_PROTECTION_MATRIX_ABORT_CROSS_PASS", $sformatf(
                "CNM Protection ERR 0x62 drained before software Abort of active Matrix ERR 0x32; ordered completions; accepted Matrix reads=%0d responses=%0d Matrix writes=%0d post-Abort writes=0 CNM responses=%0d route_mismatch=0; Matrix output is Golden prefix plus untouched suffix; seed=%0d",
                matrix_accept_count,
                compute_vif.matrix_tag_response_count - matrix_rsp_before,
                matrix_write_accept_count,
                compute_vif.cnm_tag_response_count - cnm_rsp_before, seed), UVM_LOW)
            axil_write(REG_CPLQ_HEAD, 32'd2);
            axil_write(REG_CMDQ_SIZE, 32'd0);
            axil_write(REG_CPLQ_SIZE, 32'd0);
            return;
        end

        wait_cpl_tail(32'd2);
        wait_spad_idle();
        axil_write(REG_REGION0_PERM, 32'd0);
        axil_write(REG_REGION1_PERM, 32'd0);
        axil_write(REG_REGION2_PERM, 32'd0);
        axil_write(REG_REGION3_PERM, 32'd0);

        expect_completion(cpl_base, matrix_task_id,
                          expected_matrix[15][31], 32'd512,
                          "Matrix Golden concurrent with CNM Protection");
        expect_spad(cpl_base + 32'h10, {16'd0, cnm_task_id},
                    "CNM Protection completion task/order");
        expect_spad(cpl_base + 32'h14, 32'h0000_0062,
                    "CNM source-A Protection completion owner");
        for (word_idx = 0; word_idx < 512; word_idx++)
            expect_spad(matrix_dst + (word_idx << 2),
                        expected_matrix[word_idx / 32][word_idx % 32],
                        $sformatf("CNM Protection concurrent Matrix Golden[%0d]", word_idx));
        for (word_idx = 0; word_idx < 16; word_idx++)
            expect_spad(cnm_dst + (word_idx << 2),
                        32'hfa17_9800 | word_idx,
                        $sformatf("CNM Protection no-writeback sentinel[%0d]", word_idx));

        if (compute_vif.matrix_cnm_overlap_cycles <= overlap_before ||
            compute_vif.matrix_tag_response_count <= matrix_rsp_before ||
            compute_vif.cnm_tag_response_count <= cnm_rsp_before ||
            compute_vif.matrix_route_mismatch_count != matrix_route_error_before ||
            compute_vif.cnm_route_mismatch_count != cnm_route_error_before)
            `uvm_fatal("CLUSTER_CNM_PROTECTION_OWNER", $sformatf(
                "owner/overlap evidence missing: overlap=%0d MatrixRsp=%0d CNMRsp=%0d routeMismatch=%0d/%0d",
                compute_vif.matrix_cnm_overlap_cycles - overlap_before,
                compute_vif.matrix_tag_response_count - matrix_rsp_before,
                compute_vif.cnm_tag_response_count - cnm_rsp_before,
                compute_vif.matrix_route_mismatch_count - matrix_route_error_before,
                compute_vif.cnm_route_mismatch_count - cnm_route_error_before))

        `uvm_info("CLUSTER_CNM_PROTECTION_MATRIX_OWNER_CROSS_PASS", $sformatf(
            "CNM source-A Protection ERR 0x62 while Matrix remains active and completes 512-word Golden; both_busy=%0d overlap=%0d MatrixRsp=%0d CNMRsp=%0d route_mismatch=0; CNM destination unchanged; seed=%0d",
            both_busy_cycles,
            compute_vif.matrix_cnm_overlap_cycles - overlap_before,
            compute_vif.matrix_tag_response_count - matrix_rsp_before,
            compute_vif.cnm_tag_response_count - cnm_rsp_before, seed), UVM_LOW)

        axil_write(REG_CPLQ_HEAD, 32'd2);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
    endtask

    task automatic run_real_engine_protection_case(
        input int unsigned engine,
        input int unsigned fault_phase,
        input int unsigned seed
    );
        bit [31:0] desc_addr;
        bit [31:0] cpl_addr;
        bit [31:0] src0;
        bit [31:0] src1;
        bit [31:0] src0_span;
        bit [31:0] src1_span;
        bit [31:0] dst;
        bit [31:0] task_id;
        bit [31:0] kv_aux0;
        bit [31:0] expected_error;
        bit [31:0] request_addr;
        bit [31:0] denied_addr;
        bit denied_seen;
        bit busy_seen;
        bit monitor_done;
        int unsigned cycle;
        int unsigned word_idx;

        if (engine > 6)
            `uvm_fatal("CLUSTER_PROTECTION", $sformatf("invalid engine index %0d", engine))

        if (fault_phase > 2)
            `uvm_fatal("CLUSTER_PROTECTION", $sformatf("invalid fault phase %0d", fault_phase))

        desc_addr = CLUSTER_PROT_CMDQ + (fault_phase * 32'h400) + (engine * 32'h40);
        cpl_addr = CLUSTER_PROT_CPLQ + (fault_phase * 32'h100) + (engine * 32'h10);
        dst = FAULT_Y_LOCAL + 32'h3000 + (engine * 32'h200) + (fault_phase * 32'h40);
        task_id = 32'h0730 + (fault_phase * 16) + engine;
        denied_seen = 1'b0;
        denied_addr = '0;
        busy_seen = 1'b0;
        monitor_done = 1'b0;
        src0_span = 32'h100;
        src1_span = 32'h100;

        for (word_idx = 0; word_idx < 16; word_idx++)
            spad_write(dst + (word_idx << 2), 32'hb10c_0000 | (engine << 8) | word_idx);

        case (engine)
            0: begin
                src0 = SCALAR_A_LOCAL;
                src1 = SCALAR_B_LOCAL;
                write_cluster_desc(desc_addr, 8'h10, task_id[15:0], src0, src1,
                                   dst, 16'd0, 16'd0, 16'd1, 32'd0,
                                   32'd0, 32'd0, 32'd0, 8'd3);
            end
            1: begin
                src0 = FP_A_LOCAL;
                src1 = FP_B_LOCAL;
                src0_span = 32'd4;
                src1_span = 32'd4;
                write_cluster_desc(desc_addr, 8'h50, task_id[15:0], src0, src1,
                                   dst, 16'd1, 16'd1, 16'd2, 32'd0,
                                   32'd0, 32'd0, 32'd0, 8'd7);
            end
            2: begin
                src0 = CNM_A_LOCAL;
                src1 = CNM_B_LOCAL;
                write_cnm_v3_desc(desc_addr, task_id[15:0], src0, src1, dst);
            end
            3: begin
                src0 = MATRIX_FAULT_A_LOCAL;
                src1 = MATRIX_FAULT_B_LOCAL;
                write_v3_desc(desc_addr, 8'h30, task_id[15:0], src0, src1,
                              dst, 16'd4, 16'd4, 16'd1);
            end
            4: begin
                src0 = GELU_A_LOCAL;
                src1 = 32'd0;
                write_v3_desc(desc_addr, 8'h35, task_id[15:0], src0, src1,
                              dst, 16'd0, 16'd0, 16'd4);
            end
            5: begin
                src0 = CONV_A_LOCAL;
                src1 = CONV_W_LOCAL;
                src0_span = 32'h40;
                src1_span = 32'h40;
                write_cluster_desc(desc_addr, 8'h16, task_id[15:0], src0, src1,
                                   dst, 16'd3, 16'd3, 16'd9, 32'd0,
                                   32'd0, 32'd0, 32'd0, 8'd5);
            end
            default: begin
                src0 = KV_VECTOR_LOCAL;
                src1 = 32'd0;
                kv_aux0 = (fault_phase == 2) ? 32'd0 : {16'd1,16'd1};
                write_cluster_desc(desc_addr, 8'h43, task_id[15:0], src0, src1,
                                   dst, 16'd0, 16'd0, 16'd4,
                                   kv_aux0, 32'd16, 32'd64,
                                   32'd0, 8'd5);
            end
        endcase

        // Phase 0 denies operand A while allowing B. Phase 1 denies operand B
        // while allowing A. Phase 2 allows reads and denies writeback. Region
        // bounds are valid/aligned in every case; only the named permission
        // is withdrawn so the result exercises a real Protection contract.
        axil_write(REG_REGION0_PERM, 32'd0);
        axil_write(REG_REGION1_PERM, 32'd0);
        axil_write(REG_REGION2_PERM, 32'd0);
        axil_write(REG_REGION3_PERM, 32'd0);
        axil_write(REG_REGION0_BASE, desc_addr);
        axil_write(REG_REGION0_LIMIT, desc_addr + 32'h40);
        axil_write(REG_REGION0_PERM, 32'h0000_000d); // enable + read + execute
        axil_write(REG_REGION1_BASE, cpl_addr);
        axil_write(REG_REGION1_LIMIT, cpl_addr + 32'h10);
        axil_write(REG_REGION1_PERM, 32'h0000_000b); // enable + read + write
        if (fault_phase == 0) begin
            if (src1 != 0) begin
                axil_write(REG_REGION2_BASE, src1);
                axil_write(REG_REGION2_LIMIT, src1 + src1_span);
                axil_write(REG_REGION2_PERM, 32'h0000_000d);
            end
        end else if (fault_phase == 1) begin
            axil_write(REG_REGION2_BASE, src0);
            axil_write(REG_REGION2_LIMIT, src0 + src0_span);
            axil_write(REG_REGION2_PERM, 32'h0000_000d);
        end else begin
            axil_write(REG_REGION2_BASE, src0);
            axil_write(REG_REGION2_LIMIT, src0 + src0_span);
            axil_write(REG_REGION2_PERM, 32'h0000_000d);
            if (src1 != 0) begin
                axil_write(REG_REGION3_BASE, src1);
                axil_write(REG_REGION3_LIMIT, src1 + src1_span);
                axil_write(REG_REGION3_PERM, 32'h0000_000d);
            end
        end

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

        for (cycle = 0; cycle < 30000 && !monitor_done; cycle++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.processor_busy)
                busy_seen = 1'b1;

            case (engine)
                2: begin
                    for (int lane = 0; lane < 4; lane++) begin
                        request_addr = compute_vif.selected_cnm_addr[lane];
                        if (compute_vif.selected_cnm_valid[lane] &&
                            !compute_vif.selected_cnm_access_ok[lane] &&
                            ((fault_phase == 0 && request_addr >= src0 && request_addr < src0 + src0_span) ||
                             (fault_phase == 1 && src1 != 0 && request_addr >= src1 && request_addr < src1 + src1_span))) begin
                            denied_seen = 1'b1;
                            denied_addr = request_addr;
                        end
                    end
                end
                3: begin
                    request_addr = compute_vif.selected_banked_addr;
                    if (compute_vif.selected_banked_valid &&
                        !compute_vif.selected_banked_access_ok &&
                        ((fault_phase == 0 && request_addr >= src0 && request_addr < src0 + src0_span) ||
                         (fault_phase == 1 && src1 != 0 && request_addr >= src1 && request_addr < src1 + src1_span))) begin
                        denied_seen = 1'b1;
                        denied_addr = request_addr;
                    end
                end
                default: begin
                    request_addr = compute_vif.selected_spad_addr;
                    if (compute_vif.selected_spad_valid &&
                        !compute_vif.selected_spad_access_ok &&
                        ((fault_phase == 0 && request_addr >= src0 && request_addr < src0 + src0_span) ||
                         (fault_phase == 1 && src1 != 0 && request_addr >= src1 && request_addr < src1 + src1_span))) begin
                        denied_seen = 1'b1;
                        denied_addr = request_addr;
                    end
                end
            endcase

            if ((fault_phase == 2) && compute_vif.selected_spad_valid &&
                compute_vif.selected_spad_write &&
                !compute_vif.selected_spad_access_ok &&
                (compute_vif.selected_spad_addr >= dst) &&
                (compute_vif.selected_spad_addr < dst + 32'h40)) begin
                denied_seen = 1'b1;
                denied_addr = compute_vif.selected_spad_addr;
            end

            if ((engine == 3) && (fault_phase == 2) &&
                compute_vif.selected_line_valid && compute_vif.selected_line_write &&
                !compute_vif.selected_line_access_ok &&
                (compute_vif.selected_line_addr >= dst) &&
                (compute_vif.selected_line_addr < dst + 32'h40)) begin
                denied_seen = 1'b1;
                denied_addr = compute_vif.selected_line_addr;
            end

            if (busy_seen && !compute_vif.processor_busy)
                monitor_done = 1'b1;
        end
        if (!busy_seen || !monitor_done)
            `uvm_fatal("CLUSTER_PROTECTION", $sformatf(
                "engine %0d did not complete within protection monitor window", engine))
        wait_cpl_tail(32'd1);
        wait_spad_idle();

        // Disable the test permissions before host-side readback checks.
        axil_write(REG_REGION0_PERM, 32'd0);
        axil_write(REG_REGION1_PERM, 32'd0);
        axil_write(REG_REGION2_PERM, 32'd0);
        axil_write(REG_REGION3_PERM, 32'd0);

        if (!denied_seen)
            `uvm_fatal("CLUSTER_PROTECTION", $sformatf(
                "engine %0d phase %0d completed without observing the denied request", engine, fault_phase))
        expected_error = ((engine == 5) || (engine == 6)) ? 32'h0000_0072 : 32'h0000_0062;
        expect_spad(cpl_addr, {16'd0, task_id[15:0]},
                    $sformatf("protection engine%0d phase%0d task ID", engine, fault_phase));
        expect_spad(cpl_addr + 32'h04, expected_error,
                    $sformatf("protection engine%0d phase%0d error completion", engine, fault_phase));
        for (word_idx = 0; word_idx < 16; word_idx++)
            expect_spad(dst + (word_idx << 2),
                        32'hb10c_0000 | (engine << 8) | word_idx,
                        $sformatf("protection engine%0d phase%0d no-writeback[%0d]", engine, fault_phase, word_idx));

        `uvm_info("CLUSTER_PROTECTION_CASE_PASS", $sformatf(
            "engine=%0d phase=%0d task=0x%04h denied_addr=0x%08h completion_error=%0d seed=%0d",
            engine, fault_phase, task_id[15:0], denied_addr, expected_error[7:4], seed), UVM_LOW)
        axil_write(REG_CPLQ_HEAD, 32'd1);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
    endtask

    task automatic wait_cpl_tail(input bit [31:0] expected);
        bit [31:0] value;
        int unsigned poll;
        value = '0;
        for (poll = 0; poll < 3000; poll++) begin
            axil_read(REG_CPLQ_TAIL, value);
            if (value == expected) return;
        end
        `uvm_fatal("CLUSTER_TIMEOUT", $sformatf("CPLQ_TAIL expected %0d got %0d", expected, value))
    endtask

    task automatic run_serial_descriptor(
        input bit [31:0] descriptor_base,
        input bit [31:0] completion_base,
        input bit [15:0] task_id,
        input bit [31:0] result,
        input bit [31:0] elements,
        input string tag,
        output int unsigned elapsed_cycles
    );
        int unsigned start_cycle;
        int unsigned end_cycle;
        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, descriptor_base);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd1);
        axil_write(REG_CPLQ_BASE, completion_base);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        start_cycle = compute_vif.sim_cycles;
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd1);
        end_cycle = compute_vif.sim_cycles;
        elapsed_cycles = end_cycle - start_cycle;
        wait_spad_idle();
        expect_completion(completion_base, task_id, result, elements, tag);
        axil_write(REG_CPLQ_HEAD, 32'd1);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
    endtask

    task automatic wait_spad_idle();
        int unsigned poll;
        int unsigned quiet_cycles;
        quiet_cycles = 0;
        for (poll = 0; poll < 50000; poll++) begin
            @(posedge compute_vif.aclk);
            if (!compute_vif.core_busy && !compute_vif.processor_busy &&
                (compute_vif.engine_busy == 0) &&
                (compute_vif.engine_req_valid == 0) &&
                !compute_vif.core_spad_valid &&
                !compute_vif.banked_valid &&
                (compute_vif.cnm_valid == 0) &&
                !compute_vif.matrix_line_valid &&
                !compute_vif.dma_valid &&
                !compute_vif.dma_line_valid &&
                !compute_vif.desc_valid &&
                !compute_vif.cpl_valid) begin
                quiet_cycles++;
                if (quiet_cycles == 3) return;
            end else
                quiet_cycles = 0;
        end
        `uvm_fatal("CLUSTER_SPAD_IDLE", $sformatf(
            "scheduler SPAD did not stay idle: core_busy=%b processor_busy=%b engine_busy=%07b engine_req=%07b core=%b banked=%b cnm=%b line=%b dma=%b dma_line=%b desc=%b cpl=%b",
            compute_vif.core_busy, compute_vif.processor_busy,
            compute_vif.engine_busy, compute_vif.engine_req_valid,
            compute_vif.core_spad_valid, compute_vif.banked_valid,
            compute_vif.cnm_valid, compute_vif.matrix_line_valid,
            compute_vif.dma_valid, compute_vif.dma_line_valid,
            compute_vif.desc_valid, compute_vif.cpl_valid))
    endtask

    task automatic run_dma_store_response_test();
        localparam bit [31:0] DMA_SOURCE_SPAD = 32'h0005_8000;
        localparam bit [31:0] DMA_DEST_DDR = 32'h0000_1800;
        bit [31:0] expected[0:3];
        bit [31:0] dma_status;
        uvm_hdl_data_t ddr_word;
        string ddr_path;
        bit hdl_ok;
        bit completed;
        int unsigned word_idx;
        int unsigned poll;

        for (word_idx = 0; word_idx < 4; word_idx++) begin
            expected[word_idx] = 32'hd00d_1000 ^ (word_idx * 32'h0101_0101);
            spad_write(DMA_SOURCE_SPAD + (word_idx << 2), expected[word_idx]);
        end
        axil_write(REG_DMA_EXT, DMA_DEST_DDR);
        axil_write(REG_DMA_SPAD, DMA_SOURCE_SPAD);
        axil_write(REG_DMA_LEN, 32'd4);
        axil_write(REG_DMA_CTRL, 32'd3); // SPAD -> DDR store

        completed = 1'b0;
        for (poll = 0; poll < 3000; poll++) begin
            axil_read(REG_DMA_STATUS, dma_status);
            if (dma_status[2])
                `uvm_fatal("CLUSTER_DMA_RESPONSE", $sformatf(
                    "DMA store error status=0x%08h", dma_status))
            if (dma_status[1]) begin
                completed = 1'b1;
                break;
            end
        end
        if (!completed)
            `uvm_fatal("CLUSTER_DMA_RESPONSE", "DMA store timed out")
        axil_write(REG_DMA_STATUS, 32'd2);

        for (word_idx = 0; word_idx < 4; word_idx++) begin
            ddr_path = $sformatf("tb_ai_accel_uvm.axi_mem_u.mem[%0d]",
                                 (DMA_DEST_DDR >> 2) + word_idx);
            ddr_word = '0;
            hdl_ok = uvm_hdl_read(ddr_path, ddr_word);
            if (!hdl_ok || ddr_word[31:0] !== expected[word_idx])
                `uvm_fatal("CLUSTER_DMA_RESPONSE", $sformatf(
                    "DMA store word%0d expected=0x%08h actual=0x%08h path=%s",
                    word_idx, expected[word_idx], ddr_word[31:0], ddr_path))
        end
        `uvm_info("CLUSTER_DMA_RESPONSE_PASS",
            "real top SPAD-to-DDR DMA store returned tagged client-4 reads and matched all four DDR words",
            UVM_LOW)
    endtask

    task automatic write_contract_vdot_desc(
        input bit [31:0] base,
        input bit [15:0] task_id,
        input bit [31:0] src0,
        input bit [31:0] src1,
        input bit [31:0] dst,
        input bit [15:0] length,
        input bit [7:0] unused_flags,
        input bit [31:0] unused_aux0,
        input bit [31:0] unused_src0_stride,
        input bit [31:0] unused_src1_stride,
        input bit [31:0] unused_dst_stride
    );
        write_cluster_desc(base, 8'h10, task_id, src0, src1, dst,
                           16'd0, 16'd0, length, unused_aux0,
                           unused_src0_stride, unused_src1_stride,
                           unused_dst_stride, 8'd3);
        // For VDOT, flags, aux0, and strides are descriptor fields but are
        // not consumed by the selected scalar opcode.
        spad_write(base + 32'h1c, {24'd0, unused_flags});
    endtask

    task automatic configure_contract_queues(
        input bit [31:0] completion_base,
        input bit [31:0] descriptor_count
    );
        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, CLUSTER_CONTRACT_CMDQ);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, descriptor_count);
        axil_write(REG_CPLQ_BASE, completion_base);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
    endtask

    task automatic clear_contract_queues(input bit [31:0] completion_head);
        axil_write(REG_CPLQ_HEAD, completion_head);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
    endtask

    task automatic run_banked_vdot_cmdq_dispatch_test(input int unsigned seed);
        bit [31:0] src0;
        bit [31:0] src1;
        bit [31:0] dst;
        bit [31:0] packed_word;
        bit [31:0] expected_word;
        bit [15:0] task_id;
        int unsigned launch_before;
        int unsigned k_idx;
        int unsigned lane;
        int unsigned byte_idx;
        int signed a_value;
        int signed b_value;
        int signed golden_sum;

        src0 = 32'h0004_e000;
        src1 = 32'h0004_e100;
        dst = 32'h0004_e200;
        task_id = 16'h0687;
        golden_sum = 0;

        // Banked VDOT consumes three K words from each physical bank. Keep
        // the four byte lanes distinct so the top-level launch and reduction
        // are checked against an independent signed Golden.
        for (k_idx = 0; k_idx < 3; k_idx++) begin
            for (lane = 0; lane < 4; lane++) begin
                packed_word = '0;
                for (byte_idx = 0; byte_idx < 4; byte_idx++) begin
                    a_value = int'(k_idx) + int'(lane) + int'(byte_idx) - 3;
                    b_value = (2 * int'(k_idx)) - int'(lane) + int'(byte_idx) + 1;
                    packed_word[byte_idx*8 +: 8] = a_value[7:0];
                    golden_sum += a_value * b_value;
                end
                spad_write(src0 + (k_idx << 4) + (lane << 2), packed_word);

                packed_word = '0;
                for (byte_idx = 0; byte_idx < 4; byte_idx++) begin
                    b_value = (2 * int'(k_idx)) - int'(lane) + int'(byte_idx) + 1;
                    packed_word[byte_idx*8 +: 8] = b_value[7:0];
                end
                spad_write(src1 + (k_idx << 4) + (lane << 2), packed_word);
            end
        end
        expected_word = golden_sum;
        spad_write(dst, 32'hbad0_0687);

        write_cluster_desc(CLUSTER_CONTRACT_CMDQ, 8'h20, task_id,
                           src0, src1, dst, 16'd1, 16'd1, 16'd3,
                           32'd0, 32'd0, 32'd0, 32'd0, 8'd3);
        launch_before = compute_vif.launch_sample_count;
        configure_contract_queues(CLUSTER_CONTRACT_CPLQ, 32'd1);
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd1);
        wait_spad_idle();

        if ((compute_vif.launch_sample_count - launch_before) != 1 ||
            compute_vif.launch_snapshot_opcode[2] !== 8'h20 ||
            compute_vif.launch_snapshot_src0[2] !== src0 ||
            compute_vif.launch_snapshot_src1[2] !== src1 ||
            compute_vif.launch_snapshot_dst[2] !== dst ||
            compute_vif.launch_snapshot_length[2] !== 16'd3)
            `uvm_fatal("CLUSTER_OPCODE_LAUNCH", $sformatf(
                "CMDQ opcode 0x20 launch mismatch: count_delta=%0d op=%02h src=%08h/%08h dst=%08h length=%0d",
                compute_vif.launch_sample_count - launch_before,
                compute_vif.launch_snapshot_opcode[2],
                compute_vif.launch_snapshot_src0[2],
                compute_vif.launch_snapshot_src1[2],
                compute_vif.launch_snapshot_dst[2],
                compute_vif.launch_snapshot_length[2]))

        expect_completion(CLUSTER_CONTRACT_CPLQ, task_id,
                          golden_sum, 32'd1,
                          "CMDQ banked VDOT opcode 0x20 completion");
        expect_spad(dst, expected_word, "CMDQ banked VDOT opcode 0x20 Golden");
        `uvm_info("CLUSTER_OPCODE_LAUNCH_PASS", $sformatf(
            "CMDQ fetch/validate/launch opcode=0x20 engine=CNM one completion and independent 48-byte-product signed Golden passed seed=%0d result=%0d",
            seed, golden_sum), UVM_LOW)
        clear_contract_queues(32'd1);
    endtask

    task automatic run_scalar_gemv_gemm_cmdq_dispatch_test(input int unsigned seed);
        bit [31:0] a_words[0:3];
        bit [31:0] b_words[0:3];
        bit [31:0] dst_base[0:1];
        bit [31:0] golden[0:1][0:3];
        bit [7:0] observed_opcode[0:1];
        bit [31:0] observed_src0[0:1];
        bit [31:0] observed_src1[0:1];
        bit [31:0] observed_dst[0:1];
        bit [15:0] observed_m[0:1];
        bit [15:0] observed_n[0:1];
        bit [15:0] observed_k[0:1];
        int unsigned launch_before;
        int unsigned engine_launch_before;
        int unsigned busy_launch_before;
        int unsigned launch_seen;
        int unsigned poll;
        int unsigned op_idx;
        int unsigned word_idx;
        int unsigned lane;
        int unsigned k_idx;
        int unsigned row_idx;
        int unsigned col_idx;
        int signed a_value;
        int signed b_value;
        int signed sum;
        bit [31:0] packed_a;
        bit [31:0] packed_b;
        bit monitor_complete;

        dst_base[0] = SCALAR_OPCODE_Y_LOCAL;
        dst_base[1] = SCALAR_OPCODE_Y_LOCAL + 32'h20;
        for (word_idx = 0; word_idx < 4; word_idx++) begin
            packed_a = '0;
            packed_b = '0;
            for (lane = 0; lane < 4; lane++) begin
                a_value = ((int'(seed % 13) + int'(word_idx * 5) + int'(lane * 3)) % 15) - 7;
                b_value = ((int'(seed % 11) + int'(word_idx * 7) + int'(lane * 2)) % 13) - 6;
                packed_a[lane*8 +: 8] = a_value[7:0];
                packed_b[lane*8 +: 8] = b_value[7:0];
            end
            a_words[word_idx] = packed_a;
            b_words[word_idx] = packed_b;
            spad_write(SCALAR_OPCODE_A_LOCAL + (word_idx << 2), packed_a);
            spad_write(SCALAR_OPCODE_B_LOCAL + (word_idx << 2), packed_b);
        end

        // Build independent signed-byte Goldens for 2xK GEMV and 2x2xK GEMM.
        // The GEMV input vector is reused for each row; GEMM advances A by row
        // and B by output column. The same K=2 vectors cover multiple packed
        // words and mixed positive/negative lane products.
        for (row_idx = 0; row_idx < 2; row_idx++) begin
            sum = 0;
            for (k_idx = 0; k_idx < 2; k_idx++) begin
                for (lane = 0; lane < 4; lane++) begin
                    a_value = $signed(a_words[k_idx][lane*8 +: 8]);
                    b_value = $signed(b_words[row_idx*2 + k_idx][lane*8 +: 8]);
                    sum += a_value * b_value;
                end
            end
            golden[0][row_idx] = sum;
            for (col_idx = 0; col_idx < 2; col_idx++) begin
                sum = 0;
                for (k_idx = 0; k_idx < 2; k_idx++) begin
                    for (lane = 0; lane < 4; lane++) begin
                        a_value = $signed(a_words[row_idx*2 + k_idx][lane*8 +: 8]);
                        b_value = $signed(b_words[col_idx*2 + k_idx][lane*8 +: 8]);
                        sum += a_value * b_value;
                    end
                end
                golden[1][row_idx*2 + col_idx] = sum;
            end
        end

        for (op_idx = 0; op_idx < 2; op_idx++) begin
            for (word_idx = 0; word_idx < 4; word_idx++)
                spad_write(dst_base[op_idx] + (word_idx << 2),
                           32'hbad0_a100 | (op_idx << 4) | word_idx);
            write_cluster_desc(SCALAR_OPCODE_CMDQ + (op_idx << 6),
                               op_idx == 0 ? 8'h11 : 8'h12,
                               16'h0690 + op_idx,
                               SCALAR_OPCODE_A_LOCAL, SCALAR_OPCODE_B_LOCAL,
                               dst_base[op_idx], 16'd2,
                               op_idx == 0 ? 16'd0 : 16'd2,
                               16'd2, 32'd0, 32'd0, 32'd0, 32'd0, 8'd3);
        end
        for (op_idx = 0; op_idx < 2; op_idx++) begin
            observed_opcode[op_idx] = '0;
            observed_src0[op_idx] = '0;
            observed_src1[op_idx] = '0;
            observed_dst[op_idx] = '0;
            observed_m[op_idx] = '0;
            observed_n[op_idx] = '0;
            observed_k[op_idx] = '0;
        end

        launch_before = compute_vif.launch_sample_count;
        engine_launch_before = compute_vif.engine_launch_count[0];
        busy_launch_before = compute_vif.same_engine_launch_while_busy;
        launch_seen = 0;
        monitor_complete = 1'b0;
        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, SCALAR_OPCODE_CMDQ);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd2);
        axil_write(REG_CPLQ_BASE, SCALAR_OPCODE_CPLQ);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);

        fork
            begin : scalar_opcode_launch_monitor
                for (poll = 0; poll < 50000 && launch_seen < 2; poll++) begin
                    @(posedge compute_vif.aclk);
                    if (compute_vif.launch_valid) begin
                        observed_opcode[launch_seen] = compute_vif.launch_op;
                        observed_src0[launch_seen] = compute_vif.launch_src0;
                        observed_src1[launch_seen] = compute_vif.launch_src1;
                        observed_dst[launch_seen] = compute_vif.launch_dst;
                        observed_m[launch_seen] = compute_vif.launch_m;
                        observed_n[launch_seen] = compute_vif.launch_n;
                        observed_k[launch_seen] = compute_vif.launch_k;
                        launch_seen++;
                    end
                end
                if (launch_seen != 2)
                    `uvm_fatal("CLUSTER_SCALAR_OPCODE", $sformatf(
                        "real CMDQ launch monitor timed out after %0d/2 Scalar launches",
                        launch_seen))
                monitor_complete = 1'b1;
            end
            begin : scalar_opcode_submit
                axil_write(REG_DOORBELL, 32'd1);
                wait_cpl_tail(32'd2);
            end
        join
        wait_spad_idle();

        if (!monitor_complete || observed_opcode[0] !== 8'h11 ||
            observed_opcode[1] !== 8'h12 ||
            observed_src0[0] !== SCALAR_OPCODE_A_LOCAL ||
            observed_src1[0] !== SCALAR_OPCODE_B_LOCAL ||
            observed_dst[0] !== dst_base[0] || observed_m[0] !== 16'd2 ||
            observed_n[0] !== 16'd0 || observed_k[0] !== 16'd2 ||
            observed_src0[1] !== SCALAR_OPCODE_A_LOCAL ||
            observed_src1[1] !== SCALAR_OPCODE_B_LOCAL ||
            observed_dst[1] !== dst_base[1] || observed_m[1] !== 16'd2 ||
            observed_n[1] !== 16'd2 || observed_k[1] !== 16'd2 ||
            compute_vif.launch_sample_count - launch_before != 2 ||
            compute_vif.engine_launch_count[0] - engine_launch_before != 2 ||
            compute_vif.same_engine_launch_while_busy != busy_launch_before)
            `uvm_fatal("CLUSTER_SCALAR_OPCODE", $sformatf(
                "CMDQ Scalar dispatch mismatch: op={%02h,%02h} launches=%0d engine0=%0d busy_relaunch_delta=%0d",
                observed_opcode[0], observed_opcode[1],
                compute_vif.launch_sample_count - launch_before,
                compute_vif.engine_launch_count[0] - engine_launch_before,
                compute_vif.same_engine_launch_while_busy - busy_launch_before))

        for (row_idx = 0; row_idx < 2; row_idx++)
            expect_spad(dst_base[0] + (row_idx << 2), golden[0][row_idx],
                        $sformatf("CMDQ GEMV row%0d Golden", row_idx));
        for (word_idx = 0; word_idx < 4; word_idx++)
            expect_spad(dst_base[1] + (word_idx << 2), golden[1][word_idx],
                        $sformatf("CMDQ GEMM element%0d Golden", word_idx));
        expect_completion(SCALAR_OPCODE_CPLQ, 16'h0690,
                          golden[0][1], 32'd2, "CMDQ Scalar GEMV completion");
        expect_completion(SCALAR_OPCODE_CPLQ + 32'h10, 16'h0691,
                          golden[1][3], 32'd4, "CMDQ Scalar GEMM completion");
        `uvm_info("CLUSTER_SCALAR_OPCODE_DISPATCH_PASS", $sformatf(
            "real CMDQ launches ordered Scalar GEMV 0x11 then GEMM 0x12 on engine 0; 2/2 completion and 6/6 output words match independent signed K=2 Golden; no relaunch while busy; seed=%0d",
            seed), UVM_LOW)
        axil_write(REG_CPLQ_HEAD, 32'd2);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
    endtask


    task automatic run_scalar_gemv_abort_write_prefix(input int unsigned seed);
        localparam int unsigned ROWS = 16;
        localparam int unsigned K_WORDS = 64;
        localparam bit [31:0] SRC_A = 32'h0006_d000;
        localparam bit [31:0] SRC_B = 32'h0006_e000;
        localparam bit [31:0] DST = 32'h0006_f000;
        localparam bit [31:0] COMPLETION = 32'h0000_5bc0;
        bit [31:0] write_addr[0:ROWS-1];
        bit [31:0] write_data[0:ROWS-1];
        int signed expected_output[0:ROWS-1];
        bit [31:0] packed_a;
        bit [31:0] packed_b;
        bit [15:0] task_id;
        int unsigned accepted_write_count;
        int unsigned accepted_reads;
        int unsigned returned_reads;
        int unsigned post_abort_output_writes;
        int unsigned poll;
        int unsigned row_idx;
        int unsigned k_idx;
        int unsigned lane;
        int signed a_value;
        int signed b_value;
        bit first_write_seen;
        bit abort_seen;
        bit abort_active_seen;
        bit monitor_done;

        task_id = 16'h07a0;
        accepted_write_count = 0;
        accepted_reads = 0;
        returned_reads = 0;
        post_abort_output_writes = 0;
        first_write_seen = 1'b0;
        abort_seen = 1'b0;
        abort_active_seen = 1'b0;
        monitor_done = 1'b0;

        // Build a legal 16-row GEMV with enough K work to let software Abort
        // arrive after a real output handshake and before the suffix is done.
        for (k_idx = 0; k_idx < K_WORDS; k_idx++) begin
            packed_a = '0;
            for (lane = 0; lane < 4; lane++) begin
                a_value = ((int'(seed % 7) + int'(k_idx * 5) +
                            int'(lane * 2)) % 15) - 7;
                packed_a[lane*8 +: 8] = a_value[7:0];
            end
            spad_write(SRC_A + (k_idx << 2), packed_a);
        end
        for (row_idx = 0; row_idx < ROWS; row_idx++) begin
            expected_output[row_idx] = 0;
            for (k_idx = 0; k_idx < K_WORDS; k_idx++) begin
                packed_b = '0;
                for (lane = 0; lane < 4; lane++) begin
                    a_value = ((int'(seed % 7) + int'(k_idx * 5) +
                                int'(lane * 2)) % 15) - 7;
                    b_value = ((int'(seed % 5) + int'(row_idx * 3) +
                                int'(k_idx * 5) + int'(lane * 7)) % 13) - 6;
                    packed_b[lane*8 +: 8] = b_value[7:0];
                    expected_output[row_idx] += a_value * b_value;
                end
                spad_write(SRC_B + ((row_idx * K_WORDS + k_idx) << 2),
                           packed_b);
            end
            spad_write(DST + (row_idx << 2),
                       32'hbad0_7a00 | row_idx);
        end
        for (row_idx = 0; row_idx < 4; row_idx++)
            spad_write(COMPLETION + (row_idx << 2),
                       32'h7a00_0000 | row_idx);

        write_cluster_desc(CLUSTER_CONTRACT_CMDQ, 8'h11, task_id,
                           SRC_A, SRC_B, DST,
                           16'd16, 16'd0, 16'd64, 32'd0,
                           32'd0, 32'd0, 32'd0, 8'd3);
        configure_contract_queues(COMPLETION, 32'd1);

        fork
            begin : scalar_abort_prefix_monitor
                while (!monitor_done) begin
                    @(posedge compute_vif.aclk);
                    if (compute_vif.engine_req_valid[0] &&
                        compute_vif.engine_req_ready[0] &&
                        compute_vif.engine_req_write[0]) begin
                        if (accepted_write_count >= ROWS)
                            `uvm_fatal("CLUSTER_SCALAR_ABORT_PREFIX",
                                "Scalar accepted more output writes than its 16-row GEMV")
                        write_addr[accepted_write_count] =
                            compute_vif.engine_req_addr[0 +: 32];
                        write_data[accepted_write_count] =
                            compute_vif.engine_req_wdata[0 +: 32];
                        accepted_write_count++;
                        first_write_seen = 1'b1;
                        // The write accepted on the first Abort-sampling edge
                        // belongs to the committed prefix. Only later writes
                        // violate the frozen Abort boundary.
                        if (abort_active_seen)
                            post_abort_output_writes++;
                    end
                    if (compute_vif.engine_req_valid[0] &&
                        compute_vif.engine_req_ready[0] &&
                        !compute_vif.engine_req_write[0])
                        accepted_reads++;
                    if (compute_vif.rsp_valid && compute_vif.rsp_client == 3'd2)
                        returned_reads++;
                    if (compute_vif.dut_abort_active) begin
                        abort_seen = 1'b1;
                        abort_active_seen = 1'b1;
                    end
                end
            end
            begin : scalar_abort_after_first_output
                axil_write(REG_DOORBELL, 32'd1);
                poll = 0;
                while (!first_write_seen && poll < 100000) begin
                    @(posedge compute_vif.aclk);
                    poll++;
                end
                if (!first_write_seen)
                    `uvm_fatal("CLUSTER_SCALAR_ABORT_PREFIX",
                        "Scalar GEMV did not accept an output write before Abort timeout")
                axil_write(REG_ABORT, 32'd1);
                wait_cpl_tail(32'd1);
                monitor_done = 1'b1;
            end
        join

        wait_spad_idle();
        if (!abort_seen)
            `uvm_fatal("CLUSTER_SCALAR_ABORT_PREFIX",
                "software Abort was not observed while Scalar GEMV was active")
        if (accepted_write_count == 0 || accepted_write_count >= ROWS)
            `uvm_fatal("CLUSTER_SCALAR_ABORT_PREFIX", $sformatf(
                "Abort did not cut a non-empty proper Scalar GEMV prefix: writes=%0d",
                accepted_write_count))
        if (accepted_reads == 0 || returned_reads != accepted_reads)
            `uvm_fatal("CLUSTER_SCALAR_ABORT_PREFIX", $sformatf(
                "Scalar GEMV read responses did not drain: accepted=%0d returned=%0d",
                accepted_reads, returned_reads))
        if (post_abort_output_writes != 0)
            `uvm_fatal("CLUSTER_SCALAR_ABORT_PREFIX", $sformatf(
                "Scalar GEMV accepted %0d output writes after Abort sampling",
                post_abort_output_writes))

        expect_spad(COMPLETION + 32'h00, {16'd0, task_id},
                    "Scalar accepted-write Abort task ID");
        expect_spad(COMPLETION + 32'h04, 32'h0000_0032,
                    "Scalar accepted-write Abort status/code");
        for (row_idx = 0; row_idx < accepted_write_count; row_idx++) begin
            if (write_addr[row_idx] !== DST + (row_idx << 2))
                `uvm_fatal("CLUSTER_SCALAR_ABORT_PREFIX", $sformatf(
                    "non-prefix Scalar output address index=%0d expected=0x%08h actual=0x%08h",
                    row_idx, DST + (row_idx << 2), write_addr[row_idx]))
            if (write_data[row_idx] !== expected_output[row_idx])
                `uvm_fatal("CLUSTER_SCALAR_ABORT_PREFIX", $sformatf(
                    "Scalar accepted-prefix Golden mismatch index=%0d expected=%0d actual=%0d",
                    row_idx, expected_output[row_idx], $signed(write_data[row_idx])))
            expect_spad(DST + (row_idx << 2), expected_output[row_idx],
                        $sformatf("Scalar accepted Abort prefix Golden[%0d]", row_idx));
        end
        for (row_idx = accepted_write_count; row_idx < ROWS; row_idx++)
            expect_spad(DST + (row_idx << 2), 32'hbad0_7a00 | row_idx,
                        $sformatf("Scalar Abort preserved unaccepted suffix[%0d]", row_idx));

        `uvm_info("CLUSTER_SCALAR_ABORT_WRITE_PREFIX_PASS", $sformatf(
            "task_id=%04h accepted_output_prefix=%0d/16 read_drain=%0d/%0d post_abort_writes=%0d completion=ERR_ABORT seed=%0d",
            task_id, accepted_write_count, accepted_reads, returned_reads,
            post_abort_output_writes, seed), UVM_LOW)
        axil_write(REG_CPLQ_HEAD, 32'd1);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
    endtask


    task automatic run_scalar_cmdq_numeric_boundary_test(input int unsigned seed);
        localparam bit [31:0] NUM_CMDQ = 32'h0005_b000;
        localparam bit [31:0] NUM_CPLQ = 32'h0005_b400;
        localparam bit [31:0] NUM_A = 32'h0007_2000;
        localparam bit [31:0] NUM_B = 32'h0007_2100;
        localparam bit [31:0] NUM_Y = 32'h0007_2200;
        localparam bit [31:0] NUM_BIAS = 32'h0007_2300;
        bit [31:0] a_data[0:6];
        bit [31:0] b_data[0:6];
        bit [31:0] bias_data[0:6];
        bit bias_enable[0:6];
        bit [4:0] shifts[0:6];
        bit [1:0] activations[0:6];
        bit [31:0] expected[0:6];
        bit [7:0] observed_op[0:6];
        bit [31:0] observed_src0[0:6];
        bit [31:0] observed_src1[0:6];
        bit [31:0] observed_dst[0:6];
        bit [15:0] observed_m[0:6];
        bit [15:0] observed_n[0:6];
        bit [15:0] observed_k[0:6];
        bit [4:0] observed_shift[0:6];
        bit [1:0] observed_activation[0:6];
        bit [31:0] observed_bias_base[0:6];
        bit observed_bias_enable[0:6];
        bit [6:0] case_mask;
        longint signed accum;
        longint signed shifted_sum;
        int signed a_value;
        int signed b_value;
        int unsigned lane;
        int unsigned idx;
        int unsigned launch_before;
        int unsigned engine_launch_before;
        int unsigned busy_launch_before;
        int unsigned launch_seen;
        int unsigned poll;
        bit monitor_complete;

        // Seven legal 1xK1 descriptors cover bias sign extension and saturation,
        // arithmetic shift 31, and all assigned activation encodings.
        a_data[0] = 32'h7f7f_7f7f; b_data[0] = 32'h7f7f_7f7f;
        a_data[1] = 32'h8080_8080; b_data[1] = 32'h7f7f_7f7f;
        a_data[2] = 32'h7f7f_7f7f; b_data[2] = 32'h7f7f_7f7f;
        a_data[3] = 32'h7f7f_7f7f; b_data[3] = 32'h7f7f_7f7f;
        a_data[4] = 32'h8080_8080; b_data[4] = 32'h7f7f_7f7f;
        a_data[5] = 32'h7f7f_7f7f; b_data[5] = 32'h7f7f_7f7f;
        a_data[6] = 32'h8080_8080; b_data[6] = 32'h7f7f_7f7f;

        bias_data[0] = 32'h7fff_ffff; bias_enable[0] = 1'b1;
        bias_data[1] = 32'h8000_0000; bias_enable[1] = 1'b1;
        bias_data[2] = 32'h8000_0000; bias_enable[2] = 1'b1;
        bias_data[3] = 32'd0;         bias_enable[3] = 1'b0;
        bias_data[4] = 32'd0;         bias_enable[4] = 1'b0;
        bias_data[5] = 32'd0;         bias_enable[5] = 1'b0;
        bias_data[6] = 32'd0;         bias_enable[6] = 1'b0;

        shifts[0] = 5'd0;  activations[0] = 2'd0;
        shifts[1] = 5'd0;  activations[1] = 2'd0;
        shifts[2] = 5'd31; activations[2] = 2'd0;
        shifts[3] = 5'd0;  activations[3] = 2'd1;
        shifts[4] = 5'd0;  activations[4] = 2'd1;
        shifts[5] = 5'd0;  activations[5] = 2'd2;
        shifts[6] = 5'd0;  activations[6] = 2'd2;

        for (idx = 0; idx < 7; idx++) begin
            spad_write(NUM_A + (idx << 2), a_data[idx]);
            spad_write(NUM_B + (idx << 2), b_data[idx]);
            spad_write(NUM_BIAS + (idx << 2), bias_data[idx]);
            spad_write(NUM_Y + (idx << 2), 32'hbad0_b200 | idx);
            write_cluster_desc(NUM_CMDQ + (idx << 6), 8'h11,
                               16'h06a0 + idx,
                               NUM_A + (idx << 2), NUM_B + (idx << 2),
                               NUM_Y + (idx << 2), 16'd1, 16'd0, 16'd1,
                               32'd0, 32'd0, 32'd0, 32'd0, 8'd3);
            spad_write(NUM_CMDQ + (idx << 6) + 32'h0c, NUM_BIAS + (idx << 2));
            spad_write(NUM_CMDQ + (idx << 6) + 32'h1c,
                       {31'd0, bias_enable[idx]});
            spad_write(NUM_CMDQ + (idx << 6) + 32'h24,
                       {25'd0, activations[idx], shifts[idx]});
            observed_op[idx] = '0;
            observed_src0[idx] = '0;
            observed_src1[idx] = '0;
            observed_dst[idx] = '0;
            observed_m[idx] = '0;
            observed_n[idx] = '0;
            observed_k[idx] = '0;
            observed_shift[idx] = '0;
            observed_activation[idx] = '0;
            observed_bias_base[idx] = '0;
            observed_bias_enable[idx] = 1'b0;

            accum = 64'sd0;
            if (bias_enable[idx])
                accum = $signed(bias_data[idx]);
            for (lane = 0; lane < 4; lane++) begin
                a_value = $signed(a_data[idx][lane*8 +: 8]);
                b_value = $signed(b_data[idx][lane*8 +: 8]);
                accum += a_value * b_value;
            end
            shifted_sum = accum >>> shifts[idx];
            if (activations[idx] == 2'd1 && shifted_sum < 0)
                shifted_sum = 64'sd0;
            else if (activations[idx] == 2'd2) begin
                if (shifted_sum < 0)
                    shifted_sum = 64'sd0;
                else if (shifted_sum > 64'sd6)
                    shifted_sum = 64'sd6;
            end
            if (shifted_sum > 64'sd2147483647)
                expected[idx] = 32'h7fff_ffff;
            else if (shifted_sum < -64'sd2147483648)
                expected[idx] = 32'h8000_0000;
            else
                expected[idx] = shifted_sum[31:0];
        end

        launch_before = compute_vif.launch_sample_count;
        engine_launch_before = compute_vif.engine_launch_count[0];
        busy_launch_before = compute_vif.same_engine_launch_while_busy;
        launch_seen = 0;
        case_mask = '0;
        monitor_complete = 1'b0;
        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, NUM_CMDQ);
        axil_write(REG_CMDQ_SIZE, 32'd8);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd7);
        axil_write(REG_CPLQ_BASE, NUM_CPLQ);
        axil_write(REG_CPLQ_SIZE, 32'd8);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);

        fork
            begin : scalar_numeric_launch_monitor
                for (poll = 0; poll < 50000 && launch_seen < 7; poll++) begin
                    @(posedge compute_vif.aclk);
                    if (compute_vif.launch_valid) begin
                        if (launch_seen >= 7)
                            `uvm_fatal("CLUSTER_SCALAR_NUMERIC", "unexpected extra Scalar launch")
                        observed_op[launch_seen] = compute_vif.launch_op;
                        observed_src0[launch_seen] = compute_vif.launch_src0;
                        observed_src1[launch_seen] = compute_vif.launch_src1;
                        observed_dst[launch_seen] = compute_vif.launch_dst;
                        observed_m[launch_seen] = compute_vif.launch_m;
                        observed_n[launch_seen] = compute_vif.launch_n;
                        observed_k[launch_seen] = compute_vif.launch_k;
                        observed_shift[launch_seen] = compute_vif.launch_shift;
                        observed_activation[launch_seen] = compute_vif.launch_activation;
                        observed_bias_base[launch_seen] = compute_vif.launch_bias_base;
                        observed_bias_enable[launch_seen] = compute_vif.launch_bias_enable;
                        launch_seen++;
                    end
                end
                if (launch_seen != 7)
                    `uvm_fatal("CLUSTER_SCALAR_NUMERIC", $sformatf(
                        "real CMDQ numeric launch monitor timed out after %0d/7 launches",
                        launch_seen))
                monitor_complete = 1'b1;
            end
            begin : scalar_numeric_submit
                axil_write(REG_DOORBELL, 32'd1);
                wait_cpl_tail(32'd7);
            end
        join
        wait_spad_idle();

        if (!monitor_complete ||
            compute_vif.launch_sample_count - launch_before != 7 ||
            compute_vif.engine_launch_count[0] - engine_launch_before != 7 ||
            compute_vif.same_engine_launch_while_busy != busy_launch_before)
            `uvm_fatal("CLUSTER_SCALAR_NUMERIC", $sformatf(
                "launch accounting mismatch: launches=%0d engine0=%0d busy_relaunch_delta=%0d",
                compute_vif.launch_sample_count - launch_before,
                compute_vif.engine_launch_count[0] - engine_launch_before,
                compute_vif.same_engine_launch_while_busy - busy_launch_before))

        for (idx = 0; idx < 7; idx++) begin
            if (observed_op[idx] !== 8'h11 ||
                observed_src0[idx] !== (NUM_A + (idx << 2)) ||
                observed_src1[idx] !== (NUM_B + (idx << 2)) ||
                observed_dst[idx] !== (NUM_Y + (idx << 2)) ||
                observed_m[idx] !== 16'd1 || observed_n[idx] !== 16'd0 ||
                observed_k[idx] !== 16'd1 ||
                observed_shift[idx] !== shifts[idx] ||
                observed_activation[idx] !== activations[idx] ||
                observed_bias_base[idx] !== (NUM_BIAS + (idx << 2)) ||
                observed_bias_enable[idx] !== bias_enable[idx])
                `uvm_fatal("CLUSTER_SCALAR_NUMERIC", $sformatf(
                    "launch %0d descriptor mismatch op=%02h shape=%0dx%0dx%0d shift=%0d activation=%0d bias=%08h/%0b",
                    idx, observed_op[idx], observed_m[idx], observed_n[idx],
                    observed_k[idx], observed_shift[idx], observed_activation[idx],
                    observed_bias_base[idx], observed_bias_enable[idx]))
            expect_spad(NUM_Y + (idx << 2), expected[idx],
                        $sformatf("CMDQ Scalar numeric boundary case%0d", idx));
            expect_completion(NUM_CPLQ + (idx << 4), 16'h06a0 + idx,
                              expected[idx], 32'd1,
                              $sformatf("CMDQ Scalar numeric completion case%0d", idx));
            case_mask[idx] = 1'b1;
        end

        if (case_mask !== 7'h7f)
            `uvm_fatal("CLUSTER_SCALAR_NUMERIC", $sformatf(
                "numeric case coverage incomplete mask=%02h", case_mask))
        `uvm_info("CLUSTER_SCALAR_CMDQ_NUMERIC_BOUNDARY_PASS", $sformatf(
            "real CMDQ 1xK1 Scalar bias min/max, shift31, Identity/ReLU/ReLU6 and signed INT32 saturation; case_mask=%02h outputs=7/7 completions=7/7 seed=%0d",
            case_mask, seed), UVM_LOW)
        axil_write(REG_CPLQ_HEAD, 32'd7);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
    endtask

    task automatic run_scalar_legacy_conv_cmdq_test(input int unsigned seed);
        localparam bit [31:0] LEGACY_CMDQ = 32'h0005_c000;
        localparam bit [31:0] LEGACY_CPLQ = 32'h0005_c100;
        localparam bit [31:0] LEGACY_A = 32'h0007_3000;
        localparam bit [31:0] LEGACY_B = 32'h0007_3400;
        localparam bit [31:0] LEGACY_Y = 32'h0007_3800;
        localparam int unsigned OUTPUTS = 4;
        bit [7:0] opcode[0:2];
        bit [15:0] k_words[0:2];
        bit [31:0] observed_src0[0:2];
        bit [31:0] observed_src1[0:2];
        bit [31:0] observed_dst[0:2];
        bit [7:0] observed_opcode[0:2];
        bit [15:0] observed_m[0:2];
        bit [15:0] observed_n[0:2];
        bit [15:0] observed_k[0:2];
        bit [31:0] a_words[0:2][0:17];
        bit [31:0] b_words[0:2][0:17];
        bit [31:0] golden[0:2][0:3];
        bit [2:0] case_mask;
        longint signed accum;
        int signed a_value;
        int signed b_value;
        int signed sample_value;
        int unsigned launch_before;
        int unsigned engine_launch_before;
        int unsigned busy_launch_before;
        int unsigned launch_seen;
        int unsigned poll;
        int unsigned op_idx;
        int unsigned word_idx;
        int unsigned word_count_a;
        int unsigned word_count_b;
        int unsigned row_idx;
        int unsigned col_idx;
        int unsigned out_idx;
        int unsigned k_idx;
        int unsigned lane;
        int unsigned a_index;
        int unsigned b_index;
        bit [31:0] packed_a;
        bit [31:0] packed_b;
        bit monitor_complete;

        opcode[0] = 8'h13; // legacy Conv1x1 on the scalar INT8 core
        opcode[1] = 8'h14; // legacy im2col Conv3x3 on the scalar INT8 core
        opcode[2] = 8'h15; // legacy depthwise Conv3x3 on the scalar INT8 core
        k_words[0] = 16'd2;
        k_words[1] = 16'd9;
        k_words[2] = 16'd2;

        // Exercise all three legacy opcodes through descriptor fetch,
        // validator, scalar launch, SPAD, completion writer, and full image.
        // 0x14 models a 3x3 im2col patch as nine packed K words. 0x15 stores
        // one A vector per flattened output pixel/channel and one B vector
        // per channel, matching the core's depthwise address progression.
        for (op_idx = 0; op_idx < 3; op_idx++) begin
            word_count_a = (op_idx == 2) ?
                           (4 * int'(k_words[op_idx])) :
                           (2 * int'(k_words[op_idx]));
            word_count_b = 2 * int'(k_words[op_idx]);
            for (word_idx = 0; word_idx < word_count_a; word_idx++) begin
                packed_a = '0;
                for (lane = 0; lane < 4; lane++) begin
                    sample_value = (int'(seed % 251) + int'(op_idx * 29) +
                                    int'(word_idx * 17) + int'(lane * 53)) % 255;
                    sample_value = sample_value - 128;
                    packed_a[lane*8 +: 8] = sample_value[7:0];
                end
                a_words[op_idx][word_idx] = packed_a;
                spad_write(LEGACY_A + (op_idx * 32'h100) + (word_idx << 2),
                           packed_a);
            end
            for (word_idx = 0; word_idx < word_count_b; word_idx++) begin
                packed_b = '0;
                for (lane = 0; lane < 4; lane++) begin
                    sample_value = (int'(seed % 241) + int'(op_idx * 43) +
                                    int'(word_idx * 31) + int'(lane * 47)) % 255;
                    sample_value = sample_value - 128;
                    packed_b[lane*8 +: 8] = sample_value[7:0];
                end
                b_words[op_idx][word_idx] = packed_b;
                spad_write(LEGACY_B + (op_idx * 32'h100) + (word_idx << 2),
                           packed_b);
            end

            for (out_idx = 0; out_idx < OUTPUTS; out_idx++) begin
                row_idx = out_idx / 2;
                col_idx = out_idx % 2;
                accum = 64'sd0;
                for (k_idx = 0; k_idx < int'(k_words[op_idx]); k_idx++) begin
                    if (op_idx == 2)
                        a_index = out_idx * int'(k_words[op_idx]) + k_idx;
                    else
                        a_index = row_idx * int'(k_words[op_idx]) + k_idx;
                    b_index = col_idx * int'(k_words[op_idx]) + k_idx;
                    for (lane = 0; lane < 4; lane++) begin
                        a_value = $signed(a_words[op_idx][a_index][lane*8 +: 8]);
                        b_value = $signed(b_words[op_idx][b_index][lane*8 +: 8]);
                        accum += a_value * b_value;
                    end
                end
                golden[op_idx][out_idx] = accum[31:0];
                spad_write(LEGACY_Y + (op_idx * 32'h100) + (out_idx << 2),
                           32'hbad0_c100 | (op_idx << 4) | out_idx);
            end

            write_cluster_desc(LEGACY_CMDQ + (op_idx << 6), opcode[op_idx],
                               16'h06c0 + op_idx,
                               LEGACY_A + (op_idx * 32'h100),
                               LEGACY_B + (op_idx * 32'h100),
                               LEGACY_Y + (op_idx * 32'h100),
                               16'd2, 16'd2, k_words[op_idx],
                               32'd0, 32'd0, 32'd0, 32'd0, 8'd3);
            observed_opcode[op_idx] = '0;
            observed_src0[op_idx] = '0;
            observed_src1[op_idx] = '0;
            observed_dst[op_idx] = '0;
            observed_m[op_idx] = '0;
            observed_n[op_idx] = '0;
            observed_k[op_idx] = '0;
        end

        launch_before = compute_vif.launch_sample_count;
        engine_launch_before = compute_vif.engine_launch_count[0];
        busy_launch_before = compute_vif.same_engine_launch_while_busy;
        launch_seen = 0;
        case_mask = '0;
        monitor_complete = 1'b0;
        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, LEGACY_CMDQ);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd3);
        axil_write(REG_CPLQ_BASE, LEGACY_CPLQ);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);

        fork
            begin : legacy_conv_launch_monitor
                for (poll = 0; poll < 50000 && launch_seen < 3; poll++) begin
                    @(posedge compute_vif.aclk);
                    if (compute_vif.launch_valid) begin
                        if (launch_seen >= 3)
                            `uvm_fatal("CLUSTER_LEGACY_CONV", "unexpected extra Scalar launch")
                        observed_opcode[launch_seen] = compute_vif.launch_op;
                        observed_src0[launch_seen] = compute_vif.launch_src0;
                        observed_src1[launch_seen] = compute_vif.launch_src1;
                        observed_dst[launch_seen] = compute_vif.launch_dst;
                        observed_m[launch_seen] = compute_vif.launch_m;
                        observed_n[launch_seen] = compute_vif.launch_n;
                        observed_k[launch_seen] = compute_vif.launch_k;
                        launch_seen++;
                    end
                end
                if (launch_seen != 3)
                    `uvm_fatal("CLUSTER_LEGACY_CONV", $sformatf(
                        "real CMDQ launch monitor timed out after %0d/3 legacy Scalar Conv launches",
                        launch_seen))
                monitor_complete = 1'b1;
            end
            begin : legacy_conv_submit
                axil_write(REG_DOORBELL, 32'd1);
                wait_cpl_tail(32'd3);
            end
        join
        wait_spad_idle();

        if (!monitor_complete ||
            compute_vif.launch_sample_count - launch_before != 3 ||
            compute_vif.engine_launch_count[0] - engine_launch_before != 3 ||
            compute_vif.same_engine_launch_while_busy != busy_launch_before)
            `uvm_fatal("CLUSTER_LEGACY_CONV", $sformatf(
                "legacy Conv launch accounting mismatch: launches=%0d engine0=%0d busy_relaunch_delta=%0d",
                compute_vif.launch_sample_count - launch_before,
                compute_vif.engine_launch_count[0] - engine_launch_before,
                compute_vif.same_engine_launch_while_busy - busy_launch_before))

        for (op_idx = 0; op_idx < 3; op_idx++) begin
            if (observed_opcode[op_idx] !== opcode[op_idx] ||
                observed_src0[op_idx] !== (LEGACY_A + (op_idx * 32'h100)) ||
                observed_src1[op_idx] !== (LEGACY_B + (op_idx * 32'h100)) ||
                observed_dst[op_idx] !== (LEGACY_Y + (op_idx * 32'h100)) ||
                observed_m[op_idx] !== 16'd2 || observed_n[op_idx] !== 16'd2 ||
                observed_k[op_idx] !== k_words[op_idx])
                `uvm_fatal("CLUSTER_LEGACY_CONV", $sformatf(
                    "legacy Conv descriptor/launch mismatch index=%0d op=%02h shape=%0dx%0dx%0d expected=%02h/2x2x%0d",
                    op_idx, observed_opcode[op_idx], observed_m[op_idx],
                    observed_n[op_idx], observed_k[op_idx], opcode[op_idx],
                    k_words[op_idx]))

            for (out_idx = 0; out_idx < OUTPUTS; out_idx++)
                expect_spad(LEGACY_Y + (op_idx * 32'h100) + (out_idx << 2),
                            golden[op_idx][out_idx],
                            $sformatf("legacy Conv opcode%02h output%0d Golden",
                                      opcode[op_idx], out_idx));
            expect_completion(LEGACY_CPLQ + (op_idx << 4), 16'h06c0 + op_idx,
                              golden[op_idx][OUTPUTS-1], 32'd4,
                              $sformatf("legacy Conv opcode%02h completion", opcode[op_idx]));
            case_mask[op_idx] = 1'b1;
        end

        if (case_mask !== 3'b111)
            `uvm_fatal("CLUSTER_LEGACY_CONV", $sformatf(
                "legacy Conv opcode testpoint coverage incomplete mask=%03b", case_mask))
        `uvm_info("CLUSTER_LEGACY_CONV_CMDQ_PASS", $sformatf(
            "real CMDQ Scalar opcodes 0x13/0x14/0x15; Conv1x1 2x2xK2, im2col Conv3x3 2x2xK9, depthwise Conv3x3 2x2xK2; 3/3 launch, completion and 12/12 independent Golden image words passed seed=%0d",
            seed), UVM_LOW)
        axil_write(REG_CPLQ_HEAD, 32'd3);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
    endtask

    task automatic run_launch_snapshot_and_unused_fields_test();
        int unsigned launch_before;

        spad_write(SCALAR_A_LOCAL, 32'h0403_0201);
        spad_write(SCALAR_B_LOCAL, 32'h0807_0605);
        spad_write(CONTRACT_Y0_LOCAL, 32'hbad0_0680);
        spad_write(CONTRACT_Y1_LOCAL, 32'hbad0_0681);
        write_contract_vdot_desc(CLUSTER_CONTRACT_CMDQ + 32'h00, 16'h0680,
                                 SCALAR_A_LOCAL, SCALAR_B_LOCAL,
                                 CONTRACT_Y0_LOCAL, 16'd1, 8'd0,
                                 32'd0, 32'd0, 32'd0, 32'd0);
        write_contract_vdot_desc(CLUSTER_CONTRACT_CMDQ + 32'h40, 16'h0681,
                                 SCALAR_A_LOCAL, SCALAR_B_LOCAL,
                                 CONTRACT_Y1_LOCAL, 16'd1, 8'h76,
                                 32'hcafe_f00d, 32'd16, 32'd32, 32'd64);

        launch_before = compute_vif.launch_sample_count;
        configure_contract_queues(CLUSTER_CONTRACT_CPLQ, 32'd2);
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd2);
        wait_spad_idle();

        expect_spad(CONTRACT_Y0_LOCAL, 32'd70, "VDOT default unused fields");
        expect_spad(CONTRACT_Y1_LOCAL, 32'd70, "VDOT perturbed unused fields");
        expect_completion(CLUSTER_CONTRACT_CPLQ + 32'h00, 16'h0680,
                          32'd70, 32'd1, "VDOT default field completion");
        expect_completion(CLUSTER_CONTRACT_CPLQ + 32'h10, 16'h0681,
                          32'd70, 32'd1, "VDOT unused-field completion");
        if (compute_vif.launch_sample_count != launch_before + 2 ||
            !compute_vif.launch_sample_seen[0])
            `uvm_fatal("CLUSTER_LAUNCH_SAMPLE", $sformatf(
                "expected two captured launches; before=%0d after=%0d seen=%07b",
                launch_before, compute_vif.launch_sample_count,
                compute_vif.launch_sample_seen))
        if (compute_vif.launch_snapshot_src0[0] !== SCALAR_A_LOCAL ||
            compute_vif.launch_snapshot_src1[0] !== SCALAR_B_LOCAL ||
            compute_vif.launch_snapshot_dst[0] !== CONTRACT_Y1_LOCAL ||
            compute_vif.launch_snapshot_length[0] !== 16'd1 ||
            compute_vif.launch_snapshot_flags[0] !== 8'h76 ||
            compute_vif.launch_snapshot_aux0[0] !== 32'hcafe_f00d ||
            compute_vif.launch_snapshot_src0_stride[0] !== 32'd16 ||
            compute_vif.launch_snapshot_src1_stride[0] !== 32'd32 ||
            compute_vif.launch_snapshot_dst_stride[0] !== 32'd64)
            `uvm_fatal("CLUSTER_LAUNCH_SAMPLE", $sformatf(
                "captured scalar launch differs from descriptor: src0=%08h src1=%08h dst=%08h length=%0d flags=%02h aux=%08h strides=%0d/%0d/%0d",
                compute_vif.launch_snapshot_src0[0],
                compute_vif.launch_snapshot_src1[0],
                compute_vif.launch_snapshot_dst[0],
                compute_vif.launch_snapshot_length[0],
                compute_vif.launch_snapshot_flags[0],
                compute_vif.launch_snapshot_aux0[0],
                compute_vif.launch_snapshot_src0_stride[0],
                compute_vif.launch_snapshot_src1_stride[0],
                compute_vif.launch_snapshot_dst_stride[0]))
        `uvm_info("CLUSTER_LAUNCH_FIELDS_PASS",
            "launch payload sampled from the descriptor; changing scalar VDOT flags/aux/strides left Golden output unchanged",
            UVM_LOW)
        clear_contract_queues(32'd2);
    endtask

    task automatic run_inflight_parameter_latch_test();
        int unsigned word_idx;
        int unsigned poll;
        int unsigned launch_before;
        bit busy_seen;
        bit [31:0] completion_base;
        completion_base = CLUSTER_CONTRACT_CPLQ + 32'h100;

        for (word_idx = 0; word_idx < 64; word_idx++) begin
            spad_write(CONTRACT_SHARED_LOCAL + (word_idx << 2), 32'h0403_0201);
            spad_write(CONTRACT_B_LOCAL + (word_idx << 2), 32'h0807_0605);
        end
        spad_write(CONTRACT_Y0_LOCAL, 32'hbad0_0682);
        spad_write(CONTRACT_MUTATED_Y_LOCAL, 32'hbad0_06f0);
        write_contract_vdot_desc(CLUSTER_CONTRACT_CMDQ, 16'h0682,
                                 CONTRACT_SHARED_LOCAL, CONTRACT_B_LOCAL,
                                 CONTRACT_Y0_LOCAL, 16'd64, 8'd0,
                                 32'd0, 32'd0, 32'd0, 32'd0);
        launch_before = compute_vif.launch_sample_count;
        configure_contract_queues(completion_base, 32'd1);
        axil_write(REG_DOORBELL, 32'd1);
        busy_seen = 1'b0;
        for (poll = 0; poll < 3000; poll++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.engine_busy[0]) begin
                busy_seen = 1'b1;
                break;
            end
        end
        if (!busy_seen)
            `uvm_fatal("CLUSTER_PARAM_LATCH", "scalar task did not become active before descriptor mutation")

        // The descriptor has been sampled and the scalar engine is active.
        // Repointing its backing descriptor now must not change this task.
        spad_write(CLUSTER_CONTRACT_CMDQ + 32'h04, CONTRACT_B_LOCAL);
        spad_write(CLUSTER_CONTRACT_CMDQ + 32'h08, CONTRACT_B_LOCAL);
        spad_write(CLUSTER_CONTRACT_CMDQ + 32'h10, CONTRACT_MUTATED_Y_LOCAL);
        wait_cpl_tail(32'd1);
        wait_spad_idle();
        expect_spad(CONTRACT_Y0_LOCAL, 32'd4480,
                    "in-flight latched VDOT destination");
        expect_spad(CONTRACT_MUTATED_Y_LOCAL, 32'hbad0_06f0,
                    "in-flight descriptor mutation did not redirect writeback");
        expect_completion(completion_base, 16'h0682, 32'd4480, 32'd1,
                          "in-flight VDOT parameter latch");
        if (compute_vif.launch_sample_count != launch_before + 1 ||
            compute_vif.launch_snapshot_src0[0] !== CONTRACT_SHARED_LOCAL ||
            compute_vif.launch_snapshot_src1[0] !== CONTRACT_B_LOCAL ||
            compute_vif.launch_snapshot_dst[0] !== CONTRACT_Y0_LOCAL)
            `uvm_fatal("CLUSTER_PARAM_LATCH", "launch-time source/destination snapshot was not retained")
        `uvm_info("CLUSTER_PARAMETER_LATCH_PASS",
            "mutating source and destination descriptor words after scalar launch did not alter the in-flight task",
            UVM_LOW)
        clear_contract_queues(32'd1);
    endtask

    task automatic run_cnm_inflight_parameter_latch_test();
        int unsigned word_idx;
        int unsigned poll;
        int unsigned launch_before;
        int unsigned overlap_cycles;
        int unsigned descriptor_write_cycles;
        int signed golden_sum;
        int signed a_value;
        int signed b_value;
        bit cnm_busy_seen;
        bit scalar_busy_seen;
        bit cnm_done_seen;
        bit scalar_done_seen;
        bit [31:0] completion_base;
        completion_base = CLUSTER_CONTRACT_CPLQ + 32'h500;
        overlap_cycles = 0;
        descriptor_write_cycles = 0;
        cnm_busy_seen = 1'b0;
        scalar_busy_seen = 1'b0;
        cnm_done_seen = 1'b0;
        scalar_done_seen = 1'b0;

        // Reuse the already initialized C1 banked GEMV operands. Their four
        // byte lanes have distinct signed values, so this independent Golden
        // covers all four physical banks and all 64 K terms.
        golden_sum = 0;
        for (word_idx = 0; word_idx < 64; word_idx++) begin
            for (int unsigned lane = 0; lane < 4; lane++) begin
                case (lane)
                    0: begin a_value = 2; b_value = 7; end
                    1: begin a_value = 3; b_value = 11; end
                    2: begin a_value = 4; b_value = 13; end
                    default: begin a_value = 5; b_value = 17; end
                endcase
                for (int unsigned byte_idx = 0; byte_idx < 4; byte_idx++)
                    golden_sum += a_value * b_value;
            end
        end
        if (golden_sum != 47104)
            `uvm_fatal("CLUSTER_CNM_PARAM_LATCH", $sformatf(
                "independent CNM banked GEMV Golden expected 47104, calculated %0d",
                golden_sum))

        for (word_idx = 0; word_idx < 16; word_idx++) begin
            spad_write(CNM_LATCH_Y_LOCAL + (word_idx << 2),
                       32'hbad0_6c00 | word_idx);
            spad_write(CNM_LATCH_MUTATED_Y_LOCAL + (word_idx << 2),
                       32'hbad0_6d00 | word_idx);
        end
        spad_write(SCALAR_A_LOCAL, 32'h0403_0201);
        spad_write(SCALAR_B_LOCAL, 32'h0807_0605);
        write_cnm_v3_desc(CLUSTER_CONTRACT_CMDQ, 16'h0688,
                          C1_CNM_A_LOCAL, C1_CNM_B_LOCAL,
                          CNM_LATCH_Y_LOCAL);
        spad_write(CLUSTER_CONTRACT_CMDQ + 32'h18, 32'd64);
        // A second, independent engine performs the descriptor-memory
        // mutation through a legal scheduler-side SPAD write.  The command
        // processor fetches both entries before the scalar result overwrites
        // the CNM destination word, so this avoids an illegal host/compute
        // collision while still exercising an in-flight CNM descriptor.
        write_contract_vdot_desc(CLUSTER_CONTRACT_CMDQ + 32'h40, 16'h0689,
                                 SCALAR_A_LOCAL, SCALAR_B_LOCAL,
                                 CLUSTER_CONTRACT_CMDQ + 32'h10, 16'd1, 8'd0,
                                 32'd0, 32'd0, 32'd0, 32'd0);
        launch_before = compute_vif.launch_sample_count;
        configure_contract_queues(completion_base, 32'd2);
        axil_write(REG_DOORBELL, 32'd1);

        for (poll = 0; poll < 10000; poll++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.engine_busy[2]) cnm_busy_seen = 1'b1;
            if (compute_vif.engine_busy[0]) scalar_busy_seen = 1'b1;
            if (compute_vif.engine_busy[2] && compute_vif.engine_busy[0])
                overlap_cycles++;
            if (compute_vif.engine_busy[2] &&
                compute_vif.engine_req_valid[0] &&
                compute_vif.engine_req_write[0] &&
                compute_vif.engine_req_addr[31:0] ===
                    (CLUSTER_CONTRACT_CMDQ + 32'h10))
                descriptor_write_cycles++;
            if (compute_vif.engine_done[2]) cnm_done_seen = 1'b1;
            if (compute_vif.engine_done[0]) scalar_done_seen = 1'b1;
            if (cnm_done_seen && scalar_done_seen) break;
        end
        if (!cnm_busy_seen || !scalar_busy_seen || !cnm_done_seen ||
            !scalar_done_seen || overlap_cycles == 0 ||
            descriptor_write_cycles == 0)
            `uvm_fatal("CLUSTER_CNM_PARAM_LATCH",
                $sformatf("CNM/scalar legal descriptor mutation did not overlap: busy=%b/%b done=%b/%b overlap=%0d writes=%0d",
                    cnm_busy_seen, scalar_busy_seen, cnm_done_seen,
                    scalar_done_seen, overlap_cycles, descriptor_write_cycles))
        wait_cpl_tail(32'd2);
        wait_spad_idle();
        for (word_idx = 0; word_idx < 16; word_idx++) begin
            expect_spad(CNM_LATCH_Y_LOCAL + (word_idx << 2), golden_sum,
                        $sformatf("in-flight CNM latched Golden[%0d]", word_idx));
            expect_spad(CNM_LATCH_MUTATED_Y_LOCAL + (word_idx << 2),
                        32'hbad0_6d00 | word_idx,
                        $sformatf("in-flight CNM mutation destination sentinel[%0d]", word_idx));
        end
        expect_completion(completion_base, 16'h0688, golden_sum, 32'd16,
                          "in-flight CNM descriptor latch");
        expect_completion(completion_base + 32'h10, 16'h0689, 32'd70, 32'd1,
                          "parallel scalar descriptor mutation");
        expect_spad(CLUSTER_CONTRACT_CMDQ + 32'h10, 32'd70,
                    "parallel engine changed fetched CNM descriptor word");
        if (compute_vif.launch_sample_count != launch_before + 2 ||
            compute_vif.launch_snapshot_opcode[2] !== 8'h21 ||
            compute_vif.launch_snapshot_src0[2] !== C1_CNM_A_LOCAL ||
            compute_vif.launch_snapshot_src1[2] !== C1_CNM_B_LOCAL ||
            compute_vif.launch_snapshot_dst[2] !== CNM_LATCH_Y_LOCAL)
            `uvm_fatal("CLUSTER_CNM_PARAM_LATCH", $sformatf(
                "CNM launch snapshot changed: delta=%0d op=%02h src=%08h/%08h dst=%08h",
                compute_vif.launch_sample_count - launch_before,
                compute_vif.launch_snapshot_opcode[2],
                compute_vif.launch_snapshot_src0[2],
                compute_vif.launch_snapshot_src1[2],
                compute_vif.launch_snapshot_dst[2]))
        `uvm_info("CLUSTER_CNM_PARAMETER_LATCH_PASS", $sformatf(
            "CNM GEMV retained launch parameters while a legal scalar SPAD write changed its fetched descriptor during %0d overlapping cycles; descriptor write overlapped CNM for %0d cycles; 16 outputs match signed 4-bank K=64 Golden=%0d",
            overlap_cycles, descriptor_write_cycles, golden_sum), UVM_LOW)
        clear_contract_queues(32'd2);
    endtask

    task automatic run_matrix_inflight_parameter_latch_test(
        input int signed expected_matrix[0:15][0:31]
    );
        int unsigned word_idx;
        int unsigned poll;
        int unsigned launch_before;
        bit busy_seen;
        bit [31:0] completion_base;
        completion_base = CLUSTER_CONTRACT_CPLQ + 32'h300;

        // The matrix operands and independent 16x32x64 Golden were prepared
        // before the first GEMM in this sequence. Use disjoint destinations so
        // this probe observes only the in-flight descriptor snapshot.
        for (word_idx = 0; word_idx < 512; word_idx++) begin
            spad_write(MATRIX_LATCH_Y_LOCAL + (word_idx << 2),
                       32'hbad0_6a00 | word_idx);
            spad_write(MATRIX_LATCH_MUTATED_Y_LOCAL + (word_idx << 2),
                       32'hbad0_6b00 | word_idx);
        end
        write_v3_desc(CLUSTER_CONTRACT_CMDQ, 8'h30, 16'h0685,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, MATRIX_LATCH_Y_LOCAL,
                      16'd16, 16'd32, 16'd16);
        launch_before = compute_vif.launch_sample_count;
        configure_contract_queues(completion_base, 32'd1);
        axil_write(REG_DOORBELL, 32'd1);

        busy_seen = 1'b0;
        for (poll = 0; poll < 10000; poll++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.engine_busy[3]) begin
                busy_seen = 1'b1;
                break;
            end
        end
        if (!busy_seen)
            `uvm_fatal("CLUSTER_MATRIX_PARAM_LATCH",
                "Matrix task did not become active before descriptor mutation")

        // Replace the backing descriptor with a different, otherwise legal
        // Matrix task while the original long GEMM is active. The accepted
        // task must keep its launch-time source, destination, shape and flags.
        spad_write(CLUSTER_CONTRACT_CMDQ + 32'h04, CONTRACT_B_LOCAL);
        spad_write(CLUSTER_CONTRACT_CMDQ + 32'h08, CONTRACT_SHARED_LOCAL);
        spad_write(CLUSTER_CONTRACT_CMDQ + 32'h10, MATRIX_LATCH_MUTATED_Y_LOCAL);
        spad_write(CLUSTER_CONTRACT_CMDQ + 32'h14, {16'd4, 16'd4});
        spad_write(CLUSTER_CONTRACT_CMDQ + 32'h18, 32'd4);
        spad_write(CLUSTER_CONTRACT_CMDQ + 32'h1c, 32'h0000_0006);

        wait_cpl_tail(32'd1);
        wait_spad_idle();
        for (word_idx = 0; word_idx < 512; word_idx++) begin
            expect_spad(MATRIX_LATCH_Y_LOCAL + (word_idx << 2),
                        expected_matrix[word_idx / 32][word_idx % 32],
                        $sformatf("in-flight Matrix latched Golden[%0d]", word_idx));
            expect_spad(MATRIX_LATCH_MUTATED_Y_LOCAL + (word_idx << 2),
                        32'hbad0_6b00 | word_idx,
                        $sformatf("in-flight Matrix mutation destination sentinel[%0d]", word_idx));
        end
        expect_completion(completion_base, 16'h0685,
                          expected_matrix[15][31], 32'd512,
                          "in-flight Matrix parameter latch");
        if (compute_vif.launch_sample_count != launch_before + 1 ||
            compute_vif.launch_snapshot_src0[3] !== MATRIX_A_LOCAL ||
            compute_vif.launch_snapshot_src1[3] !== MATRIX_B_LOCAL ||
            compute_vif.launch_snapshot_dst[3] !== MATRIX_LATCH_Y_LOCAL ||
            compute_vif.launch_snapshot_m[3] !== 16'd16 ||
            compute_vif.launch_snapshot_n[3] !== 16'd32 ||
            compute_vif.launch_snapshot_k[3] !== 16'd16 ||
            compute_vif.launch_snapshot_flags[3] !== 8'd0)
            `uvm_fatal("CLUSTER_MATRIX_PARAM_LATCH", $sformatf(
                "Matrix launch snapshot changed: count=%0d/%0d src=%08h/%08h dst=%08h shape=%0d/%0d/%0d flags=%02h",
                compute_vif.launch_sample_count, launch_before + 1,
                compute_vif.launch_snapshot_src0[3],
                compute_vif.launch_snapshot_src1[3],
                compute_vif.launch_snapshot_dst[3],
                compute_vif.launch_snapshot_m[3],
                compute_vif.launch_snapshot_n[3],
                compute_vif.launch_snapshot_k[3],
                compute_vif.launch_snapshot_flags[3]))
        `uvm_info("CLUSTER_MATRIX_PARAMETER_LATCH_PASS",
            "mutating Matrix source, destination, shape, and transpose descriptor fields after launch preserved the original 16x32x64 Golden image and completion",
            UVM_LOW)
        clear_contract_queues(32'd1);
    endtask

    task automatic run_sfu_inflight_parameter_latch_test();
        int unsigned poll;
        int unsigned word_idx;
        int unsigned launch_before;
        bit state_seen;
        bit hdl_ok;
        uvm_hdl_data_t state_value;
        bit [31:0] completion_base;
        string state_path;
        completion_base = CLUSTER_CONTRACT_CPLQ + 32'h400;
        state_path = "tb_ai_accel_uvm.dut.compute_cluster_u.tensor_sfu_u.state_r";

        // RMSNorm over [1,2,2,0] with epsilon 1 has an exact integer Golden:
        // floor((1+4+4+0)/4)=2, isqrt(2+1)=1, and the Q30 reciprocal is 1.
        // A different source [4,4,4,4] would instead normalize to [1,1,1,1].
        spad_write(SFU_LATCH_SRC_LOCAL + 32'h00, 32'd1);
        spad_write(SFU_LATCH_SRC_LOCAL + 32'h04, 32'd2);
        spad_write(SFU_LATCH_SRC_LOCAL + 32'h08, 32'd2);
        spad_write(SFU_LATCH_SRC_LOCAL + 32'h0c, 32'd0);
        for (word_idx = 0; word_idx < 4; word_idx++) begin
            spad_write(SFU_LATCH_MUTATED_SRC_LOCAL + (word_idx << 2), 32'd4);
            spad_write(SFU_LATCH_Y_LOCAL + (word_idx << 2), 32'hbad0_6c00 | word_idx);
            spad_write(SFU_LATCH_MUTATED_Y_LOCAL + (word_idx << 2), 32'hbad0_6d00 | word_idx);
        end
        write_v3_desc(CLUSTER_CONTRACT_CMDQ, 8'h33, 16'h0686,
                      SFU_LATCH_SRC_LOCAL, 32'd0, SFU_LATCH_Y_LOCAL,
                      16'd0, 16'd0, 16'd4);
        launch_before = compute_vif.launch_sample_count;
        configure_contract_queues(completion_base, 32'd1);
        axil_write(REG_DOORBELL, 32'd1);

        // State 13 is the iterative RMS mean-square divider wait. The SFU
        // keeps its SPAD request deasserted here, so host writes to the already
        // fetched descriptor do not contend with an outstanding engine read.
        state_seen = 1'b0;
        for (poll = 0; poll < 10000; poll++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.engine_busy[4]) begin
                hdl_ok = uvm_hdl_read(state_path, state_value);
                if (!hdl_ok)
                    `uvm_fatal("CLUSTER_SFU_PARAM_LATCH",
                        $sformatf("failed to read SFU state through %s", state_path))
                if (state_value[5:0] == 6'd13) begin
                    state_seen = 1'b1;
                    break;
                end
            end
        end
        if (!state_seen)
            `uvm_fatal("CLUSTER_SFU_PARAM_LATCH",
                "RMSNorm task did not reach the divider wait before descriptor mutation")

        // Mutate the fetched descriptor to point at a different legal input,
        // destination and one-element length. The accepted four-element task
        // must continue from its launch-time snapshot.
        spad_write(CLUSTER_CONTRACT_CMDQ + 32'h04, SFU_LATCH_MUTATED_SRC_LOCAL);
        spad_write(CLUSTER_CONTRACT_CMDQ + 32'h10, SFU_LATCH_MUTATED_Y_LOCAL);
        spad_write(CLUSTER_CONTRACT_CMDQ + 32'h18, 32'd1);

        wait_cpl_tail(32'd1);
        wait_spad_idle();
        for (word_idx = 0; word_idx < 4; word_idx++) begin
            expect_spad(SFU_LATCH_Y_LOCAL + (word_idx << 2),
                        (word_idx < 3) ? (word_idx == 0 ? 32'd1 : 32'd2) : 32'd0,
                        $sformatf("in-flight SFU RMSNorm latched Golden[%0d]", word_idx));
            expect_spad(SFU_LATCH_MUTATED_Y_LOCAL + (word_idx << 2),
                        32'hbad0_6d00 | word_idx,
                        $sformatf("in-flight SFU mutation destination sentinel[%0d]", word_idx));
        end
        expect_completion(completion_base, 16'h0686, 32'd0, 32'd4,
                          "in-flight SFU RMSNorm parameter latch");
        if (compute_vif.launch_sample_count != launch_before + 1 ||
            compute_vif.launch_snapshot_src0[4] !== SFU_LATCH_SRC_LOCAL ||
            compute_vif.launch_snapshot_src1[4] !== 32'd0 ||
            compute_vif.launch_snapshot_dst[4] !== SFU_LATCH_Y_LOCAL ||
            compute_vif.launch_snapshot_length[4] !== 16'd4)
            `uvm_fatal("CLUSTER_SFU_PARAM_LATCH", $sformatf(
                "SFU launch snapshot changed: count=%0d/%0d src0=%08h src1=%08h dst=%08h length=%0d",
                compute_vif.launch_sample_count, launch_before + 1,
                compute_vif.launch_snapshot_src0[4],
                compute_vif.launch_snapshot_src1[4],
                compute_vif.launch_snapshot_dst[4],
                compute_vif.launch_snapshot_length[4]))
        `uvm_info("CLUSTER_SFU_PARAMETER_LATCH_PASS",
            "real-top RMSNorm retained its four-element source/destination/length snapshot while the backing descriptor was changed during divider wait",
            UVM_LOW)
        clear_contract_queues(32'd1);
    endtask

    task automatic run_shared_readonly_isolation_test();
        int unsigned word_idx;
        int unsigned poll;
        int unsigned launch_before;
        bit overlap_seen;
        bit scalar_shared_read_seen;
        bit sfu_shared_read_seen;
        bit [31:0] addr;
        bit [31:0] completion_base;
        completion_base = CLUSTER_CONTRACT_CPLQ + 32'h200;
        overlap_seen = 1'b0;
        scalar_shared_read_seen = 1'b0;
        sfu_shared_read_seen = 1'b0;

        for (word_idx = 0; word_idx < 64; word_idx++) begin
            spad_write(CONTRACT_SHARED_LOCAL + (word_idx << 2), 32'd0);
            spad_write(CONTRACT_B_LOCAL + (word_idx << 2), 32'h0101_0101);
            spad_write(CONTRACT_SFU_Y_LOCAL + (word_idx << 2), 32'hbad0_0684);
        end
        spad_write(CONTRACT_Y0_LOCAL, 32'hbad0_0683);
        write_contract_vdot_desc(CLUSTER_CONTRACT_CMDQ + 32'h00, 16'h0683,
                                 CONTRACT_SHARED_LOCAL, CONTRACT_B_LOCAL,
                                 CONTRACT_Y0_LOCAL, 16'd64, 8'd0,
                                 32'd0, 32'd0, 32'd0, 32'd0);
        write_v3_desc(CLUSTER_CONTRACT_CMDQ + 32'h40, 8'h35, 16'h0684,
                      CONTRACT_SHARED_LOCAL, 32'd0, CONTRACT_SFU_Y_LOCAL,
                      16'd0, 16'd0, 16'd64);

        launch_before = compute_vif.launch_sample_count;
        configure_contract_queues(completion_base, 32'd2);
        axil_write(REG_DOORBELL, 32'd1);
        for (poll = 0; poll < 50000; poll++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.engine_busy[0] && compute_vif.engine_busy[4])
                overlap_seen = 1'b1;
            for (int engine = 0; engine < 7; engine++) begin
                if (compute_vif.engine_req_valid[engine] &&
                    compute_vif.engine_req_ready[engine] &&
                    !compute_vif.engine_req_write[engine]) begin
                    addr = compute_vif.engine_req_addr[engine*32 +: 32];
                    if (addr >= CONTRACT_SHARED_LOCAL &&
                        addr < CONTRACT_SHARED_LOCAL + 32'h100) begin
                        if (engine == 0) scalar_shared_read_seen = 1'b1;
                        if (engine == 4) sfu_shared_read_seen = 1'b1;
                    end
                end
            end
            if (compute_vif.launch_sample_count >= launch_before + 2 &&
                overlap_seen && !compute_vif.engine_busy[0] &&
                !compute_vif.engine_busy[4])
                break;
        end
        if (!overlap_seen || !scalar_shared_read_seen || !sfu_shared_read_seen)
            `uvm_fatal("CLUSTER_SHARED_READONLY", $sformatf(
                "shared read-only contract incomplete: overlap=%b scalar_read=%b sfu_read=%b launch_delta=%0d",
                overlap_seen, scalar_shared_read_seen, sfu_shared_read_seen,
                compute_vif.launch_sample_count - launch_before))
        wait_cpl_tail(32'd2);
        wait_spad_idle();
        expect_spad(CONTRACT_Y0_LOCAL, 32'd0, "shared read-only scalar Golden");
        for (word_idx = 0; word_idx < 64; word_idx++)
            expect_spad(CONTRACT_SFU_Y_LOCAL + (word_idx << 2), 32'd0,
                        $sformatf("shared read-only SFU Golden[%0d]", word_idx));
        expect_completion(completion_base + 32'h00, 16'h0683,
                          32'd0, 32'd1, "shared read-only scalar completion");
        expect_completion(completion_base + 32'h10, 16'h0684,
                          32'd0, 32'd64, "shared read-only SFU completion");
        if (compute_vif.launch_snapshot_src0[0] !== CONTRACT_SHARED_LOCAL ||
            compute_vif.launch_snapshot_src0[4] !== CONTRACT_SHARED_LOCAL)
            `uvm_fatal("CLUSTER_SHARED_READONLY", "concurrent engines did not sample the same shared read-only source")
        `uvm_info("CLUSTER_SHARED_READONLY_PASS",
            "concurrent Scalar VDOT and SFU GELU read the same immutable SPAD region and produced independent Golden outputs",
            UVM_LOW)
        clear_contract_queues(32'd2);
    endtask

    task automatic run_conv_abort_write_prefix(input int unsigned seed);
        int signed expected_output[0:3];
        bit [31:0] write_addr[0:3];
        bit [31:0] write_data[0:3];
        bit [31:0] desc_base;
        bit [31:0] completion_base;
        bit [31:0] src;
        bit [31:0] weights;
        bit [31:0] dst;
        bit [31:0] sentinel;
        bit [15:0] task_id;
        int unsigned accepted_write_count;
        int unsigned accepted_reads;
        int unsigned returned_reads;
        int unsigned poll;
        int unsigned word_idx;
        bit first_write_seen;
        bit abort_seen;
        bit monitor_done;

        desc_base = CLUSTER_CONTRACT_CMDQ;
        completion_base = 32'h0000_5d00;
        src = 32'h0004_d100;
        weights = 32'h0004_d200;
        dst = 32'h0004_d300;
        sentinel = 32'hbad0_78f0;
        task_id = 16'h0771;
        accepted_write_count = 0;
        accepted_reads = 0;
        returned_reads = 0;
        first_write_seen = 1'b0;
        abort_seen = 1'b0;
        monitor_done = 1'b0;

        expected_output[0] = 54;
        expected_output[1] = 63;
        expected_output[2] = 90;
        expected_output[3] = 99;
        for (word_idx = 0; word_idx < 16; word_idx++) begin
            spad_write(src + (word_idx << 2), word_idx + 1);
            if (word_idx < 4)
                spad_write(dst + (word_idx << 2), sentinel ^ word_idx);
        end
        for (word_idx = 0; word_idx < 9; word_idx++)
            spad_write(weights + (word_idx << 2), 32'd1);
        for (word_idx = 0; word_idx < 4; word_idx++)
            spad_write(completion_base + (word_idx << 2), 32'h7810_0000 | word_idx);

        // 4x4 input, 3x3 unit kernel, stride-one valid output => four ordered
        // INT32 results. Abort after the first accepted result must retain a
        // legal one-to-three-word prefix and preserve every later sentinel.
        write_cluster_desc(desc_base, 8'h16, task_id, src, weights, dst,
                           16'd4, 16'd4, 16'd9, 32'd0,
                           32'd0, 32'd0, 32'd0, 8'd5);
        configure_contract_queues(completion_base, 32'd1);
        axil_write(REG_DOORBELL, 32'd1);

        fork
            begin : conv_abort_prefix_monitor
                while (!monitor_done) begin
                    @(posedge compute_vif.aclk);
                    if (compute_vif.dut_abort_active)
                        abort_seen = 1'b1;
                    if (compute_vif.engine_req_valid[5] &&
                        compute_vif.engine_req_ready[5]) begin
                        if (compute_vif.engine_req_write[5]) begin
                            if (accepted_write_count >= 4)
                                `uvm_fatal("CLUSTER_CONV_ABORT_PREFIX",
                                    "Conv accepted more output writes than its 4x4 valid descriptor")
                            write_addr[accepted_write_count] =
                                compute_vif.engine_req_addr[5*32 +: 32];
                            write_data[accepted_write_count] =
                                compute_vif.engine_req_wdata[5*32 +: 32];
                            accepted_write_count++;
                            first_write_seen = 1'b1;
                        end else begin
                            accepted_reads++;
                        end
                    end
                    if (compute_vif.rsp_valid &&
                        (compute_vif.rsp_client == 3'd2))
                        returned_reads++;
                end
            end
            begin : abort_after_first_conv_write
                poll = 0;
                while (!first_write_seen && poll < 50000) begin
                    @(posedge compute_vif.aclk);
                    poll++;
                end
                if (!first_write_seen)
                    `uvm_fatal("CLUSTER_CONV_ABORT_PREFIX",
                        "Conv did not accept an output write before the Abort timeout")
                axil_write(REG_ABORT, 32'd1);
                wait_cpl_tail(32'd1);
                monitor_done = 1'b1;
            end
        join

        wait_spad_idle();
        if (!abort_seen)
            `uvm_fatal("CLUSTER_CONV_ABORT_PREFIX",
                "software Abort was not observed while Conv output was active")
        if (accepted_write_count == 0 || accepted_write_count >= 4)
            `uvm_fatal("CLUSTER_CONV_ABORT_PREFIX", $sformatf(
                "Abort did not cut a non-empty proper output prefix: writes=%0d",
                accepted_write_count))
        if (accepted_reads == 0 || returned_reads != accepted_reads)
            `uvm_fatal("CLUSTER_CONV_ABORT_PREFIX", $sformatf(
                "Conv read responses did not drain: accepted=%0d returned=%0d",
                accepted_reads, returned_reads))

        expect_spad(completion_base + 32'h00, {16'd0, task_id},
                    "Conv accepted-write Abort task ID");
        expect_spad(completion_base + 32'h04, 32'h0000_0032,
                    "Conv accepted-write Abort status/code");
        for (word_idx = 0; word_idx < accepted_write_count; word_idx++) begin
            if (write_addr[word_idx] !== dst + (word_idx << 2))
                `uvm_fatal("CLUSTER_CONV_ABORT_PREFIX", $sformatf(
                    "non-prefix output address index=%0d expected=0x%08h actual=0x%08h",
                    word_idx, dst + (word_idx << 2), write_addr[word_idx]))
            if (write_data[word_idx] !== expected_output[word_idx])
                `uvm_fatal("CLUSTER_CONV_ABORT_PREFIX", $sformatf(
                    "Golden mismatch in accepted prefix index=%0d expected=%0d actual=%0d",
                    word_idx, expected_output[word_idx], $signed(write_data[word_idx])))
            expect_spad(dst + (word_idx << 2), expected_output[word_idx],
                        $sformatf("Conv accepted Abort prefix Golden[%0d]", word_idx));
        end
        for (word_idx = accepted_write_count; word_idx < 4; word_idx++)
            expect_spad(dst + (word_idx << 2), sentinel ^ word_idx,
                        $sformatf("Conv Abort preserved unaccepted suffix[%0d]", word_idx));

        `uvm_info("CLUSTER_CONV_ABORT_WRITE_PREFIX_PASS", $sformatf(
            "task_id=%04h accepted_output_prefix=%0d/4 read_drain=%0d/%0d completion=ERR_ABORT seed=%0d",
            task_id, accepted_write_count, accepted_reads, returned_reads, seed), UVM_LOW)
        axil_write(REG_CPLQ_HEAD, 32'd1);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
    endtask

    task automatic run_kv_abort_write_prefix(input int unsigned seed);
        bit [31:0] expected_output[0:7];
        bit [31:0] write_addr[0:7];
        bit [31:0] write_data[0:7];
        bit [31:0] desc_base;
        bit [31:0] completion_base;
        bit [31:0] src;
        bit [31:0] dst;
        bit [31:0] cache_offset;
        bit [31:0] sentinel;
        bit [31:0] source_word;
        bit [15:0] task_id;
        int unsigned accepted_write_count;
        int unsigned accepted_reads;
        int unsigned returned_reads;
        int unsigned poll;
        int unsigned word_idx;
        bit first_write_seen;
        bit abort_seen;
        bit monitor_done;

        desc_base = CLUSTER_CONTRACT_CMDQ;
        completion_base = 32'h0000_5e00;
        src = 32'h0004_d500;
        dst = 32'h0004_d600;
        // aux0={head=1,token=2}, token stride=16 B, head stride=64 B.
        cache_offset = (32'd2 * 32'd16) + (32'd1 * 32'd64);
        sentinel = 32'hbad0_7a00;
        task_id = 16'h0775;
        accepted_write_count = 0;
        accepted_reads = 0;
        returned_reads = 0;
        first_write_seen = 1'b0;
        abort_seen = 1'b0;
        monitor_done = 1'b0;

        // KV_WRITE copies eight signed payload words to one head/token cache
        // slice. Guard words immediately before and after the slice detect an
        // address-offset or overrun error independently of the accepted prefix.
        for (word_idx = 0; word_idx < 8; word_idx++) begin
            source_word = 32'h5a00_0000 ^ (word_idx * 32'h0101_0101);
            expected_output[word_idx] = source_word;
            spad_write(src + (word_idx << 2), source_word);
        end
        for (word_idx = 0; word_idx < 10; word_idx++)
            spad_write(dst + cache_offset - 32'd4 + (word_idx << 2),
                       sentinel ^ word_idx);
        for (word_idx = 0; word_idx < 4; word_idx++)
            spad_write(completion_base + (word_idx << 2),
                       32'h7a50_0000 | word_idx);

        write_cluster_desc(desc_base, 8'h43, task_id, src, 32'd0, dst,
                           16'd0, 16'd0, 16'd8, {16'd1,16'd2},
                           32'd16, 32'd64, 32'd0, 8'd5);
        configure_contract_queues(completion_base, 32'd1);
        axil_write(REG_DOORBELL, 32'd1);

        fork
            begin : kv_abort_prefix_monitor
                while (!monitor_done) begin
                    @(posedge compute_vif.aclk);
                    if (compute_vif.dut_abort_active)
                        abort_seen = 1'b1;
                    if (compute_vif.engine_req_valid[6] &&
                        compute_vif.engine_req_ready[6]) begin
                        if (compute_vif.engine_req_write[6]) begin
                            if (accepted_write_count >= 8)
                                `uvm_fatal("CLUSTER_KV_ABORT_PREFIX",
                                    "KV accepted more cache writes than its 8-word descriptor")
                            write_addr[accepted_write_count] =
                                compute_vif.engine_req_addr[6*32 +: 32];
                            write_data[accepted_write_count] =
                                compute_vif.engine_req_wdata[6*32 +: 32];
                            accepted_write_count++;
                            first_write_seen = 1'b1;
                        end else begin
                            accepted_reads++;
                        end
                    end
                    if (compute_vif.rsp_valid &&
                        (compute_vif.rsp_client == 3'd2))
                        returned_reads++;
                end
            end
            begin : abort_after_first_kv_write
                poll = 0;
                while (!first_write_seen && poll < 50000) begin
                    @(posedge compute_vif.aclk);
                    poll++;
                end
                if (!first_write_seen)
                    `uvm_fatal("CLUSTER_KV_ABORT_PREFIX",
                        "KV did not accept a cache write before the Abort timeout")
                axil_write(REG_ABORT, 32'd1);
                wait_cpl_tail(32'd1);
                monitor_done = 1'b1;
            end
        join

        wait_spad_idle();
        if (!abort_seen)
            `uvm_fatal("CLUSTER_KV_ABORT_PREFIX",
                "software Abort was not observed while KV cache write was active")
        if (accepted_write_count == 0 || accepted_write_count >= 8)
            `uvm_fatal("CLUSTER_KV_ABORT_PREFIX", $sformatf(
                "Abort did not cut a non-empty proper KV output prefix: writes=%0d",
                accepted_write_count))
        if (accepted_reads == 0 || returned_reads != accepted_reads)
            `uvm_fatal("CLUSTER_KV_ABORT_PREFIX", $sformatf(
                "KV read responses did not drain: accepted=%0d returned=%0d",
                accepted_reads, returned_reads))

        expect_spad(completion_base + 32'h00, {16'd0, task_id},
                    "KV accepted-write Abort task ID");
        expect_spad(completion_base + 32'h04, 32'h0000_0032,
                    "KV accepted-write Abort status/code");
        expect_spad(dst + cache_offset - 32'd4, sentinel,
                    "KV Abort preserved pre-slice guard");
        for (word_idx = 0; word_idx < accepted_write_count; word_idx++) begin
            if (write_addr[word_idx] !== dst + cache_offset + (word_idx << 2))
                `uvm_fatal("CLUSTER_KV_ABORT_PREFIX", $sformatf(
                    "non-prefix KV cache address index=%0d expected=0x%08h actual=0x%08h",
                    word_idx, dst + cache_offset + (word_idx << 2), write_addr[word_idx]))
            if (write_data[word_idx] !== expected_output[word_idx])
                `uvm_fatal("CLUSTER_KV_ABORT_PREFIX", $sformatf(
                    "Golden mismatch in accepted KV prefix index=%0d expected=0x%08h actual=0x%08h",
                    word_idx, expected_output[word_idx], write_data[word_idx]))
            expect_spad(dst + cache_offset + (word_idx << 2), expected_output[word_idx],
                        $sformatf("KV accepted Abort prefix Golden[%0d]", word_idx));
        end
        for (word_idx = accepted_write_count; word_idx < 8; word_idx++)
            expect_spad(dst + cache_offset + (word_idx << 2), sentinel ^ (word_idx + 1),
                        $sformatf("KV Abort preserved unaccepted suffix[%0d]", word_idx));
        expect_spad(dst + cache_offset + 32'd32, sentinel ^ 9,
                    "KV Abort preserved post-slice guard");

        `uvm_info("CLUSTER_KV_ABORT_WRITE_PREFIX_PASS", $sformatf(
            "task_id=%04h accepted_output_prefix=%0d/8 read_drain=%0d/%0d head=1 token=2 cache_offset=%0d completion=ERR_ABORT seed=%0d",
            task_id, accepted_write_count, accepted_reads, returned_reads,
            cache_offset, seed), UVM_LOW)
        axil_write(REG_CPLQ_HEAD, 32'd1);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
    endtask

    task automatic run_matrix_abort_write_prefix(input int unsigned seed);
        int signed input_a[0:3][0:15];
        int signed input_b[0:15][0:3];
        int signed expected_output[0:3][0:3];
        bit [31:0] write_addr[0:15];
        bit [31:0] write_data[0:15];
        bit [31:0] desc_base;
        bit [31:0] completion_base;
        bit [31:0] src_a;
        bit [31:0] src_b;
        bit [31:0] dst;
        bit [31:0] sentinel;
        bit [31:0] packed_word;
        bit [15:0] task_id;
        int unsigned accepted_write_count;
        int unsigned accepted_reads;
        int unsigned returned_reads;
        int unsigned poll;
        int unsigned row_idx;
        int unsigned col_idx;
        int unsigned k_idx;
        int unsigned k_word;
        int unsigned lane;
        bit first_write_seen;
        bit abort_seen;
        bit monitor_done;
        bit line_seen;

        desc_base = CLUSTER_CONTRACT_CMDQ;
        completion_base = 32'h0000_5e00;
        src_a = 32'h0004_d400;
        src_b = 32'h0004_d800;
        // Four-byte aligned but not 16-byte aligned: SPEC v1.5 requires the
        // Matrix 4-word output chunks to use ordered scalar writes.
        dst = 32'h0004_dc04;
        sentinel = 32'hbad0_7900;
        task_id = 16'h0772;
        accepted_write_count = 0;
        accepted_reads = 0;
        returned_reads = 0;
        first_write_seen = 1'b0;
        abort_seen = 1'b0;
        monitor_done = 1'b0;
        line_seen = 1'b0;

        // A 4x4 output tile with K=16 INT8 elements (four packed K words).
        // Use bounded signed values and calculate the full independent Golden
        // before launching the real Matrix engine.
        for (row_idx = 0; row_idx < 4; row_idx++) begin
            for (k_idx = 0; k_idx < 16; k_idx++)
                input_a[row_idx][k_idx] = int'(row_idx) + int'(k_idx % 5) - 2;
        end
        for (k_idx = 0; k_idx < 16; k_idx++) begin
            for (col_idx = 0; col_idx < 4; col_idx++)
                input_b[k_idx][col_idx] = int'(col_idx) - int'(k_idx % 3) + 1;
        end
        for (row_idx = 0; row_idx < 4; row_idx++) begin
            for (col_idx = 0; col_idx < 4; col_idx++) begin
                expected_output[row_idx][col_idx] = 0;
                for (k_idx = 0; k_idx < 16; k_idx++)
                    expected_output[row_idx][col_idx] +=
                        input_a[row_idx][k_idx] * input_b[k_idx][col_idx];
            end
        end

        for (k_word = 0; k_word < 4; k_word++) begin
            for (row_idx = 0; row_idx < 4; row_idx++) begin
                packed_word = '0;
                for (lane = 0; lane < 4; lane++)
                    packed_word[lane*8 +: 8] = input_a[row_idx][k_word*4 + lane];
                spad_write(src_a + (k_word << 4) + (row_idx << 2), packed_word);
            end
            for (col_idx = 0; col_idx < 4; col_idx++) begin
                packed_word = '0;
                for (lane = 0; lane < 4; lane++)
                    packed_word[lane*8 +: 8] = input_b[k_word*4 + lane][col_idx];
                spad_write(src_b + (k_word << 4) + (col_idx << 2), packed_word);
            end
        end
        for (row_idx = 0; row_idx < 4; row_idx++)
            for (col_idx = 0; col_idx < 4; col_idx++)
                spad_write(dst + ((row_idx * 4 + col_idx) << 2), sentinel ^ (row_idx * 4 + col_idx));
        for (row_idx = 0; row_idx < 4; row_idx++)
            spad_write(completion_base + (row_idx << 2), 32'h7720_0000 | row_idx);

        write_v3_desc(desc_base, 8'h30, task_id, src_a, src_b, dst,
                      16'd4, 16'd4, 16'd4);
        configure_contract_queues(completion_base, 32'd1);
        axil_write(REG_DOORBELL, 32'd1);

        fork
            begin : matrix_abort_prefix_monitor
                while (!monitor_done) begin
                    @(posedge compute_vif.aclk);
                    if (compute_vif.dut_abort_active)
                        abort_seen = 1'b1;
                    if (compute_vif.matrix_line_valid)
                        line_seen = 1'b1;
                    if (compute_vif.matrix_request_valid && compute_vif.banked_ready)
                        accepted_reads++;
                    if (compute_vif.rsp_valid && (compute_vif.rsp_client == 3'd3))
                        returned_reads++;
                    if (compute_vif.engine_req_valid[3] &&
                        compute_vif.engine_req_ready[3] &&
                        compute_vif.engine_req_write[3]) begin
                        if (accepted_write_count >= 16)
                            `uvm_fatal("CLUSTER_MATRIX_ABORT_PREFIX",
                                "Matrix accepted more output writes than its 4x4 descriptor")
                        write_addr[accepted_write_count] =
                            compute_vif.engine_req_addr[3*32 +: 32];
                        write_data[accepted_write_count] =
                            compute_vif.engine_req_wdata[3*32 +: 32];
                        accepted_write_count++;
                        first_write_seen = 1'b1;
                    end
                end
            end
            begin : abort_after_first_matrix_write
                poll = 0;
                while (!first_write_seen && poll < 100000) begin
                    @(posedge compute_vif.aclk);
                    poll++;
                end
                if (!first_write_seen)
                    `uvm_fatal("CLUSTER_MATRIX_ABORT_PREFIX",
                        "Matrix did not accept a scalar output write before Abort timeout")
                axil_write(REG_ABORT, 32'd1);
                wait_cpl_tail(32'd1);
                monitor_done = 1'b1;
            end
        join

        wait_spad_idle();
        if (!abort_seen)
            `uvm_fatal("CLUSTER_MATRIX_ABORT_PREFIX",
                "software Abort was not observed while Matrix output was active")
        if (line_seen)
            `uvm_fatal("CLUSTER_MATRIX_ABORT_PREFIX",
                "4-byte-aligned non-16-byte Matrix destination incorrectly used the Line port")
        if (accepted_write_count == 0 || accepted_write_count >= 16)
            `uvm_fatal("CLUSTER_MATRIX_ABORT_PREFIX", $sformatf(
                "Abort did not cut a non-empty proper Matrix output prefix: writes=%0d",
                accepted_write_count))
        if (accepted_reads == 0 || returned_reads != accepted_reads)
            `uvm_fatal("CLUSTER_MATRIX_ABORT_PREFIX", $sformatf(
                "Matrix accepted reads did not drain: accepted=%0d returned=%0d",
                accepted_reads, returned_reads))

        expect_spad(completion_base + 32'h00, {16'd0, task_id},
                    "Matrix accepted-write Abort task ID");
        expect_spad(completion_base + 32'h04, 32'h0000_0032,
                    "Matrix accepted-write Abort status/code");
        for (row_idx = 0; row_idx < 4; row_idx++) begin
            for (col_idx = 0; col_idx < 4; col_idx++) begin
                k_idx = row_idx * 4 + col_idx;
                if (k_idx < accepted_write_count) begin
                    if (write_addr[k_idx] !== dst + (k_idx << 2))
                        `uvm_fatal("CLUSTER_MATRIX_ABORT_PREFIX", $sformatf(
                            "non-prefix output address index=%0d expected=0x%08h actual=0x%08h",
                            k_idx, dst + (k_idx << 2), write_addr[k_idx]))
                    if (write_data[k_idx] !== expected_output[row_idx][col_idx])
                        `uvm_fatal("CLUSTER_MATRIX_ABORT_PREFIX", $sformatf(
                            "Golden mismatch in accepted prefix index=%0d expected=%0d actual=%0d",
                            k_idx, expected_output[row_idx][col_idx], $signed(write_data[k_idx])))
                    expect_spad(dst + (k_idx << 2), expected_output[row_idx][col_idx],
                                $sformatf("Matrix accepted Abort Golden[%0d,%0d]", row_idx, col_idx));
                end else begin
                    expect_spad(dst + (k_idx << 2), sentinel ^ k_idx,
                                $sformatf("Matrix Abort preserved suffix[%0d,%0d]", row_idx, col_idx));
                end
            end
        end

        `uvm_info("CLUSTER_MATRIX_ABORT_WRITE_PREFIX_PASS", $sformatf(
            "task_id=%04h accepted_output_prefix=%0d/16 read_drain=%0d/%0d line_fallback=1 completion=ERR_ABORT seed=%0d",
            task_id, accepted_write_count, accepted_reads, returned_reads, seed), UVM_LOW)
        axil_write(REG_CPLQ_HEAD, 32'd1);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
    endtask

    task automatic run_matrix_line_abort_write_prefix(input int unsigned seed);
        int signed input_a[0:3][0:3];
        int signed input_b[0:3][0:15];
        int signed expected_output[0:3][0:15];
        bit [31:0] line_addr[0:15];
        bit [127:0] line_data[0:15];
        bit [15:0] line_wstrb[0:15];
        bit [31:0] desc_base;
        bit [31:0] completion_base;
        bit [31:0] src_a;
        bit [31:0] src_b;
        bit [31:0] dst;
        bit [31:0] sentinel;
        bit [31:0] packed_word;
        bit [15:0] task_id;
        int unsigned accepted_line_count;
        int unsigned accepted_reads;
        int unsigned returned_reads;
        int unsigned poll;
        int unsigned row_idx;
        int unsigned col_idx;
        int unsigned k_idx;
        int unsigned lane;
        int unsigned output_idx;
        bit first_line_seen;
        bit abort_seen;
        bit monitor_done;

        desc_base = CLUSTER_CONTRACT_CMDQ;
        completion_base = 32'h0000_5f00;
        src_a = 32'h0004_e000;
        src_b = 32'h0004_e400;
        dst = 32'h0004_e800;
        sentinel = 32'hbad0_7a00;
        task_id = 16'h0773;
        accepted_line_count = 0;
        accepted_reads = 0;
        returned_reads = 0;
        first_line_seen = 1'b0;
        abort_seen = 1'b0;
        monitor_done = 1'b0;

        // M=4, N=16 and one packed K word produce sixteen aligned 128-bit
        // output Line writes. Keep values small enough for an independent
        // signed Golden and preserve a long sentinel suffix after Abort.
        for (row_idx = 0; row_idx < 4; row_idx++) begin
            for (k_idx = 0; k_idx < 4; k_idx++)
                input_a[row_idx][k_idx] = int'(row_idx) + int'(k_idx) - 1;
        end
        for (k_idx = 0; k_idx < 4; k_idx++) begin
            for (col_idx = 0; col_idx < 16; col_idx++)
                input_b[k_idx][col_idx] = int'(col_idx % 7) - int'(k_idx) + 1;
        end
        for (row_idx = 0; row_idx < 4; row_idx++) begin
            for (col_idx = 0; col_idx < 16; col_idx++) begin
                expected_output[row_idx][col_idx] = 0;
                for (k_idx = 0; k_idx < 4; k_idx++)
                    expected_output[row_idx][col_idx] +=
                        input_a[row_idx][k_idx] * input_b[k_idx][col_idx];
            end
        end

        for (row_idx = 0; row_idx < 4; row_idx++) begin
            packed_word = '0;
            for (lane = 0; lane < 4; lane++)
                packed_word[lane*8 +: 8] = input_a[row_idx][lane];
            spad_write(src_a + (row_idx << 2), packed_word);
        end
        for (col_idx = 0; col_idx < 16; col_idx++) begin
            packed_word = '0;
            for (lane = 0; lane < 4; lane++)
                packed_word[lane*8 +: 8] = input_b[lane][col_idx];
            spad_write(src_b + (col_idx << 2), packed_word);
        end
        for (output_idx = 0; output_idx < 64; output_idx++)
            spad_write(dst + (output_idx << 2), sentinel ^ output_idx);
        for (row_idx = 0; row_idx < 4; row_idx++)
            spad_write(completion_base + (row_idx << 2), 32'h7730_0000 | row_idx);

        write_v3_desc(desc_base, 8'h30, task_id, src_a, src_b, dst,
                      16'd4, 16'd16, 16'd1);
        configure_contract_queues(completion_base, 32'd1);
        axil_write(REG_DOORBELL, 32'd1);

        fork
            begin : matrix_line_abort_prefix_monitor
                while (!monitor_done) begin
                    @(posedge compute_vif.aclk);
                    if (compute_vif.dut_abort_active)
                        abort_seen = 1'b1;
                    if (compute_vif.matrix_line_valid &&
                        compute_vif.matrix_line_ready &&
                        compute_vif.matrix_line_write) begin
                        if (accepted_line_count >= 16)
                            `uvm_fatal("CLUSTER_MATRIX_LINE_ABORT_PREFIX",
                                "Matrix accepted more Line writes than the 4x16 descriptor")
                        line_addr[accepted_line_count] = compute_vif.matrix_line_addr;
                        line_data[accepted_line_count] = compute_vif.matrix_line_wdata;
                        line_wstrb[accepted_line_count] = compute_vif.matrix_line_wstrb;
                        accepted_line_count++;
                        first_line_seen = 1'b1;
                    end
                    if (compute_vif.matrix_request_valid && compute_vif.banked_ready)
                        accepted_reads++;
                    if (compute_vif.rsp_valid && (compute_vif.rsp_client == 3'd3))
                        returned_reads++;
                end
            end
            begin : abort_after_first_matrix_line
                poll = 0;
                while (!first_line_seen && poll < 100000) begin
                    @(posedge compute_vif.aclk);
                    poll++;
                end
                if (!first_line_seen)
                    `uvm_fatal("CLUSTER_MATRIX_LINE_ABORT_PREFIX",
                        "Matrix did not accept an aligned Line output before Abort timeout")
                axil_write(REG_ABORT, 32'd1);
                wait_cpl_tail(32'd1);
                monitor_done = 1'b1;
            end
        join

        wait_spad_idle();
        if (!abort_seen)
            `uvm_fatal("CLUSTER_MATRIX_LINE_ABORT_PREFIX",
                "software Abort was not observed while Matrix Line output was active")
        if (accepted_line_count == 0 || accepted_line_count >= 16)
            `uvm_fatal("CLUSTER_MATRIX_LINE_ABORT_PREFIX", $sformatf(
                "Abort did not leave a non-empty proper Line prefix: lines=%0d",
                accepted_line_count))
        if (accepted_reads == 0 || returned_reads != accepted_reads)
            `uvm_fatal("CLUSTER_MATRIX_LINE_ABORT_PREFIX", $sformatf(
                "Matrix accepted reads did not drain: accepted=%0d returned=%0d",
                accepted_reads, returned_reads))

        expect_spad(completion_base + 32'h00, {16'd0, task_id},
                    "Matrix Line accepted-write Abort task ID");
        expect_spad(completion_base + 32'h04, 32'h0000_0032,
                    "Matrix Line accepted-write Abort status/code");
        for (output_idx = 0; output_idx < 64; output_idx++) begin
            row_idx = output_idx / 16;
            col_idx = output_idx % 16;
            if ((row_idx * 4 + (col_idx / 4)) < accepted_line_count)
                expect_spad(dst + (output_idx << 2), expected_output[row_idx][col_idx],
                    $sformatf("Matrix Line Abort Golden prefix[%0d,%0d]", row_idx, col_idx));
            else
                expect_spad(dst + (output_idx << 2), sentinel ^ output_idx,
                    $sformatf("Matrix Line Abort preserved suffix[%0d,%0d]", row_idx, col_idx));
        end
        for (output_idx = 0; output_idx < accepted_line_count; output_idx++) begin
            row_idx = output_idx / 4;
            col_idx = (output_idx % 4) * 4;
            if (line_addr[output_idx] !== dst + (row_idx * 64) + (col_idx << 2))
                `uvm_fatal("CLUSTER_MATRIX_LINE_ABORT_PREFIX", $sformatf(
                    "non-prefix Line address index=%0d expected=0x%08h actual=0x%08h",
                    output_idx, dst + (row_idx * 64) + (col_idx << 2),
                    line_addr[output_idx]))
            if (line_wstrb[output_idx] !== 16'hffff)
                `uvm_fatal("CLUSTER_MATRIX_LINE_ABORT_PREFIX", $sformatf(
                    "aligned Matrix Line WSTRB index=%0d expected=ffff actual=%04h",
                    output_idx, line_wstrb[output_idx]))
            for (lane = 0; lane < 4; lane++) begin
                if (line_data[output_idx][lane*32 +: 32] !==
                    expected_output[row_idx][col_idx + lane])
                    `uvm_fatal("CLUSTER_MATRIX_LINE_ABORT_PREFIX", $sformatf(
                        "Line Golden mismatch line=%0d lane=%0d expected=%0d actual=%0d",
                        output_idx, lane, expected_output[row_idx][col_idx + lane],
                        $signed(line_data[output_idx][lane*32 +: 32])))
            end
        end

        `uvm_info("CLUSTER_MATRIX_LINE_ABORT_WRITE_PREFIX_PASS", $sformatf(
            "task_id=%04h accepted_line_prefix=%0d/16 accepted_output_words=%0d/64 read_drain=%0d/%0d wstrb=ffff completion=ERR_ABORT seed=%0d",
            task_id, accepted_line_count, accepted_line_count * 4,
            accepted_reads, returned_reads, seed), UVM_LOW)
        axil_write(REG_CPLQ_HEAD, 32'd1);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
    endtask

    task automatic run_cnm_abort_write_prefix(input int unsigned seed);
        int signed a_elem[0:3][0:3][0:3];
        int signed b_elem[0:15][0:3][0:3][0:3];
        int signed expected_output[0:15];
        bit [31:0] write_addr[0:15];
        bit [31:0] write_data[0:15];
        bit [31:0] desc_base;
        bit [31:0] completion_base;
        bit [31:0] src_a;
        bit [31:0] src_b;
        bit [31:0] dst;
        bit [31:0] sentinel;
        bit [31:0] packed_word;
        bit [15:0] task_id;
        int unsigned accepted_write_count;
        int unsigned accepted_reads;
        int unsigned returned_reads;
        int unsigned poll;
        int unsigned row_idx;
        int unsigned k_idx;
        int unsigned lane;
        int unsigned byte_idx;
        int signed value_a;
        int signed value_b;
        bit first_write_seen;
        bit abort_seen;
        bit monitor_done;

        desc_base = CLUSTER_CONTRACT_CMDQ;
        completion_base = 32'h0000_5e80;
        src_a = 32'h0004_e000;
        src_b = 32'h0004_e100;
        dst = 32'h0004_e800;
        sentinel = 32'hbad0_7a00;
        task_id = 16'h0774;
        accepted_write_count = 0;
        accepted_reads = 0;
        returned_reads = 0;
        first_write_seen = 1'b0;
        abort_seen = 1'b0;
        monitor_done = 1'b0;

        // A legal 16-output GEMV with K=4 words.  The four independent
        // bank lanes each consume one packed INT8 word per K step.  Keep the
        // operation long enough that software Abort cuts a real output prefix.
        for (k_idx = 0; k_idx < 4; k_idx++) begin
            for (lane = 0; lane < 4; lane++) begin
                packed_word = '0;
                for (byte_idx = 0; byte_idx < 4; byte_idx++) begin
                    a_elem[k_idx][lane][byte_idx] =
                        int'((k_idx + lane + byte_idx) % 5) - 2;
                    packed_word[byte_idx*8 +: 8] = a_elem[k_idx][lane][byte_idx];
                end
                spad_write(src_a + (k_idx << 4) + (lane << 2), packed_word);
            end
        end
        for (row_idx = 0; row_idx < 16; row_idx++) begin
            expected_output[row_idx] = 0;
            for (k_idx = 0; k_idx < 4; k_idx++) begin
                for (lane = 0; lane < 4; lane++) begin
                    packed_word = '0;
                    for (byte_idx = 0; byte_idx < 4; byte_idx++) begin
                        b_elem[row_idx][k_idx][lane][byte_idx] =
                            int'((row_idx + k_idx + lane + byte_idx) % 7) - 3;
                        packed_word[byte_idx*8 +: 8] =
                            b_elem[row_idx][k_idx][lane][byte_idx];
                        expected_output[row_idx] +=
                            a_elem[k_idx][lane][byte_idx] *
                            b_elem[row_idx][k_idx][lane][byte_idx];
                    end
                    spad_write(src_b + (row_idx * 64) + (k_idx << 4) +
                               (lane << 2), packed_word);
                end
            end
            spad_write(dst + (row_idx << 2), sentinel ^ row_idx);
        end
        for (row_idx = 0; row_idx < 4; row_idx++)
            spad_write(completion_base + (row_idx << 2),
                       32'h7740_0000 | row_idx);

        write_cnm_v3_desc(desc_base, task_id, src_a, src_b, dst);
        spad_write(desc_base + 32'h18, 32'd4);
        configure_contract_queues(completion_base, 32'd1);
        axil_write(REG_DOORBELL, 32'd1);

        fork
            begin : cnm_abort_prefix_monitor
                while (!monitor_done) begin
                    @(posedge compute_vif.aclk);
                    if (compute_vif.dut_abort_active)
                        abort_seen = 1'b1;
                    accepted_reads += $countones(compute_vif.cnm_accept_mask);
                    returned_reads += $countones(compute_vif.cnm_rsp_valid);
                    if (compute_vif.engine_req_valid[2] &&
                        compute_vif.engine_req_ready[2] &&
                        compute_vif.engine_req_write[2]) begin
                        if (accepted_write_count >= 16)
                            `uvm_fatal("CLUSTER_CNM_ABORT_PREFIX",
                                "CNM accepted more output writes than its 16-row descriptor")
                        write_addr[accepted_write_count] =
                            compute_vif.engine_req_addr[2*32 +: 32];
                        write_data[accepted_write_count] =
                            compute_vif.engine_req_wdata[2*32 +: 32];
                        accepted_write_count++;
                        first_write_seen = 1'b1;
                    end
                end
            end
            begin : abort_after_first_cnm_write
                poll = 0;
                while (!first_write_seen && poll < 100000) begin
                    @(posedge compute_vif.aclk);
                    poll++;
                end
                if (!first_write_seen)
                    `uvm_fatal("CLUSTER_CNM_ABORT_PREFIX",
                        "CNM did not accept an output write before the Abort timeout")
                axil_write(REG_ABORT, 32'd1);
                wait_cpl_tail(32'd1);
                monitor_done = 1'b1;
            end
        join

        wait_spad_idle();
        if (!abort_seen)
            `uvm_fatal("CLUSTER_CNM_ABORT_PREFIX",
                "software Abort was not observed while CNM output was active")
        if (accepted_write_count == 0 || accepted_write_count >= 16)
            `uvm_fatal("CLUSTER_CNM_ABORT_PREFIX", $sformatf(
                "Abort did not cut a non-empty proper CNM output prefix: writes=%0d",
                accepted_write_count))
        if (accepted_reads == 0 || returned_reads != accepted_reads)
            `uvm_fatal("CLUSTER_CNM_ABORT_PREFIX", $sformatf(
                "CNM read responses did not drain: accepted=%0d returned=%0d",
                accepted_reads, returned_reads))

        expect_spad(completion_base + 32'h00, {16'd0, task_id},
                    "CNM accepted-write Abort task ID");
        expect_spad(completion_base + 32'h04, 32'h0000_0032,
                    "CNM accepted-write Abort status/code");
        for (row_idx = 0; row_idx < accepted_write_count; row_idx++) begin
            if (write_addr[row_idx] !== dst + (row_idx << 2))
                `uvm_fatal("CLUSTER_CNM_ABORT_PREFIX", $sformatf(
                    "non-prefix output address index=%0d expected=0x%08h actual=0x%08h",
                    row_idx, dst + (row_idx << 2), write_addr[row_idx]))
            if (write_data[row_idx] !== expected_output[row_idx])
                `uvm_fatal("CLUSTER_CNM_ABORT_PREFIX", $sformatf(
                    "Golden mismatch in accepted prefix index=%0d expected=%0d actual=%0d",
                    row_idx, expected_output[row_idx], $signed(write_data[row_idx])))
            expect_spad(dst + (row_idx << 2), expected_output[row_idx],
                        $sformatf("CNM accepted Abort prefix Golden[%0d]", row_idx));
        end
        for (row_idx = accepted_write_count; row_idx < 16; row_idx++)
            expect_spad(dst + (row_idx << 2), sentinel ^ row_idx,
                        $sformatf("CNM Abort preserved unaccepted suffix[%0d]", row_idx));

        `uvm_info("CLUSTER_CNM_ABORT_WRITE_PREFIX_PASS", $sformatf(
            "task_id=%04h accepted_output_prefix=%0d/16 read_drain=%0d/%0d completion=ERR_ABORT seed=%0d",
            task_id, accepted_write_count, accepted_reads, returned_reads, seed), UVM_LOW)
        axil_write(REG_CPLQ_HEAD, 32'd1);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
    endtask

    task automatic run_engine_reset_drain_sweep();
        int engine;
        int unsigned poll;
        bit accepted_read;
        bit [6:0] reset_seen;
        bit [31:0] completion_base;
        bit [31:0] reset_dst;
        bit [31:0] value;
        bit [31:0] debug_head;
        bit [31:0] debug_tail;
        bit [31:0] debug_status;
        bit [31:0] sentinel;
        bit [15:0] task_id;
        bit [31:0] desc_base;
        uvm_hdl_data_t reset_value;
        bit reset_ok;

        reset_seen = '0;
        // Queue setup below points CMDQ_BASE at CLUSTER_CONTRACT_CMDQ, so the
        // reset probe descriptor must occupy that exact base slot.
        desc_base = CLUSTER_CONTRACT_CMDQ;
        for (engine = 0; engine < 7; engine++) begin
            task_id = 16'h0700 + engine;
            completion_base = CLUSTER_CONTRACT_CPLQ + 32'h400 + (engine * 32'h10);
            reset_dst = 32'h0003_3000 + (engine * 32'h100);
            sentinel = 32'hbad0_7000 + engine;
            spad_write(reset_dst, sentinel);
            for (poll = 0; poll < 4; poll++)
                spad_write(completion_base + (poll * 4), sentinel ^ poll);

            case (engine)
                0: write_cluster_desc(desc_base, 8'h10, task_id,
                       SCALAR_A_LOCAL, SCALAR_B_LOCAL, reset_dst,
                       16'd0, 16'd0, 16'd64, 32'd0,
                       32'd0, 32'd0, 32'd0, 8'd3);
                1: write_cluster_desc(desc_base, 8'h50, task_id,
                       FP_A_LOCAL, FP_B_LOCAL, reset_dst,
                       16'd1, 16'd1, 16'd64, 32'd0,
                       32'd0, 32'd0, 32'd0, 8'd7);
                2: begin
                    write_cnm_v3_desc(desc_base, task_id,
                        CNM_A_LOCAL, CNM_B_LOCAL, reset_dst);
                    spad_write(desc_base + 32'h18, 32'd64);
                end
                3: write_v3_desc(desc_base, 8'h30, task_id,
                       MATRIX_A_LOCAL, MATRIX_B_LOCAL, reset_dst,
                       16'd16, 16'd32, 16'd16);
                4: write_v3_desc(desc_base, 8'h35, task_id,
                       GELU_A_LOCAL, 32'd0, reset_dst,
                       16'd0, 16'd0, 16'd64);
                5: write_cluster_desc(desc_base, 8'h16, task_id,
                       CONV_A_LOCAL, CONV_W_LOCAL, reset_dst,
                       16'd3, 16'd3, 16'd9, 32'd0,
                       32'd0, 32'd0, 32'd0, 8'd5);
                6: write_cluster_desc(desc_base, 8'h43, task_id,
                       KV_VECTOR_LOCAL, 32'd0, reset_dst,
                       16'd0, 16'd0, 16'd64, {16'd1,16'd1},
                       32'd16, 32'd64, 32'd0, 8'd5);
                default: `uvm_fatal("CLUSTER_ENGINE_RESET", "invalid engine index")
            endcase

            configure_contract_queues(completion_base, 32'd1);
            axil_write(REG_DOORBELL, 32'd1);
            accepted_read = 1'b0;
            for (poll = 0; poll < 50000; poll++) begin
                @(posedge compute_vif.aclk);
                if (compute_vif.engine_busy[engine]) begin
                    if (engine == 2)
                        accepted_read = |compute_vif.cnm_accept_mask;
                    else if (engine == 3)
                        accepted_read = compute_vif.matrix_request_valid &&
                                        compute_vif.banked_ready;
                    else
                        accepted_read = compute_vif.engine_req_valid[engine] &&
                                        compute_vif.engine_req_ready[engine] &&
                                        !compute_vif.engine_req_write[engine];
                    if (accepted_read) break;
                end
            end
            if (!accepted_read)
                begin
                axil_read(REG_CMDQ_HEAD, debug_head);
                axil_read(REG_CPLQ_TAIL, debug_tail);
                axil_read(CIMFORGE_SPAD_BASE + completion_base + 32'h04,
                          debug_status);
                `uvm_fatal("CLUSTER_ENGINE_RESET", $sformatf(
                    "engine %0d task_id=%04h did not accept a real SPAD read before reset; busy=%07b req=%07b cnm_accept=%b matrix_req=%b banked_ready=%b cmd_head=%0d cpl_tail=%0d cpl_status=%08h",
                    engine, task_id, compute_vif.engine_busy,
                    compute_vif.engine_req_valid, compute_vif.cnm_accept_mask,
                    compute_vif.matrix_request_valid, compute_vif.banked_ready,
                    debug_head, debug_tail, debug_status))
                end

            // Assert reset immediately after the accepted read edge so the
            // response ledger must discard the old-epoch response cleanly.
            #1ns;
            reset_value = 1'b0;
            reset_ok = uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", reset_value);
            if (!reset_ok)
                `uvm_fatal("CLUSTER_ENGINE_RESET", $sformatf(
                    "failed to reset real engine %0d with an accepted read", engine))
            repeat (4) @(posedge compute_vif.aclk);
            if (compute_vif.engine_busy !== 7'b0)
                `uvm_fatal("CLUSTER_ENGINE_RESET", $sformatf(
                    "engine %0d remained busy during reset: %07b",
                    engine, compute_vif.engine_busy))
            #1ns;
            reset_value = 1'b1;
            reset_ok = uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", reset_value);
            if (!reset_ok)
                `uvm_fatal("CLUSTER_ENGINE_RESET", $sformatf(
                    "failed to release reset after engine %0d", engine))
            repeat (8) @(posedge compute_vif.aclk);
            wait_spad_idle();

            axil_read(REG_CPLQ_TAIL, value);
            if (value !== 32'd0)
                `uvm_fatal("CLUSTER_ENGINE_RESET", $sformatf(
                    "engine %0d left a stale completion tail after reset: %0d",
                    engine, value))
            expect_spad(reset_dst, sentinel, $sformatf(
                "engine %0d reset prevented output writeback", engine));
            for (poll = 0; poll < 4; poll++)
                expect_spad(completion_base + (poll * 4), sentinel ^ poll,
                    $sformatf("engine %0d reset preserved completion word %0d",
                              engine, poll));
            reset_seen[engine] = 1'b1;
            `uvm_info("CLUSTER_ENGINE_RESET_CASE_PASS", $sformatf(
                "engine=%0d opcode=%02h accepted_read=1; reset cleared busy and preserved destination/completion image",
                engine, (engine == 0) ? 8'h10 :
                        (engine == 1) ? 8'h50 :
                        (engine == 2) ? 8'h21 :
                        (engine == 3) ? 8'h30 :
                        (engine == 4) ? 8'h35 :
                        (engine == 5) ? 8'h16 : 8'h43), UVM_LOW)
        end

        if (reset_seen !== 7'h7f)
            `uvm_fatal("CLUSTER_ENGINE_RESET", $sformatf(
                "not all real engines were reset after accepted reads: mask=%07b",
                reset_seen))
        `uvm_info("CLUSTER_ENGINE_RESET_PASS", $sformatf(
            "real top reset after accepted SPAD reads on all seven engines; reset mask=%07b; stale completion, destination writeback and completion memory were checked",
            reset_seen), UVM_LOW)
    endtask

    task automatic prepare_engine_parity_reset_case(
        input int unsigned engine,
        input bit operand_b,
        input bit [15:0] task_id,
        input bit [31:0] desc_addr,
        input bit [31:0] dst,
        output bit [31:0] fault_addr);
        bit [31:0] src0;
        bit [31:0] src1;
        int unsigned word_idx;

        src0 = '0;
        src1 = '0;
        fault_addr = '0;
        for (word_idx = 0; word_idx < 16; word_idx++)
            spad_write(dst + (word_idx << 2),
                       32'hbaad_0000 | (engine << 8) | (operand_b << 7) | word_idx);

        case (engine)
            0: begin
                src0 = SCALAR_A_LOCAL;
                src1 = SCALAR_B_LOCAL;
                spad_write(src0, 32'h0101_0101);
                spad_write(src1, 32'h0202_0202);
                write_cluster_desc(desc_addr, 8'h10, task_id, src0, src1,
                                   dst, 16'd0, 16'd0, 16'd1, 32'd0,
                                   32'd0, 32'd0, 32'd0, 8'd3);
            end
            1: begin
                src0 = FP_A_LOCAL;
                src1 = FP_B_LOCAL;
                spad_write(src0, 32'h3f80_3f80);
                spad_write(src1, 32'h4000_4000);
                write_cluster_desc(desc_addr, 8'h50, task_id, src0, src1,
                                   dst, 16'd1, 16'd1, 16'd2, 32'd0,
                                   32'd0, 32'd0, 32'd0, 8'd7);
            end
            2: begin
                src0 = CNM_A_LOCAL;
                src1 = CNM_B_LOCAL;
                for (word_idx = 0; word_idx < 4; word_idx++) begin
                    spad_write(src0 + (word_idx << 2), 32'h0101_0101);
                    spad_write(src1 + (word_idx << 2), 32'h0202_0202);
                end
                write_cnm_v3_desc(desc_addr, task_id, src0, src1, dst);
            end
            3: begin
                src0 = MATRIX_FAULT_A_LOCAL;
                src1 = MATRIX_FAULT_B_LOCAL;
                for (word_idx = 0; word_idx < 4; word_idx++) begin
                    spad_write(src0 + (word_idx << 2), 32'h0101_0101);
                    spad_write(src1 + (word_idx << 2), 32'h0101_0101);
                end
                write_v3_desc(desc_addr, 8'h30, task_id, src0, src1,
                              dst, 16'd4, 16'd4, 16'd1);
            end
            4: begin
                src0 = GELU_A_LOCAL;
                for (word_idx = 0; word_idx < 4; word_idx++)
                    spad_write(src0 + (word_idx << 2), 32'h3f80_0000 + word_idx);
                write_v3_desc(desc_addr, 8'h35, task_id, src0, 32'd0,
                              dst, 16'd0, 16'd0, 16'd4);
            end
            5: begin
                src0 = CONV_A_LOCAL;
                src1 = CONV_W_LOCAL;
                for (word_idx = 0; word_idx < 9; word_idx++) begin
                    spad_write(src0 + (word_idx << 2), word_idx + 1);
                    spad_write(src1 + (word_idx << 2), 32'd1);
                end
                write_cluster_desc(desc_addr, 8'h16, task_id, src0, src1,
                                   dst, 16'd3, 16'd3, 16'd9, 32'd0,
                                   32'd0, 32'd0, 32'd0, 8'd5);
            end
            6: begin
                src0 = KV_VECTOR_LOCAL;
                for (word_idx = 0; word_idx < 4; word_idx++)
                    spad_write(src0 + (word_idx << 2), (word_idx + 1) * 32'h100);
                write_cluster_desc(desc_addr, 8'h43, task_id, src0, 32'd0,
                                   dst, 16'd0, 16'd0, 16'd4,
                                   {16'd1,16'd1}, 32'd16, 32'd64,
                                   32'd0, 8'd5);
            end
            default: `uvm_fatal("CLUSTER_PARITY_RESET", $sformatf(
                "invalid engine index %0d", engine))
        endcase

        fault_addr = operand_b ? src1 : src0;
        if (fault_addr == 0)
            `uvm_fatal("CLUSTER_PARITY_RESET", $sformatf(
                "engine %0d does not define operand B", engine))
    endtask

    task automatic run_engine_parity_reset_case(
        input int unsigned engine,
        input bit operand_b,
        input int unsigned slot,
        input int unsigned seed,
        input bit reset_after_response);
        bit [31:0] desc_addr;
        bit [31:0] cpl_addr;
        bit [31:0] dst;
        bit [31:0] fault_addr;
        bit [31:0] value;
        bit accepted_fault_read;
        bit consumed_fault_response;
        bit [15:0] task_id;
        string parity_path;
        uvm_hdl_data_t saved_parity;
        uvm_hdl_data_t reset_value;
        int unsigned poll;

        // configure_contract_queues() publishes CLUSTER_CONTRACT_CMDQ as the
        // command ring base; keep each case in that actual ring slot.
        desc_addr = CLUSTER_CONTRACT_CMDQ;
        cpl_addr = 32'h0000_9000 + (slot * 32'h10);
        dst = 32'h0003_d000 + (slot * 32'h100);
        task_id = 16'h07f0 + slot;

        prepare_engine_parity_reset_case(engine, operand_b, task_id,
                                         desc_addr, dst, fault_addr);
        for (poll = 0; poll < 4; poll++)
            spad_write(cpl_addr + (poll * 4), 32'hbaad_c000 | (slot << 4) | poll);

        inject_spad_parity_fault(fault_addr, parity_path, saved_parity);
        configure_contract_queues(cpl_addr, 32'd1);
        axil_write(REG_DOORBELL, 32'd1);
        accepted_fault_read = 1'b0;
        for (poll = 0; poll < 50000; poll++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.engine_busy[engine]) begin
                case (engine)
                    2: accepted_fault_read = compute_vif.cnm_accept_mask[0] &&
                        (compute_vif.cnm_req_addr[0] == fault_addr);
                    3: accepted_fault_read = compute_vif.matrix_request_valid &&
                        compute_vif.banked_ready &&
                        (compute_vif.matrix_banked_req_addr == fault_addr);
                    default: accepted_fault_read =
                        compute_vif.engine_req_valid[engine] &&
                        compute_vif.engine_req_ready[engine] &&
                        !compute_vif.engine_req_write[engine] &&
                        (compute_vif.engine_req_addr[engine*32 +: 32] == fault_addr);
                endcase
                if (accepted_fault_read) break;
            end
        end
        if (!accepted_fault_read)
            `uvm_fatal("CLUSTER_PARITY_RESET", $sformatf(
                "engine=%0d operand=%s did not accept the parity-faulted read at %08h; busy=%07b req=%07b cnm_accept=%b matrix_req=%b",
                engine, operand_b ? "B" : "A", fault_addr,
                compute_vif.engine_busy, compute_vif.engine_req_valid,
                compute_vif.cnm_accept_mask, compute_vif.matrix_request_valid))

        consumed_fault_response = 1'b0;
        if (reset_after_response) begin
            // Wait for the actual per-engine parity response to be presented
            // at a sampling edge. Matrix uses its dedicated banked path and
            // CNM has per-lane parity; the other engines use the shared-core
            // response mux. Reset immediately after this consume edge, while
            // the core is active in its error path but before Done publishes.
            for (poll = 0; poll < 50000; poll++) begin
                @(posedge compute_vif.aclk);
                if (compute_vif.engine_parity_rsp_error[engine]) begin
                    if (!compute_vif.engine_busy[engine])
                        `uvm_fatal("CLUSTER_PARITY_RESET", $sformatf(
                            "engine=%0d parity response was not sampled while active", engine))
                    consumed_fault_response = 1'b1;
                    break;
                end
            end
            if (!consumed_fault_response)
                `uvm_fatal("CLUSTER_PARITY_RESET", $sformatf(
                    "engine=%0d operand=%s did not consume its parity response",
                    engine, operand_b ? "B" : "A"))
            #1ns;
        end else begin
            // The scratchpad response is registered. Reset at +1ns after the
            // accepted-read edge, before the fault response is sampled.
            #1ns;
        end
        reset_value = 1'b0;
        if (!uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", reset_value))
            `uvm_fatal("CLUSTER_PARITY_RESET", $sformatf(
                "failed to assert reset for engine=%0d operand=%s",
                engine, operand_b ? "B" : "A"))
        restore_spad_parity(parity_path, saved_parity);
        repeat (4) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.rsp_valid !== 1'b0 ||
                compute_vif.matrix_rsp_valid !== 1'b0 ||
                compute_vif.cnm_rsp_valid !== 4'b0 ||
                compute_vif.engine_parity_rsp_error !== 7'b0)
                `uvm_fatal("CLUSTER_PARITY_RESET", $sformatf(
                    "old-epoch response visible during reset engine=%0d operand=%s",
                    engine, operand_b ? "B" : "A"))
        end
        if (compute_vif.engine_busy !== 7'b0)
            `uvm_fatal("CLUSTER_PARITY_RESET", $sformatf(
                "engine busy survived reset engine=%0d busy=%07b",
                engine, compute_vif.engine_busy))
        #1ns;
        reset_value = 1'b1;
        if (!uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", reset_value))
            `uvm_fatal("CLUSTER_PARITY_RESET", $sformatf(
                "failed to release reset for engine=%0d operand=%s",
                engine, operand_b ? "B" : "A"))
        repeat (8) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.rsp_valid !== 1'b0 ||
                compute_vif.matrix_rsp_valid !== 1'b0 ||
                compute_vif.cnm_rsp_valid !== 4'b0 ||
                compute_vif.engine_parity_rsp_error !== 7'b0)
                `uvm_fatal("CLUSTER_PARITY_RESET", $sformatf(
                    "stale response escaped reset epoch engine=%0d operand=%s",
                    engine, operand_b ? "B" : "A"))
        end
        wait_spad_idle();
        axil_read(REG_CPLQ_TAIL, value);
        if (value !== 32'd0)
            `uvm_fatal("CLUSTER_PARITY_RESET", $sformatf(
                "reset must suppress old-epoch completion engine=%0d operand=%s tail=%0d",
                engine, operand_b ? "B" : "A", value))
        for (poll = 0; poll < 16; poll++)
            expect_spad(dst + (poll << 2),
                32'hbaad_0000 | (engine << 8) | (operand_b << 7) | poll,
                $sformatf("parity-reset destination sentinel e%0d p%0d w%0d",
                          engine, operand_b, poll));
        for (poll = 0; poll < 4; poll++)
            expect_spad(cpl_addr + (poll << 2),
                32'hbaad_c000 | (slot << 4) | poll,
                $sformatf("parity-reset completion sentinel e%0d p%0d w%0d",
                          engine, operand_b, poll));

        // Reissue the repaired legal descriptor to prove the new epoch can
        // dispatch and retire the same engine operation.
        restore_spad_parity(parity_path, saved_parity);
        prepare_engine_parity_reset_case(engine, operand_b, task_id + 16'h0100,
                                         desc_addr, dst, fault_addr);
        configure_contract_queues(cpl_addr, 32'd1);
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd1);
        wait_spad_idle();
        expect_spad(cpl_addr, {16'd0, task_id + 16'h0100},
                    $sformatf("parity-reset recovery task id e%0d p%0d", engine, operand_b));
        expect_spad(cpl_addr + 32'h04, 32'd1,
                    $sformatf("parity-reset recovery status e%0d p%0d", engine, operand_b));
        `uvm_info("CLUSTER_PARITY_RESET_CASE_PASS", $sformatf(
            "engine=%0d operand=%0s reset_phase=%0s; parity epoch produced no stale response/completion/writeback; repaired task retired after recovery; seed=%0d",
            engine, operand_b ? "B" : "A",
            reset_after_response ? "after_response_consume" : "before_response_consume", seed), UVM_LOW)
        clear_contract_queues(32'd1);
    endtask

    task automatic run_engine_parity_reset_sweep(input int unsigned seed);
        int unsigned cases;
        int unsigned engine;
        int unsigned operand_phase;
        int unsigned reset_phase;

        cases = 0;
        for (engine = 0; engine < 7; engine++) begin
            for (operand_phase = 0; operand_phase < 2; operand_phase++) begin
                if ((operand_phase == 0) || (engine == 0) || (engine == 1) ||
                    (engine == 2) || (engine == 3) || (engine == 5)) begin
                    for (reset_phase = 0; reset_phase < 2; reset_phase++) begin
                        run_engine_parity_reset_case(engine, operand_phase[0],
                            cases, seed, reset_phase[0]);
                        cases++;
                    end
                end
            end
        end
        if (cases != 24)
            `uvm_fatal("CLUSTER_PARITY_RESET", $sformatf(
                "expected 24 legal engine/operand/reset cases, observed %0d", cases))
        `uvm_info("CLUSTER_PARITY_RESET_CROSS_PASS", $sformatf(
            "before-response-consume parity reset cross=12/12; engines=7 operands={A all,B where defined}; seed=%0d",
            seed), UVM_LOW)
        `uvm_info("CLUSTER_PARITY_RESET_CONSUMED_CROSS_PASS", $sformatf(
            "after-response-consume parity reset cross=12/12; engines=7 operands={A all,B where defined}; recovery dispatched for all 24 phase cases; seed=%0d",
            seed), UVM_LOW)
    endtask

    task automatic run_matrix_parity_reset_epoch_case(input int unsigned seed);
        int unsigned poll;
        int unsigned word_idx;
        bit accepted_fault_read;
        bit parity_response_consumed;
        bit [31:0] desc_base;
        bit [31:0] cpl_base;
        bit [31:0] matrix_a;
        bit [31:0] matrix_b;
        bit [31:0] matrix_dst;
        bit [31:0] value;
        bit [31:0] sentinel;
        uvm_hdl_data_t reset_value;
        uvm_hdl_data_t saved_parity;
        string parity_path;

        desc_base = CLUSTER_CONTRACT_CMDQ;
        cpl_base = CLUSTER_CONTRACT_CPLQ + 32'h900;
        matrix_a = MATRIX_FAULT_A_LOCAL;
        matrix_b = MATRIX_FAULT_B_LOCAL;
        matrix_dst = 32'h0003_c000;
        sentinel = 32'hbad0_7e40;
        accepted_fault_read = 1'b0;

        // A legal 4x4x4 INT8 GEMM: each packed A/B word contains four ones,
        // so all 16 outputs are exactly four after recovery.
        for (word_idx = 0; word_idx < 4; word_idx++) begin
            spad_write(matrix_a + (word_idx << 2), 32'h0101_0101);
            spad_write(matrix_b + (word_idx << 2), 32'h0101_0101);
        end
        for (word_idx = 0; word_idx < 16; word_idx++)
            spad_write(matrix_dst + (word_idx << 2), sentinel | word_idx);
        for (word_idx = 0; word_idx < 4; word_idx++)
            spad_write(cpl_base + (word_idx << 2), sentinel ^ word_idx);

        write_v3_desc(desc_base, 8'h30, 16'h07e4,
                      matrix_a, matrix_b, matrix_dst,
                      16'd4, 16'd4, 16'd1);
        configure_contract_queues(cpl_base, 32'd1);
        inject_spad_parity_fault(matrix_a, parity_path, saved_parity);
        axil_write(REG_DOORBELL, 32'd1);

        for (poll = 0; poll < 50000; poll++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.matrix_request_valid && compute_vif.banked_ready &&
                (compute_vif.matrix_banked_req_addr == matrix_a)) begin
                accepted_fault_read = 1'b1;
                break;
            end
        end
        if (!accepted_fault_read)
            `uvm_fatal("CLUSTER_MATRIX_PARITY_RESET",
                "Matrix did not accept the parity-faulted A read before reset")

        // Reset one nanosecond after the accepted banked-read edge, before
        // the registered parity response can be consumed by the engine.
        #1ns;
        reset_value = 1'b0;
        if (!uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", reset_value))
            `uvm_fatal("CLUSTER_MATRIX_PARITY_RESET",
                "failed to assert reset with the Matrix parity response pending")
        restore_spad_parity(parity_path, saved_parity);
        repeat (4) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.rsp_valid !== 1'b0)
                `uvm_fatal("CLUSTER_MATRIX_PARITY_RESET",
                    "old-epoch Matrix parity response was visible during reset")
        end
        if (compute_vif.engine_busy !== 7'b0)
            `uvm_fatal("CLUSTER_MATRIX_PARITY_RESET", $sformatf(
                "Matrix remained busy during reset: busy=%07b",
                compute_vif.engine_busy))
        #1ns;
        reset_value = 1'b1;
        if (!uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", reset_value))
            `uvm_fatal("CLUSTER_MATRIX_PARITY_RESET",
                "failed to release reset after the pending parity response")
        repeat (8) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.rsp_valid !== 1'b0)
                `uvm_fatal("CLUSTER_MATRIX_PARITY_RESET",
                    "stale Matrix parity response escaped into the new epoch")
        end
        wait_spad_idle();

        axil_read(REG_CPLQ_TAIL, value);
        if (value !== 32'd0)
            `uvm_fatal("CLUSTER_MATRIX_PARITY_RESET", $sformatf(
                "reset must discard the old-epoch completion, tail=%0d", value))
        for (word_idx = 0; word_idx < 16; word_idx++)
            expect_spad(matrix_dst + (word_idx << 2), sentinel | word_idx,
                $sformatf("Matrix parity/reset preserved destination[%0d]", word_idx));
        for (word_idx = 0; word_idx < 4; word_idx++)
            expect_spad(cpl_base + (word_idx << 2), sentinel ^ word_idx,
                $sformatf("Matrix parity/reset preserved completion word[%0d]", word_idx));

        // Reissue the same legal descriptor after restoring parity. Golden
        // completion and all output words prove that the new epoch is usable.
        write_v3_desc(desc_base, 8'h30, 16'h07e5,
                      matrix_a, matrix_b, matrix_dst,
                      16'd4, 16'd4, 16'd1);
        configure_contract_queues(cpl_base, 32'd1);
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd1);
        wait_spad_idle();
        expect_completion(cpl_base, 16'h07e5, 32'd4, 32'd16,
                          "Matrix parity/reset new-epoch recovery");
        for (word_idx = 0; word_idx < 16; word_idx++)
            expect_spad(matrix_dst + (word_idx << 2), 32'd4,
                $sformatf("Matrix parity/reset recovery Golden[%0d]", word_idx));
        clear_contract_queues(32'd1);

        // Exercise the adjacent reset phase: the Matrix samples the registered
        // parity response on a clock edge, then reset arrives before the
        // resulting error can be published as a completion.
        accepted_fault_read = 1'b0;
        parity_response_consumed = 1'b0;
        for (word_idx = 0; word_idx < 16; word_idx++)
            spad_write(matrix_dst + (word_idx << 2), sentinel | word_idx);
        for (word_idx = 0; word_idx < 4; word_idx++)
            spad_write(cpl_base + (word_idx << 2), sentinel ^ (word_idx + 8));
        write_v3_desc(desc_base, 8'h30, 16'h07e6,
                      matrix_a, matrix_b, matrix_dst,
                      16'd4, 16'd4, 16'd1);
        configure_contract_queues(cpl_base, 32'd1);
        inject_spad_parity_fault(matrix_a, parity_path, saved_parity);
        axil_write(REG_DOORBELL, 32'd1);
        for (poll = 0; poll < 50000; poll++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.matrix_request_valid && compute_vif.banked_ready &&
                (compute_vif.matrix_banked_req_addr == matrix_a)) begin
                accepted_fault_read = 1'b1;
                break;
            end
        end
        if (!accepted_fault_read)
            `uvm_fatal("CLUSTER_MATRIX_PARITY_RESET_AFTER_RESPONSE",
                "Matrix did not accept the second parity-faulted A read")
        for (poll = 0; poll < 50000; poll++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.matrix_response_fault) begin
                if (!compute_vif.engine_busy[3])
                    `uvm_fatal("CLUSTER_MATRIX_PARITY_RESET_AFTER_RESPONSE",
                        "Matrix was not active on the edge that consumed its parity response")
                parity_response_consumed = 1'b1;
                break;
            end
        end
        if (!parity_response_consumed)
            `uvm_fatal("CLUSTER_MATRIX_PARITY_RESET_AFTER_RESPONSE",
                "accepted parity response was not sampled by the Matrix engine")

        // This delay places reset after the response-consume edge, while the
        // Matrix error path is active and before a completion can be published.
        #1ns;
        reset_value = 1'b0;
        if (!uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", reset_value))
            `uvm_fatal("CLUSTER_MATRIX_PARITY_RESET_AFTER_RESPONSE",
                "failed to assert reset after Matrix consumed the parity response")
        restore_spad_parity(parity_path, saved_parity);
        repeat (4) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.rsp_valid !== 1'b0)
                `uvm_fatal("CLUSTER_MATRIX_PARITY_RESET_AFTER_RESPONSE",
                    "consumed-fault epoch produced a response during reset")
        end
        #1ns;
        reset_value = 1'b1;
        if (!uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", reset_value))
            `uvm_fatal("CLUSTER_MATRIX_PARITY_RESET_AFTER_RESPONSE",
                "failed to release reset after consumed parity response")
        repeat (8) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.rsp_valid !== 1'b0)
                `uvm_fatal("CLUSTER_MATRIX_PARITY_RESET_AFTER_RESPONSE",
                    "consumed-fault response escaped into the new epoch")
        end
        wait_spad_idle();
        axil_read(REG_CPLQ_TAIL, value);
        if (value !== 32'd0)
            `uvm_fatal("CLUSTER_MATRIX_PARITY_RESET_AFTER_RESPONSE", $sformatf(
                "reset after parity response consumption must suppress old completion, tail=%0d",
                value))
        for (word_idx = 0; word_idx < 16; word_idx++)
            expect_spad(matrix_dst + (word_idx << 2), sentinel | word_idx,
                $sformatf("Matrix consumed-parity/reset preserved destination[%0d]", word_idx));
        for (word_idx = 0; word_idx < 4; word_idx++)
            expect_spad(cpl_base + (word_idx << 2), sentinel ^ (word_idx + 8),
                $sformatf("Matrix consumed-parity/reset preserved completion[%0d]", word_idx));

        write_v3_desc(desc_base, 8'h30, 16'h07e7,
                      matrix_a, matrix_b, matrix_dst,
                      16'd4, 16'd4, 16'd1);
        configure_contract_queues(cpl_base, 32'd1);
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd1);
        wait_spad_idle();
        expect_completion(cpl_base, 16'h07e7, 32'd4, 32'd16,
                          "Matrix consumed-parity/reset new-epoch recovery");
        for (word_idx = 0; word_idx < 16; word_idx++)
            expect_spad(matrix_dst + (word_idx << 2), 32'd4,
                $sformatf("Matrix consumed-parity/reset recovery Golden[%0d]", word_idx));
        clear_contract_queues(32'd1);
        `uvm_info("CLUSTER_MATRIX_PARITY_RESET_EPOCH_PASS", $sformatf(
            "reset before the accepted Matrix parity response was consumed; no old-epoch response/completion escaped and the reissued 4x4x4 GEMM matched all 16 Golden outputs; seed=%0d",
            seed), UVM_LOW)
        `uvm_info("CLUSTER_MATRIX_PARITY_RESET_AFTER_RESPONSE_PASS", $sformatf(
            "Matrix sampled the accepted parity response before reset; no old-epoch completion or data side effect escaped, and the reissued GEMM matched all 16 Golden outputs; seed=%0d",
            seed), UVM_LOW)
    endtask

    task automatic run_engine_abort_drain_sweep();
        int engine;
        int unsigned poll;
        int unsigned word_idx;
        int unsigned accepted_reads;
        int unsigned returned_reads;
        int unsigned accepted_now;
        int unsigned returned_now;
        int unsigned accepted_output_writes;
        int unsigned post_abort_output_writes;
        bit accepted_read;
        bit monitor_done;
        bit abort_seen;
        bit abort_active_seen;
        bit [6:0] abort_seen_mask;
        bit [6:0] sentinel_preserved_mask;
        bit [31:0] completion_base;
        bit [31:0] desc_base;
        bit [31:0] abort_dst;
        bit [31:0] abort_src0;
        bit [31:0] abort_src1;
        bit [15:0] task_id;

        abort_seen_mask = '0;
        sentinel_preserved_mask = '0;
        desc_base = CLUSTER_CONTRACT_CMDQ;
        // Give every long-running engine fully initialized legal operands so
        // the independent memory scoreboard can check all accepted reads.
        for (word_idx = 0; word_idx < 64; word_idx++) begin
            spad_write(32'h0004_a800 + (word_idx << 2), 32'h0102_0304 + word_idx);
            spad_write(32'h0004_a900 + (word_idx << 2), 32'h0506_0708 + word_idx);
            spad_write(32'h0004_aa00 + (word_idx << 2), 32'h1111_1111 * (word_idx + 1));
            spad_write(32'h0004_b000 + (word_idx << 2), 32'd0);
            spad_write(32'h0004_b100 + (word_idx << 2), word_idx + 1);
            spad_write(32'h0004_b700 + (word_idx << 2), (word_idx + 1) * 32'h100);
        end
        for (word_idx = 64; word_idx < 256; word_idx++)
            spad_write(32'h0004_b100 + (word_idx << 2), word_idx + 1);
        for (word_idx = 0; word_idx < 256; word_idx++)
            spad_write(32'h0004_ab00 + (word_idx << 2),
                       32'h0101_0101 * ((word_idx % 15) + 1));
        for (word_idx = 0; word_idx < 9; word_idx++)
            spad_write(32'h0004_b600 + (word_idx << 2), 32'd1);

        for (engine = 0; engine < 7; engine++) begin
            task_id = 16'h0760 + engine;
            completion_base = 32'h0000_5c00;
            abort_dst = 32'h0003_a000 + (engine * 32'h1000);
            abort_src0 = 32'h0004_a800;
            abort_src1 = 32'h0004_a900;
            for (word_idx = 0; word_idx < 8; word_idx++)
                spad_write(abort_dst + (word_idx << 2),
                           32'hbad0_7600 | (engine << 8) | word_idx);
            for (word_idx = 0; word_idx < 4; word_idx++)
                spad_write(completion_base + (word_idx << 2),
                           32'h7600_0000 | (engine << 8) | word_idx);

            case (engine)
                0: write_cluster_desc(desc_base, 8'h10, task_id,
                       abort_src0, abort_src1, abort_dst,
                       16'd0, 16'd0, 16'd64, 32'd0,
                       32'd0, 32'd0, 32'd0, 8'd3);
                1: write_cluster_desc(desc_base, 8'h50, task_id,
                       abort_src0, abort_src1, abort_dst,
                       16'd1, 16'd1, 16'd64, 32'd0,
                       32'd0, 32'd0, 32'd0, 8'd7);
                2: begin
                    write_cnm_v3_desc(desc_base, task_id,
                        32'h0004_aa00, 32'h0004_ab00, abort_dst);
                    spad_write(desc_base + 32'h18, 32'd64);
                end
                3: write_v3_desc(desc_base, 8'h30, task_id,
                       MATRIX_A_LOCAL, MATRIX_B_LOCAL, abort_dst,
                       16'd16, 16'd32, 16'd16);
                4: write_v3_desc(desc_base, 8'h35, task_id,
                       32'h0004_b000, 32'd0, abort_dst,
                       16'd0, 16'd0, 16'd64);
                5: write_cluster_desc(desc_base, 8'h16, task_id,
                       32'h0004_b100, 32'h0004_b600, abort_dst,
                       16'd16, 16'd16, 16'd9, 32'd0,
                       32'd0, 32'd0, 32'd0, 8'd5);
                6: write_cluster_desc(desc_base, 8'h43, task_id,
                       32'h0004_b700, 32'd0, abort_dst,
                       16'd0, 16'd0, 16'd64, {16'd1,16'd1},
                       32'd16, 32'd64, 32'd0, 8'd5);
                default: `uvm_fatal("CLUSTER_ENGINE_ABORT", "invalid engine index")
            endcase

            configure_contract_queues(completion_base, 32'd1);
            axil_write(REG_DOORBELL, 32'd1);
            accepted_read = 1'b0;
            accepted_reads = 0;
            returned_reads = 0;
            accepted_output_writes = 0;
            post_abort_output_writes = 0;
            abort_active_seen = 1'b0;
            for (poll = 0; poll < 50000; poll++) begin
                @(posedge compute_vif.aclk);
                accepted_now = 0;
                case (engine)
                    2: accepted_now = $countones(compute_vif.cnm_accept_mask);
                    3: accepted_now = compute_vif.matrix_request_valid &&
                                      compute_vif.banked_ready;
                    default: accepted_now = compute_vif.engine_req_valid[engine] &&
                                            compute_vif.engine_req_ready[engine] &&
                                            !compute_vif.engine_req_write[engine];
                endcase
                accepted_reads += accepted_now;
                if (accepted_now != 0) begin
                    accepted_read = 1'b1;
                    break;
                end
            end
            if (!accepted_read)
                `uvm_fatal("CLUSTER_ENGINE_ABORT", $sformatf(
                    "engine %0d task_id=%04h did not accept a real SPAD read before Abort; busy=%07b req=%07b cnm_accept=%b matrix_req=%b banked_ready=%b",
                    engine, task_id, compute_vif.engine_busy,
                    compute_vif.engine_req_valid, compute_vif.cnm_accept_mask,
                    compute_vif.matrix_request_valid, compute_vif.banked_ready))

            monitor_done = 1'b0;
            abort_seen = 1'b0;
            fork
                begin : abort_drain_monitor
                    while (!monitor_done) begin
                        @(posedge compute_vif.aclk);
                        if (compute_vif.engine_req_valid[engine] &&
                            compute_vif.engine_req_ready[engine] &&
                            compute_vif.engine_req_write[engine]) begin
                            accepted_output_writes++;
                            // A write accepted on the same edge that the engine
                            // first samples core_abort is part of the frozen
                            // committed prefix. Only a later handshake is a
                            // post-Abort write violation.
                            if (abort_active_seen)
                                post_abort_output_writes++;
                        end
                        if (compute_vif.dut_abort_active) begin
                            abort_seen = 1'b1;
                            abort_active_seen = 1'b1;
                        end
                        accepted_now = 0;
                        returned_now = 0;
                        case (engine)
                            2: begin
                                accepted_now = $countones(compute_vif.cnm_accept_mask);
                                returned_now = $countones(compute_vif.cnm_rsp_valid);
                            end
                            3: begin
                                accepted_now = compute_vif.matrix_request_valid &&
                                               compute_vif.banked_ready;
                                returned_now = compute_vif.rsp_valid &&
                                               (compute_vif.rsp_client == 3'd3);
                            end
                            default: begin
                                accepted_now = compute_vif.engine_req_valid[engine] &&
                                               compute_vif.engine_req_ready[engine] &&
                                               !compute_vif.engine_req_write[engine];
                                returned_now = compute_vif.rsp_valid &&
                                               (compute_vif.rsp_client == 3'd2);
                            end
                        endcase
                        accepted_reads += accepted_now;
                        returned_reads += returned_now;
                    end
                end
                begin : issue_abort_and_retire
                    axil_write(REG_ABORT, 32'd1);
                    wait_cpl_tail(32'd1);
                    monitor_done = 1'b1;
                end
            join

            wait_spad_idle();
            if (!abort_seen)
                `uvm_fatal("CLUSTER_ENGINE_ABORT", $sformatf(
                    "software Abort was not observed while engine %0d task_id=%04h was draining",
                    engine, task_id))
            if (compute_vif.engine_busy != 0)
                `uvm_fatal("CLUSTER_ENGINE_ABORT", $sformatf(
                    "engine %0d completion published with busy mask=%07b",
                    engine, compute_vif.engine_busy))
            if (accepted_reads == 0 || returned_reads != accepted_reads)
                `uvm_fatal("CLUSTER_ENGINE_ABORT", $sformatf(
                    "engine %0d Abort failed to drain accepted reads: accepted=%0d returned=%0d",
                    engine, accepted_reads, returned_reads))
            if (post_abort_output_writes != 0)
                `uvm_fatal("CLUSTER_ENGINE_ABORT", $sformatf(
                    "engine %0d accepted %0d output writes after the first edge on which it sampled Abort",
                    engine, post_abort_output_writes))
            if (accepted_output_writes == 0) begin
                for (word_idx = 0; word_idx < 8; word_idx++)
                    expect_spad(abort_dst + (word_idx << 2),
                                32'hbad0_7600 | (engine << 8) | word_idx,
                                $sformatf("engine%0d Abort preserved output sentinel[%0d]",
                                          engine, word_idx));
                sentinel_preserved_mask[engine] = 1'b1;
            end else if (engine < 4) begin
                `uvm_fatal("CLUSTER_ENGINE_ABORT", $sformatf(
                    "engine %0d unexpectedly committed an output prefix before Abort sampling; prefix=%0d",
                    engine, accepted_output_writes))
            end
            expect_spad(completion_base + 32'h00, {16'd0, task_id},
                        $sformatf("engine%0d Abort completion task ID", engine));
            expect_spad(completion_base + 32'h04, 32'h0000_0032,
                        $sformatf("engine%0d Abort completion status/code", engine));
            abort_seen_mask[engine] = 1'b1;
            `uvm_info("CLUSTER_ENGINE_ABORT_CASE_PASS", $sformatf(
                "engine=%0d task_id=%04h accepted_read=1 abort=1 completion=ERR_ABORT accepted_reads=%0d returned_reads=%0d accepted_prefix_writes=%0d post_abort_output_writes=%0d sentinel_check=%s all_engines_idle=1",
                engine, task_id, accepted_reads, returned_reads,
                accepted_output_writes, post_abort_output_writes,
                (accepted_output_writes == 0) ? "8/8" : "prefix_oracle"), UVM_LOW)
            axil_write(REG_CPLQ_HEAD, 32'd1);
            axil_write(REG_CMDQ_SIZE, 32'd0);
            axil_write(REG_CPLQ_SIZE, 32'd0);
        end

        if (abort_seen_mask !== 7'h7f)
            `uvm_fatal("CLUSTER_ENGINE_ABORT", $sformatf(
                "not all real engines passed accepted-read Abort/drain: mask=%07b",
                abort_seen_mask))
        if (sentinel_preserved_mask[3:0] !== 4'hf)
            `uvm_fatal("CLUSTER_ENGINE_ABORT", $sformatf(
                "long-running Scalar/FP/CNM/Matrix Abort cases failed to preserve zero-prefix sentinels: mask=%07b",
                sentinel_preserved_mask))
        `uvm_info("CLUSTER_ENGINE_ABORT_PASS", $sformatf(
            "software Abort after accepted SPAD reads drained all real engines; abort mask=%07b post-abort output-write suppression=7/7 zero-prefix sentinel mask=%07b words=%0d/56; short visible prefixes are checked by per-engine Golden tests; completion owner/status and accepted-read response balance checked",
            abort_seen_mask, sentinel_preserved_mask,
            $countones(sentinel_preserved_mask) * 8), UVM_LOW)
    endtask

    task automatic run_sfu_abort_write_prefix(input int unsigned seed);
        int signed gelu_inputs[0:3];
        int signed gelu_golden[0:3];
        bit [31:0] write_addr[0:63];
        bit [31:0] write_data[0:63];
        bit [31:0] desc_base;
        bit [31:0] completion_base;
        bit [31:0] dst;
        bit [31:0] sentinel;
        bit [15:0] task_id;
        int unsigned accepted_write_count;
        int unsigned accepted_reads;
        int unsigned returned_reads;
        int unsigned poll;
        int unsigned word_idx;
        bit first_write_seen;
        bit abort_seen;
        bit monitor_done;

        desc_base = CLUSTER_CONTRACT_CMDQ;
        completion_base = 32'h0000_5c80;
        dst = 32'h0004_c000;
        sentinel = 32'hbad0_77f0;
        task_id = 16'h0770;
        accepted_write_count = 0;
        accepted_reads = 0;
        returned_reads = 0;
        first_write_seen = 1'b0;
        abort_seen = 1'b0;
        monitor_done = 1'b0;

        gelu_inputs[0] = 16;
        gelu_inputs[1] = -16;
        gelu_inputs[2] = 32;
        gelu_inputs[3] = -32;
        gelu_golden[0] = 8;
        gelu_golden[1] = -8;
        gelu_golden[2] = 17;
        gelu_golden[3] = -15;
        for (word_idx = 0; word_idx < 64; word_idx++) begin
            spad_write(GELU_A_LOCAL + (word_idx << 2), gelu_inputs[word_idx % 4]);
            spad_write(dst + (word_idx << 2), sentinel ^ word_idx);
        end
        for (word_idx = 0; word_idx < 4; word_idx++)
            spad_write(completion_base + (word_idx << 2), 32'h77f0_0000 | word_idx);

        write_v3_desc(desc_base, 8'h35, task_id, GELU_A_LOCAL, 32'd0, dst,
                      16'd0, 16'd0, 16'd64);
        configure_contract_queues(completion_base, 32'd1);
        axil_write(REG_DOORBELL, 32'd1);

        fork
            begin : sfu_abort_prefix_monitor
                while (!monitor_done) begin
                    @(posedge compute_vif.aclk);
                    if (compute_vif.dut_abort_active)
                        abort_seen = 1'b1;
                    if (compute_vif.engine_req_valid[4] &&
                        compute_vif.engine_req_ready[4]) begin
                        if (compute_vif.engine_req_write[4]) begin
                            if (accepted_write_count >= 64)
                                `uvm_fatal("CLUSTER_SFU_ABORT_PREFIX",
                                    "SFU accepted more output writes than the 64-element descriptor")
                            write_addr[accepted_write_count] =
                                compute_vif.engine_req_addr[4*32 +: 32];
                            write_data[accepted_write_count] =
                                compute_vif.engine_req_wdata[4*32 +: 32];
                            accepted_write_count++;
                            first_write_seen = 1'b1;
                        end else begin
                            accepted_reads++;
                        end
                    end
                    if (compute_vif.rsp_valid &&
                        (compute_vif.rsp_client == 3'd2))
                        returned_reads++;
                end
            end
            begin : abort_after_first_sfu_write
                poll = 0;
                while (!first_write_seen && poll < 50000) begin
                    @(posedge compute_vif.aclk);
                    poll++;
                end
                if (!first_write_seen)
                    `uvm_fatal("CLUSTER_SFU_ABORT_PREFIX",
                        "SFU did not accept an output write before the Abort timeout")
                axil_write(REG_ABORT, 32'd1);
                wait_cpl_tail(32'd1);
                monitor_done = 1'b1;
            end
        join

        wait_spad_idle();
        if (!abort_seen)
            `uvm_fatal("CLUSTER_SFU_ABORT_PREFIX",
                "software Abort was not observed during SFU output drain")
        if (accepted_write_count == 0 || accepted_write_count >= 64)
            `uvm_fatal("CLUSTER_SFU_ABORT_PREFIX", $sformatf(
                "Abort did not cut a non-empty proper output prefix: writes=%0d",
                accepted_write_count))
        if (accepted_reads == 0 || returned_reads != accepted_reads)
            `uvm_fatal("CLUSTER_SFU_ABORT_PREFIX", $sformatf(
                "SFU read responses did not drain: accepted=%0d returned=%0d",
                accepted_reads, returned_reads))

        expect_spad(completion_base + 32'h00, {16'd0, task_id},
                    "SFU accepted-write Abort task ID");
        expect_spad(completion_base + 32'h04, 32'h0000_0032,
                    "SFU accepted-write Abort status/code");
        for (word_idx = 0; word_idx < accepted_write_count; word_idx++) begin
            if (write_addr[word_idx] !== dst + (word_idx << 2))
                `uvm_fatal("CLUSTER_SFU_ABORT_PREFIX", $sformatf(
                    "non-prefix output address index=%0d expected=0x%08h actual=0x%08h",
                    word_idx, dst + (word_idx << 2), write_addr[word_idx]))
            if (write_data[word_idx] !== gelu_golden[word_idx % 4])
                `uvm_fatal("CLUSTER_SFU_ABORT_PREFIX", $sformatf(
                    "Golden mismatch in accepted prefix index=%0d expected=0x%08h actual=0x%08h",
                    word_idx, gelu_golden[word_idx % 4], write_data[word_idx]))
            expect_spad(dst + (word_idx << 2), gelu_golden[word_idx % 4],
                        $sformatf("SFU accepted Abort prefix Golden[%0d]", word_idx));
        end
        for (word_idx = accepted_write_count; word_idx < 64; word_idx++)
            expect_spad(dst + (word_idx << 2), sentinel ^ word_idx,
                        $sformatf("SFU Abort preserved unaccepted suffix[%0d]", word_idx));

        `uvm_info("CLUSTER_SFU_ABORT_WRITE_PREFIX_PASS", $sformatf(
            "task_id=%04h accepted_output_prefix=%0d/64 read_drain=%0d/%0d completion=ERR_ABORT seed=%0d",
            task_id, accepted_write_count, accepted_reads, returned_reads, seed), UVM_LOW)
        axil_write(REG_CPLQ_HEAD, 32'd1);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
    endtask

    task automatic check_request_stability();
        int unsigned e;
        if (compute_vif.engine_req_stability_violations != 0 ||
            compute_vif.matrix_banked_stall_violations != 0 ||
            compute_vif.matrix_line_stall_violations != 0 ||
            compute_vif.cnm_stall_violations != 0)
            `uvm_fatal("CLUSTER_REQUEST_STABILITY", $sformatf(
                "stall payload changed: engine=%0d MatrixBanked=%0d MatrixLine=%0d CNM=%0d",
                compute_vif.engine_req_stability_violations,
                compute_vif.matrix_banked_stall_violations,
                compute_vif.matrix_line_stall_violations,
                compute_vif.cnm_stall_violations))
        if (compute_vif.engine_req_stall_seen == 0 ||
            compute_vif.matrix_banked_stall_checks == 0)
            `uvm_fatal("CLUSTER_REQUEST_STABILITY", $sformatf(
                "no stalled compute request was checked: engine_mask=%07b banked_checks=%0d",
                compute_vif.engine_req_stall_seen,
                compute_vif.matrix_banked_stall_checks))
        for (e = 0; e < 7; e++)
            if (compute_vif.engine_req_stall_checks[e] != 0 &&
                compute_vif.engine_req_stall_cycles[e] == 0)
                `uvm_fatal("CLUSTER_REQUEST_STABILITY", $sformatf(
                    "engine%0d stability checks lack a stall sample", e))
        `uvm_info("CLUSTER_REQUEST_STABILITY_PASS", $sformatf(
            "engine stalled mask=%07b cycles={%0d,%0d,%0d,%0d,%0d,%0d,%0d}; Matrix banked checks=%0d fault-cancel=%0d, Matrix line checks=%0d, CNM lane checks={%0d,%0d,%0d,%0d}",
            compute_vif.engine_req_stall_seen,
            compute_vif.engine_req_stall_cycles[0], compute_vif.engine_req_stall_cycles[1],
            compute_vif.engine_req_stall_cycles[2], compute_vif.engine_req_stall_cycles[3],
            compute_vif.engine_req_stall_cycles[4], compute_vif.engine_req_stall_cycles[5],
            compute_vif.engine_req_stall_cycles[6],
            compute_vif.matrix_banked_stall_checks,
            compute_vif.matrix_banked_fault_cancel_checks,
            compute_vif.matrix_line_stall_checks,
            compute_vif.cnm_stall_checks[0], compute_vif.cnm_stall_checks[1],
            compute_vif.cnm_stall_checks[2], compute_vif.cnm_stall_checks[3]), UVM_LOW)
    endtask

    task automatic wait_matrix_sfu_overlap();
        int unsigned poll;
        for (poll = 0; poll < 3000; poll++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.engine_busy[3] && compute_vif.engine_busy[4]) return;
        end
        `uvm_fatal("CLUSTER_ABORT", "Matrix and SFU did not become active together before abort")
    endtask

    task automatic wait_matrix_read_accept();
        int unsigned poll;
        for (poll = 0; poll < 3000; poll++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.banked_valid && compute_vif.banked_ready) return;
        end
        `uvm_fatal("CLUSTER_RESET", "Matrix did not receive a banked-SPAD grant before reset")
    endtask

    task automatic wait_matrix_prefetch_active();
        int unsigned poll;
        for (poll = 0; poll < 3000; poll++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.matrix_prefetch_active) return;
        end
        `uvm_fatal("CLUSTER_PREFETCH", "Matrix did not enter next-K prefetch before abort/reset")
    endtask

    task automatic check_cnm_address_stream();
        int unsigned lane_count[0:3];
        int unsigned lane;
        int unsigned poll;
        int unsigned matrix_reads;
        bit complete;
        bit [31:0] expected_addr;
        bit [31:0] cpl_tail;
        for (lane = 0; lane < 4; lane++) lane_count[lane] = 0;
        poll = 0;
        matrix_reads = 0;
        complete = 1'b0;
        while (!complete && poll < 10000) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.aresetn) begin
                if (compute_vif.banked_valid && compute_vif.banked_ready) begin
                    if (compute_vif.matrix_banked_req_addr[1:0] != 2'b00 ||
                        !((compute_vif.matrix_banked_req_addr >= MATRIX_A_LOCAL &&
                           compute_vif.matrix_banked_req_addr < MATRIX_A_LOCAL + 32'h400) ||
                          (compute_vif.matrix_banked_req_addr >= MATRIX_B_LOCAL &&
                           compute_vif.matrix_banked_req_addr < MATRIX_B_LOCAL + 32'h800)))
                        `uvm_fatal("CLUSTER_MATRIX_ADDR", $sformatf("Matrix banked read outside aligned A/B tile regions: 0x%08h", compute_vif.matrix_banked_req_addr))
                    matrix_reads++;
                end
                for (lane = 0; lane < 4; lane++) begin
                    if (compute_vif.cnm_accept_mask[lane]) begin
                        if (lane_count[lane][0])
                            expected_addr = CNM_B_LOCAL + ((lane_count[lane] >> 1) << 4) + (lane << 2);
                        else
                            expected_addr = CNM_A_LOCAL + (lane << 2);
                        if (compute_vif.cnm_req_addr[lane] !== expected_addr)
                            `uvm_fatal("CLUSTER_CNM_ADDR", $sformatf("lane%0d read[%0d] expected=0x%08h actual=0x%08h", lane, lane_count[lane], expected_addr, compute_vif.cnm_req_addr[lane]))
                        lane_count[lane]++;
                    end
                end
            end
            complete = 1'b1;
            for (lane = 0; lane < 4; lane++)
                if (lane_count[lane] != 32) complete = 1'b0;
            if (!complete && (compute_vif.engine_done[2] ||
                              compute_vif.engine_error[2]))
                break;
            poll++;
        end
        for (lane = 0; lane < 4; lane++) begin
            if (lane_count[lane] != 32) begin
                axil_read(REG_CPLQ_TAIL, cpl_tail);
                `uvm_fatal("CLUSTER_CNM_ADDR_TIMEOUT", $sformatf(
                    "lane0..3 accepted %0d/%0d/%0d/%0d of 32 A/B requests; engine_busy=%07b done=%07b error=%07b cpl_tail=%0d responses=%0d lanes=%b matrix_rsp=%0d cnm_fsm=%0d lane_fsm=%h req=%b ready=%b rsp=%b",
                    lane_count[0], lane_count[1], lane_count[2], lane_count[3],
                    compute_vif.engine_busy, compute_vif.engine_done,
                    compute_vif.engine_error, cpl_tail,
                    compute_vif.cnm_tag_response_count,
                    compute_vif.cnm_response_lane_seen,
                    compute_vif.matrix_tag_response_count,
                    compute_vif.cnm_core_state, compute_vif.cnm_lane_state,
                    compute_vif.cnm_request_valid, compute_vif.cnm_request_ready,
                    compute_vif.cnm_rsp_valid))
            end
        end
        if (matrix_reads == 0)
            `uvm_fatal("CLUSTER_MATRIX_ADDR", "no accepted Matrix banked reads observed during Matrix/CNM overlap window")
        `uvm_info("CLUSTER_CNM_ADDR_PASS", $sformatf("all four CNM lanes accepted expected A/B addresses; Matrix accepted %0d reads within its A/B tile regions", matrix_reads), UVM_LOW)
    endtask

    task body();
        bit [31:0] value;
        bit [31:0] packed_word;
        int unsigned seed;
        int unsigned tile_row;
        int unsigned tile_col;
        int unsigned k_word;
        int unsigned row_lane;
        int unsigned col_lane;
        int unsigned k_lane;
        int unsigned row_idx;
        int unsigned col_idx;
        int unsigned k_idx;
        int signed matrix_a[0:15][0:63];
        int signed matrix_b[0:63][0:31];
        int signed matrix_golden[0:15][0:31];
        int signed line_stall_cnm_golden[0:15];
        int signed gelu_values[0:3];
        int signed gelu_results[0:3];
        int signed accumulator;
        int unsigned word_idx;
        int unsigned engine_idx;
        int unsigned cplq_poll;
        int unsigned pair_i;
        int unsigned pair_j;
        int unsigned pair_index;
        int unsigned pair_poll;
        int unsigned max_active_engines;
        int unsigned c1_k;
        int unsigned c1_row;
        int unsigned c1_col;
        bit cplq_all_engines_idle;
        bit c1_run_started;
        bit c1_run_complete;
        bit [20:0] engine_pair_overlap_seen;
        int unsigned protection_case_count;
        int unsigned fault_order[0:17];
        int unsigned fault_i;
        int unsigned fault_j;
        int unsigned fault_swap;
        int unsigned fault_case_id;
        int unsigned cnm_lane;
        int unsigned cnm_byte;
        int signed cnm_a_value;
        int signed cnm_b_value;
        int unsigned matrix_line_stall_checks_before;
        int unsigned matrix_line_stall_violations_before;
        bit [17:0] fault_cases_seen;
        int unsigned overlap_total;
        int unsigned matrix_prefetch_overlap_total;
        int unsigned matrix_cnm_overlap_total;
        int unsigned cnm_grants_total;
        int unsigned matrix_responses_total;
        int unsigned cnm_responses_total;
        bit [3:0] cnm_lanes_seen_total;
        int unsigned contention_total;
        int unsigned banked_grants_total;
        int unsigned core_grants_total;
        int unsigned serial_matrix_cycles;
        int unsigned serial_cnm_cycles;
        int unsigned serial_sfu0_cycles;
        int unsigned serial_sfu1_cycles;
        int unsigned serial_total_cycles;
        int unsigned serial_matrix_cnm_sfu_cycles;
        int unsigned staged_pair_start_cycle;
        int unsigned staged_pair_cycles;
        int unsigned staged_sfu_start_cycle;
        int unsigned staged_sfu_cycles;
        int unsigned staged_total_cycles;
        int unsigned staged_contention_start;
        int unsigned staged_contention_cycles;
        int unsigned parallel_start_cycle;
        int unsigned parallel_cycles;
        int unsigned parallel_contention_start;
        int unsigned parallel_contention_cycles;
        int unsigned recovery_start_cycle;
        int unsigned recovery_cycles;
        real measured_speedup;
        bit reset_value;
        bit reset_ok;

        if (compute_vif == null)
            `uvm_fatal("CLUSTER_NOVIF", "real compute cluster sequence requires compute_vif")

        mutation_kind = "";
        void'($value$plusargs("CL_MUTATION=%s", mutation_kind));
        seed = 20261025;
        void'($value$plusargs("COMPUTE_CLUSTER_SEED=%d", seed));
        rng_state = seed ^ 32'h7ac4_01d3;
        if (rng_state == 0) rng_state = 32'h1;
        serial_total_cycles = 0;
        serial_matrix_cnm_sfu_cycles = 0;
        staged_pair_cycles = 0;
        staged_sfu_cycles = 0;
        staged_total_cycles = 0;
        staged_contention_cycles = 0;
        parallel_cycles = 0;
        parallel_contention_cycles = 0;
        recovery_cycles = 0;
        measured_speedup = 0.0;
        for (row_idx = 0; row_idx < 16; row_idx++)
            for (k_idx = 0; k_idx < 64; k_idx++)
                matrix_a[row_idx][k_idx] = next_small_signed();
        for (k_idx = 0; k_idx < 64; k_idx++)
            for (col_idx = 0; col_idx < 32; col_idx++)
                matrix_b[k_idx][col_idx] = next_small_signed();

        // The matrix controller consumes 4x4 tile-major operands: each K
        // group is one 128-bit bank row, with four packed lanes per bank.
        for (tile_row = 0; tile_row < 4; tile_row++) begin
            for (k_word = 0; k_word < 16; k_word++) begin
                for (row_lane = 0; row_lane < 4; row_lane++) begin
                    packed_word = '0;
                    for (k_lane = 0; k_lane < 4; k_lane++) begin
                        row_idx = tile_row * 4 + row_lane;
                        k_idx = k_word * 4 + k_lane;
                        packed_word[k_lane*8 +: 8] = matrix_a[row_idx][k_idx];
                    end
                    spad_write(MATRIX_A_LOCAL + ((tile_row * 16 + k_word) << 4) + (row_lane << 2), packed_word);
                end
            end
        end
        for (tile_col = 0; tile_col < 8; tile_col++) begin
            for (k_word = 0; k_word < 16; k_word++) begin
                for (col_lane = 0; col_lane < 4; col_lane++) begin
                    packed_word = '0;
                    for (k_lane = 0; k_lane < 4; k_lane++) begin
                        col_idx = tile_col * 4 + col_lane;
                        k_idx = k_word * 4 + k_lane;
                        packed_word[k_lane*8 +: 8] = matrix_b[k_idx][col_idx];
                    end
                    spad_write(MATRIX_B_LOCAL + ((tile_col * 16 + k_word) << 4) + (col_lane << 2), packed_word);
                end
            end
        end
        for (row_idx = 0; row_idx < 16; row_idx++) begin
            for (col_idx = 0; col_idx < 32; col_idx++) begin
                accumulator = 0;
                for (k_idx = 0; k_idx < 64; k_idx++)
                    accumulator += matrix_a[row_idx][k_idx] * matrix_b[k_idx][col_idx];
                matrix_golden[row_idx][col_idx] = accumulator;
            end
        end

        gelu_values[0] = 16;
        gelu_values[1] = -16;
        gelu_values[2] = 32;
        gelu_values[3] = -32;
        gelu_results[0] = 8;
        gelu_results[1] = -8;
        gelu_results[2] = 17;
        gelu_results[3] = -15;
        for (word_idx = 0; word_idx < 64; word_idx++) begin
            spad_write(GELU_A_LOCAL + (word_idx << 2), gelu_values[word_idx % 4]);
            spad_write(GELU_B_LOCAL + (word_idx << 2), gelu_values[word_idx % 4]);
        end
        for (word_idx = 0; word_idx < 4; word_idx++) begin
            case (word_idx)
                0: packed_word = 32'h0202_0202;
                1: packed_word = 32'h0303_0303;
                2: packed_word = 32'h0404_0404;
                default: packed_word = 32'h0505_0505;
            endcase
            spad_write(CNM_A_LOCAL + (word_idx << 2), packed_word);
        end
        for (row_idx = 0; row_idx < 16; row_idx++) begin
            for (col_idx = 0; col_idx < 4; col_idx++) begin
                case (col_idx)
                    0: packed_word = 32'h0707_0707;
                    1: packed_word = 32'h0b0b_0b0b;
                    2: packed_word = 32'h0d0d_0d0d;
                    default: packed_word = 32'h1111_1111;
                endcase
                spad_write(CNM_B_LOCAL + (row_idx << 4) + (col_idx << 2), packed_word);
            end
        end

        // Keep a strict standalone A-tile reuse baseline before adding CNM
        // contention. The parallel workload below separately checks data
        // integrity while the shared banked port is under contention.
        write_v3_desc(CMDQ_LOCAL, 8'h30, 16'h05ff,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, MATRIX_Y_LOCAL,
                      16'd16, 16'd32, 16'd16);
        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, CMDQ_LOCAL);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd1);
        axil_write(REG_CPLQ_BASE, CPLQ_LOCAL);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        parallel_start_cycle = compute_vif.sim_cycles;
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd1);
        serial_matrix_cycles = compute_vif.sim_cycles - parallel_start_cycle;
        wait_spad_idle();
        expect_completion(CPLQ_LOCAL, 16'h05ff, matrix_golden[15][31],
                          32'd512, "serial Matrix baseline");
        if (compute_vif.matrix_a_cache_hits != 16)
            `uvm_fatal("CLUSTER_A_CACHE_BASELINE", $sformatf(
                "standalone 16x32x64 GEMM expected 16 A-tile cache hits, observed %0d",
                compute_vif.matrix_a_cache_hits))
        for (word_idx = 0; word_idx < 512; word_idx++)
            expect_spad(MATRIX_Y_LOCAL + (word_idx << 2),
                        matrix_golden[word_idx / 32][word_idx % 32],
                        $sformatf("standalone Matrix Golden[%0d]", word_idx));
        `uvm_info("CLUSTER_A_CACHE_BASELINE_PASS",
                  "standalone 16x32x64 Matrix Golden and all 16 A-tile reuse hits passed",
                  UVM_LOW)
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_HEAD, 32'd1);

        // Same four operations as the parallel run, deliberately submitted
        // and retired one at a time. Capture only doorbell-to-completion-tail
        // cycles; descriptor programming is excluded from both measurements.
        write_cnm_v3_desc(CMDQ_LOCAL, 16'h0601,
                          CNM_A_LOCAL, CNM_B_LOCAL, CNM_Y_LOCAL);
        run_serial_descriptor(CMDQ_LOCAL, CPLQ_LOCAL, 16'h0601,
                              32'd736, 32'd16, "serial CNM", serial_cnm_cycles);
        write_v3_desc(CMDQ_LOCAL, 8'h35, 16'h0602,
                      GELU_A_LOCAL, 32'd0, GELU_Y0_LOCAL,
                      16'd0, 16'd0, 16'd64);
        run_serial_descriptor(CMDQ_LOCAL, CPLQ_LOCAL, 16'h0602,
                              -32'sd15, 32'd64, "serial SFU0", serial_sfu0_cycles);
        write_v3_desc(CMDQ_LOCAL, 8'h35, 16'h0603,
                      GELU_B_LOCAL, 32'd0, GELU_Y1_LOCAL,
                      16'd0, 16'd0, 16'd64);
        run_serial_descriptor(CMDQ_LOCAL, CPLQ_LOCAL, 16'h0603,
                              -32'sd15, 32'd64, "serial SFU1", serial_sfu1_cycles);
        serial_total_cycles = serial_matrix_cycles + serial_cnm_cycles +
                              serial_sfu0_cycles + serial_sfu1_cycles;
        serial_matrix_cnm_sfu_cycles = serial_matrix_cycles + serial_cnm_cycles +
                                        serial_sfu0_cycles;
        `uvm_info("CLUSTER_SERIAL_BENCH_PASS", $sformatf(
            "serial Matrix/CNM/SFU cycles=%0d/%0d/%0d total=%0d; extra queued SFU=%0d four-task total=%0d",
            serial_matrix_cycles, serial_cnm_cycles, serial_sfu0_cycles,
            serial_matrix_cnm_sfu_cycles, serial_sfu1_cycles,
            serial_total_cycles), UVM_LOW)

        // Benchmark the requested staged mode: Matrix and CNM share the
        // scratchpad concurrently, then SFU starts after both retire. Sum the
        // two doorbell-to-tail intervals so descriptor-programming time stays
        // outside both the serial and staged measurements.
        write_v3_desc(CMDQ_LOCAL + 32'h00, 8'h30, 16'h0700,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, MATRIX_Y_LOCAL,
                      16'd16, 16'd32, 16'd16);
        write_cnm_v3_desc(CMDQ_LOCAL + 32'h40, 16'h0701,
                          CNM_A_LOCAL, CNM_B_LOCAL, CNM_Y_LOCAL);
        write_v3_desc(CMDQ_LOCAL + 32'h80, 8'h35, 16'h0702,
                      GELU_A_LOCAL, 32'd0, GELU_Y0_LOCAL,
                      16'd0, 16'd0, 16'd64);
        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, CMDQ_LOCAL);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd2);
        axil_write(REG_CPLQ_BASE, CPLQ_LOCAL);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        staged_contention_start = compute_vif.matrix_cnm_shared_accept_cycles;
        staged_pair_start_cycle = compute_vif.sim_cycles;
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd2);
        staged_pair_cycles = compute_vif.sim_cycles - staged_pair_start_cycle;
        staged_contention_cycles = compute_vif.matrix_cnm_shared_accept_cycles -
                                   staged_contention_start;
        if (staged_contention_cycles == 0)
            `uvm_fatal("CLUSTER_STAGED_CONTENTION",
                "Matrix and CNM never contended for a shared banked-SPAD admission during the staged pair")
        wait_spad_idle();
        expect_completion(CPLQ_LOCAL + 32'h00, 16'h0700,
                          matrix_golden[15][31], 32'd512,
                          "staged Matrix completion");
        expect_completion(CPLQ_LOCAL + 32'h10, 16'h0701, 32'd736, 32'd16,
                          "staged CNM completion");
        for (word_idx = 0; word_idx < 512; word_idx++)
            expect_spad(MATRIX_Y_LOCAL + (word_idx << 2),
                        matrix_golden[word_idx / 32][word_idx % 32],
                        $sformatf("staged Matrix Golden[%0d]", word_idx));
        for (word_idx = 0; word_idx < 16; word_idx++)
            expect_spad(CNM_Y_LOCAL + (word_idx << 2), 32'd736,
                        $sformatf("staged CNM Golden[%0d]", word_idx));
        axil_write(REG_CPLQ_HEAD, 32'd2);
        axil_write(REG_CMDQ_TAIL, 32'd3);
        staged_sfu_start_cycle = compute_vif.sim_cycles;
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd3);
        staged_sfu_cycles = compute_vif.sim_cycles - staged_sfu_start_cycle;
        staged_total_cycles = staged_pair_cycles + staged_sfu_cycles;
        wait_spad_idle();
        expect_completion(CPLQ_LOCAL + 32'h20, 16'h0702, -32'sd15, 32'd64,
                          "staged SFU completion");
        for (word_idx = 0; word_idx < 64; word_idx++)
            expect_spad(GELU_Y0_LOCAL + (word_idx << 2),
                        gelu_results[word_idx % 4],
                        $sformatf("staged SFU Golden[%0d]", word_idx));
        measured_speedup = real'(serial_matrix_cnm_sfu_cycles) /
                           real'(staged_total_cycles);
        `uvm_info("CLUSTER_STAGED_BENCH_PASS", $sformatf(
            "serial Matrix/CNM/SFU=%0d cycles; staged Matrix+CNM=%0d then SFU=%0d total=%0d speedup=%.3f pair_contention_cycles=%0d completion_order=0700,0701,0702",
            serial_matrix_cnm_sfu_cycles, staged_pair_cycles,
            staged_sfu_cycles, staged_total_cycles, measured_speedup,
            staged_contention_cycles), UVM_LOW)
        axil_write(REG_CPLQ_HEAD, 32'd3);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);

        // Keep a real CNM banked requester active while the long Matrix GEMM
        // reaches its line-writeback phase.  The two operations use disjoint
        // SPAD regions, so this creates legal arbitration pressure without a
        // read/write dependency or conflicting output ownership.
        for (k_word = 0; k_word < 32; k_word++) begin
            for (cnm_lane = 0; cnm_lane < 4; cnm_lane++) begin
                packed_word = '0;
                for (cnm_byte = 0; cnm_byte < 4; cnm_byte++) begin
                    cnm_a_value = int'(k_word % 5) + int'(cnm_lane * 2) +
                                  int'(cnm_byte) - 5;
                    packed_word[cnm_byte*8 +: 8] = cnm_a_value[7:0];
                end
                spad_write(MATRIX_LINE_STALL_CNM_A_LOCAL +
                           (k_word << 4) + (cnm_lane << 2), packed_word);
            end
        end
        for (row_idx = 0; row_idx < 16; row_idx++) begin
            line_stall_cnm_golden[row_idx] = 0;
            for (k_word = 0; k_word < 32; k_word++) begin
                for (cnm_lane = 0; cnm_lane < 4; cnm_lane++) begin
                    packed_word = '0;
                    for (cnm_byte = 0; cnm_byte < 4; cnm_byte++) begin
                        cnm_a_value = int'(k_word % 5) + int'(cnm_lane * 2) +
                                      int'(cnm_byte) - 5;
                        cnm_b_value = int'(row_idx % 5) + int'(k_word % 3) +
                                      int'(cnm_lane) + int'(cnm_byte) - 3;
                        packed_word[cnm_byte*8 +: 8] = cnm_b_value[7:0];
                        line_stall_cnm_golden[row_idx] +=
                            cnm_a_value * cnm_b_value;
                    end
                    spad_write(MATRIX_LINE_STALL_CNM_B_LOCAL +
                               ((row_idx * 32 + k_word) << 4) +
                               (cnm_lane << 2), packed_word);
                end
            end
        end

        write_v3_desc(CMDQ_LOCAL + 32'h180, 8'h30, 16'h0710,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, MATRIX_Y_LOCAL,
                      16'd16, 16'd32, 16'd16);
        write_cluster_desc(CMDQ_LOCAL + 32'h1c0, 8'h21, 16'h0711,
                           MATRIX_LINE_STALL_CNM_A_LOCAL,
                           MATRIX_LINE_STALL_CNM_B_LOCAL,
                           MATRIX_LINE_STALL_CNM_Y_LOCAL,
                           16'd16, 16'd1, 16'd32, 32'd0,
                           32'd0, 32'd0, 32'd0, 8'd3);
        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, CMDQ_LOCAL + 32'h180);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd2);
        axil_write(REG_CPLQ_BASE, CPLQ_LOCAL + 32'h180);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        matrix_line_stall_checks_before = compute_vif.matrix_line_stall_checks;
        matrix_line_stall_violations_before =
            compute_vif.matrix_line_stall_violations;
        parallel_start_cycle = compute_vif.sim_cycles;
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd2);
        parallel_cycles = compute_vif.sim_cycles - parallel_start_cycle;
        wait_spad_idle();
        if ((compute_vif.matrix_line_stall_checks -
             matrix_line_stall_checks_before) == 0)
            `uvm_fatal("CLUSTER_MATRIX_LINE_STALL",
                "legal Matrix/CNM overlap did not exercise Matrix line-write backpressure")
        if ((compute_vif.matrix_line_stall_violations -
             matrix_line_stall_violations_before) != 0)
            `uvm_fatal("CLUSTER_MATRIX_LINE_STALL",
                "Matrix line payload changed while the shared SPAD arbiter denied acceptance")
        for (word_idx = 0; word_idx < 512; word_idx++)
            expect_spad(MATRIX_Y_LOCAL + (word_idx << 2),
                        matrix_golden[word_idx / 32][word_idx % 32],
                        $sformatf("line-stalled Matrix Golden[%0d]", word_idx));
        for (row_idx = 0; row_idx < 16; row_idx++)
            expect_spad(MATRIX_LINE_STALL_CNM_Y_LOCAL + (row_idx << 2),
                        line_stall_cnm_golden[row_idx],
                        $sformatf("line-stalled CNM Golden[%0d]", row_idx));
        expect_completion(CPLQ_LOCAL + 32'h180, 16'h0710,
                          matrix_golden[15][31], 32'd512,
                          "line-stalled Matrix");
        expect_completion(CPLQ_LOCAL + 32'h190, 16'h0711,
                          line_stall_cnm_golden[15], 32'd16,
                          "line-stalled CNM");
        `uvm_info("CLUSTER_MATRIX_LINE_STALL_PASS", $sformatf(
            "legal 16x32x64 Matrix + 16x32 CNM overlap; Matrix line stability checks=%0d violations=%0d; overlap_cycles=%0d; outputs and ordered completions match independent Golden",
            compute_vif.matrix_line_stall_checks -
                matrix_line_stall_checks_before,
            compute_vif.matrix_line_stall_violations -
                matrix_line_stall_violations_before,
            parallel_cycles), UVM_LOW)
        axil_write(REG_CPLQ_HEAD, 32'd2);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);

        write_v3_desc(CMDQ_LOCAL + 32'h00, 8'h30, 16'h0600,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, MATRIX_Y_LOCAL,
                      16'd16, 16'd32, 16'd16);
        write_cnm_v3_desc(CMDQ_LOCAL + 32'h40, 16'h0601,
                          CNM_A_LOCAL, CNM_B_LOCAL, CNM_Y_LOCAL);
        write_v3_desc(CMDQ_LOCAL + 32'h80, 8'h35, 16'h0602,
                      GELU_A_LOCAL, 32'd0, GELU_Y0_LOCAL,
                      16'd0, 16'd0, 16'd64);
        write_v3_desc(CMDQ_LOCAL + 32'hc0, 8'h35, 16'h0603,
                      GELU_B_LOCAL, 32'd0, GELU_Y1_LOCAL,
                      16'd0, 16'd0, 16'd64);

        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, CMDQ_LOCAL);
        // The command ring also reserves one slot to distinguish full from
        // empty, so four outstanding descriptors need an eight-entry ring.
        axil_write(REG_CMDQ_SIZE, 32'd8);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd4);
        axil_write(REG_CPLQ_BASE, CPLQ_LOCAL);
        // This ring keeps one entry empty to distinguish full from empty.
        // Four ordered completions therefore need an eight-entry ring.
        axil_write(REG_CPLQ_SIZE, 32'd8);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        parallel_contention_start = compute_vif.shared_spad_contention_cycles;
        parallel_start_cycle = compute_vif.sim_cycles;
        axil_write(REG_DOORBELL, 32'd1);
        check_cnm_address_stream();
        wait_cpl_tail(32'd4);
        parallel_cycles = compute_vif.sim_cycles - parallel_start_cycle;
        parallel_contention_cycles = compute_vif.shared_spad_contention_cycles -
                                     parallel_contention_start;
        wait_spad_idle();
        if (parallel_cycles != 0)
            measured_speedup = real'(serial_total_cycles) / real'(parallel_cycles);
        `uvm_info("CLUSTER_PARALLEL_BENCH_PASS", $sformatf(
            "same Matrix/CNM/SFU/SFU work parallel cycles=%0d serial_cycles=%0d speedup=%.3f completion_order=0600,0601,0602,0603 shared_spad_contention_cycles=%0d",
            parallel_cycles, serial_total_cycles, measured_speedup,
            parallel_contention_cycles), UVM_LOW)

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
        run_shared_readonly_isolation_test();
        check_request_stability();
        run_engine_abort_drain_sweep();
        run_sfu_abort_write_prefix(seed);
        run_conv_abort_write_prefix(seed);
        run_kv_abort_write_prefix(seed);
        run_matrix_abort_write_prefix(seed);
        run_matrix_line_abort_write_prefix(seed);
        run_cnm_abort_write_prefix(seed);
        run_engine_reset_drain_sweep();
        run_engine_parity_reset_sweep(seed);
        run_matrix_parity_reset_epoch_case(seed);

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
