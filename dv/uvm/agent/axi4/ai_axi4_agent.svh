class ai_axi4_agent extends uvm_agent;
    `uvm_component_utils(ai_axi4_agent)
    ai_axi4_monitor monitor;
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase); is_active=UVM_PASSIVE; monitor=ai_axi4_monitor::type_id::create("monitor",this);
    endfunction
endclass
