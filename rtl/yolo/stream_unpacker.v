`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: stream_unpacker
// Description: 
//   - GFB에서 읽어온 2048-bit 덩어리를 받아, 128-bit(16채널)씩 16번 뱉어냅니다.
//   - 💡 [Zero-Bubble 설계] 16번째 조각을 뱉어냄과 동시에 다음 2048-bit 데이터를
//     받아들여, 단 1클럭의 쉬는 시간 없이 무한 스트리밍(100% Throughput)을 달성합니다.
//////////////////////////////////////////////////////////////////////////////////

module stream_unpacker #(
    parameter IN_WIDTH  = 2048, // GFB의 1주소 데이터 폭
    parameter OUT_WIDTH = 128   // 하위 연산기(Conv)의 1클럭 입력 폭
)(
    input  wire                 clk,      // 시스템 클럭
    input  wire                 rst_n,    // 비동기 리셋 (Active-Low)

    // [Input] GFB (Read Controller)로부터 들어오는 2048-bit 데이터
    input  wire [IN_WIDTH-1:0]  data_in,  
    input  wire                 valid_in, // 2048-bit 데이터가 유효함을 알림
    output wire                 ready_out,// GFB 측에 "나 받을 준비 됐어"라고 알림
    
    // [Output] Coordinate Generator로 나가는 128-bit 스트림
    output reg  [OUT_WIDTH-1:0] data_out,
    output reg                  valid_out,
    input  wire                 ready_in  // 하위 모듈이 멈추라고 보내는 브레이크 신호
);

    // =========================================================================
    // [내부 상태 레지스터 선언]
    // =========================================================================
    reg [IN_WIDTH-1:0] buffer;    // 2048-bit 데이터를 붙잡아둘 거대 래치(Latch)
    reg [3:0]          chunk_idx; // 0~15까지 세는 4-bit 조각 인덱스
    reg                busy;      // 현재 버퍼 안에 해체 중인 데이터가 있는지 여부 (1: 해체중)

    // 💡 [Zero-Bubble Ready 로직]
    // 내가 비어있거나(!busy), 현재 마지막 15번째 조각을 뱉고 있으면서 하위 모듈이 삼켜줄 때
    // 앞단에 ready_out = 1을 보내 다음 2048-bit를 들이밀라고 지시합니다.
    assign ready_out = (!busy) || (busy && (chunk_idx == 4'd15) && ready_in);

    // =========================================================================
    // [Unpacking 순차 회로 (FSM)]
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            buffer <= 0; chunk_idx <= 0; busy <= 0;
            data_out <= 0; valid_out <= 0;
        end 
        else if (ready_in) begin // 하위 모듈이 받을 수 있을 때만 동작
            
            // 상태 1: 비어있을 때 (IDLE)
            if (!busy) begin
                if (valid_in) begin
                    buffer <= data_in; // 2048-bit 버퍼에 저장
                    busy <= 1'b1;      // 작업 시작 선언
                    
                    // 1클럭의 지연도 없애기 위해, 받는 즉시 0번째 조각(0~127bit)을 밖으로 출력
                    data_out <= data_in[0 +: OUT_WIDTH];
                    valid_out <= 1'b1;
                    chunk_idx <= 4'd1; // 다음 클럭엔 1번째 조각을 뱉어야 하므로 인덱스는 1로 셋팅
                end else begin
                    valid_out <= 1'b0; // 들어온 게 없으면 쓰레기값 출력 방지
                end
            end 
            
            // 상태 2: 버퍼에 있는 데이터를 썰고 있을 때 (UNPACKING)
            else begin
                // Variable Part-Select 문법: chunk_idx 위치부터 128비트를 잘라냅니다.
                data_out <= buffer[chunk_idx * OUT_WIDTH +: OUT_WIDTH];
                valid_out <= 1'b1;
                
                // 만약 방금 뱉은 게 마지막 15번째 조각이었다면?
                if (chunk_idx == 4'd15) begin
                    // 이때 앞단에서 새로운 2048-bit를 바로 들이밀었다면 (Back-to-back)
                    if (valid_in) begin
                        buffer <= data_in; // 새 데이터를 덮어씀
                        chunk_idx <= 4'd1; // 인덱스를 1로 되감음
                        // 0번째 조각은 버퍼에 안 가고 바로 바이패스 출력!
                        data_out <= data_in[0 +: OUT_WIDTH];
                    end else begin
                        // 새 데이터가 없으면 비어있는 상태(IDLE)로 돌아감
                        busy <= 1'b0;
                        chunk_idx <= 4'd0;
                    end
                end else begin
                    // 마지막 조각이 아니면 인덱스만 1 증가시킴
                    chunk_idx <= chunk_idx + 1;
                end
            end
        end
    end
endmodule