@echo off
setlocal
cd /d "%~dp0"
call xvlog -sv rtl\rv32_pkg.sv rtl\apb_ram.sv rtl\apb_requester.sv rtl\control_unit.sv rtl\datapath.sv rtl\instruction_rom.sv rtl\rv32i_cpu.sv tb_rv32i_sum.sv
if errorlevel 1 exit /b 1
call xelab tb_rv32i_sum -s rv32i_sum --override_timeunit --override_timeprecision --timescale 1ns/1ps
if errorlevel 1 exit /b 1
call xsim rv32i_sum -runall
if errorlevel 1 exit /b 1
findstr /c:"PASS: a=10 sum=55" xsim.log >nul
if errorlevel 1 exit /b 1
exit /b 0
