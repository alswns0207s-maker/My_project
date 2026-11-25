`timescale 1ns / 1ps
module alu (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);

    assign result = a + b;

endmodule
