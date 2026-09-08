module lif_top #(
    parameter LEAK_FACTOR = 16'h00E0,  // α = 0.875
    parameter THRESHOLD   = 16'h0100,  // θ = 1.0 or 21845 in decimal
    parameter REFRAC      = 4'd8         // 8-cycle refractory period
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        sample_en,
    
    // 16 IHC channel inputs (Q12.4 envelope values)
    input  wire [15:0] ihc_ch1,  input  wire [15:0] ihc_ch2,
    input  wire [15:0] ihc_ch3,  input  wire [15:0] ihc_ch4,
    input  wire [15:0] ihc_ch5,  input  wire [15:0] ihc_ch6,
    input  wire [15:0] ihc_ch7,  input  wire [15:0] ihc_ch8,
    input  wire [15:0] ihc_ch9,  input  wire [15:0] ihc_ch10,
    input  wire [15:0] ihc_ch11, input  wire [15:0] ihc_ch12,
    input  wire [15:0] ihc_ch13, input  wire [15:0] ihc_ch14,
    input  wire [15:0] ihc_ch15, input  wire [15:0] ihc_ch16,
    
    // === OUTPUT: 16-bit spike vector (one bit per neuron) ===
    output wire [15:0] spike_bus
    // REMOVED: data [23:0], aer_valid, aer_ready (AER encoding moved to top_layer)
);

    // 16 parallel LIF neurons → spike_bus[15:0]
    lif_neuron #(.LEAK_FACTOR(LEAK_FACTOR), .THRESHOLD(THRESHOLD), .REFRAC(REFRAC))
    u_lif1  (.clk(clk), .rst(rst), .sample_en(sample_en), .ihc_in(ihc_ch1),  .spike(spike_bus[0]));
    lif_neuron #(.LEAK_FACTOR(LEAK_FACTOR), .THRESHOLD(THRESHOLD), .REFRAC(REFRAC))
    u_lif2  (.clk(clk), .rst(rst), .sample_en(sample_en), .ihc_in(ihc_ch2),  .spike(spike_bus[1]));
    lif_neuron #(.LEAK_FACTOR(LEAK_FACTOR), .THRESHOLD(THRESHOLD), .REFRAC(REFRAC))
    u_lif3  (.clk(clk), .rst(rst), .sample_en(sample_en), .ihc_in(ihc_ch3),  .spike(spike_bus[2]));
    lif_neuron #(.LEAK_FACTOR(LEAK_FACTOR), .THRESHOLD(THRESHOLD), .REFRAC(REFRAC))
    u_lif4  (.clk(clk), .rst(rst), .sample_en(sample_en), .ihc_in(ihc_ch4),  .spike(spike_bus[3]));
    lif_neuron #(.LEAK_FACTOR(LEAK_FACTOR), .THRESHOLD(THRESHOLD), .REFRAC(REFRAC))
    u_lif5  (.clk(clk), .rst(rst), .sample_en(sample_en), .ihc_in(ihc_ch5),  .spike(spike_bus[4]));
    lif_neuron #(.LEAK_FACTOR(LEAK_FACTOR), .THRESHOLD(THRESHOLD), .REFRAC(REFRAC))
    u_lif6  (.clk(clk), .rst(rst), .sample_en(sample_en), .ihc_in(ihc_ch6),  .spike(spike_bus[5]));
    lif_neuron #(.LEAK_FACTOR(LEAK_FACTOR), .THRESHOLD(THRESHOLD), .REFRAC(REFRAC))
    u_lif7  (.clk(clk), .rst(rst), .sample_en(sample_en), .ihc_in(ihc_ch7),  .spike(spike_bus[6]));
    lif_neuron #(.LEAK_FACTOR(LEAK_FACTOR), .THRESHOLD(THRESHOLD), .REFRAC(REFRAC))
    u_lif8  (.clk(clk), .rst(rst), .sample_en(sample_en), .ihc_in(ihc_ch8),  .spike(spike_bus[7]));
    lif_neuron #(.LEAK_FACTOR(LEAK_FACTOR), .THRESHOLD(THRESHOLD), .REFRAC(REFRAC))
    u_lif9  (.clk(clk), .rst(rst), .sample_en(sample_en), .ihc_in(ihc_ch9),  .spike(spike_bus[8]));
    lif_neuron #(.LEAK_FACTOR(LEAK_FACTOR), .THRESHOLD(THRESHOLD), .REFRAC(REFRAC))
    u_lif10 (.clk(clk), .rst(rst), .sample_en(sample_en), .ihc_in(ihc_ch10), .spike(spike_bus[9]));
    lif_neuron #(.LEAK_FACTOR(LEAK_FACTOR), .THRESHOLD(THRESHOLD), .REFRAC(REFRAC))
    u_lif11 (.clk(clk), .rst(rst), .sample_en(sample_en), .ihc_in(ihc_ch11), .spike(spike_bus[10]));
    lif_neuron #(.LEAK_FACTOR(LEAK_FACTOR), .THRESHOLD(THRESHOLD), .REFRAC(REFRAC))
    u_lif12 (.clk(clk), .rst(rst), .sample_en(sample_en), .ihc_in(ihc_ch12), .spike(spike_bus[11]));
    lif_neuron #(.LEAK_FACTOR(LEAK_FACTOR), .THRESHOLD(THRESHOLD), .REFRAC(REFRAC))
    u_lif13 (.clk(clk), .rst(rst), .sample_en(sample_en), .ihc_in(ihc_ch13), .spike(spike_bus[12]));
    lif_neuron #(.LEAK_FACTOR(LEAK_FACTOR), .THRESHOLD(THRESHOLD), .REFRAC(REFRAC))
    u_lif14 (.clk(clk), .rst(rst), .sample_en(sample_en), .ihc_in(ihc_ch14), .spike(spike_bus[13]));
    lif_neuron #(.LEAK_FACTOR(LEAK_FACTOR), .THRESHOLD(THRESHOLD), .REFRAC(REFRAC))
    u_lif15 (.clk(clk), .rst(rst), .sample_en(sample_en), .ihc_in(ihc_ch15), .spike(spike_bus[14]));
    lif_neuron #(.LEAK_FACTOR(LEAK_FACTOR), .THRESHOLD(THRESHOLD), .REFRAC(REFRAC))
    u_lif16 (.clk(clk), .rst(rst), .sample_en(sample_en), .ihc_in(ihc_ch16), .spike(spike_bus[15]));


endmodule