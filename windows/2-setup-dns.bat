@echo off
rem Runs setup-dns.ps1 as Administrator (UAC prompt).
set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%SCRIPT_DIR%setup-dns.ps1\"'"
