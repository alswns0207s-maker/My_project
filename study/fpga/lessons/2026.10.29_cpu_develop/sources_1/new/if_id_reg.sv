module  if_id_reg (
    input logic clk,
    input logic reset,
    input logic en,
    input logic flush,

    input logic valid_in,
    input logic [31:0] pc_in,
    input logic [31:0] instr_in,
    output logic [31:0] pc_out,
    output logic [31:0] instr_out,
    output logic valid_out
);

    always_ff @(posedge clk) begin
        if (!reset) begin
            valid_out <= 1'b0;
            pc_out    <= 32'd0;
            instr_out <= 32'd0;
        end else if (flush) begin
            valid_out <= 1'b0;
            pc_out    <= 32'd0;
            instr_out <= 32'd0;
        end else if (en) begin
            valid_out <= valid_in;
            pc_out    <= pc_in;
            instr_out <= instr_in;
        end
    end
endmodule