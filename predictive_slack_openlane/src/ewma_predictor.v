// ============================================================================
// Module: ewma_predictor
// Description: Multiplier-Less EWMA Predictor — The crown jewel of the paper.
//              Strictly avoids the '*' operator. Uses arithmetic right-shifts
//              to approximate the alpha smoothing gain, keeping the logic
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

    // Stage 1 registers
    reg [7:0] alpha_part_r;
    reg [7:0] one_minus_alpha_part_r;
    reg       epoch_stage1;

    // Shifted terms (avoid barrel shifter)
    reg [7:0] meas_shifted;
    reg [7:0] pred_shifted;

    wire signed [8:0] error;
    assign error = {1'b0, measured_slack} - {1'b0, predicted_slack};

    always @(*) begin
        case (alpha_shift)
            2'd1: begin
                meas_shifted = measured_slack >> 1;
                pred_shifted = predicted_slack >> 1;
            end
            2'd2: begin
                meas_shifted = measured_slack >> 2;
                pred_shifted = predicted_slack >> 2;
            end
            default: begin
                meas_shifted = measured_slack >> 3;
                pred_shifted = predicted_slack >> 3;
            end
        endcase
    end

    // Stage 1: compute partial terms and register the trigger
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alpha_part_r           <= 8'd0;
            one_minus_alpha_part_r <= 8'd0;
            epoch_stage1           <= 1'b0;
        end else begin
            epoch_stage1 <= epoch_trigger;
            if (epoch_trigger) begin
                alpha_part_r           <= meas_shifted;
                one_minus_alpha_part_r <= predicted_slack - pred_shifted;
            end
        end
    end

    // Stage 2: accumulate and update state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            predicted_slack <= 8'd200;  // Initialize to safe slack
            alpha_shift     <= 2'd2;    // Default alpha = 0.25
        end else if (epoch_stage1) begin
            predicted_slack <= alpha_part_r + one_minus_alpha_part_r;

            if (error > 9'sd20 && alpha_shift > 2'd1) begin
                alpha_shift <= alpha_shift - 1;
            end else if (error < -9'sd20 && alpha_shift < 2'd3) begin
                alpha_shift <= alpha_shift + 1;
            end
        end
    end

endmodule
