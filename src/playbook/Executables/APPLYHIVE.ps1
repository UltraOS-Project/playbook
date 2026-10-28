# APPLYHIVE.ps1 - mirror HKCU tweaks into the default-user profile
# UltraOS v1.2.0 - GPL-3.0 - https://github.com/UltraOS-Project/playbook
#
# Provenance: pattern derived from the Atlas playbook's APPLYDUHIVE.ps1
# (Atlas-OS/Atlas, GPL-3.0). DELIBERATE UltraOS IMPROVEMENT (T1-j blueprint S7a):
# Atlas parses ~196 tweak YAML files at RUNTIME with a NuGet-downloaded FXPSYaml
# module and copies live HKCU values into the default hive. UltraOS instead
# compiles default-user.reg at BUILD time (scripts/gen-defaultuser-reg.py scans
# Configuration/**/*.yml for HKCU actions), so this script imports one
# registry section at a time: no internet dependency, no module install,
# no YAML re-parse.
#
# main.yml loads C:\Users\Default\NTUSER.DAT as HKU\AME_UserHive_Default before
# this runs. default-user.reg contains [HKEY_USERS\AME_UserHive_Default\...] key
# sections mirroring every HKCU registryValue/registryKey action of the playbook.
#
# HONEST LIMITATION (documented, accepted for v1.0.0): the generated .reg is a
# SUPERSET across presets/options - build-time compilation cannot know which
# wizard options the user selects at runtime, so the default profile receives
# every HKCU action (e.g. privacy-positive ones regardless of preset). Live-user
# gating remains exact (the engine applies those actions with option gates).
# Per-preset default-user hives are a v1.1 roadmap item.
#
# Runs as currentUserElevated via main.yml. PS 5.1, built-ins only.
# Exit codes: 0 = imported, or completed with per-section warnings (this mirror is
#                optional and must not halt the main install)
#             1 = the hive could not be loaded or the .reg could not be read

$ErrorActionPreference = 'Continue'

$regFile = Join-Path $PSScriptRoot 'default-user.reg'

if (-not (Test-Path -LiteralPath $regFile)) {
    # Missing build artifact (e.g. a dev build that skipped gen-defaultuser-reg.py).
    # Mirroring the default profile is optional - warn and let the playbook continue.
    Write-Warning "APPLYHIVE: default-user.reg not found in $PSScriptRoot - skipping default-user mirror. Run scripts/gen-defaultuser-reg.py when building the playbook."
    exit 0
}

$hiveLoaded = Test-Path 'Registry::HKEY_USERS\AME_UserHive_Default'
$loadedHere = $false
if (-not $hiveLoaded) {
    # Fallback: main.yml normally loads the hive (skipped in OOBE flows). If the
    # engine did not, load it ourselves from the default profile, and remember to
    # unload it again so we never leave NTUSER.DAT locked.
    Write-Output 'APPLYHIVE: default hive not loaded yet - loading C:\Users\Default\NTUSER.DAT'
    & "$env:SystemRoot\System32\reg.exe" load 'HKU\AME_UserHive_Default' "$env:SystemDrive\Users\Default\NTUSER.DAT"
    if ($LASTEXITCODE -eq 0 -and (Test-Path 'Registry::HKEY_USERS\AME_UserHive_Default')) {
        $loadedHere = $true
    }
    else {
        Write-Error "APPLYHIVE: failed to load the default-user hive (reg.exe exit $LASTEXITCODE)."
        exit 1
    }
}

Write-Output "APPLYHIVE: importing $regFile into HKU\AME_UserHive_Default"
try {
    $lines = Get-Content -LiteralPath $regFile -Encoding Unicode -ErrorAction Stop
}
catch {
    Write-Error "APPLYHIVE: could not read default-user registry file: $($_.Exception.Message)"
    if ($loadedHere) {
        $unloadOutput = & "$env:SystemRoot\System32\reg.exe" unload 'HKU\AME_UserHive_Default' 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "APPLYHIVE: failed to unload default-user hive: $($unloadOutput -join ' ')"
        }
    }
    exit 1
}
$sections = New-Object System.Collections.Generic.List[object]
$currentSection = $null
foreach ($line in $lines) {
    if ($line -match '^\[.*\]$') {
        if ($null -ne $currentSection) {
            $sections.Add([object]($currentSection.ToArray()))
        }
        $currentSection = New-Object System.Collections.Generic.List[string]
        $currentSection.Add('Windows Registry Editor Version 5.00')
        $currentSection.Add('')
        $currentSection.Add($line)
    }
    elseif ($null -ne $currentSection) {
        $currentSection.Add($line)
    }
}
if ($null -ne $currentSection) {
    $sections.Add([object]($currentSection.ToArray()))
}
if ($sections.Count -eq 0) {
    Write-Error 'APPLYHIVE: default-user registry file contained no key sections.'
    if ($loadedHere) {
        $unloadOutput = & "$env:SystemRoot\System32\reg.exe" unload 'HKU\AME_UserHive_Default' 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "APPLYHIVE: failed to unload default-user hive: $($unloadOutput -join ' ')"
        }
    }
    exit 1
}

$failedSections = New-Object System.Collections.Generic.List[string]
$tempFile = Join-Path $env:TEMP "UltraOS-default-user-$PID.reg"
try {
    for ($i = 0; $i -lt $sections.Count; $i++) {
        $block = [string[]]$sections[$i]
        $sectionName = $block | Where-Object { $_ -match '^\[.*\]$' } | Select-Object -First 1
        [System.IO.File]::WriteAllLines($tempFile, $block, [System.Text.Encoding]::Unicode)
        $output = & "$env:SystemRoot\System32\reg.exe" import $tempFile 2>&1
        if ($LASTEXITCODE -ne 0) {
            $failedSections.Add($sectionName)
            Write-Warning "APPLYHIVE: registry section $sectionName reported errors (reg.exe exit $LASTEXITCODE): $($output -join ' ')"
        }
    }
}
finally {
    try {
        if (Test-Path -LiteralPath $tempFile) {
            Remove-Item -LiteralPath $tempFile -Force -ErrorAction Stop
        }
    }
    catch {
        Write-Warning "APPLYHIVE: could not remove temporary registry file $tempFile : $($_.Exception.Message)"
    }
    if ($loadedHere) {
        $unloadOutput = & "$env:SystemRoot\System32\reg.exe" unload 'HKU\AME_UserHive_Default' 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "APPLYHIVE: failed to unload default-user hive: $($unloadOutput -join ' ')"
        }
    }
}

if ($failedSections.Count -gt 0) {
    Write-Warning "APPLYHIVE: completed with $($failedSections.Count) registry section(s) reporting errors; other default-user settings were applied. Review the warnings above."
    if ($failedSections.Count -eq $sections.Count) {
        Write-Error 'APPLYHIVE: every default-user registry section reported errors; no settings could be confirmed as applied.'
        exit 1
    }
}
else {
    Write-Output 'APPLYHIVE: default-user hive updated.'
}

exit 0
