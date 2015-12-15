set_false_path -from [get_ports {SDA}] -to {pkt_decode:u_cmd_decode|mipi:mipi_u|sf_data[0]}

set_false_path -from { clk_gen:clk_gen_u|altpll:altpll_component|clk_gen_altpll:auto_generated|wire_pll1_clk[0] } -to [get_ports {SCLK}]
set_output_delay -clock { clk_gen:clk_gen_u|altpll:altpll_component|clk_gen_altpll:auto_generated|wire_pll1_clk[0] } -max 1 [get_ports {SDA}]
set_output_delay -clock { clk_gen:clk_gen_u|altpll:altpll_component|clk_gen_altpll:auto_generated|wire_pll1_clk[0] } -min -5 [get_ports {SDA}] 