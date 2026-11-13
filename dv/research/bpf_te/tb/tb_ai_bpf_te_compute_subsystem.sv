`timescale 1ns/1ps
module tb_ai_bpf_te_compute_subsystem;
  reg clk=0; always #5 clk=~clk;
  reg resetn=0, epoch_bump=0, init_valid=0, init_write=0;
  reg [31:0] init_addr=0, init_wdata=0; reg [3:0] init_wstrb=4'hf;
  reg probe_valid=0; reg [31:0] probe_addr=0; wire probe_rsp_valid; wire [31:0] probe_rdata;
  reg matrix_start=0, cnm_start=0, abort=0; reg [7:0] op_mode=8'h20;
  reg matrix_transpose_a=0, matrix_transpose_b=0, matrix_bias_enable=0;
  reg [31:0] ms0=0,ms1=0,mdst=0,mi=1,m0s=0,m1s=0,mds=0,maux=0,mb=0;
  reg [15:0] mm=1,mn=1,mk=1,cl=1,cm=1; reg [4:0] mshift=0,cshift=0;
  reg [1:0] mact=0,cact=0; reg [31:0] cs0=32'h100,cs1=32'h200,cdst=32'h300,wd=0;
  wire mbusy,mdone,merr,cbusy,cdone,cerr; wire [3:0] mecode,cecode;
  wire [31:0] mres,mcy,cres,ccy,acc,rsp,den;
  wire output_write_commit; wire [31:0] output_write_addr, output_write_data;
  reg saw_output_write=0; reg [31:0] saw_output_addr=0, saw_output_data=0;
  always @(posedge clk) if (output_write_commit) begin saw_output_write<=1; saw_output_addr<=output_write_addr; saw_output_data<=output_write_data; end
  wire matrix_line_commit; wire [31:0] matrix_line_commit_addr; wire [127:0] matrix_line_commit_data; wire [15:0] matrix_line_commit_wstrb;
  integer matrix_line_count=0; reg matrix_line_bad=0;
  always @(posedge clk) if (matrix_line_commit) begin
    matrix_line_count <= matrix_line_count + 1;
    $display("MATRIX_LINE_COMMIT addr=%h data=%h wstrb=%h",matrix_line_commit_addr,matrix_line_commit_data,matrix_line_commit_wstrb);
    if (matrix_line_commit_wstrb !== 16'hffff || matrix_line_commit_data !== 128'hfffffffcfffffffcfffffffcfffffffc) matrix_line_bad <= 1;
  end
  ai_bpf_te_compute_subsystem dut(
    .clk(clk),.resetn(resetn),.epoch_bump(epoch_bump),.init_valid(init_valid),
    .init_write(init_write),.init_addr(init_addr),.init_wdata(init_wdata),.init_wstrb(init_wstrb),
    .probe_valid(probe_valid),.probe_addr(probe_addr),.probe_rsp_valid(probe_rsp_valid),.probe_rdata(probe_rdata),
    .matrix_start(matrix_start),.cnm_start(cnm_start),.abort(abort),.op_mode(op_mode),
    .matrix_src0(ms0),.matrix_src1(ms1),.matrix_dst(mdst),.matrix_m(mm),.matrix_n(mn),.matrix_k(mk),
    .matrix_instance_count(mi),.matrix_src0_stride(m0s),.matrix_src1_stride(m1s),.matrix_dst_stride(mds),
    .matrix_aux0(maux),.matrix_transpose_a(matrix_transpose_a),.matrix_transpose_b(matrix_transpose_b),.matrix_bias_enable(matrix_bias_enable),
    .matrix_bias_base(mb),.matrix_shift(mshift),.matrix_activation(mact),.cnm_src0(cs0),.cnm_src1(cs1),
    .cnm_dst(cdst),.cnm_length(cl),.cnm_m(cm),.cnm_shift(cshift),.cnm_activation(cact),.watchdog_limit(wd),
    .matrix_busy(mbusy),.matrix_done(mdone),.matrix_error(merr),.matrix_error_code(mecode),.matrix_result(mres),.matrix_cycles(mcy),
    .cnm_busy(cbusy),.cnm_done(cdone),.cnm_error(cerr),.cnm_error_code(cecode),.cnm_result(cres),.cnm_cycles(ccy),
    .accepted_bank_ops(acc),.response_ops(rsp),.denied_ops(den),.output_write_commit(output_write_commit),
    .output_write_addr(output_write_addr),.output_write_data(output_write_data),.matrix_line_commit(matrix_line_commit),
    .matrix_line_commit_addr(matrix_line_commit_addr),.matrix_line_commit_data(matrix_line_commit_data),.matrix_line_commit_wstrb(matrix_line_commit_wstrb));

  task host_write_word(input [31:0] a, input [31:0] d);
    begin @(negedge clk); init_valid=1; init_write=1; init_addr=a; init_wdata=d;
      @(negedge clk); init_valid=0; init_write=0; end
  endtask
  initial begin
    repeat(3) @(negedge clk); resetn=1;
    host_write_word(32'h100,32'h00000002); host_write_word(32'h104,32'h00000003);
    host_write_word(32'h108,32'h00000004); host_write_word(32'h10c,32'h00000005);
    host_write_word(32'h200,32'h00000007); host_write_word(32'h204,32'h00000008);
    host_write_word(32'h208,32'h00000009); host_write_word(32'h20c,32'h0000000a);
    @(negedge clk); cnm_start=1; @(negedge clk); cnm_start=0;
    wait(cdone); if(cerr || cres!==32'd124) $fatal(1,"CNM integration mismatch err=%0d code=%h result=%0d",cerr,cecode,cres);
    if (!saw_output_write || saw_output_addr !== 32'h300 || saw_output_data !== 32'd124)
      $fatal(1,"CNM writeback mismatch seen=%0d addr=%h data=%h",saw_output_write,saw_output_addr,saw_output_data);
    @(negedge clk); probe_addr=32'h300; probe_valid=1;
    @(negedge clk); probe_valid=0; wait(probe_rsp_valid);
    if (probe_rdata !== 32'd124) $fatal(1,"CNM SPAD readback mismatch data=%h",probe_rdata);
    $display("BPF_TE_REAL_CNM_MEMORY_GOLDEN_PASS addr=0x300 data=%0d",probe_rdata);
    $display("BPF_TE_REAL_CNM_PASS result=%0d cycles=%0d accepted_bank_ops=%0d response_ops=%0d denied_ops=%0d",cres,ccy,acc,rsp,den);
    // Zero-filled 4x4 GEMM exercises the real Matrix banked-read path and
    // aligned Line writeback through the same four-bank adapter.
    op_mode=8'h30; mm=4; mn=4; mk=1; ms0=32'h400; ms1=32'h800; mdst=32'h1000;
    for (integer wi=0; wi<16; wi=wi+1) begin
      host_write_word(32'h400 + wi*4, 32'h01010101);
      host_write_word(32'h800 + wi*4, 32'hffffffff);
    end
    @(negedge clk); matrix_start=1; @(negedge clk); matrix_start=0;
    matrix_wait: begin
      repeat (1000) begin @(negedge clk); if (mdone) disable matrix_wait; end
    end
    if (!mdone && !merr) $fatal(1,"Matrix integration timeout");
    if (merr) $fatal(1,"Matrix integration error code=%h",mecode);
    if (matrix_line_count == 0 || matrix_line_bad) $fatal(1,"Matrix nonzero writeback mismatch count=%0d bad=%0d",matrix_line_count,matrix_line_bad);
    $display("BPF_TE_REAL_MATRIX_PASS result=%0d cycles=%0d line_writes=%0d accepted_bank_ops=%0d response_ops=%0d denied_ops=%0d",mres,mcy,matrix_line_count,acc,rsp,den);
    // Flush an accepted CNM read in flight. The wrapper must turn the dropped
    // old-epoch response into an engine-visible abort rather than hang.
    op_mode=8'h20; @(negedge clk); cnm_start=1; @(negedge clk); cnm_start=0;
    epoch_wait: begin
      repeat (200) begin
        @(negedge clk);
        if (|dut.atomic_u.bank_req_valid) begin epoch_bump=1; @(negedge clk); epoch_bump=0; disable epoch_wait; end
      end
    end
    wait(cdone); if (!cerr) $fatal(1,"Epoch flush did not produce CNM error");
    $display("BPF_TE_EPOCH_ABORT_PASS code=%h cycles=%0d",cecode,ccy);
    repeat(3) @(negedge clk); $finish;
  end
endmodule
