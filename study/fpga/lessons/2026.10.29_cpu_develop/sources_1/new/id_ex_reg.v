module id_ex_reg (
    input  logic        clk,
    input  logic        reset,
    input  logic        en,
    input  logic        flush,

    input  logic        valid_in,
    input  logic [31:0] rs1_data_in,
    input  logic [31:0] imm_in,
    input  logic [4:0]  rd_addr_in,
    input  logic        reg_write_in,

    output logic        valid_out,
    output logic [31:0] rs1_data_out,
    output logic [31:0] imm_out,
    output logic [4:0]  rd_addr_out,
    output logic        reg_write_out
);

    always_ff @(posedge clk) begin
        if (!reset) begin
            valid_out     <= 1'b0;
            rs1_data_out  <= 32'd0;
            imm_out       <= 32'd0;
            rd_addr_out   <= 5'd0;
            reg_write_out <= 1'b0;
        end else if (flush) begin
            valid_out     <= 1'b0;
            rs1_data_out  <= 32'd0;
            imm_out       <= 32'd0;
            rd_addr_out   <= 5'd0;
            reg_write_out <= 1'b0;
        end else if (en) begin
            valid_out     <= valid_in;
            rs1_data_out  <= rs1_data_in;
            imm_out       <= imm_in;
            rd_addr_out   <= rd_addr_in;
            reg_write_out <= reg_write_in;
        end
    end

endmodule