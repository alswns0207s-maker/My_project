`timescale 1ns / 1ps


module tb_uart ();
    parameter BAUD_TICK = (100000000 / 9600) * 10;
    reg rx, clk, reset, tx_start;
    reg [7:0] tx_data;
    wire tx_busy;
    wire tx_done;
    wire rx_done;
    wire [7:0] rx_data;
    integer i;
    reg [7:0] o_rx_data;


    uart_controller DUT (
        .clk(clk),
        .reset(reset),
        .tx(tx),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx_busy(tx_busy),
        .tx_done(tx_done),
        .rx(rx),
        .rx_done(rx_done),
        .rx_data(rx_data)
    );
    always #5 clk = ~clk;



    task SENDER_FOR_UART_RX(input [7:0] send_data);
        begin
            //START
            rx = 0;
            #(BAUD_TICK);
            //DATA
            for (i = 0; i < 8; i = i + 1) begin
                rx = send_data[i];
                #(BAUD_TICK);
            end

        end
        rx = 1;
        #(BAUD_TICK);
    endtask

    task UART_TX_START_task(input [7:0] i_tx_data);
        begin
            //uart tx
            @(negedge clk);  // wait

            tx_start = 1;
            tx_data  = i_tx_data;
            @(negedge clk);  // wait
            tx_start = 0;
            wait (DUT.U_UART_TX.tx_done);
            // #(BAUD_TICK * 10);

        end
    endtask









    initial begin
        clk = 0;
        reset = 1;
        tx_start = 0;
        tx_data = 0;
        rx = 1;
        #10;
        reset = 0;
        #10;
        // for (i = 0; i < 256; i = i + 1) begin
        //     UART_TX_task(i);
        //     if(i == o_rx_data)begin
        //         $display("PASS");
        //     end else
        //         $display("FAIL");

        UART_TX_START_TASK(8'h30);
        UART_TX_START_TASK(8'h31);


        SENDER_FOR_UART_RX(8'h32);
        SENDER_FOR_UART_RX(8'h33);

        #100;
        $STOP;
    end



endmodule
