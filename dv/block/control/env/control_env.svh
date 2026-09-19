class control_env extends uvm_env;
    `uvm_component_utils(control_env)
    control_axil_agent agent;
    control_reg_block ral;
    control_reg_adapter adapter;
    control_scoreboard sb;
    control_coverage cov;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = control_axil_agent::type_id::create("agent", this);
        sb = control_scoreboard::type_id::create("sb", this);
        cov = control_coverage::type_id::create("cov", this);
        ral = control_reg_block::type_id::create("ral"); ral.build();
        adapter = control_reg_adapter::type_id::create("adapter");
    endfunction
    function void connect_phase(uvm_phase phase);
        agent.monitor.ap.connect(sb.ctrl_imp);
        agent.monitor.ap.connect(cov.cov_imp);
        ral.default_map.set_sequencer(agent.sequencer, adapter);
        ral.default_map.set_auto_predict(1);
    endfunction
endclass
