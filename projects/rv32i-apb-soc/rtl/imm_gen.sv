module imm_gen (
    input  logic [31:0] instr_code,
    output logic [31:0] imm
);
    always_comb begin
        case (instr_code[6:0])
            7'b000_0011,
            7'b001_0011,
            7'b110_0111:
                imm = {{20{instr_code[31]}}, instr_code[31:20]};
            7'b010_0011:
                imm = {{20{instr_code[31]}}, instr_code[31:25], instr_code[11:7]};
            7'b110_0011:
                imm = {{19{instr_code[31]}}, instr_code[31], instr_code[7],
                       instr_code[30:25], instr_code[11:8], 1'b0};
            7'b011_0111,
            7'b001_0111:
                imm = {instr_code[31:12], 12'd0};
            7'b110_1111:
                imm = {{11{instr_code[31]}}, instr_code[31], instr_code[19:12],
                       instr_code[20], instr_code[30:21], 1'b0};
            default: imm = 32'd0;
        endcase
    end
endmodule
