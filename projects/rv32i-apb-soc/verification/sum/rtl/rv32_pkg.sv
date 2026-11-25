package rv32_pkg;

    typedef enum logic [6:0] {
        OP_ILTYPE = 7'b0000011,
        OP_ITYPE  = 7'b0010011,
        OP_AUTYPE = 7'b0010111,
        OP_STYPE  = 7'b0100011,
        OP_RTYPE  = 7'b0110011,
        OP_LUTYPE = 7'b0110111,
        OP_BTYPE  = 7'b1100011,
        OP_JRTYPE = 7'b1100111,
        OP_JLTYPE = 7'b1101111
    } opcode_e;

    typedef enum logic [3:0] {
        R_ADD  = 4'b0_000,
        R_SUB  = 4'b1_000,
        R_SLL  = 4'b0_001,
        R_SLT  = 4'b0_010,
        R_SLTU = 4'b0_011,
        R_XOR  = 4'b0_100,
        R_SRL  = 4'b0_101,
        R_SRA  = 4'b1_101,
        R_OR   = 4'b0_110,
        R_AND  = 4'b0_111
    } instr_rtype_e;

    typedef enum logic [2:0] {
        B_BEQ  = 3'b000,
        B_BNE  = 3'b001,
        B_BLT  = 3'b100,
        B_BGE  = 3'b101,
        B_BLTU = 3'b110,
        B_BGEU = 3'b111
    } instr_btype_e;

endpackage : rv32_pkg
