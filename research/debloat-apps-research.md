# UltraOS Research Dossier — T1-e: Debloat AppX Catalog (Windows 11 24H2/25H2/26H2-era)

Agent: T1-e | Date: 2026-10-07 | Status: COMPLETE
Scope: definitive AppX/package debloat catalog for the UltraOS playbook (Safe / Balanced / Extreme presets), Atlas ground truth (verbatim), community catalogs (winutil, Win11Debloat, Sycnex), working removal commands, dependency warnings, 2026 special cases (Copilot/Recall/Widgets/Outlook/Teams/OneDrive/Edge/UCPD), and a full reinstall/undo guide.

Sources convention: everything below was read directly from cloned repos or fetched URLs on **2026-10-07**. Items that could not be verified against a source in this environment are marked **⚠️ UNVERIFIED**.

---

## 1. Executive summary

- **Atlas (ground truth)** removes ~35 AppX families via AME Wizard `!appx` (family wildcard) and then **deprovisions every removed package** by diffing `Get-AppxPackage` before/after and creating `HKLM\…\AppxAllUserStore\Deprovisioned\<PackageFamilyName>` keys — the Microsoft-documented way to stop apps returning after feature updates. Phone Link (`Microsoft.YourPhone`) is deliberately NOT removed with `!appx` (breaks Cross Device Experience Host) but with plain `Remove-AppxPackage` + `Remove-AppxProvisionedPackage`. Snipping Tool and Edge are *options*, not defaults.
- **AME Wizard `!appx`** action (engine: `trusted-uninstaller-cli` → `ame-assassin.exe`) removes a package **family/package/app for ALL users**, directly editing the StateRepository SQLite + `AppxAllUserStore` registry (bypasses DISM, can require the KProcessHacker kernel driver). It does **not** deprovision — that's why Atlas adds the registry diff step. This is a critical implementation detail for UltraOS.
- **PowerShell 7 pitfall** (winutil, verified in code): `Remove-AppxPackage` pipeline binding from `Get-AppxPackage -AllUsers` fails silently in PS7 and DISM cmdlets throw "Class not registered" — always loop explicitly and/or shell out to Windows PowerShell 5.1.
- **Copilot (2026 state)**: the app is `Microsoft.Copilot` (Store ID `9NHT9RB2F4HD`, winget/msstore `XP9CXNGPPJ97XX`); it is distributed/updated through **EdgeUpdate**, and Microsoft announced the "unified Microsoft Copilot app" (Microsoft 365 Copilot app renamed → Microsoft Copilot). Appx removal alone can be undone by EdgeUpdate; `winget uninstall` + policies are the reliable removal path. `Microsoft.Windows.Copilot` as a package could **not** be verified (⚠️ UNVERIFIED — see §8.1).
- **Recall**: disabled via policy `DisableAIDataAnalysis` (CSP `…/WindowsAI/`), and its bits are removable via `Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -Remove` (MS Learn, verbatim verified). The AI platform package is `MicrosoftWindows.Client.CoreAI` (winutil removes it using the `EndOfLife` registry trick).
- **Edge on 26H2**: removal is *not* an appx operation; the working community method = `HKLM\SOFTWARE\Microsoft\EdgeUpdateDev → AllowUninstall` + stub `MicrosoftEdge.exe` in `SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe` + `setup.exe --uninstall --system-level --force-uninstall`. Atlas additionally blocks reinstall via `Deprovisioned\Microsoft.MicrosoftEdge.Stable_8wekyb3d8bbwe` and **requires UCPD disabled** before the playbook runs (playbook requirement `UCPDDisabled`). Known risk (upstream README, verbatim): "Removing Edge may cause update failure loop."

---

## 2. Mechanism primer — how AppX removal actually works

### 2.1 Inventory commands (always run these first)
```powershell
# Installed, per-user (run in Windows PowerShell 5.1 for full fidelity)
Get-AppxPackage -AllUsers | Select Name, PackageFullName, PackageFamilyName, InstallLocation, NonRemovable

# Provisioned (staged for NEW users)
Get-AppxProvisionedPackage -Online | Select DisplayName, PackageName, Version

# DISM equivalent
dism /online /get-provisionedappxpackages
```

### 2.2 Removal commands that work
```powershell
# 1) Current user only
Get-AppxPackage Microsoft.BingWeather | Remove-AppxPackage

# 2) All users (PS7 pitfall: pipeline binding silently fails — loop explicitly, winutil Remove-WinUtilAPPX.ps1)
$pkgs = Get-AppxPackage "*Microsoft.BingWeather*" -AllUsers | Sort-Object PackageFullName -Unique
foreach ($pkg in $pkgs) { Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers -ErrorAction Stop }

# 3) Deprovision (stop reinstall for new users) — DisplayName match, Win11Debloat style
$provs = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -Like "*Microsoft.BingWeather*"
foreach ($prov in $provs) { Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName }
# (newer alias also used by Win11Debloat: Remove-ProvisionedAppxPackage -Online -AllUsers -PackageName …)

# 4) DISM offline/online (Sysprep image path, from winutil Invoke-WinUtilISOScript.ps1)
dism /image:C:\mount /remove-provisionedappxpackages /packagename:<full-name>
# online:
dism /online /remove-provisionedappxpackages /packagename:Microsoft.BingWeather_4.x.x.x_neutral_~_8wekyb3d8bbwe

# 5) Prevent return after FEATURE UPDATES (Microsoft-documented; Atlas does this via diff)
#    HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\<PackageFamilyName>
New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned" -Name "Microsoft.BingWeather_8wekyb3d8bbwe" -Force

# 6) Block future provisioning of stubborn packages (EndOfLife trick, used by winutil for CoreAI)
$Appx = (Get-AppxPackage MicrosoftWindows.Client.CoreAI).PackageFullName
$Sid  = (Get-LocalUser $Env:UserName).Sid.Value
New-Item "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\EndOfLife\$Sid\$Appx" -Force

# 7) Sponsored/3rd-party app installs come from CloudContent/ContentDeliveryManager — policy:
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /t REG_DWORD /d 1 /f
# (plus HKCU ContentDeliveryManager values — see §8.11; Atlas config-content-delivery.yml is the full recipe)
```

### 2.3 AME Wizard `!appx` action (UltraOS will use this) — VERIFIED from docs + engine source
Docs (docs.amelabs.net/developers/actions/Appx.html, fetched 2026-10-07):
> "Removes a specified APPX family, package, or app. This can also clear the cache of a given APPX package. If you are not aware of the difference, leave the default of `family`."
- Parameters: `name` (string, wildcards both sides), `operation` (`remove`|`clearCache`, default `remove`), `type` (`family`|`package`|`app`, default `family`), `verboseOutput` (bool), `unregister` (bool — "the program files of the target APPX component will not be deleted").
- Docs-recommended cache clears after mass removal: `*Client.CBS*`, `*StartMenuExperienceHost*`, `*Windows.Search*`.

Engine source (`/home/z/my-project/repos/trusted-uninstaller-cli/TrustedUninstaller.Shared/Actions/AppxAction.cs`, read verbatim):
- Runs `ame-assassin.exe -<type> "<name>" [-Verbose] [-UseKernelDriver]`; `-ClearCache` for cache op.
- ISO mode: deletes package folders from `Program Files\WindowsApps` + `Windows\SystemApps` of the mounted WIM, or strips `<Application Id>` nodes from `AppxManifest.xml` when `type: app`.
- ame-assassin (github.com/Ameliorated-LLC/ame-assassin, branch `public`, "Specialized tool for removing APPX packages bypassing DISM, as well as for removing system components") edits the **StateRepository SQLite tables** (`PackageFamilyUser`, `Package`, `ProvisionedPackage`, `EndOfLifePackage`, …) and `HKLM\…\Appx\AppxAllUserStore` registry, kills locking processes (can restart Explorer), optionally uses a kernel driver (`-UseKernelDriver`, requires playbook `UseKernelDriver` flag).
- **It does NOT create Deprovisioned keys** → UltraOS must replicate Atlas's deprovision-diff step.

### 2.4 Atlas deprovision-diff trick (verbatim from appx.yml, explained)
1. BEFORE removals: `(Get-AppxPackage).PackageFamilyName | Out-File $env:windir\AtlasModules\AtlasPackagesOld.txt`
2. Remove families with `!appx`.
3. AFTER: `(diff (gc $a) ((Get-AppxPackage).PackageFamilyName)).InputObject | ForEach-Object { New-Item -Path "HKLM:\…\Appx\AppxAllUserStore\Deprovisioned" -Name $_ -Force }`
   (packages that disappeared = were removed → create a Deprovisioned key with the **PackageFamilyName**)
Microsoft doc backing this: "Keep removed apps from returning during an update" — https://learn.microsoft.com/en-us/windows/application-management/remove-provisioned-apps-during-update (fetched 2026-10-07; example key `…\Deprovisioned\Microsoft.BingWeather_8wekyb3d8bbwe`).

---

## 3. Atlas ground truth (VERBATIM)

