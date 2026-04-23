# 🚀 Predictive Slack-Aware Accelerator — Lab Execution Guide

> **Target**: 180nm CMOS · 250 MHz (4.0 ns) · Cadence Digital Flow  
> **Tools**: Xcelium → Genus → Innovus → Joules  
> **Output**: Area (Table III), Timing (Table II), Power (Figure 6 & 7)

---

## 📋 Table of Contents

1. [Pre-Flight Checklist](#1--pre-flight-checklist)
2. [Step 1 — Workspace Setup](#2--step-1--workspace-setup)
3. [Step 2 — RTL Simulation (Xcelium)](#3--step-2--rtl-simulation-xcelium)
4. [Step 3 — Logic Synthesis (Genus)](#4--step-3--logic-synthesis-genus)
5. [Step 4 — Place & Route (Innovus)](#5--step-4--place--route-innovus)
6. [Step 5 — Power Analysis (Joules)](#6--step-5--power-analysis-joules)
7. [Reading Your Results](#7--reading-your-results)
8. [Troubleshooting](#8--troubleshooting)

---

## 1. 🛫 Pre-Flight Checklist

Before touching any Cadence tool, verify you have:

| Item | Check | Notes |
|------|-------|-------|
| CentOS terminal access | ☐ | SSH or local |
| Cadence license sourced | ☐ | `source /path/to/cshrc.cds` |
| 180nm PDK available | ☐ | `.lib`, `.lef` files |
| `predictive_flow/` uploaded | ☐ | All 5 RTL + 4 scripts |
| X11 forwarding (for GUI) | ☐ | `ssh -X user@server` |

### Verify Cadence Tools Are Available

```bash
which genus      # Should print: /path/to/genus
which innovus    # Should print: /path/to/innovus
which xrun       # Should print: /path/to/xrun
which joules     # Should print: /path/to/joules
```

### Source the Tool Environment (if not auto-loaded)

```bash
source /home/Cadence/install/cshrc.cds
# OR (depending on your lab setup):
module load cadence/2023
```

---

## 2. 📁 Step 1 — Workspace Setup

### Create a Clean Workspace

```bash
# Upload the predictive_flow/ folder to the server, then:
cd predictive_flow

# Create a work directory (keeps tool junk out of your source tree)
mkdir -p work
cd work
```

### Verify Your File Tree

```bash
cd .. && find . -type f | sort && cd work
```

Expected output:
```
./hdl/adapt_ctrl.v
./hdl/ewma_predictor.v
./hdl/predictive_top.v
./hdl/slack_monitor.v
./hdl/tb_predictive_top.v
./scripts/constraints.sdc
./scripts/innovus_flow.tcl
./scripts/joules_flow.tcl
./scripts/synth_genus.tcl
```

### ⚠️ Update Library Paths

Before running **any** script, you **must** update the library paths in these files to match your lab:

| File | Variable to Update | Example Path |
|------|--------------------|-------------|
| `synth_genus.tcl` | `init_lib_search_path` | `/home/Cadence/FOUNDRY/digital/180nm/dig/lib` |
| `innovus_flow.tcl` | `init_lib_search_path`, `init_lef_file` | Same as above + `.lef` path |
| `joules_flow.tcl` | `library` | Full path to `typical.lib` |

Use `sed` for quick inline edits:
```bash
# Example: Replace the library path in all scripts
sed -i 's|/home/Cadence/FOUNDRY/digital/180nm/dig/lib|/your/actual/lib/path|g' ../scripts/*.tcl
```

---

## 3. 🔬 Step 2 — RTL Simulation (Xcelium)

**Purpose**: Prove the predictor works visually + generate the `.vcd` file for Joules.

### Run Simulation (Headless)

```bash
cd predictive_flow/work

xrun -64bit -access +rwc ../hdl/*.v \
     -timescale 1ns/1ps \
     -input "@run" \
     -input "@exit"
```

### Run Simulation (With GUI — for waveform screenshot)

```bash
xrun -64bit -gui -access +rwc ../hdl/*.v -timescale 1ns/1ps
```

**Inside SimVision GUI:**
1. In the left panel, expand `tb_predictive_top` → `uut`
2. Select these signals:
   - `debug_measured_slack`
   - `debug_predicted_slack`
   - `freq_out`
   - `vdd_out`
   - `prec_sel`
   - `pg_out`
3. Right-click → **Send to Waveform Window**
4. Press **Run** (F2 or green arrow)
5. 📸 **Take a screenshot** → This is your **Figure 5**

### Verify VCD Was Generated

```bash
ls -lh ../results/predictive_workload.vcd
# Should be several MB in size
```

> **If the VCD is 0 bytes or missing**, check that `$dumpfile` path in the testbench resolves correctly from your `work/` directory.

---

## 4. ⚙️ Step 3 — Logic Synthesis (Genus)

**Purpose**: Translate RTL → 180nm logic gates. Produces **Area** (Table III) and **Timing** (Table II).

### Run Synthesis

```bash
cd predictive_flow/work

genus -f ../scripts/synth_genus.tcl | tee ../logs/genus.log
```

### What to Expect

The script will:
1. Read all 4 RTL files
2. Elaborate `predictive_top` as the top module
3. Apply the 250 MHz (4.0 ns) clock constraint
4. Run 3-stage synthesis: `syn_generic` → `syn_map` → `syn_opt`
5. Export reports to `results/` and the synthesized netlist

### Verify Outputs

```bash
ls ../results/
# Should contain:
#   genus_area_report.txt
#   genus_timing_report.txt
#   genus_power_report.txt
#   genus_gates_report.txt
#   genus_qor_report.txt
#   predictive_netlist.v      ← REQUIRED for Innovus
#   predictive_constraints.sdc ← REQUIRED for Innovus
```

### Quick Area Check

```bash
grep -i "total" ../results/genus_area_report.txt
```

### Quick Timing Check (Must be positive slack!)

```bash
grep -i "slack" ../results/genus_timing_report.txt
```

> **If WNS (Worst Negative Slack) is negative**, your design doesn't meet timing at 250 MHz. Try relaxing the clock period in `constraints.sdc` to 5.0 ns (200 MHz).

---

## 5. 🏗️ Step 4 — Place & Route (Innovus)

**Purpose**: Place gates on silicon, route wires, generate the **chip layout screenshot** and **post-route timing**.

### Prerequisites

✅ Genus must have completed successfully  
✅ `results/predictive_netlist.v` must exist  
✅ `results/predictive_constraints.sdc` must exist

### Run Innovus (GUI Mode — Required for Screenshot)

```bash
cd predictive_flow/work

innovus -gui
```

**Inside the Innovus console (bottom of GUI window):**

```tcl
source ../scripts/innovus_flow.tcl
```

### What to Expect

The script will execute in this order:
1. `init_design` — Load netlist and libraries
2. `globalNetConnect` — **Critical fix** for power net connectivity
3. `floorPlan` — Create 70% utilization square floorplan
4. `addRing` + `addStripe` — Build VDD/VSS power grid
5. `place_opt_design` — Place standard cells
6. `ccopt_design` — Clock Tree Synthesis (250 MHz)
7. `routeDesign` — Connect all metal wires
8. `optDesign -postRoute` — Final optimization
9. Reports saved to `results/`

### 📸 Take the Layout Screenshot (Figure 8)

Once the script finishes:

1. **Menu**: `View` → `Color Preferences`
2. Enable: `Instance` (cells), `Wire` (metal layers), `Power` (VDD/VSS)
3. **Zoom to fit**: Press `F` key
4. **Screenshot**: `File` → `Save Screen Image` → Save as `layout.png`

**LaTeX caption suggestion:**
```latex
\begin{figure}[t]
\centering
\includegraphics[width=\columnwidth]{figures/layout.png}
\caption{Post-route physical layout of the proposed predictive slack-aware
accelerator in 180nm CMOS technology.}
\label{fig:layout}
\end{figure}
```

### Verify Timing

```bash
grep -i "WNS\|slack" ../results/innovus_timing_report.txt
```

> A **positive** WNS (e.g., `+88 ps`) means you successfully met the 250 MHz target.

---

## 6. ⚡ Step 5 — Power Analysis (Joules)

**Purpose**: Use the actual simulation activity (VCD) to extract **precise dynamic/static power breakdown** for Figure 6 and Figure 7.

### Prerequisites

✅ `results/predictive_netlist.v` must exist (from Genus)  
✅ `results/predictive_workload.vcd` must exist (from Xcelium)

### Run Joules

```bash
cd predictive_flow/work

joules -f ../scripts/joules_flow.tcl | tee ../logs/joules.log
```

### Verify Reports

```bash
cat ../results/joules_power_breakdown.txt
cat ../results/joules_power_hierarchy.txt
```

### How to Read the Output

The `joules_power_breakdown.txt` will contain columns like:

| Component | Internal (mW) | Switching (mW) | Leakage (µW) | Total (mW) |
|-----------|---------------|-----------------|---------------|------------|
| u_monitor | ... | ... | ... | ... |
| u_predictor | ... | ... | ... | ... |
| u_controller | ... | ... | ... | ... |

- **Internal + Switching = Dynamic Power** → This is what your predictor saves
- **Leakage = Static Power** → Reduced by power gating (`pg_mask`)

### Getting the 34.5% Reduction Number

You must run Joules **3 times** with different configurations:

| Run | Configuration | How |
|-----|--------------|-----|
| 1 | **Baseline** (No predictor) | Force `freq_sel=2'b11`, `vdd_sel=2'b10` always |
| 2 | **Reactive** (No prediction) | Remove EWMA, use raw `measured_slack` directly |
| 3 | **Predictive** (Full system) | Run as-is |

The power reduction = `(Baseline - Predictive) / Baseline × 100%`

---

## 7. 📊 Reading Your Results

### For Table II — Timing Results

| Metric | Source File | What to Look For |
|--------|------------|------------------|
| Clock Period | `constraints.sdc` | 4.0 ns (250 MHz) |
| WNS (Pre-Route) | `genus_timing_report.txt` | Should be ≥ 0 |
| WNS (Post-Route) | `innovus_timing_report.txt` | Should be ≥ 0 |
| TNS | `innovus_timing_report.txt` | Should be 0 |

### For Table III — Area Results

| Metric | Source File | What to Look For |
|--------|------------|------------------|
| Total Cell Area | `genus_area_report.txt` | In µm² |
| Gate Count (GE) | `genus_gates_report.txt` | Total gate equivalents |
| Per-Module Area | `innovus_area_report.txt` | Breakdown by module |

### For Figure 6 — Power Breakdown

| Metric | Source File |
|--------|------------|
| Dynamic Power (per module) | `joules_power_breakdown.txt` |
| Leakage Power (per module) | `joules_power_breakdown.txt` |
| Hierarchical breakdown | `joules_power_hierarchy.txt` |

---

## 8. 🔧 Troubleshooting

### "Library not found" in Genus/Innovus

```bash
# Find your lab's .lib files
find /home/Cadence -name "*.lib" 2>/dev/null
find /cad -name "*.lib" 2>/dev/null

# Update the path in all scripts
sed -i 's|/home/Cadence/FOUNDRY/digital/180nm/dig/lib|/your/found/path|g' ../scripts/*.tcl
```

### "Unrouted power nets" in Innovus

This is fixed in our script via `globalNetConnect`. If it still occurs:
```tcl
# In Innovus console:
globalNetConnect VDD -type pgpin -pin VDD -inst * -override
globalNetConnect VSS -type pgpin -pin VSS -inst * -override
```

### VCD file is empty (0 bytes)

```bash
# Check the $dumpfile path is relative to where you ran xrun
# Run from work/ directory, VCD goes to ../results/
# OR fix the path in testbench:
# Change:  $dumpfile("../results/predictive_workload.vcd");
# To:      $dumpfile("predictive_workload.vcd");
```

### Genus exits with "cannot elaborate"

```bash
# Check for syntax errors in RTL
xrun -compile ../hdl/*.v 2>&1 | head -50
```

### Timing violation (negative WNS)

```tcl
# In Genus, try more aggressive optimization:
syn_opt -incr
# Or relax the clock:
# Edit constraints.sdc: create_clock -period 5.0 ...
```

---

## 📂 Complete File Reference

```
predictive_flow/
├── hdl/                              # ← RTL Source Code
│   ├── slack_monitor.v               #    Activity sensor (toggle counting)
│   ├── ewma_predictor.v              #    Multiplier-less EWMA (shift-only)
│   ├── adapt_ctrl.v                  #    LUT-based 4D controller FSM
│   ├── predictive_top.v              #    Top-level integration
│   └── tb_predictive_top.v           #    Testbench (4-phase workload + VCD)
│
├── scripts/                          # ← Automation Scripts
│   ├── constraints.sdc               #    250 MHz timing constraints
│   ├── synth_genus.tcl               #    Genus synthesis automation
│   ├── innovus_flow.tcl              #    Innovus P&R automation
│   └── joules_flow.tcl               #    Joules power analysis
│
├── results/                          # ← Output (generated by tools)
│   ├── predictive_netlist.v          #    Synthesized gate-level netlist
│   ├── predictive_constraints.sdc    #    Post-synthesis SDC
│   ├── predictive_workload.vcd       #    Simulation activity dump
│   ├── genus_area_report.txt         #    Area (Table III)
│   ├── genus_timing_report.txt       #    Pre-route timing
│   ├── innovus_timing_report.txt     #    Post-route timing (Table II)
│   ├── joules_power_breakdown.txt    #    Power by type (Figure 6)
│   └── joules_power_hierarchy.txt    #    Power by module (Figure 7)
│
├── logs/                             # ← Tool log files
│   ├── genus.log
│   └── joules.log
│
├── work/                             # ← Run tools from here
└── RUN_ME_LINUX.md                   # ← This file
```

---

## ⚡ Quick-Reference Command Cheat Sheet

```bash
# ---- FROM THE work/ DIRECTORY ----

# 1. Simulate (headless)
xrun -64bit -access +rwc ../hdl/*.v -timescale 1ns/1ps

# 2. Simulate (GUI for waveform screenshot)
xrun -64bit -gui -access +rwc ../hdl/*.v -timescale 1ns/1ps

# 3. Synthesize
genus -f ../scripts/synth_genus.tcl | tee ../logs/genus.log

# 4. Place & Route (GUI for layout screenshot)
innovus -gui
# then in console: source ../scripts/innovus_flow.tcl

# 5. Power Analysis
joules -f ../scripts/joules_flow.tcl | tee ../logs/joules.log
```

---

*Generated for the Predictive Slack-Aware AI & DSP Accelerator project.*  
*Target: 180nm CMOS, 250 MHz, Cadence Digital Flow (Xcelium → Genus → Innovus → Joules)*
