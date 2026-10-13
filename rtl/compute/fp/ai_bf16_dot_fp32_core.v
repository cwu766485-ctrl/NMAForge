// Backward-compatible BF16-only wrapper around the shared mixed-format core.
// Existing BF16 users keep the original interface and cycle behavior.
module ai_bf16_dot_fp32_core (
    input  wire        clk,
    input  wire        resetn,
    input  wire        start,
    input  wire        abort,
    input  wire [31:0] src0_base,
    input  wire [31:0] src1_base,
    input  wire [31:0] dst_base,
    input  wire [15:0] length,
    input  wire [31:0] watchdog_limit,
    output wire        spad_valid,
    output wire        spad_write,
    output wire [31:0] spad_addr,
    output wire [31:0] spad_wdata,
    input  wire        spad_ready,
    input  wire        spad_rsp_valid,
    input  wire [31:0] spad_rdata,
    input  wire        spad_parity_error,
    input  wire        spad_protection_error,
    output wire        busy,
    output wire        done,
    output wire        error,
    output wire [3:0]  error_code,
    output wire [31:0] result,
    output wire [31:0] cycle_count,
    output wire [31:0] element_count
);

    ai_mixed_precision_dot_fp32_core mixed_core_u (
        .clk(clk), .resetn(resetn), .start(start), .format_fp16(1'b0),
        .abort(abort), .src0_base(src0_base), .src1_base(src1_base),
        .dst_base(dst_base), .length(length),
        .watchdog_limit(watchdog_limit), .spad_valid(spad_valid),
        .spad_write(spad_write), .spad_addr(spad_addr),
        .spad_wdata(spad_wdata), .spad_ready(spad_ready),
        .spad_rsp_valid(spad_rsp_valid), .spad_rdata(spad_rdata),
        .spad_parity_error(spad_parity_error),
        .spad_protection_error(spad_protection_error), .busy(busy),
        .done(done), .error(error), .error_code(error_code),
        .result(result), .cycle_count(cycle_count),
        .element_count(element_count)
    );

endmodule
