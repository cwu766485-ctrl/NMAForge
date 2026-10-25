`timescale 1ns/1ps

interface ai_parallel_compute_if(input logic clk);
    logic resetn;
    logic submit;
    logic abort;
    logic [31:0] cmdq_tail;
    logic [31:0] cplq_head;
    logic [31:0] cplq_size;
    logic [6:0] engine_busy;
    logic [6:0] engine_done;
    logic [6:0] engine_error;
    logic [27:0] engine_error_code;
    logic [223:0] engine_result;
    logic [223:0] engine_cycles;
    logic [223:0] engine_elements;
    logic completion_busy;
    logic completion_done;

    logic fetch_start;
    logic [63:0] fetch_base;
    logic fetch_done;
    logic fetch_error;
    logic [7:0] desc_op;
    logic [15:0] desc_task_id;
    logic [31:0] desc_src0, desc_src1, desc_dst, desc_bias_base;
    logic [15:0] desc_length, desc_m, desc_n, desc_k;
    logic [4:0] desc_shift;
    logic [1:0] desc_activation;
    logic desc_bias_enable;
    logic [7:0] desc_flags;
    logic [31:0] desc_aux0, desc_src0_stride, desc_src1_stride, desc_dst_stride;
    logic [15:0] desc_batch_count, desc_head_count;
    logic [15:0] desc_wait_mask, desc_signal_mask, desc_clear_mask;
    logic [7:0] desc_version;

    logic launch_valid;
    logic [7:0] launch_op;
    logic [15:0] launch_task_id;
    logic [31:0] launch_src0, launch_src1, launch_dst;
    logic [15:0] launch_length, launch_m, launch_n, launch_k;
    logic [4:0] launch_shift;
    logic [1:0] launch_activation;
    logic [31:0] launch_bias_base;
    logic launch_bias_enable;
    logic [7:0] launch_flags;
    logic [31:0] launch_aux0, launch_src0_stride, launch_src1_stride, launch_dst_stride;
    logic [15:0] launch_batch_count, launch_head_count;

    logic completion_start;
    logic [15:0] completion_task_id;
    logic [3:0] completion_status, completion_error_code;
    logic [31:0] completion_result, completion_elements;
    logic [31:0] cmdq_head, cplq_tail;
    logic dispatcher_busy;
    logic event_valid, event_error;
    logic [3:0] event_error_code;

    logic [6:0] req_valid, req_write, req_ready, req_protection_error;
    logic [223:0] req_addr, req_wdata, engine_rsp_rdata;
    logic spad_valid, spad_write, spad_ready, spad_protection_error;
    logic [31:0] spad_addr, spad_wdata;
    logic rsp_valid, rsp_error, rsp_parity_error;
    logic [31:0] rsp_rdata;
    logic [6:0] engine_rsp_valid, engine_rsp_error;

    logic [7:0] debug_fifo_done;
    logic [7:0] debug_fifo_error;
    logic [3:0] debug_fifo_count;
    logic [1:0] debug_issue_state;
    logic [6:0] debug_engine_active;
    logic debug_desc_invalid;
    logic debug_cplq_full;
    logic out_of_order_seen;
    logic simultaneous_done_seen;
    logic [20:0] pair_overlap_seen;
    logic [20:0] pair_coverage_ever;
    logic [4:0] scenario_coverage_seen;
    integer launch_count, accepted_read_count, accepted_write_count;
    integer parallel_seed;
    integer response_owner_errors, request_stall_count, completion_log_count;
    logic [15:0] launch_log_id [0:15];
    logic [15:0] completion_log_id [0:7];
    logic [3:0] completion_log_status [0:7];
    logic [3:0] completion_log_error [0:7];
    logic [31:0] completion_log_result [0:7];
    logic [31:0] completion_log_elements [0:7];
    logic spad_read_error_enable;
    logic [2:0] spad_read_error_owner;
    logic simultaneous_done_enable;
    logic [2:0] simultaneous_done_engine0, simultaneous_done_engine1;
    logic spad_write_stall_enable;

    logic [7:0] desc_mem_op [0:7];
    logic [15:0] desc_mem_task_id [0:7];
    logic [15:0] desc_mem_length [0:7], desc_mem_m [0:7], desc_mem_n [0:7], desc_mem_k [0:7];
    logic [7:0] desc_mem_version [0:7];
    integer desc_mem_engine_latency [0:7];
    integer desc_mem_fetch_latency [0:7];
    logic desc_mem_read_error [0:7];

    logic [2:0] model_state [0:6];
    integer model_delay [0:6];
    logic model_abort_pending [0:6];
    logic model_read_error [0:6];
    logic [15:0] model_task_id [0:6];
    logic [31:0] model_read_addr [0:6], model_write_addr [0:6], model_write_data [0:6];
    integer model_latency [0:6];
    logic [31:0] model_read_expected [0:6];
    logic [31:0] accepted_read_data_d;
    logic accepted_read_error_d, accepted_read_d;
    logic [31:0] accepted_read_data_q;
    logic spad_ready_rand;
    logic [31:0] spad_lfsr;
    logic [31:0] fetch_lfsr;
    integer fetch_pending, fetch_index, fetch_delay;
    logic completion_pending;
    integer completion_delay;
    integer launch_engine;
    integer owner_index;
    integer i, j, pair_index;
    integer pair_sample_index;

    covergroup engine_pair_cg;
        cp_engine_pair: coverpoint pair_sample_index {
            bins all_unordered_pairs[21] = {[0:20]};
        }
    endgroup
    engine_pair_cg engine_pair_cov = new();

    covergroup parallel_scenario_cg with function sample(input integer scenario_id);
        cp_parallel_scenario: coverpoint scenario_id {
            bins queue_full_out_of_order = {1};
            bins all_engine_pairs = {2};
            bins owner_error = {3};
            bins abort_drain = {4};
            bins active_reset_recovery = {5};
        }
    endgroup
    parallel_scenario_cg scenario_cov = new();

    initial begin
        parallel_seed=20261024;
        void'($value$plusargs("PARALLEL_SEED=%d",parallel_seed));
        pair_coverage_ever=21'd0;
        scenario_coverage_seen=5'd0;
    end

    localparam logic [2:0] MODEL_IDLE=3'd0, MODEL_READ_REQ=3'd1,
                           MODEL_READ_WAIT=3'd2, MODEL_WRITE_REQ=3'd3,
                           MODEL_DELAY=3'd4;

    function automatic integer engine_for_op(input logic [7:0] op);
        if (op==8'h50 || op==8'h51) engine_for_op=1;
        else if (op==8'h20 || op==8'h21) engine_for_op=2;
        else if (op==8'h30 || op==8'h31) engine_for_op=3;
        else if (op>=8'h32 && op<=8'h39) engine_for_op=4;
        else if (op==8'h16 || op==8'h17) engine_for_op=5;
        else if (op==8'h43 || op==8'h44) engine_for_op=6;
        else engine_for_op=0;
    endfunction

    function automatic integer slot_for_task(input logic [15:0] task_id);
        integer slot;
        begin
            slot_for_task=-1;
            for (slot=0;slot<8;slot=slot+1)
                if (desc_mem_task_id[slot]===task_id) slot_for_task=slot;
        end
    endfunction

    always_comb begin
        req_valid=7'd0;
        req_write=7'd0;
        req_addr=224'd0;
        req_wdata=224'd0;
        for (integer e=0;e<7;e=e+1) begin
            if (model_state[e]==MODEL_READ_REQ) begin
                req_valid[e]=1'b1;
                req_addr[e*32 +: 32]=model_read_addr[e];
            end else if (model_state[e]==MODEL_WRITE_REQ) begin
                req_valid[e]=1'b1;
                req_write[e]=1'b1;
                req_addr[e*32 +: 32]=model_write_addr[e];
                req_wdata[e*32 +: 32]=model_write_data[e];
            end
        end
        spad_ready=spad_ready_rand &&
                   !(spad_write_stall_enable && spad_valid && spad_write);
    end

    // The SPAD response has the real one-cycle registered latency. Random
    // grant stalls, descriptor fetch delay, engine service delay, and
    // completion-writer delay vary across runs without violating that port
    // contract.
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            spad_ready_rand<=1'b0;
            rsp_valid<=1'b0;
            rsp_error<=1'b0;
            rsp_parity_error<=1'b0;
            rsp_rdata<=32'd0;
            accepted_read_d<=1'b0;
            accepted_read_data_d<=32'd0;
            accepted_read_error_d<=1'b0;
            spad_lfsr<=32'h45a1_0f31 ^ parallel_seed;
            accepted_read_count<=0;
            accepted_write_count<=0;
            request_stall_count<=0;
        end else begin
            spad_lfsr<={spad_lfsr[30:0],spad_lfsr[31]^spad_lfsr[21]^spad_lfsr[1]^spad_lfsr[0]};
            spad_ready_rand<=spad_lfsr[0] | spad_lfsr[3] | spad_lfsr[7];
            rsp_valid<=accepted_read_d;
            rsp_rdata<=accepted_read_data_d;
            rsp_error<=accepted_read_error_d;
            accepted_read_d<=spad_valid && spad_ready && !spad_write;
            accepted_read_data_d<=spad_addr ^ 32'h5a5a_0000;
            accepted_read_error_d<=1'b0;
            if (spad_valid && !spad_ready)
                request_stall_count<=request_stall_count+1;
            if (spad_valid && spad_ready && !spad_write) begin
                accepted_read_count<=accepted_read_count+1;
                owner_index=0;
                for (integer k=0;k<7;k=k+1)
                    if (req_ready[k]) owner_index=k;
                accepted_read_error_d<=spad_read_error_enable &&
                                       (owner_index==spad_read_error_owner) ||
                                       model_read_error[owner_index];
            end
            if (spad_valid && spad_ready && spad_write)
                accepted_write_count<=accepted_write_count+1;
        end
    end

    // Descriptor fetch model: seeded 0..3-cycle delay, descriptors are
    // returned from the CMDQ slot selected by fetch_base.
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            fetch_pending<=0;fetch_index<=0;fetch_delay<=0;
            fetch_done<=1'b0;fetch_error<=1'b0;
            desc_op<=0;desc_task_id<=0;desc_src0<=0;desc_src1<=0;desc_dst<=0;
            desc_bias_base<=0;desc_length<=0;desc_m<=0;desc_n<=0;desc_k<=0;
            desc_shift<=0;desc_activation<=0;desc_bias_enable<=0;desc_flags<=0;
            desc_aux0<=0;desc_src0_stride<=0;desc_src1_stride<=0;desc_dst_stride<=0;
            desc_batch_count<=0;desc_head_count<=0;desc_wait_mask<=0;
            desc_signal_mask<=0;desc_clear_mask<=0;desc_version<=0;
            fetch_lfsr<=32'h0b17_2026 ^ parallel_seed;
        end else begin
            fetch_lfsr<={fetch_lfsr[30:0],fetch_lfsr[31]^fetch_lfsr[6]^fetch_lfsr[4]^fetch_lfsr[2]};
            fetch_done<=1'b0;
            if (fetch_start && !fetch_pending) begin
                fetch_index=(fetch_base-64'h1000)>>6;
                fetch_pending<=1;
                fetch_delay<=desc_mem_fetch_latency[fetch_index];
            end else if (fetch_pending && fetch_delay>0) begin
                fetch_delay<=fetch_delay-1;
            end else if (fetch_pending) begin
                desc_op<=desc_mem_op[fetch_index];
                desc_task_id<=desc_mem_task_id[fetch_index];
                desc_length<=desc_mem_length[fetch_index];
                desc_m<=desc_mem_m[fetch_index];desc_n<=desc_mem_n[fetch_index];
                desc_k<=desc_mem_k[fetch_index];desc_version<=desc_mem_version[fetch_index];
                desc_src0<=32'h1000+(fetch_index*32'h100);
                desc_src1<=32'h1080+(fetch_index*32'h100);
                desc_dst<=32'h2000+(fetch_index*32'h100);
                desc_bias_base<=0;desc_shift<=0;desc_activation<=0;
                desc_bias_enable<=0;desc_flags<=0;desc_aux0<=0;
                desc_src0_stride<=0;desc_src1_stride<=0;desc_dst_stride<=0;
                desc_batch_count<=0;desc_head_count<=0;
                desc_wait_mask<=0;desc_signal_mask<=0;desc_clear_mask<=0;
                fetch_error<=1'b0;fetch_done<=1'b1;fetch_pending<=0;
            end
        end
    end

    // Seven independent behavioral Engine response models drive the real
    // Compute SPAD MUX and the real parallel dispatcher. A model issues one
    // read and one write per accepted task and exposes independent latency,
    // error, and simultaneous-Done controls.
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            engine_busy<=0;engine_done<=0;engine_error<=0;
            engine_error_code<=0;engine_result<=0;engine_cycles<=0;engine_elements<=0;
            launch_count<=0;response_owner_errors<=0;simultaneous_done_seen<=0;
            for (integer n=0;n<16;n=n+1) launch_log_id[n]<=0;
            for (integer e=0;e<7;e=e+1) begin
                model_state[e]<=MODEL_IDLE;model_delay[e]<=0;
                model_abort_pending[e]<=0;model_read_error[e]<=0;
                model_task_id[e]<=0;model_read_addr[e]<=0;model_write_addr[e]<=0;
                model_write_data[e]<=0;model_latency[e]<=0;model_read_expected[e]<=0;
            end
        end else begin
            engine_done<=0;
            if (launch_valid) begin
                launch_engine=engine_for_op(launch_op);
                owner_index=slot_for_task(launch_task_id);
                if (owner_index<0)
                    $fatal(1,"parallel UVM launch has no descriptor model task=%04h",launch_task_id);
                if (engine_busy[launch_engine])
                    response_owner_errors<=response_owner_errors+1;
                engine_busy[launch_engine]<=1'b1;
                model_state[launch_engine]<=MODEL_READ_REQ;
                model_task_id[launch_engine]<=launch_task_id;
                model_read_addr[launch_engine]<=32'h1000+(launch_task_id<<2)+(launch_engine<<8);
                model_read_expected[launch_engine]<=
                    (32'h1000+(launch_task_id<<2)+(launch_engine<<8)) ^ 32'h5a5a_0000;
                model_write_addr[launch_engine]<=32'h2000+(launch_task_id<<2)+(launch_engine<<8);
                model_write_data[launch_engine]<={launch_task_id[15:0],8'd0,launch_engine[7:0]};
                model_latency[launch_engine]<=desc_mem_engine_latency[owner_index];
                model_delay[launch_engine]<=desc_mem_engine_latency[owner_index];
                model_read_error[launch_engine]<=desc_mem_read_error[owner_index];
                model_abort_pending[launch_engine]<=1'b0;
                engine_error[launch_engine]<=1'b0;
                engine_error_code[launch_engine*4 +: 4]<=0;
                engine_cycles[launch_engine*32 +: 32]<=0;
                launch_log_id[launch_count]<=launch_task_id;
                launch_count<=launch_count+1;
                launch_count<=launch_count+1;
            end else begin
                for (integer e=0;e<7;e=e+1)
                    if (engine_busy[e]) engine_cycles[e*32 +: 32]<=engine_cycles[e*32 +: 32]+1;
            end

            if (abort)
                for (integer e=0;e<7;e=e+1)
                    if (engine_busy[e]) model_abort_pending[e]<=1'b1;

            if (simultaneous_done_enable && !simultaneous_done_seen &&
                model_state[simultaneous_done_engine0]==MODEL_DELAY &&
                model_state[simultaneous_done_engine1]==MODEL_DELAY &&
                engine_busy[simultaneous_done_engine0] && engine_busy[simultaneous_done_engine1]) begin
                engine_done[simultaneous_done_engine0]<=1'b1;
                engine_done[simultaneous_done_engine1]<=1'b1;
                engine_busy[simultaneous_done_engine0]<=1'b0;
                engine_busy[simultaneous_done_engine1]<=1'b0;
                engine_result[simultaneous_done_engine0*32 +: 32]<=model_write_data[simultaneous_done_engine0];
                engine_result[simultaneous_done_engine1*32 +: 32]<=model_write_data[simultaneous_done_engine1];
                engine_elements[simultaneous_done_engine0*32 +: 32]<=1;
                engine_elements[simultaneous_done_engine1*32 +: 32]<=1;
                model_state[simultaneous_done_engine0]<=MODEL_IDLE;
                model_state[simultaneous_done_engine1]<=MODEL_IDLE;
                simultaneous_done_seen<=1'b1;
            end else begin
                for (integer e=0;e<7;e=e+1) begin
                    if (engine_busy[e]) begin
                        if (model_abort_pending[e] || abort) begin
                            if (model_state[e]==MODEL_READ_WAIT && !engine_rsp_valid[e]) begin
                                // Drain a registered response already accepted
                                // by the shared SPAD before reporting abort.
                            end else begin
                                engine_done[e]<=1'b1;engine_error[e]<=1'b1;
                                engine_error_code[e*4 +: 4]<=4'd3;
                                engine_busy[e]<=1'b0;model_state[e]<=MODEL_IDLE;
                                engine_elements[e*32 +: 32]<=0;
                            end
                        end else begin
                            case (model_state[e])
                                MODEL_READ_REQ: if (req_ready[e]) model_state[e]<=MODEL_READ_WAIT;
                                MODEL_READ_WAIT: if (engine_rsp_valid[e]) begin
                                    if (engine_rsp_rdata[e*32 +: 32]!==model_read_expected[e])
                                        response_owner_errors<=response_owner_errors+1;
                                    if (engine_rsp_error[e]) begin
                                        engine_done[e]<=1'b1;engine_error[e]<=1'b1;
                                        engine_error_code[e*4 +: 4]<=4'd5;
                                        engine_result[e*32 +: 32]<=0;engine_elements[e*32 +: 32]<=0;
                                        engine_busy[e]<=1'b0;model_state[e]<=MODEL_IDLE;
                                    end else model_state[e]<=MODEL_WRITE_REQ;
                                end
                                MODEL_WRITE_REQ: if (req_ready[e]) model_state[e]<=MODEL_DELAY;
                                MODEL_DELAY: if (model_delay[e]>0) model_delay[e]<=model_delay[e]-1;
                                default: begin end
                            endcase
                            if (model_state[e]==MODEL_DELAY && model_delay[e]==0 &&
                                !(simultaneous_done_enable &&
                                  (e==simultaneous_done_engine0 || e==simultaneous_done_engine1))) begin
                                engine_done[e]<=1'b1;engine_error[e]<=1'b0;
                                engine_error_code[e*4 +: 4]<=0;
                                engine_result[e*32 +: 32]<=model_write_data[e];
                                engine_elements[e*32 +: 32]<=1;
                                engine_busy[e]<=1'b0;model_state[e]<=MODEL_IDLE;
                            end
                        end
                    end
                end
            end
        end
    end

    // Completion Writer model adds independent latency and records the exact
    // payload offered by the FIFO head.
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            completion_busy<=0;completion_done<=0;completion_pending<=0;
            completion_delay<=0;completion_log_count<=0;
            for (integer n=0;n<8;n=n+1) begin
                completion_log_id[n]<=0;completion_log_status[n]<=0;
                completion_log_error[n]<=0;completion_log_result[n]<=0;
                completion_log_elements[n]<=0;
            end
        end else begin
            completion_done<=0;
            if (completion_start && !completion_busy) begin
                completion_busy<=1;completion_pending<=1;
                completion_delay<=1+(fetch_lfsr[1:0]);
                completion_log_id[completion_log_count]<=completion_task_id;
                completion_log_status[completion_log_count]<=completion_status;
                completion_log_error[completion_log_count]<=completion_error_code;
                completion_log_result[completion_log_count]<=completion_result;
                completion_log_elements[completion_log_count]<=completion_elements;
                completion_log_count<=completion_log_count+1;
            end else if (completion_busy) begin
                if (completion_delay>0) completion_delay<=completion_delay-1;
                else begin completion_done<=1;completion_busy<=0;completion_pending<=0;end
            end
        end
    end

    // Transaction-level UVM BFM API.
    task automatic configure_descriptor(input integer slot,input logic [7:0] op,
        input logic [15:0] task_id,input integer service_latency,
        input bit inject_read_error,input integer fetch_latency);
        begin
            desc_mem_op[slot]=op;desc_mem_task_id[slot]=task_id;
            desc_mem_engine_latency[slot]=service_latency;
            desc_mem_read_error[slot]=inject_read_error;
            desc_mem_fetch_latency[slot]=fetch_latency;
            desc_mem_length[slot]=16'd1;desc_mem_m[slot]=16'd1;
            desc_mem_n[slot]=16'd1;desc_mem_k[slot]=16'd1;
            desc_mem_version[slot]=8'd7;
            if (op==8'h51 || op==8'h50) begin
                desc_mem_m[slot]=1;desc_mem_n[slot]=1;desc_mem_version[slot]=7;
            end else if (op==8'h30 || op==8'h31) begin
                desc_mem_m[slot]=4;desc_mem_n[slot]=4;desc_mem_k[slot]=1;
                desc_mem_version[slot]=3;
            end else if (op>=8'h32 && op<=8'h39) begin
                desc_mem_length[slot]=16'd1;desc_mem_version[slot]=3;
            end else if (op==8'h16 || op==8'h17) begin
                desc_mem_m[slot]=3;desc_mem_n[slot]=3;desc_mem_version[slot]=5;
            end else if (op==8'h43 || op==8'h44) begin
                desc_mem_version[slot]=5;
            end
        end
    endtask

    task automatic pulse_submit(input integer count);
        begin
            cmdq_tail=count;@(negedge clk);submit=1;@(negedge clk);submit=0;
        end
    endtask

    task automatic wait_launch_count(input integer count,input integer limit);
        integer cycles;
        begin
            cycles=0;
            while (launch_count<count && cycles<limit) begin @(negedge clk);cycles=cycles+1;end
            if (launch_count<count) $fatal(1,"parallel UVM launch timeout expected=%0d actual=%0d fetch_start=%b fetch_pending=%0d fetch_done=%b desc_op=%02h desc_id=%04h head=%0d tail=%0d busy=%b issue=%0d invalid=%b active=%b fifo=%0d done=%b error=%b event=%b err=%b/%0d",
                count,launch_count,fetch_start,fetch_pending,fetch_done,desc_op,desc_task_id,
                cmdq_head,cmdq_tail,dispatcher_busy,debug_issue_state,debug_desc_invalid,
                debug_engine_active,debug_fifo_count,debug_fifo_done,debug_fifo_error,
                event_valid,event_error,event_error_code);
        end
    endtask

    task automatic wait_cpl_tail(input logic [31:0] value,input integer limit);
        integer cycles;
        begin
            cycles=0;
            while(cplq_tail!==value && cycles<limit) begin @(negedge clk);cycles=cycles+1;end
            if(cplq_tail!==value) $fatal(1,"parallel UVM CPL tail timeout expected=%0d actual=%0d",value,cplq_tail);
        end
    endtask

    task automatic reset_and_clear;
        begin
            @(negedge clk);resetn=0;submit=0;abort=0;cmdq_tail=0;cplq_head=0;cplq_size=4;
            spad_read_error_enable=0;spad_read_error_owner=0;
            simultaneous_done_enable=0;simultaneous_done_engine0=1;simultaneous_done_engine1=2;
            simultaneous_done_seen=0;spad_write_stall_enable=0;
            repeat(3) @(negedge clk);resetn=1;repeat(3) @(negedge clk);
            for(integer s=0;s<8;s=s+1) begin
                desc_mem_op[s]=0;desc_mem_task_id[s]=0;desc_mem_length[s]=1;
                desc_mem_m[s]=1;desc_mem_n[s]=1;desc_mem_k[s]=1;desc_mem_version[s]=7;
                desc_mem_engine_latency[s]=0;desc_mem_fetch_latency[s]=0;desc_mem_read_error[s]=0;
            end
        end
    endtask

    task automatic run_campaign;
        integer idx,cycles;
        logic [15:0] expected_id;
        logic [7:0] expected_engine;
        logic [31:0] expected_tail,expected_result;
        begin
            // Cross-engine overlap, opposite completion order, simultaneous
            // Done, same-engine queueing, randomized SPAD grant stalls and
            // CPLQ full hold/resume all use the real RTL dispatcher and mux.
            reset_and_clear();
            cplq_size=2;
            configure_descriptor(0,8'h32,16'h0100,14,0,0);
            configure_descriptor(1,8'h51,16'h0101,1,0,2);
            configure_descriptor(2,8'h20,16'h0102,1,0,1);
            configure_descriptor(3,8'h10,16'h0103,2,0,3);
            configure_descriptor(4,8'h36,16'h0104,1,0,0);
            simultaneous_done_enable=1;
            simultaneous_done_engine0=1;simultaneous_done_engine1=2;
            pulse_submit(5);
            wait_launch_count(4,2000);
            if ($countones(engine_busy)<2)
                $fatal(1,"parallel UVM did not observe cross-engine overlap");
            cycles=0;
            while ((!simultaneous_done_seen || !out_of_order_seen ||
                    engine_busy!=0 || cplq_tail!=1 || debug_fifo_count<4) && cycles<50000) begin
                @(negedge clk);cycles=cycles+1;
            end
            if (cycles>=50000)
                $fatal(1,"parallel UVM overlap/FIFO closure timeout busy=%b tail=%0d fifo=%0d simdone=%b ooo=%b",
                       engine_busy,cplq_tail,debug_fifo_count,simultaneous_done_seen,out_of_order_seen);
            repeat(20) @(negedge clk);
            if (cplq_tail!=1 || !debug_cplq_full || debug_fifo_count<4)
                $fatal(1,"CPLQ full did not hold buffered completions tail=%0d fifo=%0d",cplq_tail,debug_fifo_count);
            if (accepted_read_count<4 || accepted_write_count<3 || request_stall_count==0)
                $fatal(1,"SPAD owner/stall traffic too small reads=%0d writes=%0d stalls=%0d",
                       accepted_read_count,accepted_write_count,request_stall_count);
            if (response_owner_errors!=0)
                $fatal(1,"SPAD response owner/data errors=%0d",response_owner_errors);

            for(idx=0;idx<5;idx=idx+1) begin
                expected_id=16'h0100+idx;
                expected_tail=(idx+1)%2;
                if (completion_log_count<=idx)
                    wait_cpl_tail(expected_tail,5000);
                if (completion_log_id[idx]!==expected_id ||
                    completion_log_status[idx]!==4'd1 || completion_log_error[idx]!==0)
                    $fatal(1,"parallel UVM FIFO completion[%0d] got id=%04h status=%0d err=%0d expected id=%04h",
                           idx,completion_log_id[idx],completion_log_status[idx],completion_log_error[idx],expected_id);
                expected_engine=engine_for_op(desc_mem_op[idx]);
                expected_result={expected_id,8'd0,expected_engine};
                if(completion_log_result[idx]!==expected_result || completion_log_elements[idx]!==1)
                    $fatal(1,"parallel UVM FIFO payload mismatch slot=%0d result=%08h expected=%08h elements=%0d",
                           idx,completion_log_result[idx],expected_result,completion_log_elements[idx]);
                if(launch_log_id[idx]!==expected_id)
                    $fatal(1,"parallel UVM launch order mismatch slot=%0d id=%04h expected=%04h",
                           idx,launch_log_id[idx],expected_id);
                if(idx<4) cplq_head=(idx+1)%2;
                if(idx<4) begin
                    cycles=0;
                    while(cplq_tail!==((idx+2)%2) && cycles<5000) begin @(negedge clk);cycles=cycles+1;end
                    if(cycles>=5000) $fatal(1,"CPLQ did not resume after consumer advanced head");
                end
            end
            simultaneous_done_enable=0;
            if (!simultaneous_done_seen || !out_of_order_seen)
                $fatal(1,"parallel UVM missed simultaneous or out-of-order completion");
            if (response_owner_errors!=0)
                $fatal(1,"parallel UVM SPAD owner checker failed after drain");
            $display("[PARALLEL_UVM_FIFO_PASS] launches=%0d out_of_order=1 simultaneous_done=1 cplq_full_resume=1 owner_errors=%0d stalls=%0d",
                     launch_count,response_owner_errors,request_stall_count);
            scenario_cov.sample(1);
            scenario_coverage_seen[0]=1'b1;

            // Keep every engine occupied together long enough to measure all
            // unordered pairs through the actual dispatcher launch path.
            reset_and_clear();cplq_size=8;
            configure_descriptor(0,8'h10,16'h0110,30,0,0);
            configure_descriptor(1,8'h51,16'h0111,30,0,1);
            configure_descriptor(2,8'h20,16'h0112,30,0,0);
            configure_descriptor(3,8'h30,16'h0113,30,0,1);
            configure_descriptor(4,8'h35,16'h0114,30,0,0);
            configure_descriptor(5,8'h16,16'h0115,30,0,2);
            configure_descriptor(6,8'h43,16'h0116,30,0,1);
            pulse_submit(7);
            cycles=0;
            while(engine_busy!=7'h7f && cycles<10000) begin @(negedge clk);cycles=cycles+1;end
            if(engine_busy!=7'h7f)
                $fatal(1,"parallel UVM failed to overlap all seven engines busy=%b launches=%0d",engine_busy,launch_count);
            repeat(2) @(negedge clk);
            if(pair_overlap_seen!==21'h1fffff)
                $fatal(1,"parallel UVM unordered pair coverage incomplete mask=%021b",pair_overlap_seen);
            wait_cpl_tail(7,30000);
            cycles=0;
            while(dispatcher_busy && cycles<1000) begin @(negedge clk);cycles=cycles+1;end
            if(completion_log_count!=7 || engine_busy!=0 || dispatcher_busy)
                $fatal(1,"all-engine overlap drain incomplete completions=%0d busy=%b dispatcher=%b",
                       completion_log_count,engine_busy,dispatcher_busy);
            for(idx=0;idx<7;idx=idx+1) begin
                expected_id=16'h0110+idx;
                expected_engine=engine_for_op(desc_mem_op[idx]);
                if(completion_log_id[idx]!==16'h0110+idx || completion_log_status[idx]!==4'd1 ||
                   completion_log_elements[idx]!==1 ||
                   completion_log_result[idx]!=={expected_id,8'd0,expected_engine} ||
                   launch_log_id[idx]!==expected_id)
                    $fatal(1,"all-engine overlap owner/order/payload mismatch slot=%0d id=%04h result=%08h",
                           idx,completion_log_id[idx],completion_log_result[idx]);
            end
            $display("[PARALLEL_UVM_ALL_ENGINE_PAIR_PASS] engines=7 unordered_pairs=21/21 ordered_completions=7");
            scenario_cov.sample(2);
            scenario_coverage_seen[1]=1'b1;

            // A read error belongs only to its accepted Engine requester and
            // must become that descriptor's error completion.
            reset_and_clear();cplq_size=4;spad_read_error_enable=1;spad_read_error_owner=1;
            configure_descriptor(0,8'h10,16'h0200,1,0,0);
            configure_descriptor(1,8'h51,16'h0201,1,1,1);
            pulse_submit(2);wait_cpl_tail(2,10000);
            if(completion_log_id[0]!==16'h0200 || completion_log_status[0]!==4'd1 ||
               completion_log_id[1]!==16'h0201 || completion_log_status[1]!==4'd2 ||
               completion_log_error[1]!==4'd5 || response_owner_errors!=0)
                $fatal(1,"SPAD error escaped owner or completion FIFO order");
            $display("[PARALLEL_UVM_ERROR_OWNER_PASS] task=0201 error_code=5 unaffected_task=0200");
            scenario_cov.sample(3);
            scenario_coverage_seen[2]=1'b1;

            // Abort stops a descriptor whose fetch is delayed from launching,
            // reports ERR_ABORT for active/draining work, and retires records
            // in CMDQ order.
            reset_and_clear();cplq_size=4;
            configure_descriptor(0,8'h10,16'h0300,30,0,0);
            configure_descriptor(1,8'h32,16'h0301,30,0,0);
            configure_descriptor(2,8'h51,16'h0302,1,0,8);
            pulse_submit(3);wait_launch_count(2,2000);
            cycles=0;
            while(engine_busy==0 && cycles<1000) begin @(negedge clk);cycles=cycles+1;end
            if(engine_busy==0) $fatal(1,"parallel UVM abort did not have active engines");
            @(negedge clk);abort=1;@(negedge clk);abort=0;
            wait_cpl_tail(3,10000);
            cycles=0;
            while(dispatcher_busy && cycles<1000) begin @(negedge clk);cycles=cycles+1;end
            if(launch_count!=2 || completion_log_count!=3)
                $fatal(1,"abort dispatched delayed descriptor or lost completion launches=%0d cpls=%0d",
                       launch_count,completion_log_count);
            for(idx=0;idx<3;idx=idx+1)
                if(completion_log_id[idx] !== (16'h0300+idx) ||
                   completion_log_status[idx] !== 4'd2 || completion_log_error[idx] !== 4'd3)
                    $fatal(1,"abort drain completion order/status mismatch slot=%0d id=%04h status=%0d code=%0d",
                           idx,completion_log_id[idx],completion_log_status[idx],completion_log_error[idx]);
            if(dispatcher_busy || engine_busy!=0 || response_owner_errors!=0)
                $fatal(1,"parallel UVM abort returned before owner/engine drain");
            $display("[PARALLEL_UVM_ABORT_DRAIN_PASS] active=2 delayed_fetch=1 launches=2 completions=3 fifo_order=1");
            scenario_cov.sample(4);
            scenario_coverage_seen[3]=1'b1;

            // Reset while an accepted SPAD read is outstanding, then run a
            // fresh command and prove a pending owner error is killed with
            // the response-owner pipeline and cannot poison recovery.
            reset_and_clear();cplq_size=4;spad_read_error_enable=1;spad_read_error_owner=4;
            configure_descriptor(0,8'h32,16'h0400,20,0,0);
            pulse_submit(1);wait_launch_count(1,2000);
            cycles=0;
            while(accepted_read_count==0 && cycles<1000) begin @(negedge clk);cycles=cycles+1;end
            if(accepted_read_count==0) $fatal(1,"reset probe did not accept a SPAD read");
            if(!accepted_read_error_d)
                $fatal(1,"reset/error combo did not hold an owner error response in flight");
            @(negedge clk);
            if(!engine_rsp_valid[4] || !engine_rsp_error[4])
                $fatal(1,"reset/error combo did not route pending error to the owning engine");
            resetn=0;repeat(2) @(negedge clk);resetn=1;repeat(3) @(negedge clk);
            spad_read_error_enable=0;
            configure_descriptor(0,8'h10,16'h0401,1,0,0);
            pulse_submit(1);wait_cpl_tail(1,10000);
            cycles=0;
            while(dispatcher_busy && cycles<1000) begin @(negedge clk);cycles=cycles+1;end
            if(completion_log_count!=1 || completion_log_id[0]!==16'h0401 ||
               completion_log_status[0]!==4'd1 || response_owner_errors!=0 ||
               dispatcher_busy || engine_busy!=0)
                $fatal(1,"post-reset recovery task was contaminated by stale owner/completion log=%0d id=%04h status=%0d ownererr=%0d busy=%b dispatcher=%b tail=%0d launches=%0d rsp=%b",
                    completion_log_count,completion_log_id[0],completion_log_status[0],
                    response_owner_errors,engine_busy,dispatcher_busy,cplq_tail,launch_count,rsp_valid);
            $display("[PARALLEL_UVM_RESET_RECOVERY_PASS] old_task=0400 pending_owner_error=1 recovery_task=0401 stale_response=0");
            scenario_cov.sample(5);
            scenario_coverage_seen[4]=1'b1;
            if(pair_coverage_ever!==21'h1fffff || scenario_coverage_seen!==5'b11111)
                $fatal(1,"parallel functional coverage incomplete pair_mask=%021b scenario_mask=%05b",
                       pair_coverage_ever,scenario_coverage_seen);
            $display("[PARALLEL_UVM_COVERAGE_PASS] engine_pairs=%0.1f%% scenarios=%0.1f%% seed=%0d",
                     100.0*$countones(pair_coverage_ever)/21.0,
                     100.0*$countones(scenario_coverage_seen)/5.0,parallel_seed);
            $display("[PARALLEL_DISPATCH_SPAD_UVM_PASS] random_grant_stall=1 fifo=1 out_of_order=1 simultaneous_done=1 error=1 abort_drain=1 reset_recovery=1 seed=%0d",parallel_seed);
        end
    endtask

    // Run-level counters and overlap/owner checks.
    always @(posedge clk or negedge resetn) begin
        if(!resetn) begin
            out_of_order_seen<=0;pair_overlap_seen<=0;
        end else begin
            if(debug_fifo_done[1] && !debug_fifo_done[0]) out_of_order_seen<=1;
            pair_index=0;
            for(integer a=0;a<6;a=a+1)
                for(integer b=a+1;b<7;b=b+1) begin
                    if(engine_busy[a] && engine_busy[b] && !pair_overlap_seen[pair_index]) begin
                        pair_overlap_seen[pair_index]<=1'b1;
                        pair_coverage_ever[pair_index]<=1'b1;
                        pair_sample_index=pair_index;
                        engine_pair_cov.sample();
                    end
                    pair_index=pair_index+1;
                end
        end
    end
endinterface
