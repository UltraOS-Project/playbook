# ===========================================================================================
# UltraOS EDGE-UNLOCK.ps1 - removes Microsoft Edge using Edge's own uninstaller
# ===========================================================================================
# Called by: Configuration/tweaks/debloat/edge-removal.yml (option: opt-uninstall-edge)
# Context:   runs as the elevated current user via AME Wizard (runas: currentUserElevated).
#            Edge's setup.exe is known to misbehave under SYSTEM/TrustedInstaller
#            contexts (T1-h2 4.1), so this script is deliberately NOT run as TI.
#
# Mechanism (research/known-issues-compatibility.md 9.2 + 4.1, research/debloat-apps-research.md 8.12):
#   1. The playbook YAML has already applied the registry unlock (EdgeUpdateDev
#      AllowUninstall in both registry views + NoRemove deletes) before this script.
#   2. This script creates the BrowserReplacement stub (an empty MicrosoftEdge.exe in
#      the legacy UWP Edge SystemApps folder), which unlocks uninstallation outside
#      EEA/DMA regions. Mechanism idea documented in winutil (MIT) and ReviOS (CC
#      BY-SA - ideas only, zero code copied); implemented from scratch for UltraOS.
#   3. Locates setup.exe under Program Files (x86)\Microsoft\Edge\Application\<version>\
#      Installer\ (registry UninstallString fallback) and runs:
#        setup.exe --uninstall --system-level --force-uninstall
#   4. The YAML then sweeps the Edge AppX families and writes Deprovisioned keys.
#
# Known risks (documented in the playbook file header too):
#   - "Removing Edge may cause update failure loop. Install Edge, install all Windows
#     updates, then remove Edge." (ShadowWhisperer/Remove-MS-Edge README)
#   - UCPD is community-reported to interfere with programmatic Edge removal on some
#     builds (causality unverified). If this script reports a gate, re-run it from an
#     elevated PowerShell (see docs/TROUBLESHOOTING.md).
#   - WebView2 is never touched: Outlook, Widgets, Xbox sign-in, Photos edit and many
#     3rd-party apps depend on it.
#
# Undo:      winget install Microsoft.Edge --source winget
#            (also offered in the UltraOS post-install folder and the install report)
#
# Compatibility: Windows PowerShell 5.1 (no PS7-only syntax). Idempotent: exits
# cleanly when Edge is already gone. Always exits 0 - failure details are printed
# for the install report instead of halting the playbook.
#
# License: GPL-3.0 (UltraOS). Attribution: Atlas-OS/Atlas (GPL-3.0) for the overall
# Edge-removal chain design; winutil (MIT) and Win11Debloat for method ideas.
# ===========================================================================================

$ErrorActionPreference = 'Continue'

function Write-UltraOS {
    param([string]$Text)
    Write-Output "[UltraOS] $Text"
}

# --- 1) BrowserReplacement stub ------------------------------------------------------------
# An empty MicrosoftEdge.exe inside the legacy UWP Edge folder flips Edge's
# BrowserReplacement gate and unlocks uninstallation in non-EU regions. The stub is
# intentionally left in place afterwards: it keeps Settings > Apps able to uninstall
# Edge again even if it ever gets reinstalled.
$stubDir = Join-Path $env:SystemRoot 'SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe'
$stubExe = Join-Path $stubDir 'MicrosoftEdge.exe'
try {
    if (-not (Test-Path -LiteralPath $stubDir)) {
        New-Item -ItemType Directory -Path $stubDir -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $stubExe)) {
        New-Item -ItemType File -Path $stubExe -Force | Out-Null
    }
    Write-UltraOS "BrowserReplacement stub ready: $stubExe"
}
catch {
    Write-UltraOS "WARN: could not create BrowserReplacement stub ($($_.Exception.Message)); continuing with the uninstaller anyway."
}

# --- 2) Locate Edge's own setup.exe (the uninstaller) --------------------------------------
# Primary: newest versioned folder under Program Files (x86)\Microsoft\Edge\Application.
$setup = $null
$pf86 = ${env:ProgramFiles(x86)}
if ($pf86) {
    $setup = Get-Item -Path (Join-Path $pf86 'Microsoft\Edge\Application\*\Installer\setup.exe') -ErrorAction SilentlyContinue |
        Sort-Object -Property FullName |
        Select-Object -Last 1
}
# Fallback (Win11Debloat method B): the registered UninstallString points at setup.exe.
if (-not $setup) {
    $un = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge' -ErrorAction SilentlyContinue).UninstallString
    if ($un) {
        $clean = $un.Trim()
        $exe = $null
        if ($clean.StartsWith('"')) {
            $exe = $clean.Substring(1).Split('"')[0]
        }
        else {
            $exe = $clean.Split(' ')[0]
        }
        if ($exe -and (Test-Path -LiteralPath $exe)) {
            $setup = Get-Item -LiteralPath $exe
            Write-UltraOS "setup.exe located via UninstallString fallback."
        }
    }
}

# --- 3) Run the uninstaller -----------------------------------------------------------------
if ($setup) {
    Write-UltraOS "Running Edge uninstaller: $($setup.FullName)"
    # --delete-profile is deliberately NOT passed: UltraOS never deletes user data
    # by default (T1-h 4.3 guidance, Atlas parity).
    try {
        $proc = Start-Process -FilePath $setup.FullName `
            -ArgumentList '--uninstall', '--system-level', '--force-uninstall' `
            -WindowStyle Hidden -Wait -PassThru
        Write-UltraOS "Edge setup.exe exit code: $($proc.ExitCode)"
    }
    catch {
        Write-UltraOS "ERROR: failed to launch Edge setup.exe ($($_.Exception.Message))."
    }
}
else {
    Write-UltraOS "Edge setup.exe not found - Edge appears to be already removed."
}

# --- 4) Verify (ReviOS success check, idea reuse - T1-h2 9.2) -------------------------------
$isGone = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate' -ErrorAction SilentlyContinue).IsEdgeStableUninstalled
if ($isGone -eq 1) {
    Write-UltraOS 'SUCCESS: EdgeUpdate reports IsEdgeStableUninstalled = 1.'
}
else {
    Write-UltraOS 'NOTE: removal not confirmed yet (IsEdgeStableUninstalled not set).'
    Write-UltraOS 'Edge may still be present, or the uninstaller was gated (UCPD/region/parent process).'
    Write-UltraOS 'Check Settings > Apps > Installed apps, or re-run this script from an elevated PowerShell.'
    Write-UltraOS 'Reinstall/remove later: winget install Microsoft.Edge --source winget'
}

# Always exit 0: the playbook continues with the AppX sweep and deprovision keys,
# and the report shows this script output for transparency.
exit 0
