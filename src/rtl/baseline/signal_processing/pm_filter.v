module pm_filter (
    input wire clk,                    
    input wire rst,              // Active-LOW reset
    input wire valid_in,
    input wire signed [15:0] x_n,
    output reg signed [15:0] y_n,
    output reg valid_out
);
    reg signed [15:0] x_n_1;
    
    // Pre-emphasis coefficient: α = 0.92 × 2^15 = 30146
    wire signed [15:0] alpha = 16'sb0111010111000010;
    
    // Multiply α × x[n-1] → 32-bit result
    wire signed [31:0] mult_result = alpha * x_n_1;
    
    // Scale back to Q0.15: take bits [30:15]
    wire signed [15:0] mult_scaled = mult_result[30:15];
    
    // Subtract with sign-extension to 17-bit for overflow headroom
    wire signed [16:0] sub_result = {x_n[15], x_n} - {mult_scaled[15], mult_scaled};
    
    // ✅ Combinational saturation logic (blocking via assign)
    wire signed [15:0] y_next;
    assign y_next = (sub_result > 17'sd32767)  ? 16'sd32767  :
                    (sub_result < -17'sd32768) ? -16'sd32768 :
                    sub_result[15:0];
    
// ✅ Sequential block: ACTIVE-LOW reset, all outputs registered together
always @(posedge clk) begin
    if (!rst) begin
        x_n_1     <= 16'sd0;
        y_n       <= 16'sd0;
        valid_out <= 1'b0;
    end else if (valid_in) begin        // ← ADD THIS LINE (was just "else")
        x_n_1     <= x_n;
        y_n       <= y_next;
        valid_out <= valid_in;
    end                                 // ← remove the bare "else" entirely
end
endmodule