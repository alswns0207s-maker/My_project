`timescale 1ns / 1ps
module uart_fifo_loopback_top (
    input  wire clk,
    input  wire reset,
    input  wire rx,
    output wire tx
);

    // ---------------- 16x baud tick (RX/TX 공유) ----------------
    wire w_baud_tick_16;
    baud_tick_rx U_BAUD_TICK_x16 (
        .clk        (clk),
        .reset      (reset),
        .o_baud_tick(w_baud_tick_16)
    );

    // ---------------- UART_RX : 직렬 rx -> 병렬 rx_data ----------------
    wire [7:0] w_rx_data;
    wire       w_rx_done;
    uart_rx U_UART_RX (
        .clk        (clk),
        .reset      (reset),
        .rx         (rx),
        .i_baud_tick(w_baud_tick_16),
        .rx_data    (w_rx_data),
        .rx_done    (w_rx_done)
    );

    // ---------------- FIFO_RX : 수신 데이터 임시 저장 ----------------
    wire [7:0] w_fifo_rx_rdata;
    wire       w_fifo_rx_full;
    wire       w_fifo_rx_empty;
    wire       w_fifo_rx_pop;

    fifo #(.WIDTH(2)) U_FIFO_RX (
        .clk   (clk),
        .reset (reset),
        .push  (w_rx_done),          // 한 바이트 수신 완료될 때마다 push
        .pop   (w_fifo_rx_pop),
        .wdata (w_rx_data),
        .rdata (w_fifo_rx_rdata),
        .full  (w_fifo_rx_full),
        .empty (w_fifo_rx_empty)
    );

    // ---------------- FIFO_TX : 송신 대기 버퍼 ----------------
    wire       w_fifo_tx_push;
    wire       w_fifo_tx_pop;
    wire       w_fifo_tx_full;
    wire       w_fifo_tx_empty;
    wire [7:0] w_fifo_tx_rdata;

    fifo #(.WIDTH(2)) U_FIFO_TX (
        .clk   (clk),
        .reset (reset),
        .push  (w_fifo_tx_push),
        .pop   (w_fifo_tx_pop),
        .wdata (w_fifo_rx_rdata),
        .rdata (w_fifo_tx_rdata),
        .full  (w_fifo_tx_full),
        .empty (w_fifo_tx_empty)
    );

    // ---------------- FIFO_RX <-> FIFO_TX loopback 결선 ----------------
    // RX 버퍼에 데이터가 있고 TX 버퍼에 자리가 있으면 매 클럭 자동으로 한 바이트씩 이동
    assign w_fifo_rx_pop  = ~w_fifo_tx_full;
    assign w_fifo_tx_push = ~w_fifo_rx_empty;

    // ---------------- UART_TX : 병렬 -> 직렬 tx ----------------
    wire w_tx_busy;
    wire w_tx_done;

    // uart_tx가 쉬고 있고(IDLE, ~busy) 보낼 데이터가 있을 때만 정확히 1클럭 pop
    // (tx_busy가 뜨는 순간 자동으로 조건이 꺼지므로 별도 펄스 생성 없이 1클럭 pop이 보장됨)
    assign w_fifo_tx_pop = ~w_tx_busy & ~w_fifo_tx_empty;

    uart_tx U_UART_TX (
        .clk        (clk),
        .reset      (reset),
        .i_baud_tick(w_baud_tick_16),
        .tx_start   (~w_fifo_tx_empty),
        .tx_data    (w_fifo_tx_rdata),
        .tx         (tx),
        .tx_busy    (w_tx_busy),
        .tx_done    (w_tx_done)
    );

endmodule