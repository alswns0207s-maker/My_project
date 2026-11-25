`timescale 1ns / 1ps

module register_8bit(
    input [7:0] D,
    input clk,
    input reset,
    output reg [7:0] Q,
    input we

    );

    always@(posedge clk, posedge reset)
    if(reset)begin
        Q <= 0;
    end else if(we == 1) Q <= D;

endmodule

