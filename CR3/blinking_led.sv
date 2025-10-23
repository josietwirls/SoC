module blinking_led
   #(parameter W = 4)
   (
    input  logic clk,
    input  logic reset,
    input  logic cs,
    input  logic read,
    input  logic write,
    input  logic [4:0] addr,
    input  logic [31:0] wr_data,
    output logic [31:0] rd_data,
    output logic [W-1:0] led_out
   );


    // -----------------------------------------------------
    // Register map:
    //   00: LED0 rate
    //   01: LED1 rate
    //   02: LED2 rate
    //   03: LED3 rate
    // -----------------------------------------------------

    logic [31:0] led_rate [3:0];  // store rate values for each LED
   // -------------------------------------------------------------
   // Write Logic (set blink rate for selected LED)
   // -------------------------------------------------------------
   always_ff @(posedge clk or posedge reset) begin
      if (reset) begin
            led_rate[0] <= 32'd0;
            led_rate[1] <= 32'd0;
            led_rate[2] <= 32'd0;
            led_rate[3] <= 32'd0;
      end 
      else if (cs && write) begin
         case (addr)
            5'd0: led_rate[0] <= wr_data;
            5'd1: led_rate[1] <= wr_data;
            5'd2: led_rate[2] <= wr_data;
            5'd3: led_rate[3] <= wr_data;
            default: ; // ignore
         endcase
      end
   end


   blinking led0(.clk(clk), .reset(reset), .rate_ms(led_rate[0]), .led(led_out[0]));
   blinking led1(.clk(clk), .reset(reset), .rate_ms(led_rate[1]), .led(led_out[1]));
   blinking led2(.clk(clk), .reset(reset), .rate_ms(led_rate[2]), .led(led_out[2]));
   blinking led3(.clk(clk), .reset(reset), .rate_ms(led_rate[3]), .led(led_out[3]));

   
endmodule
