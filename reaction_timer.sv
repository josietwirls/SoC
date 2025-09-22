module reaction_timer(
    input logic clk,
    input logic rst,
    input logic SW0, SW1,
    output logic LED,
    output logic [7:0] an,
    output logic [7:0] sseg
    );
    
    
    parameter IDLE=3'b000;
    parameter START=3'b001;
    parameter REACTION=3'b010;
    parameter EARLY=3'b011;
    parameter LATE=3'b100;
    parameter WIN=3'b001;
    
    logic [1:0] state, nstate;
    
    //internal registers
    logic count, ncount;
    logic [7:0] sseg;
    logic led, nled;
    logic rand_num, nrand_num;
    logic [31:0] timer, ntimer;
    logic [16:0] clkdiv;
    logic tick_ms;
    
    //BCD display
    logic [13:0] disp_val;
    logic [1:0] mux_sel;
    logic [3:0] dig3, dig2, dig1, dig0; // four display digits

    function automatic [6:0] seg_decode(input [3:0] digit);
        case(digit)
            4'd0: seg_decode = 7'b1000000;
            4'd1: seg_decode = 7'b1111001;
            4'd2: seg_decode = 7'b0100100;
            4'd3: seg_decode = 7'b0110000;
            4'd4: seg_decode = 7'b0011001;
            4'd5: seg_decode = 7'b0010010;
            4'd6: seg_decode = 7'b0000010;
            4'd7: seg_decode = 7'b1111000;
            4'd8: seg_decode = 7'b0000000;
            4'd9: seg_decode = 7'b0010000;
            4'h10: seg_decode = 7'b0001001; // H
            default: seg_decode = 7'b1111111; // blank
        endcase
    endfunction


    
    always_ff@(posedge(clk), posedge(rst))
        if (rst) begin
            state<=IDLE;
            count<=0;
            led<=0;
            timer<=0;
            clkdiv  <= 0;
            tick_ms <= 0;
            mux_sel <= 0;
            rand_num<=10;
        end else begin
      // 1ms tick generator
            if (clkdiv == 100_000 - 1) begin
                clkdiv  <= 0;
                tick_ms <= 1;
            end else begin
                clkdiv  <= clkdiv + 1;
                tick_ms <= 0;
            end
            state<=nstate;
            count<=ncount;
            led<=nled;
            rand_num<=nrand_num;
            mux_sel <= mux_sel + 1;
            timer<=ntimer;
            end
    
    always_comb begin
        nstate=state;
        ncount=count;
        nled=led;
        ntimer=timer;
        nrand_num=rand_num;
        dig3 = 4'hF;
        dig2 = 4'hF;
        dig1 = 4'hF;
        dig0 = 4'hF;
        case(state)
        IDLE: begin
            nled=0;
            ntimer=0;
            ncount=0;
            // Show "HI"
            dig3 = 4'hF;   // blank
            dig2 = 4'h10;   // H
            dig1 = 4'h1;   // I
            dig0 = 4'hF;   // blank
                if(SW0) begin
                    nstate=START;
                    nrand_num = $urandom_range(15, 2);
                end
            end
        START: begin
            ncount=count+1;
            ntimer=0;
            dig3 = 4'hF;
            dig2 = 4'hF;
            dig1 = 4'hF;
            dig0 = 4'hF;
            if(SW1) begin
                nstate=EARLY;
            end
            if (count>=rand_num) begin
                nstate=REACTION;
            end
        end
        REACTION: begin
            nled=1;
            disp_val = timer[13:0]; 
            dig3 = (disp_val / 1000) % 10;
            dig2 = (disp_val / 100)  % 10;
            dig1 = (disp_val / 10)   % 10;
            dig0 = (disp_val / 1)    % 10;
            if(tick_ms) ntimer=timer+1;
            if(SW1) nstate=WIN;
            else if (timer >= 1000) nstate=LATE;
            end
        WIN: begin
            ntimer=timer;
            disp_val = timer[13:0]; 
            dig3 = (disp_val / 1000) % 10;
            dig2 = (disp_val / 100)  % 10;
            dig1 = (disp_val / 10)   % 10;
            dig0 = (disp_val / 1)    % 10;
        end
        EARLY: begin
            ntimer=0;
            dig3 = 4'd9;
            dig2 = 4'd9;
            dig1 = 4'd9;
            dig0 = 4'd9;
        end
        LATE: begin
            ntimer=0;
            dig3 = 4'd1;
            dig2 = 4'd0;
            dig1 = 4'd0;
            dig0 = 4'd0;
        end
        endcase
    end
    
    always_comb begin
        case(mux_sel)
            2'b00: begin
                an   = 8'b1111_1110; 
                sseg = {1'b1, seg_decode(dig0)};
            end
            2'b01: begin
                an   = 8'b1111_1101;
                sseg = {1'b1, seg_decode(dig1)};
            end
            2'b10: begin
                an   = 8'b1111_1011;
                sseg = {1'b1, seg_decode(dig2)};
            end
            2'b11: begin
                an   = 8'b1111_0111;
                sseg = {1'b1, seg_decode(dig3)};
            end
        endcase
    end
    
    assign LED=led;


endmodule