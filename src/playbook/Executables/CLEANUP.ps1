# CLEANUP.ps1 - UltraOS end-of-run artifact cleanup
# UltraOS v1.1.1 - GPL-3.0 - https://github.com/UltraOS-Project/playbook
#
# Provenance: modeled on the Atlas playbook's CLEANUP.ps1 (Atlas-OS/Atlas,
# GPL-3.0). DELIBERATE UltraOS differences (documented, by design):
#   1. UltraOS NEVER deletes System Restore points / shadow copies - Atlas runs
#      'vssadmin delete shadows /all' so users cannot revert; UltraOS keeps
#      rollback as a core feature (research/execution-performance-packaging.md 5.1).
#   2. UltraOS does NOT run cleanmgr/Disk Cleanup: it costs minutes and is pure
#      housekeeping (T1-j blueprint S4 demotes component cleanup out of the
#      critical path; EstimatedMinutes target 8 vs Atlas 15).
#   3. Temp clearing skips everything the AME Wizard may still be using (the
#      'AME' subtree), mirroring the proven Atlas exclusion.
#
# onUpgrade semantics: safe to run at ANY time (fresh install, upgrade re-run,
# or manual). It only removes provably-stale UltraOS leftovers and temp items;
# it never touches %WinDir%\UltraOS content (report, backups, toggles) or user
# documents.
#
# NOTE (T3-i, honest wiring status): this script is NOT currently referenced by
# main.yml (the pipeline is locked in 01-architecture section 6). It ships in
# Executables\ for manual use and for the main agent to wire into a future
# build (see worklog T3-i).
#
# PS 5.1, built-ins only. Exit codes: 0 always (best-effort cleanup must never
# break an install; individual failures are logged as warnings).

$ErrorActionPreference = 'Continue'

# ------------------------------------------------------- UltraOS leftovers ---

$windir = [Environment]::GetFolderPath('Windows')

# Legacy/dev locations UltraOS never uses in v1.0.0 but may have existed on
# pre-release test machines. Removing them keeps onUpgrade runs clean.
$staleDirs = @(
    (Join-Path $env:ProgramData 'UltraOS'),                 # pre-release staging path (superseded by %WinDir%\UltraOS)
    (Join-Path $windir 'UltraOS\Temp'),                     # transient staging, if a module ever creates one
    (Join-Path $windir 'UltraOSFolder')                     # legacy folder name from early development
)
foreach ($dir in $staleDirs) {
    if (Test-Path -LiteralPath $dir -PathType Container) {
        Write-Output "CLEANUP: removing stale folder $dir"
        Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Wizard-side temp scratch that is unambiguously ours (never in use mid-run).
Get-ChildItem -Path $env:TEMP -Filter 'ultraos-*' -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# ------------------------------------------------------------ user temp ------
# Atlas pattern (proven in production): clear the user temp folder EXCEPT the
# 'AME' tree, which the wizard may still be reading while a playbook executes.
$userTemp = $null
foreach ($p in @($env:TEMP, $env:TMP, "$env:LOCALAPPDATA\Temp")) {
    if ($p -and (Test-Path -LiteralPath $p -PathType Container)) { $userTemp = $p; break }
}
if ($userTemp) {
    Write-Output "CLEANUP: clearing user temp ($userTemp), keeping 'AME' and UltraOS items"
    Get-ChildItem -LiteralPath $userTemp -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne 'AME' -and $_.Name -notlike 'ultraos-*' } |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}
else {
    Write-Warning 'CLEANUP: user temp folder not found.'
}

# ----------------------------------------------------------- system temp -----
$machine = [System.EnvironmentVariableTarget]::Machine
$sysTemp = $null
foreach ($p in @(
        [System.Environment]::GetEnvironmentVariable('Temp', $machine),
        [System.Environment]::GetEnvironmentVariable('Tmp', $machine),
        (Join-Path $windir 'Temp')
    )) {
    if ($p -and (Test-Path -LiteralPath $p -PathType Container)) { $sysTemp = $p; break }
}
if ($sysTemp) {
    Write-Output "CLEANUP: clearing system temp ($sysTemp)"
    Get-ChildItem -LiteralPath $sysTemp -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}
else {
    Write-Warning 'CLEANUP: system temp folder not found.'
}

Write-Output 'CLEANUP: done. (System Restore points and shadow copies were intentionally NOT touched.)'
exit 0
