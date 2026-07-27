class ahb_slv_generator;

  string name;
  ahb_slv_pkt pkt2send;

  typedef mailbox #(ahb_slv_pkt) generator_mailbox;
  generator_mailbox gen_mbx;

  int packet_number;
  int number_packets;
  bit [2:0] current_op;
  bit [15:0] current_len;
  bit [1:0] current_data_width;
  bit current_signed_mode;
  bit current_saturate_en;
  bit current_round_en;
  bit [15:0] current_neuron_count;
  bit [1:0] current_som_winner_pos;

  localparam bit [31:0] REG_BASE        = 32'h0001_0000;
  localparam bit [31:0] REG_CTRL        = REG_BASE + 32'h00;
  localparam bit [31:0] REG_STATUS      = REG_BASE + 32'h04;
  localparam bit [31:0] REG_SRC0_BASE   = REG_BASE + 32'h08;
  localparam bit [31:0] REG_SRC1_BASE   = REG_BASE + 32'h0c;
  localparam bit [31:0] REG_DST_BASE    = REG_BASE + 32'h10;
  localparam bit [31:0] REG_LENGTH      = REG_BASE + 32'h14;
  localparam bit [31:0] REG_SCALE_SHIFT = REG_BASE + 32'h18;
  localparam bit [31:0] REG_IRQ_STATUS  = REG_BASE + 32'h1c;
  localparam bit [31:0] REG_RESULT      = REG_BASE + 32'h20;
  localparam bit [31:0] REG_VERSION     = REG_BASE + 32'h24;
  localparam bit [31:0] REG_CAPABILITY  = REG_BASE + 32'h28;
  localparam bit [31:0] REG_ERROR_CODE  = REG_BASE + 32'h2c;
  localparam bit [31:0] REG_CYCLE_COUNT = REG_BASE + 32'h30;
  localparam bit [31:0] REG_ELEMENT_COUNT = REG_BASE + 32'h34;
  localparam bit [31:0] REG_SRC0_STRIDE = REG_BASE + 32'h38;
  localparam bit [31:0] REG_SRC1_STRIDE = REG_BASE + 32'h3c;
  localparam bit [31:0] REG_DST_STRIDE  = REG_BASE + 32'h40;
  localparam bit [31:0] REG_CONFIG      = REG_BASE + 32'h44;
  localparam bit [31:0] REG_IRQ_ENABLE  = REG_BASE + 32'h48;
  localparam bit [31:0] REG_IRQ_MASK    = REG_BASE + 32'h4c;
  localparam bit [31:0] REG_IRQ_CLEAR   = REG_BASE + 32'h50;
  localparam bit [31:0] REG_NEURON_COUNT  = REG_BASE + 32'h54;
  localparam bit [31:0] REG_NEURON_STRIDE = REG_BASE + 32'h58;
  localparam bit [31:0] REG_NEURON_INDEX  = REG_BASE + 32'h5c;
  localparam bit [31:0] REG_SOM_BEST_DIST = REG_BASE + 32'h60;
  localparam bit [31:0] REG_SOM_WINNER    = REG_BASE + 32'h64;

  localparam bit [2:0] OP_VADD   = 3'd0;
  localparam bit [2:0] OP_VSUB   = 3'd1;
  localparam bit [2:0] OP_VMAC   = 3'd2;
  localparam bit [2:0] OP_L1DIST = 3'd3;
  localparam bit [2:0] OP_VMUL   = 3'd4;
  localparam bit [2:0] OP_SOM_RECALL = 3'd5;
  localparam bit [2:0] OP_SOM_UPDATE = 3'd6;

  extern function new(string name="ahb_slv_generator", int number_packets=0);
  extern virtual task start();
  extern virtual task gen_vec_directed_suite();
  extern virtual task gen_reset_default_cases();
  extern virtual task gen_soft_reset_case();
  extern virtual task gen_register_readback_cases();
  extern virtual task gen_extended_register_cases();
  extern virtual task gen_sram_access_cases();
  extern virtual task gen_burst_cases();
  extern virtual task gen_lane_bank_cases();
  extern virtual task gen_protocol_negative_cases();
  extern virtual task gen_vec_op(bit [2:0] op, int case_idx, int length, bit irq_en=1'b1);
  extern virtual task gen_boundary_addr_case();
  extern virtual task gen_busy_protection_case();
  extern virtual task gen_error_config_cases();
  extern virtual task gen_length_zero_error();
  extern virtual task gen_som_recall_word_case();
  extern virtual task gen_som_update_word_case();
  extern virtual task gen_som_recall_int16_case();
  extern virtual task gen_som_update_int8_case();
  extern virtual task gen_vmul_stride_case();
  extern virtual task gen_packed_config_cases();
  extern virtual task gen_signed_saturate_round_cases();
  extern virtual task gen_irq_control_case();
  extern virtual task gen_som_recall_last_case();
  extern virtual task gen_random_sram_cases(int count);
  extern virtual task gen_random_vector_cases(int count);
  extern virtual task put_access(bit write, bit [31:0] addr, bit [31:0] data, bit [2:0] size,
                                 bit [1:0] trans, bit [2:0] burst, bit expect_error,
                                 bit check_hrdata, bit [31:0] expected, string purpose);
  extern virtual task put_write(bit [31:0] addr, bit [31:0] data, string purpose="write");
  extern virtual task put_read(bit [31:0] addr, string purpose="read");
  extern virtual task put_check_read(bit [31:0] addr, bit [31:0] expected, string purpose="check_read",
                                     bit check_irq=1'b0, bit expected_irq=1'b0);
  extern virtual task put_check_nonzero_read(bit [31:0] addr, string purpose="check_nonzero_read");
  extern virtual task put_expect_error(bit write, bit [31:0] addr, bit [31:0] data, bit [2:0] size,
                                       bit [1:0] trans, bit [2:0] burst, string purpose);
  extern function bit [31:0] calc_expected(bit [2:0] op, bit [31:0] a0, bit [31:0] a1, bit [31:0] acc, bit [4:0] shift);
endclass: ahb_slv_generator

function ahb_slv_generator::new(string name="ahb_slv_generator", int number_packets=0);
  this.name = name;
  this.pkt2send = new();
  this.gen_mbx = new;
  this.packet_number = 0;
  this.number_packets = number_packets;
  this.current_op = OP_VADD;
  this.current_len = 16'd0;
  this.current_data_width = 2'd0;
  this.current_signed_mode = 1'b0;
  this.current_saturate_en = 1'b0;
  this.current_round_en = 1'b0;
  this.current_neuron_count = 16'd0;
  this.current_som_winner_pos = 2'd0;
endfunction : new

task ahb_slv_generator::put_access(bit write, bit [31:0] addr, bit [31:0] data, bit [2:0] size,
                                   bit [1:0] trans, bit [2:0] burst, bit expect_error,
                                   bit check_hrdata, bit [31:0] expected, string purpose);
  ahb_slv_pkt pkt;
  pkt = new($sformatf("pkt[%0d]", packet_number++));
  pkt.hsel = 1'b1;
  pkt.hwrite = write;
  pkt.hready = 1'b1;
  pkt.hsize = size;
  pkt.htrans = trans;
  pkt.hburst = burst;
  pkt.haddr = addr;
  pkt.hwdata = data;
  pkt.expect_error = expect_error;
  pkt.check_hrdata = check_hrdata;
  pkt.check_hrdata_nonzero = 1'b0;
  pkt.expected_hrdata = expected;
  pkt.check_irq = 1'b0;
  pkt.expected_irq = 1'b0;
  pkt.vec_op = current_op;
  pkt.vec_len = current_len;
  pkt.data_width = current_data_width;
  pkt.signed_mode = current_signed_mode;
  pkt.saturate_en = current_saturate_en;
  pkt.round_en = current_round_en;
  pkt.neuron_count = current_neuron_count;
  pkt.som_winner_pos = current_som_winner_pos;
  pkt.purpose = purpose;
  pkt.display();
  gen_mbx.put(pkt);
endtask : put_access

task ahb_slv_generator::put_write(bit [31:0] addr, bit [31:0] data, string purpose="write");
  if (addr == REG_CONFIG) begin
    current_signed_mode = data[0];
    current_saturate_en = data[1];
    current_round_en = data[2];
    current_data_width = data[5:4];
  end
  put_access(1'b1, addr, data, 3'b010, 2'b10, 3'b000, 1'b0, 1'b0, 32'd0, purpose);
endtask : put_write

task ahb_slv_generator::put_read(bit [31:0] addr, string purpose="read");
  put_access(1'b0, addr, 32'd0, 3'b010, 2'b10, 3'b000, 1'b0, 1'b0, 32'd0, purpose);
endtask : put_read

task ahb_slv_generator::put_check_read(bit [31:0] addr, bit [31:0] expected, string purpose="check_read",
                                       bit check_irq=1'b0, bit expected_irq=1'b0);
  ahb_slv_pkt pkt;
  pkt = new($sformatf("pkt[%0d]", packet_number++));
  pkt.hsel = 1'b1;
  pkt.hwrite = 1'b0;
  pkt.hready = 1'b1;
  pkt.hsize = 3'b010;
  pkt.htrans = 2'b10;
  pkt.hburst = 3'b000;
  pkt.haddr = addr;
  pkt.hwdata = 32'd0;
  pkt.expect_error = 1'b0;
  pkt.check_hrdata = 1'b1;
  pkt.check_hrdata_nonzero = 1'b0;
  pkt.expected_hrdata = expected;
  pkt.check_irq = check_irq;
  pkt.expected_irq = expected_irq;
  pkt.vec_op = current_op;
  pkt.vec_len = current_len;
  pkt.data_width = current_data_width;
  pkt.signed_mode = current_signed_mode;
  pkt.saturate_en = current_saturate_en;
  pkt.round_en = current_round_en;
  pkt.neuron_count = current_neuron_count;
  pkt.som_winner_pos = current_som_winner_pos;
  pkt.purpose = purpose;
  pkt.display();
  gen_mbx.put(pkt);
endtask : put_check_read

task ahb_slv_generator::put_check_nonzero_read(bit [31:0] addr, string purpose="check_nonzero_read");
  ahb_slv_pkt pkt;
  pkt = new($sformatf("pkt[%0d]", packet_number++));
  pkt.hsel = 1'b1;
  pkt.hwrite = 1'b0;
  pkt.hready = 1'b1;
  pkt.hsize = 3'b010;
  pkt.htrans = 2'b10;
  pkt.hburst = 3'b000;
  pkt.haddr = addr;
  pkt.hwdata = 32'd0;
  pkt.expect_error = 1'b0;
  pkt.check_hrdata = 1'b1;
  pkt.check_hrdata_nonzero = 1'b1;
  pkt.expected_hrdata = 32'd0;
  pkt.check_irq = 1'b0;
  pkt.expected_irq = 1'b0;
  pkt.vec_op = current_op;
  pkt.vec_len = current_len;
  pkt.data_width = current_data_width;
  pkt.signed_mode = current_signed_mode;
  pkt.saturate_en = current_saturate_en;
  pkt.round_en = current_round_en;
  pkt.neuron_count = current_neuron_count;
  pkt.som_winner_pos = current_som_winner_pos;
  pkt.purpose = purpose;
  pkt.display();
  gen_mbx.put(pkt);
endtask : put_check_nonzero_read

task ahb_slv_generator::put_expect_error(bit write, bit [31:0] addr, bit [31:0] data, bit [2:0] size,
                                         bit [1:0] trans, bit [2:0] burst, string purpose);
  put_access(write, addr, data, size, trans, burst, 1'b1, 1'b0, 32'd0, purpose);
endtask : put_expect_error

function bit [31:0] ahb_slv_generator::calc_expected(bit [2:0] op, bit [31:0] a0, bit [31:0] a1, bit [31:0] acc, bit [4:0] shift);
  bit [63:0] product;
  begin
    product = a0 * a1;
    case (op)
      OP_VADD:   calc_expected = a0 + a1;
      OP_VSUB:   calc_expected = a0 - a1;
      OP_VMAC:   calc_expected = acc + (product[31:0] >> shift);
      OP_L1DIST: calc_expected = acc + ((a0 >= a1) ? (a0 - a1) : (a1 - a0));
      default:   calc_expected = 32'd0;
    endcase
  end
endfunction : calc_expected

task ahb_slv_generator::gen_reset_default_cases();
  current_op = OP_VADD;
  current_len = 16'd0;
  $display($time, "ns:[ahb_slv_generator] Generate reset default register checks");

  put_check_read(REG_CTRL,        32'h0000_0000, "reset_check_ctrl", 1'b1, 1'b0);
  put_check_read(REG_STATUS,      32'h0000_0000, "reset_check_status", 1'b1, 1'b0);
  put_check_read(REG_SRC0_BASE,   32'h0000_0000, "reset_check_src0");
  put_check_read(REG_SRC1_BASE,   32'h0000_0000, "reset_check_src1");
  put_check_read(REG_DST_BASE,    32'h0000_0000, "reset_check_dst");
  put_check_read(REG_LENGTH,      32'h0000_0000, "reset_check_length");
  put_check_read(REG_SCALE_SHIFT, 32'h0000_0000, "reset_check_scale_shift");
  put_check_read(REG_IRQ_STATUS,  32'h0000_0000, "reset_check_irq_status", 1'b1, 1'b0);
  put_check_read(REG_RESULT,      32'h0000_0000, "reset_check_result");
endtask : gen_reset_default_cases

task ahb_slv_generator::gen_soft_reset_case();
  current_op = OP_VADD;
  current_len = 16'd0;
  $display($time, "ns:[ahb_slv_generator] Generate soft reset register access case");

  put_write(REG_CTRL, 32'h0000_0100, "soft_reset_pulse");
  put_check_read(REG_CTRL, 32'h0000_0000, "soft_reset_ctrl_readback", 1'b1, 1'b0);
  put_check_read(REG_STATUS, 32'h0000_0000, "soft_reset_status_readback", 1'b1, 1'b0);
endtask : gen_soft_reset_case

task ahb_slv_generator::gen_register_readback_cases();
  current_op = OP_L1DIST;
  current_len = 16'd8;
  $display($time, "ns:[ahb_slv_generator] Generate register readback cases");

  put_write(REG_SRC0_BASE,   32'h0000_0400, "reg_rw_src0_write");
  put_write(REG_SRC1_BASE,   32'h0000_0800, "reg_rw_src1_write");
  put_write(REG_DST_BASE,    32'h0000_0c00, "reg_rw_dst_write");
  put_write(REG_LENGTH,      32'd8,         "reg_rw_length_write");
  put_write(REG_SCALE_SHIFT, 32'd5,         "reg_rw_scale_write");
  put_write(REG_CTRL,        {27'd0, 1'b1, OP_L1DIST, 1'b0}, "reg_rw_ctrl_write_no_start");

  put_check_read(REG_SRC0_BASE,   32'h0000_0400, "reg_rw_src0_check");
  put_check_read(REG_SRC1_BASE,   32'h0000_0800, "reg_rw_src1_check");
  put_check_read(REG_DST_BASE,    32'h0000_0c00, "reg_rw_dst_check");
  put_check_read(REG_LENGTH,      32'h0000_0008, "reg_rw_length_check");
  put_check_read(REG_SCALE_SHIFT, 32'h0000_0005, "reg_rw_scale_check");
  put_check_read(REG_CTRL,        32'h0000_0016, "reg_rw_ctrl_check_start_reads_zero", 1'b1, 1'b0);
endtask : gen_register_readback_cases

task ahb_slv_generator::gen_extended_register_cases();
  current_op = OP_VADD;
  current_len = 16'd0;
  current_data_width = 2'd1;
  current_neuron_count = 16'd4;
  current_som_winner_pos = 2'd3;
  $display($time, "ns:[ahb_slv_generator] Generate extended register readback cases");

  put_check_read(REG_VERSION,    32'h0004_0000, "reg_check_version");
  put_check_read(REG_CAPABILITY, 32'h0003_7f1f, "reg_check_capability");
  put_check_read(REG_ERROR_CODE, 32'd0,         "reg_check_error_code_reset");
  put_check_read(REG_CYCLE_COUNT, 32'd0,        "reg_check_cycle_count_reset");
  put_check_read(REG_ELEMENT_COUNT, 32'd0,      "reg_check_element_count_reset");

  put_write(REG_SRC0_STRIDE, 32'd8,  "reg_stride_src0_write");
  put_write(REG_SRC1_STRIDE, 32'd12, "reg_stride_src1_write");
  put_write(REG_DST_STRIDE,  32'd16, "reg_stride_dst_write");
  put_write(REG_CONFIG,      32'h0000_0017, "reg_config_write");
  put_write(REG_NEURON_COUNT,  32'd4,  "reg_neuron_count_write");
  put_write(REG_NEURON_STRIDE, 32'd32, "reg_neuron_stride_write");
  put_write(REG_NEURON_INDEX,  32'd3,  "reg_neuron_index_write");

  put_check_read(REG_SRC0_STRIDE, 32'd8,  "reg_stride_src0_check");
  put_check_read(REG_SRC1_STRIDE, 32'd12, "reg_stride_src1_check");
  put_check_read(REG_DST_STRIDE,  32'd16, "reg_stride_dst_check");
  put_check_read(REG_CONFIG,      32'h0000_0017, "reg_config_check");
  put_check_read(REG_NEURON_COUNT,  32'd4,  "reg_neuron_count_check");
  put_check_read(REG_NEURON_STRIDE, 32'd32, "reg_neuron_stride_check");
  put_check_read(REG_NEURON_INDEX,  32'd3,  "reg_neuron_index_check");

  put_write(REG_SRC0_STRIDE, 32'd4, "reg_stride_src0_restore");
  put_write(REG_SRC1_STRIDE, 32'd4, "reg_stride_src1_restore");
  put_write(REG_DST_STRIDE,  32'd4, "reg_stride_dst_restore");
  put_write(REG_CONFIG,      32'd0, "reg_config_restore");
  put_write(REG_NEURON_COUNT,  32'd1, "reg_neuron_count_restore");
  put_write(REG_NEURON_STRIDE, 32'd4, "reg_neuron_stride_restore");
  put_write(REG_NEURON_INDEX,  32'd0, "reg_neuron_index_restore");
endtask : gen_extended_register_cases

task ahb_slv_generator::gen_sram_access_cases();
  current_op = OP_VADD;
  current_len = 16'd0;
  $display($time, "ns:[ahb_slv_generator] Generate SRAM access and protocol cases");

  put_access(1'b1, 32'h0000_2000, 32'h0000_005a, 3'b000, 2'b10, 3'b000, 1'b0, 1'b0, 32'd0, "sram_byte_write");
  put_access(1'b0, 32'h0000_2000, 32'd0,        3'b000, 2'b10, 3'b000, 1'b0, 1'b1, 32'h0000_005a, "sram_byte_read_check");

  put_access(1'b1, 32'h0000_4000, 32'h0000_cafe, 3'b001, 2'b10, 3'b000, 1'b0, 1'b0, 32'd0, "sram_half_write");
  put_access(1'b0, 32'h0000_4000, 32'd0,         3'b001, 2'b10, 3'b000, 1'b0, 1'b1, 32'h0000_cafe, "sram_half_read_check");
  put_access(1'b1, 32'h0000_0000, 32'h0000_1101, 3'b001, 2'b10, 3'b000, 1'b0, 1'b0, 32'd0, "sram_half_bank0_low_write");
  put_access(1'b0, 32'h0000_0000, 32'd0,         3'b001, 2'b10, 3'b000, 1'b0, 1'b1, 32'h0000_1101, "sram_half_bank0_low_read_check");
  put_access(1'b1, 32'h0000_2000, 32'h0000_2202, 3'b001, 2'b10, 3'b000, 1'b0, 1'b0, 32'd0, "sram_half_bank0_high_write");
  put_access(1'b0, 32'h0000_2000, 32'd0,         3'b001, 2'b10, 3'b000, 1'b0, 1'b1, 32'h0000_2202, "sram_half_bank0_high_read_check");
  put_access(1'b1, 32'h0000_6000, 32'h0000_6606, 3'b001, 2'b10, 3'b000, 1'b0, 1'b0, 32'd0, "sram_half_bank1_high_write");
  put_access(1'b0, 32'h0000_6000, 32'd0,         3'b001, 2'b10, 3'b000, 1'b0, 1'b1, 32'h0000_6606, "sram_half_bank1_high_read_check");

  put_access(1'b1, 32'h0000_2020, 32'h1234_abcd, 3'b010, 2'b10, 3'b000, 1'b0, 1'b0, 32'd0, "sram_word_write");
  put_access(1'b0, 32'h0000_2020, 32'd0,         3'b010, 2'b10, 3'b000, 1'b0, 1'b1, 32'h1234_abcd, "sram_word_read_check");

  put_expect_error(1'b1, 32'h0000_0000, 32'hdead_beef, 3'b011, 2'b10, 3'b000, "illegal_hsize");
  put_expect_error(1'b1, 32'h0000_0001, 32'h0000_beef, 3'b001, 2'b10, 3'b000, "unaligned_halfword");
  put_expect_error(1'b1, 32'h0000_0002, 32'hdead_beef, 3'b010, 2'b10, 3'b000, "unaligned_word");
  put_expect_error(1'b1, 32'h0000_0080, 32'hdead_beef, 3'b010, 2'b10, 3'b010, "unsupported_wrap4");
  put_expect_error(1'b1, 32'h0000_0084, 32'hdead_beef, 3'b010, 2'b10, 3'b100, "unsupported_wrap8");
  put_expect_error(1'b1, 32'h0000_0088, 32'hdead_beef, 3'b010, 2'b10, 3'b110, "unsupported_wrap16");
  put_expect_error(1'b0, 32'h0000_0090, 32'd0,         3'b111, 2'b10, 3'b000, "read_illegal_hsize");

  put_access(1'b0, 32'h0000_0000, 32'd0, 3'b010, 2'b00, 3'b000, 1'b0, 1'b0, 32'd0, "htrans_idle_ignored");
  put_access(1'b0, 32'h0000_0000, 32'd0, 3'b010, 2'b01, 3'b000, 1'b0, 1'b0, 32'd0, "htrans_busy_ignored");
endtask : gen_sram_access_cases

task ahb_slv_generator::gen_random_sram_cases(int count);
  ahb_slv_pkt random_pkt;
  bit [31:0] expected;

  current_op = OP_VADD;
  current_len = 16'd0;
  current_data_width = 2'd0;
  current_neuron_count = 16'd0;
  current_som_winner_pos = 2'd0;
  $display($time, "ns:[ahb_slv_generator] Generate %0d constrained-random SRAM write/read pairs", count);

  for (int i = 0; i < count; i++) begin
    random_pkt = new($sformatf("random_sram_template[%0d]", i));
    if (!random_pkt.randomize() with {
          hwrite == 1'b1;
          htrans == 2'b10;
          hburst == 3'b000;
          haddr inside {[32'h0000_0800:32'h0000_1ffc]};
        })
      $fatal(1, "[ahb_slv_generator] Failed to randomize SRAM packet %0d", i);

    case (random_pkt.hsize)
      3'b000: expected = {24'd0, random_pkt.hwdata[7:0]};
      3'b001: expected = {16'd0, random_pkt.hwdata[15:0]};
      default: expected = random_pkt.hwdata;
    endcase

    put_access(1'b1, random_pkt.haddr, random_pkt.hwdata, random_pkt.hsize,
               random_pkt.htrans, random_pkt.hburst, 1'b0, 1'b0, 32'd0,
               $sformatf("random_sram_write_%0d", i));
    put_access(1'b0, random_pkt.haddr, 32'd0, random_pkt.hsize,
               random_pkt.htrans, random_pkt.hburst, 1'b0, 1'b1, expected,
               $sformatf("random_sram_read_check_%0d", i));
  end
endtask : gen_random_sram_cases

task ahb_slv_generator::gen_random_vector_cases(int count);
  bit [2:0] op;
  int length;
  bit irq_en;

  $display($time, "ns:[ahb_slv_generator] Generate %0d random vector configuration cases", count);
  for (int i = 0; i < count; i++) begin
    case ($urandom_range(0, 3))
      0: op = OP_VADD;
      1: op = OP_VSUB;
      2: op = OP_VMAC;
      default: op = OP_L1DIST;
    endcase
    length = $urandom_range(1, 8);
    irq_en = $urandom_range(0, 1);
    gen_vec_op(op, 9 + (i % 5), length, irq_en);
  end
endtask : gen_random_vector_cases

task ahb_slv_generator::gen_lane_bank_cases();
  bit [31:0] addr;
  current_op = OP_VADD;
  current_len = 16'd0;
  $display($time, "ns:[ahb_slv_generator] Generate SRAM lane/bank selection cases");

  for (int lane = 0; lane < 8; lane++) begin
    addr = lane << 13;
    put_access(1'b1, addr, 32'h0000_00a0 + lane, 3'b000, 2'b10, 3'b000,
               1'b0, 1'b0, 32'd0, "lane_byte_write");
    put_access(1'b0, addr, 32'd0, 3'b000, 2'b10, 3'b000,
               1'b0, 1'b1, 32'h0000_00a0 + lane, "lane_byte_read_check");
  end
endtask : gen_lane_bank_cases

task ahb_slv_generator::gen_protocol_negative_cases();
  current_op = OP_VADD;
  current_len = 16'd0;
  $display($time, "ns:[ahb_slv_generator] Generate AHB/register negative protocol cases");

  put_expect_error(1'b0, 32'h0000_5000, 32'd0, 3'b010, 2'b11, 3'b000, "seq_without_active_burst");

  put_access(1'b1, 32'h0000_3200, 32'h3200_0000, 3'b010, 2'b10, 3'b011,
             1'b0, 1'b0, 32'd0, "burst_hsize_change_first");
  put_expect_error(1'b1, 32'h0000_3204, 32'h3200_0001, 3'b001, 2'b11, 3'b011, "burst_hsize_change_error");

  put_access(1'b1, 32'h0000_3300, 32'h3300_0000, 3'b010, 2'b10, 3'b011,
             1'b0, 1'b0, 32'd0, "burst_bad_addr_first");
  put_expect_error(1'b1, 32'h0000_3308, 32'h3300_0002, 3'b010, 2'b11, 3'b011, "burst_bad_addr_error");

  put_access(1'b1, 32'h0000_3400, 32'h3400_0000, 3'b010, 2'b10, 3'b001,
             1'b0, 1'b0, 32'd0, "incr_bad_addr_first");
  put_expect_error(1'b1, 32'h0000_3408, 32'h3400_0002, 3'b010, 2'b11, 3'b001, "incr_bad_addr_error");

  put_expect_error(1'b0, REG_BASE + 32'h80, 32'd0,        3'b010, 2'b10, 3'b000, "reg_unknown_read");
  put_expect_error(1'b1, REG_BASE + 32'h80, 32'h1234_5678, 3'b010, 2'b10, 3'b000, "reg_unknown_write");
  put_expect_error(1'b0, REG_CTRL,          32'd0,        3'b000, 2'b10, 3'b000, "reg_byte_read_error");
  put_expect_error(1'b1, REG_CTRL,          32'h0000_0001, 3'b001, 2'b10, 3'b000, "reg_half_write_error");
endtask : gen_protocol_negative_cases

task ahb_slv_generator::gen_burst_cases();
  bit [31:0] base;
  base = 32'h0000_3000;
  current_op = OP_VADD;
  current_len = 16'd0;
  $display($time, "ns:[ahb_slv_generator] Generate burst cases");

  for (int i = 0; i < 4; i++) begin
    put_access(1'b1, base + i * 4, 32'h7100_0000 + i, 3'b010,
               (i == 0) ? 2'b10 : 2'b11, 3'b011, 1'b0, 1'b0, 32'd0, "incr4_write");
  end

  for (int i = 0; i < 4; i++) begin
    put_access(1'b0, base + i * 4, 32'd0, 3'b010,
               (i == 0) ? 2'b10 : 2'b11, 3'b011, 1'b0, 1'b1, 32'h7100_0000 + i, "incr4_read_check");
  end

  put_access(1'b1, 32'h0000_3100, 32'h0000_0001, 3'b010, 2'b10, 3'b001, 1'b0, 1'b0, 32'd0, "incr_write_first");
  put_access(1'b1, 32'h0000_3104, 32'h0000_0002, 3'b010, 2'b11, 3'b001, 1'b0, 1'b0, 32'd0, "incr_write_seq");
  put_access(1'b1, 32'h0000_3120, 32'h0000_0008, 3'b010, 2'b10, 3'b101, 1'b0, 1'b0, 32'd0, "incr8_first_beat");
  put_access(1'b1, 32'h0000_3140, 32'h0000_0010, 3'b010, 2'b10, 3'b111, 1'b0, 1'b0, 32'd0, "incr16_first_beat");
endtask : gen_burst_cases

task ahb_slv_generator::gen_vec_op(bit [2:0] op, int case_idx, int length, bit irq_en=1'b1);
  bit [31:0] src0_base;
  bit [31:0] src1_base;
  bit [31:0] dst_base;
  bit [31:0] src0_data [0:15];
  bit [31:0] src1_data [0:15];
  bit [31:0] expected  [0:15];
  bit [31:0] acc;
  bit [4:0]  shift;
  int poll_count;

  src0_base = 32'h0000_0000 + case_idx * 32'h0000_0400;
  src1_base = src0_base + 32'h0000_0100;
  dst_base  = src0_base + 32'h0000_0200;
  shift = (op == OP_VMAC) ? case_idx[4:0] : 5'd0;
  acc = 32'd0;
  current_op = op;
  current_len = length[15:0];
  current_data_width = 2'd0;
  current_neuron_count = 16'd0;
  current_som_winner_pos = 2'd3;
  poll_count = 64 + length * 16;

  $display($time, "ns:[ahb_slv_generator] Generate vector op case op=%0d case=%0d length=%0d irq_en=%0d", op, case_idx, length, irq_en);

  for (int i = 0; i < length; i++) begin
    src0_data[i] = 32'd10 + case_idx * 32 + i * 3;
    src1_data[i] = 32'd1  + case_idx * 7  + i;
    put_write(src0_base + i * 4, src0_data[i], "write_src0");
    put_write(src1_base + i * 4, src1_data[i], "write_src1");
  end

  put_write(REG_SRC0_BASE,   src0_base, "cfg_src0_base");
  put_write(REG_SRC1_BASE,   src1_base, "cfg_src1_base");
  put_write(REG_DST_BASE,    dst_base,  "cfg_dst_base");
  put_write(REG_LENGTH,      length,    "cfg_length");
  put_write(REG_SCALE_SHIFT, shift,     "cfg_scale_shift");
  put_write(REG_CTRL,        {27'd0, irq_en, op, 1'b1}, "start_op");

  for (int poll = 0; poll < poll_count; poll++)
    put_read(REG_STATUS, "poll_status");

  if ((op == OP_VADD) || (op == OP_VSUB) || (op == OP_VMUL)) begin
    for (int i = 0; i < length; i++) begin
      expected[i] = calc_expected(op, src0_data[i], src1_data[i], 32'd0, shift);
      put_check_read(dst_base + i * 4, expected[i], "check_vector_result");
    end
    put_check_read(REG_RESULT, expected[length-1], "check_result_reg");
  end else begin
    for (int i = 0; i < length; i++)
      acc = calc_expected(op, src0_data[i], src1_data[i], acc, shift);
    put_check_read(dst_base, acc, "check_acc_result");
    put_check_read(REG_RESULT, acc, "check_result_reg");
  end

  put_check_read(REG_IRQ_STATUS, 32'd1, irq_en ? "check_irq_status_irq_en_1" : "check_irq_status_irq_en_0",
                 1'b1, irq_en);
  put_write(REG_IRQ_STATUS, 32'd1, "clear_irq_status");
  put_check_read(REG_IRQ_STATUS, 32'd0, "check_irq_status_clear", 1'b1, 1'b0);
  put_write(REG_STATUS, 32'd2, "clear_done");
endtask : gen_vec_op

task ahb_slv_generator::gen_vmul_stride_case();
  bit [31:0] src0_base;
  bit [31:0] src1_base;
  bit [31:0] dst_base;

  src0_base = 32'h0000_2000;
  src1_base = 32'h0000_2100;
  dst_base  = 32'h0000_2200;
  current_op = OP_VMUL;
  current_len = 16'd2;
  current_data_width = 2'd0;
  current_neuron_count = 16'd0;
  current_som_winner_pos = 2'd3;
  $display($time, "ns:[ahb_slv_generator] Generate VMUL non-unit stride and round case");

  put_write(src0_base + 32'd0, 32'd7,  "vmul_stride_src0_0");
  put_write(src0_base + 32'd8, 32'd9,  "vmul_stride_src0_1");
  put_write(src1_base + 32'd0, 32'd5,  "vmul_stride_src1_0");
  put_write(src1_base + 32'd12, 32'd3, "vmul_stride_src1_1");
  put_write(REG_SRC0_BASE, src0_base, "vmul_stride_cfg_src0");
  put_write(REG_SRC1_BASE, src1_base, "vmul_stride_cfg_src1");
  put_write(REG_DST_BASE,  dst_base,  "vmul_stride_cfg_dst");
  put_write(REG_LENGTH,    32'd2,      "vmul_stride_cfg_length");
  put_write(REG_SCALE_SHIFT, 32'd1,    "vmul_stride_cfg_shift");
  put_write(REG_SRC0_STRIDE, 32'd8,    "vmul_stride_cfg_src0_stride");
  put_write(REG_SRC1_STRIDE, 32'd12,   "vmul_stride_cfg_src1_stride");
  put_write(REG_DST_STRIDE,  32'd16,   "vmul_stride_cfg_dst_stride");
  put_write(REG_CONFIG,      32'h0000_0004, "vmul_stride_cfg_round");
  put_write(REG_CTRL, {27'd0, 1'b1, OP_VMUL, 1'b1}, "vmul_stride_start");
  for (int poll = 0; poll < 128; poll++)
    put_read(REG_STATUS, "vmul_stride_poll");
  put_check_read(dst_base + 32'd0,  32'd18, "vmul_stride_check_0");
  put_check_read(dst_base + 32'd16, 32'd14, "vmul_stride_check_1");
  put_check_read(REG_RESULT,        32'd14, "vmul_stride_check_result");
  put_check_read(REG_ELEMENT_COUNT, 32'd2,  "vmul_stride_check_elements");
  put_check_nonzero_read(REG_CYCLE_COUNT, "vmul_stride_check_cycles_nonzero");
  put_write(REG_IRQ_STATUS, 32'd1, "vmul_stride_clear_irq");
  put_write(REG_STATUS, 32'd2, "vmul_stride_clear_done");
  put_write(REG_SRC0_STRIDE, 32'd4, "vmul_stride_restore_src0_stride");
  put_write(REG_SRC1_STRIDE, 32'd4, "vmul_stride_restore_src1_stride");
  put_write(REG_DST_STRIDE,  32'd4, "vmul_stride_restore_dst_stride");
  put_write(REG_CONFIG,      32'd0, "vmul_stride_restore_config");
endtask : gen_vmul_stride_case

task ahb_slv_generator::gen_packed_config_cases();
  current_neuron_count = 16'd0;
  current_som_winner_pos = 2'd3;
  $display($time, "ns:[ahb_slv_generator] Generate packed signed/saturate cases");

  current_op = OP_VADD;
  current_len = 16'd1;
  current_data_width = 2'd1;
  put_write(32'h0000_2300, 32'hffff_7fff, "packed_i16_vadd_src0");
  put_write(32'h0000_2304, 32'h0001_0002, "packed_i16_vadd_src1");
  put_write(REG_SRC0_BASE, 32'h0000_2300, "packed_i16_vadd_cfg_src0");
  put_write(REG_SRC1_BASE, 32'h0000_2304, "packed_i16_vadd_cfg_src1");
  put_write(REG_DST_BASE,  32'h0000_2308, "packed_i16_vadd_cfg_dst");
  put_write(REG_LENGTH,    32'd1, "packed_i16_vadd_cfg_length");
  put_write(REG_CONFIG,    32'h0000_0012, "packed_i16_vadd_cfg_sat");
  put_write(REG_CTRL, {27'd0, 1'b1, OP_VADD, 1'b1}, "packed_i16_vadd_start");
  for (int poll = 0; poll < 64; poll++)
    put_read(REG_STATUS, "packed_i16_vadd_poll");
  put_check_read(32'h0000_2308, 32'hffff_8001, "packed_i16_vadd_check");
  put_write(REG_IRQ_STATUS, 32'd1, "packed_i16_vadd_clear_irq");
  put_write(REG_STATUS, 32'd2, "packed_i16_vadd_clear_done");

  current_op = OP_VSUB;
  current_data_width = 2'd2;
  put_write(32'h0000_2310, 32'h807f_05fb, "packed_i8_vsub_src0");
  put_write(32'h0000_2314, 32'h01ff_0a02, "packed_i8_vsub_src1");
  put_write(REG_SRC0_BASE, 32'h0000_2310, "packed_i8_vsub_cfg_src0");
  put_write(REG_SRC1_BASE, 32'h0000_2314, "packed_i8_vsub_cfg_src1");
  put_write(REG_DST_BASE,  32'h0000_2318, "packed_i8_vsub_cfg_dst");
  put_write(REG_CONFIG,    32'h0000_0023, "packed_i8_vsub_cfg_signed_sat");
  put_write(REG_CTRL, {27'd0, 1'b1, OP_VSUB, 1'b1}, "packed_i8_vsub_start");
  for (int poll = 0; poll < 64; poll++)
    put_read(REG_STATUS, "packed_i8_vsub_poll");
  put_check_read(32'h0000_2318, 32'h807f_fbf9, "packed_i8_vsub_check");
  put_write(REG_IRQ_STATUS, 32'd1, "packed_i8_vsub_clear_irq");
  put_write(REG_STATUS, 32'd2, "packed_i8_vsub_clear_done");

  current_op = OP_VMUL;
  current_data_width = 2'd1;
  put_write(32'h0000_2320, 32'h0003_0002, "packed_i16_vmul_src0");
  put_write(32'h0000_2324, 32'h0005_0004, "packed_i16_vmul_src1");
  put_write(REG_SRC0_BASE, 32'h0000_2320, "packed_i16_vmul_cfg_src0");
  put_write(REG_SRC1_BASE, 32'h0000_2324, "packed_i16_vmul_cfg_src1");
  put_write(REG_DST_BASE,  32'h0000_2328, "packed_i16_vmul_cfg_dst");
  put_write(REG_SCALE_SHIFT, 32'd0, "packed_i16_vmul_cfg_shift");
  put_write(REG_CONFIG,    32'h0000_0010, "packed_i16_vmul_cfg");
  put_write(REG_CTRL, {27'd0, 1'b1, OP_VMUL, 1'b1}, "packed_i16_vmul_start");
  for (int poll = 0; poll < 64; poll++)
    put_read(REG_STATUS, "packed_i16_vmul_poll");
  put_check_read(32'h0000_2328, 32'h000f_0008, "packed_i16_vmul_check");
  put_write(REG_IRQ_STATUS, 32'd1, "packed_i16_vmul_clear_irq");
  put_write(REG_STATUS, 32'd2, "packed_i16_vmul_clear_done");

  current_op = OP_VMAC;
  current_data_width = 2'd2;
  put_write(32'h0000_2330, 32'h0403_0201, "packed_i8_vmac_src0");
  put_write(32'h0000_2334, 32'h0202_0202, "packed_i8_vmac_src1");
  put_write(REG_SRC0_BASE, 32'h0000_2330, "packed_i8_vmac_cfg_src0");
  put_write(REG_SRC1_BASE, 32'h0000_2334, "packed_i8_vmac_cfg_src1");
  put_write(REG_DST_BASE,  32'h0000_2338, "packed_i8_vmac_cfg_dst");
  put_write(REG_CONFIG,    32'h0000_0020, "packed_i8_vmac_cfg");
  put_write(REG_CTRL, {27'd0, 1'b1, OP_VMAC, 1'b1}, "packed_i8_vmac_start");
  for (int poll = 0; poll < 64; poll++)
    put_read(REG_STATUS, "packed_i8_vmac_poll");
  put_check_read(32'h0000_2338, 32'd20, "packed_i8_vmac_check");
  put_check_read(REG_RESULT, 32'd20, "packed_i8_vmac_check_result");
  put_write(REG_IRQ_STATUS, 32'd1, "packed_i8_vmac_clear_irq");
  put_write(REG_STATUS, 32'd2, "packed_i8_vmac_clear_done");

  current_op = OP_L1DIST;
  current_data_width = 2'd1;
  put_write(32'h0000_2340, 32'h0010_0008, "packed_i16_l1_src0");
  put_write(32'h0000_2344, 32'h0004_0002, "packed_i16_l1_src1");
  put_write(REG_SRC0_BASE, 32'h0000_2340, "packed_i16_l1_cfg_src0");
  put_write(REG_SRC1_BASE, 32'h0000_2344, "packed_i16_l1_cfg_src1");
  put_write(REG_DST_BASE,  32'h0000_2348, "packed_i16_l1_cfg_dst");
  put_write(REG_CONFIG,    32'h0000_0010, "packed_i16_l1_cfg");
  put_write(REG_CTRL, {27'd0, 1'b1, OP_L1DIST, 1'b1}, "packed_i16_l1_start");
  for (int poll = 0; poll < 64; poll++)
    put_read(REG_STATUS, "packed_i16_l1_poll");
  put_check_read(32'h0000_2348, 32'd18, "packed_i16_l1_check");
  put_check_read(REG_RESULT, 32'd18, "packed_i16_l1_check_result");
  put_write(REG_IRQ_STATUS, 32'd1, "packed_i16_l1_clear_irq");
  put_write(REG_STATUS, 32'd2, "packed_i16_l1_clear_done");
  put_write(REG_CONFIG, 32'd0, "packed_config_restore");
endtask : gen_packed_config_cases

task ahb_slv_generator::gen_signed_saturate_round_cases();
  current_len = 16'd1;
  current_data_width = 2'd0;
  current_neuron_count = 16'd0;
  current_som_winner_pos = 2'd3;
  $display($time, "ns:[ahb_slv_generator] Generate signed/saturate/round cases");

  current_op = OP_VADD;
  put_write(32'h0000_3700, 32'hffff_fff6, "signed_vadd_src0");
  put_write(32'h0000_3704, 32'd3, "signed_vadd_src1");
  put_write(REG_SRC0_BASE, 32'h0000_3700, "signed_vadd_cfg_src0");
  put_write(REG_SRC1_BASE, 32'h0000_3704, "signed_vadd_cfg_src1");
  put_write(REG_DST_BASE,  32'h0000_3708, "signed_vadd_cfg_dst");
  put_write(REG_LENGTH,    32'd1, "signed_vadd_cfg_length");
  put_write(REG_CONFIG,    32'h0000_0001, "signed_vadd_cfg");
  put_write(REG_CTRL, {27'd0, 1'b1, OP_VADD, 1'b1}, "signed_vadd_start");
  for (int poll = 0; poll < 64; poll++)
    put_read(REG_STATUS, "signed_vadd_poll");
  put_check_read(32'h0000_3708, 32'hffff_fff9, "signed_vadd_check");
  put_write(REG_IRQ_STATUS, 32'd1, "signed_vadd_clear_irq");
  put_write(REG_STATUS, 32'd2, "signed_vadd_clear_done");

  current_op = OP_VMUL;
  put_write(32'h0000_3710, 32'hffff_fff9, "signed_round_vmul_src0");
  put_write(32'h0000_3714, 32'd5, "signed_round_vmul_src1");
  put_write(REG_SRC0_BASE, 32'h0000_3710, "signed_round_vmul_cfg_src0");
  put_write(REG_SRC1_BASE, 32'h0000_3714, "signed_round_vmul_cfg_src1");
  put_write(REG_DST_BASE,  32'h0000_3718, "signed_round_vmul_cfg_dst");
  put_write(REG_SCALE_SHIFT, 32'd2, "signed_round_vmul_cfg_shift");
  put_write(REG_CONFIG,    32'h0000_0005, "signed_round_vmul_cfg");
  put_write(REG_CTRL, {27'd0, 1'b1, OP_VMUL, 1'b1}, "signed_round_vmul_start");
  for (int poll = 0; poll < 64; poll++)
    put_read(REG_STATUS, "signed_round_vmul_poll");
  put_check_read(32'h0000_3718, 32'hffff_fff6, "signed_round_vmul_check");
  put_write(REG_IRQ_STATUS, 32'd1, "signed_round_vmul_clear_irq");
  put_write(REG_STATUS, 32'd2, "signed_round_vmul_clear_done");

  current_op = OP_VMAC;
  put_write(32'h0000_3720, 32'hffff_fff9, "signed_round_vmac_src0");
  put_write(32'h0000_3724, 32'd5, "signed_round_vmac_src1");
  put_write(REG_SRC0_BASE, 32'h0000_3720, "signed_round_vmac_cfg_src0");
  put_write(REG_SRC1_BASE, 32'h0000_3724, "signed_round_vmac_cfg_src1");
  put_write(REG_DST_BASE,  32'h0000_3728, "signed_round_vmac_cfg_dst");
  put_write(REG_CONFIG,    32'h0000_0005, "signed_round_vmac_cfg");
  put_write(REG_CTRL, {27'd0, 1'b1, OP_VMAC, 1'b1}, "signed_round_vmac_start");
  for (int poll = 0; poll < 64; poll++)
    put_read(REG_STATUS, "signed_round_vmac_poll");
  put_check_read(32'h0000_3728, 32'hffff_fff6, "signed_round_vmac_check");
  put_write(REG_IRQ_STATUS, 32'd1, "signed_round_vmac_clear_irq");
  put_write(REG_STATUS, 32'd2, "signed_round_vmac_clear_done");

  current_op = OP_L1DIST;
  put_write(32'h0000_3730, 32'hffff_fff6, "signed_l1_src0");
  put_write(32'h0000_3734, 32'd5, "signed_l1_src1");
  put_write(REG_SRC0_BASE, 32'h0000_3730, "signed_l1_cfg_src0");
  put_write(REG_SRC1_BASE, 32'h0000_3734, "signed_l1_cfg_src1");
  put_write(REG_DST_BASE,  32'h0000_3738, "signed_l1_cfg_dst");
  put_write(REG_CONFIG,    32'h0000_0001, "signed_l1_cfg");
  put_write(REG_CTRL, {27'd0, 1'b1, OP_L1DIST, 1'b1}, "signed_l1_start");
  for (int poll = 0; poll < 64; poll++)
    put_read(REG_STATUS, "signed_l1_poll");
  put_check_read(32'h0000_3738, 32'd15, "signed_l1_check");
  put_write(REG_IRQ_STATUS, 32'd1, "signed_l1_clear_irq");
  put_write(REG_STATUS, 32'd2, "signed_l1_clear_done");

  current_op = OP_VADD;
  put_write(32'h0000_3740, 32'hffff_ffff, "sat32_vadd_src0");
  put_write(32'h0000_3744, 32'd1, "sat32_vadd_src1");
  put_write(REG_SRC0_BASE, 32'h0000_3740, "sat32_vadd_cfg_src0");
  put_write(REG_SRC1_BASE, 32'h0000_3744, "sat32_vadd_cfg_src1");
  put_write(REG_DST_BASE,  32'h0000_3748, "sat32_vadd_cfg_dst");
  put_write(REG_CONFIG,    32'h0000_0002, "sat32_vadd_cfg");
  put_write(REG_CTRL, {27'd0, 1'b1, OP_VADD, 1'b1}, "sat32_vadd_start");
  for (int poll = 0; poll < 64; poll++)
    put_read(REG_STATUS, "sat32_vadd_poll");
  put_check_read(32'h0000_3748, 32'hffff_ffff, "sat32_vadd_check");
  put_write(REG_IRQ_STATUS, 32'd1, "sat32_vadd_clear_irq");
  put_write(REG_STATUS, 32'd2, "sat32_vadd_clear_done");
  put_write(REG_CONFIG, 32'd0, "signed_sat_round_restore_config");
  put_write(REG_SCALE_SHIFT, 32'd0, "signed_sat_round_restore_shift");
endtask : gen_signed_saturate_round_cases

task ahb_slv_generator::gen_irq_control_case();
  current_op = OP_VADD;
  current_len = 16'd1;
  current_data_width = 2'd0;
  current_neuron_count = 16'd0;
  current_som_winner_pos = 2'd3;
  $display($time, "ns:[ahb_slv_generator] Generate IRQ enable/mask/clear case");

  put_write(32'h0000_2380, 32'd11, "irq_ctrl_src0");
  put_write(32'h0000_2384, 32'd22, "irq_ctrl_src1");
  put_write(REG_SRC0_BASE, 32'h0000_2380, "irq_ctrl_cfg_src0");
  put_write(REG_SRC1_BASE, 32'h0000_2384, "irq_ctrl_cfg_src1");
  put_write(REG_DST_BASE,  32'h0000_2388, "irq_ctrl_cfg_dst");
  put_write(REG_LENGTH,    32'd1, "irq_ctrl_cfg_length");
  put_write(REG_IRQ_ENABLE, 32'd1, "irq_ctrl_enable");
  put_write(REG_IRQ_MASK,   32'd1, "irq_ctrl_mask");
  put_check_read(REG_IRQ_ENABLE, 32'd1, "irq_ctrl_enable_check");
  put_check_read(REG_IRQ_MASK,   32'd1, "irq_ctrl_mask_check");
  put_write(REG_CTRL, {27'd0, 1'b1, OP_VADD, 1'b1}, "irq_ctrl_start");
  for (int poll = 0; poll < 64; poll++)
    put_read(REG_STATUS, "irq_ctrl_poll");
  put_check_read(REG_IRQ_STATUS, 32'd1, "irq_ctrl_pending_masked", 1'b1, 1'b0);
  put_write(REG_IRQ_MASK, 32'd0, "irq_ctrl_unmask");
  put_check_read(REG_IRQ_STATUS, 32'd1, "irq_ctrl_pending_unmasked", 1'b1, 1'b1);
  put_write(REG_IRQ_CLEAR, 32'd1, "irq_ctrl_clear");
  put_check_read(REG_IRQ_STATUS, 32'd0, "irq_ctrl_cleared", 1'b1, 1'b0);
  put_write(REG_STATUS, 32'd2, "irq_ctrl_clear_done");
endtask : gen_irq_control_case

task ahb_slv_generator::gen_som_recall_word_case();
  bit [31:0] x_base;
  bit [31:0] w_base;
  int poll_count;

  x_base = 32'h0000_2400;
  w_base = 32'h0000_2500;
  poll_count = 192;
  current_op = OP_SOM_RECALL;
  current_len = 16'd3;
  current_data_width = 2'd0;
  current_neuron_count = 16'd3;
  current_som_winner_pos = 2'd1;

  $display($time, "ns:[ahb_slv_generator] Generate SOM_RECALL word case");

  put_write(x_base + 32'd0, 32'd10, "som_recall_word_x0");
  put_write(x_base + 32'd4, 32'd20, "som_recall_word_x1");
  put_write(x_base + 32'd8, 32'd30, "som_recall_word_x2");

  put_write(w_base + 32'h00 + 32'd0, 32'd0,   "som_recall_word_w0_0");
  put_write(w_base + 32'h00 + 32'd4, 32'd0,   "som_recall_word_w0_1");
  put_write(w_base + 32'h00 + 32'd8, 32'd0,   "som_recall_word_w0_2");
  put_write(w_base + 32'h20 + 32'd0, 32'd9,   "som_recall_word_w1_0");
  put_write(w_base + 32'h20 + 32'd4, 32'd19,  "som_recall_word_w1_1");
  put_write(w_base + 32'h20 + 32'd8, 32'd31,  "som_recall_word_w1_2");
  put_write(w_base + 32'h40 + 32'd0, 32'd100, "som_recall_word_w2_0");
  put_write(w_base + 32'h40 + 32'd4, 32'd100, "som_recall_word_w2_1");
  put_write(w_base + 32'h40 + 32'd8, 32'd100, "som_recall_word_w2_2");

  put_write(REG_SRC0_BASE,     x_base, "som_recall_word_cfg_x");
  put_write(REG_SRC1_BASE,     w_base, "som_recall_word_cfg_w");
  put_write(REG_DST_BASE,      32'h0000_2700, "som_recall_word_cfg_dst_unused");
  put_write(REG_LENGTH,        32'd3, "som_recall_word_cfg_len");
  put_write(REG_SCALE_SHIFT,   32'd0, "som_recall_word_cfg_alpha_unused");
  put_write(REG_SRC0_STRIDE,   32'd4, "som_recall_word_cfg_x_stride");
  put_write(REG_SRC1_STRIDE,   32'd4, "som_recall_word_cfg_w_stride");
  put_write(REG_DST_STRIDE,    32'd4, "som_recall_word_cfg_dst_stride");
  put_write(REG_CONFIG,        32'd0, "som_recall_word_cfg_config");
  put_write(REG_NEURON_COUNT,  32'd3, "som_recall_word_cfg_neuron_count");
  put_write(REG_NEURON_STRIDE, 32'h20, "som_recall_word_cfg_neuron_stride");
  put_write(REG_NEURON_INDEX,  32'd0, "som_recall_word_cfg_neuron_index_unused");
  put_write(REG_CTRL,          {27'd0, 1'b1, OP_SOM_RECALL, 1'b1}, "som_recall_word_start");

  for (int poll = 0; poll < poll_count; poll++)
    put_read(REG_STATUS, "som_recall_word_poll");

  put_check_read(REG_SOM_WINNER,    32'd1, "som_recall_word_check_winner");
  put_check_read(REG_SOM_BEST_DIST, 32'd3, "som_recall_word_check_best_dist");
  put_check_read(REG_RESULT,        32'd1, "som_recall_word_check_result");
  put_check_read(REG_IRQ_STATUS,    32'd1, "som_recall_word_check_irq", 1'b1, 1'b1);
  put_write(REG_IRQ_STATUS, 32'd1, "som_recall_word_clear_irq");
  put_write(REG_STATUS, 32'd2, "som_recall_word_clear_done");
endtask : gen_som_recall_word_case

task ahb_slv_generator::gen_som_update_word_case();
  bit [31:0] x_base;
  bit [31:0] w_base;
  int poll_count;

  x_base = 32'h0000_2800;
  w_base = 32'h0000_2900;
  poll_count = 96;
  current_op = OP_SOM_UPDATE;
  current_len = 16'd2;
  current_data_width = 2'd0;
  current_neuron_count = 16'd2;
  current_som_winner_pos = 2'd1;

  $display($time, "ns:[ahb_slv_generator] Generate SOM_UPDATE word case");

  put_write(x_base + 32'd0, 32'd20, "som_update_word_x0");
  put_write(x_base + 32'd4, 32'd10, "som_update_word_x1");
  put_write(w_base + 32'h00 + 32'd0, 32'd0,  "som_update_word_w0_0");
  put_write(w_base + 32'h00 + 32'd4, 32'd0,  "som_update_word_w0_1");
  put_write(w_base + 32'h20 + 32'd0, 32'd12, "som_update_word_w1_0");
  put_write(w_base + 32'h20 + 32'd4, 32'd18, "som_update_word_w1_1");

  put_write(REG_SRC0_BASE,     x_base, "som_update_word_cfg_x");
  put_write(REG_SRC1_BASE,     w_base, "som_update_word_cfg_w");
  put_write(REG_DST_BASE,      32'h0000_2b00, "som_update_word_cfg_dst_unused");
  put_write(REG_LENGTH,        32'd2, "som_update_word_cfg_len");
  put_write(REG_SCALE_SHIFT,   32'd1, "som_update_word_cfg_alpha");
  put_write(REG_SRC0_STRIDE,   32'd4, "som_update_word_cfg_x_stride");
  put_write(REG_SRC1_STRIDE,   32'd4, "som_update_word_cfg_w_stride");
  put_write(REG_DST_STRIDE,    32'd4, "som_update_word_cfg_dst_stride");
  put_write(REG_CONFIG,        32'd0, "som_update_word_cfg_config");
  put_write(REG_NEURON_COUNT,  32'd2, "som_update_word_cfg_neuron_count");
  put_write(REG_NEURON_STRIDE, 32'h20, "som_update_word_cfg_neuron_stride");
  put_write(REG_NEURON_INDEX,  32'd1, "som_update_word_cfg_neuron_index");
  put_write(REG_CTRL,          {27'd0, 1'b1, OP_SOM_UPDATE, 1'b1}, "som_update_word_start");

  for (int poll = 0; poll < poll_count; poll++)
    put_read(REG_STATUS, "som_update_word_poll");

  put_check_read(w_base + 32'h20 + 32'd0, 32'd16, "som_update_word_check_w1_0");
  put_check_read(w_base + 32'h20 + 32'd4, 32'd14, "som_update_word_check_w1_1");
  put_check_read(REG_SOM_WINNER, 32'd1, "som_update_word_check_index");
  put_check_read(REG_RESULT,     32'd1, "som_update_word_check_result");
  put_write(REG_IRQ_STATUS, 32'd1, "som_update_word_clear_irq");
  put_write(REG_STATUS, 32'd2, "som_update_word_clear_done");
endtask : gen_som_update_word_case

task ahb_slv_generator::gen_som_recall_int16_case();
  bit [31:0] x_base;
  bit [31:0] w_base;
  int poll_count;

  x_base = 32'h0000_2c00;
  w_base = 32'h0000_2d00;
  poll_count = 128;
  current_op = OP_SOM_RECALL;
  current_len = 16'd2;
  current_data_width = 2'd1;
  current_neuron_count = 16'd2;
  current_som_winner_pos = 2'd0;

  $display($time, "ns:[ahb_slv_generator] Generate SOM_RECALL int16 packed case");

  put_write(x_base + 32'd0, 32'h0014_000a, "som_recall_i16_x0");
  put_write(x_base + 32'd4, 32'h0028_001e, "som_recall_i16_x1");
  put_write(w_base + 32'h00 + 32'd0, 32'h0014_000a, "som_recall_i16_w0_0");
  put_write(w_base + 32'h00 + 32'd4, 32'h0028_001e, "som_recall_i16_w0_1");
  put_write(w_base + 32'h20 + 32'd0, 32'h0000_0000, "som_recall_i16_w1_0");
  put_write(w_base + 32'h20 + 32'd4, 32'h0000_0000, "som_recall_i16_w1_1");

  put_write(REG_SRC0_BASE,     x_base, "som_recall_i16_cfg_x");
  put_write(REG_SRC1_BASE,     w_base, "som_recall_i16_cfg_w");
  put_write(REG_DST_BASE,      32'h0000_2f00, "som_recall_i16_cfg_dst_unused");
  put_write(REG_LENGTH,        32'd2, "som_recall_i16_cfg_len");
  put_write(REG_SCALE_SHIFT,   32'd0, "som_recall_i16_cfg_alpha_unused");
  put_write(REG_SRC0_STRIDE,   32'd4, "som_recall_i16_cfg_x_stride");
  put_write(REG_SRC1_STRIDE,   32'd4, "som_recall_i16_cfg_w_stride");
  put_write(REG_CONFIG,        32'h0000_0010, "som_recall_i16_cfg_config");
  put_write(REG_NEURON_COUNT,  32'd2, "som_recall_i16_cfg_neuron_count");
  put_write(REG_NEURON_STRIDE, 32'h20, "som_recall_i16_cfg_neuron_stride");
  put_write(REG_CTRL,          {27'd0, 1'b1, OP_SOM_RECALL, 1'b1}, "som_recall_i16_start");

  for (int poll = 0; poll < poll_count; poll++)
    put_read(REG_STATUS, "som_recall_i16_poll");

  put_check_read(REG_SOM_WINNER,    32'd0, "som_recall_i16_check_winner");
  put_check_read(REG_SOM_BEST_DIST, 32'd0, "som_recall_i16_check_best_dist");
  put_check_read(REG_RESULT,        32'd0, "som_recall_i16_check_result");
  put_write(REG_IRQ_STATUS, 32'd1, "som_recall_i16_clear_irq");
  put_write(REG_STATUS, 32'd2, "som_recall_i16_clear_done");
  put_write(REG_CONFIG, 32'd0, "som_recall_i16_clear_config");
endtask : gen_som_recall_int16_case

task ahb_slv_generator::gen_som_update_int8_case();
  bit [31:0] x_base;
  bit [31:0] w_base;
  int poll_count;

  x_base = 32'h0000_3000;
  w_base = 32'h0000_3100;
  poll_count = 80;
  current_op = OP_SOM_UPDATE;
  current_len = 16'd1;
  current_data_width = 2'd2;
  current_neuron_count = 16'd1;
  current_som_winner_pos = 2'd0;

  $display($time, "ns:[ahb_slv_generator] Generate SOM_UPDATE int8 packed case");

  put_write(x_base, 32'h2018_1008, "som_update_i8_x");
  put_write(w_base, 32'h100c_0804, "som_update_i8_w");

  put_write(REG_SRC0_BASE,     x_base, "som_update_i8_cfg_x");
  put_write(REG_SRC1_BASE,     w_base, "som_update_i8_cfg_w");
  put_write(REG_DST_BASE,      32'h0000_3200, "som_update_i8_cfg_dst_unused");
  put_write(REG_LENGTH,        32'd1, "som_update_i8_cfg_len");
  put_write(REG_SCALE_SHIFT,   32'd1, "som_update_i8_cfg_alpha");
  put_write(REG_SRC0_STRIDE,   32'd4, "som_update_i8_cfg_x_stride");
  put_write(REG_SRC1_STRIDE,   32'd4, "som_update_i8_cfg_w_stride");
  put_write(REG_CONFIG,        32'h0000_0020, "som_update_i8_cfg_config");
  put_write(REG_NEURON_COUNT,  32'd1, "som_update_i8_cfg_neuron_count");
  put_write(REG_NEURON_STRIDE, 32'd4, "som_update_i8_cfg_neuron_stride");
  put_write(REG_NEURON_INDEX,  32'd0, "som_update_i8_cfg_neuron_index");
  put_write(REG_CTRL,          {27'd0, 1'b1, OP_SOM_UPDATE, 1'b1}, "som_update_i8_start");

  for (int poll = 0; poll < poll_count; poll++)
    put_read(REG_STATUS, "som_update_i8_poll");

  put_check_read(w_base, 32'h1812_0c06, "som_update_i8_check_weight");
  put_check_read(REG_SOM_WINNER, 32'd0, "som_update_i8_check_index");
  put_check_read(REG_RESULT,     32'd0, "som_update_i8_check_result");
  put_write(REG_IRQ_STATUS, 32'd1, "som_update_i8_clear_irq");
  put_write(REG_STATUS, 32'd2, "som_update_i8_clear_done");
  put_write(REG_CONFIG, 32'd0, "som_update_i8_clear_config");
endtask : gen_som_update_int8_case

task ahb_slv_generator::gen_som_recall_last_case();
  bit [31:0] x_base;
  bit [31:0] w_base;

  x_base = 32'h0000_3400;
  w_base = 32'h0000_3500;
  current_op = OP_SOM_RECALL;
  current_len = 16'd1;
  current_data_width = 2'd0;
  current_neuron_count = 16'd4;
  current_som_winner_pos = 2'd2;
  $display($time, "ns:[ahb_slv_generator] Generate SOM_RECALL winner-last case");

  put_write(x_base,              32'd50, "som_last_x");
  put_write(w_base + 32'h00,     32'd0,  "som_last_w0");
  put_write(w_base + 32'h20,     32'd10, "som_last_w1");
  put_write(w_base + 32'h40,     32'd20, "som_last_w2");
  put_write(w_base + 32'h60,     32'd49, "som_last_w3");
  put_write(REG_SRC0_BASE,       x_base, "som_last_cfg_x");
  put_write(REG_SRC1_BASE,       w_base, "som_last_cfg_w");
  put_write(REG_DST_BASE,        32'h0000_3600, "som_last_cfg_dst_unused");
  put_write(REG_LENGTH,          32'd1, "som_last_cfg_length");
  put_write(REG_SRC0_STRIDE,     32'd4, "som_last_cfg_src0_stride");
  put_write(REG_SRC1_STRIDE,     32'd4, "som_last_cfg_src1_stride");
  put_write(REG_DST_STRIDE,      32'd4, "som_last_cfg_dst_stride");
  put_write(REG_NEURON_COUNT,    32'd4, "som_last_cfg_neuron_count");
  put_write(REG_NEURON_STRIDE,   32'h20, "som_last_cfg_neuron_stride");
  put_write(REG_CTRL, {27'd0, 1'b1, OP_SOM_RECALL, 1'b1}, "som_last_start");
  for (int poll = 0; poll < 192; poll++)
    put_read(REG_STATUS, "som_last_poll");
  put_check_read(REG_SOM_WINNER,    32'd3, "som_last_check_winner");
  put_check_read(REG_SOM_BEST_DIST, 32'd1, "som_last_check_distance");
  put_check_read(REG_ELEMENT_COUNT, 32'd4, "som_last_check_elements");
  put_write(REG_IRQ_STATUS, 32'd1, "som_last_clear_irq");
  put_write(REG_STATUS, 32'd2, "som_last_clear_done");
endtask : gen_som_recall_last_case

task ahb_slv_generator::gen_boundary_addr_case();
  current_op = OP_VADD;
  current_len = 16'd1;
  $display($time, "ns:[ahb_slv_generator] Generate legal boundary address case");

  put_write(32'h0000_3ff4, 32'd100, "boundary_src0");
  put_write(32'h0000_3ff8, 32'd23,  "boundary_src1");
  put_write(REG_SRC0_BASE, 32'h0000_3ff4, "boundary_cfg_src0");
  put_write(REG_SRC1_BASE, 32'h0000_3ff8, "boundary_cfg_src1");
  put_write(REG_DST_BASE,  32'h0000_3ffc, "boundary_cfg_dst");
  put_write(REG_LENGTH,    32'd1, "boundary_cfg_length");
  put_write(REG_CTRL,      {27'd0, 1'b1, OP_VADD, 1'b1}, "boundary_start");
  for (int poll = 0; poll < 64; poll++)
    put_read(REG_STATUS, "boundary_poll_status");
  put_check_read(32'h0000_3ffc, 32'd123, "boundary_check_result");
  put_check_read(REG_IRQ_STATUS, 32'd1, "boundary_check_irq", 1'b1, 1'b1);
  put_write(REG_IRQ_STATUS, 32'd1, "boundary_clear_irq");
  put_check_read(REG_IRQ_STATUS, 32'd0, "boundary_check_irq_clear", 1'b1, 1'b0);
  put_write(REG_STATUS, 32'd2, "boundary_clear_done");
endtask : gen_boundary_addr_case

task ahb_slv_generator::gen_busy_protection_case();
  current_op = OP_VADD;
  current_len = 16'd16;
  $display($time, "ns:[ahb_slv_generator] Generate busy protection case");

  for (int i = 0; i < 16; i++) begin
    put_write(32'h0000_1800 + i * 4, 32'd3 + i, "busy_src0");
    put_write(32'h0000_1900 + i * 4, 32'd7 + i, "busy_src1");
  end
  put_write(REG_SRC0_BASE, 32'h0000_1800, "busy_cfg_src0");
  put_write(REG_SRC1_BASE, 32'h0000_1900, "busy_cfg_src1");
  put_write(REG_DST_BASE,  32'h0000_1a00, "busy_cfg_dst");
  put_write(REG_LENGTH,    32'd16, "busy_cfg_length");
  put_write(REG_CTRL,      {27'd0, 1'b1, OP_VADD, 1'b1}, "busy_start");

  put_read(REG_STATUS, "busy_confirm_status");
  put_expect_error(1'b0, 32'h0000_1800, 32'd0, 3'b010, 2'b10, 3'b000, "busy_sram_read_error");
  put_expect_error(1'b1, REG_LENGTH, 32'd4, 3'b010, 2'b10, 3'b000, "busy_cfg_write_error");

  for (int poll = 0; poll < 320; poll++)
    put_read(REG_STATUS, "busy_poll_status");
  put_check_read(32'h0000_1a00, 32'd10, "busy_check_first_result");
  put_check_read(REG_IRQ_STATUS, 32'd1, "busy_check_irq", 1'b1, 1'b1);
  put_write(REG_IRQ_STATUS, 32'd1, "busy_clear_irq");
  put_check_read(REG_IRQ_STATUS, 32'd0, "busy_check_irq_clear", 1'b1, 1'b0);
  put_write(REG_STATUS, 32'd2, "busy_clear_done");
endtask : gen_busy_protection_case

task ahb_slv_generator::gen_length_zero_error();
  current_op = OP_VADD;
  current_len = 16'd0;
  $display($time, "ns:[ahb_slv_generator] Generate length zero error case");
  put_write(REG_SRC0_BASE, 32'h0000_0000, "err_cfg_src0");
  put_write(REG_SRC1_BASE, 32'h0000_0100, "err_cfg_src1");
  put_write(REG_DST_BASE,  32'h0000_0200, "err_cfg_dst");
  put_write(REG_LENGTH,    32'd0, "err_cfg_length_zero");
  put_write(REG_CTRL,      {27'd0, 1'b0, OP_VADD, 1'b1}, "err_start_length_zero");
  for (int poll = 0; poll < 16; poll++)
    put_read(REG_STATUS, "err_poll_status");
  put_check_read(REG_STATUS, 32'h0000_0006, "check_length_zero_status");
  put_write(REG_STATUS, 32'h0000_0006, "clear_error_done");
endtask : gen_length_zero_error

task ahb_slv_generator::gen_error_config_cases();
  current_op = 3'd7;
  current_len = 16'd2;
  $display($time, "ns:[ahb_slv_generator] Generate configuration error cases");

  put_write(REG_SRC0_BASE, 32'h0000_0000, "illegal_op_src0");
  put_write(REG_SRC1_BASE, 32'h0000_0100, "illegal_op_src1");
  put_write(REG_DST_BASE,  32'h0000_0200, "illegal_op_dst");
  put_write(REG_LENGTH,    32'd2, "illegal_op_length");
  put_write(REG_CTRL,      {27'd0, 1'b0, 3'd7, 1'b1}, "illegal_op_start");
  for (int poll = 0; poll < 16; poll++)
    put_read(REG_STATUS, "illegal_op_poll");
  put_check_read(REG_STATUS, 32'h0000_0006, "check_illegal_op_status");
  put_check_read(REG_ERROR_CODE, 32'd2, "check_illegal_op_error_code");
  put_write(REG_STATUS, 32'h0000_0006, "clear_illegal_op");

  current_op = OP_VADD;
  put_write(REG_SRC0_BASE, 32'h0000_0002, "misalign_src0");
  put_write(REG_SRC1_BASE, 32'h0000_0100, "misalign_src1");
  put_write(REG_DST_BASE,  32'h0000_0200, "misalign_dst");
  put_write(REG_LENGTH,    32'd2, "misalign_length");
  put_write(REG_CTRL,      {27'd0, 1'b0, OP_VADD, 1'b1}, "misalign_start");
  for (int poll = 0; poll < 16; poll++)
    put_read(REG_STATUS, "misalign_poll");
  put_check_read(REG_STATUS, 32'h0000_0006, "check_misalign_status");
  put_check_read(REG_ERROR_CODE, 32'd3, "check_misalign_error_code");
  put_write(REG_STATUS, 32'h0000_0006, "clear_misalign");

  put_write(REG_SRC0_BASE, 32'h0000_0000, "misalign_dst_src0");
  put_write(REG_SRC1_BASE, 32'h0000_0100, "misalign_dst_src1");
  put_write(REG_DST_BASE,  32'h0000_0202, "misalign_dst_addr");
  put_write(REG_LENGTH,    32'd2, "misalign_dst_length");
  put_write(REG_CTRL,      {27'd0, 1'b0, OP_VADD, 1'b1}, "misalign_dst_start");
  for (int poll = 0; poll < 16; poll++)
    put_read(REG_STATUS, "misalign_dst_poll");
  put_check_read(REG_STATUS, 32'h0000_0006, "check_misalign_dst_status");
  put_write(REG_STATUS, 32'h0000_0006, "clear_misalign_dst");

  put_write(REG_SRC0_BASE, 32'h0000_3ffc, "range_src0");
  put_write(REG_SRC1_BASE, 32'h0000_0100, "range_src1");
  put_write(REG_DST_BASE,  32'h0000_0200, "range_dst");
  put_write(REG_LENGTH,    32'd2, "range_length");
  put_write(REG_CTRL,      {27'd0, 1'b0, OP_VADD, 1'b1}, "range_start");
  for (int poll = 0; poll < 16; poll++)
    put_read(REG_STATUS, "range_poll");
  put_check_read(REG_STATUS, 32'h0000_0006, "check_range_status");
  put_write(REG_STATUS, 32'h0000_0006, "clear_range");

  put_write(REG_SRC0_BASE, 32'h0000_0000, "range_dst_src0");
  put_write(REG_SRC1_BASE, 32'h0000_0100, "range_dst_src1");
  put_write(REG_DST_BASE,  32'h0000_3ffc, "range_dst_addr");
  put_write(REG_LENGTH,    32'd2, "range_dst_length");
  put_write(REG_CTRL,      {27'd0, 1'b0, OP_VADD, 1'b1}, "range_dst_start");
  for (int poll = 0; poll < 16; poll++)
    put_read(REG_STATUS, "range_dst_poll");
  put_check_read(REG_STATUS, 32'h0000_0006, "check_range_dst_status");
  put_check_read(REG_ERROR_CODE, 32'd4, "check_range_dst_error_code");
  put_write(REG_STATUS, 32'h0000_0006, "clear_range_dst");

  put_write(REG_SRC0_BASE, 32'h0000_0000, "stride_zero_src0");
  put_write(REG_SRC1_BASE, 32'h0000_0100, "stride_zero_src1");
  put_write(REG_DST_BASE,  32'h0000_0200, "stride_zero_dst");
  put_write(REG_LENGTH,    32'd2, "stride_zero_length");
  put_write(REG_SRC0_STRIDE, 32'd0, "stride_zero_cfg");
  put_write(REG_CTRL, {27'd0, 1'b0, OP_VADD, 1'b1}, "stride_zero_start");
  for (int poll = 0; poll < 16; poll++)
    put_read(REG_STATUS, "stride_zero_poll");
  put_check_read(REG_ERROR_CODE, 32'd5, "check_stride_zero_error_code");
  put_write(REG_STATUS, 32'h0000_0006, "clear_stride_zero");
  put_write(REG_SRC0_STRIDE, 32'd4, "restore_stride_zero");

  put_write(REG_SRC1_STRIDE, 32'd6, "stride_misalign_cfg");
  put_write(REG_CTRL, {27'd0, 1'b0, OP_VADD, 1'b1}, "stride_misalign_start");
  for (int poll = 0; poll < 16; poll++)
    put_read(REG_STATUS, "stride_misalign_poll");
  put_check_read(REG_ERROR_CODE, 32'd3, "check_stride_misalign_error_code");
  put_write(REG_STATUS, 32'h0000_0006, "clear_stride_misalign");
  put_write(REG_SRC1_STRIDE, 32'd4, "restore_stride_misalign");

  put_write(REG_SRC0_BASE, 32'h0000_3ff0, "stride_range_src0");
  put_write(REG_LENGTH, 32'd3, "stride_range_length");
  put_write(REG_SRC0_STRIDE, 32'd16, "stride_range_cfg");
  put_write(REG_CTRL, {27'd0, 1'b0, OP_VADD, 1'b1}, "stride_range_start");
  for (int poll = 0; poll < 16; poll++)
    put_read(REG_STATUS, "stride_range_poll");
  put_check_read(REG_ERROR_CODE, 32'd4, "check_stride_range_error_code");
  put_write(REG_STATUS, 32'h0000_0006, "clear_stride_range");
  put_write(REG_SRC0_STRIDE, 32'd4, "restore_stride_range");

  current_data_width = 2'd3;
  put_write(REG_SRC0_BASE, 32'h0000_0000, "illegal_width_src0");
  put_write(REG_LENGTH, 32'd1, "illegal_width_length");
  put_write(REG_CONFIG, 32'h0000_0030, "illegal_width_cfg");
  put_write(REG_CTRL, {27'd0, 1'b0, OP_VADD, 1'b1}, "illegal_width_start");
  for (int poll = 0; poll < 16; poll++)
    put_read(REG_STATUS, "illegal_width_poll");
  put_check_read(REG_ERROR_CODE, 32'd9, "check_illegal_width_error_code");
  put_write(REG_STATUS, 32'h0000_0006, "clear_illegal_width");
  put_write(REG_CONFIG, 32'd0, "restore_illegal_width");
  current_data_width = 2'd0;

  for (int invalid_width_op = 1; invalid_width_op <= 7; invalid_width_op++) begin
    current_op = invalid_width_op[2:0];
    current_data_width = 2'd3;
    put_write(REG_CONFIG, 32'h0000_0030, "illegal_width_cross_cfg");
    put_write(REG_CTRL, {27'd0, 1'b0, invalid_width_op[2:0], 1'b1}, "illegal_width_cross_start");
    for (int poll = 0; poll < 16; poll++)
      put_read(REG_STATUS, "illegal_width_cross_poll");
    put_check_read(REG_ERROR_CODE, (invalid_width_op == 7) ? 32'd2 : 32'd9,
                   "check_illegal_width_cross_error_code");
    put_write(REG_STATUS, 32'h0000_0006, "clear_illegal_width_cross");
    put_write(REG_CONFIG, 32'd0, "restore_illegal_width_cross");
  end
  current_data_width = 2'd0;

  current_op = OP_SOM_RECALL;
  current_neuron_count = 16'd0;
  put_write(REG_NEURON_COUNT, 32'd0, "illegal_neuron_count_cfg");
  put_write(REG_NEURON_STRIDE, 32'd4, "illegal_neuron_stride_cfg");
  put_write(REG_CTRL, {27'd0, 1'b0, OP_SOM_RECALL, 1'b1}, "illegal_neuron_count_start");
  for (int poll = 0; poll < 16; poll++)
    put_read(REG_STATUS, "illegal_neuron_count_poll");
  put_check_read(REG_ERROR_CODE, 32'd10, "check_illegal_neuron_count_error_code");
  put_write(REG_STATUS, 32'h0000_0006, "clear_illegal_neuron_count");

  current_op = OP_SOM_UPDATE;
  current_neuron_count = 16'd2;
  put_write(REG_NEURON_COUNT, 32'd2, "illegal_neuron_index_count");
  put_write(REG_NEURON_INDEX, 32'd2, "illegal_neuron_index_cfg");
  put_write(REG_CTRL, {27'd0, 1'b0, OP_SOM_UPDATE, 1'b1}, "illegal_neuron_index_start");
  for (int poll = 0; poll < 16; poll++)
    put_read(REG_STATUS, "illegal_neuron_index_poll");
  put_check_read(REG_ERROR_CODE, 32'd10, "check_illegal_neuron_index_error_code");
  put_write(REG_STATUS, 32'h0000_0006, "clear_illegal_neuron_index");
  put_write(REG_NEURON_COUNT, 32'd1, "restore_neuron_count");
  put_write(REG_NEURON_INDEX, 32'd0, "restore_neuron_index");
endtask : gen_error_config_cases

task ahb_slv_generator::gen_vec_directed_suite();
  int random_sram_count;
  int random_vector_count;

  random_sram_count = 0;
  random_vector_count = 0;
  void'($value$plusargs("RANDOM_SRAM_CASES=%d", random_sram_count));
  void'($value$plusargs("RANDOM_VECTOR_CASES=%d", random_vector_count));

  gen_reset_default_cases();
  gen_soft_reset_case();
  gen_register_readback_cases();
  gen_extended_register_cases();
  gen_sram_access_cases();
  gen_lane_bank_cases();
  gen_burst_cases();
  gen_protocol_negative_cases();
  gen_vec_op(OP_VADD,   0, 2, 1'b1);
  gen_vec_op(OP_VSUB,   1, 2, 1'b1);
  gen_vec_op(OP_VMAC,   2, 3, 1'b1);
  gen_vec_op(OP_L1DIST, 3, 4, 1'b1);
  gen_vec_op(OP_VADD,   4, 1, 1'b0);
  gen_vec_op(OP_VSUB,   5, 16, 1'b1);
  gen_vec_op(OP_VADD,   7, 8, 1'b1);
  gen_vec_op(OP_VMAC,   8, 2, 1'b1);
  gen_vmul_stride_case();
  gen_packed_config_cases();
  gen_signed_saturate_round_cases();
  gen_irq_control_case();
  gen_boundary_addr_case();
  gen_busy_protection_case();
  gen_length_zero_error();
  gen_error_config_cases();
  gen_som_recall_word_case();
  gen_som_update_word_case();
  gen_som_recall_int16_case();
  gen_som_update_int8_case();
  gen_som_recall_last_case();
  if (random_sram_count > 0)
    gen_random_sram_cases(random_sram_count);
  if (random_vector_count > 0)
    gen_random_vector_cases(random_vector_count);
endtask : gen_vec_directed_suite

task ahb_slv_generator::start();
  $display($time, "ns: [ahb_slv_generator] Vector accelerator generator started");
  fork
    begin
      gen_vec_directed_suite();
      $display($time, "ns: [ahb_slv_generator] Generation finished, packets=%0d", packet_number);
    end
  join_none
endtask: start
