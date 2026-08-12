package ai_accel_env_pkg;
    import uvm_pkg::*;
    import ai_accel_uvm_types_pkg::*;
    import ai_axil_agent_pkg::*;
    import ai_axi4_agent_pkg::*;
    `include "uvm_macros.svh"

    `include "model/ai_accel_reference_model.svh"
    `include "scoreboard/ai_accel_scoreboard.svh"
    `include "coverage/ai_axil_coverage.svh"
    `include "coverage/ai_axi4_coverage.svh"
    `include "ai_accel_env.svh"
endpackage
