@echo off
:: UltraOS - opens the official Microsoft Edge download page, for users who
:: removed Edge with the playbook opt-in and want it back.
:: Reinstall guidance verified in research/known-issues-compatibility.md
:: (T1-h2) section 4.3 - the official installer is the supported path.
start "" "https://www.microsoft.com/edge/download"
echo If the page did not open, visit: https://www.microsoft.com/edge/download
echo.
echo TIP: Edge can also be reinstalled from an elevated terminal with winget:
echo   winget install --id Microsoft.Edge --silent --accept-package-agreements --accept-source-agreements
echo.
echo Press any key to exit...
pause > nul
exit /b 0
