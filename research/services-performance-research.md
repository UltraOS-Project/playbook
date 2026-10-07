# UltraOS Research Dossier — Services + Performance + Gaming + Network + Power (T1-g)

**Agent:** T1-g (services & performance catalog) | **Date:** 2026-10-07 | **License context:** UltraOS GPL-3.0, AME Wizard playbook, Win 11 26H2, editions Home+Pro
**Ground truth:** Atlas repo clone at `/home/z/my-project/repos/atlas` (Atlas-OS/Atlas, playbook v0.5.0, SupportedBuilds 26100/26200 — **no 26H2 support upstream**, our opportunity gap)
**Supplements:** Microsoft Learn IoT service guidance (fetched live 2026-10-07), web searches (dates cited), community knowledge — flagged `⚠️ UNVERIFIED` where not corroborated.

> Startup type codes used by Atlas `!service`/`setSvc.cmd` (writes `HKLM\SYSTEM\CurrentControlSet\Services\<svc>\Start` REG_DWORD):
> **0 = Boot, 1 = System, 2 = Automatic, 3 = Manual, 4 = Disabled**

---

## 0. Executive summary — Atlas philosophy (critical for UltraOS preset design)

1. **Atlas v0.5.0 is far more conservative than its reputation.** It disables only **7 services + 3 drivers** by default (see §1.1). SysMain, printing, Bluetooth, network discovery, SMB workstation, FSO/Game Bar, and even Defender tray defaults are **ENABLED** in v0.5.0 (confirmed by `Executables/DEFAULT.reg` states: `SuperFetch=1`, `Printing=1`, `Bluetooth=1`, `NetworkDiscovery=1`, `LanmanWorkstation=1`, `FSOGameBar=1`, `Mitigations=2` = Windows-default, `PowerSaving=1` = default power-saving, `Indexing=1` = minimal, `CpuIdle=1` = idle enabled).
2. **Atlas actively REMOVED classic tweaks as placebo:** `disable-paging.yml` is commented out of `tweaks.yml` with the note *"Disabled as there's no evidence it helps (likely placebo)"*. `disable-game-bar.yml` and `disable-llmnr.yml` are also commented out (the latter marked "Needed for compatibility"). UltraOS should mirror this honesty.
3. **Atlas does NOT ship the classic gamer network tweaks.** Repo-wide grep (2026-10-07) finds **zero** occurrences of `autotuninglevel`, `throttlingindex`, `TcpAckFrequency`/Nagle, RSS, or ECN commands. Its network file only configures **NIC adapter registry keywords** (see §5.1 verbatim) and uses `netsh ... reset` to restore. Community "network optimizer" registry sets (TcpAckFrequency=1, TCPNoDelay, NetworkThrottlingIndex=ffffffff) are **not Atlas ground truth** — map them to Extreme/optional with caveats.
4. **Atlas does NOT touch** HAGS (`HwSchMode`), Game Mode (`AllowAutoGameMode`), MPO (`OverlayTestMode`), GameInput, PCIe ASPM, or Xbox *services*. For HAGS it only ships a URL shortcut: `AtlasDesktop\5. Windows Settings\Default Graphics Settings (HAGS).url` → `ms-settings:display`. It removes only the **Xbox Console Companion app** (`Microsoft.XboxApp*` in `appx.yml`) and keeps Xbox services — even **excluding `Xbl*`/`Xbox*` from service-host-splitting** "to fix issues with Game Bar" (§6.6).
5. Options (wizard `playbook.conf`): `mitigations-disable`, `disable-power-saving`, `disable-hibernation`, `disable-core-isolation`, `defender-disable`, `auto-updates-disable` — a ready-made model for UltraOS's Safe/Balanced/Extreme radio/checkbox pages.
6. Every Atlas toggle script self-describes state under `HKLM\SOFTWARE\AtlasOS\Services\<SettingName>\{state,path}` — a clean pattern UltraOS should copy for rollback + post-run report.

---

## 1. SERVICES

### 1.1 Atlas `src/playbook/Configuration/atlas/services.yml` — VERBATIM (authoritative)

