`timescale 1ns / 1ps

module dht11_controller #(
    parameter TICK_1US = 100
)(
    input             clk,
    input             reset,
    input             start,
    output     [15:0] humidity,
    output     [15:0] temperature,
    output            done,
    output            valid,
    inout             dht11_io
);
    localparam IDLE = 0, START = 1, WAIT_LOW  = 2, WAIT_HIGH = 3, DATA_LOW  = 4, DATA_HIGH = 5, FINISH = 6;

    reg [2:0] state;
    reg [15:0] cnt;
    reg [5:0] bit_cnt;
    reg [39:0] data_reg;

    reg done_reg;
    reg valid_reg;
    reg dht_s0, dht_s1;

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            dht_s0 <= 1;
            dht_s1 <= 1;
        end
        else begin
            dht_s0 <= dht11_io;
            dht_s1 <= dht_s0;
        end
    end

    wire tick_us;

    tick_gen_1us #(
        .F_COUNT(TICK_1US)
    ) U_TICK (
        .clk      (clk),
        .reset    (reset),
        .run_stop (1'b1),
        .clear    (1'b0),
        .o_tick   (tick_us)
    );

    assign dht11_io = (state == START) ? 1'b0 : 1'bz;

    assign humidity    = data_reg[39:24];
    assign temperature = data_reg[23:8];

    assign done  = done_reg;
    assign valid = valid_reg;

    always @(posedge clk, posedge reset) begin

        if (reset) begin
            state     <= IDLE;
            cnt       <= 0;
            bit_cnt   <= 0;
            data_reg  <= 0;
            done_reg  <= 0;
            valid_reg <= 0;
        end
        else begin
            done_reg <= 0;
            case (state)
                IDLE: begin
                    cnt <= 0;
                    if (start) begin
                        valid_reg <= 0;
                        data_reg  <= 0;
                        bit_cnt   <= 0;
                        state     <= START;
                    end
                end
                START: begin
                    if (tick_us) begin

                        if (cnt == 18_999) begin
                            cnt   <= 0;
                            state <= WAIT_LOW;
                        end
                        else begin
                            cnt <= cnt + 1;
                        end
                    end
                end
                WAIT_LOW: begin
                    if (dht_s1 == 0)
                        state <= WAIT_HIGH;
                end
                WAIT_HIGH: begin
                    if (dht_s1 == 1)
                        state <= DATA_LOW;
                end
                DATA_LOW: begin
                    if (dht_s1 == 1) begin
                        cnt   <= 0;
                        state <= DATA_HIGH;
                    end
                end
                DATA_HIGH: begin
                    if (tick_us)
                        cnt <= cnt + 1;
                    if (dht_s1 == 0) begin
                        data_reg <= { data_reg[38:0], (cnt > 40) };
                        cnt <= 0;
                        if (bit_cnt == 39) begin
                            state <= FINISH;
                        end
                        else begin
                            bit_cnt <= bit_cnt + 1;
                            state   <= DATA_LOW;
                        end
                    end
                end

                FINISH: begin

                    valid_reg <= data_reg[7:0] ==
                        ( data_reg[39:32] + data_reg[31:24] + data_reg[23:16] +  data_reg[15:8]);
                    done_reg <= 1;

                    state <= IDLE;
                end

                default:
                    state <= IDLE;

            endcase
        end
    end

endmodule