`timescale 1ns/1ps

// Integration test for the command-path wrapper.  It drives two queue
// submissions through the ctrl-domain snapshot interface, models the
// descriptor fetch/compute endpoints in the compute domain, and checks the
// completion writer and reverse event packet under independent back-pressure.
module tb_ai_accel_dual_clock_command_path;
  logic ctrl_clk=0, compute_clk=0, ctrl_resetn=0, compute_resetn=0;
  always #5.5 ctrl_clk=~ctrl_clk;
  always #8.5 compute_clk=~compute_clk;

  logic ctrl_cmd_valid, ctrl_abort, ctrl_submit, ctrl_direct_start, ctrl_tile_start;
  logic [15:0] ctrl_cmd_sequence;
  logic [63:0] ctrl_cmdq_base; logic [31:0] ctrl_cmdq_size,ctrl_cmdq_tail;
  logic ctrl_desc_external,ctrl_cmdq_head_load; logic [31:0] ctrl_cmdq_head_seed;
  logic [31:0] ctrl_cplq_base,ctrl_cplq_size,ctrl_cplq_head; logic ctrl_completion_protected;
  logic ctrl_cplq_tail_load; logic [31:0] ctrl_cplq_tail_seed;
  logic [7:0] ctrl_cfg_op; logic [31:0] ctrl_cfg_src0,ctrl_cfg_src1,ctrl_cfg_dst;
  logic [15:0] ctrl_cfg_length,ctrl_cfg_m,ctrl_cfg_n,ctrl_cfg_k; logic [4:0] ctrl_cfg_shift;
  logic [1:0] ctrl_cfg_activation; logic [31:0] ctrl_cfg_bias_base; logic ctrl_cfg_bias_enable;
  logic [15:0] ctrl_tile_count; logic [63:0] ctrl_tile_ext_input_base,ctrl_tile_ext_output_base;
  logic [31:0] ctrl_tile_ext_input_stride,ctrl_tile_ext_output_stride,ctrl_tile_buffer0_base,ctrl_tile_buffer1_base,ctrl_tile_output_offset;
  logic [15:0] ctrl_tile_input_words,ctrl_tile_output_words; wire ctrl_cmd_ready;

  logic compute_fetch_busy,compute_fetch_done,compute_fetch_error;
  logic [7:0] compute_desc_op; logic [15:0] compute_desc_task_id;
  logic [31:0] compute_desc_src0,compute_desc_src1,compute_desc_dst; logic [15:0] compute_desc_length,compute_desc_m,compute_desc_n,compute_desc_k;
  logic [4:0] compute_desc_shift; logic [1:0] compute_desc_activation; logic [31:0] compute_desc_bias_base; logic compute_desc_bias_enable;
  logic [7:0] compute_desc_flags; logic [31:0] compute_desc_aux0,compute_desc_src0_stride,compute_desc_src1_stride,compute_desc_dst_stride;
  logic [15:0] compute_desc_batch_count,compute_desc_head_count,compute_desc_wait_mask,compute_desc_signal_mask,compute_desc_clear_mask; logic [7:0] compute_desc_version;
  logic compute_status_busy,compute_status_done,compute_status_error; logic [3:0] compute_status_error_code; logic [31:0] compute_status_result,compute_status_cycles,compute_status_elements;
  logic compute_dma_busy,compute_dma_done,compute_dma_error; logic [3:0] compute_dma_error_code;
  wire compute_fetch_start,compute_launch_valid,compute_completion_spad_valid,compute_completion_spad_write,compute_processor_busy,compute_event_overflow;
  wire [63:0] compute_fetch_base; wire compute_fetch_external;
  wire [7:0] compute_launch_op; wire [15:0] compute_launch_task_id,compute_launch_length,compute_launch_m,compute_launch_n,compute_launch_k,compute_tile_completed;
  wire [31:0] compute_launch_src0,compute_launch_src1,compute_launch_dst,compute_launch_bias_base,compute_launch_aux0,compute_launch_src0_stride,compute_launch_src1_stride,compute_launch_dst_stride;
  wire [4:0] compute_launch_shift; wire [1:0] compute_launch_activation; wire compute_launch_bias_enable; wire [7:0] compute_launch_flags;
  wire [15:0] compute_launch_batch_count,compute_launch_head_count; wire compute_tile_dma_start,compute_tile_dma_store,compute_tile_active;
  wire [63:0] compute_tile_dma_ext_addr; wire [31:0] compute_tile_dma_spad_addr; wire [15:0] compute_tile_dma_length_words;
  wire [31:0] compute_tile_perf_total,compute_tile_perf_dma,compute_tile_perf_compute,compute_tile_perf_overlap,compute_tile_perf_stall;
  wire [31:0] compute_completion_spad_addr,compute_completion_spad_wdata,compute_cmdq_head,compute_cplq_tail; wire [15:0] compute_dependency_events;
  logic compute_completion_spad_ready;
  wire ctrl_cpl_valid; logic ctrl_cpl_ready; wire [7:0] ctrl_cpl_packet_version; wire [15:0] ctrl_event_sequence;
  wire ctrl_event_valid,ctrl_event_error; wire [3:0] ctrl_event_error_code; wire [31:0] ctrl_event_result,ctrl_event_cycles,ctrl_event_elements,ctrl_cmdq_head,ctrl_cplq_tail; wire [15:0] ctrl_dependency_events; wire ctrl_busy;

  ai_accel_dual_clock_command_path dut (.*);

  integer errors=0, cmd_count=0, launch_count=0, event_count=0, word_count=0, done_count=0, countdown=0;
  reg [31:0] ready_lfsr=32'h91e10da5, cpl_lfsr=32'h7a31c2e9;
  function automatic [31:0] step(input [31:0] x); step={x[30:0],x[31]^x[21]^x[1]^x[0]}; endfunction

  task automatic set_cmd(input integer n);
    begin
      ctrl_cmd_sequence=16'h120+n; ctrl_abort=0; ctrl_submit=1; ctrl_direct_start=0; ctrl_tile_start=0;
      ctrl_cmdq_base=64'h0; ctrl_cmdq_size=0; ctrl_cmdq_tail=0; ctrl_desc_external=0; ctrl_cmdq_head_load=0; ctrl_cmdq_head_seed=0;
      ctrl_cplq_base=32'h1000; ctrl_cplq_size=16; ctrl_cplq_head=0; ctrl_completion_protected=0; ctrl_cplq_tail_load=0; ctrl_cplq_tail_seed=0;
      ctrl_cfg_op=8'h10; ctrl_cfg_src0=32'h2000+n*64; ctrl_cfg_src1=32'h3000+n*64; ctrl_cfg_dst=32'h4000+n*64; ctrl_cfg_length=16'd64; ctrl_cfg_m=16'd4; ctrl_cfg_n=16'd4; ctrl_cfg_k=16'd4;
      ctrl_cfg_shift=0; ctrl_cfg_activation=0; ctrl_cfg_bias_base=0; ctrl_cfg_bias_enable=0; ctrl_tile_count=0;
      ctrl_tile_ext_input_base=0; ctrl_tile_ext_output_base=0; ctrl_tile_ext_input_stride=0; ctrl_tile_ext_output_stride=0; ctrl_tile_buffer0_base=0; ctrl_tile_buffer1_base=0; ctrl_tile_output_offset=0; ctrl_tile_input_words=0; ctrl_tile_output_words=0;
    end
  endtask

  // Descriptor fetch model: legal ABI v7 descriptor, non-zero aligned fields.
  always @(posedge compute_clk) begin
    compute_fetch_done<=0; compute_fetch_error<=0; compute_fetch_busy<=0;
    if (compute_fetch_start) begin
      compute_desc_op<=8'h10; compute_desc_task_id<=16'h40+cmd_count; compute_desc_src0<=32'h2000+cmd_count*64; compute_desc_src1<=32'h3000+cmd_count*64; compute_desc_dst<=32'h4000+cmd_count*64;
      compute_desc_length<=16'd64; compute_desc_m<=16'd4; compute_desc_n<=16'd4; compute_desc_k<=16'd4; compute_desc_shift<=0; compute_desc_activation<=0; compute_desc_bias_base<=0; compute_desc_bias_enable<=0; compute_desc_flags<=0; compute_desc_aux0<=0;
      compute_desc_src0_stride<=16'd64; compute_desc_src1_stride<=16'd64; compute_desc_dst_stride<=16'd64; compute_desc_batch_count<=1; compute_desc_head_count<=1; compute_desc_wait_mask<=0; compute_desc_signal_mask<=0; compute_desc_clear_mask<=0; compute_desc_version<=8'd7;
      compute_fetch_done<=1;
    end
  end

  // Compute model accepts each launch and returns a deterministic completion.
  always @(posedge compute_clk) begin
    compute_status_done<=0; compute_status_error<=0; compute_dma_busy<=0; compute_dma_done<=0; compute_dma_error<=0;
    if (compute_launch_valid) begin compute_status_busy<=1; compute_status_result<=32'hcafe0000+launch_count; compute_status_cycles<=32'd9; compute_status_elements<=32'd16; countdown<=2; launch_count<=launch_count+1; end
    else if (countdown>0) begin countdown<=countdown-1; if (countdown==1) begin compute_status_busy<=0; compute_status_done<=1; done_count<=done_count+1; end end
  end

  always @(negedge compute_clk) begin ready_lfsr<=step(ready_lfsr); compute_completion_spad_ready <= ready_lfsr[2:0] != 0; end
  always @(negedge ctrl_clk) begin cpl_lfsr<=step(cpl_lfsr); ctrl_cpl_ready <= ctrl_resetn && (cpl_lfsr[2:0] != 0); end

  // Four-word completion record checker.  The writer must hold address/data
  // stable through every injected ready stall.
  always @(posedge compute_clk) if (compute_completion_spad_valid && compute_completion_spad_ready) begin
    if (compute_completion_spad_addr !== 32'h1000 + (word_count/4)*16 + (word_count%4)*4) begin $display("ERROR completion address word=%0d addr=%h",word_count,compute_completion_spad_addr); errors=errors+1; end
    case (word_count%4)
      0: if (compute_completion_spad_wdata[31:16] !== 0) errors=errors+1;
      1: if (compute_completion_spad_wdata[3:0] !== 1) begin $display("ERROR completion status %h",compute_completion_spad_wdata); errors=errors+1; end
      2: if (compute_completion_spad_wdata !== 32'hcafe0000+(word_count/4)) errors=errors+1;
      3: if (compute_completion_spad_wdata !== 32'd16) errors=errors+1;
    endcase
    word_count=word_count+1;
  end

  always @(posedge ctrl_clk) if (ctrl_cpl_valid && ctrl_cpl_ready) begin
    if (ctrl_cpl_packet_version!==8'h01 || ctrl_event_sequence!==16'h120+event_count || ctrl_event_valid!==1 || ctrl_event_error!==0 || ctrl_event_result!==32'hcafe0000+event_count || ctrl_event_elements!==32'd16 || ctrl_cmdq_head!==event_count+1 || ctrl_cplq_tail!==event_count+1 || ctrl_busy!==0) begin
      $display("ERROR event %0d seq=%h result=%h head=%0d tail=%0d busy=%b",event_count,ctrl_event_sequence,ctrl_event_result,ctrl_cmdq_head,ctrl_cplq_tail,ctrl_busy); errors=errors+1;
    end
    event_count=event_count+1;
  end

  task automatic send_commands; integer n; begin for(n=0;n<2;n=n+1) begin @(negedge ctrl_clk); set_cmd(n); ctrl_cmd_valid=1; while(1) begin @(posedge ctrl_clk); if(ctrl_cmd_ready) begin cmd_count=cmd_count+1; @(negedge ctrl_clk); ctrl_cmd_valid=0; break; end end end end endtask

  initial begin
    ctrl_cmd_valid=0; ctrl_cpl_ready=0; ctrl_abort=0; ctrl_submit=0; ctrl_direct_start=0; ctrl_tile_start=0; ctrl_cmd_sequence=0;
    compute_fetch_busy=0; compute_fetch_done=0; compute_fetch_error=0; compute_status_busy=0; compute_status_done=0; compute_status_error=0; compute_status_error_code=0; compute_status_result=0; compute_status_cycles=0; compute_status_elements=0; compute_dma_busy=0; compute_dma_done=0; compute_dma_error=0; compute_dma_error_code=0; compute_completion_spad_ready=0;
    compute_desc_op=0; compute_desc_task_id=0; compute_desc_src0=0; compute_desc_src1=0; compute_desc_dst=0; compute_desc_length=0; compute_desc_m=0; compute_desc_n=0; compute_desc_k=0; compute_desc_shift=0; compute_desc_activation=0; compute_desc_bias_base=0; compute_desc_bias_enable=0; compute_desc_flags=0; compute_desc_aux0=0; compute_desc_src0_stride=0; compute_desc_src1_stride=0; compute_desc_dst_stride=0; compute_desc_batch_count=0; compute_desc_head_count=0; compute_desc_wait_mask=0; compute_desc_signal_mask=0; compute_desc_clear_mask=0; compute_desc_version=0;
    repeat(3) @(posedge ctrl_clk); ctrl_resetn=1; repeat(2) @(posedge compute_clk); compute_resetn=1;
    // Do not use one join_any for the producer and completion wait: command
    // enqueue normally finishes long before the compute path retires either
    // command.  The inner fork owns only success-versus-timeout.
    fork
      begin : command_producer
        send_commands();
      end
      begin : completion_wait
        fork : completion_or_timeout
          begin
            wait(event_count == 2);
          end
          begin
            repeat(3000) @(posedge ctrl_clk);
            $fatal(1,"timeout events=%0d words=%0d launches=%0d",event_count,word_count,launch_count);
          end
        join_any
        disable completion_or_timeout;
      end
    join
    if(errors!=0 || event_count!=2 || word_count!=8 || compute_event_overflow!==0) $fatal(1,"COMMAND PATH FAIL errors=%0d events=%0d words=%0d launches=%0d overflow=%b",errors,event_count,word_count,launch_count,compute_event_overflow);
    $display("DUAL CLOCK COMMAND PATH PASS commands=%0d launches=%0d events=%0d completion_words=%0d errors=%0d overflow=%b",cmd_count,launch_count,event_count,word_count,errors,compute_event_overflow); $finish;
  end
endmodule
