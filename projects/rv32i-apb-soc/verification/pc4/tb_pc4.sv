`timescale 1ns/1ps
module tb_pc4;
    logic clk = 0, rst_n = 0, jal = 0, pc_en = 1;
    logic [31:0] imm_extend = 0;
    wire [31:0] pc_ripple, pc_restored, sum_ripple, sum_restored;
    int checked = 0;
    always #4.5 clk = ~clk;

    ripple_pc ripple(.clk(clk), .rst_n(rst_n), .b_taken(1'b0), .branch(1'b0),
        .jal(jal), .jalr(1'b0), .pc_en(pc_en), .imm_extend(imm_extend), .rs1(32'b0),
        .pc(pc_ripple), .pc_imm(), .pc_4(sum_ripple));
    program_counter restored(.clk(clk), .rst_n(rst_n), .b_taken(1'b0), .branch(1'b0),
        .jal(jal), .jalr(1'b0), .pc_en(pc_en), .imm_extend(imm_extend), .rs1(32'b0),
        .pc(pc_restored), .pc_imm(), .pc_4(sum_restored));

    task automatic check_pc(input logic [31:0] target);
        @(negedge clk);
        jal = 1;
        imm_extend = target - pc_restored;
        pc_en = 0;
        @(negedge clk);
        jal = 0;
        pc_en = 1;
        @(negedge clk);
        if (pc_ripple !== target || pc_restored !== target ||
            sum_ripple !== (target + 32'd4) || sum_restored !== (target + 32'd4))
            $fatal(1, "PC+4 mismatch at %08h", target);
        checked++;
    endtask

    initial begin
        repeat (2) @(negedge clk);
        rst_n = 1;
        check_pc(32'h0);
        check_pc(32'h3);
        check_pc(32'h7fff_fffc);
        check_pc(32'hffff_fffc);
        check_pc(32'hffff_ffff);
        for (int n = 3; n < 32; n++) check_pc((32'h1 << n) - 4);
        repeat (1000) check_pc($urandom);
        $display("PASS: %0d directed and random cases, ripple PC+4 == restored PC+4 == expected 32-bit sum", checked);
        $finish;
    end
endmodule
