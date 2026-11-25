module APB_master (
    input  logic clk, rst_n,
    input  logic [31:0] daddr, dwdata,
    input  logic dwe, transfer_req,
    output logic [31:0] drdata,
    output logic dready,
    output logic [31:0] PAddr, PWData,
    output logic PWrite, PEnable,
    output logic psel0, psel1, psel2, psel3, psel4, psel5, psel6,
    input  logic [31:0] PRData0, PRData1, PRData2, PRData3, PRData4, PRData5, PRData6,
    input  logic PReady0, PReady1, PReady2, PReady3, PReady4, PReady5, PReady6
);
    typedef enum logic [1:0] {IDLE, SETUP, ACCESS} state_e;
    state_e c_state, n_state;
    logic [31:0] addr_hold, wdata_hold;
    logic dwe_hold, slv_ready, selected_valid, dec_enable;
    logic [2:0] sel_idx;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            c_state   <= IDLE;
            addr_hold <= 32'd0;
            wdata_hold <= 32'd0;
            dwe_hold <= 1'b0;
        end else begin
            c_state <= n_state;
            if (c_state == IDLE && transfer_req) begin
                addr_hold  <= daddr;
                wdata_hold <= dwdata;
                dwe_hold   <= dwe;
            end
        end
    end

    always_comb begin
        n_state = c_state;
        PEnable = 1'b0;
        dready  = 1'b0;
        case (c_state)
            IDLE:   if (transfer_req) n_state = SETUP;
            SETUP:  n_state = ACCESS;
            ACCESS: begin
                PEnable = 1'b1;
                if (!selected_valid || slv_ready) begin
                    dready  = 1'b1;
                    n_state = IDLE;
                end
            end
            default: n_state = IDLE;
        endcase
    end

    assign dec_enable = (c_state != IDLE);
    assign PAddr  = addr_hold;
    assign PWData = wdata_hold;
    assign PWrite = dwe_hold;

    Address_Decoder U_APB_DEC (
        .PAddr(addr_hold), .enable(dec_enable), .sel_idx(sel_idx),
        .selected_valid(selected_valid),
        .psel0(psel0), .psel1(psel1), .psel2(psel2), .psel3(psel3),
        .psel4(psel4), .psel5(psel5), .psel6(psel6)
    );

    mux7to1 #(.WIDTH(32)) U_RDATA_MUX (
        .sel_idx(sel_idx), .data_in0(PRData0), .data_in1(PRData1),
        .data_in2(PRData2), .data_in3(PRData3), .data_in4(PRData4),
        .data_in5(PRData5), .data_in6(PRData6), .data_out(drdata)
    );

    mux7to1 #(.WIDTH(1)) U_READY_MUX (
        .sel_idx(sel_idx), .data_in0(PReady0), .data_in1(PReady1),
        .data_in2(PReady2), .data_in3(PReady3), .data_in4(PReady4),
        .data_in5(PReady5), .data_in6(PReady6), .data_out(slv_ready)
    );
endmodule
