module id_ex_reg (
    input logic clk, reset, en, flush,
    input logic valid_in,
    input logic [4:0] rs1_addr_in,
    input logic [31:0] rs1_data_in, imm_in,
    input logic [4:0] rd_addr_in,
    input logic reg_write_in,

    output logic [4:0] rs1_addr_out,
    output logic valid_out,
    output logic [31:0] rs1_data_out, imm_out,
    output logic [4:0] rd_addr_out,
    output logic reg_write_out
);
    always_ff @(posedge clk) begin
        if (!reset) begin
            valid_out <= 0;
            rs1_data_out <= 0;
            imm_out <= 0;
            rd_addr_out <= 0;
            reg_write_out <= 0;
            rs1_addr_out <= 5'd0;
        end else if (flush) begin
            valid_out <= 0;
            rs1_data_out <= 0;
            imm_out <= 0;
            rd_addr_out <= 0;
            reg_write_out <= 0;
            rs1_addr_out <= 5'd0
        end else if (en) begin
            valid_out <= valid_in;
            rs1_data_out <= rs1_data_in;
            imm_out <= imm_in;
            rd_addr_out <= rd_addr_in;
            reg_write_out <= reg_write_in;
            rs1_addr_out <= rs1_addr_in;
        end
    end
endmodule