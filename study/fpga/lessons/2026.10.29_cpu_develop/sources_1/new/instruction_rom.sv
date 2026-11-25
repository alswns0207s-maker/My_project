module instruction_rom (
    input  logic [31:0] instr_addr,
    output logic [31:0] instr_code
);

always_comb begin
    case (instr_addr)
        32'd0: instr_code = 32'h00500093; // addi x1, x0, 5
        32'd4: instr_code = 32'h00208113; // addi x2, x1, 2

        default:
            instr_code = 32'h00000013;   // 이후는 nop
    endcase
end

endmodule