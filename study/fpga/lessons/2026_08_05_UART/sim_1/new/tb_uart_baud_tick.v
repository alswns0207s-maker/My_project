`timescale 1ns / 1ps

module tb_uart_baud_tick();

    parameter BAUD_TICK = 100_000_000/9600*10;

    reg clk, reset;
    wire o_baud_tick;

    baud_tick dut(

    .clk(clk),
    .reset(reset),
    .o_baud_tick(o_baud_tick)
);

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;
        #20
        reset = 0;        
        #(BAUD_TICK * 10);

        #100;
    $stop;
    end




endmodule
