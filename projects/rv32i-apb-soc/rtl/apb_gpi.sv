module apb_gpi (
    input logic clk, rst_n, input logic [7:0] gpi_pin,
    input logic PSEL, PENABLE, input logic [31:0] PADDR, PWDATA,
    input logic PWRITE, output logic PREADY, output logic [31:0] PRDATA
);
    logic access;
    logic [31:0] CTR;
    logic [7:0] sync1, sync2;
    assign access = PSEL && PENABLE;
    assign PREADY = access;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin sync1 <= 8'd0; sync2 <= 8'd0; end
        else begin sync1 <= gpi_pin; sync2 <= sync1; end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) CTR <= 32'd0;
        else if (access && PWRITE && PADDR[3:2] == 2'd0) CTR <= PWDATA;
    end

    always_comb begin
        PRDATA = 32'd0;
        if (access && !PWRITE) begin
            case (PADDR[3:2])
                2'd0: PRDATA = CTR;
                2'd1: PRDATA = {24'd0, sync2};
                default: PRDATA = 32'd0;
            endcase
        end
    end
endmodule
