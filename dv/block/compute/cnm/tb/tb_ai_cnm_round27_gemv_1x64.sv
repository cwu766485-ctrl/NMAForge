`timescale 1ns/1ps

// Same-workload CNM endpoint for Round 27.  The logical operation is
// y[c] = sum_k A[k] * W[k,c], with K=N=64.  CNM emits one output channel
// per command row and rereads the shared A vector for each output channel.
module tb_ai_cnm_round27_gemv_1x64;
  reg clk=0, resetn=0, start=0, abort=0;
  reg [15:0] length=4;
  reg gemv_mode=1;
  reg arbiter_stall_mode=0;
  wire [3:0] req, rsp_valid;
  wire [31:0] a0,a1,a2,a3,result,cycles,elements;
  wire [31:0] local_acc,global_reduce,reads,prefetch,computes,rsp_wait;
  wire busy,done,error,spad_valid,spad_write;
  wire [31:0] spad_addr,spad_wdata;
  reg rsp=0;
  reg [3:0] rsp_valid_r=0;
  reg [31:0] rsp_data0=0,rsp_data1=0,rsp_data2=0,rsp_data3=0;
  reg [3:0] ready_mask;
  reg signed [7:0] operand_a [0:63];
  reg signed [7:0] operand_b [0:4095];
  reg signed [31:0] expected [0:63];
  reg signed [31:0] observed [0:63];
  integer writes=0, denied_bank_requests=0, errors=0;
  integer c,k,lane,byte_lane,word_index,accum,cycle_snapshot,ready_lane;
  wire [3:0] cnm_rsp_valid = gemv_mode ? rsp_valid_r : {4{rsp}};
  wire [31:0] cnm_data0 = gemv_mode ? rsp_data0 : 32'h01010101;
  wire [31:0] cnm_data1 = gemv_mode ? rsp_data1 : 32'h01010101;
  wire [31:0] cnm_data2 = gemv_mode ? rsp_data2 : 32'h01010101;
  wire [31:0] cnm_data3 = gemv_mode ? rsp_data3 : 32'h01010101;

  always #5 clk=~clk;

  function [31:0] read_operand_word(input [31:0] address);
    integer lane_index, byte_address, data_index;
    reg [31:0] word_value;
    begin
      word_value=32'd0;
      for(lane_index=0;lane_index<4;lane_index=lane_index+1) begin
        byte_address=address+lane_index;
        if(byte_address>=0 && byte_address<64)
          word_value[lane_index*8+:8]=operand_a[byte_address];
        else if(byte_address>=32'h4000 && byte_address<32'h5000) begin
          data_index=byte_address-32'h4000;
          word_value[lane_index*8+:8]=operand_b[data_index];
        end else
          word_value[lane_index*8+:8]=8'hxx;
      end
      read_operand_word=word_value;
    end
  endfunction

  always @* begin
    if(!arbiter_stall_mode) ready_mask=4'hf;
    else begin
      // Deterministic bank-ready service pattern.  This models admission
      // backpressure at the CNM endpoint; it is not the product SPAD arbiter.
      ready_mask=4'hf;
      for(ready_lane=0;ready_lane<4;ready_lane=ready_lane+1)
        if(((cycles + ready_lane*3) % 7)==0) ready_mask[ready_lane]=1'b0;
    end
  end

  ai_banked_cnm_core dut(
    .clk(clk),.resetn(resetn),.start(start),.abort(abort),.op_mode(8'h21),
    .src0_base(32'h0000),.src1_base(32'h4000),.dst_base(32'h8000),
    .length(length),.m_size(16'd64),.scale_shift(5'd0),.activation(2'd0),.watchdog_limit(32'd0),
    .cnm_req_valid(req),.cnm_addr0(a0),.cnm_addr1(a1),.cnm_addr2(a2),.cnm_addr3(a3),
    .cnm_req_ready(ready_mask),.cnm_rsp_valid(cnm_rsp_valid),
    .cnm_data0(cnm_data0),.cnm_data1(cnm_data1),.cnm_data2(cnm_data2),.cnm_data3(cnm_data3),
    .cnm_parity_error(4'd0),.cnm_protection_error(1'b0),
    .spad_valid(spad_valid),.spad_write(spad_write),.spad_addr(spad_addr),.spad_wdata(spad_wdata),
    .spad_ready(1'b1),.spad_protection_error(1'b0),.busy(busy),.done(done),.error(error),.error_code(),
    .result(result),.cycle_count(cycles),.element_count(elements),
    .local_accumulate_events(local_acc),.global_reduce_events(global_reduce),
    .banked_read_issue_events(reads),.prefetch_events(prefetch),
    .pipeline_compute_events(computes),.response_wait_cycles(rsp_wait)
  );

  // One-cycle, in-order response model per bank.  Data is captured when the
  // request is admitted so later address changes cannot alter the response.
  always @(posedge clk) begin
    if(!resetn) begin
      rsp<=1'b0; rsp_valid_r<=4'b0;
      rsp_data0<=32'd0; rsp_data1<=32'd0; rsp_data2<=32'd0; rsp_data3<=32'd0;
      denied_bank_requests<=0;
    end else begin
      rsp<=|req;
      rsp_valid_r<=4'b0;
      if(gemv_mode) begin
        if(req[0] && ready_mask[0]) begin rsp_valid_r[0]<=1'b1; rsp_data0<=read_operand_word(a0); end
        if(req[1] && ready_mask[1]) begin rsp_valid_r[1]<=1'b1; rsp_data1<=read_operand_word(a1); end
        if(req[2] && ready_mask[2]) begin rsp_valid_r[2]<=1'b1; rsp_data2<=read_operand_word(a2); end
        if(req[3] && ready_mask[3]) begin rsp_valid_r[3]<=1'b1; rsp_data3<=read_operand_word(a3); end
        denied_bank_requests=denied_bank_requests+
          (req[0] && !ready_mask[0])+(req[1] && !ready_mask[1])+
          (req[2] && !ready_mask[2])+(req[3] && !ready_mask[3]);
      end
      if(spad_valid && spad_write) begin
        if(spad_addr>=32'h8000 && spad_addr<32'h8100 && spad_addr[1:0]==0) begin
          word_index=(spad_addr-32'h8000)>>2;
          observed[word_index]=spad_wdata;
          writes<=writes+1;
        end else begin
          $display("ERROR: CNM write outside output range addr=%08x data=%08x",spad_addr,spad_wdata);
          errors<=errors+1;
        end
      end
    end
  end

  task reset_dut;
    begin
      @(negedge clk); resetn=0; start=0; arbiter_stall_mode=0;
      repeat(3) @(negedge clk);
      resetn=1;
    end
  endtask

  task prepare_operands;
    integer ci,ki,expected_sum;
    begin
      writes=0; errors=0; denied_bank_requests=0;
      for(ki=0;ki<64;ki=ki+1)
        operand_a[ki]=((ki*5+3)%13)-6;
      for(ki=0;ki<64;ki=ki+1)
        for(ci=0;ci<64;ci=ci+1)
          operand_b[ci*64+ki]=((ki*7+ci*3+1)%11)-5;
      for(ci=0;ci<64;ci=ci+1) begin
        expected_sum=0;
        for(ki=0;ki<64;ki=ki+1)
          expected_sum=expected_sum+$signed(operand_a[ki])*$signed(operand_b[ci*64+ki]);
        expected[ci]=expected_sum;
        observed[ci]=32'hbad00000+ci;
      end
    end
  endtask

  task run_case(input integer inject_stalls);
    integer i,case_reads,case_prefetch,case_compute,case_reduce,case_cycles;
    integer case_mac_per_cycle_x1000;
    begin
      arbiter_stall_mode=inject_stalls!=0;
      cycle_snapshot=cycles;
      $display("CNM_CASE_START stalls=%0d resetn=%b core_state=%0d cycles=%0d",
               inject_stalls,resetn,dut.state_r,cycles);
      @(negedge clk); start=1;
      @(negedge clk); start=0;
      repeat(200000) begin
        @(negedge clk);
        if(done) disable run_case;
      end
      $fatal(1,"Round27 CNM 1x64x64 timeout inject_stalls=%0d",inject_stalls);
    end
  endtask

  // Keep completion checking outside the bounded wait so every output and
  // every event counter is checked after either run.
  task check_and_report(input integer inject_stalls);
    integer i,case_mac_per_cycle_x1000;
    begin
      if(error || busy || elements!==32'd64 || writes!==64 || global_reduce!==32'd64 ||
         local_acc!==32'd1024 || computes!==32'd1024 || reads!==32'd2048 || prefetch!==32'd768)
        $fatal(1,"CNM status mismatch stall=%0d err=%b busy=%b outputs=%0d writes=%0d local=%0d compute=%0d reads=%0d prefetch=%0d reduce=%0d",
               inject_stalls,error,busy,elements,writes,local_acc,computes,reads,prefetch,global_reduce);
      for(i=0;i<64;i=i+1)
        if(observed[i]!==expected[i])
          $fatal(1,"CNM Golden mismatch stall=%0d output=%0d addr=%08x expected=%08x actual=%08x",
                 inject_stalls,i,32'h8000+i*4,expected[i],observed[i]);
      case_mac_per_cycle_x1000=(4096*1000)/cycles;
      $display("ROUND27_CNM_GEMV_1X64_PASS mode=%s shape=1x64x64 useful_macs=4096 cycles=%0d mac_cycles=%0d mac_per_cycle_x1000=%0d reads=%0d read_bytes=%0d write_bytes=256 prefetch_events=%0d arbiter_denied_bank_requests=%0d response_wait=%0d golden=64/64 PASS memory=one-cycle-behavioral",
               inject_stalls ? "ready-stall" : "always-ready",cycles,computes,
               case_mac_per_cycle_x1000,reads,reads*4,prefetch,denied_bank_requests,rsp_wait);
    end
  endtask

  initial begin
    #0;
    repeat(3) @(negedge clk);
    resetn=1;
    prepare_operands();
    run_case(0);
    check_and_report(0);
    reset_dut();
    prepare_operands();
    run_case(1);
    check_and_report(1);
    if(errors) $fatal(1,"Round27 CNM GEMV errors=%0d",errors);
    $display("PASS: Round27 CNM 1x64x64 same-workload A/B");
    $finish;
  end
endmodule