### 3.1 `src/playbook/Configuration/atlas/appx.yml` (complete file, verbatim)
```yaml
---
title: AppX
description: Removes AppX packages and prevents them from being reinstalled
onUpgrade: false
actions:
  - !writeStatus: {status: 'Removing AppX packages'}
  
  # The reason of removing those applications is that they might be sending user data,
  # showing unwanted content and using hardware resources. They can also simply be annoyances
  # that are never used. However, most of these applications can be reinstalled via
  # Microsoft Store in case the user needs them.

  # https://docs.microsoft.com/en-us/windows/application-management/apps-in-windows-10

  #####################################################################################################

  # Get current AppX packages to deprovision removed ones afterward
  - !powerShell:
    command: |
      (Get-AppxPackage).PackageFamilyName |
        Out-File """$([Environment]::GetFolderPath('Windows'))\AtlasModules\AtlasPackagesOld.txt"""
    runas: currentUserElevated
    wait: true

  # AppX Microsoft Teams
  # Seems legacy - not in 23H2
  - !taskKill: {name: 'msteams*', ignoreErrors: true}
  - !appx: {name: 'MicrosoftTeams*', type: family}
  - !registryValue: {path: 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Communications', value: 'ConfigureChatAutoInstall', data: '0', type: REG_DWORD}

  # New AppX Teams in 24H2
  - !taskKill: {name: 'ms-teams*', ignoreErrors: true}
  - !appx: {name: 'MSTeams*', type: family}
  # 24H2 Copilot app
  - !appx: {name: 'Microsoft.Copilot*', type: family}

  # Other apps
  - !appx: {name: 'Clipchamp.Clipchamp*', type: family}
  - !appx: {name: 'Disney.37853FC22B2CE*', type: family}
  - !appx: {name: 'SpotifyAB.SpotifyMusic*', type: family}
  - !appx: {name: 'Microsoft.549981C3F5F10*', type: family} # Cortana
  - !appx: {name: 'Microsoft.XboxApp*', type: family} # Xbox Console Companion (deprecated)
  - !appx: {name: 'microsoft.windowscommunicationsapps*', type: family} # Mail and Calendar
  - !appx: {name: 'Microsoft.MSPaint*', type: family} # Paint 3D
  - !appx: {name: 'Microsoft.Getstarted*', type: family} # Tips (deprecated)
  - !appx: {name: 'Microsoft.ZuneVideo*', type: family} # Films & TV
  - !appx: {name: 'MicrosoftCorporationII.MicrosoftFamily*', type: family}
  - !appx: {name: 'Microsoft.MixedReality.Portal*', type: family}
  - !appx: {name: 'Microsoft.Windows.DevHome*', type: family}
  - !appx: {name: 'Microsoft.BingWeather*', type: family}
  - !appx: {name: 'Microsoft.BingNews*', type: family}
  - !appx: {name: 'Microsoft.BingSearch*', type: family}
  - !appx: {name: 'Microsoft.OutlookForWindows*', type: family}
  - !appx: {name: 'Microsoft.GetHelp*', type: family}
  - !appx: {name: 'Microsoft.Microsoft3DViewer*', type: family}
  - !appx: {name: 'Microsoft.MicrosoftOfficeHub*', type: family}
  - !appx: {name: 'Microsoft.MicrosoftSolitaireCollection*', type: family}
  - !appx: {name: 'Microsoft.MicrosoftStickyNotes*', type: family}
  - !appx: {name: 'Microsoft.Office.OneNote*', type: family}
  - !appx: {name: 'Microsoft.People*', type: family}
  - !appx: {name: 'Microsoft.PowerAutomateDesktop*', type: family}
  - !appx: {name: 'Microsoft.ScreenSketch*', type: family, option: 'remove-snipping-tool'}
  - !appx: {name: 'Microsoft.SkypeApp*', type: family}
  - !appx: {name: 'Microsoft.Todos*', type: family}
  - !appx: {name: 'Microsoft.WindowsAlarms*', type: family}
  - !appx: {name: 'Microsoft.WindowsCamera*', type: family}
  - !appx: {name: 'Microsoft.WindowsFeedbackHub*', type: family}
  - !appx: {name: 'Microsoft.WindowsMaps*', type: family}
  - !appx: {name: 'Microsoft.WindowsSoundRecorder*', type: family}
  - !appx: {name: 'Ink.Handwriting.Main.Store.en-US1.0', type: family}
  # Removing using AME Wizard causes issues with Cross Device Experience Host installing
  # - !appx: {name: 'Microsoft.YourPhone*', type: family}
  - !powerShell:
    command: |
      Get-AppxPackage Microsoft.YourPhone* | Remove-AppxPackage
      Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -eq 'Microsoft.YourPhone' } | Remove-AppxProvisionedPackage -Online
    runas: currentUserElevated
    wait: true

  # Prevent provisioned applications from being reinstalled
  # https://learn.microsoft.com/en-us/windows/application-management/remove-provisioned-apps-during-update
  - !powerShell:
    command: |
      $a = """$([Environment]::GetFolderPath('Windows'))\AtlasModules\AtlasPackagesOld.txt"""
      (diff (gc $a) ((Get-AppxPackage).PackageFamilyName)).InputObject | 
        Foreach-Object { New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned" -Name $_ -Force };
      Remove-Item $a -Force
    runas: currentUserElevated
    wait: true

  # Clear caches of Client.CBS and more
  # Start menu cache is cleared later
  - !writeStatus: {status: 'Clearing AppX caches'}
  - !appx: {operation: clearCache, name: '*MicrosoftWindows.Client.CBS*'}
  - !appx: {operation: clearCache, name: '*Microsoft.Windows.Search*'}
  - !appx: {operation: clearCache, name: '*Microsoft.Windows.SecHealthUI*'}
```

**Atlas removal summary** (35 `!appx` families + 2 special): Teams legacy `MicrosoftTeams*`, `MSTeams*`, `Microsoft.Copilot*`, `Clipchamp.Clipchamp*`, `Disney.37853FC22B2CE*`, `SpotifyAB.SpotifyMusic*`, `Microsoft.549981C3F5F10*` (Cortana, note: **NOT** the old `Microsoft.549981C3F8F0` Win10-era ID — see §8.13), `Microsoft.XboxApp*`, `microsoft.windowscommunicationsapps*`, `Microsoft.MSPaint*` (Paint 3D), `Microsoft.Getstarted*` (Tips), `Microsoft.ZuneVideo*`, `MicrosoftCorporationII.MicrosoftFamily*`, `Microsoft.MixedReality.Portal*`, `Microsoft.Windows.DevHome*`, `Microsoft.BingWeather*`, `Microsoft.BingNews*`, `Microsoft.BingSearch*`, `Microsoft.OutlookForWindows*`, `Microsoft.GetHelp*`, `Microsoft.Microsoft3DViewer*`, `Microsoft.MicrosoftOfficeHub*`, `Microsoft.MicrosoftSolitaireCollection*`, `Microsoft.MicrosoftStickyNotes*`, `Microsoft.Office.OneNote*`, `Microsoft.People*`, `Microsoft.PowerAutomateDesktop*`, `Microsoft.ScreenSketch*` (OPTION `remove-snipping-tool`), `Microsoft.SkypeApp*`, `Microsoft.Todos*`, `Microsoft.WindowsAlarms*`, `Microsoft.WindowsCamera*`, `Microsoft.WindowsFeedbackHub*`, `Microsoft.WindowsMaps*`, `Microsoft.WindowsSoundRecorder*`, `Ink.Handwriting.Main.Store.en-US1.0`, `Microsoft.YourPhone*` (PowerShell, not `!appx` — Cross Device Experience Host bug).

**Atlas KEEPS (never touches)**: Microsoft Store, DesktopAppInstaller (winget), Calculator, Photos (`Microsoft.Windows.Photos`), Notepad (`Microsoft.WindowsNotepad`), Terminal, Paint (`Microsoft.Paint` — only removes Paint 3D `Microsoft.MSPaint`), Media Player (`Microsoft.ZuneMusic`), Snipping Tool (default), Windows.WebExperience/Widgets (disables via policy instead — see §8.3), `Microsoft.WidgetsPlatformRuntime`, `Microsoft.StartExperiencesApp`, Quick Assist (`MicrosoftCorporationII.QuickAssist`), `MicrosoftWindows.CrossDevice`, Xbox stack except `XboxApp` (keeps `GamingApp`, `XboxGamingOverlay`, `XboxIdentityProvider`, `Xbox.TCUI`), `Microsoft.Whiteboard`, `Microsoft.RemoteDesktop`, all frameworks (`VCLibs`, `.NET Native`, `Microsoft.UI.Xaml`, `Microsoft.WindowsAppRuntime`), `MicrosoftWindows.Client.CoreAI`/Recall (handled via policy + optional features, not appx), `Microsoft.PCManager`.

### 3.2 `src/playbook/Configuration/atlas/components.yml` (complete file, verbatim)
```yaml
---
title: Components
description: Removes certain Windows components
onUpgrade: false
actions:
    # Remove Security Center startup item
  - !registryValue: {path: 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run', value: 'SecurityHealth', operation: delete}

    # Disable Smart App Control
    # Causes slow app loading issues and sends data to Microsoft
  - !registryValue:
    path: 'HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy'
    value: 'VerifiedAndReputablePolicyState'
    data: '0'
    type: REG_DWORD

    # Microsoft Edge
  - !writeStatus: {status: 'Removing Microsoft Edge', option: 'uninstall-edge'}
  - !powerShell:
    command: '& """.\AtlasModules\Scripts\ScriptWrappers\RemoveEdge.ps1""" -UninstallEdge -RemoveEdgeData -KeepAppX -NonInteractive'
    runas: currentUserElevated
    option: 'uninstall-edge'
    wait: true
    exeDir: true
    # AppX uninstallation in the script seems to fail, therefore it's not used and AME Wizard is used instead
    # Note that AppX Edge is removed from the latest builds of Windows, but people could be running a non-updated version
  - !appx: {name: 'Microsoft.MicrosoftEdge_8wekyb3d8bbwe', type: family, option: 'uninstall-edge'}
  - !registryKey: {path: 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\Microsoft.MicrosoftEdge_8wekyb3d8bbwe', operation: add, option: 'uninstall-edge'}
  - !registryKey: {path: 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\Microsoft.MicrosoftEdge.Stable_8wekyb3d8bbwe', operation: add, option: 'uninstall-edge'}

    # OneDrive
    # The actual OneDrive setup in Windows is stripped at a component-level in the miscellaneous package
  - !writeStatus: {status: 'Removing OneDrive'}
  - !run: {exeDir: true, exe: 'ONED.cmd'}

    # Windows components and Telemetry
  - !writeStatus: {status: 'Removing components'}
  - !registryKey:
    path: 'HKLM\OfflineSys\ControlSet001\Services\WdBoot'
    operation: delete
    option: 'defender-disable'
    iso: only
  - !powerShell:
    command: >-
      & """$([Environment]::GetFolderPath('Windows'))\AtlasModules\Scripts\packageInstall.ps1"""
      -InstallPackages @('*Z-Atlas-NoDefender-Package*',
        '*Z-Atlas-NoTelemetry-Package*'
      )
      -NoInteraction
    option: 'defender-disable'
    wait: true
    exeDir: true
  - !powerShell:
    command: >-
      & """$([Environment]::GetFolderPath('Windows'))\AtlasModules\Scripts\packageInstall.ps1"""
      -InstallPackages @('*Z-Atlas-NoTelemetry-Package*')
      -UninstallPackages @('*Z-Atlas-NoDefender-Package*')
      -NoInteraction
    option: 'defender-enable'
    wait: true
    exeDir: true
```
Notes: (a) OneDrive "component-level" comment is **stale** — current repo ships only `Z-Atlas-NoDefender-Package` and `Z-Atlas-NoTelemetry-Package` CABs (`src/sxsc/*.yaml`, superseded-component manifests); OneDrive is only removed via `ONED.cmd` (§8.6). (b) Edge: `!appx Microsoft.MicrosoftEdge_8wekyb3d8bbwe` (legacy UWP stub) + Deprovisioned keys for both `Microsoft.MicrosoftEdge_8wekyb3d8bbwe` and `Microsoft.MicrosoftEdge.Stable_8wekyb3d8bbwe` families. (c) `uninstall-edge` and `remove-snipping-tool` are user checkboxes (playbook.conf lines 116-132), NOT defaults.

