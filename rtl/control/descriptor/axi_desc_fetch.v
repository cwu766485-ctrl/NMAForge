`timescale 1ns / 1ps

// A6 external descriptor fetch. A descriptor remains 64 bytes in software
// ABI, but is fetched as four 128-bit beats. ID 0 is reserved exclusively for
// this client; the top-level response demux sends RID 1..4 to payload DMA.
module axi_desc_fetch #(
    parameter integer AXI_ADDR_WIDTH = 64
)(
    input wire clk, input wire resetn, input wire start,
    input wire [AXI_ADDR_WIDTH-1:0] desc_base,
    output wire [3:0] m_axi_arid, output reg m_axi_arvalid,
    output reg [AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    output wire [7:0] m_axi_arlen, output wire [2:0] m_axi_arsize, output wire [1:0] m_axi_arburst,
    input wire m_axi_arready, input wire [3:0] m_axi_rid, input wire [127:0] m_axi_rdata,
    input wire [1:0] m_axi_rresp, input wire m_axi_rvalid, input wire m_axi_rlast, output wire m_axi_rready,
    output reg busy, output reg done, output reg error,
    output reg [7:0] desc_op, output reg [15:0] desc_task_id,
    output reg [31:0] desc_src0_base, output reg [31:0] desc_src1_base, output reg [31:0] desc_dst_base,
    output reg [15:0] desc_length, output reg [15:0] desc_m_size, output reg [15:0] desc_n_size, output reg [15:0] desc_k_words,
    output reg [4:0] desc_scale_shift, output reg [1:0] desc_activation,
    output reg [31:0] desc_bias_base, output reg desc_bias_enable, output reg [7:0] desc_flags, output reg [31:0] desc_aux0,
    output reg [31:0] desc_src0_stride, output reg [31:0] desc_src1_stride, output reg [31:0] desc_dst_stride,
    output reg [15:0] desc_batch_count, output reg [15:0] desc_head_count,
    output reg [15:0] desc_wait_mask, output reg [15:0] desc_signal_mask, output reg [15:0] desc_clear_mask, output reg [7:0] desc_version
);
  localparam [1:0] OKAY=2'b00; localparam [1:0] INCR=2'b01;
  localparam [1:0] IDLE=2'd0, ADDR=2'd1, DATA=2'd2, DONE=2'd3;
  reg [1:0] state_r; reg [1:0] beat_r;
  wire [31:0] d0=m_axi_rdata[31:0], d1=m_axi_rdata[63:32], d2=m_axi_rdata[95:64], d3=m_axi_rdata[127:96];
  assign m_axi_arid=4'd0; assign m_axi_arlen=8'd3; assign m_axi_arsize=3'd4; assign m_axi_arburst=INCR;
  assign m_axi_rready=(state_r==DATA) && (m_axi_rid==4'd0);
  always @(posedge clk or negedge resetn) begin
    if(!resetn) begin
      state_r<=IDLE; beat_r<=0; m_axi_arvalid<=0; m_axi_araddr<=0; busy<=0; done<=0; error<=0;
      desc_op<=0;desc_task_id<=0;desc_src0_base<=0;desc_src1_base<=0;desc_bias_base<=0;desc_dst_base<=0;desc_length<=0;desc_m_size<=0;desc_n_size<=0;desc_k_words<=0;desc_bias_enable<=0;desc_flags<=0;desc_aux0<=0;desc_scale_shift<=0;desc_activation<=0;desc_src0_stride<=0;desc_src1_stride<=0;desc_dst_stride<=0;desc_batch_count<=0;desc_head_count<=0;desc_wait_mask<=0;desc_signal_mask<=0;desc_clear_mask<=0;desc_version<=0;
    end else begin
      done<=0;
      case(state_r)
        IDLE: begin busy<=0; error<=0; m_axi_arvalid<=0; if(start) begin busy<=1; beat_r<=0; if(desc_base[3:0]!=0) begin error<=1;state_r<=DONE;end else begin m_axi_araddr<=desc_base;state_r<=ADDR;end end end
        ADDR: if(!m_axi_arvalid) m_axi_arvalid<=1; else if(m_axi_arready) begin m_axi_arvalid<=0;state_r<=DATA;end
        DATA: if(m_axi_rvalid && m_axi_rready) begin
          if(m_axi_rresp!=OKAY || (m_axi_rlast != (beat_r==3))) begin error<=1;state_r<=DONE;end
          else begin
            case(beat_r)
              0: begin desc_op<=d0[7:0];desc_task_id<=d0[31:16];desc_src0_base<=d1;desc_src1_base<=d2;desc_bias_base<=d3;end
              1: begin desc_dst_base<=d0;desc_m_size<=d1[15:0];desc_n_size<=d1[31:16];desc_k_words<=d2[15:0];desc_length<=d2[15:0];desc_bias_enable<=d3[0];desc_flags<=d3[7:0];end
              2: begin desc_aux0<=d0;desc_scale_shift<=d1[4:0];desc_activation<=d1[6:5];desc_src0_stride<=d2;desc_src1_stride<=d3;end
              default: begin desc_dst_stride<=d0;desc_batch_count<=d1[15:0];desc_head_count<=d1[31:16];desc_wait_mask<=d2[15:0];desc_signal_mask<=d2[31:16];desc_version<=d3[7:0];desc_clear_mask<=d3[31:16];end
            endcase
            if(beat_r==3) state_r<=DONE; else beat_r<=beat_r+1;
          end
        end
        DONE: begin busy<=0;done<=1;state_r<=IDLE;end
      endcase
    end
  end
endmodule
