`timescale 1ns/1ps

module tb_ai_compute_spad_path_fairness;
  localparam integer NUM_ENGINES = 7;
  localparam integer RUN_CYCLES = 4096;
  localparam integer ENGINE_WAIT_BOUND = 96;
  localparam integer CLIENT_WAIT_BOUND = 32;

  reg clk = 1'b0;
  reg resetn = 1'b0;

  reg [6:0] engine_req_valid = 7'd0;
  reg [6:0] engine_req_write = 7'd0;
  reg [223:0] engine_req_addr = 224'd0;
  reg [223:0] engine_req_wdata = 224'd0;
  wire [6:0] engine_req_ready;
  wire [6:0] engine_protection_error;
  wire [6:0] engine_rsp_valid;
  wire [223:0] engine_rsp_rdata;
  wire [6:0] engine_rsp_error;

  wire mux_core_valid;
  wire mux_core_write;
  wire [31:0] mux_core_addr;
  wire [31:0] mux_core_wdata;
  wire mux_core_ready;
  wire mux_core_protection_error;
  wire mux_core_rsp_valid;
  wire [31:0] mux_core_rsp_rdata;
  wire mux_core_rsp_error;

  reg desc_valid = 1'b0;
  reg desc_write = 1'b0;
  reg [31:0] desc_addr = 32'd0;
  reg [31:0] desc_wdata = 32'd0;
  wire desc_ready;
  reg cpl_valid = 1'b0;
  reg cpl_write = 1'b1;
  reg [31:0] cpl_addr = 32'd0;
  reg [31:0] cpl_wdata = 32'd0;
  wire cpl_ready;
  reg banked_valid = 1'b1;
  reg [31:0] banked_addr = 32'h2000_0000;
  wire banked_ready;
  reg [3:0] cnm_valid = 4'd0;
  reg [31:0] cnm_addr0 = 32'd0;
  reg [31:0] cnm_addr1 = 32'd0;
  reg [31:0] cnm_addr2 = 32'd0;
  reg [31:0] cnm_addr3 = 32'd0;
  wire [3:0] cnm_ready;
  reg dma_valid = 1'b1;
  reg dma_write = 1'b0;
  reg [31:0] dma_addr = 32'h3000_0000;
  reg [31:0] dma_wdata = 32'd0;
  wire dma_ready;
  reg dma_line_valid = 1'b0;
  reg dma_line_write = 1'b0;
  reg [31:0] dma_line_addr = 32'd0;
  reg [127:0] dma_line_wdata = 128'd0;
  reg [15:0] dma_line_wstrb = 16'd0;
  wire dma_line_ready;
  wire core_line_ready;

  wire spad_valid;
  wire spad_write;
  wire [31:0] spad_addr;
  wire [31:0] spad_wdata;
  wire spad_line_valid;
  wire spad_line_write;
  wire [31:0] spad_line_addr;
  wire [127:0] spad_line_wdata;
  wire [15:0] spad_line_wstrb;
  wire spad_banked_valid;
  wire [31:0] spad_banked_addr;
  wire [3:0] spad_cnm_valid;
  wire [31:0] spad_cnm_addr0;
  wire [31:0] spad_cnm_addr1;
  wire [31:0] spad_cnm_addr2;
  wire [31:0] spad_cnm_addr3;
  wire [2:0] request_client;
  wire arb_rsp_valid;
  wire [2:0] arb_rsp_client;
  wire arb_rsp_is_line;
  wire [3:0] arb_cnm_rsp_valid;
  wire [31:0] arb_rsp_rdata;
  wire arb_rsp_error;

  reg [31:0] spad_rdata_stage = 32'd0;
  reg [31:0] spad_rdata = 32'd0;
  reg spad_parity_stage = 1'b0;
  reg spad_parity_error = 1'b0;
  reg [3:0] spad_line_parity_error = 4'd0;
  reg spad_line_error = 1'b0;
  wire spad_error;
  reg [31:0] selected_mem_addr;

  integer engine_seq [0:6];
  integer engine_grants [0:6];
  integer engine_read_grants [0:6];
  integer engine_write_grants [0:6];
  integer engine_responses [0:6];
  integer engine_wait_age [0:6];
  integer engine_max_wait [0:6];
  integer banked_seq = 0;
  integer dma_seq = 0;
  integer desc_seq = 0;
  integer cpl_seq = 0;
  integer banked_grants = 0;
  integer dma_grants = 0;
  integer desc_grants = 0;
  integer cpl_grants = 0;
  integer banked_wait_age = 0;
  integer banked_max_wait = 0;
  integer dma_wait_age = 0;
  integer dma_max_wait = 0;
  integer core_group_wait_age = 0;
  integer core_group_max_wait = 0;
  integer expected_responses = 0;
  integer total_accepts = 0;
  integer cycle;
  integer owner;
  integer lane;
  integer accepted_client;
  integer accepted_owner;
  integer accepted_total;
  integer selected_write;
  integer desc_pending = 0;
  integer cpl_pending = 0;
  reg pending_rsp_valid = 1'b0;
  reg [2:0] pending_rsp_client = 3'd0;
  integer pending_rsp_owner = 0;
  reg [31:0] pending_rsp_data = 32'd0;
  reg pending_rsp_error = 1'b0;
  reg new_pending_rsp_valid;
  reg [2:0] new_pending_rsp_client;
  integer new_pending_rsp_owner;
  reg [31:0] new_pending_rsp_data;
  reg new_pending_rsp_error;

  always #5 clk = ~clk;

  function automatic [31:0] engine_addr(input integer engine, input integer seq);
    engine_addr = 32'h1000_0000 | (engine << 20) | ((seq & 16'hffff) << 2);
  endfunction

  function automatic [31:0] seq_addr(input [31:0] base, input integer seq);
    seq_addr = base | ((seq & 24'hffffff) << 2);
  endfunction

  function automatic [31:0] spad_pattern(input [31:0] addr);
    spad_pattern = addr ^ 32'h5ac3_a53c;
  endfunction

  always @* begin
    if (spad_banked_valid)
      selected_mem_addr = spad_banked_addr;
    else
      selected_mem_addr = spad_addr;
  end

  assign spad_error = (spad_valid || spad_banked_valid) && selected_mem_addr[4];

  ai_compute_spad_mux mux_dut (
    .clk(clk), .resetn(resetn),
    .req_valid(engine_req_valid), .req_write(engine_req_write),
    .req_addr(engine_req_addr), .req_wdata(engine_req_wdata),
    .req_ready(engine_req_ready),
    .spad_valid(mux_core_valid), .spad_write(mux_core_write),
    .spad_addr(mux_core_addr), .spad_wdata(mux_core_wdata),
    .spad_ready(mux_core_ready), .spad_protection_error(mux_core_protection_error),
    .req_protection_error(engine_protection_error),
    .rsp_valid(mux_core_rsp_valid), .rsp_rdata(mux_core_rsp_rdata),
    .rsp_error(mux_core_rsp_error), .rsp_parity_error(1'b0),
    .engine_rsp_valid(engine_rsp_valid), .engine_rsp_rdata(engine_rsp_rdata),
    .engine_rsp_error(engine_rsp_error)
  );

  ai_spad_arbiter arbiter_dut (
    .clk(clk), .resetn(resetn),
    .desc_valid(desc_valid), .desc_write(desc_write), .desc_addr(desc_addr),
    .desc_wdata(desc_wdata), .desc_ready(desc_ready),
    .cpl_valid(cpl_valid), .cpl_write(cpl_write), .cpl_addr(cpl_addr),
    .cpl_wdata(cpl_wdata), .cpl_ready(cpl_ready),
    .core_valid(mux_core_valid), .core_write(mux_core_write),
    .core_addr(mux_core_addr), .core_wdata(mux_core_wdata),
    .core_ready(mux_core_ready),
    .core_line_valid(1'b0), .core_line_write(1'b0),
    .core_line_addr(32'd0), .core_line_wdata(128'd0),
    .core_line_wstrb(16'd0), .core_line_ready(core_line_ready),
    .banked_valid(banked_valid), .banked_addr(banked_addr), .banked_ready(banked_ready),
    .cnm_valid(cnm_valid), .cnm_addr0(cnm_addr0), .cnm_addr1(cnm_addr1),
    .cnm_addr2(cnm_addr2), .cnm_addr3(cnm_addr3), .cnm_ready(cnm_ready),
    .dma_valid(dma_valid), .dma_write(dma_write), .dma_addr(dma_addr),
    .dma_wdata(dma_wdata), .dma_ready(dma_ready),
    .dma_line_valid(dma_line_valid), .dma_line_write(dma_line_write),
    .dma_line_addr(dma_line_addr), .dma_line_wdata(dma_line_wdata),
    .dma_line_wstrb(dma_line_wstrb), .dma_line_ready(dma_line_ready),
    .spad_valid(spad_valid), .spad_write(spad_write),
    .spad_addr(spad_addr), .spad_wdata(spad_wdata),
    .spad_line_valid(spad_line_valid), .spad_line_write(spad_line_write),
    .spad_line_addr(spad_line_addr), .spad_line_wdata(spad_line_wdata),
    .spad_line_wstrb(spad_line_wstrb),
    .spad_banked_valid(spad_banked_valid), .spad_banked_addr(spad_banked_addr),
    .spad_cnm_valid(spad_cnm_valid), .spad_cnm_addr0(spad_cnm_addr0),
    .spad_cnm_addr1(spad_cnm_addr1), .spad_cnm_addr2(spad_cnm_addr2),
    .spad_cnm_addr3(spad_cnm_addr3), .spad_rdata(spad_rdata),
    .spad_error(spad_error), .spad_parity_error(spad_parity_error),
    .spad_line_error(spad_line_error), .spad_line_parity_error(spad_line_parity_error),
    .rsp_valid(arb_rsp_valid), .rsp_client(arb_rsp_client),
    .rsp_is_line(arb_rsp_is_line), .cnm_rsp_valid(arb_cnm_rsp_valid),
    .request_client(request_client), .rsp_rdata(arb_rsp_rdata),
    .rsp_error(arb_rsp_error)
  );

  assign mux_core_protection_error = 1'b0;
  assign mux_core_rsp_valid = arb_rsp_valid && (arb_rsp_client == 3'd2);
  assign mux_core_rsp_rdata = arb_rsp_rdata;
  assign mux_core_rsp_error = arb_rsp_error;

  ap_scheduler_grant_at_most_one: assert property (
    @(posedge clk) disable iff (!resetn)
    $onehot0({desc_ready, cpl_ready, mux_core_ready, banked_ready, dma_ready})
  ) else $fatal(1, "scheduler admitted multiple scalar clients");

  ap_engine_response_onehot: assert property (
    @(posedge clk) disable iff (!resetn)
    (|engine_rsp_valid) |-> $onehot(engine_rsp_valid)
  ) else $fatal(1, "one core response was routed to multiple engines");

  ap_core_payload_stable_under_preemption: assert property (
    @(posedge clk) disable iff (!resetn)
    (mux_core_valid && !mux_core_ready) |=>
      (mux_core_valid && $stable({mux_core_write, mux_core_addr, mux_core_wdata}))
  ) else $fatal(1, "compute MUX changed the selected request while scheduler preempted it");

  cp_desc_beats_completion: cover property (
    @(posedge clk) disable iff (!resetn)
    desc_valid && cpl_valid && desc_ready && !cpl_ready
  );
  cp_core_admitted: cover property (@(posedge clk) disable iff (!resetn) mux_core_ready);
  cp_banked_admitted: cover property (@(posedge clk) disable iff (!resetn) banked_ready);
  cp_dma_admitted: cover property (@(posedge clk) disable iff (!resetn) dma_ready);

  task automatic check_pending_response;
    reg [6:0] expected_valid;
    reg [6:0] expected_error;
    begin
      if (arb_rsp_valid !== pending_rsp_valid)
        $fatal(1, "scheduler response valid mismatch expected=%b actual=%b client=%0d",
               pending_rsp_valid, arb_rsp_valid, pending_rsp_client);
      if (pending_rsp_valid) begin
        if (arb_rsp_client !== pending_rsp_client)
          $fatal(1, "scheduler response client mismatch expected=%0d actual=%0d",
                 pending_rsp_client, arb_rsp_client);
        if (arb_rsp_rdata !== pending_rsp_data)
          $fatal(1, "scheduler response data mismatch client=%0d expected=%08h actual=%08h",
                 pending_rsp_client, pending_rsp_data, arb_rsp_rdata);
        if (arb_rsp_error !== pending_rsp_error)
          $fatal(1, "scheduler response error mismatch client=%0d expected=%b actual=%b",
                 pending_rsp_client, pending_rsp_error, arb_rsp_error);
        expected_responses = expected_responses + 1;
        if (pending_rsp_client == 3'd2) begin
          expected_valid = 7'b0000001 << pending_rsp_owner;
          expected_error = pending_rsp_error ? expected_valid : 7'd0;
          if (engine_rsp_valid !== expected_valid)
            $fatal(1, "engine response owner mismatch expected=%07b actual=%07b owner=%0d",
                   expected_valid, engine_rsp_valid, pending_rsp_owner);
          if (engine_rsp_rdata[pending_rsp_owner*32 +: 32] !== pending_rsp_data)
            $fatal(1, "engine response payload mismatch owner=%0d expected=%08h actual=%08h",
                   pending_rsp_owner, pending_rsp_data,
                   engine_rsp_rdata[pending_rsp_owner*32 +: 32]);
          if (engine_rsp_error !== expected_error)
            $fatal(1, "engine response error owner mismatch expected=%07b actual=%07b",
                   expected_error, engine_rsp_error);
          for (lane = 0; lane < NUM_ENGINES; lane = lane + 1)
            if ((lane != pending_rsp_owner) &&
                (engine_rsp_rdata[lane*32 +: 32] !== 32'd0))
              $fatal(1, "core response leaked to engine %0d from owner %0d",
                     lane, pending_rsp_owner);
          engine_responses[pending_rsp_owner] = engine_responses[pending_rsp_owner] + 1;
        end else if (engine_rsp_valid !== 7'd0) begin
          $fatal(1, "non-core scheduler response leaked to compute engines: client=%0d valid=%07b",
                 pending_rsp_client, engine_rsp_valid);
        end
      end else if (engine_rsp_valid !== 7'd0) begin
        $fatal(1, "ghost compute-engine response valid=%07b", engine_rsp_valid);
      end
    end
  endtask

  initial begin
    expected_responses = 0;
    total_accepts = 0;
    for (lane = 0; lane < NUM_ENGINES; lane = lane + 1) begin
      engine_seq[lane] = 0;
      engine_grants[lane] = 0;
      engine_read_grants[lane] = 0;
      engine_write_grants[lane] = 0;
      engine_responses[lane] = 0;
      engine_wait_age[lane] = 0;
      engine_max_wait[lane] = 0;
    end
    pending_rsp_valid = 1'b0;
    pending_rsp_client = 3'd0;
    pending_rsp_owner = 0;
    pending_rsp_data = 32'd0;
    pending_rsp_error = 1'b0;

    repeat (3) @(negedge clk);
    resetn = 1'b1;
    engine_req_valid = 7'h7f;
    for (lane = 0; lane < NUM_ENGINES; lane = lane + 1) begin
      engine_req_write[lane] = ((engine_seq[lane] % 5) == 0);
      engine_req_addr[lane*32 +: 32] = engine_addr(lane, engine_seq[lane]);
      engine_req_wdata[lane*32 +: 32] = 32'hcc00_0000 | (lane << 16) | engine_seq[lane];
    end
    banked_valid = 1'b1;
    banked_addr = seq_addr(32'h2000_0000, banked_seq);
    dma_valid = 1'b1;
    dma_addr = seq_addr(32'h3000_0000, dma_seq);
    dma_write = ((dma_seq % 4) == 0);
    dma_wdata = 32'hdd00_0000 | dma_seq;

    for (cycle = 0; cycle < RUN_CYCLES; cycle = cycle + 1) begin
      @(negedge clk);
      if ((cycle % 211) == 19) begin
        desc_pending = 1;
        cpl_pending = 1;
      end
      desc_valid = desc_pending[0];
      cpl_valid = cpl_pending[0];
      desc_write = 1'b0;
      desc_addr = seq_addr(32'h4000_0000, desc_seq);
      cpl_write = 1'b1;
      cpl_addr = seq_addr(32'h5000_0000, cpl_seq);
      cpl_wdata = 32'hc011_0000 | cpl_seq;

      @(posedge clk);
      accepted_total = desc_ready + cpl_ready + mux_core_ready + banked_ready + dma_ready;
      if (accepted_total != 1)
        $fatal(1, "scheduler grant count expected 1 actual=%0d client=%0d", accepted_total, request_client);
      if ((spad_valid || spad_banked_valid) !== 1'b1 ||
          (spad_valid && spad_banked_valid))
        $fatal(1, "accepted scheduler cycle must expose exactly one memory request");
      if (spad_line_valid || (|spad_cnm_valid))
        $fatal(1, "disabled line/CNM requester appeared in test");

      new_pending_rsp_valid = 1'b0;
      new_pending_rsp_client = request_client;
      new_pending_rsp_owner = 0;
      new_pending_rsp_data = 32'd0;
      new_pending_rsp_error = 1'b0;
      selected_write = spad_valid ? spad_write : 1'b0;
      accepted_owner = -1;
      accepted_client = request_client;
      if (desc_ready) begin
        if (request_client != 3'd0 || desc_addr != spad_addr)
          $fatal(1, "descriptor priority/selected address mismatch");
        desc_grants = desc_grants + 1;
        desc_seq = desc_seq + 1;
        desc_pending = 0;
      end else if (cpl_ready) begin
        if (request_client != 3'd1 || cpl_addr != spad_addr || !spad_write)
          $fatal(1, "completion write selection mismatch");
        cpl_grants = cpl_grants + 1;
        cpl_seq = cpl_seq + 1;
        cpl_pending = 0;
      end else if (mux_core_ready) begin
        if ($countones(engine_req_ready) != 1)
          $fatal(1, "core scheduler grant must identify one MUX engine");
        accepted_owner = engine_req_ready[0] ? 0 :
                         engine_req_ready[1] ? 1 :
                         engine_req_ready[2] ? 2 :
                         engine_req_ready[3] ? 3 :
                         engine_req_ready[4] ? 4 :
                         engine_req_ready[5] ? 5 : 6;
        if (request_client != 3'd2 || mux_core_addr !== spad_addr ||
            mux_core_write !== spad_write ||
            engine_req_addr[accepted_owner*32 +: 32] !== mux_core_addr)
          $fatal(1, "compute MUX/arbiter accepted-owner mismatch engine=%0d", accepted_owner);
        engine_grants[accepted_owner] = engine_grants[accepted_owner] + 1;
        engine_seq[accepted_owner] = engine_seq[accepted_owner] + 1;
        if (spad_write) begin
          engine_write_grants[accepted_owner] = engine_write_grants[accepted_owner] + 1;
        end else begin
          engine_read_grants[accepted_owner] = engine_read_grants[accepted_owner] + 1;
        end
        engine_req_write[accepted_owner] = ((engine_seq[accepted_owner] % 5) == 0);
        engine_req_addr[accepted_owner*32 +: 32] = engine_addr(accepted_owner, engine_seq[accepted_owner]);
        engine_req_wdata[accepted_owner*32 +: 32] =
          32'hcc00_0000 | (accepted_owner << 16) | engine_seq[accepted_owner];
      end else if (banked_ready) begin
        if (request_client != 3'd3 || !spad_banked_valid || banked_addr != spad_banked_addr)
          $fatal(1, "banked scheduler owner mismatch");
        banked_grants = banked_grants + 1;
        banked_seq = banked_seq + 1;
        banked_addr = seq_addr(32'h2000_0000, banked_seq);
      end else if (dma_ready) begin
        if (request_client != 3'd4 || !spad_valid || dma_addr != spad_addr)
          $fatal(1, "DMA scheduler owner mismatch");
        dma_grants = dma_grants + 1;
        dma_seq = dma_seq + 1;
        dma_addr = seq_addr(32'h3000_0000, dma_seq);
        dma_write = ((dma_seq % 4) == 0);
        dma_wdata = 32'hdd00_0000 | dma_seq;
      end

      if (spad_valid || spad_banked_valid) begin
        total_accepts = total_accepts + 1;
        if (!selected_write) begin
          new_pending_rsp_valid = 1'b1;
          new_pending_rsp_client = request_client;
          new_pending_rsp_data = spad_pattern(selected_mem_addr);
          new_pending_rsp_error = selected_mem_addr[4] || selected_mem_addr[2];
          if (request_client == 3'd2)
            new_pending_rsp_owner = selected_mem_addr[22:20];
          else if (request_client == 3'd0)
            new_pending_rsp_owner = 0;
          else if (request_client == 3'd3)
            new_pending_rsp_owner = 3;
          else if (request_client == 3'd4)
            new_pending_rsp_owner = 4;
          else
            $fatal(1, "unexpected read response client=%0d", request_client);
        end
      end

      for (lane = 0; lane < NUM_ENGINES; lane = lane + 1) begin
        if (engine_req_ready[lane]) begin
          engine_wait_age[lane] = 0;
        end else begin
          engine_wait_age[lane] = engine_wait_age[lane] + 1;
          if (engine_wait_age[lane] > engine_max_wait[lane])
            engine_max_wait[lane] = engine_wait_age[lane];
          if (engine_wait_age[lane] > ENGINE_WAIT_BOUND)
            $fatal(1, "engine %0d exceeded end-to-end scheduler wait bound", lane);
        end
      end
      if (mux_core_ready) core_group_wait_age = 0;
      else begin
        core_group_wait_age = core_group_wait_age + 1;
        if (core_group_wait_age > core_group_max_wait)
          core_group_max_wait = core_group_wait_age;
        if (core_group_wait_age > CLIENT_WAIT_BOUND)
          $fatal(1, "core scheduler client exceeded wait bound");
      end
      if (banked_ready) banked_wait_age = 0;
      else begin
        banked_wait_age = banked_wait_age + 1;
        if (banked_wait_age > banked_max_wait) banked_max_wait = banked_wait_age;
        if (banked_wait_age > CLIENT_WAIT_BOUND)
          $fatal(1, "banked scheduler client exceeded wait bound");
      end
      if (dma_ready) dma_wait_age = 0;
      else begin
        dma_wait_age = dma_wait_age + 1;
        if (dma_wait_age > dma_max_wait) dma_max_wait = dma_wait_age;
        if (dma_wait_age > CLIENT_WAIT_BOUND)
          $fatal(1, "DMA scheduler client exceeded wait bound");
      end

      #1;
      check_pending_response();
      pending_rsp_valid = new_pending_rsp_valid;
      pending_rsp_client = new_pending_rsp_client;
      pending_rsp_owner = new_pending_rsp_owner;
      pending_rsp_data = new_pending_rsp_data;
      pending_rsp_error = new_pending_rsp_error;
    end

    @(negedge clk);
    desc_valid = 1'b0;
    cpl_valid = 1'b0;
    engine_req_valid = 7'd0;
    banked_valid = 1'b0;
    dma_valid = 1'b0;
    repeat (3) begin
      @(posedge clk);
      #1;
      check_pending_response();
      pending_rsp_valid = 1'b0;
      pending_rsp_client = 3'd0;
      pending_rsp_owner = 0;
      pending_rsp_data = 32'd0;
      pending_rsp_error = 1'b0;
    end

    if (desc_grants == 0 || cpl_grants == 0 || banked_grants == 0 || dma_grants == 0)
      $fatal(1, "scheduler client missing grants desc/cpl/banked/dma=%0d/%0d/%0d/%0d",
             desc_grants, cpl_grants, banked_grants, dma_grants);
    for (lane = 0; lane < NUM_ENGINES; lane = lane + 1) begin
      if (engine_grants[lane] == 0 || engine_read_grants[lane] == 0 ||
          engine_write_grants[lane] == 0)
        $fatal(1, "engine %0d missing read/write grants=%0d/%0d/%0d", lane,
               engine_grants[lane], engine_read_grants[lane], engine_write_grants[lane]);
      if (engine_responses[lane] != engine_read_grants[lane])
        $fatal(1, "engine %0d lost or duplicated read response=%0d/%0d", lane,
               engine_read_grants[lane], engine_responses[lane]);
    end
    if (arb_rsp_valid !== 1'b0 || engine_rsp_valid !== 7'd0)
      $fatal(1, "response pipe did not drain after final read");

    $display("COMPUTE_SPAD_PATH_FAIRNESS_PASS cycles=%0d accepts=%0d engines=%0d/%0d/%0d/%0d/%0d/%0d/%0d max_engine_wait=%0d/%0d/%0d/%0d/%0d/%0d/%0d groups_core_banked_dma=%0d/%0d/%0d controls_desc_cpl=%0d/%0d responses=%0d",
             RUN_CYCLES, total_accepts,
             engine_grants[0], engine_grants[1], engine_grants[2], engine_grants[3],
             engine_grants[4], engine_grants[5], engine_grants[6],
             engine_max_wait[0], engine_max_wait[1], engine_max_wait[2], engine_max_wait[3],
             engine_max_wait[4], engine_max_wait[5], engine_max_wait[6],
             core_group_max_wait, banked_max_wait, dma_max_wait,
             desc_grants, cpl_grants, expected_responses);
    $finish;
  end

  always @(posedge clk or negedge resetn) begin
    if (!resetn) begin
      spad_rdata_stage <= 32'd0;
      spad_rdata <= 32'd0;
      spad_parity_stage <= 1'b0;
      spad_parity_error <= 1'b0;
    end else begin
      spad_rdata <= spad_rdata_stage;
      spad_parity_error <= spad_parity_stage;
      if (spad_valid || spad_banked_valid) begin
        spad_rdata_stage <= spad_pattern(selected_mem_addr);
        spad_parity_stage <= selected_mem_addr[2];
      end else begin
        spad_rdata_stage <= 32'd0;
        spad_parity_stage <= 1'b0;
      end
    end
  end
endmodule
