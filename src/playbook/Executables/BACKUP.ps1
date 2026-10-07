# BACKUP.ps1 - UltraOS pre-install state snapshot (rollback layer L1 + report baseline)
# UltraOS v1.0.1 - GPL-3.0 - https://github.com/UltraOS-Project/playbook
#
# Provenance: services-export pattern derived from the Atlas playbook's BACKUP.ps1
# (Atlas-OS/Atlas, GPL-3.0); report/baseline design from
# research/execution-performance-packaging.md section 5.2 (L1) and section 6.2.
#
# Snapshots the CURRENT state into %WinDir%\UltraOS\Backups\ BEFORE any tweak runs
# (main.yml step: RESTOREPOINT -> BACKUP -> modules):
#   services-before.reg  full reg.exe export of HKLM\SYSTEM\CurrentControlSet\Services
#   appx-before.txt     one PackageFamilyName per line (all users)
#   tasks-before.csv    TaskPath,TaskName,State of every scheduled task
#   meta.json           build/edition/UltraOS version/preset/timestamp
#
# RE-RUN SEMANTICS (honest): backups are REFRESHED on every playbook run - they
# capture the state immediately before the LATEST run, not the first-ever install.
# (On upgrades start.yml clears %WinDir%\UltraOS first, so stale snapshots cannot
# survive anyway.) For original-stock restoration use the System Restore point
# (RESTOREPOINT.ps1) or the stock-values inventory (Configuration/ultraos/revert.yml).
#
# Runs as TrustedInstaller via main.yml. PS 5.1, built-ins only.
# Exit codes: 0 = ok (non-critical steps may have logged warnings)
#             1 = hard failure: the services export could not be produced
#             (the engine only logs non-zero exits; it never halts the playbook)

$ErrorActionPreference = 'Continue'

$windir = [Environment]::GetFolderPath('Windows')
$backupDir = Join-Path $windir 'UltraOS\Backups'

try {
    New-Item -ItemType Directory -Path $backupDir -Force -ErrorAction Stop | Out-Null
}
catch {
    Write-Error "BACKUP: cannot create backup directory '$backupDir': $($_.Exception.Message)"
    exit 1
}
Write-Output "BACKUP: snapshotting pre-install state to $backupDir"

# ---------------------------------------------------------------- services ---
# Full-tree export (not just Start values): reg import of this file can restore any
# Services-tree value. REPORT.ps1 and UNDO.ps1 parse only the Start dwords.
$servicesReg = Join-Path $backupDir 'services-before.reg'
try {
    $null = & "$env:SystemRoot\System32\reg.exe" export 'HKLM\SYSTEM\CurrentControlSet\Services' "$servicesReg" /y
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $servicesReg)) {
        throw "reg.exe export exited with code $LASTEXITCODE"
    }
    Write-Output "BACKUP: services registry exported -> services-before.reg"
}
catch {
    Write-Error "BACKUP: HARD FAILURE - services registry export failed: $($_.Exception.Message)"
    exit 1
}

# -------------------------------------------------------------------- appx ---
$appxTxt = Join-Path $backupDir 'appx-before.txt'
try {
    # -AllUsers keeps the snapshot context-independent (TrustedInstaller has no
    # interactive profile); falls back to the current context on older builds.
    $packages = $null
    try {
        $packages = Get-AppxPackage -AllUsers -Name '*' -ErrorAction Stop
    }
    catch {
        Write-Warning "BACKUP: Get-AppxPackage -AllUsers failed ($($_.Exception.Message)); retrying in current context."
        $packages = Get-AppxPackage -Name '*' -ErrorAction Stop
    }
    $families = @($packages |
        Where-Object { $_.PackageFamilyName } |
        Select-Object -ExpandProperty PackageFamilyName |
        Sort-Object -Unique)
    # UTF-8 no BOM: reg.exe-style tooling and plain-text diffing both work.
    [System.IO.File]::WriteAllLines($appxTxt, $families, (New-Object System.Text.UTF8Encoding $false))
    Write-Output "BACKUP: $($families.Count) AppX package families listed -> appx-before.txt"
}
catch {
    Write-Warning "BACKUP: AppX snapshot failed: $($_.Exception.Message) - the report will show 'no baseline' for apps."
    if (-not (Test-Path -LiteralPath $appxTxt)) {
        '' | Set-Content -LiteralPath $appxTxt -Encoding ASCII
    }
}

# ------------------------------------------------------------------- tasks ---
$tasksCsv = Join-Path $backupDir 'tasks-before.csv'
try {
    # Some orphaned tasks throw non-terminating errors; SilentlyContinue keeps the rest.
    Get-ScheduledTask -ErrorAction SilentlyContinue |
        Select-Object TaskPath, TaskName, State |
        Export-Csv -Path $tasksCsv -NoTypeInformation -Encoding UTF8
    Write-Output "BACKUP: scheduled task states exported -> tasks-before.csv"
}
catch {
    Write-Warning "BACKUP: scheduled-task snapshot failed: $($_.Exception.Message) - the report will show 'no baseline' for tasks."
    if (-not (Test-Path -LiteralPath $tasksCsv)) {
        '"TaskPath","TaskName","State"' | Set-Content -LiteralPath $tasksCsv -Encoding UTF8
    }
}

# -------------------------------------------------------------------- meta ---
$metaJson = Join-Path $backupDir 'meta.json'
try {
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
    $setup = Get-ItemProperty 'HKLM:\SOFTWARE\UltraOS\SetupOptions' -ErrorAction SilentlyContinue
    $meta = [ordered]@{
        GeneratedAt     = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        ProductName     = $cv.ProductName
        Edition         = $cv.EditionID
        DisplayVersion  = $cv.DisplayVersion
        Build           = ('{0}.{1}' -f $cv.CurrentBuild, $cv.UBR)
        Architecture    = $env:PROCESSOR_ARCHITECTURE
        UltraOSVersion  = $setup.Version
        Preset          = $setup.Preset
    }
    ($meta | ConvertTo-Json) | Set-Content -LiteralPath $metaJson -Encoding UTF8
    Write-Output "BACKUP: installation metadata written -> meta.json"
}
catch {
    Write-Warning "BACKUP: meta.json could not be written: $($_.Exception.Message)"
}

Write-Output 'BACKUP: pre-install snapshot complete.'
exit 0
