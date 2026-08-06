`timescale 1ns / 1ps

// Four-bank, common-clock true-dual-port scratchpad.
//
// Port A is reserved for the AXI-Lite host/debug window.  Port B is reserved
// for the scheduler (DMA, descriptor, scalar core or banked core).  Both read
// paths have two registered cycles of latency.  The extra output register is
// required for timing closure when a 512 KiB profile creates deep BRAM chains.
// The banked engine uses Port B exclusively and reads all four banks at the
// same row; it issues its two operands in separate cycles.
module ai_scratchpad #(
    parameter integer BANKS = 4,
    parameter integer WORDS_PER_BANK = 32768,
    parameter integer ROW_BITS = $clog2(WORDS_PER_BANK)
)(
    input wire clk, input wire resetn,
    input wire host_valid, input wire host_write,
    input wire [31:0] host_addr, input wire [31:0] host_wdata,
    input wire [3:0] host_wstrb,
    output reg [31:0] host_rdata, output reg host_error,
    output reg host_parity_error,
    input wire compute_valid, input wire compute_write,
    input wire [31:0] compute_addr, input wire [31:0] compute_wdata,
    output reg [31:0] compute_rdata, output reg compute_parity_error,
    input wire line_valid, input wire line_write,
    input wire [31:0] line_addr, input wire [127:0] line_wdata,
    input wire [15:0] line_wstrb,
    output reg [127:0] line_rdata, output reg [3:0] line_parity_error,
    output reg line_error,
    input wire banked_read_valid, input wire [31:0] banked_addr,
    output reg [31:0] banked_data0, output reg [31:0] banked_data1,
    output reg [31:0] banked_data2, output reg [31:0] banked_data3,
    output reg [3:0] banked_parity_error
    ,input wire [3:0] cnm_read_valid,
    input wire [31:0] cnm_addr0, input wire [31:0] cnm_addr1,
    input wire [31:0] cnm_addr2, input wire [31:0] cnm_addr3,
    output reg [31:0] cnm_data0, output reg [31:0] cnm_data1,
    output reg [31:0] cnm_data2, output reg [31:0] cnm_data3,
    output reg [3:0] cnm_parity_error
);
    localparam integer BANK_BITS = 2;
    localparam integer BANK_MEMORY_BITS = WORDS_PER_BANK * 32;
    wire [31:0] host_word_addr = host_addr[31:2];
    wire [31:0] compute_word_addr = compute_addr[31:2];
    wire [31:0] line_word_addr = line_addr[31:2];
    wire [31:0] banked_word_addr = banked_addr[31:2];
    wire [31:0] cnm_word_addr0 = cnm_addr0[31:2], cnm_word_addr1 = cnm_addr1[31:2];
    wire [31:0] cnm_word_addr2 = cnm_addr2[31:2], cnm_word_addr3 = cnm_addr3[31:2];
    wire [1:0] host_bank = host_word_addr[1:0];
    wire [1:0] compute_bank = compute_word_addr[1:0];
    wire [ROW_BITS-1:0] host_row = host_word_addr[ROW_BITS+BANK_BITS-1:BANK_BITS];
    wire [ROW_BITS-1:0] compute_row = compute_word_addr[ROW_BITS+BANK_BITS-1:BANK_BITS];
    wire [ROW_BITS-1:0] line_row = line_word_addr[ROW_BITS+BANK_BITS-1:BANK_BITS];
    wire [ROW_BITS-1:0] banked_row = banked_word_addr[ROW_BITS+BANK_BITS-1:BANK_BITS];
    wire [ROW_BITS-1:0] cnm_row0 = cnm_word_addr0[ROW_BITS+BANK_BITS-1:BANK_BITS];
    wire [ROW_BITS-1:0] cnm_row1 = cnm_word_addr1[ROW_BITS+BANK_BITS-1:BANK_BITS];
    wire [ROW_BITS-1:0] cnm_row2 = cnm_word_addr2[ROW_BITS+BANK_BITS-1:BANK_BITS];
    wire [ROW_BITS-1:0] cnm_row3 = cnm_word_addr3[ROW_BITS+BANK_BITS-1:BANK_BITS];
    wire host_align_error = |host_addr[1:0];
    wire compute_align_error = |compute_addr[1:0];
    wire line_align_error = |line_addr[3:0];
    wire banked_align_error = |banked_addr[3:0];
    wire host_range_error = (host_word_addr >= BANKS * WORDS_PER_BANK);
    wire compute_range_error = (compute_word_addr >= BANKS * WORDS_PER_BANK);
    wire line_range_error = (line_addr > (BANKS * WORDS_PER_BANK * 4) - 16);
    wire banked_range_error = (banked_addr > (BANKS * WORDS_PER_BANK * 4) - 16);
    wire cnm_align_error = |cnm_addr0[1:0] || |cnm_addr1[1:0] || |cnm_addr2[1:0] || |cnm_addr3[1:0];
    wire cnm_range_error = (cnm_word_addr0 >= BANKS*WORDS_PER_BANK) || (cnm_word_addr1 >= BANKS*WORDS_PER_BANK) ||
                           (cnm_word_addr2 >= BANKS*WORDS_PER_BANK) || (cnm_word_addr3 >= BANKS*WORDS_PER_BANK);
    wire host_conflict = host_valid && (compute_valid || line_valid ||
                                        banked_read_valid || (|cnm_read_valid));
    wire host_access_ok = host_valid && !host_align_error && !host_range_error && !host_conflict;
    wire compute_access_ok = compute_valid && !compute_align_error && !compute_range_error;
    wire line_access_ok = line_valid && !line_align_error && !line_range_error;
    wire banked_access_ok = banked_read_valid && !banked_align_error && !banked_range_error;
    // A2.2 permits each lane to be valid independently.  An inactive lane
    // does not consume its bank port and its response bit remains clear.
    wire cnm_lane_access0 = cnm_read_valid[0] && !|cnm_addr0[1:0] && (cnm_word_addr0 < BANKS*WORDS_PER_BANK);
    wire cnm_lane_access1 = cnm_read_valid[1] && !|cnm_addr1[1:0] && (cnm_word_addr1 < BANKS*WORDS_PER_BANK);
    wire cnm_lane_access2 = cnm_read_valid[2] && !|cnm_addr2[1:0] && (cnm_word_addr2 < BANKS*WORDS_PER_BANK);
    wire cnm_lane_access3 = cnm_read_valid[3] && !|cnm_addr3[1:0] && (cnm_word_addr3 < BANKS*WORDS_PER_BANK);
    wire cnm_access_ok = cnm_lane_access0 || cnm_lane_access1 || cnm_lane_access2 || cnm_lane_access3;

    always @(*) begin
        host_error = host_align_error || host_range_error || host_conflict;
        line_error = line_valid && (line_align_error || line_range_error);
    end

`ifndef VCS
    // FPGA implementation: four explicit common-clock true-dual-port BRAMs.
    // Port A: host/debug; Port B: scheduler/banked engine.
    wire [31:0] x0a, x1a, x2a, x3a, x0b, x1b, x2b, x3b;
    // Match the bank select to XPM READ_LATENCY=2.  Using the live request
    // address here creates a false functional coupling between the next
    // request and the returning data, and also places the complete scheduler
    // address mux in front of every compute consumer.
    reg [1:0] host_read_bank_d0, host_read_bank_d1;
    reg [1:0] compute_read_bank_d0, compute_read_bank_d1;
    wire portb_enable = line_access_ok || banked_access_ok || cnm_access_ok || compute_access_ok;
    wire [ROW_BITS-1:0] portb_row = line_access_ok ? line_row :
                                    (banked_access_ok ? banked_row : compute_row);
    wire [3:0] host_we = (host_access_ok && host_write) ? host_wstrb : 4'b0;
    wire [3:0] compute_we = (compute_access_ok && compute_write) ? 4'hf : 4'b0;

    xpm_memory_tdpram #(.ADDR_WIDTH_A(ROW_BITS),.ADDR_WIDTH_B(ROW_BITS),.AUTO_SLEEP_TIME(0),.BYTE_WRITE_WIDTH_A(8),.BYTE_WRITE_WIDTH_B(8),.CLOCKING_MODE("common_clock"),.MEMORY_INIT_FILE("none"),.MEMORY_INIT_PARAM("0"),.MEMORY_OPTIMIZATION("true"),.MEMORY_PRIMITIVE("block"),.MEMORY_SIZE(BANK_MEMORY_BITS),.MESSAGE_CONTROL(0),.READ_DATA_WIDTH_A(32),.READ_DATA_WIDTH_B(32),.READ_LATENCY_A(2),.READ_LATENCY_B(2),.READ_RESET_VALUE_A("0"),.READ_RESET_VALUE_B("0"),.RST_MODE_A("SYNC"),.RST_MODE_B("SYNC"),.SIM_ASSERT_CHK(0),.USE_EMBEDDED_CONSTRAINT(0),.USE_MEM_INIT(0),.WAKEUP_TIME("disable_sleep"),.WRITE_DATA_WIDTH_A(32),.WRITE_DATA_WIDTH_B(32),.WRITE_MODE_B("read_first"),.WRITE_MODE_A("read_first")) xpm_bank0 (.clka(clk),.clkb(clk),.ena(host_access_ok && host_bank==2'd0),.enb(portb_enable),.wea(host_we),.web(line_access_ok&&line_write?line_wstrb[3:0]:((compute_access_ok&&compute_bank==2'd0)?compute_we:4'b0)),.addra(host_row),.addrb(cnm_access_ok ? cnm_row0 : portb_row),.dina(host_wdata),.dinb(line_access_ok?line_wdata[31:0]:compute_wdata),.douta(x0a),.doutb(x0b),.rsta(1'b0),.rstb(1'b0),.regcea(1'b1),.regceb(1'b1),.sleep(1'b0),.injectsbiterra(1'b0),.injectdbiterra(1'b0),.injectsbiterrb(1'b0),.injectdbiterrb(1'b0));
    xpm_memory_tdpram #(.ADDR_WIDTH_A(ROW_BITS),.ADDR_WIDTH_B(ROW_BITS),.AUTO_SLEEP_TIME(0),.BYTE_WRITE_WIDTH_A(8),.BYTE_WRITE_WIDTH_B(8),.CLOCKING_MODE("common_clock"),.MEMORY_INIT_FILE("none"),.MEMORY_INIT_PARAM("0"),.MEMORY_OPTIMIZATION("true"),.MEMORY_PRIMITIVE("block"),.MEMORY_SIZE(BANK_MEMORY_BITS),.MESSAGE_CONTROL(0),.READ_DATA_WIDTH_A(32),.READ_DATA_WIDTH_B(32),.READ_LATENCY_A(2),.READ_LATENCY_B(2),.READ_RESET_VALUE_A("0"),.READ_RESET_VALUE_B("0"),.RST_MODE_A("SYNC"),.RST_MODE_B("SYNC"),.SIM_ASSERT_CHK(0),.USE_EMBEDDED_CONSTRAINT(0),.USE_MEM_INIT(0),.WAKEUP_TIME("disable_sleep"),.WRITE_DATA_WIDTH_A(32),.WRITE_DATA_WIDTH_B(32),.WRITE_MODE_A("read_first"),.WRITE_MODE_B("read_first")) xpm_bank1 (.clka(clk),.clkb(clk),.ena(host_access_ok && host_bank==2'd1),.enb(portb_enable),.wea(host_we),.web(line_access_ok&&line_write?line_wstrb[7:4]:((compute_access_ok&&compute_bank==2'd1)?compute_we:4'b0)),.addra(host_row),.addrb(cnm_access_ok ? cnm_row1 : portb_row),.dina(host_wdata),.dinb(line_access_ok?line_wdata[63:32]:compute_wdata),.douta(x1a),.doutb(x1b),.rsta(1'b0),.rstb(1'b0),.regcea(1'b1),.regceb(1'b1),.sleep(1'b0),.injectsbiterra(1'b0),.injectdbiterra(1'b0),.injectsbiterrb(1'b0),.injectdbiterrb(1'b0));
    xpm_memory_tdpram #(.ADDR_WIDTH_A(ROW_BITS),.ADDR_WIDTH_B(ROW_BITS),.AUTO_SLEEP_TIME(0),.BYTE_WRITE_WIDTH_A(8),.BYTE_WRITE_WIDTH_B(8),.CLOCKING_MODE("common_clock"),.MEMORY_INIT_FILE("none"),.MEMORY_INIT_PARAM("0"),.MEMORY_OPTIMIZATION("true"),.MEMORY_PRIMITIVE("block"),.MEMORY_SIZE(BANK_MEMORY_BITS),.MESSAGE_CONTROL(0),.READ_DATA_WIDTH_A(32),.READ_DATA_WIDTH_B(32),.READ_LATENCY_A(2),.READ_LATENCY_B(2),.READ_RESET_VALUE_A("0"),.READ_RESET_VALUE_B("0"),.RST_MODE_A("SYNC"),.RST_MODE_B("SYNC"),.SIM_ASSERT_CHK(0),.USE_EMBEDDED_CONSTRAINT(0),.USE_MEM_INIT(0),.WAKEUP_TIME("disable_sleep"),.WRITE_DATA_WIDTH_A(32),.WRITE_DATA_WIDTH_B(32),.WRITE_MODE_A("read_first"),.WRITE_MODE_B("read_first")) xpm_bank2 (.clka(clk),.clkb(clk),.ena(host_access_ok && host_bank==2'd2),.enb(portb_enable),.wea(host_we),.web(line_access_ok&&line_write?line_wstrb[11:8]:((compute_access_ok&&compute_bank==2'd2)?compute_we:4'b0)),.addra(host_row),.addrb(cnm_access_ok ? cnm_row2 : portb_row),.dina(host_wdata),.dinb(line_access_ok?line_wdata[95:64]:compute_wdata),.douta(x2a),.doutb(x2b),.rsta(1'b0),.rstb(1'b0),.regcea(1'b1),.regceb(1'b1),.sleep(1'b0),.injectsbiterra(1'b0),.injectdbiterra(1'b0),.injectsbiterrb(1'b0),.injectdbiterrb(1'b0));
    xpm_memory_tdpram #(.ADDR_WIDTH_A(ROW_BITS),.ADDR_WIDTH_B(ROW_BITS),.AUTO_SLEEP_TIME(0),.BYTE_WRITE_WIDTH_A(8),.BYTE_WRITE_WIDTH_B(8),.CLOCKING_MODE("common_clock"),.MEMORY_INIT_FILE("none"),.MEMORY_INIT_PARAM("0"),.MEMORY_OPTIMIZATION("true"),.MEMORY_PRIMITIVE("block"),.MEMORY_SIZE(BANK_MEMORY_BITS),.MESSAGE_CONTROL(0),.READ_DATA_WIDTH_A(32),.READ_DATA_WIDTH_B(32),.READ_LATENCY_A(2),.READ_LATENCY_B(2),.READ_RESET_VALUE_A("0"),.READ_RESET_VALUE_B("0"),.RST_MODE_A("SYNC"),.RST_MODE_B("SYNC"),.SIM_ASSERT_CHK(0),.USE_EMBEDDED_CONSTRAINT(0),.USE_MEM_INIT(0),.WAKEUP_TIME("disable_sleep"),.WRITE_DATA_WIDTH_A(32),.WRITE_DATA_WIDTH_B(32),.WRITE_MODE_A("read_first"),.WRITE_MODE_B("read_first")) xpm_bank3 (.clka(clk),.clkb(clk),.ena(host_access_ok && host_bank==2'd3),.enb(portb_enable),.wea(host_we),.web(line_access_ok&&line_write?line_wstrb[15:12]:((compute_access_ok&&compute_bank==2'd3)?compute_we:4'b0)),.addra(host_row),.addrb(cnm_access_ok ? cnm_row3 : portb_row),.dina(host_wdata),.dinb(line_access_ok?line_wdata[127:96]:compute_wdata),.douta(x3a),.doutb(x3b),.rsta(1'b0),.rstb(1'b0),.regcea(1'b1),.regceb(1'b1),.sleep(1'b0),.injectsbiterra(1'b0),.injectdbiterra(1'b0),.injectsbiterrb(1'b0),.injectdbiterrb(1'b0));

    always @(posedge clk) begin
        if (host_access_ok && !host_write)
            host_read_bank_d0 <= host_bank;
        host_read_bank_d1 <= host_read_bank_d0;
        if (compute_access_ok && !compute_write)
            compute_read_bank_d0 <= compute_bank;
        compute_read_bank_d1 <= compute_read_bank_d0;
    end

    always @(*) begin
        host_rdata = host_read_bank_d1==2'd0 ? x0a : host_read_bank_d1==2'd1 ? x1a : host_read_bank_d1==2'd2 ? x2a : x3a;
        compute_rdata = compute_read_bank_d1==2'd0 ? x0b : compute_read_bank_d1==2'd1 ? x1b : compute_read_bank_d1==2'd2 ? x2b : x3b;
        host_parity_error = 1'b0;
        compute_parity_error = 1'b0;
        banked_data0=x0b; banked_data1=x1b; banked_data2=x2b; banked_data3=x3b;
        banked_parity_error=4'b0;
        cnm_data0=x0b; cnm_data1=x1b; cnm_data2=x2b; cnm_data3=x3b;
        cnm_parity_error=4'b0;
        line_rdata={x3b,x2b,x1b,x0b};
        line_parity_error=4'b0;
    end
