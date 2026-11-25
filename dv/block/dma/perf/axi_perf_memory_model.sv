`timescale 1ns/1ps

// Performance-oriented AXI4 slave for DMA bandwidth studies (not a protocol
// stress model).  Read bursts are accepted while fewer than MAX_OUTSTANDING
// are in flight; each burst's first beat is returned LATENCY cycles after its
// AR handshake (pipelined across bursts), and beats stream back-to-back at one
// beat per BEAT_INTERVAL cycles, in AR order, honoring RREADY.  BEAT_INTERVAL
// models a DRAM/interconnect bandwidth cap below the 16-byte/cycle AXI peak.
// Writes accept one W beat per cycle and return B LATENCY cycles after WLAST.
module axi_perf_memory_model #(
    parameter integer WORDS = 1 << 20
)(
    input  wire         clk,
    input  wire         resetn,
    input  wire [31:0]  latency,
    input  wire [31:0]  beat_interval,
    input  wire [31:0]  max_outstanding,
    input  wire [3:0]   arid,
    input  wire         arvalid,
    input  wire [63:0]  araddr,
    input  wire [7:0]   arlen,
    input  wire [2:0]   arsize,
    output wire         arready,
    output reg  [3:0]   rid,
    output reg  [127:0] rdata,
    output reg  [1:0]   rresp,
    output reg          rvalid,
    output reg          rlast,
    input  wire         rready,
    input  wire [3:0]   awid,
    input  wire         awvalid,
    input  wire [63:0]  awaddr,
    input  wire [7:0]   awlen,
    output wire         awready,
    input  wire         wvalid,
    input  wire [127:0] wdata,
    input  wire         wlast,
    output wire         wready,
    output reg  [3:0]   bid,
    output reg  [1:0]   bresp,
    output reg          bvalid,
    input  wire         bready
);
    reg [31:0] mem [0:WORDS-1];
    reg [63:0] q_addr [0:31];
    reg [7:0]  q_len  [0:31];
    reg [3:0]  q_id   [0:31];
    reg [63:0] q_due  [0:31];
    reg [4:0]  q_head, q_tail;
    reg [5:0]  q_count;
    reg [63:0] now;
    reg [7:0]  beat_idx;
    reg [31:0] gap;
    reg        active;
    assign arready = (q_count < max_outstanding) && (q_count < 6'd32);
    wire ar_fire = arvalid && arready;
    wire [63:0] cur_word = (q_addr[q_head] >> 2) + {beat_idx, 2'b00};
    wire beat_fire = rvalid && rready;
    wire burst_done = beat_fire && rlast;

    // Write side
    reg [3:0]  w_id;
    reg        w_active;
    reg [63:0] w_word;
    reg [63:0] b_due_q [0:15];
    reg [3:0]  b_id_q [0:15];
    reg [3:0]  b_head, b_tail;
    reg [4:0]  b_count;
    assign awready = !w_active;
    assign wready = w_active;

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            q_head <= 0; q_tail <= 0; q_count <= 0; now <= 0; beat_idx <= 0;
            gap <= 0; active <= 0; rvalid <= 0; rlast <= 0; rid <= 0; rdata <= 0;
            rresp <= 0; w_active <= 0; w_id <= 0; w_word <= 0; b_head <= 0; b_tail <= 0;
            b_count <= 0; bvalid <= 0; bid <= 0; bresp <= 0;
        end else begin
            now <= now + 1;
            if (ar_fire) begin
                q_addr[q_tail] <= araddr; q_len[q_tail] <= arlen; q_id[q_tail] <= arid;
                q_due[q_tail] <= now + latency;
                q_tail <= q_tail + 1'b1;
            end
            q_count <= q_count + (ar_fire ? 6'd1 : 6'd0) - (burst_done ? 6'd1 : 6'd0);
            if (beat_fire) begin
                rvalid <= 1'b0;
                if (rlast) begin
                    q_head <= q_head + 1'b1; beat_idx <= 0;
                end else beat_idx <= beat_idx + 1'b1;
                gap <= (beat_interval > 2) ? beat_interval - 2 : 0;
            end
            // Present the next beat (back-to-back when beat_interval == 1).
            if ((!rvalid || beat_fire) && (q_count - (burst_done ? 1 : 0)) != 0) begin
                if (beat_fire && beat_interval > 1) begin
                    // wait for the gap
                end else if (!beat_fire && gap != 0) begin
                    gap <= gap - 1;
                end else begin : present
                    reg [4:0] h;
                    reg [7:0] bi;
                    h = (beat_fire && rlast) ? q_head + 1'b1 : q_head;
                    bi = beat_fire ? ((rlast) ? 8'd0 : beat_idx + 8'd1) : beat_idx;
                    if (q_due[h] <= now) begin
                        rvalid <= 1'b1; rid <= q_id[h];
                        rdata <= {mem[((q_addr[h] >> 2) + {bi, 2'b00} + 3) % WORDS],
                                  mem[((q_addr[h] >> 2) + {bi, 2'b00} + 2) % WORDS],
                                  mem[((q_addr[h] >> 2) + {bi, 2'b00} + 1) % WORDS],
                                  mem[((q_addr[h] >> 2) + {bi, 2'b00}) % WORDS]};
                        rresp <= 2'b00; rlast <= (bi == q_len[h]);
                    end
                end
            end
            // Writes
            if (awvalid && awready) begin
                w_active <= 1'b1; w_id <= awid; w_word <= awaddr >> 2;
            end
            if (wvalid && wready) begin
                mem[w_word % WORDS] <= wdata[31:0]; mem[(w_word + 1) % WORDS] <= wdata[63:32];
                mem[(w_word + 2) % WORDS] <= wdata[95:64]; mem[(w_word + 3) % WORDS] <= wdata[127:96];
                w_word <= w_word + 4;
                if (wlast) begin
                    w_active <= 1'b0;
                    b_due_q[b_tail] <= now + latency; b_id_q[b_tail] <= w_id;
                    b_tail <= b_tail + 1'b1;
                end
            end
            b_count <= b_count + ((wvalid && wready && wlast) ? 5'd1 : 5'd0) -
                       ((bvalid && bready) ? 5'd1 : 5'd0);
            if (bvalid && bready) begin bvalid <= 1'b0; b_head <= b_head + 1'b1; end
            if ((!bvalid || bready) && b_count - ((bvalid && bready) ? 1 : 0) != 0) begin : bpres
                reg [3:0] bh;
                bh = (bvalid && bready) ? b_head + 1'b1 : b_head;
                if (b_due_q[bh] <= now) begin bvalid <= 1'b1; bid <= b_id_q[bh]; bresp <= 2'b00; end
            end
        end
    end
endmodule
