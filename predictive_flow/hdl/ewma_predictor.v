// ============================================================================
// Module: ewma_predictor
// Description: Multiplier-Less EWMA Predictor — The crown jewel of the paper.
//              Strictly avoids the '*' operator. Uses arithmetic right-shifts
//              (>>>) to approximate the alpha smoothing gain, keeping the logic
//              footprint under 500 gates as claimed.
//              Includes adaptive gain update via sign-based gradient step.
// Paper Ref:   Section III — Predictive Modeling with Multiplier-Less EWMA
// Formula:     s_tilde[n] = alpha * s_hat[n] + (1 - alpha) * s_tilde[n-1]
//              where alpha = 1 / 2^alpha_shift
// ============================================================================

module ewma_predictor (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       epoch_trigger,
    input  wire [7:0] measured_slack,  // s_hat[n]  — from slack_monitor
    output reg  [7:0] predicted_slack  // s_tilde[n] — predicted next-epoch slack
);

    // Adaptive gain represented as a shift amount
    // alpha_shift = 1 → alpha = 0.500 (aggressive tracking)
    // alpha_shift = 2 → alpha = 0.250 (balanced)
    // alpha_shift = 3 → alpha = 0.125 (heavy smoothing)
    reg [1:0] alpha_shift; 

    wire signed [8:0] error;
    wire [7:0] alpha_part;
    wire [7:0] one_minus_alpha_part;

    // Prediction error: e[n] = s_hat[n] - s_tilde[n-1]
    assign error = {1'b0, measured_slack} - {1'b0, predicted_slack};

    // MULTIPLIER-LESS EWMA CALCULATION:
    // alpha_part         = s_hat[n]     >> alpha_shift   (≈ alpha * measured)
    // one_minus_alpha    = s_tilde[n-1] - (s_tilde[n-1] >> alpha_shift)  (≈ (1-alpha) * predicted)
    assign alpha_part           = measured_slack  >> alpha_shift;
    assign one_minus_alpha_part = predicted_slack - (predicted_slack >> alpha_shift);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            predicted_slack <= 8'd200;  // Initialize to safe slack
            alpha_shift     <= 2'd2;    // Default alpha = 0.25
        end else if (epoch_trigger) begin
            // Update prediction (no multiplier used)
            predicted_slack <= alpha_part + one_minus_alpha_part;
            
            // Adaptive Gain Update (Sign-based gradient step from Section III-B)
            // Large positive error → prediction too low → increase responsiveness
            // Large negative error → prediction too high → increase smoothing
            if (error > 9'sd20 && alpha_shift > 2'd1) begin
                alpha_shift <= alpha_shift - 1; // Increase responsiveness
            end else if (error < -9'sd20 && alpha_shift < 2'd3) begin
                alpha_shift <= alpha_shift + 1; // Increase smoothing
            end
        end
    end

endmodule
