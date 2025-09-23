`timescale 1ns/1ps

module square_circuit_tb;
    logic clk;
    logic cw;
    logic en;
    logic rst_n;
    logic [7:0] seg;    
    logic [7:0] digit;  

    // DUT instantiation
    square_circuit dut (
        .clk(clk),
        .en(en),
        .cw(cw),
        .seg(seg),
        .digit(digit),
        .rst_n(rst_n)
    );
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // stimulus
    initial begin
        cw = 00;
        en = 0;
        rst_n = 0;
        
        #20
        en = 1;   // enable, clockwise

        #20 
        rst_n = 1;
        
        #20 
        rst_n = 0;
        
        #200 
        cw = 1;
        
        #200;
        $finish;
        
    end
endmodule
