module apb_gpo (
    input logic clk, rst_n, input logic PSEL, PENABLE,
    input logic [31:0] PADDR, PWDATA, input logic PWRITE,
    output logic PREADY, output logic [31:0] PRDATA,
    output logic [7:0] gpo_pin
);
    logic access;
    logic [31:0] CTR, ODR;
    assign access = PSEL && PENABLE;
    assign PREADY = access;
    assign gpo_pin = ODR[7:0];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin CTR <= 32'd0; ODR <= 32'd0; end
        else if (access && PWRITE) begin
            case (PADDR[3:2])
                2'd0: CTR <= PWDATA;
                2'd1: ODR <= PWDATA;
                default: ;
            endcase
        end
    end

    always_comb begin
        PRDATA = 32'd0;
        if (access && !PWRITE) begin
            case (PADDR[3:2])
                2'd0: PRDATA = CTR;
                2'd1: PRDATA = ODR;
                default: PRDATA = 32'd0;
            endcase
        end
    end
endmodule
