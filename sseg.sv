// Time-multiplexed 7-seg driver (active-low segments/anodes)
module sseg #(
  parameter int MUX_DIV_BITS = 18
)(
  input  logic        clk,
  input  logic        rst_n,      // async active-low
  input  logic [15:0] digits,     // {d3,d2,d1,d0} nibble-coded
  output logic [7:0]  sseg,       // {dp,g,f,e,d,c,b,a} active-low
  output logic [7:0]  an          // active-low digit enables
);
  logic [MUX_DIV_BITS-1:0] mux_div;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      mux_div <= '0;
    else
      mux_div <= mux_div + 1'b1;
  end

  logic [1:0] sel = mux_div[MUX_DIV_BITS-1 -: 2];

  logic [3:0] nib;
  always_comb begin
    unique case (sel)
      2'd0: nib = digits[3:0];
      2'd1: nib = digits[7:4];
      2'd2: nib = digits[11:8];
      2'd3: nib = digits[15:12];
      default: nib = 4'hB; // blank
    endcase
  end

  // LUT: 0..9, A, B(blank), H, D(blank), I, F(blank)
  localparam logic [7:0] SEG_LUT [0:15] = '{
    8'hC0,8'hF9,8'hA4,8'hB0,8'h99,8'h92,8'h82,8'hF8,8'h80,8'h90, // 0..9
    8'h88,   // A
    8'hFF,   // B -> blank
    8'h89,   // H
    8'hFF,   // D -> blank
    8'hCF,   // I
    8'hFF    // F -> blank
  };

  always_comb begin
    sseg = SEG_LUT[nib];
    an   = ~(8'b0000_0001 << sel);
  end
endmodule
