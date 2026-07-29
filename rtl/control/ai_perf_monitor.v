`timescale 1ns / 1ps

// A5 performance monitor.  Counters are intentionally passive: they never
// participate in arbitration or backpressure, and software clears a snapshot
// before measuring one workload through PERF_CTRL[0].
module ai_perf_monitor(
    input  wire        clk,
    input  wire        resetn,
    input  wire        clear,
    input  wire        matrix_busy,
    input  wire        matrix_mac_active,
    input  wire        matrix_banked_wait,
    input  wire        dma_ar_fire,
    input  wire        dma_r_fire,
    input  wire        dma_rlast_fire,
    input  wire        dma_aw_fire,
    input  wire        dma_w_fire,
    input  wire        dma_r_stall,
    input  wire [4:0]  dma_r_beat_bytes,
    input  wire [4:0]  dma_w_beat_bytes,
    output reg [31:0] matrix_cycles,
    output reg [31:0] matrix_mac_cycles,
    output reg [31:0] matrix_banked_stall_cycles,
    output reg [31:0] dma_read_bytes,
    output reg [31:0] dma_write_bytes,
    output reg [31:0] dma_ar_count,
    output reg [31:0] dma_aw_count,
    output reg [31:0] dma_r_stall_cycles,
    output reg [2:0]  dma_rd_outstanding,
    output reg [2:0]  dma_rd_outstanding_highwater
);
    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            matrix_cycles <= 0;
            matrix_mac_cycles <= 0;
            matrix_banked_stall_cycles <= 0;
            dma_read_bytes <= 0;
            dma_write_bytes <= 0;
            dma_ar_count <= 0;
            dma_aw_count <= 0;
            dma_r_stall_cycles <= 0;
            dma_rd_outstanding <= 0;
            dma_rd_outstanding_highwater <= 0;
        end else if (clear) begin
            matrix_cycles <= 0;
            matrix_mac_cycles <= 0;
            matrix_banked_stall_cycles <= 0;
            dma_read_bytes <= 0;
            dma_write_bytes <= 0;
            dma_ar_count <= 0;
            dma_aw_count <= 0;
            dma_r_stall_cycles <= 0;
            dma_rd_outstanding <= 0;
            dma_rd_outstanding_highwater <= 0;
        end else begin
            if (matrix_busy)
                matrix_cycles <= matrix_cycles + 1'b1;
            if (matrix_mac_active)
                matrix_mac_cycles <= matrix_mac_cycles + 1'b1;
            if (matrix_banked_wait)
                matrix_banked_stall_cycles <= matrix_banked_stall_cycles + 1'b1;
            if (dma_r_fire)
                dma_read_bytes <= dma_read_bytes +
                                  {27'd0, dma_r_beat_bytes};
            if (dma_w_fire)
                dma_write_bytes <= dma_write_bytes +
                                   {27'd0, dma_w_beat_bytes};
            if (dma_ar_fire)
                dma_ar_count <= dma_ar_count + 1'b1;
            if (dma_aw_fire)
                dma_aw_count <= dma_aw_count + 1'b1;
            if (dma_r_stall)
                dma_r_stall_cycles <= dma_r_stall_cycles + 1'b1;
            case ({dma_ar_fire, dma_rlast_fire})
                2'b10: dma_rd_outstanding <= dma_rd_outstanding + 1'b1;
                2'b01: dma_rd_outstanding <= dma_rd_outstanding - 1'b1;
                default: dma_rd_outstanding <= dma_rd_outstanding;
            endcase
            if (dma_ar_fire && !dma_rlast_fire &&
                dma_rd_outstanding + 1'b1 > dma_rd_outstanding_highwater)
                dma_rd_outstanding_highwater <= dma_rd_outstanding + 1'b1;
        end
    end
endmodule
