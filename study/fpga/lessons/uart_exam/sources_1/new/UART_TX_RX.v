`timescale 1ns / 1ps



module UART_TX_RX(

    );
endmodule

module TX(
    input clk,
    input reset,
    input [7:0]data,
    input enable,
    input baud_rate_tick,
    output o_data
);
typedef enum (
    IDLE = 0,
    START,
    DATA,
    STOP
)uart_state_t;
reg [1:0]state_reg, state_reg_next; 
reg data_reg, data_reg_next;

always@(posedge clk)begin
    state_reg_next <= IDLE;
    data_reg_next <= 0;
    
    if(reset)begin
        
    end



end

always


endmodule

module baud_rate_counter#(
        parameter integer CLK_FREQ_HZ = 100000000,
        parameter integer BAUD_RATE = 115200
)(
        input clk,
        input reset,
        output reg baud_rate_tick
    );
    localparam integer CNT_WIDTH = $clog2(CLK_FREQ_HZ / BAUD_RATE);
    reg [CNT_WIDTH-1 : 0]baud_cnt=0;
    always@(posedge clk)begin
        if(reset)begin
            baud_cnt <= 0;
            baud_rate_tick <= 1'b0;
        end
        else if(baud_cnt == CLK_FREQ_HZ / BAUD_RATE -1)begin
            baud_cnt <= 0;
            baud_rate_tick <= 1'b1;
        end else begin
            baud_cnt <= baud_cnt + 1;
            baud_rate_tick <= 1'b0;
        end
        end
endmodule

module RX(



);
endmodule