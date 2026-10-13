`timescale 1ns/1ps

// Integration-level ready/valid test for ai_accel_dual_clock_shell.
//
// The two clocks are deliberately incommensurate (11 ns and 17 ns).  Every
// command/completion field is checked at the receiving handshake edge.  The
// source processes only change payload while valid is low or immediately
// after a handshake, so a stalled transfer also checks the ready/valid hold
// contract.
module tb_ai_accel_dual_clock_shell;
    localparam integer N = 8;
    localparam integer TOTAL = 2*N;

    reg ctrl_clk=0, compute_clk=0;
    reg ctrl_resetn=0, compute_resetn=0, traffic_enable=0;
    reg ctrl_cmd_valid=0, compute_cmd_ready=0;
    reg compute_cpl_valid=0, ctrl_cpl_ready=0;
    wire ctrl_cmd_ready, compute_cmd_valid, compute_cpl_ready, ctrl_cpl_valid;

    reg [15:0] ctrl_cmd_sequence;
    reg ctrl_abort, ctrl_submit, ctrl_direct_start, ctrl_tile_start;
    reg [63:0] ctrl_cmdq_base;
    reg [31:0] ctrl_cmdq_size, ctrl_cmdq_tail;
    reg ctrl_desc_external, ctrl_cmdq_head_load;
    reg [31:0] ctrl_cmdq_head_seed, ctrl_cplq_base, ctrl_cplq_size, ctrl_cplq_head;
    reg ctrl_completion_protected, ctrl_cplq_tail_load;
    reg [31:0] ctrl_cplq_tail_seed;
    reg [7:0] ctrl_cfg_op;
    reg [31:0] ctrl_cfg_src0, ctrl_cfg_src1, ctrl_cfg_dst;
    reg [15:0] ctrl_cfg_length, ctrl_cfg_m, ctrl_cfg_n, ctrl_cfg_k;
    reg [4:0] ctrl_cfg_shift;
    reg [1:0] ctrl_cfg_activation;
    reg [31:0] ctrl_cfg_bias_base;
    reg ctrl_cfg_bias_enable;
    reg [15:0] ctrl_tile_count;
    reg [63:0] ctrl_tile_ext_input_base, ctrl_tile_ext_output_base;
    reg [31:0] ctrl_tile_ext_input_stride, ctrl_tile_ext_output_stride;
    reg [31:0] ctrl_tile_buffer0_base, ctrl_tile_buffer1_base, ctrl_tile_output_offset;
    reg [15:0] ctrl_tile_input_words, ctrl_tile_output_words;

    wire [7:0] compute_cmd_packet_version;
    wire [15:0] compute_cmd_sequence;
    wire compute_abort, compute_submit, compute_direct_start, compute_tile_start;
    wire [63:0] compute_cmdq_base;
    wire [31:0] compute_cmdq_size, compute_cmdq_tail;
    wire compute_desc_external, compute_cmdq_head_load;
    wire [31:0] compute_cmdq_head_seed, compute_cplq_base, compute_cplq_size, compute_cplq_head;
    wire compute_completion_protected, compute_cplq_tail_load;
    wire [31:0] compute_cplq_tail_seed;
    wire [7:0] compute_cfg_op;
    wire [31:0] compute_cfg_src0, compute_cfg_src1, compute_cfg_dst;
    wire [15:0] compute_cfg_length, compute_cfg_m, compute_cfg_n, compute_cfg_k;
    wire [4:0] compute_cfg_shift;
    wire [1:0] compute_cfg_activation;
    wire [31:0] compute_cfg_bias_base;
    wire compute_cfg_bias_enable;
    wire [15:0] compute_tile_count;
    wire [63:0] compute_tile_ext_input_base, compute_tile_ext_output_base;
    wire [31:0] compute_tile_ext_input_stride, compute_tile_ext_output_stride;
    wire [31:0] compute_tile_buffer0_base, compute_tile_buffer1_base, compute_tile_output_offset;
    wire [15:0] compute_tile_input_words, compute_tile_output_words;

    reg [15:0] compute_event_sequence;
    reg compute_event_valid, compute_event_error;
    reg [3:0] compute_event_error_code;
    reg [31:0] compute_event_result, compute_event_cycles, compute_event_elements;
    reg [31:0] compute_cmdq_head, compute_cplq_tail;
    reg [15:0] compute_dependency_events;
    reg compute_busy;
    wire [7:0] ctrl_cpl_packet_version;
    wire [15:0] ctrl_event_sequence;
    wire ctrl_event_valid, ctrl_event_error;
    wire [3:0] ctrl_event_error_code;
    wire [31:0] ctrl_event_result, ctrl_event_cycles, ctrl_event_elements;
    wire [31:0] ctrl_cmdq_head, ctrl_cplq_tail;
    wire [15:0] ctrl_dependency_events;
    wire ctrl_busy;

    ai_accel_dual_clock_shell #(.CMD_PACKET_WIDTH(1024), .CPL_PACKET_WIDTH(256), .FIFO_DEPTH(16)) dut (
        .ctrl_clk(ctrl_clk), .ctrl_resetn(ctrl_resetn), .ctrl_cmd_valid(ctrl_cmd_valid), .ctrl_cmd_ready(ctrl_cmd_ready),
        .ctrl_cmd_sequence(ctrl_cmd_sequence), .ctrl_abort(ctrl_abort), .ctrl_submit(ctrl_submit),
        .ctrl_direct_start(ctrl_direct_start), .ctrl_tile_start(ctrl_tile_start), .ctrl_cmdq_base(ctrl_cmdq_base),
        .ctrl_cmdq_size(ctrl_cmdq_size), .ctrl_cmdq_tail(ctrl_cmdq_tail), .ctrl_desc_external(ctrl_desc_external),
        .ctrl_cmdq_head_load(ctrl_cmdq_head_load), .ctrl_cmdq_head_seed(ctrl_cmdq_head_seed), .ctrl_cplq_base(ctrl_cplq_base),
        .ctrl_cplq_size(ctrl_cplq_size), .ctrl_cplq_head(ctrl_cplq_head), .ctrl_completion_protected(ctrl_completion_protected),
        .ctrl_cplq_tail_load(ctrl_cplq_tail_load), .ctrl_cplq_tail_seed(ctrl_cplq_tail_seed), .ctrl_cfg_op(ctrl_cfg_op),
        .ctrl_cfg_src0(ctrl_cfg_src0), .ctrl_cfg_src1(ctrl_cfg_src1), .ctrl_cfg_dst(ctrl_cfg_dst), .ctrl_cfg_length(ctrl_cfg_length),
        .ctrl_cfg_m(ctrl_cfg_m), .ctrl_cfg_n(ctrl_cfg_n), .ctrl_cfg_k(ctrl_cfg_k), .ctrl_cfg_shift(ctrl_cfg_shift),
        .ctrl_cfg_activation(ctrl_cfg_activation), .ctrl_cfg_bias_base(ctrl_cfg_bias_base), .ctrl_cfg_bias_enable(ctrl_cfg_bias_enable),
        .ctrl_tile_count(ctrl_tile_count), .ctrl_tile_ext_input_base(ctrl_tile_ext_input_base), .ctrl_tile_ext_output_base(ctrl_tile_ext_output_base),
        .ctrl_tile_ext_input_stride(ctrl_tile_ext_input_stride), .ctrl_tile_ext_output_stride(ctrl_tile_ext_output_stride),
        .ctrl_tile_buffer0_base(ctrl_tile_buffer0_base), .ctrl_tile_buffer1_base(ctrl_tile_buffer1_base), .ctrl_tile_output_offset(ctrl_tile_output_offset),
        .ctrl_tile_input_words(ctrl_tile_input_words), .ctrl_tile_output_words(ctrl_tile_output_words),
        .compute_clk(compute_clk), .compute_resetn(compute_resetn), .compute_cmd_valid(compute_cmd_valid), .compute_cmd_ready(compute_cmd_ready),
        .compute_cmd_packet_version(compute_cmd_packet_version), .compute_cmd_sequence(compute_cmd_sequence), .compute_abort(compute_abort),
        .compute_submit(compute_submit), .compute_direct_start(compute_direct_start), .compute_tile_start(compute_tile_start),
        .compute_cmdq_base(compute_cmdq_base), .compute_cmdq_size(compute_cmdq_size), .compute_cmdq_tail(compute_cmdq_tail),
        .compute_desc_external(compute_desc_external), .compute_cmdq_head_load(compute_cmdq_head_load), .compute_cmdq_head_seed(compute_cmdq_head_seed),
        .compute_cplq_base(compute_cplq_base), .compute_cplq_size(compute_cplq_size), .compute_cplq_head(compute_cplq_head),
        .compute_completion_protected(compute_completion_protected), .compute_cplq_tail_load(compute_cplq_tail_load), .compute_cplq_tail_seed(compute_cplq_tail_seed),
        .compute_cfg_op(compute_cfg_op), .compute_cfg_src0(compute_cfg_src0), .compute_cfg_src1(compute_cfg_src1), .compute_cfg_dst(compute_cfg_dst),
        .compute_cfg_length(compute_cfg_length), .compute_cfg_m(compute_cfg_m), .compute_cfg_n(compute_cfg_n), .compute_cfg_k(compute_cfg_k),
        .compute_cfg_shift(compute_cfg_shift), .compute_cfg_activation(compute_cfg_activation), .compute_cfg_bias_base(compute_cfg_bias_base),
        .compute_cfg_bias_enable(compute_cfg_bias_enable), .compute_tile_count(compute_tile_count), .compute_tile_ext_input_base(compute_tile_ext_input_base),
        .compute_tile_ext_output_base(compute_tile_ext_output_base), .compute_tile_ext_input_stride(compute_tile_ext_input_stride),
        .compute_tile_ext_output_stride(compute_tile_ext_output_stride), .compute_tile_buffer0_base(compute_tile_buffer0_base),
        .compute_tile_buffer1_base(compute_tile_buffer1_base), .compute_tile_output_offset(compute_tile_output_offset),
        .compute_tile_input_words(compute_tile_input_words), .compute_tile_output_words(compute_tile_output_words),
        .compute_cpl_valid(compute_cpl_valid), .compute_cpl_ready(compute_cpl_ready), .compute_event_sequence(compute_event_sequence),
        .compute_event_valid(compute_event_valid), .compute_event_error(compute_event_error), .compute_event_error_code(compute_event_error_code),
        .compute_event_result(compute_event_result), .compute_event_cycles(compute_event_cycles), .compute_event_elements(compute_event_elements),
        .compute_cmdq_head(compute_cmdq_head), .compute_cplq_tail(compute_cplq_tail), .compute_dependency_events(compute_dependency_events), .compute_busy(compute_busy),
        .ctrl_cpl_valid(ctrl_cpl_valid), .ctrl_cpl_ready(ctrl_cpl_ready), .ctrl_cpl_packet_version(ctrl_cpl_packet_version),
        .ctrl_event_sequence(ctrl_event_sequence), .ctrl_event_valid(ctrl_event_valid), .ctrl_event_error(ctrl_event_error),
        .ctrl_event_error_code(ctrl_event_error_code), .ctrl_event_result(ctrl_event_result), .ctrl_event_cycles(ctrl_event_cycles),
        .ctrl_event_elements(ctrl_event_elements), .ctrl_cmdq_head(ctrl_cmdq_head), .ctrl_cplq_tail(ctrl_cplq_tail),
        .ctrl_dependency_events(ctrl_dependency_events), .ctrl_busy(ctrl_busy));

    always #5.5 ctrl_clk = ~ctrl_clk;
    always #8.5 compute_clk = ~compute_clk;

    integer errors=0, cmd_sent=0, cmd_got=0, cpl_sent=0, cpl_got=0;
    reg [31:0] cmd_rand=32'h13579bdf, cpl_rand=32'h2468ace1;
    function automatic [31:0] lfsr(input [31:0] x);
        lfsr = {x[30:0], x[31]^x[21]^x[1]^x[0]};
    endfunction
    function automatic [31:0] u(input integer i, input integer salt);
        u = 32'h1000_0000 + i*32'h0101_0101 + salt*32'h0011_2233;
    endfunction

    task automatic load_command(input integer i);
        begin
            ctrl_cmd_sequence=u(i,1) & 16'hffff; ctrl_abort=i[0]; ctrl_submit=~i[0]; ctrl_direct_start=i[1]; ctrl_tile_start=i[2];
            ctrl_cmdq_base={u(i,2),u(i,3)}; ctrl_cmdq_size=u(i,4); ctrl_cmdq_tail=u(i,5); ctrl_desc_external=i[1];
            ctrl_cmdq_head_load=i[0]; ctrl_cmdq_head_seed=u(i,6); ctrl_cplq_base=u(i,7); ctrl_cplq_size=u(i,8); ctrl_cplq_head=u(i,9);
            ctrl_completion_protected=i[2]; ctrl_cplq_tail_load=i[0]^i[1]; ctrl_cplq_tail_seed=u(i,10); ctrl_cfg_op=8'h80+i;
            ctrl_cfg_src0=u(i,11); ctrl_cfg_src1=u(i,12); ctrl_cfg_dst=u(i,13); ctrl_cfg_length=16'h200+i; ctrl_cfg_m=16'h31+i; ctrl_cfg_n=16'h42+i; ctrl_cfg_k=16'h53+i;
            ctrl_cfg_shift=5'h10+i; ctrl_cfg_activation=2'b01+i[0]; ctrl_cfg_bias_base=u(i,14); ctrl_cfg_bias_enable=i[0]; ctrl_tile_count=16'h60+i;
            ctrl_tile_ext_input_base={u(i,15),u(i,16)}; ctrl_tile_ext_output_base={u(i,17),u(i,18)}; ctrl_tile_ext_input_stride=u(i,19); ctrl_tile_ext_output_stride=u(i,20);
            ctrl_tile_buffer0_base=u(i,21); ctrl_tile_buffer1_base=u(i,22); ctrl_tile_output_offset=u(i,23); ctrl_tile_input_words=16'h70+i; ctrl_tile_output_words=16'h80+i;
        end
    endtask

    task automatic check_command(input integer i);
        begin
            if (compute_cmd_packet_version!==8'h01 || compute_cmd_sequence!==(u(i,1) & 16'hffff) || compute_abort!==i[0] || compute_submit!==(~i[0]) || compute_direct_start!==i[1] || compute_tile_start!==i[2] ||
                compute_cmdq_base!=={u(i,2),u(i,3)} || compute_cmdq_size!==u(i,4) || compute_cmdq_tail!==u(i,5) || compute_desc_external!==i[1] || compute_cmdq_head_load!==i[0] || compute_cmdq_head_seed!==u(i,6) ||
                compute_cplq_base!==u(i,7) || compute_cplq_size!==u(i,8) || compute_cplq_head!==u(i,9) || compute_completion_protected!==i[2] || compute_cplq_tail_load!==(i[0]^i[1]) || compute_cplq_tail_seed!==u(i,10) ||
                compute_cfg_op!==(8'h80+i) || compute_cfg_src0!==u(i,11) || compute_cfg_src1!==u(i,12) || compute_cfg_dst!==u(i,13) || compute_cfg_length!==(16'h200+i) || compute_cfg_m!==(16'h31+i) || compute_cfg_n!==(16'h42+i) || compute_cfg_k!==(16'h53+i) ||
                compute_cfg_shift!==(5'h10+i) || compute_cfg_activation!==(2'b01+i[0]) || compute_cfg_bias_base!==u(i,14) || compute_cfg_bias_enable!==i[0] || compute_tile_count!==(16'h60+i) ||
                compute_tile_ext_input_base!=={u(i,15),u(i,16)} || compute_tile_ext_output_base!=={u(i,17),u(i,18)} || compute_tile_ext_input_stride!==u(i,19) || compute_tile_ext_output_stride!==u(i,20) ||
                compute_tile_buffer0_base!==u(i,21) || compute_tile_buffer1_base!==u(i,22) || compute_tile_output_offset!==u(i,23) || compute_tile_input_words!==(16'h70+i) || compute_tile_output_words!==(16'h80+i)) begin
                $display("ERROR command field mismatch index=%0d",i); errors=errors+1;
            end
        end
    endtask

    task automatic load_completion(input integer i);
        begin
            compute_event_sequence=u(i,30) & 16'hffff; compute_event_valid=i[0]; compute_event_error=~i[0]; compute_event_error_code=4'h5+i;
            compute_event_result=u(i,31); compute_event_cycles=u(i,32); compute_event_elements=u(i,33); compute_cmdq_head=u(i,34); compute_cplq_tail=u(i,35);
            compute_dependency_events=16'hc000+i; compute_busy=i[1];
        end
    endtask
    task automatic check_completion(input integer i);
        begin
            if (ctrl_cpl_packet_version!==8'h01 || ctrl_event_sequence!==(u(i,30) & 16'hffff) || ctrl_event_valid!==i[0] || ctrl_event_error!==(~i[0]) || ctrl_event_error_code!==((i+5) & 4'hf) ||
                ctrl_event_result!==u(i,31) || ctrl_event_cycles!==u(i,32) || ctrl_event_elements!==u(i,33) || ctrl_cmdq_head!==u(i,34) || ctrl_cplq_tail!==u(i,35) || ctrl_dependency_events!==(16'hc000+i) || ctrl_busy!==i[1]) begin
                $display("ERROR completion field mismatch index=%0d",i); errors=errors+1;
            end
        end
    endtask

    always @(negedge compute_clk) begin
        compute_cmd_ready <= traffic_enable && compute_resetn && (cmd_rand[2:0] != 0);
        cmd_rand <= lfsr(cmd_rand);
    end
    always @(negedge ctrl_clk) begin
        ctrl_cpl_ready <= traffic_enable && ctrl_resetn && (cpl_rand[2:0] != 0);
        cpl_rand <= lfsr(cpl_rand);
    end
    always @(posedge compute_clk) if (compute_cmd_valid && compute_cmd_ready) begin check_command(cmd_got); cmd_got=cmd_got+1; end
    always @(posedge ctrl_clk) if (ctrl_cpl_valid && ctrl_cpl_ready) begin check_completion(cpl_got); cpl_got=cpl_got+1; end

    task automatic send_commands(input integer first);
        integer j;
        begin
            for (j=0;j<N;j=j+1) begin
                @(negedge ctrl_clk); load_command(first+j); ctrl_cmd_valid=1'b1;
                while (1) begin @(posedge ctrl_clk); if (ctrl_cmd_ready) begin @(negedge ctrl_clk); ctrl_cmd_valid=1'b0; break; end end
            end
        end
    endtask
    task automatic send_completions(input integer first);
        integer j;
        begin
            for (j=0;j<N;j=j+1) begin
                @(negedge compute_clk); load_completion(first+j); compute_cpl_valid=1'b1;
                while (1) begin @(posedge compute_clk); if (compute_cpl_ready) begin @(negedge compute_clk); compute_cpl_valid=1'b0; break; end end
            end
        end
    endtask

    initial begin
        ctrl_cmd_valid=0; compute_cpl_valid=0; ctrl_cpl_ready=0; compute_cmd_ready=0;
        compute_event_sequence=0; compute_event_valid=0; compute_event_error=0; compute_event_error_code=0; compute_event_result=0; compute_event_cycles=0; compute_event_elements=0; compute_cmdq_head=0; compute_cplq_tail=0; compute_dependency_events=0; compute_busy=0;
        repeat(3) @(posedge ctrl_clk); ctrl_resetn=1; repeat(2) @(posedge compute_clk); compute_resetn=1;
        repeat(2) @(posedge ctrl_clk); traffic_enable=1;
        fork
            send_commands(0);
            begin wait(cmd_got==N); send_completions(0); end
        join
        wait(cpl_got==N);

        // Explicitly exercise the documented one-sided-reset boundary.  The
        // FIFO does not preserve an epoch across a unilateral reset, so the
        // remote consumer is quiesced until a subsequent bilateral reset has
        // flushed both pointers and they have been allowed to resynchronize.
        @(negedge ctrl_clk); traffic_enable=0;
        @(negedge compute_clk); compute_resetn=0; repeat(3) @(negedge compute_clk); compute_resetn=1;
        repeat(2) @(posedge compute_clk);
        ctrl_resetn=0; compute_resetn=0; repeat(3) @(posedge ctrl_clk); repeat(2) @(posedge compute_clk); ctrl_resetn=1; compute_resetn=1;
        repeat(2) @(posedge ctrl_clk); repeat(2) @(posedge compute_clk); traffic_enable=1;
        fork
            send_commands(N);
            begin wait(cmd_got==TOTAL); send_completions(N); end
        join
        fork
            begin wait(cpl_got==TOTAL); end
            begin repeat(2000) @(posedge ctrl_clk); $fatal(1,"timeout cmd=%0d/%0d cpl=%0d/%0d",cmd_got,TOTAL,cpl_got,TOTAL); end
        join_any disable fork;
        ctrl_cmd_valid=0; compute_cpl_valid=0; ctrl_cpl_ready=0; compute_cmd_ready=0;
        if (errors != 0 || cmd_got != TOTAL || cpl_got != TOTAL) $fatal(1,"DUAL CLOCK SHELL FAIL errors=%0d cmd=%0d cpl=%0d",errors,cmd_got,cpl_got);
        $display("DUAL CLOCK SHELL PASS commands=%0d completions=%0d errors=%0d",cmd_got,cpl_got,errors);
        $finish;
    end
endmodule
