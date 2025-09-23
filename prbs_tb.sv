`timescale 1ns/1ps
module prbs_tb;
  localparam int N = 14;

  logic clk = 0;
  logic rst_n;
  logic [N-1:0] rnd_bus;

  always #5 clk = ~clk; // 100 MHz

  prbs #(.N(N)) dut (
    .clk    (clk),
    .rst_n  (rst_n),
    .rnd_bus(rnd_bus)
  );

  initial begin
    rst_n = 0;       // assert reset (active-low)
    #20;
    rst_n = 1;       // release
    repeat (50) @(posedge clk);

    rst_n = 0; #10;  // pulse reset
    rst_n = 1;
    repeat (30) @(posedge clk);

    $finish;
  end
endmodule
