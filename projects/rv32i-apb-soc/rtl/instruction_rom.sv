module instruction_rom #(
    parameter MEM_FILE = "rom_code_apb_gpio.mem"
) (
    input  logic [31:0] instr_addr,
    output logic [31:0] instr_code
);
    logic [31:0] instr_rom [0:63];
    integer i;

    initial begin
        for (i = 0; i < 64; i = i + 1)
            instr_rom[i] = 32'h0000_0013;
        $readmemh(MEM_FILE, instr_rom);
    end

    assign instr_code = instr_rom[instr_addr[7:2]];
endmodule
