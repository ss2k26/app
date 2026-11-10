@echo off
rem Re-create the bridge at every Windows logon
set "D=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%D%wsl-mysql-bridge.ps1" -Action install
