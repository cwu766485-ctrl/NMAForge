// Scratchpad storage/protection structural wrapper.  Arbitration remains
// exclusively owned by ai_spad_arbiter outside this module.
module ai_accel_spad_subsystem #(
    parameter integer BANKS = 4,
    parameter integer WORDS_PER_BANK = 32768,
    parameter integer ROW_BITS = $clog2(WORDS_PER_BANK),
    parameter integer SPAD_BYTES = BANKS * WORDS_PER_BANK * 4
)(
    input  wire         clk,
    input  wire         resetn,

    input  wire [31:0]  region0_base,
    input  wire [31:0]  region0_limit,
    input  wire [3:0]   region0_perm,
    input  wire [31:0]  region1_base,
    input  wire [31:0]  region1_limit,
    input  wire [3:0]   region1_perm,
    input  wire [31:0]  region2_base,
    input  wire [31:0]  region2_limit,
    input  wire [3:0]   region2_perm,
    input  wire [31:0]  region3_base,
    input  wire [31:0]  region3_limit,
    input  wire [3:0]   region3_perm,

    input  wire         host_valid,
    input  wire         host_write,
    input  wire [31:0]  host_addr,
    input  wire [31:0]  host_wdata,
    input  wire [3:0]   host_wstrb,

    input  wire         compute_valid,
    input  wire         compute_write,
    input  wire [31:0]  compute_addr,
    input  wire [31:0]  compute_wdata,
    input  wire         compute_req_execute,

    input  wire         line_valid,
    input  wire         line_write,
    input  wire [31:0]  line_addr,
    input  wire [127:0] line_wdata,
    input  wire [15:0]  line_wstrb,
    input  wire         line_req_execute,

    input  wire         banked_valid,
    input  wire [31:0]  banked_addr,

    input  wire [3:0]   cnm_valid,
    input  wire [31:0]  cnm_addr0,
    input  wire [31:0]  cnm_addr1,
    input  wire [31:0]  cnm_addr2,
    input  wire [31:0]  cnm_addr3,

    input  wire [31:0]  cpl_base,
    input  wire [31:0]  cpl_index,

    output wire [31:0]  host_rdata,
    output wire         host_error,
    output wire         host_parity_error,
    output wire [31:0]  compute_rdata,
    output wire         compute_parity_error,
    output wire [127:0] line_rdata,
    output wire [3:0]   line_parity_error,
    output wire         line_raw_error,
    output wire [31:0]  banked_data0,
    output wire [31:0]  banked_data1,
    output wire [31:0]  banked_data2,
    output wire [31:0]  banked_data3,
    output wire [3:0]   banked_parity_error,
    output wire [31:0]  cnm_data0,
    output wire [31:0]  cnm_data1,
    output wire [31:0]  cnm_data2,
    output wire [31:0]  cnm_data3,
    output wire [3:0]   cnm_parity_error,
    output wire         cnm_protection_error,
    output wire         host_prot_allow,
    output wire         compute_prot_allow,
    output wire         line_prot_allow,
    output wire         banked_prot_allow,
    output wire         cpl_prot_allow
);

    wire [3:0] cnm_lane_prot_allow;
    wire [3:0] cnm_lane_access_allow;
    wire banked_access_allow;
    reg cnm_protection_error_r;

    ai_spad_protection cnm_protection0_u (
        .region0_base(region0_base), .region0_limit(region0_limit), .region0_perm(region0_perm),
        .region1_base(region1_base), .region1_limit(region1_limit), .region1_perm(region1_perm),
        .region2_base(region2_base), .region2_limit(region2_limit), .region2_perm(region2_perm),
        .region3_base(region3_base), .region3_limit(region3_limit), .region3_perm(region3_perm),
        .req_valid(cnm_valid[0]), .req_addr(cnm_addr0), .req_bytes(32'd4),
        .req_write(1'b0), .req_execute(1'b1), .allow(cnm_lane_prot_allow[0])
    );
    ai_spad_protection cnm_protection1_u (
        .region0_base(region0_base), .region0_limit(region0_limit), .region0_perm(region0_perm),
        .region1_base(region1_base), .region1_limit(region1_limit), .region1_perm(region1_perm),
        .region2_base(region2_base), .region2_limit(region2_limit), .region2_perm(region2_perm),
        .region3_base(region3_base), .region3_limit(region3_limit), .region3_perm(region3_perm),
        .req_valid(cnm_valid[1]), .req_addr(cnm_addr1), .req_bytes(32'd4),
        .req_write(1'b0), .req_execute(1'b1), .allow(cnm_lane_prot_allow[1])
    );
    ai_spad_protection cnm_protection2_u (
        .region0_base(region0_base), .region0_limit(region0_limit), .region0_perm(region0_perm),
        .region1_base(region1_base), .region1_limit(region1_limit), .region1_perm(region1_perm),
        .region2_base(region2_base), .region2_limit(region2_limit), .region2_perm(region2_perm),
        .region3_base(region3_base), .region3_limit(region3_limit), .region3_perm(region3_perm),
        .req_valid(cnm_valid[2]), .req_addr(cnm_addr2), .req_bytes(32'd4),
        .req_write(1'b0), .req_execute(1'b1), .allow(cnm_lane_prot_allow[2])
    );
    ai_spad_protection cnm_protection3_u (
        .region0_base(region0_base), .region0_limit(region0_limit), .region0_perm(region0_perm),
        .region1_base(region1_base), .region1_limit(region1_limit), .region1_perm(region1_perm),
        .region2_base(region2_base), .region2_limit(region2_limit), .region2_perm(region2_perm),
        .region3_base(region3_base), .region3_limit(region3_limit), .region3_perm(region3_perm),
        .req_valid(cnm_valid[3]), .req_addr(cnm_addr3), .req_bytes(32'd4),
        .req_write(1'b0), .req_execute(1'b1), .allow(cnm_lane_prot_allow[3])
    );

    assign cnm_lane_access_allow[0] = cnm_lane_prot_allow[0] &&
                                      !(|cnm_addr0[1:0]) &&
                                      (cnm_addr0 <= SPAD_BYTES - 32'd4);
    assign cnm_lane_access_allow[1] = cnm_lane_prot_allow[1] &&
                                      !(|cnm_addr1[1:0]) &&
                                      (cnm_addr1 <= SPAD_BYTES - 32'd4);
    assign cnm_lane_access_allow[2] = cnm_lane_prot_allow[2] &&
                                      !(|cnm_addr2[1:0]) &&
                                      (cnm_addr2 <= SPAD_BYTES - 32'd4);
    assign cnm_lane_access_allow[3] = cnm_lane_prot_allow[3] &&
                                      !(|cnm_addr3[1:0]) &&
                                      (cnm_addr3 <= SPAD_BYTES - 32'd4);

    assign banked_access_allow = banked_prot_allow && !(|banked_addr[3:0]) &&
                                 (banked_addr <= SPAD_BYTES - 32'd16);

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            cnm_protection_error_r <= 1'b0;
        end else begin
            cnm_protection_error_r <= |(cnm_valid & ~cnm_lane_access_allow);
        end
    end
    assign cnm_protection_error = cnm_protection_error_r;

    ai_spad_protection host_protection_u (
        .region0_base(region0_base), .region0_limit(region0_limit), .region0_perm(region0_perm),
        .region1_base(region1_base), .region1_limit(region1_limit), .region1_perm(region1_perm),
        .region2_base(region2_base), .region2_limit(region2_limit), .region2_perm(region2_perm),
        .region3_base(region3_base), .region3_limit(region3_limit), .region3_perm(region3_perm),
        .req_valid(host_valid), .req_addr(host_addr), .req_bytes(32'd4),
        .req_write(host_write), .req_execute(1'b0), .allow(host_prot_allow)
    );

    ai_spad_protection compute_protection_u (
        .region0_base(region0_base), .region0_limit(region0_limit), .region0_perm(region0_perm),
        .region1_base(region1_base), .region1_limit(region1_limit), .region1_perm(region1_perm),
        .region2_base(region2_base), .region2_limit(region2_limit), .region2_perm(region2_perm),
        .region3_base(region3_base), .region3_limit(region3_limit), .region3_perm(region3_perm),
        .req_valid(compute_valid), .req_addr(compute_addr), .req_bytes(32'd4),
        .req_write(compute_write), .req_execute(compute_req_execute), .allow(compute_prot_allow)
    );

    ai_spad_protection line_protection_u (
        .region0_base(region0_base), .region0_limit(region0_limit), .region0_perm(region0_perm),
        .region1_base(region1_base), .region1_limit(region1_limit), .region1_perm(region1_perm),
        .region2_base(region2_base), .region2_limit(region2_limit), .region2_perm(region2_perm),
        .region3_base(region3_base), .region3_limit(region3_limit), .region3_perm(region3_perm),
        .req_valid(line_valid), .req_addr(line_addr), .req_bytes(32'd16),
        .req_write(line_write), .req_execute(line_req_execute), .allow(line_prot_allow)
    );

    ai_spad_protection banked_protection_u (
        .region0_base(region0_base), .region0_limit(region0_limit), .region0_perm(region0_perm),
        .region1_base(region1_base), .region1_limit(region1_limit), .region1_perm(region1_perm),
        .region2_base(region2_base), .region2_limit(region2_limit), .region2_perm(region2_perm),
        .region3_base(region3_base), .region3_limit(region3_limit), .region3_perm(region3_perm),
        .req_valid(banked_valid), .req_addr(banked_addr), .req_bytes(32'd16),
        .req_write(1'b0), .req_execute(1'b1), .allow(banked_prot_allow)
    );

    ai_spad_protection completion_protection_u (
        .region0_base(region0_base), .region0_limit(region0_limit), .region0_perm(region0_perm),
        .region1_base(region1_base), .region1_limit(region1_limit), .region1_perm(region1_perm),
        .region2_base(region2_base), .region2_limit(region2_limit), .region2_perm(region2_perm),
        .region3_base(region3_base), .region3_limit(region3_limit), .region3_perm(region3_perm),
        .req_valid(1'b1), .req_addr(cpl_base + (cpl_index << 4)), .req_bytes(32'd16),
        .req_write(1'b1), .req_execute(1'b0), .allow(cpl_prot_allow)
    );

    ai_scratchpad #(
        .BANKS          (BANKS),
        .WORDS_PER_BANK (WORDS_PER_BANK),
        .ROW_BITS       (ROW_BITS)
    ) scratchpad_u (
        .clk                  (clk),
        .resetn               (resetn),
        .host_valid           (host_valid && host_prot_allow),
        .host_write           (host_write),
        .host_addr            (host_addr),
        .host_wdata           (host_wdata),
        .host_wstrb           (host_wstrb),
        .host_rdata           (host_rdata),
        .host_error           (host_error),
        .host_parity_error    (host_parity_error),
        .compute_valid        (compute_valid && compute_prot_allow),
        .compute_write        (compute_write),
        .compute_addr         (compute_addr),
        .compute_wdata        (compute_wdata),
        .compute_rdata        (compute_rdata),
        .compute_parity_error (compute_parity_error),
        .line_valid           (line_valid && line_prot_allow),
        .line_write           (line_write),
        .line_addr            (line_addr),
        .line_wdata           (line_wdata),
        .line_wstrb           (line_wstrb),
        .line_rdata           (line_rdata),
        .line_parity_error    (line_parity_error),
        .line_error           (line_raw_error),
        .banked_read_valid    (banked_valid && banked_access_allow),
        .banked_addr          (banked_addr),
        .banked_data0         (banked_data0),
        .banked_data1         (banked_data1),
        .banked_data2         (banked_data2),
        .banked_data3         (banked_data3),
        .banked_parity_error  (banked_parity_error),
        // The arbiter still accepts and tags the complete lane mask. Denied
        // lanes are suppressed at the SRAM boundary and are reported with
        // the registered Protection error above.
        .cnm_read_valid       (cnm_valid & cnm_lane_access_allow),
        .cnm_addr0            (cnm_addr0),
        .cnm_addr1            (cnm_addr1),
        .cnm_addr2            (cnm_addr2),
        .cnm_addr3            (cnm_addr3),
        .cnm_data0            (cnm_data0),
        .cnm_data1            (cnm_data1),
        .cnm_data2            (cnm_data2),
        .cnm_data3            (cnm_data3),
        .cnm_parity_error     (cnm_parity_error)
    );

endmodule
