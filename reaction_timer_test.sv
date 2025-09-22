`timescale 1ns/1ps

module reaction_timer_test;

    // Clock and reset
    logic clk;
    logic rst;

    // Buttons
    logic SW0; // start
    logic SW1; // stop

    // Outputs
    logic LED;
    logic [7:0] sseg;
    logic [7:0] an;

    // Instantiate DUT
    reaction_timer dut (
        .clk(clk),
        .rst(rst),
        .SW0(SW0),
        .SW1(SW1),
        .LED(LED),
        .sseg(sseg),
        .an(an)
    );

    // Clock generation: 100 MHz
    initial clk = 0;
    always #5 clk = ~clk; // period = 10 ns

    // Test stimulus
    initial begin
        // Initialize
        rst = 1;
        SW0 = 0;
        SW1 = 0;
        #20;
        rst = 0;

        // Show initial state (HI)
        #50;

        // Start reaction timer
        SW0 = 1;
        #10;
        SW0 = 0;

        // Wait for stimulus LED (simulate random delay)
        #200_000_000; // e.g., 200 ms (adjust according to your simulation scale)

        // Press stop button (simulate human reaction)
        SW1 = 1;
        #10;
        SW1 = 0;

        // Wait a bit to see output
        #50;

        // Press clear to reset
        rst = 1;
        #10;
        rst = 0;

        // Finish simulation
        #50;
        $finish;
    end

    // Optional: monitor outputs
    initial begin
        $display("Time(ns)\tLED\tSSEG\tAN");
        $monitor("%0t\t%b\t%8b\t%8b", $time, LED, sseg, an);
    end

endmodule
