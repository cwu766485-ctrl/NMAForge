class ai_base_test extends uvm_test;
    `uvm_component_utils(ai_base_test)
    ai_accel_env env;
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase); env=ai_accel_env::type_id::create("env",this); endfunction
endclass
