
`define SIMULATION

// ===============================================
// RV32I Multi-Cycle CPU Datapath
// ===============================================
module datapath(
    input logic clk, rst_n,
    input logic rf_we, alusrc_sel,
    input logic branch, jal, jalr, pc_en,
    input logic [2:0] rfsrc_sel,
    input logic [3:0] alu_control,
    input logic [31:0] instr_code, drdata,
    output logic [31:0] instr_addr, daddr, dwdata
);

    logic [31:0] alu_result;
    logic [31:0] rf_rd1, rf_rd2;
    logic [31:0] imm_extend;
    logic [31:0] alusrc_muxout;
    logic [31:0] wb_muxout;
    logic [31:0] pc_imm, pc_4;
    logic [31:0] dec_rd1, dec_rd2, dec_imm;
    logic b_taken;

    // Register File
    reg_file U_REG_FILE(
        .clk(clk),
        .rst_n(rst_n),
        .ra1(instr_code[19:15]),
        .ra2(instr_code[24:20]),
        .wa(instr_code[11:7]),
        .we(rf_we),
        .wd(wb_muxout),
        .rd1(rf_rd1),
        .rd2(rf_rd2)
    );

    // Decode Stage Registers
    regi DEC_RS1(
        .clk(clk),
        .wdata(rf_rd1),
        .rdata(dec_rd1)
    );

    regi DEC_RS2(
        .clk(clk),
        .wdata(rf_rd2),
        .rdata(dec_rd2)
    );

    imm_extend U_IMM_EXTEND(
        .instr_code(instr_code),
        .imm_extend(imm_extend)
    );

    regi DEC_IMM(
        .clk(clk),
        .wdata(imm_extend),
        .rdata(dec_imm)
    );

    // ALU Source MUX
    mux_2x1 U_ALUSRC_MUX(
        .sel(alusrc_sel),
        .in0(dec_rd2),
        .in1(dec_imm),
        .mux_out(alusrc_muxout)
    );

    // ALU
    alu U_ALU(
        .rs1(dec_rd1),
        .rs2(alusrc_muxout),
        .alu_control(alu_control),
        .alu_result(alu_result),
        .b_taken(b_taken)
    );

    // Execute Stage Registers
    regi EXE_ALU(
        .clk(clk),
        .wdata(alu_result),
        .rdata(daddr)
    );

    regi EXE_RS2(
        .clk(clk),
        .wdata(rf_rd2),
        .rdata(dwdata)
    );

    // Writeback MUX
    mux_5x1 U_WB_MUX(
        .sel(rfsrc_sel),
        .in0(alu_result),
        .in1(drdata),
        .in2(imm_extend),
        .in3(pc_imm),
        .in4(pc_4),
        .mux_out(wb_muxout)
    );

    // Program Counter
    program_counter U_PC(
        .clk(clk),
        .rst_n(rst_n),
        .b_taken(b_taken),
        .branch(branch),
        .jal(jal),
        .jalr(jalr),
        .pc_en(pc_en),
        .imm_extend(imm_extend),
        .rs1(rf_rd1),
        .pc_imm(pc_imm),
        .pc_4(pc_4),
        .pc(instr_addr)
    );

endmodule


// ===============================================
// 5-to-1 MUX
// ===============================================
module mux_5x1(
    input logic [2:0] sel,
    input logic [31:0] in0, in1, in2, in3, in4,
    output logic [31:0] mux_out
);

    always_comb begin
        mux_out = in0;

        case(sel)
            3'd0: mux_out = in0;
            3'd1: mux_out = in1;
            3'd2: mux_out = in2;
            3'd3: mux_out = in3;
            3'd4: mux_out = in4;
            default: mux_out = in0;
        endcase
    end

endmodule


// ===============================================
// 2-to-1 MUX
// ===============================================
module mux_2x1(
    input logic sel,
    input logic [31:0] in0, in1,
    output logic [31:0] mux_out
);

    assign mux_out = sel ? in1 : in0;

endmodule


// ===============================================
// ALU
// ===============================================
module alu(
    input logic [31:0] rs1, rs2,
    input logic [3:0] alu_control,
    output logic [31:0] alu_result,
    output logic b_taken
);

    always_comb begin
        alu_result = 32'h00000000;

        case(alu_control)
            4'b0_000: alu_result = rs1 + rs2;
            4'b1_000: alu_result = rs1 - rs2;
            4'b0_100: alu_result = rs1 ^ rs2;
            4'b0_110: alu_result = rs1 | rs2;
            4'b0_111: alu_result = rs1 & rs2;

            4'b0_001: alu_result = rs1 << rs2[4:0];
            4'b0_101: alu_result = rs1 >> rs2[4:0];
            4'b1_101: alu_result = $signed(rs1) >>> rs2[4:0];

            4'b0_010:
                alu_result = ($signed(rs1) < $signed(rs2))
                            ? 32'd1 : 32'd0;

            4'b0_011:
                alu_result = (rs1 < rs2)
                            ? 32'd1 : 32'd0;

            default: alu_result = 32'd0;
        endcase
    end

    // Branch Comparison
    always_comb begin
        b_taken = 1'b0;

        case(alu_control)
            4'b0_000: b_taken = (rs1 == rs2);
            4'b0_001: b_taken = (rs1 != rs2);
            4'b0_100: b_taken = ($signed(rs1) < $signed(rs2));
            4'b0_101: b_taken = ($signed(rs1) >= $signed(rs2));
            4'b0_110: b_taken = (rs1 < rs2);
            4'b0_111: b_taken = (rs1 >= rs2);
            default: b_taken = 1'b0;
        endcase
    end

endmodule


// ===============================================
// Program Counter
// Timing Experiment: Slow Ripple-Carry PC+4
// ===============================================
module program_counter(
    input logic clk, rst_n,
    input logic b_taken, branch, jal, jalr, pc_en,
    input logic [31:0] imm_extend, rs1,
    output logic [31:0] pc, pc_imm, pc_4
);

    logic [31:0] mux_out;
    logic [31:0] jalr_mux_out;
    logic [31:0] reg_out;
    logic [31:0] jalr_target;

    assign pc_imm = jalr_mux_out + imm_extend;

    assign pc_4 = pc + 32'd4;

    // ===========================================
    // JAL / JALR / Branch
    // ===========================================

    assign jalr_target =
        jalr ? {pc_imm[31:1], 1'b0} : pc_imm;

    mux_2x1 MUX(
        .sel((b_taken && branch) || jalr || jal),
        .in0(pc_4),
        .in1(jalr_target),
        .mux_out(mux_out)
    );

    mux_2x1 JALR_MUX(
        .sel(jalr),
        .in0(pc),
        .in1(rs1),
        .mux_out(jalr_mux_out)
    );

    // Next PC Register
    always_ff @(posedge clk) begin
        if (!rst_n)
            reg_out <= 32'd0;
        else
            reg_out <= mux_out;
    end

    // Current PC Register
    always_ff @(posedge clk) begin
        if (!rst_n)
            pc <= 32'd0;
        else if (pc_en)
            pc <= reg_out;
    end

endmodule


// ===============================================
// Register File
// ===============================================
module reg_file(
    input logic clk,
    input logic rst_n,
    input logic we,
    input logic [31:0] wd,
    input logic [4:0] ra1, ra2, wa,
    output logic [31:0] rd1, rd2
);

    logic [31:0] ram_file [1:31];

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            for (int i = 1; i < 32; i++)
                ram_file[i] <= 32'd0;
        end
        else begin
            if (we && wa != 5'd0)
                ram_file[wa] <= wd;
        end
    end

    assign rd1 = (ra1 == 5'd0) ? 32'd0 : ram_file[ra1];
    assign rd2 = (ra2 == 5'd0) ? 32'd0 : ram_file[ra2];

endmodule


// ===============================================
// Pipeline / Stage Register
// ===============================================
module regi(
    input logic clk,
    input logic [31:0] wdata,
    output logic [31:0] rdata
);

    always_ff @(posedge clk) begin
        rdata <= wdata;
    end

endmodule


// ===============================================
// Immediate Generator
// ===============================================
module imm_extend
    import rv32_pkg::*;
(
    input logic [31:0] instr_code,
    output logic [31:0] imm_extend
);

    opcode_e opcode;

    assign opcode = opcode_e'(instr_code[6:0]);

    logic [2:0] funct3;
    assign funct3 = instr_code[14:12];

    always_comb begin
        case(opcode)

            OP_STYPE:
                imm_extend = {
                    {20{instr_code[31]}},
                    instr_code[31:25],
                    instr_code[11:7]
                };

            OP_ITYPE: begin
                if (funct3 == 3'b001 || funct3 == 3'b101)
                    imm_extend = {27'd0, instr_code[24:20]};
                else
                    imm_extend = {
                        {20{instr_code[31]}},
                        instr_code[31:20]
                    };
            end

            OP_ILTYPE, OP_JRTYPE:
                imm_extend = {
                    {20{instr_code[31]}},
                    instr_code[31:20]
                };

            OP_BTYPE:
                imm_extend = {
                    {19{instr_code[31]}},
                    instr_code[31],
                    instr_code[7],
                    instr_code[30:25],
                    instr_code[11:8],
                    1'b0
                };

            OP_LUTYPE, OP_AUTYPE:
                imm_extend = {
                    instr_code[31:12],
                    12'd0
                };

            OP_JLTYPE:
                imm_extend = {
                    {11{instr_code[31]}},
                    instr_code[31],
                    instr_code[19:12],
                    instr_code[20],
                    instr_code[30:21],
                    1'b0
                };

            default:
                imm_extend = 32'h0000_0000;

        endcase
    end

endmodule
