`timescale 1ns / 1ps

module control_unit (
    input  clk,
    input  reset,
    input  i_run_stop,
    input  i_clear,
    input  i_mode,
    output o_run_stop,
    output o_clear,
    output o_mode
);
    parameter stop = 0, run = 1, clear = 2, mode = 3;

    reg [1:0] c_state, n_state;
    //output
    assign{o_clear, o_run_stop, o_mode} = (c_state == stop)?3'b000:
                                            (c_state ==run )? 3'b010:
                                            (c_state ==clear)?3'b100:
                                            (c_state==mode)?3'b000:3'b000;

    //state register
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            c_state <= stop;
        end else begin
            c_state <= n_state;
        end
    end



    //next cl

    always @(*) begin
        n_state = c_state;
        case (c_state)
            stop: begin
                if (i_run_stop) n_state = run;
                else if (i_clear) n_state = clear;
                else if (i_mode) n_state = mode;
                else n_state = c_state;
            end

            run: begin
                if (i_run_stop) begin
                    n_state = stop;
                end
            end
            clear: begin
                n_state = stop;
            end

            mode: begin
                n_state = stop;
            end
        endcase
    end



endmodule
