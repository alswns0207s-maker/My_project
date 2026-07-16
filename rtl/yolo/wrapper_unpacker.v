`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: wrapper_unpacker
// Description: 
//   - Unpacker와 Coordinate Generator를 하나로 감싸는 최상위 배전반.
//   - 💡 [인터페이스 확장] FSM으로부터 i_start와 target_pixel을 받아 하위로 넘겨줍니다.
//////////////////////////////////////////////////////////////////////////////////

module wrapper_unpacker #(
    parameter IN_WIDTH  = 2048,
    parameter OUT_WIDTH = 128
)(
    input  wire                 clk,
    input  wire                 rst_n,
    
    // [Dynamic Parameters from Top FSM]
    input  wire                 i_start,      // 레이어 시작 트리거
    input  wire [9:0]           total_ch_in,  // 활성 채널 수
    input  wire [10:0]          img_width,    // 이미지 폭
    input  wire [19:0]          target_pixel, // 💡 이번 레이어 총 픽셀 수 (더미 판독용)
    
    // [Input] GFB Read Controller 
    input  wire [IN_WIDTH-1:0]  data_in,
    input  wire                 valid_in,
    output wire                 ready_out,
    
    // [Output] 하위 Conv Module
    output wire [OUT_WIDTH-1:0] data_out,
    output wire                 valid_out,
    output wire                 last_fold_out,
    output wire [10:0]          px_out,
    output wire [10:0]          py_out,
    input  wire                 ready_in
);

    wire [OUT_WIDTH-1:0] w_unpack_data;
    wire                 w_unpack_valid;
    wire                 w_unpack_ready;

    stream_unpacker #(
        .IN_WIDTH(IN_WIDTH), .OUT_WIDTH(OUT_WIDTH)
    ) u_unpacker (
        .clk        (clk),
        .rst_n      (rst_n),
        .data_in    (data_in),      
        .valid_in   (valid_in),     
        .ready_out  (ready_out),    
        .data_out   (w_unpack_data),
        .valid_out  (w_unpack_valid),
        .ready_in   (w_unpack_ready)
    );

    coord_generator #(
        .DATA_WIDTH(OUT_WIDTH)
    ) u_coord_gen (
        .clk          (clk),
        .rst_n        (rst_n),
        .i_start      (i_start),      // 💡 결선 완료
        .total_ch_in  (total_ch_in),
        .img_width    (img_width),
        .target_pixel (target_pixel), // 💡 결선 완료
        
        .data_in      (w_unpack_data), 
        .valid_in     (w_unpack_valid),
        .ready_out    (w_unpack_ready),
        
        .data_out     (data_out),      
        .valid_out    (valid_out),
        .last_fold_out(last_fold_out),
        .px_out       (px_out),
        .py_out       (py_out),
        .ready_in     (ready_in)       
    );

endmodule