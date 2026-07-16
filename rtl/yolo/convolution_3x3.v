`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: convolution_3x3
// Description: 
//   - 커널 크기 3x3 고정, 채널(Channel) 방향으로만 폴딩(Folding) 연산을 수행하는 범용 모듈.
//   - 가중치 및 편향과 전체 ch수는 top 모듈에서 설정됨
//   - 4-Stage Pipeline 구조 적용 (Multiply -> Channel Sum -> Spatial Sum -> Accumulate)
//   - 병목 없이 매 클럭마다 144개의 MAC 연산을 수행함.
//   - channel folder로부터 3x3x16 의 픽셀 스트림이 입력됨. 6x6 window generator는 6x6x3,
//      남은 36바이트는 0으로 처리하여 입력 크기 맞춰서 layer0에서도 범용 사용!
//   - [추가] ready_in 신호를 통한 파이프라인 Backpressure (Stall/Freeze) 지원
//////////////////////////////////////////////////////////////////////////////////

module convolution_3x3 #(
    parameter DATA_WIDTH = 8,   // 양자화된 픽셀 및 가중치 비트 수 (INT8)
    parameter BIAS_WIDTH = 16,  // 양자화된 편향 비트 수 (INT16)
    parameter ACC_WIDTH = 32,   // 오버플로우 방지용 누적기 비트 수 (INT32)
    parameter FOLD_CH = 16      // 1클럭당 동시 연산 채널 수 (병렬도)
)(
    input wire clk,
    input wire rst_n,
    
    // [입력 데이터 버스]
    // 픽셀은 Window Gen에서 [Pixel0_16ch, Pixel1_16ch...] 순서로 들어옵니다.
    input wire [DATA_WIDTH*FOLD_CH*9-1:0] pixel_in,
    
    // 가중치는 Python .mem 파일에서 [Ch0_9px, Ch1_9px...] 순서로 들어옵니다.
    input wire [DATA_WIDTH*FOLD_CH*9-1:0] weight_in,
    
    // 💡 [핵심 버그 수정 1] Bias 포트를 signed로 명시하여 부호 확장을 보장합니다.
    input wire signed [BIAS_WIDTH-1:0] bias_in,
    
    // [흐름 제어 제어 포트]
    input wire valid_in,        // 입력 데이터 유효
    input wire last_fold_in,    // 현재 입력이 채널 누적의 마지막 조각임을 알림
    input wire ready_in,        // 외부 Stall 제어 신호
    
    // [최종 연산 결과 포트]
    output reg [ACC_WIDTH-1:0] pixel_out, // 32-bit 부호 있는 Psum 결과
    output reg valid_out                  // 연산 완료 플래그
);

    // =========================================================================
    // [제어 신호 지연(Pipeline) 레지스터]
    // =========================================================================
    reg valid_s1, valid_s2, valid_s3;
    reg last_fold_s1, last_fold_s2, last_fold_s3;
    
    // 💡 [핵심 버그 수정 2] 파이프라인 지연 편향 레지스터에도 signed 선언!
    reg signed [BIAS_WIDTH-1:0] bias_s1, bias_s2, bias_s3;

    // =========================================================================
    // [Pipeline Stage 1] 8-bit * 8-bit 곱셈기 (Multiply)
    // =========================================================================
    // 16비트 부호 있는 결과를 저장할 9x16 2차원 레지스터 배열
    
    (* use_dsp = "yes" *) reg signed [15:0] mult_reg [0:8][0:FOLD_CH-1];
    integer p, c; // 루프 변수

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_s1 <= 0;
            last_fold_s1 <= 0;
            bias_s1 <= 0;
            for (p = 0; p < 9; p = p + 1) begin
                for (c = 0; c < FOLD_CH; c = c + 1) begin
                    mult_reg[p][c] <= 0;
                end
            end
        end 
        else if (ready_in) begin // Stall이 아닐 때만 전진
            valid_s1 <= valid_in;
            last_fold_s1 <= last_fold_in;
            bias_s1 <= bias_in; // 음수 유지를 위해 signed 레지스터에 래치
            
            if (valid_in) begin
                for (p = 0; p < 9; p = p + 1) begin
                    for (c = 0; c < FOLD_CH; c = c + 1) begin
                        // 💡 [핵심 버그 수정 3: 텐서 평탄화(Flatten) 정렬]
                        // 픽셀 인덱스: (p * 16 + c) -> [픽셀우선] 윈도우 생성기의 조립 방향
                        // 가중치 인덱스: (c * 9 + p) -> [채널우선] 파이썬 Numpy의 조립 방향
                        // 각 버스 구조의 특성에 맞춰 인덱스를 교차 참조함으로써 완벽한 매칭을 이뤄냅니다!
                        mult_reg[p][c] <= 
                            $signed(pixel_in[(p * FOLD_CH + c) * DATA_WIDTH +: DATA_WIDTH]) * $signed(weight_in[(c * 9 + p) * DATA_WIDTH +: DATA_WIDTH]);
                    end
                end
            end
        end
    end

    // =========================================================================
    // [Pipeline Stage 2] 채널 방향 덧셈 (Channel Sum)
    // =========================================================================
    // 16개 채널의 곱셈 결과를 더하므로 오버플로우를 막기 위해 20-bit로 확장
    reg signed [19:0] ch_sum_reg [0:8];
    integer temp_ch_sum; 

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_s2 <= 0;
            last_fold_s2 <= 0;
            bias_s2 <= 0;
            for (p = 0; p < 9; p = p + 1) begin
                ch_sum_reg[p] <= 0;
            end
        end 
        else if (ready_in) begin
            valid_s2 <= valid_s1;
            last_fold_s2 <= last_fold_s1;
            bias_s2 <= bias_s1;
            
            if (valid_s1) begin
                for (p = 0; p < 9; p = p + 1) begin
                    temp_ch_sum = 0;
                    for (c = 0; c < FOLD_CH; c = c + 1) begin
                        temp_ch_sum = temp_ch_sum + mult_reg[p][c];
                    end
                    ch_sum_reg[p] <= temp_ch_sum; // 1개 픽셀 위치의 16채널 합산 완료
                end
            end
        end
    end

    // =========================================================================
    // [Pipeline Stage 3] 공간 방향 덧셈 (Spatial Sum)
    // =========================================================================
    // 9개 위치의 채널 합산 결과를 모두 더하므로 24-bit로 확장
    reg signed [23:0] spatial_sum_reg;
    integer temp_spatial_sum;

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_s3 <= 0;
            last_fold_s3 <= 0;
            bias_s3 <= 0;
            spatial_sum_reg <= 0;
        end 
        else if (ready_in) begin
            valid_s3 <= valid_s2;
            last_fold_s3 <= last_fold_s2;
            bias_s3 <= bias_s2;
            
            if (valid_s2) begin
                temp_spatial_sum = 0;
                for (p = 0; p < 9; p = p + 1) begin
                    temp_spatial_sum = temp_spatial_sum + ch_sum_reg[p];
                end
                spatial_sum_reg <= temp_spatial_sum; // 3x3 윈도우 1장(16채널 분량)의 합산 완료
            end
        end
    end

    // =========================================================================
    // [Pipeline Stage 4] 누적 및 편향 더하기 (Accumulate & Output)
    // =========================================================================
    reg signed [ACC_WIDTH-1:0] accumulator; // 32-bit Psum 누적기

    always @(posedge clk) begin
        if (!rst_n) begin
            valid_out <= 0;
            pixel_out <= 0;
            accumulator <= 0;
        end 
        else if (ready_in) begin
            if (valid_s3) begin
                if (last_fold_s3) begin
                    // 💡 [핵심 버그 수정 4]
                    // bias_s3가 앞서 signed로 안전하게 선언되었으므로, 
                    // 음수가 들어와도 32-bit 덧셈 시 앞자리가 1로 꽉 채워집니다 (Perfect Sign Extension).
                    pixel_out <= accumulator + spatial_sum_reg + bias_s3;
                    valid_out <= 1;  
                    accumulator <= 0; // 누적기 초기화 (다음 연산을 위해)
                end 
                else begin
                    // 마지막 폴딩이 아니면 결과를 내보내지 않고 계속 누적합니다.
                    accumulator <= accumulator + spatial_sum_reg;
                    valid_out <= 0;
                end
            end 
            else begin
                valid_out <= 0; // 데이터가 무효하면 출력 플래그도 내림
            end
        end
    end

endmodule