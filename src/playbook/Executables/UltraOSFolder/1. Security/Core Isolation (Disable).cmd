@echo off
:: UltraOS post-install toggle - disable Core Isolation / VBS (breaks Valorant, WSL2, Docker - not recommended)
:: Self-elevating wrapper pattern derived from Atlas-OS/Atlas 'AtlasDesktop' (GPL-3.0)
:: https://github.com/Atlas-OS/Atlas - adapted for UltraOS, state markers under
:: HKLM\SOFTWARE\UltraOS\SetupOptions instead of AtlasOS\Services.
:: Provenance: research/atlas-playbook-analysis.md (T1-a section 6.2) + T1-g + Atlas ConfigVBS.ps1 (24H2 forced-value pattern)
set "settingName=CoreIsolation"
set "stateValue=0"
set "scriptPath=%~f0"
set "workerScript=%~dp0..\Scripts\vbs.ps1"

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

:: State marker - read by the install report and undo tooling
reg add "HKLM\SOFTWARE\UltraOS\SetupOptions\%settingName%" /v state /t REG_DWORD /d %stateValue% /f > nul
reg add "HKLM\SOFTWARE\UltraOS\SetupOptions\%settingName%" /v path /t REG_SZ /d "%scriptPath%" /f > nul

powershell -NoP -EP Bypass -File "%workerScript%" -Disable

if "%~1"=="/silent" exit /b

echo.
echo Core Isolation (VBS) has been disabled - reboot to apply. Valorant/FACEIT/WSL2/Docker will not work while it is off.
echo Press any key to exit...
pause > nul
exit /b
