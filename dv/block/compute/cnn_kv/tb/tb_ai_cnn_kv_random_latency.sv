`timescale 1ns/1ps

module tb_ai_cnn_kv_random_latency;
  reg clk=0, resetn=0;
  reg conv_start=0, kv_start=0;
  reg conv_abort=0,kv_abort=0,spad_error=0;
  reg [31:0] conv_watchdog=0,kv_watchdog=0;
  reg [7:0] conv_op=8'h16;
  reg [15:0] conv_height=3, conv_width=3;
  reg [31:0] conv_src=0, conv_weight=32'h100, conv_dst=32'h200;
  reg [7:0] kv_op=8'h43;
  reg [31:0] kv_src=32'h100, kv_dst=32'h500;
  reg [15:0] kv_length=1;
  reg [31:0] kv_stride_token=64, kv_stride_head=16, kv_aux=0;

  wire cv,cw,cb,cdone,ce; wire [3:0] cec;
  wire [31:0] ca,cd,cr,ccyc,cel;
  wire kvv,kvw,kvb,kvdone,kve; wire [3:0] kvec;
  wire [31:0] kva,kvd,kvr,kvcyc,kvel;
  wire spad_valid = cb ? cv : kvv;
  wire spad_write = cb ? cw : kvw;
  wire [31:0] spad_addr = cb ? ca : kva;
  wire [31:0] spad_wdata = cb ? cd : kvd;

  reg spad_ready=0, spad_rsp_valid=0;
  reg [31:0] spad_rdata=0;
  reg rsp_pending=0;
  reg [31:0] rsp_pending_data=0;
  reg [3:0] rsp_delay=0;
  // Model the full 512 KiB scratchpad aperture so address and stride checks
  // cover real high offsets instead of silently aliasing through addr[11:2].
  reg [31:0] memory[0:131071];
  integer seed=20261021,initial_seed;
  integer write_count=0, accepted_read_count=0, response_count=0;
  integer ready_stall_cycles=0, max_response_delay=0;
  integer i,trial,idx,head,token,length,offset,timeout;
  integer out_count,out_row,out_col,kr,kc,source_index,weight_index,conv_dw_count=0;
  integer signed input_value, weight_value, expected_conv, got;
  integer signed expected_conv_outputs[0:63];
  integer signed expected_words[0:127];
  reg [31:0] temp;
  integer tinynpu_conv_bench=0;

  function automatic integer spad_word_index(input [31:0] addr);
    begin
      if (addr[1:0] != 2'b00 || addr[31:19] != 0)
        $fatal(1,"illegal testbench SPAD address %08x",addr);
      spad_word_index=addr[18:2];
    end
  endfunction

  always #5 clk=~clk;

  ai_conv3x3_linebuffer_core #(.MAX_WIDTH(8)) conv(
    .clk(clk),.resetn(resetn),.start(conv_start),.abort(conv_abort),.op_mode(conv_op),
    .src0_base(conv_src),.src1_base(conv_weight),.dst_base(conv_dst),
    .height(conv_height),.width(conv_width),.watchdog_limit(conv_watchdog),
    .spad_valid(cv),.spad_write(cw),.spad_addr(ca),.spad_wdata(cd),
    .spad_ready(spad_ready),.spad_rsp_valid(spad_rsp_valid),
    .spad_rdata(spad_rdata),.spad_error(spad_error),.busy(cb),.done(cdone),
    .error(ce),.error_code(cec),.result(cr),.cycle_count(ccyc),
    .element_count(cel));

  ai_kv_cache_engine kv(
    .clk(clk),.resetn(resetn),.start(kv_start),.abort(kv_abort),.op_mode(kv_op),
    .src0_base(kv_src),.dst_base(kv_dst),.length(kv_length),
    .src0_stride(kv_stride_token),.src1_stride(kv_stride_head),.aux0(kv_aux),
    .watchdog_limit(kv_watchdog),.spad_valid(kvv),.spad_write(kvw),.spad_addr(kva),
    .spad_wdata(kvd),.spad_ready(spad_ready),
    .spad_rsp_valid(spad_rsp_valid),.spad_rdata(spad_rdata),
    .spad_error(spad_error),.busy(kvb),.done(kvdone),.error(kve),
    .error_code(kvec),.result(kvr),.cycle_count(kvcyc),.element_count(kvel));

  // A deterministic LFSR drives independent request-ready stalls and ordered
  // registered read-response latency (0..7 cycles). Only one read is pending
  // because both engines issue the next read after consuming its response.
  always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      spad_ready<=0; spad_rsp_valid<=0; spad_rdata<=0;
      rsp_pending<=0; rsp_pending_data<=0; rsp_delay<=0;
      temp<=32'hd192_ed03;
    end else begin
      temp <= {temp[30:0],temp[31]^temp[21]^temp[1]^temp[0]};
      spad_ready <= tinynpu_conv_bench ? 1'b1 : (temp[0] | temp[3]);
      spad_rsp_valid <= 0;
      if (spad_valid && !spad_ready) ready_stall_cycles<=ready_stall_cycles+1;
      if (rsp_pending) begin
        if (rsp_delay==0) begin
          spad_rsp_valid<=1;
          spad_rdata<=rsp_pending_data;
          rsp_pending<=0;
          response_count<=response_count+1;
        end else rsp_delay<=rsp_delay-1'b1;
      end else if (spad_valid && !spad_write && spad_ready) begin
        rsp_pending_data<=memory[spad_word_index(spad_addr)];
        rsp_pending<=1;
        rsp_delay<=tinynpu_conv_bench ? 4'd0 : temp[6:4];
        accepted_read_count<=accepted_read_count+1;
        if (temp[6:4]>max_response_delay) max_response_delay<=temp[6:4];
      end
      if (spad_valid && spad_write && spad_ready) begin
        memory[spad_word_index(spad_addr)]<=spad_wdata;
        write_count<=write_count+1;
      end
    end
  end

  task automatic wait_conv_done;
    begin
      timeout=0;
      while (!cdone && timeout<20000) begin @(negedge clk); timeout=timeout+1; end
      if (!cdone || ce) $fatal(1,"CNN line-buffer timeout/error code=%0d",cec);
      @(negedge clk);
    end
  endtask

  task automatic wait_kv_done;
    begin
      timeout=0;
      while (!kvdone && timeout<20000) begin @(negedge clk); timeout=timeout+1; end
      if (!kvdone || kve) $fatal(1,"KV cache timeout/error code=%0d",kvec);
      @(negedge clk);
    end
  endtask

  task automatic launch_conv;
    begin
      @(negedge clk); conv_start=1;
      @(negedge clk); conv_start=0;
      wait_conv_done();
    end
  endtask

  task automatic launch_kv;
    begin
      @(negedge clk); kv_start=1;
      @(negedge clk); kv_start=0;
      wait_kv_done();
    end
  endtask

  task automatic drain_spad_response;
    begin
      timeout=0;
      while(rsp_pending && timeout<1000) begin @(negedge clk); timeout=timeout+1; end
      if(rsp_pending) $fatal(1,"CNN/KV test left a registered SPAD response pending");
      repeat(2) @(negedge clk);
    end
  endtask

  task automatic expect_conv_error(input [3:0] expected_code,input integer case_id);
    integer writes_before;
    begin
      writes_before=write_count;
      @(negedge clk);conv_start=1;
      @(negedge clk);conv_start=0;
      timeout=0;
      while(!cdone && timeout<20000) begin @(negedge clk);timeout=timeout+1;end
      if(!cdone || !ce || cec!==expected_code || cb)
        $fatal(1,"CNN fault case=%0d done/error/code/busy=%b/%b/%0d/%b expected=%0d",
               case_id,cdone,ce,cec,cb,expected_code);
      if(write_count!=writes_before)
        $fatal(1,"CNN fault case=%0d committed output writes=%0d before=%0d",
               case_id,write_count,writes_before);
      @(negedge clk);spad_error=0;conv_abort=0;conv_watchdog=0;
      drain_spad_response();
    end
  endtask

  task automatic expect_kv_error(input [3:0] expected_code,input integer case_id);
    integer writes_before;
    begin
      writes_before=write_count;
      @(negedge clk);kv_start=1;
      @(negedge clk);kv_start=0;
      timeout=0;
      while(!kvdone && timeout<20000) begin @(negedge clk);timeout=timeout+1;end
      if(!kvdone || !kve || kvec!==expected_code || kvb)
        $fatal(1,"KV fault case=%0d done/error/code/busy=%b/%b/%0d/%b expected=%0d",
               case_id,kvdone,kve,kvec,kvb,expected_code);
      if(write_count!=writes_before)
        $fatal(1,"KV fault case=%0d committed output writes=%0d before=%0d",
               case_id,write_count,writes_before);
      @(negedge clk);spad_error=0;kv_abort=0;kv_watchdog=0;
      drain_spad_response();
    end
  endtask

  task automatic expect_conv_watchdog_priority;
    integer writes_before;
    begin
      writes_before=write_count;
      conv_op=8'h16;conv_height=6;conv_width=6;
      conv_watchdog=1;conv_abort=0;spad_error=0;
      @(negedge clk);conv_start=1;
      @(negedge clk);conv_start=0;
      timeout=0;
      while((!cb || ccyc<conv_watchdog) && timeout<2000) begin
        @(negedge clk);timeout=timeout+1;
      end
      if(!cb || ccyc<conv_watchdog)
        $fatal(1,"Conv watchdog-priority probe did not reach its expiry cycle");
      // Assert both lower-priority faults before the edge that observes an
      // already-expired watchdog. This samples all three causes together.
      conv_abort=1;spad_error=1;
      @(negedge clk);
      timeout=0;
      while(!cdone && timeout<2000) begin @(negedge clk);timeout=timeout+1;end
      if(!cdone || !ce || cec!==4'd4 || cb)
        $fatal(1,"Conv same-cycle watchdog/abort/SPAD priority code=%0d expected=4",cec);
      if(write_count!=writes_before)
        $fatal(1,"Conv same-cycle fault committed output writes=%0d before=%0d",
               write_count,writes_before);
      @(negedge clk);conv_abort=0;conv_watchdog=0;spad_error=0;
      drain_spad_response();
    end
  endtask

  task automatic expect_kv_watchdog_priority;
    integer writes_before;
    begin
      writes_before=write_count;
      kv_op=8'h43;kv_length=64;
      kv_watchdog=1;kv_abort=0;spad_error=0;
      @(negedge clk);kv_start=1;
      @(negedge clk);kv_start=0;
      timeout=0;
      while((!kvb || kvcyc<kv_watchdog) && timeout<2000) begin
        @(negedge clk);timeout=timeout+1;
      end
      if(!kvb || kvcyc<kv_watchdog)
        $fatal(1,"KV watchdog-priority probe did not reach its expiry cycle");
      kv_abort=1;spad_error=1;
      @(negedge clk);
      timeout=0;
      while(!kvdone && timeout<2000) begin @(negedge clk);timeout=timeout+1;end
      if(!kvdone || !kve || kvec!==4'd4 || kvb)
        $fatal(1,"KV same-cycle watchdog/abort/SPAD priority code=%0d expected=4",kvec);
      if(write_count!=writes_before)
        $fatal(1,"KV same-cycle fault committed output writes=%0d before=%0d",
               write_count,writes_before);
      @(negedge clk);kv_abort=0;kv_watchdog=0;spad_error=0;
      drain_spad_response();
    end
  endtask

  task automatic check_reset_recovery;
    integer writes_before;
    begin
      writes_before=write_count;
      @(negedge clk);conv_start=1;
      @(negedge clk);conv_start=0;
      if(!cb) $fatal(1,"CNN reset probe failed to enter busy");
      // Reset wins over simultaneously asserted lifecycle and SPAD faults.
      conv_abort=1;spad_error=1;
      resetn=0; #1;
      if(cb || cdone || ce || kvb || kvdone || kve)
        $fatal(1,"CNN/KV reset did not clear both engines");
      repeat(3) @(negedge clk);resetn=1;conv_abort=0;spad_error=0;
      repeat(2) @(negedge clk);
      if(write_count!=writes_before) $fatal(1,"reset probe committed an output");
      conv_height=3;conv_width=3;conv_watchdog=0;spad_error=0;
      for(i=0;i<9;i=i+1) begin memory[spad_word_index(conv_src)+i]=i-4;memory[spad_word_index(conv_weight)+i]=1;end
      expected_conv=0;
      for(i=0;i<9;i=i+1) expected_conv=expected_conv+i-4;
      launch_conv();
      if($signed(memory[spad_word_index(conv_dst)])!==expected_conv || ce)
        $fatal(1,"CNN did not recover after in-flight reset");

      // Reset KV independently while it is active, then verify a fresh cache
      // write command still reaches the selected offset and preserves data.
      kv_op=8'h43;kv_length=3;kv_src=32'h100;kv_dst=32'h500;kv_aux=0;
      kv_stride_token=64;kv_stride_head=16;
      for(i=0;i<3;i=i+1) begin
        expected_words[i]=32'hcafe_1000+i;
        memory[spad_word_index(kv_src)+i]=expected_words[i];
      end
      writes_before=write_count;
      @(negedge clk);kv_start=1;
      @(negedge clk);kv_start=0;
      if(!kvb) $fatal(1,"KV reset probe did not enter busy");
      kv_abort=1;spad_error=1;
      resetn=0;#1;
      if(cb || cdone || ce || kvb || kvdone || kve)
        $fatal(1,"in-flight KV reset did not clear both engines");
      repeat(3) @(negedge clk);resetn=1;kv_abort=0;spad_error=0;
      repeat(2) @(negedge clk);
      if(write_count!=writes_before) $fatal(1,"KV reset probe committed an output");
      write_count=0;launch_kv();
      if(kvel!==3 || write_count!=3 || kvr!==expected_words[2])
        $fatal(1,"KV did not recover after in-flight reset");
      for(i=0;i<3;i=i+1)
        if(memory[spad_word_index(kv_dst)+i]!==expected_words[i])
          $fatal(1,"KV recovery data i=%0d got=%08x expected=%08x",
                 i,memory[(kv_dst>>2)+i],expected_words[i]);
    end
  endtask

  task automatic run_kv_roundtrip(input integer trial_id);
    integer expected_offset;
    begin
      expected_offset=head*kv_stride_head+token*kv_stride_token;
      kv_length=length;
      // aux0[15:0] is token; aux0[31:16] is head. src0_stride is the
      // token byte stride and src1_stride is the head byte stride.
      kv_aux={head[15:0],token[15:0]};
      kv_src=32'h0001_0000;
      kv_dst=32'h0003_0000;
      for (i=0;i<length;i=i+1) begin
        input_value=$random(seed);
        expected_words[i]=input_value;
        memory[spad_word_index(kv_src)+i]=input_value;
      end
      write_count=0;
      kv_op=8'h43;
      launch_kv();
      if (kvel!==length || write_count!=length || kvr!==expected_words[length-1])
        $fatal(1,"KV write trial=%0d elements=%0d writes=%0d expected=%0d result=%08x last=%08x",
               trial_id,kvel,write_count,length,kvr,expected_words[length-1]);
      for (i=0;i<length;i=i+1)
        if (memory[spad_word_index(kv_dst+expected_offset)+i]!==expected_words[i])
          $fatal(1,"KV write trial=%0d i=%0d got=%08x expected=%08x",
                 trial_id,i,memory[spad_word_index(kv_dst+expected_offset)+i],expected_words[i]);

      kv_op=8'h44;
      kv_src=kv_dst;
      kv_dst=32'h0007_0000;
      write_count=0;
      launch_kv();
      if (kvel!==length || write_count!=length || kvr!==expected_words[length-1])
        $fatal(1,"KV read trial=%0d elements=%0d writes=%0d expected=%0d result=%08x last=%08x",
               trial_id,kvel,write_count,length,kvr,expected_words[length-1]);
      for (i=0;i<length;i=i+1)
        if (memory[spad_word_index(kv_dst)+i]!==expected_words[i])
          $fatal(1,"KV read trial=%0d i=%0d got=%08x expected=%08x",
                 trial_id,i,memory[spad_word_index(kv_dst)+i],expected_words[i]);
    end
  endtask

  task automatic run_late_conv_fault;
    integer reads_before,writes_before,outputs_before;
    begin
      conv_height=6;conv_width=6;conv_op=8'h16;
      conv_src=32'h0000_1000;conv_weight=32'h0000_5000;conv_dst=32'h0000_9000;
      for(i=0;i<36;i=i+1) memory[spad_word_index(conv_src)+i]=1;
      for(i=0;i<9;i=i+1) memory[spad_word_index(conv_weight)+i]=1;
      for(i=0;i<16;i=i+1) memory[spad_word_index(conv_dst)+i]=32'hface_cafe;
      reads_before=accepted_read_count;writes_before=write_count;
      @(negedge clk);conv_start=1;
      @(negedge clk);conv_start=0;
      // Nine weights and thirty-one pixels have been accepted: the engine
      // has completed twelve output windows and is working on the final row.
      timeout=0;
      while(accepted_read_count < reads_before+40 && timeout<20000) begin
        @(negedge clk);timeout=timeout+1;
      end
      if(accepted_read_count != reads_before+40)
        $fatal(1,"CNN late-fault injection did not reach the requested read frontier");
      outputs_before=write_count-writes_before;
      if(outputs_before!=12 || cel!=12)
        $fatal(1,"CNN late-fault frontier outputs=%0d elements=%0d",outputs_before,cel);
      spad_error=1;
      timeout=0;
      while(!cdone && timeout<20000) begin @(negedge clk);timeout=timeout+1;end
      if(!cdone || !ce || cec!=4'd7 || cb || cel!=outputs_before ||
         write_count-writes_before!=outputs_before)
        $fatal(1,"CNN late fault failed done/error/code/elements/writes=%b/%b/%0d/%0d/%0d",
               cdone,ce,cec,cel,write_count-writes_before);
      for(i=0;i<outputs_before;i=i+1)
        if($signed(memory[spad_word_index(conv_dst)+i])!=9)
          $fatal(1,"CNN late-fault committed prefix[%0d]=%0d expected=9",i,
                 $signed(memory[spad_word_index(conv_dst)+i]));
      for(i=outputs_before;i<16;i=i+1)
        if(memory[spad_word_index(conv_dst)+i]!==32'hface_cafe)
          $fatal(1,"CNN late-fault modified output suffix[%0d]=%08x",i,
                 memory[spad_word_index(conv_dst)+i]);
      spad_error=0;drain_spad_response();
    end
  endtask

  task automatic run_late_kv_fault;
    integer reads_before,writes_before,expected_offset,dst_index;
    begin
      kv_length=64;kv_op=8'h43;kv_aux={16'd23,16'd12};
      kv_stride_token=32'd252;kv_stride_head=32'd1020;
      kv_src=32'h0001_0000;kv_dst=32'h0002_0000;
      for(i=0;i<64;i=i+1) memory[spad_word_index(kv_src)+i]=32'hca00_0000+i;
      expected_offset=23*1020+12*252;
      dst_index=spad_word_index(kv_dst+expected_offset);
      for(i=0;i<64;i=i+1) memory[dst_index+i]=32'hface_cafe;
      reads_before=accepted_read_count;writes_before=write_count;
      @(negedge clk);kv_start=1;
      @(negedge clk);kv_start=0;
      timeout=0;
      while(accepted_read_count < reads_before+24 && timeout<20000) begin
        @(negedge clk);timeout=timeout+1;
      end
      if(accepted_read_count != reads_before+24 || write_count-writes_before!=23 ||
         kvel!=23)
        $fatal(1,"KV late-fault frontier reads=%0d writes=%0d elements=%0d",
               accepted_read_count-reads_before,write_count-writes_before,kvel);
      spad_error=1;
      timeout=0;
      while(!kvdone && timeout<20000) begin @(negedge clk);timeout=timeout+1;end
      if(!kvdone || !kve || kvec!=4'd7 || kvb || kvel!=23 ||
         write_count-writes_before!=23)
        $fatal(1,"KV late fault failed done/error/code/elements/writes=%b/%b/%0d/%0d/%0d",
               kvdone,kve,kvec,kvel,write_count-writes_before);
      for(i=0;i<23;i=i+1)
        if(memory[dst_index+i]!==32'hca00_0000+i)
          $fatal(1,"KV late-fault prefix[%0d]=%08x expected=%08x",
                 i,memory[dst_index+i],32'hca00_0000+i);
      for(i=23;i<64;i=i+1)
        if(memory[dst_index+i]!==32'hface_cafe)
          $fatal(1,"KV late-fault modified output suffix[%0d]=%08x",i,
                 memory[dst_index+i]);
      spad_error=0;drain_spad_response();
    end
  endtask

  initial begin
    if ($value$plusargs("SEED=%d",seed)) begin end
    initial_seed=seed;
    tinynpu_conv_bench=$test$plusargs("TINYNPU_CONV_MATCH_ONLY");
    for (i=0;i<131072;i=i+1) memory[i]=0;
    repeat (4) @(negedge clk); resetn=1;

    if(tinynpu_conv_bench) begin
      conv_height=3;conv_width=3;conv_op=8'h16;
      conv_src=32'h0000_0000;conv_weight=32'h0000_0100;conv_dst=32'h0000_0200;
      conv_watchdog=0;write_count=0;accepted_read_count=0;response_count=0;
      for(i=0;i<9;i=i+1) begin
        input_value=((i*2+1)%9)-4;
        weight_value=((i*2+5)%9)-4;
        memory[spad_word_index(conv_src)+i]=input_value;
        memory[spad_word_index(conv_weight)+i]=weight_value;
      end
      expected_conv=0;
      for(i=0;i<9;i=i+1)
        expected_conv=expected_conv+
          $signed(memory[spad_word_index(conv_src)+i][7:0])*
          $signed(memory[spad_word_index(conv_weight)+i][7:0]);
      @(negedge clk);conv_start=1;
      @(negedge clk);conv_start=0;
      wait_conv_done();
      if(cel!==1 || write_count!==1 ||
         $signed(memory[spad_word_index(conv_dst)])!==expected_conv ||
         $signed(cr)!==expected_conv)
        $fatal(1,"TinyNPU-mapped CNN mismatch result=%0d memory=%0d expected=%0d elements=%0d writes=%0d",
               $signed(cr),$signed(memory[spad_word_index(conv_dst)]),expected_conv,cel,write_count);
      $display("CNN_TINYNPU_MATCH_PASS seed=%0d shape=3x3x1 filter=3x3x1 useful_macs=9 cycles=%0d spad_reads=%0d spad_read_bytes=%0d spad_writes=%0d spad_write_bytes=%0d output=%0d",
               initial_seed,ccyc,accepted_read_count,accepted_read_count*4,
               write_count,write_count*4,$signed(cr));
      $finish;
    end

    // Convolution: alternate standard/depthwise opcodes, vary spatial shape,
    // and check every sliding 3x3 output as the line buffers wrap rows.
    for (trial=0;trial<24;trial=trial+1) begin
      conv_height=3+($random(seed)&3);
      conv_width=3+($random(seed)&3);
      conv_op=(trial&1)?8'h17:8'h16;
      // Keep the three regions disjoint while varying their low address bits
      // over a full 4 KiB range.
      conv_src=($random(seed)&1023)<<2;
      conv_weight=32'h0000_4000+(($random(seed)&1023)<<2);
      conv_dst=32'h0000_8000+(($random(seed)&1023)<<2);
      if(conv_op==8'h17) conv_dw_count=conv_dw_count+1;
      for (i=0;i<conv_height*conv_width;i=i+1) begin
        input_value=($random(seed)%33)-16;
        memory[spad_word_index(conv_src)+i]=input_value;
      end
      for (i=0;i<9;i=i+1) begin
        weight_value=($random(seed)%17)-8;
        memory[spad_word_index(conv_weight)+i]=weight_value;
      end
      out_count=0;
      for(out_row=0;out_row<conv_height-2;out_row=out_row+1)
        for(out_col=0;out_col<conv_width-2;out_col=out_col+1) begin
          expected_conv=0;
          for(kr=0;kr<3;kr=kr+1)
            for(kc=0;kc<3;kc=kc+1) begin
              source_index=spad_word_index(conv_src)+(out_row+kr)*conv_width+out_col+kc;
              weight_index=spad_word_index(conv_weight)+kr*3+kc;
              expected_conv=expected_conv+
                $signed(memory[source_index][7:0])*$signed(memory[weight_index][7:0]);
            end
          expected_conv_outputs[out_count]=expected_conv;
          out_count=out_count+1;
        end
      write_count=0;
      launch_conv();
      if(cel!==out_count || write_count!=out_count ||
         $signed(cr)!==expected_conv_outputs[out_count-1])
        $fatal(1,"CNN trial=%0d op=%02x shape=%0dx%0d result=%0d/%0d elements=%0d/%0d writes=%0d/%0d",
               trial,conv_op,conv_height,conv_width,$signed(cr),
               expected_conv_outputs[out_count-1],cel,out_count,write_count,out_count);
      for(i=0;i<out_count;i=i+1) begin
        got=$signed(memory[spad_word_index(conv_dst)+i]);
        if(got!==expected_conv_outputs[i])
          $fatal(1,"CNN trial=%0d op=%02x output=%0d got=%0d expected=%0d",
                 trial,conv_op,i,got,expected_conv_outputs[i]);
      end
    end

    // KV write/read with varied length, head/token, and full 10-bit aligned
    // byte-stride variation. Address checks cover the full scratchpad model.
    for (trial=0;trial<24;trial=trial+1) begin
      length=1+($random(seed)&127);
      head=$random(seed)&63;
      token=$random(seed)&63;
      kv_stride_head=4*($random(seed)&255);
      kv_stride_token=4*($random(seed)&255);
      run_kv_roundtrip(trial);
    end

    // Deterministic stride/address boundaries: zero strides, minimum aligned
    // strides, and a high head/token pair whose final vector ends near the
    // top of the 512 KiB scratchpad aperture.
    head=0;token=0;kv_stride_head=0;kv_stride_token=0;length=1;
    run_kv_roundtrip(100);
    head=1;token=1;kv_stride_head=4;kv_stride_token=4;length=16;
    run_kv_roundtrip(101);
    head=255;token=255;kv_stride_head=32'd1020;kv_stride_token=32'd252;
    length=128;run_kv_roundtrip(102);

    // Exercise the error exits that the arithmetic/round-trip loop does not
    // reach: invalid configuration, SPAD error, abort, watchdog, and reset.
    conv_height=2;conv_width=3;expect_conv_error(4'd1,0);
    conv_op=8'hff;conv_height=3;conv_width=3;expect_conv_error(4'd2,1);
    conv_op=8'h16;spad_error=1;expect_conv_error(4'd7,2);
    spad_error=0;conv_abort=1;expect_conv_error(4'd3,3);
    conv_abort=0;conv_watchdog=1;expect_conv_error(4'd4,4);
    conv_watchdog=0;

    // Simultaneous SPAD failure and abort follows the RTL's documented
    // priority: watchdog, then abort, then SPAD error.
    spad_error=1;conv_abort=1;expect_conv_error(4'd3,5);
    expect_conv_watchdog_priority();
    run_late_conv_fault();

    kv_length=0;expect_kv_error(4'd1,0);
    kv_length=2;kv_op=8'h7f;expect_kv_error(4'd2,1);
    kv_op=8'h43;spad_error=1;expect_kv_error(4'd7,2);
    spad_error=0;kv_abort=1;expect_kv_error(4'd3,3);
    kv_abort=0;kv_watchdog=1;expect_kv_error(4'd4,4);
    kv_watchdog=0;
    spad_error=1;kv_abort=1;expect_kv_error(4'd3,5);
    expect_kv_watchdog_priority();
    run_late_kv_fault();
    check_reset_recovery();

    if (accepted_read_count!=response_count || rsp_pending)
      $fatal(1,"SPAD response accounting reads=%0d responses=%0d pending=%b",
             accepted_read_count,response_count,rsp_pending);
    if (ready_stall_cycles==0 || max_response_delay==0)
      $fatal(1,"SPAD latency stress did not exercise ready or response stalls");
    $display("CNN_KV_RANDOM_LATENCY_PASS conv_cases=25 conv_dw_cases=%0d kv_roundtrips=27 conv_faults=6 kv_faults=7 late_faults=2 reset_fault_combo=1 reset_recovery=1 seed=%0d reads=%0d responses=%0d max_rsp_delay=%0d ready_stalls=%0d",
             conv_dw_count,initial_seed,accepted_read_count,response_count,max_response_delay,ready_stall_cycles);
    $finish;
  end
endmodule
