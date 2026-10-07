# RESTOREPOINT.ps1 - UltraOS pre-install System Restore point (rollback layer L0)
# UltraOS v1.0.0 - GPL-3.0 - https://github.com/UltraOS-Project/UltraOS
#
# Provenance: research/execution-performance-packaging.md section 5.2 (L0 design).
# Unlike Atlas (which deletes all restore points in CLEANUP.ps1), UltraOS creates
# one before any change and NEVER deletes shadow copies - rollback is a core feature.
#
# Runs as TrustedInstaller via main.yml (option 'rp-on'). PS 5.1, built-ins only.
#
# KNOWN LIMITATION (handled below): since Windows 8, the System Restore provider
# throttles checkpoint creation - if ANY restore point was created within the last
# 24 hours (SystemRestorePointCreationFrequency, default 1440 min), a new one is
# skipped or Checkpoint-Computer throws. This is NOT a hard failure: an existing
# recent point still covers this install, so we log it and exit 0.
#
# Exit codes: 0 = checkpoint created OR a recent (<24h) point already exists
#             1 = hard failure (no checkpoint could be created, none recent)
# Note: the engine only LOGS non-zero exit codes (PowershellAction.cs:143-144,
# verified from the MIT engine source) - a 1 never halts the playbook.

$ErrorActionPreference = 'Continue'

# PS 5.1's Checkpoint-Computer has no -CheckpointName parameter; -Description IS
# the name shown in the System Restore UI (the engine calls it "checkpoint name").
$checkpointName = 'UltraOS v1.0.0'

$systemDrive = "$env:SystemDrive" + "\"
Write-Output "RESTOREPOINT: ensuring System Protection is enabled on $systemDrive"

# System Protection may be disabled by policy or by the user; enable it first.
# (Enable-ComputerRestore is idempotent - a no-op when already enabled.)
$enabled = $false
try {
    Enable-ComputerRestore -Drive $systemDrive -ErrorAction Stop
    $enabled = $true
}
catch {
    Write-Warning "RESTOREPOINT: could not enable System Protection ($($_.Exception.Message)); will still attempt the checkpoint."
}

# Attempt the checkpoint.
$created = $false
try {
    Write-Output "RESTOREPOINT: creating checkpoint '$checkpointName'"
    # MODIFY_SETTINGS = the documented type for settings/registry modifications.
    Checkpoint-Computer -Description $checkpointName -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
    $created = $true
    Write-Output "RESTOREPOINT: checkpoint created successfully."
}
catch {
    # Most common cause: the 24-hour duplicate-checkpoint throttle described above.
    Write-Warning "RESTOREPOINT: Checkpoint-Computer failed: $($_.Exception.Message)"
}

if ($created) { exit 0 }

# Checkpoint failed - check whether a recent restore point already exists
# (the 24h throttle case, or a point the user created manually moments ago).
try {
    $cutoff = (Get-Date).AddHours(-24)
    $recent = Get-ComputerRestorePoint -ErrorAction Stop |
        Where-Object { $_.CreationTime -gt $cutoff } |
        Sort-Object -Property SequenceNumber |
        Select-Object -Last 1
    if ($recent) {
        Write-Output "RESTOREPOINT: a restore point from the last 24 hours already exists ('$($recent.Description)', $($recent.CreationTime)) - the 24h creation throttle applies, keeping the existing point. Exiting gracefully."
        exit 0
    }
}
catch {
    Write-Warning "RESTOREPOINT: could not enumerate restore points ($($_.Exception.Message))."
}

if (-not $enabled) {
    Write-Error "RESTOREPOINT: HARD FAILURE - System Protection could not be enabled and no checkpoint was created. Restores are unavailable; the install itself is unaffected (backups still run via BACKUP.ps1)."
}
else {
    Write-Error "RESTOREPOINT: HARD FAILURE - System Protection is enabled but the checkpoint could not be created and no recent point exists."
}
exit 1
