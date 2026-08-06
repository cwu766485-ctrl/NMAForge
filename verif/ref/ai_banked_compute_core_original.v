`timescale 1ns / 1ps

// Frozen pre-CNM reference used only by the performance benchmark.  This is
// the original central-accumulator implementation, kept out of synthesizable
// source lists so it cannot accidentally become the active accelerator path.
module ai_banked_compute_core_original(
    input wire clk, input wire resetn, input wire start, input wire abort,
    input wire [7:0] op_mode, input wire [31:0] src0_base, input wire [31:0] src1_base,
    input wire [31:0] dst_base, input wire [15:0] length, input wire [15:0] m_size,
    input wire [4:0] scale_shift, input wire [1:0] activation, input wire [31:0] watchdog_limit,
    input wire [31:0] bank0_data, input wire [31:0] bank1_data, input wire [31:0] bank2_data, input wire [31:0] bank3_data,
    input wire [3:0] bank_parity_error, output reg banked_read_valid, output reg [31:0] banked_addr,
    input wire banked_ready, input wire banked_rsp_valid, input wire banked_protection_error,
    output reg spad_valid, output reg spad_write, output reg [31:0] spad_addr, output reg [31:0] spad_wdata,
    input wire spad_ready, input wire spad_protection_error, output reg busy, output reg done, output reg error,
    output reg [3:0] error_code, output reg [31:0] result, output reg [31:0] cycle_count, output reg [31:0] element_count
);
    localparam [7:0] OP_BANKED_VDOT=8'h20, OP_BANKED_GEMV=8'h21;
    localparam [3:0] ERR_CONFIG=1, ERR_OP=2, ERR_ABORT=3, ERR_WATCHDOG=4, ERR_PARITY=5, ERR_PROTECTION=6;
    localparam [3:0] ST_IDLE=0, ST_A_REQ=1, ST_A_WAIT=2, ST_B_REQ=3, ST_B_WAIT=4, ST_WRITE=5, ST_NEXT=6, ST_DONE=7, ST_ERROR=8;
    reg [3:0] state_r; reg [7:0] op_r; reg [31:0] a_base_r,b_base_r,out_addr_r,watchdog_r;
    reg [4:0] shift_r; reg [1:0] activation_r; reg [15:0] length_r,m_r,row_r,k_r;
    reg [31:0] a0_r,a1_r,a2_r,a3_r; reg signed [63:0] acc_r;
    wire signed [31:0] p0,p1,p2,p3; wire signed [33:0] bank_sum;
    wire signed [63:0] acc_next=acc_r+{{30{bank_sum[33]}},bank_sum};
    wire signed [63:0] shifted=acc_next >>> shift_r;
    wire signed [63:0] activated=(activation_r==2'd1 && shifted<0)?64'sd0:shifted;
    wire [31:0] quantized=(activated>64'sh0000_0000_7fff_ffff)?32'h7fff_ffff:
                           (activated<-64'sd2147483648)?32'h8000_0000:activated[31:0];
    wire last_k=(k_r==length_r-1'b1), last_row=(op_r==OP_BANKED_VDOT)||(row_r==m_r-1'b1);
    wire [31:0] vector_bytes={12'd0,length_r,4'b0000};
    ai_bank_pe pe0(.act_word(a0_r),.weight_word(bank0_data),.partial_sum(p0));
    ai_bank_pe pe1(.act_word(a1_r),.weight_word(bank1_data),.partial_sum(p1));
    ai_bank_pe pe2(.act_word(a2_r),.weight_word(bank2_data),.partial_sum(p2));
    ai_bank_pe pe3(.act_word(a3_r),.weight_word(bank3_data),.partial_sum(p3));
    ai_reduction_tree reduce_u(.partial0(p0),.partial1(p1),.partial2(p2),.partial3(p3),.sum(bank_sum));
    always @(*) begin
      banked_read_valid=(state_r==ST_A_REQ)||(state_r==ST_B_REQ);
      banked_addr=(state_r==ST_A_REQ)?a_base_r+({16'd0,k_r}<<4):b_base_r+({16'd0,k_r}<<4);
      spad_valid=(state_r==ST_WRITE); spad_write=(state_r==ST_WRITE); spad_addr=out_addr_r; spad_wdata=result;
    end
    always @(posedge clk or negedge resetn) begin
      if(!resetn) begin state_r<=ST_IDLE; busy<=0; done<=0; error<=0; error_code<=0; result<=0; cycle_count<=0; element_count<=0; op_r<=0; a_base_r<=0; b_base_r<=0; out_addr_r<=0; watchdog_r<=0; shift_r<=0; activation_r<=0; length_r<=0; m_r<=0; row_r<=0; k_r<=0; a0_r<=0; a1_r<=0; a2_r<=0; a3_r<=0; acc_r<=0; end
      else begin
        done<=0; if(busy) cycle_count<=cycle_count+1'b1;
        if(busy&&abort) begin error_code<=ERR_ABORT; state_r<=ST_ERROR; end
        else if(busy&&watchdog_r!=0&&cycle_count>=watchdog_r) begin error_code<=ERR_WATCHDOG; state_r<=ST_ERROR; end
        else case(state_r)
          ST_IDLE: if(start) begin op_r<=op_mode; a_base_r<=src0_base; b_base_r<=src1_base; out_addr_r<=dst_base; watchdog_r<=watchdog_limit; shift_r<=scale_shift; activation_r<=activation; length_r<=length; m_r<=m_size; row_r<=0; k_r<=0; acc_r<=0; cycle_count<=0; element_count<=0; busy<=1; error<=0; error_code<=0; if(op_mode!=OP_BANKED_VDOT&&op_mode!=OP_BANKED_GEMV) begin error_code<=ERR_OP; state_r<=ST_ERROR; end else if(length==0||(op_mode==OP_BANKED_GEMV&&m_size==0)|||src0_base[3:0]|| |src1_base[3:0] || |dst_base[1:0]) begin error_code<=ERR_CONFIG; state_r<=ST_ERROR; end else state_r<=ST_A_REQ; end
          ST_A_REQ: if(banked_ready) begin if(banked_protection_error) begin error_code<=ERR_PROTECTION; state_r<=ST_ERROR; end else state_r<=ST_A_WAIT; end
          ST_A_WAIT: if(banked_rsp_valid) begin if(|bank_parity_error) begin error_code<=ERR_PARITY; state_r<=ST_ERROR; end else begin a0_r<=bank0_data;a1_r<=bank1_data;a2_r<=bank2_data;a3_r<=bank3_data;state_r<=ST_B_REQ;end end
          ST_B_REQ: if(banked_ready) begin if(banked_protection_error) begin error_code<=ERR_PROTECTION;state_r<=ST_ERROR;end else state_r<=ST_B_WAIT;end
          ST_B_WAIT: if(banked_rsp_valid) begin if(|bank_parity_error) begin error_code<=ERR_PARITY;state_r<=ST_ERROR;end else if(last_k) begin result<=quantized;state_r<=ST_WRITE;end else begin acc_r<=acc_next;k_r<=k_r+1'b1;state_r<=ST_A_REQ;end end
          ST_WRITE: if(spad_ready) begin if(spad_protection_error) begin error_code<=ERR_PROTECTION;state_r<=ST_ERROR;end else begin element_count<=element_count+1'b1;state_r<=ST_NEXT;end end
          ST_NEXT: if(last_row) state_r<=ST_DONE; else begin row_r<=row_r+1'b1;k_r<=0;acc_r<=0;b_base_r<=b_base_r+vector_bytes;out_addr_r<=out_addr_r+4;state_r<=ST_A_REQ;end
          ST_DONE: begin busy<=0;done<=1;error<=0;state_r<=ST_IDLE;end
          ST_ERROR: begin busy<=0;done<=1;error<=1;state_r<=ST_IDLE;end
          default: state_r<=ST_IDLE;
        endcase
      end
    end
endmodule
