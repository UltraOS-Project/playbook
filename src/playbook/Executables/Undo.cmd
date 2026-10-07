@echo off
:: Undo.cmd - self-elevating wrapper for UNDO.ps1 (UltraOS partial rollback)
:: UltraOS v1.0.0 - GPL-3.0 - https://github.com/UltraOS-Project/UltraOS
:: Self-elevation pattern written for UltraOS (generic Windows idiom; the Atlas
:: playbook's self-elevating .cmd files, GPL-3.0, served as the reference).
::
:: Restores what can be restored from C:\Windows\UltraOS\Backups:
::   - service startup values
::   - scheduled tasks disabled by the install
:: Removed apps must be reinstalled from the Microsoft Store manually.
:: For a FULL registry rollback use System Restore (rstrui.exe) instead.

setlocal
title UltraOS Undo

:: fltmc requires elevation and is present on all Windows 11 editions (net
:: session depends on the Server service and is unreliable on Home).
fltmc >nul 2>&1
if errorlevel 1 (
    echo Requesting administrator rights...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b 0
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0UNDO.ps1"
set "UNDOEXIT=%errorlevel%"

echo.
if "%UNDOEXIT%"=="0" (
    echo Undo finished. A reboot is recommended.
) else (
    echo Undo reported a problem - read the messages above.
)
pause
exit /b %UNDOEXIT%
