`timescale 1ns / 1ps

module dht11_controller #(
    parameter TICK_1US = 100
)(
    input         clk,
    input         reset,
    input         start,
    output [15:0] humidity,
    output [15:0] temperature,
    output        done,
    output        valid,
    inout         dht11_io
);
    // release(~30us) + 센서 응답 Low(80us) + 센서 응답 High(80us) 는
    // 데이터시트 기준 시간이 거의 고정이라, 신호를 굳이 감시하지 않고
    // 그냥 "215us 동안 기다렸다가" 바로 데이터 비트 읽기로 넘어간다.
    // (215us면 bit0의 Low 구간(50us) 중간쯤이라 안전하게 걸린다.)
    // 그래서 rise/fall(edge) 검출이 아예 필요 없고, 2단 sync + 레벨 비교
    // (dht_s1==0/1)만으로 충분하다. 진짜 값을 담고 있는 DATA_LOW/DATA_HIGH
    // 구간만 신호를 직접 본다.
    localparam IDLE      = 0,
               WAIT      = 1,   // MCU가 19ms 동안 Low로 눌러서 시작을 알림
               SYNC      = 2,   // release+응답Low+응답High(~190us)를 고정 215us로 그냥 흘려보냄
               DATA_LOW  = 3,
               DATA_HIGH = 4,
               STOP      = 5;

    reg [2:0]  state;
    reg [15:0] cnt;
    reg [5:0]  bit_cnt;
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

    assign dht11_io = (state == WAIT) ? 1'b0 : 1'bz;

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
                        state     <= WAIT;
                    end
                end
                WAIT: begin
                    if (tick_us) begin
                        if (cnt == 18_999) begin
                            cnt   <= 0;
                            state <= SYNC;
                        end
                        else begin
                            cnt <= cnt + 1;
                        end
                    end
                end
                SYNC: begin
                    if (tick_us) begin
                        if (cnt == 214) begin
                            cnt   <= 0;
                            state <= DATA_LOW;
                        end
                        else begin
                            cnt <= cnt + 1;
                        end
                    end
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
                            state <= STOP;
                        end
                        else begin
                            bit_cnt <= bit_cnt + 1;
                            state   <= DATA_LOW;
                        end
                    end
                end

                STOP: begin
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
