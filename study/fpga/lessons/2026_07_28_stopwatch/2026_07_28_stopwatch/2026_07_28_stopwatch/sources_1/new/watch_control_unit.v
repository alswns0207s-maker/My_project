`timescale 1ns / 1ps

module control_unit_watch(
    input clk,
    input reset,
    input btn_L,
    input btn_R,
    input btn_U,
    input btn_D,
    input btn_C,
    output [1:0]edit_sel,
    output o_clear
);
parameter LEFT = 1, RIGHT = 2, UP = 3, DOWN = 4, CLEAR = 0;
reg [2:0] c_state, n_state;
reg btn_L_reg, btn_L_next, btn_R_reg, btn_R_next, btn_U_reg, btn_U_next;
reg btn_D_reg, btn_D_next, btn_C_reg, btn_C_next, clear_reg, clear_next;
//state register
always@(posedge clk, posedge reset)begin
    if(reset)begin
        c_state <= CLEAR;
        btn_L_reg <= 1'b0;
        btn_R_reg <= 1'b0;
        btn_U_reg <= 1'b0;
        btn_D_reg <= 1'b0;
        btn_C_reg <= 1'b0;
    end else begin
        c_state <= n_state;
        btn_L_reg <= btn_L_next;
        btn_R_reg <= btn_R_next;
        btn_U_reg <= btn_U_next;
        btn_D_reg <= btn_D_reg;
        btn_C_reg <= btn_C_reg;
    end
end
//next cl
always@(*)begin
    n_state = c_state;
    clear_next = clear_reg;
    btn_C_next = btn_C_reg;
    btn_D_next = btn_D_reg;
    btn_L_next = btn_L_reg;
    btn_R_next = btn_R_reg;
    case(c_state)
        btn_C:begin
            c_state = CLEAR;
            btn_L_next = 1'b0;
            btn_R_next = 1'b0;
            btn_U_next = 1'b0;
            btn_D_next = 1'b0;
        end
        btn_L:begin
            btn_L_next = 1'b1;
            if(btn_L)begin
                n_state = CLEAR;
            end
        end
        btn_R:begin
            btn_R_next = 1'b1;
            if(btn_R)begin
                n_state = CLEAR;
            end
        end
        btn_U:begin
            btn_U_next = 1'b1;
            if(btn_U)begin
                n_state = CLEAR;
            end
        end
        btn_D:begin
            btn_D_next = 1'b1;
            if(btn_D)begin
                n_state = CLEAR;
            end
        end
    endcase

end



endmodule