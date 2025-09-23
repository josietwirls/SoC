`timescale 1ns/1ps
module sseg_tb;
  logic clk = 0;
  logic rst_n;
  logic [15:0] digits;
  logic [7:0] sseg, an;

  always #5 clk = ~clk; // 100 MHz

  sseg #(.MUX_DIV_BITS(8)) dut (
    .clk   (clk),
    .rst_n (rst_n),
    .digits(digits),
    .sseg  (sseg),
    .an    (an)
  );

  initial begin
    rst_n = 0; digits = 16'h8320; #20;
    rst_n = 1; repeat (40) @(posedge clk);

    digits = 16'hABCD; repeat (40) @(posedge clk);
    digits = 16'h8888; repeat (40) @(posedge clk);
    $finish;
  end
endmodule
