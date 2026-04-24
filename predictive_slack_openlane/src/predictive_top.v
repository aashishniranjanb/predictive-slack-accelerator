// ============================================================================
// Module: predictive_top
// Description: Master Integration — Wires the Slack Monitor, EWMA Predictor,
//              and Adaptive Controller into a closed-loop system. Exposes
//              telemetry ports for waveform capture (Figure 5) and provides
//              a 64-bit compute bus input for simulation-driven analysis.
// Paper Ref:   Section II — System Architecture (Figure 2)
// ============================================================================

module predictive_top (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [63:0] compute_bus_in,  // Monitored by the slack sensor

    // Top-level adaptive outputs (drive external DVFS/PLL/LDO)
    output wire [1:0]  freq_out,
    output wire [1:0]  vdd_out,
    output wire        prec_out,
    output wire [2:0]  pg_out,

    // Telemetry for simulation observability (Figure 5 waveforms)
    output wire [7:0]  debug_measured_slack,
    output wire [7:0]  debug_predicted_slack
);

    // Internal interconnect
    wire        epoch_sync;
    wire [7:0]  internal_measured_slack;
    wire [7:0]  internal_predicted_slack;

    // Pipeline registers between predictor and controller
    reg  [7:0]  pred_slack_pipe;
    reg         epoch_pipe;

    // ========================================================================
    // Stage 1: Slack Monitor — Observes compute bus toggles, estimates slack
    // ========================================================================
    slack_monitor #(
        .WINDOW_SIZE (1024),
        .BUS_WIDTH   (64)
    ) u_monitor (
        .clk           (clk),
        .rst_n         (rst_n),
        .compute_bus   (compute_bus_in),
        .measured_slack(internal_measured_slack),
        .epoch_trigger (epoch_sync)
    );

    // ========================================================================
    // Stage 2: EWMA Predictor — Predicts next-epoch slack (multiplier-less)
    // ========================================================================
    ewma_predictor u_predictor (
        .clk            (clk),
        .rst_n          (rst_n),
        .epoch_trigger  (epoch_sync),
        .measured_slack (internal_measured_slack),
        .predicted_slack(internal_predicted_slack)
    );

    // Pipeline stage: separate predictor output from controller input
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pred_slack_pipe <= 8'd200;
            epoch_pipe     <= 1'b0;
        end else begin
            epoch_pipe <= epoch_sync;
            if (epoch_sync) begin
                pred_slack_pipe <= internal_predicted_slack;
            end
        end
    end

    // ========================================================================
    // Stage 3: Adaptive Controller — Maps prediction to DVFS/Precision knobs
    // ========================================================================
    adapt_ctrl u_controller (
        .clk            (clk),
        .rst_n          (rst_n),
        .epoch_trigger  (epoch_pipe),
        .predicted_slack(pred_slack_pipe),
        .freq_sel       (freq_out),
        .vdd_sel        (vdd_out),
        .prec_sel       (prec_out),
        .pg_mask        (pg_out)
    );

    // Route telemetry to top level for waveform capture
    assign debug_measured_slack  = internal_measured_slack;
    assign debug_predicted_slack = pred_slack_pipe;

endmodule
