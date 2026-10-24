`timescale 1ns / 1ps

// Multi-engine CMDQ issue and in-order retirement controller.
//
// Each of the seven compute engines may own one active command. Completed
// records are buffered in an eight-entry FIFO and become visible in the same
// order in which their descriptors were accepted. Macro descriptors are
// handed to the legacy command processor after earlier parallel work drains;
// this preserves the existing child-fetch and fail-stop semantics.
module ai_parallel_compute_dispatcher(
    input wire clk,
    input wire resetn,
    input wire submit,
    input wire abort,
    input wire scheduler_ready,
    input wire [63:0] cmdq_base,
    input wire [31:0] cmdq_size,
    input wire [31:0] cmdq_tail,
    input wire desc_external,
    input wire cmdq_head_load,
    input wire [31:0] cmdq_head_seed,
    input wire cplq_tail_load,
    input wire [31:0] cplq_tail_seed,
    input wire [31:0] cplq_base,
    input wire [31:0] cplq_size,
    input wire [31:0] cplq_head,
    input wire completion_protected,
    input wire sync_legacy_state,
    input wire [31:0] legacy_cmdq_head,
    input wire [31:0] legacy_cplq_tail,
    input wire [15:0] legacy_dependency_events,

    input wire fetch_done,
    input wire fetch_error,
    input wire [7:0] desc_op,
    input wire [15:0] desc_task_id,
    input wire [31:0] desc_src0,
    input wire [31:0] desc_src1,
    input wire [31:0] desc_dst,
    input wire [15:0] desc_length,
    input wire [15:0] desc_m,
    input wire [15:0] desc_n,
    input wire [15:0] desc_k,
    input wire [4:0] desc_shift,
    input wire [1:0] desc_activation,
    input wire [31:0] desc_bias_base,
    input wire desc_bias_enable,
    input wire [7:0] desc_flags,
    input wire [31:0] desc_aux0,
    input wire [31:0] desc_src0_stride,
    input wire [31:0] desc_src1_stride,
    input wire [31:0] desc_dst_stride,
    input wire [15:0] desc_batch_count,
    input wire [15:0] desc_head_count,
    input wire [15:0] desc_wait_mask,
    input wire [15:0] desc_signal_mask,
    input wire [15:0] desc_clear_mask,
    input wire [7:0] desc_version,

    input wire [6:0] engine_busy,
    input wire [6:0] engine_done,
    input wire [6:0] engine_error,
    input wire [27:0] engine_error_code,
    input wire [223:0] engine_result,
    input wire [223:0] engine_cycles,
    input wire [223:0] engine_elements,
    input wire completion_busy,
    input wire completion_done,

    output reg fetch_start,
    output reg [63:0] fetch_base,
    output reg fetch_external,
    output reg launch_valid,
    output reg [7:0] launch_op,
    output reg [15:0] launch_task_id,
    output reg [31:0] launch_src0,
    output reg [31:0] launch_src1,
    output reg [31:0] launch_dst,
    output reg [15:0] launch_length,
    output reg [15:0] launch_m,
    output reg [15:0] launch_n,
    output reg [15:0] launch_k,
    output reg [4:0] launch_shift,
    output reg [1:0] launch_activation,
    output reg [31:0] launch_bias_base,
    output reg launch_bias_enable,
    output reg [7:0] launch_flags,
    output reg [31:0] launch_aux0,
    output reg [31:0] launch_src0_stride,
    output reg [31:0] launch_src1_stride,
    output reg [31:0] launch_dst_stride,
    output reg [15:0] launch_batch_count,
    output reg [15:0] launch_head_count,

    output reg completion_start,
    output wire [31:0] completion_base,
    output wire [31:0] completion_index,
    output reg [15:0] completion_task_id,
    output reg [3:0] completion_status,
    output reg [3:0] completion_error_code,
    output reg [31:0] completion_result,
    output reg [31:0] completion_elements,

    output reg [31:0] cmdq_head,
    output reg [31:0] cplq_tail,
    output wire busy,
    output reg event_valid,
    output reg event_error,
    output reg [3:0] event_error_code,
    output reg [31:0] event_result,
    output reg [31:0] event_cycles,
    output reg [31:0] event_elements,
    output reg [15:0] dependency_events,
    output reg legacy_handoff
);
    localparam [1:0] ISSUE_IDLE = 2'd0;
    localparam [1:0] ISSUE_FETCH = 2'd1;
    localparam [1:0] ISSUE_DECODE = 2'd2;
    localparam [3:0] ERR_ABORT = 4'd3;
    localparam [3:0] ERR_FETCH = 4'd6;
    localparam [3:0] ERR_DESC = 4'd7;
    localparam [3:0] ERR_EMPTY = 4'd8;
    localparam [3:0] ERR_CPL = 4'd9;
    localparam [3:0] ERR_PROT = 4'd10;
    localparam [3:0] ERR_DEPENDENCY = 4'd12;
    localparam [3:0] CPL_DONE = 4'd1;
    localparam [3:0] CPL_ERROR = 4'd2;

    reg [1:0] issue_state_r;
    reg queue_active_r;
    reg aborting_r;
    reg retire_wait_r;
    reg [15:0] dependency_wait_cycles_r;
    reg [2:0] fifo_head_r, fifo_tail_r;
    reg [3:0] fifo_count_r;
    reg [6:0] engine_active_r;
    reg [2:0] engine_fifo_slot_r [0:6];
    reg fifo_done_r [0:7];
    reg fifo_error_r [0:7];
    reg [3:0] fifo_error_code_r [0:7];
    reg [15:0] fifo_task_id_r [0:7];
    reg [15:0] fifo_signal_mask_r [0:7];
    reg fifo_completion_required_r [0:7];
    reg [31:0] fifo_result_r [0:7];
    reg [31:0] fifo_cycles_r [0:7];
    reg [31:0] fifo_elements_r [0:7];

    wire [31:0] cmdq_head_index, cmdq_head_next;
    wire [31:0] cmdq_after_next_index;
    wire [31:0] cplq_tail_index, cplq_tail_next;
    wire [31:0] cplq_after_next_index_unused;
    ai_ring_pointer_next cmdq_pointer_u(
        .pointer(cmdq_head), .queue_size(cmdq_size),
        .index(cmdq_head_index), .next_pointer(cmdq_head_next)
    );
    ai_ring_pointer_next cmdq_next_index_u(
        .pointer(cmdq_head_next), .queue_size(cmdq_size),
        .index(cmdq_after_next_index), .next_pointer()
    );
    ai_ring_pointer_next cplq_pointer_u(
        .pointer(cplq_tail), .queue_size(cplq_size),
        .index(cplq_tail_index), .next_pointer(cplq_tail_next)
    );
    ai_ring_pointer_next cplq_next_index_u(
        .pointer(cplq_tail_next), .queue_size(cplq_size),
        .index(cplq_after_next_index_unused), .next_pointer()
    );

    wire cplq_full = cplq_size != 0 && cplq_tail_next == cplq_head;
    wire completion_available = cplq_size != 0 && !cplq_full && !completion_protected;
    wire [15:0] wait_events_missing = desc_wait_mask & ~dependency_events;
    wire dependencies_ready = (wait_events_missing == 16'd0);
    wire macro_op = (desc_op >= 8'h40) && (desc_op <= 8'h42);
    wire descriptor_invalid;
    wire validator_macro;
    ai_descriptor_validator descriptor_validator_u(
        .op(desc_op), .version(desc_version), .src0(desc_src0), .src1(desc_src1),
        .dst(desc_dst), .bias_base(desc_bias_base), .length(desc_length),
        .m_size(desc_m), .n_size(desc_n), .k_words(desc_k),
        .bias_enable(desc_bias_enable), .flags(desc_flags), .scale_shift(desc_shift),
        .activation(desc_activation), .aux0(desc_aux0),
        .src0_stride(desc_src0_stride), .src1_stride(desc_src1_stride),
        .dst_stride(desc_dst_stride), .batch_count(desc_batch_count),
        .head_count(desc_head_count), .macro_child_fetch(1'b0),
        .op_valid(), .is_macro(validator_macro), .is_tensor_matrix(),
        .is_tensor_sfu(), .version_valid(), .dimensions_valid(),
        .alignment_error(), .descriptor_invalid(descriptor_invalid)
    );

    function [2:0] engine_for_op;
        input [7:0] op;
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

    wire [2:0] desc_engine = engine_for_op(desc_op);
    wire desc_engine_ready = !engine_active_r[desc_engine] && !engine_busy[desc_engine];
    wire can_enqueue = fifo_count_r < 4'd8;
    wire enqueue_from_fetch = issue_state_r == ISSUE_FETCH && fetch_done &&
                              can_enqueue && (abort || aborting_r || fetch_error);
    wire enqueue_from_decode = issue_state_r == ISSUE_DECODE && can_enqueue &&
        (abort || aborting_r || descriptor_invalid ||
         (!dependencies_ready && dependency_wait_cycles_r == 16'hffff) ||
         (dependencies_ready && !macro_op && desc_engine_ready));
    wire head_entry_ready = fifo_count_r != 0 && fifo_done_r[fifo_head_r];
    wire head_needs_completion = fifo_completion_required_r[fifo_head_r];
    wire retire_without_cpl = head_entry_ready && !retire_wait_r &&
                              (!head_needs_completion || completion_protected ||
                               cplq_size == 0);
    wire retire_start_cpl = head_entry_ready && !retire_wait_r &&
                            head_needs_completion && !completion_protected &&
                            cplq_size != 0 && !cplq_full && !completion_busy;
    wire retire_complete_cpl = retire_wait_r && completion_done;
    wire dequeue_fire = retire_without_cpl || retire_complete_cpl;
    wire retire_success = dequeue_fire && !fifo_error_r[fifo_head_r] &&
                          (retire_complete_cpl ||
                           (retire_without_cpl && !head_needs_completion));
    wire dispatch_descriptor = enqueue_from_decode && dependencies_ready &&
                               !macro_op && !descriptor_invalid &&
                               !abort && !aborting_r;
    assign completion_base = cplq_base;
    assign completion_index = cplq_tail_index;
    assign busy = queue_active_r || (fifo_count_r != 0) || retire_wait_r ||
                  (issue_state_r != ISSUE_IDLE);

    task enqueue_error;
        input [15:0] task_id;
        input [3:0] code;
        input [31:0] result_value;
        input [31:0] cycle_value;
        input [31:0] element_value;
        integer slot;
        begin
            slot = fifo_tail_r;
            fifo_task_id_r[slot] <= task_id;
            fifo_signal_mask_r[slot] <= 16'd0;
            fifo_completion_required_r[slot] <= (cplq_size != 0);
            fifo_error_r[slot] <= 1'b1;
            fifo_error_code_r[slot] <= code;
            fifo_result_r[slot] <= result_value;
            fifo_cycles_r[slot] <= cycle_value;
            fifo_elements_r[slot] <= element_value;
            fifo_done_r[slot] <= 1'b1;
            fifo_tail_r <= fifo_tail_r + 3'd1;
            cmdq_head <= cmdq_head_next;
            if (!aborting_r && !abort && cmdq_after_next_index != cmdq_tail) begin
                issue_state_r <= ISSUE_FETCH;
                fetch_start <= 1'b1;
                fetch_base <= cmdq_base + (cmdq_after_next_index << 6);
                fetch_external <= desc_external;
            end else begin
                issue_state_r <= ISSUE_IDLE;
            end
        end
    endtask

    task accept_descriptor;
        input [2:0] engine_id;
        integer slot;
        begin
            slot = fifo_tail_r;
            fifo_task_id_r[slot] <= desc_task_id;
            fifo_signal_mask_r[slot] <= desc_signal_mask;
            fifo_completion_required_r[slot] <= (cplq_size != 0);
            fifo_error_r[slot] <= 1'b0;
            fifo_error_code_r[slot] <= 4'd0;
            fifo_result_r[slot] <= 32'd0;
            fifo_cycles_r[slot] <= 32'd0;
            fifo_elements_r[slot] <= 32'd0;
            fifo_done_r[slot] <= 1'b0;
            engine_fifo_slot_r[engine_id] <= fifo_tail_r;
            engine_active_r[engine_id] <= 1'b1;
            {launch_valid, launch_op, launch_task_id, launch_src0, launch_src1,
             launch_dst, launch_length, launch_m, launch_n, launch_k,
             launch_shift, launch_activation, launch_bias_base,
             launch_bias_enable, launch_flags, launch_aux0,
             launch_src0_stride, launch_src1_stride, launch_dst_stride,
             launch_batch_count, launch_head_count} <=
            {1'b1, desc_op, desc_task_id, desc_src0, desc_src1, desc_dst,
             desc_length, desc_m, desc_n, desc_k, desc_shift, desc_activation,
             desc_bias_base, desc_bias_enable, desc_flags, desc_aux0,
             desc_src0_stride, desc_src1_stride, desc_dst_stride,
             desc_batch_count == 16'd0 ? 16'd1 : desc_batch_count,
             desc_head_count == 16'd0 ? 16'd1 : desc_head_count};
            fifo_tail_r <= fifo_tail_r + 3'd1;
            cmdq_head <= cmdq_head_next;
            dependency_wait_cycles_r <= 16'd0;
            if (!aborting_r && !abort && cmdq_after_next_index != cmdq_tail) begin
                issue_state_r <= ISSUE_FETCH;
                fetch_start <= 1'b1;
                fetch_base <= cmdq_base + (cmdq_after_next_index << 6);
                fetch_external <= desc_external;
            end else begin
                issue_state_r <= ISSUE_IDLE;
            end
        end
    endtask

    integer i;
    integer head_slot;
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            issue_state_r <= ISSUE_IDLE;
            queue_active_r <= 1'b0;
            aborting_r <= 1'b0;
            retire_wait_r <= 1'b0;
            dependency_wait_cycles_r <= 16'd0;
            fifo_head_r <= 3'd0;
            fifo_tail_r <= 3'd0;
            fifo_count_r <= 4'd0;
            engine_active_r <= 7'd0;
            fetch_start <= 1'b0;
            fetch_base <= 64'd0;
            fetch_external <= 1'b0;
            launch_valid <= 1'b0;
            launch_op <= 8'd0;
            launch_task_id <= 16'd0;
            launch_src0 <= 32'd0;
            launch_src1 <= 32'd0;
            launch_dst <= 32'd0;
            launch_length <= 16'd0;
            launch_m <= 16'd0;
            launch_n <= 16'd0;
            launch_k <= 16'd0;
            launch_shift <= 5'd0;
            launch_activation <= 2'd0;
            launch_bias_base <= 32'd0;
            launch_bias_enable <= 1'b0;
            launch_flags <= 8'd0;
            launch_aux0 <= 32'd0;
            launch_src0_stride <= 32'd0;
            launch_src1_stride <= 32'd0;
            launch_dst_stride <= 32'd0;
            launch_batch_count <= 16'd1;
            launch_head_count <= 16'd1;
            completion_start <= 1'b0;
            completion_task_id <= 16'd0;
            completion_status <= 4'd0;
            completion_error_code <= 4'd0;
            completion_result <= 32'd0;
            completion_elements <= 32'd0;
            cmdq_head <= 32'd0;
            cplq_tail <= 32'd0;
            event_valid <= 1'b0;
            event_error <= 1'b0;
            event_error_code <= 4'd0;
            event_result <= 32'd0;
            event_cycles <= 32'd0;
            event_elements <= 32'd0;
            dependency_events <= 16'd0;
            legacy_handoff <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                fifo_done_r[i] <= 1'b0;
                fifo_error_r[i] <= 1'b0;
                fifo_error_code_r[i] <= 4'd0;
                fifo_task_id_r[i] <= 16'd0;
                fifo_signal_mask_r[i] <= 16'd0;
                fifo_completion_required_r[i] <= 1'b0;
                fifo_result_r[i] <= 32'd0;
                fifo_cycles_r[i] <= 32'd0;
                fifo_elements_r[i] <= 32'd0;
            end
            for (i = 0; i < 7; i = i + 1)
                engine_fifo_slot_r[i] <= 3'd0;
        end else begin
            fetch_start <= 1'b0;
            launch_valid <= 1'b0;
            completion_start <= 1'b0;
            event_valid <= 1'b0;
            legacy_handoff <= 1'b0;

            if (cmdq_head_load)
                cmdq_head <= cmdq_head_seed;
            else if (sync_legacy_state && !busy)
                cmdq_head <= legacy_cmdq_head;
            if (cplq_tail_load)
                cplq_tail <= cplq_tail_seed;
            else if (sync_legacy_state && !busy)
                cplq_tail <= legacy_cplq_tail;
            if (sync_legacy_state && !busy)
                dependency_events <= legacy_dependency_events;

            if (abort)
                aborting_r <= 1'b1;

            // Latch every engine result before considering FIFO retirement.
            // The slot pointer is unique while that engine is active.
            for (i = 0; i < 7; i = i + 1) begin
                if (engine_active_r[i] && engine_done[i]) begin
                    head_slot = engine_fifo_slot_r[i];
                    fifo_done_r[head_slot] <= 1'b1;
                    fifo_error_r[head_slot] <= engine_error[i] || abort || aborting_r;
                    fifo_error_code_r[head_slot] <= engine_error[i] ?
                        engine_error_code[i*4 +: 4] :
                        ((abort || aborting_r) ? ERR_ABORT : 4'd0);
                    fifo_result_r[head_slot] <= engine_result[i*32 +: 32];
                    fifo_cycles_r[head_slot] <= engine_cycles[i*32 +: 32];
                    fifo_elements_r[head_slot] <= engine_elements[i*32 +: 32];
                    engine_active_r[i] <= 1'b0;
                end
            end

            if (retire_start_cpl) begin
                completion_start <= 1'b1;
                completion_task_id <= fifo_task_id_r[fifo_head_r];
                completion_status <= fifo_error_r[fifo_head_r] ? CPL_ERROR : CPL_DONE;
                completion_error_code <= fifo_error_r[fifo_head_r] ?
                                         fifo_error_code_r[fifo_head_r] : 4'd0;
                completion_result <= fifo_result_r[fifo_head_r];
                completion_elements <= fifo_elements_r[fifo_head_r];
                retire_wait_r <= 1'b1;
            end

            if (dequeue_fire) begin
                fifo_done_r[fifo_head_r] <= 1'b0;
                fifo_head_r <= fifo_head_r + 3'd1;
                retire_wait_r <= 1'b0;
                if (retire_complete_cpl)
                    cplq_tail <= cplq_tail_next;

                event_valid <= 1'b1;
                event_error <= retire_without_cpl && head_needs_completion ?
                               1'b1 : fifo_error_r[fifo_head_r];
                event_error_code <= retire_without_cpl && head_needs_completion ?
                                    ERR_PROT : fifo_error_code_r[fifo_head_r];
                event_result <= fifo_result_r[fifo_head_r];
                event_cycles <= fifo_cycles_r[fifo_head_r];
                event_elements <= fifo_elements_r[fifo_head_r];
            end

            if (sync_legacy_state && !busy)
                dependency_events <= legacy_dependency_events;
            else if (dispatch_descriptor || retire_success) begin
                dependency_events <=
                    (dependency_events |
                     (retire_success ? fifo_signal_mask_r[fifo_head_r] : 16'd0)) &
                    ~(dispatch_descriptor ? desc_clear_mask : 16'd0);
            end

            case ({(enqueue_from_fetch || enqueue_from_decode), dequeue_fire})
                2'b10: fifo_count_r <= fifo_count_r + 4'd1;
                2'b01: fifo_count_r <= fifo_count_r - 4'd1;
                default: fifo_count_r <= fifo_count_r;
            endcase

            case (issue_state_r)
                ISSUE_IDLE: begin
                    if (!queue_active_r && fifo_count_r == 0 && !retire_wait_r &&
                        submit && scheduler_ready) begin
                        if (cmdq_size != 0 && cmdq_head_index == cmdq_tail) begin
                            event_valid <= 1'b1;
                            event_error <= 1'b1;
                            event_error_code <= ERR_EMPTY;
                        end else if (cmdq_size != 0 && cplq_size != 0 &&
                                     !completion_available) begin
                            event_valid <= 1'b1;
                            event_error <= 1'b1;
                            event_error_code <= completion_protected ? ERR_PROT : ERR_CPL;
                        end else if (cmdq_size != 0) begin
                            queue_active_r <= 1'b1;
                            aborting_r <= 1'b0;
                            issue_state_r <= ISSUE_FETCH;
                            fetch_start <= 1'b1;
                            fetch_base <= cmdq_base + (cmdq_head_index << 6);
                            fetch_external <= desc_external;
                        end
                    end else if (queue_active_r) begin
                        if (abort || aborting_r) begin
                            if (fifo_count_r == 0 && !retire_wait_r) begin
                                queue_active_r <= 1'b0;
                                aborting_r <= 1'b0;
                            end
                        end else if (cmdq_size != 0 && cmdq_head_index != cmdq_tail &&
                                     can_enqueue && !abort) begin
                            issue_state_r <= ISSUE_FETCH;
                            fetch_start <= 1'b1;
                            fetch_base <= cmdq_base + (cmdq_head_index << 6);
                            fetch_external <= desc_external;
                        end else if (fifo_count_r == 0 && !retire_wait_r &&
                                     cmdq_head_index == cmdq_tail) begin
                            queue_active_r <= 1'b0;
                        end
                    end
                end

                ISSUE_FETCH: begin
                    if (abort || aborting_r) begin
                        if (fetch_done && can_enqueue) begin
                            enqueue_error(desc_task_id, ERR_ABORT, 32'd0, 32'd0, 32'd0);
                            if (fifo_count_r == 0 && !retire_wait_r)
                                queue_active_r <= 1'b1;
                        end
                    end else if (fetch_done) begin
                        if (fetch_error) begin
                            if (can_enqueue)
                                enqueue_error(desc_task_id, ERR_FETCH, 32'd0, 32'd0, 32'd0);
                        end else begin
                            issue_state_r <= ISSUE_DECODE;
                            dependency_wait_cycles_r <= 16'd0;
                        end
                    end
                end

                ISSUE_DECODE: begin
                    if (abort || aborting_r) begin
                        if (can_enqueue)
                            enqueue_error(desc_task_id, ERR_ABORT, 32'd0, 32'd0, 32'd0);
                    end else if (descriptor_invalid) begin
                        if (can_enqueue)
                            enqueue_error(desc_task_id, ERR_DESC, 32'd0, 32'd0, 32'd0);
                    end else if (!dependencies_ready) begin
                        if (dependency_wait_cycles_r == 16'hffff) begin
                            if (can_enqueue)
                                enqueue_error(desc_task_id, ERR_DEPENDENCY,
                                              {16'd0, dependency_events}, 32'd0, 32'd0);
                        end else begin
                            dependency_wait_cycles_r <= dependency_wait_cycles_r + 16'd1;
                        end
                    end else if (macro_op) begin
                        if (fifo_count_r == 0 && !retire_wait_r && !completion_busy) begin
                            legacy_handoff <= 1'b1;
                            queue_active_r <= 1'b0;
                            issue_state_r <= ISSUE_IDLE;
                        end
                    end else if (can_enqueue && desc_engine_ready) begin
                        accept_descriptor(desc_engine);
                    end
                end
                default: issue_state_r <= ISSUE_IDLE;
            endcase
        end
    end
endmodule
