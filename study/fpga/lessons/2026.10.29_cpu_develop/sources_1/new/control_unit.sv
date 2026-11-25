`timescale 1ns / 1ps
module control_unit (
    input  logic [31:0] instr,
    output logic        reg_write
);

    always_comb begin
        // 기본값: 레지스터 쓰기 금지
        reg_write = 1'b0;

        case (instr[6:0])
            7'b0010011: begin
                // ADDI
                if (instr[14:12] == 3'b000)
                    reg_write = 1'b1;
            end

            default: begin
                reg_write = 1'b0;
            end
        endcase
    end

endmodule
