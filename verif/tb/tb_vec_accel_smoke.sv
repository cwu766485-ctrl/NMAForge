`timescale 1ns / 1ps

module tb_vec_accel_smoke;

    localparam REG_BASE        = 32'h0001_0000;
    localparam REG_CTRL        = REG_BASE + 32'h00;
    localparam REG_STATUS      = REG_BASE + 32'h04;
    localparam REG_SRC0_BASE   = REG_BASE + 32'h08;
    localparam REG_SRC1_BASE   = REG_BASE + 32'h0c;
    localparam REG_DST_BASE    = REG_BASE + 32'h10;
    localparam REG_LENGTH      = REG_BASE + 32'h14;
    localparam REG_SCALE_SHIFT = REG_BASE + 32'h18;

    localparam OP_VADD = 3'd0;
    localparam OP_VSUB = 3'd1;
    localparam OP_VMAC = 3'd2;
    localparam OP_L1DIST = 3'd3;

    reg         hclk;
    reg         sram_clk;
    reg         hresetn;
    reg         hsel;
    reg         hwrite;
    reg         hready;
    reg  [2:0]  hsize;
    reg  [2:0]  hburst;
    reg  [1:0]  htrans;
    reg  [31:0] hwdata;
    reg  [31:0] haddr;

    wire        hready_resp;
    wire [1:0]  hresp;
    wire [31:0] hrdata;
    wire        irq;

    reg [31:0] in0;
    reg [31:0] in1;
    reg [31:0] rd0;
    reg [31:0] rd1;
    reg [31:0] status;

    vec_accel_top #(
        .SRAM_WAIT_CYCLES(1)
    ) dut (
        .hclk        (hclk),
        .sram_clk    (sram_clk),
        .hresetn     (hresetn),
        .hsel        (hsel),
        .hwrite      (hwrite),
        .hready      (hready),
        .hsize       (hsize),
        .hburst      (hburst),
        .htrans      (htrans),
        .hwdata      (hwdata),
        .haddr       (haddr),
        .dft_en      (1'b0),
        .bist_en     (1'b0),
        .hready_resp (hready_resp),
        .hresp       (hresp),
        .hrdata      (hrdata),
        .irq         (irq),
        .bist_done   (),
        .bist_fail   ()
    );

    initial begin
        hclk = 1'b0;
        forever #5 hclk = ~hclk;
    end

    initial begin
        sram_clk = 1'b0;
        forever #5 sram_clk = ~sram_clk;
    end

    task ahb_idle;
        begin
            hsel   <= 1'b0;
            hwrite <= 1'b0;
            hready <= 1'b1;
            hsize  <= 3'b010;
            hburst <= 3'b000;
            htrans <= 2'b00;
            haddr  <= 32'd0;
            hwdata <= 32'd0;
        end
    endtask

    task ahb_write_word;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(negedge hclk);
            hsel   <= 1'b1;
            hwrite <= 1'b1;
            hready <= 1'b1;
            hsize  <= 3'b010;
            hburst <= 3'b000;
            htrans <= 2'b10;
            haddr  <= addr;
            hwdata <= data;

            @(negedge hclk);
            hsel   <= 1'b0;
            htrans <= 2'b00;
            haddr  <= 32'd0;
            hwdata <= data;

            if (addr[16] == 1'b0) begin
                while (hready_resp !== 1'b0)
                    @(negedge hclk);
                while (hready_resp !== 1'b1)
                    @(negedge hclk);
            end else begin
                repeat (2) @(negedge hclk);
            end
            if (hresp != 2'b00)
                $display("%0t ERROR: write hresp=%0h addr=%08h", $time, hresp, addr);
        end
    endtask

    task ahb_read_word;
        input  [31:0] addr;
        output [31:0] data;
        begin
            @(negedge hclk);
            hsel   <= 1'b1;
            hwrite <= 1'b0;
            hready <= 1'b1;
            hsize  <= 3'b010;
            hburst <= 3'b000;
            htrans <= 2'b10;
            haddr  <= addr;
            hwdata <= 32'd0;

            @(negedge hclk);
            hsel   <= 1'b0;
            htrans <= 2'b00;
            haddr  <= 32'd0;

            if (addr[16] == 1'b0) begin
                while (hready_resp !== 1'b0)
                    @(negedge hclk);
                while (hready_resp !== 1'b1)
                    @(negedge hclk);
            end else begin
                repeat (2) @(negedge hclk);
            end
            data = hrdata;
            if (hresp != 2'b00)
                $display("%0t ERROR: read hresp=%0h addr=%08h", $time, hresp, addr);
        end
    endtask

    task start_and_wait;
        input [2:0] op_mode;
        begin : wait_done
            integer poll_idx;
            ahb_write_word(REG_CTRL, {27'd0, 1'b0, op_mode, 1'b1});
            status = 32'd0;
            for (poll_idx = 0; poll_idx < 100; poll_idx = poll_idx + 1) begin
                ahb_read_word(REG_STATUS, status);
                if (status[1])
                    disable wait_done;
            end
        end
    endtask

    initial begin
        hresetn = 1'b0;
        ahb_idle();
        repeat (8) @(posedge hclk);
        hresetn = 1'b1;
        repeat (4) @(posedge hclk);

        ahb_write_word(32'h0000_0000, 32'd10);
        ahb_write_word(32'h0000_0004, 32'd20);
        ahb_write_word(32'h0000_0100, 32'd1);
        ahb_write_word(32'h0000_0104, 32'd2);

        ahb_read_word(32'h0000_0000, in0);
        ahb_read_word(32'h0000_0100, in1);
        $display("%0t INFO: input readback src0[0]=%0d src1[0]=%0d", $time, in0, in1);

        ahb_write_word(REG_SRC0_BASE,   32'h0000_0000);
        ahb_write_word(REG_SRC1_BASE,   32'h0000_0100);
        ahb_write_word(REG_DST_BASE,    32'h0000_0200);
        ahb_write_word(REG_LENGTH,      32'd2);
        ahb_write_word(REG_SCALE_SHIFT, 32'd0);
        start_and_wait(OP_VADD);

        ahb_read_word(32'h0000_0200, rd0);
        ahb_read_word(32'h0000_0204, rd1);

        if ((rd0 == 32'd11) && (rd1 == 32'd22)) begin
            $display("%0t PASS: VADD result rd0=%0d rd1=%0d irq=%0b", $time, rd0, rd1, irq);
        end else begin
            $display("%0t FAIL: VADD result rd0=%0d rd1=%0d", $time, rd0, rd1);
        end

        ahb_write_word(REG_DST_BASE, 32'h0000_0300);
        start_and_wait(OP_VSUB);
        ahb_read_word(32'h0000_0300, rd0);
        ahb_read_word(32'h0000_0304, rd1);
        if ((rd0 == 32'd9) && (rd1 == 32'd18))
            $display("%0t PASS: VSUB result rd0=%0d rd1=%0d", $time, rd0, rd1);
        else
            $display("%0t FAIL: VSUB result rd0=%0d rd1=%0d", $time, rd0, rd1);

        ahb_write_word(REG_DST_BASE, 32'h0000_0400);
        start_and_wait(OP_VMAC);
        ahb_read_word(32'h0000_0400, rd0);
        if (rd0 == 32'd50)
            $display("%0t PASS: VMAC result=%0d", $time, rd0);
        else
            $display("%0t FAIL: VMAC result=%0d", $time, rd0);

        ahb_write_word(REG_DST_BASE, 32'h0000_0500);
        start_and_wait(OP_L1DIST);
        ahb_read_word(32'h0000_0500, rd0);
        if (rd0 == 32'd27)
            $display("%0t PASS: L1DIST result=%0d", $time, rd0);
        else
            $display("%0t FAIL: L1DIST result=%0d", $time, rd0);

        $finish;
    end

endmodule
