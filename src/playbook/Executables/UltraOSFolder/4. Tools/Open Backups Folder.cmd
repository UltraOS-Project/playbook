@echo off
:: UltraOS - opens the pre-install backups folder (C:\Windows\UltraOS\Backups)
:: with the services/appx/tasks snapshots used by the uninstall tool.
:: No administrator rights required - this only opens File Explorer.
if not exist "%WinDir%\UltraOS\Backups" (
    echo The backups folder was not found:
    echo   %WinDir%\UltraOS\Backups
    echo.
    echo It is created during the UltraOS install. If it is missing, re-run
    echo the UltraOS playbook and let it finish.
    pause
    exit /b 1
)
start "" explorer.exe "%WinDir%\UltraOS\Backups"
exit /b 0
