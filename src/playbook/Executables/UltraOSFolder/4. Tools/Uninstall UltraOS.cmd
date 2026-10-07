@echo off
:: UltraOS uninstaller - runs the undo tool (Scripts\UNDO.ps1) which restores
:: backed-up service states, scheduled tasks and registry values, then removes
:: the UltraOS folder. Self-elevating pattern derived from Atlas-OS/Atlas
:: 'AtlasDesktop' (GPL-3.0): https://github.com/Atlas-OS/Atlas
set "undoScript=%~dp0..\Scripts\UNDO.ps1"

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

if not exist "%undoScript%" (
    echo Undo script not found.
    echo "%undoScript%"
    pause
    exit /b 1
)

echo Running the UltraOS undo tool - restoring services, scheduled tasks and
echo registry values from the backups taken before the install...
echo.
powershell -NoP -EP Bypass -File "%undoScript%"
if errorlevel 1 (
    echo.
    echo The undo tool reported an error - the UltraOS folder was NOT removed.
    echo Review the messages above, fix the issue and run this script again.
    pause
    exit /b 1
)

echo.
echo Undo complete. Removing the UltraOS folder...
:: This folder cannot be deleted while this script runs from it, so a detached
:: helper removes it a few seconds after this window closes.

echo UltraOS has been uninstalled. A reboot is recommended.
if "%~1"=="/silent" goto remove
echo Press any key to exit...
pause > nul
:remove
for %%i in ("%~dp0..") do set "ultraosRoot=%%~fi"
start "" /min powershell -NoP -WindowStyle Hidden -Command "Start-Sleep -Seconds 4; Remove-Item -LiteralPath '%ultraosRoot%' -Recurse -Force -ErrorAction SilentlyContinue"
exit /b 0
