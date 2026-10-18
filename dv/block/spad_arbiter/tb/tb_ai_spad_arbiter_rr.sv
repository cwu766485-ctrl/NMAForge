`timescale 1ns / 1ps

module tb_ai_spad_arbiter_rr;
  reg clk=0, resetn=0;
  reg desc_valid=0, desc_write=0;
  reg [31:0] desc_addr=0, desc_wdata=0;
  wire desc_ready;
  reg cpl_valid=0, cpl_write=0;
  reg [31:0] cpl_addr=0, cpl_wdata=0;
  wire cpl_ready;
  reg core_valid=0, core_write=0;
  reg [31:0] core_addr=0, core_wdata=0;
  wire core_ready;
  reg core_line_valid=0, core_line_write=0;
  reg [31:0] core_line_addr=0;
  reg [127:0] core_line_wdata=0;
  reg [15:0] core_line_wstrb=0;
  wire core_line_ready;
  reg banked_valid=0;
  reg [31:0] banked_addr=0;
  wire banked_ready;
  reg [3:0] cnm_valid=0;
  reg [31:0] cnm_addr0=0, cnm_addr1=0, cnm_addr2=0, cnm_addr3=0;
  wire [3:0] cnm_ready;
  reg dma_valid=0, dma_write=0;
  reg [31:0] dma_addr=0, dma_wdata=0;
  wire dma_ready;
  reg dma_line_valid=0, dma_line_write=0;
  reg [31:0] dma_line_addr=0;
  reg [127:0] dma_line_wdata=0;
  reg [15:0] dma_line_wstrb=0;
  wire dma_line_ready;
  wire spad_valid, spad_write;
  wire [31:0] spad_addr, spad_wdata;
  wire spad_line_valid, spad_line_write;
  wire [31:0] spad_line_addr;
  wire [127:0] spad_line_wdata;
  wire [15:0] spad_line_wstrb;
  wire spad_banked_valid;
  wire [31:0] spad_banked_addr;
  wire [3:0] spad_cnm_valid;
  wire [31:0] spad_cnm_addr0, spad_cnm_addr1, spad_cnm_addr2, spad_cnm_addr3;
  reg [31:0] spad_rdata=0;
  reg spad_error=0;
  reg spad_parity_error=0;
  reg spad_line_error=0;
  reg [3:0] spad_line_parity_error=0;
  wire rsp_valid;
  wire [2:0] rsp_client;
  wire rsp_is_line;
  wire [2:0] request_client;
  wire [31:0] rsp_rdata;
  wire rsp_error;
  wire [3:0] cnm_rsp_valid;
  integer i;
  integer cnm_grants, dma_line_grants;
  integer core_rr_grants, banked_rr_grants, dma_rr_grants;
  integer core_wait_cycles, banked_wait_cycles, dma_wait_cycles;
  integer rr_mode_cycle, rr_mode_drain, rr_mode_cycles;
  integer rr_mode_core_grants, rr_mode_banked_grants, rr_mode_dma_grants;
  integer rr_mode_core_wait, rr_mode_banked_wait, rr_mode_dma_wait;
  integer rr_mode_core_max_wait, rr_mode_banked_max_wait, rr_mode_dma_max_wait;
  integer rr_mode_core_scalar, rr_mode_core_line;
  integer rr_mode_banked_single, rr_mode_banked_cnm;
  integer rr_mode_dma_scalar, rr_mode_dma_line;
  reg [31:0] rr_mode_seed;
  reg rr_mode_core_fire, rr_mode_banked_fire, rr_mode_dma_fire;

  always #5 clk=~clk;
  ai_spad_arbiter dut(.*);

  function [31:0] xorshift32;
    input [31:0] value;
    reg [31:0] next_value;
    begin
      next_value = value ^ (value << 13);
      next_value = next_value ^ (next_value >> 17);
      next_value = next_value ^ (next_value << 5);
      xorshift32 = next_value;
    end
  endfunction

  task check_rr_mode_cycle;
    integer active_grants;
    begin
      rr_mode_core_fire = (core_ready || core_line_ready) &&
                          (core_valid || core_line_valid);
      rr_mode_banked_fire = (banked_ready || (|cnm_ready)) &&
                            (banked_valid || (|cnm_valid));
      rr_mode_dma_fire = (dma_ready || dma_line_ready) &&
                         (dma_valid || dma_line_valid);
      active_grants = (rr_mode_core_fire ? 1 : 0) +
                      (rr_mode_banked_fire ? 1 : 0) +
                      (rr_mode_dma_fire ? 1 : 0);
      if (active_grants > 1)
        $fatal(1,"multiple data-plane clients granted in one scheduler cycle");

      if (core_valid || core_line_valid) begin
        if (rr_mode_core_fire) begin
          if (rr_mode_core_wait > 2)
            $fatal(1,"random-mode core wait exceeded RR bound: %0d",rr_mode_core_wait);
          if (rr_mode_core_wait > rr_mode_core_max_wait)
            rr_mode_core_max_wait = rr_mode_core_wait;
          rr_mode_core_grants = rr_mode_core_grants + 1;
          if (core_line_valid) rr_mode_core_line = rr_mode_core_line + 1;
          else rr_mode_core_scalar = rr_mode_core_scalar + 1;
          rr_mode_core_wait = 0;
          if (request_client != 3'd2)
            $fatal(1,"random-mode core grant has client tag %0d",request_client);
        end else begin
          rr_mode_core_wait = rr_mode_core_wait + 1;
          if (rr_mode_core_wait > 2)
            $fatal(1,"random-mode core starvation exceeded two cycles");
        end
      end else begin
        rr_mode_core_wait = 0;
      end

      if (banked_valid || (|cnm_valid)) begin
        if (rr_mode_banked_fire) begin
          if (rr_mode_banked_wait > 2)
            $fatal(1,"random-mode banked wait exceeded RR bound: %0d",rr_mode_banked_wait);
          if (rr_mode_banked_wait > rr_mode_banked_max_wait)
            rr_mode_banked_max_wait = rr_mode_banked_wait;
          rr_mode_banked_grants = rr_mode_banked_grants + 1;
          if (|cnm_valid) rr_mode_banked_cnm = rr_mode_banked_cnm + 1;
          else rr_mode_banked_single = rr_mode_banked_single + 1;
          rr_mode_banked_wait = 0;
          if (request_client != 3'd3)
            $fatal(1,"random-mode banked grant has client tag %0d",request_client);
        end else begin
          rr_mode_banked_wait = rr_mode_banked_wait + 1;
          if (rr_mode_banked_wait > 2)
            $fatal(1,"random-mode banked starvation exceeded two cycles");
        end
      end else begin
        rr_mode_banked_wait = 0;
      end

      if (dma_valid || dma_line_valid) begin
        if (rr_mode_dma_fire) begin
          if (rr_mode_dma_wait > 2)
            $fatal(1,"random-mode DMA wait exceeded RR bound: %0d",rr_mode_dma_wait);
          if (rr_mode_dma_wait > rr_mode_dma_max_wait)
            rr_mode_dma_max_wait = rr_mode_dma_wait;
          rr_mode_dma_grants = rr_mode_dma_grants + 1;
          if (dma_line_valid) rr_mode_dma_line = rr_mode_dma_line + 1;
          else rr_mode_dma_scalar = rr_mode_dma_scalar + 1;
          rr_mode_dma_wait = 0;
          if (request_client != 3'd4)
            $fatal(1,"random-mode DMA grant has client tag %0d",request_client);
        end else begin
          rr_mode_dma_wait = rr_mode_dma_wait + 1;
          if (rr_mode_dma_wait > 2)
            $fatal(1,"random-mode DMA starvation exceeded two cycles");
        end
      end else begin
        rr_mode_dma_wait = 0;
      end
    end
  endtask

  initial begin
    repeat(3) @(posedge clk);
    resetn=1;
    core_valid=1;
    banked_valid=1;
    dma_valid=1;
    for(i=0;i<6;i=i+1) begin
      @(negedge clk);
      case(i%3)
        0: if(!core_ready || banked_ready || dma_ready)
             $fatal(1,"RR expected core at step %0d",i);
        1: if(core_ready || !banked_ready || dma_ready)
             $fatal(1,"RR expected banked at step %0d",i);
        2: if(core_ready || banked_ready || !dma_ready)
             $fatal(1,"RR expected DMA at step %0d",i);
      endcase
      @(posedge clk);
    end
    desc_valid=1;
    @(negedge clk);
    if(!desc_ready || core_ready || banked_ready || dma_ready)
      $fatal(1,"descriptor did not retain control-plane priority");
    @(posedge clk);
    desc_valid=0;
    core_valid=0;
    banked_valid=0;
    dma_valid=0;
    core_line_valid=1;
    core_line_addr=32'h100;
    @(negedge clk);
    if(!core_line_ready || core_ready || dma_line_ready ||
       !spad_line_valid || request_client!=3'd2)
      $fatal(1,"core 128-bit line request was not admitted");
    @(posedge clk);
    core_line_valid=0;
    dma_line_valid=1;
    dma_line_addr=32'h200;
    @(negedge clk);
    if(!dma_line_ready || dma_ready || core_line_ready ||
       !spad_line_valid || request_client!=3'd4)
      $fatal(1,"DMA 128-bit line request was not admitted");
    @(posedge clk);
    dma_line_valid=0;
    // Sustained CNM-read and DMA-line traffic shares the one scheduler port.
    // This is deliberately an arbiter-level contention test: the software
    // register ABI forbids launching a standalone DMA while a direct command
    // is busy.  It proves the physical SPAD admission policy used when an
    // internal tile pipeline overlaps DMA and compute, without claiming an
    // unsupported direct-DMA-plus-CNM workload.
    cnm_valid=4'b1111;
    cnm_addr0=32'h0100; cnm_addr1=32'h0204;
    cnm_addr2=32'h0308; cnm_addr3=32'h040c;
    dma_line_valid=1;
    dma_line_addr=32'h0800;
    cnm_grants=0;
    dma_line_grants=0;
    for(i=0;i<12;i=i+1) begin
      @(negedge clk);
      if (cnm_ready == 4'hf)
        cnm_grants=cnm_grants+1;
      if (dma_line_ready)
        dma_line_grants=dma_line_grants+1;
      @(posedge clk);
    end
    @(negedge clk);
    cnm_valid=0;
    dma_line_valid=0;
    if (cnm_grants == 0 || dma_line_grants == 0 ||
        (cnm_grants > dma_line_grants+1) ||
        (dma_line_grants > cnm_grants+1))
      $fatal(1,"CNM/DMA contention was not fair cnm=%0d dma=%0d",
             cnm_grants,dma_line_grants);
    $display("CNM/DMA SPAD contention PASS cnm_grants=%0d dma_line_grants=%0d",
             cnm_grants,dma_line_grants);

    // Keep all three data-plane clients continuously requesting. The RR
    // cursor must bound each client's wait to at most the two grants owed to
    // the other clients, not merely produce nonzero aggregate grant counts.
    core_valid=1;
    banked_valid=1;
    dma_line_valid=1;
    core_rr_grants=0;
    banked_rr_grants=0;
    dma_rr_grants=0;
    core_wait_cycles=0;
    banked_wait_cycles=0;
    dma_wait_cycles=0;
    for(i=0;i<30;i=i+1) begin
      @(negedge clk);
      if(core_ready) begin
        if(core_wait_cycles>2)
          $fatal(1,"core RR wait exceeded bound: %0d",core_wait_cycles);
        core_rr_grants=core_rr_grants+1;
        core_wait_cycles=0;
      end else begin
        core_wait_cycles=core_wait_cycles+1;
      end
      if(banked_ready) begin
        if(banked_wait_cycles>2)
          $fatal(1,"banked RR wait exceeded bound: %0d",banked_wait_cycles);
        banked_rr_grants=banked_rr_grants+1;
        banked_wait_cycles=0;
      end else begin
        banked_wait_cycles=banked_wait_cycles+1;
      end
      if(dma_line_ready) begin
        if(dma_wait_cycles>2)
          $fatal(1,"DMA RR wait exceeded bound: %0d",dma_wait_cycles);
        dma_rr_grants=dma_rr_grants+1;
        dma_wait_cycles=0;
      end else begin
        dma_wait_cycles=dma_wait_cycles+1;
      end
      @(posedge clk);
    end
    @(negedge clk);
    core_valid=0;
    banked_valid=0;
    dma_line_valid=0;
    if(core_rr_grants!=10 || banked_rr_grants!=10 || dma_rr_grants!=10)
      $fatal(1,"3-client RR grant distribution mismatch core=%0d banked=%0d dma=%0d",
             core_rr_grants,banked_rr_grants,dma_rr_grants);
    $display("3-client sustained SPAD round-robin PASS grants=%0d/%0d/%0d max_wait=2",
             core_rr_grants,banked_rr_grants,dma_rr_grants);

    // Sustain all three data-plane clients while changing each request form
    // after its handshake. This exercises scalar/line and banked/CNM paths
    // under repeated arbitration stalls without inventing downstream memory
    // back-pressure (the scheduler-side SPAD port has no ready input).
    rr_mode_cycles=300;
    if ($value$plusargs("SPAD_RR_MODE_CYCLES=%d", rr_mode_cycles)) begin
      if (rr_mode_cycles<300 || rr_mode_cycles>1000000)
        $fatal(1,"SPAD_RR_MODE_CYCLES must be in 300..1000000, got %0d",
               rr_mode_cycles);
    end
    rr_mode_seed=32'hA10D2026;
    rr_mode_core_grants=0; rr_mode_banked_grants=0; rr_mode_dma_grants=0;
    rr_mode_core_wait=0; rr_mode_banked_wait=0; rr_mode_dma_wait=0;
    rr_mode_core_max_wait=0; rr_mode_banked_max_wait=0; rr_mode_dma_max_wait=0;
    rr_mode_core_scalar=0; rr_mode_core_line=0;
    rr_mode_banked_single=0; rr_mode_banked_cnm=0;
    rr_mode_dma_scalar=0; rr_mode_dma_line=0;
    core_valid=0; core_line_valid=0; core_line_addr=32'h0100;
    banked_valid=0; cnm_valid=0;
    dma_valid=0; dma_line_valid=0; dma_line_addr=32'h0800;
    rr_mode_seed=xorshift32(rr_mode_seed);
    if (rr_mode_seed[0]) core_line_valid=1; else core_valid=1;
    rr_mode_seed=xorshift32(rr_mode_seed);
    if (rr_mode_seed[0]) cnm_valid=4'hf; else banked_valid=1;
    rr_mode_seed=xorshift32(rr_mode_seed);
    if (rr_mode_seed[0]) dma_line_valid=1; else dma_valid=1;

    for (rr_mode_cycle=0; rr_mode_cycle<rr_mode_cycles; rr_mode_cycle=rr_mode_cycle+1) begin
      @(negedge clk);
      check_rr_mode_cycle();
      if (!(rr_mode_core_fire || rr_mode_banked_fire || rr_mode_dma_fire))
        $fatal(1,"random-mode sustained traffic had no grant");
      @(posedge clk);
      #1;
      if (rr_mode_core_fire) begin
        if (rr_mode_cycle==rr_mode_cycles-1) begin
          core_valid=0; core_line_valid=0;
        end else begin
          rr_mode_seed=xorshift32(rr_mode_seed);
          if (rr_mode_seed[0]) begin core_line_valid=1; core_valid=0; end
          else begin core_line_valid=0; core_valid=1; end
        end
      end
      if (rr_mode_banked_fire) begin
        if (rr_mode_cycle==rr_mode_cycles-1) begin
          banked_valid=0; cnm_valid=0;
        end else begin
          rr_mode_seed=xorshift32(rr_mode_seed);
          if (rr_mode_seed[0]) begin cnm_valid=4'hf; banked_valid=0; end
          else begin cnm_valid=0; banked_valid=1; end
        end
      end
      if (rr_mode_dma_fire) begin
        if (rr_mode_cycle==rr_mode_cycles-1) begin
          dma_valid=0; dma_line_valid=0;
        end else begin
          rr_mode_seed=xorshift32(rr_mode_seed);
          if (rr_mode_seed[0]) begin dma_line_valid=1; dma_valid=0; end
          else begin dma_line_valid=0; dma_valid=1; end
        end
      end
    end

    // Retire the two requests left by the last randomized cycle without
    // issuing replacements; requests must remain asserted until accepted.
    rr_mode_drain=0;
    while ((core_valid || core_line_valid || banked_valid || (|cnm_valid) ||
            dma_valid || dma_line_valid) && rr_mode_drain<3) begin
      @(negedge clk);
      check_rr_mode_cycle();
      @(posedge clk);
      #1;
      if (rr_mode_core_fire) begin core_valid=0; core_line_valid=0; end
      if (rr_mode_banked_fire) begin banked_valid=0; cnm_valid=0; end
      if (rr_mode_dma_fire) begin dma_valid=0; dma_line_valid=0; end
      rr_mode_drain=rr_mode_drain+1;
    end
    if (core_valid || core_line_valid || banked_valid || (|cnm_valid) ||
        dma_valid || dma_line_valid)
      $fatal(1,"random-mode RR drain failed to retire pending requests");
    if (rr_mode_core_grants<100 || rr_mode_banked_grants<100 ||
        rr_mode_dma_grants<100 || rr_mode_core_scalar==0 || rr_mode_core_line==0 ||
        rr_mode_banked_single==0 || rr_mode_banked_cnm==0 ||
        rr_mode_dma_scalar==0 || rr_mode_dma_line==0 ||
        rr_mode_core_max_wait>2 || rr_mode_banked_max_wait>2 || rr_mode_dma_max_wait>2)
      $fatal(1,"random-mode RR coverage incomplete grants=%0d/%0d/%0d modes=%0d/%0d,%0d/%0d,%0d/%0d",
             rr_mode_core_grants,rr_mode_banked_grants,rr_mode_dma_grants,
             rr_mode_core_scalar,rr_mode_core_line,rr_mode_banked_single,
             rr_mode_banked_cnm,rr_mode_dma_scalar,rr_mode_dma_line);
    $display("Seeded request-mode SPAD RR PASS cycles=%0d grants=%0d/%0d/%0d max_wait=%0d/%0d/%0d modes core=%0d/%0d banked=%0d/%0d dma=%0d/%0d",
             rr_mode_cycles,rr_mode_core_grants,rr_mode_banked_grants,
             rr_mode_dma_grants,
             rr_mode_core_max_wait,rr_mode_banked_max_wait,rr_mode_dma_max_wait,
             rr_mode_core_scalar,rr_mode_core_line,rr_mode_banked_single,
             rr_mode_banked_cnm,rr_mode_dma_scalar,rr_mode_dma_line);

    // CNM carries four independent lane addresses through the same unique
    // scheduler admission point.  Verify the lane mask and addresses are
    // preserved, and that the delayed response identifies the same lanes.
    cnm_valid=4'b1011;
    cnm_addr0=32'h0100; cnm_addr1=32'h0204;
    cnm_addr2=32'h0308; cnm_addr3=32'h040c;
    @(negedge clk);
    if(cnm_ready!==4'hf || spad_cnm_valid!==4'b1011 ||
       spad_cnm_addr0!==32'h0100 || spad_cnm_addr1!==32'h0204 ||
       spad_cnm_addr2!==32'h0308 || spad_cnm_addr3!==32'h040c ||
       request_client!=3'd3)
      $fatal(1,"CNM lane request was not admitted intact");
    // Keep valid asserted across the sampling posedge.  Deasserting it at
    // that same posedge races the arbiter's sequential block in simulation:
    // the client tag can be captured while the lane mask is already zero.
    @(posedge clk);
    @(negedge clk);
    cnm_valid=0;
    // The arbiter registers request metadata at the first posedge above and
    // emits its tagged response at the following posedge.
    @(posedge clk);
    @(negedge clk);
    if(cnm_rsp_valid!==4'b1011 || !rsp_valid || rsp_client!=3'd3)
      $fatal(1,"CNM response lane mask was not preserved");
    $display("Scratchpad round-robin arbiter PASS");

    // Scratchpad parity arrives registered with the read-data response.  A
    // parity error asserted in that response cycle must not be sampled one
    // edge early or shifted onto the following request.
    cnm_valid=0;
    core_valid=1;
    core_write=0;
    core_addr=32'h0500;
    spad_parity_error=0;
    @(posedge clk);
    core_valid=0;
    @(posedge clk);
    spad_parity_error=1;
    #1;
    if (rsp_valid!==1'b1 || rsp_client!==3'd2 || rsp_error!==1'b1)
      $fatal(1,"core parity error was not aligned with response valid=%b client=%0d error=%b",
             rsp_valid,rsp_client,rsp_error);
    spad_parity_error=0;
    @(posedge clk);
    #1;
    if (rsp_valid!==1'b0)
      $fatal(1,"core parity response valid did not retire");
    $display("Scratchpad response parity alignment PASS");
    $finish;
  end
endmodule
