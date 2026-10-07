# UltraOS post-install toggle worker - Windows Update policy
# ---------------------------------------------------------------------------
# Pattern: worker scripts behind self-elevating .cmd toggles, derived from
# Atlas-OS/Atlas 'AtlasDesktop' toggles (GPL-3.0).
# https://github.com/Atlas-OS/Atlas
#
# Registry writes MIRROR the playbook module tweaks/qol/updates.yml (opt-in
# wu-notify) by T3-g - same values, so the folder toggle round-trips the state
# the playbook applied:
#   Disable side = the wu-notify pair:
#     - NoAutoUpdate=1  (automatic download/install off - user checks and
#       installs manually; documented trade-off: 'Receive updates for other
#       Microsoft products' stops taking effect)
#     - AUOptions=2     ('notify for download and notify for install' -
#       Atlas's own notify-only mechanism, kept as the belt-and-braces
#       companion so the policy degrades to notify-only even if a future
#       servicing change ignores NoAutoUpdate)
#   Enable side = delete both values -> stock fully-automatic updates.
# NEVER full disable: the Windows Update services (wuauserv, UsoSvc, DoSvc,
# TrustedInstaller) are on the never-touch list (01-architecture section 7.7)
# and are never modified here - updates always keep working.
[CmdletBinding()]
param (
    [Parameter()][switch]$Enable,
    [Parameter()][switch]$Disable
)

$ErrorActionPreference = 'Continue'

$markerName = 'AutomaticUpdates'
$wuAu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'

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
    Write-Host 'Usage: updates.ps1 -Enable | -Disable'
    exit 1
}

if ($Disable) {
    Write-Host 'Setting Windows Updates to notify-only / manual install...'

    # Automatic download/install off - the user stays in control from
    # Settings > Windows Update (matches the wizard option 'Notify only')
    Set-ULValue -Path $wuAu -Name 'NoAutoUpdate' -Value 1

    # Belt-and-braces companion: if a future servicing change ignores
    # NoAutoUpdate, the policy still degrades to notify-only
    Set-ULValue -Path $wuAu -Name 'AUOptions' -Value 2

    Write-StateMarker -State 0
    Write-Host 'Windows Updates are now NOTIFY-ONLY: nothing downloads or installs on its own.'
    Write-Host 'Use Settings > Windows Update > Check for updates when you want them.'
    Write-Host 'The update services themselves are untouched - updates always keep working.'
    exit 0
}

if ($Enable) {
    Write-Host 'Restoring automatic Windows Updates...'

    # Removing both policy values restores stock fully-automatic updates
    Remove-ItemProperty -LiteralPath $wuAu -Name 'NoAutoUpdate' -ErrorAction SilentlyContinue
    Remove-ItemProperty -LiteralPath $wuAu -Name 'AUOptions' -ErrorAction SilentlyContinue

    Write-StateMarker -State 1
    Write-Host 'Automatic Windows Updates restored (Windows default behavior).'
    exit 0
}
