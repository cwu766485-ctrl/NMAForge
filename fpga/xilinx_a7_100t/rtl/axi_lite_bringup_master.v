`timescale 1ns / 1ps

module axi_lite_bringup_master #(
    parameter integer RESET_WAIT_CYCLES = 1024,
    parameter integer POLL_TIMEOUT_CYCLES = 50000
)(
    input  wire        clk,
    input  wire        resetn,

    output reg  [31:0] m_axi_awaddr,
    output reg         m_axi_awvalid,
    input  wire        m_axi_awready,
    output reg  [31:0] m_axi_wdata,
    output reg  [3:0]  m_axi_wstrb,
    output reg         m_axi_wvalid,
    input  wire        m_axi_wready,
    input  wire [1:0]  m_axi_bresp,
    input  wire        m_axi_bvalid,
    output reg         m_axi_bready,

    output reg  [31:0] m_axi_araddr,
    output reg         m_axi_arvalid,
    input  wire        m_axi_arready,
    input  wire [31:0] m_axi_rdata,
    input  wire [1:0]  m_axi_rresp,
    input  wire        m_axi_rvalid,
    output reg         m_axi_rready,

    output wire        running,
    output wire        pass,
    output wire        fail
);

    localparam [31:0] REG_CTRL      = 32'h0000_0000;
    localparam [31:0] REG_STATUS    = 32'h0000_0004;
    localparam [31:0] REG_OP_MODE   = 32'h0000_0008;
    localparam [31:0] REG_SRC0_BASE = 32'h0000_000c;
    localparam [31:0] REG_SRC1_BASE = 32'h0000_0010;
    localparam [31:0] REG_DST_BASE  = 32'h0000_0014;
    localparam [31:0] REG_LENGTH    = 32'h0000_0018;
    localparam [31:0] REG_QUANT_ACT = 32'h0000_0028;
    localparam [31:0] REG_RESULT    = 32'h0000_002c;
    localparam [31:0] SPAD_BASE     = 32'h0001_0000;

    localparam [7:0]  OP_VDOT_INT8  = 8'h10;
    localparam [31:0] EXPECT_RESULT = 32'd70;

    localparam AXI_RESP_OKAY = 2'b00;

    localparam ST_RESET_WAIT = 5'd0;
    localparam ST_PICK_WRITE = 5'd1;
    localparam ST_WRITE      = 5'd2;
    localparam ST_WRITE_RESP = 5'd3;
    localparam ST_POLL_READ  = 5'd4;
    localparam ST_POLL_RESP  = 5'd5;
    localparam ST_RESULT_RD  = 5'd6;
    localparam ST_RESULT_RSP = 5'd7;
    localparam ST_SPAD_RD    = 5'd8;
    localparam ST_SPAD_RSP   = 5'd9;
    localparam ST_PASS       = 5'd10;
    localparam ST_FAIL       = 5'd11;

    reg [4:0]  state_r;
    reg [3:0]  write_index_r;
    reg [31:0] wait_count_r;
    reg [31:0] poll_count_r;
    reg        aw_done_r;
    reg        w_done_r;

    assign running = (state_r != ST_PASS) && (state_r != ST_FAIL);
    assign pass = (state_r == ST_PASS);
    assign fail = (state_r == ST_FAIL);

    always @(*) begin
        case (write_index_r)
            4'd0: begin
                m_axi_awaddr = SPAD_BASE + 32'h0000;
                m_axi_wdata  = 32'h0403_0201;
            end
            4'd1: begin
                m_axi_awaddr = SPAD_BASE + 32'h0100;
                m_axi_wdata  = 32'h0807_0605;
            end
            4'd2: begin
                m_axi_awaddr = REG_OP_MODE;
                m_axi_wdata  = {24'd0, OP_VDOT_INT8};
            end
            4'd3: begin
                m_axi_awaddr = REG_SRC0_BASE;
                m_axi_wdata  = 32'h0000_0000;
            end
            4'd4: begin
                m_axi_awaddr = REG_SRC1_BASE;
                m_axi_wdata  = 32'h0000_0100;
            end
            4'd5: begin
                m_axi_awaddr = REG_DST_BASE;
                m_axi_wdata  = 32'h0000_0200;
            end
            4'd6: begin
                m_axi_awaddr = REG_LENGTH;
                m_axi_wdata  = 32'h0000_0001;
            end
            4'd7: begin
                m_axi_awaddr = REG_QUANT_ACT;
                m_axi_wdata  = 32'h0000_0000;
            end
            default: begin
                m_axi_awaddr = REG_CTRL;
                m_axi_wdata  = 32'h0000_0003;
            end
        endcase
    end

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            state_r       <= ST_RESET_WAIT;
            write_index_r <= 4'd0;
            wait_count_r  <= 32'd0;
            poll_count_r  <= 32'd0;
            aw_done_r     <= 1'b0;
            w_done_r      <= 1'b0;
            m_axi_awvalid <= 1'b0;
            m_axi_wstrb   <= 4'hf;
            m_axi_wvalid  <= 1'b0;
            m_axi_bready  <= 1'b0;
            m_axi_araddr  <= 32'd0;
            m_axi_arvalid <= 1'b0;
            m_axi_rready  <= 1'b0;
        end else begin
            case (state_r)
                ST_RESET_WAIT: begin
                    if (wait_count_r >= (RESET_WAIT_CYCLES - 1)) begin
                        state_r <= ST_PICK_WRITE;
                    end else begin
                        wait_count_r <= wait_count_r + 32'd1;
                    end
                end
                ST_PICK_WRITE: begin
                    aw_done_r     <= 1'b0;
                    w_done_r      <= 1'b0;
                    m_axi_awvalid <= 1'b1;
                    m_axi_wvalid  <= 1'b1;
                    m_axi_bready  <= 1'b0;
                    state_r       <= ST_WRITE;
                end
                ST_WRITE: begin
                    if (m_axi_awvalid && m_axi_awready) begin
                        m_axi_awvalid <= 1'b0;
                        aw_done_r     <= 1'b1;
                    end
                    if (m_axi_wvalid && m_axi_wready) begin
                        m_axi_wvalid <= 1'b0;
                        w_done_r     <= 1'b1;
                    end
                    if ((aw_done_r || (m_axi_awvalid && m_axi_awready)) &&
                        (w_done_r || (m_axi_wvalid && m_axi_wready))) begin
                        m_axi_bready <= 1'b1;
                        state_r      <= ST_WRITE_RESP;
                    end
                end
                ST_WRITE_RESP: begin
                    if (m_axi_bvalid) begin
                        m_axi_bready <= 1'b0;
                        if (m_axi_bresp != AXI_RESP_OKAY) begin
                            state_r <= ST_FAIL;
                        end else if (write_index_r == 4'd8) begin
                            poll_count_r  <= 32'd0;
                            m_axi_araddr  <= REG_STATUS;
                            m_axi_arvalid <= 1'b1;
                            state_r       <= ST_POLL_READ;
                        end else begin
                            write_index_r <= write_index_r + 4'd1;
                            state_r       <= ST_PICK_WRITE;
                        end
                    end
                end
                ST_POLL_READ: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1;
                        state_r       <= ST_POLL_RESP;
                    end
                end
                ST_POLL_RESP: begin
                    if (m_axi_rvalid) begin
                        m_axi_rready <= 1'b0;
                        if (m_axi_rresp != AXI_RESP_OKAY || m_axi_rdata[2]) begin
                            state_r <= ST_FAIL;
                        end else if (m_axi_rdata[1]) begin
                            m_axi_araddr  <= REG_RESULT;
                            m_axi_arvalid <= 1'b1;
                            state_r       <= ST_RESULT_RD;
                        end else if (poll_count_r >= (POLL_TIMEOUT_CYCLES - 1)) begin
                            state_r <= ST_FAIL;
                        end else begin
                            poll_count_r  <= poll_count_r + 32'd1;
                            m_axi_araddr  <= REG_STATUS;
                            m_axi_arvalid <= 1'b1;
                            state_r       <= ST_POLL_READ;
                        end
                    end
                end
                ST_RESULT_RD: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1;
                        state_r       <= ST_RESULT_RSP;
                    end
                end
                ST_RESULT_RSP: begin
                    if (m_axi_rvalid) begin
                        m_axi_rready <= 1'b0;
                        if (m_axi_rresp != AXI_RESP_OKAY || m_axi_rdata != EXPECT_RESULT) begin
                            state_r <= ST_FAIL;
                        end else begin
                            m_axi_araddr  <= SPAD_BASE + 32'h0200;
                            m_axi_arvalid <= 1'b1;
                            state_r       <= ST_SPAD_RD;
                        end
                    end
                end
                ST_SPAD_RD: begin
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1;
                        state_r       <= ST_SPAD_RSP;
                    end
                end
                ST_SPAD_RSP: begin
                    if (m_axi_rvalid) begin
                        m_axi_rready <= 1'b0;
                        if (m_axi_rresp == AXI_RESP_OKAY && m_axi_rdata == EXPECT_RESULT)
                            state_r <= ST_PASS;
                        else
                            state_r <= ST_FAIL;
                    end
                end
                ST_PASS: begin
                    state_r <= ST_PASS;
                end
                ST_FAIL: begin
                    state_r <= ST_FAIL;
                end
                default: begin
                    state_r <= ST_FAIL;
                end
            endcase
        end
    end

endmodule