```yaml
---
title: Services and Drivers
description: Configures services and drivers to reduce background system resource utilization
onUpgrade: false
actions:
  # ----------------------------------
  # - Potential references           -
  # - Mostly upon IoT recommendation -
  # ----------------------------------
  # https://learn.microsoft.com/en-us/windows-server/remote/remote-desktop-services/rds-vdi-recommendations-2004
  # https://learn.microsoft.com/en-us/windows-server/security/windows-services/security-guidelines-for-disabling-system-services-in-windows-server
  # https://learn.microsoft.com/en-us/windows/iot/iot-enterprise/optimize/services

  # Back up default Windows services & drivers
  - !powerShell:
    command: |
      .\BACKUP.ps1 -FilePath """$([Environment]::GetFolderPath('Windows'))\AtlasModules\Other\winServices.reg"""
    wait: true
    exeDir: true

  ##############################################################################################
  ## SCRIPTS                                                                                  ##
  ##############################################################################################

  - !writeStatus: {status: 'Disabling File Sharing'}
  - !powerShell:
    command: '.\AtlasModules\Scripts\ScriptWrappers\DisableFileSharing.ps1 -Silent'
    exeDir: true
    wait: true
    runas: currentUserElevated

  - !writeStatus: {status: 'Disabling Location'}
  - !cmd:
    command: '"AtlasDesktop\3. General Configuration\Location\Disable Location (default).cmd" /silent'
    exeDir: true
    wait: true
    runas: currentUserElevated

  - !writeStatus: {status: 'Configuring Indexing'}
  - !cmd:
    command: '"AtlasDesktop\3. General Configuration\Search Indexing\Minimal Search Indexing (default).cmd" /silent'
    exeDir: true
    wait: true
    runas: currentUserElevated

  ##############################################################################################
  ## SERVICES                                                                                 ##
  ##############################################################################################

  - !writeStatus: {status: 'Configuring services'}

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

**Note the Atlas grouping comments contradict the current Microsoft IoT page** (§1.4): MS now lists OneSyncSvc/TrkWks/PcaSvc/DiagTrack as 🟢 "OK to disable" (matching), but WerSvc + diagnosticshub are ⛔ "Don't disable" and wercplsupport is 🟡 "No guidance". **Atlas knowingly deviates from Microsoft on WerSvc and diagnosticshub.**

### 1.2 What each Atlas-disabled service does / reverts to (stock Windows 11 default Start values)

| Service | Atlas | Stock default (revert) | Function / risk |
|---|---|---|---|
| **DiagTrack** (Connected User Experiences and Telemetry) | Disabled | Automatic (2) | Telemetry upload. MS: 🟢 OK to disable. Benefit: background CPU/disk/network + privacy. Safe everywhere. Trade-off: none meaningful. |
| **OneSyncSvc** (Sync Host, per-user `OneSyncSvc_XXXXX`) | Disabled | Automatic (per-user template) | Syncs mail/contacts/calendar for Mail, Outlook (new). MS: 🟢 OK to disable. Trade-off: breaks sync in Mail-type UWP apps; harmless for most. |
| **TrkWks** (Distributed Link Tracking Client) | Disabled | Automatic (2) | Tracks shell shortcuts across volumes/NTFS. MS: 🟢 OK to disable. Trade-off: shortcuts to files on *other machines* may not self-heal. Negligible. |
| **PcaSvc** (Program Compatibility Assistant) | Disabled | Automatic (2) | Detects compat problems, applies shims. MS: 🟢 OK to disable. Trade-off: legacy apps relying on silent compat shims may misbehave; also kills "PcaPatchDbTask" synergy (§2). Atlas also disables PCA privacy side (`disable-pca.yml` in privacy folder). |
| **diagnosticshub.standardcollector.service** | Disabled | Manual (3) | ETW collection for VS diagnostics. MS: ⛔ Don't disable (IoT). Trade-off: Visual Studio profiling/diagnostics sessions fail. Pure dev-workstation concern. |
| **WerSvc** (Windows Error Reporting) | Disabled | Manual (3) | Error reporting. MS: ⛔ Don't disable. Trade-off: "Check for solutions" never works; WER dialog can hang some installers that wait on it (`⚠️` anecdotal). Privacy benefit real. |
| **wercplsupport** (Problem Reports & Solutions CPL) | Disabled | Manual (3) | MS: 🟡 No guidance. UI for problem reports; useless once WerSvc dead. |
| **UCPD** (USB Restricted Mode / USB communications disable enforcer) | Disabled | Manual (3)* | MS IoT page does not list UCPD (not found in current table). Known mainly from the "UCPD driver" date-loop bug (Nov 2023) — `⚠️ UNVERIFIED` on 26H2 behavior. Atlas also disables its velocity scheduled task (§2). Security trade-off: weakens USB-data-while-locked protection on phones. |
| **GpuEnergyDrv** (driver) | Disabled | Manual (3) | GPU energy telemetry driver (Windows 10-era). Negligible risk. |
| **NetBT** (driver, NetBIOS over TCP/IP) | Disabled | Manual (3)* | Legacy name resolution. Disabled by the file-sharing flow too (§1.5). Breaks old SMB/legacy browsing only. Re-enabled by `Enable File Sharing.cmd` flow (`sc config NetBT start=` via DisableFileSharing/EnableFileSharing pair — see §1.5). |
| **Telemetry** (driver) | Disabled | Manual (3)* | Kernel telemetry driver. No known breakage. `⚠️ UNVERIFIED` beyond community claims. |

\* Stock values from Windows 11 24H2/25H2 observation + Microsoft docs; verify on 26H2 RTM before shipping UltraOS (service defaults occasionally shift between builds).

**Revert path (important pattern):** Atlas never hardcodes per-service restores for the above; instead `BACKUP.ps1` exports `HKLM\SYSTEM\CurrentControlSet\Services` **before** changes to `%windir%\AtlasModules\Other\winServices.reg`, and after all tweaks to `atlasServices.reg`. `AtlasDesktop\9. Troubleshooting\Set services to defaults.cmd` re-runs every "(default)" script under `6. Advanced Configuration\Services` and then offers `reg import` of either backup (runs as TrustedInstaller via `RunAsTI.cmd`). **UltraOS should adopt: snapshot services before/after + one-click restore.**

### 1.3 Scripted Atlas service toggles (all optional, user-runnable; `(default)` = Atlas install default state)

From `AtlasDesktop\6. Advanced Configuration\Services\*` + `3. General Configuration\*` (values via `setSvc.cmd <svc> <start>` writing `Start` REG_DWORD):

| Toggle | Disables (Start=4) | Enables (revert Start values) | Default in v0.5.0 |
|---|---|---|---|
| **SuperFetch/SysMain** | `SysMain 4`, `rdyboost 4` (ReadyBoost driver), removes `rdyboost` LowerFilters from volume class `{71a27cdd-...}`, deletes ReadyBoost property-sheet handler | `SysMain 2`, `rdyboost 0` (Boot), re-adds LowerFilters + tab | **ENABLED (SysMain=2)** — Atlas made SuperFetch ON by default |
| **Printing** | `Spooler 4`, `PrintWorkFlowUserSvc 4`, hides Print context menus, DISM-disables `Printing-Foundation-Features`, `-InternetPrinting-Client`, `-XPSServices-Features`, `-PrintToPDFServices-Features`, hides Settings page `printers` | `Spooler 2`, `PrintWorkFlowUserSvc 3`, re-enables features/capabilities (`Print.Management.Console`, optional `Print.Fax.Scan`) | **ENABLED (Spooler=2)** |
| **Bluetooth** | `BluetoothUserService, BTAGService, BthA2dp, BthAvctpSvc, BthEnum, BthHFEnum, BthLEEnum, BthMini, BTHMODEM, BTHPORT, bthserv, BTHUSB, HidBth, Microsoft_Bluetooth_AvrcpTransport, RFCOMM, (BthPan)` → 4; disables PnP `*Bluetooth*`; `PolicyManager Connectivity AllowBluetooth=0` | same list → 3 (Manual), `AllowBluetooth=2` | **ENABLED** |
| **Network Discovery** | `fdPHost 4, FDResPub 4, lmhosts 4, SSDPSRV 4` + disables Network sidebar pane | `fdPHost 3, FDResPub 3, lmhosts 3, netman 3, NlaSvc 3 (Win11) / 2 (Win10), SSDPSRV 3`, eventlog 2 | **ENABLED** |
| **Lanman Workstation (SMB client)** | `KSecPkg 4, LanmanServer 4, LanmanWorkstation 4, mrxsmb 4, mrxsmb20 4, rdbss 3, srv2 4`, DISM-disable `SmbDirect` | `KSecPkg 0, LanmanServer 2, LanmanWorkstation 2, mrxsmb 3, mrxsmb20 3, rdbss 1, srv2 3`, enable `SmbDirect` | **ENABLED** |
| **NVIDIA Display Container LS** | `NVDisplay.ContainerLocalSystem 4` (+sc stop) | back to 2 | **ENABLED** — Atlas warns: breaks NVIDIA Control Panel & "most likely other driver features"; aimed at stripped-driver users |
| **File Sharing** (via `DisableFileSharing.ps1`) | `Disable-NetAdapterBinding ms_msclient, ms_server, ms_lltdio, ms_rspndr`; per-interface `NetbiosOptions=2`; `NetBT` disabled; network profile → Public; firewall disables File/Printer Sharing + Network Discovery (Private); reg imports for Network pane/Give-Access menus | `EnableFileSharing.ps1` reverses | **DISABLED (default)** |
| **Search Indexing** | `indexConf /stop`: `sc config WSearch start=disabled`, `sc stop WSearch`, hides Settings page `cortana-windowssearch` | full enable: delayed-auto (`sc config WSearch start=delayed-auto`); **minimal (Atlas default)**: policies `DefaultIndexedPaths` = only `%programdata%\...\Start Menu\Programs` + AtlasDesktop, `DefaultExcludedPaths` = `%systemdrive%\Users`, `RespectPowerModes=1`, `SetupCompletedSuccessfully=0`, then `/start` (delayed-auto) | **MINIMAL** |
| **Delivery Optimization** | `HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization\DODownloadMode=0` (policy — service **not** disabled; DoSvc keeps running, P2P off; mode 0 = HTTP only, no peering/LEN) | delete policy | **DISABLED (mode 0)** |
| **Automatic Updates** | `HKLM\...\WindowsUpdate\AU\AUOptions=2` (notify-only). `NoAutoUpdate=1` deliberately NOT set ("Breaks 'Receive updates for other Microsoft products'") | delete values | **DISABLED (notify)** |
| **Location** | `Disable Location (default).cmd` (per-user + machine location off) | Enable script | **DISABLED** |
| **CPU Idle** | `powercfg /setacvalueindex scheme_current sub_processor 5d76a2ca-e8c0-402f-a133-2158492d58ad 1` (Idle Disable=ON; forces max P-state); warns **do NOT use with HT/SMT enabled**; Task Manager shows 100% CPU | same GUID → 0 | **ENABLED (idle on)** |
| **Timer Resolution** | `GlobalTimerResolutionRequests=1` (HKLM\...\Session Manager\kernel) + scheduled task "Force Timer Resolution" running `SetTimerResolution.exe --resolution 5060 --no-console` at logon (0.506 ms) | delete reg value, kill exe, delete task | **DISABLED (opt-in)** |
| **Hibernation** | `powercfg /h off` + `ShowHibernateOption=0` | `powercfg /h on` | **DISABLED (default)** — note Atlas comment: "Disabling makes NTFS accessible outside of Windows" |
| **FSO & Game Bar** | see §3.2 (full value set) | see §3.2 | **ENABLED** |

### 1.4 Microsoft guidance matrix (source: `learn.microsoft.com/en-us/windows/iot/iot-enterprise/optimize/services`, fetched 2026-10-07 — same doc family Atlas cites)

Legend: 🟢 OK to disable | 🟡 No guidance | ⛔ Don't disable | 🔵 Should be disabled (IoT thin-client lens)

| Service | MS says | Note for UltraOS |
|---|---|---|
| DiagTrack | 🟢 | disable in all presets |
| SysMain | ⛔ | Atlas agrees (default ON) |
| WSearch | 🟢 | trade-off = search speed; Atlas minimal-indexing is the smart middle |
| MapsBroker | 🟢 | disable Safe+ (apps needing offline maps break — rare) |
| lfsvc (Geolocation) | 🟢 | Atlas disables Location feature anyway |
| RetailDemo | 🟢 | disable everywhere (retail-store mode only) |
| RemoteRegistry | ⛔ (IoT lists "Don't disable" for remote mgmt; security guides say disable) | **Divergence**: MS's own security baselines historically allow disabling; for home users disable = security win. Map Safe+. |
| Fax | 🟢 | disable everywhere |
| WMPNetworkSvc | 🟢 | disable unless streaming WMP libraries |
| Spooler | 🟢 | trade-off: NO printing (incl. Microsoft Print to PDF, some app "print to X" flows, e.g. some PDF printers). UltraOS Safe = keep, Extreme = disable. |
| PrintNotify | 🟢 | disable with Spooler |
| OneSyncSvc | 🟢 | disable (see §1.2) |
| PcaSvc | 🟢 | disable (see §1.2) |
| TrkWks | 🟢 | disable |
| WerSvc | ⛔ | Atlas disables anyway (privacy); honest risk note |
| wercplsupport | 🟡 | disable with WerSvc |
| diagnosticshub… | ⛔ | disable only in Extreme/dev-unaware presets; VS users need it |
| NlaSvc | 🟢 | **careful**: disabling breaks network profile change detection; some firewall/NIC UI weirdness. Balanced = Manual (stock) or leave. |
| netprofm | 🟡 | leave Manual (stock); Network & Sharing center needs it |
| dot3svc | 🟢 | disable unless 802.1X wired auth (enterprise) — rare at home |
| WLANSVC (WlanSvc) | 🟢 (IoT) | **NEVER disable on Wi-Fi machines**; disable acceptable on Ethernet-only desktops (Extreme) |
| DoSvc | ⛔ | never disable service; use `DODownloadMode` policy (Atlas pattern §1.3) |
| UsoSvc | ⛔ | never disable (breaks update installs/rollback) |
| TrustedInstaller | ⛔ | never disable (WU servicing breaks) |
| wuauserv | 🟢 (IoT) | can be disabled but breaks ALL update paths incl. Store app updates; UltraOS = keep service, use AUOptions policy (Atlas pattern) |
| WaaSMedicSvc | ⛔ | never disable (self-healing WU) |
| CDPSvc / CDPUserSvc | 🟢 | **community caveat**: CDPUserSvc/CDPsvc off breaks Nearby Sharing, "Continue on PC", some Settings→System pages render issues reported on 24H2 `⚠️ UNVERIFIED`; map to Extreme only |
| DevicesFlowUserSvc | 🟢 | breaks Miracast/Bluetooth pair UI |
| BcastDVRUserService | 🟢 | Game DVR capture service (per-user); part of Game Bar story §3 |
| MessagingService / PimIndexMaintenanceSvc / UserDataSvc / UnistoreSvc / UdkUserSvc | 🟢/🟡 | per-user shell data services; disabling degrades Contacts/search UX |
| EFS | ⛔ | don't (encrypted files become unreadable) |
| hidserv | ⛔ | don't (media keys/hot-buttons on keyboards die) |
| DsmSvc / DevQueryBroker | ⛔ | don't (device metadata/software installs break) |
| BthAvctpSvc | 🟢 | disable only with whole Bluetooth stack (AVRCP audio control for BT headphones) |
| WbioSrvc | 🟢 | disable if no fingerprint/face login (Hello biometrics break otherwise) |
| PhoneSvc / TapiSrv | 🟢 | disable (telephony; modem-era + UWP telephony) |
| wisvc | 🟢 | disable unless Insider builds |
| stisvc (WIA) | 🟢 | disable if no scanner/camera acquisition apps |
| TabletInputService | 🟢 | disable on non-touch desktops (touch keyboard/pen dies) |
| icssvc (Hotspot) | 🟢 | disable if never hotspot |
| SSDPSRV / fdPHost / FDResPub / lmhosts / upnphost | 🟢 | network discovery set — Atlas toggle §1.3 |
| Xbox: XblAuthManager, XblGameSave, XboxNetApiSvc, XboxGipSvc, GamingServices | 🔵 (IoT) | **IoT says disable, gaming says DON'T**: XblAuthManager is required for Xbox app/Game Pass sign-in and many Microsoft Store *games* (entitlement checks); XblGameSave syncs saves; XboxNetApiSvc needed for some titles' multiplayer (Xbox Networking). UltraOS gaming module: **keep all Xbox services** (Atlas keeps them). Extreme preset may offer disable with big warning. |
| AudioSrv / AudioEndpointBuilder | (not in IoT table; ⛔ by convention) | **never disable** — all audio dies. Atlas never touches. |
| SSBidiService | not in MS table | Brother/Epson printer bidi helper; disable only with printing off `⚠️ UNVERIFIED` |
| SEsvc | not found in MS IoT table / not in Atlas | "Windows Session Environment Service" — exists on some OEM installs `⚠️ UNVERIFIED`; leave alone in UltraOS |
| WalletService | 🟢 | disable |
| NDU | not listed in IoT doc | see §6.9 |
| UCPD | not listed | Atlas disables (§1.2) |

**Atlas vs community disagreement points (be explicit in UltraOS docs):**
- **SysMain**: community lists still reflex-kill it; Atlas v0.5.0 + MS say keep. On modern SSDs Superfetch's prefetch is mostly dormant; memory compression is the real loss (also disables standby memory compression → more hard faults under pressure on 8–16 GB systems).
- **WSearch**: community disables; Atlas *downscopes* instead (Start Menu only) — better UX/perf compromise. Recommend for Balanced.
- **Spooler/Bluetooth/SMB/NetworkDiscovery**: community "blacklists" disable them; Atlas enables all by default with easy toggles. Follow Atlas for Safe/Balanced.
- **WerSvc/diagnosticshub**: Atlas more aggressive than MS. Acceptable (privacy), note dev trade-offs.
- **UsoSvc/TrustedInstaller/wuauserv**: never disable (MS ⛔) — community scripts that do cause 0x8024xxxx, Store 0x80D02002-style failures and servicing corruption. UltraOS policy-only.

### 1.5 `DisableFileSharing.ps1` (verbatim, referenced by services.yml)

```powershell
#Requires -RunAsAdministrator
param ([switch]$Silent)
$fileSharingConfigPath = "$([Environment]::GetFolderPath('Windows'))\AtlasDesktop\3. General Configuration\File Sharing"

