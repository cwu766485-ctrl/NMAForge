`timescale 1ns / 1ps

// Two-context tile pipeline for the A2 dataflow.
//
// Each context owns one scratchpad buffer and moves through:
//   EMPTY -> LOADING -> READY -> COMPUTING -> PRODUCED -> STORING -> EMPTY
//
// There is one DMA engine and one compute engine.  The engines may operate on
// different contexts in the same cycle, which overlaps load/compute/store
// across consecutive tiles without allowing either engine to acquire the same
// buffer concurrently.
module ai_tile_pipeline(
    input  wire        clk,
    input  wire        resetn,
    input  wire        start,
    input  wire        abort,

    input  wire [15:0] tile_count,
    input  wire [63:0] ext_input_base,
    input  wire [63:0] ext_output_base,
    input  wire [31:0] ext_input_stride,
    input  wire [31:0] ext_output_stride,
    input  wire [31:0] buffer0_base,
    input  wire [31:0] buffer1_base,
    input  wire [31:0] output_offset,
    input  wire [15:0] input_words,
    input  wire [15:0] output_words,

    input  wire [7:0]  compute_op,
    input  wire [31:0] weight_base,
    input  wire [15:0] compute_length,
    input  wire [15:0] compute_m,
    input  wire [15:0] compute_n,
    input  wire [15:0] compute_k,
    input  wire [4:0]  compute_shift,
    input  wire [1:0]  compute_activation,
    input  wire [31:0] compute_bias_base,
    input  wire        compute_bias_enable,

    input  wire        dma_busy,
    input  wire        dma_done,
    input  wire        dma_error,
    input  wire [3:0]  dma_error_code,
    output reg         dma_start,
    output reg         dma_store,
    output reg  [63:0] dma_ext_addr,
    output reg  [31:0] dma_spad_addr,
    output reg  [15:0] dma_length_words,

    input  wire        compute_busy,
    input  wire        compute_done,
    input  wire        compute_error,
    input  wire [3:0]  compute_error_code,
    input  wire [31:0] compute_result,
    input  wire [31:0] compute_elements,
    output reg         compute_start,
    output reg  [7:0]  launch_op,
    output reg  [31:0] launch_src0,
    output reg  [31:0] launch_src1,
    output reg  [31:0] launch_dst,
    output reg  [15:0] launch_length,
    output reg  [15:0] launch_m,
    output reg  [15:0] launch_n,
    output reg  [15:0] launch_k,
    output reg  [4:0]  launch_shift,
    output reg  [1:0]  launch_activation,
    output reg  [31:0] launch_bias_base,
    output reg         launch_bias_enable,

    output reg         busy,
    output reg         done,
    output reg         error,
    output reg  [3:0]  error_code,
    output reg  [31:0] result,
    output reg  [31:0] element_count,
    output reg  [31:0] perf_total_cycles,
    output reg  [31:0] perf_dma_cycles,
    output reg  [31:0] perf_compute_cycles,
    output reg  [31:0] perf_overlap_cycles,
    output reg  [31:0] perf_stall_cycles,
    output reg  [15:0] completed_tiles
);
    localparam [2:0] CTX_EMPTY     = 3'd0;
    localparam [2:0] CTX_LOADING   = 3'd1;
    localparam [2:0] CTX_READY     = 3'd2;
    localparam [2:0] CTX_COMPUTING = 3'd3;
    localparam [2:0] CTX_PRODUCED  = 3'd4;
    localparam [2:0] CTX_STORING   = 3'd5;

    localparam [3:0] ERR_CONFIG = 4'd1;
    localparam [3:0] ERR_ABORT  = 4'd3;

    reg [2:0] ctx0_state_r, ctx1_state_r;
    reg [15:0] ctx0_tile_r, ctx1_tile_r;
    reg [15:0] next_load_tile_r, next_compute_tile_r, next_store_tile_r;
    reg [63:0] next_load_ext_addr_r, next_store_ext_addr_r;
    reg dma_inflight_r, dma_owner_r, dma_is_store_r;
    reg compute_inflight_r, compute_owner_r;

    wire dma_active = dma_busy || dma_inflight_r;
    wire compute_active = compute_busy || compute_inflight_r;
    wire config_invalid = (tile_count == 16'd0) ||
                          (input_words == 16'd0) || (output_words == 16'd0) ||
                          (buffer0_base == buffer1_base) ||
                          (|buffer0_base[1:0]) || (|buffer1_base[1:0]) ||
                          (|output_offset[1:0]) ||
                          (|ext_input_base[1:0]) || (|ext_output_base[1:0]);

    // Arbitration is deliberately based only on registered context state.
    // A completion retires in this cycle; its context can be issued again on
    // the following cycle.  This preserves the one-cycle ownership hand-off
    // between the DMA/compute engines and their scratchpad buffers.
    wire ctx0_store_ready = (ctx0_state_r == CTX_PRODUCED) &&
                            (ctx0_tile_r == next_store_tile_r);
    wire ctx1_store_ready = (ctx1_state_r == CTX_PRODUCED) &&
                            (ctx1_tile_r == next_store_tile_r);
    wire store_issue = ctx0_store_ready || ctx1_store_ready;
    wire store_ctx1 = !ctx0_store_ready && ctx1_store_ready;

    wire ctx0_load_ready = (ctx0_state_r == CTX_EMPTY);
    wire ctx1_load_ready = (ctx1_state_r == CTX_EMPTY);
    wire load_issue = (next_load_tile_r < tile_count) &&
                      (ctx0_load_ready || ctx1_load_ready);
    wire load_ctx1 = !ctx0_load_ready && ctx1_load_ready;

    wire ctx0_compute_ready = (ctx0_state_r == CTX_READY) &&
                              (ctx0_tile_r == next_compute_tile_r);
    wire ctx1_compute_ready = (ctx1_state_r == CTX_READY) &&
                              (ctx1_tile_r == next_compute_tile_r);
    wire compute_issue = ctx0_compute_ready || ctx1_compute_ready;
    wire compute_ctx1 = !ctx0_compute_ready && ctx1_compute_ready;

    wire [31:0] dma_buffer_base = (store_issue ? store_ctx1 : load_ctx1) ?
                                  buffer1_base : buffer0_base;
    wire [31:0] compute_buffer_base = compute_ctx1 ? buffer1_base : buffer0_base;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            ctx0_state_r <= CTX_EMPTY;
            ctx1_state_r <= CTX_EMPTY;
            ctx0_tile_r <= 16'd0;
            ctx1_tile_r <= 16'd0;
            next_load_tile_r <= 16'd0;
            next_compute_tile_r <= 16'd0;
            next_store_tile_r <= 16'd0;
            next_load_ext_addr_r <= 64'd0;
            next_store_ext_addr_r <= 64'd0;
            dma_inflight_r <= 1'b0;
            dma_owner_r <= 1'b0;
            dma_is_store_r <= 1'b0;
            compute_inflight_r <= 1'b0;
            compute_owner_r <= 1'b0;
            dma_start <= 1'b0;
            dma_store <= 1'b0;
            dma_ext_addr <= 64'd0;
            dma_spad_addr <= 32'd0;
            dma_length_words <= 16'd0;
            compute_start <= 1'b0;
            launch_op <= 8'd0;
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
            busy <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            error_code <= 4'd0;
            result <= 32'd0;
            element_count <= 32'd0;
            perf_total_cycles <= 32'd0;
            perf_dma_cycles <= 32'd0;
            perf_compute_cycles <= 32'd0;
            perf_overlap_cycles <= 32'd0;
            perf_stall_cycles <= 32'd0;
            completed_tiles <= 16'd0;
        end else begin
            dma_start <= 1'b0;
            compute_start <= 1'b0;
            done <= 1'b0;

            if (start && !busy) begin
                ctx0_state_r <= CTX_EMPTY;
                ctx1_state_r <= CTX_EMPTY;
                next_load_tile_r <= 16'd0;
                next_compute_tile_r <= 16'd0;
                next_store_tile_r <= 16'd0;
                next_load_ext_addr_r <= ext_input_base;
                next_store_ext_addr_r <= ext_output_base;
                dma_inflight_r <= 1'b0;
                compute_inflight_r <= 1'b0;
                completed_tiles <= 16'd0;
                result <= 32'd0;
                element_count <= 32'd0;
                perf_total_cycles <= 32'd0;
                perf_dma_cycles <= 32'd0;
                perf_compute_cycles <= 32'd0;
                perf_overlap_cycles <= 32'd0;
                perf_stall_cycles <= 32'd0;
                error <= config_invalid;
                error_code <= config_invalid ? ERR_CONFIG : 4'd0;
                busy <= !config_invalid;
                if (config_invalid)
                    done <= 1'b1;
            end else if (busy) begin
                perf_total_cycles <= perf_total_cycles + 32'd1;
                if (dma_active)
                    perf_dma_cycles <= perf_dma_cycles + 32'd1;
                if (compute_active)
                    perf_compute_cycles <= perf_compute_cycles + 32'd1;
                if (dma_active && compute_active)
                    perf_overlap_cycles <= perf_overlap_cycles + 32'd1;
                if (!dma_active && !compute_active)
                    perf_stall_cycles <= perf_stall_cycles + 32'd1;

                if (abort) begin
                    busy <= 1'b0;
                    done <= 1'b1;
                    error <= 1'b1;
                    error_code <= ERR_ABORT;
                end else begin
                    // Retire DMA ownership before issuing the next transfer.
                    if (dma_inflight_r && dma_done) begin
                        dma_inflight_r <= 1'b0;
                        if (dma_error) begin
                            busy <= 1'b0;
                            done <= 1'b1;
                            error <= 1'b1;
                            error_code <= dma_error_code;
                        end else if (dma_is_store_r) begin
                            if (!dma_owner_r)
                                ctx0_state_r <= CTX_EMPTY;
                            else
                                ctx1_state_r <= CTX_EMPTY;
                            completed_tiles <= completed_tiles + 16'd1;
                            if (completed_tiles + 16'd1 == tile_count) begin
                                busy <= 1'b0;
                                done <= 1'b1;
                                error <= 1'b0;
                                error_code <= 4'd0;
                            end
                        end else begin
                            if (!dma_owner_r)
                                ctx0_state_r <= CTX_READY;
                            else
                                ctx1_state_r <= CTX_READY;
                        end
                    end

                    if (compute_inflight_r && compute_done) begin
                        compute_inflight_r <= 1'b0;
                        result <= compute_result;
                        element_count <= element_count + compute_elements;
                        if (compute_error) begin
                            busy <= 1'b0;
                            done <= 1'b1;
                            error <= 1'b1;
                            error_code <= compute_error_code;
                        end else if (!compute_owner_r) begin
                            ctx0_state_r <= CTX_PRODUCED;
                        end else begin
                            ctx1_state_r <= CTX_PRODUCED;
                        end
                    end

                    // DMA priority is an in-order produced tile, followed by
                    // a load into an empty context.  This prevents output
                    // back-pressure from being hidden behind unlimited loads.
                    if (!dma_inflight_r && !dma_busy && !dma_done) begin
                        if (store_issue) begin
                            dma_start <= 1'b1;
                            dma_store <= 1'b1;
                            dma_owner_r <= store_ctx1;
                            dma_is_store_r <= 1'b1;
                            dma_inflight_r <= 1'b1;
                            dma_ext_addr <= next_store_ext_addr_r;
                            dma_spad_addr <= dma_buffer_base + output_offset;
                            dma_length_words <= output_words;
                            if (store_ctx1)
                                ctx1_state_r <= CTX_STORING;
                            else
                                ctx0_state_r <= CTX_STORING;
                            next_store_tile_r <= next_store_tile_r + 16'd1;
                            next_store_ext_addr_r <= next_store_ext_addr_r + ext_output_stride;
                        end else if (load_issue) begin
                            dma_start <= 1'b1;
                            dma_store <= 1'b0;
                            dma_owner_r <= load_ctx1;
                            dma_is_store_r <= 1'b0;
                            dma_inflight_r <= 1'b1;
                            dma_ext_addr <= next_load_ext_addr_r;
                            dma_spad_addr <= dma_buffer_base;
                            dma_length_words <= input_words;
                            if (load_ctx1) begin
                                ctx1_tile_r <= next_load_tile_r;
                                ctx1_state_r <= CTX_LOADING;
                            end else begin
                                ctx0_tile_r <= next_load_tile_r;
                                ctx0_state_r <= CTX_LOADING;
                            end
                            next_load_tile_r <= next_load_tile_r + 16'd1;
                            next_load_ext_addr_r <= next_load_ext_addr_r + ext_input_stride;
                        end
                    end

                    if (!compute_inflight_r && !compute_busy && !compute_done) begin
                        if (compute_issue) begin
                            compute_start <= 1'b1;
                            compute_owner_r <= compute_ctx1;
                            compute_inflight_r <= 1'b1;
                            launch_op <= compute_op;
                            launch_src0 <= compute_buffer_base;
                            launch_src1 <= weight_base;
                            launch_dst <= compute_buffer_base + output_offset;
                            launch_length <= compute_length;
                            launch_m <= compute_m;
                            launch_n <= compute_n;
                            launch_k <= compute_k;
                            launch_shift <= compute_shift;
                            launch_activation <= compute_activation;
                            launch_bias_base <= compute_bias_base;
                            launch_bias_enable <= compute_bias_enable;
                            if (compute_ctx1)
                                ctx1_state_r <= CTX_COMPUTING;
                            else
                                ctx0_state_r <= CTX_COMPUTING;
                            next_compute_tile_r <= next_compute_tile_r + 16'd1;
                        end
                    end
                end
            end
        end
    end
endmodule
