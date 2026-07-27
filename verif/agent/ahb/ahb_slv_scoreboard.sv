//=============================================================================
// Project  : ahb_soc
//
// File Name: ahb_slv_scoreboard.sv
//
// Description:
//   Class-based scoreboard for the SV AHB SRAM/vector accelerator testbench.
//   The expected stream comes from generator/driver. The actual stream comes
//   from the passive monitor. The scoreboard compares expected intent with
//   actual DUT bus response and updates/checks the reference model.
//=============================================================================

`ifndef AHB_SLV_SCOREBOARD_SV
`define AHB_SLV_SCOREBOARD_SV

class ahb_slv_scoreboard;
  string name;

  bit [7:0] mem [0:64*1024-1];
  int pass_count;
  int error_count;

  localparam bit [31:0] REG_BASE        = 32'h0001_0000;
  localparam bit [31:0] REG_CTRL        = REG_BASE + 32'h00;
  localparam bit [31:0] REG_SRC0_BASE   = REG_BASE + 32'h08;
  localparam bit [31:0] REG_SRC1_BASE   = REG_BASE + 32'h0c;
  localparam bit [31:0] REG_DST_BASE    = REG_BASE + 32'h10;
  localparam bit [31:0] REG_LENGTH      = REG_BASE + 32'h14;
  localparam bit [31:0] REG_SCALE_SHIFT = REG_BASE + 32'h18;
  localparam bit [31:0] REG_SRC0_STRIDE = REG_BASE + 32'h38;
  localparam bit [31:0] REG_SRC1_STRIDE = REG_BASE + 32'h3c;
  localparam bit [31:0] REG_DST_STRIDE  = REG_BASE + 32'h40;
  localparam bit [31:0] REG_CONFIG      = REG_BASE + 32'h44;
  localparam bit [31:0] REG_NEURON_COUNT  = REG_BASE + 32'h54;
  localparam bit [31:0] REG_NEURON_STRIDE = REG_BASE + 32'h58;
  localparam bit [31:0] REG_NEURON_INDEX  = REG_BASE + 32'h5c;
  localparam bit [31:0] REG_SOM_BEST_DIST = REG_BASE + 32'h60;
  localparam bit [31:0] REG_SOM_WINNER    = REG_BASE + 32'h64;

  localparam bit [2:0] OP_SOM_RECALL = 3'd5;
  localparam bit [2:0] OP_SOM_UPDATE = 3'd6;

  bit [31:0] model_src0_base;
  bit [31:0] model_src1_base;
  bit [31:0] model_dst_base;
  bit [15:0] model_length;
  bit [4:0]  model_scale_shift;
  bit [31:0] model_src0_stride;
  bit [31:0] model_src1_stride;
  bit [31:0] model_dst_stride;
  bit        model_signed_mode;
  bit        model_saturate_en;
  bit [1:0]  model_data_width;
  bit [15:0] model_neuron_count;
  bit [31:0] model_neuron_stride;
  bit [15:0] model_neuron_index;
  bit [31:0] model_result;
  bit [31:0] model_som_best_distance;
  bit [15:0] model_som_winner_index;

  ahb_slv_pkt exp_pkt;
  ahb_slv_pkt act_pkt;
  ahb_slv_pkt chk_pkt;

  typedef mailbox #(ahb_slv_pkt) pkt_mailbox;
  pkt_mailbox exp_mbx;
  pkt_mailbox act_mbx;
  pkt_mailbox cov_mbx;

  function new(string name="ahb_slv_scoreboard",
               pkt_mailbox exp_mbx=null,
               pkt_mailbox act_mbx=null,
               pkt_mailbox cov_mbx=null);
    this.name = name;
    this.exp_mbx = exp_mbx;
    this.act_mbx = act_mbx;
    this.cov_mbx = cov_mbx;
    if (this.exp_mbx == null)
      this.exp_mbx = new();
    if (this.act_mbx == null)
      this.act_mbx = new();
    model_src0_base = 32'd0;
    model_src1_base = 32'd0;
    model_dst_base = 32'd0;
    model_length = 16'd0;
    model_scale_shift = 5'd0;
    model_src0_stride = 32'd4;
    model_src1_stride = 32'd4;
    model_dst_stride = 32'd4;
    model_signed_mode = 1'b0;
    model_saturate_en = 1'b0;
    model_data_width = 2'd0;
    model_neuron_count = 16'd1;
    model_neuron_stride = 32'd4;
    model_neuron_index = 16'd0;
    model_result = 32'd0;
    model_som_best_distance = 32'd0;
    model_som_winner_index = 16'd0;
  endfunction

  extern task start();
  extern function void merge_expected_actual(ahb_slv_pkt exp, ahb_slv_pkt act, ref ahb_slv_pkt merged);
  extern function bit check_bus_match(ahb_slv_pkt exp, ahb_slv_pkt act);
  extern function void write_ref(ahb_slv_pkt pkt);
  extern function void check_read(ahb_slv_pkt pkt);
  extern function void check_expected_read(ahb_slv_pkt pkt);
  extern function bit is_reg_access(ahb_slv_pkt pkt);
  extern function void model_reg_write(ahb_slv_pkt pkt);
  extern function void model_start(bit [2:0] op);
  extern function void model_som_recall();
  extern function void model_som_update();
  extern function bit [31:0] read_ref_word(bit [31:0] addr);
  extern function void write_ref_word(bit [31:0] addr, bit [31:0] data);
  extern function int signed lane_value(bit [31:0] word, int lane);
  extern function int lane_count();
  extern function int lane_bits();
  extern function bit [31:0] som_update_word(bit [31:0] x_word, bit [31:0] w_word);
  extern function int signed clamp_lane(int signed value);
  extern function int unsigned byte_index(bit [31:0] addr, int lane);
  extern function void check_byte(bit [31:0] addr, bit [7:0] rdata);
  extern function void report();
