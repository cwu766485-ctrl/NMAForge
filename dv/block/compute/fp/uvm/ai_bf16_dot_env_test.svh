    class bf16_dot_agent extends uvm_agent;
        bf16_dot_sequencer sequencer;
        bf16_dot_driver driver;
        bf16_dot_monitor monitor;

        `uvm_component_utils(bf16_dot_agent)
        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            sequencer = bf16_dot_sequencer::type_id::create("sequencer", this);
            driver = bf16_dot_driver::type_id::create("driver", this);
            monitor = bf16_dot_monitor::type_id::create("monitor", this);
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            driver.seq_item_port.connect(sequencer.seq_item_export);
        endfunction
    endclass
    class bf16_dot_env extends uvm_env;
        bf16_dot_agent agent;
        bf16_dot_scoreboard scoreboard;
        bf16_dot_coverage coverage;

        `uvm_component_utils(bf16_dot_env)
        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            agent = bf16_dot_agent::type_id::create("agent", this);
            scoreboard = bf16_dot_scoreboard::type_id::create("scoreboard", this);
            coverage = bf16_dot_coverage::type_id::create("coverage", this);
        endfunction

        virtual function void connect_phase(uvm_phase phase);
            super.connect_phase(phase);
            agent.driver.expected_ap.connect(scoreboard.expected_export);
            agent.monitor.observed_ap.connect(scoreboard.observed_export);
            scoreboard.coverage_ap.connect(coverage.analysis_export);
        endfunction
    endclass

    class mixed_precision_dot_uvm_test extends uvm_test;
        bf16_dot_env env;

        `uvm_component_utils(mixed_precision_dot_uvm_test)
        function new(string name, uvm_component parent);
            super.new(name, parent);
        endfunction

        virtual function void build_phase(uvm_phase phase);
            super.build_phase(phase);
            env = bf16_dot_env::type_id::create("env", this);
        endfunction

        virtual task run_phase(uvm_phase phase);
            bf16_dot_file_sequence seq;
            phase.raise_objection(this);
            seq = bf16_dot_file_sequence::type_id::create("seq");
            if (!$value$plusargs("RANDOM_VECTORS=%s", seq.vector_file))
                `uvm_fatal("BF16/TEST", "Pass +RANDOM_VECTORS=<path>")
            seq.start(env.agent.sequencer);
            phase.drop_objection(this);
        endtask
    endclass
