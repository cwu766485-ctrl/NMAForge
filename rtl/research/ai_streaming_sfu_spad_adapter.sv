`timescale 1ns/1ps

// Research-only one-element adapter for the product single-word registered
// SPAD contract. It preserves request stability and waits for each response.
module ai_streaming_sfu_spad_adapter (
    input logic clk, input logic resetn, input logic start,
    input logic [1:0] op_mode, input logic [4:0] shift,
    input logic [31:0] src0_base, input logic [31:0] src1_base,
    input logic [31:0] dst_base,
    output logic spad_valid, output logic spad_write,
    output logic [31:0] spad_addr, output logic [31:0] spad_wdata,
    input logic spad_ready, input logic spad_rsp_valid,
    input logic [31:0] spad_rdata, output logic busy, output logic done,
    output logic error, output logic [31:0] result
);
    localparam logic [2:0] IDLE=0,A_REQ=1,A_WAIT=2,B_REQ=3,B_WAIT=4,STREAM_IN=5,STREAM_OUT=6,WRITE=7;
    logic [2:0] state_r; logic [1:0] op_r; logic [4:0] shift_r;
    logic [31:0] src0_r,src1_r,dst_r,a_r,b_r;
    logic in_valid,in_ready,out_valid,out_ready; logic signed [31:0] out_data;
    logic out_error;
    ai_streaming_sfu stream_u(.clk,.resetn,.epoch_bump(1'b0),
      .in_valid,.in_ready,.in_a(a_r),.in_b(b_r),.op_mode(op_r),.shift(shift_r),
      .out_valid,.out_ready,.out_data,.out_error,
      .accepted_count(),.committed_count());
    wire residual = (op_r == 2'd0);
    always_comb begin
      spad_valid=0; spad_write=0; spad_addr=0; spad_wdata=out_data;
      in_valid=(state_r==STREAM_IN); out_ready=(state_r==STREAM_OUT);
      case(state_r)
        A_REQ: begin spad_valid=1; spad_addr=src0_r; end
        B_REQ: begin spad_valid=1; spad_addr=src1_r; end
        WRITE: begin spad_valid=1; spad_write=1; spad_addr=dst_r; end
        default: ;
      endcase
    end
    assign busy=(state_r!=IDLE);
    always_ff @(posedge clk or negedge resetn) begin
      if(!resetn) begin state_r<=IDLE; op_r<=0; shift_r<=0; src0_r<=0; src1_r<=0; dst_r<=0; a_r<=0; b_r<=0; done<=0; error<=0; result<=0; end
      else begin
        done<=0;
        case(state_r)
          IDLE: if(start) begin op_r<=op_mode; shift_r<=shift; src0_r<=src0_base; src1_r<=src1_base; dst_r<=dst_base; error<=0; state_r<=A_REQ; end
          A_REQ: if(spad_ready) state_r<=A_WAIT;
          A_WAIT: if(spad_rsp_valid) begin a_r<=spad_rdata; state_r<=residual?B_REQ:STREAM_IN; end
          B_REQ: if(spad_ready) state_r<=B_WAIT;
          B_WAIT: if(spad_rsp_valid) begin b_r<=spad_rdata; state_r<=STREAM_IN; end
          STREAM_IN: if(in_ready) state_r<=STREAM_OUT;
          STREAM_OUT: if(out_valid && out_ready) begin result<=out_data; error<=out_error; state_r<=WRITE; end
          WRITE: if(spad_ready) begin done<=1; state_r<=IDLE; end
          default: state_r<=IDLE;
        endcase
      end
    end
endmodule
