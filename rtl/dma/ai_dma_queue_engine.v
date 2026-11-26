`timescale 1ns / 1ps

// Queued DMA engine for CMDQ opcode 0x60 (DMA_COPY, ABI v7.4 extension,
// advertised by CAP2[8]).
//
// The parallel dispatcher treats this block as engine 7. A launch latches the
// descriptor, waits until the shared payload DMA is idle, then issues exactly
// one start pulse into ai_axi128_dma through ai_accel_dma_request_mux. While
// `own` is high the queued request owns the DMA request port; register DMA and
// tile DMA must not be started by software while CMDQ DMA work is in flight.
//
// Descriptor mapping (validated by ai_descriptor_validator):
//   {src1,src0}  64-bit external byte address (word aligned)
//   dst          SPAD byte address (word aligned)
//   length       words per row (1D: total words)
//   m_size       row count; 0 selects a one-dimensional transfer
//   src0_stride  external row stride in bytes (2D only)
//   dst_stride   SPAD row stride in bytes (2D only)
//   flags[0]     0 = load DDR->SPAD, 1 = store SPAD->DDR
//
// Completion: result=0 and elements=words transferred on success. On a DMA
// error the payload-DMA error code is reported unchanged (as the tile path
// does) and result[31:28]=2 tags the DMA source.
module ai_dma_queue_engine (
    input  wire        clk,
    input  wire        resetn,
    input  wire        abort,
    input  wire        launch,
    input  wire [31:0] src0,
    input  wire [31:0] src1,
    input  wire [31:0] dst,
    input  wire [15:0] length,
    input  wire [15:0] m_size,
    input  wire [31:0] src0_stride,
    input  wire [31:0] dst_stride,
    input  wire [7:0]  flags,

    input  wire        dma_busy,
    input  wire        dma_done,
    input  wire        dma_error,
    input  wire [3:0]  dma_error_code,

    output reg         own,
    output reg         dma_start,
    output reg         dma_store,
    output reg  [63:0] dma_ext_addr,
    output reg  [31:0] dma_spad_addr,
    output reg  [15:0] dma_length_words,
    output reg  [15:0] dma_row_words,
    output reg  [15:0] dma_row_count,
    output reg  [31:0] dma_ext_stride,
    output reg  [31:0] dma_spad_stride,

    output wire        busy,
    output reg         done,
    output reg         error,
    output reg  [3:0]  error_code,
    output reg  [31:0] result,
    output reg  [31:0] cycles,
    output reg  [31:0] elements
);
    localparam [1:0] ST_IDLE = 2'd0, ST_WAIT_IDLE = 2'd1, ST_RUN = 2'd2;
    localparam [3:0] ERR_ABORT = 4'd3;

    reg [1:0] state_r;
    reg [31:0] words_r;

    assign busy = (state_r != ST_IDLE);

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state_r <= ST_IDLE;
            own <= 1'b0;
            dma_start <= 1'b0;
            dma_store <= 1'b0;
            dma_ext_addr <= 64'd0;
            dma_spad_addr <= 32'd0;
            dma_length_words <= 16'd0;
            dma_row_words <= 16'd0;
            dma_row_count <= 16'd0;
            dma_ext_stride <= 32'd0;
            dma_spad_stride <= 32'd0;
            done <= 1'b0;
            error <= 1'b0;
            error_code <= 4'd0;
            result <= 32'd0;
            cycles <= 32'd0;
            elements <= 32'd0;
            words_r <= 32'd0;
        end else begin
            dma_start <= 1'b0;
            done <= 1'b0;
            if (state_r != ST_IDLE)
                cycles <= cycles + 32'd1;
            case (state_r)
                ST_IDLE: begin
                    if (launch) begin
                        own <= 1'b1;
                        dma_store <= flags[0];
                        dma_ext_addr <= {src1, src0};
                        dma_spad_addr <= dst;
                        dma_length_words <= length;
                        dma_row_words <= (m_size == 16'd0) ? 16'd0 : length;
                        dma_row_count <= m_size;
                        dma_ext_stride <= (m_size == 16'd0) ? 32'd0 : src0_stride;
                        dma_spad_stride <= (m_size == 16'd0) ? 32'd0 : dst_stride;
                        words_r <= (m_size == 16'd0) ? {16'd0, length} :
                                   ({16'd0, length} * {16'd0, m_size});
                        cycles <= 32'd0;
                        error <= 1'b0;
                        error_code <= 4'd0;
                        result <= 32'd0;
                        elements <= 32'd0;
                        state_r <= ST_WAIT_IDLE;
                    end
                end
                ST_WAIT_IDLE: begin
                    if (abort) begin
                        own <= 1'b0;
                        done <= 1'b1;
                        error <= 1'b1;
                        error_code <= ERR_ABORT;
                        result <= 32'h2000_0000;
                        state_r <= ST_IDLE;
                    end else if (!dma_busy) begin
                        dma_start <= 1'b1;
                        state_r <= ST_RUN;
                    end
                end
                ST_RUN: begin
                    // ai_axi128_dma pulses done for both success and error;
                    // error is already a level at that cycle. Waiting for done
                    // keeps write drain and abort drain inside this request.
                    if (dma_done) begin
                        own <= 1'b0;
                        done <= 1'b1;
                        error <= dma_error;
                        error_code <= dma_error ? dma_error_code : 4'd0;
                        result <= dma_error ? (32'h2000_0000 | {28'd0, dma_error_code}) :
                                  32'd0;
                        elements <= dma_error ? 32'd0 : words_r;
                        state_r <= ST_IDLE;
                    end
                end
                default: state_r <= ST_IDLE;
            endcase
        end
    end
endmodule
