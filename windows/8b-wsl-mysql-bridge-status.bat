@echo off
rem Show bridge status
set "D=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%D%wsl-mysql-bridge.ps1" -Action status
