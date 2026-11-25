`timescale 1ns / 1ps
module tb_ex();

    reg clk, reset, echo, start, trigger;
    reg [3:0]fnd_com;
    reg [7:0]fnd_data;
    reg [13:0]fnd_in; 
    reg btn;

    TOP_SR04 U_TOP_SR04(
    .clk(clk),
    .reset(reset),
    .btn(btn),
    .echo(echo),
    .trigger(trigger),
    .fnd_com(fnd_com),
    .fnd_data(fnd_data)
);
always #5 clk = ~clk;

initial begin
clk = 0;
reset = 1;
start = 0;
#10;
reset = 0;
start = 1;
#10;
start = 0;
#12_000;
$stop;
end
endmodule
