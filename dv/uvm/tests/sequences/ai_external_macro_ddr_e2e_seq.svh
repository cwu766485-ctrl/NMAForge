class ai_external_macro_ddr_e2e_seq extends ai_fp16_ddr_e2e_seq;
    `uvm_object_utils(ai_external_macro_ddr_e2e_seq)

    localparam bit [31:0] MACRO_CMDQ_ADDR = 32'h0000_7e00;
    localparam bit [31:0] MACRO_CPLQ_ADDR = 32'h0000_7f80;
    localparam bit [63:0] CHILD_LIST_ADDR = 64'h0000_0001_0000_1000;
    localparam bit [31:0] SPAD_A0_ADDR = 32'h0000_7000;
    localparam bit [31:0] SPAD_A1_ADDR = 32'h0000_7010;
    localparam bit [31:0] SPAD_A2_ADDR = 32'h0000_7020;
    localparam bit [31:0] SPAD_B_ADDR  = 32'h0000_7030;
    localparam bit [31:0] SPAD_Y0_ADDR = 32'h0000_7040;
    localparam bit [31:0] SPAD_Y1_ADDR = 32'h0000_7050;
    localparam bit [31:0] SPAD_Y2_ADDR = 32'h0000_7060;
    localparam int unsigned DDR_CHILD_LIST_WORD = 1024;

    function new(string name = "ai_external_macro_ddr_e2e_seq");
        super.new(name);
    endfunction

    task automatic deposit_external_child_descriptor(
        input int unsigned child_index,
        input bit [15:0] task_id,
        input bit [31:0] src0_addr,
        input bit [31:0] dst_addr
    );
        bit [31:0] desc [0:15];
        uvm_hdl_data_t backdoor_value;
        bit ok;
        string path;

        desc[0]  = {task_id, 8'd0, 8'h10};
        desc[1]  = src0_addr;
        desc[2]  = SPAD_B_ADDR;
        desc[3]  = 32'd0;
        desc[4]  = dst_addr;
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

        for (int unsigned word_index = 0; word_index < 16; word_index++) begin
            path = $sformatf("tb_ai_accel_uvm.axi_mem_u.mem[%0d]",
                DDR_CHILD_LIST_WORD + child_index * 16 + word_index);
            backdoor_value = '0;
            backdoor_value[31:0] = desc[word_index];
            ok = uvm_hdl_deposit(path, backdoor_value);
            if (!ok)
                `uvm_fatal("MACRO_E2E_BACKDOOR",
                    $sformatf("failed to initialize external child %0d word %0d", child_index, word_index))
        end
    endtask

    task automatic write_internal_macro_parent();
        bit [31:0] desc [0:15];

        desc[0]  = {16'h6100, 8'd0, 8'h40};
        desc[1]  = CHILD_LIST_ADDR[31:0];
        desc[2]  = CHILD_LIST_ADDR[63:32];
        desc[3]  = 32'd0;
        desc[4]  = 32'd0;
        desc[5]  = 32'h0001_0001;
        desc[6]  = 32'd3;
        desc[7]  = 32'h0000_0008; // ABI-v7 external child-list selector.
        desc[8]  = 32'd0;
        desc[9]  = 32'd0;
        desc[10] = 32'd0;
        desc[11] = 32'd0;
        desc[12] = 32'd0;
        desc[13] = 32'd0;
        desc[14] = 32'd0;
        desc[15] = 32'd7;

        for (int unsigned word_index = 0; word_index < 16; word_index++)
            axil_write(CIMFORGE_SPAD_BASE + MACRO_CMDQ_ADDR + (word_index * 4), desc[word_index]);
    endtask

    virtual task body();
        bit [31:0] value;
        bit [31:0] expected_result [0:2];
        bit [31:0] result_addr [0:2];
        int unsigned poll;
        bit completed;

        expected_result[0] = 32'd4;
        expected_result[1] = 32'd8;
        expected_result[2] = 32'd12;
        result_addr[0] = SPAD_Y0_ADDR;
        result_addr[1] = SPAD_Y1_ADDR;
        result_addr[2] = SPAD_Y2_ADDR;

        // INT8 values are repeated in all four lanes; each child computes
        // 4 * A_lane * B_lane and writes to a distinct scratchpad word.
        axil_write(CIMFORGE_SPAD_BASE + SPAD_A0_ADDR, 32'h0101_0101);
        axil_write(CIMFORGE_SPAD_BASE + SPAD_A1_ADDR, 32'h0202_0202);
        axil_write(CIMFORGE_SPAD_BASE + SPAD_A2_ADDR, 32'h0303_0303);
        axil_write(CIMFORGE_SPAD_BASE + SPAD_B_ADDR,  32'h0101_0101);
        for (int unsigned child_index = 0; child_index < 3; child_index++) begin
            axil_write(CIMFORGE_SPAD_BASE + result_addr[child_index], 32'hface_0000 + child_index);
            deposit_external_child_descriptor(
                child_index, 16'h6111 + child_index,
                (child_index == 0) ? SPAD_A0_ADDR :
                ((child_index == 1) ? SPAD_A1_ADDR : SPAD_A2_ADDR),
                result_addr[child_index]);
        end

        write_internal_macro_parent();
        axil_write(CIMFORGE_REG_CMDQ_BASE_LO, MACRO_CMDQ_ADDR);
        axil_write(32'h0000_0084, 32'd0); // CMDQ_BASE_HI; parent lives in SPAD.
        axil_write(CIMFORGE_REG_CMDQ_SIZE, 32'd4);
        axil_write(CIMFORGE_REG_CMDQ_HEAD, 32'd0);
        axil_write(CIMFORGE_REG_CMDQ_TAIL, 32'd1);
        axil_write(CIMFORGE_REG_CPLQ_BASE_LO, MACRO_CPLQ_ADDR);
        axil_write(32'h0000_0094, 32'd0); // CPLQ_BASE_HI.
        axil_write(CIMFORGE_REG_CPLQ_SIZE, 32'd4);
        axil_write(CIMFORGE_REG_CPLQ_HEAD, 32'd0);
        axil_write(CIMFORGE_REG_CPLQ_TAIL, 32'd0);
        axil_write(32'h0000_00ac, 32'd0); // CMD_CTRL: queue parent fetched internally.
        axil_write(CIMFORGE_REG_DOORBELL, 32'd1);

        completed = 1'b0;
        for (poll = 0; poll < 300; poll++) begin
            axil_read(CIMFORGE_REG_CPLQ_TAIL, value);
            if (value == 32'd1) begin
                completed = 1'b1;
                break;
            end
        end
        if (!completed)
            `uvm_fatal("MACRO_E2E_CPL", "external three-child macro did not retire")

        axil_read(CIMFORGE_REG_CMDQ_HEAD, value);
        if (value !== 32'd1)
            `uvm_error("MACRO_E2E_QUEUE", $sformatf("CMDQ_HEAD expected 1, got %0d", value))

        for (int unsigned child_index = 0; child_index < 3; child_index++) begin
            axil_read(CIMFORGE_SPAD_BASE + result_addr[child_index], value);
            if (value !== expected_result[child_index])
                `uvm_error("MACRO_E2E_RESULT",
                    $sformatf("child %0d result expected=%0d actual=0x%08h",
                        child_index, expected_result[child_index], value))
        end

        axil_read(CIMFORGE_SPAD_BASE + MACRO_CPLQ_ADDR, value);
        if (value[15:0] !== 16'h6100)
            `uvm_error("MACRO_E2E_CPL", $sformatf("parent task ID expected=0x6100, got 0x%08h", value))
        axil_read(CIMFORGE_SPAD_BASE + MACRO_CPLQ_ADDR + 4, value);
        if (value !== 32'd1)
            `uvm_error("MACRO_E2E_CPL", $sformatf("parent status expected success, got 0x%08h", value))
        axil_read(CIMFORGE_SPAD_BASE + MACRO_CPLQ_ADDR + 8, value);
        if (value !== 32'd12)
            `uvm_error("MACRO_E2E_CPL", $sformatf("parent result expected last child result 12, got %0d", value))
        axil_read(CIMFORGE_SPAD_BASE + MACRO_CPLQ_ADDR + 12, value);
        if (value !== 32'd3)
            `uvm_error("MACRO_E2E_CPL", $sformatf("parent element count expected 3, got %0d", value))

        axil_read(CIMFORGE_REG_CPLQ_TAIL, value);
        if (value !== 32'd1)
            `uvm_error("MACRO_E2E_CPL", "macro children must publish exactly one parent completion")
        `uvm_info("MACRO_EXTERNAL_DDR_E2E_PASS",
            "ABI-v7 internal parent fetched three child descriptors from 0x1_0000_1000 over AXI; all INT8 results and the single aggregate completion matched",
            UVM_LOW)
    endtask
endclass
