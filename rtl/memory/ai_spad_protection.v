`timescale 1ns / 1ps

// ---------------------------------------------------------------------------
// Scratchpad region permission checker.
//
// Region limits are exclusive byte addresses.  PERM bits are:
//   bit0 read, bit1 write, bit2 execute, bit3 enable.
// Disabled regions do not participate.  If all regions are disabled, the
// checker intentionally permits every request for backwards compatibility.
// A request must fit completely inside one enabled region; permissions may not
// be assembled from two adjacent regions.
// ---------------------------------------------------------------------------
module ai_spad_protection(
    input  wire [31:0] region0_base,
    input  wire [31:0] region0_limit,
    input  wire [3:0]  region0_perm,
    input  wire [31:0] region1_base,
    input  wire [31:0] region1_limit,
    input  wire [3:0]  region1_perm,
    input  wire [31:0] region2_base,
    input  wire [31:0] region2_limit,
    input  wire [3:0]  region2_perm,
    input  wire [31:0] region3_base,
    input  wire [31:0] region3_limit,
    input  wire [3:0]  region3_perm,
    input  wire        req_valid,
    input  wire [31:0] req_addr,
    input  wire [31:0] req_bytes,
    input  wire        req_write,
    input  wire        req_execute,
    output reg         allow
);

    wire any_enabled;
    wire [32:0] req_end;
    wire r0_match;
    wire r1_match;
    wire r2_match;
    wire r3_match;

    assign any_enabled = region0_perm[3] || region1_perm[3] ||
                         region2_perm[3] || region3_perm[3];
    assign req_end = {1'b0, req_addr} + {1'b0, req_bytes};

    function region_allows;
        input [31:0] base;
        input [31:0] limit;
        input [3:0] perm;
        input write_req;
        input exec_req;
        begin
            region_allows = perm[3] &&
                            (write_req ? perm[1] : perm[0]) &&
                            (!exec_req || perm[2]);
        end
    endfunction

    assign r0_match = region_allows(region0_base, region0_limit, region0_perm,
                                    req_write, req_execute) &&
                      (req_addr >= region0_base) && (req_end <= {1'b0, region0_limit});
    assign r1_match = region_allows(region1_base, region1_limit, region1_perm,
                                    req_write, req_execute) &&
                      (req_addr >= region1_base) && (req_end <= {1'b0, region1_limit});
    assign r2_match = region_allows(region2_base, region2_limit, region2_perm,
                                    req_write, req_execute) &&
                      (req_addr >= region2_base) && (req_end <= {1'b0, region2_limit});
    assign r3_match = region_allows(region3_base, region3_limit, region3_perm,
                                    req_write, req_execute) &&
                      (req_addr >= region3_base) && (req_end <= {1'b0, region3_limit});

    always @(*) begin
        if (!req_valid || !any_enabled)
            allow = 1'b1;
        else if (req_bytes == 32'd0)
            allow = 1'b0;
        else
            allow = r0_match || r1_match || r2_match || r3_match;
    end

endmodule
