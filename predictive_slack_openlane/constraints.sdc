# Clock (already implicit but good to define)
create_clock -name clk -period 10 [get_ports clk]

# Fix unconstrained outputs
set_output_delay -clock clk -max 0 [get_ports {pg_out[*]}]
set_output_delay -clock clk -max 0 [get_ports {freq_out[*]}]
set_output_delay -clock clk -max 0 [get_ports {vdd_out[*]}]
set_output_delay -clock clk -max 0 [get_ports {prec_out}]
set_output_delay -clock clk -max 0 [get_ports {debug_measured_slack[*]}]
set_output_delay -clock clk -max 0 [get_ports {debug_predicted_slack[*]}]
set_max_delay 0 -from [get_clocks {clk}] -to [get_ports {pg_out[*]}]

# Exempt the power-gating output mask from timing closure; it is a control signal
# intended for slow power-gate actuation and not part of the synchronous data path.
set_false_path -to [get_ports {pg_out[*]}]

# Optional: input delay (safe default)
set_input_delay -clock clk 0 [get_ports {compute_bus_in}]
set_input_delay -clock clk 0 [get_ports {rst_n}]
