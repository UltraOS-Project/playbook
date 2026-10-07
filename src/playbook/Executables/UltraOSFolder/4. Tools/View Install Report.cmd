@echo off
:: UltraOS - opens the install report generated at the end of the playbook run
:: (C:\Windows\UltraOS\install-report.html, plain-text .txt fallback).
:: No administrator rights required - this only opens a file.
setlocal
set "report=%WinDir%\UltraOS\install-report.html"
if exist "%report%" goto open
set "report=%WinDir%\UltraOS\install-report.txt"
if exist "%report%" goto open
echo The install report was not found:
echo   %WinDir%\UltraOS\install-report.html
echo.
echo It is generated at the very end of the UltraOS install. If it is missing,
echo re-run the UltraOS playbook and let it finish.
pause
exit /b 1
:open
start "" "%report%"
endlocal
exit /b 0
