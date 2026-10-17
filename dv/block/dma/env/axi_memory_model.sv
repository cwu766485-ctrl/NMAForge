`timescale 1ns / 1ps

module axi_memory_model #(
    parameter integer WORDS = 4096,
    parameter integer ADDR_WIDTH = 64,
    // Optional testbench mapping for exercising 64-bit AXI addresses while
    // keeping the model's small backing array indexed by the low 32 bits.
    // Disabled by default so standalone DMA tests retain high-address errors.
    parameter bit ALLOW_HIGH_ADDR_ALIAS = 1'b0,
    parameter [31:0] HIGH_ADDR_ALIAS_TAG = 32'd1
)(
    input  wire        clk,
    input  wire        resetn,

    input  wire        arvalid,
    input  wire [3:0]  arid,
    input  wire [ADDR_WIDTH-1:0] araddr,
    input  wire [7:0]  arlen,
    input  wire [2:0]  arsize,
    input  wire [1:0]  arburst,
    output wire        arready,
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
    output wire        awready,
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
    reg [1:0]  arready_gap_target_r;
    reg [1:0]  awready_gap_target_r;
    reg        arready_gap_target_valid_r;
    reg        awready_gap_target_valid_r;
    reg [1:0]  gap_pick;
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

    // Keep the historical ready timing when the opt-in address-gap knobs are
    // zero.  The base registers below retain the original registered-ready
    // behavior; the combinational gates only affect explicitly configured
    // E2E backpressure runs.
    reg        arready_base_r;
    reg        awready_base_r;
    reg        ar_hold_active_r;
    reg        aw_hold_active_r;
    reg [ADDR_WIDTH-1:0] ar_hold_addr_r;
    reg [3:0]  ar_hold_id_r;
    reg [7:0]  ar_hold_len_r;
    reg [2:0]  ar_hold_size_r;
    reg [1:0]  ar_hold_burst_r;
    reg [ADDR_WIDTH-1:0] aw_hold_addr_r;
    reg [3:0]  aw_hold_id_r;
    reg [7:0]  aw_hold_len_r;
    reg [2:0]  aw_hold_size_r;
    reg [1:0]  aw_hold_burst_r;
    reg [1:0]  arready_gap_count_r;
    reg [1:0]  awready_gap_count_r;
    integer    ar_stall_cycles_r;
    integer    aw_stall_cycles_r;

    integer ready_gap_cfg;
    integer read_gap_cfg;
    integer arready_gap_cfg;
    integer awready_gap_cfg;
    integer transaction_jitter_enable;
    integer inject_read_error_word;
    integer inject_write_error_word;

    wire [31:0] read_word_addr;
    wire [31:0] write_word_addr;
    wire read_addr_error;
    wire write_addr_error;
    wire read_inject_error;
    wire write_inject_error;
    wire ar_fire = arvalid && arready;
    wire aw_fire = awvalid && awready;
    wire read_dequeue = !read_active_r && !rvalid && read_q_count_r != 0;

    // Nonzero address-gap settings select periodic READY-low windows.  The
    // phase counters are free-running and independent of VALID, avoiding an
    // artificial VALID-to-READY combinational path in the memory responder.
    // With a zero gap these outputs retain the historical registered timing.
    assign arready = resetn &&
                     ((arready_gap_cfg == 0) ? arready_base_r :
                      ((read_q_count_r < 3'd4) &&
                       (!transaction_jitter_enable || arready_gap_target_valid_r) &&
                       (arready_gap_count_r >=
                        (transaction_jitter_enable ? arready_gap_target_r :
                                                     arready_gap_cfg[1:0]))));
    assign awready = resetn &&
                     ((awready_gap_cfg == 0) ? awready_base_r :
                      (!write_active_r && !bvalid &&
                       (!transaction_jitter_enable || awready_gap_target_valid_r) &&
                       (awready_gap_count_r >=
                        (transaction_jitter_enable ? awready_gap_target_r :
                                                     awready_gap_cfg[1:0]))));

    // Per-transaction gap sampling is opt-in. Keeping it disabled preserves
    // the existing deterministic responder timing for all legacy tests.
    covergroup axi_arready_stall_cg with function sample(input integer stall_cycles);
        option.per_instance = 1;
        cp_stall_cycles: coverpoint stall_cycles {
            bins cycles[] = {[0:3]};
        }
    endgroup
    covergroup axi_awready_stall_cg with function sample(input integer stall_cycles);
        option.per_instance = 1;
        cp_stall_cycles: coverpoint stall_cycles {
            bins cycles[] = {[0:3]};
        }
    endgroup
    covergroup axi_read_response_gap_cg with function sample(input integer gap_cycles);
        option.per_instance = 1;
        cp_gap_cycles: coverpoint gap_cycles {
            bins cycles[] = {[0:3]};
        }
    endgroup
    covergroup axi_write_data_gap_cg with function sample(input integer gap_cycles);
        option.per_instance = 1;
        cp_gap_cycles: coverpoint gap_cycles {
            bins cycles[] = {[0:3]};
        }
    endgroup

    axi_arready_stall_cg arready_stall_cg = new();
    axi_awready_stall_cg awready_stall_cg = new();
    axi_read_response_gap_cg read_response_gap_cg = new();
    axi_write_data_gap_cg write_data_gap_cg = new();

    function automatic [1:0] choose_gap(input integer max_gap);
        integer bounded_max;
        begin
            if (max_gap <= 0) begin
                choose_gap = 2'd0;
            end else begin
                bounded_max = (max_gap > 3) ? 3 : max_gap;
                choose_gap = $urandom_range(bounded_max, 0);
            end
        end
    endfunction

    assign read_word_addr = read_addr_r[31:2] +
                            (read_size_r == AXI_SIZE_128B ? {22'd0,read_idx_r,2'b00} : {24'd0,read_idx_r});
    assign write_word_addr = write_addr_r[31:2] +
                             (write_size_r == AXI_SIZE_128B ?
                              {22'd0,write_idx_r,2'b00} :
                              {24'd0,write_idx_r});
    assign read_addr_error = (((read_addr_r >> 32) != 0) &&
                              !(ALLOW_HIGH_ADDR_ALIAS &&
                                ((read_addr_r >> 32) == HIGH_ADDR_ALIAS_TAG))) ||
                             (read_word_addr >= WORDS);
    assign write_addr_error = (((write_addr_r >> 32) != 0) &&
                               !(ALLOW_HIGH_ADDR_ALIAS &&
                                 ((write_addr_r >> 32) == HIGH_ADDR_ALIAS_TAG))) ||
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
            arready_base_r <= 1'b0;
            rid            <= 4'd0;
            rdata          <= 128'd0;
            rresp          <= AXI_RESP_OKAY;
            rvalid         <= 1'b0;
            rlast          <= 1'b0;
            awready_base_r <= 1'b0;
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
            arready_gap_target_r <= 2'd0;
            awready_gap_target_r <= 2'd0;
            arready_gap_target_valid_r <= 1'b0;
            awready_gap_target_valid_r <= 1'b0;
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
            ar_hold_active_r <= 1'b0;
            aw_hold_active_r <= 1'b0;
            ar_hold_addr_r <= {ADDR_WIDTH{1'b0}};
            ar_hold_id_r <= 4'd0;
            ar_hold_len_r <= 8'd0;
            ar_hold_size_r <= 3'd0;
            ar_hold_burst_r <= 2'd0;
            aw_hold_addr_r <= {ADDR_WIDTH{1'b0}};
            aw_hold_id_r <= 4'd0;
            aw_hold_len_r <= 8'd0;
            aw_hold_size_r <= 3'd0;
            aw_hold_burst_r <= 2'd0;
            arready_gap_count_r <= 2'd0;
            awready_gap_count_r <= 2'd0;
            ar_stall_cycles_r <= 0;
            aw_stall_cycles_r <= 0;
            ready_gap_cfg <= 0;
            read_gap_cfg  <= 1;
            arready_gap_cfg <= 0;
            awready_gap_cfg <= 0;
            transaction_jitter_enable <= 0;
            inject_read_error_word <= -1;
            inject_write_error_word <= -1;
        end else begin
            arready_base_r <= read_q_count_r < 3'd4;
            awready_base_r <= !write_active_r && !bvalid;
            wready  <= write_active_r && !bvalid && (wready_gap_r == 2'd0);

            // Check the AXI master side of VALID/READY: once an address is
            // presented and stalled, VALID and the complete payload must stay
            // stable through the accepting edge.
            if (ar_hold_active_r &&
                (!arvalid || ({arid, araddr, arlen, arsize, arburst} !==
                              {ar_hold_id_r, ar_hold_addr_r, ar_hold_len_r,
                               ar_hold_size_r, ar_hold_burst_r})))
                $fatal(1, "AXI AR payload changed before ARREADY handshake");
            if (aw_hold_active_r &&
                (!awvalid || ({awid, awaddr, awlen, awsize, awburst} !==
                              {aw_hold_id_r, aw_hold_addr_r, aw_hold_len_r,
                               aw_hold_size_r, aw_hold_burst_r})))
                $fatal(1, "AXI AW payload changed before AWREADY handshake");

            if (arvalid && !arready) begin
                if (!ar_hold_active_r) begin
                    ar_hold_id_r <= arid;
                    ar_hold_addr_r <= araddr;
                    ar_hold_len_r <= arlen;
                    ar_hold_size_r <= arsize;
                    ar_hold_burst_r <= arburst;
                end
                ar_hold_active_r <= 1'b1;
            end else if (ar_fire) begin
                ar_hold_active_r <= 1'b0;
            end

            if (awvalid && !awready) begin
                if (!aw_hold_active_r) begin
                    aw_hold_id_r <= awid;
                    aw_hold_addr_r <= awaddr;
                    aw_hold_len_r <= awlen;
                    aw_hold_size_r <= awsize;
                    aw_hold_burst_r <= awburst;
                end
                aw_hold_active_r <= 1'b1;
            end else if (aw_fire) begin
                aw_hold_active_r <= 1'b0;
            end

            // Four-cycle period: cfg=1/2/3 creates 1/2/3 consecutive
            // READY-low cycles followed by the remaining high cycles.
            // Natural two-bit overflow wraps phase 3 back to 0.
            arready_gap_count_r <= arready_gap_count_r + 2'd1;
            awready_gap_count_r <= awready_gap_count_r + 2'd1;

            // Select the address-channel threshold once per newly presented
            // request. The target is then held while VALID is stalled.
            if (transaction_jitter_enable && arvalid &&
                !ar_hold_active_r && !arready_gap_target_valid_r) begin
                arready_gap_target_r <= choose_gap(arready_gap_cfg);
                arready_gap_target_valid_r <= 1'b1;
            end else if (!transaction_jitter_enable) begin
                arready_gap_target_valid_r <= 1'b0;
            end
            if (transaction_jitter_enable && awvalid &&
                !aw_hold_active_r && !awready_gap_target_valid_r) begin
                awready_gap_target_r <= choose_gap(awready_gap_cfg);
                awready_gap_target_valid_r <= 1'b1;
            end else if (!transaction_jitter_enable) begin
                awready_gap_target_valid_r <= 1'b0;
            end

            if (!arvalid || ar_fire) begin
                if (ar_fire && (arready_gap_cfg != 0) && (ar_stall_cycles_r != 0)) begin
                    $display("[AXI_MEM_ADDR_STALL] channel=AR configured=%0d observed=%0d", arready_gap_cfg, ar_stall_cycles_r);
                end
                if (transaction_jitter_enable)
                    arready_stall_cg.sample(ar_stall_cycles_r);
                ar_stall_cycles_r <= 0;
            end else if (!arready && (ar_stall_cycles_r < 32'h7fff_ffff) &&
                         (arready_gap_cfg != 0)) begin
                ar_stall_cycles_r <= ar_stall_cycles_r + 1;
            end

            if (!awvalid || aw_fire) begin
                if (aw_fire && (awready_gap_cfg != 0) && (aw_stall_cycles_r != 0)) begin
                    $display("[AXI_MEM_ADDR_STALL] channel=AW configured=%0d observed=%0d", awready_gap_cfg, aw_stall_cycles_r);
                end
                if (transaction_jitter_enable)
                    awready_stall_cg.sample(aw_stall_cycles_r);
                aw_stall_cycles_r <= 0;
            end else if (!awready && (aw_stall_cycles_r < 32'h7fff_ffff) &&
                         (awready_gap_cfg != 0)) begin
                aw_stall_cycles_r <= aw_stall_cycles_r + 1;
            end

            if (ar_fire) begin
                arready_gap_target_valid_r <= 1'b0;
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
                gap_pick = transaction_jitter_enable ? choose_gap(read_gap_cfg) : read_gap_cfg[1:0];
                read_gap_r <= gap_pick;
                if (transaction_jitter_enable)
                    read_response_gap_cg.sample(gap_pick);
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
                    gap_pick = transaction_jitter_enable ? choose_gap(read_gap_cfg) : read_gap_cfg[1:0];
                    read_gap_r <= gap_pick;
                    if (transaction_jitter_enable)
                        read_response_gap_cg.sample(gap_pick);
                end
            end

            if (aw_fire) begin
                awready_gap_target_valid_r <= 1'b0;
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
                gap_pick = transaction_jitter_enable ? choose_gap(ready_gap_cfg) : ready_gap_cfg[1:0];
                wready_gap_r <= gap_pick;
                if (transaction_jitter_enable)
                    write_data_gap_cg.sample(gap_pick);
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
                gap_pick = transaction_jitter_enable ? choose_gap(ready_gap_cfg) : ready_gap_cfg[1:0];
                wready_gap_r <= gap_pick;
                if (transaction_jitter_enable)
                    write_data_gap_cg.sample(gap_pick);

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
