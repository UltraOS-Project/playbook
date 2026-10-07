# UltraOS post-install toggle worker - CPU security mitigations
# ---------------------------------------------------------------------------
# Pattern: worker scripts behind self-elevating .cmd toggles, derived from
# Atlas-OS/Atlas 'AtlasModules/Scripts/ScriptWrappers' (GPL-3.0).
# https://github.com/Atlas-OS/Atlas
#
# Registry writes MIRROR the playbook module tweaks/security/mitigations.yml
# (opt-in 'disable CPU mitigations') by T3-h - same four registry-backed items:
#   Disable side (T1-g section 6.1 / Atlas 'Disable All Mitigations.cmd'):
#     - FeatureSettingsOverride=3 + FeatureSettingsOverrideMask=3
#       (Spectre/Meltdown family, incl. branch-prediction mitigations)
#     - DisableExceptionChainValidation=1 (SEHOP)
#     - Set-ProcessMitigation -System -Disable CFG
#     - ProtectionMode=0 (file system mitigations)
#   Enable side (T3-h manual-undo recipe, Atlas 'Set Windows Default
#   Mitigations.cmd' pattern): delete the override values,
#   Set-ProcessMitigation -System -Enable CFG, ProtectionMode=1.
# SCOPE (deliberate, mirrors T3-h's module): Atlas additionally rewrites the
# kernel MitigationOptions/MitigationAuditOptions nibble mask to all-2s, sets
# 'bcdedit /set nx OptIn' and adds a Valorant CFG exception. UltraOS v1 ships
# NONE of these - the blanket nibble mask is the EAC-adjacent trigger
# (T1-h2 section 6.1: Fortnite 0xEAC02014 on Atlas) and DEP stays at the
# Windows default. The Enable side still deletes the kernel masks as
# defensive no-throw cleanup in case an older install left them behind.
# A REBOOT is required for kernel changes to take effect.
[CmdletBinding()]
param (
    [Parameter()][switch]$Enable,
    [Parameter()][switch]$Disable
)

$ErrorActionPreference = 'Continue'

$markerName  = 'Mitigations'
$sessionMgr  = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
$memoryMgmt  = "$sessionMgr\Memory Management"
$kernel      = "$sessionMgr\kernel"
$virtualization = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization'

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

if ($Enable -and $Disable) {
    Write-Host 'ERROR: choose either -Enable or -Disable, not both.'
    exit 1
}
if (-not ($Enable -or $Disable)) {
    Write-Host 'Usage: mitigations.ps1 -Enable | -Disable'
    exit 1
}

if ($Disable) {
    Write-Host 'Disabling CPU mitigations (Spectre/Meltdown family, CFG, SEHOP)...'

    # Spectre/Meltdown family off (incl. branch-prediction mitigations)
    Set-ULValue -Path $memoryMgmt -Name 'FeatureSettingsOverride' -Value 3
    Set-ULValue -Path $memoryMgmt -Name 'FeatureSettingsOverrideMask' -Value 3

    # SEHOP off (exists in ntoskrnl strings - kept for Atlas parity)
    Set-ULValue -Path $kernel -Name 'DisableExceptionChainValidation' -Value 1

    # Control Flow Guard off system-wide (no registry form - needs the cmdlet)
    Set-ProcessMitigation -System -Disable CFG -ErrorAction SilentlyContinue

    # File system mitigations off
    Set-ULValue -Path $sessionMgr -Name 'ProtectionMode' -Value 0

    Write-StateMarker -State 0
    Write-Host 'CPU mitigations disabled. A REBOOT is required for changes to apply.'
    Write-Host 'WARNING: this trades security for performance - near-zero gain on modern'
    Write-Host '         CPUs (8th-gen Intel / Ryzen 3000+). Anti-cheat issues? Run the'
    Write-Host '         paired "Mitigations (Enable)" script and reboot.'
    exit 0
}

if ($Enable) {
    Write-Host 'Restoring Windows default mitigations...'

    # Windows defaults = the override values simply do not exist
    Remove-ItemProperty -LiteralPath $memoryMgmt -Name 'FeatureSettingsOverride' -ErrorAction SilentlyContinue
    Remove-ItemProperty -LiteralPath $memoryMgmt -Name 'FeatureSettingsOverrideMask' -ErrorAction SilentlyContinue
    Remove-ItemProperty -LiteralPath $kernel -Name 'DisableExceptionChainValidation' -ErrorAction SilentlyContinue

    # Defensive no-throw cleanup (older installs / other tools may have left
    # the kernel nibble masks or the VM mitigation override behind)
    Remove-ItemProperty -LiteralPath $kernel -Name 'MitigationAuditOptions' -ErrorAction SilentlyContinue
    Remove-ItemProperty -LiteralPath $kernel -Name 'MitigationOptions' -ErrorAction SilentlyContinue
    Remove-ItemProperty -LiteralPath $virtualization -Name 'MinVmVersionForCpuBasedMitigations' -ErrorAction SilentlyContinue

    # CFG back on system-wide (T3-h manual-undo recipe)
    Set-ProcessMitigation -System -Enable CFG -ErrorAction SilentlyContinue

    # File system mitigations back on
    Set-ULValue -Path $sessionMgr -Name 'ProtectionMode' -Value 1

    Write-StateMarker -State 1
    Write-Host 'Windows default mitigations restored. A REBOOT is required for changes to apply.'
    exit 0
}
