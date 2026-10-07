# UNDO.ps1 - UltraOS partial rollback (run via Undo.cmd, or the Tools page of
#            the UltraOS folder)
# UltraOS v1.1.0 - GPL-3.0 - https://github.com/UltraOS-Project/playbook
#
# Provenance: rollback design research/execution-performance-packaging.md 5.2;
# services-Start restore pattern derived from the Atlas playbook's BACKUP.ps1 +
# 'Set services to defaults' flow (Atlas-OS/Atlas, GPL-3.0).
#
# SCOPE - HONEST STATEMENT (read before promising anything to users):
#   FULLY RESTORED by this script:
#     - Service startup values: every service whose Start value differs from the
#       pre-run snapshot (Backups\services-before.reg) is restored to it.
#     - Scheduled tasks: every task the run disabled (was Ready/Running in the
#       snapshot, is Disabled now) is re-enabled.
#   PARTIALLY RESTORED:
#     - Nothing else. Registry policy tweaks, visual preferences and network
#       settings are NOT individually inverted here (they are documented in the
#       playbook's Configuration/ultraos/revert.yml stock-values inventory, but
#       applying them requires the AME Wizard engine, not this script).
#   NOT RESTORED (manual action):
#     - Removed AppX apps: reinstall from the Microsoft Store (this script prints
#       the removed list + Store search links).
#     - Windows-component-level changes (optional extras): only a repair install
#       (in-place upgrade with a Windows ISO) fully reverts those.
#   FULL REGISTRY ROLLBACK ALTERNATIVE: if a System Restore point was created
#   during install (recommended default), rstrui.exe restores ALL registry state
#   at once - see the note this script prints at the end.
#
# SAFETY: service restores are Start-VALUE-ONLY imports. The full
# services-before.reg tree is deliberately NOT blind-imported: if Windows
# servicing changed a service between install and undo, re-importing old
# ImagePath/Security blobs would corrupt it. (Same reasoning as Atlas's
# Start-only winServices.reg.)
#
# PS 5.1, built-ins only. Exit codes: 0 = undo ran (warnings possible)
#             1 = not elevated, or no baseline snapshot found.

$ErrorActionPreference = 'Continue'

# --------------------------------------------------------------- elevation ----

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error 'UNDO: administrator rights are required. Run Undo.cmd (it self-elevates) instead of UNDO.ps1 directly.'
    exit 1
}

# --------------------------------------------------------------- baselines ----

$windir = [Environment]::GetFolderPath('Windows')
$backupDir = Join-Path $windir 'UltraOS\Backups'
$servicesReg = Join-Path $backupDir 'services-before.reg'
$tasksCsv = Join-Path $backupDir 'tasks-before.csv'
$appxTxt = Join-Path $backupDir 'appx-before.txt'

if (-not (Test-Path -LiteralPath $servicesReg)) {
    Write-Error "UNDO: baseline snapshot not found ($servicesReg). Nothing to undo - either UltraOS was never installed on this machine, or the backups were deleted."
    exit 1
}
Write-Output "UNDO: using baseline snapshot from $backupDir"

# ---------------------------------------------------------------- helpers -----

function Get-ServiceStartFromReg {
    # Same parser as REPORT.ps1: reg.exe export -> service name -> Start dword.
    param([string] $Path)
    $result = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $result }
    $currentKey = $null
    foreach ($line in [System.IO.File]::ReadLines($Path)) {
        $keyMatch = [regex]::Match($line, '^\[(.+)\]\s*$')
        if ($keyMatch.Success) { $currentKey = $keyMatch.Groups[1].Value; continue }
        if ($currentKey) {
            $svcMatch = [regex]::Match($currentKey, '^HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Services\\([^\\]+)$')
            if ($svcMatch.Success) {
                $startMatch = [regex]::Match($line, '^"Start"=dword:([0-9A-Fa-f]{8})')
                if ($startMatch.Success) {
                    $result[$svcMatch.Groups[1].Value] = [Convert]::ToInt32($startMatch.Groups[1].Value, 16)
                }
            }
        }
    }
    return $result
}

$beforeServices = Get-ServiceStartFromReg $servicesReg
Write-Output "UNDO: baseline contains $($beforeServices.Count) services."

# ------------------------------------------------------------- 1. services ----

Write-Output 'UNDO: [1/3] restoring service startup values...'

# Current Start values, read the same way as the baseline (apples-to-apples).
$nowServices = @{}
$nowReg = Join-Path ([System.IO.Path]::GetTempPath()) 'ultraos-undo-now.reg'
$null = & "$env:SystemRoot\System32\reg.exe" export 'HKLM\SYSTEM\CurrentControlSet\Services' "$nowReg" /y
if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $nowReg)) {
    $nowServices = Get-ServiceStartFromReg $nowReg
    Remove-Item -LiteralPath $nowReg -Force -ErrorAction SilentlyContinue
}
if ($nowServices.Count -eq 0) {
    Write-Warning 'UNDO: could not read current service values - services step skipped.'
}

$toRestore = @()
if ($nowServices.Count -gt 0) {
    foreach ($name in @($beforeServices.Keys)) {
        if ($nowServices.ContainsKey($name) -and [int]$nowServices[$name] -ne [int]$beforeServices[$name]) {
            $toRestore += [PSCustomObject]@{ Name = $name; Start = [int]$beforeServices[$name] }
        }
    }
}

