set signals {
  /tb_rv32i_sum/clk
  /tb_rv32i_sum/rst_n
  /tb_rv32i_sum/pc
  /tb_rv32i_sum/dut/U_RV32I_CPU/U_CONTROL_UNIT/c_state
  /tb_rv32i_sum/dut/transfer
  /tb_rv32i_sum/dut/PSEL0
  /tb_rv32i_sum/dut/PENABLE
  /tb_rv32i_sum/dut/PREADY0
  /tb_rv32i_sum/dut/PWRITE
  /tb_rv32i_sum/dut/PADDR
  /tb_rv32i_sum/dut/PWDATA
  /tb_rv32i_sum/dut/U_APB_BRAM/dmem
}
foreach signal $signals {
    if {[catch {add_wave $signal} message]} {puts "Wave $signal: $message"}
}
run 220 ns
