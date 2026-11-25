module mux7to1 #(parameter WIDTH = 32) (
    input logic [2:0] sel_idx,
    input logic [WIDTH-1:0] data_in0, data_in1, data_in2, data_in3,
    input logic [WIDTH-1:0] data_in4, data_in5, data_in6,
    output logic [WIDTH-1:0] data_out
);
    always_comb begin
        case (sel_idx)
            3'd0: data_out = data_in0;
            3'd1: data_out = data_in1;
            3'd2: data_out = data_in2;
            3'd3: data_out = data_in3;
            3'd4: data_out = data_in4;
            3'd5: data_out = data_in5;
            3'd6: data_out = data_in6;
            default: data_out = '0;
        endcase
    end
endmodule
