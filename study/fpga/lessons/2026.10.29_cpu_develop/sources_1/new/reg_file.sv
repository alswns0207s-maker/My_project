`timescale 1ns / 1ps

module reg_file (
    input  logic        clk,
    input  logic        reset,

    // WB 단계에서 사용할 쓰기 포트
    input  logic        we,
    input  logic [4:0]  rd_addr,
    input  logic [31:0] rd_data,

    // ID 단계에서 사용할 읽기 포트
    input  logic [4:0]  rs1_addr,
    input  logic [4:0]  rs2_addr,
    output logic [31:0] rs1_data,
    output logic [31:0] rs2_data
);

    logic [31:0] regs [1:31];

    // 쓰기: 클록 상승 에지에서 저장
    always_ff @(posedge clk) begin
        if (!reset) begin
            for (int i = 1; i < 32; i++)
                regs[i] <= 32'd0;
        end else if (we && rd_addr != 5'd0) begin
            regs[rd_addr] <= rd_data;
        end
    end

    // 읽기: 주소가 바뀌면 바로 출력
    assign rs1_data =
        (rs1_addr == 5'd0) ? 32'd0 : regs[rs1_addr];

    assign rs2_data =
        (rs2_addr == 5'd0) ? 32'd0 : regs[rs2_addr];

endmodule