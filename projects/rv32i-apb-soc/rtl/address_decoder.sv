module Address_Decoder (
    input  logic [31:0] PAddr,
    input  logic        enable,
    output logic [ 2:0] sel_idx,
    output logic        selected_valid,
    output logic        psel0, psel1, psel2, psel3, psel4, psel5, psel6
);
    always_comb begin
        sel_idx       = 3'd0;
        selected_valid = 1'b0;
        psel0 = 1'b0;
        psel1 = 1'b0;
        psel2 = 1'b0;
        psel3 = 1'b0;
        psel4 = 1'b0;
        psel5 = 1'b0;
        psel6 = 1'b0;

        if (enable) begin
            case (PAddr[31:28])
                4'h1: begin
                    psel0 = 1'b1;
                    sel_idx = 3'd0;
                    selected_valid = 1'b1;
                end
                4'h2: begin
                    case (PAddr[11:8])
                        4'h0: begin psel1 = 1'b1; sel_idx = 3'd1; selected_valid = 1'b1; end
                        4'h1: begin psel2 = 1'b1; sel_idx = 3'd2; selected_valid = 1'b1; end
                        4'h2: begin psel3 = 1'b1; sel_idx = 3'd3; selected_valid = 1'b1; end
                        4'h3: begin psel4 = 1'b1; sel_idx = 3'd4; selected_valid = 1'b1; end
                        4'h4: begin psel5 = 1'b1; sel_idx = 3'd5; selected_valid = 1'b1; end
                        4'h5: begin psel6 = 1'b1; sel_idx = 3'd6; selected_valid = 1'b1; end
                        default: ;
                    endcase
                end
                default: ;
            endcase
        end
    end
endmodule
