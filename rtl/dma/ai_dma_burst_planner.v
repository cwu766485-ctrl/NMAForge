module ai_dma_burst_planner #(
    parameter integer MAX_BURST_BEATS = 16,
    parameter integer AXI_ADDR_WIDTH = 64
) (
    input  wire [AXI_ADDR_WIDTH-1:0] ext_addr,
    input  wire [15:0]               remaining_words,
    output wire                      plan_wide,
    output wire [4:0]                plan_beats,
    output wire [15:0]               plan_words,
    output wire [31:0]               plan_bytes
);

    reg [8:0]  boundary_beats_comb;
    reg [15:0] remaining_beats_comb;
    reg [4:0]  plan_beats_comb;
    reg [15:0] plan_words_comb;
    reg [31:0] plan_bytes_comb;
    reg        plan_wide_comb;

    always @(*) begin
        plan_wide_comb = (ext_addr[3:0] == 0);
        boundary_beats_comb = (13'd4096 - {1'b0, ext_addr[11:0]}) >> 4;
        remaining_beats_comb = (remaining_words + 16'd3) >> 2;
        if (!plan_wide_comb) begin
            plan_beats_comb = 1;
            plan_words_comb = 1;
            plan_bytes_comb = 4;
        end else begin
            if (boundary_beats_comb < MAX_BURST_BEATS &&
                {7'd0, boundary_beats_comb} < remaining_beats_comb)
                plan_beats_comb = boundary_beats_comb[4:0];
            else if (remaining_beats_comb > MAX_BURST_BEATS)
                plan_beats_comb = MAX_BURST_BEATS;
            else
                plan_beats_comb = remaining_beats_comb[4:0];
            if (remaining_words < ({11'd0, plan_beats_comb} << 2))
                plan_words_comb = remaining_words;
            else
                plan_words_comb = ({11'd0, plan_beats_comb} << 2);
            plan_bytes_comb = {27'd0, plan_beats_comb} << 4;
        end
    end

    assign plan_wide = plan_wide_comb;
    assign plan_beats = plan_beats_comb;
    assign plan_words = plan_words_comb;
    assign plan_bytes = plan_bytes_comb;

endmodule
