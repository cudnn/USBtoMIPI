## Generated SDC file "Z:/USBToMIPI/FPGA/sdc/clocks.sdc"

## Copyright (C) 1991-2015 Altera Corporation. All rights reserved.
## Your use of Altera Corporation's design tools, logic functions 
## and other software and tools, and its AMPP partner logic 
## functions, and any output files from any of the foregoing 
## (including device programming or simulation files), and any 
## associated documentation or information are expressly subject 
## to the terms and conditions of the Altera Program License 
## Subscription Agreement, the Altera Quartus Prime License Agreement,
## the Altera MegaCore Function License Agreement, or other 
## applicable license agreement, including, without limitation, 
## that your use is for the sole purpose of programming logic 
## devices manufactured by Altera and sold by Altera or its 
## authorized distributors.  Please refer to the applicable 
## agreement for further details.


## VENDOR  "Altera"
## PROGRAM "Quartus Prime"
## VERSION "Version 15.1.0 Build 185 10/21/2015 SJ Standard Edition"

## DATE    "Thu Nov 19 13:32:09 2015"

##
## DEVICE  "EP4CE10F17C8"
##


#**************************************************************
# Time Information
#**************************************************************

set_time_format -unit ns -decimal_places 3



#**************************************************************
# Create Clock
#**************************************************************

create_clock -name {CLK1} -period 20.833 -waveform { 0.000 10.416 } [get_ports {CLK1}]
create_clock -name {CLK2} -period 20 -waveform { 0.000 19.231 } [get_ports {CLK2}]

#**************************************************************
# Create Generated Clock
#**************************************************************

derive_pll_clocks -use_net_name


#**************************************************************
# Set Clock Latency
#**************************************************************


#**************************************************************
# Set Clock Uncertainty
#**************************************************************

derive_clock_uncertainty


#**************************************************************
# Set Input Delay
#**************************************************************



#**************************************************************
# Set Output Delay
#**************************************************************



#**************************************************************
# Set Clock Groups
#**************************************************************

set_clock_groups -exclusive -group [get_clocks {clk_gen:main_clk_gen|altpll:altpll_component|clk_gen_altpll:auto_generated|wire_pll1_clk[0]}] -group [get_clocks {mipi_clkpll_v2:mipi_clk_gen|altpll:altpll_component|mipi_clkpll_v2_altpll:auto_generated|wire_pll1_clk[0]}]
set_clock_groups -exclusive -group [get_clocks {clk_gen:main_clk_gen|altpll:altpll_component|clk_gen_altpll:auto_generated|wire_pll1_clk[0]}] -group [get_clocks {mipi_clkpll_v2:mipi_clk_gen|altpll:altpll_component|mipi_clkpll_v2_altpll:auto_generated|wire_pll1_clk[1]}]
set_clock_groups -exclusive -group [get_clocks {mipi_clkpll_v2:mipi_clk_gen|altpll:altpll_component|mipi_clkpll_v2_altpll:auto_generated|wire_pll1_clk[0]}] -group [get_clocks {mipi_clkpll_v2:mipi_clk_gen|altpll:altpll_component|mipi_clkpll_v2_altpll:auto_generated|wire_pll1_clk[1]}]

#**************************************************************
# Set False Path
#**************************************************************



#**************************************************************
# Set Multicycle Path
#**************************************************************



#**************************************************************
# Set Maximum Delay
#**************************************************************



#**************************************************************
# Set Minimum Delay
#**************************************************************



#**************************************************************
# Set Input Transition
#**************************************************************

