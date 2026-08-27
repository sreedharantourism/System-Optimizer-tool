@echo off
setlocal EnableExtensions
title Sree Laptop Command Center - FINAL DESKTOP WINDOW
cd /d "%~dp0"

net session >nul 2>&1
if not "%errorlevel%"=="0" (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b 0
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Sree_Laptop_Command_Center_FINAL.ps1"

if errorlevel 1 (
    echo.
    echo ======================================================
    echo Sree Laptop Command Center failed to start.
    echo ======================================================
    pause
)
