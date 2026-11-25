`timescale 1ns / 1ps

module tb_test(

    );


    integer INTA, INTB, INTC, INTD;
    initial begin
         INTA = -12/4;
         INTB = -'d12/4;
         INTC = -'sd12 /4;
         INTD = -4'sd12/4;
         $display("INTA = %d, INTB = %d, INTC = %d = INTD = %d", INTA, INTB, INTC,INTD);
         #1
         $finish;
    end
endmodule
