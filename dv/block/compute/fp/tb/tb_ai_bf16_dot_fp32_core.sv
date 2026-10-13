`timescale 1ns/1ps
module tb_ai_bf16_dot_fp32_core;
    reg clk=0, resetn=0, start=0, abort=0;
    always #5 clk=~clk;
    reg [31:0] src0_base=32'h100, src1_base=32'h200, dst_base=32'h300;
    reg [15:0] length=0;
    reg [31:0] watchdog_limit=0;
    wire spad_valid, spad_write;
    wire [31:0] spad_addr, spad_wdata;
    reg spad_ready=0, spad_rsp_valid=0;
    reg [31:0] spad_rdata=0;
    reg spad_parity_error=0, spad_protection_error=0;
    wire busy, done, error;
    wire [3:0] error_code;
    wire [31:0] result, cycle_count, element_count;

    ai_bf16_dot_fp32_core dut(.*);

    reg [31:0] mem [0:255];
    integer accept_count=0, write_count=0, response_count=0;
    integer peak_outstanding_reads=0;
    integer stall_cycles=0, cycles=0;
    integer random_stalls=0, random_transactions=0;
    integer cov_len_1=0, cov_len_2=0, cov_len_3=0, cov_len_4=0;
    integer cov_zero=0, cov_subnormal=0, cov_normal=0, cov_inf=0, cov_nan=0;
    integer cov_positive=0, cov_negative=0, cov_stalled=0;
    integer pending_count=0, pending_head=0, pending_tail=0;
    integer pending_due [0:3];
    reg pending_parity [0:3];
    reg [31:0] pending_data [0:3];
    integer parity_accept_index=-1;
    wire pending = (pending_count != 0);
    reg [31:0] held_addr=0, held_data=0;
    reg held_valid=0, held_write=0;
    reg inject_parity=0, inject_protection=0;
    reg stall_write=0;

    property p_spad_request_stable_while_stalled;
        @(posedge clk) disable iff (!resetn)
            (spad_valid && !spad_ready) |=>
                ((abort || dut.mixed_core_u.watchdog_expired) ||
                 (spad_valid && $stable({spad_write, spad_addr, spad_wdata})));
    endproperty
    assert property (p_spad_request_stable_while_stalled)
        else $fatal(1, "SPAD request changed while ready was low");

    always @(posedge clk) begin
        if (resetn) begin
            if (spad_rsp_valid && (dut.mixed_core_u.outstanding_reads_r == 0))
                $fatal(1,"response outstanding counter underflow state=%0d accepted=%0d delivered=%0d addr=%h",
                       dut.mixed_core_u.state_r,accept_count,response_count,spad_addr);
            if (spad_valid && spad_ready && !spad_write && !spad_rsp_valid &&
                (dut.mixed_core_u.outstanding_reads_r >= 2))
                $fatal(1,"read outstanding counter overflow");
        end
    end

    always @(negedge clk) begin
        if (!resetn) begin
            spad_ready=0; spad_rsp_valid=0;
            pending_count=0; pending_head=0; pending_tail=0;
        end else begin
            cycles=cycles+1;
            if (dut.mixed_core_u.outstanding_reads_r > 2)
                $fatal(1,"core exceeded legal two-read outstanding limit");
            if (dut.mixed_core_u.outstanding_reads_r > peak_outstanding_reads)
                peak_outstanding_reads=dut.mixed_core_u.outstanding_reads_r;
            spad_rsp_valid=0;
            spad_parity_error=0;
            spad_protection_error=0;
            if (pending_count>0 && pending_due[pending_head]<=cycles) begin
                    spad_rsp_valid=1;
                    spad_rdata=pending_data[pending_head];
                    spad_parity_error=pending_parity[pending_head];
                    response_count=response_count+1;
                pending_head=(pending_head==3) ? 0 : pending_head+1;
                pending_count=pending_count-1;
            end
            if (stall_write && spad_valid && spad_write) begin
                spad_ready=0;
            end else if (stall_cycles>0) begin
                spad_ready=0; stall_cycles=stall_cycles-1;
            end else begin
                spad_ready=1;
                if (random_stalls && ($urandom_range(0,2)==0))
                    stall_cycles=$urandom_range(1,2);
            end
            if (spad_valid && spad_ready && inject_protection)
                spad_protection_error=1;
            if (spad_valid && !spad_ready) begin
                if (!held_valid) begin
                    if (random_stalls) cov_stalled=cov_stalled+1;
                    held_addr=spad_addr; held_data=spad_wdata;
                    held_valid=1; held_write=spad_write;
                end else if (held_addr!==spad_addr || held_data!==spad_wdata ||
                             held_write!==spad_write)
                    $fatal(1,"request changed under ready stall");
            end else if (held_valid && !spad_valid &&
                         (abort || dut.mixed_core_u.watchdog_expired)) begin
                // This local request interface permits canceling an unaccepted
                // read on abort/watchdog. Accepted reads still drain in WAIT.
                held_valid=0;
            end
        end
    end

    // Sample valid/ready at the DUT's active edge, not a half-cycle later.
    always @(posedge clk) begin
        if (resetn && spad_valid && spad_ready) begin
            held_valid=0;
            if (spad_write) begin
                write_count=write_count+1;
                if (spad_addr!==dst_base) $fatal(1,"bad write address %h",spad_addr);
                if (!spad_protection_error) mem[spad_addr>>2]=spad_wdata;
            end else begin
                if (pending_count>=4) $fatal(1,"response queue overflow");
                if ((accept_count & 1)==0) begin
                    if (spad_addr !== (src0_base + ((accept_count/2)*4)))
                        $fatal(1,"A read order/address mismatch idx=%0d addr=%h",
                               accept_count,spad_addr);
                end else if (spad_addr !== (src1_base + (((accept_count-1)/2)*4)) )
                    $fatal(1,"B read order/address mismatch idx=%0d addr=%h",
                           accept_count,spad_addr);
                accept_count=accept_count+1;
                if ((spad_addr >> 2) >= 256)
                    $fatal(1,"SPAD read outside test memory: %h",spad_addr);
                pending_data[pending_tail]=mem[spad_addr>>2];
                pending_parity[pending_tail]=inject_parity &&
                    ((parity_accept_index < 0) ||
                     ((accept_count-1) == parity_accept_index));
                pending_due[pending_tail]=cycles+2;
                pending_tail=(pending_tail==3) ? 0 : pending_tail+1;
                pending_count=pending_count+1;
            end
        end
    end

    task reset_case;
        begin
            @(negedge clk); resetn=0; start=0; abort=0;
            inject_parity=0; inject_protection=0;
            parity_accept_index=-1;
            accept_count=0; write_count=0; response_count=0;
            peak_outstanding_reads=0;
            pending_count=0; pending_head=0; pending_tail=0; held_valid=0;
            stall_cycles=0; stall_write=0; spad_ready=0;
            repeat(2) @(negedge clk);
            resetn=1; @(negedge clk);
        end
    endtask

    task launch(input [15:0] n);
        begin length=n; start=1; @(negedge clk); start=0; end
    endtask

    task wait_done(input integer max_cycles);
        integer k;
        begin
            k=0; while (!done && k<max_cycles) begin @(negedge clk); k=k+1; end
            if (!done) $fatal(1,"timeout waiting done");
        end
    endtask

    task check_success(input [31:0] expected, input integer expected_reads,
                       input [31:0] expected_elements);
        begin
            wait_done(100);
            if (error || error_code!==0) $fatal(1,"unexpected error %0d",error_code);
            if (result!==expected) $fatal(1,"result %h expected %h",result,expected);
            if (mem[dst_base>>2]!==expected)
                $fatal(1,"SPAD result %h expected %h",mem[dst_base>>2],expected);
            if (element_count!==expected_elements) $fatal(1,"element_count %0d",element_count);
            if (accept_count!=expected_reads || write_count!=1)
                $fatal(1,"reads=%0d writes=%0d",accept_count,write_count);
        end
    endtask

    task sample_bf16(input [15:0] value);
        reg [7:0] exponent;
        reg [6:0] fraction;
        begin
            exponent=value[14:7];
            fraction=value[6:0];
            if (value[15]) cov_negative=cov_negative+1;
            else cov_positive=cov_positive+1;
            if (exponent==0) begin
                if (fraction==0) cov_zero=cov_zero+1;
                else cov_subnormal=cov_subnormal+1;
            end else if (exponent==8'hff) begin
                if (fraction==0) cov_inf=cov_inf+1;
                else cov_nan=cov_nan+1;
            end else cov_normal=cov_normal+1;
        end
    endtask

    task run_random_vectors;
        integer fd, scan_count, vector_count, vector_length;
        integer seed_value, seed_advance;
        reg [15:0] a0, a1, a2, a3;
        reg [15:0] b0, b1, b2, b3;
        reg [31:0] expected_value;
        reg [1023:0] vector_path;
        begin
            seed_value=20261013;
            if ($value$plusargs("SEED=%d",seed_value)) begin end
            seed_advance=$urandom(seed_value);
            if (!$value$plusargs("RANDOM_VECTORS=%s",vector_path))
                $fatal(1,"RANDOM_VECTORS plusarg is required");
            fd=$fopen(vector_path,"r");
            if (fd==0) $fatal(1,"cannot open BF16 dot vector file %0s",vector_path);
            vector_count=0;
            while (!$feof(fd)) begin
                scan_count=$fscanf(fd,"%d %h %h %h %h %h %h %h %h %h",
                                   vector_length,a0,a1,a2,a3,b0,b1,b2,b3,
                                   expected_value);
                if (scan_count==10) begin
                    if (vector_length<1 || vector_length>4)
                        $fatal(1,"invalid random vector length %0d",vector_length);
                    mem[(src0_base>>2)]= {a1,a0};
                    mem[(src0_base>>2)+1]= {a3,a2};
                    mem[(src1_base>>2)]= {b1,b0};
                    mem[(src1_base>>2)+1]= {b3,b2};
                    sample_bf16(a0); sample_bf16(b0);
                    if (vector_length>1) begin
                        sample_bf16(a1); sample_bf16(b1);
                    end
                    if (vector_length>2) begin
                        sample_bf16(a2); sample_bf16(b2);
                    end
                    if (vector_length>3) begin
                        sample_bf16(a3); sample_bf16(b3);
                    end
                    case (vector_length)
                        1: cov_len_1=cov_len_1+1;
                        2: cov_len_2=cov_len_2+1;
                        3: cov_len_3=cov_len_3+1;
                        4: cov_len_4=cov_len_4+1;
                        default: $fatal(1,"unreachable vector length");
                    endcase
                    reset_case();
                    random_stalls=1;
                    stall_cycles=$urandom_range(1,3);
                    launch(vector_length[15:0]);
                    check_success(expected_value,2*((vector_length+1)/2),
                                  vector_length);
                    random_stalls=0;
                    random_transactions=random_transactions+1;
                    vector_count=vector_count+1;
                end else if (scan_count!=-1) begin
                    $fatal(1,"malformed vector row %0d (fields=%0d)",
                           vector_count+1,scan_count);
                end
            end
            $fclose(fd);
            if (vector_count<20)
                $fatal(1,"too few randomized transactions: %0d",vector_count);
            if (!cov_len_1 || !cov_len_2 || !cov_len_3 || !cov_len_4 ||
                !cov_zero || !cov_subnormal || !cov_normal || !cov_inf ||
                !cov_nan || !cov_positive || !cov_negative || !cov_stalled)
                $fatal(1,"functional coverage hole: len=%0d/%0d/%0d/%0d class=%0d/%0d/%0d/%0d/%0d sign=%0d/%0d stall=%0d",
                       cov_len_1,cov_len_2,cov_len_3,cov_len_4,
                       cov_zero,cov_subnormal,cov_normal,cov_inf,cov_nan,
                       cov_positive,cov_negative,cov_stalled);
            $display("BF16_DOT_COVERAGE seed=%0d transactions=%0d len[1:4]=%0d/%0d/%0d/%0d class[z/sub/norm/inf/nan]=%0d/%0d/%0d/%0d/%0d sign[pos/neg]=%0d/%0d stalled=%0d",
                     seed_value,random_transactions,cov_len_1,cov_len_2,
                     cov_len_3,cov_len_4,cov_zero,cov_subnormal,cov_normal,
                     cov_inf,cov_nan,cov_positive,cov_negative,cov_stalled);
        end
    endtask

    initial begin
        // 1*3 + 2*4 = 11; input words are packed low-even/high-odd.
        mem['h100>>2]=32'h40003f80; mem['h200>>2]=32'h40804040;
        mem['h104>>2]=32'h3f803f80; mem['h204>>2]=32'h40404040;
        reset_case(); stall_cycles=3; launch(1); check_success(32'h40400000,2,1);
        // length 2 checks both lanes and the specification's bit-exact 11.
        reset_case(); launch(2); check_success(32'h41300000,2,2);
        if (peak_outstanding_reads<2)
            $fatal(1,"two accepted outstanding reads were not observed: peak=%0d",
                   peak_outstanding_reads);
        // length 3 consumes one high lane from second word; high tail is poison.
        mem['h104>>2]=32'h7f800000; mem['h204>>2]=32'h7f803f80;
        reset_case(); launch(3); check_success(32'h41300000,4,3);

        // Reset with an accepted read drops the operation and clears outputs.
        reset_case(); launch(2);
        wait (accept_count>0 && accept_count>response_count);
        @(negedge clk); resetn=0; #1;
        if (busy || done || error) $fatal(1,"reset did not clear engine");
        repeat(2) @(negedge clk);
        resetn=1; repeat(3) @(negedge clk);
        if (write_count!=0) $fatal(1,"reset transaction wrote output");

        // Abort while a read is outstanding: wait for/drain response, then fail.
        reset_case(); launch(2);
        wait (accept_count>0 && accept_count>response_count);
        @(negedge clk); abort=1; @(negedge clk); abort=0;
        wait_done(30);
        if (!error || error_code!=3 || pending || write_count!=0)
            $fatal(1,"abort drain failed code=%0d pending=%0d",error_code,pending);

        // The final output request is the commit point.  If abort arrives
        // after writeback is presented, hold it stable through back-pressure,
        // accept the write, and report success rather than a failed completion
        // with an already-modified destination.
        reset_case(); launch(1);
        wait (spad_valid && spad_write);
        stall_write=1; abort=1; repeat(3) @(negedge clk);
        if (!spad_valid || !spad_write || spad_addr!==dst_base)
            $fatal(1,"writeback request was not held during abort/back-pressure");
        stall_write=0; abort=0; wait_done(30);
        if (error || error_code!=0 || write_count!=1 ||
            result!==32'h40400000 || mem[dst_base>>2]!==32'h40400000)
            $fatal(1,"writeback commit point mismatch error=%0d code=%0d result=%h",
                   error,error_code,result);

        // Protection is reported after the accepted request's response drains.
        reset_case(); inject_protection=1; launch(1); wait_done(30);
        if (!error || error_code!=6 || pending || write_count!=0)
            $fatal(1,"protection handling failed code=%0d",error_code);

        reset_case(); inject_parity=1; launch(1); wait_done(30);
        if (!error || error_code!=5 || pending || write_count!=0)
            $fatal(1,"parity handling failed code=%0d",error_code);

        // A parity error in word 1 must preserve the two valid prefix
        // elements from word 0, while draining accepted reads and suppressing
        // the final writeback.
        reset_case(); inject_parity=1; parity_accept_index=2;
        launch(4); wait_done(40);
        if (!error || error_code!=5 || element_count!=2 || pending ||
            write_count!=0 || accept_count!=4)
            $fatal(1,"word-1 parity cutoff failed code=%0d elements=%0d reads=%0d pending=%0d writes=%0d",
                   error_code,element_count,accept_count,pending,write_count);

        reset_case(); watchdog_limit=3; stall_cycles=10; launch(1); wait_done(40);
        watchdog_limit=0;
        if (!error || error_code!=4 || pending || write_count!=0)
            $fatal(1,"watchdog handling failed code=%0d",error_code);

        if ($test$plusargs("RANDOM_VECTORS")) run_random_vectors();

        $display("PASS: BF16 dot core block test");
        $finish;
    end
endmodule
