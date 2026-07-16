set_property PACKAGE_PIN E19 [get_ports sys_diff_clock_clk_p]
set_property PACKAGE_PIN E18 [get_ports sys_diff_clock_clk_n]
set_property IOSTANDARD LVDS [get_ports sys_diff_clock_clk_p]
set_property IOSTANDARD LVDS [get_ports sys_diff_clock_clk_n]
create_clock -name sys_diff_clock -period 5.000 [get_ports sys_diff_clock_clk_p]

# The UDP/BRAM/DUT-side logic is intentionally constrained as a 100 MHz domain.
create_generated_clock -name app_clk_100 -source [get_pins u_app_mmcm/CLKIN1] -divide_by 2 [get_pins u_app_clk_bufg/O]

# The VC707 200 MHz system clock only feeds clocking/support logic, while the
# PCS/PMA-generated Ethernet clocks remain independent.  CDC into the 100 MHz
# application domain is handled by AXI-Stream async FIFOs in the RTL.
set_clock_groups -asynchronous -group [get_clocks sys_diff_clock] -group [get_clocks {clkout0 clkout1}]
set_clock_groups -asynchronous -group [get_clocks app_clk_100] -group [get_clocks {clkout0 clkout1}]

set_property PACKAGE_PIN AV40 [get_ports reset]
set_property IOSTANDARD LVCMOS18 [get_ports reset]

set_property PACKAGE_PIN AH31 [get_ports mdio_mdc]
set_property IOSTANDARD LVCMOS18 [get_ports mdio_mdc]
set_property PACKAGE_PIN AK33 [get_ports mdio_mdio_io]
set_property IOSTANDARD LVCMOS18 [get_ports mdio_mdio_io]
set_property PACKAGE_PIN AJ33 [get_ports phy_rst_n]
set_property IOSTANDARD LVCMOS18 [get_ports phy_rst_n]

set_property BOARD_PART_PIN {sgmii_mgt_clkp} [get_ports gtrefclk_p]
set_property BOARD_PART_PIN {sgmii_mgt_clkn} [get_ports gtrefclk_n]
set_property BOARD_PART_PIN {sgmii_rxp} [get_ports rxp]
set_property BOARD_PART_PIN {sgmii_rxn} [get_ports rxn]
set_property BOARD_PART_PIN {sgmii_txp} [get_ports txp]
set_property BOARD_PART_PIN {sgmii_txn} [get_ports txn]

set_property CFGBVS GND [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]
