`timescale 1ns / 1ps

// Scratchpad-resident KV-cache address generator.
// aux0 = {head_index[15:0], token_index[15:0]}; src0_stride is the byte
// stride between tokens and src1_stride is the byte stride between heads.
// OP_KV_WRITE copies vector src0 -> cache dst, OP_KV_READ copies cache src0
// -> vector dst.  Keeping this primitive separate from MHA makes cache
// lifetime, head ownership and causal command chaining visible to software.
module ai_kv_cache_engine(
    input wire clk, input wire resetn, input wire start, input wire abort,
    input wire [7:0] op_mode, input wire [31:0] src0_base,
    input wire [31:0] dst_base, input wire [15:0] length,
    input wire [31:0] src0_stride, input wire [31:0] src1_stride,
    input wire [31:0] aux0, input wire [31:0] watchdog_limit,
    output reg spad_valid, output reg spad_write, output reg [31:0] spad_addr,
    output reg [31:0] spad_wdata, input wire spad_ready,
    input wire spad_rsp_valid, input wire [31:0] spad_rdata,
    input wire spad_error, output reg busy, output reg done, output reg error,
    output reg [3:0] error_code, output reg [31:0] result,
    output reg [31:0] cycle_count, output reg [31:0] element_count
);
  localparam [7:0] OP_KV_WRITE = 8'h43;
  localparam [7:0] OP_KV_READ  = 8'h44;
  localparam [3:0] ERR_CONFIG   = 4'd1;
  localparam [3:0] ERR_OP       = 4'd2;
  localparam [3:0] ERR_ABORT    = 4'd3;
  localparam [3:0] ERR_WATCHDOG = 4'd4;
  localparam [3:0] ERR_SPAD     = 4'd7;

  localparam [2:0] ST_IDLE      = 3'd0;
  localparam [2:0] ST_READ_REQ  = 3'd1;
  localparam [2:0] ST_READ_WAIT = 3'd2;
  localparam [2:0] ST_WRITE     = 3'd3;
  localparam [2:0] ST_DONE      = 3'd4;
  localparam [2:0] ST_ERROR     = 3'd5;

  reg [2:0] state_r;
  reg write_r;
  reg [31:0] src_r, dst_r, cache_offset_r, watchdog_r;
  reg [15:0] length_r, index_r;
  reg [31:0] data_r;
  wire valid_operation = (op_mode == OP_KV_WRITE) || (op_mode == OP_KV_READ);
  wire starts_kv_write = (op_mode == OP_KV_WRITE);
  // Compute address products and the combined cache offset at a width that
  // preserves all 16x32-bit product bits. The SPAD port is word based, so
  // bases/strides must be word aligned and all generated addresses must fit
  // the 32-bit byte-address space before a command is accepted.
  wire [47:0] token_stride_product = {32'd0,aux0[15:0]} * {16'd0,src0_stride};
  wire [47:0] head_stride_product  = {32'd0,aux0[31:16]} * {16'd0,src1_stride};
  wire [48:0] cache_offset_wide = {1'b0,token_stride_product} +
                                           {1'b0,head_stride_product};
  wire [31:0] last_word_byte_offset = ({16'd0,length} - 32'd1) << 2;
  wire [31:0] cache_base = starts_kv_write ? dst_base : src0_base;
  wire [31:0] linear_base = starts_kv_write ? src0_base : dst_base;
  wire [33:0] cache_last_addr_wide = {2'b0,cache_base} +
                                              {2'b0,cache_offset_wide[31:0]} +
                                              {2'b0,last_word_byte_offset};
  wire [33:0] linear_last_addr_wide = {2'b0,linear_base} +
                                               {2'b0,last_word_byte_offset};
  wire kv_address_config_error =
      (src0_base[1:0] != 2'b00) || (dst_base[1:0] != 2'b00) ||
      (src0_stride[1:0] != 2'b00) || (src1_stride[1:0] != 2'b00) ||
      (cache_offset_wide[48:32] != 0) ||
      (cache_last_addr_wide[33:32] != 0) ||
      (linear_last_addr_wide[33:32] != 0);
  wire watchdog_expired = busy && watchdog_r != 0 &&
                          cycle_count >= watchdog_r;
  wire [31:0] cache_addr = cache_offset_r + ({16'd0,index_r}<<2);
  wire [31:0] read_addr = write_r ? (src_r + ({16'd0,index_r}<<2)) : (src_r + cache_addr);
  wire [31:0] write_addr = write_r ? (dst_r + cache_addr) : (dst_r + ({16'd0,index_r}<<2));
  always @(*) begin
    spad_valid=0; spad_write=0; spad_addr=0; spad_wdata=data_r;
    if(state_r==ST_READ_REQ) begin spad_valid=1; spad_addr=read_addr; end
    else if(state_r==ST_WRITE) begin spad_valid=1; spad_write=1; spad_addr=write_addr; end
  end
  always @(posedge clk or negedge resetn) begin
    if(!resetn) begin state_r<=ST_IDLE; busy<=0; done<=0; error<=0; error_code<=0; result<=0; cycle_count<=0; element_count<=0; index_r<=0; end
    else begin
      done<=0;
      if(state_r==ST_IDLE && start && length!=0 && valid_operation) cycle_count<=0;
      else if(busy) cycle_count<=cycle_count+1;
      if(state_r!=ST_ERROR && watchdog_expired) begin error<=1; error_code<=ERR_WATCHDOG; state_r<=ST_ERROR; end
      else if(state_r!=ST_ERROR && ((spad_error && busy) || (abort && busy))) begin error<=1; error_code<=abort?ERR_ABORT:ERR_SPAD; state_r<=ST_ERROR; end
      else case(state_r)
        ST_IDLE: begin busy<=0; error<=0; error_code<=0; if(start) begin
          if(length==0) begin error<=1; error_code<=ERR_CONFIG; state_r<=ST_ERROR; end
          else if(!valid_operation) begin error<=1; error_code<=ERR_OP; state_r<=ST_ERROR; end
          else if(kv_address_config_error) begin error<=1; error_code<=ERR_CONFIG; state_r<=ST_ERROR; end
          else begin busy<=1; write_r<=starts_kv_write; src_r<=src0_base; dst_r<=dst_base;
            cache_offset_r <= cache_offset_wide[31:0];
            length_r<=length; index_r<=0; result<=0; element_count<=0; watchdog_r<=watchdog_limit; state_r<=ST_READ_REQ; end
        end end
        ST_READ_REQ: if(spad_ready) state_r<=ST_READ_WAIT;
        ST_READ_WAIT: if(spad_rsp_valid) begin data_r<=spad_rdata; state_r<=ST_WRITE; end
        ST_WRITE: if(spad_ready) begin
          result<=data_r; element_count<=element_count+1;
          if(index_r+1>=length_r) state_r<=ST_DONE; else begin index_r<=index_r+1; state_r<=ST_READ_REQ; end
        end
        ST_DONE: begin busy<=0; done<=1; state_r<=ST_IDLE; end
        ST_ERROR: begin busy<=0; done<=1; state_r<=ST_IDLE; end
      endcase
    end
  end
endmodule
