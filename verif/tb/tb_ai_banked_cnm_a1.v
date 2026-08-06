`timescale 1ns/1ps

// Focused CNM A1/A2 test.  It uses three K groups: each group retires four
// bank-local PE contributions, while the shared reduction is used once only
// when the VDOT output is complete.  The A2 counters also prove that the
// second and third A reads are issued as prefetches.
module tb_ai_banked_cnm_a1;
    reg clk=0, resetn=0, start=0, abort=0;
    reg [7:0] op_mode=8'h20;
    reg [31:0] src0_base=0, src1_base=32'h100, dst_base=32'h200;
    reg [15:0] length=3, m_size=1;
    reg [4:0] scale_shift=0;
    reg [1:0] activation=0;
    reg [31:0] watchdog_limit=0;
    reg [31:0] bank0_data=0, bank1_data=0, bank2_data=0, bank3_data=0;
    reg [3:0] bank_parity_error=0;
    wire banked_read_valid;
    wire [31:0] banked_addr;
    wire spad_valid, spad_write;
    wire [31:0] spad_addr, spad_wdata;
    wire busy, done, error;
    wire [3:0] error_code;
    wire [31:0] result, cycle_count, element_count;
    wire [31:0] local_accumulate_events, global_reduce_events;
    wire [31:0] banked_read_issue_events, prefetch_events;
    wire [31:0] pipeline_compute_events, response_wait_cycles;
    reg banked_rsp_valid=0;
    reg pending_read=0;
    reg [31:0] pending_addr=0;
    integer errors=0;

    always #5 clk=~clk;

    ai_banked_compute_core dut(
        .clk(clk), .resetn(resetn), .start(start), .abort(abort), .op_mode(op_mode),
        .src0_base(src0_base), .src1_base(src1_base), .dst_base(dst_base),
        .length(length), .m_size(m_size), .scale_shift(scale_shift), .activation(activation),
        .watchdog_limit(watchdog_limit),
        .bank0_data(bank0_data), .bank1_data(bank1_data), .bank2_data(bank2_data), .bank3_data(bank3_data),
        .bank_parity_error(bank_parity_error), .banked_read_valid(banked_read_valid),
        .banked_addr(banked_addr), .banked_ready(1'b1), .banked_rsp_valid(banked_rsp_valid),
        .banked_protection_error(1'b0), .spad_valid(spad_valid), .spad_write(spad_write),
        .spad_addr(spad_addr), .spad_wdata(spad_wdata), .spad_ready(1'b1),
        .spad_protection_error(1'b0), .busy(busy), .done(done), .error(error),
        .error_code(error_code), .result(result), .cycle_count(cycle_count),
        .element_count(element_count), .local_accumulate_events(local_accumulate_events),
        .global_reduce_events(global_reduce_events),
        .banked_read_issue_events(banked_read_issue_events), .prefetch_events(prefetch_events),
        .pipeline_compute_events(pipeline_compute_events), .response_wait_cycles(response_wait_cycles)
    );

    // One registered scratchpad response.  A data are all +1.  B groups are
    // +1, +2 and -1, hence the expected 16 + 32 - 16 = 32 result.
    always @(posedge clk) begin
        banked_rsp_valid <= pending_read;
        if (pending_read) begin
            if (pending_addr < 32'h100) begin
                bank0_data<=32'h01010101; bank1_data<=32'h01010101;
                bank2_data<=32'h01010101; bank3_data<=32'h01010101;
            end else begin
                case (pending_addr - 32'h100)
                    0:  begin bank0_data<=32'h01010101; bank1_data<=32'h01010101; bank2_data<=32'h01010101; bank3_data<=32'h01010101; end
                    16: begin bank0_data<=32'h02020202; bank1_data<=32'h02020202; bank2_data<=32'h02020202; bank3_data<=32'h02020202; end
                    default: begin bank0_data<=32'hffffffff; bank1_data<=32'hffffffff; bank2_data<=32'hffffffff; bank3_data<=32'hffffffff; end
                endcase
            end
        end
        pending_read <= banked_read_valid;
        pending_addr <= banked_addr;
    end

    initial begin
        repeat(3) @(posedge clk);
        resetn=1;
        @(posedge clk); start=1;
        @(posedge clk); start=0;
        wait(done);
        @(posedge clk);
        if(error) begin $display("ERROR: CNM core raised error code %0d",error_code); errors=errors+1; end
        if(result!==32'd32) begin $display("ERROR: result expected 32 got %0d",result); errors=errors+1; end
        if(spad_wdata!==32'd32) begin $display("ERROR: write expected 32 got %0d",spad_wdata); errors=errors+1; end
        if(local_accumulate_events!==32'd12) begin $display("ERROR: expected 12 local accumulate events got %0d",local_accumulate_events); errors=errors+1; end
        if(global_reduce_events!==32'd1) begin $display("ERROR: expected one global reduction got %0d",global_reduce_events); errors=errors+1; end
        if(banked_read_issue_events!==32'd6) begin $display("ERROR: expected six A/B reads got %0d",banked_read_issue_events); errors=errors+1; end
        if(prefetch_events!==32'd2) begin $display("ERROR: expected two A prefetches got %0d",prefetch_events); errors=errors+1; end
        if(pipeline_compute_events!==32'd3) begin $display("ERROR: expected three compute retires got %0d",pipeline_compute_events); errors=errors+1; end
        // A1 measured 21 cycles in this exact deterministic harness.  A2
        // must overlap requests/responses enough to improve that baseline.
        if(cycle_count>=32'd21) begin $display("ERROR: A2 expected fewer than 21 baseline cycles got %0d",cycle_count); errors=errors+1; end
        if(element_count!==32'd1) begin $display("ERROR: expected one output got %0d",element_count); errors=errors+1; end
        if(errors!=0) $fatal(1,"CNM A2 test failed: %0d errors",errors);
        $display("PASS: CNM A2 VDOT result=%0d A1_cycles=21 A2_cycles=%0d saved_cycles=%0d local_acc=%0d global_reduce=%0d reads=%0d prefetch=%0d compute=%0d rsp_wait=%0d", result, cycle_count, 32'd21-cycle_count, local_accumulate_events, global_reduce_events, banked_read_issue_events, prefetch_events, pipeline_compute_events, response_wait_cycles);
        $finish;
    end
endmodule
