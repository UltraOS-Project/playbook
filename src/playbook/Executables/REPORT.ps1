# REPORT.ps1 - UltraOS post-install report (the UltraOS differentiator)
# UltraOS v1.1.0 - GPL-3.0 - https://github.com/UltraOS-Project/playbook
#
# Provenance: report design from research/execution-performance-packaging.md
# section 6.2 (T1-j); diff patterns adapted from the Atlas playbook's appx
# before/after diff (Atlas-OS/Atlas, GPL-3.0). Written from scratch for UltraOS.
#
# WHAT IT DOES
#   1. Reads the pre-run snapshot in %WinDir%\UltraOS\Backups\ created by BACKUP.ps1:
#      services-before.reg, appx-before.txt, tasks-before.csv, meta.json
#   2. Reads the CURRENT state: live services Start values (reg export + parse,
#      Get-CimInstance Win32_Service fallback), current AppX packages, task states
#   3. Reads HKLM\SOFTWARE\UltraOS\SetupOptions (preset, version - written by start.yml)
#   4. Emits %WinDir%\UltraOS\install-report.html (self-contained, inline CSS)
#      and install-report.txt (plain text) - both PS 5.1-safe, no external modules.
#
# Honesty rules baked in: every diff is computed from real before/after data;
# missing baselines are reported as "unavailable" instead of guessed; security
# notes only appear when the live value actually reflects the condition.
#
# Runs as TrustedInstaller via finish.yml. PS 5.1, built-ins only.
# Exit codes: 0 = report generated (possibly with partial data)
#             1 = the report files could not be written at all

$ErrorActionPreference = 'Continue'

$windir   = [Environment]::GetFolderPath('Windows')
$ultraDir = Join-Path $windir 'UltraOS'
$backupDir = Join-Path $ultraDir 'Backups'
$htmlPath = Join-Path $ultraDir 'install-report.html'
$txtPath  = Join-Path $ultraDir 'install-report.txt'
$nl       = "`r`n"

# ------------------------------------------------------------------ helpers ---

function ConvertTo-HtmlEncoded {
    param([string] $Text)
    if ($null -eq $Text) { return '' }
    return ($Text -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;')
}

function Get-StartName {
    # Service Start dword -> human label (same numbering as `sc config`).
    param([int] $Start)
    switch ($Start) {
        0 { return 'Boot' } 1 { return 'System' } 2 { return 'Automatic' }
        3 { return 'Manual' } 4 { return 'Disabled' }
        default { return "Start=$Start" }
    }
}

function Get-ServiceStartFromReg {
    # Parses a reg.exe export of HKLM\SYSTEM\CurrentControlSet\Services into a
    # hashtable: service name -> Start dword. Only direct service keys with a
    # top-level "Start" value are collected (subkeys like \Parameters reset the
    # current key and are ignored). reg.exe exports are UTF-16LE; ReadLines
    # detects the BOM automatically.
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

# ------------------------------------------------------------- before state ---

Write-Output 'REPORT: collecting pre-run baseline from Backups'

$beforeServices = Get-ServiceStartFromReg (Join-Path $backupDir 'services-before.reg')
$hasSvcBaseline = ($beforeServices.Count -gt 0)

$beforeFamilies = @()
$appxTxt = Join-Path $backupDir 'appx-before.txt'
if (Test-Path -LiteralPath $appxTxt) {
    $beforeFamilies = @(Get-Content -LiteralPath $appxTxt -ErrorAction SilentlyContinue |
        Where-Object { $_ -and $_.Trim() } | ForEach-Object { $_.Trim() })
}
$hasAppxBaseline = ($beforeFamilies.Count -gt 0)

$beforeTasks = @()
$tasksCsv = Join-Path $backupDir 'tasks-before.csv'
if (Test-Path -LiteralPath $tasksCsv) {
    try { $beforeTasks = @(Import-Csv -Path $tasksCsv -ErrorAction Stop) } catch {
        Write-Warning "REPORT: could not parse tasks-before.csv: $($_.Exception.Message)"
    }
}
$hasTaskBaseline = ($beforeTasks.Count -gt 0)

$meta = $null
$metaJson = Join-Path $backupDir 'meta.json'
if (Test-Path -LiteralPath $metaJson) {
    try { $meta = Get-Content -LiteralPath $metaJson -Raw | ConvertFrom-Json } catch { $meta = $null }
}

# -------------------------------------------------------------- current state ---

Write-Output 'REPORT: reading current system state'

# Services: reg export + the same parser keeps an exact apples-to-apples Start
# dword comparison (CIM StartMode cannot express delayed-auto as a distinct dword).
$nowServices = @{}
$nowReg = Join-Path ([System.IO.Path]::GetTempPath()) 'ultraos-services-now.reg'
$null = & "$env:SystemRoot\System32\reg.exe" export 'HKLM\SYSTEM\CurrentControlSet\Services' "$nowReg" /y
if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $nowReg)) {
    $nowServices = Get-ServiceStartFromReg $nowReg
    Remove-Item -LiteralPath $nowReg -Force -ErrorAction SilentlyContinue
}
if ($nowServices.Count -eq 0) {
    Write-Warning 'REPORT: live services reg export failed - falling back to Get-CimInstance Win32_Service'
    try {
        Get-CimInstance -ClassName Win32_Service -ErrorAction Stop | ForEach-Object {
            $s = -1
            switch ($_.StartMode) {
                'Boot' { $s = 0 } 'System' { $s = 1 } 'Auto' { $s = 2 }
                'Manual' { $s = 3 } 'Disabled' { $s = 4 } default { $s = -1 }
            }
            if ($s -ge 0) { $nowServices[$_.Name] = $s }
        }
    } catch { Write-Warning "REPORT: Win32_Service query failed: $($_.Exception.Message)" }
}

