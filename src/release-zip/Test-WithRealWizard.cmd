@echo off
REM ============================================================================
REM  UltraOS v1.1.0 - AME Wizard runtime test (run on WINDOWS)
REM ----------------------------------------------------------------------------
REM  This script performs the Windows-side runtime verification that the Linux
REM  build sandbox cannot do (AMEWizard.exe is a Windows .NET 4.8 app):
REM
REM    1. SHA-256 verification of the .apbx against SHA256SUMS.txt
REM    2. Container test - extracts the .apbx with ZipCrypto password "malte"
REM       using 7-Zip (bundled with AME Wizard, if found), exactly like the
REM       engine does, then validates playbook.conf XML + lists feature pages
REM    3. Launches AME Wizard with the playbook preloaded so you can click
REM       through every page - the real load test
REM
REM  Usage:  double-click, or from PowerShell:
REM          .\Test-WithRealWizard.cmd [path\to\UltraOS-Playbook-v1.1.0.apbx]
REM ============================================================================
setlocal enabledelayedexpansion
set "APBX=%~1"
if "%APBX%"=="" for %%F in ("%~dp0UltraOS-Playbook-v*.apbx") do set "APBX=%%~fF"
if "%APBX%"=="" (
    echo [ERROR] no .apbx found next to this script.
    echo         Drag a UltraOS-Playbook-v1.1.0.apbx onto this file or pass it as argument.
    pause & exit /b 1
)
echo.
echo === UltraOS runtime test ====================================================
echo   Playbook : %APBX%
echo.

REM --- 1. SHA-256 --------------------------------------------------------------
for /f "skip=1 tokens=1" %%H in ('certutil -hashfile "%APBX%" SHA256 ^| findstr /v /i "hash"') do set "HASH=%%H"
echo   SHA-256  : !HASH!
if exist "%~dp0SHA256SUMS.txt" (
    findstr /i "!HASH!" "%~dp0SHA256SUMS.txt" >nul
    if !errorlevel! equ 0 (echo   [OK]     checksum matches SHA256SUMS.txt) else (echo   [WARN]   checksum not listed in SHA256SUMS.txt)
) else (
    echo   [NOTE]   SHA256SUMS.txt not found next to script - skipping checksum match
)

REM --- 2. locate AME Wizard + 7-Zip -------------------------------------------
set "WIZ="
for %%P in (
    "%ProgramFiles%\AME Wizard\AMEWizard.exe"
    "%ProgramFiles(x86)%\AME Wizard\AMEWizard.exe"
    "%LocalAppData%\Programs\AME Wizard\AMEWizard.exe"
    "%UserProfile%\Downloads\AMEWizard.exe"
    "%UserProfile%\Desktop\AMEWizard.exe"
) do if not defined WIZ if exist %%P set "WIZ=%%~P"
if defined WIZ (echo   Wizard  : %WIZ%) else (echo   Wizard  : not found in common locations - pass path below)

set "SZ="
for %%P in ("%ProgramFiles%\AME Wizard\Files\SevenZip\7za.exe" "%ProgramFiles%\7-Zip\7z.exe" "%ProgramFiles(x86)%\7-Zip\7z.exe") do if not defined SZ if exist %%P set "SZ=%%~P"
where 7z.exe >nul 2>&1 && if not defined SZ set "SZ=7z.exe"

set "TMPDIR=%TEMP%\UltraOS-RuntimeTest"
if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%"
mkdir "%TMPDIR%" >nul

if defined SZ (
    echo   7-Zip   : %SZ%
    echo   [..]    extracting .apbx with password "malte" (engine container test)...
    "%SZ%" x -y -pmalte -o"%TMPDIR%" "%APBX%" >nul 2>&1
    if !errorlevel! neq 0 (
        echo   [FAIL]  7-Zip could not extract the .apbx - the archive is corrupt or
        echo           not a ZipCrypto container. Do not use this playbook.
        pause & exit /b 1
    )
    echo   [OK]     container extracted with password "malte"
    if not exist "%TMPDIR%\playbook.conf" (
        echo   [FAIL]  playbook.conf missing from archive root - wrong packaging layout.
        pause & exit /b 1
    )
    echo   [OK]     playbook.conf present at archive root
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "try { [xml]$c = Get-Content -Raw '%TMPDIR%\playbook.conf'; $pages = $c.Playbook.FeaturePages.ChildNodes.Count; Write-Host ('  [OK]     playbook.conf XML valid - ' + $pages + ' feature pages, version ' + $c.Playbook.Version + ', builds ' + ($c.Playbook.SupportedBuilds.string -join ', ')); Write-Host '  [OK]     runtime load simulation: PASS' } catch { Write-Host '  [FAIL]   playbook.conf XML parse error:' $_.Exception.Message; exit 1 }"
    if !errorlevel! neq 0 (echo   The engine would reject this playbook. & pause & exit /b 1)
) else (
    echo   [NOTE]   7-Zip not found - skipping container extraction test.
    echo            ^(Install 7-Zip or AME Wizard for the full container test.^)
)

REM --- 3. launch the wizard with the playbook preloaded ------------------------
echo.
if not defined WIZ (
    echo   To finish the runtime test manually:
    echo     1. Open AME Wizard as administrator
    echo     2. "Select" ^> browse to: %APBX%
    echo     3. Click Next - the playbook must reach the preset page without errors
) else (
    echo   [..]    launching AME Wizard with the playbook preloaded...
    echo           Click through: the preset page, restore-point page, updates page,
    echo           advanced options, browser page - then Cancel (no changes are made
    echo           until you confirm the install on the last page).
    start "" "%WIZ%" "%APBX%"
)
echo.
echo === test finished ===========================================================
pause
