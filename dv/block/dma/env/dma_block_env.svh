class dma_block_env extends uvm_env;
    dma_block_cfg cfg;
    dma_cmd_sequencer cmd_sqr;
    dma_cmd_driver cmd_drv;
    dma_axi_read_responder axi_rsp;
    dma_spad_model spad_model;
    dma_axi_monitor axi_mon;
    dma_spad_monitor spad_mon;
    dma_block_scoreboard sb;
    `uvm_component_utils(dma_block_env)

    function new(string name = "dma_block_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(dma_block_cfg)::get(this, "", "cfg", cfg))
            cfg = dma_block_cfg::type_id::create("cfg");
        cmd_sqr = dma_cmd_sequencer::type_id::create("cmd_sqr", this);
        cmd_drv = dma_cmd_driver::type_id::create("cmd_drv", this);
        axi_rsp = dma_axi_read_responder::type_id::create("axi_rsp", this);
        spad_model = dma_spad_model::type_id::create("spad_model", this);
        axi_mon = dma_axi_monitor::type_id::create("axi_mon", this);
        spad_mon = dma_spad_monitor::type_id::create("spad_mon", this);
        sb = dma_block_scoreboard::type_id::create("sb", this);
        uvm_config_db#(dma_block_cfg)::set(this, "axi_rsp", "cfg", cfg);
        uvm_config_db#(dma_block_cfg)::set(this, "spad_model", "cfg", cfg);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        cmd_drv.seq_item_port.connect(cmd_sqr.seq_item_export);
        cmd_drv.cmd_ap.connect(sb.cmd_imp);
        spad_mon.write_ap.connect(sb.spad_imp);
        axi_mon.write_ap.connect(sb.axi_imp);
    endfunction
endclass
