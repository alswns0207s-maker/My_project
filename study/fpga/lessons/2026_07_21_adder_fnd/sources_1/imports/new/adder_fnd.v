`timescale 1ns / 1ps

module adder_fnd(
    input clk,
    input reset,
    input [7:0]a, 
    input [7:0]b,
    output [3:0] fnd_com,
    output [7:0] fnd_data,
    output c
    );

    wire [7:0] s;

full_adder_8bit FA8(
    .a(a),
    .b(b),
    .c(c),
    .s(s)
);



fnd_controller U_FSN_CNTL(
    .clk(clk),
    .reset(reset),
    .fnd_in(s),
    .fnd_com(fnd_com),
    .fnd_data(fnd_data)

);


endmodule
