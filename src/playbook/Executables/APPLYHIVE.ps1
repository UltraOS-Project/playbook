# APPLYHIVE.ps1 - mirror HKCU tweaks into the default-user profile
# UltraOS v1.1.1 - GPL-3.0 - https://github.com/UltraOS-Project/playbook
#
# Provenance: pattern derived from the Atlas playbook's APPLYDUHIVE.ps1
# (Atlas-OS/Atlas, GPL-3.0). DELIBERATE UltraOS IMPROVEMENT (T1-j blueprint S7a):
# Atlas parses ~196 tweak YAML files at RUNTIME with a NuGet-downloaded FXPSYaml
# module and copies live HKCU values into the default hive. UltraOS instead
# compiles default-user.reg at BUILD time (scripts/gen-defaultuser-reg.py scans
# Configuration/**/*.yml for HKCU actions), so this script is a single
# reg.exe import: no internet dependency, no module install, no YAML re-parse.
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
# Exit codes: 0 = imported (or skipped because the .reg is missing - the playbook
#                must never fail on this optional mirror step)
#             1 = .reg exists but the import hard-failed (logged by the engine,
#                 never halts the playbook)

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
$null = & "$env:SystemRoot\System32\reg.exe" import "$regFile"
if ($LASTEXITCODE -ne 0) {
    Write-Error "APPLYHIVE: reg.exe import failed with exit code $LASTEXITCODE."
    if ($loadedHere) {
        & "$env:SystemRoot\System32\reg.exe" unload 'HKU\AME_UserHive_Default' | Out-Null
    }
    exit 1
}
Write-Output 'APPLYHIVE: default-user hive updated.'

if ($loadedHere) {
    & "$env:SystemRoot\System32\reg.exe" unload 'HKU\AME_UserHive_Default' | Out-Null
    Write-Output 'APPLYHIVE: hive unloaded (we loaded it as a fallback).'
}
exit 0
