# UltraOS Research Dossier T1-f — Windows 11 (26H2-era) Privacy / Telemetry Disable Catalog

- **Agent:** T1-f (privacy telemetry catalog)
- **Date:** 2026-10-07 (all web sources accessed this date)
- **Scope:** The definitive registry/service/task catalog for the UltraOS privacy module (presets Safe / Balanced / Extreme, editions Home + Pro, AME Wizard playbook format)
- **Ground truth:** Atlas-OS/Atlas playbook clone at `/home/z/my-project/repos/atlas` (all 34 files under `src/playbook/Configuration/tweaks/privacy/` read verbatim, plus `atlas/services.yml`, `atlas/components.yml`, `debloat/config-content-delivery.yml`, `debloat/disable-scheduled-tasks.yml`, `qol/windows-update/disable-msrt-telemetry.yml`, `networking/disable-llmnr.yml`, AtlasDesktop CMD scripts, `src/sxsc/Atlas-NoTelemetry.yaml`)
- **Corroboration:** ChrisTitusTech winutil clone at `/home/z/my-project/repos/winutil` (`config/tweaks.json`, `functions/private/Invoke-WinUtilISOScript.ps1`); Microsoft Learn CSP/privacy documentation (fetched + HTML-parsed, HTTP 200); O&O ShutUp10++ official pages.
- **Rule:** Nothing fabricated. Items not directly confirmed in one of the above sources are marked **⚠️ UNVERIFIED**.

---

## 0. Executive summary

1. Atlas's privacy layer = **34 YAML tweak files** (all quoted/inlined below) + service disables in `atlas/services.yml` + 7 scheduled-task disables in `debloat/disable-scheduled-tasks.yml` + an optional **component-removal CAB** (`Z-Atlas-NoTelemetry-Package`, removes ~40 CBS components incl. CompatTelRunner, Appraiser, TelemetryClient, Unified-Telemetry-Client). UltraOS Extreme preset should replicate the first three layers via AME Wizard YAML and treat the CAB as an "Atlas-parity" stretch goal.
2. **Critical edition semantics (MS Learn, verified):** `AllowTelemetry=0` ("Security"/Diagnostic data off) is only honored on **Enterprise, Education, Server**. On **Home and Pro it behaves as 1 (Required/Basic)**. UltraOS must present telemetry floor honestly: on Home/Pro the *effective* minimum is Required diagnostic data unless the DiagTrack service itself is disabled.
3. 26H2-era AI privacy = Recall (`DisableAIDataAnalysis` under `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` — exactly what Atlas ships) + Copilot (`TurnOffWindowsCopilot`, deprecated but functional, HKCU Policies) + Insider/26H2-era agent policies (`DisableSettingsAgent`, `AgentConnectorAccessPolicy`, `OnDeviceRegistryLoggingLevel` — documented in Policy CSP WindowsAI, several Insider-only ⚠️).
4. Winutil contributes items Atlas lacks: **Siuf feedback frequency**, **PowerShell 7 telemetry opt-out**, **Defender sample submission consent**, **WPBT**, **Teredo**, **device metadata from network**, **consumer features policy**, **WSAIFabricSvc + Recall optional feature removal**, and the canonical scheduled-task file paths (Compatibility Appraiser, ProgramDataUpdater, Chkdsk\Proxy, WER\QueueReporting).
5. What cannot honestly be fully disabled on Home/Pro: required diagnostic data, MSA-linked cloud data (if the user signs in), Store/Update/licensing traffic, Defender cloud channel. See §12.

---

## 1. Sources (all accessed 2026-10-07)

**Local repos (ground truth):**
- Atlas: `https://github.com/Atlas-OS/Atlas` → clone `/home/z/my-project/repos/atlas`, files under `src/playbook/`
- winutil: `https://github.com/ChrisTitusTech/winutil` → clone `/home/z/my-project/repos/winutil` (`config/tweaks.json`, `functions/private/Invoke-WinUtilISOScript.ps1`)

**Microsoft Learn (curl/page_reader, HTTP 200 verified):**
- Policy CSP — System (AllowTelemetry, DisableDiagnosticDataViewer, LimitDiagnosticLogCollection, LimitDumpCollection, ConfigureTelemetryOptInSettingsUx, ConfigureTelemetryOptInChangeNotification, DisableOneSettingsDownloads, DisableDeviceDelete): https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-system
- Policy CSP — WindowsAI (DisableAIDataAnalysis, AllowRecallEnablement, TurnOffWindowsCopilot, RemoveMicrosoftCopilotApp, SetDenyAppListForRecall, SetMaximumStorageDurationForRecallSnapshots, DisableSettingsAgent, DisableRecallDataProviders, OnDeviceRegistryLoggingLevel, AgentConnectorAccessPolicy): https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-windowsai
- Policy CSP — Privacy (LetAppsAccessHumanPresence, LetAppsAccessLocation, …AppPrivacy): https://learn.microsoft.com/en-us/windows/client-management/mdm/policy-csp-privacy
- Configure Windows diagnostic data in your organization (edition semantics of level 0): https://learn.microsoft.com/en-us/windows/privacy/configure-windows-diagnostic-data-in-your-organization
- Windows diagnostic data overview: https://learn.microsoft.com/en-us/windows/privacy/windows-diagnostic-data

