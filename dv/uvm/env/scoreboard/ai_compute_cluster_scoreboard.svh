`uvm_analysis_imp_decl(_compute_cluster)
class ai_compute_cluster_scoreboard extends uvm_component;
    `uvm_component_utils(ai_compute_cluster_scoreboard)
    uvm_analysis_imp_compute_cluster #(ai_compute_cluster_obs, ai_compute_cluster_scoreboard) analysis_export;

    typedef struct packed {
        bit [31:0] addr;
        bit [127:0] expected;
        bit [3:0] check_words;
        bit [3:0] banks;
        bit [6:0] engines;
        bit [2:0] client;
        bit [15:0] epoch;
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
    int unsigned full_line_write_masks;
    int unsigned partial_line_write_masks;
    int unsigned zero_line_write_masks;
    int unsigned read_bank_hits[0:3];
    int unsigned read_engine_hits[0:6];
    int unsigned write_engine_hits[0:6];
    int unsigned memory_epoch;
    int unsigned stale_epoch_responses;
    int unsigned invalid_engine_done;
    bit [6:0] active_engine_seen;
    bit [6:0] error_terminal_pending;
    bit [6:0] error_seen;
    bit reset_active_previous;
    string mutation_kind;
    bit mutation_caught;

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

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mutation_kind = "";
        mutation_caught = 1'b0;
        void'($value$plusargs("CL_MUTATION=%s", mutation_kind));
    endfunction

    function void note_mutation_caught(input string checker_name);
        if ((mutation_kind != "") && !mutation_caught) begin
            mutation_caught = 1'b1;
            `uvm_info("CLUSTER_MUTATION_CAUGHT", $sformatf(
                "mutation=%s checker=%s", mutation_kind, checker_name), UVM_LOW)
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

    function automatic pending_memory_read_t annotate_snapshot(
        input pending_memory_read_t source,
        input int client,
        input bit [6:0] engines,
        input int lane_id
    );
        pending_memory_read_t item;
        int word_lane;
        int bank_id;
        item = source;
        item.client = client[2:0];
        item.engines = engines;
        item.epoch = memory_epoch[15:0];
        for (word_lane = 0; word_lane < 4; word_lane++) begin
            if (item.check_words[word_lane]) begin
                bank_id = ((item.addr >> 2) + word_lane) & 3;
                item.banks[bank_id] = 1'b1;
            end
        end
        if (client == 5 && lane_id >= 0 &&
            item.banks != (4'b0001 << lane_id))
            `uvm_error("CLUSTER_MEMORY_BANK", $sformatf(
                "CNM lane=%0d accepted address=0x%08h maps to bank mask=%b",
                lane_id, item.addr, item.banks))
        for (bank_id = 0; bank_id < 4; bank_id++)
            if (item.banks[bank_id]) read_bank_hits[bank_id]++;
        for (bank_id = 0; bank_id < 7; bank_id++)
            if (engines[bank_id]) read_engine_hits[bank_id]++;
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
                    note_mutation_caught("memory_data");
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
        bit [6:0] invalid_done_mask;
        bit [6:0] missing_done_mask;
        bit [6:0] accepted_engine_mask;
        pending_memory_read_t item;
        bit [127:0] actual;
        observations++;
        if (obs.reset_active) begin
            if (!reset_active_previous) memory_epoch++;
            reset_active_previous = 1'b1;
            active_engine_seen = 7'd0;
            error_terminal_pending = 7'd0;
            error_seen = 7'd0;
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
        reset_active_previous = 1'b0;

        if (obs.launch_valid) begin
            case (obs.launch_op)
                8'h10, 8'h11, 8'h12, 8'h13, 8'h14, 8'h15: error_seen[0] = 1'b0;
                8'h50, 8'h51: error_seen[1] = 1'b0;
                8'h20, 8'h21: error_seen[2] = 1'b0;
                8'h30, 8'h31: error_seen[3] = 1'b0;
                8'h32, 8'h33, 8'h34, 8'h35, 8'h36, 8'h37, 8'h38, 8'h39:
                    error_seen[4] = 1'b0;
                8'h16, 8'h17: error_seen[5] = 1'b0;
                8'h43, 8'h44: error_seen[6] = 1'b0;
                default: ;
            endcase
        end

        // Some engines retire an errored operation with a Done pulse one
        // sampled cycle after the error pulse. Preserve that owner-specific
        // terminal window; a bare/unowned Done still fails below.
        invalid_done_mask = obs.engine_done &
                            ~(active_engine_seen | obs.engine_busy |
                              error_terminal_pending);
        if (invalid_done_mask != 0) begin
            invalid_engine_done++;
            note_mutation_caught("engine_done_lifecycle");
            `uvm_error("CLUSTER_DONE_WITHOUT_ACTIVE", $sformatf(
                "engine_done=%07b has no active transaction; busy=%07b previously_active=%07b",
                obs.engine_done, obs.engine_busy, active_engine_seen))
        end
        missing_done_mask = active_engine_seen & ~obs.engine_busy &
                            ~obs.engine_done & ~obs.engine_error;
        if (missing_done_mask != 0) begin
            note_mutation_caught("engine_done_lifecycle");
            `uvm_error("CLUSTER_MISSING_DONE", $sformatf(
                "active engines stopped without done/error: engines=%07b",
                missing_done_mask))
            // Retire the bad observation after reporting it so one missing
            // pulse does not cascade into an error on every later sample.
            active_engine_seen &= ~missing_done_mask;
        end
        error_terminal_pending = obs.engine_error & ~obs.engine_done &
                                 (active_engine_seen | obs.engine_busy |
                                  error_terminal_pending);
        error_terminal_pending &= ~obs.engine_done;
        active_engine_seen |= obs.engine_busy;
        active_engine_seen &= ~(obs.engine_done | obs.engine_error);
        if (obs.multi_engine_abort) begin
            active_engine_seen = 7'd0;
            error_terminal_pending = 7'd0;
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
                if ((mutation_kind == "response_epoch") && (memory_epoch != 0))
                    note_mutation_caught("response_epoch");
                else
                    note_mutation_caught("response_owner_route");
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
                        if (item.epoch != memory_epoch[15:0]) begin
                            stale_epoch_responses++;
                            `uvm_error("CLUSTER_MEMORY_EPOCH", $sformatf(
                                "client=%0d accepted_epoch=%0d current_epoch=%0d addr=0x%08h",
                                item.client, item.epoch, memory_epoch, item.addr))
                        end
                        actual = {obs.banked_rdata[3], obs.banked_rdata[2],
                                  obs.banked_rdata[1], obs.banked_rdata[0]};
                        compare_snapshot(item, actual, 3, -1);
                    end
                end else if (obs.rsp_client == 3'd5) begin
                    cnm_tag_responses++;
                    if (!(|obs.cnm_rsp_valid) || obs.matrix_rsp_valid) begin
                        note_mutation_caught("response_owner_route");
                        `uvm_error("CLUSTER_CNM_RSP_ROUTE", $sformatf("CNM tag routed incorrectly: matrix_valid=%b cnm_valid=%b", obs.matrix_rsp_valid, obs.cnm_rsp_valid))
                    end
                end else begin
                    if (pending_memory_reads[obs.rsp_client].size() == 0)
                        `uvm_error("CLUSTER_MEMORY_ORPHAN", $sformatf("client=%0d response has no memory snapshot", obs.rsp_client))
                    else begin
                        item = pending_memory_reads[obs.rsp_client].pop_front();
                        if (item.epoch != memory_epoch[15:0]) begin
                            stale_epoch_responses++;
                            `uvm_error("CLUSTER_MEMORY_EPOCH", $sformatf(
                                "client=%0d accepted_epoch=%0d current_epoch=%0d addr=0x%08h",
                                item.client, item.epoch, memory_epoch, item.addr))
                        end
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
                        if (item.epoch != memory_epoch[15:0]) begin
                            stale_epoch_responses++;
                            `uvm_error("CLUSTER_MEMORY_EPOCH", $sformatf(
                                "CNM lane=%0d accepted_epoch=%0d current_epoch=%0d addr=0x%08h",
                                lane, item.epoch, memory_epoch, item.addr))
                        end
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
            obs.selected_spad_write && obs.selected_spad_access_ok) begin
            write_model_word(obs.selected_spad_addr, obs.selected_spad_wdata, 4'hf);
            if (obs.request_client == 3'd2) begin
                accepted_engine_mask = obs.engine_req_valid & obs.engine_req_ready;
                if ($countones(accepted_engine_mask) != 1)
                    `uvm_error("CLUSTER_MEMORY_OWNER", $sformatf(
                        "accepted core write must have one engine owner: valid=%07b ready=%07b addr=0x%08h",
                        obs.engine_req_valid, obs.engine_req_ready, obs.selected_spad_addr))
                if (|(accepted_engine_mask & error_seen)) begin
                    note_mutation_caught("write_after_error_prefix");
                    `uvm_error("CLUSTER_WRITE_AFTER_ERROR", $sformatf(
                        "accepted engine write after terminal error: owner=%07b error_seen=%07b addr=0x%08h",
                        accepted_engine_mask, error_seen, obs.selected_spad_addr))
                end
                for (lane = 0; lane < 7; lane++)
                    if (accepted_engine_mask[lane]) write_engine_hits[lane]++;
            end
        end
        if (obs.selected_line_valid && obs.selected_line_ready &&
            obs.selected_line_write && obs.selected_line_access_ok) begin
            if (obs.selected_line_wstrb == 16'hffff)
                full_line_write_masks++;
            else if (obs.selected_line_wstrb == 16'h0000)
                zero_line_write_masks++;
            else
                partial_line_write_masks++;
            if ((obs.request_client == 3'd2) && obs.engine_busy[3] &&
                (obs.selected_line_wstrb != 16'hffff)) begin
                note_mutation_caught("matrix_write_mask");
                `uvm_error("CLUSTER_MATRIX_WSTRB", $sformatf(
                    "Matrix line write mask expected=ffff actual=%04h addr=0x%08h",
                    obs.selected_line_wstrb, obs.selected_line_addr))
            end
            if ((obs.request_client == 3'd2) && obs.engine_busy[3])
                write_engine_hits[3]++;
            if ((obs.request_client == 3'd2) && error_seen[3]) begin
                note_mutation_caught("write_after_error_prefix");
                `uvm_error("CLUSTER_WRITE_AFTER_ERROR", $sformatf(
                    "accepted Matrix line write after terminal error: error_seen=%07b addr=0x%08h",
                    error_seen, obs.selected_line_addr))
            end
            for (lane = 0; lane < 4; lane++)
                write_model_word(obs.selected_line_addr + (lane * 4),
                                 obs.selected_line_wdata[lane*32 +: 32],
                                 obs.selected_line_wstrb[lane*4 +: 4]);
        end

        if (obs.selected_banked_valid && obs.selected_banked_ready &&
            (obs.request_client == 3'd3) &&
            (obs.selected_banked_addr !== obs.matrix_banked_req_addr)) begin
            note_mutation_caught("matrix_request_address");
            `uvm_error("CLUSTER_MATRIX_ADDR", $sformatf(
                "Matrix banked request address mismatch: source=0x%08h selected=0x%08h",
                obs.matrix_banked_req_addr, obs.selected_banked_addr))
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
                        annotate_snapshot(make_read_snapshot(obs.selected_spad_addr,
                            4'b0001, 1'b0, obs.selected_spad_access_ok),
                            client, 7'd0, -1));
                    2, 4: begin
                        accepted_engine_mask = (client == 2) ?
                            (obs.engine_req_valid & obs.engine_req_ready) : 7'd0;
                        if ((client == 2) &&
                            ($countones(accepted_engine_mask) != 1))
                            `uvm_error("CLUSTER_MEMORY_OWNER", $sformatf(
                                "accepted core read must have one engine owner: valid=%07b ready=%07b addr=0x%08h",
                                obs.engine_req_valid, obs.engine_req_ready,
                                obs.selected_spad_addr))
                        if (obs.selected_line_valid && obs.selected_line_ready &&
                            !obs.selected_line_write)
                            pending_memory_reads[client].push_back(
                                annotate_snapshot(make_read_snapshot(obs.selected_line_addr,
                                    4'b1111, 1'b1, obs.selected_line_access_ok),
                                    client, accepted_engine_mask, -1));
                        else
                            pending_memory_reads[client].push_back(
                                annotate_snapshot(make_read_snapshot(obs.selected_spad_addr,
                                    4'b0001, 1'b0, obs.selected_spad_access_ok),
                                    client, accepted_engine_mask, -1));
                    end
                    3: pending_memory_reads[client].push_back(
                        annotate_snapshot(make_read_snapshot(obs.selected_banked_addr,
                            4'b1111, 1'b0, obs.selected_banked_access_ok),
                            client, 7'b0001000, -1));
                    default: ;
                endcase
            end
        end
        for (lane = 0; lane < 4; lane++) begin
            if (obs.cnm_accept_mask[lane]) begin
                cnm_pending_lane_reads[lane]++;
                cnm_lane_accepts[lane]++;
                pending_cnm_lane_reads[lane].push_back(
                    annotate_snapshot(make_read_snapshot(obs.selected_cnm_addr[lane],
                        4'b0001, 1'b0, obs.selected_cnm_access_ok[lane]),
                        5, 7'b0000100, lane));
            end
        end
        error_seen |= obs.engine_error;
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
            "writes=%0d checked_words=%0d mismatches=%0d unknown_reads=%0d epoch=%0d stale_epoch=%0d line_wstrb={full:%0d,partial:%0d,zero:%0d} bank_hits={%0d,%0d,%0d,%0d} engine_read_hits={%0d,%0d,%0d,%0d,%0d,%0d,%0d} engine_write_hits={%0d,%0d,%0d,%0d,%0d,%0d,%0d}",
            memory_model_writes, memory_data_checks,
            memory_data_mismatches, memory_unknown_reads, memory_epoch,
            stale_epoch_responses, full_line_write_masks,
            partial_line_write_masks, zero_line_write_masks,
            read_bank_hits[0], read_bank_hits[1], read_bank_hits[2], read_bank_hits[3],
            read_engine_hits[0], read_engine_hits[1], read_engine_hits[2],
            read_engine_hits[3], read_engine_hits[4], read_engine_hits[5], read_engine_hits[6],
            write_engine_hits[0], write_engine_hits[1], write_engine_hits[2],
            write_engine_hits[3], write_engine_hits[4], write_engine_hits[5],
            write_engine_hits[6]), UVM_LOW)
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