# Disable network items
Disable-NetAdapterBinding -Name "*" -ComponentID ms_msclient, ms_server, ms_lltdio, ms_rspndr | Out-Null

# Disable NetBios over TCP/IP
$interfaces = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces" -Recurse | Where-Object { $_.GetValue("NetbiosOptions") -ne $null }
foreach ($interface in $interfaces) {
    Set-ItemProperty -Path $interface.PSPath -Name "NetbiosOptions" -Value 2 | Out-Null
}

# Disable NetBIOS service
sc.exe config NetBT start=disabled | Out-Null

# Set network profile to 'Public Network'
Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Public

# Disable network discovery firewall rules
Get-NetFirewallRule | Where-Object {
    ($_.Group -eq "@FirewallAPI.dll,-28502" -or $_.Group -eq "@FirewallAPI.dll,-32752") -or
    ($_.DisplayGroup -eq "File and Printer Sharing" -or $_.DisplayGroup -eq "Network Discovery") -and
    $_.Profile -like "*Private*"
} | Disable-NetFirewallRule

reg import "$fileSharingConfigPath\Network Navigation Pane\Disable Network Navigation Pane (default).reg" | Out-Null
reg import "$fileSharingConfigPath\Give Access To Menu\Disable Give Access To Menu (default).reg" | Out-Null
```
(Also `script-devices.yml` runs `Disable-NetAdapterBinding -Name "*" -ComponentID ms_msclient, ms_server, ms_lldp, ms_lltdio, ms_rspndr` — note it adds **ms_lldp**.)

### 1.6 `start.yml` (verbatim, relevant excerpt — initial config)

```yaml
  - !writeStatus: {status: 'Enabling DirectPlay'}
  - !run: {exe: 'DISM.exe', args: '/Online /Enable-Feature /FeatureName:"DirectPlay" /NoRestart /All', weight: 30}
  - !run: {exe: 'DISM.exe', args: '/Online /Remove-Capability /CapabilityName:"App.StepsRecorder~~~~0.0.1.0" /NoRestart', weight: 30, onUpgrade: false}
  - !writeStatus: {status: 'Cleaning the component store'}
  - !run: {exe: 'DISM.exe', args: '/Online /Cleanup-Image /StartComponentCleanup', weight: 50}
```
(PATH setup for AtlasModules + software installs omitted — see file). **UltraOS gaming note:** DirectPlay enabled = legacy multiplayer (old titles); Steps Recorder removed.

`atlas/default.yml` just imports `DEFAULT.reg` + `DEFAULT.ps1` (sets `HKLM\SOFTWARE\AtlasOS\Services\*` default states — the source of §1.3's "Default" column). `atlas/revert.yml` (onUpgrade) only deletes legacy `FolderDescriptions\...\PropertyBag\ThisPCPolicy` values from pre-0.5 versions (folder-specific This-PC policies) — nothing service-related.

---

## 2. SCHEDULED TASKS — `tweaks/debloat/disable-scheduled-tasks.yml` VERBATIM

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

Plus from `disable-sleep-study.yml` (§4.5): `\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem` disabled.
That is the **complete** Atlas disabled-task list — 7 tasks total. (Older Atlas/community lists with 20+ tasks incl. `Microsoft Compatibility Appraiser`, `MareBackup`, `Proxy`, `StartupAppTask`, `CacheTask`, `RegIdleBackup`, `ResPriStaticDbSync` etc. are **not** in v0.5.0 — UltraOS can offer a bigger opt-in "Extreme" set: compatibility appraiser + CEIP family + `Notification Barbie` etc., but keep `RegIdleBackup` (registry backups) and `StartupAppTask` ON in Safe/Balanced.)

---

## 3. GAMING

### 3.1 GameDVR / Game Bar — `tweaks/performance/disable-game-bar.yml` VERBATIM

```yaml
---
title: Disable Game Bar
description: Disables XBOX Game Bar, which is known as a bloatware feature
actions:

  # Disable Game Bar
  - !registryValue:
    path: 'HKCU\System\GameConfigStore'
    value: 'GameDVR_Enabled'
    data: '0'
    type: REG_DWORD
    
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR'
    value: 'AppCaptureEnabled'
    data: '0'
    type: REG_DWORD
    
  # Disable Game Bar tips
  # Disable 'Open Xbox Game Bar using this button on a controller'
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\GameBar'
    value: 'GamePanelStartupTipIndex'
    data: '3'
    type: REG_DWORD
    
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\GameBar'
    value: 'ShowStartupPanel'
    data: '0'
    type: REG_DWORD
    
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\GameBar'
    value: 'UseNexusForGameBarEnabled'
    data: '0'
    type: REG_DWORD
    
  # Disable Game Bar Presence Writer, required for GameBar
  - !registryValue:
    path: 'HKLM\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter'
    value: 'ActivationType'
    data: '0'
    type: REG_DWORD

  # Disable Windows Game Recording and Broadcasting
  # It automatically disables Game Bar
  - !registryValue:
    path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR'
    value: 'AllowGameDVR'
    data: '0'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR'
    value: 'value'
    data: '0'
    type: REG_DWORD
```

**⚠️ STATUS: commented out of `tweaks.yml`** (line: `# - !task: {path: 'tweaks\performance\disable-game-bar.yml'}`) — Atlas ships Game Bar **enabled** and exposes `AtlasDesktop\3. General Configuration\FSO and Game Bar\` toggles instead. The Toolbox `Performance.psm1` retains a `Disable-GameBar` function with the same 8 values.

