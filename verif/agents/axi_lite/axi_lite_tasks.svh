task axi_idle;
    begin
        s_axi_awaddr  <= 32'd0;
        s_axi_awvalid <= 1'b0;
        s_axi_wdata   <= 32'd0;
        s_axi_wstrb   <= 4'hf;
        s_axi_wvalid  <= 1'b0;
        s_axi_bready  <= 1'b1;
        s_axi_araddr  <= 32'd0;
        s_axi_arvalid <= 1'b0;
        s_axi_rready  <= 1'b1;
    end
endtask

// Match the Zynq PS/AXI Interconnect behavior: BREADY is asserted before the
// address and data handshakes and remains asserted throughout the transfer.
// Monitor BVALID in parallel so a legal single-cycle response cannot be missed.
task axi_write_bready_preasserted;
    input [31:0] addr;
    input [31:0] data;
    integer response_wait_cycles;
    reg response_seen;
    begin
        response_seen = 1'b0;
        s_axi_bready <= 1'b1;
        fork
            begin
                @(negedge aclk);
                s_axi_awaddr  <= addr;
                s_axi_awvalid <= 1'b1;
                while (!s_axi_awready)
                    @(negedge aclk);
                @(negedge aclk);
                s_axi_awvalid <= 1'b0;
            end
            begin
                repeat (2) @(negedge aclk);
                s_axi_wdata  <= data;
                s_axi_wstrb  <= 4'hf;
                s_axi_wvalid <= 1'b1;
                while (!s_axi_wready)
                    @(negedge aclk);
                @(negedge aclk);
                s_axi_wvalid <= 1'b0;
            end
            begin
                response_wait_cycles = 0;
                while (!response_seen && (response_wait_cycles < 100)) begin
                    @(posedge aclk);
                    if (s_axi_bvalid && s_axi_bready) begin
                        response_seen = 1'b1;
                        if (s_axi_bresp != 2'b00) begin
                            $display("%0t ERROR: preasserted-BREADY write addr=%08h bresp=%0h",
                                     $time, addr, s_axi_bresp);
                            errors = errors + 1;
                        end
                    end
                    response_wait_cycles = response_wait_cycles + 1;
                end
            end
        join
        if (!response_seen) begin
            $display("%0t ERROR: preasserted-BREADY write timeout addr=%08h", $time, addr);
            errors = errors + 1;
        end
    end
endtask

task axi_write;
    input [31:0] addr;
    input [31:0] data;
    begin
        axi_write_delayed(addr, data, 0, 0, 0);
    end
endtask

task axi_write_delayed;
    input [31:0] addr;
    input [31:0] data;
    input integer aw_delay;
    input integer w_delay;
    input integer bready_delay;
    integer aw_wait_cycles;
    integer w_wait_cycles;
    integer b_wait_cycles;
    // Hold BREADY low before launching AW/W.  Otherwise a zero-latency
    // response can be consumed while the fork is still retiring its address
    // and data threads, leaving the task waiting forever for a BVALID pulse
    // that has already completed.
    s_axi_bready <= 1'b0;
    fork
        begin
            // Always launch on a falling edge so VALID spans at least one
            // rising edge even when the caller entered this task at posedge.
            repeat (aw_delay + 1) @(negedge aclk);
            s_axi_awaddr  <= addr;
            s_axi_awvalid <= 1'b1;
            aw_wait_cycles = 0;
            while (!s_axi_awready && (aw_wait_cycles < 100)) begin
                @(negedge aclk);
                aw_wait_cycles = aw_wait_cycles + 1;
            end
            if (!s_axi_awready) begin
                $display("%0t ERROR: AXI write AW timeout addr=%08h", $time, addr);
                errors = errors + 1;
            end
            @(negedge aclk);
            s_axi_awvalid <= 1'b0;
        end
        begin
            repeat (w_delay + 1) @(negedge aclk);
            s_axi_wdata   <= data;
            s_axi_wstrb   <= 4'hf;
            s_axi_wvalid  <= 1'b1;
            w_wait_cycles = 0;
            while (!s_axi_wready && (w_wait_cycles < 100)) begin
                @(negedge aclk);
                w_wait_cycles = w_wait_cycles + 1;
            end
            if (!s_axi_wready) begin
                $display("%0t ERROR: AXI write W timeout addr=%08h", $time, addr);
                errors = errors + 1;
            end
            @(negedge aclk);
            s_axi_wvalid <= 1'b0;
        end
    join
    begin
        repeat (bready_delay) @(negedge aclk);
        s_axi_bready <= 1'b1;
        b_wait_cycles = 0;
        while (!s_axi_bvalid && (b_wait_cycles < 100)) begin
            @(negedge aclk);
            b_wait_cycles = b_wait_cycles + 1;
        end
        if (!s_axi_bvalid) begin
            $display("%0t ERROR: AXI write B timeout addr=%08h", $time, addr);
            errors = errors + 1;
        end
        if (s_axi_bresp != 2'b00) begin
            $display("%0t ERROR: AXI write addr=%08h bresp=%0h", $time, addr, s_axi_bresp);
            errors = errors + 1;
        end
        @(negedge aclk);
        s_axi_bready <= 1'b1;
    end
endtask

task axi_read;
    input  [31:0] addr;
    output [31:0] data;
    begin
        axi_read_delayed(addr, data, 0);
    end
endtask

task axi_read_delayed;
    input  [31:0] addr;
    output [31:0] data;
    input integer rready_delay;
    begin
        @(negedge aclk);
        s_axi_araddr  <= addr;
        s_axi_arvalid <= 1'b1;
        while (!s_axi_arready)
            @(negedge aclk);
        @(negedge aclk);
        s_axi_arvalid <= 1'b0;
        s_axi_rready  <= 1'b0;
        repeat (rready_delay) @(negedge aclk);
        s_axi_rready <= 1'b1;
        while (!s_axi_rvalid)
            @(negedge aclk);
        data = s_axi_rdata;
        if (s_axi_rresp != 2'b00) begin
            $display("%0t ERROR: AXI read addr=%08h rresp=%0h", $time, addr, s_axi_rresp);
            errors = errors + 1;
        end
        @(negedge aclk);
        s_axi_rready <= 1'b1;
    end
endtask

task expect_slverr_write;
    input [31:0] addr;
    input [31:0] data;
    begin
        @(negedge aclk);
        s_axi_awaddr  <= addr;
        s_axi_awvalid <= 1'b1;
        s_axi_wdata   <= data;
        s_axi_wstrb   <= 4'hf;
        s_axi_wvalid  <= 1'b1;
        while (!(s_axi_awready && s_axi_wready))
            @(negedge aclk);
        @(negedge aclk);
        s_axi_awvalid <= 1'b0;
        s_axi_wvalid  <= 1'b0;
        while (!s_axi_bvalid)
            @(negedge aclk);
        if (s_axi_bresp != 2'b10) begin
            $display("%0t ERROR: expected SLVERR write addr=%08h bresp=%0h", $time, addr, s_axi_bresp);
            errors = errors + 1;
        end else begin
            $display("%0t PASS: SLVERR write addr=%08h", $time, addr);
        end
        @(negedge aclk);
    end
endtask

task expect_slverr_read;
    input [31:0] addr;
    begin
        @(negedge aclk);
        s_axi_araddr  <= addr;
        s_axi_arvalid <= 1'b1;
        s_axi_rready  <= 1'b1;
        while (!s_axi_arready)
            @(negedge aclk);
        @(negedge aclk);
        s_axi_arvalid <= 1'b0;
        while (!s_axi_rvalid)
            @(negedge aclk);
        if (s_axi_rresp != 2'b10) begin
            $display("%0t ERROR: expected SLVERR read addr=%08h rresp=%0h", $time, addr, s_axi_rresp);
            errors = errors + 1;
        end else begin
            $display("%0t PASS: SLVERR read addr=%08h", $time, addr);
        end
        @(negedge aclk);
    end
endtask

task expect_read;
    input [31:0] addr;
    input [31:0] expected;
    input [511:0] name;
    begin
        axi_read(addr, rd);
        if (rd !== expected) begin
            $display("%0t ERROR: %0s expected=%0d/%08h actual=%0d/%08h",
                     $time, name, expected, expected, rd, rd);
            errors = errors + 1;
        end else begin
            $display("%0t PASS: %0s = %0d/%08h", $time, name, rd, rd);
        end
    end
endtask
