`timescale 1ns/1ps
`ifndef DEPTH
`define DEPTH 8192
`endif
`ifndef BANKS
`define BANKS 4
`endif
`ifndef ROW_WIDTH
`define ROW_WIDTH $clog2(`DEPTH)
`endif
`ifndef CAPACITY
`define CAPACITY (16*`DEPTH)
`endif
module tb_spad_geometry;
    ai_scratchpad #(.BANKS(`BANKS), .WORDS_PER_BANK(`DEPTH),
                   .ROW_BITS(`ROW_WIDTH)) ram();
    ai_accel_memory_fabric #(.WORDS_PER_BANK(`DEPTH),
        .ROW_BITS(`ROW_WIDTH), .SPAD_BYTES(`CAPACITY)) fabric();
    initial begin
        #1;
        $display("SPAD_GEOMETRY_VALID depth=%0d banks=%0d row=%0d capacity=%0d",
            `DEPTH, `BANKS, `ROW_WIDTH, `CAPACITY);
        $finish;
    end
endmodule
