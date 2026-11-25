`timescale 1ns / 1ps

module tb_10000_counter ();

    reg clk;
    reg reset;
    reg btn_L;
    reg btn_R;
    reg btn_U;
    wire [3:0] fnd_com;
    wire [7:0] fnd_data;

    parameter test_delay = 25000_000;

    top_counter_10000 DUT(
        .clk (clk),
        .reset(reset),
        .btn_L(btn_L),
        .btn_R(btn_R),
        .btn_UP(btn_U),
        .fnd_com(fnd_com),
        .fnd_data(fnd_data)
    );


    //clock generation 100MHZ
    always #5 clk = ~clk;
    initial begin
        clk   = 0;
        reset = 1;
        {btn_R, btn_L, btn_U} = 3'b000;
        #10;
        reset = 0;
        //1 stop
        {btn_R, btn_L, btn_U} = 3'b000;
        #(test_delay);

        // run btn push
        {btn_R, btn_L, btn_U} = 3'b010;
        #(test_delay);
        {btn_R, btn_L, btn_U} = 3'b000;
        #(test_delay);
        {btn_R, btn_L, btn_U} = 3'b001;
        #(test_delay);
        {btn_R, btn_L, btn_U} = 3'b000;
        #(test_delay);
        // period tick clock : 1_000_000, 1clock : 10nsec, 10 : 10 tickS
        // #(1_000_000 * 10 * 10);
        #(1000);
    end

endmodule
