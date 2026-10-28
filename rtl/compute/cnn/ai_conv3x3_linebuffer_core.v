`timescale 1ns / 1ps

// A6 streaming 3x3 convolution front-end.  Input and coefficient elements
// are signed INT8 in bits[7:0] of scalar scratchpad words.  The engine reads
// each input pixel once into three rotating line buffers and emits the valid
// (no-padding, stride-1) 3x3 window result as an INT32 scratchpad word.
// OP_DWCONV3X3 uses the same per-channel kernel; command software invokes one
// descriptor per channel, with independent src/dst offsets.
module ai_conv3x3_linebuffer_core #(
    parameter integer MAX_WIDTH=128
)(
    input wire clk, input wire resetn, input wire start, input wire abort,
    input wire [7:0] op_mode, input wire [31:0] src0_base,
    input wire [31:0] src1_base, input wire [31:0] dst_base,
    input wire [15:0] height, input wire [15:0] width,
    input wire [31:0] watchdog_limit,
    output reg spad_valid, output reg spad_write, output reg [31:0] spad_addr,
    output reg [31:0] spad_wdata, input wire spad_ready,
    input wire spad_rsp_valid, input wire [31:0] spad_rdata,
    input wire spad_error, output reg busy, output reg done, output reg error,
    output reg [3:0] error_code, output reg [31:0] result,
    output reg [31:0] cycle_count, output reg [31:0] element_count
);
  localparam [7:0] OP_CONV3X3=8'h16, OP_DWCONV3X3=8'h17;
  localparam [3:0] ERR_CONFIG=4'd1, ERR_OP=4'd2, ERR_ABORT=4'd3,
                   ERR_WATCHDOG=4'd4, ERR_SPAD=4'd7;
  localparam [3:0] IDLE=0, W_REQ=1, W_WAIT=2, P_REQ=3, P_WAIT=4,
                   CALC=5, WRITE=6, NEXT=7, DONE=8, ERROR=9;
  reg [3:0] state_r; reg [31:0] src_r, weight_r, dst_r, watchdog_r;
  reg [15:0] h_r,w_r,row_r,col_r,weight_idx_r;
  reg [1:0] row_bank_r;
  // CALC already occupies a dedicated cycle.  Register both products of that
  // cycle so WRITE does not carry the 3x3 MAC/address arithmetic through the
  // scratchpad arbiter, protection checker, and unrelated DMA error fanout.
  // This is a timing boundary, not an extra algorithmic pipeline stage.
  reg [31:0] calc_addr_r;
  reg signed [31:0] calc_sum_r;
  reg signed [7:0] weights [0:8];
  reg signed [7:0] line0 [0:MAX_WIDTH-1];
  reg signed [7:0] line1 [0:MAX_WIDTH-1];
  reg signed [7:0] line2 [0:MAX_WIDTH-1];
  reg signed [31:0] sum_comb;
  function signed [31:0] mul_i8;
    input signed [7:0] lhs;
    input signed [7:0] rhs;
    reg signed [15:0] product;
    begin
      product = lhs * rhs;
      mul_i8 = {{16{product[15]}},product};
    end
  endfunction
  wire [31:0] pixel_addr = src_r + (((row_r*w_r)+col_r)<<2);
  wire [31:0] out_addr = dst_r + ((((row_r-2)*(w_r-2))+(col_r-2))<<2);
  always @(*) begin
    sum_comb=0;
    if(row_r>=2 && col_r>=2) begin
      case(row_bank_r)
        2: sum_comb = mul_i8(line0[col_r-2],weights[0]) + mul_i8(line0[col_r-1],weights[1]) + mul_i8(line0[col_r],weights[2])
                     + mul_i8(line1[col_r-2],weights[3]) + mul_i8(line1[col_r-1],weights[4]) + mul_i8(line1[col_r],weights[5])
                     + mul_i8(line2[col_r-2],weights[6]) + mul_i8(line2[col_r-1],weights[7]) + mul_i8(line2[col_r],weights[8]);
        0: sum_comb = mul_i8(line1[col_r-2],weights[0]) + mul_i8(line1[col_r-1],weights[1]) + mul_i8(line1[col_r],weights[2])
                     + mul_i8(line2[col_r-2],weights[3]) + mul_i8(line2[col_r-1],weights[4]) + mul_i8(line2[col_r],weights[5])
                     + mul_i8(line0[col_r-2],weights[6]) + mul_i8(line0[col_r-1],weights[7]) + mul_i8(line0[col_r],weights[8]);
        default: sum_comb = mul_i8(line2[col_r-2],weights[0]) + mul_i8(line2[col_r-1],weights[1]) + mul_i8(line2[col_r],weights[2])
                           + mul_i8(line0[col_r-2],weights[3]) + mul_i8(line0[col_r-1],weights[4]) + mul_i8(line0[col_r],weights[5])
                           + mul_i8(line1[col_r-2],weights[6]) + mul_i8(line1[col_r-1],weights[7]) + mul_i8(line1[col_r],weights[8]);
      endcase
    end
  end
  always @(*) begin
    spad_valid=0; spad_write=0; spad_addr=0; spad_wdata=calc_sum_r;
    if(state_r==W_REQ) begin spad_valid=1; spad_addr=weight_r+({28'd0,weight_idx_r}<<2); end
    else if(state_r==P_REQ) begin spad_valid=1; spad_addr=pixel_addr; end
    else if(state_r==WRITE) begin spad_valid=1; spad_write=1; spad_addr=calc_addr_r; end
  end
  always @(posedge clk or negedge resetn) begin
    if(!resetn) begin state_r<=IDLE; busy<=0; done<=0; error<=0; error_code<=0; result<=0; cycle_count<=0; element_count<=0; row_r<=0; col_r<=0; weight_idx_r<=0; row_bank_r<=0; calc_addr_r<=0; calc_sum_r<=0; end
    else begin
      done<=0;
      if(state_r==IDLE && start && op_mode==OP_CONV3X3 && height>=3 && width>=3 && width<=MAX_WIDTH)
        cycle_count<=0;
      else if(state_r==IDLE && start && op_mode==OP_DWCONV3X3 && height>=3 && width>=3 && width<=MAX_WIDTH)
        cycle_count<=0;
      else if(busy) cycle_count<=cycle_count+1;
      if(state_r!=ERROR && busy&&watchdog_r!=0&&cycle_count>=watchdog_r) begin error<=1; error_code<=ERR_WATCHDOG; state_r<=ERROR; end
      else if(state_r!=ERROR && ((spad_error&&busy)||(abort&&busy))) begin error<=1; error_code<=abort?ERR_ABORT:ERR_SPAD; state_r<=ERROR; end
      else case(state_r)
        IDLE: begin busy<=0; error<=0; error_code<=0; if(start) begin
          if(op_mode!=OP_CONV3X3 && op_mode!=OP_DWCONV3X3) begin error<=1; error_code<=ERR_OP; state_r<=ERROR; end
          else if(height<3||width<3||width>MAX_WIDTH) begin error<=1; error_code<=ERR_CONFIG; state_r<=ERROR; end
          else begin busy<=1; src_r<=src0_base; weight_r<=src1_base; dst_r<=dst_base; h_r<=height; w_r<=width; watchdog_r<=watchdog_limit; row_r<=0; col_r<=0; row_bank_r<=0; weight_idx_r<=0; element_count<=0; result<=0; state_r<=W_REQ; end
        end end
        W_REQ: if(spad_ready) state_r<=W_WAIT;
        W_WAIT: if(spad_rsp_valid) begin weights[weight_idx_r]<=spad_rdata[7:0]; if(weight_idx_r==8) state_r<=P_REQ; else begin weight_idx_r<=weight_idx_r+1; state_r<=W_REQ; end end
        P_REQ: if(spad_ready) state_r<=P_WAIT;
        P_WAIT: if(spad_rsp_valid) begin
          case(row_bank_r) 0:line0[col_r]<=spad_rdata[7:0]; 1:line1[col_r]<=spad_rdata[7:0]; default:line2[col_r]<=spad_rdata[7:0]; endcase
          if(row_r>=2 && col_r>=2) state_r<=CALC; else state_r<=NEXT;
        end
        CALC: begin
          calc_addr_r <= out_addr;
          calc_sum_r  <= sum_comb;
          state_r     <= WRITE;
        end
        WRITE: if(spad_ready) begin result<=calc_sum_r; element_count<=element_count+1; state_r<=NEXT; end
        NEXT: if(col_r+1>=w_r) begin col_r<=0; if(row_r+1>=h_r) state_r<=DONE; else begin row_r<=row_r+1; row_bank_r<=row_bank_r==2?0:row_bank_r+1; state_r<=P_REQ; end end else begin col_r<=col_r+1; state_r<=P_REQ; end
        DONE: begin busy<=0; done<=1; state_r<=IDLE; end
        ERROR: begin busy<=0; done<=1; state_r<=IDLE; end
      endcase
    end
  end
endmodule
