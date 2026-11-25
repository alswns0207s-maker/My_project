`timescale 1ns / 1ps

module imm_extend(
    input logic [31:0] instr,
    output logic [31:0] imm
    );

    assign imm = {{20{instr[31]}}, instr[31:20]};

endmodule
