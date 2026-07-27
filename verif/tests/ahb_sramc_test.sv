//=============================================================================
// Project  : ahb_soc
//
// File Name: ahb_sramc_test.sv
//
// Description:
//   Longer class-based SV test. It uses the same vector accelerator generator
//   sequence with a longer simulation window.
//=============================================================================

program automatic ahb_sramc_test(ahb_slv_if.driver drv_if,
                                 ahb_slv_if.monitor mon_if);

  ahb_slv_generator  generator;
  ahb_slv_driver     driver;
  ahb_slv_monitor    monitor;
  ahb_slv_scoreboard scoreboard;
  ahb_slv_fcoverage  fcoverage;

  int number_packets;

  initial begin
    number_packets = 200;

    generator  = new("ahb_slv_generator", number_packets);
    fcoverage  = new("ahb_slv_fcoverage");
    scoreboard = new("ahb_slv_scoreboard",
                     null,
                     null,
                     fcoverage.sb_mbx);
    monitor    = new("ahb_slv_monitor",
                     mon_if,
                     scoreboard.act_mbx);
    driver     = new("ahb_slv_driver",
                     generator.gen_mbx,
                     drv_if,
                     scoreboard.exp_mbx);

    reset();

    scoreboard.start();
    fcoverage.start();
    monitor.start();
    generator.start();
    driver.start();

    wait_for_driver_done(30000);
    repeat(20) @(drv_if.drv_cb);
    scoreboard.report();
    fcoverage.report();

    if (scoreboard.error_count == 0)
      $display($time, "ns:[ahb_sramc_test] TEST PASS");
    else
      $display($time, "ns:[ahb_sramc_test] TEST FAIL");

    $finish;
  end

  task reset();
    $display($time, "ns:[RESET] Design reset start");
    drv_if.hresetn <= 1'b0;
    drv_if.drv_cb.hsel    <= 1'b0;
    drv_if.drv_cb.hwrite  <= 1'b0;
    drv_if.drv_cb.hready  <= 1'b1;
    drv_if.drv_cb.hsize   <= 3'b010;
    drv_if.drv_cb.htrans  <= 2'b00;
    drv_if.drv_cb.hburst  <= 3'b000;
    drv_if.drv_cb.haddr   <= 32'h0;
    drv_if.drv_cb.hwdata  <= 32'h0;
    repeat(5) @(drv_if.drv_cb);
    drv_if.hresetn <= 1'b1;
    repeat(2) @(drv_if.drv_cb);
    $display($time, "ns:[RESET] Design reset end");
  endtask : reset

  task wait_for_driver_done(int max_cycles);
    fork
      begin
        wait (driver.done == 1'b1);
      end
      begin
        repeat(max_cycles) @(drv_if.drv_cb);
        if (driver.done != 1'b1)
          $display($time, "ns:[ahb_sramc_test][ERROR] Driver timeout, sent=%0d", driver.packets_sent);
      end
    join_any
    disable fork;
  endtask : wait_for_driver_done

endprogram : ahb_sramc_test
