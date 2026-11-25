`timescale 1ns / 1ps
module ex_mem_reg (
    input  logic        clk,
    input  logic        reset,
    input  logic        en,
    input  logic        flush,

    input  logic        valid_in,
    input  logic [31:0] alu_result_in,
    input  logic [4:0]  rd_addr_in,
    input  logic        reg_write_in,

    output logic        valid_out,
    output logic [31:0] alu_result_out,
    output logic [4:0]  rd_addr_out,
    output logic        reg_write_out
);

    always_ff @(posedge clk) begin
        if (!reset) begin
            valid_out      <= 1'b0;
            alu_result_out <= 32'd0;
            rd_addr_out    <= 5'd0;
            reg_write_out  <= 1'b0;
        end else if (flush) begin
            valid_out      <= 1'b0;
            alu_result_out <= 32'd0;
            rd_addr_out    <= 5'd0;
            reg_write_out  <= 1'b0;
        end else if (en) begin
            valid_out      <= valid_in;
            alu_result_out <= alu_result_in;
            rd_addr_out    <= rd_addr_in;
            reg_write_out  <= reg_write_in;
        end
    end

endmodule
