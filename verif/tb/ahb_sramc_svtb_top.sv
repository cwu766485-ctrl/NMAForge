module ahb_sramc_svtb_top();
 
  bit  hclk;
  bit  sram_clk;
  bit  hresetn;

  ahb_slv_if ahb_sramc_if(hclk);
 
  vec_accel_top u_vec_accel_top
  (
	.hclk	  	(hclk),
	.sram_clk	(sram_clk),
	.hresetn	(ahb_sramc_if.hresetn),
	.hsel		  (ahb_sramc_if.hsel),
	.hwrite		(ahb_sramc_if.hwrite),
	.hready		(ahb_sramc_if.hready),
	.hsize		(ahb_sramc_if.hsize),    
	.hburst		(ahb_sramc_if.hburst),
	.htrans		(ahb_sramc_if.htrans),
	.hwdata		(ahb_sramc_if.hwdata),
	.haddr		(ahb_sramc_if.haddr),		
	.dft_en		(1'b0),
	.bist_en	(1'b0),
	.hready_resp(ahb_sramc_if.hready_resp),
	.hresp		(ahb_sramc_if.hresp),
	.hrdata		(ahb_sramc_if.hrdata),
  .irq      (ahb_sramc_if.irq),
	.bist_done	(),
	.bist_fail	()
);

  ahb_sramc_base_test test (ahb_sramc_if, ahb_sramc_if);
  //ahb_sramc_test test (ahb_sramc_if, ahb_sramc_if);

  vec_accel_sva #(
    .SRAM_WAIT_CYCLES(1)
  ) u_vec_accel_sva (
    .hclk          (hclk),
    .hresetn       (ahb_sramc_if.hresetn),
    .hsel          (ahb_sramc_if.hsel),
    .hready        (ahb_sramc_if.hready),
    .hwrite        (ahb_sramc_if.hwrite),
    .htrans        (ahb_sramc_if.htrans),
    .hsize         (ahb_sramc_if.hsize),
    .hburst        (ahb_sramc_if.hburst),
    .haddr         (ahb_sramc_if.haddr),
    .hwdata        (ahb_sramc_if.hwdata),
    .hready_resp   (ahb_sramc_if.hready_resp),
    .hresp         (ahb_sramc_if.hresp),
    .hrdata        (ahb_sramc_if.hrdata),
    .irq           (ahb_sramc_if.irq),
    .core_busy     (u_vec_accel_top.core_busy),
    .core_start    (u_vec_accel_top.core_start),
    .core_done     (u_vec_accel_top.core_done),
    .core_error    (u_vec_accel_top.core_error),
    .core_sram_req (u_vec_accel_top.core_sram_req)
  );

  initial begin
    hclk = 0;
    forever begin
      #10 hclk = ~hclk;
    end
  end 

  initial begin
    sram_clk = 1;
    forever begin
      #10 sram_clk = ~sram_clk;
    end
   end 


  initial begin
    if($test$plusargs("VCD_ON")) begin
      $dumpfile("ahb_sramc_svtb_top.vcd");
      $dumpvars(0, ahb_sramc_svtb_top);
    end
`ifdef VCS
    if($test$plusargs("VPD_ON")) begin
      $vcdpluson();
      $vcdplusmemon();
    end
`endif
  end   
endmodule
