// ============================================================================
// Module: slack_monitor
// Description: Activity & Replica Sensor. Continuously counts bit-toggles on
//              the compute bus over a configurable observation window and maps
//              high activity to low slack (simulating IR-drop/thermal stress).
//              Outputs a quantized 8-bit slack estimate every epoch.
// Paper Ref:   Section IV — In-Situ Timing Slack Estimation
// ============================================================================

module slack_monitor #(
    parameter WINDOW_SIZE = 1024,
    parameter BUS_WIDTH   = 64
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire [BUS_WIDTH-1:0] compute_bus,
    output reg  [7:0]           measured_slack, // 8-bit slack estimate (1 unit = 10ps)
    output reg                  epoch_trigger   // Pulses every WINDOW_SIZE cycles
);

    reg [15:0] toggle_count;
    reg [9:0]  cycle_count;
    reg [BUS_WIDTH-1:0] prev_bus;
    
    integer i;
    reg [6:0] current_toggles;

    // Combinational: Count per-cycle Hamming distance (XOR popcount)
    always @(*) begin
        current_toggles = 0;
        for (i = 0; i < BUS_WIDTH; i = i + 1) begin
            current_toggles = current_toggles + (compute_bus[i] ^ prev_bus[i]);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            toggle_count   <= 0;
            cycle_count    <= 0;
            prev_bus       <= 0;
            measured_slack <= 8'd200; // Default safe slack (2.0 ns)
            epoch_trigger  <= 1'b0;
        end else begin
            prev_bus      <= compute_bus;
            epoch_trigger <= 1'b0;
            
            if (cycle_count == WINDOW_SIZE - 1) begin
                cycle_count   <= 0;
                epoch_trigger <= 1'b1;

                // Map high toggles → low slack (simulating IR drop / thermal stress)
                // Assuming max toggle_count ≈ 32000 for normal 64-bit operation
                if (toggle_count > 16'd20000)
                    measured_slack <= 8'd40;   // 0.4 ns — HIGH RISK
                else if (toggle_count > 16'd10000)
                    measured_slack <= 8'd90;   // 0.9 ns — MODERATE
                else
                    measured_slack <= 8'd180;  // 1.8 ns — AGGRESSIVE savings
                
                toggle_count <= 0;
            end else begin
                cycle_count  <= cycle_count + 1;
                toggle_count <= toggle_count + current_toggles;
            end
        end
    end

endmodule
