// Passive Stage A observation only. Enable with +STAGE_A_PROFILE=<file prefix>.
// Exclusive clock windows match transformer_top_timing_enable and final-tail
// capture used by the existing Golden/timing checker. No DUT forcing.
integer sa_cycle_fd=0, sa_traffic_fd=0, sa_axi_fd=0, sa_clock=0, sa_window=-1;
integer sa_phase,sa_lane;
reg sa_active=0;
initial begin : stage_a_open
    string path;
    if ($value$plusargs("STAGE_A_PROFILE=%s",path)) begin
        sa_cycle_fd=$fopen({path,"_cycles.csv"},"w");
        sa_traffic_fd=$fopen({path,"_traffic.csv"},"w");
        sa_axi_fd=$fopen({path,"_axi.csv"},"w");
        $fdisplay(sa_axi_fd,"clock,read,address");
        if (!sa_cycle_fd || !sa_traffic_fd || !sa_axi_fd) $fatal(1,"Stage A profile open failed");
        $fdisplay(sa_cycle_fd,"window,clock,phase,matrix_state,sfu_state,sfu_opcode,desc_request,cpl_request,scalar_stall,banked_stall,line_stall,dma_busy");
        $fdisplay(sa_traffic_fd,"window,clock,engine,write,address,bytes");
    end
end
always @(posedge aclk) begin
    sa_clock=sa_clock+1;
    if(sa_axi_fd) begin
        if(s_axi_awvalid && s_axi_awready)
            $fdisplay(sa_axi_fd,"%0d,0,%08h",sa_clock,s_axi_awaddr);
        if(s_axi_arvalid && s_axi_arready)
            $fdisplay(sa_axi_fd,"%0d,1,%08h",sa_clock,s_axi_araddr);
    end
    if(sa_cycle_fd) begin
        if(transformer_top_timing_enable && !transformer_top_final_captured) begin
            if(!sa_active) begin sa_window=sa_window+1;sa_active=1;end
            // Exclusive priority mirrors the existing Top profiler. Multi-engine
            // overlap is reported separately; never add counters from engines.
            if(dut.matrix_busy) begin
                case(dut.compute_cluster_u.tensor_matrix_u.state_r)
                  1,2,3,4,5,6:sa_phase=0; // Matrix initial fetch/drain
                  7,8:sa_phase=1;         // Matrix prepare/execute
                  9:sa_phase=2;           // Matrix output materialization
                  14:sa_phase=3;          // Matrix prefetch wait
                  default:sa_phase=4;     // Matrix lifecycle
                endcase
            end else if(dut.engine_busy[4]) begin
                case(dut.compute_cluster_u.tensor_sfu_u.state_r)
                  1,2,3,4,5,6,10,11,18,19,20,21,23,24,25,26,32,33,36,37,39,40:sa_phase=5;
                  9,27:sa_phase=6; // SFU output materialization
                  28,29:sa_phase=8; // SFU lifecycle
                  default:sa_phase=7; // SFU arithmetic/control, including cache access
                endcase
            end else if(dut.engine_busy[6])sa_phase=9;
            else if(dut.engine_busy[5] || dut.engine_busy[2] || dut.engine_busy[1] || dut.engine_busy[0])sa_phase=10;
            else if(dut.cpl_spad_valid)sa_phase=11;
            else if(dut.desc_spad_valid)sa_phase=12;
            else sa_phase=13; // no-engine control/response/dispatch remainder
            $fdisplay(sa_cycle_fd,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
              sa_window,sa_clock,sa_phase,dut.compute_cluster_u.tensor_matrix_u.state_r,
              dut.compute_cluster_u.tensor_sfu_u.state_r,dut.compute_cluster_u.tensor_sfu_u.op_r,
              dut.desc_spad_valid,dut.cpl_spad_valid,
              |(dut.compute_engine_req_valid & ~dut.compute_engine_ready),
              dut.banked_read_valid && !dut.arb_banked_ready,
              dut.matrix_line_valid && !dut.arb_core_line_ready,dut.dma_busy);
            for(sa_lane=0;sa_lane<7;sa_lane=sa_lane+1)
                if(dut.compute_engine_req_valid[sa_lane] && dut.compute_engine_ready[sa_lane])
                    $fdisplay(sa_traffic_fd,"%0d,%0d,%0d,%0d,%08h,4",sa_window,sa_clock,sa_lane,
                      dut.compute_engine_req_write[sa_lane],dut.compute_engine_req_addr[sa_lane*32+:32]);
            if(dut.banked_read_valid && dut.arb_banked_ready)
                $fdisplay(sa_traffic_fd,"%0d,%0d,3,0,%08h,16",sa_window,sa_clock,dut.matrix_banked_read_addr);
            if(dut.matrix_line_valid && dut.arb_core_line_ready)
                $fdisplay(sa_traffic_fd,"%0d,%0d,3,1,%08h,16",sa_window,sa_clock,dut.matrix_line_addr);
        end else sa_active=0;
    end
end
