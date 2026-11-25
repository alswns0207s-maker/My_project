module tb_rv32i_top;
    logic clk = 1'b0;
    logic reset = 1'b1;
    logic [7:0] sw = 8'h00;
    logic [7:0] led;

    rv32i_top dut (
        .clk(clk), .reset(reset), .sw(sw), .led(led)
    );

    always #5 clk = ~clk;

    task automatic check_led(input logic [7:0] value);
        begin
            sw = value;
            repeat (24) @(posedge clk);
            if (led !== value)
                $fatal(1, "LED mismatch: sw=%02h led=%02h", value, led);
        end
    endtask

    initial begin
        repeat (4) @(posedge clk);
        reset = 1'b0;
        repeat (40) @(posedge clk);

        if (dut.U_APB_RAM.dmem[0] !== 32'h1234_5678)
            $fatal(1, "RAM test failed: %08h", dut.U_APB_RAM.dmem[0]);

        check_led(8'h01);
        check_led(8'h55);
        check_led(8'hAA);
        check_led(8'hFF);

        $display("PASS: APB RAM and switch-to-LED test completed.");
        $finish;
    end
endmodule