# AppX: same scope as BACKUP.ps1 (-AllUsers, current-context fallback).
$nowFamilies = @()
try {
    $pkg = $null
    try { $pkg = Get-AppxPackage -AllUsers -Name '*' -ErrorAction Stop }
    catch { $pkg = Get-AppxPackage -Name '*' -ErrorAction Stop }
    $nowFamilies = @($pkg | Where-Object { $_.PackageFamilyName } |
        Select-Object -ExpandProperty PackageFamilyName | Sort-Object -Unique)
}
catch { Write-Warning "REPORT: current AppX query failed: $($_.Exception.Message)" }

# Scheduled tasks: keyed "TaskPath + TaskName" -> State.
$nowTasks = @{}
try {
    Get-ScheduledTask -ErrorAction SilentlyContinue | ForEach-Object {
        $nowTasks["$($_.TaskPath)$($_.TaskName)"] = $_.State
    }
} catch { Write-Warning "REPORT: Get-ScheduledTask failed: $($_.Exception.Message)" }

# Setup markers (written by start.yml before any tweak ran).
$setup = Get-ItemProperty 'HKLM:\SOFTWARE\UltraOS\SetupOptions' -ErrorAction SilentlyContinue
$uVersion = $setup.Version
if (-not $uVersion -and $meta) { $uVersion = $meta.UltraOSVersion }
if (-not $uVersion) { $uVersion = '1.1.0' }
$preset = $setup.Preset
if (-not $preset -and $meta) { $preset = $meta.Preset }
if (-not $preset) { $preset = 'unknown' }
$presetDisplay = (Get-Culture).TextInfo.ToTitleCase($preset)

# Build identity: prefer the baseline meta.json, fall back to the live registry.
$buildLine = $null
if ($meta -and $meta.Build) {
    $buildLine = ('Windows {0} {1} (build {2})' -f $meta.ProductName, $meta.Edition, $meta.Build)
    if ($meta.DisplayVersion) { $buildLine = ('Windows {0} {1} {2} (build {3})' -f $meta.ProductName, $meta.Edition, $meta.DisplayVersion, $meta.Build) }
}
if (-not $buildLine) {
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
    if ($cv) { $buildLine = ('Windows {0} {1} (build {2}.{3})' -f $cv.ProductName, $cv.EditionID, $cv.CurrentBuild, $cv.UBR) }
    else { $buildLine = 'Windows (build unknown)' }
}

