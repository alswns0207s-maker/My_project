`timescale 1ns / 1ps
module tb_sr04();

    reg clk, reset, start, echo;
    wire trigger, done;
    wire [8:0] distance;
    sr04_controller DUT(
    .clk(clk),
    .reset(reset),
    .echo(echo),
    .start(start),
    .trigger(trigger),
    .distance(distance),
    .done(done)
);

always #5 clk = ~clk;
initial begin
    clk = 0;
    reset = 1;
    start = 0;
    echo = 0;
    #10;
    reset = 0;
    @(negedge clk);
    start = 1;
    #10;
    start = 0;
    #(12_000);
    $stop;
end



endmodule
