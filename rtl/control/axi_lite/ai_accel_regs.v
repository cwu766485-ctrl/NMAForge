`timescale 1ns / 1ps

// AXI-Lite visible register file.  This block deliberately has no descriptor,
// queue, core, or completion state machine: ai_command_processor owns that
// lifecycle.  It only stores software configuration, emits control pulses and
// records completion/DMA status.
module ai_accel_regs #(
    parameter [31:0] SPAD_BYTES = 32'd524288
)(
    input wire clk, input wire resetn,
    input wire reg_req_valid, input wire reg_req_write, input wire [31:0] reg_req_addr,
    input wire [31:0] reg_req_wdata, input wire [3:0] reg_req_wstrb,
    output reg [31:0] reg_rsp_rdata, output reg reg_rsp_error,
    input wire processor_busy, input wire processor_event_valid, input wire processor_event_error,
    input wire [3:0] processor_event_error_code, input wire [31:0] processor_event_result,
    input wire [31:0] processor_event_cycles, input wire [31:0] processor_event_elements,
    input wire [31:0] processor_cmdq_head, input wire [31:0] processor_cplq_tail,
    input wire [15:0] processor_dependency_events,
    input wire dma_busy, input wire dma_done, input wire dma_error, input wire [3:0] dma_error_code,
    output reg direct_start, output reg submit, output reg core_abort,
    output reg dma_start, output reg dma_store,
    output reg [63:0] dma_ext_addr, output reg [31:0] dma_spad_addr,
    output reg [15:0] dma_length_words, output reg [15:0] dma_row_words, output reg [15:0] dma_row_count,
    output reg [31:0] dma_ext_stride, output reg [31:0] dma_spad_stride,
    output reg dma_gather_enable, output reg [31:0] dma_gather_index_base,
    output reg [2:0] dma_read_outstanding,
    output reg [7:0] op_mode, output reg [31:0] src0_base, output reg [31:0] src1_base, output reg [31:0] dst_base,
    output reg [15:0] length, output reg [15:0] m_size, output reg [15:0] n_size, output reg [15:0] k_words,
    output reg [4:0] scale_shift, output reg [1:0] activation, output reg [31:0] watchdog_limit,
    output reg [31:0] bias_base, output reg bias_enable,
    output reg tile_start, output reg [15:0] tile_count,
    output reg [63:0] tile_ext_input_base, output reg [63:0] tile_ext_output_base,
    output reg [31:0] tile_ext_input_stride, output reg [31:0] tile_ext_output_stride,
    output reg [31:0] tile_buffer0_base, output reg [31:0] tile_buffer1_base,
    output reg [31:0] tile_output_offset,
    output reg [15:0] tile_input_words, output reg [15:0] tile_output_words,
    input wire [31:0] tile_perf_total, input wire [31:0] tile_perf_dma,
    input wire [31:0] tile_perf_compute, input wire [31:0] tile_perf_overlap,
    input wire [31:0] tile_perf_stall, input wire [15:0] tile_completed,
    input wire [31:0] perf_matrix_cycles, input wire [31:0] perf_matrix_mac_cycles,
    input wire [31:0] perf_matrix_banked_stall, input wire [31:0] perf_dma_read_bytes,
    input wire [31:0] perf_dma_write_bytes, input wire [31:0] perf_dma_ar_count,
    input wire [31:0] perf_dma_aw_count, input wire [31:0] perf_dma_r_stall,
    input wire [2:0] perf_dma_rd_outstanding, input wire [2:0] perf_dma_rd_highwater,
    output reg perf_clear,
    output wire [31:0] region0_base, output wire [31:0] region0_limit, output wire [3:0] region0_perm,
    output wire [31:0] region1_base, output wire [31:0] region1_limit, output wire [3:0] region1_perm,
    output wire [31:0] region2_base, output wire [31:0] region2_limit, output wire [3:0] region2_perm,
    output wire [31:0] region3_base, output wire [31:0] region3_limit, output wire [3:0] region3_perm,
    output wire [63:0] cmdq_base, output wire [31:0] cmdq_size,
    output wire [31:0] cmdq_tail, output reg cmdq_external,
    output reg cmdq_head_load, output reg [31:0] cmdq_head_seed,
    output wire [31:0] cplq_base, output wire [31:0] cplq_size, output wire [31:0] cplq_head,
    output reg cplq_tail_load, output reg [31:0] cplq_tail_seed,
    output wire irq
);
    localparam [8:0] CTRL=9'h000, STATUS=9'h004, OP=9'h008, SRC0=9'h00c, SRC1=9'h010, DST=9'h014,
                     LENGTH=9'h018, M=9'h01c, N=9'h020, K=9'h024, QUANT=9'h028, RESULT=9'h02c,
                     ERROR=9'h030, CYCLES=9'h034, ELEMENTS=9'h038, IRQ_STATUS=9'h03c, IRQ_ENABLE=9'h040,
                     VERSION=9'h044, CAP=9'h048, CMD_BASE=9'h080, CMD_HI=9'h084, CMD_SIZE=9'h088,
                     CMD_HEAD=9'h08c, CMD_CTRL=9'h0ac, CPL_BASE=9'h090, CPL_HI=9'h094, CPL_SIZE=9'h098,
                     CPL_TAIL=9'h09c, DOORBELL=9'h0a0, ABORT=9'h0a4, WATCHDOG=9'h0a8, DMA_CTRL=9'h0b0,
                     DMA_STATUS=9'h0b4, DMA_EXT=9'h0b8, DMA_SPAD=9'h0bc, DMA_LEN=9'h0c0, DMA_ERROR=9'h0c4,
                     CMD_TAIL=9'h0c8, CPL_HEAD=9'h0cc, QUEUE_STATUS=9'h0d0, R0_BASE=9'h0d4, R0_LIMIT=9'h0d8,
                     R0_PERM=9'h0dc, R1_BASE=9'h0e0, R1_LIMIT=9'h0e4, R1_PERM=9'h0e8, R2_BASE=9'h0ec,
                     R2_LIMIT=9'h0f0, R2_PERM=9'h0f4, R3_BASE=9'h0f8, R3_LIMIT=9'h0fc, R3_PERM=9'h100,
                     DMA_ROW_WORDS=9'h104, DMA_ROW_COUNT=9'h108, DMA_EXT_STRIDE=9'h10c, DMA_SPAD_STRIDE=9'h110,
                     BIAS_BASE=9'h114, POST_CTRL=9'h118, TILE_CTRL=9'h120, TILE_COUNT=9'h124,
                     TILE_EXT_IN=9'h128, TILE_EXT_OUT=9'h12c, TILE_EXT_IN_STRIDE=9'h130,
                     TILE_EXT_OUT_STRIDE=9'h134, TILE_BUF0=9'h138, TILE_BUF1=9'h13c,
                     TILE_IN_WORDS=9'h140, TILE_OUT_WORDS=9'h144, TILE_OUT_OFFSET=9'h148,
                     PERF_TOTAL=9'h14c, PERF_DMA=9'h150, PERF_COMPUTE=9'h154,
                     PERF_OVERLAP=9'h158, PERF_STALL=9'h15c, TILE_COMPLETED=9'h160,
                     SPAD_INFO=9'h164, EVENT_STATUS=9'h168,
                     DMA_CFG=9'h16c, DMA_GATHER_INDEX=9'h170, PERF_CTRL=9'h174,
                     PERF_MATRIX_CYCLES=9'h178, PERF_MATRIX_MAC_CYCLES=9'h17c,
                     PERF_MATRIX_BANKED_STALL=9'h180, PERF_DMA_READ_BYTES=9'h184,
                     PERF_DMA_WRITE_BYTES=9'h188, PERF_DMA_AR_COUNT=9'h18c,
                     PERF_DMA_AW_COUNT=9'h190, PERF_DMA_RD_STATE=9'h194,
                     PERF_DMA_R_STALL=9'h198, DMA_EXT_HI=9'h19c,
                     ABI_INFO=9'h1a0, ERROR_INFO=9'h1a4, CAP2=9'h1a8,
                     TILE_EXT_IN_HI=9'h1ac, TILE_EXT_OUT_HI=9'h1b0;
    reg done_r, error_r, irq_status_r, irq_enable_r;
    reg [3:0] error_code_r, dma_error_code_r, error_source_r;
    reg [31:0] result_r, cycles_r, elements_r;
    reg dma_done_r, dma_error_r;
    reg [31:0] cmd_base_r, cmd_hi_r, cmd_size_r, cmd_tail_r;
    reg [31:0] cpl_base_r, cpl_hi_r, cpl_size_r, cpl_head_r;
    reg [31:0] r0b,r0l,r1b,r1l,r2b,r2l,r3b,r3l; reg [3:0] r0p,r1p,r2p,r3p;
    wire [8:0] a = reg_req_addr[8:0];
    // Reject addresses outside the implemented 512-byte register page rather
    // than aliasing them through the low address bits.
    wire word_access = reg_req_addr[31:9] == 0 && reg_req_addr[1:0] == 0 &&
                       (!reg_req_write || reg_req_wstrb == 4'hf);
    wire cmd_empty = cmd_size_r != 0 && processor_cmdq_head == cmd_tail_r;
    wire cpl_empty = cpl_size_r != 0 && cpl_head_r == processor_cplq_tail;
    wire [31:0] cpl_next = processor_cplq_tail >= cpl_size_r-1 ? 0 : processor_cplq_tail+1;
    wire cpl_full = cpl_size_r != 0 && cpl_next == cpl_head_r;
    wire status_write = reg_req_valid && reg_req_write && !reg_rsp_error;
    reg done_n, error_n, irq_status_n, dma_done_n, dma_error_n;
    reg [3:0] error_code_n, error_source_n, dma_error_code_n;
    reg [31:0] result_n, cycles_n, elements_n;

    always @(*) begin
      done_n=done_r; error_n=error_r; irq_status_n=irq_status_r;
      error_code_n=error_code_r; error_source_n=error_source_r;
      result_n=result_r; cycles_n=cycles_r; elements_n=elements_r;
      dma_done_n=dma_done_r; dma_error_n=dma_error_r;
      dma_error_code_n=dma_error_code_r;
      if(processor_event_valid) begin
        done_n=1; error_n=processor_event_error;
        error_code_n=processor_event_error_code;
        error_source_n=processor_event_error ? 4'd1 : 4'd0;
        result_n=processor_event_result; cycles_n=processor_event_cycles;
        elements_n=processor_event_elements; irq_status_n=1;
      end
      if(dma_done) begin
        dma_done_n=1; dma_error_n=dma_error; dma_error_code_n=dma_error_code;
        if(dma_error) begin
          error_n=1; error_code_n=dma_error_code;
          error_source_n=4'd2; irq_status_n=1;
        end
      end
      if(status_write) case(a)
        CTRL: if(reg_req_wdata[0] && !processor_busy && !dma_busy) begin
          done_n=0; error_n=0; irq_status_n=0;
          error_code_n=0; error_source_n=0;
        end
        STATUS: begin
          if(reg_req_wdata[1]) done_n=0;
          if(reg_req_wdata[2]) begin error_n=0; error_code_n=0; error_source_n=0; end
        end
        IRQ_STATUS: if(reg_req_wdata[0]) irq_status_n=0;
        DOORBELL: if(!processor_busy && !dma_busy) begin
          done_n=0; error_n=0; irq_status_n=0;
          error_code_n=0; error_source_n=0;
        end
        DMA_CTRL: if(reg_req_wdata[0] && !processor_busy && !dma_busy) begin
          dma_done_n=0; dma_error_n=0; dma_error_code_n=0;
        end
        DMA_STATUS: begin
          if(reg_req_wdata[1]) dma_done_n=0;
          if(reg_req_wdata[2]) begin dma_error_n=0; dma_error_code_n=0; end
        end
        TILE_CTRL: if(reg_req_wdata[0] && !processor_busy && !dma_busy) begin
          done_n=0; error_n=0; irq_status_n=0;
          error_code_n=0; error_source_n=0;
        end
        default: begin end
      endcase
    end
    // Keep the legal-address and write-protection policies in one place.
    // The read and write muxes below remain the ABI source of truth.
    function is_known_address;
        input [8:0] address;
        begin
            case (address)
                // Direct-compute control and completion status.
                CTRL, STATUS, OP, SRC0, SRC1, DST, LENGTH, M, N, K, QUANT,
                RESULT, ERROR, CYCLES, ELEMENTS, IRQ_STATUS, IRQ_ENABLE,
                VERSION, CAP, WATCHDOG, DOORBELL, ABORT,

                // Command and completion queues.
                CMD_BASE, CMD_HI, CMD_SIZE, CMD_HEAD, CMD_TAIL, CMD_CTRL,
                CPL_BASE, CPL_HI, CPL_SIZE, CPL_TAIL, CPL_HEAD, QUEUE_STATUS,

                // Scalar/2D/gather DMA configuration and status.
                DMA_CTRL, DMA_STATUS, DMA_EXT, DMA_EXT_HI, DMA_SPAD, DMA_LEN,
                DMA_ERROR, DMA_ROW_WORDS, DMA_ROW_COUNT, DMA_EXT_STRIDE,
                DMA_SPAD_STRIDE, DMA_CFG, DMA_GATHER_INDEX,

                // Scratchpad protection regions and post-processing.
                R0_BASE, R0_LIMIT, R0_PERM, R1_BASE, R1_LIMIT, R1_PERM,
                R2_BASE, R2_LIMIT, R2_PERM, R3_BASE, R3_LIMIT, R3_PERM,
                BIAS_BASE, POST_CTRL,

                // Tile-pipeline configuration and observability.
                TILE_CTRL, TILE_COUNT, TILE_EXT_IN, TILE_EXT_OUT,
                TILE_EXT_IN_HI, TILE_EXT_OUT_HI, TILE_EXT_IN_STRIDE,
                TILE_EXT_OUT_STRIDE, TILE_BUF0, TILE_BUF1, TILE_IN_WORDS,
                TILE_OUT_WORDS, TILE_OUT_OFFSET, PERF_TOTAL, PERF_DMA,
                PERF_COMPUTE, PERF_OVERLAP, PERF_STALL, TILE_COMPLETED,

                // Global performance counters and ABI capability reporting.
                SPAD_INFO, EVENT_STATUS, PERF_CTRL, PERF_MATRIX_CYCLES,
                PERF_MATRIX_MAC_CYCLES, PERF_MATRIX_BANKED_STALL,
                PERF_DMA_READ_BYTES, PERF_DMA_WRITE_BYTES, PERF_DMA_AR_COUNT,
                PERF_DMA_AW_COUNT, PERF_DMA_RD_STATE, PERF_DMA_R_STALL,
                ABI_INFO, ERROR_INFO, CAP2:
                    is_known_address = 1'b1;
                default:
                    is_known_address = 1'b0;
            endcase
        end
    endfunction

    function is_read_only_address;
        input [8:0] address;
        begin
            case (address)
                RESULT, ERROR, CYCLES, ELEMENTS, VERSION, CAP, QUEUE_STATUS,
                DMA_ERROR, PERF_TOTAL, PERF_DMA, PERF_COMPUTE, PERF_OVERLAP,
                PERF_STALL, TILE_COMPLETED, SPAD_INFO, EVENT_STATUS,
                PERF_MATRIX_CYCLES, PERF_MATRIX_MAC_CYCLES,
                PERF_MATRIX_BANKED_STALL, PERF_DMA_READ_BYTES,
                PERF_DMA_WRITE_BYTES, PERF_DMA_AR_COUNT, PERF_DMA_AW_COUNT,
                PERF_DMA_RD_STATE, PERF_DMA_R_STALL, ABI_INFO, ERROR_INFO,
                CAP2:
                    is_read_only_address = 1'b1;
                default:
                    is_read_only_address = 1'b0;
            endcase
        end
    endfunction

    wire known = is_known_address(a);
    wire readonly = is_read_only_address(a);
    wire cfg_locked = (processor_busy || dma_busy) && reg_req_write &&
                      !(a == STATUS || a == IRQ_STATUS ||
                        a == DMA_STATUS || a == ABORT);
    assign cmdq_base={cmd_hi_r,cmd_base_r}; assign cmdq_size=cmd_size_r; assign cmdq_tail=cmd_tail_r;
    assign cplq_base=cpl_base_r; assign cplq_size=cpl_size_r; assign cplq_head=cpl_head_r;
    assign region0_base=r0b; assign region0_limit=r0l; assign region0_perm=r0p;
    assign region1_base=r1b; assign region1_limit=r1l; assign region1_perm=r1p;
    assign region2_base=r2b; assign region2_limit=r2l; assign region2_perm=r2p;
    assign region3_base=r3b; assign region3_limit=r3l; assign region3_perm=r3p;
    assign irq=irq_enable_r && irq_status_r;

    always @(*) begin
      reg_rsp_error = reg_req_valid && (!word_access || !known || (reg_req_write && (readonly || cfg_locked)));
      reg_rsp_rdata=0;
      case(a)
        // Preserve the documented STATUS ABI: bit0=command busy,
        // bit1=sticky done and bit2=sticky error.  DMA has its own status
        // register; exposing it here would shift the software-visible bits.
        CTRL: reg_rsp_rdata={30'd0,irq_enable_r,1'b0}; STATUS: reg_rsp_rdata={29'd0,error_r,done_r,processor_busy};
        OP: reg_rsp_rdata={24'd0,op_mode}; SRC0: reg_rsp_rdata=src0_base; SRC1: reg_rsp_rdata=src1_base; DST: reg_rsp_rdata=dst_base;
        LENGTH: reg_rsp_rdata={16'd0,length}; M: reg_rsp_rdata={16'd0,m_size}; N: reg_rsp_rdata={16'd0,n_size}; K: reg_rsp_rdata={16'd0,k_words}; QUANT: reg_rsp_rdata={25'd0,activation,scale_shift};
        RESULT: reg_rsp_rdata=result_r; ERROR: reg_rsp_rdata={28'd0,error_code_r}; CYCLES: reg_rsp_rdata=cycles_r; ELEMENTS: reg_rsp_rdata=elements_r;
        IRQ_STATUS: reg_rsp_rdata={31'd0,irq_status_r}; IRQ_ENABLE: reg_rsp_rdata={31'd0,irq_enable_r}; VERSION: reg_rsp_rdata=32'h1000_0008; CAP: reg_rsp_rdata=32'h001f_ff17;
        CMD_BASE: reg_rsp_rdata=cmd_base_r; CMD_HI: reg_rsp_rdata=cmd_hi_r; CMD_SIZE: reg_rsp_rdata=cmd_size_r; CMD_HEAD: reg_rsp_rdata=processor_cmdq_head; CMD_TAIL: reg_rsp_rdata=cmd_tail_r; CMD_CTRL: reg_rsp_rdata={31'd0,cmdq_external};
        CPL_BASE: reg_rsp_rdata=cpl_base_r; CPL_HI: reg_rsp_rdata=cpl_hi_r; CPL_SIZE: reg_rsp_rdata=cpl_size_r; CPL_TAIL: reg_rsp_rdata=processor_cplq_tail; CPL_HEAD: reg_rsp_rdata=cpl_head_r; QUEUE_STATUS: reg_rsp_rdata={28'd0,processor_busy,cpl_full,cpl_empty,cmd_empty};
        WATCHDOG: reg_rsp_rdata=watchdog_limit; DMA_CTRL: reg_rsp_rdata={30'd0,dma_store,1'b0}; DMA_STATUS: reg_rsp_rdata={29'd0,dma_error_r,dma_done_r,dma_busy}; DMA_EXT: reg_rsp_rdata=dma_ext_addr[31:0]; DMA_EXT_HI: reg_rsp_rdata=dma_ext_addr[63:32]; DMA_SPAD: reg_rsp_rdata=dma_spad_addr; DMA_LEN: reg_rsp_rdata={16'd0,dma_length_words}; DMA_ERROR: reg_rsp_rdata={28'd0,dma_error_code_r};
        R0_BASE:reg_rsp_rdata=r0b; R0_LIMIT:reg_rsp_rdata=r0l; R0_PERM:reg_rsp_rdata={28'd0,r0p}; R1_BASE:reg_rsp_rdata=r1b; R1_LIMIT:reg_rsp_rdata=r1l; R1_PERM:reg_rsp_rdata={28'd0,r1p}; R2_BASE:reg_rsp_rdata=r2b; R2_LIMIT:reg_rsp_rdata=r2l; R2_PERM:reg_rsp_rdata={28'd0,r2p}; R3_BASE:reg_rsp_rdata=r3b; R3_LIMIT:reg_rsp_rdata=r3l; R3_PERM:reg_rsp_rdata={28'd0,r3p};
        DMA_ROW_WORDS:reg_rsp_rdata={16'd0,dma_row_words}; DMA_ROW_COUNT:reg_rsp_rdata={16'd0,dma_row_count}; DMA_EXT_STRIDE:reg_rsp_rdata=dma_ext_stride; DMA_SPAD_STRIDE:reg_rsp_rdata=dma_spad_stride;
        BIAS_BASE:reg_rsp_rdata=bias_base; POST_CTRL:reg_rsp_rdata={31'd0,bias_enable};
        TILE_CTRL:reg_rsp_rdata=32'd0; TILE_COUNT:reg_rsp_rdata={16'd0,tile_count};
        TILE_EXT_IN:reg_rsp_rdata=tile_ext_input_base[31:0]; TILE_EXT_OUT:reg_rsp_rdata=tile_ext_output_base[31:0];
        TILE_EXT_IN_HI:reg_rsp_rdata=tile_ext_input_base[63:32];
        TILE_EXT_OUT_HI:reg_rsp_rdata=tile_ext_output_base[63:32];
        TILE_EXT_IN_STRIDE:reg_rsp_rdata=tile_ext_input_stride; TILE_EXT_OUT_STRIDE:reg_rsp_rdata=tile_ext_output_stride;
        TILE_BUF0:reg_rsp_rdata=tile_buffer0_base; TILE_BUF1:reg_rsp_rdata=tile_buffer1_base;
        TILE_IN_WORDS:reg_rsp_rdata={16'd0,tile_input_words}; TILE_OUT_WORDS:reg_rsp_rdata={16'd0,tile_output_words};
        TILE_OUT_OFFSET:reg_rsp_rdata=tile_output_offset;
        PERF_TOTAL:reg_rsp_rdata=tile_perf_total; PERF_DMA:reg_rsp_rdata=tile_perf_dma;
        PERF_COMPUTE:reg_rsp_rdata=tile_perf_compute; PERF_OVERLAP:reg_rsp_rdata=tile_perf_overlap;
        PERF_STALL:reg_rsp_rdata=tile_perf_stall; TILE_COMPLETED:reg_rsp_rdata={16'd0,tile_completed};
        SPAD_INFO:reg_rsp_rdata=SPAD_BYTES;
        EVENT_STATUS:reg_rsp_rdata={16'd0,processor_dependency_events};
        // Bit 1 used to select the wide backend.  The unified DMA is always
        // 128-bit, so the bit is now a read-only capability indication.
        DMA_CFG:reg_rsp_rdata={21'd0,dma_read_outstanding,6'd0,1'b1,dma_gather_enable};
        DMA_GATHER_INDEX:reg_rsp_rdata=dma_gather_index_base;
        PERF_CTRL:reg_rsp_rdata=32'd0;
        PERF_MATRIX_CYCLES:reg_rsp_rdata=perf_matrix_cycles;
        PERF_MATRIX_MAC_CYCLES:reg_rsp_rdata=perf_matrix_mac_cycles;
        PERF_MATRIX_BANKED_STALL:reg_rsp_rdata=perf_matrix_banked_stall;
        PERF_DMA_READ_BYTES:reg_rsp_rdata=perf_dma_read_bytes;
        PERF_DMA_WRITE_BYTES:reg_rsp_rdata=perf_dma_write_bytes;
        PERF_DMA_AR_COUNT:reg_rsp_rdata=perf_dma_ar_count;
        PERF_DMA_AW_COUNT:reg_rsp_rdata=perf_dma_aw_count;
        PERF_DMA_RD_STATE:reg_rsp_rdata={26'd0,perf_dma_rd_highwater,perf_dma_rd_outstanding};
        PERF_DMA_R_STALL:reg_rsp_rdata=perf_dma_r_stall;
        // ABI 7.1: 64-byte descriptor, 16-byte completion, 64-bit external
        // address path.  CAP2 names the post-unification architectural
        // features without repurposing legacy CAP bits.
        ABI_INFO:reg_rsp_rdata={8'd16,8'd64,8'd2,8'd7};
        ERROR_INFO:reg_rsp_rdata={24'd0,error_source_r,error_code_r};
        CAP2:reg_rsp_rdata=32'h0000_003f;
      endcase
    end
    always @(posedge clk or negedge resetn) begin
      if(!resetn) begin
        done_r<=0; error_r<=0; irq_status_r<=0; irq_enable_r<=0; error_code_r<=0; error_source_r<=0; result_r<=0; cycles_r<=0; elements_r<=0;
        direct_start<=0; submit<=0; core_abort<=0; dma_start<=0; tile_start<=0; perf_clear<=0; cmdq_head_load<=0; cmdq_head_seed<=0; cplq_tail_load<=0; cplq_tail_seed<=0; dma_store<=0; dma_ext_addr<=0; dma_spad_addr<=0; dma_length_words<=0; dma_row_words<=0; dma_row_count<=0; dma_ext_stride<=0; dma_spad_stride<=0; dma_gather_enable<=0; dma_gather_index_base<=0; dma_read_outstanding<=3'd4;
        op_mode<=0; src0_base<=0; src1_base<=0; dst_base<=0; length<=0; m_size<=0; n_size<=0; k_words<=0; scale_shift<=0; activation<=0; watchdog_limit<=0; bias_base<=0; bias_enable<=0;
        tile_count<=0; tile_ext_input_base<=0; tile_ext_output_base<=0; tile_ext_input_stride<=0; tile_ext_output_stride<=0; tile_buffer0_base<=0; tile_buffer1_base<=0; tile_output_offset<=0; tile_input_words<=0; tile_output_words<=0;
        cmd_base_r<=0; cmd_hi_r<=0; cmd_size_r<=0; cmd_tail_r<=0; cmdq_external<=0; cpl_base_r<=0; cpl_hi_r<=0; cpl_size_r<=0; cpl_head_r<=0; dma_done_r<=0; dma_error_r<=0; dma_error_code_r<=0;
        r0b<=0;r0l<=0;r0p<=0;r1b<=0;r1l<=0;r1p<=0;r2b<=0;r2l<=0;r2p<=0;r3b<=0;r3l<=0;r3p<=0;
      end else begin
        direct_start<=0; submit<=0; core_abort<=0; dma_start<=0; tile_start<=0; perf_clear<=0; cmdq_head_load<=0; cplq_tail_load<=0;
        done_r<=done_n; error_r<=error_n; irq_status_r<=irq_status_n;
        error_code_r<=error_code_n; error_source_r<=error_source_n;
        result_r<=result_n; cycles_r<=cycles_n; elements_r<=elements_n;
        dma_done_r<=dma_done_n; dma_error_r<=dma_error_n;
        dma_error_code_r<=dma_error_code_n;
        if(reg_req_valid && reg_req_write && !reg_rsp_error) case(a)
          CTRL: begin irq_enable_r<=reg_req_wdata[1]; if(reg_req_wdata[0] && !processor_busy && !dma_busy) direct_start<=1; end
          STATUS: begin end
          OP:op_mode<=reg_req_wdata[7:0]; SRC0:src0_base<=reg_req_wdata; SRC1:src1_base<=reg_req_wdata; DST:dst_base<=reg_req_wdata; LENGTH:length<=reg_req_wdata[15:0]; M:m_size<=reg_req_wdata[15:0]; N:n_size<=reg_req_wdata[15:0]; K:k_words<=reg_req_wdata[15:0]; QUANT:begin scale_shift<=reg_req_wdata[4:0]; activation<=reg_req_wdata[6:5]; end
          IRQ_STATUS:begin end IRQ_ENABLE:irq_enable_r<=reg_req_wdata[0];
          CMD_BASE:cmd_base_r<=reg_req_wdata; CMD_HI:cmd_hi_r<=reg_req_wdata; CMD_SIZE:cmd_size_r<=reg_req_wdata; CMD_HEAD:begin cmdq_head_load<=1; cmdq_head_seed<=reg_req_wdata; end CMD_TAIL:cmd_tail_r<=reg_req_wdata; CMD_CTRL:cmdq_external<=reg_req_wdata[0]; CPL_BASE:cpl_base_r<=reg_req_wdata; CPL_HI:cpl_hi_r<=reg_req_wdata; CPL_SIZE:cpl_size_r<=reg_req_wdata; CPL_TAIL:begin cplq_tail_load<=1; cplq_tail_seed<=reg_req_wdata; end CPL_HEAD:cpl_head_r<=reg_req_wdata;
          DOORBELL:if(!processor_busy && !dma_busy) submit<=1;
          ABORT:if(reg_req_wdata[0]) core_abort<=1; WATCHDOG:watchdog_limit<=reg_req_wdata;
          DMA_CTRL:begin dma_store<=reg_req_wdata[1]; if(reg_req_wdata[0] && !processor_busy && !dma_busy) dma_start<=1; end
          DMA_STATUS:begin end
          DMA_EXT:dma_ext_addr[31:0]<=reg_req_wdata; DMA_EXT_HI:dma_ext_addr[63:32]<=reg_req_wdata; DMA_SPAD:dma_spad_addr<=reg_req_wdata; DMA_LEN:dma_length_words<=reg_req_wdata[15:0]; DMA_ROW_WORDS:dma_row_words<=reg_req_wdata[15:0]; DMA_ROW_COUNT:dma_row_count<=reg_req_wdata[15:0]; DMA_EXT_STRIDE:dma_ext_stride<=reg_req_wdata; DMA_SPAD_STRIDE:dma_spad_stride<=reg_req_wdata;
          DMA_CFG:begin dma_gather_enable<=reg_req_wdata[0]; dma_read_outstanding<=reg_req_wdata[10:8]; end
          DMA_GATHER_INDEX:dma_gather_index_base<=reg_req_wdata;
          PERF_CTRL:if(reg_req_wdata[0]) perf_clear<=1'b1;
          BIAS_BASE:bias_base<=reg_req_wdata; POST_CTRL:bias_enable<=reg_req_wdata[0];
          TILE_CTRL:if(reg_req_wdata[0] && !processor_busy && !dma_busy) tile_start<=1;
          TILE_COUNT:tile_count<=reg_req_wdata[15:0]; TILE_EXT_IN:tile_ext_input_base[31:0]<=reg_req_wdata; TILE_EXT_OUT:tile_ext_output_base[31:0]<=reg_req_wdata;
          TILE_EXT_IN_HI:tile_ext_input_base[63:32]<=reg_req_wdata;
          TILE_EXT_OUT_HI:tile_ext_output_base[63:32]<=reg_req_wdata;
          TILE_EXT_IN_STRIDE:tile_ext_input_stride<=reg_req_wdata; TILE_EXT_OUT_STRIDE:tile_ext_output_stride<=reg_req_wdata;
          TILE_BUF0:tile_buffer0_base<=reg_req_wdata; TILE_BUF1:tile_buffer1_base<=reg_req_wdata;
          TILE_IN_WORDS:tile_input_words<=reg_req_wdata[15:0]; TILE_OUT_WORDS:tile_output_words<=reg_req_wdata[15:0]; TILE_OUT_OFFSET:tile_output_offset<=reg_req_wdata;
          R0_BASE:r0b<=reg_req_wdata; R0_LIMIT:r0l<=reg_req_wdata; R0_PERM:r0p<=reg_req_wdata[3:0]; R1_BASE:r1b<=reg_req_wdata; R1_LIMIT:r1l<=reg_req_wdata; R1_PERM:r1p<=reg_req_wdata[3:0]; R2_BASE:r2b<=reg_req_wdata; R2_LIMIT:r2l<=reg_req_wdata; R2_PERM:r2p<=reg_req_wdata[3:0]; R3_BASE:r3b<=reg_req_wdata; R3_LIMIT:r3l<=reg_req_wdata; R3_PERM:r3p<=reg_req_wdata[3:0];
        endcase
      end
    end
endmodule
