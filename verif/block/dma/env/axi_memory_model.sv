`timescale 1ns / 1ps

module axi_memory_model #(
    parameter integer WORDS = 4096,
    parameter integer ADDR_WIDTH = 64
)(
    input  wire        clk,
    input  wire        resetn,

    input  wire        arvalid,
    input  wire [3:0]  arid,
    input  wire [ADDR_WIDTH-1:0] araddr,
    input  wire [7:0]  arlen,
    input  wire [2:0]  arsize,
    input  wire [1:0]  arburst,
    output reg         arready,
    output reg  [3:0]  rid,
    output reg  [127:0] rdata,
    output reg  [1:0]  rresp,
    output reg         rvalid,
    output reg         rlast,
    input  wire        rready,

    input  wire        awvalid,
    input  wire [3:0]  awid,
    input  wire [ADDR_WIDTH-1:0] awaddr,
    input  wire [7:0]  awlen,
    input  wire [2:0]  awsize,
    input  wire [1:0]  awburst,
    output reg         awready,
    input  wire        wvalid,
    input  wire [127:0] wdata,
    input  wire [15:0]  wstrb,
    input  wire        wlast,
    output reg         wready,
    output reg  [1:0]  bresp,
    output reg  [3:0]  bid,
    output reg         bvalid,
    input  wire        bready
);

    localparam [1:0] AXI_RESP_OKAY = 2'b00;
    localparam [1:0] AXI_RESP_SLVERR = 2'b10;
    localparam [1:0] AXI_BURST_INCR = 2'b01;
    localparam [2:0] AXI_SIZE_32B = 3'd2;
    localparam [2:0] AXI_SIZE_128B = 3'd4;

    reg [31:0] mem [0:WORDS-1];

    reg        read_active_r;
    reg [ADDR_WIDTH-1:0] read_addr_r;
    reg [7:0]  read_len_r;
    reg [7:0]  read_idx_r;
    reg        read_error_r;
    reg [1:0]  read_gap_r;
    reg [ADDR_WIDTH-1:0] read_addr_fifo [0:3];
    reg [7:0]  read_len_fifo [0:3];
    reg [2:0]  read_size_fifo [0:3];
    reg [3:0]  read_id_fifo [0:3];
    reg        read_error_fifo [0:3];
    reg [1:0]  read_q_head_r, read_q_tail_r;
    reg [2:0]  read_q_count_r;
    reg [2:0]  read_size_r;
    reg [3:0]  read_id_r;

    reg        write_active_r;
    reg [ADDR_WIDTH-1:0] write_addr_r;
    reg [7:0]  write_len_r;
    reg [7:0]  write_idx_r;
    reg        write_error_r;
    reg [2:0]  write_size_r;
    reg [3:0]  write_id_r;
    reg [1:0]  wready_gap_r;

    integer ready_gap_cfg;
    integer inject_read_error_word;
    integer inject_write_error_word;

    wire [31:0] read_word_addr;
    wire [31:0] write_word_addr;
    wire read_addr_error;
    wire write_addr_error;
    wire read_inject_error;
    wire write_inject_error;
    wire ar_fire = arvalid && arready;
    wire read_dequeue = !read_active_r && !rvalid && read_q_count_r != 0;

    assign read_word_addr = read_addr_r[31:2] +
                            (read_size_r == AXI_SIZE_128B ? {22'd0,read_idx_r,2'b00} : {24'd0,read_idx_r});
    assign write_word_addr = write_addr_r[31:2] +
                             (write_size_r == AXI_SIZE_128B ?
                              {22'd0,write_idx_r,2'b00} :
                              {24'd0,write_idx_r});
    assign read_addr_error = ((read_addr_r >> 32) != 0) ||
                             (read_word_addr >= WORDS);
    assign write_addr_error = ((write_addr_r >> 32) != 0) ||
                              (write_word_addr >= WORDS);
    assign read_inject_error = (inject_read_error_word >= 0) &&
                               (read_word_addr == inject_read_error_word[31:0]);
    assign write_inject_error = (inject_write_error_word >= 0) &&
                                (write_word_addr == inject_write_error_word[31:0]);

    function [31:0] merge_wstrb;
        input [31:0] old_data;
        input [31:0] new_data;
        input [3:0]  strb;
        begin
            merge_wstrb = old_data;
            if (strb[0]) merge_wstrb[7:0]   = new_data[7:0];
            if (strb[1]) merge_wstrb[15:8]  = new_data[15:8];
            if (strb[2]) merge_wstrb[23:16] = new_data[23:16];
            if (strb[3]) merge_wstrb[31:24] = new_data[31:24];
        end
    endfunction

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            arready        <= 1'b0;
            rid            <= 4'd0;
            rdata          <= 128'd0;
            rresp          <= AXI_RESP_OKAY;
            rvalid         <= 1'b0;
            rlast          <= 1'b0;
            awready        <= 1'b0;
            wready         <= 1'b0;
            bresp          <= AXI_RESP_OKAY;
            bid            <= 4'd0;
            bvalid         <= 1'b0;
            read_active_r  <= 1'b0;
            read_addr_r    <= {ADDR_WIDTH{1'b0}};
            read_len_r     <= 8'd0;
            read_idx_r     <= 8'd0;
            read_error_r   <= 1'b0;
            read_gap_r     <= 2'd0;
            read_q_head_r  <= 2'd0;
            read_q_tail_r  <= 2'd0;
            read_q_count_r <= 3'd0;
            read_size_r <= AXI_SIZE_32B;
            read_id_r <= 4'd0;
            write_active_r <= 1'b0;
            write_addr_r   <= {ADDR_WIDTH{1'b0}};
            write_len_r    <= 8'd0;
            write_idx_r    <= 8'd0;
            write_error_r  <= 1'b0;
            write_size_r <= AXI_SIZE_32B;
            write_id_r <= 4'd0;
            wready_gap_r   <= 2'd0;
            ready_gap_cfg <= 0;
            inject_read_error_word <= -1;
            inject_write_error_word <= -1;
        end else begin
            arready <= read_q_count_r < 3'd4;
            awready <= !write_active_r && !bvalid;
            wready  <= write_active_r && !bvalid && (wready_gap_r == 2'd0);

            if (ar_fire) begin
                read_addr_fifo[read_q_tail_r] <= araddr;
                read_len_fifo[read_q_tail_r] <= arlen;
                read_size_fifo[read_q_tail_r] <= arsize;
                read_id_fifo[read_q_tail_r] <= arid;
                read_error_fifo[read_q_tail_r] <=
                    ((arsize != AXI_SIZE_32B) && (arsize != AXI_SIZE_128B)) ||
                    (arburst != AXI_BURST_INCR) ||
                    ((arsize == AXI_SIZE_128B) ? (araddr[3:0] != 4'b0) : (araddr[1:0] != 2'b00));
                read_q_tail_r <= read_q_tail_r + 1'b1;
            end

            if (read_dequeue) begin
                read_active_r <= 1'b1;
                read_addr_r   <= read_addr_fifo[read_q_head_r];
                read_len_r    <= read_len_fifo[read_q_head_r];
                read_idx_r    <= 8'd0;
                read_error_r  <= read_error_fifo[read_q_head_r];
                read_size_r   <= read_size_fifo[read_q_head_r];
                read_id_r     <= read_id_fifo[read_q_head_r];
                rid           <= read_id_fifo[read_q_head_r];
                read_q_head_r <= read_q_head_r + 1'b1;
                read_gap_r    <= 2'd1;
            end


            case ({ar_fire, read_dequeue})
              2'b10: read_q_count_r <= read_q_count_r + 1'b1;
              2'b01: read_q_count_r <= read_q_count_r - 1'b1;
              default: read_q_count_r <= read_q_count_r;
            endcase

            if (read_active_r && !rvalid) begin
                if (read_gap_r != 2'd0) begin
                    read_gap_r <= read_gap_r - 2'd1;
                end else begin
                    if (read_addr_error) rdata <= 128'd0;
                    else if (read_size_r == AXI_SIZE_128B)
                        rdata <= {mem[read_word_addr+3],mem[read_word_addr+2],mem[read_word_addr+1],mem[read_word_addr]};
                    else begin
                        case (read_addr_r[3:2])
                          2'd0: rdata <= {96'd0,mem[read_word_addr]};
                          2'd1: rdata <= {64'd0,mem[read_word_addr],32'd0};
                          2'd2: rdata <= {32'd0,mem[read_word_addr],64'd0};
                          default: rdata <= {mem[read_word_addr],96'd0};
                        endcase
                    end
                    rresp  <= (read_error_r || read_addr_error || read_inject_error) ?
                              AXI_RESP_SLVERR : AXI_RESP_OKAY;
                    rlast  <= (read_idx_r == read_len_r);
                    rvalid <= 1'b1;
                end
            end

            if (rvalid && rready) begin
                rvalid <= 1'b0;
                if (rlast) begin
                    read_active_r <= 1'b0;
                    rlast <= 1'b0;
                end else begin
                    read_idx_r <= read_idx_r + 8'd1;
                    read_gap_r <= 2'd1;
                end
            end

            if (awvalid && awready) begin
                write_active_r <= 1'b1;
                write_addr_r   <= awaddr;
                write_len_r    <= awlen;
                write_idx_r    <= 8'd0;
                write_size_r   <= awsize;
                write_id_r     <= awid;
                write_error_r  <=
                    ((awsize != AXI_SIZE_32B) &&
                     (awsize != AXI_SIZE_128B)) ||
                    (awburst != AXI_BURST_INCR) ||
                    ((awsize == AXI_SIZE_128B) ?
                     (awaddr[3:0] != 4'b0) :
                     (awaddr[1:0] != 2'b00));
                wready_gap_r   <= ready_gap_cfg[1:0];
            end

            if (write_active_r && wvalid && wready) begin
                if (write_addr_error || write_inject_error) begin
                    write_error_r <= 1'b1;
                end else begin
                    if (write_size_r == AXI_SIZE_128B) begin
                        mem[write_word_addr] <=
                            merge_wstrb(mem[write_word_addr],
                                        wdata[31:0], wstrb[3:0]);
                        mem[write_word_addr+1] <=
                            merge_wstrb(mem[write_word_addr+1],
                                        wdata[63:32], wstrb[7:4]);
                        mem[write_word_addr+2] <=
                            merge_wstrb(mem[write_word_addr+2],
                                        wdata[95:64], wstrb[11:8]);
                        mem[write_word_addr+3] <=
                            merge_wstrb(mem[write_word_addr+3],
                                        wdata[127:96], wstrb[15:12]);
                    end else begin
                        case (write_addr_r[3:2])
                          2'd0: mem[write_word_addr] <=
                              merge_wstrb(mem[write_word_addr],
                                          wdata[31:0], wstrb[3:0]);
                          2'd1: mem[write_word_addr] <=
                              merge_wstrb(mem[write_word_addr],
                                          wdata[63:32], wstrb[7:4]);
                          2'd2: mem[write_word_addr] <=
                              merge_wstrb(mem[write_word_addr],
                                          wdata[95:64], wstrb[11:8]);
                          default: mem[write_word_addr] <=
                              merge_wstrb(mem[write_word_addr],
                                          wdata[127:96], wstrb[15:12]);
                        endcase
                    end
                end
                wready_gap_r <= ready_gap_cfg[1:0];

                if ((write_idx_r == write_len_r) || wlast) begin
                    bresp <= (write_error_r || write_addr_error || write_inject_error ||
                              (write_idx_r != write_len_r) || !wlast) ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
                    bid <= write_id_r;
                    bvalid <= 1'b1;
                    write_active_r <= 1'b0;
                end else begin
                    write_idx_r <= write_idx_r + 8'd1;
                end
            end else if (write_active_r && wready_gap_r != 2'd0) begin
                wready_gap_r <= wready_gap_r - 2'd1;
            end

            if (bvalid && bready) begin
                bvalid <= 1'b0;
                bresp <= AXI_RESP_OKAY;
            end
        end
    end

endmodule