### 3.2 FSO (Fullscreen Optimizations) — `Disable FSO and Game Bar Support.cmd` verbatim (registry block)

```bat
reg add "HKCU\System\GameConfigStore" /v "GameDVR_DSEBehavior" /t REG_DWORD /d "2" /f
reg add "HKCU\System\GameConfigStore" /v "GameDVR_DXGIHonorFSEWindowsCompatible" /t REG_DWORD /d "1" /f
reg add "HKCU\System\GameConfigStore" /v "GameDVR_EFSEFeatureFlags" /t REG_DWORD /d "0" /f
reg add "HKCU\System\GameConfigStore" /v "GameDVR_FSEBehavior" /t REG_DWORD /d "2" /f
reg add "HKCU\System\GameConfigStore" /v "GameDVR_FSEBehaviorMode" /t REG_DWORD /d "2" /f
reg add "HKCU\System\GameConfigStore" /v "GameDVR_HonorUserFSEBehaviorMode" /t REG_DWORD /d "1" /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "__COMPAT_LAYER" /t REG_SZ /d "~ DISABLEDXMAXIMIZEDWINDOWEDMODE" /f
reg add "HKCU\System\GameBar" /v "GamePanelStartupTipIndex" /t REG_DWORD /d "3" /f
reg add "HKCU\System\GameBar" /v "ShowStartupPanel" /t REG_DWORD /d "0" /f
reg add "HKCU\System\GameBar" /v "UseNexusForGameBarEnabled" /t REG_DWORD /d "0" /f
reg add "HKLM\SOFTWARE\Microsoft\WindowsRuntime\ActivatableClassId\Windows.Gaming.GameBar.PresenceServer.Internal.PresenceWriter" /v "ActivationType" /t REG_DWORD /d "0" /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR" /v "AllowGameDVR" /t REG_DWORD /d "0" /f
reg add "HKLM\SOFTWARE\Microsoft\PolicyManager\default\ApplicationManagement\AllowGameDVR" /v "value" /t REG_DWORD /d "0" /f
reg add "HKCU\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d "0" /f
reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR" /v "AppCaptureEnabled" /t REG_DWORD /d "0" /f
Get-AppxPackage *xboxgamingoverlay* | Remove-AppxPackage -Confirm:$false
```
Revert (`Enable…(default).cmd`): deletes `GameDVR_DSEBehavior` & `GameDVR_FSEBehavior`, sets `GameDVR_FSEBehaviorMode=2`(!), `GameDVR_DXGIHonorFSEWindowsCompatible=0`, `GameDVR_HonorUserFSEBehaviorMode=0`, `EFSEFeatureFlags=0`, removes `__COMPAT_LAYER`, deletes GameBar/Policy keys, `AllowGameDVR value=1`, `GameDVR_Enabled=1`, deletes `AppCaptureEnabled`, **reinstalls Xbox Game Bar via `winget install 9NZKPSTSNW4P`**.
**Honest assessment:** disabling FSO forces exclusive fullscreen — real DWM/frame-latency benefit on *some* engines (older DX9/DX11), can *hurt* or break borderless-only titles + alt-tab stability, kills HDR on some setups. Not a universal win → opt-in per-game is the modern advice (`Win+Alt+/` per-app FSO toggle in Game Bar). GameDVR background recording off is a safe resource win. **Preset: GameDVR/capture OFF in Balanced+; FSO-off = Extreme only (or per-app).**

### 3.3 Game Mode / HAGS / MPO / GameInput / mouse-keyboard center

- **Game Mode** (`HKCU\Software\Microsoft\GameBar\AllowAutoGameMode`/`AutoGameModeEnabled`): **Atlas does not touch it.** Modern consensus: Game Mode is beneficial (suppresses background installs/updates during play) — UltraOS Safe/Balanced leave ON; Extreme may offer OFF with honest "no measurable gain" label.
- **HAGS** (`HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\HwSchMode` = 2 on, 1 off): Atlas ships only a Settings URL shortcut (`Default Graphics Settings (HAGS).url` → ms-settings:display) — **no registry change**. Community (windowsforum Jan 2026 thread, steamcommunity, acer blog Aug 2026): mixed — some report input-latency/mouse fixes, others VR/streaming/audio stutter; effect is GPU/driver dependent (NVIDIA Reflex interplay). ⚠️ No universal benchmark win. **UltraOS: expose a user-choice toggle, default = leave stock, with guidance.**
- **MPO** (`HKCU\Software\Microsoft\Windows\Dwm\OverlayTestMode=5`): **absent from Atlas.** Disabling MPO fixes flickering on multi-monitor mixed-Hz setups but costs a bit of composition efficiency on supported setups. Opt-in troubleshooting toggle only (Extreme/troubleshoot module).
- **GameInput reminders**: none in Atlas repo. Note for gaming module: `GameInput Service`/`GiSvc` should be left Manual (controller remapping, GameInput API). ⚠️ UNVERIFIED breakage reports if disabled.
- **Mouse acceleration** — Atlas `disable-mouse-accel.yml` (verbatim):
```yaml
  - !registryValue: {path: 'HKCU\Control Panel\Mouse', value: 'MouseSpeed', data: '0', type: REG_SZ}
  - !registryValue: {path: 'HKCU\Control Panel\Mouse', value: 'MouseThreshold1', data: '0', type: REG_SZ}
  - !registryValue: {path: 'HKCU\Control Panel\Mouse', value: 'MouseThreshold2', data: '0', type: REG_SZ}
```
 ("Enhance Pointer Precision" off — standard gamer 1:1 movement; also `minimize-mouse-hover-time.yml` = hover 0ms; `MouseKeys Flags=0` accessibility cleanup.)
- **Xbox Game Bar plugins / Xbox app**: only `Microsoft.XboxApp*` (Console Companion, deprecated) removed in `appx.yml`; `Microsoft.GamingApp` (new Xbox app) is **pinned** in Atlas start menu config. Xbox services untouched (§1.4).
- **DirectPlay** enabled in `start.yml` (§1.6) for legacy multiplayer.

### 3.4 MMCSS — `tweaks/performance/config-mmcss.yml` VERBATIM

```yaml
---
title: Configure the Multimedia Class Scheduler Service
description: Configures MMCSS for the best performance
actions:
    # Set system responsiveness to 10%
    # Allocates less CPU resources to tasks that request it such as browsers, so that other applications will not be impacted as much
    # https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service#registry-settings
  - !registryValue:
    path: 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    value: 'SystemResponsiveness'
    data: '10'
    type: REG_DWORD
```
Stock = 20 (desktop; 100 on Server). 10 reserves 90% for multimedia/gaming threads vs 80%. Real but modest latency/responsiveness effect for MMCSS-tagged threads; harmless. **Safe in all presets.** (Community "0" starves system maintenance threads; 10 is the sane floor — follow Atlas.)

---

## 4. POWER

### 4.1 `tweaks/scripts/script-power.yml` VERBATIM (driver of the wizard option)

```yaml
---
title: Configure Power Settings
description: Executes script to configure power settings for the best performance, especially focusing on the lowest latency e.g. by reducing any potential jitter
actions:
    # Disable power saving features
  - !cmd:
    command: '"AtlasDesktop\3. General Configuration\Power-saving\Disable Power-saving.cmd" /silent'
    exeDir: true
    wait: true
    weight: 20
    runas: currentUserElevated
    option: 'disable-power-saving'

    # Disable Fast Startup
  - !registryValue:
    path: 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
    value: 'HiberbootEnabled'
    data: '0'
    type: REG_DWORD

    # Disable Hibernation
    # Disabling makes NTFS accessible outside of Windows
  - !cmd:
    command: '"AtlasDesktop\3. General Configuration\Hibernation\Disable Hibernation (default).cmd" /silent'
    exeDir: true
    wait: true
    weight: 20
    runas: currentUserElevated
    option: 'disable-hibernation'

    # Set 'Balanced' power scheme if keeping power saving
  - !run: {exe: 'powercfg.exe', args: '/setactive "381b4222-f694-41f0-9685-ff5bb260df2e"', option: '!disable-power-saving'}
```
Note: **Fast Startup always disabled** (HiberbootEnabled=0) regardless of options; if power-saving kept → plain **Balanced** scheme active. Hibernation `powercfg /h off` + `ShowHibernateOption=0` (opt-out).

### 4.2 `DisablePowerSaving.ps1` VERBATIM (the "disable power saving" scope — full)

