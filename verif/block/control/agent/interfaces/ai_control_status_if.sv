// Test-only status/side-effect boundary for the AXI-Lite control block.
// Inputs model the command processor, DMA and performance-monitor feedback;
// outputs expose the register-file control pulses and IRQ for UVM checking.
interface ai_control_status_if(input logic clk);
    logic processor_busy;
    logic processor_event_valid;
    logic processor_event_error;
    logic [3:0] processor_event_error_code;
    logic [31:0] processor_event_result;
    logic [31:0] processor_event_cycles;
    logic [31:0] processor_event_elements;
    logic [31:0] processor_cmdq_head;
    logic [31:0] processor_cplq_tail;
    logic [15:0] processor_dependency_events;

    logic dma_busy;
    logic dma_done;
    logic dma_error;
    logic [3:0] dma_error_code;

    logic [31:0] tile_perf_total, tile_perf_dma, tile_perf_compute;
    logic [31:0] tile_perf_overlap, tile_perf_stall;
    logic [15:0] tile_completed;
    logic [31:0] perf_matrix_cycles, perf_matrix_mac_cycles;
    logic [31:0] perf_matrix_banked_stall, perf_dma_read_bytes;
    logic [31:0] perf_dma_write_bytes, perf_dma_ar_count, perf_dma_aw_count;
    logic [31:0] perf_dma_r_stall;
    logic [2:0] perf_dma_rd_outstanding, perf_dma_rd_highwater;

    logic direct_start, submit, core_abort, dma_start, dma_store;
    logic tile_start, perf_clear, irq;

    initial begin
        processor_busy = 0; processor_event_valid = 0; processor_event_error = 0;
        processor_event_error_code = '0; processor_event_result = '0;
        processor_event_cycles = '0; processor_event_elements = '0;
        processor_cmdq_head = '0; processor_cplq_tail = '0;
        processor_dependency_events = '0;
        dma_busy = 0; dma_done = 0; dma_error = 0; dma_error_code = '0;
        tile_perf_total = '0; tile_perf_dma = '0; tile_perf_compute = '0;
        tile_perf_overlap = '0; tile_perf_stall = '0; tile_completed = '0;
        perf_matrix_cycles = '0; perf_matrix_mac_cycles = '0;
        perf_matrix_banked_stall = '0; perf_dma_read_bytes = '0;
        perf_dma_write_bytes = '0; perf_dma_ar_count = '0; perf_dma_aw_count = '0;
        perf_dma_r_stall = '0; perf_dma_rd_outstanding = '0; perf_dma_rd_highwater = '0;
    end
endinterface
