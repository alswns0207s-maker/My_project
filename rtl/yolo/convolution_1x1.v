`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: convolution_1x1
// Description: 
//   - 커널 크기 1x1 고정, 오직 채널(Channel) 방향으로만 폴딩(Folding) 연산을 수행
//   - 3x3 모듈에서 9개 픽셀에 대한 공간 합산(Spatial Sum) Stage를 완전히 제거 (다이어트)
//   - 3-Stage Pipeline 구조 (Multiply -> Channel Sum -> Accumulate)
//   - [병렬도] 매 클럭마다 16개의 곱셈기(DSP)만 깔끔하게 사용함
//////////////////////////////////////////////////////////////////////////////////

module convolution_1x1 #(
    parameter DATA_WIDTH = 8,   // 양자화된 입력 및 가중치 비트 수 (INT8)
    parameter BIAS_WIDTH = 16,  // 양자화된 편향 비트 수 (INT16)
    parameter ACC_WIDTH = 32,   // 누적기(Accumulator) 비트 수 (오버플로우 방지용)
    parameter FOLD_CH = 16      // 한 클럭에 동시 연산할 입력 채널 수 (병렬도)
)(
    input wire clk,
    input wire rst_n,
    
    // [Control Signals]
    input wire valid_in,
    input wire last_fold_in,    // 1: 현재 픽셀 위치에서의 마지막 채널 묶음 연산임
    input wire ready_in,        // 다운스트림 모듈의 Stall 제어 신호
    
    // [Data Signals]
    // 3x3과 달리 9를 곱하지 않음! 1개 픽셀 * 16채널 * 8비트 = 128 bits
    input wire [(DATA_WIDTH * FOLD_CH)-1:0] pixel_in,
    input wire [(DATA_WIDTH * FOLD_CH)-1:0] weight_in,
    input wire signed [BIAS_WIDTH-1:0] bias_in, // 마지막 폴딩 사이클에서만 더해질 편향
    
    // [Output Signals]
    output reg valid_out,
    output reg signed [ACC_WIDTH-1:0] pixel_out // 32-bit 최종 누적값
);
    integer c; // 채널 루프 인덱스 변수

    // =========================================================================
    // [Data Unpacking] (조합 회로 - 클럭과 무관하게 즉시 매핑됨)
    // =========================================================================
    // 9개의 픽셀 배열이 사라지고, 단일 픽셀의 16채널 1차원 배열로 최적화됨
    wire signed [DATA_WIDTH-1:0] act_unpacked [0:FOLD_CH-1];
    wire signed [DATA_WIDTH-1:0] wgt_unpacked [0:FOLD_CH-1];

    genvar j;
    generate
        for (j = 0; j < FOLD_CH; j = j + 1) begin : CH_UNPACK
            localparam offset = j * DATA_WIDTH;
            assign act_unpacked[j] = $signed(pixel_in[offset +: DATA_WIDTH]);
            assign wgt_unpacked[j] = $signed(weight_in[offset +: DATA_WIDTH]);
        end
    endgenerate

    // =========================================================================
    // [Pipeline Stage 1] 곱셈 (Multiplication)
    // =========================================================================
    // 곱셈기 개수가 144개 -> 16개로 극적으로 줄어듦!
    (* use_dsp = "yes" *) reg signed [2*DATA_WIDTH-1:0] mult_reg [0:FOLD_CH-1]; 
    
    reg valid_s1, last_fold_s1;
    reg signed [BIAS_WIDTH-1:0] bias_s1;

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_s1 <= 0;
            last_fold_s1 <= 0;
            bias_s1 <= 0;
            for (c = 0; c < FOLD_CH; c = c + 1) begin
                mult_reg[c] <= 0;
            end
        end
        else if (ready_in) begin
            valid_s1 <= valid_in;
            last_fold_s1 <= last_fold_in;
            bias_s1 <= bias_in;
            
            if (valid_in) begin
                for (c = 0; c < FOLD_CH; c = c + 1) begin
                    mult_reg[c] <= act_unpacked[c] * wgt_unpacked[c];
                end
            end
        end
    end

    // =========================================================================
    // [Pipeline Stage 2] 채널 합산 (Channel Sum)
    // =========================================================================
    // 9개의 채널합이 아닌, 오직 1개의 채널합(20-bit)만 산출됨
    reg signed [2*DATA_WIDTH+4-1:0] ch_sum_reg; 
    
    reg valid_s2, last_fold_s2;
    reg signed [BIAS_WIDTH-1:0] bias_s2;
    reg signed [2*DATA_WIDTH+4-1:0] temp_ch_sum; 

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_s2 <= 0;
            last_fold_s2 <= 0; 
            bias_s2 <= 0;
            ch_sum_reg <= 0;
        end 
        else if (ready_in) begin
            valid_s2 <= valid_s1;
            last_fold_s2 <= last_fold_s1;
            bias_s2 <= bias_s1;
            
            if (valid_s1) begin
                temp_ch_sum = 0;
                for (c = 0; c < FOLD_CH; c = c + 1) begin
                    temp_ch_sum = temp_ch_sum + mult_reg[c];
                end
                ch_sum_reg <= temp_ch_sum;
            end
        end
    end

    // =========================================================================
    // [Pipeline Stage 3 제거] 공간 합산(Spatial Sum) 과정 생략
    // 1x1 Conv이므로 Stage 2의 ch_sum_reg가 곧바로 누적기로 들어갑니다.
    // =========================================================================

    // =========================================================================
    // [Pipeline Stage 3] 누적 및 출력 (Accumulate & Output) 
    // =========================================================================
    reg signed [ACC_WIDTH-1:0] accumulator; // 32-bit 내부 누적기

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_out <= 0;
            pixel_out <= 0;
            accumulator <= 0;
        end 
        else if (ready_in) begin
            if (valid_s2) begin
                if (last_fold_s2) begin
                    // 마지막 폴딩 사이클: 누적값 + 현재값 + 편향(Bias) 더해서 최종 출력
                    pixel_out <= accumulator + ch_sum_reg + bias_s2;
                    valid_out <= 1;  
                    accumulator <= 0; // 누적기 초기화
                end 
                else begin
                    // 중간 폴딩 사이클: 편향 없이 누적만 수행
                    accumulator <= accumulator + ch_sum_reg;
                    valid_out <= 0;  
                end
            end 
            else begin
                valid_out <= 0;
            end
        end
    end

endmodule