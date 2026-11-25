module control_unit (
    input  logic [31:0] instr_code,
    input  logic        cp_result,
    output logic        regfile_we,
    output logic        alusrc_sel,
    output logic [ 3:0] alu_control,
    output logic [ 2:0] wbsel,
    output logic [ 1:0] pc_sel,
    output logic        dwe,
    output logic        mem_req,
    output logic [ 2:0] itype
);
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic       is_branch;
    logic [1:0] pc_sel_d;

    assign opcode = instr_code[6:0];
    assign funct3 = instr_code[14:12];

    always_comb begin
        regfile_we  = 1'b0;
        alusrc_sel  = 1'b0;
        alu_control = 4'b0000;
        wbsel       = 3'b000;
        dwe         = 1'b0;
        mem_req     = 1'b0;
        itype       = 3'b010;
        is_branch   = 1'b0;
        pc_sel_d    = 2'b00;

        case (opcode)
            7'b011_0011: begin
                regfile_we  = 1'b1;
                alu_control = {instr_code[30], funct3};
            end
            7'b001_0011: begin
                regfile_we = 1'b1;
                alusrc_sel = 1'b1;
                case (funct3)
                    3'b000: alu_control = 4'b0000;
                    3'b001: alu_control = 4'b0001;
                    3'b010: alu_control = 4'b0010;
                    3'b011: alu_control = 4'b0011;
                    3'b100: alu_control = 4'b0100;
                    3'b101: alu_control = instr_code[30] ? 4'b1101 : 4'b0101;
                    3'b110: alu_control = 4'b0110;
                    3'b111: alu_control = 4'b0111;
                    default: alu_control = 4'b0000;
                endcase
            end
            7'b000_0011: begin
                regfile_we  = 1'b1;
                alusrc_sel  = 1'b1;
                alu_control = 4'b0000;
                wbsel       = 3'b001;
                mem_req     = 1'b1;
                itype       = funct3;
            end
            7'b010_0011: begin
                alusrc_sel  = 1'b1;
                alu_control = 4'b0000;
                dwe         = 1'b1;
                mem_req     = 1'b1;
                itype       = funct3;
            end
            7'b110_0011: begin
                case (funct3)
                    3'b000: alu_control = 4'b1001;
                    3'b001: alu_control = 4'b1010;
                    3'b100: alu_control = 4'b1011;
                    3'b101: alu_control = 4'b1100;
                    3'b110: alu_control = 4'b1110;
                    3'b111: alu_control = 4'b1111;
                    default: alu_control = 4'b0000;
                endcase
                is_branch = 1'b1;
            end
            7'b011_0111: begin
                regfile_we = 1'b1;
                wbsel      = 3'b010;
            end
            7'b001_0111: begin
                regfile_we = 1'b1;
                wbsel      = 3'b011;
            end
            7'b110_1111: begin
                regfile_we = 1'b1;
                wbsel      = 3'b100;
                pc_sel_d   = 2'b01;
            end
            7'b110_0111: begin
                regfile_we  = 1'b1;
                alusrc_sel  = 1'b1;
                alu_control = 4'b0000;
                wbsel       = 3'b100;
                pc_sel_d    = 2'b10;
            end
            default: ;
        endcase
    end

    always_comb begin
        if (is_branch) pc_sel = cp_result ? 2'b01 : 2'b00;
        else           pc_sel = pc_sel_d;
    end
endmodule
