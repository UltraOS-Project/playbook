# ReviOS Playbook (MeetRevision) — Deep-Dive Dossier

**Agent:** T1-b (ReviOS playbook research) · **Accessed:** 2026-10-07
**Status:** ✅ LIVE REPO FOUND, CLONED, FULLY ANALYZED FROM SOURCE
**Repo:** https://github.com/MeetRevision/playbook (default branch `main`)
**Local clone:** `/home/z/my-project/repos/revi` (92 files, HEAD `702a1715e0399094a07fd0cd668d557412b15a65`, 2026-10-05, "new way to prevent CrossDeviceResume from running" — repo is actively maintained)
**Companion repos analyzed:** `MeetRevision/revision-tool` (cloned → `/home/z/my-project/repos/revi-tool`, GPL-3.0, Dart/Flutter) and `MeetRevision/packages` (WinSxS removal manifests, read via raw.githubusercontent.com)
**License of playbook repo:** `LICENSE` = **Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)** — ⚠️ NOT GPL. If UltraOS copies YAML verbatim, CC BY-SA attribution + share-alike obligations apply (Revision Tool itself IS GPL-3.0).

---

## 1. Repo discovery (method + dead ends)

- `MeetRevision/Revi-Playbook` → **404 (dead, as briefed)**. `MeetRevision/Revi-Playbook-v2`, `MeetRevision/ReviOS`, `revios/playbook`, `ReviTools/playbook` → all 404.
- Scraped `https://github.com/MeetRevision?tab=repositories` → org repos: `packages`, `playbook`, `revision-tool`, `ventoy-conf`.
- **`MeetRevision/playbook` → HTTP 200 → cloned with `git clone --depth 1`.** The old `Revi-Playbook` repo was renamed/moved to `playbook`.
- Website: https://revi.cc (Cloudflare-protected for curl; readable via z-ai `page_reader`). Docs: https://revi.cc/docs/features, /docs/playbook/install, /docs/playbook/uninstall, /docs/setup/post-install. Discord: https://discord.gg/962y4pU (README). Donate: https://revi.cc/donate.
- Release cadence (GitHub tags): 23.05, 23.07, 23.08, 23.09, 23.10, 23.12, 24.06, 24.12, **25.10, 26.04 (latest)** — i.e. YY.MM date versions, sparse releases (~2–4/yr) while commits continue on `main` (latest 2026-10-05).

## 2. Folder anatomy (full, 92 files)

```
.github/
  FUNDING.yml, ISSUE_TEMPLATE/{bug_report.yaml, config.yml, feature_request.yaml}
  workflows/main.yml              ← build+release pipeline ("Archive and Release")
.vscode/{extensions.json, settings.json}   ← yaml.customTags = AME Wizard action tags (see §5)
images/github-banner.png, README.md, LICENSE (CC BY-SA 4.0), .gitignore ("*.apbx", "RevisionTool-Setup.exe")
src/
  playbook.conf                   ← AME Wizard XML metadata + wizard UI pages (§4)
  playbook.png                    ← wizard cover art
  Images/{brave.png, firefox.png} ← package icons for wizard Software page
  Configuration/
    main.yml                      ← entry point, orchestrates all task files (§6)
    Tasks/
      start.yml  services.yml  software.yml  registry.yml  revert.yml  final.yml
      packages/{app-win32.yml, appx.yml, win-sxs.yml, optional-features.yml}
      registry/
        os-info/{edition.yml, oem-info.yml}
        explorer/{context-menu, control-panel, explorer, notifications, search, start-menu, taskbar, view, win-settings}.yml
        privacy/{app-compat, cdm, ceip, cloud-content, privacy, telemetry, wer}.yml
        security/{bitlocker, security, vbs}.yml
        system/{boot, bypass-requirements, crash-control, disable-automatic-maintenance, ifeo, kernel, logon, multimedia, oobe, power, win32ps}.yml
        updates/{drivers, ms-store, updates}.yml
        misc/{classic-photo-viewer, deprovisioned-apps, disable-logging, disable-system-restore-pre-defined-config, enable-audio-communications-do-nothing, fixes, msi-installer-in-safe-mode}.yml
  Executables/                    ← scripts + assets shipped inside the .apbx
    EDGE.ps1, ONED.cmd, CLEANER.ps1, DISM-FEATURES.ps1, ngen.ps1, STARTMENU.cmd,
    FINALIZE.cmd, FILEASSOC.cmd, assoc.ps1, UPDATE-APPX.ps1, WALLPAPER.ps1,
    WallpaperStartup.cmd, Set-Theme.ps1, hosts, settings.json (winget/DesktopAppInstaller),
    LayoutModification.{xml,json}, DefaultLayouts.xml, OEMDefaultAssociations.xml,
    BraveSoftware/Brave-Browser/Application/initial_preferences,
    Licenses/{brave-browser-mpl.txt, fluent-gtk-theme-gnu-gpl-v3.0.txt},
    Wallpapers/{desktop.jpg, lockscreen.jpg}
```
No `Executables/*/Modules` CAB tree like Atlas — heavy lifting (appx/WinSxS/powerplan/defender) is delegated to the **Revision Tool binary** downloaded/bundled at build time (§8, §11).

## 3. Key metadata — `src/playbook.conf` (verbatim excerpts)

