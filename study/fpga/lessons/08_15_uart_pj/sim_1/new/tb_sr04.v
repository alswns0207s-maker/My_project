`timescale 1ns / 1ps

module tb_sr04_controller();

    reg clk;
    reg reset;
    reg start;
    reg echo;

    wire done;
    wire valid;
    wire trigger;
    wire [8:0] distance;

    // DUT
    sr04_controller #(
        .TICK_1US(100)
    ) DUT (
        .clk      (clk),
        .reset    (reset),
        .start    (start),
        .echo     (echo),
        .done     (done),
        .valid    (valid),
        .trigger  (trigger),
        .distance (distance)
    );

    // 100MHz clock
    always #5 clk = ~clk;

    initial begin
        clk   = 0;
        reset = 1;
        start = 0;
        echo  = 0;

        // reset
        #20;
        reset = 0;

        // start
        #20;
        start = 1;
        #10;
        start = 0;

        // wait finish trigger
        wait(trigger == 0);

        // sensor echo HIGH
        #20;
        echo = 1;

        // echo HIGH = 2000us
        // distance = 2000 / 58 ≈ 34cm
        #2_000_000;
        echo = 0;

        #100;

        $finish;
    end

endmodule