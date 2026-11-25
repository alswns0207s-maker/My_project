`timescale 1ns / 1ps

module tb_pipeline_cpu;

    logic clk;
    logic reset;

    pipeline_cpu DUT (
        .clk   (clk),
        .reset (reset)
    );

    // 10ns 주기의 클록
    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        reset = 1'b0;


        repeat (2) @(negedge clk);
        reset = 1'b1;

        
        repeat (10) @(negedge clk);
        $finish;
    end

endmodule