```xml
<Name>ReviOS</Name>
<Username>Revision</Username>
<Title>ReviOS Playbook</Title>
<Version>1.0</Version>                        <!-- patched to YY.MM by CI -->
<UniqueId>6a93ec26-284d-4943-9fc4-c9616def55c6</UniqueId>
<UpgradableFrom>any</UpgradableFrom>
<SupportedBuilds>
    <string>19044</string>   <!-- Win10 21H2 + LTSC -->
    <string>19045</string>   <!-- Win10 22H2 -->
    <string>22631</string>   <!-- Win11 23H2 -->
    <string>26100</string>   <!-- Win11 24H2 + LTSC -->
    <string>26200</string>   <!-- Win11 25H2 -->
    <string>28000</string>   <!-- Canary/26H1 platform build -->
    <string>26300</string>   <!-- Win11 26H2 GA build -->
</SupportedBuilds>
<Requirements>
    <Requirement>DefenderToggled</Requirement>
    <Requirement>NoPendingUpdates</Requirement>
    <Requirement>NoAntivirus</Requirement>
    <Requirement>Internet</Requirement>
    <Requirement>PluggedIn</Requirement>
</Requirements>
<UseKernelDriver>false</UseKernelDriver>
<ProductCode>32</ProductCode>
<Git>https://github.com/meetrevision/playbook</Git>
<Website>https://revi.cc</Website>
<DonateLink>https://revi.cc/donate</DonateLink>
<SupportsISO>true</SupportsISO>
<ISO>
    <DisableBitLocker>true</DisableBitLocker>
    <DisableHardwareRequirements>true</DisableHardwareRequirements>
</ISO>
<OOBE>
    <BulletPoints>
        <BulletPoint Icon="Rocket" Title="Performance Boost" Description="..."/>
        <BulletPoint Icon="Privacy" Title="Enhaned Privacy" Description="..."/>
        <BulletPoint Icon="Lock" Title="Revision Tool" Description="Fine-tune your system with our dedicated tool..."/>
    </BulletPoints>
    <Internet>Request</Internet>
</OOBE>
```

### 🔑 Edition & version gating — CRITICAL FINDING for UltraOS
- **ReviOS already lists build `26300` in SupportedBuilds.** Web search (2026-10-07): Windows 11 **26H2 GA = build 26300** (release build 26300.9457, GA 2026-09-29, Release Preview 2026-08-27; source: NamuWiki + Windows news results). Build `28000` = 26H1 Canary platform build. **→ ReviOS ALREADY SUPPORTS 26H2; Atlas does NOT (26100/26200 only).** UltraOS's 26H2 target = **build 26300** must be in `SupportedBuilds`.
- README: supports ARM64 + AMD64 of Win10 21H2/22H2 (incl. LTSC), Win11 23H2/24H2 (+LTSC)/25H2. "ISO Injection is only supported on Windows 11 ISOs."
- **Almost zero in-YAML build gating** — the only build check in the entire repo is in `FINALIZE.cmd`:
  ```bat
  for /f "tokens=3" %%i in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v "CurrentBuild"') do set "build=%%i"
  if %build% gtr 19045 ( set "w11=true" )   ← only used for ReviOS 10 vs ReviOS 11 branding
  ```
  Strategy: one tweak set, written to be forward-compatible across 19044→28000, with per-build breakage handled reactively (issue-linked comments), instead of Atlas's per-build gating via SupportedBuilds restriction.
- Edition branding: `registry/os-info/edition.yml` sets `EditionSubManufacturer=MeetRevision`, `EditionSubstring=Revision`, `EditionSubVersion=ReviOS`; `oem-info.yml` sets OEMInformation (SupportURL = Discord invite).

## 4. Wizard options system (FeaturePages, verbatim)

**Software page** (browser choice, `<Software>` block + `RadioImagePage` with `CheckDefaultBrowser="true" DependsOn="software" DefaultOption="browser-brave" IsRequired="true"`):
```xml
<Package Option="browser-brave" DefaultWebBrowser="true"><Name>brave</Name><Title>Brave</Title>...</Package>
<Package Option="browser-firefox" DefaultWebBrowser="true"><Name>firefox</Name>...</Package>
<RadioImageOption None="true" />
<RadioImageOption><Text>Brave</Text><Name>browser-brave</Name><FileName>brave</FileName>
  <GradientTopColor>#392DD1</GradientTopColor><GradientBottomColor>#A91B78</GradientBottomColor></RadioImageOption>
<RadioImageOption><Text>Firefox</Text><Name>browser-firefox</Name>...</RadioImageOption>
<BottomLine Text="Privacy comparison" Link="https://privacytests.org/" />
```

**Option catalog + defaults** (all pages, `IsChecked` = wizard default):

| Page | Option name | Wizard text | Default |
|---|---|---|---|
| RadioImage | `browser-brave` / `browser-firefox` / none | Brave / Firefox | **brave** |
| Radio | `disable-defender` / `enable-defender` | Disable/Enable Defender | **disable** (⚠️ security tradeoff surfaced in UI: "Disabling Windows Defender can improve system performance, but at the cost of security.") |
| Radio | `disable-hibernate` / `enable-hibernate` | Disable/Enable Hibernate (incl. Fast Startup) | **disable** (BottomLine: "⚠️ Disabling may overheat laptops in sleep mode") |
| Checkbox | `remove-edge` | Remove Microsoft Edge | ON |
| Checkbox | `remove-onedrive` | Remove OneDrive | ON |
| Checkbox | `remove-winsxs-ai` | Remove AI (Recall & Copilot) | ON |
| Checkbox | `remove-teams` | Remove Microsoft Teams | ON |
| Checkbox | `remove-appx-photos` | Remove MS Photos | ON |
| Checkbox | `remove-appx-devhome` | Remove Dev Home | ON |
| Checkbox | `remove-appx-xbox` | Remove Xbox apps | **OFF** (daily-use balance!) |
| Checkbox | `remove-appx-yourphone` | Remove 'Your Phone' | ON |
| Checkbox | `configure-wallpaper` | Apply Revision wallpaper | ON |
| Checkbox | `configure-darkmode` | Enable Dark Mode | ON |
| Checkbox | `configure-lcm` | Enable Legacy Context Menu | ON |
| Checkbox | `configure-te` | Disable Transparency Effects | ON |
| Checkbox | `remove-pinned-items-startmenu` | Remove pinned items in Start Menu | ON |
| Checkbox | `disable-automatic-maintenance` | Disable Automatic Maintenance | **OFF** |

- Hidden/legacy option: `configure-explorer-taskbar-animations` is referenced in `registry/explorer/explorer.yml` (`option:` + `!option:` branches) but is **NOT** exposed in `playbook.conf` — used by Revision Tool / historical.
- Atlas comparison (from `/home/z/my-project/repos/atlas/src/playbook/playbook.conf`): Atlas options are `auto-updates-default/disable`, `browser-brave/chrome/firefox/librewolf`, `defender-disable/enable`, `disable-core-isolation`, `disable-hibernation`, `disable-power-saving`, `install-another-browser`, `install-toolbox`, `mitigations-default/disable`, `remove-snipping-tool`, `uninstall-edge`.