```powershell
# (laptop warning omitted)
if (!(powercfg /l | Select-String "GUID: 11111111-1111-1111-1111-111111111111" -Quiet)) {
    powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 11111111-1111-1111-1111-111111111111 > $null
}
powercfg /setactive 11111111-1111-1111-1111-111111111111
powercfg /changename scheme_current "Atlas Power Scheme" "Power scheme optimized for optimal latency and performance."
## Secondary NVMe Idle Timeout - 0 milliseconds
powercfg /setacvalueindex scheme_current 0012ee47-9041-4b5d-9b77-535fba8b1442 d3d55efd-c1ff-424e-9dc3-441be7833010 0
## Primary NVMe Idle Timeout - 0 milliseconds
powercfg /setacvalueindex scheme_current 0012ee47-9041-4b5d-9b77-535fba8b1442 d639518a-e56d-4345-8af2-b9f32fb26109 0
## NVME NOPPME - Off
powercfg /setacvalueindex scheme_current 0012ee47-9041-4b5d-9b77-535fba8b1442 fc7372b6-ab2d-43ee-8797-15e9841f2cca 0
## Hub Selective Suspend Timeout - 0 milliseconds
powercfg /setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 0853a681-27c8-4100-a2fd-82013e970683 0
## USB selective suspend - Disabled
powercfg /setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
## USB 3 Link Power Management - Off
powercfg /setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 d4e98f31-5ffe-4ce1-be31-1b38b384c009 0
## Allow Throttle States - Off
powercfg /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 3b04d4fd-1cc7-4f23-ab1c-d1337819c4bb 0
## Dim display after - 0 seconds
powercfg /setacvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 17aaa29b-8b43-4b94-aafe-35f64daaf1ee 0
## Turn off display after - 0 seconds
powercfg /setacvalueindex scheme_current 7516b95f-f776-4464-8c53-06167f40cc99 3c0bc021-c8a8-4e07-a973-6b14cbcb2b7e 0
## Processor performance time check interval - 200 milliseconds
## Reduces DPCs, can be set all the way to 5000ms for statically clocked systems
powercfg /setacvalueindex scheme_current 54533251-82be-4824-96c1-47b60b740d00 4d2b0152-7d5c-498b-88e2-34345392a2c5 200
# Set the active scheme as the current scheme
powercfg /setactive scheme_current

& "$windir\AtlasModules\Scripts\toggleDev.cmd" -Disable '@("ACPI Processor Aggregator", "Microsoft Windows Management Interface for ACPI")' | Out-Null

$properties = Get-NetAdapter -Physical | Get-NetAdapterAdvancedProperty
foreach ($setting in @(
    "ULPMode", "EEE", "EEELinkAdvertisement", "AdvancedEEE", "EnableGreenEthernet", "EeePhyEnable",
    "uAPSDSupport", "EnablePowerManagement", "EnableSavePowerNow", "bLowPowerEnable", "PowerSaveMode",
    "PowerSavingMode", "SavePowerNowEnabled", "AutoPowerSaveModeEnabled", "NicAutoPowerSaver", "SelectiveSuspend"
)) {
    $properties | Where-Object { $_.RegistryKeyword -eq "*$setting" -or $_.RegistryKeyword -eq $setting } | Set-NetAdapterAdvancedProperty -RegistryValue 0
}

$keys = Get-ChildItem -Path "HKLM:\SYSTEM\CurrentControlSet\Enum" -Recurse -EA 0
foreach ($value in @(
    "AllowIdleIrpInD3", "D3ColdSupported", "DeviceSelectiveSuspended", "EnableIdlePowerManagement",
    "EnableSelectiveSuspend", "EnhancedPowerManagementEnabled", "IdleInWorkingState", "SelectiveSuspendEnabled",
    "SelectiveSuspendOn", "WaitWakeEnabled", "WakeEnabled", "WdfDirectedPowerTransitionEnable"
)) {
    $keys | Where-Object { $_.GetValueNames() -contains $value } | ForEach-Object {
        $keyPath = $_.PSPath
        $oldValue = "$value-OLD"
        if ($null -eq (Get-ItemProperty -Path $keyPath -Name $oldValue -EA 0)) {
            Rename-ItemProperty -Path $keyPath -Name $value -NewName $oldValue -Force
        }
        Set-ItemProperty -Path $KeyPath -Name $value -Value 0 -Type DWORD -Force
    }
}
Get-CimInstance -ClassName MSPower_DeviceEnable -Namespace root/WMI | Set-CimInstance -Property @{ Enable = $false }

# Disable D3 support on SATA/NVMEs while using Modern Standby
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Storage" -Name "StorageD3InModernStandby" -Value 0 -PropertyType DWORD -Force | Out-Null
# Disable IdlePowerMode for stornvme.sys (storage devices) - the device will never enter a low-power state
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" -Name "IdlePowerMode" -Value 0 -PropertyType DWORD -Force | Out-Null
# Disable power throttling
$powerKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling"
if (!(Test-Path $powerKey)) { New-Item $powerKey | Out-Null }
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -Value 1 -PropertyType DWORD -Force | Out-Null
```
**Scope notes:** duplicates **Ultimate Performance** (`e9a42b02-d5df-448d-aa00-03f14749eb61`) as "Atlas Power Scheme"; NVMe/USB idle timeouts 0, USB selective suspend + USB3 LPM off, throttle states off, display never off, CPU perf time-check 200 ms (fewer DPCs; "can go 5000 ms on statically-clocked systems"), **NIC EEE/Green-Ethernet/uAPSD/power-mgmt off**, device-level D3/selective-suspend registry zeroed (with `-OLD` rename for rollback), `MSPower_DeviceEnable` WMI off, `StorageD3InModernStandby=0`, stornvme `IdlePowerMode=0`, **PowerThrottlingOff=1**. Revert = `DefaultPowerSaving.ps1`: `powercfg /restoredefaultschemes`, re-enable devices, restore `-OLD` values, `NDIS\Parameters\DefaultPnPCapabilities=0`, reset NIC advanced props, remove the three misc values.
**PCIe ASPM: NOT included** (no `asp` powercfg GUID in repo) — Ultimate Performance base still has default ASPM policy; note as UltraOS optional add (`powercfg /setacvalueindex scheme_current 501a4d13-42af-4429-9fd1-a8218c268c20 ee12f906-d277-404b-b6da-e5fa1a576df0 0` ⚠️ verify GUID before shipping).
**Honest benefit:** eliminates latency spikes from device wake-ups (measurable DPC/ISR jitter reduction on some systems; strongly anecdotal for "FPS"). Cost: idle power +heat, USB devices never sleep (LED mice), NIC compatibility quirks, **laptop users beware**. **Preset: Extreme (or Balanced+desktop-only toggle).**

### 4.3 Power plans summary
- Stock schemes: Balanced `381b4222-f694-41f0-9685-ff5bb260df2e`, High performance `8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c`, Ultimate `e9a42b02-d5df-448d-aa00-03f14749eb61` (hidden by default; `powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61`).
- UltraOS mapping: Safe = Balanced (stock); Balanced = Balanced + fast-startup off (+ optional hibernation off); Extreme = Atlas scheme duplicate of Ultimate + §4.2. `.pow` import UX exists (`import-power-plan.yml`: HKCR `.pow` → `powercfg /import "%1"`).
- **Modern standby (S0ix) caveat**: on Modern Standby machines classic plan tweaks partially ignored/unsupported; `AnalyzeSystem`/SleepStudy disabled by Atlas regardless (§4.5).

### 4.4 CPU idle / C-states (Extreme-only)
`Disable Idle.cmd` → `powercfg /setacvalueindex scheme_current sub_processor 5d76a2ca-e8c0-402f-a133-2158492d58ad 1` (Idle Disable ON). Atlas **refuses when HT/SMT detected** ("makes overall CPU performance much worse… disable C-states in BIOS instead"). Task Manager shows constant 100% CPU. Revert: value 0. Big heat/power cost, real latency benefit only for latency-critical static-clock setups. **Extreme only, HT/SMT guard mandatory.**

### 4.5 Sleep Study / maintenance / misc power
- `disable-sleep-study.yml` verbatim:
```yaml
  - !run: {exe: 'wevtutil.exe', args: 'set-log "Microsoft-Windows-SleepStudy/Diagnostic" /e:false'}
  - !run: {exe: 'wevtutil.exe', args: 'set-log "Microsoft-Windows-Kernel-Processor-Power/Diagnostic" /e:false'}
  - !run: {exe: 'wevtutil.exe', args: 'set-log "Microsoft-Windows-UserModePowerService/Diagnostic" /e:false'}
  - !scheduledTask: {path: '\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem', operation: disable}
```
- `config-automatic-maintenance.yml` (verbatim — note they deliberately do NOT disable maintenance: "needed for auto-defrag/TRIM and more"; only stop it **waking the PC**: `HKLM\SOFTWARE\Policies\Microsoft\Windows\Task Scheduler\Maintenance\WakeUp=0`; the `MaintenanceDisabled=1` variant is present but commented out).
- Boot config (`bcdedit-tweaks.yml`): `/timeout 10`, `/set bootmenupolicy legacy` (faster dual-boot menu). QoL, not perf.
- `disable-wpbt.yml`, `crash-control-qol.yml`, startup-delay off, shutdown-time reduced — QoL family.

---

## 5. NETWORK

### 5.1 `tweaks/networking/atlas-network-settings.yml` VERBATIM + the actual script

```yaml
---
title: Applies Atlas' Network Settings
description: Applies Atlas' optimised network settings
actions:
  - !cmd:
    command: '"AtlasDesktop\9. Troubleshooting\Network\Reset Network to Atlas Default.cmd" /silent'
    exeDir: true
    wait: true
    runas: currentUserElevated
```

`Reset Network to Atlas Default.cmd` (verbatim core): finds the **PCI NIC class key** (`HKLM\SYSTEM\CurrentControlSet\Control\Class\...` from `Win32_NetworkAdapter` PNPDeviceID), then sets **only** these keyword strings to `0` (with and without `*` prefix, only if the value exists):
- `AutoDisableGigabit` ("Don't disable gigabit")
- `ApCompatMode` ("Access Point Compatibility Mode — Zero is 'High Performance'")
- `SipsEnabled` ("About reducing link speed")
- `ReduceSpeedOnPowerDown`
- `DMACoalescing` ("'may increase latency'" — cites intel.com/support/articles/000007456)

