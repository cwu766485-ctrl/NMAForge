module ai_parallel_compute_dispatcher_formal_top (
    input logic clk,
    input logic resetn,
    input logic [6:0] normal_engine_done_choice,
    input logic abort
);
    localparam integer ENGINE_COUNT = 7;

    logic submit;
    logic submit_sent_r;
    logic fetch_pending_r;
    logic [3:0] desc_index_r;
    logic [6:0] engine_busy_r;
    logic completion_active_r;

    wire fetch_start;
    wire fetch_done = fetch_pending_r;
    wire launch_valid;
    wire [7:0] launch_op;
    wire [15:0] launch_task_id;
    wire completion_start;
    wire [15:0] completion_task_id;
    wire [31:0] cmdq_head;
    wire [31:0] cplq_tail;
    wire dispatcher_busy;
    wire [6:0] engine_done;
    wire abort_active = abort || dispatcher.aborting_r;

    logic [7:0] desc_op;
    logic [7:0] desc_version;
    logic [15:0] desc_length;
    logic [15:0] desc_m;
    logic [15:0] desc_n;
    logic [15:0] desc_k;
    logic [31:0] desc_src0;
    logic [31:0] desc_src1;
    logic [31:0] desc_dst;

    function automatic [2:0] engine_for_op(input logic [7:0] op);
        begin
            if (op == 8'h50 || op == 8'h51) engine_for_op = 3'd1;
            else if (op == 8'h20 || op == 8'h21) engine_for_op = 3'd2;
            else if (op == 8'h30 || op == 8'h31) engine_for_op = 3'd3;
            else if (op >= 8'h32 && op <= 8'h39) engine_for_op = 3'd4;
            else if (op == 8'h16 || op == 8'h17) engine_for_op = 3'd5;
            else if (op == 8'h43 || op == 8'h44) engine_for_op = 3'd6;
            else engine_for_op = 3'd0;
        end
    endfunction

    always_comb begin
        desc_op = 8'h10;
        desc_version = 8'd3;
        desc_length = 16'd4;
        desc_m = 16'd1;
        desc_n = 16'd1;
        desc_k = 16'd1;
        case (desc_index_r)
            0: desc_op = 8'h10;
            1: begin desc_op = 8'h51; desc_version = 8'd7; end
            2: desc_op = 8'h20;
            3: begin
                desc_op = 8'h30;
                desc_m = 16'd4;
                desc_n = 16'd4;
                desc_k = 16'd4;
            end
            4: desc_op = 8'h35;
            5: begin
                desc_op = 8'h16;
                desc_version = 8'd5;
                desc_m = 16'd3;
                desc_n = 16'd3;
                desc_k = 16'd0;
            end
            6: begin desc_op = 8'h43; desc_version = 8'd5; end
            default: begin end
        endcase
        desc_src0 = 32'h0000_1000 + ({28'd0, desc_index_r} << 12);
        desc_src1 = 32'h0000_2000 + ({28'd0, desc_index_r} << 12);
        desc_dst  = 32'h0000_3000 + ({28'd0, desc_index_r} << 12);
    end

    always_comb begin
        submit = resetn && !submit_sent_r;
    end

    assign engine_done = engine_busy_r &
        (normal_engine_done_choice | {ENGINE_COUNT{abort_active}});

    always_ff @(posedge clk or negedge resetn) begin
        integer i;
        if (!resetn) begin
            submit_sent_r <= 1'b0;
            fetch_pending_r <= 1'b0;
            desc_index_r <= 4'd0;
            engine_busy_r <= 7'd0;
            completion_active_r <= 1'b0;
        end else begin
            if (submit)
                submit_sent_r <= 1'b1;
            fetch_pending_r <= fetch_start;
            if (fetch_done && desc_index_r < 4'd7)
                desc_index_r <= desc_index_r + 1'b1;

            for (i = 0; i < ENGINE_COUNT; i = i + 1) begin
                if (engine_done[i])
                    engine_busy_r[i] <= 1'b0;
            end
            if (launch_valid)
                engine_busy_r[engine_for_op(launch_op)] <= 1'b1;

            if (completion_start)
                completion_active_r <= 1'b1;
            else if (completion_active_r)
                completion_active_r <= 1'b0;
        end
    end

    ai_parallel_compute_dispatcher dispatcher (
        .clk(clk), .resetn(resetn), .submit(submit), .abort(abort),
        .scheduler_ready(1'b1), .cmdq_base(64'd0), .cmdq_size(32'd8),
        .cmdq_tail(32'd7), .desc_external(1'b0),
        .cmdq_head_load(1'b0), .cmdq_head_seed(32'd0),
        .cplq_tail_load(1'b0), .cplq_tail_seed(32'd0),
        .cplq_base(32'h0000_8000), .cplq_size(32'd8),
        .cplq_head(32'd0), .completion_protected(1'b0),
        .sync_legacy_state(1'b0), .legacy_cmdq_head(32'd0),
        .legacy_cplq_tail(32'd0), .legacy_dependency_events(16'd0),
        .fetch_done(fetch_done), .fetch_error(1'b0), .desc_op(desc_op),
        .desc_task_id(16'h1000 + desc_index_r), .desc_src0(desc_src0),
        .desc_src1(desc_src1), .desc_dst(desc_dst),
        .desc_length(desc_length), .desc_m(desc_m), .desc_n(desc_n),
        .desc_k(desc_k), .desc_shift(5'd0), .desc_activation(2'd0),
        .desc_bias_base(32'd0), .desc_bias_enable(1'b0),
        .desc_flags(8'd0), .desc_aux0(32'd0), .desc_src0_stride(32'd0),
        .desc_src1_stride(32'd0), .desc_dst_stride(32'd0),
        .desc_batch_count(16'd0), .desc_head_count(16'd0),
        .desc_wait_mask(16'd0), .desc_signal_mask(16'd0),
        .desc_clear_mask(16'd0), .desc_version(desc_version),
        .engine_busy(engine_busy_r), .engine_done(engine_done),
        .engine_error(7'd0), .engine_error_code(28'd0),
        .engine_result(224'd0), .engine_cycles(224'd0),
        .engine_elements(224'd0), .completion_busy(completion_active_r),
        .completion_done(completion_active_r),
        .fetch_start(fetch_start), .fetch_base(), .fetch_external(),
        .launch_valid(launch_valid), .launch_op(launch_op),
        .launch_task_id(launch_task_id), .launch_src0(), .launch_src1(),
        .launch_dst(), .launch_length(), .launch_m(), .launch_n(),
        .launch_k(), .launch_shift(), .launch_activation(),
        .launch_bias_base(), .launch_bias_enable(), .launch_flags(),
        .launch_aux0(), .launch_src0_stride(), .launch_src1_stride(),
        .launch_dst_stride(), .launch_batch_count(), .launch_head_count(),
        .completion_start(completion_start), .completion_base(),
        .completion_index(), .completion_task_id(completion_task_id),
        .completion_status(), .completion_error_code(),
        .completion_result(), .completion_elements(), .cmdq_head(cmdq_head),
        .cplq_tail(cplq_tail), .busy(dispatcher_busy), .event_valid(),
        .event_error(), .event_error_code(), .event_result(),
        .event_cycles(), .event_elements(), .dependency_events(),
        .legacy_handoff()
    );

    ap_launch_belongs_to_active_slot: assert property (
        @(posedge clk) disable iff (!resetn)
        launch_valid |-> dispatcher.engine_active_r[engine_for_op(launch_op)]);
    ap_completion_payload_matches_retirement_head: assert property (
        @(posedge clk) disable iff (!resetn)
        completion_start |-> (completion_task_id ==
            dispatcher.fifo_task_id_r[dispatcher.fifo_head_r]));
    ap_engine_done_requires_active_task: assert property (
        @(posedge clk) disable iff (!resetn)
        (engine_done & ~engine_busy_r) == 7'd0);
    ap_abort_stops_later_launches: assert property (
        @(posedge clk) disable iff (!resetn)
        launch_valid |-> !$past(abort || dispatcher.aborting_r));
    ap_abort_drains_bounded: assert property (
        @(posedge clk) disable iff (!resetn)
        (abort && dispatcher_busy) |-> ##[1:40] !dispatcher_busy);

    cp_pair_0_1: cover property (@(posedge clk) disable iff (!resetn) engine_busy_r[0] && engine_busy_r[1]);
    cp_pair_0_2: cover property (@(posedge clk) disable iff (!resetn) engine_busy_r[0] && engine_busy_r[2]);
    cp_pair_0_3: cover property (@(posedge clk) disable iff (!resetn) engine_busy_r[0] && engine_busy_r[3]);
    cp_pair_0_4: cover property (@(posedge clk) disable iff (!resetn) engine_busy_r[0] && engine_busy_r[4]);
    cp_pair_0_5: cover property (@(posedge clk) disable iff (!resetn) engine_busy_r[0] && engine_busy_r[5]);
    cp_pair_0_6: cover property (@(posedge clk) disable iff (!resetn) engine_busy_r[0] && engine_busy_r[6]);
    cp_pair_1_2: cover property (@(posedge clk) disable iff (!resetn) engine_busy_r[1] && engine_busy_r[2]);
    cp_pair_1_3: cover property (@(posedge clk) disable iff (!resetn) engine_busy_r[1] && engine_busy_r[3]);
    cp_pair_1_4: cover property (@(posedge clk) disable iff (!resetn) engine_busy_r[1] && engine_busy_r[4]);
    cp_pair_1_5: cover property (@(posedge clk) disable iff (!resetn) engine_busy_r[1] && engine_busy_r[5]);
    cp_pair_1_6: cover property (@(posedge clk) disable iff (!resetn) engine_busy_r[1] && engine_busy_r[6]);
    cp_pair_2_3: cover property (@(posedge clk) disable iff (!resetn) engine_busy_r[2] && engine_busy_r[3]);
    cp_pair_2_4: cover property (@(posedge clk) disable iff (!resetn) engine_busy_r[2] && engine_busy_r[4]);
    cp_pair_2_5: cover property (@(posedge clk) disable iff (!resetn) engine_busy_r[2] && engine_busy_r[5]);
    cp_pair_2_6: cover property (@(posedge clk) disable iff (!resetn) engine_busy_r[2] && engine_busy_r[6]);
    cp_pair_3_4: cover property (@(posedge clk) disable iff (!resetn) engine_busy_r[3] && engine_busy_r[4]);
    cp_pair_3_5: cover property (@(posedge clk) disable iff (!resetn) engine_busy_r[3] && engine_busy_r[5]);
    cp_pair_3_6: cover property (@(posedge clk) disable iff (!resetn) engine_busy_r[3] && engine_busy_r[6]);
    cp_pair_4_5: cover property (@(posedge clk) disable iff (!resetn) engine_busy_r[4] && engine_busy_r[5]);
    cp_pair_4_6: cover property (@(posedge clk) disable iff (!resetn) engine_busy_r[4] && engine_busy_r[6]);
    cp_pair_5_6: cover property (@(posedge clk) disable iff (!resetn) engine_busy_r[5] && engine_busy_r[6]);
    cp_all_seven_engines: cover property (@(posedge clk) disable iff (!resetn) &engine_busy_r);
    cp_abort_with_active_engines: cover property (@(posedge clk) disable iff (!resetn) abort && $countones(engine_busy_r) >= 2);
endmodule
