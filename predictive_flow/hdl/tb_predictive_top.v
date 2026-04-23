// ============================================================================
// Testbench: tb_predictive_top
// Description: Simulation-ready testbench that drives the entire Predictive
//              Accelerator through 4 workload phases (High → Medium → Low →
//              Burst). Generates the 'predictive_workload.vcd' file required
//              by Cadence Joules for accurate dynamic power extraction.
// Paper Ref:   Figure 5 (Measured vs Predicted Slack Waveform)
//              Figure 6 (Power Breakdown by Workload Phase)
//              Figure 7 (Adaptive Frequency Transitions)
// ============================================================================

`timescale 1ns / 1ps

module tb_predictive_top;

    // ---- Inputs ----
    reg         clk;
    reg         rst_n;
    reg [63:0]  compute_bus_in;

    // ---- Outputs ----
    wire [1:0]  freq_out;
    wire [1:0]  vdd_out;
    wire        prec_out;
    wire [2:0]  pg_out;
    wire [7:0]  debug_measured_slack;
    wire [7:0]  debug_predicted_slack;

    // ---- Instantiate the Unit Under Test (UUT) ----
    predictive_top uut (
        .clk                 (clk),
        .rst_n               (rst_n),
        .compute_bus_in      (compute_bus_in),
        .freq_out            (freq_out),
        .vdd_out             (vdd_out),
        .prec_out            (prec_out),
        .pg_out              (pg_out),
        .debug_measured_slack(debug_measured_slack),
        .debug_predicted_slack(debug_predicted_slack)
    );

    // ================================================================
    // 1. Clock Generation: 250 MHz (4.0 ns period)
    // ================================================================
    always #2.0 clk = ~clk;

    // ================================================================
    // 2. VCD Generation for Cadence Joules (Power Analysis)
    // ================================================================
    initial begin
        $dumpfile("../results/predictive_workload.vcd");
        $dumpvars(0, tb_predictive_top);
    end

    // ================================================================
    // Task: Simulate one epoch (1024 cycles) at a given activity level
    //   activity_level: 0 = Idle
    //                   1 = Low  (Aggressive slack — 8 bits toggle)
    //                   2 = Med  (Moderate slack  — 32 bits toggle)
    //                   3 = High (High Risk       — 64 bits toggle)
    // ================================================================
    task run_epoch(input integer activity_level);
        integer i;
        begin
            for (i = 0; i < 1024; i = i + 1) begin
                @(posedge clk);
                if (activity_level == 3)
                    compute_bus_in <= {$random, $random};          // Heavy: all 64 bits flip randomly
                else if (activity_level == 2)
                    compute_bus_in <= {32'd0, $random};            // Medium: only 32 bits flip
                else if (activity_level == 1)
                    compute_bus_in <= {56'd0, $random[7:0]};       // Light: only 8 bits flip
                else
                    compute_bus_in <= compute_bus_in;              // Idle: zero toggling
            end
        end
    endtask

    // ================================================================
    // 3. Main Simulation Stimulus
    // ================================================================
    initial begin
        // Initialize
        clk            = 0;
        rst_n          = 0;
        compute_bus_in = 0;

        // Reset
        #10;
        rst_n = 1;
        #10;

        $display("============================================================");
        $display("  PREDICTIVE SLACK-AWARE ACCELERATOR — SIMULATION START");
        $display("============================================================");

        // ---- Phase 1: HIGH Activity (FIR + MatVec bursts) ----
        // Expected: slack ≈ 0.4ns, freq=400MHz, VDD=1.0V
        $display("[T=%0t] Phase 1: HIGH activity (3 epochs)...", $time);
        run_epoch(3);
        run_epoch(3);
        run_epoch(3);

        // ---- Phase 2: MEDIUM Activity (Typical Edge AI inference) ----
        // Expected: slack ≈ 0.9ns, freq=300MHz, VDD=0.9V
        $display("[T=%0t] Phase 2: MEDIUM activity (3 epochs)...", $time);
        run_epoch(2);
        run_epoch(2);
        run_epoch(2);

        // ---- Phase 3: LOW / IDLE Activity (Sensor wait periods) ----
        // Expected: slack > 1.8ns, freq=100MHz, VDD=0.8V, Power Gating ON
        $display("[T=%0t] Phase 3: LOW activity / idle (3 epochs)...", $time);
        run_epoch(1);
        run_epoch(1);
        run_epoch(1);

        // ---- Phase 4: Sudden HIGH Burst (Tests predictor reaction time) ----
        // Expected: predictor tracks within 1–2 epochs
        $display("[T=%0t] Phase 4: Sudden HIGH burst (2 epochs)...", $time);
        run_epoch(3);
        run_epoch(3);

        $display("============================================================");
        $display("  SIMULATION COMPLETE — VCD saved to results/");
        $display("============================================================");
        $display("  Measured Slack : %0d", debug_measured_slack);
        $display("  Predicted Slack: %0d", debug_predicted_slack);
        $display("  Freq Select    : %0b", freq_out);
        $display("  VDD Select     : %0b", vdd_out);
        $display("  Precision      : %0b", prec_out);
        $display("  Power Gate Mask: %0b", pg_out);
        $display("============================================================");

        #100;
        $finish;
    end

endmodule
