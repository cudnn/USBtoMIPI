set_false_path -from [get_ports {SDA[*]}] -to {pkt_decode:u_cmd_decode|mipi:mipi_u|sf_data[0]}

# For FPGA board   V2
set_false_path -from { mipi_clkpll_v2:mipi_clk_gen|altpll:altpll_component|mipi_clkpll_v2_altpll:auto_generated|wire_pll1_clk[0] } -to [get_ports {SCLK[*]}]
set_output_delay -clock { mipi_clkpll_v2:mipi_clk_gen|altpll:altpll_component|mipi_clkpll_v2_altpll:auto_generated|wire_pll1_clk[0] } -max 1 [get_ports {SDA[*]}]
set_output_delay -clock { mipi_clkpll_v2:mipi_clk_gen|altpll:altpll_component|mipi_clkpll_v2_altpll:auto_generated|wire_pll1_clk[0] } -min -5 [get_ports {SDA[*]}] 

set_false_path -from {pkt_decode:u_cmd_decode|mipi_bank[*]} -to [get_ports {SCLK[*]}]
set_false_path -from {pkt_decode:u_cmd_decode|iodelay:sclk_delay|io_delay*} -to [get_ports {SCLK[*]}]