`timescale 1ns / 1ps

// Scratchpad-resident KV-cache address generator.
// aux0 = {head_index[15:0], token_index[15:0]}. Legacy KV_WRITE/KV_READ use
// src0_stride as the token stride and src1_stride as the head stride. The
// opt-in KV_WRITE Matrix-B append mode (flags[0]) scatters one packed INT8
// token into a [token,feature] B tile by byte-preserving read/modify/write.
module ai_kv_cache_engine(
    input wire clk, input wire resetn, input wire start, input wire abort,
    input wire [7:0] op_mode, input wire [31:0] src0_base,
    input wire [31:0] dst_base, input wire [15:0] length,
    input wire [31:0] src0_stride, input wire [31:0] src1_stride,
    input wire [7:0] flags,
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

  localparam [7:0] KV_FLAG_MATRIX_B_APPEND = 8'h01;

  localparam [3:0] ST_IDLE            = 4'd0;
  localparam [3:0] ST_READ_REQ        = 4'd1;
  localparam [3:0] ST_READ_WAIT       = 4'd2;
  localparam [3:0] ST_WRITE           = 4'd3;
  localparam [3:0] ST_DONE            = 4'd4;
  localparam [3:0] ST_ERROR           = 4'd5;
  localparam [3:0] ST_SCATTER_SRC_REQ = 4'd6;
  localparam [3:0] ST_SCATTER_SRC_WAIT= 4'd7;
  localparam [3:0] ST_SCATTER_DST_REQ = 4'd8;
  localparam [3:0] ST_SCATTER_DST_WAIT= 4'd9;
  localparam [3:0] ST_SCATTER_WRITE   = 4'd10;

  reg [3:0] state_r;
  reg write_r;
  reg [31:0] src_r, dst_r, cache_offset_r, watchdog_r;
  reg [15:0] length_r, index_r;
  reg [31:0] data_r, source_word_r;
  reg [15:0] token_index_r, scatter_capacity_r;
  reg [4:0] scatter_byte_shift_r;
  wire valid_operation = (op_mode == OP_KV_WRITE) || (op_mode == OP_KV_READ);
  wire starts_kv_write = (op_mode == OP_KV_WRITE);
  wire matrix_b_append = (flags == KV_FLAG_MATRIX_B_APPEND);
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
  wire [31:0] scatter_capacity_wide = (length != 0) ?
                                       (src1_stride / length) : 32'd0;
  wire [47:0] scatter_head_offset = {32'd0,aux0[31:16]} *
                                     {16'd0,src1_stride};
  wire [63:0] scatter_dst_last_wide = {32'd0,dst_base} +
      {16'd0,scatter_head_offset} +
      (((({32'd0,length} - 64'd1) >> 2) *
         ({32'd0,scatter_capacity_wide} >> 2) +
         {48'd0,aux0[15:2]}) << 4) +
      ((({32'd0,length} - 64'd1) & 64'd3) << 2);
  wire [32:0] scatter_src_last_wide = {1'b0,src0_base} +
      ({17'd0,((length - 1'b1) >> 2)} * {1'b0,src0_stride});
  wire scatter_geometry_error =
      !starts_kv_write || (length < 16'd4) || (length > 16'd16) ||
      (length[1:0] != 2'b00) || (src0_stride != 32'd16) ||
      (src1_stride == 0) || ((src1_stride % length) != 0) ||
      (scatter_capacity_wide < 4) || (scatter_capacity_wide > 16) ||
      ((scatter_capacity_wide & 32'd3) != 0) ||
      ({16'd0,aux0[15:0]} >= scatter_capacity_wide) ||
      (scatter_dst_last_wide[63:32] != 0) ||
      (scatter_src_last_wide[32] != 0);
  wire kv_address_config_error =
      (src0_base[1:0] != 2'b00) || (dst_base[1:0] != 2'b00) ||
      (src0_stride[1:0] != 2'b00) || (src1_stride[1:0] != 2'b00) ||
      (matrix_b_append ?
       ((flags != KV_FLAG_MATRIX_B_APPEND) || scatter_geometry_error) :
       ((flags != 0) || (cache_offset_wide[48:32] != 0) ||
        (cache_last_addr_wide[33:32] != 0) ||
        (linear_last_addr_wide[33:32] != 0)));
  wire watchdog_expired = busy && watchdog_r != 0 &&
                          cycle_count >= watchdog_r;
  wire [31:0] cache_addr = cache_offset_r + ({16'd0,index_r}<<2);
  wire [31:0] read_addr = write_r ? (src_r + ({16'd0,index_r}<<2)) : (src_r + cache_addr);
  wire [31:0] write_addr = write_r ? (dst_r + cache_addr) : (dst_r + ({16'd0,index_r}<<2));
  wire [31:0] scatter_source_addr = src_r +
                                      (({16'd0,index_r} >> 2) << 4);
  wire [31:0] scatter_cache_word_addr = dst_r + cache_offset_r +
      (((({16'd0,index_r} >> 2) *
          ({16'd0,scatter_capacity_r} >> 2)) +
         ({16'd0,token_index_r} >> 2)) << 4) +
      (({30'd0,index_r[1:0]}) << 2);
  wire [7:0] scatter_source_byte =
      source_word_r[index_r[1:0]*8 +: 8];
  wire [31:0] scatter_write_data =
      (data_r & ~(32'h0000_00ff << scatter_byte_shift_r)) |
      ({24'd0,scatter_source_byte} << scatter_byte_shift_r);
  always @(*) begin
    spad_valid=0; spad_write=0; spad_addr=0;
    spad_wdata=(state_r == ST_SCATTER_WRITE) ? scatter_write_data : data_r;
    if(state_r==ST_READ_REQ) begin spad_valid=1; spad_addr=read_addr; end
    else if(state_r==ST_WRITE) begin spad_valid=1; spad_write=1; spad_addr=write_addr; end
    else if(state_r==ST_SCATTER_SRC_REQ) begin
      spad_valid=1; spad_addr=scatter_source_addr;
    end else if(state_r==ST_SCATTER_DST_REQ) begin
      spad_valid=1; spad_addr=scatter_cache_word_addr;
    end else if(state_r==ST_SCATTER_WRITE) begin
      spad_valid=1; spad_write=1; spad_addr=scatter_cache_word_addr;
    end
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
            cache_offset_r <= matrix_b_append ? scatter_head_offset[31:0] :
                                                   cache_offset_wide[31:0];
            token_index_r <= aux0[15:0];
            scatter_capacity_r <= matrix_b_append ? scatter_capacity_wide[15:0] : 16'd0;
            scatter_byte_shift_r <= {aux0[1:0],3'b000};
            length_r<=length; index_r<=0; result<=0; element_count<=0;
            watchdog_r<=watchdog_limit;
            state_r<=matrix_b_append ? ST_SCATTER_SRC_REQ : ST_READ_REQ;
          end
        end end
        ST_READ_REQ: if(spad_ready) state_r<=ST_READ_WAIT;
        ST_READ_WAIT: if(spad_rsp_valid) begin data_r<=spad_rdata; state_r<=ST_WRITE; end
        ST_WRITE: if(spad_ready) begin
          result<=data_r; element_count<=element_count+1;
          if(index_r+1>=length_r) state_r<=ST_DONE; else begin index_r<=index_r+1; state_r<=ST_READ_REQ; end
        end
        ST_SCATTER_SRC_REQ: if(spad_ready) state_r<=ST_SCATTER_SRC_WAIT;
        ST_SCATTER_SRC_WAIT: if(spad_rsp_valid) begin
          source_word_r<=spad_rdata;
          state_r<=ST_SCATTER_DST_REQ;
        end
        ST_SCATTER_DST_REQ: if(spad_ready) state_r<=ST_SCATTER_DST_WAIT;
        ST_SCATTER_DST_WAIT: if(spad_rsp_valid) begin
          data_r<=spad_rdata;
          state_r<=ST_SCATTER_WRITE;
        end
        ST_SCATTER_WRITE: if(spad_ready) begin
          result<=scatter_write_data;
          element_count<=element_count+1;
          if(index_r+1>=length_r) state_r<=ST_DONE;
          else begin
            index_r<=index_r+1;
            state_r<=((index_r[1:0] == 2'b11) ? ST_SCATTER_SRC_REQ :
                                                        ST_SCATTER_DST_REQ);
          end
        end
        ST_DONE: begin busy<=0; done<=1; state_r<=ST_IDLE; end
        ST_ERROR: begin busy<=0; done<=1; state_r<=ST_IDLE; end
      endcase
    end
  end
endmodule
