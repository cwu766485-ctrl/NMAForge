`uvm_analysis_imp_decl(_axil)
`uvm_analysis_imp_decl(_axi4)
class ai_accel_scoreboard extends uvm_component;
    `uvm_component_utils(ai_accel_scoreboard)
    uvm_analysis_imp_axil #(ai_axil_item,ai_accel_scoreboard) axil_imp;
    uvm_analysis_imp_axi4 #(ai_axi4_observed_item,ai_accel_scoreboard) axi4_imp;
    bit allow_error_responses; int unsigned axil_count,axi4_count;

    // Optional V4 mixed-precision path checker. The sequence checks SPAD,
    // both completion entries and DDR readback; this passive checker checks
    // all operand AR/R data and the result AW/W/B traffic independently.
    bit check_mixed_ddr_path;
    bit check_external_macro_fetch;
    int unsigned expected_external_macro_fetch_count;
    int unsigned external_macro_fetch_count;
    int unsigned external_macro_read_beats;
    int unsigned external_macro_read_beat;
    ai_mixed_precision_vector_plan mixed_vector_plan;
    ai_accel_reference_model mixed_reference_model;
    bit fp16_a_ar_seen, fp16_b_ar_seen;
    bit bf16_a_ar_seen, bf16_b_ar_seen;
    bit int8_a_ar_seen, int8_b_ar_seen;
    bit fp16_y_aw_seen, bf16_y_aw_seen, int8_y_aw_seen;
    bit narrow_axi_read_ar_seen, narrow_axi_write_aw_seen;
    int unsigned dot_r_count, dot_w_count, dot_b_count;
    bit expect_dma_read_error;
    bit dma_error_ar_pending;
    bit [3:0] dma_error_expected_rid;
    int unsigned dma_error_ar_count;
    int unsigned dma_error_r_count;
    int unsigned dma_error_expected_beats;
    int unsigned dma_error_active_beats;
    bit dma_error_current_error_seen;
    covergroup dma_error_position_cg with function sample(bit error_on_last_beat);
        option.per_instance = 1;
        cp_error_position: coverpoint error_on_last_beat {
            bins before_burst_last = {0};
            bins on_burst_last = {1};
        }
    endgroup
    bit dma_reset_probe_ar_seen;
    bit dma_reset_probe_aw_seen;
    bit ddr_reset_recovery_ar_seen;
    bit [127:0] dot_expected_rdata_q[$];
    bit [127:0] dot_expected_rmask_q[$];
    bit [3:0] dot_expected_rid_q[$];
    bit [3:0] dot_expected_bid_q[$];
    bit [31:0] dot_expected_wdata_q[$];
    bit [1:0] dot_expected_wlane_q[$];

    function new(string name,uvm_component parent);
        super.new(name,parent);
        axil_imp=new("axil_imp",this);
        axi4_imp=new("axi4_imp",this);
        dma_error_position_cg = new;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        void'(uvm_config_db#(bit)::get(this, "", "check_mixed_ddr_path", check_mixed_ddr_path));
        void'(uvm_config_db#(bit)::get(this, "", "check_external_macro_fetch", check_external_macro_fetch));
        void'(uvm_config_db#(int unsigned)::get(this, "", "expected_external_macro_fetch_count", expected_external_macro_fetch_count));
        void'(uvm_config_db#(bit)::get(this, "", "expect_dma_read_error", expect_dma_read_error));
        void'(uvm_config_db#(bit)::get(this, "", "allow_error_responses", allow_error_responses));
        if (check_mixed_ddr_path) begin
            if (!uvm_config_db#(ai_mixed_precision_vector_plan)::get(this, "", "mixed_vector_plan", mixed_vector_plan))
                `uvm_fatal("MIXED_E2E_PLAN", "mixed DDR checker requires the randomized vector plan")
            mixed_reference_model = ai_accel_reference_model::type_id::create("mixed_reference_model");
        end
        if (check_external_macro_fetch && expected_external_macro_fetch_count == 0)
            `uvm_fatal("MACRO_E2E_AXI", "external macro checker requires a nonzero expected descriptor count")
    endfunction

    function void write_axil(ai_axil_item tr); axil_count++; if((tr.resp!=0)&&!allow_error_responses) `uvm_error("AXIL_RESP",$sformatf("Unexpected AXI-Lite response addr=0x%08h resp=%0h",tr.addr,tr.resp)) endfunction
    function void write_axi4(ai_axi4_observed_item tr);
        bit [127:0] expected_rdata;
        bit [127:0] expected_rmask;
        bit [31:0] expected_wdata;
        bit [1:0] expected_wlane;
        bit [3:0] expected_rid;
        bit [3:0] expected_bid;
        bit dma_error_transfer_ar;
        axi4_count++;
        if((tr.kind==AXI_AR||tr.kind==AXI_AW)&&((tr.size!=3'd2&&tr.size!=3'd4)||tr.burst!=2'b01)) `uvm_error("AXI_CFG",$sformatf("Unsupported AXI request size=%0d burst=%0d",tr.size,tr.burst))
        if((tr.kind==AXI_R||tr.kind==AXI_B)&&(tr.resp!=0)&&!allow_error_responses) `uvm_error("AXI_RESP",$sformatf("Unexpected AXI response id=%0d resp=%0h",tr.id,tr.resp))

        if (check_external_macro_fetch) begin
            case (tr.kind)
                AXI_AR: begin
                    if ((tr.id != 4'd0) ||
                        (tr.addr != (64'h0000_0001_0000_1000 +
                                     (external_macro_fetch_count << 6))) ||
                        (tr.len != 8'd3) || (tr.size != 3'd4) ||
                        (tr.burst != 2'b01)) begin
                        `uvm_error("MACRO_E2E_AXI_AR",
                            $sformatf("unexpected external child descriptor AR index=%0d id=%0d addr=0x%016h len=%0d size=%0d burst=%0d",
                                external_macro_fetch_count, tr.id, tr.addr,
                                tr.len, tr.size, tr.burst))
                    end
                    external_macro_fetch_count++;
                end
                AXI_R: begin
                    if ((tr.id != 4'd0) || (tr.resp != 2'b00) ||
                        (external_macro_read_beat >= 4) ||
                        (tr.last != (external_macro_read_beat == 3))) begin
                        `uvm_error("MACRO_E2E_AXI_R",
                            $sformatf("bad child descriptor response beat=%0d id=%0d resp=%0h last=%0b",
                                external_macro_read_beat, tr.id, tr.resp, tr.last))
                    end
                    external_macro_read_beats++;
                    if (external_macro_read_beat == 3)
                        external_macro_read_beat = 0;
                    else
                        external_macro_read_beat++;
                end
                default: begin
                    `uvm_error("MACRO_E2E_AXI",
                        $sformatf("unexpected payload/write AXI traffic kind=%0d during descriptor-only macro test", tr.kind))
                end
            endcase
        end

        if (check_mixed_ddr_path) begin
            case (tr.kind)
                AXI_AR: begin
                    dma_error_transfer_ar = expect_dma_read_error &&
                        ((tr.addr == 64'h0000_0000_0000_1a90) ||
                         (tr.addr == 64'h0000_0000_0000_1ab0));
                    if (tr.addr == MIXED_E2E_NARROW_DDR_READ_ADDR) begin
                        if ((tr.size != 3'd2) || (tr.len != 0) ||
                            (tr.burst != 2'b01))
                            `uvm_error("MIXED_E2E_AXI_AR", $sformatf("unexpected narrow-32 INCR read shape, addr=0x%h size=%0d len=%0d burst=%0d", tr.addr, tr.size, tr.len, tr.burst))
                        if (narrow_axi_read_ar_seen)
                            `uvm_error("MIXED_E2E_AXI_AR", "duplicate narrow-32 read")
                        narrow_axi_read_ar_seen = 1'b1;
                        dot_expected_rdata_q.push_back({64'd0, MIXED_E2E_NARROW_DATA, 32'd0});
                        dot_expected_rmask_q.push_back({64'd0, 32'hffff_ffff, 32'd0});
                        dot_expected_rid_q.push_back(tr.id);
                    end else begin
                        if ((tr.size != 3'd4) || (tr.burst != 2'b01) ||
                            (dma_error_transfer_ar ? (tr.len != 1) : (tr.len != 0)))
                            `uvm_error("MIXED_E2E_AXI_AR", $sformatf("unexpected 128-bit INCR read shape, addr=0x%h size=%0d len=%0d burst=%0d", tr.addr, tr.size, tr.len, tr.burst))
                        case (tr.addr)
                        64'h0000_0000_0000_1a00: begin
                            if (fp16_a_ar_seen) `uvm_error("MIXED_E2E_AXI_AR", "duplicate FP16 operand-A DDR read")
                            fp16_a_ar_seen = 1'b1;
                            dot_expected_rdata_q.push_back({64'd0, mixed_vector_plan.fp16_a_word(1), mixed_vector_plan.fp16_a_word(0)});
                            dot_expected_rmask_q.push_back({64'd0, (mixed_vector_plan.fp16_length > 2) ? 32'hffff_ffff : 32'd0, 32'hffff_ffff});
                            dot_expected_rid_q.push_back(tr.id);
                        end
                        64'h0000_0000_0000_1a10: begin
                            if (fp16_b_ar_seen) `uvm_error("MIXED_E2E_AXI_AR", "duplicate FP16 operand-B DDR read")
                            fp16_b_ar_seen = 1'b1;
                            dot_expected_rdata_q.push_back({64'd0, mixed_vector_plan.fp16_b_word(1), mixed_vector_plan.fp16_b_word(0)});
                            dot_expected_rmask_q.push_back({64'd0, (mixed_vector_plan.fp16_length > 2) ? 32'hffff_ffff : 32'd0, 32'hffff_ffff});
                            dot_expected_rid_q.push_back(tr.id);
                        end
                        64'h0000_0000_0000_1a30: begin
                            if (bf16_a_ar_seen) `uvm_error("MIXED_E2E_AXI_AR", "duplicate BF16 operand-A DDR read")
                            bf16_a_ar_seen = 1'b1;
                            dot_expected_rdata_q.push_back({64'd0, mixed_vector_plan.bf16_a_word(1), mixed_vector_plan.bf16_a_word(0)});
                            dot_expected_rmask_q.push_back({64'd0, (mixed_vector_plan.bf16_length > 2) ? 32'hffff_ffff : 32'd0, 32'hffff_ffff});
                            dot_expected_rid_q.push_back(tr.id);
                        end
                        64'h0000_0000_0000_1a40: begin
                            if (bf16_b_ar_seen) `uvm_error("MIXED_E2E_AXI_AR", "duplicate BF16 operand-B DDR read")
                            bf16_b_ar_seen = 1'b1;
                            dot_expected_rdata_q.push_back({64'd0, mixed_vector_plan.bf16_b_word(1), mixed_vector_plan.bf16_b_word(0)});
                            dot_expected_rmask_q.push_back({64'd0, (mixed_vector_plan.bf16_length > 2) ? 32'hffff_ffff : 32'd0, 32'hffff_ffff});
                            dot_expected_rid_q.push_back(tr.id);
                        end
                        64'h0000_0000_0000_1a60: begin
                            if (int8_a_ar_seen) `uvm_error("MIXED_E2E_AXI_AR", "duplicate INT8 operand-A DDR read")
                            int8_a_ar_seen = 1'b1;
                            dot_expected_rdata_q.push_back({96'd0, mixed_vector_plan.int8_a_word()});
                            dot_expected_rmask_q.push_back({96'd0, 32'hffff_ffff});
                            dot_expected_rid_q.push_back(tr.id);
                        end
                        64'h0000_0000_0000_1a70: begin
                            if (int8_b_ar_seen) `uvm_error("MIXED_E2E_AXI_AR", "duplicate INT8 operand-B DDR read")
                            int8_b_ar_seen = 1'b1;
                            dot_expected_rdata_q.push_back({96'd0, mixed_vector_plan.int8_b_word()});
                            dot_expected_rmask_q.push_back({96'd0, 32'hffff_ffff});
                            dot_expected_rid_q.push_back(tr.id);
                        end
                        64'h0000_0000_0000_1a90,
                        64'h0000_0000_0000_1ab0: begin
                            if (!expect_dma_read_error || dma_error_ar_pending ||
                                (dma_error_ar_count >= 2))
                                `uvm_error("MIXED_E2E_AXI_AR", $sformatf("unexpected/duplicate injected-error read address 0x%h", tr.addr))
                            else begin
                                dma_error_ar_pending = 1'b1;
                                dma_error_expected_rid = tr.id;
                                dma_error_ar_count++;
                                dma_error_expected_beats = tr.len + 1;
                                dma_error_active_beats = 0;
                                dma_error_current_error_seen = 1'b0;
                            end
                        end
                        64'h0000_0000_0000_1aa0: begin
                            if (dma_reset_probe_ar_seen)
                                `uvm_error("MIXED_E2E_AXI_AR", "duplicate in-flight-reset probe read")
                            dma_reset_probe_ar_seen = 1'b1;
                        end
                        64'h0000_0000_0000_1ad0: begin
                            if (ddr_reset_recovery_ar_seen)
                                `uvm_error("MIXED_E2E_AXI_AR", "duplicate DDR recovery read after accelerator-only reset")
                            ddr_reset_recovery_ar_seen = 1'b1;
                            dot_expected_rdata_q.push_back({96'd0, 32'hdada_5511});
                            dot_expected_rmask_q.push_back({96'd0, 32'hffff_ffff});
                            dot_expected_rid_q.push_back(tr.id);
                        end
                            default: `uvm_error("MIXED_E2E_AXI_AR", $sformatf("unexpected DDR read address 0x%h", tr.addr))
                        endcase
                    end
                end
                AXI_R: begin
                    if (dma_error_ar_pending && (tr.id == dma_error_expected_rid)) begin
                        dma_error_active_beats++;
                        if (tr.resp == 2'b10) begin
                            dma_error_r_count++;
                            if (dma_error_current_error_seen)
                                `uvm_error("MIXED_E2E_AXI_R", "injected DMA burst returned more than one SLVERR beat")
                            dma_error_current_error_seen = 1'b1;
                            dma_error_position_cg.sample(tr.last);
                        end
                        if (tr.last) begin
                            if (!dma_error_current_error_seen)
                                `uvm_error("MIXED_E2E_AXI_R", "injected DMA burst drained to RLAST without the expected SLVERR")
                            if (dma_error_active_beats != dma_error_expected_beats)
                                `uvm_error("MIXED_E2E_AXI_R", $sformatf("injected DMA burst response count expected=%0d actual=%0d", dma_error_expected_beats, dma_error_active_beats))
                            dma_error_ar_pending = 1'b0;
                            dma_error_expected_beats = 0;
                            dma_error_active_beats = 0;
                            dma_error_current_error_seen = 1'b0;
                        end
                    end else if ((dot_expected_rdata_q.size() == 0) ||
                        (dot_expected_rid_q.size() == 0) ||
                        (dot_expected_rmask_q.size() == 0)) begin
                        `uvm_error("MIXED_E2E_AXI_R", $sformatf("read response without expected request, data=0x%08h", tr.data[31:0]))
                    end else begin
                        expected_rdata = dot_expected_rdata_q.pop_front();
                        expected_rmask = dot_expected_rmask_q.pop_front();
                        expected_rid = dot_expected_rid_q.pop_front();
                        dot_r_count++;
                        if (!tr.last || (tr.id != expected_rid) ||
                            ((tr.data & expected_rmask) !== (expected_rdata & expected_rmask)) ||
                            (tr.resp != 2'b00))
                            `uvm_error("MIXED_E2E_AXI_R", $sformatf("operand read expected id=%0d data=0x%032h mask=0x%032h resp=OKAY actual id=%0d data=0x%032h resp=%0h last=%0b", expected_rid, expected_rdata, expected_rmask, tr.id, tr.data, tr.resp, tr.last))
                    end
                end
                AXI_AW: begin
                    if (tr.addr == 64'h0000_0000_0000_1aa0) begin
                        if ((tr.size != 3'd4) || (tr.len != 0) ||
                            (tr.burst != 2'b01))
                            `uvm_error("MIXED_E2E_AXI_AW", $sformatf("expected reset-probe single 128-bit INCR beat, addr=0x%h size=%0d len=%0d burst=%0d", tr.addr, tr.size, tr.len, tr.burst))
                        if (dma_reset_probe_aw_seen)
                            `uvm_error("MIXED_E2E_AXI_AW", "duplicate reset-probe DMA write")
                        dma_reset_probe_aw_seen = 1'b1;
                        // This write's B response is deliberately interrupted
                        // by the coordinated reset. Track its accepted W data
                        // but do not enqueue an expected B, so any old-epoch B
                        // observed after reset is reported as an orphan.
                        dot_expected_wdata_q.push_back(32'hbadd_1eaf);
                        dot_expected_wlane_q.push_back(tr.addr[3:2]);
                    end else if (tr.addr == MIXED_E2E_NARROW_DDR_WRITE_ADDR) begin
                        if ((tr.size != 3'd2) || (tr.len != 0) ||
                            (tr.burst != 2'b01))
                            `uvm_error("MIXED_E2E_AXI_AW", $sformatf("expected single narrow-32 INCR write, addr=0x%h size=%0d len=%0d burst=%0d", tr.addr, tr.size, tr.len, tr.burst))
                        if (narrow_axi_write_aw_seen)
                            `uvm_error("MIXED_E2E_AXI_AW", "duplicate narrow-32 write")
                        narrow_axi_write_aw_seen = 1'b1;
                        dot_expected_bid_q.push_back(tr.id);
                        dot_expected_wdata_q.push_back(MIXED_E2E_NARROW_DATA);
                        dot_expected_wlane_q.push_back(tr.addr[3:2]);
                    end else begin
                        if ((tr.size != 3'd4) || (tr.len != 0) ||
                            (tr.burst != 2'b01))
                            `uvm_error("MIXED_E2E_AXI_AW", $sformatf("expected single 128-bit INCR write, addr=0x%h size=%0d len=%0d burst=%0d", tr.addr, tr.size, tr.len, tr.burst))
                    case (tr.addr)
                        64'h0000_0000_0000_1a20: begin
                            if (fp16_y_aw_seen) `uvm_error("MIXED_E2E_AXI_AW", "duplicate FP16 result DDR write")
                            fp16_y_aw_seen = 1'b1;
                            dot_expected_bid_q.push_back(tr.id);
                            dot_expected_wdata_q.push_back(mixed_reference_model.predict_small_integer_dot(
                                mixed_vector_plan.fp16_a0, mixed_vector_plan.fp16_a1,
                                mixed_vector_plan.fp16_a2, mixed_vector_plan.fp16_a3,
                                mixed_vector_plan.fp16_b0, mixed_vector_plan.fp16_b1,
                                mixed_vector_plan.fp16_b2, mixed_vector_plan.fp16_b3,
                                mixed_vector_plan.fp16_length));
                            dot_expected_wlane_q.push_back(tr.addr[3:2]);
                        end
                        64'h0000_0000_0000_1a50: begin
                            if (bf16_y_aw_seen) `uvm_error("MIXED_E2E_AXI_AW", "duplicate BF16 result DDR write")
                            bf16_y_aw_seen = 1'b1;
                            dot_expected_bid_q.push_back(tr.id);
                            dot_expected_wdata_q.push_back(mixed_reference_model.predict_small_integer_dot(
                                mixed_vector_plan.bf16_a0, mixed_vector_plan.bf16_a1,
                                mixed_vector_plan.bf16_a2, mixed_vector_plan.bf16_a3,
                                mixed_vector_plan.bf16_b0, mixed_vector_plan.bf16_b1,
                                mixed_vector_plan.bf16_b2, mixed_vector_plan.bf16_b3,
                                mixed_vector_plan.bf16_length));
                            dot_expected_wlane_q.push_back(tr.addr[3:2]);
                        end
                        64'h0000_0000_0000_1a80: begin
                            if (int8_y_aw_seen) `uvm_error("MIXED_E2E_AXI_AW", "duplicate INT8 result DDR write")
                            int8_y_aw_seen = 1'b1;
                            dot_expected_bid_q.push_back(tr.id);
                            dot_expected_wdata_q.push_back(mixed_reference_model.predict_int8_dot4(
                                mixed_vector_plan.int8_a0, mixed_vector_plan.int8_a1,
                                mixed_vector_plan.int8_a2, mixed_vector_plan.int8_a3,
                                mixed_vector_plan.int8_b0, mixed_vector_plan.int8_b1,
                                mixed_vector_plan.int8_b2, mixed_vector_plan.int8_b3));
                            dot_expected_wlane_q.push_back(tr.addr[3:2]);
                        end
                        default: `uvm_error("MIXED_E2E_AXI_AW", $sformatf("unexpected result DDR address 0x%h", tr.addr))
                    endcase
                    end
                end
                AXI_W: begin
                    dot_w_count++;
                    if (dot_expected_wdata_q.size() == 0) begin
                        `uvm_error("MIXED_E2E_AXI_W", "write data observed without a predicted AW transaction")
                    end else begin
                        expected_wdata = dot_expected_wdata_q.pop_front();
                        if (dot_expected_wlane_q.size() == 0) begin
                            `uvm_error("MIXED_E2E_AXI_W", "write data observed without an expected byte lane")
                        end else begin
                            expected_wlane = dot_expected_wlane_q.pop_front();
                            case (expected_wlane)
                                2'd0: if ((tr.data[31:0] !== expected_wdata) || (tr.strb[3:0] != 4'hf))
                                    `uvm_error("MIXED_E2E_AXI_W", $sformatf("lane0 expected=0x%08h strb=f actual data=0x%08h strb=%04h", expected_wdata, tr.data[31:0], tr.strb))
                                2'd1: if ((tr.data[63:32] !== expected_wdata) || (tr.strb[7:4] != 4'hf))
                                    `uvm_error("MIXED_E2E_AXI_W", $sformatf("lane1 expected=0x%08h strb=f actual data=0x%08h strb=%04h", expected_wdata, tr.data[63:32], tr.strb))
                                2'd2: if ((tr.data[95:64] !== expected_wdata) || (tr.strb[11:8] != 4'hf))
                                    `uvm_error("MIXED_E2E_AXI_W", $sformatf("lane2 expected=0x%08h strb=f actual data=0x%08h strb=%04h", expected_wdata, tr.data[95:64], tr.strb))
                                default: if ((tr.data[127:96] !== expected_wdata) || (tr.strb[15:12] != 4'hf))
                                    `uvm_error("MIXED_E2E_AXI_W", $sformatf("lane3 expected=0x%08h strb=f actual data=0x%08h strb=%04h", expected_wdata, tr.data[127:96], tr.strb))
                            endcase
                            if (!tr.last)
                                `uvm_error("MIXED_E2E_AXI_W", "single-beat result write did not assert WLAST")
                        end
                    end
                end
                AXI_B: begin
                    if (dot_expected_bid_q.size() == 0) begin
                        `uvm_error("MIXED_E2E_AXI_B", $sformatf("write response without expected AW id=%0d", tr.id))
                    end else begin
                        expected_bid = dot_expected_bid_q.pop_front();
                        if (tr.id != expected_bid)
                            `uvm_error("MIXED_E2E_AXI_B", $sformatf("write response ID mismatch expected=%0d actual=%0d", expected_bid, tr.id))
                        if (tr.resp != 2'b00)
                            `uvm_error("MIXED_E2E_AXI_B", $sformatf("result write expected OKAY, id=%0d resp=%0h", tr.id, tr.resp))
                        dot_b_count++;
                    end
                end
                default: ;
            endcase
        end
    endfunction

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("SB_SUMMARY",$sformatf("observed AXI-Lite=%0d AXI4=%0d",axil_count,axi4_count),UVM_LOW)
        if (check_mixed_ddr_path) begin
            if (!fp16_a_ar_seen || !fp16_b_ar_seen ||
                !bf16_a_ar_seen || !bf16_b_ar_seen ||
                !int8_a_ar_seen || !int8_b_ar_seen ||
                (dot_r_count != 8) || (dot_expected_rdata_q.size() != 0) ||
                (dot_expected_rmask_q.size() != 0) ||
                (dot_expected_rid_q.size() != 0) || !fp16_y_aw_seen ||
                !bf16_y_aw_seen || !int8_y_aw_seen || !narrow_axi_read_ar_seen ||
                !narrow_axi_write_aw_seen || (dot_w_count != 5) || (dot_b_count != 4) ||
                (dot_expected_bid_q.size() != 0) || (dot_expected_wdata_q.size() != 0) ||
                (dot_expected_wlane_q.size() != 0) ||
                (expect_dma_read_error &&
                 (dma_error_ar_count != 2 || dma_error_r_count != 2 || dma_error_ar_pending ||
                  dma_error_position_cg.get_coverage() != 100.0)) ||
                !dma_reset_probe_ar_seen || !dma_reset_probe_aw_seen ||
                !ddr_reset_recovery_ar_seen)
                `uvm_error("MIXED_E2E_AXI_SUMMARY", $sformatf("incomplete mixed DDR path FP16_AR=%0b/%0b BF16_AR=%0b/%0b INT8_AR=%0b/%0b R=%0d W=%0d B=%0d pending_R=%0d pending_B=%0d AW=%0b/%0b/%0b DMA_ERR_R=%0d pending_err=%0b DMA_RESET_AR=%0b DMA_RESET_AW=%0b DDR_RESET_RECOVERY_AR=%0b", fp16_a_ar_seen, fp16_b_ar_seen, bf16_a_ar_seen, bf16_b_ar_seen, int8_a_ar_seen, int8_b_ar_seen, dot_r_count, dot_w_count, dot_b_count, dot_expected_rdata_q.size(), dot_expected_bid_q.size(), fp16_y_aw_seen, bf16_y_aw_seen, int8_y_aw_seen, dma_error_r_count, dma_error_ar_pending, dma_reset_probe_ar_seen, dma_reset_probe_aw_seen, ddr_reset_recovery_ar_seen))
            else
                `uvm_info("MIXED_E2E_AXI_SUMMARY", $sformatf("checked six operand reads, one post-reset recovery read, one narrow-32 read, three result writes, one narrow-32 write, two two-beat DMA SLVERR bursts count=%0d, plus reset-interrupted DMA AR and AW/W with no old B response", dma_error_r_count), UVM_LOW)
        end
        if (check_external_macro_fetch) begin
            if ((external_macro_fetch_count != expected_external_macro_fetch_count) ||
                (external_macro_read_beats != expected_external_macro_fetch_count * 4) ||
                (external_macro_read_beat != 0)) begin
                `uvm_error("MACRO_E2E_AXI_SUMMARY",
                    $sformatf("expected %0d four-beat external descriptors; AR=%0d R=%0d partial_beat=%0d",
                        expected_external_macro_fetch_count, external_macro_fetch_count,
                        external_macro_read_beats, external_macro_read_beat))
            end else begin
                `uvm_info("MACRO_AXI_DESC_FETCH_PASS",
                    $sformatf("external descriptors=%0d AXI ID=0, addresses start at 0x0000000100001000, beats=%0d",
                        external_macro_fetch_count, external_macro_read_beats), UVM_LOW)
            end
        end
    endfunction
endclass
