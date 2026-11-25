@echo off
setlocal
cd /d "%~dp0"
call xvlog -sv ..\sum\rtl\rv32_pkg.sv ..\sum\rtl\datapath.sv ripple_pc.sv tb_pc4.sv
if errorlevel 1 exit /b 1
call xelab tb_pc4 -s pc4_equivalence --override_timeunit --override_timeprecision --timescale 1ns/1ps
if errorlevel 1 exit /b 1
call xsim pc4_equivalence -runall
if errorlevel 1 exit /b 1
findstr /c:"PASS: 1034 directed and random cases" xsim.log >nul
if errorlevel 1 exit /b 1
exit /b 0
