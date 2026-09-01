// Combinational ring-pointer normalization and increment helper.
// A ring size of zero preserves the legacy compatibility behavior: the
// pointer is not normalized and next_pointer is a wrapping 32-bit increment.
module ai_ring_pointer_next (
    input  wire [31:0] pointer,
    input  wire [31:0] queue_size,
    output wire [31:0] index,
    output wire [31:0] next_pointer
);

    assign index = (queue_size != 0 && pointer >= queue_size) ? 0 : pointer;
    assign next_pointer = (queue_size == 0) ? pointer + 1 :
                          (index >= queue_size - 1 ? 0 : index + 1);

endmodule
