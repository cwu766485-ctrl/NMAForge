`timescale 1ns/1ps

module tb_ai_compute_spad_mux_fairness;
  localparam integer NUM_ENGINES = 7;
  localparam integer RUN_CYCLES = 4096;
  localparam integer MAX_WAIT_BOUND = 32;

  reg clk = 1'b0;
  reg resetn = 1'b0;
  reg [6:0] req_valid = 7'd0;
  reg [6:0] req_write = 7'd0;
  reg [223:0] req_addr = 224'd0;
  reg [223:0] req_wdata = 224'd0;
  wire [6:0] req_ready;
  wire spad_valid;
  wire spad_write;
  wire [31:0] spad_addr;
  wire [31:0] spad_wdata;
  reg spad_ready = 1'b0;
  reg spad_protection_error = 1'b0;
  wire [6:0] req_protection_error;
  reg rsp_valid = 1'b0;
  reg [31:0] rsp_rdata = 32'd0;
  reg rsp_error = 1'b0;
  reg rsp_parity_error = 1'b0;
  wire [6:0] engine_rsp_valid;
  wire [223:0] engine_rsp_rdata;
  wire [6:0] engine_rsp_error;

  integer seqno [0:6];
  integer grants [0:6];
  integer read_grants [0:6];
  integer write_grants [0:6];
  integer responses [0:6];
  integer wait_age [0:6];
  integer max_wait [0:6];
  integer i;
  integer cycle;
  integer owner;
  integer valid_count;
  integer rsp_owner;
  integer total_grants;
  integer total_responses;
  reg stall_active;
  reg [31:0] stalled_addr;
  reg [31:0] stalled_wdata;
  reg stalled_write;
  reg pending_valid;
  integer pending_owner;
  reg [31:0] pending_data;
  reg pending_error;
  reg pending_parity_error;
  reg new_pending_valid;
  integer new_pending_owner;
  reg [31:0] new_pending_data;
  reg new_pending_error;
  reg new_pending_parity_error;

  always #5 clk = ~clk;

  ai_compute_spad_mux dut (.*);

  ap_ready_onehot: assert property (
    @(posedge clk) disable iff (!resetn)
    $onehot0(req_ready)
  ) else $fatal(1, "more than one engine received request ready");

  ap_stalled_payload_stable: assert property (
    @(posedge clk) disable iff (!resetn)
    (spad_valid && !spad_ready) |=>
      (spad_valid && $stable({spad_write, spad_addr, spad_wdata}))
  ) else $fatal(1, "selected engine payload changed before SPAD acceptance");

  ap_response_owner_onehot: assert property (
    @(posedge clk) disable iff (!resetn)
    (|engine_rsp_valid) |-> $onehot(engine_rsp_valid)
  ) else $fatal(1, "one response was routed to multiple engines");

  function automatic [31:0] make_addr(input integer engine, input integer seqno_value);
    begin
      make_addr = 32'h1000_0000 | (engine << 20) | ((seqno_value & 16'hffff) << 2);
    end
  endfunction

  function automatic [31:0] make_wdata(input integer engine, input integer seqno_value);
    begin
      make_wdata = 32'hcc00_0000 | (engine << 16) | (seqno_value & 16'hffff);
    end
  endfunction

  function automatic [31:0] make_rdata(input [31:0] addr);
    begin
      make_rdata = addr ^ 32'ha5c3_5a3c;
    end
  endfunction

  task automatic check_response;
    reg [6:0] expected_valid;
    reg [6:0] expected_error;
    integer lane;
    begin
      if (pending_valid) begin
        expected_valid = 7'b0000001 << pending_owner;
        expected_error = (pending_error || pending_parity_error) ? expected_valid : 7'd0;
        if (engine_rsp_valid !== expected_valid)
          $fatal(1, "response owner mismatch expected=%07b actual=%07b owner=%0d",
                 expected_valid, engine_rsp_valid, pending_owner);
        if (engine_rsp_rdata[pending_owner*32 +: 32] !== pending_data)
          $fatal(1, "response data mismatch owner=%0d expected=%08h actual=%08h",
                 pending_owner, pending_data,
                 engine_rsp_rdata[pending_owner*32 +: 32]);
        if (engine_rsp_error !== expected_error)
          $fatal(1, "response error mismatch owner=%0d expected=%07b actual=%07b",
                 pending_owner, expected_error, engine_rsp_error);
        for (lane = 0; lane < NUM_ENGINES; lane++) begin
          if ((lane != pending_owner) &&
              (engine_rsp_rdata[lane*32 +: 32] !== 32'd0))
            $fatal(1, "response data leaked to engine=%0d owner=%0d",
                   lane, pending_owner);
        end
        responses[pending_owner] = responses[pending_owner] + 1;
        total_responses = total_responses + 1;
      end else if (engine_rsp_valid !== 7'd0) begin
        $fatal(1, "ghost response valid=%07b", engine_rsp_valid);
      end
    end
  endtask

  initial begin
    total_grants = 0;
    total_responses = 0;
    stall_active = 1'b0;
    pending_valid = 1'b0;
    pending_owner = 0;
    pending_data = 32'd0;
    pending_error = 1'b0;
    pending_parity_error = 1'b0;
    for (i = 0; i < NUM_ENGINES; i = i + 1) begin
      seqno[i] = 0;
      grants[i] = 0;
      read_grants[i] = 0;
      write_grants[i] = 0;
      responses[i] = 0;
      wait_age[i] = 0;
      max_wait[i] = 0;
    end

    repeat (3) @(negedge clk);
    resetn = 1'b1;
    req_valid = 7'h7f;
    for (i = 0; i < NUM_ENGINES; i = i + 1) begin
      req_write[i] = ((seqno[i] % 5) == 0);
      req_addr[i*32 +: 32] = make_addr(i, seqno[i]);
      req_wdata[i*32 +: 32] = make_wdata(i, seqno[i]);
    end

    for (cycle = 0; cycle < RUN_CYCLES; cycle = cycle + 1) begin
      @(negedge clk);
      // Bounded deterministic ready stalls: no more than three consecutive
      // low cycles, so every continuously-valid requester has an environment
      // progress opportunity within the stated 32-cycle bound.
      spad_ready = ((cycle % 19) != 4) && ((cycle % 19) != 5) &&
                   ((cycle % 19) != 6) && ((cycle % 19) != 13);
      rsp_valid = pending_valid;
      rsp_rdata = pending_data;
      rsp_error = pending_error;
      rsp_parity_error = pending_parity_error;
      spad_protection_error = 1'b0;
      #1;

      if (stall_active &&
          (!spad_valid || spad_addr !== stalled_addr ||
           spad_wdata !== stalled_wdata || spad_write !== stalled_write))
        $fatal(1, "mux changed selected payload while requester was stalled");

      @(posedge clk);
      if ($countones(req_ready) > 1)
        $fatal(1, "multiple engines ready in one cycle: %07b", req_ready);
      if (!spad_ready && req_ready !== 7'd0)
        $fatal(1, "engine ready asserted without SPAD ready: %07b", req_ready);
      if (spad_ready && (!spad_valid || $countones(req_ready) != 1))
        $fatal(1, "ready SPAD request did not admit exactly one engine");

      for (i = 0; i < NUM_ENGINES; i = i + 1) begin
        if (req_ready[i])
          wait_age[i] = 0;
        else begin
          wait_age[i] = wait_age[i] + 1;
          if (wait_age[i] > max_wait[i]) max_wait[i] = wait_age[i];
          if (wait_age[i] > MAX_WAIT_BOUND)
            $fatal(1, "engine %0d exceeded fairness bound %0d", i, MAX_WAIT_BOUND);
        end
      end

      new_pending_valid = 1'b0;
      new_pending_owner = 0;
      new_pending_data = 32'd0;
      new_pending_error = 1'b0;
      new_pending_parity_error = 1'b0;
      if (spad_valid && spad_ready) begin
        owner = spad_addr[22:20];
        if (owner >= NUM_ENGINES)
          $fatal(1, "invalid owner encoded in request address: %0d", owner);
        if (req_ready !== (7'b0000001 << owner))
          $fatal(1, "ready owner does not match selected request owner=%0d ready=%07b",
                 owner, req_ready);
        if (spad_addr !== req_addr[owner*32 +: 32] ||
            spad_wdata !== req_wdata[owner*32 +: 32] ||
            spad_write !== req_write[owner])
          $fatal(1, "selected payload did not match engine %0d request", owner);
        grants[owner] = grants[owner] + 1;
        total_grants = total_grants + 1;
        if (spad_write) begin
          write_grants[owner] = write_grants[owner] + 1;
        end else begin
          read_grants[owner] = read_grants[owner] + 1;
          new_pending_valid = 1'b1;
          new_pending_owner = owner;
          new_pending_data = make_rdata(spad_addr);
          new_pending_error = spad_addr[2];
          new_pending_parity_error = spad_addr[3];
        end
        seqno[owner] = seqno[owner] + 1;
        req_write[owner] = ((seqno[owner] % 5) == 0);
        req_addr[owner*32 +: 32] = make_addr(owner, seqno[owner]);
        req_wdata[owner*32 +: 32] = make_wdata(owner, seqno[owner]);
        stall_active = 1'b0;
      end else if (spad_valid && !spad_ready) begin
        if (!stall_active) begin
          stalled_addr = spad_addr;
          stalled_wdata = spad_wdata;
          stalled_write = spad_write;
        end
        stall_active = 1'b1;
      end else begin
        $fatal(1, "all seven requesters valid but mux produced no request");
      end

      #1;
      check_response();
      pending_valid = new_pending_valid;
      pending_owner = new_pending_owner;
      pending_data = new_pending_data;
      pending_error = new_pending_error;
      pending_parity_error = new_pending_parity_error;
    end

    // Deliver the final registered read response while withholding a new SPAD
    // grant. All legal requesters remain asserted; the held request stays
    // stable and no accepted read is lost.
    @(negedge clk);
    spad_ready = 1'b0;
    rsp_valid = pending_valid;
    rsp_rdata = pending_data;
    rsp_error = pending_error;
    rsp_parity_error = pending_parity_error;
    #1;
    if (stall_active &&
        (!spad_valid || spad_addr !== stalled_addr ||
         spad_wdata !== stalled_wdata || spad_write !== stalled_write))
      $fatal(1, "mux changed held request while draining final response");
    @(posedge clk);
    #1;
    check_response();

    for (i = 0; i < NUM_ENGINES; i = i + 1) begin
      if (grants[i] == 0 || read_grants[i] == 0 || write_grants[i] == 0)
        $fatal(1, "engine %0d lacks grant/read/write evidence: %0d/%0d/%0d",
               i, grants[i], read_grants[i], write_grants[i]);
      if (responses[i] != read_grants[i])
        $fatal(1, "engine %0d response count mismatch reads=%0d responses=%0d",
               i, read_grants[i], responses[i]);
    end
    if (total_responses != total_grants - (write_grants[0] + write_grants[1] +
                                           write_grants[2] + write_grants[3] +
                                           write_grants[4] + write_grants[5] +
                                           write_grants[6]))
      $fatal(1, "aggregate response count does not match accepted read requests");

    $display("COMPUTE_SPAD_MUX_FAIRNESS_PASS cycles=%0d grants=%0d per_engine=%0d/%0d/%0d/%0d/%0d/%0d/%0d max_wait=%0d/%0d/%0d/%0d/%0d/%0d/%0d responses=%0d",
             RUN_CYCLES, total_grants,
             grants[0], grants[1], grants[2], grants[3], grants[4], grants[5], grants[6],
             max_wait[0], max_wait[1], max_wait[2], max_wait[3],
             max_wait[4], max_wait[5], max_wait[6], total_responses);
    $finish;
  end
endmodule
