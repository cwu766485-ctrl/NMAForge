`timescale 1ns/1ps

// Bound structural and protocol checks for ai_async_fifo.
//
// The FIFO deliberately uses Gray-coded source pointers and two local
// synchronizer stages. These assertions make the assumptions behind the
// standard full/empty decode executable in every CDC block test that binds
// this module. They are verification-only and do not alter FIFO timing.
module ai_async_fifo_sva #(
    parameter integer PTR_WIDTH = 5
)(
    input wire                 wr_clk,
    input wire                 wr_resetn,
    input wire                 wr_fire,
    input wire                 wr_ready,
    input wire                 wr_full,
    input wire [PTR_WIDTH-1:0] wr_ptr_bin,
    input wire [PTR_WIDTH-1:0] wr_ptr_gray,
    input wire [PTR_WIDTH-1:0] rd_gray_wr1,
    input wire [PTR_WIDTH-1:0] rd_gray_wr2,
    input wire                 rd_clk,
    input wire                 rd_resetn,
    input wire                 rd_fire,
    input wire                 rd_valid,
    input wire                 rd_empty,
    input wire [PTR_WIDTH-1:0] rd_ptr_bin,
    input wire [PTR_WIDTH-1:0] rd_ptr_gray,
    input wire [PTR_WIDTH-1:0] wr_gray_rd1,
    input wire [PTR_WIDTH-1:0] wr_gray_rd2
);
    wire [PTR_WIDTH-1:0] wr_full_compare = {
        ~rd_gray_wr2[PTR_WIDTH-1:PTR_WIDTH-2],
        rd_gray_wr2[PTR_WIDTH-3:0]
    };

    function automatic [PTR_WIDTH-1:0] bin_to_gray(
        input [PTR_WIDTH-1:0] binary_value
    );
        bin_to_gray = (binary_value >> 1) ^ binary_value;
    endfunction

    // A source pointer may advance only when its local ready/valid handshake
    // fires. Gray encoding then permits at most one pointer bit to change.
    property p_wr_pointer_holds_without_fire;
        @(posedge wr_clk) disable iff (!wr_resetn)
            !wr_fire |=> $stable(wr_ptr_bin) && $stable(wr_ptr_gray);
    endproperty
    a_wr_pointer_holds_without_fire: assert property (p_wr_pointer_holds_without_fire)
        else $error("CDC FIFO SVA: write pointer changed without wr_fire");

    property p_wr_gray_matches_binary;
        @(posedge wr_clk) disable iff (!wr_resetn)
            wr_ptr_gray == bin_to_gray(wr_ptr_bin);
    endproperty
    a_wr_gray_matches_binary: assert property (p_wr_gray_matches_binary)
        else $error("CDC FIFO SVA: write Gray pointer does not encode write binary pointer");

    property p_wr_gray_changes_one_bit_per_fire;
        @(posedge wr_clk) disable iff (!wr_resetn)
            wr_fire |=> $onehot(wr_ptr_gray ^ $past(wr_ptr_gray));
    endproperty
    a_wr_gray_changes_one_bit_per_fire: assert property (p_wr_gray_changes_one_bit_per_fire)
        else $error("CDC FIFO SVA: write Gray pointer changed by other than one bit");

    property p_rd_pointer_holds_without_fire;
        @(posedge rd_clk) disable iff (!rd_resetn)
            !rd_fire |=> $stable(rd_ptr_bin) && $stable(rd_ptr_gray);
    endproperty
    a_rd_pointer_holds_without_fire: assert property (p_rd_pointer_holds_without_fire)
        else $error("CDC FIFO SVA: read pointer changed without rd_fire");

    property p_rd_gray_matches_binary;
        @(posedge rd_clk) disable iff (!rd_resetn)
            rd_ptr_gray == bin_to_gray(rd_ptr_bin);
    endproperty
    a_rd_gray_matches_binary: assert property (p_rd_gray_matches_binary)
        else $error("CDC FIFO SVA: read Gray pointer does not encode read binary pointer");

    property p_rd_gray_changes_one_bit_per_fire;
        @(posedge rd_clk) disable iff (!rd_resetn)
            rd_fire |=> $onehot(rd_ptr_gray ^ $past(rd_ptr_gray));
    endproperty
    a_rd_gray_changes_one_bit_per_fire: assert property (p_rd_gray_changes_one_bit_per_fire)
        else $error("CDC FIFO SVA: read Gray pointer changed by other than one bit");

    // Full and empty decisions must use only the second local synchronizer
    // stage. This is the intended disposition for SpyGlass Ac_conv02.
    property p_wr_full_uses_second_sync_stage;
        @(posedge wr_clk) disable iff (!wr_resetn)
            (wr_full == (wr_ptr_gray == wr_full_compare)) &&
            (wr_ready == !wr_full);
    endproperty
    a_wr_full_uses_second_sync_stage: assert property (p_wr_full_uses_second_sync_stage)
        else $error("CDC FIFO SVA: write full/ready decode is inconsistent");

    property p_rd_empty_uses_second_sync_stage;
        @(posedge rd_clk) disable iff (!rd_resetn)
            (rd_empty == (rd_ptr_gray == wr_gray_rd2)) &&
            (rd_valid == !rd_empty);
    endproperty
    a_rd_empty_uses_second_sync_stage: assert property (p_rd_empty_uses_second_sync_stage)
        else $error("CDC FIFO SVA: read empty/valid decode is inconsistent");

    // The second stage is driven only by the prior sampled first stage. Do
    // not compare a synchronizer directly with its asynchronous source.
    property p_wr_sync_has_two_stages;
        @(posedge wr_clk) disable iff (!wr_resetn)
            rd_gray_wr2 == $past(rd_gray_wr1);
    endproperty
    a_wr_sync_has_two_stages: assert property (p_wr_sync_has_two_stages)
        else $error("CDC FIFO SVA: read pointer synchronizer stage order is broken");

    property p_rd_sync_has_two_stages;
        @(posedge rd_clk) disable iff (!rd_resetn)
            wr_gray_rd2 == $past(wr_gray_rd1);
    endproperty
    a_rd_sync_has_two_stages: assert property (p_rd_sync_has_two_stages)
        else $error("CDC FIFO SVA: write pointer synchronizer stage order is broken");

    // Both pointer and synchronizer state are locally initialized by the
    // documented asynchronous-assert reset contract (Reset_sync04).
    property p_wr_reset_clears_local_cdc_state;
        @(posedge wr_clk)
            !wr_resetn |-> ((wr_ptr_bin == '0) && (wr_ptr_gray == '0) &&
                            (rd_gray_wr1 == '0) && (rd_gray_wr2 == '0));
    endproperty
    a_wr_reset_clears_local_cdc_state: assert property (p_wr_reset_clears_local_cdc_state)
        else $error("CDC FIFO SVA: write-side reset did not clear local CDC state");

    property p_rd_reset_clears_local_cdc_state;
        @(posedge rd_clk)
            !rd_resetn |-> ((rd_ptr_bin == '0) && (rd_ptr_gray == '0) &&
                            (wr_gray_rd1 == '0) && (wr_gray_rd2 == '0));
    endproperty
    a_rd_reset_clears_local_cdc_state: assert property (p_rd_reset_clears_local_cdc_state)
        else $error("CDC FIFO SVA: read-side reset did not clear local CDC state");
endmodule

// Bind by internal register name so the SVA proves the implementation, rather
// than merely re-checking an equivalent set of public outputs in a testbench.
bind ai_async_fifo ai_async_fifo_sva #(
    .PTR_WIDTH(ADDR_WIDTH + 1)
) ai_async_fifo_sva_i (
    .wr_clk(wr_clk),
    .wr_resetn(wr_resetn),
    .wr_fire(wr_fire),
    .wr_ready(wr_ready),
    .wr_full(wr_full),
    .wr_ptr_bin(wr_ptr_bin),
    .wr_ptr_gray(wr_ptr_gray),
    .rd_gray_wr1(rd_gray_wr1),
    .rd_gray_wr2(rd_gray_wr2),
    .rd_clk(rd_clk),
    .rd_resetn(rd_resetn),
    .rd_fire(rd_fire),
    .rd_valid(rd_valid),
    .rd_empty(rd_empty),
    .rd_ptr_bin(rd_ptr_bin),
    .rd_ptr_gray(rd_ptr_gray),
    .wr_gray_rd1(wr_gray_rd1),
    .wr_gray_rd2(wr_gray_rd2)
);
