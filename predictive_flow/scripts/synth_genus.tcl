# ====================================================================
# Cadence Genus — Master Synthesis Script
# Target : Predictive Slack-Aware Accelerator
# Process: 180nm Standard Cell Library
# ====================================================================

puts "============================================================"
puts "  GENUS SYNTHESIS — PREDICTIVE ACCELERATOR"
puts "============================================================"

# ----------------------------------------------------------------
# 1. Setup Library Paths
#    *** UPDATE these paths to match your college lab installation ***
# ----------------------------------------------------------------
set_db init_lib_search_path { /home/Cadence/FOUNDRY/digital/180nm/dig/lib }
set_db init_hdl_search_path { ../hdl }
set_db library { typical.lib }

# ----------------------------------------------------------------
# 2. Read RTL Source Files
# ----------------------------------------------------------------
read_hdl -sv { \
    ../hdl/slack_monitor.v \
    ../hdl/ewma_predictor.v \
    ../hdl/adapt_ctrl.v \
    ../hdl/predictive_top.v \
}

puts "--- HDL Read Complete ---"

# ----------------------------------------------------------------
# 3. Elaborate Top-Level Design
# ----------------------------------------------------------------
elaborate predictive_top
puts "--- Elaboration Complete ---"

# ----------------------------------------------------------------
# 4. Apply Timing Constraints
# ----------------------------------------------------------------
read_sdc ../scripts/constraints.sdc
puts "--- Constraints Applied ---"

# ----------------------------------------------------------------
# 5. Synthesis Flow (3-Stage)
# ----------------------------------------------------------------
# syn_generic : Technology-independent optimization
# syn_map     : Map to target library cells
# syn_opt     : Final timing/area/power optimization
syn_generic
puts "--- Generic Synthesis Complete ---"

syn_map
puts "--- Technology Mapping Complete ---"

syn_opt
puts "--- Optimization Complete ---"

# ----------------------------------------------------------------
# 6. Report Extraction (For Paper Tables II & III)
# ----------------------------------------------------------------
report_area          > ../results/genus_area_report.txt
report_timing        > ../results/genus_timing_report.txt
report_power         > ../results/genus_power_report.txt
report_gates         > ../results/genus_gates_report.txt
report_qor           > ../results/genus_qor_report.txt

puts "--- Reports Saved to results/ ---"

# ----------------------------------------------------------------
# 7. Export Netlist & Constraints for Innovus
# ----------------------------------------------------------------
write_hdl > ../results/predictive_netlist.v
write_sdc > ../results/predictive_constraints.sdc

puts "============================================================"
puts "  GENUS SYNTHESIS COMPLETE"
puts "  Netlist : ../results/predictive_netlist.v"
puts "  SDC     : ../results/predictive_constraints.sdc"
puts "  Next    : Run innovus_flow.tcl for Place & Route"
puts "============================================================"
exit
