# ====================================================================
# Synopsys Design Constraints (SDC)
# Target : Predictive Slack-Aware Accelerator
# Process: 180nm Standard Cell Library
# Clock  : 250 MHz (4.0 ns period)
# ====================================================================

# 1. Units
set_units -time ns -resistance kOhm -capacitance fF -voltage V -current mA

# 2. Create Clock — 250 MHz target
create_clock -name clk -period 4.0 [get_ports clk]

# 3. Clock Uncertainty & Transition
set_clock_uncertainty 0.200 [get_clocks clk]
set_clock_transition  0.150 [get_clocks clk]

# 4. Input/Output Delays (60% of period budget for external logic)
set_input_delay  -max 2.4 -clock clk [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay -max 2.4 -clock clk [all_outputs]

# 5. Load and Drive Strength
set_load 15 [all_outputs]
set_driving_cell -lib_cell BUFX2 [all_inputs]

# 6. Operating Conditions (Typical corner for 180nm)
# Uncomment and update to match your lab's library naming:
# set_operating_conditions -analysis_type single -library [get_libs {typical_1.8V_25C}]

# 7. Wire Load
set_wire_load_mode segmented

# 8. Design Rule Constraints
set_max_transition 0.5 [current_design]
set_max_fanout     20  [current_design]
