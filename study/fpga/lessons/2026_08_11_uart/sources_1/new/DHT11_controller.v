`timescale 1ns / 1ps
module DHT11_controller(
    input clk, 
    input reset,
    input start,
    output [15:0] humidity,
    output [15:0] temperature,
    output done,
    output valid,
    inout dht11_io

    );
    reg tick_us;
    reg [$clog2(19000)-1:0]tick_count_reg, tick_count_next;
    localparam  [2:0] IDLE = 0, START = 1, WAIT = 2, SYNC = 3, DATA = 4, STOP = 5;
    reg [2:0] c_state, n_state;

    reg io_control;
    reg dht11_io_reg, dht11_io_next;

    assign dht11_io = (io_control) ? (dht11_io_reg) : 1'bz;


    always@(posedge clk, posedge reset)begin
        if(reset)begin
            c_state <= IDLE;
            dht11_io_reg <= 1'b1;
        end else begin
            c_state <= n_state;
            dht11_io_reg <= dht11_io_next;
        end
    end

    always@(*)begin
        n_state = c_state;
        dht11_io_next = dht11_io_reg;
        io_control = 1'b1;
        case(c_state)
        IDLE : begin
            dht11_io_next = 1'b1;
            io_control = 1'b1;
            tick_count_next = 0;
            if(start)begin
                n_state = START;
            end
        end
        START : begin
            dht11_io_next = 1'b0;
            //delay 19msec low
            if(tick_count_reg == 19000)begin
                tick_count_next = 0;
                n_state = WAIT;
            end
            tick_count_next = tick_count_reg + 1;
        end
        WAIT: begin
            if(tick_us)
                if(tick_count_reg == 3)begin 
                    tick_count_next = 0;
                    n_state = SYNC;
                end else tick_count_next = tick_count_reg + 1;
        end
        SYNC:begin
            io_control = 1'b0;
            if(tick_us)
                if(tick_count_reg > 3)begin
                    n_state = DATA;
                end else begin
                    tick_count_next = tick_count_reg + 1;
                end
        end
        DATA: begin
            n_state = STOP;
        end
        STOP:begin
            if(tick_count_reg > 5)begin
                io_control = 1'b1;
                n_state = IDLE;
            end
        end
        endcase
    end



endmodule
