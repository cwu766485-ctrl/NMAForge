class dma_block_base_test extends uvm_test;
    dma_block_env env;
    dma_block_cfg cfg;
    `uvm_component_utils(dma_block_base_test)

    function new(string name = "dma_block_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        cfg = dma_block_cfg::type_id::create("cfg");
        uvm_config_db#(dma_block_cfg)::set(this, "env", "cfg", cfg);
        env = dma_block_env::type_id::create("env", this);
    endfunction
endclass
