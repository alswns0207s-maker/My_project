module apb_gpio (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        PSEL,
    input  logic        PENABLE,
    input  logic [31:0] PADDR,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    output logic        PREADY,
    output logic [31:0] PRDATA,
    inout  wire  [7:0]  gpio_pin
);
    logic [31:0] CTR, ODR;
    logic [7:0] sync1, sync2;
    logic access;

    assign access = PSEL && PENABLE;
    assign PREADY = access;

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : GEN_GPIO_PIN
            assign gpio_pin[i] = CTR[i] ? ODR[i] : 1'bz;
        end
    endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sync1 <= 8'd0;
            sync2 <= 8'd0;
        end else begin
            sync1 <= gpio_pin;
            sync2 <= sync1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            CTR <= 32'd0;
            ODR <= 32'd0;
        end else if (access && PWRITE) begin
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
                2'd2: PRDATA = {24'd0, sync2};
                default: PRDATA = 32'd0;
            endcase
        end
    end
endmodule
