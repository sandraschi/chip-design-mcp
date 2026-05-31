@echo off
cd /d "%~dp0"

set "PATH=%PATH%;%LOCALAPPDATA%\Microsoft\WindowsApps"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0webapp\start.ps1" %*
echo Exit code: %ERRORLEVEL%
if %ERRORLEVEL% NEQ 0 pause
