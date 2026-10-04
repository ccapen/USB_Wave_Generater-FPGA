create_clock -name {clk_in} -period 20.000 -waveform {0.000 10.000} [get_ports {I_clk}]
#create_generated_clock -name {mclk} -source [get_ports {I_clk}] -master_clock {clk_in} -multiply_by 2.500 -phase 0 [get_nets {pll_u.clk0_out}] -add 
#create_generated_clock -name {mclk_shift} -source [get_ports {I_clk}] -master_clock {clk_in} -multiply_by 2.500 -phase 330 [get_nets {pll_u.clk1_out}] -add 




derive_clocks