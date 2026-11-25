`timescale 1ns / 1ps
//======================================================================
// tb_register_file : register_file 모듈 단독(unit-level) 테스트벤치
//  - 여러 주소에 write 후 순서를 섞어서 read, 값이 맞는지 self-checking
//  - nonblocking write가 실제로 반영되는 시점을 display/strobe로 비교
//======================================================================
module tb_register_file();

    parameter WIDTH = 2;
    localparam DEPTH = 2 ** WIDTH;

    reg              clk;
    reg  [WIDTH-1:0] waddr, raddr;
    reg  [7:0]       wdata;
    reg              we;
    wire [7:0]       rdata;

    reg [7:0] expected [0:DEPTH-1];
    integer   i;
    integer   pass_count, fail_count;

    register_file #(.WIDTH(WIDTH)) dut (
        .clk  (clk),
        .waddr(waddr),
        .raddr(raddr),
        .wdata(wdata),
        .we   (we),
        .rdata(rdata)
    );

    always #5 clk = ~clk;

    // 안전하게 드라이브: posedge+1에서 값 세팅, 다음 posedge에서 실제 write 반영
    task automatic WRITE(input [WIDTH-1:0] addr, input [7:0] data);
        begin
            @(posedge clk); #1;
            waddr = addr;
            wdata = data;
            we    = 1'b1;
            expected[addr] = data;

            @(posedge clk);
            // display vs strobe : 이 posedge에서 register_file[addr]<=wdata가
            // 실제로 언제 반영되는지 active vs postponed region으로 비교
            $display("%0t [DISPLAY] posedge 직후(active region)     register_file[%0d]=%0d",
                       $time, addr, dut.register_file[addr]);
            $strobe ("%0t [STROBE ] 같은 시각(postponed region, settle 후) register_file[%0d]=%0d",
                       $time, addr, dut.register_file[addr]);
            #1;
            we = 1'b0;
        end
    endtask

    // 조합논리 read이므로 negedge에서 안정적으로 확인
    task automatic CHECK_READ(input [WIDTH-1:0] addr);
        begin
            @(negedge clk);
            raddr = addr;
            #1;
            if (rdata == expected[addr]) begin
                $strobe("%0t : PASS!! raddr=%0d expected=%0d got=%0d",
                         $time, addr, expected[addr], rdata);
                pass_count = pass_count + 1;
            end else begin
                $strobe("%0t : FAIL!! raddr=%0d expected=%0d got=%0d",
                         $time, addr, expected[addr], rdata);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        clk        = 0;
        we         = 0;
        waddr      = 0;
        raddr      = 0;
        wdata      = 0;
        pass_count = 0;
        fail_count = 0;
        for (i = 0; i < DEPTH; i = i + 1) expected[i] = 8'h00;

        // 서로 다른 값으로 각 주소 write
        WRITE(0, 8'hA0);
        WRITE(1, 8'hB1);
        WRITE(2, 8'hC2);
        WRITE(3, 8'hD3);

        // write 순서와 다르게 섞어서 read 검증
        CHECK_READ(2);
        CHECK_READ(0);
        CHECK_READ(3);
        CHECK_READ(1);

        // 같은 주소 재write 후 갱신 확인 (덮어쓰기 검증)
        WRITE(1, 8'hFF);
        CHECK_READ(1);
        CHECK_READ(0);  // 다른 주소는 그대로인지도 같이 확인

        #20;
        $display("%0t : TEST DONE - pass_count=%0d fail_count=%0d", $time, pass_count, fail_count);
        $finish;
    end

endmodule