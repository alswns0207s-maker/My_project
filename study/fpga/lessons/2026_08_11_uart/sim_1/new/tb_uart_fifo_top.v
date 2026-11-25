`timescale 1ns / 1ps

module tb_uart_fifo_top();

    parameter BAUD_TICK = (100_000_000 / 9600) * 10;  // 104160ns = 1비트 시간

    reg  clk;
    reg  reset;
    reg  rx;
    wire tx;

    integer i, j;
    integer send_idx, recv_idx;
    integer pass_count, fail_count;

    reg [7:0] expected_data [0:15];  
                                     
                                     
                                     
    reg [7:0] receive_data;          

    uart_fifo_loopback_top dut (
        .clk  (clk),
        .reset(reset),
        .rx   (rx),
        .tx   (tx)
    );

    always #5 clk = ~clk;
    task SENDER_FOR_UART_RX(input [7:0] send_data);
        begin
            expected_data[send_idx] = send_data;
            send_idx = send_idx + 1;

            // START
            rx = 0;
            #(BAUD_TICK);
            // DATA
            for (i = 0; i < 8; i = i + 1) begin
                rx = send_data[i];
                #(BAUD_TICK);
            end
            // STOP
            rx = 1;
            #(BAUD_TICK);
        end
    endtask
    task RECEIVER();
        begin
            wait (~tx);
            #(BAUD_TICK / 2);
            if (tx) $display("%0t : start bit error", $time);

            for (j = 0; j < 8; j = j + 1) begin
                #(BAUD_TICK);
                receive_data[j] = tx;
            end

            #(BAUD_TICK);
            if (~tx) $display("%0t : stop bit error", $time);

            if (receive_data == expected_data[recv_idx]) begin
                $strobe("%0t : PASS!! expected=%0d receive_data=%0d",
                         $time, expected_data[recv_idx], receive_data);
                pass_count = pass_count + 1;
            end else begin
                $strobe("%0t : FAIL!! expected=%0d receive_data=%0d",
                         $time, expected_data[recv_idx], receive_data);
                fail_count = fail_count + 1;
            end
            recv_idx = recv_idx + 1;
        end
    endtask

    always @(posedge clk) begin
        if (!reset && dut.w_rx_done) begin
            $display("%0t [DISPLAY] rx_done 직후(active region)     fifo_rx_empty=%b fifo_rx_rdata=%0d",
                       $time, dut.w_fifo_rx_empty, dut.w_fifo_rx_rdata);
            $strobe ("%0t [STROBE ] 같은 시각(postponed region, settle 후) fifo_rx_empty=%b fifo_rx_rdata=%0d",
                       $time, dut.w_fifo_rx_empty, dut.w_fifo_rx_rdata);
        end
    end

    initial begin
        clk        = 0;
        reset      = 1;
        rx         = 1'b1;      // idle high
        send_idx   = 0;
        recv_idx   = 0;
        pass_count = 0;
        fail_count = 0;

        #100;
        reset = 0;

        fork
            begin
                SENDER_FOR_UART_RX(8'h41); // 'A'
                SENDER_FOR_UART_RX(8'h42); // 'B'
                SENDER_FOR_UART_RX(8'h43); // 'C'
            end
            begin
                RECEIVER();
                RECEIVER();
                RECEIVER();
            end
        join

        #(BAUD_TICK * 2);
        $display("%0t : TEST DONE - pass_count=%0d fail_count=%0d", $time, pass_count, fail_count);
        $finish;
    end

endmodule