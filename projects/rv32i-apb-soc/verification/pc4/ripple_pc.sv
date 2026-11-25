module ripple_pc(
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

    // ===========================================
    // INTENTIONAL TIMING EXPERIMENT
    //
    // Original:
    // assign pc_4 = pc + 32'd4;
    //
    // Modified:
    // Explicit ripple-carry chain
    //
    // Functional result remains PC + 4.
    // ===========================================

    (* keep = "true" *)
    wire [31:3] pc4_carry;

    // Lower bits
    assign pc_4[1:0] = pc[1:0];
    assign pc_4[2] = ~pc[2];

    // Carry into bit 3
    assign pc4_carry[3] = pc[2];

    // Sequential carry propagation
    genvar i;

    generate
        for (i = 4; i < 32; i = i + 1) begin : GEN_SLOW_PC4

            assign pc4_carry[i] =
                pc4_carry[i-1] & pc[i-1];

        end
    endgenerate

    // Sum bits
    generate
        for (i = 3; i < 32; i = i + 1) begin : GEN_PC4_SUM

            assign pc_4[i] =
                pc[i] ^ pc4_carry[i];

        end
    endgenerate

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