Explicitly **commented out as "Unknown benefit"** in the script: `LargeSendOffload*`, `LsoV1IPv4`, `LsoV2IPv4`, `LsoV2IPv6`, `PriorityVLANTag`, `PacketCoalescing`, `FlowControl`/`FlowControlCap` ("Could cause dropped network frames"), `DeviceSleepOnDisconnect`, `EnableModernStandby`, `ARPOffloadEnable`, `NSOffloadEnable`, `GTKOffloadEnable`, `Enable9KJFTpt`, `EnableEDT`, `MasterSlave`, `MPC`, `PowerDownPll`, `Node`, and more. **This restraint is the headline finding for the UltraOS network module.**

`Reset Network to Windows Default.cmd`: `netsh int ip reset`, `netsh interface ipv4 reset`, `netsh interface ipv6 reset`, `netsh interface tcp reset`, `netsh winsock reset`, then `pnputil /remove-device` all Net devices + `/scan-devices` (full TCP stack reset).

### 5.2 LLMNR — `disable-llmnr.yml` VERBATIM (⚠️ currently disabled in tweaks.yml)

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
Atlas comment in tweaks.yml: *"Needed for compatibility"* — LLMNR off can break `.local`-style resolution for some older devices/discovery on small LANs. Security-positive (spoofing vector), perf-neutral. UltraOS: Balanced+ (security module), document the compat note.

### 5.3 SMB / shares (verbatim values)

- **Disable SMB bandwidth throttling** (`disable-smb-bandwidth-throttling.yml`): `HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters\DisableBandwidthThrottling = 1` (REG_DWORD). Removes SMB 10 ms/latency-induced throttling on large transfers — genuine file-copy throughput win on gigabit+; irrelevant for gaming.
- **Restrict anonymous access**: `HKLM\...\LanManServer\Parameters\RestrictNullSessAccess = 1` (STIG V-220932).
- **Restrict anonymous enumeration**: `HKLM\SYSTEM\CurrentControlSet\Control\Lsa\RestrictAnonymous = 1` (STIG V-220930).
- Whole SMB client/server stack toggle §1.3 (Lanman scripts; `SmbDirect` disable, `srv2` etc.).
- Firewall: Remote Assistance group disabled via `netsh advfirewall firewall set rule group="Remote Assistance" new enable=no` (`disable-remote-assistance.yml`).

### 5.4 What Atlas does NOT do — netsh/DNS guidance for 26H2 (community supplement)

Repo-wide: **no** `netsh int tcp set global` of any kind; **no** `TcpAckFrequency`/`TCPNoDelay` (Nagle); **no** `NetworkThrottlingIndex`; **no** `SystemResponsiveness` beyond MMCSS; **no** RSS/ECN/RSC commands; **no DNS server changes** (privacy module handles search, not DNS).

For UltraOS network module (document honestly):
- **Autotuning**: leave `normal` (`netsh int tcp set global autotuninglevel=normal`). `disabled` caps receive window → throughput collapse on high-BDP links (superuser reports; tenforums "should NEVER be disabled"). If a user's value got mangled, Atlas reset script is the fix.
- **NetworkThrottlingIndex=0xffffffff** (`HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile`): disables the 10-packet-per-ms multimedia network throttle. Popular gaming tweak; benefit is anecdotal, mostly irrelevant on modern NIC stacks. Opt-in (Extreme). ⚠️ Community-sourced, not Atlas.
- **TcpAckFrequency=1 / TCPDelAckTimestamps** per-interface: disables delayed ACKs (Nagle interplay). Latency-corner tweak; can *reduce* throughput; breaks some NAS behaviors. Opt-in per-NIC (Extreme), clearly labeled.
- **ECN** (`netsh int tcp set global ecncapability`): leave default; enabling can help congestion-sensitive flows but interacts poorly with some home routers. ⚠️.
- **DNS**: no Atlas ground truth. UltraOS can offer DoH setup guides / blank; keep out of perf module (privacy module scope).
- **NIC power management**: covered properly by Atlas `DisablePowerSaving.ps1` (§4.2) — the "Allow the computer to turn off this device" checkbox (`*PMAR`/`PnPCapabilities`) — note DefaultPowerSaving sets `HKLM\SYSTEM\CurrentControlSet\Services\NDIS\Parameters\DefaultPnPCapabilities=0` on revert; the disable path goes through `MSPower_DeviceEnable` + advanced properties.
- **Throttling-index caveats**: `ffffffff` index and `SystemResponsiveness=0` starve background MMCSS classes (audio glitching under load reported) — use 10/`ffffffff` only with explanation. Some Killer/Realtek NICs misbehave when advanced keywords like FlowControl are forced — Atlas's "only if value exists" pattern avoids this; UltraOS must do the same.

---

## 6. CPU / MEMORY

### 6.1 CPU mitigations (Spectre/Meltdown family) — Atlas implementation

Wizard option `mitigations-disable` → `Disable All Mitigations.cmd` (verbatim, core):
```bat
:: Disable Spectre and Meltdown
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "FeatureSettingsOverride" /t REG_DWORD /d "3" /f > nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" /v "FeatureSettingsOverrideMask" /t REG_DWORD /d "3" /f > nul
:: Disable Structured Exception Handling Overwrite Protection (SEHOP)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v "DisableExceptionChainValidation" /t REG_DWORD /d "1" /f > nul
:: Disable Control Flow Guard (CFG)
PowerShell -NoP -C "Set-ProcessMitigation -System -Disable CFG" > nul
:: ... read MitigationAuditOptions mask, set all bytes to 2 ...
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v "MitigationAuditOptions" /t REG_BINARY /d "<mask>" /f > nul
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" /v "MitigationOptions" /t REG_BINARY /d "<mask>" /f > nul
:: Fix Valorant with mitigations disabled - enable CFG
set "enableCFGApps=valorant valorant-win64-shipping vgtray vgc"
PowerShell -NoP -C "foreach ($a in $($env:enableCFGApps -split ' ')) {Set-ProcessMitigation -Name $a`.exe -Enable CFG}" > nul
:: DEP for OS components only
bcdedit /set nx OptIn > nul
:: Disable file system mitigations
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" /v "ProtectionMode" /t REG_DWORD /d "0" /f > nul
```
Default/revert (`Set Windows Default Mitigations.cmd`): delete `FeatureSettingsOverride(-Mask)`, delete `DisableExceptionChainValidation`, delete `MitigationAuditOptions`/`MitigationOptions`, `bcdedit /set nx OptIn`, `ProtectionMode=1`, delete `MinVmVersionForCpuBasedMitigations`.
**FGCL/FBCP**: no such keys exist in Atlas — the Spectre/Meltdown disable is the `FeatureSettingsOverride=3/3` pair (all off incl. branch-prediction mitigations). **Honest assessment:** on CPUs ≥8th-gen Intel / Ryzen 3000+, disabling mitigations yields **near-zero** real-world gain and a large attack surface; Atlas's own wizard copy: "Disabling mitigations reduces security, and could harm performance on modern CPUs… Disabling could improve performance on older CPUs." **UltraOS: default Windows mitigations (Safe+Balanced); Extreme = option with red warning; always offer Valorant-CFG exception pattern.**

### 6.2 Timer resolution

- Enable (opt-in): `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel\GlobalTimerResolutionRequests=1` (restores Win10-style global behavior on Win11 24H2+) + schtask "Force Timer Resolution" (logon, SYSTEM, highest) → `SetTimerResolution.exe --resolution 5060 --no-console` = **0.506 ms** (5060×100 ns; task description says "0.6ms"). Disable (default): delete value, `taskkill /im SetTimerResolution.exe`, delete task.
- Atlas bundles `SetTimerResolution.exe` (`AtlasModules\Tools\`); upstream github.com/amitxv/SetTimerResolution **404s as of 2026-10-07** (acknowledged in `AtlasModules\Acknowledgements\Timer Resolution (amitxv).url` — binary is in-repo, license ⚠️ verify before redistributing in GPL-3.0 UltraOS).
- Community (BlurBusters forum Dec 2024, PCGamingWiki "Windows 11 only: restore legacy system-wide timer resolution behavior"): 24H2+ **no longer honors process-wide timer requests globally** unless `GlobalTimerResolutionRequests=1`; recommended values 0.5 ms; PCGamingWiki ships the same reg key as a legacy-restore. **Is 0.5 ms stable on 26H2?** No 26H2-specific reports found yet (26H2 ≈ Sept 2026 update on 25H2 codebase — key still documented for 24H2/25H2; verify on RTM ⚠️). Benefit: smoother frame pacing/frame limiters + lower sleep-timer granularity; cost: marginally higher idle wakeups/power. **Preset: Balanced/Extreme opt-in (default off like Atlas).**
- Related QoL: `make-measuresleep-admin.yml` — `MeasureSleep.exe` runs as admin (AppCompatFlags `~ RUNASADMIN`).

### 6.3 VBS / HVCI / Core Isolation — `ConfigVBS.ps1 -DisableAllVBS` (verbatim core)

```powershell
$memIntegrity = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
$kernelShadowStacks = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks"
$credentialGuard = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\CredentialGuard"
# Memory Integrity (forced since 24H2)
New-ItemProperty -Path $memIntegrity -Name "Enabled" -Value 0 -PropertyType DWORD -Force
# Kernel-mode Hardware-enforced Stack Protection (Win11)
New-ItemProperty -Path $kernelShadowStacks -Name "Enabled" -Value 0 -PropertyType DWORD -Force
Remove-ItemProperty -Path $kernelShadowStacks -Name "ChangedInBootCycle" -EA 0
Remove-ItemProperty -Path $kernelShadowStacks -Name "WasEnabledBy" -EA 0
# Credential Guard (Win11)
New-ItemProperty -Path $credentialGuard -Name "Enabled" -Value 0 -PropertyType DWORD -Force
Remove-ItemProperty -Path $credentialGuard -Name "ChangedInBootCycle" -EA 0
Remove-ItemProperty -Path $credentialGuard -Name "WasEnabledBy" -EA 0
# LSA Protection (24H2+)
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 0 -PropertyType DWORD -Force
# VBS General (24H2+)
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard" -Name "EnableVirtualizationBasedSecurity" -Value 0 -PropertyType DWORD -Force
```
Re-enable path: `Enabled=1` + `WasEnabledBy=2` (memory integrity). Scope = **memory integrity, kernel shadow stacks, Credential Guard, LSA PPL, VBS itself**. 24H2 notes in script: values must be *forced* (Windows resets them). Honest perf: HVCI/VBS costs are real but modest on CPUs with MBEC/GMET (roughly low single-digit % in most games; larger on older CPUs & emulation) — varies by title/CPU `⚠️`; on 24H2+ many clean installs have VBS ON by default. **Preset: Safe = keep ON; Balanced = user choice (gaming focus, explain security loss); Extreme = OFF.** (Note: this is the *only* way Atlas touches hypervisor config — no `bcdedit /set hypervisorlaunchtype off`, which breaks WSL2/Sandbox/Defender Application Guard/Core Isolation UI.)

### 6.4 SysMain / pagefile

- **SysMain**: see §1.3 — Atlas default **ON**; disable also kills ReadyBoost (`rdyboost` boot driver) + removes its volume-class LowerFilter + property sheet. Community lore ("disable Superfetch on SSDs") predates modern Win11 behavior; MS ⛔. When it *does* help: heavy standby-memory churn with low RAM. **UltraOS Safe/Balanced: keep ON. Extreme: optional toggle with the full ReadyBoost cleanup.**
- **Paging / `disable-paging.yml`** (verbatim — **DISABLED IN TWEAKS.YML**, "likely placebo"):
```yaml
---
title: Disable Paging Settings
description: Disables memory paging settings for the best performance
actions:
  - !registryValue:
    path: 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
    value: 'DisablePagingExecutive'
    data: '1'
    type: REG_DWORD
  - !registryValue:
    path: 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
    value: 'DisablePageCombining'
    data: '1'
    type: REG_DWORD
