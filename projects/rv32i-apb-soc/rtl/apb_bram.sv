module apb_bram (
    input logic clk, input logic [2:0] itype,
    input logic PSEL, PENABLE, input logic [31:0] PADDR, PWDATA,
    input logic PWRITE, output logic PREADY, output logic [31:0] PRDATA
);
    logic [31:0] dmem [0:127];
    logic [6:0] widx;
    logic [31:0] word;
    logic [7:0] byte_sel;
    logic [15:0] half_sel;
    logic access;

    assign access = PSEL && PENABLE;
    assign PREADY = access;
    assign widx = PADDR[8:2];
    assign word = dmem[widx];

    always_ff @(posedge clk) begin
        if (access && PWRITE) begin
            case (itype)
                3'b000: case (PADDR[1:0])
                    2'b00: dmem[widx][7:0]   <= PWDATA[7:0];
                    2'b01: dmem[widx][15:8]  <= PWDATA[7:0];
                    2'b10: dmem[widx][23:16] <= PWDATA[7:0];
                    2'b11: dmem[widx][31:24] <= PWDATA[7:0];
                    default: ;
                endcase
                3'b001: if (PADDR[1]) dmem[widx][31:16] <= PWDATA[15:0];
                         else          dmem[widx][15:0]  <= PWDATA[15:0];
                3'b010: dmem[widx] <= PWDATA;
                default: ;
            endcase
        end
    end

    always_comb begin
        case (PADDR[1:0])
            2'b00: byte_sel = word[7:0];
            2'b01: byte_sel = word[15:8];
            2'b10: byte_sel = word[23:16];
            2'b11: byte_sel = word[31:24];
            default: byte_sel = word[7:0];
        endcase
        half_sel = PADDR[1] ? word[31:16] : word[15:0];
    end

    always_comb begin
        PRDATA = 32'd0;
        if (access && !PWRITE) begin
            case (itype)
                3'b000: PRDATA = {{24{byte_sel[7]}}, byte_sel};
                3'b001: PRDATA = {{16{half_sel[15]}}, half_sel};
                3'b010: PRDATA = word;
                3'b100: PRDATA = {24'd0, byte_sel};
                3'b101: PRDATA = {16'd0, half_sel};
                default: PRDATA = word;
            endcase
        end
    end
endmodule
