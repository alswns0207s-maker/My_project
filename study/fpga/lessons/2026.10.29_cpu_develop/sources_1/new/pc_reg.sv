`timescale 1ns / 1ps

module pc_reg(
    input logic clk,
    input logic reset,
    input logic en,
    input logic [31:0] next_pc,
    output logic [31:0] pc
    );

    always_ff@(posedge clk) begin
        if(!reset)
            pc <= 32'b0;
        else if(en)
            pc <= next_pc;
    end
endmodule
