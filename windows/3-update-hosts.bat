@echo off
rem Runs update-hosts.ps1 as Administrator (UAC prompt).
set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%SCRIPT_DIR%update-hosts.ps1\"'"
