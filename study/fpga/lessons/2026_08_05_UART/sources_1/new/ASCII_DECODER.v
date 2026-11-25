`timescale 1ns / 1ps
module ASCII_DECODER (
    input        clk,
    input        reset,
    input        rx_done,
    input  [7:0] rx_data,
    input        cur_run_stop,
    output reg d_sw_run_stop,
    output reg d_sw_clear,
    output reg d_sw_mode,
    output reg d_wt_L,
    output reg d_wt_R,
    output reg d_wt_U,
    output reg d_wt_D,
    output reg d_wt_C,
    output reg d_sec_up,
    output reg d_min_up,
    output reg d_hour_up
);

    always @(posedge clk, posedge reset) begin
        if (reset) begin
            d_sw_run_stop <= 1'b0;
            d_sw_clear    <= 1'b0;
            d_sw_mode     <= 1'b0;
            d_wt_L        <= 1'b0;
            d_wt_R        <= 1'b0;
            d_wt_U        <= 1'b0;
            d_wt_D        <= 1'b0;
            d_wt_C        <= 1'b0;
            d_sec_up      <= 1'b0;
            d_min_up      <= 1'b0;
            d_hour_up     <= 1'b0;
        end else begin
            d_sw_run_stop <= 1'b0;
            d_sw_clear    <= 1'b0;
            d_sw_mode     <= 1'b0;
            d_wt_L        <= 1'b0;
            d_wt_R        <= 1'b0;
            d_wt_U        <= 1'b0;
            d_wt_D        <= 1'b0;
            d_wt_C        <= 1'b0;
            d_sec_up      <= 1'b0;
            d_min_up      <= 1'b0;
            d_hour_up     <= 1'b0;
            if (rx_done) begin
                case (rx_data)
                    8'h72: if (!cur_run_stop) d_sw_run_stop <= 1'b1;
                    8'h73: if ( cur_run_stop) d_sw_run_stop <= 1'b1;
                    8'h63: d_sw_clear <= 1'b1;
                    8'h6D: d_sw_mode  <= 1'b1;
                    8'h4C: d_wt_L <= 1'b1;
                    8'h52: d_wt_R <= 1'b1;
                    8'h55: d_wt_U <= 1'b1;
                    8'h44: d_wt_D <= 1'b1;
                    8'h43: d_wt_C <= 1'b1;
                    8'h53: d_sec_up  <= 1'b1;
                    8'h4D: d_min_up  <= 1'b1;
                    8'h48: d_hour_up <= 1'b1;
                    default: ;
                endcase
            end
        end
    end
endmodule
