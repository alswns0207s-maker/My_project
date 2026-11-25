`timescale 1ns / 1ps
interface bus_if (
    input logic clk
);

    logic        valid;
    logic        we;
    logic [ 7:0] addr;
    logic [31:0] wdata;
    logic [31:0] rdata;

    clocking cb @(posedge clk);
        default input #1step output #1ns;
        output valid, addr, wdata;
        input rdata;
    endclocking

    modport DUT (input clk, valid, we, addr, wdata, output rdata);
    modport TB  ( output valid, we, addr, wdata);

endinterface

module reg_file (
    bus_if.DUT b
);

    always_ff @(posedge b.clk)
    if (b.valid)
        $display(
            "[dut] =%t: got we = %d, addr = %d, wdata = %d",
            $time,
            b.we,
            b.addr,
            b.wdata
        );

endmodule

module tb_practice_oop_ex7 ();

    logic clk = 0;
    always #5 clk = ~clk;

    bus_if bif(clk);
    reg_file dut(bif);

    initial begin
        $display("[ex7] interface instance connects TB and DUT");
        bif.valid = 0;

        @(posedge clk);
        bif.valid = 1;
        bif.we = 1;
        bif.addr = 8'h10;
        bif.wdata = 32'haabbccdd;
        @(posedge clk);
        bif.addr = 8'h11;
        bif.wdata = 32'h12345678;
        @(posedge clk);
        bif.valid = 0;
        @(posedge clk);
        @(posedge clk);
        $finish;
    end


endmodule