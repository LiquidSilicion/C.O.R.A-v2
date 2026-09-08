`timescale 1ns / 1ps
module lowpass_filter(
    input  wire        clk,
    input  wire        rst,           // Active-HIGH reset (Standard)
    input  wire        valid_in,
    input  wire [15:0] x_in,          // unsigned from HWR (always >= 0)
    output reg  [15:0] y_out,         // unsigned envelope (always >= 0)
    output reg         valid_out
);

    // ----------------------------------------------------------
    //  FIXED COEFFICIENTS
    //  Sum must be exactly 32768 (1.0) to prevent drift.
    //  32768 - 30306 = 2462
    // ----------------------------------------------------------
    localparam [15:0] ALPHA         = 16'd30306; 
    localparam [15:0] ONE_MINUS_A   = 16'd2462;   // <-- FIXED (was 2476)

    // ----------------------------------------------------------
    //  State register
    // ----------------------------------------------------------
    reg [15:0] y_prev;    

    // ----------------------------------------------------------
    //  Multiply & Accumulate
    //  Using 33-bit acc to prevent truncation of MSB
    // ----------------------------------------------------------
    wire [31:0] term1 = ALPHA       * y_prev;
    wire [31:0] term2 = ONE_MINUS_A * x_in;
    
    wire [32:0] acc = {1'b0, term1} + {1'b0, term2}; // 33-bit sum

    // ----------------------------------------------------------
    //  Scaling & Saturation
    //  Extract integer part [30:15] but clamp if acc[31] is set
    // ----------------------------------------------------------
    wire [15:0] y_calc;
    assign y_calc = acc[30:15]; // Shift right by 15
    
    // If acc[31] is 1, we have overflow -> Clamp to Max (FFFF)
    // Else use calculated value.
    // This ensures y_out NEVER goes negative.
    wire [15:0] y_safe;
    assign y_safe = acc[31] ? 16'hFFFF : y_calc;

    // ----------------------------------------------------------
    //  Sequential Update
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (!rst) begin
            y_prev    <= 16'd0;
            y_out     <= 16'd0;
            valid_out <= 1'b0;
        end else if (valid_in) begin
            y_prev    <= y_safe;   // Use clamped value for feedback
            y_out     <= y_safe;   // Output clamped value
            valid_out <= 1'b1;
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule