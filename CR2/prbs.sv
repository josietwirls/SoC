// 14-bit PRBS LFSR with async active-low reset
module prbs #(
  parameter int N = 14
)(
  input  logic         clk,
  input  logic         rst_n,     // async active-low
  output logic [N-1:0] rnd_bus
);
  // non-zero seed
  localparam logic [N-1:0] SEED = {{(N-1){1'b0}}, 1'b1};

  logic [N-1:0] state;
  logic         fb;

  // taps for 14-bit maximal polynomial x^14 + x^5 + x^3 + x^1 + 1
  assign fb = state[13] ^ state[4] ^ state[2] ^ state[0];

  wire [N-1:0] next_state = {fb, state[N-1:1]}; // shift-right (insert MSB)

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= SEED;
    else
      state <= next_state;
  end

  assign rnd_bus = state;
endmodule
