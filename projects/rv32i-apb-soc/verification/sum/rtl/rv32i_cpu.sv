
module rv32i_top(
    input  logic        clk,
    input  logic        rst_n,

    // Timing Analysis Debug Outputs
    output logic [31:0] dbg_pc,
    output logic [31:0] dbg_addr,
    output logic [31:0] dbg_wdata,
    output logic        dbg_ready
);

    // CPU <-> Instruction ROM
    logic [31:0] instr_addr, instr_code;

    // CPU <-> APB Requester
    logic [31:0] daddr, dwdata, drdata;
    logic        dwe, transfer, ready;
    logic [2:0]  itype;

    // APB Bus
    logic [31:0] PADDR, PWDATA;
    logic        PWRITE, PENABLE;

    logic PSEL0, PSEL1, PSEL2, PSEL3;
    logic PSEL4, PSEL5, PSEL6;

    logic [31:0] PRDATA0, PRDATA1, PRDATA2;
    logic [31:0] PRDATA3, PRDATA4, PRDATA5, PRDATA6;

    logic PREADY0, PREADY1, PREADY2, PREADY3;
    logic PREADY4, PREADY5, PREADY6;


    // ==========================================
    // Instruction ROM
    // ==========================================
    instruction_rom U_INSTR_ROM(
        .instr_addr (instr_addr),
        .instr_code (instr_code)
    );


    // ==========================================
    // RV32I Multi-Cycle CPU
    // ==========================================
    rv32i_cpu U_RV32I_CPU(
        .clk        (clk),
        .rst_n      (rst_n),
        .instr_code (instr_code),
        .instr_addr (instr_addr),
        .drdata     (drdata),
        .daddr      (daddr),
        .dwdata     (dwdata),
        .dwe        (dwe),
        .itype      (itype),
        .ready      (ready),
        .transfer   (transfer)
    );


    // ==========================================
    // APB Requester
    // ==========================================
    apb_requester U_APB_REQUESTER(
        .clk       (clk),
        .rst_n     (rst_n),

        .bus_addr  (daddr),
        .bus_wdata (dwdata),
        .bus_we    (dwe),
        .transfer  (transfer),
        .ready     (ready),
        .bus_rdata (drdata),

        .PREADY0   (PREADY0),
        .PREADY1   (PREADY1),
        .PREADY2   (PREADY2),
        .PREADY3   (PREADY3),
        .PREADY4   (PREADY4),
        .PREADY5   (PREADY5),
        .PREADY6   (PREADY6),

        .PRDATA0   (PRDATA0),
        .PRDATA1   (PRDATA1),
        .PRDATA2   (PRDATA2),
        .PRDATA3   (PRDATA3),
        .PRDATA4   (PRDATA4),
        .PRDATA5   (PRDATA5),
        .PRDATA6   (PRDATA6),

        .PADDR     (PADDR),
        .PWDATA    (PWDATA),
        .PWRITE    (PWRITE),
        .PENABLE   (PENABLE),

        .PSEL0     (PSEL0),
        .PSEL1     (PSEL1),
        .PSEL2     (PSEL2),
        .PSEL3     (PSEL3),
        .PSEL4     (PSEL4),
        .PSEL5     (PSEL5),
        .PSEL6     (PSEL6)
    );


    // ==========================================
    // APB BRAM
    // ==========================================
    apb_bram U_APB_BRAM(
        .clk     (clk),
        .itype   (itype),
        .PSEL    (PSEL0),
        .PENABLE (PENABLE),
        .PADDR   (PADDR),
        .PWDATA  (PWDATA),
        .PWRITE  (PWRITE),
        .PREADY  (PREADY0),
        .PRDATA  (PRDATA0)
    );


    // ==========================================
    // Unused APB Slaves
    // ==========================================
    assign PREADY1 = 1'b0;
    assign PRDATA1 = 32'h0000_0000;

    assign PREADY2 = 1'b0;
    assign PRDATA2 = 32'h0000_0000;

    assign PREADY3 = 1'b0;
    assign PRDATA3 = 32'h0000_0000;

    assign PREADY4 = 1'b0;
    assign PRDATA4 = 32'h0000_0000;

    assign PREADY5 = 1'b0;
    assign PRDATA5 = 32'h0000_0000;

    assign PREADY6 = 1'b0;
    assign PRDATA6 = 32'h0000_0000;


    // ==========================================
    // Timing Analysis Debug Outputs
    // ==========================================
    assign dbg_pc    = instr_addr;
    assign dbg_addr  = daddr;
    assign dbg_wdata = dwdata;
    assign dbg_ready = ready;

endmodule



// ==============================================
// RV32I CPU
// ==============================================
module rv32i_cpu(
    input  logic        clk,
    input  logic        rst_n,
    input  logic [31:0] instr_code,
    input  logic [31:0] drdata,
    input  logic        ready,

    output logic [31:0] instr_addr,
    output logic [31:0] daddr,
    output logic [31:0] dwdata,
    output logic        dwe,
    output logic        transfer,
    output logic [2:0]  itype
);

    // Control Signals
    logic rf_we;
    logic alusrc_sel;
    logic jal;
    logic jalr;
    logic branch;
    logic pc_en;

    logic [2:0] rfsrc_sel;
    logic [3:0] alu_control;


    // ==========================================
    // Control Unit
    // ==========================================
    control_unit U_CONTROL_UNIT(
        .*
    );


    // ==========================================
    // Datapath
    // ==========================================
    datapath U_DATAPATH(
        .*
    );

endmodule
