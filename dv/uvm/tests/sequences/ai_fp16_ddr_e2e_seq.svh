class ai_fp16_ddr_e2e_seq extends uvm_sequence #(ai_axil_item);
    `uvm_object_utils(ai_fp16_ddr_e2e_seq)

    localparam bit [31:0] DDR_A_ADDR = 32'h0000_1a00;
    localparam bit [31:0] DDR_B_ADDR = 32'h0000_1a10;
    localparam bit [31:0] DDR_Y_ADDR = 32'h0000_1a20;
    localparam bit [31:0] DDR_BF16_A_ADDR = 32'h0000_1a30;
    localparam bit [31:0] DDR_BF16_B_ADDR = 32'h0000_1a40;
    localparam bit [31:0] DDR_BF16_Y_ADDR = 32'h0000_1a50;
    localparam bit [31:0] DDR_INT8_A_ADDR = 32'h0000_1a60;
    localparam bit [31:0] DDR_INT8_B_ADDR = 32'h0000_1a70;
    localparam bit [31:0] DDR_INT8_Y_ADDR = 32'h0000_1a80;
    localparam bit [31:0] DDR_ERROR_ADDR = 32'h0000_1a90;
    localparam bit [31:0] DDR_ERROR_LAST_BEAT_ADDR = 32'h0000_1ab0;
    localparam bit [31:0] DDR_RESET_PROBE_ADDR = 32'h0000_1aa0;
    localparam bit [31:0] DDR_RESET_RECOVERY_ADDR = 32'h0000_1ad0;
    localparam bit [31:0] SPAD_A_ADDR = 32'h0000_7f00;
    localparam bit [31:0] SPAD_B_ADDR = 32'h0000_7f10;
    localparam bit [31:0] SPAD_Y_ADDR = 32'h0000_7f20;
    localparam bit [31:0] SPAD_BF16_A_ADDR = 32'h0000_7f30;
    localparam bit [31:0] SPAD_BF16_B_ADDR = 32'h0000_7f40;
    localparam bit [31:0] SPAD_BF16_Y_ADDR = 32'h0000_7f50;
    localparam bit [31:0] SPAD_INT8_A_ADDR = 32'h0000_7f60;
    localparam bit [31:0] SPAD_INT8_B_ADDR = 32'h0000_7f64;
    localparam bit [31:0] SPAD_INT8_Y_ADDR = 32'h0000_7f68;
    localparam bit [31:0] SPAD_BAD_Y_ADDR = 32'h0000_7d00;
    localparam bit [31:0] SPAD_ERROR_SENTINEL_ADDR = 32'h0000_7d04;
    localparam bit [31:0] SPAD_ERROR_LAST_BEAT_ADDR = 32'h0000_7d24;
    localparam bit [31:0] CMDQ_ADDR = 32'h0000_7e00;
    // Three descriptors occupy 0x7e00..0x7ebf; keep completions disjoint.
    // Keep CMDQ slot 3 (0x7ec0..0x7eff) available for the invalid-descriptor
    // wrap test; completion slot 3 is at CPLQ_ADDR + 0x30.
    localparam bit [31:0] CPLQ_ADDR = 32'h0000_7f80;
    localparam bit [31:0] CIMFORGE_REG_ERROR = 32'h0000_0030;
    localparam bit [31:0] CIMFORGE_REG_DMA_ERROR = 32'h0000_00c4;
    ai_mixed_precision_vector_plan vector_plan;
    ai_accel_reference_model reference_model;
    bit coverage_sample_valid;
    bit active_compute_reset_checked;
    bit active_dma_reset_checked;
    bit independent_ddr_reset_recovery_checked;
    bit fp_watchdog_completion_checked;
    bit fp_abort_completion_checked;
    bit axi_stalls_enabled;
    bit axi_transaction_jitter_enabled;

    task automatic apply_axi_stall_config(input string phase_name);
        uvm_hdl_data_t cfg;
        bit ok;
        if (!axi_stalls_enabled) return;
        cfg = '0;
        cfg[31:0] = vector_plan.axi_read_gap;
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.read_gap_cfg", cfg);
        if (!ok) `uvm_fatal("MIXED_E2E_AXI_STALL", "failed to deposit AXI read_gap_cfg")
        cfg = '0;
        cfg[31:0] = vector_plan.axi_ready_gap;
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.ready_gap_cfg", cfg);
        if (!ok) `uvm_fatal("MIXED_E2E_AXI_STALL", "failed to deposit AXI ready_gap_cfg")
        cfg = '0;
        cfg[31:0] = vector_plan.axi_ar_gap;
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.arready_gap_cfg", cfg);
        if (!ok) `uvm_fatal("MIXED_E2E_AXI_STALL", "failed to deposit AXI arready_gap_cfg")
        cfg = '0;
        cfg[31:0] = vector_plan.axi_aw_gap;
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.awready_gap_cfg", cfg);
        if (!ok) `uvm_fatal("MIXED_E2E_AXI_STALL", "failed to deposit AXI awready_gap_cfg")
        cfg = '0;
        cfg[31:0] = axi_transaction_jitter_enabled;
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.transaction_jitter_enable", cfg);
        if (!ok) `uvm_fatal("MIXED_E2E_AXI_STALL", "failed to deposit AXI transaction_jitter_enable")
        `uvm_info("MIXED_E2E_AXI_STALL", $sformatf("phase=%s ar_gap_cfg=%0d aw_gap_cfg=%0d read_gap_cfg=%0d ready_gap_cfg=%0d txn_jitter=%0b", phase_name, vector_plan.axi_ar_gap, vector_plan.axi_aw_gap, vector_plan.axi_read_gap, vector_plan.axi_ready_gap, axi_transaction_jitter_enabled), UVM_LOW)
    endtask

    function new(string name = "ai_fp16_ddr_e2e_seq");
        super.new(name);
    endfunction

    task automatic axil_write(input bit [31:0] addr, input bit [31:0] data);
        ai_axil_item req;
        req = ai_axil_item::type_id::create("axil_write_req");
        start_item(req);
        req.is_write = 1'b1;
        req.addr = addr;
        req.data = data;
        req.strb = 4'hf;
        finish_item(req);
        if (req.resp != 2'b00)
            `uvm_error("FP16_E2E_AXIL", $sformatf("write addr=0x%08h resp=%0h", addr, req.resp))
    endtask

    task automatic axil_read(input bit [31:0] addr, output bit [31:0] data);
        ai_axil_item req;
        req = ai_axil_item::type_id::create("axil_read_req");
        start_item(req);
        req.is_write = 1'b0;
        req.addr = addr;
        req.data = '0;
        req.strb = '0;
        finish_item(req);
        data = req.rdata;
        if (req.resp != 2'b00)
            `uvm_error("FP16_E2E_AXIL", $sformatf("read addr=0x%08h resp=%0h", addr, req.resp))
    endtask

    task automatic require_hdl_zero(input string path, input string description);
        uvm_hdl_data_t hdl_value;
        bit ok;
        hdl_value = '0;
        ok = uvm_hdl_read(path, hdl_value);
        if (!ok || hdl_value[31:0] !== 32'd0)
            `uvm_fatal("MIXED_E2E_RESET_IDLE", $sformatf("expected idle %s at %s, read_ok=%0b value=0x%0h", description, path, ok, hdl_value))
    endtask

    task automatic run_dma_outstanding_reset_check();
        uvm_hdl_data_t hdl_value;
        bit ok;
        bit read_accepted;
        bit reset_check_ok;
        bit [31:0] value;
        int unsigned poll;

        // This is an explicit coordinated reset of the accelerator and the
        // external responder, used only to clear an accepted in-flight AR.
        axil_write(CIMFORGE_SPAD_BASE + SPAD_ERROR_SENTINEL_ADDR, 32'hdeed_cafe);
        hdl_value = '0;
        hdl_value[31:0] = 0;
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.transaction_jitter_enable", hdl_value);
        if (!ok) `uvm_fatal("MIXED_E2E_DMA_RESET", "failed to disable AXI transaction jitter for deterministic reset probe")
        hdl_value = '0;
        hdl_value[31:0] = 3;
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.read_gap_cfg", hdl_value);
        if (!ok) `uvm_fatal("MIXED_E2E_DMA_RESET", "failed to force delayed AXI R response")

        axil_write(CIMFORGE_REG_DMA_EXT_ADDR, DDR_RESET_PROBE_ADDR);
        axil_write(CIMFORGE_REG_DMA_SPAD_ADDR, SPAD_ERROR_SENTINEL_ADDR);
        axil_write(CIMFORGE_REG_DMA_LENGTH, 32'd1);
        axil_write(CIMFORGE_REG_DMA_CTRL, 32'd1);

        read_accepted = 1'b0;
        for (poll = 0; poll < 2000; poll++) begin
            #1;
            hdl_value = '0;
            ok = uvm_hdl_read("tb_ai_accel_uvm.axi_mem_u.read_active_r", hdl_value);
            if (!ok) `uvm_fatal("MIXED_E2E_DMA_RESET", "failed to observe accepted AXI read")
            if (hdl_value[0] !== 1'b1) continue;

            hdl_value = '0;
            ok = uvm_hdl_read("tb_ai_accel_uvm.axi_mem_u.read_addr_r", hdl_value);
            if (!ok) `uvm_fatal("MIXED_E2E_DMA_RESET", "failed to observe outstanding AXI read address")
            if (hdl_value[63:0] !== {32'd0, DDR_RESET_PROBE_ADDR}) continue;

            hdl_value = '0;
            ok = uvm_hdl_read("tb_ai_accel_uvm.axi_mem_u.rvalid", hdl_value);
            if (!ok) `uvm_fatal("MIXED_E2E_DMA_RESET", "failed to observe AXI RVALID")
            if (hdl_value[0] !== 1'b0) continue;

            hdl_value = '0;
            ok = uvm_hdl_read("tb_ai_accel_uvm.axi_mem_u.read_gap_r", hdl_value);
            if (!ok) `uvm_fatal("MIXED_E2E_DMA_RESET", "failed to observe delayed AXI response gap")
            if (hdl_value[1:0] != 0) begin
                hdl_value = '0;
                ok = uvm_hdl_read("tb_ai_accel_uvm.dut.dma_busy", hdl_value);
                if (!ok) `uvm_fatal("MIXED_E2E_DMA_RESET", "failed to observe active DMA")
                read_accepted = (hdl_value[0] === 1'b1);
                if (read_accepted) break;
            end
        end
        if (!read_accepted)
            `uvm_fatal("MIXED_E2E_DMA_RESET", "DMA did not reach accepted-AR / delayed-R / busy state")

        `uvm_info("MIXED_E2E_DMA_RESET_ARMED", "DMA AR accepted; response is delayed (RVALID=0) before coordinated reset", UVM_LOW)
        hdl_value = '0;
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", hdl_value);
        if (!ok) `uvm_fatal("MIXED_E2E_DMA_RESET", "failed to assert coordinated system reset")
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.ddr_resetn", hdl_value);
        if (!ok) `uvm_fatal("MIXED_E2E_DMA_RESET", "failed to assert external DDR model reset")
        #60;
        hdl_value = '1;
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", hdl_value);
        if (!ok) `uvm_fatal("MIXED_E2E_DMA_RESET", "failed to release coordinated system reset")
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.ddr_resetn", hdl_value);
        if (!ok) `uvm_fatal("MIXED_E2E_DMA_RESET", "failed to release external DDR model reset")
        #60;

        reset_check_ok = 1'b1;
        hdl_value = '0;
        ok = uvm_hdl_read("tb_ai_accel_uvm.axi_mem_u.read_active_r", hdl_value);
        if (!ok || hdl_value[0] !== 1'b0) begin
            reset_check_ok = 1'b0;
            `uvm_error("MIXED_E2E_DMA_RESET", "AXI memory-model active read did not clear on coordinated reset")
        end
        hdl_value = '0;
        ok = uvm_hdl_read("tb_ai_accel_uvm.axi_mem_u.read_q_count_r", hdl_value);
        if (!ok || hdl_value[2:0] !== 3'd0) begin
            reset_check_ok = 1'b0;
            `uvm_error("MIXED_E2E_DMA_RESET", "AXI memory-model queued reads did not clear on coordinated reset")
        end
        hdl_value = '0;
        ok = uvm_hdl_read("tb_ai_accel_uvm.axi_mem_u.rvalid", hdl_value);
        if (!ok || hdl_value[0] !== 1'b0) begin
            reset_check_ok = 1'b0;
            `uvm_error("MIXED_E2E_DMA_RESET", "AXI RVALID remained asserted after coordinated reset")
        end
        hdl_value = '0;
        ok = uvm_hdl_read("tb_ai_accel_uvm.dut.dma_busy", hdl_value);
        if (!ok || hdl_value[0] !== 1'b0) begin
            reset_check_ok = 1'b0;
            `uvm_error("MIXED_E2E_DMA_RESET", "DMA did not return idle after coordinated reset")
        end

        axil_read(CIMFORGE_REG_DMA_STATUS, value);
        if (value !== 32'd0) begin
            reset_check_ok = 1'b0;
            `uvm_error("MIXED_E2E_DMA_RESET", $sformatf("DMA_STATUS after reset expected zero actual=0x%08h", value))
        end
        axil_read(CIMFORGE_SPAD_BASE + SPAD_ERROR_SENTINEL_ADDR, value);
        if (value !== 32'hdeed_cafe) begin
            reset_check_ok = 1'b0;
            `uvm_error("MIXED_E2E_DMA_RESET", $sformatf("in-flight DMA read modified destination: expected sentinel=0xdeedcafe actual=0x%08h", value))
        end

        apply_axi_stall_config("post_dma_reset");
        active_dma_reset_checked = reset_check_ok;
        if (reset_check_ok)
            `uvm_info("MIXED_E2E_DMA_RESET_PASS", "accepted DMA read was reset before R; coordinated DUT/AXI-model reset returned idle and preserved the SPAD sentinel", UVM_LOW)
    endtask

    task automatic run_ddr_alive_after_accel_reset_check();
        uvm_hdl_data_t hdl_value;
        bit ok;
        bit [31:0] value;

        // The preceding active-compute reset asserted only the accelerator
        // reset. Prove the independent DDR responder stayed out of reset and
        // still services a real DMA read after the accelerator recovers.
        hdl_value = '0;
        ok = uvm_hdl_read("tb_ai_accel_uvm.ddr_resetn", hdl_value);
        if (!ok || hdl_value[0] !== 1'b1)
            `uvm_fatal("MIXED_E2E_DDR_RESET", "external DDR model was not kept active during accelerator-only reset")

        axil_write(CIMFORGE_SPAD_BASE + SPAD_ERROR_SENTINEL_ADDR, 32'hdada_5511);
        dma_transfer(DDR_RESET_RECOVERY_ADDR, SPAD_ERROR_SENTINEL_ADDR, 1, 1'b0);
        axil_read(CIMFORGE_SPAD_BASE + SPAD_ERROR_SENTINEL_ADDR, value);
        if (value !== 32'hdada_5511) begin
            `uvm_error("MIXED_E2E_DDR_RESET", $sformatf("DDR read after accelerator-only reset expected=0xdada5511 actual=0x%08h", value))
        end else begin
            independent_ddr_reset_recovery_checked = 1'b1;
            `uvm_info("MIXED_E2E_DDR_INDEPENDENT_RESET_PASS", "accelerator reset did not reset external DDR model; post-reset DMA read returned the retained DDR operand", UVM_LOW)
        end
    endtask

    function automatic bit [31:0] layout_spad_addr(input bit [31:0] base_addr);
        return base_addr + (vector_plan.spad_layout * 4);
    endfunction

    task automatic dma_transfer(
        input bit [31:0] ddr_addr,
        input bit [31:0] spad_addr,
        input int unsigned word_count,
        input bit store_to_ddr
    );
        bit [31:0] dma_status;
        bit completed;
        int unsigned poll;

        axil_write(CIMFORGE_REG_DMA_EXT_ADDR, ddr_addr);
        axil_write(CIMFORGE_REG_DMA_SPAD_ADDR, spad_addr);
        axil_write(CIMFORGE_REG_DMA_LENGTH, word_count);
        axil_write(CIMFORGE_REG_DMA_CTRL, store_to_ddr ? 32'd3 : 32'd1);

        completed = 1'b0;
        for (poll = 0; poll < 2000; poll++) begin
            axil_read(CIMFORGE_REG_DMA_STATUS, dma_status);
            if (dma_status[2]) begin
                `uvm_error("FP16_E2E_DMA", $sformatf("DMA error status=0x%08h ext=0x%08h spad=0x%08h", dma_status, ddr_addr, spad_addr))
                break;
            end
            if (dma_status[1]) begin
                completed = 1'b1;
                break;
            end
        end
        if (!completed)
            `uvm_fatal("FP16_E2E_DMA", $sformatf("DMA timeout ext=0x%08h spad=0x%08h store=%0b", ddr_addr, spad_addr, store_to_ddr))
        else
            axil_write(CIMFORGE_REG_DMA_STATUS, 32'd2);
    endtask

    task automatic write_dot_descriptor(
        input bit [31:0] desc_addr,
        input bit [15:0] task_id,
        input bit [7:0] opcode,
        input bit [31:0] src0_addr,
        input bit [31:0] src1_addr,
        input bit [31:0] dst_addr,
        input int unsigned length
    );
        bit [31:0] desc [0:15];
        int unsigned i;

        // ABI v7 descriptor for a 1x1 dot. FP dot length counts 16-bit
        // elements (K=1..4); INT8 VDOT length counts packed 32-bit words.
        desc[0]  = {task_id, 8'd0, opcode};
        desc[1]  = src0_addr;
        desc[2]  = src1_addr;
        desc[3]  = 32'd0;
        desc[4]  = dst_addr;
        desc[5]  = 32'h0001_0001;
        desc[6]  = length;
        desc[7]  = 32'd0;
        desc[8]  = 32'd0;
        desc[9]  = 32'd0;
        desc[10] = 32'd0;
        desc[11] = 32'd0;
        desc[12] = 32'd0;
        desc[13] = 32'd0;
        desc[14] = 32'd0;
        desc[15] = 32'd7;

        for (i = 0; i < 16; i++)
            axil_write(CIMFORGE_SPAD_BASE + desc_addr + (i * 4), desc[i]);
    endtask

    function automatic string invalid_descriptor_case_name(input int unsigned case_id);
        case (case_id)
            0: return "opcode";
            1: return "version";
            2: return "dimensions";
            3: return "alignment";
            4: return "fp_stride";
            5: return "fp_flags";
            default: return "unknown";
        endcase
    endfunction

    task automatic write_invalid_descriptor(
        input bit [31:0] desc_addr,
        input bit [15:0] task_id,
        input int unsigned case_id
    );
        bit [31:0] desc [0:15];
        int unsigned i;

        // Start from a valid FP16 dot descriptor, then violate exactly one
        // validator rule so each negative test has a single clear cause.
        desc[0]  = {task_id, 8'd0, 8'h51};
        desc[1]  = layout_spad_addr(SPAD_A_ADDR);
        desc[2]  = layout_spad_addr(SPAD_B_ADDR);
        desc[3]  = 32'd0;
        desc[4]  = layout_spad_addr(SPAD_Y_ADDR);
        desc[5]  = 32'h0001_0001;
        desc[6]  = 32'd1;
        desc[7]  = 32'd0;
        desc[8]  = 32'd0;
        desc[9]  = 32'd0;
        desc[10] = 32'd0;
        desc[11] = 32'd0;
        desc[12] = 32'd0;
        desc[13] = 32'd0;
        desc[14] = 32'd0;
        desc[15] = 32'd7;

        case (case_id)
            0: desc[0][7:0] = 8'hff;       // Unsupported opcode.
            1: desc[15][7:0] = 8'd6;       // FP dot requires ABI v7.
            2: desc[6][15:0] = 16'd0;      // FP dot length must be non-zero.
            3: desc[1] = layout_spad_addr(SPAD_A_ADDR) + 32'd2; // All FP dot addresses are 4-byte aligned.
            4: desc[10] = 32'd4;            // P0 FP dot does not support strides.
            5: desc[7] = 32'h0000_0002;     // P0 FP dot does not support transpose flags.
            default: `uvm_fatal("MIXED_E2E_BAD_DESC", $sformatf("invalid descriptor case %0d", case_id))
        endcase

        for (i = 0; i < 16; i++)
            axil_write(CIMFORGE_SPAD_BASE + desc_addr + (i * 4), desc[i]);
    endtask

    task automatic enqueue_dot_command_batch();
        bit [31:0] value;
        bit [31:0] expected_fp16;
        bit [31:0] expected_bf16;
        bit [31:0] expected_int8;
        bit [31:0] expected_result_by_op [0:2];
        bit [15:0] expected_task_by_op [0:2];
        int unsigned expected_elements_by_op [0:2];
        bit completed;
        int unsigned poll;
        int unsigned slot;
        int unsigned op;
        uvm_hdl_data_t irq_pin;

        expected_fp16 = reference_model.predict_small_integer_dot(
            vector_plan.fp16_a0, vector_plan.fp16_a1,
            vector_plan.fp16_a2, vector_plan.fp16_a3,
            vector_plan.fp16_b0, vector_plan.fp16_b1,
            vector_plan.fp16_b2, vector_plan.fp16_b3,
            vector_plan.fp16_length);
        expected_bf16 = reference_model.predict_small_integer_dot(
            vector_plan.bf16_a0, vector_plan.bf16_a1,
            vector_plan.bf16_a2, vector_plan.bf16_a3,
            vector_plan.bf16_b0, vector_plan.bf16_b1,
            vector_plan.bf16_b2, vector_plan.bf16_b3,
            vector_plan.bf16_length);
        expected_int8 = reference_model.predict_int8_dot4(
            vector_plan.int8_a0, vector_plan.int8_a1,
            vector_plan.int8_a2, vector_plan.int8_a3,
            vector_plan.int8_b0, vector_plan.int8_b1,
            vector_plan.int8_b2, vector_plan.int8_b3);

        expected_result_by_op[0] = expected_fp16;
        expected_result_by_op[1] = expected_bf16;
        expected_result_by_op[2] = expected_int8;
        expected_task_by_op[0] = 16'h0503;
        expected_task_by_op[1] = 16'h0504;
        expected_task_by_op[2] = 16'h0505;
        expected_elements_by_op[0] = vector_plan.fp16_length;
        expected_elements_by_op[1] = vector_plan.bf16_length;
        expected_elements_by_op[2] = 1;

        // Publish the three legal operations in the selected descriptor order.
        // The six order codes are exhaustively swept by the Makefile regression.
        for (slot = 0; slot < 3; slot++) begin
            op = vector_plan.operation_at_slot(slot);
            case (op)
                0: write_dot_descriptor(CMDQ_ADDR + (slot * 32'h40), 16'h0503, 8'h51,
                                        layout_spad_addr(SPAD_A_ADDR),
                                        layout_spad_addr(SPAD_B_ADDR),
                                        layout_spad_addr(SPAD_Y_ADDR),
                                        vector_plan.fp16_length);
                1: write_dot_descriptor(CMDQ_ADDR + (slot * 32'h40), 16'h0504, 8'h50,
                                        layout_spad_addr(SPAD_BF16_A_ADDR),
                                        layout_spad_addr(SPAD_BF16_B_ADDR),
                                        layout_spad_addr(SPAD_BF16_Y_ADDR),
                                        vector_plan.bf16_length);
                2: write_dot_descriptor(CMDQ_ADDR + (slot * 32'h40), 16'h0505, 8'h10,
                                        layout_spad_addr(SPAD_INT8_A_ADDR),
                                        layout_spad_addr(SPAD_INT8_B_ADDR),
                                        layout_spad_addr(SPAD_INT8_Y_ADDR), 1);
                default: `uvm_fatal("MIXED_E2E_ORDER", $sformatf("invalid operation %0d in slot %0d", op, slot))
            endcase
        end

        axil_write(CIMFORGE_REG_CMDQ_BASE_LO, CMDQ_ADDR);
        // Ring pointers reserve one slot to distinguish full from empty;
        // size 4 provides three descriptor entries.
        axil_write(CIMFORGE_REG_CMDQ_SIZE, 32'd4);
        axil_write(CIMFORGE_REG_CMDQ_HEAD, 32'd0);
        axil_write(CIMFORGE_REG_CMDQ_TAIL, 32'd3);
        axil_write(CIMFORGE_REG_CPLQ_BASE_LO, CPLQ_ADDR);
        // Four pointer positions provide three completion entries with the
        // ring's reserved empty/full slot.
        axil_write(CIMFORGE_REG_CPLQ_SIZE, 32'd4);
        axil_write(CIMFORGE_REG_CPLQ_HEAD, 32'd0);
        axil_write(CIMFORGE_REG_CPLQ_TAIL, 32'd0);
        axil_write(CIMFORGE_REG_IRQ_ENABLE, 32'd1);
        axil_write(CIMFORGE_REG_DOORBELL, 32'd1);

        completed = 1'b0;
        for (poll = 0; poll < 2000; poll++) begin
            axil_read(CIMFORGE_REG_CPLQ_TAIL, value);
            if (value == 32'd3) begin
                completed = 1'b1;
                break;
            end
        end
        if (!completed) begin
            `uvm_fatal("MIXED_E2E_CPL", "completion tail did not advance to three")
            return;
        end

        axil_read(CIMFORGE_REG_IRQ_STATUS, value);
        if (value[0] !== 1'b1)
            `uvm_error("MIXED_E2E_IRQ", $sformatf("IRQ_STATUS expected sticky 1 after completion, got 0x%08h", value))
        irq_pin = '0;
        if (!uvm_hdl_read("tb_ai_accel_uvm.irq", irq_pin))
            `uvm_fatal("MIXED_E2E_IRQ", "failed to observe top-level irq output")
        else if (irq_pin[0] !== 1'b1)
            `uvm_error("MIXED_E2E_IRQ", $sformatf("top-level irq expected 1 after completion, got 0x%0h", irq_pin[0]))

        axil_read(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_Y_ADDR), value);
        if (value !== expected_fp16)
            `uvm_error("MIXED_E2E_RESULT", $sformatf("FP16 SPAD result expected=0x%08h actual=0x%08h", expected_fp16, value))
        axil_read(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_BF16_Y_ADDR), value);
        if (value !== expected_bf16)
            `uvm_error("MIXED_E2E_RESULT", $sformatf("BF16 SPAD result expected=0x%08h actual=0x%08h", expected_bf16, value))
        axil_read(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_INT8_Y_ADDR), value);
        if (value !== expected_int8)
            `uvm_error("MIXED_E2E_RESULT", $sformatf("INT8 SPAD result expected=0x%08h actual=0x%08h", expected_int8, value))

        for (slot = 0; slot < 3; slot++) begin
            op = vector_plan.operation_at_slot(slot);
            axil_read(CIMFORGE_SPAD_BASE + CPLQ_ADDR + (slot * 16), value);
            if (value[15:0] !== expected_task_by_op[op])
                `uvm_error("MIXED_E2E_CPL", $sformatf("slot %0d task ID expected=0x%04h actual=0x%04h", slot, expected_task_by_op[op], value[15:0]))
            axil_read(CIMFORGE_SPAD_BASE + CPLQ_ADDR + (slot * 16) + 4, value);
            if (value !== 32'd1)
                `uvm_error("MIXED_E2E_CPL", $sformatf("slot %0d status expected=1 actual=0x%08h", slot, value))
            axil_read(CIMFORGE_SPAD_BASE + CPLQ_ADDR + (slot * 16) + 8, value);
            if (value !== expected_result_by_op[op])
                `uvm_error("MIXED_E2E_CPL", $sformatf("slot %0d result expected=0x%08h actual=0x%08h", slot, expected_result_by_op[op], value))
            axil_read(CIMFORGE_SPAD_BASE + CPLQ_ADDR + (slot * 16) + 12, value);
            if (value !== expected_elements_by_op[op])
                `uvm_error("MIXED_E2E_CPL", $sformatf("slot %0d element count expected=%0d actual=%0d", slot, expected_elements_by_op[op], value))
        end

        axil_write(CIMFORGE_REG_IRQ_STATUS, 32'd1);
        axil_read(CIMFORGE_REG_IRQ_STATUS, value);
        if (value[0] !== 1'b0)
            `uvm_error("MIXED_E2E_IRQ", $sformatf("IRQ_STATUS expected cleared 0, got 0x%08h", value))
        irq_pin = '0;
        if (!uvm_hdl_read("tb_ai_accel_uvm.irq", irq_pin))
            `uvm_fatal("MIXED_E2E_IRQ", "failed to observe top-level irq output after clear")
        else if (irq_pin[0] !== 1'b0)
            `uvm_error("MIXED_E2E_IRQ", $sformatf("top-level irq expected 0 after clear, got 0x%0h", irq_pin[0]))
        else
            `uvm_info("MIXED_E2E_IRQ", "completion IRQ asserted and deasserted after IRQ_STATUS W1C", UVM_LOW)

        // Consume the three successful completions, then publish one invalid
        // FP16 descriptor in slot 3. Across the six seeded order runs, the
        // descriptor-order selector sweeps six independent validator rules.
        axil_write(CIMFORGE_REG_CPLQ_HEAD, 32'd3);
        axil_write(CIMFORGE_SPAD_BASE + SPAD_BAD_Y_ADDR, 32'hbad0_f00d);
        write_invalid_descriptor(CMDQ_ADDR + 32'hc0,
                                 16'h0600 + vector_plan.descriptor_order,
                                 vector_plan.descriptor_order);
        axil_write(CIMFORGE_REG_CMDQ_TAIL, 32'd0);
        axil_write(CIMFORGE_REG_DOORBELL, 32'd1);

        completed = 1'b0;
        for (poll = 0; poll < 2000; poll++) begin
            axil_read(CIMFORGE_REG_CPLQ_TAIL, value);
            if (value == 32'd0) begin
                completed = 1'b1;
                break;
            end
        end
        if (!completed) begin
            `uvm_fatal("MIXED_E2E_BAD_DESC", "completion tail did not wrap to zero")
            return;
        end

        axil_read(CIMFORGE_REG_CMDQ_HEAD, value);
        if (value !== 32'd0)
            `uvm_error("MIXED_E2E_BAD_DESC", $sformatf("CMDQ_HEAD expected wrap 0, got 0x%08h", value))
        axil_read(CIMFORGE_SPAD_BASE + CPLQ_ADDR + 32'h30, value);
        if (value[15:0] !== (16'h0600 + vector_plan.descriptor_order))
            `uvm_error("MIXED_E2E_BAD_DESC", $sformatf("invalid completion task ID expected=0x%04h actual=0x%04h", 16'h0600 + vector_plan.descriptor_order, value[15:0]))
        axil_read(CIMFORGE_SPAD_BASE + CPLQ_ADDR + 32'h34, value);
        if (value !== 32'h0000_0072)
            `uvm_error("MIXED_E2E_BAD_DESC", $sformatf("invalid completion status expected=0x72 actual=0x%08h", value))
        axil_read(CIMFORGE_SPAD_BASE + SPAD_BAD_Y_ADDR, value);
        if (value !== 32'hbad0_f00d)
            `uvm_error("MIXED_E2E_BAD_DESC", $sformatf("invalid descriptor launched or corrupted destination sentinel: expected=0xbad0f00d actual=0x%08h", value))
        axil_read(CIMFORGE_REG_ERROR, value);
        if (value[3:0] !== 4'd7)
            `uvm_error("MIXED_E2E_BAD_DESC", $sformatf("REG_ERROR expected ERR_DESC=7 actual=0x%08h", value))

        axil_read(CIMFORGE_REG_IRQ_STATUS, value);
        if (value[0] !== 1'b1)
            `uvm_error("MIXED_E2E_BAD_DESC", $sformatf("IRQ_STATUS expected sticky 1 for invalid descriptor, got 0x%08h", value))
        irq_pin = '0;
        if (!uvm_hdl_read("tb_ai_accel_uvm.irq", irq_pin))
            `uvm_fatal("MIXED_E2E_BAD_DESC", "failed to observe irq after invalid descriptor")
        else if (irq_pin[0] !== 1'b1)
            `uvm_error("MIXED_E2E_BAD_DESC", $sformatf("irq expected 1 for invalid descriptor, got 0x%0h", irq_pin[0]))

        axil_write(CIMFORGE_REG_IRQ_STATUS, 32'd1);
        axil_read(CIMFORGE_REG_IRQ_STATUS, value);
        if (value[0] !== 1'b0)
            `uvm_error("MIXED_E2E_BAD_DESC", $sformatf("IRQ_STATUS expected cleared 0, got 0x%08h", value))
        irq_pin = '0;
        if (!uvm_hdl_read("tb_ai_accel_uvm.irq", irq_pin))
            `uvm_fatal("MIXED_E2E_BAD_DESC", "failed to observe irq after invalid-descriptor W1C")
        else if (irq_pin[0] !== 1'b0)
            `uvm_error("MIXED_E2E_BAD_DESC", $sformatf("irq expected 0 after invalid-descriptor W1C, got 0x%0h", irq_pin[0]))
        else
            `uvm_info("MIXED_E2E_INVALID_DESC_PASS", $sformatf("case=%0d name=%s produced ERR_DESC without launch; CMDQ/CPLQ wrap and error IRQ W1C checks passed", vector_plan.descriptor_order, invalid_descriptor_case_name(vector_plan.descriptor_order)), UVM_LOW)

        axil_write(CIMFORGE_REG_IRQ_ENABLE, 32'd0);

        axil_write(CIMFORGE_REG_CMDQ_SIZE, 32'd0);
        axil_write(CIMFORGE_REG_CPLQ_SIZE, 32'd0);
    endtask

    task automatic run_dma_error_position_case(
        input bit [31:0] ext_addr,
        input bit [31:0] spad_addr,
        input int unsigned error_beat,
        input string case_name);
        bit [31:0] value;
        bit [31:0] dma_status;
        bit [31:0] dma_error;
        bit completed;
        bit ok;
        bit case_ok;
        int unsigned poll;
        int unsigned word_index;
        uvm_hdl_data_t hdl_value;
        bit [31:0] expected_ddr_words[8];
        string mem_path;

        if (error_beat > 1)
            `uvm_fatal("MIXED_E2E_DMA_ERROR", $sformatf("two-beat error position must be 0 or 1, got %0d", error_beat))
        case_ok = 1'b1;

        // Initialize one two-beat DMA burst with unique data and a sentinel
        // destination. The DMA buffers a burst until an OKAY RLAST, so an
        // SLVERR at either position must prevent the entire burst committing.
        for (word_index = 0; word_index < 8; word_index++) begin
            expected_ddr_words[word_index] = 32'h9000_0000 ^ (ext_addr + word_index * 4);
            mem_path = $sformatf("tb_ai_accel_uvm.axi_mem_u.mem[%0d]",
                                (ext_addr >> 2) + word_index);
            hdl_value = '0;
            hdl_value[31:0] = expected_ddr_words[word_index];
            ok = uvm_hdl_deposit(mem_path, hdl_value);
            if (!ok)
                `uvm_fatal("MIXED_E2E_DMA_ERROR", $sformatf("failed to initialize DDR test word %s", mem_path))
            axil_write(CIMFORGE_SPAD_BASE + spad_addr + word_index * 4,
                       32'hdeed_cafe ^ word_index);
        end

        // The shared top checker rejects unexpected AXI response errors. This
        // test intentionally injects one SLVERR per burst, and its scoreboard
        // checks the error code, RID/RLAST drain, and no-partial-commit result.
        hdl_value = '0;
        hdl_value[0] = 1'b1;
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.allow_m_axi_error", hdl_value);
        if (!ok) `uvm_fatal("MIXED_E2E_DMA_ERROR", "failed to enable expected AXI response error allowance")

        hdl_value = '0;
        hdl_value[31:0] = (ext_addr >> 2) + error_beat * 4;
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.inject_read_error_word", hdl_value);
        if (!ok) `uvm_fatal("MIXED_E2E_DMA_ERROR", "failed to enable AXI memory-model read error injection")

        axil_write(CIMFORGE_REG_DMA_EXT_ADDR, ext_addr);
        axil_write(CIMFORGE_REG_DMA_SPAD_ADDR, spad_addr);
        axil_write(CIMFORGE_REG_DMA_LENGTH, 32'd8);
        axil_write(CIMFORGE_REG_DMA_CTRL, 32'd1);

        completed = 1'b0;
        for (poll = 0; poll < 2000; poll++) begin
            axil_read(CIMFORGE_REG_DMA_STATUS, dma_status);
            if (dma_status[2]) begin
                completed = 1'b1;
                break;
            end
            if (dma_status[1]) begin
                `uvm_error("MIXED_E2E_DMA_ERROR", "injected AXI SLVERR unexpectedly completed DMA successfully")
                break;
            end
        end
        if (!completed)
            `uvm_fatal("MIXED_E2E_DMA_ERROR", "DMA did not report the injected AXI read error")

        axil_read(CIMFORGE_REG_DMA_ERROR, dma_error);
        if (dma_error[3:0] !== 4'd2) begin
            case_ok = 1'b0;
            `uvm_error("MIXED_E2E_DMA_ERROR", $sformatf("DMA_ERROR expected ERR_AXI_RD=2 got 0x%08h", dma_error))
        end

        for (word_index = 0; word_index < 8; word_index++) begin
            axil_read(CIMFORGE_SPAD_BASE + spad_addr + word_index * 4, value);
            if (value !== (32'hdeed_cafe ^ word_index)) begin
                case_ok = 1'b0;
                `uvm_error("MIXED_E2E_DMA_ERROR", $sformatf(
                    "%s failed burst partially committed word[%0d]=0x%08h",
                    case_name, word_index, value))
            end
        end

        // Stop injecting and clear sticky DMA status before the next position.
        hdl_value = '1;
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.inject_read_error_word", hdl_value);
        if (!ok) `uvm_fatal("MIXED_E2E_DMA_ERROR", "failed to disable AXI memory-model read error injection")
        hdl_value = '0;
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.allow_m_axi_error", hdl_value);
        if (!ok) `uvm_fatal("MIXED_E2E_DMA_ERROR", "failed to disable expected AXI response error allowance")
        axil_write(CIMFORGE_REG_DMA_STATUS, 32'd6);
        axil_read(CIMFORGE_REG_DMA_STATUS, dma_status);
        if (dma_status[2:1] !== 2'b00) begin
            case_ok = 1'b0;
            `uvm_error("MIXED_E2E_DMA_ERROR", $sformatf("DMA error W1C expected clear, status=0x%08h", dma_status))
        end
        if (case_ok)
            `uvm_info("MIXED_E2E_AXI_ERROR_CASE_PASS", $sformatf(
                "%s SLVERR beat=%0d prevented the 8-word burst from committing; error code=ERR_AXI_RD",
                case_name, error_beat), UVM_LOW)
    endtask

    task automatic run_dma_error_and_reset_recovery();
        bit [31:0] value;
        bit [31:0] expected_result;
        bit active_compute_seen;
        bit completed;
        bit ok;
        int unsigned poll;
        uvm_hdl_data_t hdl_value;

        run_dma_error_position_case(DDR_ERROR_ADDR, SPAD_ERROR_SENTINEL_ADDR,
                                    0, "error-on-first-beat");
        run_dma_error_position_case(DDR_ERROR_LAST_BEAT_ADDR,
                                    SPAD_ERROR_LAST_BEAT_ADDR,
                                    1, "error-on-last-beat");
        `uvm_info("MIXED_E2E_AXI_ERROR_PASS",
            "first/last-beat AXI read SLVERR sweep confirmed atomic burst commit and no partial SPAD write", UVM_LOW)

        // Start a fresh K=4 FP16 command and reset while the engine is active.
        // This checks that an in-flight compute event cannot leak a completion
        // after reset; the following command proves the lifecycle recovers.
        axil_write(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_A_ADDR), vector_plan.fp16_a_word(0));
        axil_write(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_A_ADDR) + 4, vector_plan.fp16_a_word(1));
        axil_write(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_B_ADDR), vector_plan.fp16_b_word(0));
        axil_write(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_B_ADDR) + 4, vector_plan.fp16_b_word(1));
        axil_write(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_Y_ADDR), 32'hface_0701);
        write_dot_descriptor(CMDQ_ADDR, 16'h0701, 8'h51,
                             layout_spad_addr(SPAD_A_ADDR),
                             layout_spad_addr(SPAD_B_ADDR),
                             layout_spad_addr(SPAD_Y_ADDR), 4);
        axil_write(CIMFORGE_REG_CMDQ_BASE_LO, CMDQ_ADDR);
        axil_write(CIMFORGE_REG_CMDQ_SIZE, 32'd4);
        axil_write(CIMFORGE_REG_CMDQ_HEAD, 32'd0);
        axil_write(CIMFORGE_REG_CMDQ_TAIL, 32'd1);
        axil_write(CIMFORGE_REG_CPLQ_BASE_LO, CPLQ_ADDR);
        axil_write(CIMFORGE_REG_CPLQ_SIZE, 32'd4);
        axil_write(CIMFORGE_REG_CPLQ_HEAD, 32'd0);
        axil_write(CIMFORGE_REG_CPLQ_TAIL, 32'd0);
        axil_write(CIMFORGE_REG_DOORBELL, 32'd1);

        active_compute_seen = 1'b0;
        for (poll = 0; poll < 2000; poll++) begin
            #1;
            hdl_value = '0;
            ok = uvm_hdl_read("tb_ai_accel_uvm.dut.fp_busy", hdl_value);
            if (!ok)
                `uvm_fatal("MIXED_E2E_ACTIVE_RESET", "failed to observe FP engine busy")
            if (hdl_value[0] === 1'b1) begin
                active_compute_seen = 1'b1;
                break;
            end
        end
        if (!active_compute_seen)
            `uvm_fatal("MIXED_E2E_ACTIVE_RESET", "FP16 engine did not become active before reset")

        // Assert reset immediately after observing fp_busy, before the K=4
        // command can reach its normal result-write/completion retirement.
        // This accelerator-only reset is intentionally performed with the
        // external DDR responder still active and no AXI request in flight.
        require_hdl_zero("tb_ai_accel_uvm.dut.dma_busy", "DUT DMA busy");
        require_hdl_zero("tb_ai_accel_uvm.axi4.arvalid", "AXI ARVALID");
        require_hdl_zero("tb_ai_accel_uvm.axi4.awvalid", "AXI AWVALID");
        require_hdl_zero("tb_ai_accel_uvm.axi4.wvalid", "AXI WVALID");
        require_hdl_zero("tb_ai_accel_uvm.axi_mem_u.read_active_r", "DDR active read");
        require_hdl_zero("tb_ai_accel_uvm.axi_mem_u.read_q_count_r", "DDR queued reads");
        require_hdl_zero("tb_ai_accel_uvm.axi_mem_u.rvalid", "DDR RVALID");
        require_hdl_zero("tb_ai_accel_uvm.axi_mem_u.write_active_r", "DDR active write");
        require_hdl_zero("tb_ai_accel_uvm.axi_mem_u.bvalid", "DDR BVALID");
        hdl_value = '0;
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", hdl_value);
        if (!ok) `uvm_fatal("MIXED_E2E_RESET", "failed to assert top-level reset")
        #60;

        hdl_value = '1;
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", hdl_value);
        if (!ok) `uvm_fatal("MIXED_E2E_RESET", "failed to release top-level reset")
        #60;
        apply_axi_stall_config("post_reset");

        axil_read(CIMFORGE_REG_VERSION, value);
        if (value !== CIMFORGE_VERSION_A10)
            `uvm_error("MIXED_E2E_RESET", $sformatf("VERSION after reset expected=0x%08h actual=0x%08h", CIMFORGE_VERSION_A10, value))
        axil_read(CIMFORGE_REG_DMA_STATUS, value);
        if (value !== 32'd0)
            `uvm_error("MIXED_E2E_RESET", $sformatf("DMA_STATUS after reset expected zero actual=0x%08h", value))
        axil_read(CIMFORGE_REG_CMDQ_HEAD, value);
        if (value !== 32'd0)
            `uvm_error("MIXED_E2E_RESET", $sformatf("CMDQ_HEAD after reset expected zero actual=0x%08h", value))
        axil_read(CIMFORGE_REG_CPLQ_TAIL, value);
        if (value !== 32'd0)
            `uvm_error("MIXED_E2E_RESET", $sformatf("CPLQ_TAIL after reset expected zero actual=0x%08h", value))
        axil_read(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_Y_ADDR), value);
        if (value !== 32'hface_0701)
            `uvm_error("MIXED_E2E_ACTIVE_RESET", $sformatf("in-flight FP16 command modified destination before reset retirement: expected sentinel=0xface0701 actual=0x%08h", value))
        #100;
        axil_read(CIMFORGE_REG_CPLQ_TAIL, value);
        if (value !== 32'd0)
            `uvm_error("MIXED_E2E_ACTIVE_RESET", $sformatf("stale completion appeared after reset: CPLQ_TAIL=0x%08h", value))
        active_compute_reset_checked = 1'b1;
        `uvm_info("MIXED_E2E_ACTIVE_RESET_PASS", "reset interrupted an active FP16 command; destination stayed unchanged and no stale completion appeared", UVM_LOW)

        run_ddr_alive_after_accel_reset_check();

        run_dma_outstanding_reset_check();

        // Scratchpad contents are explicitly reinitialized, so recovery does
        // not depend on whether a particular RAM implementation retains data.
        axil_write(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_A_ADDR), vector_plan.fp16_a_word(0));
        axil_write(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_A_ADDR) + 4, vector_plan.fp16_a_word(1));
        axil_write(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_B_ADDR), vector_plan.fp16_b_word(0));
        axil_write(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_B_ADDR) + 4, vector_plan.fp16_b_word(1));
        axil_write(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_Y_ADDR), 32'hface_0700);
        write_dot_descriptor(CMDQ_ADDR, 16'h0700, 8'h51,
                             layout_spad_addr(SPAD_A_ADDR),
                             layout_spad_addr(SPAD_B_ADDR),
                             layout_spad_addr(SPAD_Y_ADDR),
                             vector_plan.fp16_length);
        axil_write(CIMFORGE_REG_CMDQ_BASE_LO, CMDQ_ADDR);
        axil_write(CIMFORGE_REG_CMDQ_SIZE, 32'd4);
        axil_write(CIMFORGE_REG_CMDQ_HEAD, 32'd0);
        axil_write(CIMFORGE_REG_CMDQ_TAIL, 32'd1);
        axil_write(CIMFORGE_REG_CPLQ_BASE_LO, CPLQ_ADDR);
        axil_write(CIMFORGE_REG_CPLQ_SIZE, 32'd4);
        axil_write(CIMFORGE_REG_CPLQ_HEAD, 32'd0);
        axil_write(CIMFORGE_REG_CPLQ_TAIL, 32'd0);
        axil_write(CIMFORGE_REG_DOORBELL, 32'd1);

        completed = 1'b0;
        for (poll = 0; poll < 2000; poll++) begin
            axil_read(CIMFORGE_REG_CPLQ_TAIL, value);
            if (value == 32'd1) begin
                completed = 1'b1;
                break;
            end
        end
        if (!completed)
            `uvm_fatal("MIXED_E2E_RESET", "post-reset FP16 command did not complete")

        expected_result = reference_model.predict_small_integer_dot(
            vector_plan.fp16_a0, vector_plan.fp16_a1,
            vector_plan.fp16_a2, vector_plan.fp16_a3,
            vector_plan.fp16_b0, vector_plan.fp16_b1,
            vector_plan.fp16_b2, vector_plan.fp16_b3,
            vector_plan.fp16_length);
        axil_read(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_Y_ADDR), value);
        if (value !== expected_result)
            `uvm_error("MIXED_E2E_RESET", $sformatf("post-reset FP16 result expected=0x%08h actual=0x%08h", expected_result, value))
        axil_read(CIMFORGE_SPAD_BASE + CPLQ_ADDR, value);
        if (value[15:0] !== 16'h0700)
            `uvm_error("MIXED_E2E_RESET", $sformatf("post-reset completion task ID expected=0x0700 actual=0x%04h", value[15:0]))
        axil_read(CIMFORGE_SPAD_BASE + CPLQ_ADDR + 4, value);
        if (value !== 32'd1)
            `uvm_error("MIXED_E2E_RESET", $sformatf("post-reset completion status expected success actual=0x%08h", value))
        `uvm_info("MIXED_E2E_RESET_RECOVERY_PASS", "top-level reset restored queue/DMA state and a fresh FP16 command completed bit-exactly", UVM_LOW)
        run_fp_watchdog_completion_check();
        run_fp_abort_completion_check();
    endtask

    // Exercise the real FP core watchdog through descriptor fetch, command
    // retirement, and the shared four-word completion writer. This is not a
    // behavioral compute-error injection: the watchdog comes from the ABI.
    task automatic run_fp_watchdog_completion_check();
        bit [31:0] value;
        bit completed;
        int unsigned poll;

        axil_write(CIMFORGE_REG_WATCHDOG, 32'd1);
        axil_write(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_A_ADDR), vector_plan.fp16_a_word(0));
        axil_write(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_A_ADDR) + 4, vector_plan.fp16_a_word(1));
        axil_write(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_B_ADDR), vector_plan.fp16_b_word(0));
        axil_write(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_B_ADDR) + 4, vector_plan.fp16_b_word(1));
        axil_write(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_Y_ADDR), 32'hface_0702);
        write_dot_descriptor(CMDQ_ADDR + 32'h40, 16'h0702, 8'h51,
                             layout_spad_addr(SPAD_A_ADDR),
                             layout_spad_addr(SPAD_B_ADDR),
                             layout_spad_addr(SPAD_Y_ADDR), 4);

        // The preceding recovery command consumed CMDQ/CPLQ slot zero. Publish
        // slot one and require exactly one watchdog-error completion there.
        axil_write(CIMFORGE_REG_CMDQ_TAIL, 32'd2);
        axil_write(CIMFORGE_REG_DOORBELL, 32'd1);
        completed = 1'b0;
        for (poll = 0; poll < 2000; poll++) begin
            axil_read(CIMFORGE_REG_CPLQ_TAIL, value);
            if (value == 32'd2) begin
                completed = 1'b1;
                break;
            end
        end
        if (!completed)
            `uvm_fatal("MIXED_E2E_FP_WATCHDOG", "FP watchdog command did not retire a completion")

        axil_read(CIMFORGE_SPAD_BASE + CPLQ_ADDR + 32'h10, value);
        if (value[15:0] !== 16'h0702)
            `uvm_error("MIXED_E2E_FP_WATCHDOG", $sformatf("completion task ID expected=0x0702 actual=0x%04h", value[15:0]))
        axil_read(CIMFORGE_SPAD_BASE + CPLQ_ADDR + 32'h14, value);
        if (value !== 32'h0000_0042)
            `uvm_error("MIXED_E2E_FP_WATCHDOG", $sformatf("completion status/error expected=0x42 (ERR_WATCHDOG) actual=0x%08h", value))
        axil_read(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_Y_ADDR), value);
        if (value !== 32'hface_0702)
            `uvm_error("MIXED_E2E_FP_WATCHDOG", $sformatf("watchdog command unexpectedly wrote destination: expected sentinel=0xface0702 actual=0x%08h", value))

        #100;
        axil_read(CIMFORGE_REG_CPLQ_TAIL, value);
        if (value !== 32'd2)
            `uvm_error("MIXED_E2E_FP_WATCHDOG", $sformatf("watchdog command retired more than once; CPLQ_TAIL=%0d", value))
        fp_watchdog_completion_checked = 1'b1;
        `uvm_info("MIXED_E2E_FP_WATCHDOG_PASS", "software watchdog limit triggered the real FP engine; ERR_WATCHDOG propagated through CMDQ to one completion without result writeback", UVM_LOW)
    endtask

    // Exercise the software ABORT register while the real FP command is active
    // and verify that the error retires through the shared completion writer.
    task automatic run_fp_abort_completion_check();
        bit [31:0] value;
        bit active_compute_seen;
        bit outstanding_read_seen;
        bit abort_pulse_seen;
        bit completed;
        bit ok;
        int unsigned poll;
        bit [1:0] outstanding_at_abort;
        uvm_hdl_data_t hdl_value;

        axil_write(CIMFORGE_REG_WATCHDOG, 32'd0);
        axil_write(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_A_ADDR), vector_plan.fp16_a_word(0));
        axil_write(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_A_ADDR) + 4, vector_plan.fp16_a_word(1));
        axil_write(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_B_ADDR), vector_plan.fp16_b_word(0));
        axil_write(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_B_ADDR) + 4, vector_plan.fp16_b_word(1));
        axil_write(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_Y_ADDR), 32'hface_0703);
        write_dot_descriptor(CMDQ_ADDR + 32'h80, 16'h0703, 8'h51,
                             layout_spad_addr(SPAD_A_ADDR),
                             layout_spad_addr(SPAD_B_ADDR),
                             layout_spad_addr(SPAD_Y_ADDR), 4);

        // Watchdog retired slot one. Publish slot two and wait until the actual
        // FP engine is busy before sending the software abort pulse.
        axil_write(CIMFORGE_REG_CMDQ_TAIL, 32'd3);
        axil_write(CIMFORGE_REG_DOORBELL, 32'd1);
        active_compute_seen = 1'b0;
        outstanding_read_seen = 1'b0;
        for (poll = 0; poll < 2000; poll++) begin
            #1;
            hdl_value = '0;
            ok = uvm_hdl_read("tb_ai_accel_uvm.dut.fp_busy", hdl_value);
            if (!ok)
                `uvm_fatal("MIXED_E2E_FP_ABORT", "failed to observe FP engine busy")
            if (hdl_value[0] === 1'b1) begin
                active_compute_seen = 1'b1;
                hdl_value = '0;
                ok = uvm_hdl_read("tb_ai_accel_uvm.dut.compute_cluster_u.mixed_precision_dot_core_u.outstanding_reads_r", hdl_value);
                if (!ok)
                    `uvm_fatal("MIXED_E2E_FP_ABORT", "failed to observe FP outstanding SPAD reads")
                if (hdl_value[1:0] != 0) begin
                    outstanding_read_seen = 1'b1;
                    break;
                end
            end
        end
        if (!active_compute_seen)
            `uvm_fatal("MIXED_E2E_FP_ABORT", "FP16 engine did not become active before software abort")
        if (!outstanding_read_seen)
            `uvm_fatal("MIXED_E2E_FP_ABORT", "FP16 engine had no accepted SPAD read outstanding before software abort")

        // Observe the real top-level abort pulse while the FP read counter is
        // still nonzero. This distinguishes an in-flight abort/drain from an
        // abort that happens only after all SPAD reads have already returned.
        abort_pulse_seen = 1'b0;
        outstanding_at_abort = '0;
        fork
            axil_write(CIMFORGE_REG_ABORT, 32'd1);
            begin
                for (poll = 0; poll < 2000; poll++) begin
                    #1;
                    hdl_value = '0;
                    ok = uvm_hdl_read("tb_ai_accel_uvm.dut.core_abort", hdl_value);
                    if (!ok)
                        `uvm_fatal("MIXED_E2E_FP_ABORT", "failed to observe top-level software abort pulse")
                    if (hdl_value[0] === 1'b1) begin
                        hdl_value = '0;
                        ok = uvm_hdl_read("tb_ai_accel_uvm.dut.compute_cluster_u.mixed_precision_dot_core_u.outstanding_reads_r", hdl_value);
                        if (!ok)
                            `uvm_fatal("MIXED_E2E_FP_ABORT", "failed to sample outstanding reads during abort pulse")
                        outstanding_at_abort = hdl_value[1:0];
                        abort_pulse_seen = 1'b1;
                        break;
                    end
                end
            end
        join
        if (!abort_pulse_seen)
            `uvm_fatal("MIXED_E2E_FP_ABORT", "top-level software abort pulse was not observed")
        if (outstanding_at_abort == 0)
            `uvm_fatal("MIXED_E2E_FP_ABORT", "software abort arrived after all accepted FP SPAD reads had drained")

        completed = 1'b0;
        for (poll = 0; poll < 2000; poll++) begin
            axil_read(CIMFORGE_REG_CPLQ_TAIL, value);
            if (value == 32'd3) begin
                completed = 1'b1;
                break;
            end
        end
        if (!completed)
            `uvm_fatal("MIXED_E2E_FP_ABORT", "software-aborted FP command did not retire a completion")

        axil_read(CIMFORGE_SPAD_BASE + CPLQ_ADDR + 32'h20, value);
        if (value[15:0] !== 16'h0703)
            `uvm_error("MIXED_E2E_FP_ABORT", $sformatf("completion task ID expected=0x0703 actual=0x%04h", value[15:0]))
        axil_read(CIMFORGE_SPAD_BASE + CPLQ_ADDR + 32'h24, value);
        if (value !== 32'h0000_0032)
            `uvm_error("MIXED_E2E_FP_ABORT", $sformatf("completion status/error expected=0x32 (ERR_ABORT) actual=0x%08h", value))
        axil_read(CIMFORGE_SPAD_BASE + layout_spad_addr(SPAD_Y_ADDR), value);
        if (value !== 32'hface_0703)
            `uvm_error("MIXED_E2E_FP_ABORT", $sformatf("aborted command modified destination: expected sentinel=0xface0703 actual=0x%08h", value))

        hdl_value = '0;
        ok = uvm_hdl_read("tb_ai_accel_uvm.dut.compute_cluster_u.mixed_precision_dot_core_u.outstanding_reads_r", hdl_value);
        if (!ok)
            `uvm_fatal("MIXED_E2E_FP_ABORT", "failed to observe FP outstanding-read drain")
        if (hdl_value[1:0] !== 2'b00)
            `uvm_error("MIXED_E2E_FP_ABORT", $sformatf("aborted FP core did not drain outstanding reads; count=%0d", hdl_value[1:0]))

        #100;
        axil_read(CIMFORGE_REG_CPLQ_TAIL, value);
        if (value !== 32'd3)
            `uvm_error("MIXED_E2E_FP_ABORT", $sformatf("abort completion retired more than once; CPLQ_TAIL=%0d", value))
        fp_abort_completion_checked = 1'b1;
        `uvm_info("MIXED_E2E_FP_ABORT_PASS", $sformatf("software ABORT reached the active FP engine with %0d SPAD reads outstanding; reads drained before one ERR_ABORT completion, with no result writeback", outstanding_at_abort), UVM_LOW)
    endtask

    task body();
        bit [31:0] version;
        bit ok;
        uvm_hdl_data_t backdoor_value;

        if (vector_plan == null)
            `uvm_fatal("MIXED_E2E_PLAN", "test did not provide a randomized vector plan")
        reference_model = ai_accel_reference_model::type_id::create("reference_model");

        axil_read(CIMFORGE_REG_VERSION, version);
        if (version !== CIMFORGE_VERSION_A10) begin
            `uvm_error("FP16_E2E_VERSION", $sformatf("expected A10 version 0x%08h got 0x%08h", CIMFORGE_VERSION_A10, version))
            return;
        end

        // Initial reset may still be active at time zero; configure the
        // external responder only after VERSION reads valid.
        apply_axi_stall_config("pre_dma");

        // Initialize only the external memory model through the VCS/UVM
        // backdoor; all DUT accesses still use its AXI4 interface.
        backdoor_value = '0;
        backdoor_value[31:0] = vector_plan.fp16_a_word(0);
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.mem[1664]", backdoor_value);
        if (!ok) `uvm_fatal("FP16_E2E_BACKDOOR", "failed to initialize DDR model word 0x680")
        backdoor_value[31:0] = vector_plan.fp16_a_word(1);
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.mem[1665]", backdoor_value);
        if (!ok) `uvm_fatal("FP16_E2E_BACKDOOR", "failed to initialize DDR model word 0x681")
        backdoor_value[31:0] = vector_plan.fp16_b_word(0);
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.mem[1668]", backdoor_value);
        if (!ok) `uvm_fatal("FP16_E2E_BACKDOOR", "failed to initialize DDR model word 0x684")
        backdoor_value[31:0] = vector_plan.fp16_b_word(1);
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.mem[1669]", backdoor_value);
        if (!ok) `uvm_fatal("FP16_E2E_BACKDOOR", "failed to initialize DDR model word 0x685")
        backdoor_value[31:0] = 32'hface_f16d;
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.mem[1672]", backdoor_value);
        if (!ok) `uvm_fatal("FP16_E2E_BACKDOOR", "failed to initialize DDR result sentinel word 0x688")
        backdoor_value[31:0] = 32'hdada_5511;
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.mem[1716]", backdoor_value);
        if (!ok) `uvm_fatal("MIXED_E2E_BACKDOOR", "failed to initialize independent-reset recovery word 0x6b4")

        backdoor_value[31:0] = vector_plan.bf16_a_word(0);
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.mem[1676]", backdoor_value);
        if (!ok) `uvm_fatal("MIXED_E2E_BACKDOOR", "failed to initialize DDR model word 0x68c")
        backdoor_value[31:0] = vector_plan.bf16_a_word(1);
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.mem[1677]", backdoor_value);
        if (!ok) `uvm_fatal("MIXED_E2E_BACKDOOR", "failed to initialize DDR model word 0x68d")
        backdoor_value[31:0] = vector_plan.bf16_b_word(0);
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.mem[1680]", backdoor_value);
        if (!ok) `uvm_fatal("MIXED_E2E_BACKDOOR", "failed to initialize DDR model word 0x690")
        backdoor_value[31:0] = vector_plan.bf16_b_word(1);
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.mem[1681]", backdoor_value);
        if (!ok) `uvm_fatal("MIXED_E2E_BACKDOOR", "failed to initialize DDR model word 0x691")
        backdoor_value[31:0] = 32'hface_bf16;
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.mem[1684]", backdoor_value);
        if (!ok) `uvm_fatal("MIXED_E2E_BACKDOOR", "failed to initialize DDR result sentinel word 0x694")

        backdoor_value[31:0] = vector_plan.int8_a_word();
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.mem[1688]", backdoor_value);
        if (!ok) `uvm_fatal("MIXED_E2E_BACKDOOR", "failed to initialize DDR INT8 A word 0x698")
        backdoor_value[31:0] = vector_plan.int8_b_word();
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.mem[1692]", backdoor_value);
        if (!ok) `uvm_fatal("MIXED_E2E_BACKDOOR", "failed to initialize DDR INT8 B word 0x69c")
        backdoor_value[31:0] = 32'hface_180d;
        ok = uvm_hdl_deposit("tb_ai_accel_uvm.axi_mem_u.mem[1696]", backdoor_value);
        if (!ok) `uvm_fatal("MIXED_E2E_BACKDOOR", "failed to initialize DDR INT8 result sentinel word 0x6a0")

        `uvm_info("MIXED_E2E_ORDER", $sformatf("seed=%0d permutation=%0d slots=%0d,%0d,%0d (0=FP16,1=BF16,2=INT8)", vector_plan.seed, vector_plan.descriptor_order, vector_plan.operation_at_slot(0), vector_plan.operation_at_slot(1), vector_plan.operation_at_slot(2)), UVM_LOW)
        `uvm_info("MIXED_E2E_VECTOR", $sformatf("seed=%0d SPAD_LAYOUT=%0d FP16 K=%0d A=(%0d,%0d,%0d,%0d) B=(%0d,%0d,%0d,%0d), BF16 K=%0d A=(%0d,%0d,%0d,%0d) B=(%0d,%0d,%0d,%0d), INT8 A=(%0d,%0d,%0d,%0d) B=(%0d,%0d,%0d,%0d)", vector_plan.seed, vector_plan.spad_layout, vector_plan.fp16_length, vector_plan.fp16_a0, vector_plan.fp16_a1, vector_plan.fp16_a2, vector_plan.fp16_a3, vector_plan.fp16_b0, vector_plan.fp16_b1, vector_plan.fp16_b2, vector_plan.fp16_b3, vector_plan.bf16_length, vector_plan.bf16_a0, vector_plan.bf16_a1, vector_plan.bf16_a2, vector_plan.bf16_a3, vector_plan.bf16_b0, vector_plan.bf16_b1, vector_plan.bf16_b2, vector_plan.bf16_b3, vector_plan.int8_a0, vector_plan.int8_a1, vector_plan.int8_a2, vector_plan.int8_a3, vector_plan.int8_b0, vector_plan.int8_b1, vector_plan.int8_b2, vector_plan.int8_b3), UVM_LOW)

        dma_transfer(DDR_A_ADDR, layout_spad_addr(SPAD_A_ADDR), (vector_plan.fp16_length + 1) / 2, 1'b0);
        dma_transfer(DDR_B_ADDR, layout_spad_addr(SPAD_B_ADDR), (vector_plan.fp16_length + 1) / 2, 1'b0);
        dma_transfer(DDR_BF16_A_ADDR, layout_spad_addr(SPAD_BF16_A_ADDR), (vector_plan.bf16_length + 1) / 2, 1'b0);
        dma_transfer(DDR_BF16_B_ADDR, layout_spad_addr(SPAD_BF16_B_ADDR), (vector_plan.bf16_length + 1) / 2, 1'b0);
        dma_transfer(DDR_INT8_A_ADDR, layout_spad_addr(SPAD_INT8_A_ADDR), 1, 1'b0);
        dma_transfer(DDR_INT8_B_ADDR, layout_spad_addr(SPAD_INT8_B_ADDR), 1, 1'b0);
        enqueue_dot_command_batch();
        dma_transfer(DDR_Y_ADDR, layout_spad_addr(SPAD_Y_ADDR), 1, 1'b1);
        dma_transfer(DDR_BF16_Y_ADDR, layout_spad_addr(SPAD_BF16_Y_ADDR), 1, 1'b1);
        dma_transfer(DDR_INT8_Y_ADDR, layout_spad_addr(SPAD_INT8_Y_ADDR), 1, 1'b1);

        backdoor_value = '0;
        ok = uvm_hdl_read("tb_ai_accel_uvm.axi_mem_u.mem[1672]", backdoor_value);
        if (!ok) begin
            `uvm_fatal("FP16_E2E_BACKDOOR", "failed to read back DDR model word 0x688")
        end else if (backdoor_value[31:0] !== reference_model.predict_small_integer_dot(vector_plan.fp16_a0, vector_plan.fp16_a1, vector_plan.fp16_a2, vector_plan.fp16_a3, vector_plan.fp16_b0, vector_plan.fp16_b1, vector_plan.fp16_b2, vector_plan.fp16_b3, vector_plan.fp16_length)) begin
            `uvm_error("MIXED_E2E_DDR_RESULT", $sformatf("FP16 DDR result mismatch actual=0x%08h", backdoor_value[31:0]))
        end

        backdoor_value = '0;
        ok = uvm_hdl_read("tb_ai_accel_uvm.axi_mem_u.mem[1684]", backdoor_value);
        if (!ok) begin
            `uvm_fatal("MIXED_E2E_BACKDOOR", "failed to read back DDR model word 0x694")
        end else if (backdoor_value[31:0] !== reference_model.predict_small_integer_dot(vector_plan.bf16_a0, vector_plan.bf16_a1, vector_plan.bf16_a2, vector_plan.bf16_a3, vector_plan.bf16_b0, vector_plan.bf16_b1, vector_plan.bf16_b2, vector_plan.bf16_b3, vector_plan.bf16_length)) begin
            `uvm_error("MIXED_E2E_DDR_RESULT", $sformatf("BF16 DDR result mismatch actual=0x%08h", backdoor_value[31:0]))
        end

        backdoor_value = '0;
        ok = uvm_hdl_read("tb_ai_accel_uvm.axi_mem_u.mem[1696]", backdoor_value);
        if (!ok)
            `uvm_fatal("MIXED_E2E_BACKDOOR", "failed to read back DDR INT8 result word 0x6a0")
        else if (backdoor_value[31:0] !== reference_model.predict_int8_dot4(
            vector_plan.int8_a0, vector_plan.int8_a1,
            vector_plan.int8_a2, vector_plan.int8_a3,
            vector_plan.int8_b0, vector_plan.int8_b1,
            vector_plan.int8_b2, vector_plan.int8_b3))
            `uvm_error("MIXED_E2E_DDR_RESULT", $sformatf("INT8 DDR result mismatch expected=0x%08h actual=0x%08h", reference_model.predict_int8_dot4(vector_plan.int8_a0, vector_plan.int8_a1, vector_plan.int8_a2, vector_plan.int8_a3, vector_plan.int8_b0, vector_plan.int8_b1, vector_plan.int8_b2, vector_plan.int8_b3), backdoor_value[31:0]))
        run_dma_error_and_reset_recovery();
        `uvm_info("MIXED_E2E_PASS", "queued FP16, BF16, and INT8 dots matched DDR oracles; validator, DMA SLVERR, reset, watchdog, and software-abort lifecycle checks passed", UVM_LOW)
        coverage_sample_valid = 1'b1;
    endtask
endclass
