package ai_accel_tests_pkg;
    import uvm_pkg::*;
    import ai_accel_uvm_types_pkg::*;
    import ai_axil_agent_pkg::*;
    import ai_accel_env_pkg::*;
    `include "uvm_macros.svh"

    `include "sequences/ai_version_smoke_seq.svh"
    `include "sequences/ai_fp16_ddr_e2e_seq.svh"
    `include "sequences/ai_external_macro_ddr_e2e_seq.svh"
    `include "sequences/ai_compute_cluster_e2e_seq.svh"
    `include "base/ai_base_test.svh"
    `include "smoke/ai_version_smoke_test.svh"
    `include "e2e/ai_fp16_ddr_e2e_test.svh"
    `include "e2e/ai_external_macro_ddr_e2e_test.svh"
    `include "e2e/ai_compute_cluster_e2e_test.svh"
endpackage
