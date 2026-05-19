@echo off
title JARVIS Workspace - Installer
color 0A
echo.
echo   ============================================
echo     J.A.R.V.I.S  WORKSPACE  ^|  INSTALLER
echo   ============================================
echo.
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0Install.ps1"
echo.
pause
