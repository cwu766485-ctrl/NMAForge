`timescale 1ns / 1ps

// ============================================================================
// axi_lite_reg_if
// ----------------------------------------------------------------------------
// AXI-Lite slave 协议适配层。
//
// 它把 AXI-Lite 五个通道：
//   AW/W/B  写地址、写数据、写响应
//   AR/R    读地址、读数据
// 转换成更简单的内部寄存器访问接口：
//   reg_req_valid / reg_req_write / reg_req_addr / reg_req_wdata / reg_rsp_*
//
// 设计特点：
//   - AXI-Lite 写地址 AW 和写数据 W 是独立通道，可能不同拍到达；
//     因此本模块先分别收集 awaddr 和 wdata/wstrb，二者都到齐后再发内部写请求。
//   - 内部错误 reg_rsp_error 会被转换成 AXI SLVERR。
//   - 当前实现一次只处理一个读事务和一个写事务，结构简单，适合寄存器配置面。
// ============================================================================
module axi_lite_reg_if #(
    parameter integer ADDR_WIDTH = 32,
    parameter integer DATA_WIDTH = 32
)(
    input  wire                  aclk,
    input  wire                  aresetn,

    input  wire [ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire                  s_axi_awvalid,
    output wire                  s_axi_awready,
    input  wire [DATA_WIDTH-1:0] s_axi_wdata,
    input  wire [(DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                  s_axi_wvalid,
    output wire                  s_axi_wready,
    output reg  [1:0]            s_axi_bresp,
    output reg                   s_axi_bvalid,
    input  wire                  s_axi_bready,

    input  wire [ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire                  s_axi_arvalid,
    output wire                  s_axi_arready,
    output reg  [DATA_WIDTH-1:0] s_axi_rdata,
    output reg  [1:0]            s_axi_rresp,
    output reg                   s_axi_rvalid,
    input  wire                  s_axi_rready,

    output reg                   reg_req_valid,
    output reg                   reg_req_write,
    output reg  [ADDR_WIDTH-1:0] reg_req_addr,
    output reg  [DATA_WIDTH-1:0] reg_req_wdata,
    output reg  [(DATA_WIDTH/8)-1:0] reg_req_wstrb,
    input  wire [DATA_WIDTH-1:0] reg_rsp_rdata,
    input  wire                  reg_rsp_error
);

    localparam AXI_RESP_OKAY  = 2'b00;
    localparam AXI_RESP_SLVERR = 2'b10;

    localparam WR_COLLECT  = 2'd0;
    localparam WR_REQ      = 2'd1;
    localparam WR_RESP_ARM = 2'd2;
    localparam WR_RESP     = 2'd3;

    localparam RD_IDLE    = 3'd0;
    localparam RD_REQ     = 3'd1;
    localparam RD_WAIT    = 3'd2;
    localparam RD_WAIT2   = 3'd3;
    localparam RD_RESP    = 3'd4;

    reg [1:0] wr_state_r;
    reg [2:0] rd_state_r;

    reg [ADDR_WIDTH-1:0] awaddr_r;
    reg [DATA_WIDTH-1:0] wdata_r;
    reg [(DATA_WIDTH/8)-1:0] wstrb_r;
    reg [ADDR_WIDTH-1:0] araddr_r;
    reg aw_seen_r;
    reg w_seen_r;

    // ready 只在收集阶段拉高；AW/W 可以任意先后到达。
    assign s_axi_awready = (wr_state_r == WR_COLLECT) && !aw_seen_r;
    assign s_axi_wready  = (wr_state_r == WR_COLLECT) && !w_seen_r;
    assign s_axi_arready = (rd_state_r == RD_IDLE);

    // 写状态机：
    //   WR_COLLECT 收齐 AW 和 W；
    //   WR_REQ     向内部寄存器发一拍写请求，并采样 reg_rsp_error；
    //   WR_RESP    向 AXI master 返回 B 通道响应。
    //
    // 读状态机：
    //   RD_IDLE 接收 AR；
    //   RD_REQ  向内部寄存器发一拍读请求并采样 rdata/error；
    //   RD_RESP 返回 R 通道响应。
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            wr_state_r    <= WR_COLLECT;
            rd_state_r    <= RD_IDLE;
            awaddr_r      <= {ADDR_WIDTH{1'b0}};
            wdata_r       <= {DATA_WIDTH{1'b0}};
            wstrb_r       <= {(DATA_WIDTH/8){1'b0}};
            araddr_r      <= {ADDR_WIDTH{1'b0}};
            aw_seen_r     <= 1'b0;
            w_seen_r      <= 1'b0;
            s_axi_bresp   <= AXI_RESP_OKAY;
            s_axi_bvalid  <= 1'b0;
            s_axi_rdata   <= {DATA_WIDTH{1'b0}};
            s_axi_rresp   <= AXI_RESP_OKAY;
            s_axi_rvalid  <= 1'b0;
            reg_req_valid <= 1'b0;
            reg_req_write <= 1'b0;
            reg_req_addr  <= {ADDR_WIDTH{1'b0}};
            reg_req_wdata <= {DATA_WIDTH{1'b0}};
            reg_req_wstrb <= {(DATA_WIDTH/8){1'b0}};
        end else begin
            reg_req_valid <= 1'b0;

            case (wr_state_r)
                WR_COLLECT: begin
                    // AXI-Lite 允许 AW 和 W 分离到达，所以用 aw_seen_r/w_seen_r 暂存。
                    if (s_axi_awvalid && s_axi_awready) begin
                        awaddr_r      <= s_axi_awaddr;
                        aw_seen_r     <= 1'b1;
                    end
                    if (s_axi_wvalid && s_axi_wready) begin
                        wdata_r       <= s_axi_wdata;
                        wstrb_r       <= s_axi_wstrb;
                        w_seen_r      <= 1'b1;
                    end
                    // Do not consume and dispatch a same-cycle AW/W pair in
                    // one compressed state transition.  First latch both
                    // independent AXI-Lite channels; once both sticky flags
                    // are set, issue the internal request on the following
                    // clock.  Besides making the request timing unambiguous,
                    // this keeps AW/W same-cycle traffic safe after a
                    // back-to-back read or write response.
                    if (aw_seen_r && w_seen_r) begin
                        reg_req_valid <= 1'b1;
                        reg_req_write <= 1'b1;
                        reg_req_addr  <= awaddr_r;
                        reg_req_wdata <= wdata_r;
                        reg_req_wstrb <= wstrb_r;
                        wr_state_r    <= WR_REQ;
                    end
                end
                WR_REQ: begin
                    // 内部寄存器块组合给出 reg_rsp_error，本拍转成 B channel response。
                    s_axi_bresp  <= reg_rsp_error ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
                    // BREADY is commonly high before BVALID on processor
                    // interconnects.  Arm the response separately so BVALID
                    // is guaranteed to be observable for a complete cycle.
                    wr_state_r <= WR_RESP_ARM;
                end
                WR_RESP_ARM: begin
                    s_axi_bvalid <= 1'b1;
                    wr_state_r   <= WR_RESP;
                end
                WR_RESP: begin
                    // Hold VALID until a sampled VALID/READY handshake.
                    if (s_axi_bvalid && s_axi_bready) begin
                        s_axi_bvalid <= 1'b0;
                        aw_seen_r    <= 1'b0;
                        w_seen_r     <= 1'b0;
                        wr_state_r   <= WR_COLLECT;
                    end
                end
                default: begin
                    wr_state_r <= WR_COLLECT;
                end
            endcase

            case (rd_state_r)
                RD_IDLE: begin
                    // AR 握手后立即产生内部读请求。
                    if (s_axi_arvalid) begin
                        araddr_r      <= s_axi_araddr;
                        reg_req_valid <= 1'b1;
                        reg_req_write <= 1'b0;
                        reg_req_addr  <= s_axi_araddr;
                        reg_req_wdata <= {DATA_WIDTH{1'b0}};
                        reg_req_wstrb <= {(DATA_WIDTH/8){1'b0}};
                        rd_state_r    <= RD_REQ;
                    end
                end
                RD_REQ: begin
                    // Keep the request classification/address live for one
                    // additional cycle.  A scratchpad read is registered, so
                    // the top-level response mux must still know that the
                    // returning data belongs to the scratchpad in RD_WAIT.
                    // The repeated read is harmless (and has no side effect)
                    // while allowing the first registered value to be sampled
                    // below.
                    reg_req_valid <= 1'b1;
                    reg_req_write <= 1'b0;
                    reg_req_addr  <= araddr_r;
                    reg_req_wdata <= {DATA_WIDTH{1'b0}};
                    reg_req_wstrb <= {(DATA_WIDTH/8){1'b0}};
                    rd_state_r <= RD_WAIT;
                end
                RD_WAIT: begin
                    // Keep the address classification live until the second
                    // registered scratchpad read stage has completed.
                    reg_req_valid <= 1'b1;
                    reg_req_write <= 1'b0;
                    reg_req_addr  <= araddr_r;
                    reg_req_wdata <= {DATA_WIDTH{1'b0}};
                    reg_req_wstrb <= {(DATA_WIDTH/8){1'b0}};
                    rd_state_r <= RD_WAIT2;
                end
                RD_WAIT2: begin
                    // 采样内部读数据和错误响应，下一状态保持 RVALID 等待 CPU 接收。
                    s_axi_rdata  <= reg_rsp_rdata;
                    s_axi_rresp  <= reg_rsp_error ? AXI_RESP_SLVERR : AXI_RESP_OKAY;
                    s_axi_rvalid <= 1'b1;
                    rd_state_r   <= RD_RESP;
                end
                RD_RESP: begin
                    if (s_axi_rready) begin
                        s_axi_rvalid <= 1'b0;
                        rd_state_r   <= RD_IDLE;
                    end
                end
                default: begin
                    rd_state_r <= RD_IDLE;
                end
            endcase
        end
    end

endmodule
