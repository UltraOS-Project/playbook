# UltraOS recovery helper - remove Defender disable policies and restore service defaults.
[CmdletBinding()]
param (
    [Parameter()][switch]$Enable
)

$ErrorActionPreference = 'Stop'
$policyRoot = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'
$coreRoot   = 'HKLM:\SOFTWARE\Microsoft\Windows Defender'
$coreRtp    = 'HKLM:\SOFTWARE\Microsoft\Windows Defender\Real-Time Protection'
$failures = New-Object System.Collections.Generic.List[string]

function Remove-DefenderValue {
    param([string]$Path, [string]$Name)
    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }
    try {
        $properties = Get-ItemProperty -LiteralPath $Path -ErrorAction Stop
        if ($properties.PSObject.Properties.Name -contains $Name) {
            Remove-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop
        }
    }
    catch {
        $message = "Could not remove $Name from $Path : $($_.Exception.Message)"
        $script:failures.Add($message)
        Write-Warning $message
    }
}

function Invoke-Gpupdate {
    $gpupdate = Join-Path $env:SystemRoot 'System32\gpupdate.exe'
    try {
        $process = Start-Process -FilePath $gpupdate -ArgumentList '/target:computer', '/force' -Wait -WindowStyle Hidden -PassThru -ErrorAction Stop
        if ($process.ExitCode -ne 0) {
            $message = "gpupdate exited with code $($process.ExitCode)."
            $script:failures.Add($message)
            Write-Warning $message
        }
    }
    catch {
        $message = "Could not run gpupdate: $($_.Exception.Message)"
        $script:failures.Add($message)
        Write-Warning $message
    }
}

function Set-ServiceStart {
    param([string]$Name, [string]$StartType)
    $output = & "$env:SystemRoot\System32\sc.exe" config $Name "start= $StartType" 2>&1
    if ($LASTEXITCODE -ne 0) {
        $message = "Could not restore $Name start type (sc.exe exit $LASTEXITCODE): $($output -join ' ')"
        $script:failures.Add($message)
        Write-Warning $message
    }
}

if (-not $Enable) {
    Write-Host 'Usage: defender.ps1 -Enable'
    exit 1
}

Write-Host 'Re-enabling Microsoft Defender...'
Remove-DefenderValue -Path $policyRoot -Name 'DisableAntiSpyware'
Remove-DefenderValue -Path $policyRoot -Name 'DisableAntiVirus'
Remove-DefenderValue -Path "$policyRoot\Real-Time Protection" -Name 'DisableRealtimeMonitoring'
Remove-DefenderValue -Path $coreRoot -Name 'DisableAntiSpyware'
Remove-DefenderValue -Path $coreRoot -Name 'DisableAntiVirus'
Remove-DefenderValue -Path $coreRtp -Name 'DisableRealtimeMonitoring'

Set-ServiceStart -Name 'WinDefend' -StartType 'auto'
Set-ServiceStart -Name 'WdNisSvc' -StartType 'demand'
Set-ServiceStart -Name 'WdNisDrv' -StartType 'demand'
Invoke-Gpupdate

if ($failures.Count -gt 0) {
    Write-Warning "Defender recovery was incomplete ($($failures.Count) operation(s) failed). Check Windows Security or contact your administrator."
    exit 1
}

Write-Host 'Known Defender overrides cleared. Verify real-time protection in Windows Security.'
exit 0
