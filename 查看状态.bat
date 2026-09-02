@echo off
chcp 65001 >nul
echo ============================================
echo   ZCode - status
echo ============================================
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0deploy.ps1" status
echo.
echo Closing in 10 seconds...
ping -n 11 127.0.0.1 >nul 2>&1
exit