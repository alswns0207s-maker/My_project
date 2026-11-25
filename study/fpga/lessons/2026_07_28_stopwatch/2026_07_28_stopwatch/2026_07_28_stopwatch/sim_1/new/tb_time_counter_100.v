`timescale 1ns / 1ps

module tb_time_counter();


    reg clk, reset, i_tick, mode, clear;
    wire time_count;

    time_counter dut(
        .clk(clk),
        .reset(reset),
        .clear(clear),
        .time_count(time_count),
        .mode(mode),
        .o_tick(o_tick)
    );


    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 0;
        #10;
        reset = 0;
        #(500000);
        $display (time_count);
        $stop;




    end
endmodule