## 5. YAML tweak schema (verbatim examples)

Header of every task file:
```yaml
---
title: Services
description: Removal and configuration of services
privilege: TrustedInstaller    # or Admin
actions: ...
```
File-level keys: `title`, `description`, `privilege`, `onUpgrade: true` (revert.yml only), `actions`.

**Action vocabulary** (from `.vscode/settings.json` `yaml.customTags` — the canonical tag list): `!run`, `!registryKey`, `!registryValue`, `!appx`, `!file`, `!service`, `!scheduledTask`, `!taskKill`, `!systemPackage` (deprecated — comment in win-sxs.yml: "method of removing system packages is now deprecated and not recommended by Revision, as it is one of the main cause of #49"), `!cmd`, `!powerShell`, `!writeStatus`, `!task`, `!download`, `!status`, `!software`.

**Usage counts across the tree** (total ≈1,044 top-level actions): `!registryValue` 736 · `!registryKey` 103 · `!task` 52 · `!run` 36 · `!writeStatus` 32 · `!powerShell` 24 · `!service` 21 · `!taskKill` 18 · `!cmd` 7 · `!appx` 5 · `!download` 4 · `!status` 3 · `!file` 2 · `!software` 1. (2,016 lines of registry YAML in 34 files.)

Representative verbatim actions (note the modifier set):
```yaml
- !registryValue: {path: 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection', value: 'AllowTelemetry', type: REG_DWORD, data: '0'}
- !registryValue: {path: 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\Microsoft.BingWeather_8wekyb3d8bbwe', operation: add}   # deprovision key
- !registryValue: {path: 'HKCU\Software\Microsoft\GameBar', value: 'ShowStartupPanel', type: REG_DWORD, data: '0', option: "remove-appx-xbox"}
- !registryValue: {path: 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce', value: 'RevisionWallpaperStartup', type: REG_SZ, oobe: only,
    data: 'cmd /c "%SystemRoot%\Web\Wallpaper\MeetRevision\WallpaperStartup.cmd"', option: "configure-wallpaper"}
- !service: {name: 'DiagTrack', operation: change, startup: 4}          # 4=disabled, 3=manual, 2=automatic, 1=auto(boot)
- !taskKill: {name: "explorer", errorAction: Ignore}
- !taskKill: {name: "setup", errorAction: Ignore, pathContains: "\\Edge", option: "remove-edge"}
- !run: {exeDir: true, exe: "ONED.cmd", option: "remove-onedrive", oobe: false, iso: false, weight: 40}
- !run: {path: "%ProgramFiles%\\Revision Tool", exe: "revitool.exe", args: "tweaks security defender disable --force",
    wait: true, runas: currentUserElevated, weight: 100, option: 'disable-defender'}
- !download: {url: 'https://github.com/brave/brave-browser/releases/latest/download/BraveBrowserStandaloneSetup.exe',
    destination: "BraveBrowserStandaloneSetup.exe", cpuArch: X64, package: 'brave', option: "browser-brave"}
- !software: {name: "Firefox", source: chocolatey, option: "browser-firefox", package: 'firefox', weight: 150}
- !appx: {operation: clearCache, name: '*Client.CBS*'}
- !powerShell: {exeDir: true, wait: true, errorAction: Ignore, weight: 48, command: >- ... }
- !powerShell: {runas: trustedInstaller, command: | ... }
- !writeStatus: {status: "Removing Appx Packages"}
- !task: {path: 'Tasks\registry\privacy\telemetry.yml'}
- !file: {path: "%ProgramData%\\Microsoft OneDrive", option: "remove-onedrive"}
- !registryValue: {path: '...', value: 'X', operation: delete, option: '!disable-automatic-maintenance'}   # negated option
```
**Modifiers observed:** `option` / `options` (array) / `!name` negation · `oobe: true|only|false` · `iso: false` · `cpuArch: X64|Arm64` · `weight` (progress-bar weighting, values 10–200) · `errorAction: Ignore|Log|Halt` · `runas: currentUserElevated|trustedInstaller` · `wait`, `exeDir`, `overwrite`, `package`, `showOutput`, `showError`, `ignoreErrors` (cmd), `operation: change|add|delete` (registry/service), `pathContains` (taskKill).

## 6. Execution pipeline — `Configuration/main.yml` (verbatim order)

```yaml
- !task: {path: 'Tasks\registry\os-info\edition.yml'}
- !task: {path: 'Tasks\registry\os-info\oem-info.yml'}
- !task: {path: 'Tasks\start.yml'}
- !task: {path: 'Tasks\packages\app-win32.yml'}     # BEFORE win-sxs: "Uninstalling WinSxS packages before app-win32 could leave leftovers"
- !task: {path: 'Tasks\packages\win-sxs.yml'}
- !task: {path: 'Tasks\packages\appx.yml'}
# Defender requires explorer running to disable certain protections, so Explorer is terminated afterward
- !taskKill: {name: "explorer"} ... (+ SearchApp, SearchHost, RuntimeBroker, TextInputHost, ShellExperienceHost, backgroundTaskHost, Widgets)
- !task: {path: 'Tasks\software.yml'}
- !task: {path: 'Tasks\services.yml'}
- !task: {path: 'Tasks\registry.yml'}
- !task: {path: 'Tasks\revert.yml'}                 # onUpgrade: true — only on playbook upgrades
- !task: {path: 'Tasks\final.yml'}
```