endclass : ahb_slv_scoreboard

task ahb_slv_scoreboard::start();
  $display($time, "ns:[ahb_slv_scoreboard] Scoreboard started");
  fork
    forever begin
      exp_mbx.get(exp_pkt);
      act_mbx.get(act_pkt);
      merge_expected_actual(exp_pkt, act_pkt, chk_pkt);

      $display($time, "ns:[ahb_slv_scoreboard] Compare expected transaction with monitored actual response");
      chk_pkt.display();

      if (!check_bus_match(exp_pkt, act_pkt)) begin
        error_count++;
        $display($time, "ns:[ahb_slv_scoreboard][ERROR] expected/actual AHB command mismatch purpose=%s", exp_pkt.purpose);
      end else if ((chk_pkt.htrans != 2'b10) && (chk_pkt.htrans != 2'b11)) begin
        pass_count++;
        $display($time, "ns:[ahb_slv_scoreboard][PASS] idle/busy transfer ignored purpose=%s", chk_pkt.purpose);
      end else if (chk_pkt.expect_error) begin
        if (chk_pkt.hresp == 2'b01) begin
          pass_count++;
          $display($time, "ns:[ahb_slv_scoreboard][PASS] expected ERROR response observed");
        end else begin
          error_count++;
          $display($time, "ns:[ahb_slv_scoreboard][ERROR] expected ERROR response, got hresp=%0h", chk_pkt.hresp);
        end
      end else if (chk_pkt.hresp != 2'b00) begin
        error_count++;
        $display($time, "ns:[ahb_slv_scoreboard][ERROR] unexpected hresp=%0h", chk_pkt.hresp);
      end else if (chk_pkt.check_hrdata) begin
        check_expected_read(chk_pkt);
      end else if (is_reg_access(chk_pkt)) begin
        if (chk_pkt.hwrite)
          model_reg_write(chk_pkt);
        pass_count++;
        $display($time, "ns:[ahb_slv_scoreboard][PASS] register access purpose=%s", chk_pkt.purpose);
      end else if (chk_pkt.hwrite) begin
        write_ref(chk_pkt);
      end else begin
        check_read(chk_pkt);
      end

      if (cov_mbx != null)
        cov_mbx.put(chk_pkt.clone());
    end
  join_none
endtask : start

function void ahb_slv_scoreboard::merge_expected_actual(ahb_slv_pkt exp, ahb_slv_pkt act, ref ahb_slv_pkt merged);
  merged = exp.clone();
  merged.hrdata      = act.hrdata;
  merged.hresp       = act.hresp;
  merged.hready_resp = act.hready_resp;
  merged.irq         = act.irq;
endfunction : merge_expected_actual

function bit ahb_slv_scoreboard::check_bus_match(ahb_slv_pkt exp, ahb_slv_pkt act);
  bit cmd_ok;
  bit wdata_ok;

  cmd_ok = (exp.hsel   === act.hsel)   &&
           (exp.hwrite === act.hwrite) &&
           (exp.hready === act.hready) &&
           (exp.hsize  === act.hsize)  &&
           (exp.htrans === act.htrans) &&
           (exp.hburst === act.hburst) &&
           (exp.haddr  === act.haddr);
  wdata_ok = (!exp.hwrite) || (exp.hwdata === act.hwdata);

  if (!cmd_ok || !wdata_ok) begin
    $display($time, "ns:[ahb_slv_scoreboard][ERROR] expected cmd: hsel=%0h hwrite=%0h hready=%0h hsize=%0h htrans=%0h hburst=%0h haddr=%0h hwdata=%0h",
             exp.hsel, exp.hwrite, exp.hready, exp.hsize, exp.htrans, exp.hburst, exp.haddr, exp.hwdata);
    $display($time, "ns:[ahb_slv_scoreboard][ERROR] actual   cmd: hsel=%0h hwrite=%0h hready=%0h hsize=%0h htrans=%0h hburst=%0h haddr=%0h hwdata=%0h",
             act.hsel, act.hwrite, act.hready, act.hsize, act.htrans, act.hburst, act.haddr, act.hwdata);
  end

  return cmd_ok && wdata_ok;
endfunction : check_bus_match

function bit ahb_slv_scoreboard::is_reg_access(ahb_slv_pkt pkt);
  return pkt.haddr[16];
endfunction : is_reg_access

function void ahb_slv_scoreboard::check_expected_read(ahb_slv_pkt pkt);
  bit data_ok;
  bit irq_ok;
  bit model_ok;
  bit [31:0] model_expected;
  data_ok = pkt.check_hrdata_nonzero ? (pkt.hrdata != 32'd0) :
                                      (pkt.hrdata === pkt.expected_hrdata);
  irq_ok  = (!pkt.check_irq) || (pkt.irq === pkt.expected_irq);
  model_ok = 1'b1;
  model_expected = pkt.expected_hrdata;

  if (pkt.haddr == REG_SOM_BEST_DIST) begin
    model_expected = model_som_best_distance;
    model_ok = (pkt.hrdata === model_expected);
  end else if (pkt.haddr == REG_SOM_WINNER) begin
    model_expected = {16'd0, model_som_winner_index};
    model_ok = (pkt.hrdata === model_expected);
  end

  if (!data_ok || !irq_ok || !model_ok) begin
    error_count++;
    $display($time, "ns:[ahb_slv_scoreboard][ERROR] %s addr=%0h exp=%0h model_exp=%0h act=%0h exp_irq=%0h act_irq=%0h",
             pkt.purpose, pkt.haddr, pkt.expected_hrdata, model_expected, pkt.hrdata, pkt.expected_irq, pkt.irq);
  end else begin
    pass_count++;
    $display($time, "ns:[ahb_slv_scoreboard][PASS] %s addr=%0h data=%0h irq=%0h",
             pkt.purpose, pkt.haddr, pkt.hrdata, pkt.irq);
  end
endfunction : check_expected_read

function void ahb_slv_scoreboard::model_reg_write(ahb_slv_pkt pkt);
  case (pkt.haddr)
    REG_SRC0_BASE:     model_src0_base = pkt.hwdata;
    REG_SRC1_BASE:     model_src1_base = pkt.hwdata;
    REG_DST_BASE:      model_dst_base = pkt.hwdata;
    REG_LENGTH:        model_length = pkt.hwdata[15:0];
    REG_SCALE_SHIFT:   model_scale_shift = pkt.hwdata[4:0];
    REG_SRC0_STRIDE:   model_src0_stride = pkt.hwdata;
    REG_SRC1_STRIDE:   model_src1_stride = pkt.hwdata;
    REG_DST_STRIDE:    model_dst_stride = pkt.hwdata;
    REG_CONFIG: begin
      model_signed_mode = pkt.hwdata[0];
      model_saturate_en = pkt.hwdata[1];
      model_data_width = pkt.hwdata[5:4];
    end
    REG_NEURON_COUNT:  model_neuron_count = pkt.hwdata[15:0];
    REG_NEURON_STRIDE: model_neuron_stride = pkt.hwdata;
    REG_NEURON_INDEX:  model_neuron_index = pkt.hwdata[15:0];
    REG_CTRL: begin
      if (pkt.hwdata[0])
        model_start(pkt.hwdata[3:1]);
    end
    default: begin
    end
  endcase
endfunction : model_reg_write

function void ahb_slv_scoreboard::model_start(bit [2:0] op);
  if (op == OP_SOM_RECALL)
    model_som_recall();
  else if (op == OP_SOM_UPDATE)
    model_som_update();
endfunction : model_start

function void ahb_slv_scoreboard::model_som_recall();
  bit [31:0] x_word;
  bit [31:0] w_word;
  bit [31:0] distance_sum;
  bit [31:0] best;
  bit [15:0] winner;
  int signed x_lane;
  int signed w_lane;

  best = 32'hffff_ffff;
  winner = 16'd0;

  for (int n = 0; n < model_neuron_count; n++) begin
    distance_sum = 32'd0;
    for (int i = 0; i < model_length; i++) begin
      x_word = read_ref_word(model_src0_base + i * model_src0_stride);
      w_word = read_ref_word(model_src1_base + n * model_neuron_stride + i * model_src1_stride);
      for (int lane = 0; lane < lane_count(); lane++) begin
        x_lane = lane_value(x_word, lane);
        w_lane = lane_value(w_word, lane);
        distance_sum += (x_lane >= w_lane) ? (x_lane - w_lane) : (w_lane - x_lane);
      end
    end
    if ((n == 0) || (distance_sum < best)) begin
      best = distance_sum;
      winner = n[15:0];
    end
  end

  model_result = {16'd0, winner};
  model_som_best_distance = best;
  model_som_winner_index = winner;
endfunction : model_som_recall

function void ahb_slv_scoreboard::model_som_update();
  bit [31:0] x_word;
  bit [31:0] w_word;
  bit [31:0] new_word;
  bit [31:0] w_addr;

  for (int i = 0; i < model_length; i++) begin
    x_word = read_ref_word(model_src0_base + i * model_src0_stride);
    w_addr = model_src1_base + model_neuron_index * model_neuron_stride + i * model_src1_stride;
    w_word = read_ref_word(w_addr);
    new_word = som_update_word(x_word, w_word);
    write_ref_word(w_addr, new_word);
  end

  model_result = {16'd0, model_neuron_index};
  model_som_best_distance = 32'd0;
  model_som_winner_index = model_neuron_index;
endfunction : model_som_update

function void ahb_slv_scoreboard::write_ref(ahb_slv_pkt pkt);
  int base_lane;
  case (pkt.hsize)
    3'b000: begin
      base_lane = (pkt.haddr[15] ? 4 : 0) + pkt.haddr[14:13];
      mem[byte_index(pkt.haddr, base_lane)] = pkt.hwdata[7:0];
    end

    3'b001: begin
      base_lane = (pkt.haddr[14] ? 4 : 0) + (pkt.haddr[13] ? 2 : 0);
      mem[byte_index(pkt.haddr, base_lane)]   = pkt.hwdata[7:0];
      mem[byte_index(pkt.haddr, base_lane+1)] = pkt.hwdata[15:8];
    end

    3'b010: begin
      base_lane = pkt.haddr[13] ? 4 : 0;
      mem[byte_index(pkt.haddr, base_lane)]   = pkt.hwdata[7:0];
      mem[byte_index(pkt.haddr, base_lane+1)] = pkt.hwdata[15:8];
      mem[byte_index(pkt.haddr, base_lane+2)] = pkt.hwdata[23:16];
      mem[byte_index(pkt.haddr, base_lane+3)] = pkt.hwdata[31:24];
    end

    default: begin
      $display($time, "ns:[ahb_slv_scoreboard][WARN] Unsupported hsize=%0b", pkt.hsize);
    end
  endcase
endfunction : write_ref

function bit [31:0] ahb_slv_scoreboard::read_ref_word(bit [31:0] addr);
  int base_lane;
  base_lane = addr[13] ? 4 : 0;
  read_ref_word = {
    mem[byte_index(addr, base_lane+3)],
    mem[byte_index(addr, base_lane+2)],
    mem[byte_index(addr, base_lane+1)],
    mem[byte_index(addr, base_lane)]
  };
endfunction : read_ref_word

function void ahb_slv_scoreboard::write_ref_word(bit [31:0] addr, bit [31:0] data);
  int base_lane;
  base_lane = addr[13] ? 4 : 0;
  mem[byte_index(addr, base_lane)]   = data[7:0];
  mem[byte_index(addr, base_lane+1)] = data[15:8];
  mem[byte_index(addr, base_lane+2)] = data[23:16];
  mem[byte_index(addr, base_lane+3)] = data[31:24];
endfunction : write_ref_word

function int ahb_slv_scoreboard::lane_count();
  case (model_data_width)
    2'd1: lane_count = 2;
    2'd2: lane_count = 4;
    default: lane_count = 1;
  endcase
endfunction : lane_count

function int ahb_slv_scoreboard::lane_bits();
  case (model_data_width)
    2'd1: lane_bits = 16;
    2'd2: lane_bits = 8;
    default: lane_bits = 32;
  endcase
endfunction : lane_bits

function int signed ahb_slv_scoreboard::lane_value(bit [31:0] word, int lane);
  bit [31:0] raw;
  raw = 32'd0;
  case (model_data_width)
    2'd1: begin
      raw = (word >> (lane * 16)) & 32'h0000_ffff;
      if (model_signed_mode)
        lane_value = {{16{raw[15]}}, raw[15:0]};
      else
        lane_value = raw[15:0];
    end
    2'd2: begin
      raw = (word >> (lane * 8)) & 32'h0000_00ff;
      if (model_signed_mode)
        lane_value = {{24{raw[7]}}, raw[7:0]};
      else
        lane_value = raw[7:0];
    end
    default: begin
      if (model_signed_mode)
        lane_value = word;
      else
        lane_value = word;
    end
  endcase
endfunction : lane_value

function int signed ahb_slv_scoreboard::clamp_lane(int signed value);
  if (!model_saturate_en)
    return value;

  if (model_data_width == 2'd1) begin
    if (model_signed_mode) begin
      if (value > 32767) return 32767;
      if (value < -32768) return -32768;
    end else begin
      if (value > 65535) return 65535;
      if (value < 0) return 0;
    end
  end else if (model_data_width == 2'd2) begin
    if (model_signed_mode) begin
      if (value > 127) return 127;
      if (value < -128) return -128;
    end else begin
      if (value > 255) return 255;
      if (value < 0) return 0;
    end
  end

  return value;
endfunction : clamp_lane

function bit [31:0] ahb_slv_scoreboard::som_update_word(bit [31:0] x_word, bit [31:0] w_word);
  int signed x_lane;
  int signed w_lane;
  int signed new_lane;
  bit [31:0] packed_word;
  int bits;

  packed_word = 32'd0;
  bits = lane_bits();

  for (int lane = 0; lane < lane_count(); lane++) begin
    x_lane = lane_value(x_word, lane);
    w_lane = lane_value(w_word, lane);
    new_lane = clamp_lane(w_lane + ((x_lane - w_lane) >>> model_scale_shift));

    if (bits == 32)
      packed_word = new_lane[31:0];
    else if (bits == 16)
      packed_word |= (new_lane[15:0] << (lane * 16));
    else
      packed_word |= (new_lane[7:0] << (lane * 8));
  end

  return packed_word;
endfunction : som_update_word

function void ahb_slv_scoreboard::check_read(ahb_slv_pkt pkt);
  int base_lane;
  case (pkt.hsize)
    3'b000: begin
      base_lane = (pkt.haddr[15] ? 4 : 0) + pkt.haddr[14:13];
      check_byte(byte_index(pkt.haddr, base_lane), pkt.hrdata[7:0]);
    end

    3'b001: begin
      base_lane = (pkt.haddr[14] ? 4 : 0) + (pkt.haddr[13] ? 2 : 0);
      check_byte(byte_index(pkt.haddr, base_lane),   pkt.hrdata[7:0]);
      check_byte(byte_index(pkt.haddr, base_lane+1), pkt.hrdata[15:8]);
    end

    3'b010: begin
      base_lane = pkt.haddr[13] ? 4 : 0;
      check_byte(byte_index(pkt.haddr, base_lane),   pkt.hrdata[7:0]);
      check_byte(byte_index(pkt.haddr, base_lane+1), pkt.hrdata[15:8]);
      check_byte(byte_index(pkt.haddr, base_lane+2), pkt.hrdata[23:16]);
      check_byte(byte_index(pkt.haddr, base_lane+3), pkt.hrdata[31:24]);
    end

    default: begin
      $display($time, "ns:[ahb_slv_scoreboard][WARN] Unsupported hsize=%0b", pkt.hsize);
    end
  endcase
endfunction : check_read

function int unsigned ahb_slv_scoreboard::byte_index(bit [31:0] addr, int lane);
  return (lane * 8192) + addr[12:0];
endfunction : byte_index

function void ahb_slv_scoreboard::check_byte(bit [31:0] addr, bit [7:0] rdata);
  bit [7:0] exp;
  exp = mem[addr];

  if (exp != rdata) begin
    error_count++;
    $display($time, "ns:[ahb_slv_scoreboard][ERROR] addr=%0h exp=%0h act=%0h", addr, exp, rdata);
  end else begin
    pass_count++;
    $display($time, "ns:[ahb_slv_scoreboard][PASS] addr=%0h data=%0h", addr, rdata);
  end
endfunction : check_byte

function void ahb_slv_scoreboard::report();
  $display("============================================================");
  $display("[ahb_slv_scoreboard] PASS count  = %0d", pass_count);
  $display("[ahb_slv_scoreboard] ERROR count = %0d", error_count);
  $display("============================================================");
endfunction : report

`endif // AHB_SLV_SCOREBOARD_SV
