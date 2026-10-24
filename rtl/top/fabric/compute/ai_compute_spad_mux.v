`timescale 1ns / 1ps

// Round-robin admission for the compute engines that share the single-word
// scheduler SPAD port.  Requests still enter ai_spad_arbiter as one CORE
// client; this small mux preserves the sub-engine owner for ready, protection
// errors, and the registered response.
module ai_compute_spad_mux(
    input  wire         clk,
    input  wire         resetn,
    input  wire [6:0]   req_valid,
    input  wire [6:0]   req_write,
    input  wire [223:0] req_addr,
    input  wire [223:0] req_wdata,
    output reg  [6:0]   req_ready,
    output reg          spad_valid,
    output reg          spad_write,
    output reg  [31:0]  spad_addr,
    output reg  [31:0]  spad_wdata,
    input  wire         spad_ready,
    input  wire         spad_protection_error,
    output reg  [6:0]   req_protection_error,
    input  wire         rsp_valid,
    input  wire [31:0]  rsp_rdata,
    input  wire         rsp_error,
    input  wire         rsp_parity_error,
    output reg  [6:0]   engine_rsp_valid,
    output reg  [223:0] engine_rsp_rdata,
    output reg  [6:0]   engine_rsp_error
);
    reg [2:0] rr_owner_r;
    reg       held_owner_valid_r;
    reg [2:0] held_owner_r;
    reg [2:0] response_owner_d_r;
    reg [2:0] response_owner_r;
    reg       response_owner_valid_d_r;
    reg       response_owner_valid_r;
    reg [2:0] selected_owner;
    reg       selected_valid;
    integer offset;
    integer candidate;

    always @(*) begin
        selected_owner = rr_owner_r;
        selected_valid = 1'b0;
        if (held_owner_valid_r) begin
            selected_owner = held_owner_r;
            selected_valid = req_valid[held_owner_r];
        end else begin
            for (offset = 0; offset < 7; offset = offset + 1) begin
                candidate = rr_owner_r + offset;
                if (candidate >= 7)
                    candidate = candidate - 7;
                if (!selected_valid && req_valid[candidate]) begin
                    selected_owner = candidate[2:0];
                    selected_valid = 1'b1;
                end
            end
        end

        spad_valid = selected_valid;
        spad_write = 1'b0;
        spad_addr = 32'd0;
        spad_wdata = 32'd0;
        req_ready = 7'd0;
        req_protection_error = 7'd0;
        if (selected_valid) begin
            spad_write = req_write[selected_owner];
            spad_addr = req_addr[selected_owner*32 +: 32];
            spad_wdata = req_wdata[selected_owner*32 +: 32];
            req_ready[selected_owner] = spad_ready;
            req_protection_error[selected_owner] = spad_protection_error;
        end

        engine_rsp_valid = 7'd0;
        engine_rsp_rdata = 224'd0;
        engine_rsp_error = 7'd0;
        if (rsp_valid && response_owner_valid_r) begin
            engine_rsp_valid[response_owner_r] = 1'b1;
            engine_rsp_rdata[response_owner_r*32 +: 32] = rsp_rdata;
            engine_rsp_error[response_owner_r] = rsp_error || rsp_parity_error;
        end
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            rr_owner_r <= 3'd0;
            held_owner_valid_r <= 1'b0;
            held_owner_r <= 3'd0;
            response_owner_d_r <= 3'd0;
            response_owner_r <= 3'd0;
            response_owner_valid_d_r <= 1'b0;
            response_owner_valid_r <= 1'b0;
        end else begin
            if (selected_valid && !spad_ready) begin
                held_owner_valid_r <= 1'b1;
                held_owner_r <= selected_owner;
            end else if (selected_valid && spad_ready) begin
                held_owner_valid_r <= 1'b0;
                rr_owner_r <= (selected_owner == 3'd6) ? 3'd0 : selected_owner + 3'd1;
            end

            response_owner_valid_r <= response_owner_valid_d_r;
            response_owner_valid_d_r <= selected_valid && spad_ready && !spad_write;
            response_owner_r <= response_owner_d_r;
            if (selected_valid && spad_ready && !spad_write)
                response_owner_d_r <= selected_owner;
        end
    end
endmodule
