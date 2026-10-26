class ai_compute_cluster_obs extends uvm_sequence_item;
    `uvm_object_utils(ai_compute_cluster_obs)
    bit core_busy;
    bit launch_valid;
    bit [7:0] launch_op;
    bit [6:0] engine_busy;
    bit [6:0] engine_done;
    bit [6:0] engine_error;
    bit [6:0] engine_req_valid;
    bit core_spad_valid;
    bit banked_valid;
    bit [3:0] cnm_valid;
    bit matrix_prefetch_active;
    bit matrix_a_cache_hit;
    bit rsp_valid;
    bit [2:0] rsp_client;
    bit [2:0] request_client;
    bit matrix_rsp_valid;
    bit [3:0] cnm_rsp_valid;
    bit [3:0] cnm_accept_mask;
    bit reset_active;
    bit [5:0] read_accept_mask;

    function new(string name = "ai_compute_cluster_obs");
        super.new(name);
    endfunction
endclass
