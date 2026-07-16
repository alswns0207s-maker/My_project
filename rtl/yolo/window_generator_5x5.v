`timescale 1ns / 1ps

// =================================================================================
// 모듈명: window_generator_5x5
// 설명: 
//   - 5줄의 데이터를 받아 5x5(25픽셀)의 거대한 윈도우 조각을 조립합니다.
//   - 💡 [패딩 수술 완료] 합성곱용 0이 아닌, Maxpool 전용 최솟값인 -128 (8'h80)을 패딩.
//   - 💡 [좌표 수술 완료] 자체 타이머로 추측하던 좌표를 버리고, 앞단에서 흘러온
//     px_in, py_in을 사용하여 100% 오차 없는 절대 좌표 제로(최소) 패딩을 수행합니다.
// =================================================================================

module window_generator_5x5 #(
    parameter DATA_WIDTH = 8,
    parameter FOLD_CH    = 16,  
    parameter MAX_WIDTH  = 20,  
    parameter MAX_CH     = 256  
)(
    input wire clk, rst_n,
    
    input wire [10:0] img_width, img_height,
    input wire [9:0]  total_ch_in, 
    
    input wire [DATA_WIDTH*FOLD_CH-1:0] row0_in, row1_in, row2_in, row3_in, row4_in,
    input wire valid_in, last_fold_in,
    input wire [10:0] px_in, py_in,
    
    input wire ready_in,   
    output wire ready_out, 
    
    output reg [DATA_WIDTH*FOLD_CH*25-1:0] window_out,
    output reg valid_out, last_fold_out
);

    assign ready_out = ready_in;
    wire [DATA_WIDTH*FOLD_CH-1:0] PAD_VAL = {FOLD_CH{8'h80}}; 

    reg [DATA_WIDTH*FOLD_CH-1:0] delay_lines [0:4][0:3][0:15];
    wire [4:0] current_folds = total_ch_in / FOLD_CH; 

    integer r, t, d;

    always @(posedge clk) begin
        if (!rst_n) begin
            for (r=0; r<5; r=r+1)
                for (t=0; t<4; t=t+1)
                    for (d=0; d<16; d=d+1)
                        delay_lines[r][t][d] <= 0;
        end 
        else if (ready_in && valid_in) begin 
            for (r=0; r<5; r=r+1) begin
                delay_lines[r][3][0] <= (r==0)? row0_in : (r==1)? row1_in : 
                                        (r==2)? row2_in : (r==3)? row3_in : row4_in;
                for (d=1; d<16; d=d+1) delay_lines[r][3][d] <= delay_lines[r][3][d-1];
                
                delay_lines[r][2][0] <= delay_lines[r][3][current_folds - 1];
                for (d=1; d<16; d=d+1) delay_lines[r][2][d] <= delay_lines[r][2][d-1];
                
                delay_lines[r][1][0] <= delay_lines[r][2][current_folds - 1];
                for (d=1; d<16; d=d+1) delay_lines[r][1][d] <= delay_lines[r][1][d-1];
                
                delay_lines[r][0][0] <= delay_lines[r][1][current_folds - 1];
                for (d=1; d<16; d=d+1) delay_lines[r][0][d] <= delay_lines[r][0][d-1];
            end
        end
    end

    wire [DATA_WIDTH*FOLD_CH-1:0] next_taps [0:4][0:4];
    genvar gr;
    generate
        for (gr=0; gr<5; gr=gr+1) begin : tap_assign
            assign next_taps[gr][4] = (gr==0)? row0_in : (gr==1)? row1_in : 
                                      (gr==2)? row2_in : (gr==3)? row3_in : row4_in;
            assign next_taps[gr][3] = delay_lines[gr][3][current_folds - 1];
            assign next_taps[gr][2] = delay_lines[gr][2][current_folds - 1];
            assign next_taps[gr][1] = delay_lines[gr][1][current_folds - 1];
            assign next_taps[gr][0] = delay_lines[gr][0][current_folds - 1];
        end
    endgenerate

    integer rr, cc, abs_x, abs_y;

    always @(posedge clk) begin
        if (!rst_n) begin
            window_out <= 0; valid_out <= 0; last_fold_out <= 0;
        end 
        else if (ready_in) begin 
            valid_out <= valid_in;
            last_fold_out <= last_fold_in;
            
            if (valid_in) begin
                for (rr=0; rr<5; rr=rr+1) begin
                    for (cc=0; cc<5; cc=cc+1) begin
                        abs_x = $signed({1'b0, px_in}) - 4 + cc;
                        abs_y = $signed({1'b0, py_in}) - 4 + rr;
                        
                        if (abs_x >= 0 && abs_x < img_width && abs_y >= 0 && abs_y < img_height) begin
                            window_out[((rr*5 + cc)*DATA_WIDTH*FOLD_CH) +: (DATA_WIDTH*FOLD_CH)] <= next_taps[rr][cc];
                        end else begin
                            window_out[((rr*5 + cc)*DATA_WIDTH*FOLD_CH) +: (DATA_WIDTH*FOLD_CH)] <= PAD_VAL;
                        end
                    end
                end
            end else begin
                valid_out <= 0;
            end
        end
    end
endmodule