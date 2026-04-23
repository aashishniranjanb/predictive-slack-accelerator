// ============================================================================
// Module: adapt_ctrl
// Description: Multi-Dimensional LUT-Based Adaptation Controller.
//              Maps predicted slack (with safety margin) to a 4D configuration
//              vector: {Voltage, Frequency, Precision, Power-Gating}.
//              Implements the exact operating regions from Section V, Table I.
// Paper Ref:   Section V — Multi-Dimensional Actuation Strategy
// ============================================================================

module adapt_ctrl (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       epoch_trigger,
    input  wire [7:0] predicted_slack,
    
    // Multi-dimensional Actuator Outputs
    output reg  [1:0] freq_sel,   // 00=100MHz, 01=200MHz, 10=300MHz, 11=400MHz
    output reg  [1:0] vdd_sel,    // 00=0.8V,   01=0.9V,   10=1.0V
    output reg        prec_sel,   // 0=INT8,    1=INT16
    output reg  [2:0] pg_mask     // Power gating mask: {FIR, MatVec, FFT}
);

    // Hardcoded Safety Margin: delta_s = 20 (representing 200 ps)
    wire [7:0] safe_slack;
    assign safe_slack = (predicted_slack > 8'd20) ? (predicted_slack - 8'd20) : 8'd0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Default to HIGH RISK (Maximum Performance / Voltage)
            freq_sel <= 2'b11;  // 400 MHz
            vdd_sel  <= 2'b10;  // 1.0 V
            prec_sel <= 1'b1;   // INT16
            pg_mask  <= 3'b111; // All units ON
        end else if (epoch_trigger) begin
            // ============================================================
            // LUT Mapping (1 slack unit = 10 ps)
            // Matches Table I in the paper exactly
            // ============================================================
            if (safe_slack < 8'd50) begin
                // REGION 1: HIGH RISK (< 0.5 ns effective slack)
                freq_sel <= 2'b11; // 400 MHz
                vdd_sel  <= 2'b10; // 1.0 V
                prec_sel <= 1'b1;  // INT16  (full precision)
                pg_mask  <= 3'b111;// All ON (no gating)
            end 
            else if (safe_slack < 8'd120) begin
                // REGION 2: MODERATE (0.5 ns – 1.2 ns)
                freq_sel <= 2'b10; // 300 MHz
                vdd_sel  <= 2'b01; // 0.9 V
                prec_sel <= 1'b1;  // INT16
                pg_mask  <= 3'b111;// All ON
            end 
            else if (safe_slack < 8'd180) begin
                // REGION 3: RELAXED (1.2 ns – 1.8 ns)
                freq_sel <= 2'b01; // 200 MHz
                vdd_sel  <= 2'b01; // 0.9 V
                prec_sel <= 1'b0;  // INT8   (precision scaling)
                pg_mask  <= 3'b110;// Power gate FFT unit
            end 
            else begin
                // REGION 4: AGGRESSIVE SAVINGS (> 1.8 ns)
                freq_sel <= 2'b00; // 100 MHz
                vdd_sel  <= 2'b00; // 0.8 V
                prec_sel <= 1'b0;  // INT8
                pg_mask  <= 3'b100;// Power gate MatVec + FFT
            end
        end
    end

endmodule
