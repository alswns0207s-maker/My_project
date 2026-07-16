`timescale 1ns / 1ps

// =================================================================================
// 모듈명: channel_folder_5x5 (Zero-Bubble & Coordinate Sync Version)
// 설명: 
//   - 2048-bit(256채널) 픽셀을 128-bit(16채널)로 잘라서(Folding) 내보냅니다.
//   - 💡 [AXI 규약 수술 완료] ready_out을 조합 회로로 변경하여 마지막 조각을 
//     보내는 순간 앞단의 픽셀을 동시에 받아오는 진정한 Zero-Bubble을 구현했습니다.
//   - 💡 [좌표계 생성 수술] 여기서 px, py 좌표를 직접 계산하여 데이터와 함께 
//     흘려보냄으로써, 다운스트림(윈도우 생성기)에서의 좌표 엇갈림을 원천 차단합니다.
// =================================================================================

module channel_folder_5x5 #(
    parameter DATA_WIDTH = 8,   
    parameter MAX_CH     = 256, 
    parameter FOLD_CH    = 16   
)(
    input wire clk, rst_n,      
    
    input wire [9:0]  total_ch_in, 
    input wire [10:0] img_width,   
    
    input wire [DATA_WIDTH*MAX_CH-1:0] pixel_in, 
    input wire valid_in,                         
    output wire ready_out,                       
    
    input wire ready_in,                                  
    output reg [DATA_WIDTH*FOLD_CH-1:0] folded_pixel_out, 
    output reg valid_out,                                 
    output reg last_fold_out,                             
    
    output reg [10:0] px_out, 
    output reg [10:0] py_out  
);

    reg [DATA_WIDTH*MAX_CH-1:0] pixel_reg; 
    reg [4:0] fold_idx;                    
    reg busy;                              
    
    reg [10:0] current_px, current_py;

    wire [4:0] max_folds = total_ch_in / FOLD_CH; 

    // Zero-Bubble을 위한 조합 회로
    assign ready_out = (!busy) || (busy && (fold_idx == max_folds - 1) && ready_in);

    always @(posedge clk) begin
        if (!rst_n) begin
            pixel_reg <= 0; fold_idx <= 0; busy <= 0;
            folded_pixel_out <= 0; valid_out <= 0; last_fold_out <= 0;
            current_px <= 0; current_py <= 0;
            px_out <= 0; py_out <= 0;
        end 
        else if (ready_in) begin // Stall 방어
            
            if (!busy) begin
                if (valid_in) begin
                    // 💡 [핵심 수술 1] 픽셀을 받을 때 좌표를 절대 증가시키지 않음!
                    // 현재 current_px는 방금 받은 이 픽셀의 정확한 좌표를 담고 있습니다.
                    pixel_reg <= pixel_in;
                    busy <= 1;
                    fold_idx <= 0;
                end else begin
                    valid_out <= 0; last_fold_out <= 0;
                end
            end 
            
            else begin
                // 현재 픽셀 조각 방출
                folded_pixel_out <= pixel_reg[(fold_idx * DATA_WIDTH * FOLD_CH) +: (DATA_WIDTH * FOLD_CH)];
                valid_out <= 1;
                
                // 💡 현재 썰고 있는 픽셀의 올바른 좌표를 밖으로 내보냄
                px_out <= current_px;
                py_out <= current_py;
                
                if (fold_idx == max_folds - 1) begin
                    last_fold_out <= 1;
                    
                    // 💡 [핵심 수술 2] 16번의 썰기가 완전히 끝났으므로, 
                    // 다음 픽셀을 수용하기 위해 비로소 좌표를 1 증가시킵니다!
                    if (current_px == img_width - 1) begin
                        current_px <= 0;
                        current_py <= current_py + 1;
                    end else begin
                        current_px <= current_px + 1;
                    end
                    
                    if (valid_in) begin
                        pixel_reg <= pixel_in; 
                        fold_idx <= 0;         
                    end else begin
                        busy <= 0;
                    end
                end 
                else begin
                    last_fold_out <= 0;
                    fold_idx <= fold_idx + 1;
                end
            end
        end
    end
endmodule