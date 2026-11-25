module rv32i_top (
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] sw,
    output logic [7:0] led
);
    logic rst_n;
    logic [31:0] instr_code, instr_addr;
    logic [31:0] daddr, dwdata, drdata;
    logic dwe, transfer_req, dready;
    logic [2:0] itype;
    logic [31:0] PADDR, PWDATA;
    logic PWRITE, PENABLE;
    logic PSEL0, PSEL1, PSEL2, PSEL3, PSEL4, PSEL5, PSEL6;
    logic [31:0] PRDATA0, PRDATA1, PRDATA2;
    logic PREADY0, PREADY1, PREADY2;

    assign rst_n = ~reset;

    instruction_rom U_INSTR_ROM (
        .instr_addr(instr_addr),
        .instr_code(instr_code)
    );

    rv32i_cpu U_RV32I_CPU (
        .clk(clk), .rst_n(rst_n), .instr_code(instr_code),
        .drdata(drdata), .dready(dready), .instr_addr(instr_addr),
        .daddr(daddr), .dwdata(dwdata), .dwe(dwe),
        .transfer_req(transfer_req), .itype(itype)
    );

    APB_master U_APB_MASTER (
        .clk(clk), .rst_n(rst_n), .daddr(daddr), .dwdata(dwdata),
        .dwe(dwe), .transfer_req(transfer_req), .drdata(drdata),
        .dready(dready), .PAddr(PADDR), .PWData(PWDATA),
        .PWrite(PWRITE), .PEnable(PENABLE),
        .psel0(PSEL0), .psel1(PSEL1), .psel2(PSEL2), .psel3(PSEL3),
        .psel4(PSEL4), .psel5(PSEL5), .psel6(PSEL6),
        .PRData0(PRDATA0), .PRData1(PRDATA1), .PRData2(PRDATA2),
        .PRData3(32'd0), .PRData4(32'd0), .PRData5(32'd0), .PRData6(32'd0),
        .PReady0(PREADY0), .PReady1(PREADY1), .PReady2(PREADY2),
        .PReady3(1'b1), .PReady4(1'b1), .PReady5(1'b1), .PReady6(1'b1)
    );

    apb_bram U_APB_RAM (
        .clk(clk), .itype(itype), .PSEL(PSEL0), .PENABLE(PENABLE),
        .PADDR(PADDR), .PWDATA(PWDATA), .PWRITE(PWRITE),
        .PREADY(PREADY0), .PRDATA(PRDATA0)
    );

    apb_gpi U_APB_GPI (
        .clk(clk), .rst_n(rst_n), .gpi_pin(sw), .PSEL(PSEL1),
        .PENABLE(PENABLE), .PADDR(PADDR), .PWDATA(PWDATA),
        .PWRITE(PWRITE), .PREADY(PREADY1), .PRDATA(PRDATA1)
    );

    apb_gpo U_APB_GPO (
        .clk(clk), .rst_n(rst_n), .PSEL(PSEL2), .PENABLE(PENABLE),
        .PADDR(PADDR), .PWDATA(PWDATA), .PWRITE(PWRITE),
        .PREADY(PREADY2), .PRDATA(PRDATA2), .gpo_pin(led)
    );
endmodule

module rv32i_cpu (
    input  logic        clk, rst_n,
    input  logic [31:0] instr_code, drdata,
    input  logic        dready,
    output logic [31:0] instr_addr, daddr, dwdata,
    output logic        dwe, transfer_req,
    output logic [2:0]  itype
);
    logic regfile_we, alusrc_sel, cp_result, mem_req, stall;
    logic regfile_we_to_dp;
    logic [3:0] alu_control;
    logic [2:0] wbsel;
    logic [1:0] pc_sel;

    assign stall            = mem_req && !dready;
    assign transfer_req     = mem_req;
    assign regfile_we_to_dp = regfile_we && (!mem_req || dready);

    control_unit U_CONTROL_UNIT (
        .instr_code(instr_code), .cp_result(cp_result),
        .regfile_we(regfile_we), .alusrc_sel(alusrc_sel),
        .alu_control(alu_control), .wbsel(wbsel), .pc_sel(pc_sel),
        .dwe(dwe), .mem_req(mem_req), .itype(itype)
    );

    datapath U_DATAPATH (
        .clk(clk), .rst_n(rst_n), .regfile_we(regfile_we_to_dp),
        .alusrc_sel(alusrc_sel), .alu_control(alu_control),
        .wbsel(wbsel), .pc_sel(pc_sel), .stall(stall),
        .instr_code(instr_code), .drdata(drdata), .cp_result(cp_result),
        .instr_addr(instr_addr), .daddr(daddr), .dwdata(dwdata)
    );
endmodule
