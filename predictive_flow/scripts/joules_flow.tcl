# ====================================================================
# Cadence Joules — Power Analysis Script
# Target : Dynamic Power Extraction using Simulation Data (VCD)
# Purpose: Generate the exact power breakdown for Figure 6 & Figure 7
# ====================================================================

puts "============================================================"
puts "  JOULES POWER ANALYSIS — PREDICTIVE ACCELERATOR"
puts "============================================================"

# ----------------------------------------------------------------
# 1. Setup 180nm Library
#    *** UPDATE this path to match your college lab installation ***
# ----------------------------------------------------------------
set_db library /home/Cadence/FOUNDRY/digital/180nm/dig/lib/typical.lib

# ----------------------------------------------------------------
# 2. Read Synthesized Netlist & Constraints
# ----------------------------------------------------------------
read_netlist ../results/predictive_netlist.v
read_sdc     ../results/predictive_constraints.sdc
puts "--- Netlist & Constraints Loaded ---"

# ----------------------------------------------------------------
# 3. Read Simulation Activity Data (VCD from Xcelium)
#    CRITICAL: -dut must match the testbench instance path (uut)
# ----------------------------------------------------------------
read_stimulus -file ../results/predictive_workload.vcd \
              -dut  tb_predictive_top/uut
puts "--- VCD Stimulus Loaded ---"

# ----------------------------------------------------------------
# 4. Compute Power
# ----------------------------------------------------------------
compute_power
puts "--- Power Computation Complete ---"

# ----------------------------------------------------------------
# 5. Generate Power Reports (For Figure 6 & Figure 7)
# ----------------------------------------------------------------
report_power -level all  > ../results/joules_power_breakdown.txt
report_power -hierarchy  > ../results/joules_power_hierarchy.txt

puts "============================================================"
puts "  JOULES ANALYSIS COMPLETE"
puts "  ► Breakdown : ../results/joules_power_breakdown.txt"
puts "  ► Hierarchy : ../results/joules_power_hierarchy.txt"
puts "============================================================"
exit
