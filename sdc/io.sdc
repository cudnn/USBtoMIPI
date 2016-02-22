set_false_path -from [get_ports {P1_IO_DB[*]}] -to {pkt_decode:u_cmd_decode|freq_m:freq_measure|f_io[0]} 
set_false_path -from [get_ports {P1_IO_DB[*]}] -to {pkt_decode:u_cmd_decode|mipi:mipi_u[*].mipi_u|sf_data[0]}
set_false_path -from [get_ports {IO_EN}] -to {IO_1M}
set_false_path -from {IO_EN} -to [get_ports {IO_1M}]
set_false_path -from {s_1m} -to [get_ports {IO_1M}]
