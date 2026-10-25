class ai_accel_env extends uvm_env;
    `uvm_component_utils(ai_accel_env)
    ai_axil_agent axil_agent; ai_axi4_agent axi4_agent; ai_accel_scoreboard scoreboard; ai_axil_coverage axil_cov; ai_axi4_coverage axi4_cov;
    ai_compute_cluster_monitor compute_monitor;
    ai_compute_cluster_scoreboard compute_scoreboard;
    ai_compute_cluster_coverage compute_coverage;
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase); axil_agent=ai_axil_agent::type_id::create("axil_agent",this); axi4_agent=ai_axi4_agent::type_id::create("axi4_agent",this); scoreboard=ai_accel_scoreboard::type_id::create("scoreboard",this); axil_cov=ai_axil_coverage::type_id::create("axil_cov",this); axi4_cov=ai_axi4_coverage::type_id::create("axi4_cov",this);
        compute_monitor=ai_compute_cluster_monitor::type_id::create("compute_monitor",this);
        compute_scoreboard=ai_compute_cluster_scoreboard::type_id::create("compute_scoreboard",this);
        compute_coverage=ai_compute_cluster_coverage::type_id::create("compute_coverage",this);
    endfunction
    function void connect_phase(uvm_phase phase);
        axil_agent.monitor.ap.connect(scoreboard.axil_imp); axil_agent.monitor.ap.connect(axil_cov.analysis_export); axi4_agent.monitor.ap.connect(scoreboard.axi4_imp); axi4_agent.monitor.ap.connect(axi4_cov.analysis_export);
        compute_monitor.ap.connect(compute_scoreboard.analysis_export);
        compute_monitor.ap.connect(compute_coverage.analysis_export);
    endfunction
endclass
