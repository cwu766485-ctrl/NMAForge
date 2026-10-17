`timescale 1ns / 1ps

module ai_accel_sva #(
    parameter integer MAX_TASK_CYCLES = 2000,
    parameter integer M_AXI_ADDR_WIDTH = 64
)(
    input wire        clk,
    input wire        resetn,

    input wire [31:0] s_axi_awaddr,
    input wire        s_axi_awvalid,
    input wire        s_axi_awready,
    input wire [31:0] s_axi_wdata,
    input wire [3:0]  s_axi_wstrb,
    input wire        s_axi_wvalid,
    input wire        s_axi_wready,
    input wire [1:0]  s_axi_bresp,
    input wire        s_axi_bvalid,
    input wire        s_axi_bready,
    input wire [31:0] s_axi_araddr,
    input wire        s_axi_arvalid,
    input wire        s_axi_arready,
    input wire [31:0] s_axi_rdata,
    input wire [1:0]  s_axi_rresp,
    input wire        s_axi_rvalid,
    input wire        s_axi_rready,

    input wire [M_AXI_ADDR_WIDTH-1:0] m_axi_araddr,
    input wire [7:0]  m_axi_arlen,
    input wire [2:0]  m_axi_arsize,
    input wire [1:0]  m_axi_arburst,
    input wire        m_axi_arvalid,
    input wire        m_axi_arready,
    input wire [1:0]  m_axi_rresp,
    input wire        m_axi_rvalid,
    input wire        m_axi_rlast,
    input wire        m_axi_rready,
    input wire [M_AXI_ADDR_WIDTH-1:0] m_axi_awaddr,
    input wire [7:0]  m_axi_awlen,
    input wire        m_axi_awvalid,
    input wire        m_axi_awready,
    input wire [127:0] m_axi_wdata,
    input wire [15:0]  m_axi_wstrb,
    input wire        m_axi_wlast,
    input wire        m_axi_wvalid,
    input wire        m_axi_wready,
    input wire [1:0]  m_axi_bresp,
    input wire        m_axi_bvalid,
    input wire        m_axi_bready,
    // Zero means the legacy single-read window.  The A4 DMA register clamps
    // programmed values to one through four transactions.
    input wire [2:0]  dma_read_outstanding_cfg,
    input wire        allow_m_axi_error,

    input wire        doorbell_pulse,
    input wire        desc_busy,
    input wire [31:0] desc_base,
    input wire        host_valid,
    input wire        host_write,
    input wire [31:0] host_addr,
    input wire        core_busy,
    input wire        core_done,
    input wire        core_error,
    // A doorbell may launch a descriptor, DMA-only, or macro command that
    // never raises a compute-core pulse.  The command processor's event is
    // therefore the architectural completion point for the task watchdog.
    input wire        processor_event_valid
);

    reg [31:0] awaddr_hold_r;
    reg [31:0] wdata_hold_r;
    reg [3:0]  wstrb_hold_r;
    reg [31:0] araddr_hold_r;
    reg [31:0] rdata_hold_r;
    reg [1:0]  rresp_hold_r;
    reg [1:0]  bresp_hold_r;
    reg [M_AXI_ADDR_WIDTH-1:0] m_araddr_hold_r;
    reg [7:0]  m_arlen_hold_r;
    reg [M_AXI_ADDR_WIDTH-1:0] m_awaddr_hold_r;
    reg [7:0]  m_awlen_hold_r;
    reg [127:0] m_wdata_hold_r;
    reg [15:0]  m_wstrb_hold_r;
    reg        m_wlast_hold_r;
    reg        aw_hold_valid_r;
    reg        w_hold_valid_r;
    reg        ar_hold_valid_r;
    reg        m_ar_hold_valid_r;
    reg        m_aw_hold_valid_r;
    reg        m_w_hold_valid_r;
    reg        r_hold_valid_r;
    reg        b_hold_valid_r;
    reg        task_pending_r;
    reg [31:0] task_timer_r;
    reg [2:0]  m_read_outstanding_r;

    wire host_desc_conflict;

    assign host_desc_conflict = desc_busy && host_valid && host_write &&
                                (host_addr >= desc_base) &&
                                (host_addr < (desc_base + 32'd64));

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            awaddr_hold_r <= 32'd0;
            wdata_hold_r  <= 32'd0;
            wstrb_hold_r  <= 4'd0;
            araddr_hold_r <= 32'd0;
            rdata_hold_r  <= 32'd0;
            rresp_hold_r  <= 2'd0;
            bresp_hold_r  <= 2'd0;
            m_araddr_hold_r <= {M_AXI_ADDR_WIDTH{1'b0}};
            m_arlen_hold_r <= 8'd0;
            m_awaddr_hold_r <= {M_AXI_ADDR_WIDTH{1'b0}};
            m_awlen_hold_r <= 8'd0;
            m_wdata_hold_r <= 128'd0;
            m_wstrb_hold_r <= 16'd0;
            m_wlast_hold_r <= 1'b0;
            aw_hold_valid_r <= 1'b0;
            w_hold_valid_r <= 1'b0;
            ar_hold_valid_r <= 1'b0;
            m_ar_hold_valid_r <= 1'b0;
            m_aw_hold_valid_r <= 1'b0;
            m_w_hold_valid_r <= 1'b0;
            r_hold_valid_r <= 1'b0;
            b_hold_valid_r <= 1'b0;
            task_pending_r <= 1'b0;
            task_timer_r <= 32'd0;
            m_read_outstanding_r <= 3'd0;
        end else begin
            if (s_axi_awvalid && !s_axi_awready) begin
                if (!aw_hold_valid_r) begin
                    awaddr_hold_r <= s_axi_awaddr;
                    aw_hold_valid_r <= 1'b1;
                end else if (s_axi_awaddr !== awaddr_hold_r) begin
                    $fatal(1, "SVA FAIL: AWADDR changed while AWVALID waited for AWREADY");
                end
            end else begin
                if (s_axi_awvalid && s_axi_awready)
                    awaddr_hold_r <= s_axi_awaddr;
                aw_hold_valid_r <= 1'b0;
            end

            if (s_axi_wvalid && !s_axi_wready) begin
                if (!w_hold_valid_r) begin
                    wdata_hold_r <= s_axi_wdata;
                    wstrb_hold_r <= s_axi_wstrb;
                    w_hold_valid_r <= 1'b1;
                end else if ((s_axi_wdata !== wdata_hold_r) || (s_axi_wstrb !== wstrb_hold_r)) begin
                    $fatal(1, "SVA FAIL: WDATA/WSTRB changed while WVALID waited for WREADY");
                end
            end else begin
                if (s_axi_wvalid && s_axi_wready) begin
                    wdata_hold_r <= s_axi_wdata;
                    wstrb_hold_r <= s_axi_wstrb;
                end
                w_hold_valid_r <= 1'b0;
            end

            if (s_axi_arvalid && !s_axi_arready) begin
                if (!ar_hold_valid_r) begin
                    araddr_hold_r <= s_axi_araddr;
                    ar_hold_valid_r <= 1'b1;
                end else if (s_axi_araddr !== araddr_hold_r) begin
                    $fatal(1, "SVA FAIL: ARADDR changed while ARVALID waited for ARREADY");
                end
            end else begin
                if (s_axi_arvalid && s_axi_arready)
                    araddr_hold_r <= s_axi_araddr;
                ar_hold_valid_r <= 1'b0;
            end

            if (s_axi_bvalid && !s_axi_bready) begin
                if (!b_hold_valid_r) begin
                    bresp_hold_r <= s_axi_bresp;
                    b_hold_valid_r <= 1'b1;
                end else if (s_axi_bresp !== bresp_hold_r) begin
                    $fatal(1, "SVA FAIL: BRESP changed while BVALID waited for BREADY");
                end
            end else if (s_axi_bvalid && s_axi_bready) begin
                bresp_hold_r <= s_axi_bresp;
                b_hold_valid_r <= 1'b0;
            end else begin
                b_hold_valid_r <= 1'b0;
            end

            if (s_axi_rvalid && !s_axi_rready) begin
                if (!r_hold_valid_r) begin
                    rdata_hold_r <= s_axi_rdata;
                    rresp_hold_r <= s_axi_rresp;
                    r_hold_valid_r <= 1'b1;
                end else if ((s_axi_rdata !== rdata_hold_r) || (s_axi_rresp !== rresp_hold_r)) begin
                    $fatal(1, "SVA FAIL: RDATA/RRESP changed while RVALID waited for RREADY");
                end
            end else if (s_axi_rvalid && s_axi_rready) begin
                rdata_hold_r <= s_axi_rdata;
                rresp_hold_r <= s_axi_rresp;
                r_hold_valid_r <= 1'b0;
            end else begin
                r_hold_valid_r <= 1'b0;
            end

            if (m_axi_arvalid && !m_axi_arready) begin
                if (!m_ar_hold_valid_r) begin
                    m_araddr_hold_r <= m_axi_araddr;
                    m_arlen_hold_r <= m_axi_arlen;
                    m_ar_hold_valid_r <= 1'b1;
                end else if ((m_axi_araddr !== m_araddr_hold_r) ||
                             (m_axi_arlen !== m_arlen_hold_r)) begin
                    $fatal(1, "SVA FAIL: M_AXI AR changed while waiting for ARREADY");
                end
            end else begin
                m_ar_hold_valid_r <= 1'b0;
            end

            // A5 compatibility DMA uses 32-bit INCR beats; A6 descriptor and
            // tagged DMA use 128-bit INCR beats. Reject other sizes and
            // preserve the AXI 4KiB boundary rule for either ABI.
            if (m_axi_arvalid && m_axi_arready) begin
                if ((m_axi_arsize != 3'd2 && m_axi_arsize != 3'd4) ||
                    m_axi_arburst != 2'b01)
                    $fatal(1, "SVA FAIL: M_AXI AR must be 32-bit or 128-bit INCR");
                if ({1'b0, m_axi_araddr[11:0]} +
                    (({4'd0, m_axi_arlen} + 12'd1) << m_axi_arsize) > 13'd4096)
                    $fatal(1, "SVA FAIL: M_AXI AR burst crosses a 4KiB boundary");
            end

            case ({m_axi_arvalid && m_axi_arready,
                   m_axi_rvalid && m_axi_rready && m_axi_rlast})
              2'b10: m_read_outstanding_r <= m_read_outstanding_r + 3'd1;
              2'b01: begin
                  if (m_read_outstanding_r == 3'd0)
                      $fatal(1, "SVA FAIL: M_AXI RLAST arrived without an accepted AR");
                  m_read_outstanding_r <= m_read_outstanding_r - 3'd1;
              end
              default: m_read_outstanding_r <= m_read_outstanding_r;
            endcase

            if (m_read_outstanding_r >
                ((dma_read_outstanding_cfg == 3'd0) ? 3'd1 : dma_read_outstanding_cfg))
                $fatal(1, "SVA FAIL: M_AXI read outstanding window exceeded configuration");

            if (m_axi_awvalid && !m_axi_awready) begin
                if (!m_aw_hold_valid_r) begin
                    m_awaddr_hold_r <= m_axi_awaddr;
                    m_awlen_hold_r <= m_axi_awlen;
                    m_aw_hold_valid_r <= 1'b1;
                end else if ((m_axi_awaddr !== m_awaddr_hold_r) ||
                             (m_axi_awlen !== m_awlen_hold_r)) begin
                    $fatal(1, "SVA FAIL: M_AXI AW changed while waiting for AWREADY");
                end
            end else begin
                m_aw_hold_valid_r <= 1'b0;
            end

            if (m_axi_wvalid && !m_axi_wready) begin
                if (!m_w_hold_valid_r) begin
                    m_wdata_hold_r <= m_axi_wdata;
                    m_wstrb_hold_r <= m_axi_wstrb;
                    m_wlast_hold_r <= m_axi_wlast;
                    m_w_hold_valid_r <= 1'b1;
                end else if ((m_axi_wdata !== m_wdata_hold_r) ||
                             (m_axi_wstrb !== m_wstrb_hold_r) ||
                             (m_axi_wlast !== m_wlast_hold_r)) begin
                    $fatal(1, "SVA FAIL: M_AXI W changed while waiting for WREADY");
                end
            end else begin
                m_w_hold_valid_r <= 1'b0;
            end

            if (m_axi_rvalid && m_axi_rready && (m_axi_rresp != 2'b00) && !allow_m_axi_error)
                $fatal(1, "SVA FAIL: M_AXI read response error");

            if (m_axi_bvalid && m_axi_bready && (m_axi_bresp != 2'b00) && !allow_m_axi_error)
                $fatal(1, "SVA FAIL: M_AXI write response error");

            if (doorbell_pulse) begin
                task_pending_r <= 1'b1;
                task_timer_r   <= 32'd0;
            end else if (task_pending_r &&
                         (processor_event_valid || core_done || core_error)) begin
                task_pending_r <= 1'b0;
            end else if (task_pending_r) begin
                task_timer_r <= task_timer_r + 32'd1;
                if (task_timer_r > MAX_TASK_CYCLES)
                    $fatal(1, "SVA FAIL: doorbell task did not complete before timeout");
            end

            if (core_busy && core_done)
                $fatal(1, "SVA FAIL: core_busy and core_done asserted together");

            if (host_desc_conflict)
                $fatal(1, "SVA FAIL: host write conflicts with descriptor fetch window");
        end
    end

endmodule

// Testbench-only activity checks for the individual compute engines.  The
// counters are sampled every clock so that two adjacent quiescent samples
// must retain the same values.  No check is made while reset is asserted.
module ai_compute_activity_sva #(
    parameter integer COUNT_WIDTH = 32
)(
    input wire                   clk,
    input wire                   resetn,
    input wire                   wake,
    input wire                   busy,
    input wire                   done,
    input wire                   error,
    input wire                   spad_valid,
    input wire [COUNT_WIDTH-1:0] cycle_count,
    input wire [COUNT_WIDTH-1:0] element_count
);
    wire active = wake || busy || done || error;
    wire quiescent = !active;

    // Concurrent checks are disabled throughout reset.  The reset guard in
    // the antecedent also avoids using an uninitialized $past sample on the
    // first cycle after reset release.
    property p_quiescent_no_spad;
        @(posedge clk) disable iff (!resetn)
            quiescent |-> !spad_valid;
    endproperty

    property p_quiescent_counters_stable;
        @(posedge clk) disable iff (!resetn)
            (quiescent && $past(quiescent && resetn)) |->
            ((cycle_count == $past(cycle_count)) &&
             (element_count == $past(element_count)));
    endproperty

    assert property (p_quiescent_no_spad)
        else $fatal(1, "SVA FAIL: compute activity spad_valid asserted while quiescent");
    assert property (p_quiescent_counters_stable)
        else $fatal(1, "SVA FAIL: compute counters changed across quiescent cycles");
endmodule

// Concurrent AXI4 master-output properties for URG-visible protocol evidence
// in the top-level UVM environment. The procedural checker above remains
// useful for richer diagnostics. R/B payload stability is a slave-side
// responsibility and is not sampled here because legal matching responses
// are accepted without master-side backpressure in this workload.
module ai_axi_master_protocol_sva (
    input wire        clk,
    input wire        resetn,
    input wire [3:0]  arid,
    input wire [63:0] araddr,
    input wire [7:0]  arlen,
    input wire [2:0]  arsize,
    input wire [1:0]  arburst,
    input wire [3:0]  arcache,
    input wire [2:0]  arprot,
    input wire [3:0]  arqos,
    input wire        arlock,
    input wire        arvalid,
    input wire        arready,
    input wire [3:0]  awid,
    input wire [63:0] awaddr,
    input wire [7:0]  awlen,
    input wire [2:0]  awsize,
    input wire [1:0]  awburst,
    input wire [3:0]  awcache,
    input wire [2:0]  awprot,
    input wire [3:0]  awqos,
    input wire        awlock,
    input wire        awvalid,
    input wire        awready,
    input wire [127:0] wdata,
    input wire [15:0]  wstrb,
    input wire         wlast,
    input wire         wvalid,
    input wire         wready
);
    default clocking cb @(posedge clk); endclocking
    default disable iff (!resetn);

    property p_ar_payload_stable_until_accept;
        arvalid && !arready |=> arvalid &&
            $stable({arid, araddr, arlen, arsize, arburst,
                     arcache, arprot, arqos, arlock});
    endproperty

    property p_aw_payload_stable_until_accept;
        awvalid && !awready |=> awvalid &&
            $stable({awid, awaddr, awlen, awsize, awburst,
                     awcache, awprot, awqos, awlock});
    endproperty

    property p_w_payload_stable_until_accept;
        wvalid && !wready |=> wvalid && $stable({wdata, wstrb, wlast});
    endproperty

    property p_ar_burst_stays_within_4k;
        arvalid && arready |->
            ({1'b0, araddr[11:0]} +
             (({4'd0, arlen} + 13'd1) << arsize)) <= 13'd4096;
    endproperty

    property p_aw_burst_stays_within_4k;
        awvalid && awready |->
            ({1'b0, awaddr[11:0]} +
             (({4'd0, awlen} + 13'd1) << awsize)) <= 13'd4096;
    endproperty

    a_ar_payload_stable_until_accept:
        assert property (p_ar_payload_stable_until_accept)
        else $fatal(1, "SVA FAIL: AXI AR payload changed before handshake");
    a_aw_payload_stable_until_accept:
        assert property (p_aw_payload_stable_until_accept)
        else $fatal(1, "SVA FAIL: AXI AW payload changed before handshake");
    a_w_payload_stable_until_accept:
        assert property (p_w_payload_stable_until_accept)
        else $fatal(1, "SVA FAIL: AXI W payload changed before handshake");
    a_ar_burst_stays_within_4k:
        assert property (p_ar_burst_stays_within_4k)
        else $fatal(1, "SVA FAIL: AXI AR burst crosses 4 KiB boundary");
    a_aw_burst_stays_within_4k:
        assert property (p_aw_burst_stays_within_4k)
        else $fatal(1, "SVA FAIL: AXI AW burst crosses 4 KiB boundary");

    c_ar_stall_then_accept: cover property
        (arvalid && !arready ##[1:8] arvalid && arready);
    c_aw_stall_then_accept: cover property
        (awvalid && !awready ##[1:8] awvalid && awready);
    c_w_stall_then_accept: cover property
        (wvalid && !wready ##[1:8] wvalid && wready);
endmodule