`Tasks/start.yml` (TrustedInstaller) does: suppress Security-and-Maintenance toast → robocopy `Licenses` → copy `hosts` + `ipconfig /flushdns` → install VCRedist (`https://aka.ms/vs/17/release/vc_redist.x64.exe`, `/quiet /norestart`) → **install Revision Tool** (download `https://github.com/meetrevision/revision-tool/releases/latest/download/RevisionTool-Setup.exe`, fall back to bundled `RevisionTool-Setup.exe`, `/VERYSILENT /TASKS="desktopicon"`) → `ngen.ps1` (".NET Framework scheduled tasks + ngen install on loaded assemblies — "Optimizing PowerShell") → `revitool.exe tweaks performance powerplan enable`.

`Tasks/registry.yml` fans out to all 34 registry files in the order: OS Info → Explorer(9 files) → Privacy(7) → Security(2) → System(11) → Updates(3) → Misc(7).

## 7. Tweak catalog (what Revi actually changes)

### 7.1 Services (`Tasks/services.yml`, verbatim)
Disabled (startup 4): `dam`, `GpuEnergyDrv`, `NetBT`, `Telemetry` (Intel), `diagnosticshub.standardcollector.service`, `WerSvc`, `DiagTrack`, `wisvc`, `PcaSvc`, `WdiServiceHost`, `WdiSystemHost`, `tcpipreg` (marked experimental), `Wecsvc`, `UCPD` (+ `Disable-ScheduledTask -TaskPath '\Microsoft\Windows\AppxDeploymentClient' -TaskName 'UCPD velocity'`).
`edgeupdate` → Manual (3) "Disabling it breaks WebView installation via Visual Studio". `condrv` → Automatic (2) — "#184 … fixes error 3489660986 (0xd000003a)".
**Commented-out (reverted for compatibility, see §7.6):** `Beep`, `GraphicsPerfSvc`, `bam`, `Ndu`.

### 7.2 APPX removal (`Tasks/packages/appx.yml`)
44-package PowerShell list (SecureAssessmentBrowser, PeopleExperienceHost, Camera, WebExperience, WidgetsPlatformRuntime, Alarms, Maps, StickyNotes, windowscommunicationsapps, People, BingNews/Search/Weather, Solitaire, FeedbackHub, GetHelp, Getstarted, Todos, PowerAutomateDesktop, Cortana `549981C3F5F10`, QuickAssist, MicrosoftFamily, ZuneMusic/Video, SoundRecorder, Clipchamp, Whiteboard, TeamsforSurfaceHub, MailforSurfaceHub, PowerBI, Skype, OfficeHub, Office.{Excel,PowerPoint,Word,OneNote}, OutlookForWindows, Spotify, OutlookPWA, 3DViewer, Advertising, MixedReality.Portal, MSPaint (Paint3D), StartExperiencesApp) executed via:
```powershell
& (Join-Path $env:ProgramFiles 'Revision Tool\revitool.exe') appx --all-users --remove ($packages -join ',')
```
Optional blocks per wizard option (Photos; DevHome; YourPhone + `MicrosoftWindows.CrossDevice`). VCLibs restore (with OOBE offline fallback): `revitool.exe msstore-apps --id 9NBLGGH3FRZM,9NBLGGH4RV3K -r RP` ("9NBLGGH3FRZM - Desktop; 9NBLGGH4RV3K - UWPDesktop", `oobe: true`).

### 7.3 Win32 removals (`Tasks/packages/app-win32.yml`) — Edge technique is notable
- **Edge:** `EDGE.ps1 -Mode EdgeBrowser` — the "BrowserReplacement" trick: create `SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\MicrosoftEdge.exe` dummy, set `$env:windir = ""`, read uninstall string from `HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\ClientState\{56EB18F8-...}`, append `--force-uninstall --delete-profile`, **process spoofing**: copy `cmd.exe` to `$env:SystemRoot\ImmersiveControlPanel\sihost.exe` ("Allowed list of parent processes: dllhost.exe, msiexec.exe, sihost.exe, SystemSettings.exe"), run, cleanup. Plus `AllowUninstall=1` in EdgeUpdateDev, shortcut cleanup, then revitool appx removal of `Microsoft.MicrosoftEdge`, `Microsoft.MicrosoftEdgeDevToolsClient`, `Microsoft.Edge.GameAssist`.
- **OneDrive:** taskkill family → `ONED.cmd` (`oobe: false, iso: false`) → delete `%SystemDrive%\OneDriveTemp`, `%ProgramData%\Microsoft OneDrive` → revitool appx removal (`OneDrive`, `microsoft.microsoftskydrive`). `ONED.cmd` is a polyglot batch+PowerShell that iterates HKU hives per-user uninstall strings, removes Run entries + sidebar CLSID pin `{018D5C66-4533-4307-9B53-224DE2ED1FE6}`.
- **Teams:** taskkill → revitool appx (`MicrosoftTeams`, `MSTeams`, `Flipgrid`) → msiexec `/X{A7AB73A3-CB10-4AA5-9D38-6AEFFBDE4C91}` → prevent reinstall: `HKLM\...\CurrentVersion\Communications /v ConfigureChatAutoInstall /t REG_DWORD /d 0`.

### 7.4 WinSxS component removal (`Tasks/packages/win-sxs.yml` + `MeetRevision/packages` repo)
All via Revision Tool "winpackage" system (deprecated `!systemPackage:`):
```yaml
- !run: {path: "%ProgramFiles%\\Revision Tool", exe: "revitool.exe", args: "winpackage --install system-components-removal", ...}
- !run: {..., args: "tweaks security defender disable --force", option: 'disable-defender'}
- !run: {..., args: "winpackage --install ai-removal", option: 'remove-winsxs-ai'}
- !run: {..., args: "winpackage --install onedrive-removal", option: "remove-onedrive"}
- !run: {..., args: "winpackage --install xbox-removal", option: "remove-appx-xbox", weight: 30}
```
Xbox extra: `HKCR\ms-gamebar` protocol redirect to `%SystemRoot%\System32\systray.exe` (stub, issue #139).
**Packages repo** (`github.com/MeetRevision/packages`, per-arch manifests: `systemPackages-removal-{amd64,arm64}.yaml`, `ai-removal-*`, `defender-removal-*`, `onedrive-removal-*`, `xbox-removal-*`, + `schema.json`). Manifest format:
```yaml
copyright: MeetRevision
package: Revision-ReviOS-SystemPackages-Removal
target_arch: amd64
version: 1.0.0.0
updates:
  - target_component: Microsoft-Windows-Client-SQM-Consolidator
    target_arch: amd64
    version: 38655.38527.65535.65535     # supersede-with-huge-version trick
  # found in 26H2
  - target_component: Microsoft-Windows-SQM-Consolidator
    ...
```
`schema.json` fields: `copyright`, `package`, `target_arch` (amd64/arm64/wow64), `version` (x.x.x.x), `updates[]` of `{target_component, target_arch (amd64|arm64|arm64.arm|arm64.x86|x86|wow64), version, registry_keys[]}`. Applied by Revision Tool via `Add-WindowsPackage -Online -NoRestart -IgnoreCheck -PackagePath "..."` (revi-tool `win_package_repository_impl.dart:145`; run as admin *not* TrustedInstaller because TrustedInstaller breaks console output). CABs are downloaded at runtime from `meetrevision/packages` GitHub releases (`network_endpoints.dart`: `api.github.com/repos/meetrevision/packages/releases/latest`). Docs claim: "**Windows Update cannot reinstall the removed components** ✨". Removed components incl.: Telemetry Client, CEIP (SQM), Error Reporting, Targeted Content Service (32-bit), Windows Insider Program, first-logon animation, UNP, Windows To Go, Retail Demo Content, Photo Viewer 32-bit, Intel Indeo, Defender (full), AI: **Recall (AIX), Click To Do (CoreAI), Copilot** (incl. re-registering `Microsoft.AIFabric.CBS.1.6` SystemApp manifest handling in `win_package_service.dart`).

### 7.5 Optional features (`Executables/DISM-FEATURES.ps1`)
Idempotent enable/disable — checks `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Notifications\OptionalFeatures\<name>\Selection` before acting: Enable `DirectPlay`, `LegacyComponents`; Disable `MicrosoftWindowsPowerShellV2(+Root)`, `MSRDC-Infrastructure`, `Printing-Foundation-Features`, `Printing-Foundation-InternetPrinting-Client`, `WorkFolders-Client`.

### 7.6 Rollback of outdated tweaks (`Tasks/revert.yml`, `onUpgrade: true`)
Undo layer for users upgrading from older playbook versions — every entry documents its reason with issue links (this is Revi's compatibility-diary). Verbatim samples:
```yaml
# https://github.com/meetrevision/playbook/issues/27, bbr2 causes issues with sending websocket data
- !run: {exe: 'netsh', args: 'int tcp set supplemental internet congestionprovider=default'}
# Breaks XboxGipSvc - .../issues/34
- !registryValue: {path: 'HKLM\SYSTEM\ControlSet001\Control', value: 'SvcHostSplitThresholdInKB', type: REG_DWORD, data: '3670016'}
# Setting it to 0 breaks THE FINALS
- !registryValue: {path: 'HKLM\SYSTEM\ControlSet001\Control\CI\Config', value: 'VulnerableDriverBlocklistEnable', type: REG_DWORD, data: '1'}
# DPS is needed for the Data Usage page in Settings and Network monitoring in Task Manager.
- !service: {name: 'DPS', operation: change, startup: 2}
```
Also reverts: IE policies, `HeapDeCommitFreeBlockThreshold`, `bam`→Automatic (Task Mgr Efficiency Mode), GameDVR AppCaptureEnabled (#74), ProcessMitigationOptions keys, Memory Management FeatureSettings*, superfetch enable ("Disabling core Superfetch components break 'defrag c: -b'"), speech recognition, OneDrive DisableFileSyncNGSC, biometrics policies, background-apps enable (Xbox Game Bar KGL), MouseHoverTime→400, DisableAutomaticRestartSignOn (Windows Hello slow logon fix).

### 7.7 Registry highlights (per official docs + files)
- **Telemetry/privacy:** `AllowTelemetry=0` in 6 locations; autologgers `Diagtrack-Listener`, `SQMLogger`, `SetupPlatformTel` Start=0; CDM fully off; app-compat engine off; WER off; web search off (`DisableSearchBoxSuggestions=1`, `ConnectedSearchSafeSearch` delete); NVIDIA telemetry off; hosts-file blocking (~60 hosts, `0.0.0.0`, incl. Brave p2a/p3a and VS telemetry, with breakage comments e.g. `browser.events.data.microsoft.com` "breaks Visual Studio Download page").
- **Performance:** `Win32PrioritySeparation=38` (26/38 short-quantum); IFEO `Debugger=taskkill.exe` blocks for `CompatTelRunner.exe`, `AggregatorHost.exe`, `DeviceCensus.exe`, `FeatureLoader.exe` (PC Manager), `BingChatInstaller.exe`, `BGAUpsell.exe`, `BCILauncher.exe`; IFEO `PerfOptions` CPU priorities (SearchIndexer 5, ctfmon 5, fontdrvhost 1/IO 0, lsass 1, sihost 1/IO 0); `WaitToKillServiceTimeout=1500`, `MenuShowDelay=0`, `ActiveWndTrkTimeout=10`, `HungAppTimeout=2000`, `WaitToKillAppTimeout=2000`, `LowLevelHooksTimeout=1000`, `AutoEndTasks=1`; `NetworkThrottlingIndex=10` (kept default, cites djdallmann/GamingPCSetup research); folder-type discovery off; Downloads "Group By" stripped; explorer GPU preference `GpuPreference=2;`; JPEGImportQuality=100; mouse accel off (raw input).
- **Security:** VBS/HVCI off (`revitool tweaks security vbs disable` — "automatically disables Memory Integrity (HVCI) as well"); BitLocker auto-device-encryption off (`PreventDeviceEncryption=1`); SmartScreen off; App Install Control `Anywhere`; Defender Watson reporting off; Defender signature updates on battery disabled; SecurityHealth tray hidden + Run entry deleted; docs: WPBT disabled, Credential Guard off, CFG for Vanguard `vgc.exe`, ASLR for osu!.
- **Windows Update:** updates **paused until 2038-01-19** via revitool (`tweaks updates wu-pause-updates enable`, `FlightSettingsMaxPauseDays`); WU driver updates disabled (`tweaks updates wu-drivers disable`); DO `DODownloadMode=0`; Reserved Storage disabled (also in CLEANER.ps1 `Set-WindowsReservedStorageState -State Disabled`); Update Orchestrator DevHome/Outlook blockers (`BlockedOobeUpdaters=["MS_Outlook"]`, `workCompleted=1`); MS Store `AutoDownload=4`, `DisableOSUpgrade=1`; `HideMCTLink=1`.
- **Explorer/UX:** legacy context menu (`{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32`), Take Ownership context menu (with `AppliesTo` guard for system folders), dark mode, transparency off, taskbar widgets/chat/people/meet-now off, Start pins JSON (`ConfigureStartPins` = Store/Settings/Notepad/Paint/Explorer/Calculator), taskbar End Task, LaunchTo=1 (This PC), extensions shown, sudo inline (24H2+), Settings pages hidden via revitool `registry hide-page --value "cortana,privacy-feedback,windowsinsider,home"`.
- **OOBE** (`system/oobe.yml`): local account default (`HideOnlineAccountScreens=1`), EULA/wireless/OEM/privacy-experience hidden, `ProtectYourPC=3`, Cortana voice off, `NetworkLocation=Home`.
- **Bypass** (`system/bypass-requirements.yml`): `HKLM\SYSTEM\Setup\LabConfig` Bypass{SecureBoot,TPM,CPU,RAM,Storage}Check=1, `MoSetup\AllowUpgradesWithUnsupportedTPMOrCPU=1`, SV1/SV2 watermark cache=0, `OOBE\BypassNRO=1` ("Credits to St1cky and crypticus").
- **Deprovisioning** (`misc/deprovisioned-apps.yml`): 50+ `AppxAllUserStore\Deprovisioned\<pkg>` keys incl. all Edge variants + `DoNotUpdateToEdgeWithChromium=1`.

### 7.8 Scheduled tasks & boot (`Executables/FINALIZE.cmd`)
- Uninstalls Update Health Tools (`msiexec /X{43D501A5-E5E3-46EC-8F33-9E15D2A2CBD5}`), PC Health Check (`{804A0628-...}`), Windows Installation Assistant.
- `schtasks /change /disable` on 12 tasks (App Experience/CEIP, MemoryDiagnostic, WU Scheduled Start, UpdateOrchestrator OOBE scans, Power Efficiency Diagnostics…); `final.yml` also disables all `\Microsoft\Office\*` tasks.
- `wevtutil sl .../q:false` on SleepStudy/Kernel-Processor-Power/UserModePowerService diagnostic logs.
- bcdedit: `description "ReviOS 11 <ver>"`, `deletevalue useplatformclock`, `deletevalue disabledynamictick` ("breaks ROG Ally sleep, see #167"), `bootmenupolicy Legacy`, `lastknowngood yes`. Docs also claim HPET disabled, RealTimeIsUniversal (UTC clock dual-boot fix).
- `net accounts /maxpwage:unlimited`; `Disable-WindowsErrorReporting`.
- CLEANER.ps1: cleanmgr `/sagerun:1337` preset (StateFlags1337 on ~20 VolumeCaches), `Clear-EventLog` all, stops bits/appidsvc/dps/wuauserv, wipes `%windir%\{CbsTemp,Logs,SoftwareDistribution,LogFiles\WMI,SleepStudy,sru,WDI\LogFiles,winevt\Logs,SystemTemp,Temp}`, `%TEMP%` cleanup **excluding `AME` and `Revision-Tool` folders**, EdgeUpdate downloads.

## 8. Post-install system — Revision Tool (replaces Atlas's "AtlasDesktop" folder)

- **`MeetRevision/revision-tool`** — GPL-3.0, "A tool to personalize ReviOS to your needs. Rewritten in Dart with Fluent UI" (Flutter + `bdlukaa/fluent_ui`, Riverpod, Rust native pkg `revitool_native`). `revitool.exe` = CLI, `revitoolw.exe` = GUI (CLI with no args launches GUI). Refuses non-ReviOS systems: `if (!WinRegistryService.isSupported && !WinRegistryService.isAmePlaybook) exit(55)` (`main_cli.dart`).
- **Single source of truth GUI+CLI:** annotations `@CliCommand`, `@CliToggle` (name/status/enable/disable/enableForce), `@CliValue` (get/set), `@CliAction`, `@CliEnumSubCommand` in service classes; a code generator builds the CLI from the same methods the GUI toggles call. Top-level commands: `appx`, `msstore-apps`, `registry` (hide-page/unhide-page), `tweaks`, `winpackage`.
- **Full toggle catalog** (grep of annotations — the post-install toggles Revi users get): `powerplan`, `powerplan-states-c6`, `superfetch`, `memory-compression`, `intel-tsx`, `swapchain-fso`, `swapchain-wo`, `swapchain-mpo`, `background-apps`, `background-window-message-rate-limit`, `ctfmon-input`, `ntfs-last-access`, `ntfs-8dot3-naming`, `ntfs-memory-usage`, `service-grouping` (forced|recommended|disabled), `rate-limit` (values), `defender` (+`--force`), `vbs`, `memory-integrity`, `mitigation`, `tm-monitoring`, `uac`, `usage-reporting`, `explorer-gallery`, `explorer-home`, `new-context-menu`, `legacy-balloon`, `notification`, `input-personalization`, `caps-lock`, `screen-edge-swipe`, `modern-standby`, `hibernation`, `fast-startup`, `wu-pause-updates`, `wu-visibility`, `wu-drivers`, `kgl`, `update-kgl`, `certificates`, `hide-page`/`unhide-page`.
- **Micro-patches:** `tweaks patches` = `disableDriversWU()` + `enablePauseUpdatesWU()` — final.yml comment: "Apply micro patches via Revision Tool in order to avoid new playbook releases for minor changes". This is how Revi ships hotfixes without re-releasing the .apbx (they ship Revision Tool updates instead — tool auto-updates from its own GitHub releases).
- **Playbook↔tool interop commands used in YAML:** `tweaks performance powerplan enable`, `tweaks performance ntfs-last-access disable`, `tweaks performance ntfs-8dot3-naming disable`, `tweaks performance service-grouping set recommended`, `tweaks performance intel-tsx enable`, `tweaks performance superfetch enable` (revert), `tweaks performance background-apps enable` (revert), `tweaks utilities hibernation|fast-startup enable/disable`, `tweaks security vbs disable`, `tweaks security defender enable|disable --force`, `tweaks updates wu-pause-updates enable`, `tweaks updates wu-drivers disable`, `tweaks patches`, `appx --all-users --remove <csv>`, `msstore-apps --id ... -r RP`, `winpackage --install <pkg>`, `registry hide-page --value "..."`.
- **Uninstall path (docs, works 25.10+):** Revision Tool → disable "Pause Windows Updates" + "Hide the Windows Updates page" → run `revitool.exe winpackage --uninstall system-components-removal` (and `defender-removal`, `ai-removal`, `onedrive-removal`) → Settings → Recovery → **"Fix problems using Windows Update"** (repair-in-place reinstall). "Errors may occur during the uninstallation of some packages. This is normal."

## 9. Build pipeline — `.github/workflows/main.yml` ("Archive and Release", verbatim key steps)

- Trigger: `workflow_dispatch` only (manual), `runs-on: windows-latest`, checks out `main`.
- Version = `date +%y.%m` (YY.MM), patched into `src\playbook.conf` `<Version>` **and** `src\Executables\FINALIZE.cmd` `set version=`.
- Downloads `RevisionTool-Setup.exe` from `meetrevision/revision-tool` latest release, **verifies SHA256 against the release asset digest**, saves hash to env (bundled fallback for offline start.yml).
- **Package:** `7z a -pmalte -mhe=on "Revi-PB-${{ env.VERSION }}.apbx" ./src/*` → password `malte` + header encryption (⚠️ note: this is 7-Zip's native format unless `-tzip` — Atlas recon described .apbx as "renamed ZIP, password malte"; build agents should verify which container AME Wizard actually requires before choosing).
- Generates SHA256, releases via `svenstaro/upload-release-action@v2`, tag = YY.MM, release body embeds `.apbx` SHA256 + bundled Revision Tool version + its SHA256. Release text funnels users to the website download link (support the project), GitHub release is the mirror.
- `.gitignore`: `*.apbx`, `RevisionTool-Setup.exe` (artifact + bundled binary never committed).
- Contrast with Atlas: Atlas builds via `src/dependencies/local-build.ps1` with flags (`-ReplaceOldPlaybook -AddLiveLog -Removals Verification,WinverRequirement`) and CI (`apbx.yaml`) that also rebuilds sxsc CABs; Revi has no validation job and no local-build script — just the 7z pack step.

## 10. Revi vs Atlas — design differences

| Dimension | ReviOS (MeetRevision/playbook) | Atlas (Atlas-OS/Atlas, from recon + clone) |
|---|---|---|
| Philosophy | "lightweight, stable… performance and privacy while **ensuring compatibility**" — balanced daily use | Maximum performance/gaming, debold first |
| Repo shape | `src/{playbook.conf, Configuration/{main.yml, Tasks/**}, Executables/**}` (92 files, lean) | `src/playbook/{playbook.conf, Configuration/{atlas/, tweaks/{debloat,misc,networking,performance,privacy,qol}}, Executables/{AtlasDesktop, AtlasModules}}` (571 files) |
| Heavy operations | Delegated to **Revision Tool binary** (appx, WinSxS CBS packages, powerplan, defender, VBS, WU pause) — playbook YAML calls `revitool.exe` CLI | Implemented in repo: PS1 + `AtlasModules/Packages/*.cab` built by sxsc |
| Post-install UX | Full GUI+CLI app (Fluent, auto-updating, toggle list §8) | "AtlasDesktop" shortcut folder (Software/Drivers/Config) |
| Version gating | 7 builds (19044→28000) in ONE tweak set; almost no per-build conditionals; reactive issue-driven fixes | SupportedBuilds 26100/26200 only; `WinverRequirement` removal flag in build |
| 26H2 (26300) | ✅ already in SupportedBuilds (+ 28000 Canary); packages manifest has "# found in 26H2" components | ❌ not supported (UltraOS's gap) |
| Defaults | Defender **OFF** by default, hibernate OFF, Xbox kept, transparency off, dark mode on, legacy context menu on, UAC/printing/Hyper-V/WSL/fullscreen-opt "Untouched" | More aggressive (mitigations-disable option, defender-disable, etc.); ⚠️ exact Atlas defaults not audited by this agent |
| Rollback | `revert.yml` with `onUpgrade: true` (migration undo) + Revision Tool `winpackage --uninstall` + WU repair-in-place for full uninstall | Atlas playbook revert files (`atlas/revert.yml`) ⚠️ (T1-a scope) |
| Browser install | `!download` per-arch from vendor GitHub + `!software` w/ **chocolatey** (Firefox); Brave pre-tweaked via `initial_preferences` file | Similar wizard Software page ⚠️ (details T1-a) |
| Release style | YY.MM date versions, manual workflow_dispatch, SHA256 in notes, sparse (10 releases 23.05→26.04) | Semver + CI apbx.yaml w/ yamllint validation ⚠️ (details T1-a) |
| Requirements | DefenderToggled, NoPendingUpdates, NoAntivirus, Internet, PluggedIn | Same **+ UCPDDisabled** |
| License | Playbook CC BY-SA 4.0; Revision Tool GPL-3.0 | ⚠️ Atlas repo license not audited by this agent (T1-a scope) |
| Docs | revi.cc/docs (features table, post-install guide incl. NVCleanstall, uninstall guide) + Discord | Atlas docs site ⚠️ (T1-a scope) |

## 11. What UltraOS should adopt from Revi (recommendations to build fleet)

1. **`SupportedBuilds` must include `26300`** (Win11 26H2 GA build — verified via web search 2026-10-07; Revi already ships it). Consider also listing the Canary/26H1 `28000` only if UltraOS commits to testing it — Atlas's 26100/26200-only stance is the market gap; Revi is already on 26H2, so UltraOS should match (26300) and beat Atlas.
2. **Companion CLI tool pattern**: UltraOS should ship a small CLI (GPL-3.0) exposing every tweak as `enable/disable/status`, generated from the same service layer as any GUI. Benefits Revi proves: (a) playbook YAML stays declarative, (b) **micro-patches ship via tool updates instead of .apbx re-releases**, (c) post-install toggles == playbook actions (no drift), (d) uninstall (`winpackage --uninstall`) becomes possible. Even a minimal `ultraos.exe tweaks <id> enable` covering the Safe/Balanced/Extreme delta would replicate this.
3. **WinSxS supersede manifests** (MeetRevision/packages style): per-arch YAML `{target_component, target_arch, version: 38655.38527.65535.65535, registry_keys[]}` + JSON schema, applied with `Add-WindowsPackage -Online -NoRestart -IgnoreCheck`. Property: WU cannot reinstall removed components. Avoid the deprecated `!systemPackage:` tag (Revi issue #49 — corrupted servicing). Already includes 26H2-only components (`Microsoft-Windows-SQM-Consolidator`).
4. **`revert.yml` with `onUpgrade: true`** — a dedicated migration-undo file, with every entry annotated by the user-visible bug/issue it fixes. Cheap insurance for a playbook that will iterate; UltraOS presets make this even more valuable.
5. **Forward-compatible tweak discipline**: write each tweak so it's valid across all supported builds (Revi has ~zero build conditionals). For UltraOS: verify the Safe preset on 26100/26200/26300; gate truly bleeding-edge 26H2-only tweaks (e.g., Recall/AIX removal, Click To Do) behind checks or keep them in Extreme preset.
6. **Idempotent DISM feature toggling** (read CBS `OptionalFeatures\<name>\Selection` first) — faster and avoids pointless CBS transactions (UltraOS priority: fast execution).
7. **`HKU\.DEFAULT` mirroring** for every HKCU tweak (Revi does it everywhere) so new user profiles inherit the config — important for OOBE/ISO injection flows.
8. **VCLibs/MSStore runtime repair** (`msstore-apps --id 9NBLGGH3FRZM,9NBLGGH4RV3K` with offline fallback) to keep Store apps functional after appx debloat — Revi runs it during OOBE specifically.
9. **Deprovisioned-keys wall** (50+ `AppxAllUserStore\Deprovisioned` entries) paired with appx removal, so WU can't resurrect bloat.
10. **Per-arch downloads** (`cpuArch: X64|Arm64`) and **`oobe:`/`iso:` action modifiers** to make one playbook serve live/OOBE/ISO-injection modes (Revi disables ONED.cmd for `iso: false` context).
11. **Hosts-file telemetry blocklist as defense-in-depth** (with inline breakage comments), plus IFEO `Debugger` blocks — cheap, reversible, complementary to service/registry layers.
12. **CI hygiene**: date-based versioning patched into playbook.conf + a status script, SHA256 of the artifact AND of every bundled binary in release notes, hash-verified downloads of bundled components (Revi verifies RevisionTool-Setup.exe digest before packing). ⚠️ Verify 7z-vs-zip container expectation of AME Wizard (Revi packs `7z a -pmalte -mhe=on`; Atlas recon says ZIP) — build agents must confirm before implementing UltraOS packaging.
13. **Community-proof commenting style**: every risky tweak carries its rationale + source link + linked GitHub issue; every *reverted* tweak documents why. Adopt for UltraOS YAML so build/research agents can trace decisions.
14. **Laptop-safety UI copy**: warnings like "⚠️ Disabling may overheat laptops in sleep mode" (hibernate page) and security tradeoff text on the Defender radio — mirror this honesty in UltraOS preset descriptions (Safe/Balanced/Extreme).
15. **Uninstall story**: document a supported uninstall (disable WU pausing → un-supersede removal packages → Settings→Recovery→"Fix problems using Windows Update"). UltraOS priority list includes rollback; Revi's approach is the only shipped, doc-backed full-uninstall among the two.
16. **License caution**: Revi playbook YAML is **CC BY-SA 4.0**. UltraOS is GPL-3.0 — copying YAML blocks verbatim requires attribution (+share-alike compat is a legal question for the lead). Recommendation: re-derive tweaks from first principles/MS docs (most values are documented policy values anyway), attribute Revi where inspiration is direct, and keep Revision-Tool-derived code GPL-3.0-compliant.

## 12. Sources (all accessed 2026-10-07)

- LIVE repo (cloned): https://github.com/MeetRevision/playbook — `src/playbook.conf`, `src/Configuration/**` (all files quoted verbatim above), `src/Executables/**`, `.github/workflows/main.yml`, `.vscode/settings.json`, `README.md`, `LICENSE` (CC BY-SA 4.0), HEAD `702a171` 2026-10-05.
- Revision Tool (cloned): https://github.com/MeetRevision/revision-tool — `src/lib/main_cli.dart`, `src/lib/core/cli_generator/annotations.dart`, `src/lib/features/tweaks/tweaks_command.dart`, `src/lib/features/tweaks/**/*_service.dart` (annotation grep), `src/lib/features/winsxs/data/repositories/win_package_repository_impl.dart`, `src/lib/core/network/network_endpoints.dart`, `README.md` (GPL-3.0).
- Packages manifests: https://github.com/MeetRevision/packages — `systemPackages-removal-amd64.yaml`, `schema.json` (via raw.githubusercontent.com; repo listing).
- Official docs (z-ai page_reader): https://revi.cc/docs/features (full feature tables incl. Untouched/Broken lists), https://revi.cc/docs/setup/post-install (activation/drivers guide), https://revi.cc/docs/playbook/uninstall (winpackage --uninstall procedure, 25.10+).
- Releases: https://github.com/MeetRevision/playbook/releases (tags 23.05→26.04; latest "Release 26.04").
- Web search (26H2 build): results stating Win11 26H2 GA = build **26300** (.9457), Release Preview 2026-08-27, GA 2026-09-29 (NamuWiki + Windows news).
- Comparison data: local clone `/home/z/my-project/repos/atlas` (structure + `playbook.conf` option names) — full Atlas analysis is T1-a's dossier.

## 13. ⚠️ UNVERIFIED / caveats

- **26300 = 26H2 GA build**: supported by multiple web-search results but not tested on a 26300 machine here (no Windows environment in sandbox). Build agents should treat `26300` as the 26H2 build to target and re-verify at build time.
- **.apbx container format**: Revi packs with `7z a -pmalte -mhe=on` (7-Zip native format unless `-tzip` implied); briefing/T1-a describes Atlas .apbx as a renamed ZIP. Both use password `malte`. Whether AME Wizard accepts both container formats was **not verified** — do a smoke test before choosing UltraOS packaging.
- `ProductCode 32` semantics (Atlas uses one too) — undocumented in what I read; presumably an internal AME/Wizard product registry id.
- Whether Revi's `28000` entry is actively QA'd or "best effort" for Canary Insiders — not stated in repo/docs.
- Atlas-side claims in the comparison table beyond what I directly read (Atlas defaults, license, docs) — T1-a's scope; marked where uncertain.
- Stars/forks/download counts for the playbook repo were not retrievable from the curl'd HTML.