### 3.3 Atlas OneDrive removal — `Executables/ONED.cmd` (verbatim, condensed)
Full file at `/home/z/my-project/repos/atlas/src/playbook/Executables/ONED.cmd`. Key steps:
1. Refuses to strip if any `%SystemDrive%\Users\<u>\OneDrive` folder is non-empty (`exit 6000`).
2. `taskkill /f /im OneDrive.exe`, then `"%windir%\System32\OneDriveSetup.exe" /uninstall` and `"%windir%\SysWOW64\OneDriveSetup.exe" /uninstall`.
3. Per real user hive (Volatile Environment check): deletes `BannerStore`, `AutoplayHandlers`, `App Paths`, `Uninstall` subkeys matching OneDrive; unpins Explorer sidebar: `HKU\<sid>\SOFTWARE\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}` (and WOW6432Node) `System.IsPinnedToNameSpaceTree=0`; deletes namespace key `{018D5C66-…}` from Desktop\NameSpace; deletes `HKU\<sid>\Environment\OneDrive` and `Run\OneDriveSetup`.
4. Deletes `%ProgramData%\Microsoft OneDrive`, `%LOCALAPPDATA%\Microsoft\OneDrive`, per-user `AppData\Local\Microsoft\OneDrive`, `Users\<u>\OneDrive`, Start Menu `OneDrive.lnk`.
5. Deletes `HKLM\…\Explorer\SyncRootManager\*OneDrive*` keys; deletes scheduled tasks `OneDrive Reporting Task` / `OneDrive Standalone Update Task`.

