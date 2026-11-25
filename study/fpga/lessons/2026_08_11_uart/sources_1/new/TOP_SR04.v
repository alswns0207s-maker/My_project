`timescale 1ns / 1ps
module TOP_SR04 (
    input  clk,
    input  reset,
    input  btn,
    input  echo,
    output trigger,
    output [3:0]fnd_com,
    output [13:0]fnd_data
);
    wire w_o_btn;
    wire w_distance;

    sr04_controller U_SR04_CONTROLLER (
        .clk(clk),
        .reset(reset),
        .echo(echo),
        .start(w_o_btn),
        .trigger(trigger),
        .distance(w_distance),
        .done(done)
    );


    fnd_controller U_FND_CONTROLLER (
        .clk(clk),
        .reset(reset),
        .fnd_in(w_distance),
        .fnd_com(fnd_com),
        .fnd_data(fnd_data)
    );
    btn_debounce U_BTN_DEBOUNCE (
        .clk  (clk),
        .reset(reset),
        .i_btn(btn),
        .o_btn(w_o_btn)
    );




endmodule
