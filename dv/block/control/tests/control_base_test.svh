class control_base_test extends uvm_test;
    `uvm_component_utils(control_base_test)
    control_env env;
    virtual ai_control_status_if status_vif;
    function new(string name = "control_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual ai_control_status_if)::get(this, "", "status_vif", status_vif))
            `uvm_fatal("NOVIF", "control_base_test requires status_vif")
        env = control_env::type_id::create("env", this);
    endfunction
endclass
