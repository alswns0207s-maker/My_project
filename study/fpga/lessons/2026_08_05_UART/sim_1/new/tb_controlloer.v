`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/08/05 11:53:09
// Design Name: 
// Module Name: tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb();

reg clk;
reg reset;
reg btn_R;
wire tx;
wire [7:0]led;


uart_controller dut (
    .clk(clk),
    .reset(reset),
    .btn_R(btn_R),
    .tx(tx),
    .led(led)
);

always #5clk=~clk;

initial begin
    clk=0;
    reset=1;
    btn_R=0;
    #10;
    reset=0;
    btn_R=1;
end
endmodule