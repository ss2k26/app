@echo off
rem Remove the WSL MySQL bridge
set "D=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%D%wsl-mysql-bridge.ps1" -Action stop
