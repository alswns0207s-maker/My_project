`timescale 1ns / 1ps

module tb;

    parameter WIDTH = 8;

    reg push;
    reg pop;
    reg clk;
    reg reset;
    reg [7:0] w_data;
    wire [7:0] r_data;

    integer i;
    reg [7:0] compare_buffer [0:(2**WIDTH)-1];
    reg [WIDTH-1:0] push_cnt;
    reg [WIDTH-1:0] pop_cnt;

    fifo dut (
        .push(push),
        .pop(pop),
        .clk(clk),
        .reset(reset),
        .wdata(w_data),
        .rdata(r_data)
    );

    always #5 clk = ~clk;

    initial begin
        clk    = 0;
        reset  = 1;
        pop    = 0;
        push   = 0;
        w_data = 8'h00;

        @(negedge clk);
        reset = 0;

        // 1차 write
        push = 1;
        w_data = 8'h0a;
        @(negedge clk);
        w_data = 8'h0b;
        @(negedge clk);
        w_data = 8'h0c;
        @(negedge clk);
        w_data = 8'h0d;
        @(negedge clk);
        w_data = 8'h0e;
        @(negedge clk);
        push = 0;

        // read
        @(negedge clk);
        pop = 1;
        #50;
        pop = 0;

        // 2차 write/read
        @(negedge clk);
        push = 1;
        reset = 0;
        w_data = 8'h0a;
        #5;
        pop = 1;

        @(negedge clk);
        w_data = 8'h0b;
        @(negedge clk);
        w_data = 8'h0c;
        @(negedge clk);
        w_data = 8'h0d;
        @(negedge clk);
        w_data = 8'h0e;
        @(negedge clk);
        w_data = 8'h0f;
        @(negedge clk);
        w_data = 8'h10;
        @(negedge clk);
        w_data = 8'h20;
        @(negedge clk);
        push = 0;
        @(negedge clk);
        pop = 0;

        #10;
        $display("%t: RANDOM test start", $time); //230000ps

        push_cnt = 0;
        pop_cnt  = 0;

        for (i = 0; i < 256; i = i + 1) begin
            push = $random % 2;
            pop  = $random % 2;
            w_data = $random % 256;

            $strobe("%t: push=%d, pop=%d, w_data=%d", $time, push, pop, w_data);

            if (push) begin
                compare_buffer[push_cnt] = w_data;
                $strobe("%t: write compare_buffer[%0d] = %d", $time, push_cnt, compare_buffer[push_cnt]);
                push_cnt = push_cnt + 1;
            end

            if (pop) begin
                if (pop_cnt < push_cnt) begin
                    if (compare_buffer[pop_cnt] == r_data) begin
                        $display("%t: PASS!! compare_data=%d, r_data=%d, pop_cnt=%0d",
                                 $time, compare_buffer[pop_cnt], r_data, pop_cnt);
                    end else begin
                        $display("%t: FAIL!! compare_data=%d, r_data=%d, pop_cnt=%0d",
                                 $time, compare_buffer[pop_cnt], r_data, pop_cnt);
                    end
                    pop_cnt = pop_cnt + 1;
                end
            end

            #10;
        end

        $finish;
    end

endmodule