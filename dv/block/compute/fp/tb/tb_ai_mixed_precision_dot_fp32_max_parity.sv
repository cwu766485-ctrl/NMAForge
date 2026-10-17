`timescale 1ns/1ps

// Maximum-length final-A/final-B parity cutoffs and clean recovery test for the shared
// BF16/FP16 dot core. The SPAD model returns accepted reads in order after a
// two-cycle registered latency and enforces the core's two-read limit.
module tb_ai_mixed_precision_dot_fp32_max_parity;
    localparam [31:0] SRC0_BASE = 32'h1000_0000;
    localparam [31:0] SRC1_BASE = 32'h2000_0000;
    localparam [31:0] DST_BASE  = 32'h3000_0000;
    localparam [15:0] MAX_LENGTH = 16'hffff;
    localparam integer MAX_READS = 65536;
    localparam integer FINAL_A_ACCEPT_INDEX = 65534;
    localparam integer FINAL_B_ACCEPT_INDEX = 65535;
    localparam integer WATCHDOG_CYCLES = 500000;

    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg resetn = 1'b0;
    reg start = 1'b0;
    reg format_fp16 = 1'b0;
    reg abort = 1'b0;
    reg [31:0] src0_base = SRC0_BASE;
    reg [31:0] src1_base = SRC1_BASE;
    reg [31:0] dst_base = DST_BASE;
    reg [15:0] length = 16'd0;
    reg [31:0] watchdog_limit = 32'd0;
    wire spad_valid, spad_write;
    wire [31:0] spad_addr, spad_wdata;
    reg spad_ready = 1'b0;
    reg spad_rsp_valid = 1'b0;
    reg [31:0] spad_rdata = 32'd0;
    reg spad_parity_error = 1'b0;
    reg spad_protection_error = 1'b0;
    wire busy, done, error;
    wire [3:0] error_code;
    wire [31:0] result, cycle_count, element_count;

    ai_mixed_precision_dot_fp32_core dut (.*);

    // Small in-order queue; its occupancy must never exceed two. Queue
    // entries are enqueued on accepted reads and retired on response handshakes.
    integer q_head = 0, q_tail = 0, q_count = 0;
    reg [31:0] q_data [0:3];
    integer q_due [0:3];
    reg q_parity [0:3];
    integer sim_cycle = 0;
    integer accepted_reads = 0, returned_reads = 0, writes = 0;
    integer peak_model_outstanding = 0;
    integer parity_responses = 0, done_pulses = 0, error_done_pulses = 0;
    integer task_cycles = 0;
    integer expected_parity_index = -1;
    reg clean_data = 1'b0;

    function [31:0] response_data(input [31:0] addr);
        reg [15:0] one_bits;
        begin
            if (!clean_data)
                response_data = 32'd0;
            else begin
                one_bits = format_fp16 ? 16'h3c00 : 16'h3f80;
                if ((addr == SRC0_BASE) || (addr == SRC1_BASE))
                    response_data = {16'd0, one_bits};
                else
                    response_data = 32'd0;
            end
        end
    endfunction

    // Registered response drive: the head is presented only after its due
    // cycle and remains stable through the sampling active edge.
    always @(negedge clk) begin
        if (!resetn) begin
            spad_ready = 1'b0;
            spad_rsp_valid = 1'b0;
            spad_rdata = 32'd0;
            spad_parity_error = 1'b0;
            spad_protection_error = 1'b0;
        end else begin
            spad_ready = 1'b1;
            spad_rsp_valid = (q_count != 0) && (q_due[q_head] <= sim_cycle);
            if (spad_rsp_valid) begin
                spad_rdata = q_data[q_head];
                spad_parity_error = q_parity[q_head];
            end else begin
                spad_rdata = 32'd0;
                spad_parity_error = 1'b0;
            end
            spad_protection_error = 1'b0;
        end
    end

    always @(posedge clk) begin : model_and_monitor
        integer outstanding_before;
        integer word_index;
        reg read_accept;
        reg response_accept;
        if (!resetn) begin
            sim_cycle = 0;
            q_head = 0;
            q_tail = 0;
            q_count = 0;
        end else begin
            sim_cycle = sim_cycle + 1;
            if (done) begin
                done_pulses = done_pulses + 1;
                if (error) error_done_pulses = error_done_pulses + 1;
            end

            read_accept = spad_valid && spad_ready && !spad_write;
            response_accept = spad_rsp_valid;
            outstanding_before = q_count;

            if (response_accept) begin
                if (q_count == 0)
                    $fatal(1, "response with no accepted read outstanding");
                if (q_parity[q_head] &&
                    (returned_reads != expected_parity_index))
                    $fatal(1, "parity response sequence=%0d expected parity response index=%0d",
                           returned_reads, expected_parity_index);
                returned_reads = returned_reads + 1;
                if (q_parity[q_head]) parity_responses = parity_responses + 1;
                q_head = (q_head == 3) ? 0 : q_head + 1;
                q_count = q_count - 1;
            end

            if (spad_valid && spad_ready && spad_write) begin
                writes = writes + 1;
                if (spad_addr !== DST_BASE)
                    $fatal(1, "unexpected destination write address %h", spad_addr);
                if (clean_data && (spad_wdata !== 32'h3f80_0000))
                    $fatal(1, "clean recovery write data=%h expected 3f800000",
                           spad_wdata);
            end else if (read_accept) begin
                if (accepted_reads >= MAX_READS)
                    $fatal(1, "read count exceeded max-length packed-word total");
                word_index = accepted_reads / 2;
                if ((accepted_reads & 1) == 0) begin
                    if (spad_addr !== (SRC0_BASE + (word_index * 4)))
                        $fatal(1, "A request order/address mismatch accepted=%0d addr=%h",
                               accepted_reads, spad_addr);
                end else if (spad_addr !== (SRC1_BASE + (word_index * 4))) begin
                    $fatal(1, "B request order/address mismatch accepted=%0d addr=%h",
                           accepted_reads, spad_addr);
                end

                q_data[q_tail] = response_data(spad_addr);
                q_due[q_tail] = sim_cycle + 1;
                q_parity[q_tail] = (accepted_reads == expected_parity_index);
                q_tail = (q_tail == 3) ? 0 : q_tail + 1;
                q_count = q_count + 1;
                accepted_reads = accepted_reads + 1;
            end

            if (q_count > 2)
                $fatal(1, "SPAD model outstanding reads exceeded two: %0d", q_count);
            if (dut.outstanding_reads_r > 2)
                $fatal(1, "DUT outstanding reads exceeded two: %0d",
                       dut.outstanding_reads_r);
            if (q_count > peak_model_outstanding)
                peak_model_outstanding = q_count;
            // The model's count must track read handshakes exactly, including
            // a simultaneous return/new request cycle.
            if ((outstanding_before + (read_accept ? 1 : 0) -
                 (response_accept ? 1 : 0)) != q_count)
                $fatal(1, "SPAD outstanding accounting mismatch");
        end
    end

    task reset_case;
        begin
            @(negedge clk);
            resetn = 1'b0;
            start = 1'b0;
            abort = 1'b0;
            repeat (2) @(negedge clk);
            accepted_reads = 0;
            returned_reads = 0;
            writes = 0;
            peak_model_outstanding = 0;
            parity_responses = 0;
            done_pulses = 0;
            error_done_pulses = 0;
            task_cycles = 0;
            expected_parity_index = -1;
            clean_data = 1'b0;
            resetn = 1'b1;
            @(negedge clk);
        end
    endtask

    task launch(input [15:0] task_length, input reg fp16_mode);
        begin
            length = task_length;
            format_fp16 = fp16_mode;
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
        end
    endtask

    task wait_done;
        begin
            task_cycles = 0;
            while (!done && task_cycles < WATCHDOG_CYCLES) begin
                @(negedge clk);
                task_cycles = task_cycles + 1;
            end
            if (!done)
                $fatal(1, "watchdog: no completion after %0d cycles", WATCHDOG_CYCLES);
            // Allow the pulse monitor to sample done before checking totals.
            @(posedge clk);
            @(negedge clk);
        end
    endtask

    task run_parity_case(input reg fp16_mode, input reg final_b_word);
        integer injected_index;
        begin
            reset_case();
            injected_index = final_b_word ? FINAL_B_ACCEPT_INDEX :
                                            FINAL_A_ACCEPT_INDEX;
            expected_parity_index = injected_index;
            launch(MAX_LENGTH, fp16_mode);
            wait_done();
            if (!error || error_code !== 4'd5)
                $fatal(1, "format=%0d final_%s expected ERR_PARITY=5, got error=%0d code=%0d",
                       fp16_mode, final_b_word ? "B" : "A", error, error_code);
            if (error_done_pulses != 1 || done_pulses != 1)
                $fatal(1, "format=%0d final_%s completion/error not exactly once done=%0d error=%0d",
                       fp16_mode, final_b_word ? "B" : "A", done_pulses,
                       error_done_pulses);
            if (parity_responses != 1)
                $fatal(1, "format=%0d final_%s parity responses=%0d expected exactly one",
                       fp16_mode, final_b_word ? "B" : "A", parity_responses);
            if (element_count !== 32'd65534)
                $fatal(1, "format=%0d final_%s prefix element_count=%0d expected 65534",
                       fp16_mode, final_b_word ? "B" : "A", element_count);
            if (accepted_reads != MAX_READS ||
                returned_reads != MAX_READS ||
                q_count != 0 || q_head != q_tail)
                $fatal(1, "format=%0d final_%s reads not fully drained accepted=%0d returned=%0d q=%0d",
                       fp16_mode, final_b_word ? "B" : "A", accepted_reads,
                       returned_reads, q_count);
            if (peak_model_outstanding != 2)
                $fatal(1, "format=%0d final_%s failed to exercise two outstanding reads, peak=%0d",
                       fp16_mode, final_b_word ? "B" : "A",
                       peak_model_outstanding);
            if (writes != 0)
                $fatal(1, "format=%0d final_%s parity-failed task wrote destination %0d times",
                       fp16_mode, final_b_word ? "B" : "A", writes);
            $display("MAX_PARITY_PASS format=%s final_word=%s cycles=%0d accepted=%0d drained=%0d prefix=%0d peak_outstanding=%0d",
                     fp16_mode ? "FP16" : "BF16",
                     final_b_word ? "B" : "A", cycle_count, accepted_reads,
                     returned_reads, element_count, peak_model_outstanding);

            // No reset between tasks: prove lifecycle recovery and exact 1.0
            // writeback on the same core after parity has fully drained.
            expected_parity_index = -1;
            clean_data = 1'b1;
            accepted_reads = 0;
            returned_reads = 0;
            writes = 0;
            peak_model_outstanding = 0;
            launch(16'd1, fp16_mode);
            wait_done();
            if (error || error_code !== 4'd0 || result !== 32'h3f80_0000)
                $fatal(1, "format=%0d final_%s clean recovery status/result error=%0d code=%0d result=%h",
                       fp16_mode, final_b_word ? "B" : "A", error, error_code, result);
            if (element_count !== 32'd1 || accepted_reads != 2 ||
                returned_reads != 2 || q_count != 0 || writes != 1)
                $fatal(1, "format=%0d final_%s clean recovery accounting elements=%0d reads=%0d/%0d q=%0d writes=%0d",
                       fp16_mode, final_b_word ? "B" : "A", element_count,
                       accepted_reads, returned_reads, q_count, writes);
            if (done_pulses != 2 || error_done_pulses != 1 || parity_responses != 1)
                $fatal(1, "format=%0d final_%s recovery pulse/error count done=%0d errdone=%0d parity=%0d",
                       fp16_mode, final_b_word ? "B" : "A", done_pulses,
                       error_done_pulses, parity_responses);
            $display("MAX_PARITY_RECOVERY_PASS format=%s final_word=%s result=%08h reads=%0d writes=%0d",
                     fp16_mode ? "FP16" : "BF16",
                     final_b_word ? "B" : "A", result, accepted_reads, writes);
        end
    endtask

    initial begin
        run_parity_case(1'b0, 1'b0);
        run_parity_case(1'b0, 1'b1);
        run_parity_case(1'b1, 1'b0);
        run_parity_case(1'b1, 1'b1);
        $display("PASS: maximum-length mixed-precision dot parity stress");
        $finish;
    end

    initial begin
        #(WATCHDOG_CYCLES * 10 * 2);
        $fatal(1, "global simulation watchdog expired");
    end
endmodule
