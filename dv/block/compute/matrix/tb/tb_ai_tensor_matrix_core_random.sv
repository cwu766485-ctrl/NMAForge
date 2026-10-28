`timescale 1ns/1ps

`ifndef MATRIX_ARRAY_SIZE
`define MATRIX_ARRAY_SIZE 16
`endif
`ifndef MATRIX_MAX_OUTSTANDING_READS
`define MATRIX_MAX_OUTSTANDING_READS 4
`endif
`ifndef MATRIX_A_TILE_CACHE_ENABLE
`define MATRIX_A_TILE_CACHE_ENABLE 1
`endif
`ifndef MATRIX_NEXT_K_PREFETCH_ENABLE
`define MATRIX_NEXT_K_PREFETCH_ENABLE 1
`endif

// Full-core A3 transaction test. Operand words are returned through a
// registered four-bank model; bias/scalar traffic uses a separate registered
// SPAD model and aligned output rows use the line-write port.
module tb_ai_tensor_matrix_core_random;
  localparam integer PHYSICAL_ARRAY_SIZE = `MATRIX_ARRAY_SIZE;
  localparam integer MAX_OUTSTANDING_READS = `MATRIX_MAX_OUTSTANDING_READS;
  localparam integer A_TILE_CACHE_ENABLE = `MATRIX_A_TILE_CACHE_ENABLE;
  localparam integer NEXT_K_PREFETCH_ENABLE = `MATRIX_NEXT_K_PREFETCH_ENABLE;
  localparam integer BANK_RESPONSE_QUEUE_DEPTH = 4;
  localparam [31:0] SRC0_BASE = 32'h0000_0100;
  localparam [31:0] SRC1_BASE = 32'h0000_4000;
  localparam [31:0] BIAS_BASE = 32'h0000_8000;
  localparam [31:0] DST_BASE  = 32'h0001_0000;
  localparam [3:0] ERR_CONFIG=1, ERR_OP=2, ERR_ABORT=3, ERR_WATCHDOG=4,
                   ERR_PARITY=5, ERR_PROTECTION=6;

  reg clk=0, resetn=0, start=0, abort=0;
  reg [7:0] op_mode=8'h30;
  reg [31:0] src0_base=SRC0_BASE, src1_base=SRC1_BASE;
  reg [31:0] bias_base=BIAS_BASE, dst_base=DST_BASE;
  reg [15:0] m_size=4, n_size=4, k_words=1;
  reg [31:0] instance_count=1;
  reg [31:0] src0_batch_stride=0,src1_batch_stride=0,dst_batch_stride=0;
  reg transpose_a=0,transpose_b=0,bias_enable=0;
  reg [4:0] scale_shift=0;
  reg [1:0] activation=0;
  reg [31:0] watchdog_limit=0;

  wire [31:0] bank0_data,bank1_data,bank2_data,bank3_data;
  wire [3:0] bank_parity_error;
  wire banked_read_valid;
  wire [31:0] banked_addr;
  reg banked_ready=0,banked_rsp_valid=0;
  wire banked_protection_error;
  wire spad_valid,spad_write;
  wire [31:0] spad_addr,spad_wdata;
  reg spad_ready=0,spad_rsp_valid=0;
  wire [31:0] spad_rdata;
  wire spad_parity_error,spad_protection_error;
  wire line_valid,line_write;
  wire [31:0] line_addr;
  wire [127:0] line_wdata;
  wire [15:0] line_wstrb;
  reg line_ready=0;
  wire line_protection_error;
  wire busy,done,error;
  wire [3:0] error_code;
  wire [31:0] result,cycle_count,element_count;
  wire perf_mac_active,perf_banked_wait;

  reg [31:0] bank_mem [0:3][0:8191];
  reg [31:0] bias_mem [0:65535];
  reg [31:0] output_mem [0:65535];
  reg [31:0] expected_mem [0:65535];
  reg signed [7:0] logical_a [0:3][0:31][0:127];
  reg signed [7:0] logical_b [0:3][0:127][0:31];
  reg signed [31:0] logical_bias [0:31];

  reg [31:0] pending_bank_data [0:3];
  reg [31:0] bank_response_data_fifo [0:BANK_RESPONSE_QUEUE_DEPTH-1][0:3];
  integer bank_response_delay_fifo [0:BANK_RESPONSE_QUEUE_DEPTH-1];
  integer bank_response_issue_fifo [0:BANK_RESPONSE_QUEUE_DEPTH-1];
  reg [31:0] pending_spad_data;
  integer bank_response_queue_count=0;
  integer bank_response_wr_ptr=0,bank_response_rd_ptr=0;
  integer bank_outstanding_highwater=0;
  integer bank_latency_idx,bank_latency_slot;
  reg force_banked_ready=0,force_bank_response_delay=0;
  reg force_zero_bank_latency=0,force_line_stall=0;
  integer spad_delay=0;
  integer pending_bank_issue=0;
  integer bank_parity_target_issue=0;
  reg prefetch_parity_response_seen=0;
  reg watchdog_during_prefetch_seen=0;
  reg prefetch_handoff_seen=0;
  reg mac_to_a_req_seen=0;
  integer prefetch_buffer_seen_mask=0;
  reg pending_spad=0;
  wire pending_bank = (bank_response_queue_count != 0);
  wire bank_response_due = (bank_response_queue_count != 0) &&
                           (bank_response_delay_fifo[bank_response_rd_ptr] == 0);
  wire bank_request_accept = banked_read_valid && banked_ready;
  reg [31:0] rng=32'h7ac4_01d3;
  integer bank_read_count=0,bank_response_count=0;
  integer spad_read_count=0,spad_response_count=0;
  integer bank_stall_count=0,spad_stall_count=0,line_stall_count=0;
  integer line_write_count=0,scalar_write_count=0;
  integer seed=20261021,initial_seed;
  integer benchmark_mode=0;

  always @(posedge clk or negedge resetn) begin
    if(!resetn)
      mac_to_a_req_seen <= 1'b0;
    else if(!NEXT_K_PREFETCH_ENABLE && (dut.state_r==8) &&
            (dut.lane_r==2'd3) && !dut.last_k_group)
      mac_to_a_req_seen <= 1'b1;
  end

  reg inject_bank_parity=0,inject_spad_parity=0;
  reg inject_bank_protection=0,inject_spad_protection=0;
  reg inject_line_protection=0;
  reg [31:0] bank_protection_addr=0,spad_protection_addr=0;
  reg [31:0] line_protection_addr=0;

  integer cfg_m,cfg_n,cfg_kw,cfg_instances,cfg_ta,cfg_tb,cfg_bias;
  integer cfg_shift,cfg_act,cfg_pad_a,cfg_pad_b,cfg_pad_dst,cfg_unaligned;
  integer rand_state=20261021;
  integer inst,row,col,k,tile_row,tile_col,kg,lane,byte_index;
  integer a_stride,b_stride,d_stride,addr,line_index,word_index;
  integer signed accum,post_value;
  integer timeout_cycles,case_count=0,fault_count=0;
  integer expected_prefetch_count;
  integer mac_cycle_count=0,case_mac_snapshot=0;
  integer case_bank_snapshot=0,case_bank_stall_snapshot=0;
  integer case_line_stall_snapshot=0;
  reg [31:0] packed_word;

  always #5 clk=~clk;

  assign banked_protection_error = inject_bank_protection &&
      banked_read_valid && (banked_addr==bank_protection_addr);
  assign spad_protection_error = inject_spad_protection && spad_valid &&
      (spad_addr==spad_protection_addr);
  assign line_protection_error = inject_line_protection && line_valid &&
      (line_addr==line_protection_addr);
  assign spad_rdata = pending_spad_data;
  assign spad_parity_error = inject_spad_parity && spad_rsp_valid;
  assign bank0_data = pending_bank_data[0];
  assign bank1_data = pending_bank_data[1];
  assign bank2_data = pending_bank_data[2];
  assign bank3_data = pending_bank_data[3];
  assign bank_parity_error = (inject_bank_parity && banked_rsp_valid &&
                               pending_bank_issue==bank_parity_target_issue) ?
                               4'b0001 : 4'b0000;

  ai_tensor_matrix_core #(
    .ARRAY_SIZE(PHYSICAL_ARRAY_SIZE),
    .MAX_OUTSTANDING_READS(MAX_OUTSTANDING_READS),
    .ENABLE_A_TILE_CACHE(A_TILE_CACHE_ENABLE),
    .ENABLE_NEXT_K_PREFETCH(NEXT_K_PREFETCH_ENABLE)
  ) dut(
    .clk(clk),.resetn(resetn),.start(start),.abort(abort),.op_mode(op_mode),
    .src0_base(src0_base),.src1_base(src1_base),.bias_base(bias_base),.dst_base(dst_base),
    .m_size(m_size),.n_size(n_size),.k_words(k_words),.instance_count(instance_count),
    .src0_batch_stride(src0_batch_stride),.src1_batch_stride(src1_batch_stride),
    .dst_batch_stride(dst_batch_stride),.transpose_a(transpose_a),.transpose_b(transpose_b),
    .bias_enable(bias_enable),.scale_shift(scale_shift),.activation(activation),
    .watchdog_limit(watchdog_limit),
    .bank0_data(bank0_data),.bank1_data(bank1_data),.bank2_data(bank2_data),.bank3_data(bank3_data),
    .bank_parity_error(bank_parity_error),.banked_read_valid(banked_read_valid),
    .banked_addr(banked_addr),.banked_ready(banked_ready),.banked_rsp_valid(banked_rsp_valid),
    .banked_protection_error(banked_protection_error),
    .spad_valid(spad_valid),.spad_write(spad_write),.spad_addr(spad_addr),.spad_wdata(spad_wdata),
    .spad_ready(spad_ready),.spad_rsp_valid(spad_rsp_valid),.spad_rdata(spad_rdata),
    .spad_parity_error(spad_parity_error),.spad_protection_error(spad_protection_error),
    .line_valid(line_valid),.line_write(line_write),.line_addr(line_addr),.line_wdata(line_wdata),
    .line_wstrb(line_wstrb),.line_ready(line_ready),.line_protection_error(line_protection_error),
    .busy(busy),.done(done),.error(error),.error_code(error_code),.result(result),
    .cycle_count(cycle_count),.element_count(element_count),
    .perf_mac_active(perf_mac_active),.perf_banked_wait(perf_banked_wait));

  // Registered scratchpad response models. Ready and response latency vary
  // independently; the core observes the response and data on the next edge.
  always @(posedge clk or negedge resetn) begin
    if(!resetn) begin
      rng<=32'h7ac4_01d3;
      mac_cycle_count<=0;
      banked_ready<=0;banked_rsp_valid<=0;bank_response_queue_count<=0;
      bank_response_wr_ptr<=0;bank_response_rd_ptr<=0;
      bank_outstanding_highwater<=0;
      pending_bank_issue<=0;bank_read_count<=0;bank_response_count<=0;
      pending_bank_data[0]<=0;pending_bank_data[1]<=0;
      pending_bank_data[2]<=0;pending_bank_data[3]<=0;
      spad_ready<=0;spad_rsp_valid<=0;pending_spad<=0;spad_delay<=0;
      pending_spad_data<=0;spad_read_count<=0;spad_response_count<=0;
      line_ready<=0;
      line_write_count<=0;scalar_write_count<=0;
    end else begin
      if(perf_mac_active) mac_cycle_count<=mac_cycle_count+1;
      if(dut.prefetch_active &&
         (dut.prefetch_buffer_r==dut.compute_buffer_r))
        $fatal(1,"Matrix prefetch overwrote active compute buffer k=%0d buffer=%0d",
               dut.prefetch_k_group_r,dut.prefetch_buffer_r);
      if(dut.prefetch_kick)
        prefetch_buffer_seen_mask[dut.prefetch_kick_buffer] <= 1'b1;
      if((dut.state_r==8) && (dut.lane_r==2'd3) &&
         dut.prefetch_valid_r[~dut.compute_buffer_r])
        prefetch_handoff_seen<=1'b1;
      if(banked_rsp_valid && inject_bank_parity &&
         (pending_bank_issue==bank_parity_target_issue) &&
         dut.prefetch_active && dut.response_buffer)
        prefetch_parity_response_seen<=1'b1;
      if(dut.watchdog_expired && dut.prefetch_active)
        watchdog_during_prefetch_seen<=1'b1;
      rng<={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
      banked_ready<=force_banked_ready ? 1'b1 : (rng[0]|rng[3]);
      spad_ready<=rng[2]|rng[5];
      line_ready<=force_line_stall ? 1'b0 : (rng[1]|rng[4]);
      banked_rsp_valid<=0;spad_rsp_valid<=0;

      if(banked_read_valid && !banked_ready) bank_stall_count<=bank_stall_count+1;
      if(spad_valid && !spad_ready) spad_stall_count<=spad_stall_count+1;
      if(line_valid && !line_ready) line_stall_count<=line_stall_count+1;

      if(bank_response_queue_count>0) begin
        if(bank_response_due) begin
          banked_rsp_valid<=1;
          pending_bank_issue<=bank_response_issue_fifo[bank_response_rd_ptr];
          pending_bank_data[0]<=bank_response_data_fifo[bank_response_rd_ptr][0];
          pending_bank_data[1]<=bank_response_data_fifo[bank_response_rd_ptr][1];
          pending_bank_data[2]<=bank_response_data_fifo[bank_response_rd_ptr][2];
          pending_bank_data[3]<=bank_response_data_fifo[bank_response_rd_ptr][3];
          if(bank_response_rd_ptr==BANK_RESPONSE_QUEUE_DEPTH-1)
            bank_response_rd_ptr<=0;
          else bank_response_rd_ptr<=bank_response_rd_ptr+1;
          bank_response_count<=bank_response_count+1;
        end
      end
      // Age all accepted requests in parallel. Responses remain in request
      // order even if a younger entry's fixed latency expires first.
      for(bank_latency_idx=0;bank_latency_idx<BANK_RESPONSE_QUEUE_DEPTH;
          bank_latency_idx=bank_latency_idx+1) begin
        if(bank_latency_idx<bank_response_queue_count) begin
          bank_latency_slot=bank_response_rd_ptr+bank_latency_idx;
          if(bank_latency_slot>=BANK_RESPONSE_QUEUE_DEPTH)
            bank_latency_slot=bank_latency_slot-BANK_RESPONSE_QUEUE_DEPTH;
          if(bank_response_delay_fifo[bank_latency_slot]>0)
            bank_response_delay_fifo[bank_latency_slot]<=
                bank_response_delay_fifo[bank_latency_slot]-1;
        end
      end
      if(bank_request_accept) begin
        if((bank_response_queue_count==BANK_RESPONSE_QUEUE_DEPTH) &&
           !bank_response_due)
          $fatal(1,"banked responder queue overflow state=%0d addr=%08x",
                 dut.state_r,banked_addr);
        bank_response_data_fifo[bank_response_wr_ptr][0]<=
            bank_mem[0][(banked_addr>>4)&13'h1fff];
        bank_response_data_fifo[bank_response_wr_ptr][1]<=
            bank_mem[1][(banked_addr>>4)&13'h1fff];
        bank_response_data_fifo[bank_response_wr_ptr][2]<=
            bank_mem[2][(banked_addr>>4)&13'h1fff];
        bank_response_data_fifo[bank_response_wr_ptr][3]<=
            bank_mem[3][(banked_addr>>4)&13'h1fff];
        bank_response_issue_fifo[bank_response_wr_ptr]<=bank_read_count;
        bank_response_delay_fifo[bank_response_wr_ptr]<=
            (benchmark_mode || force_zero_bank_latency) ? 0 :
            (force_bank_response_delay ? 3 : rng[6:5]);
        if(bank_response_wr_ptr==BANK_RESPONSE_QUEUE_DEPTH-1)
          bank_response_wr_ptr<=0;
        else bank_response_wr_ptr<=bank_response_wr_ptr+1;
        bank_read_count<=bank_read_count+1;
      end
      case ({bank_request_accept,bank_response_due})
        2'b10: bank_response_queue_count<=bank_response_queue_count+1;
        2'b01: bank_response_queue_count<=bank_response_queue_count-1;
        default: bank_response_queue_count<=bank_response_queue_count;
      endcase
      if(bank_response_queue_count + bank_request_accept - bank_response_due >
         bank_outstanding_highwater)
        bank_outstanding_highwater<=bank_response_queue_count +
                                    bank_request_accept - bank_response_due;

      if(pending_spad) begin
        if(spad_delay==0) begin
          spad_rsp_valid<=1;pending_spad<=0;
          spad_response_count<=spad_response_count+1;
        end else spad_delay<=spad_delay-1;
      end
      if(spad_valid && spad_ready && !spad_write && !spad_protection_error) begin
        if(pending_spad) $fatal(1,"SPAD read overlapped an undelivered response");
        pending_spad_data<=bias_mem[spad_addr>>2];
        pending_spad<=1;spad_delay<=rng[8:7];spad_read_count<=spad_read_count+1;
      end
      if(spad_valid && spad_ready && spad_write && !spad_protection_error) begin
        output_mem[spad_addr>>2]<=spad_wdata;
        scalar_write_count<=scalar_write_count+1;
      end
      if(line_valid && line_ready && !line_protection_error) begin
        if(line_wstrb!==16'hffff) $fatal(1,"matrix line write strobe mismatch %h",line_wstrb);
        output_mem[line_addr>>2]<=line_wdata[31:0];
        output_mem[(line_addr>>2)+1]<=line_wdata[63:32];
        output_mem[(line_addr>>2)+2]<=line_wdata[95:64];
        output_mem[(line_addr>>2)+3]<=line_wdata[127:96];
        line_write_count<=line_write_count+1;
      end
    end
  end

  function automatic [31:0] pack4(input integer b0,b1,b2,b3);
    begin pack4={b3[7:0],b2[7:0],b1[7:0],b0[7:0]}; end
  endfunction

  task automatic prepare_case(
      input integer m,input integer n,input integer kw,input integer batches,
      input integer ta,input integer tb,input integer use_bias,
      input integer shift,input integer act,input integer padded,input integer unaligned);
    integer local_a_stride,local_b_stride,local_dst_stride;
    integer local_addr,local_index,local_word;
    integer rr,cc,ll,tt,ii,kk;
    integer signed value;
    integer signed result_value;
    begin
      cfg_m=m;cfg_n=n;cfg_kw=kw;cfg_instances=batches;cfg_ta=ta;cfg_tb=tb;
      cfg_bias=use_bias;cfg_shift=shift;cfg_act=act;cfg_pad_a=padded;
      cfg_pad_b=padded;cfg_pad_dst=padded;cfg_unaligned=unaligned;
      prefetch_buffer_seen_mask=0;
      m_size=m;n_size=n;k_words=kw;instance_count=batches;
      op_mode=(batches>1)?8'h31:8'h30;
      src0_base=SRC0_BASE;src1_base=SRC1_BASE;bias_base=BIAS_BASE;
      dst_base=DST_BASE+(unaligned?4:0);
      transpose_a=ta;transpose_b=tb;bias_enable=use_bias;
      scale_shift=shift;activation=act;watchdog_limit=0;
      local_a_stride=(m/4)*kw*16+(padded?32:0);
      local_b_stride=(n/4)*kw*16+(padded?48:0);
      local_dst_stride=m*n*4+(padded?32:0);
      src0_batch_stride=(padded?local_a_stride:0);
      src1_batch_stride=(padded?local_b_stride:0);
      dst_batch_stride=(padded?local_dst_stride:0);
      if(!padded) begin
        local_a_stride=(m/4)*kw*16;
        local_b_stride=(n/4)*kw*16;
        local_dst_stride=m*n*4;
      end

      for(ii=0;ii<batches;ii=ii+1)
        for(rr=0;rr<m;rr=rr+1)
          for(kk=0;kk<kw*4;kk=kk+1) begin
            value=($random(rand_state)%13)-6;
            logical_a[ii][rr][kk]=value;
          end
      for(ii=0;ii<batches;ii=ii+1)
        for(kk=0;kk<kw*4;kk=kk+1)
          for(cc=0;cc<n;cc=cc+1) begin
            value=($random(rand_state)%13)-6;
            logical_b[ii][kk][cc]=value;
          end
      for(cc=0;cc<n;cc=cc+1) begin
        logical_bias[cc]=($random(rand_state)%17)-8;
        bias_mem[(BIAS_BASE>>2)+cc]=logical_bias[cc];
      end

      // Arrange each banked line so the core's optional local 4x4 transpose
      // selects the requested logical A/B elements for every MAC lane.
      for(ii=0;ii<batches;ii=ii+1) begin
        for(tt=0;tt<m/4;tt=tt+1)
          for(kk=0;kk<kw;kk=kk+1) begin
            local_addr=SRC0_BASE+ii*local_a_stride+(tt*kw+kk)*16;
            local_index=(local_addr>>4)&13'h1fff;
            if(!ta) begin
              for(rr=0;rr<4;rr=rr+1) begin
                packed_word=0;
                for(ll=0;ll<4;ll=ll+1)
                  packed_word[ll*8+:8]=logical_a[ii][tt*4+rr][kk*4+ll];
                bank_mem[rr][local_index]=packed_word;
              end
            end else begin
              for(ll=0;ll<4;ll=ll+1) begin
                packed_word=0;
                for(rr=0;rr<4;rr=rr+1)
                  packed_word[rr*8+:8]=logical_a[ii][tt*4+rr][kk*4+ll];
                bank_mem[ll][local_index]=packed_word;
              end
            end
          end
        for(tt=0;tt<n/4;tt=tt+1)
          for(kk=0;kk<kw;kk=kk+1) begin
            local_addr=SRC1_BASE+ii*local_b_stride+(tt*kw+kk)*16;
            local_index=(local_addr>>4)&13'h1fff;
            if(!tb) begin
              for(cc=0;cc<4;cc=cc+1) begin
                packed_word=0;
                for(ll=0;ll<4;ll=ll+1)
                  packed_word[ll*8+:8]=logical_b[ii][kk*4+ll][tt*4+cc];
                bank_mem[cc][local_index]=packed_word;
              end
            end else begin
              for(ll=0;ll<4;ll=ll+1) begin
                packed_word=0;
                for(cc=0;cc<4;cc=cc+1)
                  packed_word[cc*8+:8]=logical_b[ii][kk*4+ll][tt*4+cc];
                bank_mem[ll][local_index]=packed_word;
              end
            end
          end
      end

      for(ii=0;ii<batches;ii=ii+1)
        for(rr=0;rr<m;rr=rr+1)
          for(cc=0;cc<n;cc=cc+1) begin
            accum=0;
            for(kk=0;kk<kw*4;kk=kk+1)
              accum=accum+$signed(logical_a[ii][rr][kk])*$signed(logical_b[ii][kk][cc]);
            if(use_bias) accum=accum+logical_bias[cc];
            result_value=accum >>> shift;
            if(act==1 && result_value<0) result_value=0;
            else if(act==2) begin
              if(result_value<0) result_value=0;
              else if(result_value>6) result_value=6;
            end
            local_addr=dst_base+ii*local_dst_stride+rr*n*4+cc*4;
            local_word=local_addr>>2;
            expected_mem[local_word]=result_value;
            output_mem[local_word]=32'hbad0_0000+local_word;
          end
      line_write_count=0;scalar_write_count=0;
      case_mac_snapshot=mac_cycle_count;
      case_bank_snapshot=bank_read_count;
      case_bank_stall_snapshot=bank_stall_count;
      case_line_stall_snapshot=line_stall_count;
    end
  endtask

  // Reuse the exact deterministic signed INT8 operands from the pinned
  // TinyNPU tiled-GEMM testbench. This is a benchmark-only data set, not a
  // product reference model; check_valid_case still checks the full DUT
  // output image against the independent integer GEMM accumulated below.
  task automatic prepare_tinynpu_match_case;
    integer rr,cc,kk,tt,ll,local_addr,local_index;
    integer signed value;
    begin
      prepare_case(16,16,4,1,0,0,0,0,0,0,0);

      for(rr=0;rr<16;rr=rr+1)
        for(kk=0;kk<16;kk=kk+1) begin
          value=((rr*3+kk*2+1)%9)-4;
          logical_a[0][rr][kk]=value;
        end
      for(kk=0;kk<16;kk=kk+1)
        for(cc=0;cc<16;cc=cc+1) begin
          // Keep the expression identical to the TinyNPU SV testbench,
          // including SystemVerilog's signed remainder semantics.
          value=((kk*2-cc*3+5)%9)-4;
          logical_b[0][kk][cc]=value;
        end

      for(tt=0;tt<4;tt=tt+1)
        for(kk=0;kk<4;kk=kk+1) begin
          local_addr=SRC0_BASE+(tt*4+kk)*16;
          local_index=(local_addr>>4)&13'h1fff;
          for(rr=0;rr<4;rr=rr+1)
            bank_mem[rr][local_index]=pack4(
                logical_a[0][tt*4+rr][kk*4],
                logical_a[0][tt*4+rr][kk*4+1],
                logical_a[0][tt*4+rr][kk*4+2],
                logical_a[0][tt*4+rr][kk*4+3]);

          local_addr=SRC1_BASE+(tt*4+kk)*16;
          local_index=(local_addr>>4)&13'h1fff;
          for(cc=0;cc<4;cc=cc+1)
            bank_mem[cc][local_index]=pack4(
                logical_b[0][kk*4][tt*4+cc],
                logical_b[0][kk*4+1][tt*4+cc],
                logical_b[0][kk*4+2][tt*4+cc],
                logical_b[0][kk*4+3][tt*4+cc]);
        end

      for(rr=0;rr<16;rr=rr+1)
        for(cc=0;cc<16;cc=cc+1) begin
          accum=0;
          for(kk=0;kk<16;kk=kk+1)
            accum=accum+$signed(logical_a[0][rr][kk])*
                         $signed(logical_b[0][kk][cc]);
          local_index=(DST_BASE>>2)+rr*16+cc;
          expected_mem[local_index]=accum;
          output_mem[local_index]=32'hbad0_0000+local_index;
        end
      line_write_count=0;scalar_write_count=0;
      case_mac_snapshot=mac_cycle_count;
      case_bank_snapshot=bank_read_count;
      case_bank_stall_snapshot=bank_stall_count;
      case_line_stall_snapshot=line_stall_count;
    end
  endtask

  task automatic launch_and_wait;
    begin
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      timeout_cycles=0;
      while(!done && timeout_cycles<200000) begin
        @(negedge clk);timeout_cycles=timeout_cycles+1;
      end
      if(!done) $fatal(1,"matrix core timeout m=%0d n=%0d kw=%0d state=%0d busy=%b cycle=%0d wdog=%0d pending=%b/%b",
                       m_size,n_size,k_words,dut.state_r,busy,cycle_count,
                       dut.watchdog_limit_r,pending_bank,pending_spad);
    end
  endtask

  task automatic check_valid_case(input integer case_id);
    integer expected_line_writes,expected_scalar_writes;
    integer ii,rr,cc,local_word;
    integer useful_mac_ops,case_mac_cycles,expected_cache_hits;
    integer m_macro_tiles,n_macro_tiles;
    integer profile_i,profile_state_sum;
    real macs_per_cycle,array_utilization,effective_gops_250;
    begin
      launch_and_wait();
      if(error || error_code!==0)
        $fatal(1,"matrix case %0d unexpected error=%b code=%0d",case_id,error,error_code);
      if(busy || element_count!==(cfg_m*cfg_n*cfg_instances))
        $fatal(1,"matrix case %0d completion elements=%0d expected=%0d busy=%b",
               case_id,element_count,cfg_m*cfg_n*cfg_instances,busy);
      expected_line_writes=cfg_unaligned?0:(cfg_m*cfg_instances*(cfg_n/4));
      expected_scalar_writes=cfg_unaligned?(cfg_m*cfg_n*cfg_instances):0;
      if(line_write_count!==expected_line_writes || scalar_write_count!==expected_scalar_writes)
        $fatal(1,"matrix case %0d writes line=%0d/%0d scalar=%0d/%0d",case_id,
               line_write_count,expected_line_writes,scalar_write_count,expected_scalar_writes);
      for(ii=0;ii<cfg_instances;ii=ii+1)
        for(rr=0;rr<cfg_m;rr=rr+1)
          for(cc=0;cc<cfg_n;cc=cc+1) begin
            local_word=(dst_base+ii*(cfg_m*cfg_n*4+(cfg_pad_dst?32:0))+rr*cfg_n*4+cc*4)>>2;
            if(output_mem[local_word]!==expected_mem[local_word])
              $fatal(1,"matrix case %0d batch=%0d row=%0d col=%0d got=%08x exp=%08x",
                     case_id,ii,rr,cc,output_mem[local_word],expected_mem[local_word]);
          end
      local_word=(dst_base+(cfg_instances-1)*(cfg_m*cfg_n*4+(cfg_pad_dst?32:0))+
                  cfg_m*cfg_n*4-4)>>2;
      if(result!==expected_mem[local_word])
        $fatal(1,"matrix case %0d result=%08x expected-last=%08x",case_id,result,expected_mem[local_word]);
      if(bank_read_count!=bank_response_count || pending_bank ||
         spad_read_count!=spad_response_count || pending_spad)
        $fatal(1,"matrix case %0d read drain bank=%0d/%0d pending=%b spad=%0d/%0d pending=%b",
               case_id,bank_read_count,bank_response_count,pending_bank,
               spad_read_count,spad_response_count,pending_spad);
      profile_state_sum=0;
      for(profile_i=0;profile_i<=14;profile_i=profile_i+1)
        profile_state_sum=profile_state_sum+dut.perf_state_cycles[profile_i];
      if(profile_state_sum!==cycle_count)
        $fatal(1,"matrix case %0d profile states=%0d do not account for total cycles=%0d",
               case_id,profile_state_sum,cycle_count);
      if((((cfg_m<PHYSICAL_ARRAY_SIZE)?cfg_m:PHYSICAL_ARRAY_SIZE)>4 ||
          ((cfg_n<PHYSICAL_ARRAY_SIZE)?cfg_n:PHYSICAL_ARRAY_SIZE)>4) &&
         (dut.perf_outstanding_highwater<2))
        $fatal(1,"matrix case %0d did not exercise multiple outstanding reads highwater=%0d",
               case_id,dut.perf_outstanding_highwater);
      expected_prefetch_count=0;
      if(NEXT_K_PREFETCH_ENABLE)
        expected_prefetch_count=(cfg_kw-1)*
            (((cfg_m+PHYSICAL_ARRAY_SIZE-1)/PHYSICAL_ARRAY_SIZE) *
             ((cfg_n+PHYSICAL_ARRAY_SIZE-1)/PHYSICAL_ARRAY_SIZE) *
             cfg_instances);
      if(dut.perf_prefetch_completed!=expected_prefetch_count)
        $fatal(1,"matrix case %0d prefetch groups=%0d expected=%0d",
               case_id,dut.perf_prefetch_completed,expected_prefetch_count);
      if(NEXT_K_PREFETCH_ENABLE && (cfg_kw>1) &&
         (dut.perf_prefetch_overlap_cycles==0))
        $fatal(1,"matrix case %0d did not overlap prefetch with MAC",case_id);
      m_macro_tiles=(cfg_m+PHYSICAL_ARRAY_SIZE-1)/PHYSICAL_ARRAY_SIZE;
      n_macro_tiles=(cfg_n+PHYSICAL_ARRAY_SIZE-1)/PHYSICAL_ARRAY_SIZE;
      expected_cache_hits=0;
      if(A_TILE_CACHE_ENABLE && (cfg_kw<=16) && (n_macro_tiles>1))
        expected_cache_hits=(n_macro_tiles-1)*m_macro_tiles*cfg_kw*cfg_instances;
      if(dut.perf_a_tile_cache_hits!=expected_cache_hits)
        $fatal(1,"matrix case %0d A-tile cache hits=%0d expected=%0d",
               case_id,dut.perf_a_tile_cache_hits,expected_cache_hits);
      if(NEXT_K_PREFETCH_ENABLE && (cfg_kw>2) &&
         (prefetch_buffer_seen_mask!=3))
        $fatal(1,"matrix case %0d did not use both ping-pong buffers mask=%0d",
               case_id,prefetch_buffer_seen_mask);
      if((MAX_OUTSTANDING_READS==2) &&
         (((cfg_m<PHYSICAL_ARRAY_SIZE)?cfg_m:PHYSICAL_ARRAY_SIZE)>
            MAX_OUTSTANDING_READS*4 ||
          ((cfg_n<PHYSICAL_ARRAY_SIZE)?cfg_n:PHYSICAL_ARRAY_SIZE)>
            MAX_OUTSTANDING_READS*4) &&
         (dut.perf_fifo_full_cycles==0))
        $fatal(1,"matrix case %0d did not exercise depth-2 request backpressure",
               case_id);
      useful_mac_ops=cfg_m*cfg_n*cfg_kw*4*cfg_instances;
      case_mac_cycles=mac_cycle_count-case_mac_snapshot;
      macs_per_cycle=(useful_mac_ops*1.0)/cycle_count;
      array_utilization=(useful_mac_ops*1.0)/(PHYSICAL_ARRAY_SIZE*PHYSICAL_ARRAY_SIZE*cycle_count);
      effective_gops_250=macs_per_cycle*0.5;
      case_count=case_count+1;
      $display("MATRIX_CORE_CASE_PASS id=%0d shape_mnk=%0d,%0d,%0d batches=%0d transpose_ab=%0d%0d bias=%0d writes=%0d/%0d cycles=%0d mac_cycles=%0d bank_reads=%0d bank_read_bytes=%0d bank_stalls=%0d line_write_bytes=%0d line_stalls=%0d macs_per_cycle=%0.3f array_utilization_pct=%0.2f effective_gops_250mhz=%0.3f physical_array=%0dx%0d",
               case_id,cfg_m,cfg_n,cfg_kw*4,cfg_instances,cfg_ta,cfg_tb,cfg_bias,
               line_write_count,scalar_write_count,cycle_count,case_mac_cycles,
               bank_read_count-case_bank_snapshot,
               (bank_read_count-case_bank_snapshot)*16,
               bank_stall_count-case_bank_stall_snapshot,
               line_write_count*16,
               line_stall_count-case_line_stall_snapshot,macs_per_cycle,
               array_utilization*100.0,effective_gops_250,PHYSICAL_ARRAY_SIZE,PHYSICAL_ARRAY_SIZE);
      $display("MATRIX_CORE_PROFILE id=%0d max_outstanding=%0d a_req=%0d a_wait=%0d b_req=%0d b_wait=%0d bias_req=%0d bias_wait=%0d prep_mac=%0d mac=%0d write=%0d next=%0d done=%0d error=%0d error_drain=%0d prefetch_wait=%0d arbiter_stall=%0d response_wait=%0d writeback_wait=%0d outstanding_highwater=%0d fifo_full=%0d prefetch_a_req=%0d prefetch_a_drain=%0d prefetch_b_req=%0d prefetch_b_drain=%0d prefetch_overlap=%0d prefetch_completed=%0d a_tile_cache_hits=%0d total=%0d",
               case_id,MAX_OUTSTANDING_READS,
               dut.perf_state_cycles[1],dut.perf_state_cycles[2],
               dut.perf_state_cycles[3],dut.perf_state_cycles[4],
               dut.perf_state_cycles[5],dut.perf_state_cycles[6],
               dut.perf_state_cycles[7],dut.perf_state_cycles[8],
               dut.perf_state_cycles[9],dut.perf_state_cycles[10],
               dut.perf_state_cycles[11],dut.perf_state_cycles[12],
               dut.perf_state_cycles[13],
               dut.perf_state_cycles[14],
               dut.perf_arbiter_stall_cycles,dut.perf_response_wait_cycles,
               dut.perf_writeback_wait_cycles,dut.perf_outstanding_highwater,
               dut.perf_fifo_full_cycles,dut.perf_prefetch_a_req_cycles,
               dut.perf_prefetch_a_drain_cycles,dut.perf_prefetch_b_req_cycles,
               dut.perf_prefetch_b_drain_cycles,dut.perf_prefetch_overlap_cycles,
               dut.perf_prefetch_completed,dut.perf_a_tile_cache_hits,cycle_count);
    end
  endtask

  task automatic finish_fault(input integer expected_code,input integer fault_id);
    integer observed_code;
    begin
      timeout_cycles=0;
      while(!done && timeout_cycles<200000) begin
        @(negedge clk);timeout_cycles=timeout_cycles+1;
      end
      if(!done) $fatal(1,"matrix fault %0d timed out",fault_id);
      if(!error || error_code!==expected_code || busy)
        $fatal(1,"matrix fault %0d got error=%b code=%0d expected=%0d busy=%b",
               fault_id,error,error_code,expected_code,busy);
      observed_code=error_code;
      if(line_write_count!=0 || scalar_write_count!=0)
        $fatal(1,"matrix fault %0d committed output before error",fault_id);
      while(pending_bank || pending_spad) @(negedge clk);
      repeat(2) @(negedge clk);
      fault_count=fault_count+1;
      $display("MATRIX_CORE_FAULT_PASS id=%0d code=%0d",fault_id,observed_code);
    end
  endtask

  task automatic check_fault(input integer expected_code,input integer fault_id);
    begin launch_and_wait();finish_fault(expected_code,fault_id);end
  endtask

  task automatic simple_fault_setup;
    begin
      prepare_case(4,4,2,1,0,0,0,0,0,0,0);
      inject_bank_parity=0;inject_spad_parity=0;
      inject_bank_protection=0;inject_spad_protection=0;inject_line_protection=0;
      watchdog_limit=0;
    end
  endtask

  task automatic check_inflight_reset_recovery;
    begin
      simple_fault_setup();
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      if(!busy) $fatal(1,"matrix reset probe did not enter busy");
      // Reset concurrently with abort plus bank/SPAD/line protection and
      // parity requests; reset must clear lifecycle status and pending work.
      abort=1;inject_bank_parity=1;inject_spad_parity=1;
      inject_bank_protection=1;inject_spad_protection=1;
      inject_line_protection=1;
      resetn=0;#1;
      if(busy || done || error || error_code!=0)
        $fatal(1,"matrix reset did not clear command status");
      repeat(3) @(negedge clk);resetn=1;abort=0;
      repeat(2) @(negedge clk);
      simple_fault_setup();
      check_valid_case(11);
    end
  endtask

  task automatic run_late_tile_parity_fault;
    integer target_issue,lines_before,scalars_before,lines_at_fault,scalars_at_fault;
    begin
      simple_fault_setup();
      // Complete the first 16x16 macro tile, then fail while reading the
      // second row tile of a 32x16 GEMM.
      prepare_case(32,16,8,1,0,0,0,0,0,0,0);
      target_issue=bank_read_count+70;
      bank_parity_target_issue=target_issue;
      inject_bank_parity=1;
      lines_before=line_write_count;scalars_before=scalar_write_count;
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      timeout_cycles=0;
      while(bank_read_count<=target_issue && timeout_cycles<200000) begin
        @(negedge clk);timeout_cycles=timeout_cycles+1;
      end
      if(bank_read_count<=target_issue)
        $fatal(1,"matrix late parity did not reach bank request %0d (count=%0d)",
               target_issue,bank_read_count);
      timeout_cycles=0;
      while(!done && timeout_cycles<200000) begin
        @(negedge clk);timeout_cycles=timeout_cycles+1;
      end
      if(!done || !error || error_code!=ERR_PARITY || busy)
        $fatal(1,"matrix late-tile parity done/error/code/busy=%b/%b/%0d/%b",
               done,error,error_code,busy);
      lines_at_fault=line_write_count;scalars_at_fault=scalar_write_count;
      if(lines_at_fault<=lines_before || scalars_at_fault!=scalars_before)
        $fatal(1,"matrix late fault missed prior tile writeback line=%0d scalar=%0d",
               lines_at_fault-lines_before,scalars_at_fault-scalars_before);
      repeat(4) @(negedge clk);
      if(line_write_count!=lines_at_fault || scalar_write_count!=scalars_at_fault)
        $fatal(1,"matrix wrote output after late parity error line=%0d->%0d scalar=%0d->%0d",
               lines_at_fault,line_write_count,scalars_at_fault,scalar_write_count);
      inject_bank_parity=0;
      while(pending_bank || pending_spad) @(negedge clk);
      fault_count=fault_count+1;
      $display("MATRIX_CORE_LATE_FAULT_PASS issue=%0d completed_lines=%0d",target_issue,
               lines_at_fault-lines_before);
    end
  endtask

  task automatic run_outstanding_abort;
    integer accepted_at_abort;
    integer timeout;
    begin
      simple_fault_setup();
      prepare_case(16,16,1,1,0,0,0,0,0,0,0);
      force_banked_ready=1;
      force_bank_response_delay=1;
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      timeout=0;
      while((dut.read_outstanding_count<MAX_OUTSTANDING_READS) &&
            (timeout<2000)) begin
        @(negedge clk);timeout=timeout+1;
      end
      if(dut.read_outstanding_count<MAX_OUTSTANDING_READS)
        $fatal(1,"depth-%0d Matrix reads did not reach full occupancy",
               MAX_OUTSTANDING_READS);
      accepted_at_abort=bank_read_count;
      abort=1;
      @(negedge clk);abort=0;
      finish_fault(ERR_ABORT,11);
      if(bank_read_count!=accepted_at_abort ||
         bank_response_count<accepted_at_abort)
        $fatal(1,"Matrix abort failed to stop and drain reads accepted=%0d now=%0d responses=%0d",
               accepted_at_abort,bank_read_count,bank_response_count);
      force_banked_ready=0;force_bank_response_delay=0;
      prepare_case(4,4,1,1,0,0,0,0,0,0,0);
      check_valid_case(12);
      $display("MATRIX_CORE_OUTSTANDING_ABORT_PASS depth=%0d drained=%0d",
               MAX_OUTSTANDING_READS,bank_response_count);
    end
  endtask

  task automatic run_outstanding_parity_fault;
    integer issue_target;
    integer timeout;
    begin
      simple_fault_setup();
      prepare_case(16,16,1,1,0,0,0,0,0,0,0);
      force_banked_ready=1;
      force_bank_response_delay=1;
      issue_target=bank_read_count;
      bank_parity_target_issue=issue_target;
      inject_bank_parity=1;
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      timeout=0;
      while((dut.read_outstanding_count<MAX_OUTSTANDING_READS) &&
            (timeout<2000)) begin
        @(negedge clk);timeout=timeout+1;
      end
      if(dut.read_outstanding_count<MAX_OUTSTANDING_READS)
        $fatal(1,"depth-%0d Matrix reads did not reach full occupancy before parity",
               MAX_OUTSTANDING_READS);
      timeout=0;
      while((dut.state_r!=13) && (timeout<2000)) begin
        @(negedge clk);timeout=timeout+1;
      end
      if((dut.state_r!=13) || (error_code!=ERR_PARITY))
        $fatal(1,"Matrix parity response did not enter drain state=%0d code=%0d",
               dut.state_r,error_code);
      inject_bank_parity=0;
      finish_fault(ERR_PARITY,12);
      force_banked_ready=0;force_bank_response_delay=0;
      prepare_case(4,4,1,1,0,0,0,0,0,0,0);
      check_valid_case(13);
      $display("MATRIX_CORE_OUTSTANDING_PARITY_PASS depth=%0d issue=%0d drained=%0d",
               MAX_OUTSTANDING_READS,issue_target,bank_response_count);
    end
  endtask

  task automatic run_prefetch_parity_fault;
    integer issue_base,target_issue,accepted_at_error,timeout;
    begin
      simple_fault_setup();
      prepare_case(16,16,2,1,0,0,0,0,0,0,0);
      force_banked_ready=1;
      force_bank_response_delay=1;
      issue_base=bank_read_count;
      target_issue=issue_base+8; // four A and four B words precede K-group 1.
      bank_parity_target_issue=target_issue;
      prefetch_parity_response_seen=0;
      inject_bank_parity=1;
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      timeout=0;
      while((bank_read_count<=target_issue) && (timeout<2000)) begin
        @(negedge clk);timeout=timeout+1;
      end
      if(bank_read_count<=target_issue)
        $fatal(1,"Matrix K-group prefetch did not issue parity target %0d",target_issue);
      timeout=0;
      while((dut.state_r!=13) && (timeout<2000)) begin
        @(negedge clk);timeout=timeout+1;
      end
      if((dut.state_r!=13) || !prefetch_parity_response_seen ||
         (error_code!=ERR_PARITY))
        $fatal(1,"prefetch parity did not fault the background buffer state=%0d seen=%b code=%0d",
               dut.state_r,prefetch_parity_response_seen,error_code);
      accepted_at_error=bank_read_count;
      inject_bank_parity=0;
      finish_fault(ERR_PARITY,13);
      if(bank_read_count!=accepted_at_error || bank_response_count<accepted_at_error)
        $fatal(1,"prefetch parity failed to stop/drain requests accepted=%0d issued=%0d returned=%0d",
               accepted_at_error,bank_read_count,bank_response_count);
      force_banked_ready=0;force_bank_response_delay=0;
      prepare_case(4,4,1,1,0,0,0,0,0,0,0);
      check_valid_case(14);
      $display("MATRIX_CORE_PREFETCH_PARITY_PASS issue=%0d drained=%0d",
               target_issue,bank_response_count);
    end
  endtask

  task automatic run_prefetch_abort;
    integer accepted_at_abort,timeout;
    begin
      simple_fault_setup();
      prepare_case(16,16,2,1,0,0,0,0,0,0,0);
      force_banked_ready=1;
      force_bank_response_delay=1;
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      timeout=0;
      while((!dut.prefetch_active || (dut.read_outstanding_count<2)) &&
            (timeout<2000)) begin
        @(negedge clk);timeout=timeout+1;
      end
      if(!dut.prefetch_active || (dut.read_outstanding_count<2) ||
         !dut.prefetch_buffer_r || dut.prefetch_buffer_r==dut.compute_buffer_r)
        $fatal(1,"Matrix abort did not reach inactive-buffer prefetch state=%0d outstanding=%0d buffers=%b/%b",
               dut.prefetch_state_r,dut.read_outstanding_count,
               dut.prefetch_buffer_r,dut.compute_buffer_r);
      accepted_at_abort=bank_read_count;
      abort=1;
      @(negedge clk);abort=0;
      finish_fault(ERR_ABORT,14);
      if((bank_read_count!=accepted_at_abort) ||
         (bank_response_count<accepted_at_abort) || dut.prefetch_valid_r!=0)
        $fatal(1,"Matrix prefetch abort failed stop/drain/clear accepted=%0d issued=%0d returned=%0d valid=%b",
               accepted_at_abort,bank_read_count,bank_response_count,
               dut.prefetch_valid_r);
      force_banked_ready=0;force_bank_response_delay=0;
      prepare_case(4,4,1,1,0,0,0,0,0,0,0);
      check_valid_case(15);
      $display("MATRIX_CORE_PREFETCH_ABORT_PASS depth=%0d drained=%0d",
               MAX_OUTSTANDING_READS,bank_response_count);
    end
  endtask

  task automatic run_prefetch_watchdog;
    integer timeout;
    begin
      simple_fault_setup();
      prepare_case(4,4,2,1,0,0,0,0,0,0,0);
      watchdog_limit=20;
      force_banked_ready=1;
      force_bank_response_delay=1;
      watchdog_during_prefetch_seen=0;
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      timeout=0;
      while((!dut.prefetch_active || (dut.read_outstanding_count==0)) &&
            !done && (timeout<2000)) begin
        @(negedge clk);timeout=timeout+1;
      end
      if(!dut.prefetch_active || (dut.read_outstanding_count==0))
        $fatal(1,"Matrix watchdog test never reached outstanding prefetch");
      timeout=0;
      while(!done && (timeout<2000)) begin
        @(negedge clk);timeout=timeout+1;
      end
      if(!done || !error || error_code!=ERR_WATCHDOG ||
         !watchdog_during_prefetch_seen)
        $fatal(1,"Matrix watchdog did not expire during prefetch done/error/code/seen=%b/%b/%0d/%b",
               done,error,error_code,watchdog_during_prefetch_seen);
      finish_fault(ERR_WATCHDOG,15);
      force_banked_ready=0;force_bank_response_delay=0;
      prepare_case(4,4,1,1,0,0,0,0,0,0,0);
      check_valid_case(16);
      $display("MATRIX_CORE_PREFETCH_WATCHDOG_PASS limit=20 drained=%0d",
               bank_response_count);
    end
  endtask

  task automatic run_prefetch_reset_recovery;
    integer timeout;
    begin
      simple_fault_setup();
      prepare_case(16,16,2,1,0,0,0,0,0,0,0);
      force_banked_ready=1;
      force_bank_response_delay=1;
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      timeout=0;
      while((!dut.prefetch_active || (dut.read_outstanding_count==0)) &&
            (timeout<2000)) begin
        @(negedge clk);timeout=timeout+1;
      end
      if(!dut.prefetch_active || (dut.read_outstanding_count==0))
        $fatal(1,"Matrix reset test never reached outstanding prefetch");
      resetn=0;#1;
      if(busy || done || error || error_code!=0 ||
         dut.read_outstanding_count!=0 || dut.prefetch_state_r!=0 ||
         dut.prefetch_valid_r!=0 || pending_bank)
        $fatal(1,"Matrix reset failed to clear in-flight prefetch state");
      repeat(3) @(negedge clk);
      resetn=1;
      force_banked_ready=0;force_bank_response_delay=0;
      repeat(2) @(negedge clk);
      if(line_write_count!=0 || scalar_write_count!=0 || pending_bank)
        $fatal(1,"Matrix reset leaked pre-reset prefetch work");
      prepare_case(4,4,1,1,0,0,0,0,0,0,0);
      check_valid_case(17);
      $display("MATRIX_CORE_PREFETCH_RESET_PASS recovery=1");
    end
  endtask

  task automatic run_phase_abort(
      input integer target_state,input integer m,input integer n,
      input integer kw,input integer use_bias,input integer fault_id);
    integer timeout,lines_before,scalars_before;
    begin
      simple_fault_setup();
      prepare_case(m,n,kw,1,0,0,use_bias,0,0,0,0);
      if(target_state==9) force_line_stall=1;
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      timeout=0;
      while((dut.state_r!=target_state) && !done && (timeout<200000)) begin
        @(negedge clk);timeout=timeout+1;
      end
      if(dut.state_r!=target_state)
        $fatal(1,"Matrix phase-abort target state=%0d not reached current=%0d done=%b",
               target_state,dut.state_r,done);
      lines_before=line_write_count;scalars_before=scalar_write_count;
      abort=1;
      @(negedge clk);abort=0;
      timeout=0;
      while(!done && (timeout<200000)) begin
        @(negedge clk);timeout=timeout+1;
      end
      if(!done || !error || error_code!=ERR_ABORT || busy)
        $fatal(1,"Matrix phase-abort state=%0d done/error/code/busy=%b/%b/%0d/%b",
               target_state,done,error,error_code,busy);
      if(line_write_count!=lines_before || scalar_write_count!=scalars_before)
        $fatal(1,"Matrix phase-abort state=%0d wrote after abort line=%0d->%0d scalar=%0d->%0d",
               target_state,lines_before,line_write_count,
               scalars_before,scalar_write_count);
      while(pending_bank || pending_spad) @(negedge clk);
      force_line_stall=0;
      fault_count=fault_count+1;
      $display("MATRIX_CORE_PHASE_ABORT_PASS state=%0d id=%0d prior_writes=%0d/%0d",
               target_state,fault_id,lines_before,scalars_before);
    end
  endtask

  task automatic run_prefetch_wait_abort;
    integer timeout,lines_before,scalars_before,accepted_at_abort;
    begin
      simple_fault_setup();
      prepare_case(16,16,2,1,0,0,0,0,0,0,0);
      force_banked_ready=1;force_bank_response_delay=1;
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      timeout=0;
      while((dut.state_r!=14) && !done && (timeout<2000)) begin
        @(negedge clk);timeout=timeout+1;
      end
      if((dut.state_r!=14) || !dut.prefetch_active)
        $fatal(1,"Matrix core did not enter ST_PREFETCH_WAIT core=%0d prefetch=%0d active=%b",
               dut.state_r,dut.prefetch_state_r,dut.prefetch_active);
      lines_before=line_write_count;scalars_before=scalar_write_count;
      accepted_at_abort=bank_read_count;
      abort=1;
      @(negedge clk);abort=0;
      finish_fault(ERR_ABORT,22);
      if(line_write_count!=lines_before || scalar_write_count!=scalars_before ||
         bank_read_count!=accepted_at_abort || bank_response_count<accepted_at_abort)
        $fatal(1,"Matrix prefetch-wait abort wrote/issued/drain mismatch writes=%0d/%0d reads=%0d/%0d responses=%0d",
               line_write_count-lines_before,scalar_write_count-scalars_before,
               accepted_at_abort,bank_read_count,bank_response_count);
      force_banked_ready=0;force_bank_response_delay=0;
      $display("MATRIX_CORE_PREFETCH_WAIT_ABORT_PASS drained=%0d",bank_response_count);
    end
  endtask

  task automatic run_prefetch_b_req_abort;
    integer timeout,accepted_at_abort;
    begin
      simple_fault_setup();
      prepare_case(16,16,2,1,0,0,0,0,0,0,0);
      force_banked_ready=1;force_bank_response_delay=1;
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      timeout=0;
      while((dut.prefetch_state_r!=3) && !done && (timeout<2000)) begin
        @(negedge clk);timeout=timeout+1;
      end
      if((dut.prefetch_state_r!=3) || !dut.prefetch_active)
        $fatal(1,"Matrix prefetch did not reach PF_B_REQ state=%0d active=%b",
               dut.prefetch_state_r,dut.prefetch_active);
      accepted_at_abort=bank_read_count;
      abort=1;
      @(negedge clk);abort=0;
      finish_fault(ERR_ABORT,23);
      if(bank_read_count!=accepted_at_abort || bank_response_count<accepted_at_abort ||
         dut.prefetch_state_r!=0 || dut.prefetch_valid_r!=0)
        $fatal(1,"Matrix PF_B_REQ abort failed cancel/stop/drain issued=%0d/%0d responses=%0d state=%0d valid=%b",
               accepted_at_abort,bank_read_count,bank_response_count,
               dut.prefetch_state_r,dut.prefetch_valid_r);
      force_banked_ready=0;force_bank_response_delay=0;
      $display("MATRIX_CORE_PREFETCH_B_REQ_ABORT_PASS drained=%0d",bank_response_count);
    end
  endtask

  task automatic run_prefetch_handoff;
    begin
      simple_fault_setup();
      prefetch_handoff_seen=0;
      if(PHYSICAL_ARRAY_SIZE==4)
        prepare_case(4,8,2,1,0,0,0,0,0,0,0);
      else
        prepare_case(16,20,8,1,0,0,0,0,0,0,0);
      force_banked_ready=1;force_zero_bank_latency=1;
      check_valid_case(21);
      if(error || (dut.perf_prefetch_completed==0) ||
         (dut.perf_prefetch_overlap_cycles==0))
        $fatal(1,"Matrix fast prefetch handoff did not complete/overlap completed=%0d overlap=%0d error=%b",
               dut.perf_prefetch_completed,dut.perf_prefetch_overlap_cycles,error);
      if(!prefetch_handoff_seen)
        $fatal(1,"Matrix array=%0d prefetch profile did not take ST_MAC->ST_PREP_MAC handoff",
               PHYSICAL_ARRAY_SIZE);
      force_banked_ready=0;force_zero_bank_latency=0;
      $display("MATRIX_CORE_PREFETCH_HANDOFF_PASS completed=%0d overlap=%0d direct=%b array=%0d",
               dut.perf_prefetch_completed,dut.perf_prefetch_overlap_cycles,
               prefetch_handoff_seen,PHYSICAL_ARRAY_SIZE);
    end
  endtask

  task automatic run_phase_reset(
      input integer target_state,input integer m,input integer n,
      input integer kw,input integer use_bias,input integer reset_id);
    integer timeout;
    begin
      simple_fault_setup();
      prepare_case(m,n,kw,1,0,0,use_bias,0,0,0,0);
      if(target_state==9) force_line_stall=1;
      if(target_state==14) begin
        force_banked_ready=1;
        force_bank_response_delay=1;
      end
      if(target_state==12) begin
        bank_parity_target_issue=bank_read_count;
        inject_bank_parity=1;
      end
      if(target_state==13) begin
        inject_bank_protection=1;
        bank_protection_addr=SRC0_BASE;
      end
      @(negedge clk);start=1;
      @(negedge clk);start=0;
      timeout=0;
      while((dut.state_r!=target_state) && !done && (timeout<200000)) begin
        @(negedge clk);timeout=timeout+1;
      end
      if(dut.state_r!=target_state)
        $fatal(1,"Matrix phase-reset target state=%0d not reached current=%0d done=%b",
               target_state,dut.state_r,done);
      resetn=0;#1;
      if(dut.state_r!=0 || busy || done || error || error_code!=0)
        $fatal(1,"Matrix reset failed to clear target state=%0d actual=%0d busy/done/error/code=%b/%b/%b/%0d",
               target_state,dut.state_r,busy,done,error,error_code);
      repeat(3) @(negedge clk);
      resetn=1;
      abort=0;inject_bank_parity=0;inject_bank_protection=0;
      force_line_stall=0;force_banked_ready=0;force_bank_response_delay=0;
      repeat(2) @(negedge clk);
      if(pending_bank || pending_spad || dut.read_outstanding_count!=0)
        $fatal(1,"Matrix reset state=%0d leaked pending reads bank=%b spad=%b outstanding=%0d",
               target_state,pending_bank,pending_spad,dut.read_outstanding_count);
      $display("MATRIX_CORE_PHASE_RESET_PASS state=%0d id=%0d",target_state,reset_id);
    end
  endtask

  initial begin
    if($value$plusargs("SEED=%d",seed)) begin end
    benchmark_mode=$test$plusargs("MATRIX_BENCHMARK_ONLY");
    initial_seed=seed;rand_state=seed;
    for(inst=0;inst<4;inst=inst+1)
      for(row=0;row<8192;row=row+1)
        for(col=0;col<4;col=col+1) bank_mem[col][row]=0;
    for(row=0;row<65536;row=row+1) begin
      bias_mem[row]=0;output_mem[row]=0;expected_mem[row]=0;
    end
    repeat(4) @(negedge clk);resetn=1;

    if($test$plusargs("MATRIX_BENCHMARK_ONLY")) begin
      prepare_case(4,4,8,1,0,0,0,0,0,0,0);
      check_valid_case(100);
      prepare_case(8,8,8,1,0,0,0,0,0,0,0);
      check_valid_case(101);
      prepare_case(16,16,8,1,0,0,0,0,0,0,0);
      check_valid_case(102);
      prepare_case(16,32,8,1,0,0,0,0,0,0,0);
      check_valid_case(103);
      prepare_case(32,32,16,1,0,0,0,0,0,0,0);
      check_valid_case(104);
      if(!NEXT_K_PREFETCH_ENABLE && !mac_to_a_req_seen)
        $fatal(1,"Matrix no-prefetch configuration missed ST_MAC->ST_A_REQ fallback");
      if(!NEXT_K_PREFETCH_ENABLE)
        $display("MATRIX_NO_PREFETCH_FALLBACK_PASS seed=%0d fallback=1",initial_seed);
      $display("MATRIX_SIZE_BENCHMARK_PASS seed=%0d workloads=4x4x32,8x8x32,16x16x32,16x32x32,32x32x64 physical_array=%0dx%0d outstanding_depth=%0d next_k_prefetch=%0d a_tile_cache=%0d bank_response_latency=1 cycle gops_reference_mhz=250 sim_period_ns=10",initial_seed,PHYSICAL_ARRAY_SIZE,PHYSICAL_ARRAY_SIZE,MAX_OUTSTANDING_READS,NEXT_K_PREFETCH_ENABLE,A_TILE_CACHE_ENABLE);
      $finish;
    end

    if($test$plusargs("TINY_NPU_MATCH_ONLY")) begin
      prepare_tinynpu_match_case();
      check_valid_case(105);
      $display("MATRIX_TINY_NPU_MATCH_PASS seed=%0d shape=16x16x16 physical_array=%0dx%0d bank_response_latency=1 cycle",
               initial_seed,PHYSICAL_ARRAY_SIZE,PHYSICAL_ARRAY_SIZE);
      $finish;
    end

    if($test$plusargs("MATRIX_PREFETCH_HANDOFF_ONLY")) begin
      run_prefetch_handoff();
      $display("MATRIX_PREFETCH_HANDOFF_ONLY_PASS seed=%0d array=%0d direct=%b",
               initial_seed,PHYSICAL_ARRAY_SIZE,prefetch_handoff_seen);
      $finish;
    end

    prepare_case(8,8,2,2,0,0,1,1,1,1,0);
    check_valid_case(0);
    prepare_case(8,4,2,1,1,0,0,0,0,0,0);
    check_valid_case(1);
    prepare_case(4,8,1,2,0,1,1,0,2,1,0);
    check_valid_case(2);
    prepare_case(4,4,1,1,1,1,0,3,0,0,1);
    check_valid_case(3);
    prepare_case(16,16,4,1,0,0,0,0,0,0,0);
    check_valid_case(4);
    prepare_case(32,16,2,1,1,1,1,1,0,0,0);
    check_valid_case(5);
    prepare_case(16,32,8,1,0,0,0,0,0,0,0);
    check_valid_case(18);
    prepare_case(32,32,16,1,0,0,0,0,0,0,0);
    check_valid_case(19);
    // The bounded A cache supports K<=64 elements (16 K words); larger K
    // remains legal and follows the banked-read path without cache hits.
    prepare_case(16,32,17,1,0,0,0,0,0,0,0);
    check_valid_case(20);

    simple_fault_setup();m_size=0;check_fault(ERR_CONFIG,0);
    simple_fault_setup();n_size=0;check_fault(ERR_CONFIG,41);
    simple_fault_setup();k_words=0;check_fault(ERR_CONFIG,42);
    simple_fault_setup();m_size=6;check_fault(ERR_CONFIG,43);
    simple_fault_setup();n_size=6;check_fault(ERR_CONFIG,44);
    simple_fault_setup();src0_base=SRC0_BASE+4;check_fault(ERR_CONFIG,45);
    simple_fault_setup();src1_base=SRC1_BASE+4;check_fault(ERR_CONFIG,46);
    simple_fault_setup();dst_base=DST_BASE+2;check_fault(ERR_CONFIG,47);
    simple_fault_setup();bias_enable=1;bias_base=BIAS_BASE+1;check_fault(ERR_CONFIG,48);
    simple_fault_setup();inject_bank_protection=1;bank_protection_addr=SRC1_BASE;
    check_fault(ERR_PROTECTION,49);inject_bank_protection=0;
    prepare_case(4,4,1,1,0,0,0,0,0,0,0);op_mode=8'h7f;check_fault(ERR_OP,1);
    simple_fault_setup();inject_bank_protection=1;bank_protection_addr=SRC0_BASE;
    check_fault(ERR_PROTECTION,2);inject_bank_protection=0;
    prepare_case(4,4,2,1,0,0,0,0,0,0,0);
    bank_parity_target_issue=bank_read_count;inject_bank_parity=1;
    check_fault(ERR_PARITY,3);inject_bank_parity=0;
    prepare_case(4,4,1,1,0,0,1,0,0,0,0);inject_spad_parity=1;
    check_fault(ERR_PARITY,4);inject_spad_parity=0;
    prepare_case(4,4,1,1,0,0,1,0,0,0,0);inject_spad_protection=1;
    spad_protection_addr=BIAS_BASE;check_fault(ERR_PROTECTION,5);inject_spad_protection=0;
    prepare_case(4,4,1,1,0,0,0,0,0,0,0);inject_line_protection=1;
    line_protection_addr=DST_BASE;check_fault(ERR_PROTECTION,6);inject_line_protection=0;
    prepare_case(4,4,1,1,0,0,0,0,0,0,1);inject_spad_protection=1;
    spad_protection_addr=DST_BASE+4;check_fault(ERR_PROTECTION,7);inject_spad_protection=0;

    simple_fault_setup();watchdog_limit=3;check_fault(ERR_WATCHDOG,8);
    simple_fault_setup();
    @(negedge clk);start=1;@(negedge clk);start=0;
    while(!busy) @(negedge clk);
    repeat(5) @(negedge clk);abort=1;@(negedge clk);abort=0;
    finish_fault(ERR_ABORT,9);

    // Abort wins over an already-expired watchdog while the command remains
    // active. Wait for the threshold before asserting Abort at the sampling
    // edge; the earlier test only asserted Abort before expiry.
    simple_fault_setup();watchdog_limit=32'd3;
    @(negedge clk);start=1;@(negedge clk);start=0;
    timeout_cycles=0;
    while((!busy || cycle_count<watchdog_limit) && timeout_cycles<2000) begin
      @(negedge clk);timeout_cycles=timeout_cycles+1;
    end
    if(!busy || cycle_count<watchdog_limit)
      $fatal(1,"Matrix Abort/watchdog priority probe missed active expiry");
    abort=1;@(negedge clk);abort=0;
    finish_fault(ERR_ABORT,10);

    // Abort also wins a selected same-cycle bank parity/protection response.
    simple_fault_setup();prepare_case(4,4,2,1,0,0,0,0,0,0,0);
    bank_parity_target_issue=bank_read_count;
    inject_bank_parity=1;inject_bank_protection=1;
    bank_protection_addr=SRC0_BASE;
    @(negedge clk);start=1;@(negedge clk);start=0;abort=1;
    finish_fault(ERR_ABORT,11);
    abort=0;inject_bank_parity=0;inject_bank_protection=0;
    run_outstanding_abort();
    run_outstanding_parity_fault();
    run_prefetch_parity_fault();
    run_prefetch_abort();
    run_prefetch_watchdog();
    run_prefetch_reset_recovery();
    run_late_tile_parity_fault();

    // Exercise abort priority at each FSM phase that was previously missing
    // from the merged transition report. The NEXT-phase case intentionally
    // permits the completed first macro tile and checks for no later writes.
    run_phase_abort(5,4,4,1,1,24);  // ST_BIAS_REQ
    run_phase_abort(6,4,4,1,1,25);  // ST_BIAS_WAIT
    run_phase_abort(7,4,4,1,0,26);  // ST_PREP_MAC
    run_phase_abort(9,4,4,1,0,27);  // ST_WRITE (write port held off)
    run_phase_abort(10,32,16,1,0,28); // ST_NEXT after first macro tile
    run_phase_abort(11,4,4,1,0,29); // ST_DONE
    run_prefetch_wait_abort();
    run_prefetch_b_req_abort();
    run_prefetch_handoff();

    // Hit the asynchronous-reset arcs that were previously only reviewed in
    // URG. Each reset is asserted while the named FSM state is active.
    run_phase_reset(2,4,4,1,0,30);   // ST_A_WAIT
    run_phase_reset(3,4,4,1,0,31);   // ST_B_REQ
    run_phase_reset(4,4,4,1,0,32);   // ST_B_WAIT
    run_phase_reset(5,4,4,1,1,33);   // ST_BIAS_REQ
    run_phase_reset(6,4,4,1,1,34);   // ST_BIAS_WAIT
    run_phase_reset(7,4,4,1,0,35);   // ST_PREP_MAC
    run_phase_reset(9,4,4,1,0,36);   // ST_WRITE
    run_phase_reset(10,32,16,1,0,37); // ST_NEXT
    run_phase_reset(12,4,4,1,0,38);  // ST_ERROR
    run_phase_reset(13,4,4,1,0,39);  // ST_ERROR_DRAIN
    run_phase_reset(14,16,16,2,0,40); // ST_PREFETCH_WAIT

    prepare_case(4,4,1,1,0,0,0,0,0,0,0);
    check_valid_case(10);
    check_inflight_reset_recovery();
    if(bank_stall_count==0 || spad_stall_count==0 || line_stall_count==0)
      $fatal(1,"matrix randomized ready profile missed stalls bank/spad/line=%0d/%0d/%0d",
             bank_stall_count,spad_stall_count,line_stall_count);
    $display("MATRIX_CORE_RANDOM_PASS cases=%0d faults=%0d late_tile_faults=1 fault_abort_combo=1 reset_fault_combo=1 reset_recovery=1 outstanding_abort=1 outstanding_parity=1 prefetch_parity=1 prefetch_abort=1 prefetch_watchdog=1 prefetch_reset=1 phase_abort=6 prefetch_wait_abort=1 prefetch_b_req_abort=1 prefetch_handoff=1 phase_reset=11 seed=%0d bank_reads=%0d responses=%0d spad_reads=%0d responses=%0d stalls=%0d/%0d/%0d",
             case_count,fault_count,initial_seed,bank_read_count,bank_response_count,
             spad_read_count,spad_response_count,bank_stall_count,spad_stall_count,line_stall_count);
    $finish;
  end
endmodule
