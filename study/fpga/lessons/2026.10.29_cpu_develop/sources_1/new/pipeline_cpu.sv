module pipeline_cpu (
    input logic clk,
    input logic reset
);

    logic [31:0] pc;
    logic [31:0] instr_code;

    logic        id_valid;
    logic [31:0] id_pc;
    logic [31:0] id_instr;

    logic [31:0] id_rs1_data;
    logic [31:0] id_rs2_data;

    logic [31:0] id_imm;

    logic [31:0] ex_alu_result;
    logic id_reg_write;
    logic ex_valid, ex_reg_write;
    logic [31:0] ex_rs1_data, ex_imm;
    logic [4:0] ex_rd_addr;


    logic        mem_valid;
    logic [31:0] mem_alu_result;
    logic [4:0]  mem_rd_addr;
    logic        mem_reg_write;

    logic        wb_valid;
    logic [31:0] wb_result;
    logic [4:0]  wb_rd_addr;
    logic        wb_reg_write;
    logic        wb_we;

    logic [4:0] ex_rs1_addr;
    logic       forward_from_mem;
    logic       forward_from_wb;
    logic [31:0] ex_operand_a;    

//forwarding 판단로직 추가
assign forward_from_mem =  mem_valid && mem_reg_write;
assign forward_from_wb =  wb_valid && wb_reg_write && (wb_rd_addr == ex_rs1_addr);

always_comb begin
    if(forward_from_mem)
        ex_operand_ad = mem_alu_result; 
    
    else if (forward_form_wb)
        ex_operand_a = wb_result;
    
    else
        ex_operand_a = ex_rs1_data;
end

    mem_wb_reg U_MEM_WB (
        .clk           (clk),
        .reset         (reset),
        .en            (1'b1),

        .valid_in      (mem_valid),
        .result_in     (mem_alu_result),
        .rd_addr_in    (mem_rd_addr),
        .reg_write_in  (mem_reg_write),

        .valid_out     (wb_valid),
        .result_out    (wb_result),
        .rd_addr_out   (wb_rd_addr),
        .reg_write_out (wb_reg_write)
);

// 유효한 명령어이고 쓰기가 허용된 경우에만 저장
assign wb_we = wb_valid && wb_reg_write;




    ex_mem_reg U_EX_MEM (
        .clk            (clk),
        .reset          (reset),
        .en             (1'b1),
        .flush          (1'b0),

        .valid_in       (ex_valid),
        .alu_result_in  (ex_alu_result),
        .rd_addr_in     (ex_rd_addr),
        .reg_write_in   (ex_reg_write),

        .valid_out      (mem_valid),
        .alu_result_out (mem_alu_result),
        .rd_addr_out    (mem_rd_addr),
        .reg_write_out  (mem_reg_write)
);



    alu U_ALU (
        .a      (ex_rs1_data),
        .b      (ex_imm),
        .result (ex_alu_result)
);


    imm_extend U_IMM_EXTEND (
        .instr (id_instr),
        .imm   (id_imm)
);



    reg_file U_REG_FILE (
    .clk      (clk),
    .reset    (reset),

    // 아직 WB가 없으므로 쓰기는 비활성화
    .we       (wb_we),
    .rd_addr  (wb_rd_addr),
    .rd_data  (wb_result),

    // IF/ID에 저장된 명령어에서 번호 추출
    .rs1_addr (id_instr[19:15]),
    .rs2_addr (id_instr[24:20]),
    .rs1_data (id_rs1_data),
    .rs2_data (id_rs2_data)
);
    pc_reg U_PC (
        .clk     (clk),
        .reset   (reset),
        .en      (1'b1),
        .next_pc (pc + 32'd4),
        .pc      (pc)
);

    instruction_rom U_ROM (
        .instr_addr (pc),
        .instr_code (instr_code)
);

    if_id_reg U_IF_ID (
        .clk       (clk),
        .reset     (reset),
        .en        (1'b1),
        .flush     (1'b0),

        .valid_in  (1'b1),
        .pc_in     (pc),
        .instr_in  (instr_code),

        .valid_out (id_valid),
        .pc_out    (id_pc),
        .instr_out (id_instr)
);


    control_unit U_CONTROL_UNIT (
        .instr     (id_instr),
        .reg_write (id_reg_write)
    );
    id_ex_reg U_ID_EX (
        .clk(clk), 
        .reset(reset),

        .rs1_addr_in (id_instr[19:15]),
        .rs1_addr_out (ex_rs1_addr), 
        .en(1'b1), 
        .flush(1'b0),
        .valid_in(id_valid),
        .rs1_data_in(id_rs1_data), 
        .imm_in(id_imm),
        .rd_addr_in(id_instr[11:7]), 
        .reg_write_in(id_reg_write),
        .valid_out(ex_valid),
        .rs1_data_out(ex_rs1_data), 
        .imm_out(ex_imm),
        .rd_addr_out(ex_rd_addr), 
        .reg_write_out(ex_reg_write)
    );

endmodule
