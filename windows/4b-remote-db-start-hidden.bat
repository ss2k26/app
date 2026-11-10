@echo off
rem Same, but hidden in the background
set "D=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%D%remote-db.ps1" -Action start -Background
