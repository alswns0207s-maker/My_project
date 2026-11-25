`timescale 1ns / 1ps
//======================================================================
// tb_control_unit : control_unit 모듈 단독(unit-level) 테스트벤치
//  - register_file 없이 push/pop만 드라이브해서 wptr/rptr/full/empty가
//    올바른지 레퍼런스 카운터 모델과 비교 (HW10 시나리오 그대로)
//======================================================================
module tb_control_unit();

    parameter WIDTH = 2;
    localparam DEPTH = 2 ** WIDTH;

    reg  clk, reset, push, pop;
    wire [WIDTH-1:0] wptr, rptr;
    wire full, empty;

    integer pass_count, fail_count;
    integer count; // 레퍼런스 모델: 현재 채워진 개수

    control_unit #(.WIDTH(WIDTH)) dut (
        .clk  (clk),
        .reset(reset),
        .push (push),
        .pop  (pop),
        .wptr (wptr),
        .rptr (rptr),
        .full (full),
        .empty(empty)
    );

    always #5 clk = ~clk;

    task automatic DRIVE(input p, input po);
        begin
            @(posedge clk);
            // display vs strobe : 같은 시각, active vs postponed region 비교
            $display("%0t [DISPLAY] posedge 직후(active region)   full=%b empty=%b wptr=%0d rptr=%0d",
                       $time, full, empty, wptr, rptr);
            $strobe ("%0t [STROBE ] 같은 시각(postponed region, settle 후) full=%b empty=%b wptr=%0d rptr=%0d",
                       $time, full, empty, wptr, rptr);
            #1;
            push = p;
            pop  = po;
        end
    endtask

    task automatic CHECK();
        begin
            @(negedge clk);
            // 레퍼런스 모델 갱신 : control_unit의 2'b11 우선순위 규칙을 그대로 반영
            case ({push, pop})
                2'b10: if (count < DEPTH) count = count + 1;   // push only
                2'b01: if (count > 0)     count = count - 1;   // pop only
                2'b11: begin
                    if (count == DEPTH)      count = count - 1;  // full -> pop처럼
                    else if (count == 0)     count = count + 1;  // empty -> push처럼
                    // 그 외는 push+pop 상쇄 -> count 변화 없음
                end
                default: ; // 2'b00
            endcase

            if ((count == 0) == empty && (count == DEPTH) == full) begin
                $strobe("%0t : PASS!! push=%b pop=%b count=%0d wptr=%0d rptr=%0d full=%b empty=%b",
                         $time, push, pop, count, wptr, rptr, full, empty);
                pass_count = pass_count + 1;
            end else begin
                $strobe("%0t : FAIL!! push=%b pop=%b count=%0d wptr=%0d rptr=%0d full=%b empty=%b",
                         $time, push, pop, count, wptr, rptr, full, empty);
                fail_count = fail_count + 1;
            end
        end
    endtask

    integer i;
    initial begin
        clk        = 0;
        reset      = 1;
        push       = 0;
        pop        = 0;
        pass_count = 0;
        fail_count = 0;
        count      = 0;

        @(posedge clk); #1;
        reset = 0;

        // 1) push only x5 (DEPTH=4라 5번째에서도 full이 유지되는지 확인)
        for (i = 0; i < 5; i = i + 1) begin
            DRIVE(1, 0);
            CHECK();
        end

        // 2) 1cycle delay
        DRIVE(0, 0);
        CHECK();

        // 3) pop only x5
        for (i = 0; i < 5; i = i + 1) begin
            DRIVE(0, 1);
            CHECK();
        end

        // 4) push/pop 혼합 : push 1회 -> push/pop 동시 8회 -> pop 1회
        DRIVE(1, 0); CHECK();
        for (i = 0; i < 8; i = i + 1) begin
            DRIVE(1, 1);
            CHECK();
        end
        DRIVE(0, 1); CHECK();

        #20;
        $display("%0t : TEST DONE - pass_count=%0d fail_count=%0d", $time, pass_count, fail_count);
        $finish;
    end

endmodule