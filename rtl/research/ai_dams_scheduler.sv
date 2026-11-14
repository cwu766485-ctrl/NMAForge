`timescale 1ns/1ps

// Isolated research prototype: bounded dependency and bank reservation tracker.
// Accepted work reserves its bank mask until matching done_tag or epoch flush.
module ai_dams_scheduler #(
    parameter integer ENGINES = 4,
    parameter integer DEPTH = 8,
    parameter integer TAG_W = 8
) (
    input  logic clk, input logic resetn,
    input  logic epoch_bump, input logic fault_abort,
    input  logic issue_valid, output logic issue_ready,
    input  logic [$clog2(ENGINES)-1:0] issue_engine,
    input  logic [TAG_W-1:0] issue_tag,
    input  logic [ENGINES-1:0] issue_dep_mask,
    input  logic [3:0] issue_bank_mask,
    input  logic issue_atomic,
    output logic grant_valid, input logic grant_ready,
    output logic [$clog2(ENGINES)-1:0] grant_engine,
    output logic [TAG_W-1:0] grant_tag,
    output logic [3:0] grant_bank_mask, output logic grant_atomic,
    input logic done_valid, input logic [TAG_W-1:0] done_tag,
    output logic busy, output logic [ENGINES-1:0] done_mask,
    output logic [31:0] accepted_count, output logic [31:0] denied_count,
    output logic [31:0] epoch
);
    localparam integer EW = (ENGINES <= 1) ? 1 : $clog2(ENGINES);
    logic [DEPTH-1:0] valid_r, dispatched_r, atomic_r;
    logic [TAG_W-1:0] tag_r [0:DEPTH-1];
    logic [EW-1:0] engine_r [0:DEPTH-1];
    logic [3:0] bank_r [0:DEPTH-1];
    logic [ENGINES-1:0] complete_r;
    logic [3:0] reserved_banks;
    logic dep_ok, bank_ok;
    integer free_idx, out_idx, i;

    always_comb begin
        reserved_banks = 4'b0;
        free_idx = -1;
        out_idx = -1;
        for (i = 0; i < DEPTH; i = i + 1) begin
            if (valid_r[i]) reserved_banks |= bank_r[i];
            else if (free_idx < 0) free_idx = i;
            if (valid_r[i] && !dispatched_r[i] && out_idx < 0) out_idx = i;
        end
        dep_ok = ((issue_dep_mask & ~complete_r) == '0);
        bank_ok = ((issue_bank_mask & reserved_banks) == 4'b0);
        issue_ready = (free_idx >= 0) && dep_ok && bank_ok &&
                      ((!issue_atomic) || (issue_bank_mask != 4'b0));
        grant_valid = out_idx >= 0;
        grant_engine = grant_valid ? engine_r[out_idx] : '0;
        grant_tag = grant_valid ? tag_r[out_idx] : '0;
        grant_bank_mask = grant_valid ? bank_r[out_idx] : '0;
        grant_atomic = grant_valid ? atomic_r[out_idx] : 1'b0;
        busy = |valid_r;
        done_mask = complete_r;
    end

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            valid_r <= '0; dispatched_r <= '0; atomic_r <= '0;
            complete_r <= '0; epoch <= '0;
            accepted_count <= '0; denied_count <= '0;
            for (integer j = 0; j < DEPTH; j = j + 1) begin
                tag_r[j] <= '0; engine_r[j] <= '0; bank_r[j] <= '0;
            end
        end else if (epoch_bump || fault_abort) begin
            valid_r <= '0; dispatched_r <= '0; atomic_r <= '0;
            complete_r <= '0; epoch <= epoch + 1'b1;
        end else begin
            if (issue_valid && !issue_ready) denied_count <= denied_count + 1'b1;
            if (issue_valid && issue_ready) begin
                valid_r[free_idx] <= 1'b1;
                dispatched_r[free_idx] <= 1'b0;
                tag_r[free_idx] <= issue_tag;
                engine_r[free_idx] <= issue_engine;
                bank_r[free_idx] <= issue_bank_mask;
                atomic_r[free_idx] <= issue_atomic;
                complete_r[issue_engine] <= 1'b0;
                accepted_count <= accepted_count + 1'b1;
            end
            if (grant_valid && grant_ready) dispatched_r[out_idx] <= 1'b1;
            if (done_valid) begin
                for (integer j = 0; j < DEPTH; j = j + 1)
                    if (valid_r[j] && tag_r[j] == done_tag) begin
                        valid_r[j] <= 1'b0;
                        dispatched_r[j] <= 1'b0;
                        complete_r[engine_r[j]] <= 1'b1;
                    end
            end
        end
    end

`ifndef SYNTHESIS
    property p_grant_stable_until_ready;
        @(posedge clk) disable iff (!resetn || epoch_bump || fault_abort)
        grant_valid && !grant_ready |=> grant_valid && $stable({grant_engine,grant_tag,grant_bank_mask,grant_atomic});
    endproperty
    assert property (p_grant_stable_until_ready);
`endif
endmodule
