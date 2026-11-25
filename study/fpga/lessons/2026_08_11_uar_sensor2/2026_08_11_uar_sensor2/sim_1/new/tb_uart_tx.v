`timescale 1ns / 1ps
//======================================================================
// tb_uart_tx : UART_TX 모듈 단독(unit-level) 테스트벤치
//  - FIFO 없이 tx_start/tx_data를 직접 드라이브하고, tx 파형을 복원해서 검증
//======================================================================
module tb_uart_tx();

    localparam BIT_TIME = 104160;

    reg        clk;
    reg        reset;
    reg        tx_start;
    reg  [7:0] tx_data;
    wire       tx;
    wire       tx_busy;
    wire       tx_done;
    wire       w_baud_tick_16;

    integer pass_count;
    integer fail_count;

    baud_tick_rx U_BAUD_TICK_x16 (
        .clk        (clk),
        .reset      (reset),
        .o_baud_tick(w_baud_tick_16)
    );

    uart_tx dut (
        .clk        (clk),
        .reset      (reset),
        .i_baud_tick(w_baud_tick_16),
        .tx_start   (tx_start),
        .tx_data    (tx_data),
        .tx         (tx),
        .tx_busy    (tx_busy),
        .tx_done    (tx_done)
    );

    always #5 clk = ~clk;

    // tx_start를 1클럭만 펄스로 걸어서 한 바이트 전송을 시작시킴
    task automatic START_TX(input [7:0] data);
        begin
            @(posedge clk);
            tx_data  = data;
            tx_start = 1'b1;
            // display vs strobe 타이밍 비교: 드라이브 직후 같은 시각 값 비교
            $display("%0t [DISPLAY] tx_start 드라이브 직후(active region)   tx_busy=%b", $time, tx_busy);
            $strobe ("%0t [STROBE ] 같은 시각(postponed region, settle 후) tx_busy=%b", $time, tx_busy);
            @(posedge clk);
            tx_start = 1'b0;
        end
    endtask

    // tx 파형을 직접 관찰해서 한 바이트 복원 + 비교
    task automatic RECEIVE_AND_CHECK(input [7:0] expected);
        reg [7:0] got;
        integer k;
        begin
            @(negedge tx);
            #(BIT_TIME/2);
            if (tx !== 1'b0)
                $display("%0t : START BIT ERROR (tx=%b)", $time, tx);

            for (k = 0; k < 8; k = k + 1) begin
                #(BIT_TIME);
                got[k] = tx;
            end

            #(BIT_TIME);
            if (tx !== 1'b1)
                $display("%0t : STOP BIT ERROR (tx=%b)", $time, tx);

            if (got == expected) begin
                $strobe("%0t : PASS!! expected=%0d got=%0d", $time, expected, got);
                pass_count = pass_count + 1;
            end else begin
                $strobe("%0t : FAIL!! expected=%0d got=%0d", $time, expected, got);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        clk        = 0;
        reset      = 1;
        tx_start   = 0;
        tx_data    = 0;
        pass_count = 0;
        fail_count = 0;

        #100;
        reset = 0;

        fork
            begin
                START_TX(8'h41);
                @(posedge tx_done);
                START_TX(8'h5A);
                @(posedge tx_done);
                START_TX(8'hC3);
            end
            begin
                RECEIVE_AND_CHECK(8'h41);
                RECEIVE_AND_CHECK(8'h5A);
                RECEIVE_AND_CHECK(8'hC3);
            end
        join

        #(BIT_TIME);
        $display("%0t : TEST DONE - pass_count=%0d fail_count=%0d", $time, pass_count, fail_count);
        $finish;
    end

endmodule