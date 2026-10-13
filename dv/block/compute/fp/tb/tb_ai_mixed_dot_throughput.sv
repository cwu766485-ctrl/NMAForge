`timescale 1ns/1ps
module tb_ai_mixed_dot_throughput;
    reg clk=0, resetn=0, start=0, format_fp16=0, abort=0;
    always #5 clk=~clk;
    reg [31:0] src0_base=32'h100, src1_base=32'h400, dst_base=32'h800;
    reg [15:0] length=0;
    reg [31:0] watchdog_limit=0;
    wire spad_valid, spad_write;
    wire [31:0] spad_addr, spad_wdata;
    reg spad_ready=1'b1;
    reg spad_rsp_valid=0;
    reg [31:0] spad_rdata=0;
    wire spad_parity_error=1'b0, spad_protection_error=1'b0;
    wire busy, done, error;
    wire [3:0] error_code;
    wire [31:0] result, cycle_count, element_count;

    ai_mixed_precision_dot_fp32_core dut(.*);

    integer reads=0, writes=0;
    integer rsp_count=0, rsp_head=0, rsp_tail=0, model_cycle=0;
    integer rsp_due [0:3];
    reg [31:0] rsp_data [0:3];
    wire response_pending = (rsp_count != 0);
    integer core_cycles=0, compute_cycles=0, admission_stall_cycles=0;
    integer response_wait_cycles=0, write_wait_cycles=0;
    integer seed=20261013, bp_percent=0, rsp_jitter_max=0;
    reg [31:0] rng=32'h9e3779b9;
    reg measuring=0;
    real throughput;

    // Small deterministic LCG. Ready is changed only on falling edges so it
    // remains stable for every DUT sampling edge.
    function [31:0] lcg_next(input [31:0] value);
        begin lcg_next = value * 32'd1664525 + 32'd1013904223; end
    endfunction
    function [31:0] expected_sum(input integer n);
        begin
            case (n)
                1: expected_sum=32'h3f800000;
                2: expected_sum=32'h40000000;
                3: expected_sum=32'h40400000;
                4: expected_sum=32'h40800000;
                16: expected_sum=32'h41800000;
                64: expected_sum=32'h42800000;
                128: expected_sum=32'h43000000;
                256: expected_sum=32'h43800000;
                1024: expected_sum=32'h44800000;
                default: expected_sum=32'bx;
            endcase
        end
    endfunction

    always @(negedge clk) begin
        if (resetn) begin
            rng = lcg_next(rng);
            spad_ready = ((rng % 100) >= bp_percent);
        end
    end

    // Ordered A/B responses. Each accepted read has at least a two-cycle
    // response delay with optional reproducible per-request jitter.
    // Responses are retired in request order even when a later request's due
    // time is earlier. Admission backpressure is independently randomized.
    always @(posedge clk) begin
        if (!resetn) begin
            reads <= 0; writes <= 0;
            rsp_count = 0; rsp_head = 0; rsp_tail = 0; model_cycle = 0;
            spad_rsp_valid <= 0; spad_rdata <= 0;
        end else begin
            spad_rsp_valid <= 0;
            model_cycle = model_cycle + 1;
            if (measuring) begin
                core_cycles <= core_cycles + 1;
                if (dut.compute_fire) compute_cycles <= compute_cycles + 1;
                if (spad_valid && !spad_write && !spad_ready)
                    admission_stall_cycles <= admission_stall_cycles + 1;
                if ((dut.outstanding_reads_r != 0) && !spad_rsp_valid)
                    response_wait_cycles <= response_wait_cycles + 1;
                if ((dut.state_r == 4'd6) && !spad_ready)
                    write_wait_cycles <= write_wait_cycles + 1;
            end
            if (rsp_count > 0 && rsp_due[rsp_head] <= model_cycle) begin
                spad_rsp_valid <= 1;
                spad_rdata <= rsp_data[rsp_head];
                rsp_head = (rsp_head == 3) ? 0 : rsp_head + 1;
                rsp_count = rsp_count - 1;
            end
            if (spad_valid && spad_ready) begin
                if (spad_write) begin
                    writes <= writes + 1;
                    if (spad_addr !== dst_base) $fatal(1,"bad write address %h",spad_addr);
                end else begin
                    if (rsp_count >= 4) $fatal(1,"response queue overflow");
                    if ((reads % 2)==0) begin
                        if (spad_addr !== src0_base + ((reads/2)*4))
                            $fatal(1,"A read order/address mismatch read=%0d addr=%h",reads,spad_addr);
                    end else if (spad_addr !== src1_base + (((reads-1)/2)*4))
                        $fatal(1,"B read order/address mismatch read=%0d addr=%h",reads,spad_addr);
                    rsp_data[rsp_tail] = format_fp16 ? 32'h3c003c00 : 32'h3f803f80;
                    rsp_due[rsp_tail] = model_cycle + 2 +
                        ((lcg_next(seed ^ reads) & 32'h7fff_ffff) %
                         (rsp_jitter_max + 1));
                    rsp_tail = (rsp_tail == 3) ? 0 : rsp_tail + 1;
                    rsp_count = rsp_count + 1;
                    reads <= reads + 1;
                end
            end
        end
    end

    task automatic run_case(input reg fp16, input integer n);
        integer expected_reads;
        reg [31:0] expected;
        begin
            @(negedge clk);
            format_fp16=fp16; length=n;
            reads=0; writes=0; core_cycles=0; compute_cycles=0;
            admission_stall_cycles=0; response_wait_cycles=0; write_wait_cycles=0;
            start=1; measuring=1;
            @(negedge clk); start=0;
            fork : wait_for_completion
                begin
                    wait (done);
                end
                begin
                    repeat (1000000) @(posedge clk);
                    $fatal(1, "dot bench timeout format=%0d length=%0d bp=%0d jitter=%0d", fp16, n, bp_percent, rsp_jitter_max);
                end
            join_any
            disable wait_for_completion;
            measuring=0;
            expected_reads=2*((n+1)/2);
            expected=expected_sum(n);
            if (error || error_code!==0) $fatal(1,"unexpected error fmt=%0d len=%0d code=%0d",fp16,n,error_code);
            if (result!==expected) $fatal(1,"result mismatch fmt=%0d len=%0d got=%h expected=%h",fp16,n,result,expected);
            if (element_count!==n) $fatal(1,"element count mismatch got=%0d expected=%0d",element_count,n);
            if (reads!==expected_reads) $fatal(1,"read count mismatch got=%0d expected=%0d",reads,expected_reads);
            if (writes!==1) $fatal(1,"expected one accepted write, got %0d",writes);
            if (response_pending) $fatal(1,"response left pending");
            throughput=(1.0*compute_cycles)/core_cycles;
            $display("DOT_BENCH,unit_spad_model,seed=%0d,bp_pct=%0d,format=%s,length=%0d,core_cycles=%0d,compute_fire_cycles=%0d,spad_admission_stall_cycles=%0d,response_wait_cycles=%0d,result_write_wait_cycles=%0d,reads=%0d,writes=%0d,elements=%0d,compute_elements_per_core_cycle=%0.5f,rsp_jitter_max=%0d",
                seed,bp_percent,fp16?"FP16":"BF16",n,core_cycles,compute_cycles,
                admission_stall_cycles,response_wait_cycles,write_wait_cycles,
                reads,writes,element_count,throughput,rsp_jitter_max);
            @(negedge clk);
        end
    endtask

    integer lengths [0:8];
    integer i;
    initial begin
        lengths[0]=1; lengths[1]=2; lengths[2]=3; lengths[3]=4;
        lengths[4]=16; lengths[5]=64; lengths[6]=128;
        lengths[7]=256; lengths[8]=1024;
        if ($value$plusargs("SEED=%d",seed)) begin end
        if ($value$plusargs("BP_PCT=%d",bp_percent)) begin end
        if ($value$plusargs("RSP_JITTER_MAX=%d",rsp_jitter_max)) begin end
        if (bp_percent<0 || bp_percent>99) $fatal(1,"BP_PCT must be 0..99");
        if (rsp_jitter_max<0 || rsp_jitter_max>31) $fatal(1,"RSP_JITTER_MAX must be 0..31");
        rng=seed;
        $display("DOT_BENCH_HEADER,unit_spad_model,seed,bp_pct,format,length,core_cycles,compute_fire_cycles,spad_admission_stall_cycles,response_wait_cycles,result_write_wait_cycles,reads,writes,elements,compute_elements_per_core_cycle,rsp_jitter_max");
        repeat(3) @(negedge clk);
        resetn=1;
        for (i=0;i<9;i=i+1) run_case(0,lengths[i]);
        for (i=0;i<9;i=i+1) run_case(1,lengths[i]);
        $display("PASS: mixed BF16/FP16 dot unit throughput benchmark (not DMA contention)");
        $finish;
    end
endmodule
