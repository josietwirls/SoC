`timescale 1ns / 1ps

module square_circuit(
    input  logic clk,
    input  logic rst_n,
    input  logic cw, en,
    output logic [7:0] seg,
    output logic [7:0] digit
    );

    // clock divider
    parameter N = 28;  
    logic [N-1:0] q_reg, q_next;
    logic [2:0] state_reg;

    // counter register
    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n)
            q_reg <= 0;
        else
            q_reg <= q_next;
    end

    // next state of counter
    assign q_next = en ? (cw ? q_reg + 1 : q_reg - 1) : q_reg;

    // use top 3 bits as state
    always_comb state_reg = q_reg[N-1:N-3];

    // outputs
    always_comb begin
        seg   = 8'b11111111;   // default blank
        digit = 8'b11111111;

        case(state_reg)
            3'b000: begin digit = 8'b11110111; seg = 8'b10011100; end
            3'b001: begin digit = 8'b11111011; seg = 8'b10011100; end
            3'b010: begin digit = 8'b11111101; seg = 8'b10011100; end
            3'b011: begin digit = 8'b11111110; seg = 8'b10011100; end
            3'b100: begin digit = 8'b11111110; seg = 8'b10100011; end
            3'b101: begin digit = 8'b11111101; seg = 8'b10100011; end
            3'b110: begin digit = 8'b11111011; seg = 8'b10100011; end
            3'b111: begin digit = 8'b11110111; seg = 8'b10100011; end
        endcase
    end
endmodule
