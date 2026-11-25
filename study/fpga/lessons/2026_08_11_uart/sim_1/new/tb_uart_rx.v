`timescale 1ns / 1ps
//======================================================================
// tb_uart_rx : UART_RX 모듈 단독(unit-level) 테스트벤치
//  - FIFO 없이 rx 핀에 직접 프레임을 실어보내서 rx_data/rx_done만 검증
//======================================================================
module tb_uart_rx();

    localparam BIT_TIME = 104160; // 100MHz clk, 9600 baud, 16x oversample 기준 1비트 시간

    reg        clk;
    reg        reset;
    reg        rx;
    wire [7:0] rx_data;
    wire       rx_done;
    wire       w_baud_tick_16;

    integer pass_count;
    integer fail_count;

    baud_tick_rx U_BAUD_TICK_x16 (
        .clk        (clk),
        .reset      (reset),
        .o_baud_tick(w_baud_tick_16)
    );

    uart_rx dut (
        .clk        (clk),
        .reset      (reset),
        .rx         (rx),
        .i_baud_tick(w_baud_tick_16),
        .rx_data    (rx_data),
        .rx_done    (rx_done)
    );

    always #5 clk = ~clk;

    task automatic SEND_BYTE(input [7:0] data);
        integer k;
        begin
            rx = 1'b0;              // start bit
            #(BIT_TIME);
            for (k = 0; k < 8; k = k + 1) begin
                rx = data[k];        // LSB부터
                #(BIT_TIME);
            end
            rx = 1'b1;               // stop bit
            #(BIT_TIME);
        end
    endtask

    task automatic CHECK_ONE(input [7:0] expected);
        begin
            @(posedge rx_done);
            // display vs strobe 타이밍 비교: 같은 시각, active vs postponed region 차이 관찰
            $display("%0t [DISPLAY] rx_done 발생 직후(active region)     rx_data=%0d", $time, rx_data);
            $strobe ("%0t [STROBE ] 같은 시각(postponed region, settle 후) rx_data=%0d", $time, rx_data);

            if (rx_data == expected) begin
                $strobe("%0t : PASS!! expected=%0d got=%0d", $time, expected, rx_data);
                pass_count = pass_count + 1;
            end else begin
                $strobe("%0t : FAIL!! expected=%0d got=%0d", $time, expected, rx_data);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        clk        = 0;
        reset      = 1;
        rx         = 1'b1;   // idle high
        pass_count = 0;
        fail_count = 0;

        #100;
        reset = 0;

        fork
            begin
                SEND_BYTE(8'h41);
                SEND_BYTE(8'h5A);
                SEND_BYTE(8'h00);
                SEND_BYTE(8'hFF);
            end
            begin
                CHECK_ONE(8'h41);
                CHECK_ONE(8'h5A);
                CHECK_ONE(8'h00);
                CHECK_ONE(8'hFF);
            end
        join

        #(BIT_TIME);
        $display("%0t : TEST DONE - pass_count=%0d fail_count=%0d", $time, pass_count, fail_count);
        $finish;
    end

endmodule