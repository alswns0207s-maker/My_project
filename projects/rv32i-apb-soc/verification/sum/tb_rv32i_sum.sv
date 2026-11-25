`timescale 1ns/1ps
module tb_rv32i_sum;
    logic clk = 0;
    logic rst_n = 0;
    wire [31:0] pc;
    int a_writes = 0, sum_writes = 0, reads = 0;
    logic previous_selected = 0, previous_enable = 0, previous_ready = 0;
    logic previous_write = 0;
    logic [31:0] previous_addr = 0, previous_data = 0;

    rv32i_top dut(.clk(clk), .rst_n(rst_n), .dbg_pc(pc),
        .dbg_addr(), .dbg_wdata(), .dbg_ready());
    always #5 clk = ~clk;

    // Sample the bus on its transfer edge, before sequential updates.
    always @(posedge clk) begin
        if (rst_n) begin
            if (previous_selected && (!previous_enable || !previous_ready)) begin
                if (dut.PSEL0 !== 1'b1 || dut.PENABLE !== 1'b1 ||
                    dut.PADDR !== previous_addr || dut.PWRITE !== previous_write ||
                    (previous_write && dut.PWDATA !== previous_data))
                    $fatal(1, "APB request changed before completion");
            end
            if (dut.PSEL0 && dut.PENABLE &&
                (!previous_selected || (previous_enable && previous_ready)))
                $fatal(1, "APB ACCESS without a preceding SETUP");

            if (dut.PSEL0 && dut.PENABLE && dut.PREADY0) begin
                if (!dut.PWRITE) begin
                    reads++;
                end else begin
                    case (dut.PADDR)
                        32'h0000_01ec: begin
                            if (a_writes > 10 || dut.PWDATA !== a_writes)
                                $fatal(1, "a store mismatch: expected %0d, got %0d",
                                    a_writes, dut.PWDATA);
                            a_writes++;
                        end
                        32'h0000_01e8: begin
                            if (sum_writes > 10 ||
                                dut.PWDATA !== (sum_writes * (sum_writes + 1) / 2))
                                $fatal(1, "sum store mismatch at iteration %0d: got %0d",
                                    sum_writes, dut.PWDATA);
                            $display("CHECK: sum[%0d] = %0d", sum_writes, dut.PWDATA);
                            sum_writes++;
                        end
                        default: begin end // Function stack and saved registers.
                    endcase
                end
            end
            previous_selected = dut.PSEL0;
            previous_enable = dut.PENABLE;
            previous_ready = dut.PREADY0;
            previous_write = dut.PWRITE;
            previous_addr = dut.PADDR;
            previous_data = dut.PWDATA;
        end
    end

    initial begin
        repeat (4) @(negedge clk);
        rst_n = 1;
        // PC 76 contains the terminal self-jump.
        repeat (5000) begin
            @(negedge clk);
            if (pc === 32'd76) begin
                if (a_writes != 11 || sum_writes != 11 || reads == 0 ||
                    dut.U_APB_BRAM.dmem[123] !== 32'd10 ||
                    dut.U_APB_BRAM.dmem[122] !== 32'd55)
                    $fatal(1, "Final check failed: a=%0d sum=%0d writes=%0d/%0d reads=%0d",
                        dut.U_APB_BRAM.dmem[123], dut.U_APB_BRAM.dmem[122],
                        a_writes, sum_writes, reads);
                $display("PASS: a=10 sum=55, a writes=%0d, sum writes=%0d, APB reads=%0d",
                    a_writes, sum_writes, reads);
                $finish;
            end
        end
        $fatal(1, "Timeout waiting for terminal PC 76; last PC=%0d", pc);
    end
endmodule
