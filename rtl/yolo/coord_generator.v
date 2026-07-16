`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: coord_generator
// Description: 
//   - Unpacker에서 나오는 128-bit 스트림에 X/Y 좌표와 Last Fold 깃발을 붙여줍니다.
//   - 💡 [게이트키퍼 수술 완료] Top FSM으로부터 target_pixel을 입력받아, 
//     목표 픽셀 수를 초과하는 나머지 조각(더미 패딩)에 대해서는 valid_out을 0으로 
//     강제 차단(Masking)하여 파이프라인 붕괴를 막습니다.
//   - 💡 [레이어 초기화 핀 추가] i_start 펄스를 받아 내부 카운터를 깔끔하게 리셋합니다.
//////////////////////////////////////////////////////////////////////////////////

module coord_generator #(
    parameter DATA_WIDTH = 128 
)(
    input  wire                  clk,
    input  wire                  rst_n,
    
    // [Dynamic Parameters from Top FSM]
    input  wire                  i_start,      // 💡 현재 레이어 연산 시작 펄스 (1클럭)
    input  wire [9:0]            total_ch_in,  // 활성 채널 수
    input  wire [10:0]           img_width,    // 현재 레이어 이미지 폭
    input  wire [19:0]           target_pixel, // 💡 이번 레이어에서 처리해야 할 "진짜" 픽셀 총 개수
    
    // [Input] Unpacker Interface
    input  wire [DATA_WIDTH-1:0] data_in,
    input  wire                  valid_in,
    output wire                  ready_out,   
    
    // [Output] Downstream Conv Interface
    output reg  [DATA_WIDTH-1:0] data_out,      
    output reg                   valid_out,     
    output reg                   last_fold_out, 
    output reg  [10:0]           px_out,        
    output reg  [10:0]           py_out,        
    input  wire                  ready_in       
);

    assign ready_out = ready_in; 

    // [내부 상태 추적 카운터]
    reg [4:0]  fold_cnt;              
    reg [10:0] current_px, current_py;
    reg [19:0] pixel_cnt; // 💡 현재까지 조립 완료된 픽셀 수를 세는 거대 카운터

    wire [4:0] max_folds = total_ch_in / 16; 

    always @(posedge clk) begin
        if (!rst_n) begin
            data_out <= 0; valid_out <= 0; last_fold_out <= 0;
            px_out <= 0; py_out <= 0;
            fold_cnt <= 0; current_px <= 0; current_py <= 0;
            pixel_cnt <= 0;
        end 
        // 💡 Top FSM에서 새 레이어 시작 명령을 내리면 모든 카운터 초기화
        else if (i_start) begin
            fold_cnt <= 0; current_px <= 0; current_py <= 0; pixel_cnt <= 0;
            valid_out <= 0; last_fold_out <= 0;
        end
        else if (ready_in) begin 
            
            if (valid_in) begin
                // 💡 [핵심: 더미 픽셀 필터링 (Gatekeeper)]
                // 현재 처리한 픽셀 수가 목표 픽셀 수보다 적을 때만 "진짜 데이터"로 인정합니다.
                if (pixel_cnt < target_pixel) begin
                    
                    // 진짜 데이터이므로 문을 열어줍니다.
                    valid_out <= 1'b1;
                    data_out  <= data_in;
                    px_out    <= current_px;
                    py_out    <= current_py;
                    
                    // 현재 조각이 1개 픽셀을 완성하는 마지막 폴딩이라면?
                    if (fold_cnt == max_folds - 1) begin
                        last_fold_out <= 1'b1; 
                        fold_cnt      <= 5'd0; 
                        
                        // 픽셀 1개 조립 완료! 전체 픽셀 카운터 1 증가
                        pixel_cnt <= pixel_cnt + 1;
                        
                        // X, Y 좌표 이동 로직
                        if (current_px == img_width - 1) begin
                            current_px <= 11'd0;           
                            current_py <= current_py + 1;
                        end else begin
                            current_px <= current_px + 1;  
                        end
                    end 
                    else begin
                        // 마지막 조각이 아니면 폴딩 카운터만 증가
                        last_fold_out <= 1'b0;
                        fold_cnt <= fold_cnt + 1;
                    end
                end 
                else begin
                    // 💡 목표 픽셀 수(target_pixel)를 이미 달성했다면, 
                    // Unpacker가 밀어넣는 나머지 데이터는 모두 '더미(Dummy) 쓰레기'입니다.
                    // valid_out을 0으로 강제 차단하여 하위 모듈이 무시하도록 만듭니다!
                    valid_out     <= 1'b0;
                    data_out      <= 0; // 안전을 위해 데이터도 0으로 밀어버림
                    last_fold_out <= 1'b0;
                end
            end 
            else begin
                valid_out <= 1'b0;
                last_fold_out <= 1'b0;
            end
        end
    end
endmodule