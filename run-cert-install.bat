@echo off
:: Automatically resolve the current directory and request Administrator elevation
set "SCRIPT_DIR=%~dp0"
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%SCRIPT_DIR%install-cert.ps1\" -ScriptFolder \"%SCRIPT_DIR%\"' -Verb RunAs"
