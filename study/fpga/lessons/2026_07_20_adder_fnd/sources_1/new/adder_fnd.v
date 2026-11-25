`timescale 1ns / 1ps

module adder_fnd(
    input [7:0]a, 
    input [7:0]b,
    input btn_L,
    input btn_R,
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
    .fnd_in(s),
    .digit_sel({btn_L, btn_R}), //concatenation msb : btn_L, lsb: btn_R
    .fnd_com(fnd_com),
    .fnd_data(fnd_data)

);


endmodule
