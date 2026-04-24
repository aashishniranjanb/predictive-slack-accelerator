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

    // Stage 1 registers
    reg [1:0] region_r;
    reg       epoch_stage1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            region_r     <= 2'd0;
            epoch_stage1 <= 1'b0;
        end else begin
            epoch_stage1 <= epoch_trigger;
            if (epoch_trigger) begin
                region_r <= (safe_slack < 8'd50)  ? 2'd0 :
                            (safe_slack < 8'd120) ? 2'd1 :
                            (safe_slack < 8'd180) ? 2'd2 : 2'd3;
            end
        end
    end

    // Stage 2: output assignment using registered region
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            freq_sel <= 2'b11;
            vdd_sel  <= 2'b10;
            prec_sel <= 1'b1;
            pg_mask  <= 3'b111;
        end else if (epoch_stage1) begin
            case (region_r)
                2'd0: begin
                    freq_sel <= 2'b11;
                    vdd_sel  <= 2'b10;
                    prec_sel <= 1'b1;
                    pg_mask  <= 3'b111;
                end
                2'd1: begin
                    freq_sel <= 2'b10;
                    vdd_sel  <= 2'b01;
                    prec_sel <= 1'b1;
                    pg_mask  <= 3'b111;
                end
                2'd2: begin
                    freq_sel <= 2'b01;
                    vdd_sel  <= 2'b01;
                    prec_sel <= 1'b0;
                    pg_mask  <= 3'b110;
                end
                default: begin
                    freq_sel <= 2'b00;
                    vdd_sel  <= 2'b00;
                    prec_sel <= 1'b0;
                    pg_mask  <= 3'b100;
                end
            endcase
        end
    end

endmodule