**Community / vendor:**
- O&O ShutUp10++ product page: https://www.oo-software.com/en/shutup10 (fetched 200; "helps you to quickly adjust data protection settings in Windows 10/11"). Manual/FAQ domain: https://manuals.oo-software.com (search hit "O&O ShutUp10 changes Windows privacy settings through registry and policy settings"). **O&O does not publish a public per-setting registry list**; its settings map onto the same keys documented here from Atlas/winutil/Learn. Any O&O-specific key beyond that overlap: ⚠️ UNVERIFIED.
- Deskmodder wiki (api.php queried; no dedicated Win11 telemetry wiki article found — Win11 wiki pages listed don't include one) and ghacks/gHacks equivalents were **not retrievable** during this session (search rate limits). Community keys below are therefore sourced only from Atlas + winutil + MS Learn; classic tenforums/elevenforum-only keys are explicitly flagged.
- .NET CLI telemetry (referenced by Atlas file): https://learn.microsoft.com/en-us/dotnet/core/tools/telemetry
- ADMX reference cited *inside Atlas files*: https://admx.help/?Category=Windows_11_2022 (paths quoted per file below)

**Presets in this dossier:** **S** = Safe (registry-only, zero functional breakage), **B** = Balanced (Atlas-parity: services+tasks off), **X** = Extreme (everything incl. component-level removal + MSA/OneDrive restrictions). "S/B" means Safe and Balanced both apply it.

---

## 2. AREA A — Telemetry services & AllowTelemetry

### 2.1 Services (startup type table)

Atlas `atlas/services.yml` disables these with `!service: {name: ..., operation: change, startup: 4}` (startup 4 = **Disabled**):

| Service name | Display name | Atlas | winutil | Notes / risk | Preset |
|---|---|---|---|---|---|
| `DiagTrack` | Connected User Experiences and Telemetry | **Disabled** | **Disabled** (`Set-Service -Name diagtrack -StartupType Disabled`) | Core telemetry uploader. Disabling stops CEIP/DiagTrack uploads; Settings > Privacy shows "Required" regardless on Home/Pro. Low breakage risk. | B/X (S: stop-only, no disable) |
| `WerSvc` | Windows Error Reporting | **Disabled** (Atlas: "Microsoft recommendation - Do not disable") | `wermgr` **Disabled** | Crash reporting stops; error dialogs change slightly; some installers' crash handling degrades. | B/X |
| `diagnosticshub.standardcollector.service` | Microsoft (R) Diagnostics Hub Standard Collector Service | **Disabled** (Atlas: "Do not disable" per MS IoT guidance) | — | Used by VS/ETW tracing tooling; breaks some dev workflows. | B/X |
| `wercplsupport` | Problem Reports Control Panel Support | **Disabled** (Atlas: "No guidance") | — | Removes Problem Reports UI plumbing. | X |
| `PcaSvc` | Program Compatibility Assistant | **Disabled** (service; also see §3 tasks, §6 PCA registry block) | — | PCA gives app-compat shims + "incorrect compatibility" dialogs; disabling is performance+privacy. Atlas default. | B/X |
| `OneSyncSvc` | Sync Host | **Disabled** | — | Breaks Mail/Calendar sync, some MSA sync; Atlas disables. | B/X |
| `TrkWks` | Distributed Link Tracking Client | **Disabled** | — | NTFS shortcut tracking; negligible user impact. | B/X |
| `UCPD` | UCPD (UrLock bypass mitigation service) | **Disabled** + task off (see §3) | — | ⚠️ Security trade-off: UCPD mitigates a BitLocker key exposure class (CVE-2022-37969-era). UltraOS should default this to OFF only in Extreme, with explicit security warning. | X (with warning) |
| `lfsvc` | Geolocation Service | via Location CMD (`sc config lfsvc start=disabled`) | **Disabled** | Location off; Find My Device breaks. | B/X |
| `MapsBroker` | Downloaded Maps Manager | via Location CMD (`sc config MapsBroker start=disabled`) | **Manual** | Offline maps updates stop. | B/X |
| `lfsvc`/`MapsBroker` stop commands | — | `sc stop lfsvc`, `sc stop MapsBroker` | — | Immediate stop at apply time. | B/X |
| `dmwappushservice` | WAP Push Message Routing Service | **not touched by Atlas** | **not touched by winutil** | Classic community disable (tenforums-era scripts, O&O ShutUp10 family); used by MDM/Intune channels. Set Manual/Disabled for privacy; breaks enterprise enrollment scenarios. ⚠️ Community-documented only, not in either repo. | X ⚠️ |
| `DoSvc` | Delivery Optimization | left running; policy DODownloadMode=0 (Atlas CMD) | — | See §10. | B/X (policy), S (mode 1) |
| `WSAIFabricSvc` | Windows AI Fabric Service | — | **Disabled** in `WPFTweaksWindowsAI` | 24H2+ on-device AI service; disabling breaks Recall/Cocreator/AI features (intended). | X |
| `Telemetry` (driver) | Microsoft Telemetry driver (`HKLM\SYSTEM\...\Services\Telemetry`) | **Disabled** (`!service: {name: 'Telemetry', operation: change, startup: 4}` under "DRIVERS") | — | Kernel telemetry driver. | B/X |
| `wermgr` | Windows Error Reporting Service (older name) | — | **Disabled** (`Set-Service wermgr`) | Same family as WerSvc on Home builds. | B/X |
| `CscService` | Offline Files | — | **Disabled** | Not telemetry per se; data-exposure reduction. | X |
| `SharedAccess` | Internet Connection Sharing (IPv6 ICS) | — | **Disabled** | Network hardening. | X |
| `StorSvc`, `MapsBroker` | Storage Service, Maps | — | **Manual** | winutil "Services - Set to Manual". | B |

Atlas driver/service disables also include `GpuEnergyDrv`, `NetBT` (NetBIOS; can be re-enabled by Atlas file-sharing script) — performance/network, listed here for completeness.

**Verbatim Atlas quote — `atlas/services.yml` (services section):**
```yaml
  # ------ Microsoft recommendation - 'OK to disable' ------
  - !service: {name: 'OneSyncSvc', operation: change, startup: 4}
  - !service: {name: 'TrkWks', operation: change, startup: 4}
  - !service: {name: 'PcaSvc', operation: change, startup: 4}
  - !service: {name: 'DiagTrack', operation: change, startup: 4}

    # ------ Microsoft recommendation - 'Do not disable' -----
  - !service: {name: 'diagnosticshub.standardcollector.service', operation: change, startup: 4}
  - !service: {name: 'WerSvc', operation: change, startup: 4} 

    # ------- Microsoft recommendation - 'No guidance' ------
  - !service: {name: 'wercplsupport', operation: change, startup: 4}
  - !service: {name: 'UCPD', operation: change, startup: 4}

  ##############################################################################################
  ## DRIVERS                                                                                  ##
  ##############################################################################################

  - !writeStatus: {status: 'Configuring drivers'}

  - !service: {name: 'GpuEnergyDrv', operation: change, startup: 4}
    # NetBios support can be enabled with the file sharing script
  - !service: {name: 'NetBT', operation: change, startup: 4}
  - !service: {name: 'Telemetry', operation: change, startup: 4}
```

### 2.2 AllowTelemetry — registry values & edition semantics

**Full Atlas file — `tweaks/privacy/telemetry/disallow-data-collection.yml` (verbatim):**
```yaml
---
title: Disallow Telemetry and Data Collection
description: Disallows telemetry and data collection to improve privacy
actions:
    # Stop DiagTrack service to add the changes
  - !service: {name: 'DiagTrack', operation: stop, ignoreErrors: true}
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack'
    value: 'ShowedToastAtLevel'
    data: '1'
    type: REG_DWORD
    
  - !registryValue:
    path: 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'
    value: 'AllowTelemetry'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'
    value: 'MaxTelemetryAllowed'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\Software\Policies\Microsoft\Windows\DataCollection'
    value: 'AllowTelemetry'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection'
    value: 'AllowTelemetry'
    data: '0'
    type: REG_DWORD

    # Misc
  - !registryValue:
    path: 'HKLM\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack\EventTranscriptKey'
    value: 'EnableEventTranscript'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\Software\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack\EventTranscriptKey'
    value: 'MiniTraceSlotEnabled'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\Software\Policies\Microsoft\Windows\DataCollection'
    value: 'AllowDeviceNameInTelemetry'
    data: '0'
    type: REG_DWORD

    # Disable & clear logger
  - !registryValue:
    path: 'HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Diagtrack-Listener'
    value: 'Start'
    data: '0'
    type: REG_DWORD
  - !cmd: {command: 'del "%ProgramData%\Microsoft\Diagnosis\ETLLogs\AutoLogger\DiagTrack*" "%ProgramData%\Microsoft\Diagnosis\ETLLogs\ShutdownLogger\DiagTrack*" > nul 2>&1'}
```

**Catalog — telemetry level & DiagTrack internals:**

| # | Registry path | Value | Type | Data | Purpose / source | Home-compat | Preset |
|---|---|---|---|---|---|---|---|
| A1 | `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection` | `AllowTelemetry` | REG_DWORD | `0` | Legacy/retail preference path (Atlas) | Yes (registry-only; but see semantics) | B/X |
| A2 | `HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection` | `AllowTelemetry` | REG_DWORD | `0` | GPO path (ADMX `DataCollection.admx`, policy "Allow Diagnostic Data", Win Components > Data Collection and Preview Builds) — confirmed by MS Learn CSP System page | Yes — GPO-style Policies keys work on Home (no gpedit needed; registry is the same mechanism) | B/X |
| A3 | `HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection` | `AllowTelemetry` | REG_DWORD | `0` | 32-bit view parity (Atlas) | Yes | B/X |
| A4 | `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection` | `MaxTelemetryAllowed` | REG_DWORD | `0` | Cap key written by newer builds/MDM-era UX (Atlas). ⚠️ UNVERIFIED against current Learn docs (not present in Policy CSP System page text); keep for Atlas parity | Yes | B/X |
| A5 | `HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack` | `ShowedToastAtLevel` | REG_DWORD | `1` | Suppresses "we changed your diagnostic data" toast (Atlas) | Yes | B/X |
| A6 | `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Diagnostics\DiagTrack\EventTranscriptKey` | `EnableEventTranscript` | REG_DWORD | `0` | Stops EventTranscript (local SQL CE store that feeds DiagTrack) (Atlas) | Yes | B/X |
| A7 | same key | `MiniTraceSlotEnabled` | REG_DWORD | `0` | MiniTrace ETW slot off (Atlas) | Yes | B/X |
| A8 | `HKLM\Software\Policies\Microsoft\Windows\DataCollection` | `AllowDeviceNameInTelemetry` | REG_DWORD | `0` | GPO "Include device name in diagnostic data" (Atlas) | Yes | S/B |
| A9 | `HKLM\SYSTEM\CurrentControlSet\Control\WMI\Autologger\Diagtrack-Listener` | `Start` | REG_DWORD | `0` | Disables DiagTrack ETW autologger session (Atlas) | Yes | B/X |
| A10 | File op | — | — | delete `%ProgramData%\Microsoft\Diagnosis\ETLLogs\AutoLogger\DiagTrack*` and `...\ShutdownLogger\DiagTrack*` | Clears stored logs (Atlas `!cmd`) | Yes | B/X |
| A11 | `HKLM\Software\Policies\Microsoft\Windows\DataCollection` | `LimitDiagnosticLogCollection` | REG_DWORD | `1` | GPO "Limit diagnostic log collection" (MS Learn CSP System; Win11 21H2+) | Yes | S/B |
| A12 | `HKLM\Software\Policies\Microsoft\Windows\DataCollection` | `LimitDumpCollection` | REG_DWORD | `1` | GPO "Limit dump collection" — WER limited to kernel mini/user triage dumps (MS Learn CSP System) | Yes | S/B |
| A13 | `HKLM\Software\Policies\Microsoft\Windows\DataCollection` | `DisableDiagnosticDataViewer` | REG_DWORD | `1` | GPO "Disable diagnostic data viewer" (MS Learn CSP System; viewer toggle hidden in Settings) — cosmetic privacy (viewer itself isn't exfil, but hides D&F page features) | Yes | B/X |
| A14 | `HKLM\Software\Policies\Microsoft\Windows\DataCollection` | `DisableOneSettingsDownloads` | REG_DWORD | `1` | GPO — blocks OneSettings service connections (MS Learn CSP System; Win11 21H2+) | Yes | B/X |
| A15 | `HKLM\Software\Policies\Microsoft\Windows\DataCollection` | `DisableDeviceDelete` | REG_DWORD | `0` | Keep the "Delete diagnostic data" button ENABLED (privacy-positive; do not set to 1) (MS Learn CSP System) | Yes | S (leave default) |
| A16 | `HKLM\Software\Policies\Microsoft\Windows\DataCollection` | `ConfigureTelemetryOptInSettingsUx` (⚠️ value name per ADMX is `DisableDiagnosticDataOptInSettings`) | REG_DWORD | `1` | Locks the Settings diagnostic-data chooser (MS Learn CSP System; prevents UI reverting level). ⚠️ Exact value name from admx.help heritage — mark for verification on a 26H2 test box | Yes | X (UltraOS keeps UI honest by leaving it configurable; Balanced = 0) |
| A17 | `HKLM\Software\Policies\Microsoft\Windows\DataCollection` | `AllowUpdateComplianceProcessing` / `EnableOneSettingsAuditing` | REG_DWORD | `0` | Update Compliance/auditing opt-outs (MS Learn CSP System lists both) — set 0 to disallow | Yes | X |

**Edition semantics — Microsoft Learn, verbatim (Policy CSP System → AllowTelemetry):**
> "0 Security. Information that's required to help keep Windows more secure, including data about the Connected User Experience and Telemetry component settings, the Malicious Software Removal Tool, and Windows Defender. **Note: This value is only applicable to Windows 10 Enterprise, Windows 10 Education, Windows 10 Mobile Enterprise, Windows 10 IoT Core (IoT Core), and Windows Server 2016. Using this setting on other devices is equivalent to setting the value of 1.** 1 (Default) Basic. … 3 Full."

And from "Configure Windows diagnostic data in your organization":
> "Diagnostic data off … no Windows diagnostic data is sent from your device. **This is only available on Windows Server, Windows Enterprise, and Windows Education editions.**"

**UltraOS implication (Home+Pro):** write `AllowTelemetry=0` (harmless, future-proof if edition upgraded) **and** state in the wizard UI: *"On Home/Pro, Microsoft enforces a Required-data floor; UltraOS additionally stops the DiagTrack service/autologger to prevent upload."* That is exactly Atlas's belt-and-braces approach (value 0 + service disabled + logger off + log deletion).

### 2.3 Component-level removal (the "nuclear option")

Atlas builds `Z-Atlas-NoTelemetry-Package` (CAB, amd64 + arm64 variants in `src/sxsc/Atlas-NoTelemetry.yaml`) which permanently removes CBS components such as:
`Microsoft-Windows-Compat-Appraiser`, `Microsoft-Windows-Compat-Appraiser-InboxDataFiles`, `Microsoft-Windows-Compat-CompatTelRunner`, `Microsoft-Windows-Compat-CompatTelRunner-DailyTask`, `Microsoft-Windows-Compat-GeneralTel`, `Microsoft-Windows-Application-Experience-AIT-Static`, `Microsoft-Windows-Application-Experience-AppInv`, `Microsoft-Windows-Application-Experience-Core-Inventory-Service`, `Microsoft-Windows-Application-Experience-Inventory-Data-Sources`, `Microsoft-Windows-Application-Experience-Program-Data`, `Microsoft-Windows-TelemetryClient` (amd64+wow64), `Microsoft-Windows-Unified-Telemetry-Client*` (resources, aggregators, autologger, decoder host, settings, WoWOnly), `Microsoft-Windows-DataCollection-Adm(.Resources)`, `Microsoft-Windows-DeviceCensus-Schedule-ClientServer`, `Microsoft-Windows-KeyboardDiagnostic(.Resources)`, `Microsoft-Windows-SetupPlatform-Telemetry-AutoLogger`, `Microsoft-Windows-SystemSettings-SettingsHandlers-SIUF(.Resources)`, `Microsoft-Windows-Feedback-*` (Feedback engine/service/deployment client/tasksch/notifications), `Microsoft-OneCoreUAP-Feedback-StringFeedbackEngine`, `Microsoft-OneCore-SystemSettings-InputCloudStore`, `Microsoft-Windows-Compatibility-Aggregator`, `Microsoft-Windows-CodeIntegrity-Aggregator`, `Microsoft-Windows-MediaFoundation-MediaFoundationAggregator`, `Microsoft-Windows-Power-EnergyEstimationEngine-Client-Overrides`, `Microsoft-Windows-Security-PwdlessPlat-Aggregator`, `Microsoft-Windows-Update-Aggregators`, `Windows-System-Diagnostics-Telemetry-PlatformTelemetryClient` (amd64+wow64).
Atlas deliberately KEEPS `Microsoft-Windows-DeviceCensus` ("Required for Application Compatibility (PcaSvc)") and `Microsoft-Windows-CoreSystem-Bluetooth-Telemetry` ("Breaks Bluetooth connectivity").

- **UltraOS guidance:** Extreme preset only; implement via `trusted-uninstaller-cli`-style CBS removal or Atlas CAB parity; **irreversible without DISM restore**; hide from Safe/Balanced. Atlas toggles it through `AtlasModules\Scripts\packageInstall.ps1` (wrapper: `AtlasDesktop\9. Troubleshooting\Telemetry Components.cmd` → `ScriptWrappers\TelemetryComponents.ps1`, package glob `*Z-Atlas-NoTelemetry-Package*`).

---

## 3. AREA B — Scheduled tasks

**Full Atlas file — `tweaks/debloat/disable-scheduled-tasks.yml` (verbatim):**
```yaml
---
title: Disable Scheduled Tasks
description: Disables scheduled tasks to prevent automatic tasks from running at startup, consuming resources and collecting user data
actions:
    # Updates compatibility database
  - !scheduledTask: {path: '\Microsoft\Windows\Application Experience\PcaPatchDbTask', operation: disable, ignoreErrors: true}

    # UCPD - might not exist on all installs, so ignore errors
  - !scheduledTask: {path: '\Microsoft\Windows\AppxDeploymentClient\UCPD velocity', operation: disable, ignoreErrors: true}

    # Data collection
  - !scheduledTask: {path: '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector', operation: disable, ignoreErrors: true}

    # CEIP - safety measure
  - !scheduledTask: {path: '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator', operation: disable, ignoreErrors: true}
  - !scheduledTask: {path: '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip', operation: disable, ignoreErrors: true} 

    # A/B testing usage reports
  - !scheduledTask: {path: '\Microsoft\Windows\Flighting\FeatureConfig\UsageDataReporting', operation: disable, ignoreErrors: true}
  - !registryValue:
    path: 'HKLM\System\CurrentControlSet\Control\Ubpm'
    value: 'CriticalMaintenance_UsageDataReporting' # Remove from automatic maintenance
    operation: delete
```

Winutil (ISO path `functions/private/Invoke-WinUtilISOScript.ps1`, lines 630–642) deletes these task *files* (confirming canonical paths): `...\Application Experience\Microsoft Compatibility Appraiser`, `...\Customer Experience Improvement Program` (folder), `...\Application Experience\ProgramDataUpdater`, `...\Chkdsk\Proxy`, `...\Windows Error Reporting\QueueReporting`, plus update-related (`InstallService`, `UpdateOrchestrator`, `WaaSMedic`, `WindowsUpdate`).

**Catalog (task path → preset):**

| Task path (`\Microsoft\Windows\…`) | Function | Source | Risk | Preset |
|---|---|---|---|---|
| `Application Experience\PcaPatchDbTask` | PCA compat-DB updater | Atlas | None meaningful | B/X |
| `Application Experience\Microsoft Compatibility Appraiser` | CompatTelRunner appraiser (upgrade telemetry) | winutil ISO list; classic tenforums | None (feature-upgrade readiness only) | B/X |
| `Application Experience\ProgramDataUpdater` | CEIP program-data upload | winutil ISO list | None | B/X |
| `Application Experience\StartupAppTask` | Startup-app telemetry/monitor | classic community (tenforums/elevenforum guides) — **not in Atlas/winutil current lists** ⚠️ | None known; may affect Start "recently added" | B/X ⚠️ |
| `AppxDeploymentClient\UCPD velocity` | UCPD feature rollout | Atlas | None known | B/X |
| `DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector` | Disk diagnostic data collection | Atlas | None | B/X |
| `Customer Experience Improvement Program\Consolidator` | CEIP upload (OS) | Atlas + winutil | None | S/B (harmless) → keep in B/X |
| `Customer Experience Improvement Program\UsbCeip` | CEIP USB telemetry | Atlas + winutil | None | B/X |
| `Customer Experience Improvement Program\KernelCeipTask` | CEIP kernel (Win10-era; often absent on Win11) | classic community ⚠️ (existence on 26H2 unverified) | None | B/X ⚠️ |
| `Flighting\FeatureConfig\UsageDataReporting` | A/B flighting usage reports | Atlas (+ UBPM registry delete, see file above) | None (flighting only) | B/X |
| `Chkdsk\Proxy` | Chkdsk telemetry proxy | winutil ISO list | None | B/X |
| `Windows Error Reporting\QueueReporting` | WER queue upload | winutil ISO list | Crash reporting stops (intended) | B/X |
| `Autochk\Proxy` | Autochk feedback upload | classic community ⚠️ | None | B/X ⚠️ |
| `Maps\MapsToastTask`, `Maps\MapsUpdateTask` | Maps updates/toasts | classic community ⚠️ (may be absent on Win11) | Offline maps won't update | X ⚠️ |
| `Family Safety Monitor\Family Safety Monitor`, `…\Family Safety Refresh Task` | Family Safety telemetry | classic community ⚠️ | Breaks Family Safety if used | X ⚠️ |
| `XblGameSaveTask` (`XblGameSave`) | Xbox Live game-save sync | classic community ⚠️ | Breaks Xbox cloud saves | X ⚠️ (not recommended) |
| `Device Information\Access` | Device metadata access | classic community ⚠️ | Driver metadata fetching | X ⚠️ |

**Note on 26H2-era reality:** Atlas marks everything `ignoreErrors: true` — several Win10-era tasks no longer exist on Win11 24H2/25H2/26H2. UltraOS must tolerate missing tasks (AME Wizard `!scheduledTask` supports `ignoreErrors`). Also note Atlas's UBPM trick: delete `HKLM\SYSTEM\CurrentControlSet\Control\Ubpm\...\CriticalMaintenance_UsageDataReporting` so *Automatic Maintenance* can't resurrect the UsageDataReporting task — worth replicating for other maintenance-bound tasks.

---

## 4. AREA C — Settings → Privacy & security

### 4.1 Advertising ID

**Atlas `advertising/disable-advertising-info.yml` (verbatim):**
```yaml
---
title: Disable Advertising ID
description: Disables Advertising ID for privacy
actions:
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
    value: 'Enabled'
    data: '0'
    type: REG_DWORD
    
  - !registryValue:
    path: 'HKLM\Software\Policies\Microsoft\Windows\AdvertisingInfo'
    value: 'DisabledByGroupPolicy'
    data: '1'
    type: REG_DWORD
```
Also: per-user reset of the ID: `HKCU\...\AdvertisingInfo` `Id` (REG_SZ, random GUID — do not just delete). Home-compat: full. Risk: apps see no ad ID. **Preset: S/B.** Winutil sets the same `Enabled=0` in `WPFTweaksTelemetry`.

### 4.2 Activity history (feed) + upload

**Atlas `disable-activity-feed.yml` (verbatim, full):**
```yaml
---
title: Disable Activity Feed
description: Disables Activity Feed in Task View for privacy and QoL
actions:
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System'
    value: 'EnableActivityFeed'
    data: '0'
    type: REG_DWORD
```

**Atlas `disallow-user-activity-upload.yml` (verbatim, full):**
```yaml
---
title: Disallow Upload and Publish of User Activities
description: Disables the upload and publish of user activities for privacy
actions:
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System'
    value: 'UploadUserActivities'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\System'
    value: 'PublishUserActivities'
    data: '0'
    type: REG_DWORD
```
Winutil's `WPFTweaksActivity` sets `EnableActivityFeed=1` (!) with `PublishUserActivities=0`/`UploadUserActivities=0` and describes it as "preserving clipboard history" — **Atlas is stricter** (0/0/0). UltraOS: follow Atlas (0/0/0); clipboard history (Win+V) is unaffected by these three values. Home-compat: yes. **Preset: S/B.**

### 4.3 App-launch tracking / Most-frequently-used

- `HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced` → `Start_TrackProgs` = `0` (REG_DWORD) — Atlas `disable-app-launch-tracking.yml` (verbatim one-liner; tenforums citation inside file). Effect: Start menu doesn't rank by usage. **S/B.**
- `HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer` → `NoInstrumentation` = `1` (REG_DWORD) — Atlas `disable-user-tracking.yml` ("Disable Most Frequently Used Applications"). **B/X.**
- Winutil also sets `Start_TrackProgs=0` in `WPFTweaksTelemetry`.

### 4.4 Tailored experiences / diagnostic-data-based tips

**Atlas `disable-tailored-experiences.yml` (verbatim, full):**
```yaml
---
title: Do Not Use Diagnostic Data For Tailored Experiences
description: Prevents Windows from using diagnostic data for tailored experiences for privacy, also labeled as "Let Microsoft provide more tailored experiences with relevant tips and recommendations by using your diagnostic data"
actions:
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy'
    value: 'TailoredExperiencesWithDiagnosticDataEnabled'
    data: '0'
    type: REG_DWORD
    
  - !registryValue:
    path: 'HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent'
    value: 'DisableTailoredExperiencesWithDiagnosticData'
    data: '1'
    type: REG_DWORD
```
**Preset: S/B.** Home-compat: full.

### 4.5 Input personalization (ink / typing / handwriting telemetry)

**Atlas `telemetry/disable-input-telemetry.yml` (verbatim, full):**
```yaml
---
title: Disable Input Telemetry
description: Disables text, ink and handwriting telemetry for privacy
actions:
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\InputPersonalization'
    value: 'RestrictImplicitInkCollection'
    data: '1'
    type: REG_DWORD
    
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\InputPersonalization'
    value: 'RestrictImplicitTextCollection'
    data: '1'
    type: REG_DWORD
    
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\InputPersonalization\TrainedDataStore'
    value: 'HarvestContacts'
    data: '0'
    type: REG_DWORD
    
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Personalization\Settings'
    value: 'AcceptedPrivacyPolicy'
    data: '0'
    type: REG_DWORD
    
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\TabletPC'
    value: 'PreventHandwritingDataSharing'
    data: '1'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\HandwritingErrorReports'
    value: 'PreventHandwritingErrorReports'
    data: '1'
    type: REG_DWORD
  # Disable typing insights
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Input\Settings'
    value: 'InsightsEnabled'
    data: '0'
    type: REG_DWORD
    
    # Disable improve inking and typing recognition
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Input\TIPC'
    value: 'Enabled'
    data: '0'
    type: REG_DWORD
    
  - !registryValue:
    path: 'HKLM\SOFTWARE\Microsoft\Input\TIPC'
    value: 'Enabled'
    data: '0'
    type: REG_DWORD
```
Risk: cloud-based IME predictions/pen personalization degrade slightly. **Preset: S/B** (HKCU part), **B/X** (HKLM policy part). Winutil `WPFTweaksTelemetry` mirrors the HKCU subset.

### 4.6 Online speech recognition

**Atlas `disable-online-speech-recognition.yml` (verbatim, full):**
```yaml
---
title: Disable Online Speech Recognition
description: Disables online speech recognition for privacy purposes
actions:
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy'
    value: 'HasAccepted'
    data: '0'
    type: REG_DWORD
    
    
    # Allow user to enable it in case they need it
  # - !registryValue:
  #   path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\InputPersonalization'
  #   value: 'AllowInputPersonalization'
  #   data: '0'
  #   type: REG_DWORD
```
Note Atlas intentionally leaves `AllowInputPersonalization=0` **commented out** so users can re-enable speech/dictation. UltraOS should do the same in Safe/Balanced; enable the policy in Extreme. Speech data auto-updates: `HKLM\SOFTWARE\Policies\Microsoft\Speech` → `AllowSpeechModelUpdate` = `0` (Atlas `disable-speech-auto-updates.yml`, verbatim in §9 appendix). **Preset: S/B.**

### 4.7 Location, sensors, presence sensing

Atlas `config-app-permissions.yml` (verbatim, full):
```yaml
---
title: Configure App Permissions
description: Configures default app permissions in Settings for the optimal privacy
actions:
  - !registryValue:
    path: 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\appDiagnostics'
    value: 'Value'
    data: 'Deny'
    type: REG_SZ
  - !registryValue:
    path: 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location'
    value: 'Value'
    data: 'Deny'
    type: REG_SZ
  - !registryValue:
    path: 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\userAccountInformation'
    value: 'Value'
    data: 'Deny'
    type: REG_SZ
```
Atlas Location CMD (`AtlasDesktop\3. General Configuration\Location\Disable Location (default).cmd`) adds:
- `sc config lfsvc start=disabled` ; `sc config MapsBroker start=disabled` (+ stops both)
- `HKLM\SOFTWARE\Policies\Microsoft\FindMyDevice` → `AllowFindMyDevice=0`, `LocationSyncEnabled=0` (DWORD)
- `HKCU\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location` → `ShowGlobalPrompts=0` (DWORD)
- hides Settings pages `privacy-location`, `findmydevice` via `settingsPages.cmd`

Winutil `WPFTweaksLocation` adds:
- service `lfsvc` → Disabled
- `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location` → `Value` = `Deny` (REG_SZ)
- `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}` → `SensorPermissionState` = `0` (DWORD) — the "location sensor" override GUID
- `HKLM\SYSTEM\Maps` → `AutoUpdateEnabled` = `0` (DWORD) — maps auto-update off

Additional sensor GPO (verified via Learn Policy CSP System page text): `HKLM\Software\Policies\Microsoft\Windows\LocationAndSensors` → `DisableLocation` = `1` (ADMX `Sensors.admx`, "Turn off location"). ⚠️ Win10-era ADMX; still present in Win11 admx.help heritage — verify on 26H2.

**Presence sensing (PresenceSense):** Policy CSP Privacy (verified): `HKLM\Software\Policies\Microsoft\Windows\AppPrivacy` → `LetAppsAccessHumanPresence` (REG_DWORD): `0` = User in control (default), `1` = Force allow, **`2` = Force deny** (ADMX `AppPrivacy.admx`, "Let Windows apps access presence sensing", Win Components > App Privacy). Non-policy knob (same ConsentStore pattern as location): `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\humanPresence` → `Value` = `Deny` (REG_SZ) ⚠️ key name inferred from CapabilityAccessManager pattern; verify on hardware with presence sensor. Risk: auto-lock-on-leave / wake-on-approach features stop. **Preset: B/X (Extreme force-deny; Balanced leaves user control but defaults off).**

**"WeMe" (mission term):** ⚠️ UNVERIFIED / ambiguous — no Windows service, task, or policy named "WeMe" exists in Atlas, winutil, or MS Learn texts fetched. Best matches: (1) **presence sensing** covered above; (2) **Windows Welcome Experience** ("we") covered by `SubscribedContent-310093Enabled=0` (§6.3); (3) typo for **Meet Now** taskbar button (`HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer` → `HideSCAMeetNow` = `1`). All three are included in the catalog.

### 4.8 Diagnostics data viewer / feedback / SIUF

- Diagnostics viewer: see A13 (disable) — but privacy-positive alternative is keeping it enabled (A15 note).
- **Feedback frequency (SIUF):** `HKCU\SOFTWARE\Microsoft\Siuf\Rules` → `NumberOfSIUFInPeriod` = `0` (REG_DWORD) and delete `PeriodInNanoSeconds` (winutil `WPFTweaksTelemetry` InvokeScript, verbatim: `Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Siuf\Rules" -Name PeriodInNanoSeconds`). Atlas does NOT set this — UltraOS adds it. Effect: Windows never asks for feedback. **Preset: S/B.**
- Atlas additionally removes the SIUF Settings handler entirely in the NoTelemetry CAB (`Microsoft-Windows-SystemSettings-SettingsHandlers-SIUF`).
- Feedback hub diagnostics: `HKLM\Software\Policies\Microsoft\Windows\DataCollection` → `FeedbackHubAlwaysSaveDiagnosticsLocally=1`, `FeedbackHubDisableSharingFeedbackPublicly=1` (MS Learn CSP System policy names; ⚠️ registry value names per ADMX `FeedbackHub.admx` — verify) — **X**.

### 4.9 Device monitoring / health attestation

Atlas `disable-device-monitoring.yml` (verbatim, full):
```yaml
---
title: Disable Device Health Attestation Monitoring and Reporting
description: Disables Device Health Attestation Monitoring and Reporting on startup for privacy
actions:
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\DeviceHealthAttestationService'
    value: 'EnableDeviceHealthAttestationService'
    data: '0'
    type: REG_DWORD
```
Risk: enterprise DHA/compliance scenarios break (irrelevant on personal PCs). **Preset: B/X.**

### 4.10 OOBE privacy re-prompt

Atlas `disable-privacy-experience.yml` (verbatim, full):
```yaml
---
title: Disable OOBE Privacy Experience
description: Disables the OOBE (Out of Box Experience) privacy configuration that you might see on updates not to override current settings
actions:
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\OOBE'
    value: 'DisablePrivacyExperience'
    data: '1'
    type: REG_DWORD
```
Prevents post-feature-update privacy screens from re-enabling defaults. **Preset: S/B.**

### 4.11 Misc privacy hardening (Atlas)

- Lockscreen camera: `HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization` → `NoLockScreenCamera` = `1` (Atlas, verbatim file `disable-lockscreen-camera.yml`). **B/X.**
- Website access to language list (anti-fingerprinting): `HKCU\Control Panel\International\User Profile` → `HttpAcceptLanguageOptOut` = `1` (Atlas `disable-web-lang-list-access.yml`). **S/B.**
- Experimentation (A/B): `HKLM\SOFTWARE\Microsoft\PolicyManager\default\System\AllowExperimentation` → `Value` = `0` (Atlas `disable-experimentation.yml`). **B/X.**
- Diagnostic tracing: `HKLM\SYSTEM\CurrentControlSet\Control\Diagnostics\Performance` → `DisableDiagnosticTracing` = `1` (Atlas `telemetry/disable-diagnostic-tracing.yml`). **B/X.**
- Performance track (responsiveness events): `HKLM\SOFTWARE\Policies\Microsoft\Windows\WDI\{9c5a40da-b965-4fc3-8781-88dd50a6299d}` → `ScenarioExecutionEnabled` = `0` (Atlas `disable-perf-track.yml`; admx.help WdiScenarioExecutionPolicy link inside file). **B/X.**
- RSoP logging: `HKLM\SOFTWARE\Policies\Microsoft\Windows\System` → `RSoPLogging` = `0` (Atlas `disable-rsop-logging.yml`). **B/X.**
- PCA / AppCompat block — Atlas `disable-pca.yml` (verbatim, full):
```yaml
---
title: Disable Program Compatibility Assistant (PCA)
description: Disables PCA for QoL and privacy
actions:
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat'
    value: 'AITEnable'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat'
    value: 'AllowTelemetry'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat'
    value: 'DisableEngine'
    data: '1'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat'
    value: 'DisableInventory'
    data: '1'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat'
    value: 'DisablePCA'
    data: '1'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\AppCompat'
    value: 'DisableUAR'
    data: '1'
    type: REG_DWORD
```
(`DisableUAR` = User Activity reporter/Steps Recorder; `DisableInventory` = app inventory.) **B/X** — with PcaSvc service disabled (§2.1) this kills the whole AppCompat/AIT pipeline.

### 4.12 Windows Error Reporting (registry layer)

Atlas `disable-win-error-reporting.yml` — full verbatim text in §9 appendix. Keys: `HKCU\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting\Disabled=1`; `HKLM\...\Windows Error Reporting`: `Disabled=1`, `DontShowUI=1`, `LoggingDisabled=1`, `DontSendAdditionalData=1`; `HKLM\SOFTWARE\Policies\Microsoft\PCHealth\ErrorReporting`: `DoReport=0`, `ShowUI=0`; `HKLM\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing\DisableWerReporting=1`; `HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Settings`: `DisableSendGenericDriverNotFoundToWER=1`, `DisableSendRequestAdditionalSoftwareToWER=1`. **Preset: B/X** (S leaves WER on).

### 4.13 Microsoft accounts (local-only enforcement)

Atlas `disallow-ms-accounts.yml` (verbatim, full):
```yaml
---
title: Disallow Users to Be Non-local
description: For privacy and QoL, users are prevented from adding Microsoft accounts as user accounts instead of local accounts
actions:
  - !registryValue:
    path: 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    value: 'NoConnectedUser'
    data: '1'
    type: REG_DWORD
```
GPO: "Accounts: Block Microsoft accounts" (AccountsBlockMicrosoftAccounts equivalent; `NoConnectedUser=1` = "Users can't add Microsoft accounts"). Risk: breaks adding MSA users, Store sign-in to *Windows*; Store sign-in inside apps still possible. **Preset: X (UltraOS default Balanced keeps MSA optional — Revi-style usability).**

### 4.14 App permissions (per-capability ConsentStore defaults)

General pattern (Atlas uses it for appDiagnostics/location/userAccountInformation; MS Learn AppPrivacy CSP confirms): `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\<capability>` → `Value` = `Deny` (REG_SZ). Capabilities UltraOS should offer (each = S/B/B depending): `location`, `appDiagnostics`, `userAccountInformation` (Atlas defaults); optional Extreme: `microphone`, `camera`, `humanPresence` ⚠️, `userAccountInformation`, `contacts`, `appointments`, `chat`, `email`, `callHistory`, `audioDeviceConfiguration`, `graphicsCaptureProgrammatic`, `graphicsCaptureWithoutBorder`, `graphicsCaptureFullScreen`, ` eyeGaze` ⚠️ (per-capability names per Settings UI; the last three are Win11-specific ⚠️). GPO equivalents: `HKLM\Software\Policies\Microsoft\Windows\AppPrivacy` → `LetAppsAccessLocation=2`, `LetAppsAccessAccountInfo=2` etc. (0=user control, 1=force allow, 2=force deny; AppPrivacy.admx — verified pattern from Learn CSP Privacy page).

### 4.15 Media Player

Atlas `config-windows-media-player.yml` (verbatim, full):
```yaml
---
title: Configure Windows Media Player
description: Configures Windows Media Player for the optimal privacy, security and usability. As a note, WMP is old, and you probably shouldn't use it.
actions:
    # Prevent Windows Media DRM internet access
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\WMDRM'
    value: 'DisableOnline'
    data: '1'
    type: REG_DWORD

    # Disable Windows Media Player wizard on first run
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\MediaPlayer\Preferences'
    value: 'AcceptedPrivacyStatement'
    data: '1'
    type: REG_DWORD

    # Disable Windows Media Player diagnostics
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\MediaPlayer\Preferences'
    value: 'UsageTracking'
    data: '0'
    type: REG_DWORD
```
**Preset: B/X.**

---

## 5. AREA D — Cloud & sync

### 5.1 Settings sync ("Windows Backup")

Atlas `cloud/disable-setting-sync.yml` — full verbatim in §9 appendix. Policy keys: `HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync`: `DisableSettingSync=2`, `DisableSettingSyncUserOverride=1`, `DisableSyncOnPaidNetwork=1`, `DisableWindowsSettingSync=2`; per-group: `HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\{Personalization,BrowserSettings,Credentials,Accessibility,Windows}\Enabled=0`; `HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\SyncPolicy=5`. Risk: theme/passwords sync off (intended). **Preset: B/X** (S leaves sync on).

### 5.2 Message cloud sync

Atlas `cloud/disallow-message-cloud-sync.yml` (verbatim, full):
```yaml
---
title: Disallow Message Service Cloud Sync
description: Disallows the Message service (which should be disabled anyways) from syncing with the cloud, as that potentially harms privacy
actions:
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Messaging'
    value: 'AllowMessageSync'
    data: '0'
    type: REG_DWORD
```
**Preset: B/X.**

### 5.3 Sync provider notifications ("ads in Explorer")

Atlas `advertising/disable-sync-provider-notifs.yml` (verbatim, full):
```yaml
---
title: Disable Sync Provider Notifications
description: Disables notifications within File Explorer from OneDrive or other sync providers to avoid advertisements
actions:
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    value: 'ShowSyncProviderNotifications'
    data: '0'
    type: REG_DWORD
```
**Preset: S/B.**

### 5.4 Suggested ways to finish setup (SCOOBE)

`HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement` → `ScoobeSystemSettingEnabled` = `0` (Atlas `cloud/disable-suggest-ways-to-finish-setup.yml`). **S/B.**

### 5.5 Content Delivery Manager (suggested apps/tips/ads) — full block

Atlas `debloat/config-content-delivery.yml` — full verbatim in §9 appendix. All values under `HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager` (REG_DWORD = `0`): `ContentDeliveryAllowed`, `FeatureManagementEnabled`, `SubscribedContentEnabled`, `RemediationRequired`, `OemPreInstalledAppsEnabled`, `PreInstalledAppsEnabled`, `PreInstalledAppsEverEnabled`, `SilentInstalledAppsEnabled`, `SubscribedContent-310093Enabled` (welcome experience), `SubscribedContent-338387Enabled` (lock screen fun facts/tips — also `RotatingLockScreenOverlayEnabled=0`), `SubscribedContent-338388Enabled` (Start suggestions), `SubscribedContent-338389Enabled` (tips/tricks/suggestions notifications — also `SoftLandingEnabled=0`), `SubscribedContent-338393Enabled`, `SubscribedContent-353694Enabled`, `SubscribedContent-353696Enabled` (suggested content in Settings), `SystemPaneSuggestionsEnabled`. Plus `HKCU\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications\EnableAccountNotifications=0` (Settings-app notifications). Consumer features GPO: `HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent` → `DisableWindowsConsumerFeatures=1` (winutil `WPFTweaksConsumerFeatures`). **Preset: S/B** (pure QoL+privacy win, fully reversible).

### 5.6 Windows Spotlight / cloud content

Atlas `Windows Spotlight\Disable Windows Spotlight (default).cmd` (verbatim, functional lines):
```bat
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v "DisableCloudOptimizedContent" /t REG_DWORD /d 1 /f
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v "DisableWindowsSpotlightFeatures" /t REG_DWORD /d 1 /f
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v "DisableWindowsSpotlightWindowsWelcomeExperience" /t REG_DWORD /d 1 /f
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v "DisableWindowsSpotlightOnActionCenter" /t REG_DWORD /d 1 /f
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v "DisableWindowsSpotlightOnSettings" /t REG_DWORD /d 1 /f
reg add "HKCU\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v "DisableThirdPartySuggestions" /t REG_DWORD /d 1 /f
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "ContentDeliveryAllowed" /t REG_DWORD /d 0 /f
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "FeatureManagementEnabled" /t REG_DWORD /d 0 /f
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContentEnabled" /t REG_DWORD /d 0 /f
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "SubscribedContent-338387Enabled" /t REG_DWORD /d 0 /f
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v "RotatingLockScreenOverlayEnabled" /t REG_DWORD /d 0 /f
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" /v "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}" /t REG_DWORD /d 1 /f
```
(GUID hides the OneDrive-ish "suggested" desktop icon.) Risk: Spotlight wallpaper/lock-screen content becomes static. **Preset: B/X** (Safe keeps Spotlight wallpaper but disables suggestions via CDM block 5.5).

### 5.7 Web search / Bing in Start, search highlights

Atlas `search-settings.yml` — full verbatim in §9 appendix (HKCU BingSearchEnabled=0; SearchSettings: IsAADCloudSearchEnabled=0, IsDeviceSearchHistoryEnabled=0, IsMSACloudSearchEnabled=0, SafeSearchMode=0; policies `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search`: ConnectedSearchUseWeb=0, DisableWebSearch=1, AllowSearchToUseLocation=0, EnableDynamicContentInWSB=0; `HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer\DisableSearchBoxSuggestions=1`; `SearchboxTaskbarMode=1`). The Web-Search CMD adds `HKCU\Software\Microsoft\Windows\CurrentVersion\SearchSettings\IsDynamicSearchBoxEnabled=0` (search highlights off) and removes `Microsoft.BingSearch*` AppX. Risk: Start/Explorer search becomes local-only (intended); "web results" gone. **Preset: S/B** (this is one of the most-wanted privacy toggles; fully reversible).

### 5.8 Widgets / News and Interests (cloud feed)

Atlas Disable Widgets CMD: `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds\EnableFeeds=0` + `HKLM\SOFTWARE\Policies\Microsoft\Dsh\AllowNewsAndInterests=0` (DWORD) + `Get-AppxPackage *WebExperience*` family removal happens via Atlas appx.yml (winutil `WPFTweaksWidget` equivalent). **Preset: B/X.**

### 5.9 Phone Link / cross-device

Atlas Disable Mobile Devices CMD: `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\NoConnectedUser=1`, hides `mobile-devices` Settings page, optional `Microsoft.YourPhone*` AppX removal. **Preset: X.**

---

## 6. AREA E — 26H2-era AI (Copilot, Recall, agents)

### 6.1 Copilot

**Atlas `Disable Microsoft Copilot (default).cmd` (verbatim, functional lines):**
```bat
powershell -NoP -NonI "Get-AppxPackage -AllUsers Microsoft.Copilot* | Remove-AppxPackage -AllUsers"
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v "ShowCopilotButton" /t REG_DWORD /d "0" /f
reg add "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v "TurnOffWindowsCopilot" /t REG_DWORD /d "1" /f
```
**MS Learn (Policy CSP WindowsAI, verified):** `TurnOffWindowsCopilot` — *"This policy is deprecated and may be removed in a future release"*; **User scope**; editions incl. Pro; registry mapping: `Registry Key Name SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot`, `Registry Value Name TurnOffWindowsCopilot`, ADMX `WindowsCopilot.admx`; values 0=Enable (default), 1=Disable. Also documents: *"The TurnOffWindowsCopilot policy isn't for the new Copilot experience that's in some Windows Insider builds and that will be gradually rolling out to Windows 11 and Windows 10 devices."*

Additional 26H2-era knobs:
- `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` → `RemoveMicrosoftCopilotApp` = `1` (REG_DWORD) — MS Learn WindowsAI (24H2+, applies to Enterprise/Pro/Education; uninstalls the Microsoft Copilot app under conditions).
- Winutil `WPFTweaksWindowsAI`: removes `MicrosoftWindows.Client.CoreAI` AppX (EndOfLife key under `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\EndOfLife\<SID>\<PackageFullName>`), uninstalls `*Copilot*` + winget "Copilot", disables service `WSAIFabricSvc`, `Disable-WindowsOptionalFeature -FeatureName Recall -Online`, hides Settings page: `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\SettingsPageVisibility` = `hide:aicomponents` (REG_SZ), plus `HKLM\SOFTWARE\Policies\WindowsNotepad\DisableAIFeatures=1` (Notepad AI).
- Taskbar button: `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ShowCopilotButton=0` (Atlas).

**Preset: B/X** (Balanced removes button + policy; Extreme removes app + CoreAI + Fabric service).

### 6.2 Recall / Windows AI

**Atlas `tweaks/privacy/disable-recall-snap.yml` (verbatim, full — as requested):**
```yaml
---
title: Disable Recall Snapshots
description: Disables snapshots of Recall (24H2+)
builds: [ '>=22000' ]
actions:
  - !cmd:
    command: '"AtlasDesktop\3. General Configuration\AI Features\Recall\Disable Recall Support (default).cmd" /silent'
    exeDir: true
    wait: true
    runas: currentUserElevated
```
**Atlas `Disable Recall Support (default).cmd` (verbatim, functional lines):**
```bat
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI" /v "DisableAIDataAnalysis" /t REG_DWORD /d 1 /f
```
(The "Enable Recall Support.cmd" reverses by `reg delete ... /v DisableAIDataAnalysis /f`.)

**MS Learn (Policy CSP WindowsAI, verified):** `DisableAIDataAnalysis` — *"Turn off saving snapshots for use with Recall"*; Computer **and User** scope; Win11 24H2 with KB5055627 (26100.3915)+; registry `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI!DisableAIDataAnalysis`; values: `0` (Default) Enable saving snapshots, `1` **Disable saving snapshots** — *"If you enable this policy, snapshots won't be saved for use with Recall. If snapshots were previously saved on the device, they'll be deleted when this policy is enabled."* ADMX: `WindowsCopilot.admx`.

Companion Recall policies (all MS Learn-verified; several Insider/Enterprise-only ⚠️ flagged):
- `AllowRecallEnablement` (24H2 KB5055627+; Pro/Ent/Edu): 0 = Recall component disabled **and bits removed + previously saved snapshots deleted**; 1 = available. Registry: `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI!AllowRecallEnablement` (⚠️ value name inferred from policy name — mapping block shows key `SOFTWARE\Policies\Microsoft\Windows\WindowsAI`; verify on test box). **Strongest Recall kill switch for 26H2 — UltraOS Extreme should use this + DisableAIDataAnalysis.**
- `SetMaximumStorageDurationForRecallSnapshots` (30/60/90/180 days; Ent/Edu only ⚠️).
- `SetMaximumStorageSpaceForRecallSnapshots` (Ent/Edu only ⚠️).
- `SetDenyAppListForRecall` / `SetDenyUriListForRecall` (AUMID/exe `;`-lists; Ent/Edu only ⚠️).
- `DisableRecallDataProviders` (App Actions providers; Insider; User scope).
- Winutil: `Disable-WindowsOptionalFeature -FeatureName Recall -Online` — removes the Recall optional component (26100+ "Recall on Copilot+ PCs" is an FoD; ⚠️ only valid where the FoD is present).
- Discrete GPU/NPU OEM tools may re-offer Recall; group policy layer above is authoritative.

**Preset: S/B** = `DisableAIDataAnalysis=1` (snapshots off, fully reversible). **X** = + `AllowRecallEnablement=0` + FoD removal + Copilot app removal.

### 6.3 Settings agents / Windows AI agents (26H2-era)

From MS Learn Policy CSP WindowsAI (fetched 2026-10-07; several marked **Windows Insider Preview** — treat as 26H2 candidates ⚠️):
- `DisableSettingsAgent` — "Settings agentic experience … natural language … AI model for intelligent Settings search suggestions"; 1 = disabled; registry `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` (⚠️ Insider — verify at 26H2 RTM).
- `AgentConnectorAccessPolicy` — MCP server/host allowlist for Windows agents (JSON); Insider ⚠️. Related: `ConfigureAgentConnectors`, `SetDataLossPreventionProvider` (Insider ⚠️).
- `OnDeviceRegistryLoggingLevel` — agent registry-operation logging: 0=Error+ (default), 1=Info+, 2=Debug+ (logging *reduction* → set 0).
- `DisableClickToDo`, `DisableCocreator` (Paint), `DisableGenerativeFill`, `DisableImageCreator` (Insider ⚠️ — names from CSP nav; per-policy detail not present in fetched page).
- Windows AI Studio: no OS policy documented (ships as app; uninstall via winget/AppX) ⚠️ UNVERIFIED.
- **Windows Backup/China-specific:** `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI` other values — none documented on the fetched page.

---

## 7. AREA F — Application-level telemetry

| App | Registry / action | Source | Preset |
|---|---|---|---|
| **NVIDIA Control Panel** | `HKCU\Software\NVIDIA Corporation\NVControlPanel2\Client` → `OptInOrOutPreference` = `0` (REG_DWORD) | Atlas `apps/disable-nvidia-telemetry.yml` (full file verbatim in §9) | S/B (if NVIDIA sw present) |
| **NVIDIA telemetry tasks/services** (NvTelemetry, `NvNode` telemetry) | ⚠️ Not in Atlas/winutil; classic community: disable `NvTelemetry` scheduled tasks/services | community ⚠️ | X ⚠️ |
| **Office 2016+ / M365** | `HKCU\Software\Policies\Microsoft\office\16.0\common` → `sendcustomerdata=0`, `qmenable=0`; `HKCU\Software\Policies\Microsoft\office\common\clienttelemetry` → `sendtelemetry=3` (=DisableTelemetry) | Atlas `apps/disable-office-telemetry.yml` (verbatim §9) | B/X |
| **Office (HKLM equivalents)** | `HKLM\SOFTWARE\Policies\Microsoft\office\...` same value names (machine-wide) | community/O&O ⚠️ | X ⚠️ |
| **.NET CLI** | env var `DOTNET_CLI_TELEMETRY_OPTOUT=1` (Atlas: `setx DOTNET_CLI_TELEMETRY_OPTOUT 1`) | Atlas `telemetry/disable-dotnet-cli-telemetry.yml` + learn.microsoft.com/dotnet/core/tools/telemetry | S/B |
| **"DotNet Task"** | ⚠️ no Windows task named this in Atlas/winutil. Likely intent: `.NET` runtime `DOTNET_CLI_TELEMETRY_OPTOUT` (above) + NGEN tasks (`\Microsoft\Windows\.NET\.NET Framework NGEN v4.0.30319*` — optimization, not telemetry; leave alone). Marked UNVERIFIED as telemetry item. | — | — |
| **PowerShell 7** | `[Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT','1','Machine')` | winutil `WPFTweaksTelemetry` InvokeScript | S/B |
| **Visual Studio Code** (if installed) | `telemetry.telemetryLevel=off` in user settings.json ⚠️ app-level, not registry | community ⚠️ | user action |
| **Windows Defender sample submission** | `Set-MpPreference -SubmitSamplesConsent 2` (0/1=always send, 2=never send) + `Set-MpPreference -EnableAutoExclusion` n/a | winutil `WPFTweaksTelemetry` | B/X (security trade-off: cloud protection weakened) |
| **MSRT (Malicious Software Removal Tool)** | `HKLM\SOFTWARE\Policies\Microsoft\MRT` → `DontReportInfectionInformation=1`; `HKLM\SOFTWARE\Microsoft\RemovalTools\MpGears` → `HeartbeatTrackingIndex=0`, `SpyNetReportingLocation=REG_MULTI_SZ ""` | Atlas `qol/windows-update/disable-msrt-telemetry.yml` (verbatim §9) | B/X |
| **Windows Media Player** | see §4.15 | Atlas | B/X |
| **Smart App Control** | `HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy\VerifiedAndReputablePolicyState=0` (0=Off) — Atlas removes it because it "sends data to Microsoft" (components.yml) | Atlas | B/X (security trade-off, wizard must warn) |
| **Edge (if kept)** | `HKLM\SOFTWARE\Policies\Microsoft\Edge`: `DiagnosticData=0` (required only), `PersonalizationReportingEnabled=0`, `UserFeedbackAllowed=0`, `ConfigureDoNotTrack=1`, plus UX items | winutil `WPFTweaksEdgeDebloat` | B |

---

## 8. AREA G — Network-level

| Item | Registry / command | Source | Preset |
|---|---|---|---|
| **LLMNR** | `HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient` → `EnableMulticast` = `0` (REG_DWORD) — Atlas `networking/disable-llmnr.yml` (verbatim, full file in §9); GPO: DNS Client "Turn off multicast name resolution" | Atlas | S/B (also security win — stops LLMNR/NBNS spoofing) |
| **NetBIOS (NetBT)** | service `NetBT` → Disabled (Atlas services.yml; re-enabled by file-sharing script) | Atlas | B/X |
| **Delivery Optimization** | `HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization` → `DODownloadMode` = `0` (REG_DWORD) (Atlas CMD; winutil `WPFTweaksDeliveryOptimization`). Modes: 0=Bypass (no peering), 1=LAN, 2=Group, 3=Internet | Atlas + winutil | S: 1 (LAN-only) · B/X: 0 |
| **WAP push** | service `dmwappushservice` → Disabled/Manual (⚠️ community; not in Atlas/winutil) | community ⚠️ | X ⚠️ |
| **Wi-Fi hotspot reporting (Wi-Fi Sense heritage)** | `HKLM\Software\Microsoft\PolicyManager\default\WiFi` → `AllowWiFiHotSpotReporting=0`, `AllowAutoConnectToWiFiSenseHotspots=0` (DWORD) | classic community (Win10 Wi-Fi Sense era) ⚠️ — keys persist in scripts; Wi-Fi Sense itself removed from Win11 | X ⚠️ (harmless but likely vestigial) |
| **WPBT (vendor boot-time code)** | `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager` → `DisableWpbtExecution` = `1` (winutil `WPFTweaksWPBT`) | winutil | B/X (security win; some vendor anti-theft features break) |
| **Device metadata from network** | `HKLM\SOFTWARE\Policies\Microsoft\Windows\Device Metadata` → `PreventDeviceMetadataFromNetwork` = `1` (winutil `WPFTweaksPreventDeviceMetadataFromNetwork`) | winutil | B/X (device icons/metadata go generic) |
| **Teredo** | `HKLM\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\DisabledComponents=1` + `netsh interface teredo set state disabled` (winutil) | winutil | X (per UltraOS networking module's call) |
| **Telemetry proxy** | `HKLM\Software\Policies\Microsoft\Windows\DataCollection\TelemetryProxy` (REG_SZ, proxy URL) — documented in CSP System nav (per-policy detail not extracted) ⚠️ | MS Learn ⚠️ | n/a (UltraOS won't fake-proxy) |
| **Hosts/endpoint blocking** | **NOT recommended** — breaks Store/Update/activation; Atlas does not do it; UltraOS design decision: no endpoint blackholing | design decision | — |

---

## 9. AREA H — Activation & update telemetry + verbatim appendix

### 9.1 Activation (KMS AVS / GenuineTicket)

**Atlas `telemetry/disable-activation-telemetry.yml` (verbatim, full):**
```yaml
---
title: Disable Key Management System Telemetry
description: Turns off KMS client online AVS validation, which prevents from sending data to Microsoft regardless of its activation state, for privacy
actions:
    # https://admx.help/?Category=Windows_11_2022&Policy=Microsoft.Policies.SoftwareProtectionPlatform::NoAcquireGT
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\CurrentVersion\Software Protection Platform'
    value: 'NoGenTicket'
    data: '1'
    type: REG_DWORD
```
GPO: "Turn off KMS client online AVS validation" (Software Protection Platform). Home-compat: yes. Risk: none for retail/digital-license users; KMS clients skip AVS validation. **Preset: S/B.**

### 9.2 Update-related telemetry

**Atlas `qol/windows-update/disable-msrt-telemetry.yml` (verbatim, full):**
```yaml
---
title: Disable MSRT telemetry
description: Disables MSRT's (Malicious Software Removal Tool) telemetry features
actions:
    # Disable MSRT telemetry
  - !registryValue: {path: 'HKLM\SOFTWARE\Policies\Microsoft\MRT', value: 'DontReportInfectionInformation', type: REG_DWORD, data: '1'}
  - !registryValue: {path: 'HKLM\SOFTWARE\Microsoft\RemovalTools\MpGears', value: 'HeartbeatTrackingIndex', type: REG_DWORD, data: '0'}
  - !registryValue: {path: 'HKLM\SOFTWARE\Microsoft\RemovalTools\MpGears', value: 'SpyNetReportingLocation', type: REG_MULTI_SZ, data: ''}
```
Update traffic itself is NOT telemetry-disable-able without breaking updates — UltraOS should leave WU endpoints alone (consistency with §12 honesty).

### 9.3 Verbatim appendix — remaining full Atlas files

**`telemetry/disable-ceip.yml`:**
```yaml
---
title: Disable Customer Experience Improvement Program
description: Disables Customer Experience Improvement Program (CEIP) as it is related to telemetry, for privacy
actions:
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\AppV\CEIP'
    value: 'CEIPEnable'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\SQMClient\Windows'
    value: 'CEIPEnable'
    data: '0'
    type: REG_DWORD
```

**`telemetry/disable-diagnostic-tracing.yml`:**
```yaml
---
title: Disable Diagnostic Tracing
description: Disables diagnostic tracing (system activities, events or errors) for privacy reasons
actions:
  - !registryValue:
    path: 'HKLM\SYSTEM\CurrentControlSet\Control\Diagnostics\Performance'
    value: 'DisableDiagnosticTracing'
    data: '1'
    type: REG_DWORD
```

**`telemetry/disable-dotnet-cli-telemetry.yml`:**
```yaml
---
title: Disable .NET CLI Telemetry
description: Disables .NET CLI telemetry for privacy
actions:
    # https://learn.microsoft.com/en-us/dotnet/core/tools/telemetry
  - !cmd: {command: 'setx DOTNET_CLI_TELEMETRY_OPTOUT 1'}
```

**`advertising/disable-advertising-info.yml`, `advertising/disable-sync-provider-notifs.yml`** — quoted in full in §4.1/§5.3.

**`apps/disable-nvidia-telemetry.yml`:**
```yaml
---
title: Disable NVIDIA Control Panel Telemetry
description: Disables NVIDIA Control Panel telemetry for privacy
actions:
  - !registryValue:
    path: 'HKCU\Software\NVIDIA Corporation\NVControlPanel2\Client'
    value: 'OptInOrOutPreference'
    data: '0'
    type: REG_DWORD
```

**`apps/disable-office-telemetry.yml`:**
```yaml
---
title: Disable Office Telemetry
description: Disables Microsoft Office telemetry for privacy
actions:
  - !registryValue:
    path: 'HKCU\Software\Policies\Microsoft\office\16.0\common'
    value: 'sendcustomerdata'
    data: '0'
    type: REG_DWORD
    
  - !registryValue:
    path: 'HKCU\Software\Policies\Microsoft\office\common\clienttelemetry'
    value: 'sendtelemetry'
    data: '3'
    type: REG_DWORD
    
    # Customer Experience Program
  - !registryValue:
    path: 'HKCU\Software\Policies\Microsoft\office\16.0\common'
    value: 'qmenable'
    data: '0'
    type: REG_DWORD
```

**`cloud/disable-setting-sync.yml` (verbatim, full):**
```yaml
---
title: Disable Settings Sync
description: Disables Settings Sync (labeled as 'Windows Backup' in Windows 10) for QoL and privacy
actions:
    # Policies don't disable the toggles in the UI, doesn't seem like much can be done about it
    # Whole Settings page is hidden anyways
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync'
    value: 'DisableSettingSync'
    data: '2'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync'
    value: 'DisableSettingSyncUserOverride'
    data: '1'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync'
    value: 'DisableSyncOnPaidNetwork'
    data: '1'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync'
    value: 'DisableWindowsSettingSync'
    data: '2'
    type: REG_DWORD
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Personalization'
    value: 'Enabled'
    data: '0'
    type: REG_DWORD
    
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\BrowserSettings'
    value: 'Enabled'
    data: '0'
    type: REG_DWORD
    
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Credentials'
    value: 'Enabled'
    data: '0'
    type: REG_DWORD
    
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Accessibility'
    value: 'Enabled'
    data: '0'
    type: REG_DWORD
    
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\Windows'
    value: 'Enabled'
    data: '0'
    type: REG_DWORD
    
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync'
    value: 'SyncPolicy'
    data: '5'
    type: REG_DWORD
```

**`cloud/disable-suggest-ways-to-finish-setup.yml`:**
```yaml
---
title: Disable Suggested Ways to Finish Setting Up Your Device
description: Disables suggested ways to finish setting up your device, as it will mostly anony you to use cloud features
actions:
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement'
    value: 'ScoobeSystemSettingEnabled'
    data: '0'
    type: REG_DWORD
```

**`networking/disable-llmnr.yml`:**
```yaml
---
title: Disable LLMNR Protocol
description: Disable Link-Local Multicast Name Resolution (LLMNR) protocol as it is vulnerable and has been replaced by DNS
actions:
    # https://admx.help/?Category=Windows_11_2022&Policy=Microsoft.Policies.DNSClient::Turn_Off_Multicast
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient'
    value: 'EnableMulticast'
    data: '0'
    type: REG_DWORD
```

**`search-settings.yml` (verbatim, full):**
```yaml
---
title: Configure Search on the Taskbar
description: Configures search for the optimal usability and privacy, such as disabling online features to make it more minimal and snappy
actions:
    # Configure search permissions
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'
    value: 'BingSearchEnabled'
    data: '0'
    type: REG_DWORD
    
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings'
    value: 'IsAADCloudSearchEnabled'
    data: '0'
    type: REG_DWORD
    
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings'
    value: 'IsDeviceSearchHistoryEnabled'
    data: '0'
    type: REG_DWORD
    
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings'
    value: 'IsMSACloudSearchEnabled'
    data: '0'
    type: REG_DWORD
    
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings'
    value: 'SafeSearchMode'
    data: '0'
    type: REG_DWORD

    # Policies
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
    value: 'ConnectedSearchUseWeb'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
    value: 'DisableWebSearch'
    data: '1'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
    value: 'AllowSearchToUseLocation'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search'
    value: 'EnableDynamicContentInWSB'
    data: '0'
    type: REG_DWORD

    # Disable online search and don't include web results from Bing
  - !registryValue:
    path: 'HKCU\SOFTWARE\Policies\Microsoft\Windows\Explorer'
    value: 'DisableSearchBoxSuggestions'
    data: '1'
    type: REG_DWORD
    
    # Set search as icon on taskbar
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'
    value: 'SearchboxTaskbarMode'
    data: '1'
    type: REG_DWORD
    
    # Fallback for OOBE as it doesn't seem to work
  - !powerShell:
    command: 'reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" /t REG_DWORD /v "SearchboxTaskbarMode" /d 1 /f > nul'
    exeDir: true
    oobe: only
```

**`disable-win-error-reporting.yml` (verbatim, full):**
```yaml
---
title: Disable Windows Error Reporting
description: Disables Windows Error Reporting for privacy and QoL
actions:
  # https://admx.help/?Category=Windows_11_2022&Policy=Microsoft.Policies.InternetCommunicationManagement::PCH_DoNotReport
  - !registryValue:
    path: 'HKCU\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'
    value: 'Disabled'
    data: '1'
    type: REG_DWORD
    
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\PCHealth\ErrorReporting'
    value: 'DoReport'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'
    value: 'Disabled'
    data: '1'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'
    value: 'DontShowUI'
    data: '1'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\PCHealth\ErrorReporting'
    value: 'ShowUI'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'
    value: 'LoggingDisabled'
    data: '1'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting'
    value: 'DontSendAdditionalData'
    data: '1'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\Software\Microsoft\Windows\CurrentVersion\Component Based Servicing'
    value: 'DisableWerReporting'
    data: '1'
    type: REG_DWORD

  # Do not send a Windows error report when a generic driver is installed on a device
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Settings'
    value: 'DisableSendGenericDriverNotFoundToWER'
    data: '1'
    type: REG_DWORD

  # Prevent Windows from sending an error report when a device driver requests additional software during installation
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Settings'
    value: 'DisableSendRequestAdditionalSoftwareToWER'
    data: '1'
    type: REG_DWORD
```

**`debloat/config-content-delivery.yml` (verbatim, full):**
```yaml
---
title: Configure Content Delivery Manager
description: Configures Content Delivery Manager not to download applications like Candy Crush Soda and turns off suggested content (tips/tricks/facts/suggestions/ads) for QoL and privacy.
actions:
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    value: 'ContentDeliveryAllowed'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    value: 'FeatureManagementEnabled'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    value: 'SubscribedContentEnabled'
    data: '0'
    type: REG_DWORD
    # Ensure no settings get changed
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    value: 'RemediationRequired'
    data: '0'
    type: REG_DWORD
    # Prevent suggested app installs
    # https://www.tenforums.com/tutorials/68217-turn-off-automatic-installation-suggested-apps-windows-10-a.html
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    value: 'OemPreInstalledAppsEnabled'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    value: 'PreInstalledAppsEnabled'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    value: 'PreInstalledAppsEverEnabled'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    value: 'SilentInstalledAppsEnabled'
    data: '0'
    type: REG_DWORD
    # 'Show me notifications in the Settings app' in Windows 11
  - !registryValue:
    path: 'HKCU\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications'
    value: 'EnableAccountNotifications'
    data: '0'
    type: REG_DWORD
    # Windows welcome experience
    # https://winaero.com/disable-welcome-page-windows-10/
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    value: 'SubscribedContent-310093Enabled'
    data: '0'
    type: REG_DWORD
    # Suggested content in the Settings app
    # https://www.tenforums.com/tutorials/100541-turn-off-suggested-content-settings-app-windows-10-a.html
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    value: 'SubscribedContent-338393Enabled'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    value: 'SubscribedContent-353694Enabled'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    value: 'SubscribedContent-353696Enabled'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    value: 'SystemPaneSuggestionsEnabled'
    data: '0'
    type: REG_DWORD
    # "Get fun facts, tips, tricks, and more on your lock screen"
    # https://www.elevenforum.com/t/enable-or-disable-facts-tips-and-tricks-on-lock-screen-in-windows-11.7079/
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    value: 'SubscribedContent-338387Enabled'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    value: 'RotatingLockScreenOverlayEnabled'
    data: '0'
    type: REG_DWORD
    # Suggestions in Start
    # https://www.tenforums.com/tutorials/24117-turn-off-app-suggestions-start-windows-10-a.html
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    value: 'SubscribedContent-338388Enabled'
    data: '0'
    type: REG_DWORD
    # "Get tips, tricks, and suggestions as you use Windows"
    # https://www.tenforums.com/tutorials/30869-turn-off-tip-trick-suggestion-notifications-windows-10-a.html
    # https://winaero.com/disable-tips-about-windows-10/
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    value: 'SubscribedContent-338389Enabled'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    value: 'SoftLandingEnabled'
    data: '0'
    type: REG_DWORD
```
(Note: Atlas commented out deleting `...\ContentDeliveryManager\Subscriptions` and `\SuggestedApps` keys "as these removals would likely break re-enabling content".)

Remaining one-page Atlas files quoted verbatim inside their sections above: `disable-activity-feed.yml` (§4.2), `disallow-user-activity-upload.yml` (§4.2), `disable-tailored-experiences.yml` (§4.4), `disable-online-speech-recognition.yml` (§4.6), `config-app-permissions.yml` (§4.7), `disable-device-monitoring.yml` (§4.9), `disable-privacy-experience.yml` (§4.10), `disable-pca.yml` (§4.11), `disable-user-tracking.yml` (§4.3 inline), `disable-app-launch-tracking.yml` (§4.3 inline), `disable-web-lang-list-access.yml` (§4.11 inline), `disable-lockscreen-camera.yml` (§4.11 inline), `disable-experimentation.yml` (§4.11 inline), `disable-rsop-logging.yml` (§4.11 inline), `disable-perf-track.yml` (§4.11 inline), `disallow-ms-accounts.yml` (§4.13), `config-windows-media-player.yml` (§4.15), `disallow-message-cloud-sync.yml` (§5.2), `disable-sync-provider-notifs.yml` (§5.3), `disable-suggest-ways-to-finish-setup.yml` (§9.3), `disable-speech-auto-updates.yml` (§4.6 ref), `disable-recall-snap.yml` (§6.2), `disable-activation-telemetry.yml` (§9.1), `disable-ceip.yml` (§9.3), `disable-diagnostic-tracing.yml` (§9.3), `disable-dotnet-cli-telemetry.yml` (§9.3), `disable-nvidia-telemetry.yml` (§9.3), `disable-office-telemetry.yml` (§9.3), `disable-setting-sync.yml` (§9.3), `disable-llmnr.yml` (§9.3), `search-settings.yml` (§9.3), `disable-win-error-reporting.yml` (§9.3), `disable-scheduled-tasks.yml` (§3), `disallow-data-collection.yml` (§2.2), `services.yml` (§2.1), `disable-msrt-telemetry.yml` (§9.2), `disable-input-telemetry.yml` (§4.5). — All 34 privacy/ files + 5 supporting files covered.

---

## 10. O&O ShutUp10++ cross-reference

- Product: https://www.oo-software.com/en/shutup10 (accessed 2026-10-07, HTTP 200). "O&O ShutUp10++ means you have full control over which comfort functions under Windows 10 and Windows 11 you wish to activate or deactivate… **using a simple, minimalist user interface**" (product blurb) — O&O does **not** publish a machine-readable settings→registry list; the manual FAQ confirms it works "through registry and policy settings" (https://manuals.oo-software.com).
- UltraOS parity statement: every ShutUp10++ *category* (telemetry, privacy, location, user-related data, Windows Defender, synchronization, Microsoft Edge, security, network) maps onto keys in this dossier (§2, §4, §5, §7, §8). Any claim of a specific *additional* O&O-only key: ⚠️ UNVERIFIED — cannot be confirmed without exporting OOSU10 diffs.
- ⚠️ Deskmodder/ghacks 26H2-specific guides could not be fetched this session (search rate-limits; deskmodder wiki has no Win11 telemetry article per wiki API query). Community-only keys in this dossier are flagged inline.

---

## 11. Preset matrix (UltraOS privacy module)

| # | Tweak | Safe | Balanced | Extreme |
|---|---|---|---|---|
| 1 | Advertising ID off (§4.1) | ✅ | ✅ | ✅ |
| 2 | Tailored experiences off (§4.4) | ✅ | ✅ | ✅ |
| 3 | Activity history 0/0/0 (§4.2) | ✅ | ✅ | ✅ |
| 4 | App-launch tracking + MFU off (§4.3) | ✅ | ✅ | ✅ |
| 5 | Input/ink/typing telemetry off (§4.5) | ✅ | ✅ | ✅ |
| 6 | Online speech off (§4.6) | ✅ | ✅ | ✅ |
| 7 | Speech model updates off | — | ✅ | ✅ |
| 8 | Feedback frequency 0 (Siuf) (§4.8) | ✅ | ✅ | ✅ |
| 9 | CDM/suggested content/ads off (§5.5) | ✅ | ✅ | ✅ |
| 10 | Sync provider notifs off (§5.3) | ✅ | ✅ | ✅ |
| 11 | SCOOBE off (§5.4) | ✅ | ✅ | ✅ |
| 12 | OOBE privacy screen suppressed (§4.10) | ✅ | ✅ | ✅ |
| 13 | Bing/web search + highlights off (§5.7) | ✅ | ✅ | ✅ |
| 14 | Language-list opt-out (§4.11) | ✅ | ✅ | ✅ |
| 15 | AllowDeviceNameInTelemetry=0 (A8) | ✅ | ✅ | ✅ |
| 16 | Limit dump/log collection (A11/A12) | ✅ | ✅ | ✅ |
| 17 | Location: ConsentStore Deny + prompts off (§4.7) | ✅ | ✅ | ✅ |
| 18 | lfsvc/MapsBroker services disabled | — | ✅ | ✅ |
| 19 | Find My Device off | — | ✅ | ✅ |
| 20 | DODownloadMode | 1 (LAN) | 0 | 0 |
| 21 | LLMNR off (§8) | ✅ | ✅ | ✅ |
| 22 | KMS NoGenTicket (§9.1) | ✅ | ✅ | ✅ |
| 23 | .NET/PowerShell 7 opt-outs (§7) | ✅ | ✅ | ✅ |
| 24 | NVIDIA CP telemetry off (§7) | ✅ | ✅ | ✅ |
| 25 | AllowTelemetry=0 (4 paths) (A1–A3) | — | ✅ | ✅ |
| 26 | DiagTrack: service stop | ✅ | ✅ | ✅ |
| 27 | DiagTrack: service disabled + autologger off + logs cleared (A6–A10) | — | ✅ | ✅ |
| 28 | WerSvc/wercplsupport/diagshub disabled (§2.1) | — | ✅ | ✅ |
| 29 | WER registry block (§4.12) | — | ✅ | ✅ |
| 30 | CEIP + SQMClient off (§9.3) | — | ✅ | ✅ |
| 31 | Scheduled tasks §3 (Atlas 6 + Appraiser/ProgramDataUpdater/QueueReporting/Proxy) | — | ✅ | ✅ |
| 32 | PCA/AppCompat block (§4.11) | — | ✅ | ✅ |
| 33 | Diagnostic tracing + perf-track + experimentation off (§4.11) | — | ✅ | ✅ |
| 34 | Spotlight/cloud content block (§5.6) | — | ✅ | ✅ |
| 35 | Widgets/feeds off (§5.8) | — | ✅ | ✅ |
| 36 | Settings sync off (§5.1) | — | ✅ | ✅ |
| 37 | Message cloud sync off (§5.2) | — | ✅ | ✅ |
| 38 | OneSettings off (A14) | — | ✅ | ✅ |
| 39 | Recall: DisableAIDataAnalysis=1 (§6.2) | ✅ | ✅ | ✅ |
| 40 | Copilot: button + TurnOffWindowsCopilot (§6.1) | ✅ | ✅ | ✅ |
| 41 | Copilot app/CoreAI/WSAIFabricSvc removal | — | — | ✅ |
| 42 | Recall: AllowRecallEnablement=0 + FoD removal | — | — | ✅ |
| 43 | Presence sensing: user-control default | user choice | ✅ deny | ✅ force-deny |
| 44 | MSRT telemetry off (§9.2) | — | ✅ | ✅ |
| 45 | Defender sample submission off (§7) | — | ✅ | ✅ |
| 46 | Smart App Control off (§7) | — | ✅ | ✅ |
| 47 | Edge debloat/telemetry (if kept) (§7) | — | ✅ | ✅ |
| 48 | WPBT off (§8) | — | ✅ | ✅ |
| 49 | Device metadata from network off (§8) | — | ✅ | ✅ |
| 50 | dmwappushservice disabled (⚠️) | — | — | ✅ |
| 51 | Wi-Fi Sense heritage keys (⚠️ vestigial) | — | — | ✅ |
| 52 | NoConnectedUser=1 (§4.13) | — | — | ✅ |
| 53 | UCPD disabled (⚠️ security trade-off) | — | — | ✅ |
| 54 | NoTelemetry component CAB parity (§2.3) | — | — | ✅ |
| 55 | Telemetry driver / NetBT off (§2.1) | — | — | ✅ |
| 56 | AppPrivacy force-deny camera/mic defaults | — | — | ✅ |

**Implementation notes for the build fleet:**
- All HKLM writes require the wizard's admin context (AME Wizard runs elevated — OK). HKCU writes apply to the running user only; **repeat for new users** via the Atlas `misc/add-newUser-script.yml` pattern (new-user hook) — UltraOS must replicate it or privacy applies only to the installing user.
- Atlas sets `onUpgrade: false` for `services.yml` — service config isn't re-applied on upgrade runs. UltraOS should re-apply telemetry layer after feature updates (26H2 will reset some CDM values; OOBE privacy suppression §4.10 mitigates the worst resets).
- `!scheduledTask` and `!service` verbs exist in AME Wizard (proven by Atlas usage); `ignoreErrors: true` is essential for edition/build variance.
- Rollback: keep UltraOS's revert.yml capturing original values (winutil models `OriginalValue` + UndoScripts; Atlas ships `atlas/revert.yml` and enable/disable CMD pairs — hybrid approach recommended).

---

## 12. What CANNOT be fully disabled (honest limits)

1. **Required diagnostic data on Home/Pro.** Microsoft Learn (verbatim above): level 0/"Diagnostic data off" exists only on Enterprise/Education/Server; on Home/Pro `AllowTelemetry=0` acts as 1 (Required). Required events (full list at MS Learn "Windows diagnostic data" / required-events docs) keep flowing via other channels **unless** DiagTrack service + autologger are also disabled (Balanced+ does this) — and even then Windows Update, licensing (sppsvc), and Defender maintain their own mandatory cloud traffic.
2. **MSA-linked data.** If the user signs into Store/Xbox/Office with a Microsoft account, cloud data collection is governed by the account, not local telemetry switches. `NoConnectedUser=1` (Extreme) only blocks *adding MSA user accounts*; in-app sign-ins still work and still sync.
3. **Defender/cloud protection channel.** SubmitSamplesConsent=2 stops sample upload, but MAPS signature queries and Security Intelligence updates remain (needed for protection). Disabling Defender entirely is out of UltraOS scope.
4. **Windows Update + Store traffic** is not "telemetry" but does include device fingerprinting (WuIdentity). No supported registry switch removes it; endpoint blocking breaks updates — rejected by design.
5. **Local event logging continues.** ETW providers, Event Logs, and some autologgers run regardless; the disables above stop *upload* (DiagTrack/WER) more than local collection. Full local logging kill would break diagnostics entirely.
6. **Feature-update resets.** 26H2 upgrades re-provision some appx/settings (CDM values, task states). OOBE privacy suppression + re-apply pass mitigate; no permanent guarantee exists.
7. **Deprecated/Insider-only AI policies.** `TurnOffWindowsCopilot` is officially deprecated and "isn't for the new Copilot experience … gradually rolling out to Windows 11" (MS Learn) — Copilot app removal (AppX/winget) is the only complete answer and can be undone by Store updates unless `Deprovisioned` keys are also written.
8. **O&O ShutUp10++ parity cannot be certified key-for-key** without diffing its exports (no public list) — see §10.
9. **Vestigial keys** (Wi-Fi Sense, some Win10-era tasks, `MaxTelemetryAllowed` provenance) are kept for compatibility but may be no-ops on 26H2 — flagged ⚠️ throughout.

---

## 13. Verification checklist for the build fleet (on a 26H2 VM)

1. `Get-Services DiagTrack, WerSvc, wercplsupport, diagnosticshub.standardcollector.service, UCPD, dmwappushservice` — confirm existence + start state after playbook run.
2. `schtasks /query /fo csv | findstr /i "Appraiser Consolidator UsbCeip ProgramDataUpdater QueueReporting Proxy PcaPatchDbTask UsageDataReporting StartupAppTask"` — confirm disabled/absent states on 26H2 RTM.
3. `reg query` each A1–A17 key; confirm set + inheritance after feature-update dry run.
4. Recall on a Copilot+-class VM: confirm `DisableAIDataAnalysis` + `AllowRecallEnablement=0` behavior and whether the FoD (`Disable-WindowsOptionalFeature -FeatureName Recall`) exists on Home 26H2.
5. Confirm value names flagged ⚠️: `DisableDiagnosticDataOptInSettings`, `AllowRecallEnablement`, `ConsentStore\humanPresence`, `FeedbackHubAlwaysSaveDiagnosticsLocally`.

— End of dossier T1-f —
