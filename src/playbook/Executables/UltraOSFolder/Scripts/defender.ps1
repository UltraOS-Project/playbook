# UltraOS post-install toggle worker - Microsoft Defender (policy level)
# ---------------------------------------------------------------------------
# Pattern: worker scripts behind self-elevating .cmd toggles, derived from
# Atlas-OS/Atlas 'AtlasModules/Scripts/ScriptWrappers' (GPL-3.0).
# https://github.com/Atlas-OS/Atlas
#
# Registry writes MIRROR the playbook module tweaks/security/defender-disable.yml
# (opt-in 'keep Defender disabled') and defender-reenable.yml (default re-enable)
# by T3-h - same values, same order:
#   Disable = the 2026-proof double-write (research/known-issues-compatibility.md
#     T1-h2 section 9.3): Policies block -> gpupdate -> CORE Defender writes ->
#     Policies block re-applied -> services to Manual (WinDefend, Sense).
#     UltraOS never removes Defender components (no sxsc/CAB) - policy level
#     only, fully reversible via the paired Enable script.
#   Enable = delete every policy/core override the Disable side writes (incl.
#     the core Real-Time Protection value the pre-install requirement reads),
#     restore stock service start types (WinDefend auto, WdNisSvc/WdNisDrv
#     demand), one gpupdate to make the policy removal immediate.
# Tamper Protection itself can NOT (and must not) be automated - if it is on,
# Windows may revert these policies (T1-h2 section 5.2); re-enabling it is a
# user-manual step in Windows Security (T3-h's reenable module says the same).
[CmdletBinding()]
param (
    [Parameter()][switch]$Enable,
    [Parameter()][switch]$Disable
)

$ErrorActionPreference = 'Continue'

$markerName = 'Defender'
$policyRoot = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'
$policyRtp  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'
$coreRoot   = 'HKLM:\SOFTWARE\Microsoft\Windows Defender'
$coreRtp    = 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection'

function Set-ULValue {
    param([string]$Path, [string]$Name, $Value, [string]$Kind = 'DWord')
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Kind -Force | Out-Null
}

function Write-StateMarker {
    param([int]$State)
    $key = "HKLM:\SOFTWARE\UltraOS\SetupOptions\$markerName"
    if (-not (Test-Path -LiteralPath $key)) {
        New-Item -Path $key -Force | Out-Null
    }
    New-ItemProperty -LiteralPath $key -Name 'state' -Value $State -PropertyType DWord -Force | Out-Null
}

function Invoke-Gpupdate {
    $gpupdate = Join-Path $env:SystemRoot 'System32\gpupdate.exe'
    if (Test-Path -LiteralPath $gpupdate) {
        Start-Process -FilePath $gpupdate -ArgumentList '/target:computer', '/force' -Wait -WindowStyle Hidden
    }
}

function Set-ServiceStart {
    # sc.exe (not Set-Service) so driver services work too
    param([string]$Name, [string]$StartType)  # auto | demand
    Start-Process -FilePath "$env:SystemRoot\System32\sc.exe" -ArgumentList 'config', $Name, "start= $StartType" -Wait -WindowStyle Hidden
}

function Apply-DefenderOffPolicies {
    # The Policies block - written twice (before gpupdate and AFTER the core
    # writes) per the double-write pattern
    Set-ULValue -Path $policyRoot -Name 'DisableAntiSpyware' -Value 1
    Set-ULValue -Path $policyRoot -Name 'DisableAntiVirus' -Value 1
    Set-ULValue -Path $policyRtp -Name 'DisableRealtimeMonitoring' -Value 1
}

if ($Enable -and $Disable) {
    Write-Host 'ERROR: choose either -Enable or -Disable, not both.'
    exit 1
}
if (-not ($Enable -or $Disable)) {
    Write-Host 'Usage: defender.ps1 -Enable | -Disable'
    exit 1
}

if ($Disable) {
    Write-Host 'Disabling Microsoft Defender via policy (2026-proof double-write)...'

    # Policy writes, pass 1 (Policies path) - mirrors defender-disable.yml
    Apply-DefenderOffPolicies

    # One computer-policy refresh - exercises the Jan-2026 auto-removal path
    Invoke-Gpupdate

    # Core writes (the engine 'DefenderToggled' requirement reads this hive)
    Set-ULValue -Path $coreRoot -Name 'DisableAntiSpyware' -Value 1
    Set-ULValue -Path $coreRoot -Name 'DisableAntiVirus' -Value 1

    # Policy writes, pass 2 - THE DOUBLE-WRITE (keeps both locations in sync)
    Apply-DefenderOffPolicies

    # Services to Manual, LAST (synchronized policy+core state resolves the
    # permission errors that occur when disabling Defender services directly).
    # MDCoreSvc/SecurityHealthService are never touched (never-touch list).
    Set-ServiceStart -Name 'WinDefend' -StartType 'demand'
    Set-ServiceStart -Name 'Sense' -StartType 'demand'

    Write-StateMarker -State 0
    Write-Host 'Defender policies written (double-write) and WinDefend/Sense set to Manual.'
    Write-Host 'NOTE: if Tamper Protection is on, Windows Security may revert these policies.'
    Write-Host '      Turn it off in Windows Security first, then re-run this toggle.'
    Write-Host 'WARNING: running Windows without real-time protection is a security risk.'
    exit 0
}

if ($Enable) {
    Write-Host 'Re-enabling Microsoft Defender...'

    # Remove policy-layer overrides - mirrors defender-reenable.yml
    Remove-ItemProperty -LiteralPath $policyRoot -Name 'DisableAntiSpyware' -ErrorAction SilentlyContinue
    Remove-ItemProperty -LiteralPath $policyRoot -Name 'DisableAntiVirus' -ErrorAction SilentlyContinue
    Remove-ItemProperty -LiteralPath $policyRtp -Name 'DisableRealtimeMonitoring' -ErrorAction SilentlyContinue

    # Remove core-layer overrides (incl. the Real-Time Protection value the
    # pre-install requirement reads) - no-throw deletes double as repair steps
    Remove-ItemProperty -LiteralPath $coreRoot -Name 'DisableAntiSpyware' -ErrorAction SilentlyContinue
    Remove-ItemProperty -LiteralPath $coreRoot -Name 'DisableAntiVirus' -ErrorAction SilentlyContinue
    Remove-ItemProperty -LiteralPath $coreRtp -Name 'DisableRealtimeMonitoring' -ErrorAction SilentlyContinue

    # Restore stock service/driver start types
    Set-ServiceStart -Name 'WinDefend' -StartType 'auto'
    Set-ServiceStart -Name 'WdNisSvc' -StartType 'demand'
    Set-ServiceStart -Name 'WdNisDrv' -StartType 'demand'

    # Make the policy removal immediate (otherwise picked up after reboot)
    Invoke-Gpupdate

    Write-StateMarker -State 1
    Write-Host 'Defender overrides cleared and stock service start types restored.'
    Write-Host 'Real-time protection re-arms on the next service start or reboot - verify in'
    Write-Host 'Windows Security > Virus & threat protection > Manage settings.'
    Write-Host 'TIP: turn Tamper Protection back on in Windows Security now.'
    exit 0
}
