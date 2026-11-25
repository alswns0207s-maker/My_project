`timescale 1ns / 1ps
//=====================================================================
// tb_sr04_controller  -  minimal functional check (real TICK_1US=100)
//   reset -> 1 measurement (30cm echo) -> done. That's it.
//=====================================================================
module tb_sr04_controller;

    reg clk = 0, reset = 1, start = 0, echo = 0;
    wire done, valid, trigger;
    wire [8:0] distance;

    sr04_controller dut (   // TICK_1US 기본값(100) 그대로 사용
        .clk     (clk),
        .reset   (reset),
        .start   (start),
        .echo    (echo),
        .done    (done),
        .valid   (valid),
        .trigger (trigger),
        .distance(distance)
    );

    always #5 clk = ~clk;   // 100MHz

    initial begin
        // 1) reset 직후 : 전부 0 이어야 정상
        reset = 1; start = 0; echo = 0;
        repeat (5) @(posedge clk);
        reset = 0;
        repeat (3) @(posedge clk);
        $display("[reset] done=%b valid=%b trigger=%b distance=%0d  (기대: 0 0 0 0)",
                  done, valid, trigger, distance);

        // 2) 측정 1회 : echo 를 30cm 에 해당하는 폭(1740us)만큼 High
        start = 1; @(posedge clk); start = 0;
        wait (trigger == 1);
        wait (trigger == 0);          // TRIGGER 끝 = WAIT_RISE 진입
        repeat (200) @(posedge clk);  // 센서가 응답하기까지 잠깐 대기
        echo = 1;
        repeat (30 * 58 * 100) @(posedge clk);   // 30cm -> 1740us -> *100 clk (TICK_1US=100)
        echo = 0;
        wait (done == 1);
        $display("[measure] distance=%0d cm valid=%b  (기대: 30, 1)", distance, valid);

        repeat (20) @(posedge clk);
        $display("TEST COMPLETE");
        $finish;
    end

endmodule