### 3.4 Atlas Edge removal chain (verified in repo)
`components.yml` → `AtlasModules\Scripts\ScriptWrappers\RemoveEdge.ps1` (he3als' EdgeRemover **v1.9.5**, based on ShadowWhisperer/Remove-MS-Edge, CC0-1.0). With `-UninstallEdge` the script downloads and runs `https://github.com/ShadowWhisperer/Remove-MS-Edge/releases/latest/download/Remove-Edge.exe` (hidden, waits), `-RemoveEdgeData` kills Edge processes and deletes `%LOCALAPPDATA%\Microsoft\Edge`. `-InstallEdge` reinstalls via official Edge MSI (msiexec /i … /quiet); `-InstallWebView` installs WebView2 Evergreen (`/silent /install`). Atlas runs it with `-KeepAppX` and does AppX via `!appx`.

### 3.5 Atlas UCPD handling (verified)
- `playbook.conf` Requirements include `UCPDDisabled` → **Atlas refuses to install unless the UCPD driver is already disabled** (user runs Atlas's pre-step).
- `Configuration/atlas/services.yml`: `!service: {name: 'UCPD', operation: change, startup: 4}` (disabled).
- `tweaks/debloat/disable-scheduled-tasks.yml`: disables scheduled task `\Microsoft\Windows\AppxDeploymentClient\UCPD velocity` (ignoreErrors).
- `Executables/FILEASSOC.cmd`: "Make a temporary renamed PowerShell executable to bypass UCPD — https://hitco.at/blog/windows-userchoice-protection-driver-ucpd/".
- UCPD facts (hitco.at article, fetched 2026-10-07, read verbatim): UCPD = "UserChoice Protection Driver", filter driver `system32\drivers\UCPD.sys` (FSFilter group, SYSTEM_START), rolled out Jan–Mar 2024 via Windows updates; blocks write access to UserChoice registry keys (default browser/PDF associations) for non-Microsoft processes → SetUserFTA 1.7 & friends get ACCESS DENIED. Managed by `UCPMgr.exe` + "UCPD velocity" task (velocity = gradual rollout control).
- UCPD vs Edge removal (community claims, clearly labeled): ⚠️ COMMUNITY CLAIM — Windows re-enables UCPD after cumulative updates and the driver blocks the `setup.exe --force-uninstall` / file-association changes used by debloaters, hence Atlas's hard requirement. The Atlas-side facts (requirement + service disable + renamed-powershell bypass) are verified; the causal "UCPD blocks Edge uninstaller" link is inferred, not verified from Microsoft docs.

---

## 4. Community catalogs (verified from source)

### 4.1 ChrisTitusTech/winutil (commit `9c87c02`, 2026-09-30)
Local clone: `/home/z/my-project/repos/winutil`.

**Removal engine** (`functions/private/Remove-WinUtilAPPX.ps1`): loops `Get-AppxPackage "*$Name*" -AllUsers` (sorted/unique) → `Remove-AppxPackage -Package $pkg.PackageFullName -AllUsers` — because "PowerShell 7 pipeline binding for Remove-AppxPackage fails silently". `Remove-WinUtilProvisionedAPPX.ps1` shells out to **powershell.exe 5.1** for `Remove-AppxProvisionedPackage` ("DISM cmdlets often fail with 'Class not registered' or hang in PowerShell 7").

**Catalog** (`config/appx.json` — includes Store IDs for reinstall; "Panel":"1" = default-checked): see table §5. Default removal preset `AppxDefault` (config/preset.json, 17 apps): FeedbackHub, GetHelp, MicrosoftOfficeHub, **Calculator**, Clipchamp, WindowsAlarms (Clock), QuickAssist, WindowsSoundRecorder, StickyNotes, Todos, Solitaire, PowerAutomate, DevHome, BingWeather, **StartExperiencesApp**, BingNews, Copilot, BingSearch.

**Notable tweaks** (config/tweaks.json):
- `WPFTweaksWidget` (Widgets - Remove): `Get-AppxPackage Microsoft.WidgetsPlatformRuntime -AllUsers | Remove-AppxPackage -AllUsers` + same for `MicrosoftWindows.Client.WebExperience`.
- `WPFTweaksWindowsAI` (AI - Disable And Remove): removes `MicrosoftWindows.Client.CoreAI` via `EndOfLife\<SID>\<PackageFullName>` key, `Get-AppxPackage -AllUsers "*Copilot*" | Remove-AppxPackage -AllUsers`, `winget uninstall -e --name "Copilot" --silent --force`, also removes `Microsoft.MicrosoftOfficeHub`, `Remove-AppxPackage $Appx` (CoreAI), `Set-Service WSAIFabricSvc -StartupType Disabled`, `Disable-WindowsOptionalFeature -FeatureName Recall -Online -NoRestart`, hides Settings page `hide:aicomponents`, disables Notepad AI (`HKLM\SOFTWARE\Policies\WindowsNotepad\DisableAIFeatures=1`).
- `WPFTweaksRemoveEdge`: dummy `%SystemRoot%\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\MicrosoftEdge.exe`, then `setup.exe --uninstall --system-level --force-uninstall --delete-profile`; undo via `winget install Microsoft.Edge`.
- `WPFTweaksRemoveOneDrive`: `icacls $Env:OneDrive /deny "*S-1-5-32-544:(D,DC)"` → `OneDriveSetup.exe /uninstall` → kill FileCoAuth/Explorer → delete `%LOCALAPPDATA%\Microsoft\OneDrive` + `%PROGRAMDATA%\Microsoft OneDrive` → grant back → delete folder if empty → `[Environment]::SetEnvironmentVariable('OneDrive',$null,'User')` → `Set-Service OneSyncSvc -StartupType Disabled`. Undo: `winget install Microsoft.Onedrive` + OneSyncSvc Automatic.
- `WPFTweaksConsumerFeatures`: `HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent /v DisableWindowsConsumerFeatures /d 1` (stops promoted/suggested app installs — the source of 3rd-party sponsored apps).
- **ISO post-install script** (`functions/private/Invoke-WinUtilISOScript.ps1` lines 501-529) removes provisioned+installed: Clipchamp.Clipchamp, Microsoft.BingNews, Microsoft.BingSearch, Microsoft.BingWeather, Microsoft.GetHelp, Microsoft.MicrosoftOfficeHub, Microsoft.MicrosoftSolitaireCollection, Microsoft.MicrosoftStickyNotes, Microsoft.OutlookForWindows, Microsoft.Paint, Microsoft.PowerAutomateDesktop, Microsoft.StartExperiencesApp, Microsoft.Todos, Microsoft.Windows.DevHome, Microsoft.WindowsFeedbackHub, Microsoft.WindowsSoundRecorder, Microsoft.ZuneMusic, MicrosoftCorporationII.QuickAssist, MSTeams — plus ContentDeliveryManager zeros and `reg delete Subscriptions / SuggestedApps` keys.

### 4.2 Raphire/Win11Debloat (fresh clone 2026-10-07, main)
Note: "Raphire/Reclaim" from the mission brief does **not exist** (404); the maintained repo is **Raphire/Win11Debloat**. Local clone: `/tmp/Win11Debloat`.

**Engine** (`Scripts/AppRemoval/Remove-SelectedApps.ps1`): per-app `RemovalMethod` from `Config/Apps.json`: `Appx` → `Remove-AppxApp` (loops packages, optional `-AllUsers`, and when AllUsers also `Remove-ProvisionedAppxPackage -Online -AllUsers -PackageName`); `WinGet` → `winget uninstall --accept-source-agreements --disable-interactivity --id <id>` with 120s timeout, post-removal verification via `winget list`, plus RunOnce scheduled uninstall for other/new users (base64-encoded command in `HKEY_USERS\Default\…\RunOnce`). Edge: tries winget (`Microsoft.Edge`/`XPFFTQ037JWMHS`), on failure prompts → `Invoke-ForceRemoveEdge` (§8.12).

**Recommendation tiers** (Config/Apps.json): `safe` (default-selected), `optional` (not default), `unsafe` (not default + warned): **unsafe** = Microsoft Edge, GetHelp, WindowsStore, WindowsTerminal, Xbox.TCUI, XboxIdentityProvider, XboxSpeechToTextOverlay; **safe defaults include**: Clipchamp, Cortana (549981C3F5F10), Bing suite, **Copilot via winget `XP9CXNGPPJ97XX`**, `Microsoft.Windows.AIHub` ("Copilot+ AI Hub"), `Microsoft.PCManager`, Getstarted, Messaging, 3DViewer, Journal, OfficeHub, PowerBI, Solitaire, StickyNotes, MixedReality, NetworkSpeedTest, `Microsoft.News`, OneNote, Sway, OneConnect, Print3D, PowerAutomate, Skype, Todos, DevHome, Alarms, FeedbackHub, Maps, SoundRecorder, XboxApp, ZuneVideo, MicrosoftFamily, QuickAssist, Teams old+new, and 3rd-party: ACGMediaPlayer, Actipro, AdobePhotoshopExpress, Amazon, PrimeVideo, Asphalt8, AutodeskSketchBook, CaesarsSlots, CookingFever, CyberLink, DisneyMagicKingdoms, **Disney.37853FC22B2CE**, Drawboard, Duolingo, EclipseManager, **FACEBOOK.FACEBOOK**, FarmVille2, Flipboard, HiddenCity, HULU, iHeartRadio, **Facebook.Instagram**, BubbleWitch3, CandyCrushSaga/Soda, LinkedIn, MarchofEmpires, **4DF9E0F8.Netflix**, NYT Crossword, OneCalendar, Pandora, Phototastic, PicsArt, Polarr, RoyalRevolt, Sidia, SlingTV, **SpotifyAB.SpotifyMusic**, **BytedancePte.Ltd.TikTok**, TuneIn, WinZip. **optional**: BingSearch, GamingApp, M365Companions (`Microsoft.M365Companions`), MSPaint, OneDrive (winget `Microsoft.OneDrive`), OutlookForWindows, Paint, People, RemoteDesktop, ScreenSketch, StartExperiencesApp, Whiteboard, Windows.Photos, Calculator, Camera, windowscommunicationsapps, Notepad, WebExperience, WidgetsPlatformRuntime, XboxGameOverlay/GamingOverlay, YourPhone, ZuneMusic, `MicrosoftWindows.CrossDevice`, OEM apps (HP `AD2F1837.*` set, Lenovo `E046963F.LenovoCompanion`/`LenovoCompanyLimited.LenovoVantageService`, Dell `DellInc.*`).

### 4.3 Sycnex/Debloat-Windows-10 (raw.githubusercontent.com, master, fetched 2026-10-07)
`scripts/remove-default-apps.ps1` — legacy Win10-focused list (useful only as historical package IDs): Microsoft.3DBuilder, Appconnector, BingFinance/News/Sports/Weather, Getstarted, MicrosoftOfficeHub, Solitaire, OneNote, People, SkypeApp, WindowsAlarms, WindowsCamera, WindowsMaps, WindowsPhone, WindowsSoundRecorder, XboxApp, ZuneMusic, ZuneVideo, windowscommunicationsapps, MinecraftUWP, MicrosoftPowerBIForWindows, NetworkSpeedTest, CommsPhone, ConnectivityStore, Messaging, Office.Sway, OneConnect, WindowsFeedbackHub, BingFoodAndDrink/Travel/HealthAndFitness, WindowsReadingList + 3rd-party (9E2F88E3.Twitter, PandoraMediaInc.29680B314EFC2, Flipboard, Shazam, king.com.CandyCrushSaga/SodaSaga/`king.com.*`, iHeartRadio, Netflix, Wunderlist, Drawboard, PicsArt, FarmVille2, TuneIn, Asphalt8, CyberLink, Facebook.Facebook, RoyalRevolt2, CaesarsSlots, MarchofEmpires, Keeper, Phototastic, XING, AutodeskSketchBook, Duolingo, EclipseManager, ActiproSoftwareLLC.562882FEEB491). Syntax: `Get-AppxPackage -Name $app -AllUsers | Remove-AppxPackage -AllUsers` + `Get-AppXProvisionedPackage -Online | Where-Object DisplayName -EQ $app | Remove-AppxProvisionedPackage -Online`; commented-out "cannot be removed" list: Microsoft.BioEnrollment, Microsoft.MicrosoftEdge, Microsoft.Windows.Cortana, Microsoft.WindowsFeedback, Microsoft.XboxGameCallableUI, Microsoft.XboxIdentityProvider, Windows.ContactSupport. Ends with `HKLM:\SOFTWARE\Policies\Microsoft\Windows\Cloud Content → DisableWindowsConsumerFeatures=1`.

### 4.4 winutil ISO script list
See §4.1 last bullet (19 packages, provisioned+installed, plus ContentDeliveryManager and Windows Chat ChatIcon=3).

---

## 5. THE ULTRAOS DEBLOAT CATALOG

Legend: **Family/Name** = exact `!appx name` pattern (family) or `Get-AppxPackage` name; **Store** = Microsoft Store product ID (reinstall URL `ms-windows-store://pdp/?productid=<ID>`; `winget install --id <ID> --source msstore`); **Preset** = S (Safe), B (Balanced), X (Extreme), "–" = keep. Presence on 24H2/25H2/26H2 noted where known (per Atlas comments "not in 23H2", MS deprecations).

### 5.1 Bloat / consumer apps (Safe-to-remove tier — Atlas & community agree)

| App (display) | Family/Name pattern | Store ID (reinstall) | Present 26H2? | Preset | Notes |
|---|---|---|---|---|---|
| Clipchamp | `Clipchamp.Clipchamp*` | 9P1J8S7CCWWT | yes (default app) | B | MS default video editor; Store-reinstallable |
| Microsoft 365 / Office Hub | `Microsoft.MicrosoftOfficeHub*` | 9WZDNCRD29V9 | being replaced | B | Store version "Microsoft 365 (Office)" ⚠️ package still OfficeHub family; Win11Debloat marks optional |
| Solitaire Collection | `Microsoft.MicrosoftSolitaireCollection*` | (winutil: none) | yes | B | Store-reinstallable |
| Sticky Notes | `Microsoft.MicrosoftStickyNotes*` | 9NBLGGH4QGHW | yes | B (Atlas) / keep in B if Revi-style usability preferred → X | breaks no dependencies |
| To Do | `Microsoft.Todos*` | 9NBLGGH5R558 | yes | B | |
| Paint 3D | `Microsoft.MSPaint*` | (delisted) | no (removed by MS) | B | pattern won't match on 24H2+ |
| 3D Viewer | `Microsoft.Microsoft3DViewer*` | (delisted) | no | B | ditto |
| Mixed Reality Portal | `Microsoft.MixedReality.Portal*` | (delisted) | no | B | |
| Skype (UWP) | `Microsoft.SkypeApp*` | (delisted; Skype retired ⚠️ UNVERIFIED date) | no | B | |
| OneNote (UWP) | `Microsoft.Office.OneNote*` | (delisted → win32 OneNote) | no | B | |
| Mail and Calendar | `microsoft.windowscommunicationsapps*` | (delisted; replaced by new Outlook) | no (MS removed 24H2) | B | |
| People | `Microsoft.People*` | (delisted) | yes (24H2 still ships ⚠️ varies) | B | |
| Maps | `Microsoft.WindowsMaps*` | (delisted) | yes ⚠️ | B | service shut down by MS (Azerbaijan…) ⚠️ UNVERIFIED |
| Alarms & Clock | `Microsoft.WindowsAlarms*` | 9WZDNCRFJ3PR | yes | B (Atlas removes) / recommend keep→X | Revi-style usability: functional app |
| Camera | `Microsoft.WindowsCamera*` | 9WZDNCRFJBBG | yes | B (Atlas removes) / recommend X | |
| Sound Recorder | `Microsoft.WindowsSoundRecorder*` | 9WZDNCRFHWKN | yes | B | |
| Feedback Hub | `Microsoft.WindowsFeedbackHub*` | 9NBLGGH4R32N | yes | B | |
| Get Help | `Microsoft.GetHelp*` | 9PKDZBMV1H3T | yes | B | Win11Debloat rates **unsafe** (support flows); Atlas removes |
| Tips / Get Started | `Microsoft.Getstarted*` | (delisted — deprecated by MS) | yes (renamed "Get Started") | B | Atlas: "Tips (deprecated)" |
| Dev Home | `Microsoft.Windows.DevHome*` | 9N8MHTPHNGVV | deprecated by MS (2025 ⚠️ exact date unverified) | B | winutil default-removes; MS deprecated Dev Home |
| Power Automate | `Microsoft.PowerAutomateDesktop*` | 9NFTCH6J7FHV | yes (Pro trials) | B | |
| Xbox Console Companion | `Microsoft.XboxApp*` | (deprecated by MS) | no | B | NOT the main Xbox app (`Microsoft.GamingApp`) |
| MicrosoftFamily / Family Safety | `MicrosoftCorporationII.MicrosoftFamily*` | — | yes | B | |
| Cortana | `Microsoft.549981C3F5F10*` AND legacy `Microsoft.549981C3F8F0` | (delisted) | no (app retired in EEA 2024; fully 2025 ⚠️ UNVERIFIED exact) | B | see §8.13 for the two IDs |
| Films & TV / Movies & TV | `Microsoft.ZuneVideo*` | 9WZDNCRFJ3P2 | yes | B | |
| Media Player | `Microsoft.ZuneMusic*` | 9WZDNCRFJ3PT | yes | X | default music player; winutil/Win11Debloat optional |
| Microsoft News (legacy) | `Microsoft.News*` | — | no | B (no-op) | from Win11Debloat |
| Bing Weather | `Microsoft.BingWeather*` | 9WZDNCRFJ3Q2 | yes | B | |
| Bing News | `Microsoft.BingNews*` | 9WZDNCRFHVFW | yes | B | |
| Bing Search (web search app) | `Microsoft.BingSearch*` | 9NZBF4GT040C | yes | B | Atlas + winutil default-remove |
| Microsoft PC Manager | `Microsoft.PCManager*` | ⚠️ UNVERIFIED ID | 25H2+ ships by default ⚠️ | B/X | from Win11Debloat (safe tier) |
| Copilot+ AI Hub | `Microsoft.Windows.AIHub*` | ⚠️ UNVERIFIED ID | Copilot+ PCs | X | from Win11Debloat |
| Ink Handwriting (en-US store pkg) | `Ink.Handwriting.Main.Store.en-US1.0` | — | yes | X | Atlas removes; low risk |
| Journal | `Microsoft.MicrosoftJournal*` | — | no | X | Win11Debloat |
| Messaging / OneConnect / Sway / Print3D / 3DBuilder / PowerBI / NetworkSpeedTest / BingFinance/Sports/etc | see §4.2/§4.3 | (all delisted) | no (Win10-era) | B (no-op patterns) | harmless no-ops on 26H2 |
| Whiteboard | `Microsoft.Whiteboard*` | — | optional | X | Win11Debloat optional |
| Remote Desktop | `Microsoft.RemoteDesktop*` | — | yes | – (keep) | Win11Debloat optional; useful |
| Quick Assist | `MicrosoftCorporationII.QuickAssist*` | 9P7BP5VNWKX5 | yes | X (Atlas keeps; Win11Debloat default-removes; winutil default-removes) | support scenarios |
| Phone Link | `Microsoft.YourPhone*` | 9NMPJ99VJBWV | yes | X (**never via `!appx`** — use Remove-AppxPackage + deprovision, see §8.7) | |
| Cross Device Experience Host | `MicrosoftWindows.CrossDevice*` | 9NTXGKQ8P7N0 | yes | – (keep in B; X only with Phone Link) | removing breaks phone-link Settings pages (winutil warning) |
| Snipping Tool | `Microsoft.ScreenSketch*` | 9MZ95KL8MR0L | yes | X (Atlas: checkbox option) | Win+Shift+S breaks; restore via Store |
| Calculator | `Microsoft.WindowsCalculator*` | 9WZDNCRFHVN5 | yes | – (keep; winutil default-removes — do NOT copy that) | |
| Photos | `Microsoft.Windows.Photos*` | 9WZDNCRFJBH4 | yes | – (keep) | default image viewer; Win11Debloat optional |
| Notepad | `Microsoft.WindowsNotepad*` | 9MSMLRH6LZF3 | yes | – (keep) | |
| Paint | `Microsoft.Paint*` | 9PCFS5B6T72H | yes | – (keep; winutil ISO list removes — avoid) | |
| Windows Terminal | `Microsoft.WindowsTerminal*` | ⚠️ (Store: 9N0DX20HK701 — UNVERIFIED here) | yes | – (KEEP; Win11Debloat "unsafe") | default terminal host since 24H2 |

### 5.2 Teams / Communications

| App | Name pattern | Store ID | Preset | Notes |
|---|---|---|---|---|
| Teams (consumer/chat, legacy) | `MicrosoftTeams*` | — | B | Atlas kills `msteams*.exe` first; sets `HKLM\…\Communications /v ConfigureChatAutoInstall=0` to stop reinstall; not in 23H2+ |
| Teams (new, "free/chat") | `MSTeams*` | XP8BT8DW290MPQ | B | Atlas kills `ms-teams*.exe` first; winutil/Win11Debloat remove; provisioned in 24H2 |
| Microsoft Teams (work, win32) | winget `Microsoft.Teams` (not appx) | — | – | out of scope for appx module |

### 5.3 Outlook (new)

| App | Name pattern | Store ID | Preset | Notes |
|---|---|---|---|---|
| New Outlook for Windows | `Microsoft.OutlookForWindows*` | 9NRX63209R7B | B | MS installs via Windows Update! Removal must ALSO delete `HKLM\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate` (value) or deprovisioning is honored from Mar-2024 CU+ (MS Learn, verified — see §8.5) |
| Microsoft 365 Companions | `Microsoft.M365Companions*` | ⚠️ UNVERIFIED ID | X | from Win11Debloat (optional tier) — newer M365 companion app on 25H2+ |

### 5.4 AI (Copilot / Recall)

| App | Name pattern | ID | Preset | Notes |
|---|---|---|---|---|
| Copilot (app) | `Microsoft.Copilot*` | Store 9NHT9RB2F4HD / winget msstore `XP9CXNGPPJ97XX` | B | **EdgeUpdate-distributed** — pair appx removal with `winget uninstall --id XP9CXNGPPJ97XX` + policy `HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot /v TurnOffWindowsCopilot=1`; see §8.1 |
| Copilot (taskbar/shell pre-app era) | — (shell feature; `Microsoft.Windows.Copilot` ⚠️ UNVERIFIED, no source found) | — | – | control via `TurnOffWindowsCopilot` + `TaskbarMn`/`ShowCopilotButton` |
| Copilot PWA auto-pin | registry `HKCU\…\Explorer\Advanced /v CopilotPWAPin=0` (Atlas config-pins.yml) | — | B | stops Copilot app auto-pinning to taskbar |
| Windows AI Platform / Recall engine | `MicrosoftWindows.Client.CoreAI` | — | X | winutil: EndOfLife key + Remove-AppxPackage; also `Disable-WindowsOptionalFeature -FeatureName Recall -Online [-Remove]`; disable snapshots: `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI /v DisableAIDataAnalysis=1` (CSP `./Device/Vendor/MSFT/Policy/Config/WindowsAI/DisableAIDataAnalysis` — MS Learn verified); service `WSAIFabricSvc` (winutil disables) |
| Recall (optional feature) | `Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -Remove` | — | X | MS Learn manage-recall doc verbatim: users "can use the following PowerShell command" |
| Microsoft 365 Copilot app (renamed → Microsoft Copilot) | unified app = `Microsoft.Copilot` | — | B | MS Learn "Deploy the unified Microsoft Copilot application": "The Microsoft 365 Copilot app is now called Microsoft Copilot"; rollout via EdgeUpdate ≥1.3.253.25, policies "Copilot Unification Allowed" / "Install" (Force Installs) |

### 5.5 Widgets / Web experience

| App | Name pattern | Store ID | Preset | Notes |
|---|---|---|---|---|
| Windows Web Experience Pack (Widgets feed) | `MicrosoftWindows.Client.WebExperience*` | ⚠️ UNVERIFIED | B (disable via policy) / X (remove appx) | Atlas does NOT remove — disables: `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds /v EnableFeeds=0` + `HKLM\SOFTWARE\Policies\Microsoft\Windows\Dsh /v AllowNewsAndInterests=0` (verbatim from Atlas Disable Widgets (default).cmd) |
| Widgets Platform Runtime | `Microsoft.WidgetsPlatformRuntime*` | ⚠️ UNVERIFIED | X | winutil WPFTweaksWidget removes with WebExperience |
| Start Experiences App | `Microsoft.StartExperiencesApp*` | 9PC1H9VN18CM | X | winutil: "Powers the Windows Widgets board" |
| News & Interests taskbar toggle | registry (see above) + `HKCU\…\Explorer\Advanced /v TaskbarDa=0` ⚠️ UNVERIFIED value | — | B | Atlas disable script doesn't set TaskbarDa — uses policies only |

### 5.6 Xbox stack (dependency warnings — winutil appx.json wording verbatim)

| App | Name pattern | Store ID | Preset | Notes |
|---|---|---|---|---|
| Xbox app | `Microsoft.GamingApp*` | 9MV0B5HZVK9Z | X | Game Pass/PC gaming; keep for gamers |
| Xbox Game Bar | `Microsoft.XboxGamingOverlay*` | 9NZKPSTSNW4P | X | also in-game overlay (Win+G) |
| Xbox Game Overlay | `Microsoft.XboxGameOverlay*` | — | X | Win11Debloat optional |
| Xbox Identity Provider | `Microsoft.XboxIdentityProvider*` | 9WZDNCRD1HKW | **NEVER** | winutil: "removing this may break Microsoft account sign-in for non-Xbox games and apps that rely on this authentication pipeline"; Sycnex lists as non-removable; Win11Debloat "unsafe" |
| Xbox TCUI | `Microsoft.Xbox.TCUI*` | — | **NEVER** | winutil: "may break Microsoft account authentication in games and apps that do not otherwise require the Xbox app" |
| Xbox Speech-to-Text Overlay | `Microsoft.XboxSpeechToTextOverlay*` | — | X | Win11Debloat "unsafe", winutil optional |

### 5.7 Sponsored / 3rd-party (come from CloudContent/ContentDeliveryManager "suggested apps" + OEM preinstalls)

| App | Name pattern | Preset | Notes |
|---|---|---|---|
| Disney+ | `Disney.37853FC22B2CE*` | B | Atlas removes explicitly (most common sponsored app) |
| Spotify | `SpotifyAB.SpotifyMusic*` | B | Atlas removes explicitly |
| TikTok | `BytedancePte.Ltd.TikTok*` | B | Win11Debloat |
| Facebook | `FACEBOOK.FACEBOOK*` | B | Win11Debloat/Sycnex |
| Instagram | `Facebook.Instagram*` | B | Win11Debloat |
| Netflix | `4DF9E0F8.Netflix*` | B | Win11Debloat/Sycnex |
| Prime Video | `AmazonVideo.PrimeVideo*` | B | Win11Debloat |
| Twitter | `9E2F88E3.Twitter*` | B (no-op) | Sycnex (X/Twitter app delisted ⚠️) |
| Candy Crush etc. | `king.com.*`, `king.com.CandyCrushSaga*`, `king.com.CandyCrushSodaSaga*` | B | Sycnex/Win11Debloat |
| (long tail) | see §4.2/§4.3 full lists (Asphalt8, Duolingo, PicsArt, FarmVille2, Phototastic, LinkedIn, Keeper, WinZipUniversal, iHeartRadio, TuneInRadio, SlingTV, Hulu, CookingFever, HiddenCity, MarchofEmpires, BubbleWitch3, DisneyMagicKingdoms, Polarr, EclipseManager, DrawboardPDF, AutodeskSketchBook, CaesarsSlots, RoyalRevolt, OneCalendar, ACGMediaPlayer, Sidia.LiveWallpaper, CyberLink, AdobePhotoshopExpress, Amazon, Flipboard, Shazam, Wunderlist, XING, NYTCrossword, PandoraMediaInc…) | B wildcard sweep | prevention beats removal: CloudContent policy + ContentDeliveryManager zeros stop them ever installing |

**Root cause (where they come from)**: ContentDeliveryManager `SilentInstalledAppsEnabled`/`PreInstalledAppsEnabled`/`OemPreInstalledAppsEnabled` + `SubscribedContent-*` (suggested content) + `HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent\DisableWindowsConsumerFeatures` for enterprise; `HKCU\…\ContentDeliveryManager` values for per-user (full Atlas recipe in §8.11). On 25H2/26H2, several (Disney+, Spotify) also ship **provisioned in the image** → remove provisioned package AND deprovision.

### 5.8 Frameworks / system packages — NEVER REMOVE (dependency chain)

- `Microsoft.WindowsStore` (+ `Microsoft.WindowsStore_8wekyb3d8bbwe`) — needed to reinstall ANYTHING; removing breaks undo. (Store repair: `Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.WindowsStore_8wekyb3d8bbwe`)
- `Microsoft.DesktopAppInstaller` — **provides winget**; UltraOS rollback uses winget (winutil undo does too).
- `Microsoft.VCLibs.140`, `Microsoft.VCLibs.140.UWPDesktop` — C++ runtime for dozens of store apps.
- `Microsoft.NET.Native.Framework.*`, `Microsoft.NET.Native.Runtime.*` — .NET Native (many inbox apps).
- `Microsoft.UI.Xaml.*` (WinUI 2), `Microsoft.WindowsAppRuntime.1_*` (Windows App SDK) — modern app UI frameworks.
- `Microsoft.Services.Store.Engagement` — store feedback SDK.
- `Microsoft.Web.WebView2` (Win32, not appx) — runtime for: new Outlook, Widgets/WebExperience, Copilot app, Photos (edit), Xbox sign-in, Roblox, PowerToys add-ons, and many 3rd-party apps (ShadowWhisperer README verified list: Barracuda Firewall Admin, Eclipse, ImageGlass 9, Quicken, Rex Atmos, Roblox, Safing Portmaster, Windows Mail, Xbox App, Tauri apps). **Do not remove; Extreme preset must warn.**
- `MicrosoftWindows.Client.CBS` — system component (Atlas clears its cache; never removes).
- `Microsoft.Windows.StartMenuExperienceHost`, `Microsoft.Windows.ShellExperienceHost`, `Microsoft.Windows.Search`, `Microsoft.Windows.FileExplorer` (24H2+), `Microsoft.Windows.InputApp`, `Microsoft.CredDialogHost`, `Microsoft.Windows.PrintDialog`, `Microsoft.Windows.SecHealthUI` (Defender UI), `Microsoft.BioEnrollment`, `Windows.ContactSupport`, `Microsoft.XboxGameCallableUI` — OS-critical / non-removable via Remove-AppxPackage (Sycnex comments + common knowledge; individual entries ⚠️ not each independently verified).
- `Microsoft.OneDriveSync` ⚠️ UNVERIFIED — reported as the OneDrive sync-engine appx on newer builds; UltraOS should detect-and-remove only if present (see §8.6).

### 5.9 Recommended preset mapping (UltraOS decision proposal)

**Safe (keep everything, only block junk + deprecated no-ops):**
- No appx removals that touch usable apps. Remove only packages Microsoft itself deprecated/retired (all effectively absent on 24H2+): `Microsoft.549981C3F5F10*` (Cortana), `MicrosoftTeams*` (legacy), `Microsoft.SkypeApp*`, `Microsoft.Office.OneNote*`, `Microsoft.MSPaint*`, `Microsoft.Microsoft3DViewer*`, `Microsoft.MixedReality.Portal*`, `microsoft.windowscommunicationsapps*`, `Microsoft.Getstarted*` (borderline — it exists on 24H2 as "Get Started"; Atlas removes → include), `Microsoft.XboxApp*` (deprecated companion).
- Disable sponsored/3rd-party installs via CloudContent + ContentDeliveryManager (registry-only, fully reversible) — **no appx removal needed because they're not yet installed**.
- Disable (not remove): Copilot policy, Recall snapshots policy, Widgets policy, Teams auto-install (`ConfigureChatAutoInstall=0`).

**Balanced (default — ≈ Atlas defaults + 26H2 additions, minus usability losses):**
- Everything in Safe, plus: `MSTeams*`, `Microsoft.Copilot*` (+ winget uninstall), `Clipchamp.Clipchamp*`, `Disney.37853FC22B2CE*`, `SpotifyAB.SpotifyMusic*` (+ TikTok/Facebook/Instagram/Netflix/PrimeVideo/king.com.* sweep), `Microsoft.BingWeather*`, `Microsoft.BingNews*`, `Microsoft.BingSearch*`, `Microsoft.OutlookForWindows*` (+ UScheduler_Oobe\OutlookUpdate deletion), `Microsoft.GetHelp*`, `Microsoft.WindowsFeedbackHub*`, `Microsoft.MicrosoftOfficeHub*`, `Microsoft.Windows.DevHome*`, `MicrosoftCorporationII.MicrosoftFamily*`, `Microsoft.PowerAutomateDesktop*`, `Microsoft.Todos*`, `Microsoft.MicrosoftStickyNotes*` (toggle, default ON to match Atlas), `Microsoft.WindowsSoundRecorder*`, `Microsoft.WindowsMaps*`, `Microsoft.People*`, `Microsoft.ZuneVideo*`, `Microsoft.MicrosoftSolitaireCollection*`, `Microsoft.WindowsAlarms*` (toggle, default ON per Atlas; UltraOS may default OFF to keep Clock), `Microsoft.WindowsCamera*` (toggle), `Microsoft.News*`, `Microsoft.PCManager*`, `Microsoft.M365Companions*`.
- Deprovision every removed family (Atlas diff trick §2.4) + `Microsoft.YourPhone` special handling only if user opts in.

**Extreme (add aggressive stuff, with warnings + Store IDs in report for undo):**
- `Microsoft.ScreenSketch*` (Snipping Tool — warn Win+Shift+S), `Microsoft.YourPhone*` + `MicrosoftWindows.CrossDevice*` (Phone Link ecosystem), Widgets appx trio (`MicrosoftWindows.Client.WebExperience*`, `Microsoft.WidgetsPlatformRuntime*`, `Microsoft.StartExperiencesApp*`), `MicrosoftCorporationII.QuickAssist*`, `Microsoft.ZuneMusic*` (Media Player), `Microsoft.Windows.AIHub*`, `MicrosoftWindows.Client.CoreAI` + `Disable-WindowsOptionalFeature -FeatureName Recall -Remove`, `Ink.Handwriting.Main.Store.en-US1.0`, `Microsoft.Whiteboard*`, Xbox stack (`Microsoft.GamingApp*`, `Microsoft.XboxGamingOverlay*`, `Microsoft.XboxGameOverlay*`, `Microsoft.XboxSpeechToTextOverlay*` — NEVER IdentityProvider/TCUI), `Microsoft.WindowsCalculator*`/`Microsoft.WindowsNotepad*`/`Microsoft.Paint*`/`Microsoft.Windows.Photos*`/`Microsoft.WindowsTerminal*` as individually-toggleable opt-ins with red warnings, Microsoft Edge removal (§8.12, gated behind UCPD-disabled check), OneDrive full strip (§8.6).

---

## 6. Atlas ↔ UltraOS mapping notes (proven behaviors to copy)

1. **Kill before remove**: `!taskKill msteams*` / `ms-teams*` before Teams removal — generalize: kill app processes before `!appx` for locked apps.
2. **Never use `!appx` on YourPhone** — Atlas comment verbatim: "Removing using AME Wizard causes issues with Cross Device Experience Host installing". Use `Remove-AppxPackage` + `Remove-AppxProvisionedPackage` PowerShell route.
3. **Always deprovision after removal** (diff trick) — or feature updates bring apps back.
4. **Clear caches after mass removal**: `!appx clearCache` on `*MicrosoftWindows.Client.CBS*`, `*Microsoft.Windows.Search*` (+ `*StartMenuExperienceHost*` per AME docs; Atlas also clears `*Microsoft.Windows.SecHealthUI*`).
5. Atlas's `Ink.Handwriting.Main.Store.en-US1.0` removal shows **exact-version package names** are also valid `!appx` targets.
6. Atlas sets `ConfigureChatAutoInstall=0` (HKLM Communications) to stop Teams/chat reinstall — include with Teams removal.
7. Atlas `appx.yml` has `onUpgrade: false` — removals run only on fresh playbook runs; on upgrade, revert.yml handles old-change cleanup. UltraOS should mimic (idempotent actions + upgrade-safe).

---

## 7. Special cases — current 2026 state

### 8.1 Copilot (app + taskbar)
- **Facts (verified)**: Copilot app = `Microsoft.Copilot` family (Atlas `Microsoft.Copilot*`; winutil StoreId `9NHT9RB2F4HD`; Win11Debloat winget msstore ID `XP9CXNGPPJ97XX`). winutil additionally runs `winget uninstall -e --name "Copilot" --silent --force` and removes `Microsoft.MicrosoftOfficeHub` in the same AI tweak. Atlas's toolbox Disable Copilot script (verbatim): `powershell -NoP -NonI "Get-AppxPackage -AllUsers Microsoft.Copilot* | Remove-AppxPackage -AllUsers"` + `ShowCopilotButton=0` (HKCU Explorer\Advanced) + `TurnOffWindowsCopilot=1` (HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot). Re-enable script installs Copilot app when taskbar Copilot unavailable (`IsCopilotAvailable` check) and notes "Copilot on the taskbar isn't available, the app will be installed instead."
- MS Learn "Deploy the unified Microsoft Copilot application" (verified 2026-10-07): unified app rollout (from ~Sept 2025) via **EdgeUpdate** ("Ensure EdgeUpdate is on version 1.3.253.25 or higher", policies "Copilot Unification Allowed", "Install: Force Installs"); "The Microsoft 365 Copilot app is now called Microsoft Copilot."
- **Implication**: on 25H2/26H2 the Copilot app can be (re)installed outside the Store by EdgeUpdate → UltraOS Balanced should ALSO set EdgeUpdate policy to block it: `HKLM\SOFTWARE\Policies\Microsoft\EdgeUpdate` ⚠️ exact value name for blocking Copilot install is UNVERIFIED; safe approach: remove appx + `winget uninstall --id XP9CXNGPPJ97XX` + `TurnOffWindowsCopilot=1` + `CopilotPWAPin=0`.
- `Microsoft.Windows.Copilot` as a package name: **⚠️ UNVERIFIED — no source in this environment lists it**; treat as myth until a `Get-AppxPackage` dump proves otherwise.
- April 2026 news (search snippets, gbhackers/cyberpress): "Microsoft has introduced a new enterprise policy to silently uninstall the Microsoft Copilot app from managed Windows 11 devices" — **⚠️ UNVERIFIED** (article body unreachable due to search rate limits; policy name unknown). Flag for follow-up.

### 8.2 Recall
- Verified (MS Learn, manage-recall): policy CSP `./Device/Vendor/MSFT/Policy/Config/WindowsAI/DisableAIDataAnalysis` ("Turn off saving snapshots for use with Recall"; disabling deletes previously saved snapshots; "Removing Recall requires a device restart"); `Disable-WindowsOptionalFeature -Online -FeatureName "Recall" -Remove` removes the bits; `AllowRecallEnablement` policy gates re-enabling (Edu/Enterprise emphasis).
- winutil adds: remove `MicrosoftWindows.Client.CoreAI` appx (EndOfLife key trick), disable `WSAIFabricSvc` service, `Disable-WindowsOptionalFeature -FeatureName Recall -Online -NoRestart`, hide Settings `aicomponents` page, `HKLM\SOFTWARE\Policies\WindowsNotepad /v DisableAIFeatures=1` (Notepad AI).
- Atlas: Recall handled by AtlasDesktop "Disable Recall Support (default).cmd/.reg" (privacy/disable-recall-snap.yml runs it `/silent`) — policy-based, not appx.

### 8.3 Widgets / WebExperience
- Atlas: **disable, don't remove** — policies `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds /v EnableFeeds=0` + `HKLM\SOFTWARE\Policies\Microsoft\Windows\Dsh /v AllowNewsAndInterests=0`, then restart Explorer (verbatim from Disable Widgets (default).cmd).
- winutil: **remove** `Microsoft.WidgetsPlatformRuntime` + `MicrosoftWindows.Client.WebExperience` (WebExperience = "Windows Web Experience Pack" — the Widgets host).
- 25H2+ note ⚠️ UNVERIFIED: WebExperience reportedly superseded by `Microsoft.StartExperiencesApp` ("Start Experiences App"/"Widgets Experience" in winutil + Win11Debloat catalogs — both verified sources list it, presence on 26H2 builds ⚠️).
- Balanced = Atlas policy method; Extreme = policy + appx removal of all three.

### 8.4 Teams
- `MicrosoftTeams` (consumer/chat, pre-23H2) vs `MSTeams` (new Teams, provisioned in 24H2+). Atlas kills `msteams*`/`ms-teams*` processes, removes both families, blocks chat auto-install (`ConfigureChatAutoInstall=0`). Reinstall: Store `XP8BT8DW290MPQ` (winutil) or `winget install Microsoft.Teams.Free` ⚠️ ID unverified.

### 8.5 Outlook (new)
- Verified MS Learn (control-install): removal = `Remove-AppxProvisionedPackage -AllUsers -Online -PackageName (Get-AppxPackage Microsoft.OutlookForWindows).PackageFullName` + delete `HKLM\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate` (Windows Orchestrator respects deprovisioning from the March 2024 non-security preview CU of 23H2 onward). Windows 10 prevention: `HKLM\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe` → `BlockedOobeUpdaters` REG_SZ = `["MS_Outlook"]`. It ships via updates (Win10: Jan 28 2025 optional / Feb 11 2025 security).
- Win11Debloat rates it **optional** (not default); Atlas removes it; winutil lists StoreId `9NRX63209R7B`. UltraOS Balanced: remove + orchestrator cleanup.

### 8.6 OneDrive
- **Atlas method (ONED.cmd, verbatim steps in §3.3)**: `OneDriveSetup.exe /uninstall` (System32 + SysWOW64 paths) + per-hive registry scrub (sidebar CLSID `{018D5C66-4533-4307-9B53-224DE2ED1FE6}`, Run keys, App Paths, Uninstall, BannerStore, AutoplayHandlers) + folder cleanup + `SyncRootManager` purge + scheduled task deletion (`OneDrive Reporting Task`, `OneDrive Standalone Update Task`).
- **winutil method**: deny-ACL guard on the OneDrive folder → `OneDriveSetup.exe /uninstall` → delete leftovers → unset `OneDrive` user env var → disable `OneSyncSvc`. Undo: `winget install Microsoft.Onedrive --source winget` + OneSyncSvc back to Automatic.
- **Win11Debloat**: winget `Microsoft.OneDrive`.
- **Block reinstall (community)**: `HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive /v DisableFileSyncNGSC /t REG_DWORD /d 1` ⚠️ UNVERIFIED in this environment (widely cited; blocks consumer sync — also blocks app functionality if later reinstalled — use in Extreme only). Atlas's components.yml comment claims component-level stripping but the current repo has no OneDrive CAB (stale comment, verified §3.2).
- `Microsoft.OneDriveSync` appx ⚠️ UNVERIFIED — detect with `Get-AppxPackage *OneDrive*` and handle if present.

### 8.7 Phone Link
- `Microsoft.YourPhone` (Store 9NMPJ99VJBWV). **Special handling required** (Atlas): plain PowerShell removal because `!appx`/AME removal breaks Cross Device Experience Host reinstallation. Atlas's AtlasDesktop script (verbatim): `powershell -NoP -NonI "Get-AppxPackage -AllUsers Microsoft.YourPhone* | Remove-AppxPackage -AllUsers"`. Related: `MicrosoftWindows.CrossDevice` (9NTXGKQ8P7N0) — winutil warns removal "may disable cross-device features such as phone screen mirroring, file transfer, and mobile hotspot handoff integrated into Windows Settings". Keep both in Balanced; remove both only in Extreme.

### 8.8 Dev Home
- `Microsoft.Windows.DevHome` — deprecated by Microsoft (announcement date ⚠️ UNVERIFIED here; widely reported 2025). Atlas removes; winutil default-removes (StoreId 9N8MHTPHNGVV); Win11Debloat safe-tier. Effectively a no-op on newest builds if MS already stopped shipping.

### 8.9 Snipping Tool
- `Microsoft.ScreenSketch*` — Atlas: checkbox option `remove-snipping-tool` (also disables the screen-capture hotkey via `tweaks\qol\disable-screen-capture-hotkey.yml` with `option: remove-snipping-tool`). Store reinstall: 9MZ95KL8MR0L. Keep in Balanced; Extreme opt-in.

### 8.10 Tips / Get Started / Get Help / Feedback Hub
- `Microsoft.Getstarted` = Tips ("deprecated" per Atlas; renamed "Get Started" and still present 24H2+ ⚠️ behavior varies). `Microsoft.GetHelp` — Atlas removes; Win11Debloat rates **unsafe** (needed for support flows; winutil default-removes anyway). `Microsoft.WindowsFeedbackHub` — universal agreement: remove (Store 9NBLGGH4R32N).

### 8.11 Sponsored apps provenance (CloudContent)
- Atlas `tweaks/debloat/config-content-delivery.yml` (verbatim values, all REG_DWORD 0 under `HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager`): `ContentDeliveryAllowed`, `FeatureManagementEnabled`, `SubscribedContentEnabled`, `RemediationRequired`, `OemPreInstalledAppsEnabled`, `PreInstalledAppsEnabled`, `PreInstalledAppsEverEnabled`, `SilentInstalledAppsEnabled`, `SubscribedContent-310093Enabled` (welcome experience), `SubscribedContent-338393Enabled`, `SubscribedContent-353694Enabled`, `SubscribedContent-353696Enabled` (Settings suggestions), `SystemPaneSuggestionsEnabled`, `SubscribedContent-338387Enabled` (lock screen fun facts), `RotatingLockScreenOverlayEnabled`, `SubscribedContent-338388Enabled` (Start suggestions), `SubscribedContent-338389Enabled` (tips/tricks notifications), `SoftLandingEnabled`; plus `HKCU\Software\Microsoft\Windows\CurrentVersion\SystemSettings\AccountNotifications /v EnableAccountNotifications=0`. Atlas deliberately does NOT delete `Subscriptions`/`SuggestedApps` keys ("would likely break re-enabling content"); winutil's ISO script DOES delete them. Enterprise hard block: `HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent /v DisableWindowsConsumerFeatures=1` (winutil ConsumerFeatures + Sycnex; disables Consumer Side Slot/SuggestedApps install path).

### 8.12 Microsoft Edge removal state-of-the-art (26H2) — facts vs community claims
**Verified facts:**
- Method A (winutil `WPFTweaksRemoveEdge`): create stub `New-Item "$Env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\MicrosoftEdge.exe"` → run `$Env:ProgramFiles (x86)\Microsoft\Edge\Application\*\Installer\setup.exe --uninstall --system-level --force-uninstall [--delete-profile]`.
- Method B (Win11Debloat `Invoke-ForceRemoveEdge`): set `HKLM\SOFTWARE\Microsoft\EdgeUpdateDev /v AllowUninstall` (empty REG_SZ, via 32-bit registry view) + same stub → read `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge` `UninstallString` and append ` --force-uninstall` → run → delete shortcuts (Start Menu, Quick Launch, taskbar tombstones, Desktop) + Run keys (`MicrosoftEdgeAutoLaunch_A9F6DCE4ABADF4F51CF45CD7129E3C6C`, `Microsoft Edge Update`).
- Method C (Atlas): delegates to ShadowWhisperer/Remove-MS-Edge `Remove-Edge.exe` release binary; wrapper v1.9.5 also offers `-InstallEdge` (official MSI) and `-InstallWebView` (Evergreen `/silent /install`).
- Reinstall: `winget install Microsoft.Edge --source winget` (winutil undo) or Edge MSI (Atlas RemoveEdge.ps1).
- Risks (ShadowWhisperer README, verbatim): "- Removing Edge may cause update failure loop. Install Edge, install all Windows updates, then remove Edge." + WebView2-dependent apps list (§5.8) + IE-compat reg restore: `HKLM\SOFTWARE\Microsoft\Internet Explorer\EdgeIntegration /v Supported /d 1`.
- Atlas blocks Edge AppX return via Deprovisioned keys (`Microsoft.MicrosoftEdge_8wekyb3d8bbwe`, `Microsoft.MicrosoftEdge.Stable_8wekyb3d8bbwe`) and removes legacy Edge AppX family `Microsoft.MicrosoftEdge_8wekyb3d8bbwe` (note: "AppX Edge is removed from the latest builds of Windows" — Atlas comment).
- **UCPD**: Atlas REQUIRES `UCPDDisabled` before playbook install (playbook.conf Requirements), disables `UCPD` service (startup=4) + `UCPD velocity` task, and its file-association script renames PowerShell to bypass UCPD (hitco.at method).
**Community claims (⚠️ not verified from primary sources):** UCPD re-enables itself after cumulative updates; UCPD blocks `--force-uninstall`; Windows updates reinstall Edge from `Microsoft Edge Update` tasks unless EdgeUpdate is gutted; removing Edge breaks Windows Update on some builds; OOBE requires a browser (24H2+ "Edge-free OOBE" only in EEA). Present these as community claims only.

### 8.13 Cortana package-name confusion (verified resolution)
Two real package identities exist: `Microsoft.549981C3F8F0` (Cortana, Win10-era original — cited in the UltraOS mission brief) and `Microsoft.549981C3F5F10` (Cortana, the Store app from Win10 2004 onward — verified via Atlas appx.yml, Win11Debloat Apps.json, and a third-party how-to showing `Get-AppxPackage -allusers Microsoft.549981C3F5F10 | Remove-AppxPackage`). **Use `Microsoft.549981C3F5F10*` (26H2-relevant), keep `Microsoft.549981C3F8F0*` as harmless legacy pattern.**

---

## 9. Reinstall / undo guide (UltraOS rollback design)

### 9.1 Universal commands
```powershell
# Re-register from local files (works if WindowsApps folder still staged; winutil Install-WinUtilAPPX approach, verified)
Add-AppxPackage -Register "C:\Program Files\WindowsApps\<PackageFullName>\AppxManifest.xml" -DisableDevelopmentMode
# Register by family (no path needed — Windows 10 1709+ / 11)
Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.ScreenSketch_8wekyb3d8bbwe
# Bulk repair after mass removal (classic)
Get-AppxPackage -AllUsers | ForEach-Object {Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction SilentlyContinue}
# Store repair
Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.WindowsStore_8wekyb3d8bbwe
wsreset.exe   # clears Store cache (i.e. what !appx clearCache does for Store/CBS/Search)
```

### 9.2 Store / winget reinstall (IDs verified from winutil appx.json + Win11Debloat Apps.json)
```powershell
winget install --id 9NBLGGH4R32N --source msstore   # Feedback Hub
winget install --id 9PKDZBMV1H3T --source msstore   # Get Help
winget install --id 9NRX63209R7B --source msstore   # Outlook for Windows (new)
winget install --id XP8BT8DW290MPQ --source msstore # Microsoft Teams
winget install --id 9P1J8S7CCWWT --source msstore   # Clipchamp
winget install --id 9WZDNCRD29V9 --source msstore   # Microsoft 365 / Office Hub
winget install --id 9WZDNCRFJ3PT --source msstore   # Media Player (ZuneMusic)
winget install --id 9NZBF4GT040C --source msstore   # Bing Search
winget install --id 9P7BP5VNWKX5 --source msstore   # Quick Assist
winget install --id 9N8MHTPHNGVV --source msstore   # Dev Home
winget install --id 9NTXGKQ8P7N0 --source msstore   # Cross Device (Mobile Devices)
winget install --id 9NBLGGH5R558 --source msstore   # To Do
winget install --id 9NFTCH6J7FHV --source msstore   # Power Automate
winget install --id 9NMPJ99VJBWV --source msstore   # Phone Link
winget install --id 9NBLGGH4QGHW --source msstore   # Sticky Notes
winget install --id 9WZDNCRFHWKN --source msstore   # Sound Recorder
winget install --id 9WZDNCRFJ3PR --source msstore   # Clock (Alarms)
winget install --id 9PCFS5B6T72H --source msstore   # Paint
winget install --id 9MSMLRH6LZF3 --source msstore   # Notepad
winget install --id 9MZ95KL8MR0L --source msstore   # Snipping Tool
winget install --id 9NHT9RB2F4HD --source msstore   # Copilot
winget install --id 9WZDNCRFHVN5 --source msstore   # Calculator
winget install --id 9WZDNCRFJBBG --source msstore   # Camera
winget install --id 9WZDNCRFJBH4 --source msstore   # Photos
winget install --id 9WZDNCRFHVFW --source msstore   # News (Bing)
winget install --id 9WZDNCRFJ3Q2 --source msstore   # Weather (Bing)
winget install --id 9MV0B5HZVK9Z --source msstore   # Xbox App
winget install --id 9NZKPSTSNW4P --source msstore   # Xbox Game Bar
winget install --id 9WZDNCRD1HKW --source msstore   # Xbox Identity Provider
winget install --id 9PC1H9VN18CM --source msstore   # Start Experiences App (Widgets)
winget install --id 9WZDNCRFJ3P2 --source msstore   # Movies & TV (ZuneVideo)
winget install Microsoft.Edge    --source winget    # Edge (undo)
winget install Microsoft.Onedrive --source winget   # OneDrive (undo)
# Direct Store deep link: start ms-windows-store://pdp/?productid=9NBLGGH4R32N
```

### 9.3 Undo of provisioning blocks (MUST be part of UltraOS rollback)
1. Delete the per-app key `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\<PackageFamilyName>` (this is what re-permits provisioning on next update; MS doc §2.2).
2. Delete `EndOfLife\<SID>\<PackageFullName>` keys (CoreAI-style blocks).
3. Restore ContentDeliveryManager values (UltraOS must snapshot originals — Atlas sets them to 0 without backups; winutil uses `OriginalValue` bookkeeping in tweaks.json — copy winutil's approach).
4. Restore scheduled tasks (Atlas disables `UCPD velocity`; winutil disables WPBT etc.), services (`OneSyncSvc`, `WSAIFabricSvc`), and policies (`TurnOffWindowsCopilot`, `EnableFeeds`, `AllowNewsAndInterests`, `DisableWindowsConsumerFeatures`).
5. DISM provisioning restore (offline/enterprise path, needs the package files):
```powershell
Add-AppxProvisionedPackage -Online -PackagePath .\app.appxbundle -LicensePath .\license.xml
# community package dump source: https://store.rg-adguard.net ⚠️ UNVERIFIED policy-wise (not an official MS source)
```
6. Windows "Get-AppxPackage -AllUsers | Add-AppxPackage -Register" bulk repair is the last-resort generic undo (§9.1) — but it only works for packages whose files remain staged; fully removed ones need Store/winget.

### 9.4 Reversibility tiers (for the UltraOS post-run report)
- Tier 1 (Store-reinstallable, one command): almost everything in §5.1-5.7 with a Store ID.
- Tier 2 (reinstallable via win32 installers): Edge (winget/MSI), OneDrive (winget/OneDriveSetup), WebView2 (Evergreen installer).
- Tier 3 (delisted — NOT Store-reinstallable): Mail & Calendar, Maps, People, Mixed Reality Portal, Skype UWP, OneNote UWP, Cortana, Tips/Getstarted, Paint 3D/3D Viewer, legacy XboxApp — document as "gone for good unless provisioned files remain" → `Add-AppxPackage -Register` from staged copy only.
- Tier 4 (OS-internal, effectively irreversible): Recall optional-feature removal (`-Remove` deletes payload — Windows may re-acquire via Windows Update ⚠️ UNVERIFIED), component-store removals (Atlas sxsc packages — not used by UltraOS debloat module).

---

## 10. Sources (all accessed 2026-10-07)

Local repos (cloned/read this session):
- Atlas: /home/z/my-project/repos/atlas (appx.yml, components.yml, ONED.cmd, RemoveEdge.ps1, playbook.conf, config-content-delivery.yml, disable-scheduled-tasks.yml, services.yml, sxsc/*.yaml, AtlasDesktop Copilot/Widgets/PhoneLink scripts) — upstream github.com/Atlas-OS/Atlas
- winutil: /home/z/my-project/repos/winutil @ 9c87c02 (config/appx.json, preset.json, tweaks.json, functions/private/{Remove-WinUtilAPPX,Remove-WinUtilProvisionedAPPX,Install-WinUtilAPPX,Invoke-WinUtilISOScript}.ps1) — upstream github.com/ChrisTitusTech/winutil
- AME Wizard engine: /home/z/my-project/repos/trusted-uninstaller-cli (TrustedUninstaller.Shared/Actions/AppxAction.cs) — upstream github.com/Ameliorated-LLC/trusted-uninstaller-cli
- ame-assassin: github.com/Ameliorated-LLC/ame-assassin (branch `public`, Program.cs read via raw.githubusercontent)
- Win11Debloat: /tmp/Win11Debloat (Config/Apps.json, Scripts/AppRemoval/{Remove-SelectedApps.ps1,Invoke-ForceRemoveEdge.ps1}) — upstream github.com/Raphire/Win11Debloat
- Sycnex/Debloat-Windows-10: raw.githubusercontent.com/Sycnex/Debloat-Windows-10/master/scripts/remove-default-apps.ps1

Web (fetched 2026-10-07):
- https://docs.amelabs.net/developers/actions/Appx.html — `!appx` action reference
- https://learn.microsoft.com/en-us/windows/application-management/remove-provisioned-apps-during-update — Deprovisioned registry mechanism (redirects from apps-in-windows-10, whose package table is retired)
- https://learn.microsoft.com/en-us/microsoft-365-apps/outlook/get-started/control-install — new Outlook removal + UScheduler_Oobe/OutlookUpdate + BlockedOobeUpdaters
- https://learn.microsoft.com/en-us/windows/client-management/manage-recall — Recall: DisableAIDataAnalysis CSP, AllowRecallEnablement, `Disable-WindowsOptionalFeature -FeatureName "Recall" -Remove`
- https://learn.microsoft.com/en-us/windows/client-management/deploy-unified-copilot-app — unified Microsoft Copilot app, EdgeUpdate distribution, Copilot policies
- https://hitco.at/blog/windows-userchoice-protection-driver-ucpd/ — UCPD deep-dive (referenced by Atlas FILEASSOC.cmd)
- https://raw.githubusercontent.com/ShadowWhisperer/Remove-MS-Edge/main/README.md — Edge removal risks, WebView2-dependent apps list, batch variants
- ⚠️ Unreachable this session (search rate limits): gbhackers/cyberpress Apr-2026 "enterprise policy to silently uninstall Copilot app" articles (noted as unverified), Dev Home deprecation announcement (devblogs URL 404).
