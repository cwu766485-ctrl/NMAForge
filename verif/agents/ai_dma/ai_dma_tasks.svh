task wait_dma_done;
    begin
        integer i;
        integer found;
        found = 0;
        for (i = 0; i < 200; i = i + 1) begin
            if (!found) begin
                axi_read(REG_DMA_STATUS, rd);
                if (rd[1])
                    found = 1;
            end
        end
        if (!found) begin
            $display("%0t ERROR: timeout waiting DMA done", $time);
            errors = errors + 1;
        end
        if (rd[2]) begin
            axi_read(REG_DMA_ERROR_CODE, rd);
            $display("%0t ERROR: dma error_code=%0d", $time, rd);
            errors = errors + 1;
        end
    end
endtask

task expect_dma_done;
    input expect_error;
    input [3:0] expected_error_code;
    begin
        integer i;
        integer found;
        reg [31:0] status;
        found = 0;
        status = 32'd0;
        for (i = 0; i < 400; i = i + 1) begin
            if (!found) begin
                axi_read(REG_DMA_STATUS, status);
                if (status[1])
                    found = 1;
            end
        end
        if (!found) begin
            $display("%0t ERROR: timeout waiting DMA done", $time);
            errors = errors + 1;
        end else if (status[2] !== expect_error) begin
            $display("%0t ERROR: DMA error bit expected=%0d actual=%0d",
                     $time, expect_error, status[2]);
            errors = errors + 1;
        end
        if (expect_error) begin
            axi_read(REG_DMA_ERROR_CODE, rd);
            if (rd[3:0] !== expected_error_code) begin
                $display("%0t ERROR: DMA error_code expected=%0d actual=%0d",
                         $time, expected_error_code, rd[3:0]);
                errors = errors + 1;
            end else begin
                $display("%0t PASS: DMA expected error_code = %0d/%08h", $time, rd[3:0], rd);
            end
        end
        clear_dma_done();
    end
endtask

task clear_dma_done;
    begin
        axi_write(REG_DMA_STATUS, 32'd2);
    end
endtask

task dma_load;
    input [31:0] ext_addr;
    input [31:0] spad_addr;
    input [15:0] words;
    begin
        axi_write(REG_DMA_EXT_ADDR, ext_addr);
        axi_write(REG_DMA_SPAD_ADDR, spad_addr);
        axi_write(REG_DMA_LENGTH, {16'd0, words});
        axi_write(REG_DMA_CTRL, 32'h0000_0001);
        wait_dma_done();
        clear_dma_done();
    end
endtask

task dma_store;
    input [31:0] ext_addr;
    input [31:0] spad_addr;
    input [15:0] words;
    begin
        axi_write(REG_DMA_EXT_ADDR, ext_addr);
        axi_write(REG_DMA_SPAD_ADDR, spad_addr);
        axi_write(REG_DMA_LENGTH, {16'd0, words});
        axi_write(REG_DMA_CTRL, 32'h0000_0003);
        wait_dma_done();
        clear_dma_done();
    end
endtask

task dma_load_expect_error;
    input [31:0] ext_addr;
    input [31:0] spad_addr;
    input [15:0] words;
    input [3:0]  expected_error_code;
    begin
        allow_m_axi_error <= 1'b1;
        axi_write(REG_DMA_EXT_ADDR, ext_addr);
        axi_write(REG_DMA_SPAD_ADDR, spad_addr);
        axi_write(REG_DMA_LENGTH, {16'd0, words});
        axi_write(REG_DMA_CTRL, 32'h0000_0001);
        expect_dma_done(1'b1, expected_error_code);
        allow_m_axi_error <= 1'b0;
    end
endtask

task dma_store_expect_error;
    input [31:0] ext_addr;
    input [31:0] spad_addr;
    input [15:0] words;
    input [3:0]  expected_error_code;
    begin
        allow_m_axi_error <= 1'b1;
        axi_write(REG_DMA_EXT_ADDR, ext_addr);
        axi_write(REG_DMA_SPAD_ADDR, spad_addr);
        axi_write(REG_DMA_LENGTH, {16'd0, words});
        axi_write(REG_DMA_CTRL, 32'h0000_0003);
        expect_dma_done(1'b1, expected_error_code);
        allow_m_axi_error <= 1'b0;
    end
endtask