`else
    // VCS behavioural equivalent of the same registered TDP interface.
    // Behavioural equivalent of the parameterized XPM storage.  No reset is
    // applied to the arrays or read data ports.
    (* ram_style = "block", keep_hierarchy = "yes" *) reg [31:0] bank0 [0:WORDS_PER_BANK-1];
    (* ram_style = "block", keep_hierarchy = "yes" *) reg [31:0] bank1 [0:WORDS_PER_BANK-1];
    (* ram_style = "block", keep_hierarchy = "yes" *) reg [31:0] bank2 [0:WORDS_PER_BANK-1];
    (* ram_style = "block", keep_hierarchy = "yes" *) reg [31:0] bank3 [0:WORDS_PER_BANK-1];
    reg bank0_parity [0:WORDS_PER_BANK-1];
    reg bank1_parity [0:WORDS_PER_BANK-1];
    reg bank2_parity [0:WORDS_PER_BANK-1];
    reg bank3_parity [0:WORDS_PER_BANK-1];
    reg [31:0] host_rdata_pipe, compute_rdata_pipe;
    reg host_parity_pipe, compute_parity_pipe;
    reg [31:0] banked_data0_pipe, banked_data1_pipe;
    reg [31:0] banked_data2_pipe, banked_data3_pipe;
    reg [3:0] banked_parity_pipe, cnm_parity_pipe;
    reg [31:0] cnm_data0_pipe, cnm_data1_pipe, cnm_data2_pipe, cnm_data3_pipe;

    function [31:0] merge_wstrb;
        input [31:0] old_data;
        input [31:0] new_data;
        input [3:0] wstrb;
        begin
            merge_wstrb = old_data;
            if (wstrb[0]) merge_wstrb[7:0] = new_data[7:0];
            if (wstrb[1]) merge_wstrb[15:8] = new_data[15:8];
            if (wstrb[2]) merge_wstrb[23:16] = new_data[23:16];
            if (wstrb[3]) merge_wstrb[31:24] = new_data[31:24];
        end
    endfunction

    always @(posedge clk) begin
        host_rdata <= host_rdata_pipe;
        host_parity_error <= host_parity_pipe;
        compute_rdata <= compute_rdata_pipe;
        compute_parity_error <= compute_parity_pipe;
        banked_data0 <= banked_data0_pipe; banked_data1 <= banked_data1_pipe;
        banked_data2 <= banked_data2_pipe; banked_data3 <= banked_data3_pipe;
        banked_parity_error <= banked_parity_pipe;
        cnm_data0 <= cnm_data0_pipe; cnm_data1 <= cnm_data1_pipe;
        cnm_data2 <= cnm_data2_pipe; cnm_data3 <= cnm_data3_pipe;
        cnm_parity_error <= cnm_parity_pipe;
        // Port A: host/debug.  Registered read data is visible two cycles after
        // host_valid; writes are byte-enabled and preserve parity.
        if (host_access_ok) begin
            case (host_bank)
                2'd0: begin
                    host_rdata_pipe <= bank0[host_row];
                    host_parity_pipe <= (^bank0[host_row]) ^ bank0_parity[host_row];
                    if (host_write) begin bank0[host_row] <= merge_wstrb(bank0[host_row], host_wdata, host_wstrb); bank0_parity[host_row] <= ^merge_wstrb(bank0[host_row], host_wdata, host_wstrb); end
                end
                2'd1: begin
                    host_rdata_pipe <= bank1[host_row];
                    host_parity_pipe <= (^bank1[host_row]) ^ bank1_parity[host_row];
                    if (host_write) begin bank1[host_row] <= merge_wstrb(bank1[host_row], host_wdata, host_wstrb); bank1_parity[host_row] <= ^merge_wstrb(bank1[host_row], host_wdata, host_wstrb); end
                end
                2'd2: begin
                    host_rdata_pipe <= bank2[host_row];
                    host_parity_pipe <= (^bank2[host_row]) ^ bank2_parity[host_row];
                    if (host_write) begin bank2[host_row] <= merge_wstrb(bank2[host_row], host_wdata, host_wstrb); bank2_parity[host_row] <= ^merge_wstrb(bank2[host_row], host_wdata, host_wstrb); end
                end
                default: begin
                    host_rdata_pipe <= bank3[host_row];
                    host_parity_pipe <= (^bank3[host_row]) ^ bank3_parity[host_row];
                    if (host_write) begin bank3[host_row] <= merge_wstrb(bank3[host_row], host_wdata, host_wstrb); bank3_parity[host_row] <= ^merge_wstrb(bank3[host_row], host_wdata, host_wstrb); end
                end
            endcase
        end

        // Port B: scheduler.  A scalar/DMA/descriptor request addresses one
        // bank; a banked request addresses all banks at one row in parallel.
        if (line_access_ok) begin
            line_rdata <= {bank3[line_row],bank2[line_row],
                           bank1[line_row],bank0[line_row]};
            line_parity_error[0] <= (^bank0[line_row]) ^ bank0_parity[line_row];
            line_parity_error[1] <= (^bank1[line_row]) ^ bank1_parity[line_row];
            line_parity_error[2] <= (^bank2[line_row]) ^ bank2_parity[line_row];
            line_parity_error[3] <= (^bank3[line_row]) ^ bank3_parity[line_row];
            if (line_write) begin
                bank0[line_row] <= merge_wstrb(bank0[line_row],line_wdata[31:0],line_wstrb[3:0]);
                bank1[line_row] <= merge_wstrb(bank1[line_row],line_wdata[63:32],line_wstrb[7:4]);
                bank2[line_row] <= merge_wstrb(bank2[line_row],line_wdata[95:64],line_wstrb[11:8]);
                bank3[line_row] <= merge_wstrb(bank3[line_row],line_wdata[127:96],line_wstrb[15:12]);
                bank0_parity[line_row] <= ^merge_wstrb(bank0[line_row],line_wdata[31:0],line_wstrb[3:0]);
                bank1_parity[line_row] <= ^merge_wstrb(bank1[line_row],line_wdata[63:32],line_wstrb[7:4]);
                bank2_parity[line_row] <= ^merge_wstrb(bank2[line_row],line_wdata[95:64],line_wstrb[11:8]);
                bank3_parity[line_row] <= ^merge_wstrb(bank3[line_row],line_wdata[127:96],line_wstrb[15:12]);
            end
        end else if (cnm_access_ok) begin
            // Each physical bank receives its own row address.  This is the
            // architectural boundary that makes the four Local Controllers
            // genuinely independent rather than a central row broadcast.
            if (cnm_lane_access0) begin cnm_data0_pipe <= bank0[cnm_row0]; cnm_parity_pipe[0] <= (^bank0[cnm_row0]) ^ bank0_parity[cnm_row0]; end
            if (cnm_lane_access1) begin cnm_data1_pipe <= bank1[cnm_row1]; cnm_parity_pipe[1] <= (^bank1[cnm_row1]) ^ bank1_parity[cnm_row1]; end
            if (cnm_lane_access2) begin cnm_data2_pipe <= bank2[cnm_row2]; cnm_parity_pipe[2] <= (^bank2[cnm_row2]) ^ bank2_parity[cnm_row2]; end
            if (cnm_lane_access3) begin cnm_data3_pipe <= bank3[cnm_row3]; cnm_parity_pipe[3] <= (^bank3[cnm_row3]) ^ bank3_parity[cnm_row3]; end
        end else if (banked_access_ok) begin
            banked_data0_pipe <= bank0[banked_row]; banked_data1_pipe <= bank1[banked_row];
            banked_data2_pipe <= bank2[banked_row]; banked_data3_pipe <= bank3[banked_row];
            banked_parity_pipe[0] <= (^bank0[banked_row]) ^ bank0_parity[banked_row];
            banked_parity_pipe[1] <= (^bank1[banked_row]) ^ bank1_parity[banked_row];
            banked_parity_pipe[2] <= (^bank2[banked_row]) ^ bank2_parity[banked_row];
            banked_parity_pipe[3] <= (^bank3[banked_row]) ^ bank3_parity[banked_row];
        end else if (compute_access_ok) begin
            case (compute_bank)
                2'd0: begin
                    compute_rdata_pipe <= bank0[compute_row]; compute_parity_pipe <= (^bank0[compute_row]) ^ bank0_parity[compute_row];
                    if (compute_write) begin bank0[compute_row] <= compute_wdata; bank0_parity[compute_row] <= ^compute_wdata; end
                end
                2'd1: begin
                    compute_rdata_pipe <= bank1[compute_row]; compute_parity_pipe <= (^bank1[compute_row]) ^ bank1_parity[compute_row];
                    if (compute_write) begin bank1[compute_row] <= compute_wdata; bank1_parity[compute_row] <= ^compute_wdata; end
                end
                2'd2: begin
                    compute_rdata_pipe <= bank2[compute_row]; compute_parity_pipe <= (^bank2[compute_row]) ^ bank2_parity[compute_row];
                    if (compute_write) begin bank2[compute_row] <= compute_wdata; bank2_parity[compute_row] <= ^compute_wdata; end
                end
                default: begin
                    compute_rdata_pipe <= bank3[compute_row]; compute_parity_pipe <= (^bank3[compute_row]) ^ bank3_parity[compute_row];
                    if (compute_write) begin bank3[compute_row] <= compute_wdata; bank3_parity[compute_row] <= ^compute_wdata; end
                end
            endcase
        end
    end
`endif
endmodule
