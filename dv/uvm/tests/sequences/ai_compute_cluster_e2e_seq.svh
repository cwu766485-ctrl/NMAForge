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

    localparam bit [31:0] CMDQ_LOCAL = 32'h0000_4000;
    localparam bit [31:0] CPLQ_LOCAL = 32'h0000_5000;
    localparam bit [31:0] MATRIX_A_LOCAL = 32'h0001_0000;
    localparam bit [31:0] MATRIX_B_LOCAL = 32'h0001_2000;
    localparam bit [31:0] MATRIX_Y_LOCAL = 32'h0003_0000;
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

    virtual ai_compute_cluster_if compute_vif;
    bit [31:0] rng_state;

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
        if (actual !== expected)
            `uvm_fatal("CLUSTER_GOLDEN", $sformatf("%s addr=0x%08h expected=0x%08h actual=0x%08h", tag, addr, expected, actual))
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
        end else begin
            fault_engine = 3; // BF16 dot
            fault_phase = case_id - 12;
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
                opcode = 8'h50;
                src0 = FP_A_LOCAL;
                src1 = FP_B_LOCAL;
                fault_addr = fault_phase ? src1 : src0;
                write_cluster_desc(desc_addr, opcode, 16'h0700 + case_id,
                                   src0, src1, dst, 16'd1, 16'd1, 16'd2,
                                   32'd0, 32'd0, 32'd0, 32'd0, 8'd7);
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

        expect_spad(cpl_addr + 32'h00, 32'h0000_0700 + case_id,
                    $sformatf("random parity case%0d task ID", case_id));
        expect_spad(cpl_addr + 32'h04, 32'h0000_0052,
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
            "engine stalled mask=%07b cycles={%0d,%0d,%0d,%0d,%0d,%0d,%0d}; Matrix banked checks=%0d, Matrix line checks=%0d, CNM lane checks={%0d,%0d,%0d,%0d}",
            compute_vif.engine_req_stall_seen,
            compute_vif.engine_req_stall_cycles[0], compute_vif.engine_req_stall_cycles[1],
            compute_vif.engine_req_stall_cycles[2], compute_vif.engine_req_stall_cycles[3],
            compute_vif.engine_req_stall_cycles[4], compute_vif.engine_req_stall_cycles[5],
            compute_vif.engine_req_stall_cycles[6],
            compute_vif.matrix_banked_stall_checks,
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
        int signed gelu_values[0:3];
        int signed gelu_results[0:3];
        int signed accumulator;
        int unsigned word_idx;
        int unsigned engine_idx;
        int unsigned fault_order[0:13];
        int unsigned fault_i;
        int unsigned fault_j;
        int unsigned fault_swap;
        int unsigned fault_case_id;
        bit [13:0] fault_cases_seen;
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

        // C1 real-top sweep: issue one descriptor for every physical engine
        // in one queue window. The work areas are disjoint so concurrent
        // access tests arbitration without relying on undefined SPAD races.
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
        for (word_idx = 0; word_idx < 4; word_idx++) begin
            spad_write(KV_VECTOR_LOCAL + (word_idx << 2), (word_idx + 1) * 32'h100);
            spad_write(KV_CACHE_LOCAL + 32'h50 + (word_idx << 2), 32'hbad0_6400 + word_idx);
        end

        write_v3_desc(CLUSTER_SWEEP_CMDQ + 32'h000, 8'h30, 16'h0640,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, SWEEP_MATRIX_Y_LOCAL,
                      16'd16, 16'd32, 16'd16);
        write_cnm_v3_desc(CLUSTER_SWEEP_CMDQ + 32'h040, 16'h0641,
                          CNM_A_LOCAL, CNM_B_LOCAL, SWEEP_CNM_Y_LOCAL);
        write_v3_desc(CLUSTER_SWEEP_CMDQ + 32'h080, 8'h35, 16'h0642,
                      GELU_A_LOCAL, 32'd0, SWEEP_SFU_Y_LOCAL,
                      16'd0, 16'd0, 16'd4);
        write_cluster_desc(CLUSTER_SWEEP_CMDQ + 32'h0c0, 8'h10, 16'h0643,
                           SCALAR_A_LOCAL, SCALAR_B_LOCAL, SCALAR_Y_LOCAL,
                           16'd0, 16'd0, 16'd1, 32'd0,
                           32'd0, 32'd0, 32'd0, 8'd3);
        write_cluster_desc(CLUSTER_SWEEP_CMDQ + 32'h100, 8'h50, 16'h0644,
                           FP_A_LOCAL, FP_B_LOCAL, FP_Y_LOCAL,
                           16'd1, 16'd1, 16'd2, 32'd0,
                           32'd0, 32'd0, 32'd0, 8'd7);
        write_cluster_desc(CLUSTER_SWEEP_CMDQ + 32'h140, 8'h16, 16'h0645,
                           CONV_A_LOCAL, CONV_W_LOCAL, CONV_Y_LOCAL,
                           16'd3, 16'd3, 16'd9, 32'd0,
                           32'd0, 32'd0, 32'd0, 8'd5);
        write_cluster_desc(CLUSTER_SWEEP_CMDQ + 32'h180, 8'h43, 16'h0646,
                           KV_VECTOR_LOCAL, 32'd0, KV_CACHE_LOCAL,
                           16'd0, 16'd0, 16'd4, {16'd1,16'd1},
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
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd7);
        wait_spad_idle();

        for (word_idx = 0; word_idx < 512; word_idx++)
            expect_spad(SWEEP_MATRIX_Y_LOCAL + (word_idx << 2),
                        matrix_golden[word_idx / 32][word_idx % 32],
                        $sformatf("C1 Matrix Golden[%0d]", word_idx));
        for (word_idx = 0; word_idx < 16; word_idx++)
            expect_spad(SWEEP_CNM_Y_LOCAL + (word_idx << 2), 32'd736,
                        $sformatf("C1 CNM Golden[%0d]", word_idx));
        for (word_idx = 0; word_idx < 4; word_idx++) begin
            expect_spad(SWEEP_SFU_Y_LOCAL + (word_idx << 2), gelu_results[word_idx],
                        $sformatf("C1 SFU Golden[%0d]", word_idx));
            expect_spad(KV_CACHE_LOCAL + 32'h50 + (word_idx << 2),
                        (word_idx + 1) * 32'h100,
                        $sformatf("C1 KV write Golden[%0d]", word_idx));
        end
        expect_spad(SCALAR_Y_LOCAL, 32'd70, "C1 scalar INT8 VDOT Golden");
        expect_spad(FP_Y_LOCAL, 32'h4130_0000, "C1 BF16 dot Golden");
        expect_spad(CONV_Y_LOCAL, 32'd45, "C1 CONV3x3 Golden");
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h00, 16'h0640,
                          matrix_golden[15][31], 32'd512, "C1 Matrix");
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h10, 16'h0641,
                          32'd736, 32'd16, "C1 CNM");
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h20, 16'h0642,
                          -32'sd15, 32'd4, "C1 SFU");
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h30, 16'h0643,
                          32'd70, 32'd1, "C1 scalar INT8");
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h40, 16'h0644,
                          32'h4130_0000, 32'd2, "C1 BF16");
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h50, 16'h0645,
                          32'd45, 32'd1, "C1 CONV3x3");
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h60, 16'h0646,
                          32'h0000_0400, 32'd4, "C1 KV write");
        for (engine_idx = 0; engine_idx < 7; engine_idx++) begin
            if (compute_vif.engine_launch_count[engine_idx] == 0)
                `uvm_fatal("CLUSTER_ENGINE_COVERAGE", $sformatf(
                    "real top did not launch engine %0d", engine_idx))
        end
        if (compute_vif.engine_backpressure_cycles == 0 ||
            compute_vif.engine_backpressure_seen == 0)
            `uvm_fatal("CLUSTER_ENGINE_BACKPRESSURE", "no engine request was denied by the shared compute SPAD mux")
        `uvm_info("CLUSTER_ALL_ENGINES_PASS", $sformatf(
                  "all seven production engines launched and matched SPAD Golden; compute-request backpressure cycles=%0d stalled-engine-mask=%07b",
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
        // the complete four-word payload.
        write_cluster_desc(CLUSTER_SWEEP_CMDQ, 8'h44, 16'h0647,
                           KV_CACHE_LOCAL, 32'd0, KV_READ_LOCAL,
                           16'd0, 16'd0, 16'd4, {16'd1,16'd1},
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
        for (word_idx = 0; word_idx < 4; word_idx++)
            expect_spad(KV_READ_LOCAL + (word_idx << 2),
                        (word_idx + 1) * 32'h100,
                        $sformatf("C1 KV read Golden[%0d]", word_idx));
        expect_completion(CLUSTER_SWEEP_CPLQ + 32'h100, 16'h0647,
                          32'h0000_0400, 32'd4, "C1 KV read");
        axil_write(REG_CPLQ_HEAD, 32'd1);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);

        // Seeded randomized ordering of a complete parity fault cross:
        // INT8, Matrix, CNM (all four lanes), and BF16; A/B operand phase;
        // every failed operation must retire ERR_PARITY without writeback.
        for (word_idx = 0; word_idx < 4; word_idx++) begin
            spad_write(MATRIX_FAULT_A_LOCAL + (word_idx << 2),
                       32'h1100_0000 | word_idx);
            spad_write(MATRIX_FAULT_B_LOCAL + (word_idx << 2),
                       32'h2200_0000 | word_idx);
        end
        for (fault_i = 0; fault_i < 14; fault_i++) fault_order[fault_i] = fault_i;
        for (fault_i = 13; fault_i > 0; fault_i--) begin
            rng_state = rng_state ^ (rng_state << 13);
            rng_state = rng_state ^ (rng_state >> 17);
            rng_state = rng_state ^ (rng_state << 5);
            fault_j = rng_state % (fault_i + 1);
            fault_swap = fault_order[fault_i];
            fault_order[fault_i] = fault_order[fault_j];
            fault_order[fault_j] = fault_swap;
        end
        fault_cases_seen = '0;
        for (fault_i = 0; fault_i < 14; fault_i++) begin
            fault_case_id = fault_order[fault_i];
            if (fault_cases_seen[fault_case_id])
                `uvm_fatal("CLUSTER_FAULT_CROSS", $sformatf("duplicate randomized fault case=%0d", fault_case_id))
            fault_cases_seen[fault_case_id] = 1'b1;
            run_random_parity_case(fault_case_id, seed);
        end
        if (fault_cases_seen !== 14'h3fff)
            `uvm_fatal("CLUSTER_FAULT_CROSS", $sformatf("fault cross incomplete: seen=%h", fault_cases_seen))
        `uvm_info("CLUSTER_RANDOM_FAULT_CROSS_PASS", $sformatf(
            "parity cases=14/14; engines={INT8,Matrix,CNM,BF16}; operand phases={A,B}; CNM lanes=4/4; randomized_order_seed=%0d",
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
        run_launch_snapshot_and_unused_fields_test();
        run_inflight_parameter_latch_test();
        run_shared_readonly_isolation_test();
        check_request_stability();
        run_engine_reset_drain_sweep();

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
