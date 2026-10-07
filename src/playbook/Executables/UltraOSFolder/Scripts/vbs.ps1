# UltraOS post-install toggle worker - Core Isolation (VBS / Memory Integrity)
# ---------------------------------------------------------------------------
# Pattern: worker scripts behind self-elevating .cmd toggles, derived from
# Atlas-OS/Atlas 'AtlasModules/Scripts/ScriptWrappers/ConfigVBS.ps1' (GPL-3.0).
# https://github.com/Atlas-OS/Atlas
#
# Registry values mirror the playbook module tweaks/security/vbs.yml (T3-h)
# and the 24H2 forced-value pattern documented in
# research/services-performance-research.md (T1-g):
#   Disable side (Atlas ConfigVBS.ps1 -DisableAllVBS):
#     - HypervisorEnforcedCodeIntegrity\Enabled=0 (must be FORCED on 24H2+,
#       Windows re-arms it otherwise)
#     - KernelShadowStacks / CredentialGuard: Enabled=0 + clear the
#       ChangedInBootCycle/WasEnabledBy re-arm values when the keys exist
#     - Lsa\RunAsPPL=0 (LSA protection, 24H2+)
#     - DeviceGuard\EnableVirtualizationBasedSecurity=0 (24H2+)
#   Enable side (Atlas 'Enable VBS.cmd'):
#     - HVCI Enabled=1 + WasEnabledBy=2, EnableVirtualizationBasedSecurity=1
# Compatibility warning (T1-h2 section 6.1/6.2): while VBS is disabled,
# Valorant/Vanguard, FACEIT, WSL2, Docker Desktop and Hyper-V do not work.
# A reboot is required for changes to take effect.
[CmdletBinding()]
param (
    [Parameter()][switch]$Enable,
    [Parameter()][switch]$Disable
)

$ErrorActionPreference = 'Continue'

$markerName = 'CoreIsolation'
$deviceGuard = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
$hvci    = "$deviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
$shadow  = "$deviceGuard\Scenarios\KernelShadowStacks"
$cred    = "$deviceGuard\Scenarios\CredentialGuard"

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
    Write-Host 'Usage: vbs.ps1 -Enable | -Disable'
    exit 1
}

if ($Disable) {
    Write-Host 'Disabling Core Isolation (VBS / Memory Integrity)...'

    # Memory Integrity (HVCI) - Force is required on 24H2/25H2/26H2
    Set-ULValue -Path $hvci -Name 'Enabled' -Value 0

    # Kernel-mode Hardware-enforced Stack Protection (Windows 11) - only when
    # the scenario key exists, and clear the re-arm values
    if (Test-Path -LiteralPath $shadow) {
        Set-ULValue -Path $shadow -Name 'Enabled' -Value 0
        Remove-ItemProperty -LiteralPath $shadow -Name 'ChangedInBootCycle' -ErrorAction SilentlyContinue
        Remove-ItemProperty -LiteralPath $shadow -Name 'WasEnabledBy' -ErrorAction SilentlyContinue
    }

    # Credential Guard (Windows 11) - same treatment
    if (Test-Path -LiteralPath $cred) {
        Set-ULValue -Path $cred -Name 'Enabled' -Value 0
        Remove-ItemProperty -LiteralPath $cred -Name 'ChangedInBootCycle' -ErrorAction SilentlyContinue
        Remove-ItemProperty -LiteralPath $cred -Name 'WasEnabledBy' -ErrorAction SilentlyContinue
    }

    # LSA Protection (24H2+)
    Set-ULValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'RunAsPPL' -Value 0

    # VBS general setting (24H2+)
    # https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-deviceguard-unattend-enablevirtualizationbasedsecurity
    Set-ULValue -Path $deviceGuard -Name 'EnableVirtualizationBasedSecurity' -Value 0

    Write-StateMarker -State 0
    Write-Host 'Core Isolation (VBS) disabled. A REBOOT is required for changes to apply.'
    Write-Host 'WARNING: Valorant/FACEIT anti-cheat, WSL2, Docker Desktop and Hyper-V do NOT'
    Write-Host '         work while VBS is off. Re-run with the Enable script to restore it.'
    exit 0
}

if ($Enable) {
    Write-Host 'Enabling Core Isolation (VBS / Memory Integrity)...'

    # Memory Integrity on (WasEnabledBy=2 = enabled by the OS, Atlas pattern)
    Set-ULValue -Path $hvci -Name 'Enabled' -Value 1
    Set-ULValue -Path $hvci -Name 'WasEnabledBy' -Value 2

    # VBS general setting back on
    Set-ULValue -Path $deviceGuard -Name 'EnableVirtualizationBasedSecurity' -Value 1

    Write-StateMarker -State 1
    Write-Host 'Core Isolation (VBS) enabled. A REBOOT is required for changes to apply.'
    Write-Host 'Verify the final state in Windows Security > Device security > Core isolation.'
    exit 0
}
