@echo off
cd /d "%~dp0"
set /p "AIRGESTURE_PI=Pi IP address: "
py pc_companion.py --pi "%AIRGESTURE_PI%"
pause
