interface ai_dma_spad_system_if(input logic clk, input logic resetn);
    // Testbench-driven subsystem reset handshake. The UVM test drives only
    // the request; the top-level testbench owns ctrl_if.resetn and returns ack.
    logic subsystem_reset_req;
    logic subsystem_reset_ack;

    // Runtime region configuration for subsystem protection checks.
    logic [31:0] region0_base;
    logic [31:0] region0_limit;
    logic [3:0] region0_perm;

    // Host port used only to initialize/check the real scratchpad contents.
    logic host_valid;
    logic host_write;
    logic [31:0] host_addr;
    logic [31:0] host_wdata;
    logic [3:0] host_wstrb;
    logic [31:0] host_rdata;
    logic host_error;

    // Competing scalar compute-like scheduler client.
    logic core_valid;
    logic core_write;
    logic [31:0] core_addr;
    logic [31:0] core_wdata;
    logic core_ready;
    logic [31:0] core_rdata;
    logic core_rsp_valid;
    logic core_rsp_error;

    // Matrix-like 128-bit banked read requester.  The focused ownership test
    // drives the real memory fabric/arbiter boundary without substituting a
    // behavioral response path.
    logic banked_valid;
    logic [31:0] banked_addr;
    logic banked_ready;
    logic banked_rsp_valid;
    logic [31:0] banked_data0;
    logic [31:0] banked_data1;
    logic [31:0] banked_data2;
    logic [31:0] banked_data3;

    // Real mixed-precision compute client controls/observations. The UVM
    // subsystem test can select this RTL engine instead of the synthetic
    // scalar requester while it shares the same arbiter port with DMA.
    logic fp_mode;
    logic fp_start;
    logic fp_format_fp16;
    logic fp_abort;
    logic [31:0] fp_src0_base;
    logic [31:0] fp_src1_base;
    logic [31:0] fp_dst_base;
    logic [15:0] fp_length;
    logic [31:0] fp_watchdog_limit;
    logic fp_req_valid;
    logic fp_req_write;
    logic [31:0] fp_req_addr;
    logic fp_req_ready;
    logic fp_rsp_valid;
    logic fp_rsp_error;
    logic fp_busy;
    logic fp_done;
    logic fp_error;
    logic [3:0] fp_error_code;
    logic [31:0] fp_result;
    logic [31:0] fp_cycle_count;
    logic [31:0] fp_element_count;

    // Real four-bank CNM client used for DMA/SPAD contention verification.
    logic cnm_mode;
    logic cnm_start;
    logic cnm_abort;
    logic [7:0] cnm_op_mode;
    logic [31:0] cnm_src0_base;
    logic [31:0] cnm_src1_base;
    logic [31:0] cnm_dst_base;
    logic [15:0] cnm_length;
    logic [15:0] cnm_m_size;
    logic [4:0] cnm_scale_shift;
    logic [1:0] cnm_activation;
    logic [31:0] cnm_watchdog_limit;
    logic [3:0] cnm_req_valid;
    logic [31:0] cnm_addr0;
    logic [31:0] cnm_addr1;
    logic [31:0] cnm_addr2;
    logic [31:0] cnm_addr3;
    logic [3:0] cnm_req_ready;
    logic [3:0] cnm_rsp_valid;
    logic [31:0] cnm_data0;
    logic [31:0] cnm_data1;
    logic [31:0] cnm_data2;
    logic [31:0] cnm_data3;
    logic [3:0] cnm_parity_error;
    logic cnm_protection_error;
    logic cnm_spad_valid;
    logic cnm_spad_write;
    logic [31:0] cnm_spad_addr;
    logic [31:0] cnm_spad_wdata;
    logic cnm_spad_protection_error;
    logic cnm_busy;
    logic cnm_done;
    logic cnm_error;
    logic [3:0] cnm_error_code;
    logic [31:0] cnm_result;
    logic [31:0] cnm_cycle_count;
    logic [31:0] cnm_element_count;
    logic [31:0] cnm_local_accumulate_events;
    logic [31:0] cnm_global_reduce_events;
    logic [31:0] cnm_banked_read_issue_events;
    logic [31:0] cnm_prefetch_events;
    logic [31:0] cnm_pipeline_compute_events;
    logic [31:0] cnm_response_wait_cycles;

    // Synthetic descriptor/completion clients exercise control-plane priority.
    logic desc_valid;
    logic [31:0] desc_addr;
    logic desc_ready;
    logic desc_rsp_valid;
    logic desc_rsp_error;
    logic cpl_valid;
    logic cpl_write;
    logic [31:0] cpl_addr;
    logic [31:0] cpl_wdata;
    logic cpl_ready;

    // Passive visibility into the shared scheduler port and DMA grants.
    logic dma_valid;
    logic dma_write;
    logic dma_ready;
    logic dma_rsp_valid;
    logic dma_line_valid;
    logic dma_line_ready;
    logic dma_line_rsp_valid;
    logic [2:0] request_client;
    logic arb_rsp_valid;
    logic [2:0] arb_rsp_client;
    logic arb_rsp_is_line;
    logic [31:0] arb_rsp_rdata;
    logic arb_rsp_error;

    initial begin
        subsystem_reset_req = 1'b0;
        host_valid = 1'b0;
        host_write = 1'b0;
        host_addr = '0;
        host_wdata = '0;
        host_wstrb = '0;
        region0_base = '0;
        region0_limit = '0;
        region0_perm = '0;
        core_valid = 1'b0;
        core_write = 1'b0;
        core_addr = '0;
        core_wdata = '0;
        banked_valid = 1'b0;
        banked_addr = '0;
        fp_mode = 1'b0;
        fp_start = 1'b0;
        fp_format_fp16 = 1'b0;
        fp_abort = 1'b0;
        fp_src0_base = '0;
        fp_src1_base = '0;
        fp_dst_base = '0;
        fp_length = '0;
        fp_watchdog_limit = '0;
        cnm_mode = 1'b0;
        cnm_start = 1'b0;
        cnm_abort = 1'b0;
        cnm_op_mode = '0;
        cnm_src0_base = '0;
        cnm_src1_base = '0;
        cnm_dst_base = '0;
        cnm_length = '0;
        cnm_m_size = '0;
        cnm_scale_shift = '0;
        cnm_activation = '0;
        cnm_watchdog_limit = '0;
        desc_valid = 1'b0;
        desc_addr = '0;
        cpl_valid = 1'b0;
        cpl_write = 1'b0;
        cpl_addr = '0;
        cpl_wdata = '0;
    end
endinterface