if ($toRestore.Count -eq 0) {
    Write-Output 'UNDO: no service startup values need restoring (already at baseline).'
}
else {
    # Generate a Start-only .reg (UTF-8 no BOM - reg.exe requirement, same as Atlas BACKUP.ps1).
    $undoReg = Join-Path ([System.IO.Path]::GetTempPath()) 'ultraos-undo-start.reg'
    $content = New-Object System.Collections.Generic.List[string]
    $content.Add('Windows Registry Editor Version 5.00')
    foreach ($svc in ($toRestore | Sort-Object -Property Name)) {
        $content.Add('')
        $content.Add("[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\$($svc.Name)]")
        $content.Add(('"Start"=dword:{0:x8}' -f $svc.Start))
        Write-Output ("UNDO:   {0} -> {1}" -f $svc.Name, $svc.Start)
    }
    [System.IO.File]::WriteAllLines($undoReg, $content, (New-Object System.Text.UTF8Encoding $false))
    $null = & "$env:SystemRoot\System32\reg.exe" import "$undoReg"
    if ($LASTEXITCODE -eq 0) {
        Write-Output "UNDO: $($toRestore.Count) service startup value(s) restored (effective after reboot)."
    }
    else {
        Write-Error "UNDO: reg.exe import failed with exit code $LASTEXITCODE - services NOT restored."
    }
    Remove-Item -LiteralPath $undoReg -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------- 2. tasks ----

Write-Output 'UNDO: [2/3] re-enabling scheduled tasks...'

$enabledCount = 0
$failedCount = 0
if (Test-Path -LiteralPath $tasksCsv) {
    $beforeTasks = @()
    try { $beforeTasks = @(Import-Csv -Path $tasksCsv -ErrorAction Stop) } catch {
        Write-Warning "UNDO: could not parse tasks-before.csv: $($_.Exception.Message)"
    }
    $nowTasks = @{}
    try {
        Get-ScheduledTask -ErrorAction SilentlyContinue | ForEach-Object {
            $nowTasks["$($_.TaskPath)$($_.TaskName)"] = $_.State
        }
    } catch { Write-Warning "UNDO: Get-ScheduledTask failed: $($_.Exception.Message)" }

    foreach ($row in $beforeTasks) {
        $key = "$($row.TaskPath)$($row.TaskName)"
        if (-not $nowTasks.ContainsKey($key)) { continue }
        if ("$($row.State)" -ne 'Disabled' -and "$($nowTasks[$key])" -eq 'Disabled') {
            try {
                Enable-ScheduledTask -TaskPath $row.TaskPath -TaskName $row.TaskName -ErrorAction Stop | Out-Null
                Write-Output "UNDO:   re-enabled $($key.TrimStart('\'))"
                $enabledCount++
            }
            catch {
                Write-Warning "UNDO:   could not re-enable $($key.TrimStart('\')): $($_.Exception.Message)"
                $failedCount++
            }
        }
    }
}
else {
    Write-Warning 'UNDO: tasks-before.csv not found - tasks step skipped.'
}
Write-Output "UNDO: $enabledCount task(s) re-enabled, $failedCount failure(s)."

# ---------------------------------------------------------------- 3. appx ----

Write-Output 'UNDO: [3/3] checking removed apps (manual reinstall required)...'

if (Test-Path -LiteralPath $appxTxt) {
    $beforeFamilies = @(Get-Content -LiteralPath $appxTxt -ErrorAction SilentlyContinue |
        Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_.Trim() })
    $nowFamilies = @()
    try {
        $pkg = $null
        try { $pkg = Get-AppxPackage -AllUsers -Name '*' -ErrorAction Stop }
        catch { $pkg = Get-AppxPackage -Name '*' -ErrorAction Stop }
        $nowFamilies = @($pkg | Where-Object { $_.PackageFamilyName } |
            Select-Object -ExpandProperty PackageFamilyName | Sort-Object -Unique)
    }
    catch { Write-Warning "UNDO: current AppX query failed: $($_.Exception.Message)" }

    if ($nowFamilies.Count -gt 0) {
        $removed = @($beforeFamilies | Where-Object { $nowFamilies -notcontains $_ } | Sort-Object)
        if ($removed.Count -eq 0) {
            Write-Output 'UNDO: no AppX packages are missing relative to the baseline.'
        }
        else {
            Write-Output "UNDO: the following $($removed.Count) app(s) were removed and must be reinstalled MANUALLY:"
            foreach ($fam in $removed) { Write-Output "UNDO:   $fam" }
            Write-Output 'UNDO: reinstall them from the Microsoft Store:'
            Write-Output 'UNDO:   - open the Store app, or'
            Write-Output 'UNDO:   - https://apps.microsoft.com/search?query=<part of the name>'
        }
    }
}
else {
    Write-Warning 'UNDO: appx-before.txt not found - app check skipped.'
}

# ------------------------------------------------------------------- notes ----

Write-Output ''
Write-Output 'UNDO: DONE (partial - see the scope notes at the top of this script).'
Write-Output 'UNDO: - Registry policy tweaks and visual preferences were NOT inverted. For a full registry'
Write-Output 'UNDO:   rollback use System Restore: run rstrui.exe and pick the "UltraOS v1.1.0" point'
Write-Output 'UNDO:   created during install (if that option was selected).'
Write-Output 'UNDO: - A REBOOT is recommended so restored service startup values take effect.'
Write-Output 'UNDO: - See install-report.html / install-report.txt in the same folder for what changed.'
exit 0
