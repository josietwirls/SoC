module blinking #(  // 100 MHz default clock
)(
    input  logic clk,
    input  logic reset,
    input  logic [31:0] rate_ms,   // Desired blink rate (ms)
    output logic led
);

    localparam CLK_FREQ = 100_000_000;
    logic [31:0] counter;
    logic [31:0] toggle_count;

    always_comb begin
        if (rate_ms != 0)
            toggle_count = (CLK_FREQ / 1000) * rate_ms;
        else
            toggle_count = 32'd0;
    end

    // Main counter logic
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            counter <= 0;
            led <= 0;
        end else begin
            if (counter >= toggle_count) begin
                counter <= 0;
                led <= ~led;
            end else begin
                counter <= counter + 1;
            end
        end
    end
    

    //if (count >= 999999){
    //    mss_count = ms_count + 1;
    //    count = 0;
   //     if (ms_count >= delay_ms)
   //         ms_count = 0;
   //         led = ~led;
  // else 
  //  count++;
    
endmodule
