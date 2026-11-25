module alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [ 3:0] alu_control,
    output logic [31:0] alu_result,
    output logic        cp_result
);
    always_comb begin
        alu_result = 32'd0;
        cp_result  = 1'b0;

        case (alu_control)
            4'b0000: alu_result = a + b;
            4'b0001: alu_result = a << b[4:0];
            4'b0010: alu_result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            4'b0011: alu_result = (a < b) ? 32'd1 : 32'd0;
            4'b0100: alu_result = a ^ b;
            4'b0101: alu_result = a >> b[4:0];
            4'b0110: alu_result = a | b;
            4'b0111: alu_result = a & b;
            4'b1000: alu_result = a - b;
            4'b1001: cp_result  = (a == b);
            4'b1010: cp_result  = (a != b);
            4'b1011: cp_result  = ($signed(a) < $signed(b));
            4'b1100: cp_result  = ($signed(a) >= $signed(b));
            4'b1101: alu_result = $unsigned($signed(a) >>> b[4:0]);
            4'b1110: cp_result  = (a < b);
            4'b1111: cp_result  = (a >= b);
            default: begin
                alu_result = 32'd0;
                cp_result  = 1'b0;
            end
        endcase
    end
endmodule
