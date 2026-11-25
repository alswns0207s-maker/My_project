module pipeline_cpu (
    input logic clk,
    input logic reset
);

    logic [31:0] pc;
    logic [31:0] instr_code;

    logic        id_valid;
    logic [31:0] id_pc;
    logic [31:0] id_instr;

    pc_reg U_PC (
        .clk     (clk),
        .reset   (reset),
        .en      (1'b1),
        .next_pc (pc + 32'd4),
        .pc      (pc)
    );

    instruction_rom U_ROM (
        .instr_addr (pc),
        .instr_code (instr_code)
    );

    if_id_reg U_IF_ID (
        .clk       (clk),
        .rst_n     (reset),
        .en        (1'b1),
        .flush     (1'b0),

        .valid_in  (1'b1),
        .pc_in     (pc),
        .instr_in  (instr_code),

        .valid_out (id_valid),
        .pc_out    (id_pc),
        .instr_out (id_instr)
    );

endmodule
