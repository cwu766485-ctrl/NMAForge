`timescale 1ns/1ps

// The original BF16 dot environment now exercises both packed BF16 and FP16
// formats through the same mixed-precision core and SPAD transaction model.
package ai_bf16_dot_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `uvm_analysis_imp_decl(_exp)
    `uvm_analysis_imp_decl(_obs)

    localparam logic [31:0] BF16_DOT_SRC0_BASE = 32'h0000_0100;
    localparam logic [31:0] BF16_DOT_SRC1_BASE = 32'h0000_0200;
    localparam logic [31:0] BF16_DOT_DST_BASE  = 32'h0000_0300;

    typedef enum int unsigned {
        FP_FAULT_NONE = 0,
        FP_FAULT_CONFIG,
        FP_FAULT_CONFIG_SRC0_ALIGN,
        FP_FAULT_CONFIG_SRC1_ALIGN,
        FP_FAULT_CONFIG_DST_ALIGN,
        FP_FAULT_READ_PARITY,
        FP_FAULT_READ_B_PARITY,
        FP_FAULT_READ_PARITY_LATE,
        FP_FAULT_READ_PROTECTION,
        FP_FAULT_READ_B_PROTECTION,
        FP_FAULT_READ_LATE_PROTECTION,
        FP_FAULT_READ_LATE_B_PROTECTION,
        FP_FAULT_READ_LATE_PROTECTION_ABORT,
        FP_FAULT_ABORT_WAIT_A,
        FP_FAULT_WATCHDOG,
        FP_FAULT_WRITE_PROTECTION,
        FP_FAULT_ABORT_CALC,
        FP_FAULT_RESET_READ_A,
        FP_FAULT_RESET_WAIT_A,
        FP_FAULT_RESET_READ_B,
        FP_FAULT_RESET_WAIT_B,
        FP_FAULT_RESET_CALC,
        FP_FAULT_RESET_WRITE,
        FP_FAULT_ABORT_UNACCEPTED_A,
        FP_FAULT_ABORT_UNACCEPTED_B
    } fp_fault_mode_e;

    typedef enum int unsigned {
        BF16_CLASS_ZERO      = 0,
        BF16_CLASS_SUBNORMAL = 1,
        BF16_CLASS_NORMAL    = 2,
        BF16_CLASS_INFINITY  = 3,
        BF16_CLASS_NAN       = 4
    } bf16_class_e;

    function automatic bf16_class_e classify_bf16(bit [15:0] value);
        if (value[14:7] == 0)
            return (value[6:0] == 0) ? BF16_CLASS_ZERO : BF16_CLASS_SUBNORMAL;
        if (value[14:7] == 8'hff)
            return (value[6:0] == 0) ? BF16_CLASS_INFINITY : BF16_CLASS_NAN;
        return BF16_CLASS_NORMAL;
    endfunction

    function automatic bf16_class_e classify_fp16(bit [15:0] value);
        if (value[14:10] == 0)
            return (value[9:0] == 0) ? BF16_CLASS_ZERO : BF16_CLASS_SUBNORMAL;
        if (value[14:10] == 5'h1f)
            return (value[9:0] == 0) ? BF16_CLASS_INFINITY : BF16_CLASS_NAN;
        return BF16_CLASS_NORMAL;
    endfunction

    `include "ai_bf16_dot_items.svh"
    `include "ai_bf16_dot_sequence.svh"
    `include "ai_bf16_dot_driver.svh"
    `include "ai_bf16_dot_monitor.svh"
    `include "ai_bf16_dot_scoreboard.svh"
    `include "ai_bf16_dot_coverage.svh"
    `include "ai_bf16_dot_env_test.svh"
endpackage