# ------------------------------------------------------------------- diffs ---

$svcChanged = @()   # objects: Name, Before, After
$svcRemoved = @()
if ($hasSvcBaseline -and $nowServices.Count -gt 0) {
    foreach ($name in @($beforeServices.Keys)) {
        if (-not $nowServices.ContainsKey($name)) { $svcRemoved += $name; continue }
        if ([int]$nowServices[$name] -ne [int]$beforeServices[$name]) {
            $svcChanged += [PSCustomObject]@{
                Name   = $name
                Before = [int]$beforeServices[$name]
                After  = [int]$nowServices[$name]
            }
        }
    }
    $svcChanged = @($svcChanged | Sort-Object -Property Name)
    $svcRemoved = @($svcRemoved | Sort-Object)
}

$appsRemoved = @()
if ($hasAppxBaseline -and $nowFamilies.Count -gt 0) {
    $appsRemoved = @($beforeFamilies | Where-Object { $nowFamilies -notcontains $_ } | Sort-Object)
}

$tasksDisabled = @()  # strings "TaskPath\TaskName"
$tasksMissing  = @()
if ($hasTaskBaseline -and $nowTasks.Count -gt 0) {
    foreach ($row in $beforeTasks) {
        $key = "$($row.TaskPath)$($row.TaskName)"
        if (-not $nowTasks.ContainsKey($key)) { $tasksMissing += ($key.TrimStart('\')); continue }
        if ("$($row.State)" -ne 'Disabled' -and "$($nowTasks[$key])" -eq 'Disabled') {
            $tasksDisabled += $key.TrimStart('\')
        }
    }
    $tasksDisabled = @($tasksDisabled | Sort-Object)
    $tasksMissing  = @($tasksMissing | Sort-Object)
}

# ---------------------------------------------------------- security notes ---

# Only notes whose condition is verified live - never speculative claims.
$notes = New-Object System.Collections.Generic.List[string]
if ($nowServices.ContainsKey('WinDefend') -and [int]$nowServices['WinDefend'] -eq 4) {
    $notes.Add('Microsoft Defender antimalware (WinDefend) is currently DISABLED. This is only expected if you selected "Keep Defender disabled". You can re-enable it at any time from the Security page of the UltraOS folder or via Windows Security.')
}
$au = (Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -ErrorAction SilentlyContinue).AUOptions
if ([int]$au -eq 2) {
    $notes.Add('Windows Update is set to NOTIFY ONLY (check for updates but do not install automatically). Install updates regularly via Settings > Windows Update.')
}
else {
    $notes.Add('Windows Update is set to AUTOMATIC (default Windows behavior).')
}
try {
    $rp = Get-ComputerRestorePoint -ErrorAction Stop | Sort-Object -Property SequenceNumber | Select-Object -Last 1
    if ($rp) {
        $notes.Add("Latest System Restore point: '$($rp.Description)' ($($rp.CreationTime)). Full registry rollback is available via rstrui.exe if ever needed.")
    }
    else {
        $notes.Add('No System Restore points exist. Consider creating one (search "Create a restore point") before future system changes.')
    }
}
catch {
    $notes.Add('System Restore points could not be enumerated (System Protection may be disabled). A restore point was only created if you selected that option during install.')
}
$fso = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\memory management' -ErrorAction SilentlyContinue).FeatureSettingsOverride
if ([int]$fso -eq 3) {
    $notes.Add('CPU security mitigations (Spectre/Meltdown-class) are DISABLED. Some anti-cheat systems (e.g. Valorant/EAC titles) may refuse to run - re-enable from the Security page of the UltraOS folder before playing such games.')
}
$vbs = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' -ErrorAction SilentlyContinue).EnableVirtualizationBasedSecurity
if ([int]$vbs -eq 0) {
    $notes.Add('Virtualization-Based Security / Core Isolation (HVCI) is DISABLED, which can improve performance at a security cost. Re-enable from the Security page of the UltraOS folder if needed.')
}
$notes.Add('A reboot is recommended so all service and driver changes take full effect.')

# ------------------------------------------------------------- undo guidance ---

$undoLines = @(
    '1. Partial undo - run Undo.cmd in C:\Windows\UltraOS (also linked from the Tools page of the UltraOS folder). It restores service startup values and re-enables the scheduled tasks UltraOS disabled, using the pre-run snapshot in C:\Windows\UltraOS\Backups.'
    '2. Removed apps are NOT reinstalled automatically - reinstall the ones you want from the Microsoft Store (apps.microsoft.com).'
    '3. Registry policy tweaks are not individually inverted by Undo. For a full registry rollback, use System Restore (rstrui.exe) with the point created during install, if one was created.'
    '4. Windows-component-level changes (removed capabilities/packages) can only be fully reverted with a repair install (in-place upgrade using a Windows ISO) - a Windows limitation, not an UltraOS one.'
)

# ------------------------------------------------------------------ HTML render ---

$timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

$svcRows = @()
if ($svcChanged.Count -gt 0) {
    foreach ($c in $svcChanged) {
        $svcRows += ('            <tr><td class="mono">{0}</td><td>{1}</td><td class="changed">{2}</td></tr>' -f (ConvertTo-HtmlEncoded $c.Name), (Get-StartName $c.Before), (Get-StartName $c.After))
    }
}
else {
    $svcRows += '            <tr><td colspan="3" class="muted">No service changes detected (no changes made, or the baseline snapshot is unavailable).</td></tr>'
}

$appsItems = @()
if ($appsRemoved.Count -gt 0) {
    foreach ($a in $appsRemoved) { $appsItems += ('            <li class="mono">{0}</li>' -f (ConvertTo-HtmlEncoded $a)) }
}
else {
    $appsItems += '            <li class="muted">No AppX packages were removed, or the baseline snapshot is unavailable.</li>'
}

$taskItems = @()
if ($tasksDisabled.Count -gt 0) {
    foreach ($t in $tasksDisabled) { $taskItems += ('            <li class="mono">{0}</li>' -f (ConvertTo-HtmlEncoded $t)) }
}
else {
    $taskItems += '            <li class="muted">No scheduled tasks were disabled, or the baseline snapshot is unavailable.</li>'
}

$svcRemovedNote = ''
if ($svcRemoved.Count -gt 0) {
    $svcRemovedNote = ('        <p class="muted">Additionally, {0} baseline service(s) no longer exist on this system (removed outside UltraOS or by the debloat module): {1}</p>' -f $svcRemoved.Count, ((ConvertTo-HtmlEncoded ($svcRemoved -join ', '))))
}
$tasksMissingNote = ''
if ($tasksMissing.Count -gt 0) {
    $tasksMissingNote = ('        <p class="muted">Additionally, {0} baseline task(s) no longer exist (deleted, not just disabled).</p>' -f $tasksMissing.Count)
}

$noteItems = @()
foreach ($n in $notes) { $noteItems += ('            <li>{0}</li>' -f (ConvertTo-HtmlEncoded $n)) }
$undoItems = @()
foreach ($u in $undoLines) { $undoItems += ('            <li>{0}</li>' -f (ConvertTo-HtmlEncoded $u)) }

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>UltraOS $uVersion Install Report</title>
<style>
  body { font-family: 'Segoe UI', system-ui, -apple-system, sans-serif; margin: 0; background: #f2f3f7; color: #22262e; }
  .wrap { max-width: 920px; margin: 0 auto; padding: 0 24px 48px; }
  header { background: linear-gradient(135deg, #1e1b2e 0%, #4c3a8c 70%, #6c5ce7 100%); color: #fff; padding: 36px 24px 28px; }
  header .wrap { padding-bottom: 0; }
  header h1 { margin: 0 0 6px; font-size: 26px; letter-spacing: 0.5px; }
  header .meta { color: #d5d0f0; font-size: 13px; line-height: 1.7; }
  .cards { display: flex; gap: 14px; margin: -22px 0 8px; flex-wrap: wrap; }
  .card { background: #fff; border-radius: 10px; box-shadow: 0 2px 10px rgba(20,15,60,0.10); padding: 16px 22px; min-width: 130px; }
  .card .num { font-size: 28px; font-weight: 600; color: #4c3a8c; }
  .card .lbl { font-size: 12px; color: #6b7280; text-transform: uppercase; letter-spacing: 0.6px; }
  h2 { font-size: 16px; margin: 30px 0 10px; padding-bottom: 6px; border-bottom: 2px solid #6c5ce7; color: #2d2a45; }
  table { border-collapse: collapse; width: 100%; background: #fff; font-size: 13px; box-shadow: 0 1px 5px rgba(20,15,60,0.07); }
  th { background: #2d2a45; color: #fff; text-align: left; padding: 8px 12px; font-weight: 500; }
  td { padding: 6px 12px; border-bottom: 1px solid #eceef4; vertical-align: top; }
  tr:nth-child(even) td { background: #f8f8fc; }
  .mono { font-family: Consolas, 'Cascadia Mono', monospace; font-size: 12.5px; }
  .changed { font-weight: 600; color: #b03040; }
  ul { background: #fff; box-shadow: 0 1px 5px rgba(20,15,60,0.07); margin: 0; padding: 14px 14px 14px 34px; font-size: 13px; line-height: 1.8; }
  .notes li { line-height: 1.6; }
  .muted { color: #6b7280; }
  footer { margin-top: 34px; font-size: 11.5px; color: #8a8f9c; line-height: 1.6; border-top: 1px solid #d9dbe6; padding-top: 12px; }
</style>
</head>
<body>
<header>
  <div class="wrap">
    <h1>UltraOS $uVersion &mdash; Install Report</h1>
    <div class="meta">
      $buildLine<br>
      Preset: <strong>$presetDisplay</strong> &nbsp;&middot;&nbsp; Report generated: $timestamp<br>
      Baseline captured: $(if ($meta) { $meta.GeneratedAt } else { 'not available' }) &nbsp;&middot;&nbsp; Rollback data: C:\Windows\UltraOS\Backups
    </div>
  </div>
</header>
<div class="wrap">
  <div class="cards">
    <div class="card"><div class="num">$($svcChanged.Count)</div><div class="lbl">Services changed</div></div>
    <div class="card"><div class="num">$($appsRemoved.Count)</div><div class="lbl">Apps removed</div></div>
    <div class="card"><div class="num">$($tasksDisabled.Count)</div><div class="lbl">Tasks disabled</div></div>
  </div>

  <h2>Services changed</h2>
  <table>
    <tr><th style="width:45%">Service</th><th style="width:25%">Before UltraOS</th><th style="width:30%">Now</th></tr>
$($svcRows -join "`r`n")
  </table>
$svcRemovedNote

  <h2>Apps removed ($($appsRemoved.Count))</h2>
  <ul>
$($appsItems -join "`r`n")
  </ul>

  <h2>Scheduled tasks disabled ($($tasksDisabled.Count))</h2>
  <ul>
$($taskItems -join "`r`n")
  </ul>
$tasksMissingNote

  <h2>Security notes</h2>
  <ul class="notes">
$($noteItems -join "`r`n")
  </ul>

  <h2>Undo &amp; rollback</h2>
  <ul>
$($undoItems -join "`r`n")
  </ul>

  <footer>
    Generated by UltraOS $uVersion (GPL-3.0) &middot; https://github.com/UltraOS-Project/playbook<br>
    UltraOS is derived from the Atlas playbook by AtlasOS contributors (https://github.com/Atlas-OS/Atlas).<br>
    This report is a point-in-time diff generated on this machine. Plain-text copy: install-report.txt.
  </footer>
</div>
</body>
</html>
"@

# ------------------------------------------------------------------- TXT render ---

function Get-Padded([string] $Text, [int] $Width) {
    if ($Text.Length -ge $Width) { return $Text }
    return $Text + (' ' * ($Width - $Text.Length))
}

$txt = New-Object System.Collections.Generic.List[string]
$txt.Add('==================================================================')
$txt.Add(" ULTRAOS $uVersion - INSTALL REPORT")
$txt.Add('==================================================================')
$txt.Add(" Generated      : $timestamp")
$txt.Add(" System         : $buildLine")
$txt.Add(" Preset         : $presetDisplay")
if ($meta) { $txt.Add(" Baseline taken : $($meta.GeneratedAt)") }
$txt.Add(" Backups        : C:\Windows\UltraOS\Backups")
$txt.Add('')
$txt.Add(" SUMMARY: $($svcChanged.Count) services changed | $($appsRemoved.Count) apps removed | $($tasksDisabled.Count) tasks disabled")
$txt.Add('')
$txt.Add('------------------------------------------------------------------')
$txt.Add(' SERVICES CHANGED')
$txt.Add('------------------------------------------------------------------')
if ($svcChanged.Count -gt 0) {
    foreach ($c in $svcChanged) {
        $txt.Add(('   ' + (Get-Padded $c.Name 45) + (Get-Padded (Get-StartName $c.Before) 12) + ' -> ' + (Get-StartName $c.After)))
    }
}
else { $txt.Add('   No service changes detected (no changes made, or baseline unavailable).') }
if ($svcRemoved.Count -gt 0) { $txt.Add("   [note] $($svcRemoved.Count) baseline service(s) no longer exist: $($svcRemoved -join ', ')") }
$txt.Add('')
$txt.Add('------------------------------------------------------------------')
$txt.Add(" APPS REMOVED ($($appsRemoved.Count))")
$txt.Add('------------------------------------------------------------------')
if ($appsRemoved.Count -gt 0) {
    foreach ($a in $appsRemoved) { $txt.Add("   $a") }
    $txt.Add('   Reinstall via the Microsoft Store: https://apps.microsoft.com/search?query=<name>')
}
else { $txt.Add('   No AppX packages were removed, or baseline unavailable.') }
$txt.Add('')
$txt.Add('------------------------------------------------------------------')
$txt.Add(" SCHEDULED TASKS DISABLED ($($tasksDisabled.Count))")
$txt.Add('------------------------------------------------------------------')
if ($tasksDisabled.Count -gt 0) {
    foreach ($t in $tasksDisabled) { $txt.Add("   $t") }
}
else { $txt.Add('   No scheduled tasks were disabled, or baseline unavailable.') }
if ($tasksMissing.Count -gt 0) { $txt.Add("   [note] $($tasksMissing.Count) baseline task(s) were deleted entirely.") }
$txt.Add('')
$txt.Add('------------------------------------------------------------------')
$txt.Add(' SECURITY NOTES')
$txt.Add('------------------------------------------------------------------')
foreach ($n in $notes) { $txt.Add(" * $n") }
$txt.Add('')
$txt.Add('------------------------------------------------------------------')
$txt.Add(' UNDO & ROLLBACK')
$txt.Add('------------------------------------------------------------------')
foreach ($u in $undoLines) { $txt.Add(" $u") }
$txt.Add('')
$txt.Add('------------------------------------------------------------------')
$txt.Add(" Generated by UltraOS $uVersion (GPL-3.0) - https://github.com/UltraOS-Project/playbook")
$txt.Add(' UltraOS is derived from the Atlas playbook by AtlasOS contributors.')
$txt.Add('==================================================================')

# --------------------------------------------------------------------- write ---

try {
    if (-not (Test-Path -LiteralPath $ultraDir)) {
        New-Item -ItemType Directory -Path $ultraDir -Force -ErrorAction Stop | Out-Null
    }
    [System.IO.File]::WriteAllText($htmlPath, $html, (New-Object System.Text.UTF8Encoding $false))
    [System.IO.File]::WriteAllLines($txtPath, $txt, (New-Object System.Text.UTF8Encoding $true))
}
catch {
    Write-Error "REPORT: could not write report files: $($_.Exception.Message)"
    exit 1
}

Write-Output "REPORT: $htmlPath"
Write-Output "REPORT: $txtPath"
Write-Output "REPORT: $($svcChanged.Count) services changed, $($appsRemoved.Count) apps removed, $($tasksDisabled.Count) tasks disabled."
exit 0
