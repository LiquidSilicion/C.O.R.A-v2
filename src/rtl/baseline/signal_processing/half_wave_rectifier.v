module half_wave_rectifier(    
    input  wire               clk,
    input  wire               rst,
    input  wire               valid_in,
    input  wire signed [15:0] x_in,       // signed input from adaptation filter
    output reg         [15:0] y_out,       // unsigned output - negatives zeroed
    output reg                valid_out );
 
    always @(posedge clk) begin
        if (!rst) begin
            y_out     <= 16'd0;
            valid_out <= 1'b0;
        end
        else if (valid_in) begin
            y_out     <= x_in[15] ? 16'd0 : x_in;
            valid_out <= 1'b1;
        end
        else begin
            valid_out <= 1'b0;
        end
    end
endmodule