class ai_compute_cluster_e2e_seq extends uvm_sequence #(ai_axil_item);
    `uvm_object_utils(ai_compute_cluster_e2e_seq)

    localparam bit [31:0] REG_CMDQ_CTRL = 32'h0000_00ac;
    localparam bit [31:0] REG_CMDQ_BASE = 32'h0000_0080;
    localparam bit [31:0] REG_CMDQ_SIZE = 32'h0000_0088;
    localparam bit [31:0] REG_CMDQ_HEAD = 32'h0000_008c;
    localparam bit [31:0] REG_CMDQ_TAIL = 32'h0000_00c8;
    localparam bit [31:0] REG_CPLQ_BASE = 32'h0000_0090;
    localparam bit [31:0] REG_CPLQ_SIZE = 32'h0000_0098;
    localparam bit [31:0] REG_CPLQ_TAIL = 32'h0000_009c;
    localparam bit [31:0] REG_CPLQ_HEAD = 32'h0000_00cc;
    localparam bit [31:0] REG_DOORBELL = 32'h0000_00a0;
    localparam bit [31:0] REG_ABORT = 32'h0000_00a4;

    localparam bit [31:0] CMDQ_LOCAL = 32'h0000_4000;
    localparam bit [31:0] CPLQ_LOCAL = 32'h0000_5000;
    localparam bit [31:0] MATRIX_A_LOCAL = 32'h0001_0000;
    localparam bit [31:0] MATRIX_B_LOCAL = 32'h0001_2000;
    localparam bit [31:0] MATRIX_Y_LOCAL = 32'h0003_0000;
    localparam bit [31:0] GELU_A_LOCAL = 32'h0002_0000;
    localparam bit [31:0] GELU_B_LOCAL = 32'h0002_0100;
    localparam bit [31:0] GELU_Y0_LOCAL = 32'h0002_0200;
    localparam bit [31:0] GELU_Y1_LOCAL = 32'h0002_0300;
    localparam bit [31:0] CNM_A_LOCAL = 32'h0004_8000;
    localparam bit [31:0] CNM_B_LOCAL = 32'h0004_9000;
    localparam bit [31:0] CNM_Y_LOCAL = 32'h0004_a000;

    virtual ai_compute_cluster_if compute_vif;
    bit [31:0] rng_state;

    function automatic int signed next_small_signed();
        int unsigned value;
        rng_state = rng_state ^ (rng_state << 13);
        rng_state = rng_state ^ (rng_state >> 17);
        rng_state = rng_state ^ (rng_state << 5);
        value = rng_state % 5;
        return int'(value) - 2;
    endfunction

    function new(string name = "ai_compute_cluster_e2e_seq");
        super.new(name);
    endfunction

    task automatic axil_write(input bit [31:0] addr, input bit [31:0] data);
        ai_axil_item req;
        req = ai_axil_item::type_id::create("cluster_axil_write");
        start_item(req);
        req.is_write = 1'b1;
        req.addr = addr;
        req.data = data;
        req.strb = 4'hf;
        finish_item(req);
        if (req.resp !== 2'b00)
            `uvm_fatal("CLUSTER_AXIL", $sformatf("write addr=0x%08h resp=%0h", addr, req.resp))
    endtask

    task automatic axil_read(input bit [31:0] addr, output bit [31:0] data);
        ai_axil_item req;
        req = ai_axil_item::type_id::create("cluster_axil_read");
        start_item(req);
        req.is_write = 1'b0;
        req.addr = addr;
        req.data = '0;
        req.strb = '0;
        finish_item(req);
        if (req.resp !== 2'b00)
            `uvm_fatal("CLUSTER_AXIL", $sformatf("read addr=0x%08h resp=%0h", addr, req.resp))
        data = req.rdata;
    endtask

    task automatic spad_write(input bit [31:0] addr, input bit [31:0] data);
        axil_write(CIMFORGE_SPAD_BASE + addr, data);
    endtask

    task automatic expect_spad(input bit [31:0] addr, input bit [31:0] expected, input string tag);
        bit [31:0] actual;
        axil_read(CIMFORGE_SPAD_BASE + addr, actual);
        if (actual !== expected)
            `uvm_fatal("CLUSTER_GOLDEN", $sformatf("%s addr=0x%08h expected=0x%08h actual=0x%08h", tag, addr, expected, actual))
    endtask

    task automatic write_v3_desc(
        input bit [31:0] base,
        input bit [7:0] op,
        input bit [15:0] task_id,
        input bit [31:0] src0,
        input bit [31:0] src1,
        input bit [31:0] dst,
        input bit [15:0] m,
        input bit [15:0] n,
        input bit [15:0] length_or_k
    );
        spad_write(base + 32'h00, {task_id, 8'd0, op});
        spad_write(base + 32'h04, src0);
        spad_write(base + 32'h08, src1);
        spad_write(base + 32'h0c, 32'd0);
        spad_write(base + 32'h10, dst);
        spad_write(base + 32'h14, {n, m});
        spad_write(base + 32'h18, {16'd0, length_or_k});
        spad_write(base + 32'h1c, 32'd0);
        spad_write(base + 32'h20, 32'd1);
        spad_write(base + 32'h24, 32'd0);
        spad_write(base + 32'h28, 32'd0);
        spad_write(base + 32'h2c, 32'd0);
        spad_write(base + 32'h30, 32'd0);
        spad_write(base + 32'h34, 32'h0001_0001);
        spad_write(base + 32'h38, 32'd0);
        spad_write(base + 32'h3c, 32'd3);
    endtask

    task automatic write_cnm_v3_desc(
        input bit [31:0] base,
        input bit [15:0] task_id,
        input bit [31:0] src0,
        input bit [31:0] src1,
        input bit [31:0] dst
    );
        spad_write(base + 32'h00, {task_id, 8'd0, 8'h21});
        spad_write(base + 32'h04, src0);
        spad_write(base + 32'h08, src1);
        spad_write(base + 32'h0c, 32'd0);
        spad_write(base + 32'h10, dst);
        spad_write(base + 32'h14, {16'd1, 16'd16});
        spad_write(base + 32'h18, 32'd1);
        spad_write(base + 32'h1c, 32'd0);
        spad_write(base + 32'h20, 32'd0);
        spad_write(base + 32'h24, 32'd0);
        spad_write(base + 32'h28, 32'd0);
        spad_write(base + 32'h2c, 32'd0);
        spad_write(base + 32'h30, 32'd0);
        spad_write(base + 32'h34, 32'h0001_0001);
        spad_write(base + 32'h38, 32'd0);
        spad_write(base + 32'h3c, 32'd3);
    endtask

    task automatic expect_completion(
        input bit [31:0] base,
        input bit [15:0] task_id,
        input bit [31:0] result,
        input bit [31:0] elements,
        input string tag
    );
        expect_spad(base + 32'h00, {16'd0, task_id}, {tag, " task_id"});
        expect_spad(base + 32'h04, 32'h0000_0001, {tag, " status"});
        expect_spad(base + 32'h08, result, {tag, " result"});
        expect_spad(base + 32'h0c, elements, {tag, " elements"});
    endtask

    task automatic wait_cpl_tail(input bit [31:0] expected);
        bit [31:0] value;
        int unsigned poll;
        value = '0;
        for (poll = 0; poll < 3000; poll++) begin
            axil_read(REG_CPLQ_TAIL, value);
            if (value == expected) return;
        end
        `uvm_fatal("CLUSTER_TIMEOUT", $sformatf("CPLQ_TAIL expected %0d got %0d", expected, value))
    endtask

    task automatic wait_spad_idle();
        int unsigned poll;
        int unsigned quiet_cycles;
        quiet_cycles = 0;
        for (poll = 0; poll < 50000; poll++) begin
            @(posedge compute_vif.aclk);
            if (!compute_vif.core_busy && !compute_vif.processor_busy &&
                (compute_vif.engine_busy == 0) &&
                (compute_vif.engine_req_valid == 0) &&
                !compute_vif.core_spad_valid &&
                !compute_vif.banked_valid &&
                (compute_vif.cnm_valid == 0) &&
                !compute_vif.matrix_line_valid &&
                !compute_vif.dma_valid &&
                !compute_vif.dma_line_valid &&
                !compute_vif.desc_valid &&
                !compute_vif.cpl_valid) begin
                quiet_cycles++;
                if (quiet_cycles == 3) return;
            end else
                quiet_cycles = 0;
        end
        `uvm_fatal("CLUSTER_SPAD_IDLE", $sformatf(
            "scheduler SPAD did not stay idle: core_busy=%b processor_busy=%b engine_busy=%07b engine_req=%07b core=%b banked=%b cnm=%b line=%b dma=%b dma_line=%b desc=%b cpl=%b",
            compute_vif.core_busy, compute_vif.processor_busy,
            compute_vif.engine_busy, compute_vif.engine_req_valid,
            compute_vif.core_spad_valid, compute_vif.banked_valid,
            compute_vif.cnm_valid, compute_vif.matrix_line_valid,
            compute_vif.dma_valid, compute_vif.dma_line_valid,
            compute_vif.desc_valid, compute_vif.cpl_valid))
    endtask

    task automatic wait_matrix_sfu_overlap();
        int unsigned poll;
        for (poll = 0; poll < 3000; poll++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.engine_busy[3] && compute_vif.engine_busy[4]) return;
        end
        `uvm_fatal("CLUSTER_ABORT", "Matrix and SFU did not become active together before abort")
    endtask

    task automatic wait_matrix_read_accept();
        int unsigned poll;
        for (poll = 0; poll < 3000; poll++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.banked_valid && compute_vif.banked_ready) return;
        end
        `uvm_fatal("CLUSTER_RESET", "Matrix did not receive a banked-SPAD grant before reset")
    endtask

    task automatic wait_matrix_prefetch_active();
        int unsigned poll;
        for (poll = 0; poll < 3000; poll++) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.matrix_prefetch_active) return;
        end
        `uvm_fatal("CLUSTER_PREFETCH", "Matrix did not enter next-K prefetch before abort/reset")
    endtask

    task automatic check_cnm_address_stream();
        int unsigned lane_count[0:3];
        int unsigned lane;
        int unsigned poll;
        int unsigned matrix_reads;
        bit complete;
        bit [31:0] expected_addr;
        bit [31:0] cpl_tail;
        for (lane = 0; lane < 4; lane++) lane_count[lane] = 0;
        poll = 0;
        matrix_reads = 0;
        complete = 1'b0;
        while (!complete && poll < 10000) begin
            @(posedge compute_vif.aclk);
            if (compute_vif.aresetn) begin
                if (compute_vif.banked_valid && compute_vif.banked_ready) begin
                    if (compute_vif.matrix_banked_req_addr[1:0] != 2'b00 ||
                        !((compute_vif.matrix_banked_req_addr >= MATRIX_A_LOCAL &&
                           compute_vif.matrix_banked_req_addr < MATRIX_A_LOCAL + 32'h400) ||
                          (compute_vif.matrix_banked_req_addr >= MATRIX_B_LOCAL &&
                           compute_vif.matrix_banked_req_addr < MATRIX_B_LOCAL + 32'h800)))
                        `uvm_fatal("CLUSTER_MATRIX_ADDR", $sformatf("Matrix banked read outside aligned A/B tile regions: 0x%08h", compute_vif.matrix_banked_req_addr))
                    matrix_reads++;
                end
                for (lane = 0; lane < 4; lane++) begin
                    if (compute_vif.cnm_accept_mask[lane]) begin
                        if (lane_count[lane][0])
                            expected_addr = CNM_B_LOCAL + ((lane_count[lane] >> 1) << 4) + (lane << 2);
                        else
                            expected_addr = CNM_A_LOCAL + (lane << 2);
                        if (compute_vif.cnm_req_addr[lane] !== expected_addr)
                            `uvm_fatal("CLUSTER_CNM_ADDR", $sformatf("lane%0d read[%0d] expected=0x%08h actual=0x%08h", lane, lane_count[lane], expected_addr, compute_vif.cnm_req_addr[lane]))
                        lane_count[lane]++;
                    end
                end
            end
            complete = 1'b1;
            for (lane = 0; lane < 4; lane++)
                if (lane_count[lane] != 32) complete = 1'b0;
            if (!complete && (compute_vif.engine_done[2] ||
                              compute_vif.engine_error[2]))
                break;
            poll++;
        end
        for (lane = 0; lane < 4; lane++) begin
            if (lane_count[lane] != 32) begin
                axil_read(REG_CPLQ_TAIL, cpl_tail);
                `uvm_fatal("CLUSTER_CNM_ADDR_TIMEOUT", $sformatf(
                    "lane0..3 accepted %0d/%0d/%0d/%0d of 32 A/B requests; engine_busy=%07b done=%07b error=%07b cpl_tail=%0d responses=%0d lanes=%b matrix_rsp=%0d cnm_fsm=%0d lane_fsm=%h req=%b ready=%b rsp=%b",
                    lane_count[0], lane_count[1], lane_count[2], lane_count[3],
                    compute_vif.engine_busy, compute_vif.engine_done,
                    compute_vif.engine_error, cpl_tail,
                    compute_vif.cnm_tag_response_count,
                    compute_vif.cnm_response_lane_seen,
                    compute_vif.matrix_tag_response_count,
                    compute_vif.cnm_core_state, compute_vif.cnm_lane_state,
                    compute_vif.cnm_request_valid, compute_vif.cnm_request_ready,
                    compute_vif.cnm_rsp_valid))
            end
        end
        if (matrix_reads == 0)
            `uvm_fatal("CLUSTER_MATRIX_ADDR", "no accepted Matrix banked reads observed during Matrix/CNM overlap window")
        `uvm_info("CLUSTER_CNM_ADDR_PASS", $sformatf("all four CNM lanes accepted expected A/B addresses; Matrix accepted %0d reads within its A/B tile regions", matrix_reads), UVM_LOW)
    endtask

    task body();
        bit [31:0] value;
        bit [31:0] packed_word;
        int unsigned seed;
        int unsigned tile_row;
        int unsigned tile_col;
        int unsigned k_word;
        int unsigned row_lane;
        int unsigned col_lane;
        int unsigned k_lane;
        int unsigned row_idx;
        int unsigned col_idx;
        int unsigned k_idx;
        int signed matrix_a[0:15][0:63];
        int signed matrix_b[0:63][0:31];
        int signed matrix_golden[0:15][0:31];
        int signed gelu_values[0:3];
        int signed gelu_results[0:3];
        int signed accumulator;
        int unsigned word_idx;
        int unsigned overlap_total;
        int unsigned matrix_prefetch_overlap_total;
        int unsigned matrix_cnm_overlap_total;
        int unsigned cnm_grants_total;
        int unsigned matrix_responses_total;
        int unsigned cnm_responses_total;
        bit [3:0] cnm_lanes_seen_total;
        int unsigned contention_total;
        int unsigned banked_grants_total;
        int unsigned core_grants_total;
        bit reset_value;
        bit reset_ok;

        if (compute_vif == null)
            `uvm_fatal("CLUSTER_NOVIF", "real compute cluster sequence requires compute_vif")

        seed = 20261025;
        void'($value$plusargs("COMPUTE_CLUSTER_SEED=%d", seed));
        rng_state = seed ^ 32'h7ac4_01d3;
        if (rng_state == 0) rng_state = 32'h1;
        for (row_idx = 0; row_idx < 16; row_idx++)
            for (k_idx = 0; k_idx < 64; k_idx++)
                matrix_a[row_idx][k_idx] = next_small_signed();
        for (k_idx = 0; k_idx < 64; k_idx++)
            for (col_idx = 0; col_idx < 32; col_idx++)
                matrix_b[k_idx][col_idx] = next_small_signed();

        // The matrix controller consumes 4x4 tile-major operands: each K
        // group is one 128-bit bank row, with four packed lanes per bank.
        for (tile_row = 0; tile_row < 4; tile_row++) begin
            for (k_word = 0; k_word < 16; k_word++) begin
                for (row_lane = 0; row_lane < 4; row_lane++) begin
                    packed_word = '0;
                    for (k_lane = 0; k_lane < 4; k_lane++) begin
                        row_idx = tile_row * 4 + row_lane;
                        k_idx = k_word * 4 + k_lane;
                        packed_word[k_lane*8 +: 8] = matrix_a[row_idx][k_idx];
                    end
                    spad_write(MATRIX_A_LOCAL + ((tile_row * 16 + k_word) << 4) + (row_lane << 2), packed_word);
                end
            end
        end
        for (tile_col = 0; tile_col < 8; tile_col++) begin
            for (k_word = 0; k_word < 16; k_word++) begin
                for (col_lane = 0; col_lane < 4; col_lane++) begin
                    packed_word = '0;
                    for (k_lane = 0; k_lane < 4; k_lane++) begin
                        col_idx = tile_col * 4 + col_lane;
                        k_idx = k_word * 4 + k_lane;
                        packed_word[k_lane*8 +: 8] = matrix_b[k_idx][col_idx];
                    end
                    spad_write(MATRIX_B_LOCAL + ((tile_col * 16 + k_word) << 4) + (col_lane << 2), packed_word);
                end
            end
        end
        for (row_idx = 0; row_idx < 16; row_idx++) begin
            for (col_idx = 0; col_idx < 32; col_idx++) begin
                accumulator = 0;
                for (k_idx = 0; k_idx < 64; k_idx++)
                    accumulator += matrix_a[row_idx][k_idx] * matrix_b[k_idx][col_idx];
                matrix_golden[row_idx][col_idx] = accumulator;
            end
        end

        gelu_values[0] = 16;
        gelu_values[1] = -16;
        gelu_values[2] = 32;
        gelu_values[3] = -32;
        gelu_results[0] = 8;
        gelu_results[1] = -8;
        gelu_results[2] = 17;
        gelu_results[3] = -15;
        for (word_idx = 0; word_idx < 64; word_idx++) begin
            spad_write(GELU_A_LOCAL + (word_idx << 2), gelu_values[word_idx % 4]);
            spad_write(GELU_B_LOCAL + (word_idx << 2), gelu_values[word_idx % 4]);
        end
        for (word_idx = 0; word_idx < 4; word_idx++) begin
            case (word_idx)
                0: packed_word = 32'h0202_0202;
                1: packed_word = 32'h0303_0303;
                2: packed_word = 32'h0404_0404;
                default: packed_word = 32'h0505_0505;
            endcase
            spad_write(CNM_A_LOCAL + (word_idx << 2), packed_word);
        end
        for (row_idx = 0; row_idx < 16; row_idx++) begin
            for (col_idx = 0; col_idx < 4; col_idx++) begin
                case (col_idx)
                    0: packed_word = 32'h0707_0707;
                    1: packed_word = 32'h0b0b_0b0b;
                    2: packed_word = 32'h0d0d_0d0d;
                    default: packed_word = 32'h1111_1111;
                endcase
                spad_write(CNM_B_LOCAL + (row_idx << 4) + (col_idx << 2), packed_word);
            end
        end

        // Keep a strict standalone A-tile reuse baseline before adding CNM
        // contention. The parallel workload below separately checks data
        // integrity while the shared banked port is under contention.
        write_v3_desc(CMDQ_LOCAL, 8'h30, 16'h05ff,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, MATRIX_Y_LOCAL,
                      16'd16, 16'd32, 16'd16);
        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, CMDQ_LOCAL);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd1);
        axil_write(REG_CPLQ_BASE, CPLQ_LOCAL);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd1);
        wait_spad_idle();
        if (compute_vif.matrix_a_cache_hits != 16)
            `uvm_fatal("CLUSTER_A_CACHE_BASELINE", $sformatf(
                "standalone 16x32x64 GEMM expected 16 A-tile cache hits, observed %0d",
                compute_vif.matrix_a_cache_hits))
        for (word_idx = 0; word_idx < 512; word_idx++)
            expect_spad(MATRIX_Y_LOCAL + (word_idx << 2),
                        matrix_golden[word_idx / 32][word_idx % 32],
                        $sformatf("standalone Matrix Golden[%0d]", word_idx));
        `uvm_info("CLUSTER_A_CACHE_BASELINE_PASS",
                  "standalone 16x32x64 Matrix Golden and all 16 A-tile reuse hits passed",
                  UVM_LOW)
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);

        write_v3_desc(CMDQ_LOCAL + 32'h00, 8'h30, 16'h0600,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, MATRIX_Y_LOCAL,
                      16'd16, 16'd32, 16'd16);
        write_cnm_v3_desc(CMDQ_LOCAL + 32'h40, 16'h0601,
                          CNM_A_LOCAL, CNM_B_LOCAL, CNM_Y_LOCAL);
        write_v3_desc(CMDQ_LOCAL + 32'h80, 8'h35, 16'h0602,
                      GELU_A_LOCAL, 32'd0, GELU_Y0_LOCAL,
                      16'd0, 16'd0, 16'd64);
        write_v3_desc(CMDQ_LOCAL + 32'hc0, 8'h35, 16'h0603,
                      GELU_B_LOCAL, 32'd0, GELU_Y1_LOCAL,
                      16'd0, 16'd0, 16'd64);

        axil_write(REG_CMDQ_CTRL, 32'd0);
        axil_write(REG_CMDQ_BASE, CMDQ_LOCAL);
        // The command ring also reserves one slot to distinguish full from
        // empty, so four outstanding descriptors need an eight-entry ring.
        axil_write(REG_CMDQ_SIZE, 32'd8);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd4);
        axil_write(REG_CPLQ_BASE, CPLQ_LOCAL);
        // This ring keeps one entry empty to distinguish full from empty.
        // Four ordered completions therefore need an eight-entry ring.
        axil_write(REG_CPLQ_SIZE, 32'd8);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        axil_write(REG_DOORBELL, 32'd1);
        check_cnm_address_stream();
        wait_cpl_tail(32'd4);
        wait_spad_idle();

        if (compute_vif.overlap_cycles == 0)
            `uvm_fatal("CLUSTER_OVERLAP", "real Matrix and SFU never overlapped")
        if (compute_vif.shared_spad_contention_cycles == 0)
            `uvm_fatal("CLUSTER_SPAD_CONTENTION", "real core and banked requests never contended at ai_spad_arbiter")
        if (compute_vif.arb_banked_grants == 0 || compute_vif.arb_core_grants == 0)
            `uvm_fatal("CLUSTER_SPAD_TRAFFIC", "expected both banked and core SPAD grants")
        if (compute_vif.same_engine_launch_while_busy != 0)
            `uvm_fatal("CLUSTER_OWNER", $sformatf("same-engine launch while busy count=%0d", compute_vif.same_engine_launch_while_busy))
        if (compute_vif.matrix_a_cache_hits == 0)
            `uvm_fatal("CLUSTER_A_CACHE", "Matrix/CNM contention run recorded no A-tile cache hits")
        `uvm_info("CLUSTER_A_CACHE_CONTENTION", $sformatf(
                  "Matrix/CNM workload retained %0d A-tile cache hits under shared-port contention; standalone baseline was 16",
                  compute_vif.matrix_a_cache_hits), UVM_LOW)
        if (compute_vif.matrix_prefetch_overlap_cycles == 0)
            `uvm_fatal("CLUSTER_PREFETCH", "next-K prefetch did not overlap Matrix MAC")
        if (compute_vif.matrix_cnm_overlap_cycles == 0)
            `uvm_fatal("CLUSTER_CNM_OVERLAP", "Matrix and CNM were not simultaneously active")
        if (compute_vif.matrix_cnm_shared_accept_cycles == 0)
            `uvm_fatal("CLUSTER_CNM_ARBITRATION", "Matrix and CNM did not contend at shared banked admission")
        if (compute_vif.matrix_tag_response_count == 0 || compute_vif.cnm_tag_response_count == 0)
            `uvm_fatal("CLUSTER_CNM_RESPONSE", $sformatf("missing owner responses: Matrix=%0d CNM=%0d", compute_vif.matrix_tag_response_count, compute_vif.cnm_tag_response_count))
        if (compute_vif.matrix_route_mismatch_count != 0 || compute_vif.cnm_route_mismatch_count != 0)
            `uvm_fatal("CLUSTER_CNM_ROUTE", $sformatf("response route mismatches: Matrix=%0d CNM=%0d", compute_vif.matrix_route_mismatch_count, compute_vif.cnm_route_mismatch_count))
        if (compute_vif.cnm_response_lane_seen !== 4'hf)
            `uvm_fatal("CLUSTER_CNM_BANKS", $sformatf("expected responses from all CNM banks, observed lane mask=%b", compute_vif.cnm_response_lane_seen))
        `uvm_info("CLUSTER_CNM_OWNER_PASS", $sformatf("Matrix tag3 responses=%0d, CNM tag5 responses=%0d, CNM lane mask=%b, overlap cycles=%0d, shared banked grants=%0d", compute_vif.matrix_tag_response_count, compute_vif.cnm_tag_response_count, compute_vif.cnm_response_lane_seen, compute_vif.matrix_cnm_overlap_cycles, compute_vif.matrix_cnm_shared_accept_cycles), UVM_LOW)
        matrix_prefetch_overlap_total = compute_vif.matrix_prefetch_overlap_cycles;
        matrix_cnm_overlap_total = compute_vif.matrix_cnm_overlap_cycles;
        cnm_grants_total = compute_vif.arb_cnm_grants;
        matrix_responses_total = compute_vif.matrix_tag_response_count;
        cnm_responses_total = compute_vif.cnm_tag_response_count;
        cnm_lanes_seen_total = compute_vif.cnm_response_lane_seen;
        overlap_total = compute_vif.overlap_cycles;
        contention_total = compute_vif.shared_spad_contention_cycles;
        banked_grants_total = compute_vif.arb_banked_grants;
        core_grants_total = compute_vif.arb_core_grants;

        for (word_idx = 0; word_idx < 512; word_idx++)
            expect_spad(MATRIX_Y_LOCAL + (word_idx << 2), matrix_golden[word_idx / 32][word_idx % 32], $sformatf("16x32x64 GEMM[%0d]", word_idx));
        for (word_idx = 0; word_idx < 16; word_idx++)
            expect_spad(CNM_Y_LOCAL + (word_idx << 2), 32'd736,
                        $sformatf("CNM GEMV row[%0d]", word_idx));
        for (word_idx = 0; word_idx < 64; word_idx++) begin
            expect_spad(GELU_Y0_LOCAL + (word_idx << 2), gelu_results[word_idx % 4],
                        $sformatf("GELU0 output[%0d]", word_idx));
            expect_spad(GELU_Y1_LOCAL + (word_idx << 2), gelu_results[word_idx % 4],
                        $sformatf("GELU1 output[%0d]", word_idx));
        end

        expect_completion(CPLQ_LOCAL + 32'h00, 16'h0600, matrix_golden[15][31], 32'd512, "Matrix");
        expect_completion(CPLQ_LOCAL + 32'h10, 16'h0601, 32'd736, 32'd16, "CNM GEMV");
        expect_completion(CPLQ_LOCAL + 32'h20, 16'h0602, -32'sd15, 32'd64, "SFU first");
        expect_completion(CPLQ_LOCAL + 32'h30, 16'h0603, -32'sd15, 32'd64, "SFU queued");
        axil_read(REG_CMDQ_HEAD, value);
        if (value !== 32'd4)
            `uvm_fatal("CLUSTER_CMDQ", $sformatf("CMDQ_HEAD expected=4 actual=%0d", value))
        axil_write(REG_CPLQ_HEAD, 32'd4);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);

        // Abort two real in-flight engines after their overlap is observed.
        // Sentinels prove the Matrix tile has not started writeback at abort.
        for (word_idx = 0; word_idx < 4; word_idx++)
            spad_write(32'h0003_1000 + (word_idx << 2), 32'hbad0_0600 + word_idx);
        write_v3_desc(CMDQ_LOCAL + 32'h100, 8'h30, 16'h0610,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, 32'h0003_1000,
                      16'd16, 16'd16, 16'd16);
        write_v3_desc(CMDQ_LOCAL + 32'h140, 8'h35, 16'h0611,
                      GELU_A_LOCAL, 32'd0, 32'h0003_1100,
                      16'd0, 16'd0, 16'd1024);
        axil_write(REG_CMDQ_BASE, CMDQ_LOCAL + 32'h100);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd2);
        axil_write(REG_CPLQ_BASE, CPLQ_LOCAL + 32'h100);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        axil_write(REG_DOORBELL, 32'd1);
        wait_matrix_sfu_overlap();
        wait_matrix_prefetch_active();
        axil_write(REG_ABORT, 32'd1);
        wait_cpl_tail(32'd2);
        expect_spad(CPLQ_LOCAL + 32'h100, 32'h0000_0610, "abort Matrix task ID");
        expect_spad(CPLQ_LOCAL + 32'h104, 32'h0000_0032, "abort Matrix status/code");
        expect_spad(CPLQ_LOCAL + 32'h110, 32'h0000_0611, "abort SFU task ID");
        expect_spad(CPLQ_LOCAL + 32'h114, 32'h0000_0032, "abort SFU status/code");
        for (word_idx = 0; word_idx < 4; word_idx++)
            expect_spad(32'h0003_1000 + (word_idx << 2), 32'hbad0_0600 + word_idx,
                        $sformatf("abort Matrix no-writeback[%0d]", word_idx));
        if (compute_vif.engine_busy != 0)
            `uvm_fatal("CLUSTER_ABORT", $sformatf("abort completion published with engine_busy=%07b", compute_vif.engine_busy))
        axil_write(REG_CPLQ_HEAD, 32'd2);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);

        // Reset both real engines while they are active. The behavioral SRAM
        // contents are retained across accelerator reset; the command and
        // completion lifecycle state must be cleared without stale writeback.
        for (word_idx = 0; word_idx < 4; word_idx++)
            spad_write(32'h0003_2000 + (word_idx << 2), 32'hbad0_0620 + word_idx);
        write_v3_desc(CMDQ_LOCAL + 32'h200, 8'h30, 16'h0620,
                      MATRIX_A_LOCAL, MATRIX_B_LOCAL, 32'h0003_2000,
                      16'd16, 16'd16, 16'd16);
        write_v3_desc(CMDQ_LOCAL + 32'h240, 8'h35, 16'h0621,
                      GELU_A_LOCAL, 32'd0, 32'h0003_2100,
                      16'd0, 16'd0, 16'd1024);
        axil_write(REG_CMDQ_BASE, CMDQ_LOCAL + 32'h200);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd2);
        axil_write(REG_CPLQ_BASE, CPLQ_LOCAL + 32'h200);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        axil_write(REG_DOORBELL, 32'd1);
        wait_matrix_sfu_overlap();
        wait_matrix_read_accept();
        wait_matrix_prefetch_active();
        #1ns;
        reset_value = 1'b0;
        reset_ok = uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", reset_value);
        if (!reset_ok)
            `uvm_fatal("CLUSTER_RESET", "failed to assert accelerator reset with Matrix and SFU active")
        repeat (4) @(posedge compute_vif.aclk);
        if (compute_vif.engine_busy !== 7'b0)
            `uvm_fatal("CLUSTER_RESET", $sformatf("engines did not clear during reset: %07b", compute_vif.engine_busy))
        reset_value = 1'b1;
        reset_ok = uvm_hdl_deposit("tb_ai_accel_uvm.aresetn", reset_value);
        if (!reset_ok)
            `uvm_fatal("CLUSTER_RESET", "failed to release accelerator reset")
        repeat (8) @(posedge compute_vif.aclk);
        axil_read(REG_CPLQ_TAIL, value);
        if (value !== 32'd0)
            `uvm_fatal("CLUSTER_RESET", $sformatf("stale completion tail after reset: %0d", value))
        for (word_idx = 0; word_idx < 4; word_idx++)
            expect_spad(32'h0003_2000 + (word_idx << 2), 32'hbad0_0620 + word_idx,
                        $sformatf("reset Matrix no-writeback[%0d]", word_idx));

        // Prove the real cluster and queue path recover after reset by
        // executing a fresh SFU task and checking its completion and image.
        write_v3_desc(CMDQ_LOCAL + 32'h300, 8'h35, 16'h0622,
                      GELU_A_LOCAL, 32'd0, GELU_Y0_LOCAL,
                      16'd0, 16'd0, 16'd4);
        axil_write(REG_CMDQ_BASE, CMDQ_LOCAL + 32'h300);
        axil_write(REG_CMDQ_SIZE, 32'd4);
        axil_write(REG_CMDQ_HEAD, 32'd0);
        axil_write(REG_CMDQ_TAIL, 32'd1);
        axil_write(REG_CPLQ_BASE, CPLQ_LOCAL + 32'h300);
        axil_write(REG_CPLQ_SIZE, 32'd4);
        axil_write(REG_CPLQ_HEAD, 32'd0);
        axil_write(REG_CPLQ_TAIL, 32'd0);
        axil_write(REG_DOORBELL, 32'd1);
        wait_cpl_tail(32'd1);
        expect_completion(CPLQ_LOCAL + 32'h300, 16'h0622, -32'sd15, 32'd4,
                          "post-reset SFU recovery");
        expect_spad(GELU_Y0_LOCAL + 32'h00, 32'd8, "post-reset GELU output0");
        expect_spad(GELU_Y0_LOCAL + 32'h04, -32'sd8, "post-reset GELU output1");
        expect_spad(GELU_Y0_LOCAL + 32'h08, 32'd17, "post-reset GELU output2");
        expect_spad(GELU_Y0_LOCAL + 32'h0c, -32'sd15, "post-reset GELU output3");
        axil_write(REG_CPLQ_HEAD, 32'd1);
        axil_write(REG_CMDQ_SIZE, 32'd0);
        axil_write(REG_CPLQ_SIZE, 32'd0);
        overlap_total += compute_vif.overlap_cycles;
        contention_total += compute_vif.shared_spad_contention_cycles;
        banked_grants_total += compute_vif.arb_banked_grants;
        core_grants_total += compute_vif.arb_core_grants;
        `uvm_info("CLUSTER_RESET_RECOVERY_PASS", "active Matrix/SFU reset discarded both in-flight tasks, preserved SRAM sentinels, and accepted a fresh post-reset SFU task", UVM_LOW)

        `uvm_info("COMPUTE_CLUSTER_REAL_UVM_PASS", $sformatf(
            "standalone Matrix16x32x64 Golden + 16 A-tile reuse hits; parallel Matrix/CNM GEMV with separate response tags and four-bank Golden + next-K prefetch + queued SFU tasks + concurrent abort/reset/recovery seed=%0d; prefetch_overlap=%0d matrix_cnm_overlap=%0d matrix_rsp=%0d cnm_rsp=%0d cnm_lanes=%b overlap=%0d arbiter_contention=%0d banked_grants=%0d cnm_grants=%0d core_grants=%0d",
            seed, matrix_prefetch_overlap_total,
            matrix_cnm_overlap_total, matrix_responses_total, cnm_responses_total,
            cnm_lanes_seen_total,
            overlap_total, contention_total,
            banked_grants_total, cnm_grants_total,
            core_grants_total), UVM_LOW)
    endtask
endclass
