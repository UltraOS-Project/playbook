# UltraOS post-install toggle worker - Recall (AI) snapshot saving
# ---------------------------------------------------------------------------
# Pattern: worker scripts behind self-elevating .cmd toggles, derived from
# Atlas-OS/Atlas 'AtlasDesktop' toggles (GPL-3.0).
# https://github.com/Atlas-OS/Atlas
#
# Registry values mirror the playbook module tweaks/privacy/ai-features.yml
# (T3-b) and the Atlas 'Recall' toggle analyzed in
# research/privacy-telemetry-research.md (T1-b) section 6.2:
#   Disable side = HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI
#                 DisableAIDataAnalysis=1
#     MS Learn (Policy CSP WindowsAI): 1 = snapshots are not saved for use
#     with Recall; previously saved snapshots are deleted when the policy is
#     enabled. Computer AND user scope, 24H2 KB5055627+ - fully reversible.
#   Enable side = delete DisableAIDataAnalysis (0/absent = default behavior).
# Note: the opt-in 'strip Recall' install option (opt-strip-recall, Extreme)
# additionally sets AllowRecallEnablement=0 and removes the Recall feature
# on demand - that deeper layer belongs to the playbook module, not this
# reversible toggle.
[CmdletBinding()]
param (
    [Parameter()][switch]$Enable,
    [Parameter()][switch]$Disable
)

$ErrorActionPreference = 'Continue'

$markerName = 'Recall'
$windowsAi = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'

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
    Write-Host 'Usage: recall.ps1 -Enable | -Disable'
    exit 1
}

if ($Disable) {
    Write-Host 'Disabling Recall (AI) snapshot saving...'

    # 1 = do not save snapshots for use with Recall (MS Learn, Policy CSP
    # WindowsAI - DisableAIDataAnalysis); Windows deletes already saved
    # snapshots when this policy is applied
    Set-ULValue -Path $windowsAi -Name 'DisableAIDataAnalysis' -Value 1

    Write-StateMarker -State 0
    Write-Host 'Recall snapshot saving disabled. Previously saved snapshots are deleted by Windows.'
    Write-Host 'This is the reversible policy layer - it does not remove Recall components.'
    exit 0
}

if ($Enable) {
    Write-Host 'Enabling Recall (AI) snapshot saving...'

    # Absent = default behavior (snapshots saved where Recall is available)
    Remove-ItemProperty -LiteralPath $windowsAi -Name 'DisableAIDataAnalysis' -ErrorAction SilentlyContinue

    Write-StateMarker -State 1
    Write-Host 'Recall snapshot saving enabled (Windows default behavior).'
    Write-Host 'Check Settings > Privacy & security > Recall for the on-device controls.'
    exit 0
}
