`timescale 1ns / 1ps

module tb_ai_spad_protection;
    reg  [31:0] region_base [0:3];
    reg  [31:0] region_limit [0:3];
    reg  [3:0]  region_perm [0:3];
    reg         req_valid;
    reg  [31:0] req_addr;
    reg  [31:0] req_bytes;
    reg         req_write;
    reg         req_execute;
    wire        allow;

    reg  [31:0] rng;
    reg  [31:0] seed_value;
    integer directed_checks;
    integer random_checks;
    integer allow_checks;
    integer deny_checks;
    integer i;
    integer region_index;
    integer trial;

    ai_spad_protection dut (
        .region0_base (region_base[0]), .region0_limit(region_limit[0]),
        .region0_perm (region_perm[0]),
        .region1_base (region_base[1]), .region1_limit(region_limit[1]),
        .region1_perm (region_perm[1]),
        .region2_base (region_base[2]), .region2_limit(region_limit[2]),
        .region2_perm (region_perm[2]),
        .region3_base (region_base[3]), .region3_limit(region_limit[3]),
        .region3_perm (region_perm[3]),
        .req_valid(req_valid), .req_addr(req_addr), .req_bytes(req_bytes),
        .req_write(req_write), .req_execute(req_execute), .allow(allow)
    );

    function automatic logic reference_allow;
        logic any_region_enabled;
        logic [32:0] request_end;
        integer region;
        begin
            any_region_enabled = region_perm[0][3] || region_perm[1][3] ||
                                 region_perm[2][3] || region_perm[3][3];
            request_end = {1'b0, req_addr} + {1'b0, req_bytes};
            reference_allow = 1'b0;

            if (!req_valid || !any_region_enabled) begin
                reference_allow = 1'b1;
            end else if (req_bytes == 32'd0) begin
                reference_allow = 1'b0;
            end else begin
                for (region = 0; region < 4; region = region + 1) begin
                    if (region_perm[region][3] &&
                        (req_write ? region_perm[region][1] : region_perm[region][0]) &&
                        (!req_execute || region_perm[region][2]) &&
                        (req_addr >= region_base[region]) &&
                        (request_end <= {1'b0, region_limit[region]}))
                        reference_allow = 1'b1;
                end
            end
        end
    endfunction

    function automatic [31:0] xorshift32(input [31:0] value);
        reg [31:0] next_value;
        begin
            next_value = value ^ (value << 13);
            next_value = next_value ^ (next_value >> 17);
            next_value = next_value ^ (next_value << 5);
            xorshift32 = next_value;
        end
    endfunction

    task automatic clear_regions;
        integer region;
        begin
            for (region = 0; region < 4; region = region + 1) begin
                region_base[region] = 32'd0;
                region_limit[region] = 32'd0;
                region_perm[region] = 4'd0;
            end
        end
    endtask

    task automatic set_region(
        input integer region,
        input [31:0] base,
        input [31:0] limit,
        input [3:0] permission
    );
        begin
            region_base[region] = base;
            region_limit[region] = limit;
            region_perm[region] = permission;
        end
    endtask

    task automatic check_result(
        input string label,
        input logic expected,
        input bit randomized
    );
        begin
            #1;
            if (allow !== expected)
                $fatal(1, "SPAD_PROTECTION_FAIL %s allow=%b expected=%b addr=%08h bytes=%0d valid/write/exec=%b/%b/%b",
                       label, allow, expected, req_addr, req_bytes,
                       req_valid, req_write, req_execute);
            if (randomized)
                random_checks = random_checks + 1;
            else
                directed_checks = directed_checks + 1;
            if (expected)
                allow_checks = allow_checks + 1;
            else
                deny_checks = deny_checks + 1;
        end
    endtask

    task automatic check_model(input string label);
        begin
            check_result(label, reference_allow(), 1'b1);
        end
    endtask

    initial begin
        req_valid = 1'b1;
        req_addr = 32'd0;
        req_bytes = 32'd4;
        req_write = 1'b0;
        req_execute = 1'b0;
        directed_checks = 0;
        random_checks = 0;
        allow_checks = 0;
        deny_checks = 0;
        seed_value = 32'hA10D_2026;
        if (!$value$plusargs("SEED=%d", seed_value))
            seed_value = 32'hA10D_2026;
        if (seed_value == 32'd0)
            seed_value = 32'h1;
        rng = seed_value;
        clear_regions();

        // No enabled region is the documented compatibility/open mode.
        req_valid = 1'b1;
        req_addr = 32'hffff_fff0;
        req_bytes = 32'd0;
        check_result("all-regions-disabled", 1'b1, 1'b0);

        // A non-request must not be rejected, even with an enabled region.
        set_region(0, 32'h0000_0100, 32'h0000_0110, 4'b1001);
        req_valid = 1'b0;
        req_bytes = 32'd0;
        check_result("request-invalid", 1'b1, 1'b0);

        // Enabled protection rejects empty accesses and permissionless access.
        req_valid = 1'b1;
        req_bytes = 32'd0;
        check_result("zero-byte-request", 1'b0, 1'b0);
        req_bytes = 32'd4;
        set_region(0, 32'h0000_0100, 32'h0000_0110, 4'b1000);
        check_result("enabled-without-operation-permission", 1'b0, 1'b0);

        // Exercise each region independently with a matching read request.
        for (i = 0; i < 4; i = i + 1) begin
            clear_regions();
            set_region(i, 32'h0000_0200, 32'h0000_0210, 4'b1001);
            req_valid = 1'b1;
            req_addr = 32'h0000_0200;
            req_bytes = 32'd4;
            req_write = 1'b0;
            req_execute = 1'b0;
            check_result($sformatf("region-%0d-match", i), 1'b1, 1'b0);
        end

        clear_regions();
        set_region(0, 32'h0000_0100, 32'h0000_0110, 4'b1001);
        req_addr = 32'h0000_0100;
        req_bytes = 32'd4;
        req_write = 1'b0;
        req_execute = 1'b0;
        check_result("read-permission", 1'b1, 1'b0);
        req_write = 1'b1;
        check_result("read-region-denies-write", 1'b0, 1'b0);
        set_region(0, 32'h0000_0100, 32'h0000_0110, 4'b1010);
        check_result("write-region-allows-write", 1'b1, 1'b0);
        req_write = 1'b0;
        check_result("write-region-denies-read", 1'b0, 1'b0);

        set_region(0, 32'h0000_0100, 32'h0000_0110, 4'b1101);
        req_write = 1'b0;
        req_execute = 1'b1;
        check_result("execute-permission", 1'b1, 1'b0);
        set_region(0, 32'h0000_0100, 32'h0000_0110, 4'b1001);
        check_result("execute-permission-denied", 1'b0, 1'b0);
        set_region(0, 32'h0000_0100, 32'h0000_0110, 4'b1110);
        req_write = 1'b1;
        check_result("write-and-execute-permission", 1'b1, 1'b0);

        // Lower bound is inclusive and upper bound is exclusive.
        set_region(0, 32'h0000_0100, 32'h0000_0110, 4'b1001);
        req_write = 1'b0;
        req_execute = 1'b0;
        req_addr = 32'h0000_00ff;
        req_bytes = 32'd1;
        check_result("below-lower-bound", 1'b0, 1'b0);
        req_addr = 32'h0000_0100;
        req_bytes = 32'd4;
        check_result("inclusive-lower-bound", 1'b1, 1'b0);
        req_addr = 32'h0000_010c;
        req_bytes = 32'd4;
        check_result("exclusive-limit-exact-end", 1'b1, 1'b0);
        req_addr = 32'h0000_0110;
        check_result("at-exclusive-limit", 1'b0, 1'b0);
        req_addr = 32'h0000_010c;
        req_bytes = 32'd8;
        check_result("crosses-exclusive-limit", 1'b0, 1'b0);

        // A request cannot be covered by stitching adjacent regions together.
        clear_regions();
        set_region(0, 32'h0000_0100, 32'h0000_0104, 4'b1001);
        set_region(1, 32'h0000_0104, 32'h0000_0108, 4'b1001);
        req_addr = 32'h0000_0100;
        req_bytes = 32'd8;
        check_result("adjacent-regions-do-not-combine", 1'b0, 1'b0);

        // Regions are ORed: one matching enabled region is sufficient.
        set_region(0, 32'h0000_0100, 32'h0000_0110, 4'b1010);
        set_region(1, 32'h0000_0100, 32'h0000_0110, 4'b1001);
        req_addr = 32'h0000_0100;
        req_bytes = 32'd4;
        req_write = 1'b0;
        req_execute = 1'b0;
        check_result("one-of-overlapping-regions-allows", 1'b1, 1'b0);

        // PERM[3] is required to enable a region even if other bits are set.
        set_region(0, 32'h0000_0100, 32'h0000_0110, 4'b0111);
        set_region(1, 32'h0000_0200, 32'h0000_0210, 4'b1001);
        req_addr = 32'h0000_0100;
        check_result("disabled-region-does-not-match", 1'b0, 1'b0);

        // 33-bit end-address arithmetic must reject wrapping out of 32-bit SPAD space.
        clear_regions();
        set_region(0, 32'h0000_0000, 32'hffff_ffff, 4'b1001);
        req_addr = 32'hffff_fff0;
        req_bytes = 32'd16;
        check_result("end-address-equals-2pow32", 1'b0, 1'b0);
        req_bytes = 32'd32;
        check_result("end-address-overflow", 1'b0, 1'b0);

        // Deterministic randomized differential checks near region boundaries
        // plus unconstrained addresses; the reference uses an independent model.
        for (trial = 0; trial < 512; trial = trial + 1) begin
            for (region_index = 0; region_index < 4; region_index = region_index + 1) begin
                rng = xorshift32(rng);
                region_base[region_index] = rng;
                rng = xorshift32(rng);
                region_limit[region_index] = region_base[region_index] + {26'd0, rng[5:0]} + 32'd1;
                region_perm[region_index] = rng[3:0];
            end

            rng = xorshift32(rng);
            req_valid = rng[0];
            req_write = rng[1];
            req_execute = rng[2];
            req_bytes = {24'd0, rng[7:0]};
            rng = xorshift32(rng);
            region_index = rng[1:0];
            case (rng[3:2])
                2'd0: req_addr = region_base[region_index];
                2'd1: req_addr = region_limit[region_index] - req_bytes;
                2'd2: req_addr = region_base[region_index] - {27'd0, rng[4:0]};
                default: req_addr = rng;
            endcase
            check_model($sformatf("random-%0d", trial));
        end

        if (directed_checks < 25 || random_checks != 512 ||
            allow_checks == 0 || deny_checks == 0)
            $fatal(1, "SPAD_PROTECTION_COVERAGE directed=%0d random=%0d allow/deny=%0d/%0d",
                   directed_checks, random_checks, allow_checks, deny_checks);

        $display("SPAD_PROTECTION_TEST_PASS directed=%0d random=%0d allow=%0d deny=%0d seed=%08h",
                 directed_checks, random_checks, allow_checks, deny_checks, seed_value);
        $finish;
    end
endmodule
