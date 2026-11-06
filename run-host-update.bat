@echo off
:: Resolves the directory path and strips out potential parsing trailing spaces natively
set "SCRIPT_DIR=%~dp0"
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%SCRIPT_DIR%update-hosts.ps1\" -ScriptFolder \"%SCRIPT_DIR%\"' -Verb RunAs"
