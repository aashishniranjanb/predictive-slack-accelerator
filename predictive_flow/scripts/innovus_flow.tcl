# ====================================================================
# Cadence Innovus — Place & Route Script (180nm SAFE MODE)
# Target : Predictive Slack-Aware Accelerator
# Includes: globalNetConnect fix for unrouted power nets
# ====================================================================

puts "============================================================"
puts "  INNOVUS PLACE & ROUTE — PREDICTIVE ACCELERATOR"
puts "============================================================"

# ----------------------------------------------------------------
# 1. Setup 180nm Libraries
#    *** UPDATE these paths to match your college lab installation ***
# ----------------------------------------------------------------
set_db init_lib_search_path /home/Cadence/FOUNDRY/digital/180nm/dig/lib
set_db init_lef_file        /home/Cadence/FOUNDRY/digital/180nm/dig/lef/typical.lef
set_db init_verilog         ../results/predictive_netlist.v
set_db init_top_cell        predictive_top
set_db init_pwr_net         VDD
set_db init_gnd_net         VSS

# ----------------------------------------------------------------
# 2. Initialize Design
# ----------------------------------------------------------------
init_design
puts "--- Design Initialized ---"

# ----------------------------------------------------------------
# 3. CRITICAL FIX: Explicitly Connect Global Power Nets
#    Without this, Innovus will fail to power the cells → DRC errors
# ----------------------------------------------------------------
globalNetConnect VDD -type pgpin -pin VDD -inst *
globalNetConnect VSS -type pgpin -pin VSS -inst *
globalNetConnect VDD -type tiehi
globalNetConnect VSS -type tielo
puts "--- Global Power Nets Connected ---"

# ----------------------------------------------------------------
# 4. Apply SDC Constraints (From Genus output)
# ----------------------------------------------------------------
read_sdc ../results/predictive_constraints.sdc

# ----------------------------------------------------------------
# 5. Floorplanning
#    Aspect ratio = 1.0 (square), Core Utilization = 70%, Margins = 10µm
# ----------------------------------------------------------------
floorPlan -r 1.0 0.7 10 10 10 10
puts "--- Floorplan Created ---"

# ----------------------------------------------------------------
# 6. Power Planning — Rings and Stripes
# ----------------------------------------------------------------
addRing   -nets {VDD VSS} -width 2 -spacing 1 \
          -layer {top met1 bottom met1 left met2 right met2}
addStripe -nets {VDD VSS} -layer met2 -direction vertical \
          -width 1 -spacing 2 -set_to_set_distance 20
puts "--- Power Grid Created ---"

# ----------------------------------------------------------------
# 7. Placement — Standard Cell Placement
# ----------------------------------------------------------------
place_opt_design
puts "--- Placement Complete ---"

# ----------------------------------------------------------------
# 8. Clock Tree Synthesis (CTS)
#    Ensures the 250 MHz clock reaches all registers simultaneously
# ----------------------------------------------------------------
create_ccopt_clock_tree_spec
ccopt_design
puts "--- CTS Complete ---"

# ----------------------------------------------------------------
# 9. Routing — NanoRoute
# ----------------------------------------------------------------
routeDesign
setExtractRCMode -engine postRoute
extractRC
puts "--- Routing Complete ---"

# ----------------------------------------------------------------
# 10. Post-Route Optimization & Reporting
# ----------------------------------------------------------------
optDesign -postRoute

report_timing > ../results/innovus_timing_report.txt
report_area   > ../results/innovus_area_report.txt
report_power  > ../results/innovus_power_report.txt

# ----------------------------------------------------------------
# 11. Save Final Design
# ----------------------------------------------------------------
saveDesign ../results/predictive_routed.enc

puts "============================================================"
puts "  INNOVUS PLACE & ROUTE COMPLETE"
puts "  ► TAKE YOUR LAYOUT SCREENSHOT NOW (View → Color Prefs)"
puts "  ► Timing : ../results/innovus_timing_report.txt"
puts "  ► Area   : ../results/innovus_area_report.txt"
puts "  ► Next   : Run joules_flow.tcl for Power Analysis"
puts "============================================================"
