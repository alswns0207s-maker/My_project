`timescale 1ns / 1ps

module axi_master_slave(

    );
endmodule


task axi_write(logic [31:0] addr, logic [31:0] data);
    @(posedge ACLK);
    addr = waddr;
    wdata = data;
    write = 1'b1;
    transfer = 1'b1;
    wait(ready)
    @(posedge ACLK);
    $display("[%0t] AXI WRITE WADDR = %0h", $time, addr, wdata);
    
endtask