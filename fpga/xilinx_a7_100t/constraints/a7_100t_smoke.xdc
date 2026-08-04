## Xilinx Artix-7 100T FGG484 board smoke constraints.
## Source notes:
## - docs/hardware/allegro/pstxnet.dat maps FPGA_SYSCLK_50M to U1 W19.
## - FPGA_CLK maps to TCK_0/JTAG and is intentionally not used here.
## - D2/D3/D4 LED anode nets route through R13/R14/R15 to U1 F20/D21/E21.

set_property PACKAGE_PIN W19 [get_ports sys_clk_50m]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk_50m]
create_clock -name sys_clk_50m -period 20.000 [get_ports sys_clk_50m]

set_property PACKAGE_PIN F20 [get_ports {user_led[0]}]
set_property PACKAGE_PIN D21 [get_ports {user_led[1]}]
set_property PACKAGE_PIN E21 [get_ports {user_led[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {user_led[*]}]
set_property DRIVE 8 [get_ports {user_led[*]}]
set_property SLEW SLOW [get_ports {user_led[*]}]
