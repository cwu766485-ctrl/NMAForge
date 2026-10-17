package control_tests_pkg;
    import uvm_pkg::*;
    import control_axil_types_pkg::*;
    import control_axil_agent_pkg::*;
    import control_env_pkg::*;
    `include "uvm_macros.svh"
    `include "control_base_test.svh"
    `include "control_sequences.svh"

    class control_reset_version_test extends control_base_test;
        `uvm_component_utils(control_reset_version_test)
        function new(string name="control_reset_version_test", uvm_component parent=null); super.new(name,parent); endfunction
        task run_phase(uvm_phase phase);
            control_reset_version_seq seq = control_reset_version_seq::type_id::create("seq");
            phase.raise_objection(this); seq.start(env.agent.sequencer); phase.drop_objection(this);
        endtask
    endclass
    class control_register_file_test extends control_base_test;
        `uvm_component_utils(control_register_file_test)
        function new(string name="control_register_file_test", uvm_component parent=null); super.new(name,parent); endfunction
        task run_phase(uvm_phase phase);
            control_register_file_seq seq = control_register_file_seq::type_id::create("seq");
            phase.raise_objection(this); seq.start(env.agent.sequencer); phase.drop_objection(this);
        endtask
    endclass
    class control_protocol_test extends control_base_test;
        `uvm_component_utils(control_protocol_test)
        function new(string name="control_protocol_test", uvm_component parent=null); super.new(name,parent); endfunction
        task run_phase(uvm_phase phase);
            control_protocol_seq seq = control_protocol_seq::type_id::create("seq");
            phase.raise_objection(this); seq.start(env.agent.sequencer); phase.drop_objection(this);
        endtask
    endclass
    class control_channel_backpressure_test extends control_base_test;
        `uvm_component_utils(control_channel_backpressure_test)
        function new(string name="control_channel_backpressure_test", uvm_component parent=null); super.new(name,parent); endfunction
        task run_phase(uvm_phase phase);
            control_channel_backpressure_seq seq = control_channel_backpressure_seq::type_id::create("seq");
            phase.raise_objection(this); seq.start(env.agent.sequencer); phase.drop_objection(this);
        endtask
    endclass
    class control_inflight_reset_test extends control_base_test;
        `uvm_component_utils(control_inflight_reset_test)
        function new(string name="control_inflight_reset_test", uvm_component parent=null); super.new(name,parent); endfunction
        task run_phase(uvm_phase phase);
            control_inflight_reset_seq seq = control_inflight_reset_seq::type_id::create("seq");
            phase.raise_objection(this); seq.start(env.agent.sequencer); phase.drop_objection(this);
        endtask
    endclass
    class control_irq_error_test extends control_base_test;
        `uvm_component_utils(control_irq_error_test)
        function new(string name="control_irq_error_test", uvm_component parent=null); super.new(name,parent); endfunction
        task run_phase(uvm_phase phase);
            control_irq_error_seq seq = control_irq_error_seq::type_id::create("seq");
            phase.raise_objection(this); seq.start(env.agent.sequencer); phase.drop_objection(this);
        endtask
    endclass
    class control_busy_abort_test extends control_base_test;
        `uvm_component_utils(control_busy_abort_test)
        function new(string name="control_busy_abort_test", uvm_component parent=null); super.new(name,parent); endfunction
        task run_phase(uvm_phase phase);
            control_busy_abort_seq seq = control_busy_abort_seq::type_id::create("seq");
            phase.raise_objection(this); seq.start(env.agent.sequencer); phase.drop_objection(this);
        endtask
    endclass
    class control_random_rw_test extends control_base_test;
        `uvm_component_utils(control_random_rw_test)
        function new(string name="control_random_rw_test", uvm_component parent=null); super.new(name,parent); endfunction
        task run_phase(uvm_phase phase);
            control_random_rw_seq seq = control_random_rw_seq::type_id::create("seq");
            phase.raise_objection(this); seq.start(env.agent.sequencer); phase.drop_objection(this);
        endtask
    endclass

    // This test intentionally uses the real UVM register model rather than
    // direct sequence items.  It proves that the generated P0 RAL map,
    // sequencer binding, adapter and monitor-driven predictor work together.
    class control_ral_access_test extends control_base_test;
        `uvm_component_utils(control_ral_access_test)
        function new(string name="control_ral_access_test", uvm_component parent=null); super.new(name,parent); endfunction
        task run_phase(uvm_phase phase);
            uvm_status_e status;
            uvm_reg_data_t value;
            phase.raise_objection(this);
            env.ral.version.read(status, value, UVM_FRONTDOOR, env.ral.default_map);
            if (status != UVM_IS_OK || value != 32'h1000_000a)
                `uvm_error("RAL", $sformatf("VERSION read status=%s value=%08h", status.name(), value))
            env.ral.op.write(status, 32'h0000_005a, UVM_FRONTDOOR, env.ral.default_map);
            if (status != UVM_IS_OK)
                `uvm_error("RAL", $sformatf("OP write status=%s", status.name()))
            env.ral.op.read(status, value, UVM_FRONTDOOR, env.ral.default_map);
            if (status != UVM_IS_OK || value != 32'h0000_005a)
                `uvm_error("RAL", $sformatf("OP read status=%s value=%08h", status.name(), value))
            phase.drop_objection(this);
        endtask
    endclass
endpackage