```
Analysis: `DisablePagingExecutive=1` keeps *kernel/drivers* resident (small real RAM cost, near-zero measurable benefit on modern systems); `DisablePageCombining=1` disables memory page combining (saves CPU on combine scans, *costs* RAM on duplicate-page-heavy workloads). **Not** a pagefile-disable. UltraOS: Extreme-only, honest labeling. Do NOT ship "delete pagefile" logic — apps with `VirtualAlloc` commit assumptions crash.
- **Reserved storage off** (`disable-reserved-storage.yml`): `DISM /Online /Set-ReservedStorageState /State:Disabled` (ignoreErrors) — frees ~7 GB; update headroom trade-off. **Balanced+.**
- **NDU**: see §6.9.

### 6.5 Service host splitting — `disable-service-host-split.yml` VERBATIM

```yaml
---
title: Disable Service Host Splitting
description: Disables Service Host splitting for much lower RAM usage and process count, excluding XBOX services to fix issues with Game Bar
actions:
  # https://learn.microsoft.com/en-us/windows/application-management/svchost-service-refactoring
  - !powerShell:
    command: |
      Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services' |
        Where-Object { $_.Name -notmatch 'Xbl|Xbox' } |
        Foreach-Object {
          if ($null -ne (Get-ItemProperty -Path """Registry::$_""" -EA 0).Start) {
            Set-ItemProperty -Path """Registry::$_""" -Name 'SvcHostSplitDisable' -Type DWORD -Value 1 -Force -EA 0
          }
        }
    wait: true
```
Effect: with >3.5 GB RAM, Win10/11 splits services across many `svchost.exe`; setting per-service `SvcHostSplitDisable=1` forces grouping → fewer processes, lower PTE/handle overhead, ~50–150 MB RAM saved (varies). **When it HURTS:** services that crash take down their whole group (bigger blast radius); per-service CPU accounting/affinity isolation lost; debugging harder; on 24H2+ with >32 GB RAM Microsoft splits *more* aggressively and some security tooling expects it. Xbox exclusion exists because grouping Xbox services broke Game Bar. **Preset: Balanced (Atlas default-ON, worth it) with Xbox exclusion kept verbatim.**

### 6.6 FTH — `disable-fth.yml` VERBATIM

```yaml
---
title: Disable Fault Tolerant Heap (FTH)
description: FTH is a feature in Windows 7+ that applies mitigations (non-CPU related) to applications that repeatedly crash to prevent further crashes, but when the FTH is active for a certain application, there's a performance hit.
actions:
  # https://devblogs.microsoft.com/oldnewthing/20120125-00/?p=8463
  # https://docs.microsoft.com/en-us/windows/win32/win7appqual/fault-tolerant-heap
  - !file: {path: '%windir%\AtlasDesktop\7. Security\Mitigations\Fault Tolerant Heap', cpuArch: 'Arm64'}   # delete on ARM64 (no FTH)
  - !run: {exe: 'rundll32.exe', args: 'fthsvc.dll,FthSysprepSpecialize', cpuArch: 'X64'}                    # reset existing FTH state
  - !registryValue: {path: 'HKLM\SOFTWARE\Microsoft\Fth', value: 'Enabled', data: '0', type: REG_DWORD, cpuArch: 'X64'}
```
Effect: FTH auto-applies heap shim to apps that crash repeatedly — once applied, that app pays a tax. Reset+disable = remove tax from already-flagged legacy apps. Low risk, low but real benefit (mostly old games/utilities). **Safe/Balanced+ (default ON like Atlas, x64 only).**

### 6.7 Win32PrioritySeparation — `win32-priority-separation.yml` VERBATIM

```yaml
---
title: Prioritize Foreground Applications
description: Prioritizes foreground applications for process scheduling by setting Win32PrioritySeparation to 26 hex, meaning a short quantum, variable, high foreground boost
actions:
  - !registryValue:
    path: 'HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl'
    value: 'Win32PrioritySeparation'
    data: '38'
    type: REG_DWORD
```
`38` decimal = **0x26**. Per Atlas's own description: "short quantum, variable, high foreground boost" (bits: quantum-length=short, quantum-type=variable, foreground-boost=high; bit-level decode order varies across references — ⚠️ don't over-specify in UltraOS docs, the value itself is what matters). Stock Windows 11 desktop default = **2 (0x02)**. Effect: foreground app threads get shorter scheduler quanta with a bigger priority boost → snappier foreground apps/audio under load; background services slightly starved. Modest, real, safe. **Safe+ all presets (desktop profile).** ⚠️ Verify 26H2 keeps semantics (unchanged since Vista; extremely stable assumption).

### 6.8 NTFS — `optimize-ntfs.yml` VERBATIM

```yaml
---
title: Optimize NTFS
description: Optimizes NTFS options for optimal QoL, performance and privacy
actions:
  - !run: {exe: 'fsutil', args: 'behavior set disablelastaccess 1'}
  - !run: {exe: 'fsutil', args: '8dot3name set 1'}
```
`disablelastaccess=1` (user-managed, disabled) stops Last-Access-Time updates (less write churn + privacy); `8dot3name set 1` disables 8.3 short-name creation (faster file creation in large dirs; breaks ancient 16-bit/very old installers only). Reverts: `disablelastaccess 2` (system-managed default)/`0`; `8dot3name set 0`/volume-wise `fsutil 8dot3name strip`. **Safe+ (default ON like Atlas).**

### 6.9 NDU (Network Data Usage) — community item, not in Atlas

`HKLM\SYSTEM\CurrentControlSet\Services\NDU` Start=4 is a long-standing community tweak (origin: memory-leak reports with Killer NICs / early Win10). Current status: not in MS IoT guidance table, not in Atlas. Leak largely historical; service tracks per-app network usage for Settings. Disabling breaks **Settings → Network → Data usage** UI. **UltraOS: not recommended for Safe/Balanced; Extreme optional with the data-usage-breakage note. ⚠️ UNVERIFIED benefit on 26H2.**

### 6.10 Background apps — `disable-background-apps.yml` VERBATIM

```yaml
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'
    value: 'GlobalUserDisabled'
    data: '1'
    type: REG_DWORD
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'
    value: 'BackgroundAppGlobalToggle'
    data: '0'
    type: REG_DWORD
