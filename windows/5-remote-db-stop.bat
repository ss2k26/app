@echo off
rem Stop tunnel / remove portproxy rules
set "D=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%D%remote-db.ps1" -Action stop
