`timescale 1ns / 1ps

// =================================================================================
// 모듈명: upsampling_block (Lightweight / Zero-Bubble)
// 설명: 
//   - 불필요한 px, py 및 i_row_repeat 좌표 추적 로직을 완전히 제거했습니다.
//   - 오직 128-bit 데이터 스트림을 가로(Horizontal) 방향으로 2배 복제하여 
//     딜레이(Bubble) 없이 바로 통과시키는 역할만 수행합니다.
//   - 세로 확장은 FSM이 GFB에서 값을 두 번 반복해서 읽어오는 것으로 해결
// =================================================================================

module upsampling_block #(
    parameter DATA_WIDTH = 128,
    parameter MAX_CH     = 256
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // [Dynamic Parameters]
    input  wire [9:0]            total_ch_in,   

    // [Input Stream] (좌표 포트 삭제)
    input  wire [DATA_WIDTH-1:0] data_in,
    input  wire                  valid_in,
    input  wire                  last_fold_in,
    output wire                  ready_out,

    // [Output Stream] (좌표 포트 삭제)
    output wire [DATA_WIDTH-1:0] data_out,
    output wire                  valid_out,
    output wire                  last_fold_out,
    input  wire                  ready_in
);

    reg [2047:0] pixel_buf; 
    
    localparam S_PASS_LEFT = 1'b0; // 들어오는 즉시 왼쪽 픽셀로 Bypass 및 버퍼 저장
    localparam S_OUT_RIGHT = 1'b1; // 버퍼에서 꺼내어 오른쪽 픽셀로 출력

    reg state;
    reg [4:0] fold_cnt; 
    wire [4:0] max_folds = total_ch_in / 16;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= S_PASS_LEFT;
            fold_cnt <= 0;
            pixel_buf <= 0;
        end else begin
            case (state)
                S_PASS_LEFT: begin
                    // 입력 데이터가 유효하고, 다운스트림도 받을 준비가 되었을 때
                    if (valid_in && ready_in) begin
                        // 데이터를 출력함과 동시에 오른쪽 픽셀 출력을 위해 버퍼에 기록
                        pixel_buf[fold_cnt * DATA_WIDTH +: DATA_WIDTH] <= data_in;

                        // 현재 조각이 픽셀의 마지막 채널 묶음일 경우, 상태 전환
                        if (last_fold_in || (fold_cnt == max_folds - 1)) begin
                            state <= S_OUT_RIGHT; 
                            fold_cnt <= 0;
                        end else begin
                            fold_cnt <= fold_cnt + 1;
                        end
                    end
                end

                S_OUT_RIGHT: begin
                    if (ready_in) begin
                        if (fold_cnt == max_folds - 1) begin
                            state <= S_PASS_LEFT; // 오른쪽 픽셀까지 전송 완료, 초기화
                            fold_cnt <= 0;
                        end else begin
                            fold_cnt <= fold_cnt + 1;
                        end
                    end
                end
            endcase
        end
    end

    // =========================================================================
    // [출력 조합 논리 회로]
    // =========================================================================
    assign data_out = (state == S_PASS_LEFT) ? data_in : pixel_buf[fold_cnt * DATA_WIDTH +: DATA_WIDTH];
    assign valid_out = (state == S_PASS_LEFT) ? valid_in : 1'b1;
    assign last_fold_out = (state == S_PASS_LEFT) ? last_fold_in : (fold_cnt == max_folds - 1);
    assign ready_out = (state == S_PASS_LEFT) ? ready_in : 1'b0;

endmodule