@echo off
cd /d "%~dp0"
if not exist reportes mkdir reportes
techscan64.exe
