`timescale 1ns / 1ps

// =================================================================================
// 모듈명: concat_block (Lightweight)
// 설명: 
//   - 불필요한 px, py 라우팅 로직을 제거하여 리소스를 최적화했습니다.
//   - A 스트림과 B 스트림을 16채널(128-bit) 단위로 이어 붙이는 MUX 역할만 집중합니다.
// =================================================================================

module concat_block #(
    parameter DATA_WIDTH = 128
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // [Dynamic Parameters]
    input  wire [9:0]            ch_a,          
    input  wire [9:0]            ch_b,          

    // [Stream A Input] 
    input  wire [DATA_WIDTH-1:0] data_a,
    input  wire                  valid_a,
    output wire                  ready_a,

    // [Stream B Input] 
    input  wire [DATA_WIDTH-1:0] data_b,
    input  wire                  valid_b,
    output wire                  ready_b,

    // [Output Stream]
    output wire [DATA_WIDTH-1:0] data_out,
    output wire                  valid_out,
    output wire                  last_fold_out,
    input  wire                  ready_in
);

    localparam S_PASS_A = 1'b0; 
    localparam S_PASS_B = 1'b1; 

    reg       state;
    reg [4:0] fold_cnt;

    wire [4:0] max_folds_a = ch_a / 16;
    wire [4:0] max_folds_b = ch_b / 16;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= S_PASS_A;
            fold_cnt <= 0;
        end else begin
            if (state == S_PASS_A) begin
                if (valid_a && ready_in) begin
                    if (fold_cnt == max_folds_a - 1) begin
                        state <= S_PASS_B; 
                        fold_cnt <= 0;
                    end else begin
                        fold_cnt <= fold_cnt + 1;
                    end
                end
            end 
            else begin // S_PASS_B
                if (valid_b && ready_in) begin
                    if (fold_cnt == max_folds_b - 1) begin
                        state <= S_PASS_A; 
                        fold_cnt <= 0;
                    end else begin
                        fold_cnt <= fold_cnt + 1;
                    end
                end
            end
        end
    end

    // [제어 및 출력 조합 논리 회로]
    assign ready_a = (state == S_PASS_A) ? ready_in : 1'b0;
    assign ready_b = (state == S_PASS_B) ? ready_in : 1'b0;

    assign data_out  = (state == S_PASS_A) ? data_a  : data_b;
    assign valid_out = (state == S_PASS_A) ? valid_a : valid_b;

    assign last_fold_out = (state == S_PASS_B) && (fold_cnt == max_folds_b - 1) && valid_b;

endmodule