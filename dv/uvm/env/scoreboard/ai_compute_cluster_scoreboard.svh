`uvm_analysis_imp_decl(_compute_cluster)
class ai_compute_cluster_scoreboard extends uvm_component;
    `uvm_component_utils(ai_compute_cluster_scoreboard)
    uvm_analysis_imp_compute_cluster #(ai_compute_cluster_obs, ai_compute_cluster_scoreboard) analysis_export;

    typedef struct packed {
        bit [31:0] addr;
        bit [127:0] expected;
        bit [3:0] check_words;
        bit check_data;
        bit is_line;
    } pending_memory_read_t;

    // The model is byte addressed so host byte strobes and 128-bit line
    // strobes are represented exactly. A request snapshots expected data at
    // acceptance, before later writes can alter the reference image.
    bit [7:0] model_byte[longint unsigned];
    pending_memory_read_t pending_memory_reads[0:5][$];
    pending_memory_read_t pending_cnm_lane_reads[0:3][$];

    int unsigned observations;
    int unsigned busy_observations;
    int unsigned overlap_observations;
    int unsigned engine_done_events;
    int unsigned engine_error_events;
    int unsigned spad_responses;
    int unsigned accepted_reads;
    int unsigned orphan_responses;
    int unsigned reset_dropped_reads;
    int unsigned matrix_tag_responses;
    int unsigned cnm_tag_responses;
    int unsigned pending_reads[0:5];
    int unsigned cnm_pending_lane_reads[0:3];
    int unsigned cnm_lane_accepts[0:3];
    int unsigned cnm_lane_responses[0:3];
    int unsigned memory_model_writes;
    int unsigned memory_data_checks;
    int unsigned memory_data_mismatches;
    int unsigned memory_unknown_reads;

    function new(string name, uvm_component parent);
        int client;
        int lane;
        super.new(name, parent);
        analysis_export = new("analysis_export", this);
        for (client = 0; client < 6; client++) pending_reads[client] = 0;
        for (lane = 0; lane < 4; lane++) begin
            cnm_pending_lane_reads[lane] = 0;
            cnm_lane_accepts[lane] = 0;
            cnm_lane_responses[lane] = 0;
        end
    endfunction

    function automatic bit [31:0] read_model_word(
        input bit [31:0] addr,
        output bit known
    );
        bit [31:0] word_value;
        longint unsigned byte_addr;
        int byte_lane;
        word_value = '0;
        known = 1'b1;
        for (byte_lane = 0; byte_lane < 4; byte_lane++) begin
            byte_addr = longint'(addr) + byte_lane;
            if (model_byte.exists(byte_addr))
                word_value[byte_lane*8 +: 8] = model_byte[byte_addr];
            else begin
                known = 1'b0;
                word_value[byte_lane*8 +: 8] = '0;
            end
        end
        return word_value;
    endfunction

    function void write_model_word(
        input bit [31:0] addr,
        input bit [31:0] data,
        input bit [3:0] strobe
    );
        longint unsigned byte_addr;
        int byte_lane;
        for (byte_lane = 0; byte_lane < 4; byte_lane++) begin
            if (strobe[byte_lane]) begin
                byte_addr = longint'(addr) + byte_lane;
                model_byte[byte_addr] = data[byte_lane*8 +: 8];
            end
        end
        memory_model_writes++;
    endfunction

    function automatic pending_memory_read_t make_read_snapshot(
        input bit [31:0] addr,
        input bit [3:0] words,
        input bit is_line,
        input bit access_ok
    );
        pending_memory_read_t item;
        bit word_known;
        bit all_known;
        bit [31:0] word_value;
        int lane;
        item = '0;
        item.addr = addr;
        item.check_words = words;
        item.check_data = access_ok;
        item.is_line = is_line;
        all_known = 1'b1;
        for (lane = 0; lane < 4; lane++) begin
            if (words[lane]) begin
                word_value = read_model_word(addr + (lane * 4), word_known);
                item.expected[lane*32 +: 32] = word_value;
                all_known &= word_known;
            end
        end
        if (access_ok && !all_known) begin
            item.check_data = 1'b0;
            memory_unknown_reads++;
            `uvm_error("CLUSTER_MEMORY_UNKNOWN", $sformatf(
                "accepted read has uninitialized reference bytes addr=0x%08h words=%b",
                addr, words))
        end
        return item;
    endfunction

    function void compare_snapshot(
        input pending_memory_read_t item,
        input bit [127:0] actual,
        input int client,
        input int lane_id
    );
        int lane;
        if (!item.check_data) return;
        for (lane = 0; lane < 4; lane++) begin
            if (item.check_words[lane]) begin
                memory_data_checks++;
                if (actual[lane*32 +: 32] !== item.expected[lane*32 +: 32]) begin
                    memory_data_mismatches++;
                    `uvm_error("CLUSTER_MEMORY_MISMATCH", $sformatf(
                        "client=%0d lane=%0d word_lane=%0d addr=0x%08h expected=0x%08h actual=0x%08h",
                        client, lane_id, lane, item.addr + (lane * 4),
                        item.expected[lane*32 +: 32], actual[lane*32 +: 32]))
                end
            end
        end
    endfunction

    function void write_compute_cluster(ai_compute_cluster_obs obs);
        int client;
        int lane;
        pending_memory_read_t item;
        bit [127:0] actual;
        observations++;
        if (obs.reset_active) begin
            for (client = 0; client < 6; client++) begin
                if (pending_reads[client] != 0)
                    reset_dropped_reads += pending_reads[client];
                pending_reads[client] = 0;
                pending_memory_reads[client].delete();
            end
            for (lane = 0; lane < 4; lane++) begin
                cnm_pending_lane_reads[lane] = 0;
                pending_cnm_lane_reads[lane].delete();
            end
            return;
        end

        if (obs.core_busy !== (|obs.engine_busy))
            `uvm_error("CLUSTER_BUSY", $sformatf("core_busy=%b engine_busy=%07b", obs.core_busy, obs.engine_busy))
        if (|obs.engine_busy) busy_observations++;
        if ($countones(obs.engine_busy) > 1) overlap_observations++;
        if (|obs.engine_done) engine_done_events++;
        if (|obs.engine_error) engine_error_events++;

        // Return-side checking precedes request snapshot insertion. This
        // mirrors the registered SRAM response and supports back-to-back reads.
        if (obs.rsp_valid) begin
            spad_responses++;
            if (obs.rsp_client > 3'd5) begin
                orphan_responses++;
                `uvm_error("CLUSTER_RSP_CLIENT", $sformatf("response has illegal arbiter client=%0d", obs.rsp_client))
            end else if (pending_reads[obs.rsp_client] == 0) begin
                orphan_responses++;
                `uvm_error("CLUSTER_ORPHAN_RSP", $sformatf("response for client=%0d has no accepted read", obs.rsp_client))
            end else begin
                pending_reads[obs.rsp_client]--;
                if (obs.rsp_client == 3'd3) begin
                    matrix_tag_responses++;
                    if (!obs.matrix_rsp_valid || (|obs.cnm_rsp_valid))
                        `uvm_error("CLUSTER_MATRIX_RSP_ROUTE", $sformatf("Matrix tag routed incorrectly: matrix_valid=%b cnm_valid=%b", obs.matrix_rsp_valid, obs.cnm_rsp_valid))
                    if (pending_memory_reads[3].size() == 0)
                        `uvm_error("CLUSTER_MEMORY_ORPHAN", "banked response has no memory snapshot")
                    else begin
                        item = pending_memory_reads[3].pop_front();
                        actual = {obs.banked_rdata[3], obs.banked_rdata[2],
                                  obs.banked_rdata[1], obs.banked_rdata[0]};
                        compare_snapshot(item, actual, 3, -1);
                    end
                end else if (obs.rsp_client == 3'd5) begin
                    cnm_tag_responses++;
                    if (!(|obs.cnm_rsp_valid) || obs.matrix_rsp_valid)
                        `uvm_error("CLUSTER_CNM_RSP_ROUTE", $sformatf("CNM tag routed incorrectly: matrix_valid=%b cnm_valid=%b", obs.matrix_rsp_valid, obs.cnm_rsp_valid))
                end else begin
                    if (pending_memory_reads[obs.rsp_client].size() == 0)
                        `uvm_error("CLUSTER_MEMORY_ORPHAN", $sformatf("client=%0d response has no memory snapshot", obs.rsp_client))
                    else begin
                        item = pending_memory_reads[obs.rsp_client].pop_front();
                        actual = item.is_line ? obs.selected_line_rdata : {96'd0, obs.selected_rsp_rdata};
                        compare_snapshot(item, actual, obs.rsp_client, -1);
                    end
                end
            end
        end else if ((|obs.cnm_rsp_valid) || obs.matrix_rsp_valid) begin
            `uvm_error("CLUSTER_UNTAGGED_RSP", $sformatf("engine response route asserted without arbiter response: matrix=%b cnm=%b", obs.matrix_rsp_valid, obs.cnm_rsp_valid))
        end

        for (lane = 0; lane < 4; lane++) begin
            if (obs.cnm_rsp_valid[lane]) begin
                if (obs.rsp_client != 3'd5)
                    `uvm_error("CLUSTER_CNM_LANE_TAG", $sformatf("CNM lane %0d response has arbiter tag %0d", lane, obs.rsp_client))
                if (cnm_pending_lane_reads[lane] == 0)
                    `uvm_error("CLUSTER_CNM_ORPHAN_LANE", $sformatf("CNM lane %0d response has no accepted lane read", lane))
                else begin
                    cnm_pending_lane_reads[lane]--;
                    cnm_lane_responses[lane]++;
                    if (pending_cnm_lane_reads[lane].size() == 0)
                        `uvm_error("CLUSTER_MEMORY_ORPHAN", $sformatf("CNM lane=%0d response has no memory snapshot", lane))
                    else begin
                        item = pending_cnm_lane_reads[lane].pop_front();
                        actual = {96'd0, obs.cnm_rdata[lane]};
                        compare_snapshot(item, actual, 5, lane);
                    end
                end
            end
        end

        // Host writes initialize/update the independent reference image.
        if (obs.host_valid && obs.host_write && obs.host_access_ok)
            write_model_word(obs.host_addr, obs.host_wdata, obs.host_wstrb);

        // All scalar scheduler clients share the arbiter's selected 32-bit
        // request bus. Their ready lines differ but the address/data owner is
        // captured by the arbiter tag in the same cycle.
        if (obs.selected_spad_valid && obs.selected_spad_ready &&
            obs.selected_spad_write && obs.selected_spad_access_ok)
            write_model_word(obs.selected_spad_addr, obs.selected_spad_wdata, 4'hf);
        if (obs.selected_line_valid && obs.selected_line_ready &&
            obs.selected_line_write && obs.selected_line_access_ok) begin
            for (lane = 0; lane < 4; lane++)
                write_model_word(obs.selected_line_addr + (lane * 4),
                                 obs.selected_line_wdata[lane*32 +: 32],
                                 obs.selected_line_wstrb[lane*4 +: 4]);
        end

        // Requests are snapshotted only after a real arbiter admission. This
        // scoreboard covers descriptor/completion/core/DMA scalar reads,
        // Matrix/DMA lines, all four Matrix bank lanes, and independent CNM lanes.
        for (client = 0; client < 6; client++) begin
            if (obs.read_accept_mask[client]) begin
                pending_reads[client]++;
                accepted_reads++;
                case (client)
                    0, 1: pending_memory_reads[client].push_back(
                        make_read_snapshot(obs.selected_spad_addr, 4'b0001,
                                           1'b0, obs.selected_spad_access_ok));
                    2, 4: begin
                        if (obs.selected_line_valid && obs.selected_line_ready &&
                            !obs.selected_line_write)
                            pending_memory_reads[client].push_back(
                                make_read_snapshot(obs.selected_line_addr, 4'b1111,
                                                   1'b1, obs.selected_line_access_ok));
                        else
                            pending_memory_reads[client].push_back(
                                make_read_snapshot(obs.selected_spad_addr, 4'b0001,
                                                   1'b0, obs.selected_spad_access_ok));
                    end
                    3: pending_memory_reads[client].push_back(
                        make_read_snapshot(obs.selected_banked_addr, 4'b1111,
                                           1'b0, obs.selected_banked_access_ok));
                    default: ;
                endcase
            end
        end
        for (lane = 0; lane < 4; lane++) begin
            if (obs.cnm_accept_mask[lane]) begin
                cnm_pending_lane_reads[lane]++;
                cnm_lane_accepts[lane]++;
                pending_cnm_lane_reads[lane].push_back(
                    make_read_snapshot(obs.selected_cnm_addr[lane], 4'b0001,
                                       1'b0, obs.selected_cnm_access_ok[lane]));
            end
        end
    endfunction

    function void report_phase(uvm_phase phase);
        int client;
        int lane;
        super.report_phase(phase);
        for (client = 0; client < 6; client++) begin
            if (pending_reads[client] != 0)
                `uvm_error("CLUSTER_RSP_DRAIN", $sformatf("client=%0d has %0d accepted reads without responses at test end", client, pending_reads[client]))
            if (pending_memory_reads[client].size() != 0)
                `uvm_error("CLUSTER_MEMORY_DRAIN", $sformatf("client=%0d has %0d memory snapshots at test end", client, pending_memory_reads[client].size()))
        end
        for (lane = 0; lane < 4; lane++) begin
            if (cnm_pending_lane_reads[lane] != 0)
                `uvm_error("CLUSTER_CNM_LANE_DRAIN", $sformatf("CNM lane=%0d has %0d accepted reads without response", lane, cnm_pending_lane_reads[lane]))
            if (pending_cnm_lane_reads[lane].size() != 0)
                `uvm_error("CLUSTER_MEMORY_DRAIN", $sformatf("CNM lane=%0d has %0d memory snapshots at test end", lane, pending_cnm_lane_reads[lane].size()))
        end
        if (memory_data_checks == 0)
            `uvm_error("CLUSTER_MEMORY_EMPTY", "memory scoreboard did not compare any returned words")
        if (memory_data_mismatches != 0 || memory_unknown_reads != 0)
            `uvm_error("CLUSTER_MEMORY_SUMMARY", $sformatf("mismatches=%0d unknown_reads=%0d", memory_data_mismatches, memory_unknown_reads))
        `uvm_info("CLUSTER_MEMORY_SCOREBOARD", $sformatf(
            "writes=%0d checked_words=%0d mismatches=%0d unknown_reads=%0d",
            memory_model_writes, memory_data_checks,
            memory_data_mismatches, memory_unknown_reads), UVM_LOW)
        `uvm_info("CLUSTER_SCOREBOARD", $sformatf(
            "observations=%0d busy=%0d overlap=%0d done=%0d errors=%0d reads=%0d responses=%0d orphan=%0d reset_dropped=%0d matrix_rsp=%0d cnm_rsp=%0d cnm_lane_accepts={%0d,%0d,%0d,%0d} cnm_lane_responses={%0d,%0d,%0d,%0d} pending={%0d,%0d,%0d,%0d,%0d,%0d}",
            observations, busy_observations, overlap_observations,
            engine_done_events, engine_error_events, accepted_reads,
            spad_responses, orphan_responses, reset_dropped_reads,
            matrix_tag_responses, cnm_tag_responses,
            cnm_lane_accepts[0], cnm_lane_accepts[1], cnm_lane_accepts[2], cnm_lane_accepts[3],
            cnm_lane_responses[0], cnm_lane_responses[1], cnm_lane_responses[2], cnm_lane_responses[3],
            pending_reads[0], pending_reads[1], pending_reads[2],
            pending_reads[3], pending_reads[4], pending_reads[5]), UVM_LOW)
    endfunction
endclass
