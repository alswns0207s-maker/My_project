`timescale 1ns / 1ps

module sr04_controller (
    input clk,
    input reset,
    input echo,
    input start,
    output trigger,
    output reg [8:0] distance,
    output done
);
    reg  [2:0] n_state, c_state;
    reg  [8:0] distance_next;
    reg  [4:0] tick_gen_count_reg, tick_gen_count_next;
    reg  [$clog2(23200)-1:0] echo_tick_gen_count_reg, echo_tick_gen_count_next;

    wire w_tick_us;

    ila_0 U_ILA_0(
    .clk(clk),
    .probe0(start),//start
    .probe1(trigger), //trigger
    .probe2(echo), //echo
    .probe3(c_state) //current_state
    );

    tick_generator U_TICK_GENERATOR (
        .clk      (clk),
        .reset    (reset),
        .run_stop (1'b1),
        .clear    (1'b0),
        .o_tick_us(w_tick_us)
    );

    //state_register
    parameter IDLE = 3'b000, START = 3'b001, WAIT = 3'b010, COUNT = 3'b011, DISTANCE = 3'b100;

    assign trigger = (c_state == IDLE) && start && (tick_gen_count_reg <= 11);
    assign done    = (c_state == DISTANCE);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            c_state <= IDLE;
            tick_gen_count_reg <= 5'b00000;
            echo_tick_gen_count_reg <= 0;
            distance <= 0;
        end else begin
            c_state <= n_state;
            tick_gen_count_reg <= tick_gen_count_next;
            echo_tick_gen_count_reg <= echo_tick_gen_count_next;
            distance <= distance_next; 
        end
    end

    //next_logic
    always @(*) begin
        n_state = c_state;
        tick_gen_count_next = tick_gen_count_reg;
        echo_tick_gen_count_next = echo_tick_gen_count_reg;
        distance_next = distance;

        case (c_state)
            IDLE: begin
                tick_gen_count_next = 4'b0000;
                echo_tick_gen_count_next = 0;
                if (start) begin
                    if (w_tick_us) begin
                        tick_gen_count_next = tick_gen_count_reg + 1;
                        if (tick_gen_count_reg == 11) begin
                            n_state = START;
                        end
                    end
                end else n_state = IDLE;
            end
            START: begin
                n_state = WAIT;
            end
            WAIT: begin
                if (echo) begin
                    n_state = COUNT;
                end
            end
            COUNT: begin
                if (w_tick_us) begin
                    echo_tick_gen_count_next = echo_tick_gen_count_reg + 1;
                    if (~echo) begin
                        n_state = DISTANCE;
                    end else n_state = COUNT;
                end

            end
            DISTANCE: begin
                distance_next = echo_tick_gen_count_reg / 58;
                n_state = IDLE;
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

    parameter F_COUNT = 100;
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