```
Stops UWP/packaged apps running in background (Win11 Settings exposes per-app now; these global values still honored on 24H2 ⚠️ verify 26H2). Real battery/RAM win; trade-off: notifications/alarms from store apps, Phone Link etc. **Balanced+ (Atlas default ON).**

### 6.11 Other CPU/memory/perf items

- **Auto folder discovery** (Atlas default ON): runs `Disable Automatic Folder Discovery (default).cmd` (shell `Bags\AllFolders\Shell\FolderType=NotSpecified` via cmd due to AME-hive issue) — Explorer stops sniffing folder contents for template; fixes misdetected "Pictures" folders + minor CPU. Safe+.
- **Performance counters rebuild** (`rebuild-perf-counters.yml`): `lodctr /r` ×2 + `winmgmt /resyncperf` — fixes broken counters (some games/apps query them); harmless repair. Safe+.
- **`script-ngen.yml`**: `NGEN.ps1` compiles .NET assemblies → faster PowerShell/first-run app startup. Safe+ (one-time cost at install).
- **`respect-power-modes-search.yml`**: `HKLM\Software\Microsoft\Windows Search\Gather\Windows\SystemIndex\RespectPowerModes=1` — indexer respects power modes (battery saver pauses indexing). Safe+.
- **Storage Sense** configured (`config-storage-sense.yml`) & App archiving off (`disable-auto-app-archival.yml`) — storage module scope.
- **`extend-cache.yml`, `classic-search.yml`, `disable-gallery.yml`** — Explorer QoL/perf.
- **`crash-control-qol.yml` / `disable-wpbt.yml` / `decrease-shutdown-time.yml` / `disable-startup-delay.yml`** — shutdown/startup latency QoL.
- **`disable-resume.yml`** (Fast Resume off), **`config-content-delivery.yml`** (suggestions off).
- **`visual-effects.yml`**: custom perf set — `UserPreferencesMask=9012038010000000`, `MinAnimate=0`, `TaskbarAnimations=0`, `VisualFXSetting=3` (custom), `DragFullWindows=1` kept, `FontSmoothing=2`, thumbnails/icons kept (`IconsOnly=0`, `ListviewAlphaSelect=1`, `ListviewShadow=1`), `EnableAeroPeek=0`, `AlwaysHibernateThumbnails=0`. Sensible perf-with-usability set (keeps font smoothing + thumbnails).

---

## 7. Preset mapping proposal (Safe / Balanced / Extreme) — Home+Pro identical (service set & registry paths are edition-agnostic; only gpedit UI absent on Home — policy *registry* keys used above all apply on Home; `PolicyManager` keys apply on both)

| Item | Safe | Balanced | Extreme |
|---|---|---|---|
| DiagTrack, MapsBroker, lfsvc, RetailDemo, Fax, WMPNetworkSvc, TrkWks, OneSyncSvc, wisvc, WalletService, PhoneSvc/TapiSrv, stisvc(no scanner), TabletInput(no touch), icssvc | disable | disable | disable |
| PcaSvc, wercplsupport, UCPD, GpuEnergyDrv, Telemetry drv, NetBT | disable (Atlas set) | disable | disable |
| WerSvc, diagnosticshub | keep (MS ⛔) | disable (Atlas set, dev warning) | disable |
| WSearch | stock | minimal-indexing (Atlas) | disabled |
| SysMain + rdyboost | keep | keep | toggle (default keep) |
| Spooler / Bluetooth / SMB / NetworkDiscovery / LanmanStack | keep | keep (Atlas toggles exposed) | optional disable per-feature |
| Xbox services (Xbl*, GamingServices) | **keep** | **keep** | keep (never offer disable in gaming preset; Extreme side-toggle only w/ warning) |
| DoSvc / UsoSvc / TrustedInstaller / wuauserv | keep service; DODownloadMode=0 policy; AUOptions=2 notify | same | same |
| CDPSvc/CDPUserSvc, NDU, RemoteRegistry, dot3svc | keep | keep | optional (RemoteRegistry disable OK in all; NDU/CDP flagged ⚠️) |
| Scheduled tasks (7-task Atlas set + AnalyzeSystem) | on | on | on (+ optional extended set, keep RegIdleBackup/StartupAppTask) |
| GameDVR/capture off, GameBar kept installed | off | off | off |
| FSO disable / Game Bar uninstall | no | no | optional per-app guidance |
| Game Mode, HAGS, MPO, GameInput | untouched | untouched | HAGS/MPO user-choice toggles only |
| Mouse accel off + hover 0 | on | on | on |
| MMCSS SystemResponsiveness=10 | on | on | on |
| Mitigations | Windows default | Windows default | disable option (Valorant CFG exception) |
| VBS/HVCI | on | choice | off |
| Timer resolution 0.506 ms | off | opt-in | on |
| Power: fast startup off, hibernation off (opt) | off | off | off |
| Power-saving disable (Atlas scheme, §4.2) | no | desktop-toggle | on (not laptops) |
| CPU idle disable (HT/SMT guard) | no | no | guarded option |
| Service host split (Xbox excluded) | on | on | on |
| FTH off (x64) | on | on | on |
| Win32PrioritySeparation=0x26 | on | on | on |
| NTFS lastaccess/8.3 | on | on | on |
| Background apps off | on | on | on |
| Reserved storage off | on | on | on |
| NIC advanced props (AutoDisableGigabit/ApCompatMode/SipsEnabled/ReduceSpeedOnPowerDown/DMACoalescing=0) | on | on | on |
| NetworkThrottlingIndex / TcpAckFrequency / autotuning | untouched | untouched | opt-in flags, labeled ⚠️ |
| LLMNR off | on | on | on |
| SMB throttling off + anonymous restrictions | on | on | on |
| NDU | keep | keep | optional ⚠️ |

**Home+Pro notes:** all values are HKLM/HKCU registry or powercfg/sc/DISM — no edition gating needed; `HKLM\SOFTWARE\Policies\...` honored on Home. Windows Update deferral (`TargetReleaseVersion`) works via registry on Home. BitLocker/Defender flows differ slightly (Defender toggle is a wizard option in Atlas — separate dossier).

---

## 8. Sources

**Repo (ground truth, cloned 2026-10-07, `github.com/Atlas-OS/Atlas`):**
- `src/playbook/Configuration/atlas/{services,start,default,revert,appx,components}.yml`
- `src/playbook/Configuration/tweaks.yml` (default-on/optional/commented tweak matrix)
- `src/playbook/Configuration/tweaks/{debloat,performance,networking,scripts,misc,qol}/...` (all files quoted verbatim above)
- `src/playbook/playbook.conf` (FeaturePages/options, SupportedBuilds 26100/26200)
- `src/playbook/Executables/`: `DEFAULT.reg`, `DISABLEPNP.ps1`, `CLIENTCBS.ps1`, `AtlasModules/Scripts/ScriptWrappers/{DisableFileSharing,DisablePowerSaving,DefaultPowerSaving,ConfigVBS}.ps1`, `AtlasModules/Scripts/{setSvc.cmd,indexConf.cmd}`, `AtlasDesktop/**` (Superfetch, Printing, Bluetooth, Network Discovery, Lanman, NVIDIA, Power-saving, Hibernation, CPU Idle, Timer Resolution, FSO/Game Bar, Search Indexing, Delivery Optimization, Automatic Updates, Mitigations), `AtlasModules/Other/Force Timer Resolution.xml`, `Tools/SetTimerResolution.exe`, `Modules/Performance/Performance.psm1`

**Web (accessed 2026-10-07):**
- Microsoft Learn — Guidance on configuring system services (Windows IoT Enterprise): https://learn.microsoft.com/en-us/windows/iot/iot-enterprise/optimize/services (fetched full table; per-service 🟢🟡⛔🔵 statuses quoted in §1.4)
- Microsoft Learn — MMCSS registry settings: https://learn.microsoft.com/en-us/windows/win32/procthread/multimedia-class-scheduler-service
- Microsoft Learn — svchost service refactoring: https://learn.microsoft.com/en-us/windows/application-management/svchost-service-refactoring
- Microsoft Learn — performance-tuning file server (SMB throttling): https://learn.microsoft.com/en-us/windows-server/administration/performance-tuning/role/file-server
- Intel — DMACoalescing latency note: https://www.intel.com/content/www/us/en/support/articles/000007456/ethernet-products.html
- MS devblogs — FTH (Raymond Chen): https://devblogs.microsoft.com/oldnewthing/20120125-00/?p=8463
- STIG viewer — V-220932/V-220930 (anonymous share restrictions)
- Blur Busters forum (Dec 2024) — 24H2 GlobalTimerResolutionRequests + 0.5 ms discussion: https://forums.blurbusters.com
- PCGamingWiki — "Windows 11 only: restore legacy system-wide timer resolution behavior": https://www.pcgamingwiki.com
- TenForums/SuperUser — autotuninglevel must not be disabled: https://www.tenforums.com, https://superuser.com
- WindowsForum (Jan 2026) HAGS thread; Acer blog (Aug 2026) HAGS caveats; SteamCommunity HAGS reports — mixed consensus, no benchmark claim made
- TechSpot (Aug 2026) / Yahoo Tech (Sep 2026) — Windows 11 26H2 rollout overview (movable taskbar, local search focus)
- ⚠️ amitxv/SetTimerResolution GitHub repo — **404 as of 2026-10-07**; binary bundled in Atlas repo

**Honesty ledger (placebo risk):** disable-paging (Atlas: "likely placebo"), NDU disable (unverified on 26H2), NetworkThrottlingIndex/TcpAckFrequency (anecdotal, corner-case), HAGS on/off (mixed reports), CPU-mitigation disabling on modern CPUs (≈0 gain), FSO-disable (title-dependent), MPO-disable (troubleshoot-only). Measurably real: MMCSS=10, Win32PrioritySeparation=0x26, service-host-split RAM savings, SMB throttling off (large copies), GameDVR background capture off, reserved storage reclaim, FTH reset, NTFS last-access/8.3, minimal indexing (disk/CPU), power-saving elimination (DPC jitter, desktops).
