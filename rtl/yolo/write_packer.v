`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: write_packer
// Description: 
//   - Post Processor에서 나오는 128-bit 데이터를 받아 16번 모아서 
//     2048-bit의 거대한 한 덩어리로 압축(Packing)하는 모듈입니다.
//   - 💡 [Flush 로직 제거] Top FSM이 프레임 종료 후 더미 픽셀(Dummy Pixel)을 
//     밀어넣어 파이프라인을 비울 것이므로, 본 모듈은 Flush 제어 신호 없이 
//     무조건 16개가 찰 때마다 BRAM에 쓰기(Write)만 수행하도록 최적화되었습니다.
//   - 💡 [데이터 오염 버그 치료] 2048-bit가 완성되는 즉시 출력 레지스터(out_reg)에 
//     래치(Latch)하여, 연속 스트리밍 시 미래의 데이터가 과거를 덮어쓰는 버그를 차단했습니다.
//////////////////////////////////////////////////////////////////////////////////

module write_packer #(
    parameter IN_WIDTH   = 128,  // 단일 픽셀 조각 비트 수 (16채널 * 8비트)
    parameter OUT_WIDTH  = 2048, // GFB에 쓰일 1단어 비트 수
    parameter PACK_RATIO = 16    // 2048 / 128 = 16번의 패킹 비율
)(
    input wire clk,              // 시스템 클럭
    input wire rst_n,            // 비동기 리셋

    input wire                i_start,  // 💡 레이어 시작 펄스 (찌꺼기 비우기 용도)
    input wire [IN_WIDTH-1:0] data_in,  // 포스트 프로세서에서 들어오는 128-bit 데이터
    input wire                valid_in, // 입력 데이터 유효 깃발
    
    output reg [OUT_WIDTH-1:0] data_out, // 2048-bit 꽉 찬 데이터 출력 (1클럭 래치됨)
    output reg                 we_out    // GFB BRAM 쓰기 활성화 신호
);

    // 0~14번 방(총 15개) 대기실 배열. 15번째 데이터는 조합회로로 즉시 병합됨.
    reg [IN_WIDTH-1:0] pack_array [0:14]; 
    reg [4:0] pack_cnt; // 현재 모인 픽셀 개수 (0 ~ 15)

    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            pack_cnt <= 0;
            we_out   <= 0;
            data_out <= 0;
            for (i=0; i<15; i=i+1) pack_array[i] <= 0;
        end 
        // 💡 [오염 방지] 새 레이어가 시작되면 모아둔 픽셀 카운터를 0으로 초기화!
        else if (i_start) begin
            pack_cnt <= 0;
            we_out   <= 0;
        end
        else begin
            we_out <= 1'b0; // 평상시에는 GFB Write 금지

            if (valid_in) begin
                // 마지막 16번째 픽셀이 들어오는 순간!
                if (pack_cnt == 5'd15) begin
                    // LSB(우측)에 0번 방, MSB(좌측)에 최신 15번 픽셀을 이어붙입니다.
                    data_out <= {data_in, 
                                 pack_array[14], pack_array[13], pack_array[12], pack_array[11], 
                                 pack_array[10], pack_array[9],  pack_array[8],  pack_array[7], 
                                 pack_array[6],  pack_array[5],  pack_array[4],  pack_array[3], 
                                 pack_array[2],  pack_array[1],  pack_array[0]};
                    
                    we_out   <= 1'b1;  // 다음 클럭에 GFB에 쓰기 지시
                    pack_cnt <= 0;     // 카운터를 비워 새로운 2048-bit 패킹 준비
                end 
                else begin
                    // 아직 16개가 안 모였으면 해당 방 번호에 데이터를 임시 보관
                    pack_array[pack_cnt] <= data_in;
                    pack_cnt <= pack_cnt + 1;
                end
            end
        end
    end

endmodule