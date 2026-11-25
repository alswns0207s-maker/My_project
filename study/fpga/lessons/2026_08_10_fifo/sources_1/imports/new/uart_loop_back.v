`timescale 1ns / 1ps
module uart_loop_back(
    input clk,
    input reset,
    input rx,
    output tx
    );
    wire w_baud_tick_16;
    wire w_rx_done;
    wire [7:0] w_rx_data;

    uart_tx U_UART_TX (
        .clk(clk),
        .reset(reset),
        .i_baud_tick(w_i_baud_tick_16),
        .tx_start(w_rx_done),
        .tx_data(w_rx_data),
        .tx(tx),
        .tx_busy(),
        .tx_done()
    );

    baud_tick_rx U_BAUD_TICK_RX (
        .clk(clk),
        .reset(reset),
        .o_baud_tick(w_i_baud_tick_16)
    );

    uart_rx U_UART_RX (
        .clk(clk),
        .reset(reset),
        .rx(rx),
        .i_baud_tick(w_i_baud_tick_16),
        .rx_data(w_rx_data),
        .rx_done(w_rx_done)
    );

endmodule
