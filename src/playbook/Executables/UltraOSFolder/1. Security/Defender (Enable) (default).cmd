@echo off
:: UltraOS post-install toggle - re-enable Microsoft Defender (recommended)
:: Self-elevating wrapper pattern derived from Atlas-OS/Atlas 'AtlasDesktop' (GPL-3.0)
:: Recovery command for known disable policies from older UltraOS releases.
set "workerScript=%~dp0..\Scripts\defender.ps1"

set "___args="%~f0" %*"
fltmc > nul 2>&1 || (
    echo Administrator privileges are required.
    powershell -c "Start-Process -Verb RunAs -FilePath 'cmd' -ArgumentList """/c $env:___args"""" 2> nul || (
        echo You must run this script as admin.
        if "%*"=="" pause
        exit /b 1
    )
    exit /b
)

if not exist "%workerScript%" (
    echo Script not found.
    echo "%workerScript%"
    pause
    exit /b 1
)

powershell -NoP -EP Bypass -File "%workerScript%" -Enable
set "result=%ERRORLEVEL%"

if "%~1"=="/silent" exit /b %result%

echo.
if not "%result%"=="0" echo Defender recovery was incomplete. Check Windows Security or contact your administrator.
if "%result%"=="0" echo Known Defender overrides were cleared. Verify protection in Windows Security.
echo Press any key to exit...
pause > nul
exit /b %result%
