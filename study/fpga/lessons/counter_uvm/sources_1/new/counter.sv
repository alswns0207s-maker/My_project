`timescale 1ns / 1ps

module counter #(
    parameter WIDTH = 8
)(
    input  logic             clk,
    input  logic             reset,
    input  logic             cnt_en,
    output logic [WIDTH-1:0] count
);

    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            count <= '0;
        else if (cnt_en)
            count <= count + 1'b1;
    end

endmodule
