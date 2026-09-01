// Combinational descriptor-source selector between scratchpad and external AXI fetchers.
module ai_descriptor_source_mux (
    input  wire        select_external,

    input  wire        spad_done,
    input  wire        spad_error,
    input  wire [7:0]  spad_op,
    input  wire [15:0] spad_task_id,
    input  wire [31:0] spad_src0_base,
    input  wire [31:0] spad_src1_base,
    input  wire [31:0] spad_dst_base,
    input  wire [15:0] spad_length,
    input  wire [15:0] spad_m_size,
    input  wire [15:0] spad_n_size,
    input  wire [15:0] spad_k_words,
    input  wire [4:0]  spad_scale_shift,
    input  wire [1:0]  spad_activation,
    input  wire [31:0] spad_bias_base,
    input  wire        spad_bias_enable,
    input  wire [7:0]  spad_flags,
    input  wire [31:0] spad_aux0,
    input  wire [31:0] spad_src0_stride,
    input  wire [31:0] spad_src1_stride,
    input  wire [31:0] spad_dst_stride,
    input  wire [15:0] spad_batch_count,
    input  wire [15:0] spad_head_count,
    input  wire [15:0] spad_wait_mask,
    input  wire [15:0] spad_signal_mask,
    input  wire [15:0] spad_clear_mask,
    input  wire [7:0]  spad_version,

    input  wire        axi_done,
    input  wire        axi_error,
    input  wire [7:0]  axi_op,
    input  wire [15:0] axi_task_id,
    input  wire [31:0] axi_src0_base,
    input  wire [31:0] axi_src1_base,
    input  wire [31:0] axi_dst_base,
    input  wire [15:0] axi_length,
    input  wire [15:0] axi_m_size,
    input  wire [15:0] axi_n_size,
    input  wire [15:0] axi_k_words,
    input  wire [4:0]  axi_scale_shift,
    input  wire [1:0]  axi_activation,
    input  wire [31:0] axi_bias_base,
    input  wire        axi_bias_enable,
    input  wire [7:0]  axi_flags,
    input  wire [31:0] axi_aux0,
    input  wire [31:0] axi_src0_stride,
    input  wire [31:0] axi_src1_stride,
    input  wire [31:0] axi_dst_stride,
    input  wire [15:0] axi_batch_count,
    input  wire [15:0] axi_head_count,
    input  wire [15:0] axi_wait_mask,
    input  wire [15:0] axi_signal_mask,
    input  wire [15:0] axi_clear_mask,
    input  wire [7:0]  axi_version,

    output wire        desc_done,
    output wire        desc_error,
    output wire [7:0]  desc_op,
    output wire [15:0] desc_task_id,
    output wire [31:0] desc_src0_base,
    output wire [31:0] desc_src1_base,
    output wire [31:0] desc_dst_base,
    output wire [15:0] desc_length,
    output wire [15:0] desc_m_size,
    output wire [15:0] desc_n_size,
    output wire [15:0] desc_k_words,
    output wire [4:0]  desc_scale_shift,
    output wire [1:0]  desc_activation,
    output wire [31:0] desc_bias_base,
    output wire        desc_bias_enable,
    output wire [7:0]  desc_flags,
    output wire [31:0] desc_aux0,
    output wire [31:0] desc_src0_stride,
    output wire [31:0] desc_src1_stride,
    output wire [31:0] desc_dst_stride,
    output wire [15:0] desc_batch_count,
    output wire [15:0] desc_head_count,
    output wire [15:0] desc_wait_mask,
    output wire [15:0] desc_signal_mask,
    output wire [15:0] desc_clear_mask,
    output wire [7:0]  desc_version
);

    assign desc_done = select_external ? axi_done : spad_done;
    assign desc_error = select_external ? axi_error : spad_error;
    assign desc_op = select_external ? axi_op : spad_op;
    assign desc_task_id = select_external ? axi_task_id : spad_task_id;
    assign desc_src0_base = select_external ? axi_src0_base : spad_src0_base;
    assign desc_src1_base = select_external ? axi_src1_base : spad_src1_base;
    assign desc_dst_base = select_external ? axi_dst_base : spad_dst_base;
    assign desc_length = select_external ? axi_length : spad_length;
    assign desc_m_size = select_external ? axi_m_size : spad_m_size;
    assign desc_n_size = select_external ? axi_n_size : spad_n_size;
    assign desc_k_words = select_external ? axi_k_words : spad_k_words;
    assign desc_scale_shift = select_external ? axi_scale_shift : spad_scale_shift;
    assign desc_activation = select_external ? axi_activation : spad_activation;
    assign desc_bias_base = select_external ? axi_bias_base : spad_bias_base;
    assign desc_bias_enable = select_external ? axi_bias_enable : spad_bias_enable;
    assign desc_flags = select_external ? axi_flags : spad_flags;
    assign desc_aux0 = select_external ? axi_aux0 : spad_aux0;
    assign desc_src0_stride = select_external ? axi_src0_stride : spad_src0_stride;
    assign desc_src1_stride = select_external ? axi_src1_stride : spad_src1_stride;
    assign desc_dst_stride = select_external ? axi_dst_stride : spad_dst_stride;
    assign desc_batch_count = select_external ? axi_batch_count : spad_batch_count;
    assign desc_head_count = select_external ? axi_head_count : spad_head_count;
    assign desc_wait_mask = select_external ? axi_wait_mask : spad_wait_mask;
    assign desc_signal_mask = select_external ? axi_signal_mask : spad_signal_mask;
    assign desc_clear_mask = select_external ? axi_clear_mask : spad_clear_mask;
    assign desc_version = select_external ? axi_version : spad_version;

endmodule
