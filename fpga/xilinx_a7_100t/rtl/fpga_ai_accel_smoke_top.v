`timescale 1ns / 1ps

module fpga_ai_accel_smoke_top(
    input  wire       sys_clk_50m,
    output wire [2:0] user_led
);

    reg [15:0] reset_shift_r = 16'd0;
    reg [24:0] heartbeat_r = 25'd0;

    wire resetn;
    wire bringup_running;
    wire bringup_pass;
    wire bringup_fail;
    wire irq;

    wire [31:0] s_axi_awaddr;
    wire        s_axi_awvalid;
    wire        s_axi_awready;
    wire [31:0] s_axi_wdata;
    wire [3:0]  s_axi_wstrb;
    wire        s_axi_wvalid;
    wire        s_axi_wready;
    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;
    wire        s_axi_bready;
    wire [31:0] s_axi_araddr;
    wire        s_axi_arvalid;
    wire        s_axi_arready;
    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rvalid;
    wire        s_axi_rready;

    assign resetn = reset_shift_r[15];

    always @(posedge sys_clk_50m) begin
        if (!reset_shift_r[15])
            reset_shift_r <= {reset_shift_r[14:0], 1'b1};
        heartbeat_r <= heartbeat_r + 25'd1;
    end

    assign user_led[0] = heartbeat_r[24];
    assign user_led[1] = bringup_pass;
    assign user_led[2] = bringup_fail || (bringup_running && heartbeat_r[22]);

    axi_lite_bringup_master bringup_u(
        .clk           (sys_clk_50m),
        .resetn        (resetn),
        .m_axi_awaddr  (s_axi_awaddr),
        .m_axi_awvalid (s_axi_awvalid),
        .m_axi_awready (s_axi_awready),
        .m_axi_wdata   (s_axi_wdata),
        .m_axi_wstrb   (s_axi_wstrb),
        .m_axi_wvalid  (s_axi_wvalid),
        .m_axi_wready  (s_axi_wready),
        .m_axi_bresp   (s_axi_bresp),
        .m_axi_bvalid  (s_axi_bvalid),
        .m_axi_bready  (s_axi_bready),
        .m_axi_araddr  (s_axi_araddr),
        .m_axi_arvalid (s_axi_arvalid),
        .m_axi_arready (s_axi_arready),
        .m_axi_rdata   (s_axi_rdata),
        .m_axi_rresp   (s_axi_rresp),
        .m_axi_rvalid  (s_axi_rvalid),
        .m_axi_rready  (s_axi_rready),
        .running       (bringup_running),
        .pass          (bringup_pass),
        .fail          (bringup_fail)
    );

    // Keep the small Artix-7 compatibility profile; XCZU15EG and the generic
    // IP default use 32768 words/bank (512 KiB).
    ai_accel_top #(.SPAD_WORDS_PER_BANK(4096)) dut_u(
        .aclk           (sys_clk_50m),
        .aresetn        (resetn),
        .s_axi_awaddr   (s_axi_awaddr),
        .s_axi_awvalid  (s_axi_awvalid),
        .s_axi_awready  (s_axi_awready),
        .s_axi_wdata    (s_axi_wdata),
        .s_axi_wstrb    (s_axi_wstrb),
        .s_axi_wvalid   (s_axi_wvalid),
        .s_axi_wready   (s_axi_wready),
        .s_axi_bresp    (s_axi_bresp),
        .s_axi_bvalid   (s_axi_bvalid),
        .s_axi_bready   (s_axi_bready),
        .s_axi_araddr   (s_axi_araddr),
        .s_axi_arvalid  (s_axi_arvalid),
        .s_axi_arready  (s_axi_arready),
        .s_axi_rdata    (s_axi_rdata),
        .s_axi_rresp    (s_axi_rresp),
        .s_axi_rvalid   (s_axi_rvalid),
        .s_axi_rready   (s_axi_rready),
        .irq            (irq),
        .m_axi_arvalid  (),
        .m_axi_araddr   (),
        .m_axi_arlen    (),
        .m_axi_arsize   (),
        .m_axi_arburst  (),
        .m_axi_arready  (1'b0),
        .m_axi_rdata    (32'd0),
        .m_axi_rresp    (2'b00),
        .m_axi_rvalid   (1'b0),
        .m_axi_rlast    (1'b0),
        .m_axi_rready   (),
        .m_axi_awvalid  (),
        .m_axi_awaddr   (),
        .m_axi_awlen    (),
        .m_axi_awsize   (),
        .m_axi_awburst  (),
        .m_axi_awready  (1'b0),
        .m_axi_wvalid   (),
        .m_axi_wdata    (),
        .m_axi_wstrb    (),
        .m_axi_wlast    (),
        .m_axi_wready   (1'b0),
        .m_axi_bresp    (2'b00),
        .m_axi_bvalid   (1'b0),
        .m_axi_bready   ()
    );

endmodule
