# UltraOS post-install toggle worker - GameDVR / Game Bar background recording
# ---------------------------------------------------------------------------
# Pattern: worker scripts behind self-elevating .cmd toggles, derived from
# Atlas-OS/Atlas 'AtlasDesktop' toggles (GPL-3.0).
# https://github.com/Atlas-OS/Atlas
#
# Registry values mirror the playbook module tweaks/performance/gaming.yml
# (T3-f) and the Atlas values analyzed in
# research/services-performance-research.md (T1-g) section 3.1:
#   Disable side = Atlas 'disable-game-bar.yml' value set:
#     - HKCU GameConfigStore GameDVR_Enabled=0 + GameDVR AppCaptureEnabled=0
#     - Game Bar tips off (GameBar key: GamePanelStartupTipIndex=3,
#       ShowStartupPanel=0, UseNexusForGameBarEnabled=0)
#     - PresenceWriter ActivationType=0 (HKLM)
#     - Policy pair: Policies\Windows\GameDVR AllowGameDVR=0 +
#       PolicyManager AllowGameDVR value=0 (HKLM)
#   Enable side = Atlas 'Enable FSO and Game Bar Support' pattern: set
#     GameDVR_Enabled=1, restore ActivationType/PolicyManager to 1 and
#     DELETE the per-user override values so Windows defaults return.
# NOTE: HKCU writes affect the user running the toggle; the playbook mirrors
# its own HKCU tweaks to the default user via APPLYHIVE.ps1 at install time.
# Game Mode stays ON in both directions (UltraOS keeps it - T1-g).
[CmdletBinding()]
param (
    [Parameter()][switch]$Enable,
    [Parameter()][switch]$Disable
)

$ErrorActionPreference = 'Continue'

$markerName = 'GameDVR'
$gameConfigStore = 'HKCU:\System\GameConfigStore'
$gameDvrCapture  = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR'
$gameBar         = 'HKCU:\SOFTWARE\Microsoft\GameBar'
$presenceWriter  = 'HKLM:\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter'
$gameDvrPolicy   = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'
$policyManager   = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR'

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
    Write-Host 'Usage: gamebar.ps1 -Enable | -Disable'
    exit 1
}

if ($Disable) {
    Write-Host 'Disabling GameDVR and Game Bar background recording...'

    Set-ULValue -Path $gameConfigStore -Name 'GameDVR_Enabled' -Value 0
    Set-ULValue -Path $gameDvrCapture -Name 'AppCaptureEnabled' -Value 0

    # Game Bar tips / controller button off
    Set-ULValue -Path $gameBar -Name 'GamePanelStartupTipIndex' -Value 3
    Set-ULValue -Path $gameBar -Name 'ShowStartupPanel' -Value 0
    Set-ULValue -Path $gameBar -Name 'UseNexusForGameBarEnabled' -Value 0

    # Game Bar Presence Writer (required by Game Bar) off
    Set-ULValue -Path $presenceWriter -Name 'ActivationType' -Value 0

    # Policy pair: background recording off machine-wide
    Set-ULValue -Path $gameDvrPolicy -Name 'AllowGameDVR' -Value 0
    Set-ULValue -Path $policyManager -Name 'value' -Value 0

    Write-StateMarker -State 0
    Write-Host 'GameDVR / Game Bar background recording disabled.'
    Write-Host 'The Xbox Game Bar app itself is untouched (Game Mode stays on too).'
    exit 0
}

if ($Enable) {
    Write-Host 'Enabling GameDVR and Game Bar background recording (Windows defaults)...'

    # Per Atlas enable pattern: set the master switches back on and DELETE the
    # per-user override values so Windows defaults return
    Set-ULValue -Path $gameConfigStore -Name 'GameDVR_Enabled' -Value 1
    Remove-ItemProperty -LiteralPath $gameDvrCapture -Name 'AppCaptureEnabled' -ErrorAction SilentlyContinue

    Remove-ItemProperty -LiteralPath $gameBar -Name 'GamePanelStartupTipIndex' -ErrorAction SilentlyContinue
    Remove-ItemProperty -LiteralPath $gameBar -Name 'ShowStartupPanel' -ErrorAction SilentlyContinue
    Remove-ItemProperty -LiteralPath $gameBar -Name 'UseNexusForGameBarEnabled' -ErrorAction SilentlyContinue

    # Presence Writer back on
    Set-ULValue -Path $presenceWriter -Name 'ActivationType' -Value 1

    # Policy pair: remove the machine-wide recording block
    Remove-ItemProperty -LiteralPath $gameDvrPolicy -Name 'AllowGameDVR' -ErrorAction SilentlyContinue
    Set-ULValue -Path $policyManager -Name 'value' -Value 1

    Write-StateMarker -State 1
    Write-Host 'GameDVR / Game Bar background recording enabled (Windows defaults).'
    exit 0
}
