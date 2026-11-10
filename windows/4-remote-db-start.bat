@echo off
rem Foreground tunnel to the VPS databases (close the window to stop)
set "D=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%D%remote-db.ps1" -Action start
