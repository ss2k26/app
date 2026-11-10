@echo off
rem Let WSL/Docker apps reach Windows MySQL as 127.0.0.1 (UAC prompt)
set "D=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%D%wsl-mysql-bridge.ps1" -Action start
