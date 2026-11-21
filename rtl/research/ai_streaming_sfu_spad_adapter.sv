`timescale 1ns/1ps

// Parameterized research vector engine on the product single-word SPAD
// contract. Results are buffered before ordered writeback, so abort during
// collection commits no output and abort during writeback commits a prefix.
module ai_streaming_sfu_spad_adapter #(
    parameter integer MAX_LEN = 64,
    parameter integer INDEX_W = (MAX_LEN <= 2) ? 1 : $clog2(MAX_LEN)
) (
    input logic clk, input logic resetn, input logic start,
    input logic abort, input logic epoch_bump,
    input logic [1:0] op_mode, input logic [4:0] shift,
    input logic [31:0] src0_base, input logic [31:0] src1_base,
    input logic [31:0] dst_base, input logic [15:0] length,
    output logic spad_valid, output logic spad_write,
    output logic [31:0] spad_addr, output logic [31:0] spad_wdata,
    input logic spad_ready, input logic spad_rsp_valid,
    input logic [31:0] spad_rdata, input logic spad_parity_error,
    input logic spad_protection_error,
    output logic busy, output logic done, output logic error,
    output logic [3:0] error_code, output logic [31:0] cycle_count,
    output logic [31:0] read_accept_count, output logic [31:0] write_accept_count,
    output logic [31:0] request_stall_count, output logic [31:0] response_wait_count
);
    localparam logic [1:0] OP_RESIDUAL=2'd0, OP_REQUANT=2'd1;
    localparam logic [3:0] ERR_CONFIG=4'd1, ERR_ABORT=4'd3,
                           ERR_PARITY=4'd5, ERR_PROTECTION=4'd6;
    localparam logic [3:0] IDLE=0, READ_A_REQ=1, READ_A_WAIT=2,
                           READ_B_REQ=3, READ_B_WAIT=4, STREAM_IN=5,
                           STREAM_OUT=6, WRITEBACK=7, COMPLETE=8;
    logic [3:0] state_r;
    logic [1:0] op_r;
    logic [4:0] shift_r;
    logic [15:0] length_r;
    logic [INDEX_W-1:0] index_r;
    logic [31:0] src0_r,src1_r,dst_r,a_r,b_r;
    logic signed [31:0] output_buffer [0:MAX_LEN-1];
    logic in_valid,in_ready,out_valid,out_ready; logic signed [31:0] out_data;
    logic out_error, abort_pending_r;

    ai_streaming_sfu stream_u(.clk,.resetn,.epoch_bump(abort|epoch_bump),
      .in_valid,.in_ready,.in_a(a_r),.in_b(b_r),.op_mode(op_r),.shift(shift_r),
      .out_valid,.out_ready,.out_data,.out_error,
      .accepted_count(),.committed_count());

    always_comb begin
      spad_valid=0; spad_write=0; spad_addr=0; spad_wdata=0;
      in_valid=(state_r==STREAM_IN); out_ready=(state_r==STREAM_OUT);
      case(state_r)
        READ_A_REQ: begin spad_valid=1; spad_addr=src0_r+({16'b0,index_r}<<2); end
        READ_B_REQ: begin spad_valid=1; spad_addr=src1_r+({16'b0,index_r}<<2); end
        WRITEBACK: begin spad_valid=1; spad_write=1;
          spad_addr=dst_r+({16'b0,index_r}<<2); spad_wdata=output_buffer[index_r]; end
        default: ;
      endcase
    end

    always_ff @(posedge clk or negedge resetn) begin
      if(!resetn) begin
        state_r<=IDLE; op_r<=0; shift_r<=0; length_r<=0; index_r<=0;
        src0_r<=0; src1_r<=0; dst_r<=0; a_r<=0; b_r<=0;
        abort_pending_r<=0; busy<=0; done<=0; error<=0; error_code<=0;
        cycle_count<=0; read_accept_count<=0; write_accept_count<=0;
        request_stall_count<=0; response_wait_count<=0;
      end else begin
        done<=0;
        if(busy) cycle_count<=cycle_count+1'b1;
        if((state_r==READ_A_REQ || state_r==READ_B_REQ || state_r==WRITEBACK) &&
           spad_valid && !spad_ready) request_stall_count<=request_stall_count+1'b1;
        if((state_r==READ_A_WAIT || state_r==READ_B_WAIT) && !spad_rsp_valid)
          response_wait_count<=response_wait_count+1'b1;
        if(state_r==IDLE && start) begin
          busy<=1; error<=0; error_code<=0; index_r<=0; cycle_count<=0;
          read_accept_count<=0; write_accept_count<=0;
          request_stall_count<=0; response_wait_count<=0;
          abort_pending_r<=0; op_r<=op_mode; shift_r<=shift; length_r<=length;
          src0_r<=src0_base; src1_r<=src1_base; dst_r<=dst_base;
          if(length==0 || length>MAX_LEN || (op_mode!=OP_RESIDUAL && op_mode!=OP_REQUANT) ||
             (|src0_base[1:0]) || (|dst_base[1:0]) ||
             (op_mode==OP_RESIDUAL && (|src1_base[1:0]))) begin
            error<=1; error_code<=ERR_CONFIG; state_r<=COMPLETE;
          end else state_r<=READ_A_REQ;
        end else if(state_r!=IDLE && state_r!=COMPLETE && (abort || epoch_bump)) begin
          if(state_r==READ_A_WAIT || state_r==READ_B_WAIT) abort_pending_r<=1;
          else begin
            // A write accepted on the abort edge is part of the committed
            // prefix; the memory handshake cannot be revoked after the edge.
            if(state_r==WRITEBACK && spad_valid && spad_ready && !spad_protection_error)
              write_accept_count<=write_accept_count+1'b1;
            error<=1; error_code<=ERR_ABORT; state_r<=COMPLETE;
          end
        end else case(state_r)
          READ_A_REQ: if(spad_ready) begin
            read_accept_count<=read_accept_count+1'b1;
            if(spad_protection_error) begin error<=1; error_code<=ERR_PROTECTION; state_r<=COMPLETE; end
            else state_r<=READ_A_WAIT;
          end
          READ_A_WAIT: if(spad_rsp_valid) begin
            if(abort_pending_r) begin error<=1; error_code<=ERR_ABORT; state_r<=COMPLETE; end
            else if(spad_parity_error) begin error<=1; error_code<=ERR_PARITY; state_r<=COMPLETE; end
            else begin a_r<=spad_rdata; state_r<=(op_r==OP_RESIDUAL)?READ_B_REQ:STREAM_IN; end
          end
          READ_B_REQ: if(spad_ready) begin
            read_accept_count<=read_accept_count+1'b1;
            if(spad_protection_error) begin error<=1; error_code<=ERR_PROTECTION; state_r<=COMPLETE; end
            else state_r<=READ_B_WAIT;
          end
          READ_B_WAIT: if(spad_rsp_valid) begin
            if(abort_pending_r) begin error<=1; error_code<=ERR_ABORT; state_r<=COMPLETE; end
            else if(spad_parity_error) begin error<=1; error_code<=ERR_PARITY; state_r<=COMPLETE; end
            else begin b_r<=spad_rdata; state_r<=STREAM_IN; end
          end
          STREAM_IN: if(in_ready) state_r<=STREAM_OUT;
          STREAM_OUT: if(out_valid && out_ready) begin
            if(out_error) begin error<=1; error_code<=ERR_CONFIG; state_r<=COMPLETE; end
            else begin
              output_buffer[index_r]<=out_data;
              if(index_r==length_r-1'b1) begin index_r<=0; state_r<=WRITEBACK; end
              else begin index_r<=index_r+1'b1; state_r<=READ_A_REQ; end
            end
          end
          WRITEBACK: if(spad_ready) begin
            if(spad_protection_error) begin error<=1; error_code<=ERR_PROTECTION; state_r<=COMPLETE; end
            else begin
              write_accept_count<=write_accept_count+1'b1;
              if(index_r==length_r-1'b1) state_r<=COMPLETE;
              else index_r<=index_r+1'b1;
            end
          end
          COMPLETE: begin done<=1; busy<=0; state_r<=IDLE; end
          default: state_r<=IDLE;
        endcase
      end
    end

`ifndef SYNTHESIS
    property p_spad_request_stable_until_accept;
      @(posedge clk) disable iff(!resetn || abort || epoch_bump)
      spad_valid && !spad_ready |=> spad_valid &&
        $stable({spad_write,spad_addr,spad_wdata});
    endproperty
    assert property(p_spad_request_stable_until_accept);
`endif
endmodule
