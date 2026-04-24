// ============================================================================
// Module: slack_monitor (PIPELINED, BALANCED POPCOUNT)
// Description: Counts bit toggles on compute_bus over a window.
//              Uses a 3-stage pipelined popcount to meet timing.
//              Window accumulation produces measured_slack and epoch_trigger.
// ============================================================================

module slack_monitor #(
    parameter integer BUS_WIDTH  = 64,
    parameter integer WINDOW_SIZE = 1024
)(
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire [BUS_WIDTH-1:0]     compute_bus,

    output reg  [7:0]               measured_slack,
    output reg                      epoch_trigger
);

    // ------------------------------------------------------------------------
    // Stage 0: register input and compute toggles
    // ------------------------------------------------------------------------
    reg [BUS_WIDTH-1:0] bus_q;
    reg [BUS_WIDTH-1:0] toggle_s0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bus_q     <= {BUS_WIDTH{1'b0}};
            toggle_s0 <= {BUS_WIDTH{1'b0}};
        end else begin
            toggle_s0 <= compute_bus ^ bus_q; // XOR toggle detect
            bus_q     <= compute_bus;
        end
    end

    // ------------------------------------------------------------------------
    // Stage 1: pairwise add (64 -> 32 values of 2 bits)
    // ------------------------------------------------------------------------
    reg [1:0] pair_s1 [0:(BUS_WIDTH/2)-1];
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < BUS_WIDTH/2; i = i + 1)
                pair_s1[i] <= 2'd0;
        end else begin
            for (i = 0; i < BUS_WIDTH/2; i = i + 1)
                pair_s1[i] <= toggle_s0[2*i] + toggle_s0[2*i+1];
        end
    end

    // ------------------------------------------------------------------------
    // Stage 2: group add (32 -> 8 values of up to 5 bits)
    // Each group sums 4 pair entries: max = 4 * 2 = 8 (fits in 4 bits, keep 5)
    // ------------------------------------------------------------------------
    reg [4:0] group_s2 [0:(BUS_WIDTH/8)-1]; // 8 entries for 64-bit

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (j = 0; j < BUS_WIDTH/8; j = j + 1)
                group_s2[j] <= 5'd0;
        end else begin
            for (j = 0; j < BUS_WIDTH/8; j = j + 1) begin
                group_s2[j] <= pair_s1[4*j] + pair_s1[4*j+1]
                             + pair_s1[4*j+2] + pair_s1[4*j+3];
            end
        end
    end

    // ------------------------------------------------------------------------
    // Stage 3: final sum (8 -> 7 bits max for 64 toggles)
    // ------------------------------------------------------------------------
    reg [6:0] popcount_s3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            popcount_s3 <= 7'd0;
        end else begin
            popcount_s3 <= group_s2[0] + group_s2[1]
                         + group_s2[2] + group_s2[3]
                         + group_s2[4] + group_s2[5]
                         + group_s2[6] + group_s2[7];
        end
    end

    // ------------------------------------------------------------------------
    // Window accumulation
    // ------------------------------------------------------------------------
    reg [15:0] cycle_cnt;     // enough for WINDOW_SIZE up to 65535
    reg [15:0] toggle_accum;  // accumulate popcounts

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt      <= 16'd0;
            toggle_accum   <= 16'd0;
            measured_slack <= 8'd200;
            epoch_trigger  <= 1'b0;
        end else begin
            epoch_trigger <= 1'b0;

            // accumulate each cycle (pipeline latency is fixed, so OK)
            toggle_accum <= toggle_accum + popcount_s3;
            cycle_cnt    <= cycle_cnt + 1;

            if (cycle_cnt == (WINDOW_SIZE-1)) begin
                // Simple mapping: fewer toggles => more slack
                // Normalize: scale down accumulation (>> shift) to 8-bit
                // You can tune the shift factor for your workload
                measured_slack <= (toggle_accum[15:8]); // coarse normalization

                epoch_trigger  <= 1'b1;
                cycle_cnt      <= 16'd0;
                toggle_accum   <= 16'd0;
            end
        end
    end

endmodule