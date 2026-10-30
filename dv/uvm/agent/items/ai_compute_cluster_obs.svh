class ai_compute_cluster_obs extends uvm_sequence_item;
    `uvm_object_utils(ai_compute_cluster_obs)
    bit core_busy;
    bit cplq_full;
    bit launch_valid;
    bit [7:0] launch_op;
    bit [6:0] engine_busy;
    bit [6:0] engine_done;
    bit [6:0] engine_error;
    bit [6:0] engine_req_valid;
    bit [6:0] engine_req_ready;
    bit engine_backpressure;
    bit multi_engine_abort;
    bit core_spad_valid;
    bit banked_valid;
    bit [3:0] cnm_valid;
    bit matrix_prefetch_active;
    bit matrix_a_cache_hit;
    bit matrix_banked_fault_cancel;
    bit rsp_valid;
    bit [2:0] rsp_client;
    bit [2:0] request_client;
    bit matrix_rsp_valid;
    bit [3:0] cnm_rsp_valid;
    bit [3:0] cnm_accept_mask;
    bit reset_active;
    bit [5:0] read_accept_mask;
    bit mutation_probe;

    bit host_valid, host_write, host_access_ok;
    bit [31:0] host_addr, host_wdata;
    bit [3:0] host_wstrb;
    bit selected_spad_valid, selected_spad_write, selected_spad_ready;
    bit selected_spad_access_ok;
    bit [31:0] selected_spad_addr, selected_spad_wdata;
    bit selected_line_valid, selected_line_write, selected_line_ready;
    bit selected_line_access_ok;
    bit [31:0] selected_line_addr;
    bit [127:0] selected_line_wdata, selected_line_rdata;
    bit [15:0] selected_line_wstrb;
    bit selected_banked_valid, selected_banked_ready, selected_banked_access_ok;
    bit [31:0] selected_banked_addr;
    bit [31:0] matrix_banked_req_addr;
    bit [31:0] banked_rdata[0:3];
    bit [3:0] selected_cnm_valid, selected_cnm_ready, selected_cnm_access_ok;
    bit [31:0] selected_cnm_addr[0:3];
    bit [31:0] cnm_rdata[0:3];
    bit selected_rsp_is_line, selected_rsp_error;
    bit [31:0] selected_rsp_rdata;

    function new(string name = "ai_compute_cluster_obs");
        super.new(name);
    endfunction
endclass
