class control_axil_agent extends uvm_agent;
    `uvm_component_utils(control_axil_agent)
    control_axil_sequencer sequencer;
    control_axil_driver driver;
    control_axil_monitor monitor;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = control_axil_monitor::type_id::create("monitor", this);
        if (is_active == UVM_ACTIVE) begin
            sequencer = control_axil_sequencer::type_id::create("sequencer", this);
            driver = control_axil_driver::type_id::create("driver", this);
        end
    endfunction
    function void connect_phase(uvm_phase phase);
        if (is_active == UVM_ACTIVE) driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
endclass
