module datapath (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        regfile_we,
    input  logic        alusrc_sel,
    input  logic [ 3:0] alu_control,
    input  logic [ 2:0] wbsel,
    input  logic [ 1:0] pc_sel,
    input  logic        stall,
    input  logic [31:0] instr_code,
    input  logic [31:0] drdata,
    output logic        cp_result,
    output logic [31:0] instr_addr,
    output logic [31:0] daddr,
    output logic [31:0] dwdata
);
    logic [31:0] pc, pc_next;
    logic [31:0] pc_imm, pc_4, jalr_add, jalr_target;
    logic [31:0] rs1, rs2, imm, alu_b, alu_result, wd;

    register_file U_REGISTER_FILE (
        .clk(clk), .ra1(instr_code[19:15]), .ra2(instr_code[24:20]),
        .we(regfile_we), .wa(instr_code[11:7]), .wd(wd), .rd1(rs1), .rd2(rs2)
    );

    imm_gen U_IMM_GEN (.instr_code(instr_code), .imm(imm));
    mux_2x1 U_ALUSRC_MUX (.in0(rs2), .in1(imm), .sel(alusrc_sel), .y(alu_b));
    alu U_ALU (
        .a(rs1), .b(alu_b), .alu_control(alu_control),
        .alu_result(alu_result), .cp_result(cp_result)
    );

    adder U_ADD_PC_IMM (.a(pc),  .b(imm),   .y(pc_imm));
    adder U_ADD_PC_4   (.a(pc),  .b(32'd4), .y(pc_4));
    adder U_ADD_RS1_IMM(.a(rs1), .b(imm),   .y(jalr_add));

    assign jalr_target = {jalr_add[31:1], 1'b0};

    mux_4x1 U_PC_MUX (
        .in0(pc_4), .in1(pc_imm), .in2(jalr_target), .in3(32'd0),
        .sel(pc_sel), .y(pc_next)
    );

    program_counter U_PROGRAM_COUNTER (
        .clk(clk), .rst_n(rst_n), .en(!stall), .pc_next(pc_next), .pc(pc)
    );

    mux_8x1 U_WB_MUX (
        .in0(alu_result), .in1(drdata), .in2(imm), .in3(pc_imm),
        .in4(pc_4), .in5(32'd0), .in6(32'd0), .in7(32'd0),
        .sel(wbsel), .y(wd)
    );

    assign instr_addr = pc;
    assign daddr      = alu_result;
    assign dwdata     = rs2;
endmodule

module register_file (
    input logic clk, input logic [4:0] ra1, ra2, input logic we,
    input logic [4:0] wa, input logic [31:0] wd,
    output logic [31:0] rd1, rd2
);
    logic [31:0] register_ram_file [0:31];
    always_ff @(posedge clk)
        if (we && (wa != 5'd0)) register_ram_file[wa] <= wd;
    assign rd1 = (ra1 != 5'd0) ? register_ram_file[ra1] : 32'd0;
    assign rd2 = (ra2 != 5'd0) ? register_ram_file[ra2] : 32'd0;
endmodule

module program_counter (
    input logic clk, input logic rst_n, input logic en,
    input logic [31:0] pc_next, output logic [31:0] pc
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) pc <= 32'd0;
        else if (en) pc <= pc_next;
    end
endmodule

module adder #(parameter WIDTH = 32) (
    input logic [WIDTH-1:0] a, b, output logic [WIDTH-1:0] y
);
    assign y = a + b;
endmodule

module mux_2x1 #(parameter WIDTH = 32) (
    input logic [WIDTH-1:0] in0, in1, input logic sel,
    output logic [WIDTH-1:0] y
);
    assign y = sel ? in1 : in0;
endmodule

module mux_4x1 #(parameter WIDTH = 32) (
    input logic [WIDTH-1:0] in0, in1, in2, in3,
    input logic [1:0] sel, output logic [WIDTH-1:0] y
);
    always_comb begin
        case (sel)
            2'd0: y = in0;
            2'd1: y = in1;
            2'd2: y = in2;
            2'd3: y = in3;
            default: y = in0;
        endcase
    end
endmodule

module mux_8x1 #(parameter WIDTH = 32) (
    input logic [WIDTH-1:0] in0, in1, in2, in3, in4, in5, in6, in7,
    input logic [2:0] sel, output logic [WIDTH-1:0] y
);
    always_comb begin
        case (sel)
            3'd0: y = in0;
            3'd1: y = in1;
            3'd2: y = in2;
            3'd3: y = in3;
            3'd4: y = in4;
            3'd5: y = in5;
            3'd6: y = in6;
            3'd7: y = in7;
            default: y = in0;
        endcase
    end
endmodule
