`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: maxpool_block_5x5 (Pre-Folded Architecture - Fully Parameterized)
//
// Description: 
//   - YOLOv5n의 SPPF(Spatial Pyramid Pooling Fast) 레이어를 위한 5x5 Max Pooling 래퍼 모듈입니다.
//   - [Data Flow (데이터 흐름)]
//     1. 입력 수신: Top 모듈에 있는 '공용 픽셀 채널 폴더(Shared Pixel Folder)'가 2048-bit의 
//        거대 특징맵을 128-bit(16채널 조각) 단위로 썰어서(Folding) 본 모듈의 'folded_pixel_in'으로 주입합니다.
//     2. 라인 버퍼링 (Line Buffer): 1D 평탄화 버퍼가 128-bit 데이터를 받아 5줄(Row)의 과거 데이터를 기억합니다.
//     3. 윈도우 생성 (Window Generator): 5줄의 데이터를 받아 시프트 연산을 통해 5x5 크기(25개 픽셀)의 
//        연산용 윈도우 덩어리(3200-bit)로 조립합니다.
//     4. 파이프라인 지연 (Pipeline Register): 타이밍 마진을 확보하기 위해 1클럭 지연시킵니다.
//     5. 최댓값 추출 (Max Array): 16개의 비교기 트리가 16개 채널에 대해 동시에 5x5 영역의 최댓값을 찾아 출력합니다.
//
//   - [모듈의 핵심 기능]
//     - BRAM 자원을 낭비하는 내부 폴더를 삭제하고 외부 공용 폴더의 출력을 직접 받아 경량화(DSP Zero, BRAM 8개) 달성.
//     - 해상도(IMG_WIDTH, IMG_HEIGHT)를 파라미터화하여 SPPF뿐만 아니라 어떤 크기의 특징맵에도 재사용 가능.
//     - ready_in 신호를 통한 완벽한 파이프라인 정지(Freeze/Stall) 기능 내장.
//////////////////////////////////////////////////////////////////////////////////

module maxpool_block_5x5 #(
    parameter DATA_WIDTH = 8,
    parameter MAX_CH     = 256,
    parameter MAX_WIDTH  = 20,
    parameter FOLD_CH    = 16
)(
    input wire clk, rst_n,

    input wire [10:0] img_width, img_height,
    input wire [9:0]  total_ch_in,

    input wire [DATA_WIDTH*MAX_CH-1:0] pixel_in,
    input wire valid_in,
    output wire ready_out, 

    input wire ready_in,   
    output wire [DATA_WIDTH*FOLD_CH-1:0] max_out,
    output wire valid_out,
    output wire last_fold_out
);

    // =========================================================================
    // [1] Channel Folder 인스턴스화
    // =========================================================================
    wire [DATA_WIDTH*FOLD_CH-1:0] cf_folded_pixel;
    wire cf_valid, cf_last_fold, lb_ready_out;
    wire [10:0] cf_px, cf_py; 

    channel_folder_5x5 #(
        .DATA_WIDTH(DATA_WIDTH), .MAX_CH(MAX_CH), .FOLD_CH(FOLD_CH)
    ) u_folder (
        .clk(clk), .rst_n(rst_n),
        .total_ch_in(total_ch_in), .img_width(img_width),
        .pixel_in(pixel_in), .valid_in(valid_in), .ready_out(ready_out),
        .ready_in(lb_ready_out), 
        .folded_pixel_out(cf_folded_pixel), .valid_out(cf_valid), .last_fold_out(cf_last_fold),
        .px_out(cf_px), .py_out(cf_py) 
    );

    // =========================================================================
    // [2] Line Buffer 인스턴스화
    // =========================================================================
    wire [DATA_WIDTH*FOLD_CH-1:0] lb_row0, lb_row1, lb_row2, lb_row3, lb_row4;
    wire lb_valid, lb_last_fold, wg_ready_out;
    wire [10:0] lb_px, lb_py;

    line_buffer_5x5 #(
        .DATA_WIDTH(DATA_WIDTH), .FOLD_CH(FOLD_CH), .MAX_WIDTH(MAX_WIDTH), .MAX_CH(MAX_CH)
    ) u_line_buf (
        .clk(clk), .rst_n(rst_n),
        .img_width(img_width), .total_ch_in(total_ch_in),
        .pixel_in(cf_folded_pixel), .valid_in(cf_valid), .last_fold_in(cf_last_fold),
        .px_in(cf_px), .py_in(cf_py), 
        .ready_in(wg_ready_out), .ready_out(lb_ready_out),
        .row0_out(lb_row0), .row1_out(lb_row1), .row2_out(lb_row2), 
        .row3_out(lb_row3), .row4_out(lb_row4),
        .valid_out(lb_valid), .last_fold_out(lb_last_fold),
        .px_out(lb_px), .py_out(lb_py)
    );

    // =========================================================================
    // [3] Window Generator 인스턴스화
    // =========================================================================
    wire [DATA_WIDTH*FOLD_CH*25-1:0] wg_window;
    wire wg_valid, wg_last_fold;
    wire pipeline_ready_in = ready_in;

    window_generator_5x5 #(
        .DATA_WIDTH(DATA_WIDTH), .FOLD_CH(FOLD_CH), .MAX_WIDTH(MAX_WIDTH), .MAX_CH(MAX_CH)
    ) u_win_gen (
        .clk(clk), .rst_n(rst_n),
        .img_width(img_width), .img_height(img_height),
        .total_ch_in(total_ch_in), // 💡 [동적 채널 연동]
        .row0_in(lb_row0), .row1_in(lb_row1), .row2_in(lb_row2), 
        .row3_in(lb_row3), .row4_in(lb_row4),
        .valid_in(lb_valid), .last_fold_in(lb_last_fold),
        .px_in(lb_px), .py_in(lb_py), 
        .ready_in(pipeline_ready_in), .ready_out(wg_ready_out),
        .window_out(wg_window), .valid_out(wg_valid), .last_fold_out(wg_last_fold)
    );

    // =========================================================================
    // [4] 파이프라인 마진 레지스터 (1-Clock Delay)
    // =========================================================================
    reg [DATA_WIDTH*FOLD_CH*25-1:0] delayed_window;
    reg delayed_valid, delayed_last_fold;

    always @(posedge clk) begin
        if (!rst_n) begin
            delayed_window <= 0; delayed_valid <= 0; delayed_last_fold <= 0;
        end 
        else if (ready_in) begin 
            delayed_window    <= wg_window;
            delayed_valid     <= wg_valid;
            delayed_last_fold <= wg_last_fold;
        end
    end

    // =========================================================================
    // [5] Maxpool 5x5 Array 인스턴스화
    // =========================================================================
    maxpool_5x5_array #(
        .DATA_WIDTH(DATA_WIDTH), .FOLD_CH(FOLD_CH)
    ) u_max_array (
        .clk(clk), .rst_n(rst_n),
        .window_in(delayed_window), .valid_in(delayed_valid), .last_fold_in(delayed_last_fold),
        .ready_in(ready_in), 
        .pixel_out(max_out), .valid_out(valid_out), .last_fold_out(last_fold_out)
    );

endmodule