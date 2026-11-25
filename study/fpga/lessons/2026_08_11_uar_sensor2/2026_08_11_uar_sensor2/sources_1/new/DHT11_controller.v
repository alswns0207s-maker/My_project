`timescale 1ns / 1ps
module DHT11_controller(
    input clk, 
    input reset,
    input start,
    output reg [15:0] humidity,
    output reg [15:0] temperature,
    output reg done,
    output reg valid,
    inout dht11_io

    );

    wire w_tick_us;
    tick_generator U_TICK_US (
        .clk       (clk),
        .reset     (reset),
        .run_stop  (1'b1),
        .clear     (1'b0),
        .o_tick_us (w_tick_us)
    );

    reg [$clog2(18000)-1:0] tick_count_reg, tick_count_next;
    localparam [2:0] IDLE=0, START=1, WAIT=2, SYNC=3, BIT_LOW=4, BIT_HIGH=5, STOP=6;
    reg [2:0] c_state, n_state;

    reg io_control;
    reg dht11_io_reg, dht11_io_next;
    assign dht11_io = (io_control) ? (dht11_io_reg) : 1'bz;

    // ---- 40bit 수신용 레지스터 ----
    reg [39:0] shift_reg, shift_reg_next;
    reg [5:0]  bit_count_reg, bit_count_next;
    reg        bit_value_reg, bit_value_next;   // BIT_HIGH count==50 value
    reg [15:0] humidity_next, temperature_next;
    reg        done_next, valid_next;

    // shift_reg 안의 40bit를 필드별로 분리 (MSB first: 습도정수-습도소수-온도정수-온도소수-checksum)
    wire [7:0] hum_int   = shift_reg[39:32];
    wire [7:0] hum_dec   = shift_reg[31:24];
    wire [7:0] temp_int  = shift_reg[23:16];
    wire [7:0] temp_dec  = shift_reg[15:8];
    wire [7:0] recv_chk  = shift_reg[7:0];
    wire [7:0] calc_chk  = hum_int + hum_dec + temp_int + temp_dec;

    always@(posedge clk, posedge reset)begin
        if(reset)begin
            c_state        <= IDLE;
            dht11_io_reg   <= 1'b1;
            tick_count_reg <= 0;
            shift_reg      <= 0;
            bit_count_reg  <= 0;
            bit_value_reg      <= 0;
            humidity       <= 0;
            temperature    <= 0;
            done           <= 0;
            valid          <= 0;
        end else begin
            c_state        <= n_state;
            dht11_io_reg   <= dht11_io_next;
            tick_count_reg <= tick_count_next;
            shift_reg      <= shift_reg_next;
            bit_count_reg  <= bit_count_next;
            bit_value_reg      <= bit_value_next;
            humidity       <= humidity_next;
            temperature    <= temperature_next;
            done           <= done_next;
            valid          <= valid_next;
        end
    end

    always@(*)begin
        n_state          = c_state;
        dht11_io_next    = dht11_io_reg;
        tick_count_next  = tick_count_reg;
        shift_reg_next   = shift_reg;
        bit_count_next   = bit_count_reg;
        bit_value_next   = bit_value_reg;
        humidity_next    = humidity;
        temperature_next = temperature;
        valid_next       = valid;
        done_next        = 1'b0;      
        io_control       = 1'b1;

        case(c_state)

        IDLE : begin
            dht11_io_next = 1'b1;
            io_control = 1'b1;
            tick_count_next = 0;
            bit_count_next = 0;
            if(start)begin
                n_state = START;
            end
        end

        START : begin
            // 18ms Low
            dht11_io_next = 1'b0;
            if(w_tick_us)begin
                if(tick_count_reg == 18000)begin
                    tick_count_next = 0;
                    n_state = WAIT;
                end else begin
                    tick_count_next = tick_count_reg + 1;
                end
            end
        end

        WAIT: begin
            // 30us High 
            dht11_io_next = 1'b1;
            if(w_tick_us)begin
                if(tick_count_reg == 30)begin
                    tick_count_next = 0;
                    n_state = SYNC;
                end else begin
                    tick_count_next = tick_count_reg + 1;
                end
            end
        end

        SYNC: begin
            // 센서 응답 80us(Low)+80us(High) = 160us, count로만 대기
            io_control = 1'b0;
            if(w_tick_us)begin
                if(tick_count_reg == 160)begin
                    tick_count_next = 0;
                    n_state = BIT_LOW;
                end else begin
                    tick_count_next = tick_count_reg + 1;
                end
            end
        end

        BIT_LOW: begin
            // 비트 시작:50us Low
            io_control = 1'b0;
            if(w_tick_us)begin
                if(tick_count_reg == 50)begin
                    tick_count_next = 0;
                    n_state = BIT_HIGH;
                end else begin
                    tick_count_next = tick_count_reg + 1;
                end
            end
        end

        BIT_HIGH: begin
            // 최대 80us 대기, count==50
            io_control = 1'b0;
            if(w_tick_us)begin
                if(tick_count_reg == 50)begin
                    bit_value_next = dht11_io;
                end
                if(tick_count_reg == 80)begin
                    tick_count_next = 0;
                    shift_reg_next  = {shift_reg[38:0], bit_value_reg};
                    bit_count_next  = bit_count_reg + 1;
                    if(bit_count_next == 40)begin
                        n_state = STOP;
                    end else begin
                        n_state = BIT_LOW;
                    end
                end else begin
                    tick_count_next = tick_count_reg + 1;
                end
            end
        end

        STOP: begin
            // 마지막 50us Low, 끝나면 checksum 비교
            io_control = 1'b0;
            if(w_tick_us)begin
                if(tick_count_reg == 50)begin
                    tick_count_next   = 0;
                    humidity_next     = {hum_int, hum_dec};
                    temperature_next  = {temp_int, temp_dec};
                    valid_next        = (calc_chk == recv_chk);
                    done_next         = 1'b1;
                    n_state = IDLE;
                end else begin
                    tick_count_next = tick_count_reg + 1;
                end
            end
        end

        endcase
    end

endmodule




module tick_generator (
    input clk,
    input reset,
    input run_stop,
    input clear,
    output reg o_tick_us
);

    parameter F_COUNT = 100;  // 100MHz clk: 100 x 10ns = 1us
    reg [$clog2(F_COUNT)-1:0] tick_count;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            tick_count <= 0;
            o_tick_us  <= 1'b0;
        end else if (clear) begin
            tick_count <= 0;
            o_tick_us  <= 1'b0;
        end else if (run_stop) begin
            tick_count <= tick_count + 1;
            if (tick_count == F_COUNT - 1) begin
                o_tick_us  <= 1'b1;
                tick_count <= 0;
            end else begin
                o_tick_us <= 1'b0;
            end
        end
    end

endmodule