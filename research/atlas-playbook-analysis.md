# Dossier T1-a — AtlasOS Playbook Deep-Dive (authoritative analysis for UltraOS build agents)

**Agent:** T1-a (Atlas playbook authority) · **Date:** 2026-10-07 · **Status:** COMPLETE
**Primary source:** local clone `/home/z/my-project/repos/atlas` (github.com/Atlas-OS/Atlas), HEAD `1ed9630616b29f0c7974e8bd76a94fc06f60388c`, committed 2026-05-04 "fix: correct pull request labeler paths". Playbook version **v0.5.0** (`<Title>Atlas v0.5.0</Title>`, `<Version>0.5.0</Version>`), `<UpgradableFrom>0.4.1</UpgradableFrom>`. License: GPL-3.0 (repo `LICENSE`).
**Corroborating engine source (already cloned):** `/home/z/my-project/repos/trusted-uninstaller-cli` (github.com/Ameliorated-LLC/trusted-uninstaller-cli, MIT) — the open-source backend of AME Wizard; I used it to verify every YAML key semantics below.
**Web docs skimmed (accessed 2026-10-07):** docs.atlasos.net (installation, atlas-folder pages), docs.amelabs.net (developers: creation/actions/tasks/configuration/requirements/verification/upgrades).

> Everything below was read directly from the files quoted. Anything I could not verify is marked ⚠️ UNVERIFIED.

---

## 1. Repo & playbook layout (verified by LS)

```
/home/z/my-project/repos/atlas/
├── .github/workflows/apbx.yaml        # CI: yamllint + sxsc CAB rebuild + .apbx artifact
├── src/
│   ├── playbook/                       # THE PLAYBOOK
│   │   ├── playbook.conf               # XML metadata + FeaturePages wizard UI
│   │   ├── playbook.png                # wizard icon (256px, see Verification docs)
│   │   ├── build-playbook.sh / .cmd    # thin wrappers → local-build.ps1
│   │   ├── Images/                     # browser logos for RadioImagePage (brave/firefox/librewolf/chrome .png)
│   │   ├── Configuration/              # 191 YAML files
│   │   │   ├── custom.yml              # ROOT task file (entry point)
│   │   │   ├── tweaks.yml              # runs all tweaks/** files in order
│   │   │   ├── atlas/{start,services,components,appx,default,revert}.yml
│   │   │   └── tweaks/{debloat,misc,networking,performance,privacy,qol,security,scripts}/...
│   │   └── Executables/                # PS1/CMD + Themes/ + ViVeTool zips
│   │       ├── AtlasDesktop/           # copied to %windir%\AtlasDesktop (post-install toggle folder)
│   │       └── AtlasModules/           # copied to %windir%\AtlasModules (scripts/modules/tools/cabs)
│   ├── sxsc/                           # component-removal YAMLs (built into .cab by CI)
│   ├── sxsc-disabled/                  # disabled component-removal YAMLs (NOT built)
│   ├── release-zip/                    # ships alongside the .apbx in release artifacts
│   └── dependencies/local-build.ps1    # builds the .apbx
```

Stats (rg counts over `src/playbook/Configuration/`): **191 .yml files**; action usages: `!registryValue` 410, `!task` 187, `!powerShell` 53, `!appx` 42, `!registryKey` 37, `!writeStatus` 36, `!run` 29, `!cmd` 22, `!service` 13, `!scheduledTask` 8, `!taskKill` 7, `!file` 1. `option:` keys appear 40× across 16 distinct option names.

---

## 2. `playbook.conf` — full element reference (quoted from file)

The entire file is 176 lines; quoted verbatim (src/playbook/playbook.conf):

```xml
<Playbook>
        <Name>AtlasOS</Name>
        <Username>Atlas</Username>
        <Title>Atlas v0.5.0</Title>
        <ShortDescription>AtlasOS Playbook for Windows 11</ShortDescription>
        <Description><![CDATA[╭───────────── ⚠️ 𝗖𝗿𝗶𝘁𝗶𝗰𝗮𝗹 ⚠️ ─────────────╮
│       Read the Atlas documentation first.       │
│                https://docs.atlasos.net/                │
╰───────────────────────────────────────╯

Atlas makes your computer snappier and more private with lots of usability improvements.]]></Description>
        <Details>An open and lightweight modification to Windows, designed to optimize performance, privacy and security.</Details>
        <ProgressText><![CDATA[Atlas is currently installing software, copying its configuration folders, and tweaking Windows. If you are not already, we recommend following our documentation.]]></ProgressText>
        <Version>0.5.0</Version>
        <SupportedBuilds>
                <!-- 24H2 -->
                <string>26100</string>
                <!-- 25H2 -->
                <string>26200</string>
        </SupportedBuilds>
        <UpgradableFrom>0.4.1</UpgradableFrom>
        <Requirements>
                <Requirement>DefenderToggled</Requirement>
                <Requirement>NoAntivirus</Requirement>
                <Requirement>Internet</Requirement>
                <Requirement>NoPendingUpdates</Requirement>
                <Requirement>UCPDDisabled</Requirement>
                <Requirement>PluggedIn</Requirement>
        </Requirements>
        <UniqueId>00000000-0000-4000-6174-6c6173203a33</UniqueId>
        <InstallGuide>https://docs.atlasos.net/getting-started/installation</InstallGuide>
        <Overhaul>true</Overhaul>
        <UseKernelDriver>false</UseKernelDriver>
        <AllowUnsupportedUpgrades>false</AllowUnsupportedUpgrades>
        <ProductCode>64</ProductCode>
        <EstimatedMinutes>15</EstimatedMinutes>
        <Git>https://github.com/Atlas-OS/Atlas</Git>
        <Website>https://atlasos.net</Website>
        <DonateLink>https://ko-fi.com/atlasos</DonateLink>
        <SupportsISO>true</SupportsISO>
        <OOBE>
                <BulletPoints>
                        <BulletPoint Icon="Rocket" Title="Performance"
                        Description="By removing unnecessary background processes, telemetry, optionally disabling power-saving features and more."/>
                        <BulletPoint Icon="Lock" Title="Usability"
                        Description="By removing Windows' advertising, and fixing general annoyances, you will have a more enjoyable Windows experience."/>
                        <BulletPoint Icon="Privacy" Title="Privacy"
                        Description="By eliminating most of Microsoft's notorious tracking, pre-installed apps, and bloatware, Atlas makes Windows private."/>
                </BulletPoints>
                <Internet>Force</Internet>
        </OOBE>
        <ISO>
                <DisableBitLocker>true</DisableBitLocker>
                <DisableHardwareRequirements>true</DisableHardwareRequirements>
        </ISO>
        <FeaturePages>
                <RadioPage IsRequired="true" DefaultOption="defender-enable" Description="Disabling Defender reduces security, and is an option for advanced users only.">
                        <TopLine Text="Defender can be toggled in the Atlas folder."/>
                        <Options>
                                <RadioOption>
                                        <Text>Enable Defender (recommended)</Text>
                                        <Name>defender-enable</Name>
                                </RadioOption>
                                <RadioOption>
                                        <Text>Disable Defender</Text>
                                        <Name>defender-disable</Name>
                                </RadioOption>
                        </Options>
                        <BottomLine Text="Learn more" Link="https://docs.atlasos.net/getting-started/post-installation/atlas-folder/security/#defender"/>
                </RadioPage>
                <RadioPage IsRequired="true" DefaultOption="mitigations-default" Description="Disabling mitigations reduces security, and could harm performance on modern CPUs.">
                        <TopLine Text="Disabling could improve performance on older CPUs."/>
                        <Options>
                                <RadioOption>
                                        <Text>Default Windows Mitigations (recommended)</Text>
                                        <Name>mitigations-default</Name>
                                </RadioOption>
                                <RadioOption>
                                        <Text>Disable All Mitigations</Text>
                                        <Name>mitigations-disable</Name>
                                </RadioOption>
                        </Options>
                        <BottomLine Text="Learn more" Link="https://docs.atlasos.net/getting-started/post-installation/atlas-folder/security/#mitigations"/>
                </RadioPage>
                <RadioPage IsRequired="true" DefaultOption="auto-updates-disable" Description="Updates are important for security, you'll get update notifications regardless.">
                        <TopLine Text="This can be changed in the Atlas folder later."/>
                        <Options>
                                <RadioOption>
                                        <Text>Disable Automatic Windows Updates</Text>
                                        <Name>auto-updates-disable</Name>
                                </RadioOption>
                                <RadioOption>
                                        <Text>Enable Automatic Windows Updates</Text>
                                        <Name>auto-updates-default</Name>
                                </RadioOption>
                        </Options>
                        <BottomLine Text="Learn more" Link="https://docs.atlasos.net/getting-started/post-installation/atlas-folder/general-configuration/#automatic-updates"/>
                </RadioPage>
                <CheckboxPage IsRequired="true" Description="Select the options you would like to use, they can be changed in the Atlas folder later.">
                        <Options>
                                <CheckboxOption>
                                        <Text>Disable Hibernation</Text>
                                        <Name>disable-hibernation</Name>
                                </CheckboxOption>
                        <CheckboxOption>
                                        <Text>Maximum Performance (Disable Power Saving)</Text>
                                        <Name>disable-power-saving</Name>
                        </CheckboxOption>
                        <CheckboxOption>
                                        <Text>Disable Core Isolation</Text>
                                        <Name>disable-core-isolation</Name>
                        </CheckboxOption>
                        </Options>
                        <BottomLine Text="Learn more" Link="https://docs.atlasos.net/getting-started/post-installation/atlas-folder/configuration"/>
                </CheckboxPage>
                <CheckboxPage IsRequired="true" Description="Select the options you would like to use, they can be changed in the Atlas folder later.">
                        <Options>
                                <CheckboxOption>
                                        <Text>Remove Snipping Tool App</Text>
                                        <Name>remove-snipping-tool</Name>
                                </CheckboxOption>
                                <CheckboxOption>
                                        <Text>Remove Microsoft Edge</Text>
                                        <Name>uninstall-edge</Name>
                                </CheckboxOption>
                                <CheckboxOption>
                                        <Text>Install a Browser</Text>
                                        <Name>install-another-browser</Name>
                                </CheckboxOption>
                        </Options>
                        <BottomLine Text="Learn more" Link="https://docs.atlasos.net/getting-started/post-installation/atlas-folder/configuration"/>
                </CheckboxPage>
        <CheckboxPage IsRequired="true" Description="Would you like to install AtlasOS Toolbox (BETA)?">
                <Options>
                        <CheckboxOption>
                                <Text>Install Atlas Toolbox</Text>
                                <Name>install-toolbox</Name>
                        </CheckboxOption>
                </Options>
        </CheckboxPage>
                <RadioImagePage CheckDefaultBrowser="true" DependsOn="install-another-browser" DefaultOption="browser-brave" Description="Select your preferred browser to install. Browser settings are not modified.">
                        <TopLine Text="We do not recommend Chrome for privacy reasons."/>
                        <Options>
                                <RadioImageOption>
                                        <Text>Brave</Text>
                                        <Name>browser-brave</Name>
                                        <FileName>brave</FileName>
                                        <GradientTopColor>#131524</GradientTopColor>
                                        <GradientBottomColor>#3b3e4f</GradientBottomColor>
                                </RadioImageOption>
                                <RadioImageOption>
                                        <Text>LibreWolf</Text>
                                        <Name>browser-librewolf</Name>
                                        <FileName>librewolf</FileName>
                                        <GradientTopColor>#057DB6</GradientTopColor>
                                        <GradientBottomColor>#86D8FF</GradientBottomColor>
                                </RadioImageOption>
                                <RadioImageOption>
                                        <Text>Firefox</Text>
                                        <Name>browser-firefox</Name>
                                        <FileName>firefox</FileName>
                                        <GradientTopColor>#FF3647</GradientTopColor>
                                        <GradientBottomColor>#FFC742</GradientBottomColor>
                                </RadioImageOption>
                                <RadioImageOption>
                                        <Text>Chrome</Text>
                                        <Name>browser-chrome</Name>
                                        <FileName>chrome</FileName>
                                        <GradientTopColor>#7E7E7E</GradientTopColor>
                                        <GradientBottomColor>#D0D0D0</GradientBottomColor>
                                </RadioImageOption>
                        </Options>
                        <BottomLine Text="Which is best for me?" Link="https://docs.atlasos.net/getting-started/post-installation/software/web-browsers"/>
                </RadioImagePage>
        </FeaturePages>
</Playbook>
```

### 2.1 Element semantics (per docs.amelabs.net/developers/configuration.html, cross-checked with engine source where possible)

| Element | Meaning | Notes verified |
|---|---|---|
| `Name` / `Username` | Playbook / creator name shown in wizard | required |
| `Title` | Primary pages title | required |
| `ShortDescription` | Side-bar text | required |
| `Description` | First intro page (supports CDATA; Atlas embeds ASCII-art warning + docs link) | required |
| `Details` | Updates-window description | required |
| `Version` | Must match `1`, `0.1`, or `0.0.1` style (docs) | required; local-build.ps1 regex `^(0|[1-9]\d*)(\.(0|[1-9]\d*)){0,2}$` |
| `SupportedBuilds` → `<string>` | Allowed Windows build numbers (UBR-agnostic: `26100`, `26200`) | **This is the only build gate**; 26H2 (27xxx) NOT supported → UltraOS opportunity |
| `UpgradableFrom` | Prior playbook versions this can upgrade from; supports ranges (`1.0.0-1.5.0`), `any`, or multiple `<string>` (docs) | Atlas: `0.4.1` |
| `Requirements` → `<Requirement>` | Wizard pre-flight checks. Docs catalog (docs.amelabs.net/developers/requirements.html): `Internet`, `NoInternet`, `Activation`, `FreshInstall` (install ≤40h old), `DefenderToggled` (user toggles 4 Defender toggles), `DefenderDisabled`, `UCPDDisabled`, `NoAntivirus` (WMI `root/SecurityCenter2` AntivirusProduct), `NoPendingUpdates`, `PasswordSet`, `AdministratorPasswordSet`, `PluggedIn` | Atlas uses 6 (see conf) |
| `UniqueId` | UUIDv4 identifier; used by upgrade option-memory (see §5.4) | Atlas: `00000000-0000-4000-6174-6c6173203a33` |
| `InstallGuide` | Custom install doc URL (pairs with FreshInstall req) | |
| `Overhaul` | Marks "overhaul"-class playbook (changes lots of Windows) | `true` |
| `UseKernelDriver` | Use AME Wizard kernel driver for extra privilege | `false` (TrustedInstaller is enough) |
| `AllowUnsupportedUpgrades` | `false` = block upgrades from versions not in `UpgradableFrom` | |
| `ProductCode` | AME **verification** code (assigned by Ameliorated; `local-build.ps1 -Removals Verification` strips `<ProductCode>` for local builds) | Atlas: `64`; ⚠️ UNVERIFIED what the number denotes internally |
| `EstimatedMinutes` | Time estimate in wizard | 15 |
| `Git` / `Website` / `DonateLink` | Links in updates window | |
| `SupportsISO` | Playbook can be injected into an ISO | `true` |
| `OOBE` → `BulletPoints` (`Icon`,`Title`,`Description`), `Internet` | Intro-page bullets + internet policy during OOBE flow; `Internet: Force` | |
| `ISO` → `DisableBitLocker`, `DisableHardwareRequirements` | ISO-injection options | both `true` |
| `FeaturePages` | Wizard option pages (see §3) | |
| `ProgressText` | Progress-window text (CDATA ok) | |

### 2.2 FeaturePages UI schema (ground truth from conf + amelabs docs sidebar "Custom Features": CheckboxPage, RadioPage, RadioImagePage, "Using Features In YAML")

- **`<RadioPage IsRequired DefaultOption Description>`** with `<TopLine Text>`, `<Options><RadioOption><Text><Name>`, `<BottomLine Text Link>`.
- **`<CheckboxPage IsRequired Description>`** with `<Options><CheckboxOption><Text><Name>`, optional `<BottomLine>`. Multiple CheckboxPages allowed; each renders as its own page.
- **`<RadioImagePage CheckDefaultBrowser DependsOn DefaultOption Description>`** with `<RadioImageOption>` children having `<Text> <Name> <FileName> <GradientTopColor> <GradientBottomColor>`; `FileName` maps to `Images/<name>.png` in the playbook root. `DependsOn="install-another-browser"` = only shown if that option was checked on a previous page.
- The `<Name>` of the selected Radio/Checkbox option becomes a **playbook option string** (e.g. `defender-disable`, `uninstall-edge`) that YAML actions reference via `option:` (see §5.2).

### 2.3 Full option inventory (16 names, all traced in YAML)

| Option | UI | Where consumed in YAML (verified by rg) |
|---|---|---|
| `defender-enable` / `defender-disable` | RadioPage 1 | `atlas/components.yml` (CAB package install/uninstall + ISO WdBoot delete) |
| `mitigations-default` / `mitigations-disable` | RadioPage 2 | `mitigations-disable` gates whole file `tweaks/scripts/script-mitigations.yml` (file-level `option:`); `mitigations-default` triggers nothing (Windows default stands) |
| `auto-updates-disable` / `auto-updates-default` | RadioPage 3 | `tweaks/qol/windows-update/disable-auto-updates.yml` gated on `auto-updates-disable`; **`auto-updates-default` appears ONLY in playbook.conf — no YAML action wired** (choosing it simply skips the disable script) |
| `disable-hibernation` | Checkbox | `tweaks/scripts/script-power.yml` (runs "Disable Hibernation (default).cmd") |
| `disable-power-saving` | Checkbox | `script-power.yml` (runs "Disable Power-saving.cmd"); negated `'!disable-power-saving'` sets Windows Balanced plan `381b4222-f694-41f0-9685-ff5bb260df2e` |
| `disable-core-isolation` | Checkbox | file-level `option:` in `tweaks/scripts/script-core-isolation.yml` → `ConfigVBS.ps1 -DisableAllVBS` |
| `remove-snipping-tool` | Checkbox | `atlas/appx.yml` (`Microsoft.ScreenSketch*` removal) + `tweaks/qol/disable-screen-capture-hotkey.yml` |
| `uninstall-edge` | Checkbox | `atlas/components.yml` (RemoveEdge.ps1 + appx + deprovision keys); negated in `script-file-associations.yml` |
| `install-another-browser` | Checkbox | gates `tweaks/qol/taskbar/config-pins.yml` (`option: '!install-another-browser'`) and RadioImagePage DependsOn |
| `install-toolbox` | Checkbox | `atlas/start.yml` (SOFTWARE.ps1 -Toolbox) |
| `browser-brave` / `browser-firefox` / `browser-chrome` / `browser-librewolf` | RadioImagePage | `atlas/start.yml` (installer scripts) + `script-file-associations.yml` (FILEASSOC.cmd "<Browser>") |

---

## 3. Execution pipeline — what runs when (from `Configuration/custom.yml`, quoted verbatim)

```yaml
---
title: Root Playbook File
description: Runs all of the Playbook files
actions:
  # some changes requires default user access. loading the hive before everything else is required
  - !powerShell:
    command: 'reg load HKU\AME_UserHive_Default C:\Users\Default\NTUSER.DAT'
    oobe: false
    wait: true
  - !writeStatus: { status: "Deleting old AtlasOS folders" }
  - !powerShell:
    command: '.\STOPFOLDERPROC.ps1'
    exeDir: true
    onUpgrade: true
    wait: true
    runas: currentUserElevated
  - !powerShell:
    command: |
      $windir = [Environment]::GetFolderPath('Windows')
      Remove-Item -LiteralPath "$windir\AtlasDesktop" -Force -Recurse
      Remove-Item -LiteralPath "$windir\AtlasModules" -Force -Recurse
    wait: true
    exeDir: true
    oobe: false
    onUpgrade: true

  - !writeStatus: { status: "Copying files" }
  - !powerShell:
    command: |
      $windir = [Environment]::GetFolderPath('Windows')
      @(
          'AtlasModules',
          'AtlasDesktop'
      ) | ForEach-Object {
          if (!(Test-Path $_)) { exit 1 }
          Copy-Item -Path $_ -Destination $windir -Force -Recurse
          if (!$?) { exit 2 }
      }
      Start-Process -FilePath """$windir\AtlasDesktop\6. Advanced Configuration\Process Explorer\Uninstall Process Explorer.cmd""" -ArgumentList "/silent" -WindowStyle Hidden
      Copy-Item -Path 'Themes\*' -Destination """$windir\Resources\Themes""" -Force -Recurse
    weight: 10
    wait: true
    exeDir: true
    handleExitCodes: { "!0": halt }

  # Prevent annoying notifications during deployment
  - !cmd:
    command: "DISABLENOTIFS.cmd"
    exeDir: true
    wait: true
    runas: currentUserElevated
  - !taskKill: { name: "explorer" }
  - !taskKill: { name: "ShellExperienceHost" }
  - !run: { exe: "explorer.exe", runas: "currentUser", wait: false }

  # Configure PowerShell first so that other PowerShell scripts work
  # NGEN - .NET assemblies PowerShell optimization
  - !writeStatus: { status: "Optimizing PowerShell" }
  - !task: { path: 'tweaks\scripts\script-ngen.yml' }
  - !task: { path: 'tweaks\qol\config-powershell.yml' }

  # Disk Cleanup is run first so it can run in the background
  - !writeStatus: { status: "Cleaning up" }
  - !powerShell:
    command: '.\CLEANUP.ps1'
    exeDir: true
    wait: true
    runas: currentUserElevated

  # Set hidden Settings pages
  # Done before everything else as scripts will overwrite it
  - !task: { path: 'tweaks\qol\set-hidden-settings-pages.yml' }

  # Main tasks
  - !task: { path: 'atlas\start.yml' }
  - !task: { path: 'atlas\services.yml' }
  - !task: { path: 'atlas\components.yml' }
  - !task: { path: 'atlas\appx.yml' }
  - !task: { path: 'atlas\default.yml' }
  - !task: { path: 'atlas\revert.yml' }
  - !task: { path: "tweaks.yml" }

  # Set hives to HKU default user
  - !writeStatus: { status: "Applying hives..." }
  - !powerShell:
    command: '.\APPLYDUHIVE.ps1'
    exeDir: true
    wait: true
    runas: currentUserElevated

  # Set all the correct paths if there are incorrect ones in the registry
  - !writeStatus: { status: "Cleaning up registry paths" }
  - !powerShell:
    command: '.\SETPATHS.ps1'
    exeDir: true
    wait: true
    runas: currentUserElevated

  # Unloading the hive
  - !powerShell:
    command: 'reg unload HKU\AME_UserHive_Default'
    oobe: false
    wait: true

  # Set PowerShell execution policy to RemoteSigned from the previous "Unrestricted"
  # This allows Atlas folder scripts (local) to run while requiring signatures for downloaded scripts
  - !writeStatus: { status: "Securing PowerShell execution policy" }
  - !registryValue:
    path: 'HKLM\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell'
    value: 'ExecutionPolicy'
    data: 'RemoteSigned'
    type: REG_SZ
```

**Sequence summary (fresh install):**
1. Load `C:\Users\Default\NTUSER.DAT` as `HKU\AME_UserHive_Default` (future users get tweaks via this hive).
2. On upgrade only: `STOPFOLDERPROC.ps1` (kills processes/tasks running from `%windir%\AtlasModules`/`AtlasDesktop`, incl. `SetTimerResolution.exe`) and delete old folders.
3. Copy `Executables/AtlasModules` + `Executables/AtlasDesktop` → `%windir%\`, extract themes to `%windir%\Resources\Themes`, silently uninstall Process Explorer.
4. `DISABLENOTIFS.cmd` (kills WpnService etc. so no popups mid-install; re-enabled at the very end by `tweaks/misc/enable-notifications.yml`), kill+restart explorer.
5. NGEN PowerShell (`NGEN.ps1` compiles loaded .NET assemblies — "speeds up powershell startup time by 10x"), set execution policy Unrestricted (restored to RemoteSigned at the end).
6. `CLEANUP.ps1` (cleanmgr preset 64 config + start, TEMP cleanup, `vssadmin delete shadows /all /quiet`).
7. `atlas/start.yml` (PATH setup, DISM DirectPlay enable, remove Steps Recorder capability, `StartComponentCleanup`, SOFTWARE.ps1 installs vcredists+NanaZip/7-Zip+legacy DirectX, option-gated browsers/Toolbox).
8. `atlas/services.yml` → backup services, disable file sharing/location/minimal-indexing via AtlasDesktop scripts, disable services+drivers.
9. `atlas/components.yml` → SecurityHealth run-key delete, Smart App Control off, OneDrive strip (`ONED.cmd`), option-gated Edge removal, option-gated **sxsc CAB package install/uninstall (Defender/NoTelemetry)**.
10. `atlas/appx.yml` → appx removals + deprovision diff + cache clears.
11. `atlas/default.yml` → `reg import DEFAULT.reg` (writes ~58 `HKLM\SOFTWARE\AtlasOS\Services\<Name>` state markers) + `DEFAULT.ps1` (upgrade-only: re-runs every `(default).cmd` toggle with `/silent /noAction`).
12. `atlas/revert.yml` (upgrade-only, TrustedInstaller) → deletes old `ThisPCPolicy` registry values from pre-0.5 versions.
13. `tweaks.yml` → ~180 task files across networking/performance/privacy/qol/security/debloat/scripts/misc (full catalog §10).
14. `APPLYDUHIVE.ps1` → scans **all** `Configuration/tweaks/**/*.yml` for `HKCU\...` `path:`s, mirrors those values into `HKU\AME_UserHive_Default` so newly created users inherit the tweaks.
15. `SETPATHS.ps1` → fixes `path` values under `HKLM\SOFTWARE\AtlasOS\Services` pointing into AtlasDesktop.
16. Unload hive; set PowerShell `ExecutionPolicy=RemoteSigned`.

**New users:** `tweaks/misc/add-newUser-script.yml` writes a `RunOnce` value into the default-user hive running `%windir%\AtlasModules\Scripts\newUsers.ps1` on first login (applies dynamically generated per-user tweaks). Quoted verbatim:

```yaml
---
title: Add newUsers.cmd script
description: Adds the newUsers.ps1 script to RunOnce, which applies any tweaks that are dynamically generated on new user creation
actions:
  - !registryValue:
    path: 'HKU\AME_UserHive_Default\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    value: 'RunScript'
    data: |
      powershell -EP Bypass -NoP & """$([Environment]::GetFolderPath('Windows'))\AtlasModules\Scripts\newUsers.ps1"""
    type: REG_SZ
```

---

## 4. How user selections flow into YAML — the `option:` plumbing (verified against engine source)

From `/home/z/my-project/repos/trusted-uninstaller-cli/TrustedUninstaller.Shared/AmeliorationUtil.cs` (lines ~1505-1525) and `Tasks/TaskAction.cs`:

- `option: 'name'` → action runs **iff** the user selected that FeaturePages option (case-insensitive `options.Contains(option)`).
- `option: '!name'` → **negation**: runs iff NOT selected.
- `options: ['a','b']` (array; Atlas doesn't use it) → OR for positive entries, AND for `!negative` entries. A single string may also use `&` (AND): `IsApplicableOption` splits on `&`, and `&`+`!` cannot be mixed.
- Options can gate **whole task files** (file-level `option:` — e.g. `script-mitigations.yml`, `script-core-isolation.yml`) or **individual actions**.
- `builds:` supports `>=, <=, >, <` operators, `!` negation (e.g. `['>=22621','!>22625']`), exact builds and `build.ubr` (e.g. `22621.1265`) — engine `TaskAction.IsApplicableNumber()`.
- **Upgrade memory**: per docs.amelabs.net/developers/upgrades.html — on upgrade, if the old version had the same option available and the user did NOT select it, actions gated on that option won't run even if newly selected (requires old playbook to have a `UniqueId`).
- `onUpgrade: true` = run **only** when upgrading from a version listed in `UpgradableFrom`; `onUpgrade: false` = run only when NOT upgrading. Re-running the same version re-triggers only `onUpgrade: false` actions. `onUpgradeVersions: ['>=1.0','!1.2']` refines this.
- Action-level tri-state flags (engine `TaskAction.cs` lines 15-38):
  - `iso: true` = run during ISO mastering AND normal install; `iso: only` = ISO mastering only; `iso: false` (**default for actions**) = never during ISO mastering. Example in Atlas: `atlas/components.yml` WdBoot service-key delete uses `iso: only` under `HKLM\OfflineSys\ControlSet001\Services\WdBoot` (offline hive during ISO mastering).
  - `oobe: true` = always run during OOBE + normal; `oobe: only` = OOBE only; `oobe: false` = never during OOBE; **null (default)** = run normally, and during OOBE unless `iso: true`. Task-level defaults differ: `UninstallTask.cs` sets task `ISO=True`, `OOBE=True` by default.
- `cpuArch:` gates by CPU architecture — e.g. `tweaks/performance/disable-fth.yml` uses `cpuArch: 'X64'` for FTH disable and a `!file` delete for `cpuArch: 'Arm64'`; `tweaks/misc/delete-windows-specific-files.yml` deletes Open-Shell files on ARM64.
- `weight:` gives actions relative weights for progress reporting (e.g. `weight: 150` on the SOFTWARE.ps1 install action).

---

## 5. The YAML tweak schema — complete reference

### 5.1 Task-file skeleton

```yaml
---
title: <required string>
description: <optional string>
privilege: <Admin|TrustedInstaller>          # default Admin (UninstallTask.cs: Privilege = Admin)
option: '<option-name>'                       # gate whole file on one option
options: ['a', 'b']                           # or several
builds: ['>=22000']                           # build gate
cpuArch: 'X64'                                # arch gate
onUpgrade: true|false                         # upgrade-only / fresh-only
onUpgradeVersions: ['0.4.1']
actions:
  - !<actionType>: { ... }                    # ordered list, executed top to bottom
```

### 5.2 Common action-level keys (all action types, from `TaskAction.cs`)

`iso` (True/Only/False), `oobe` (True/Only/False), `ignoreErrors` (bool), `option` (string, supports `!` negation), `options` (array), `builds` (array), `cpuArch` (string), `onUpgrade` (bool?), `onUpgradeVersions`, `previousOption`, `errorAction` (Ignore/Log/Notify/Halt), `allowRetries`, `status`, `weight`.

### 5.3 Action types — full key catalog (engine `TrustedUninstaller.Shared/Actions/*.cs` + amelabs docs)

| Action | Keys (verified from source `[YamlMember Alias=…]`) |
|---|---|
| `!registryValue` | `path`, `value` (empty string `''` = default value), `data`, `type` (REG_DWORD/REG_SZ/REG_BINARY/…), `operation` (add/**delete**), `scope` (allUsers/currentUser/activeUsers/defaultUsers — for HKCU hives), `weight` |
| `!registryKey` | `path`, `operation` (add/delete/…), `scope`, `weight` |
| `!powerShell` | `command` (runs `powershell -NoP -ExecutionPolicy Bypass -NonInteractive -C`), `exeDir` (work dir = playbook Executables folder), `runas` (currentUser/currentUserElevated/system/**trustedInstaller** default), `wait` (default false), `timeout`, `handleExitCodes` (e.g. `{ "!0": halt }`; handlers log/error/halt/retry/retryError, conditionals `'!0'`, `'>=1'`), `weight` |
| `!cmd` | `command`, `exeDir`, `runas`, `wait`, `timeout`, `handleExitCodes`, `weight` |
| `!run` | `exe`, `args`, `exeDir`/`baseDir`, `runas`, `wait`, `timeout`, `createWindow`/`hideWindow`, `showOutput`/`showError`, `handleExitCodes`, `weight` |
| `!service` | `name`, `operation` (change/stop/start/pause/continue/delete/deleteStop), `startup` (2=Automatic, 3=Manual, **4=Disabled**), `deleteStop`, `deleteUsingRegistry`, `device` (bool for drivers), `weight` |
| `!scheduledTask` | `path` (full task path `\Microsoft\Windows\...`), `operation` (disable/enable/…), `data`, `weight` |
| `!appx` | `name` (wildcards `*`), `type` (**family** default / package / app), `operation` (remove/**clearCache**), `verboseOutput`, `unregister`, `weight` |
| `!taskKill` | `name` (wildcard ok, e.g. `msteams*`), `pathContains`, `weight` |
| `!task` | `path` (relative path to another yml, **backslashes** — Windows path separators), `iso`, `oobe` |
| `!writeStatus` | `status` (progress text) |
| `!file` | `path`, `prioritizeExe`, `useNSudoTI`, `weight` (delete/modify files) |
| `!download` | `url`, `git`, `package`, `destination`, `overwrite`, `regex`, `weight` (not used by Atlas) |
| `!software` / `!systemPackage` / `!update` / `!user` / `!shortcut` / `!language` / `!lineInFile` | exist in engine; Atlas uses none of these |

Escaping convention seen throughout Atlas: inside single-quoted YAML strings, embedded double quotes are tripled (`"""C:\path with spaces"""`) and PowerShell env-vars use `[Environment]::GetFolderPath(...)` instead of relying on env expansion. Path variables like `%windir%` appear literally in `!file:` and some `data:` strings (engine expands them) — e.g. `- !file: {path: '%windir%\AtlasDesktop\7. Security\Mitigations\Fault Tolerant Heap', cpuArch: 'Arm64'}`.

### 5.4 Five+ complete example files, VERBATIM

**(1) `Configuration/atlas/services.yml`** — service/driver disabling + AtlasDesktop script invocation:

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

**(2) `Configuration/atlas/components.yml`** — component removal incl. Edge/OneDrive/sxsc CABs, with option + ISO gating:

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
  - !registryKey: {path: 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\Microsoft.MicrosoftEdge.Stable_8wekyb3d8bbwe', operation: add, option: 'uninstall-edge'}
  - !registryKey: {path: 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\Microsoft.MicrosoftEdge_8wekyb3d8bbwe', operation: add, option: 'uninstall-edge'}

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

Note: the **NoTelemetry CAB is installed on EVERY Atlas install** (both branches); the NoDefender CAB only when `defender-disable`.

**(3) `Configuration/tweaks/debloat/disable-scheduled-tasks.yml`** — scheduled tasks:

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

**(4) `Configuration/tweaks/scripts/script-power.yml`** — option-gated power config (both positive and negated options):

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

**(5) `Configuration/tweaks/scripts/script-file-associations.yml`** — browser-aware file assoc:

```yaml
---
title: Set File Associations
description: Sets file associations for the user-selected web browser and other apps
actions:
  - !run:
    exe: 'FILEASSOC.cmd'
    exeDir: true
    option: '!uninstall-edge'
  - !run:
    exe: 'FILEASSOC.cmd'
    args: '"Brave"'
    option: 'browser-brave'
    exeDir: true
  - !run:
    exe: 'FILEASSOC.cmd'
    args: '"LibreWolf"'
    option: 'browser-librewolf'
    exeDir: true
  - !run:
    exe: 'FILEASSOC.cmd'
    args: '"Firefox"'
    option: 'browser-firefox'
    exeDir: true
  - !run:
    exe: 'FILEASSOC.cmd'
    args: '"Google Chrome"'
    option: 'browser-chrome'
    exeDir: true
```

**(6) `Configuration/tweaks/qol/set-hidden-settings-pages.yml`** — build-conditional registry:

```yaml
---
title: Set Hidden Pages
description: Hides Settings pages that are either broken or unused
actions:
    # https://learn.microsoft.com/en-us/windows/uwp/launch-resume/launch-settings-app

    # Windows 10
  - !registryValue:
    path: 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
    value: 'SettingsPageVisibility'
    data: 'hide:recovery;maps;maps-downloadmaps;privacy;privacy-speechtyping;privacy-speech;privacy-feedback;privacy-activityhistory;search-permissions;privacy-general;sync;mobile-devices;mobile-devices-addphone;workplace;backup'
    type: REG_SZ
    builds: [ '<22000' ]

    # Windows 11
  - !registryValue:
    path: 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer'
    value: 'SettingsPageVisibility'
    data: 'hide:recovery;maps;maps-downloadmaps;privacy;privacy-feedback;privacy-activityhistory;search-permissions;privacy-general;sync;mobile-devices;mobile-devices-addphone;workplace;family-group;deviceusage;home'
    type: REG_SZ
    builds: [ '>=22000' ]
```

**(7) `Configuration/tweaks/performance/system/win32-priority-separation.yml`** — minimal example:

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

**(8) `Configuration/tweaks/misc/config-time.yml`** — service start + exe runs:

```yaml
---
title: Configure Time Servers
description: Configures time servers to be more reliable and accurate than the defaults
actions:
    # https://www.pool.ntp.org/en/use.html
  - !service: {name: 'w32time', operation: start, ignoreErrors: true}
  - !run: {exe: 'w32tm', args: '/config /syncfromflags:manual /manualpeerlist:"0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org"'}
  - !run: {exe: 'w32tm', args: '/config /update'}
  - !run: {exe: 'w32tm', args: '/resync', ignoreErrors: true}
```

**(9) `Configuration/tweaks/qol/taskbar/end-task.yml`** — build gate:

```yaml
---
title: Add 'End task' to the taskbar
description: Adds 'End task' as a right-click option on taskbar for QoL
builds: [ '>22000' ]
actions:
  - !registryValue:
    path: 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings'
    value: 'TaskbarEndTask'
    data: '1'
    type: REG_DWORD
```

**(10) `Configuration/tweaks/qol/shell/restore-old-context-menu.yml`** — `oobe: only` fallback:

```yaml
---
title: Restore Old Context Menu
description: Restores the old context menu in Windows 11
builds: [ '>=22000' ]
actions:
  - !registryValue:
    path: 'HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
    value: ''
    data: ''
    type: REG_SZ
    
    # Fall back for OOBE cause it seems not to work 
  - !powerShell:
    command: 'reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /t REG_SZ /d "" /f > nul'
    exeDir: true
    oobe: only
```

---

## 6. `Executables/` catalog — what runs when

### 6.1 Root-level scripts (all run from the playbook `Executables` dir via `exeDir: true`)

| File | Purpose (verified by reading) | Invoked by |
|---|---|---|
| `APPLYDUHIVE.ps1` | Installs FXPSYaml module; parses **every** `Configuration/tweaks/**/*.yml`; collects all `HKCU\` paths; copies those values from live HKCU into `HKU\AME_UserHive_Default` (default-user hive) | custom.yml (end) |
| `ASSOC.ps1` | Implements Microsoft's `Set-UserFTA`-style hash (MD5+custom mixing, 268 lines) so `FILEASSOC.cmd` can set per-user file associations without dism | FILEASSOC.cmd |
| `BACKUP.ps1 -FilePath <reg>` | Dumps every service's `Start`+`Description` (excluding Defender-described) into a .reg (UTF-8 no BOM). Called twice: BEFORE changes → `AtlasModules\Other\winServices.reg`, AFTER → `atlasServices.reg` | atlas/services.yml, tweaks/scripts/script-backup2.yml |
| `CLEANUP.ps1` | cleanmgr preset `StateFlags0064` (skips D3D shader cache, Recycle Bin, Temp Files, Update Cleanup, Language Pack), `cleanmgr /sagerun:64`, clears user+system TEMP (skips `AME` folder), `vssadmin delete shadows /all /quiet`; skips cleanmgr if other Windows installs exist on other drives | custom.yml (early, background) |
| `CLIENTCBS.ps1` | Parses `SystemApps\...\wsxpacks\Account\SettingsExtensions.json` for velocity IDs, hides `ms-settings:account` page, extracts ViVeTool (x64 or ARM64CLR zip) and disables each ID (`ViVeTool.exe /disable /id:$id`) — removes Settings 'Accounts' page ads | tweaks/scripts/script-clientcbs.yml |
| `DEFAULT.ps1` | Re-runs **every** `AtlasDesktop\**\*(default).cmd` with `/silent /noAction` — upgrade-only (`onUpgrade: true` in atlas/default.yml) | atlas/default.yml |
| `DEFAULT.reg` | 22 KB reg file writing ~58 `HKLM\SOFTWARE\AtlasOS\Services\<Name>` marker keys (state+path) — see §7 | atlas/default.yml |
| `DISABLENOTIFS.cmd` / `ENABLENOTIFS.cmd` | Disable/enable Windows notifications (WpnService + WpnUserService* stop/disable/delete, toast registry, hides notifications settings pages) | custom.yml (start) / tweaks/misc/enable-notifications.yml (end) |
| `DISABLEPNP.ps1` | Disables 21 PnP devices by friendly name (AMD PSP, Intel ME, SMBus, System Speaker/Timer, PCI Simple Communications, Kernel Debug Network Adapter, etc.) | tweaks/scripts/script-devices.yml |
| `FILEASSOC.cmd` | 45 KB batch: sets file associations for browser/PDF etc. via ASSOC.ps1 hash (SetUserFTA technique) | script-file-associations.yml |
| `LIBREWOLF.ps1` | Downloads LibreWolf from GitLab project 44042130 releases, silent install, installs LibreWolf-WinUpdater from codeberg with a per-user scheduled task (every 7h + at logon +1m delay) | atlas/start.yml (option browser-librewolf) |
| `NGEN.ps1` | `ngen install` on all loaded .NET assemblies | tweaks/scripts/script-ngen.yml (runs FIRST of all tweaks) |
| `ONED.cmd` | OneDrive strip: aborts (exit 6000) if any user's OneDrive folder is non-empty; kills OneDrive.exe; runs OneDriveSetup /uninstall (SysWOW64 + System32); per-HKU-hive cleanup of BannerStore/AutoplayHandlers/App Paths/Uninstall OneDrive entries; unpins CLSID {018D5C66-4533-4307-9B53-224DE2ED1FE6}; deletes OneDrive scheduled tasks; removes leftover dirs | atlas/components.yml (always) |
| `PFP.ps1` | Generates user account pictures at 448/192/48/40/32 px from `user.png` into `CommonAppData\Microsoft\User Account Pictures` | tweaks/scripts/script-pfp.yml (onUpgrade: false) |
| `SETPATHS.ps1` | Rewrites stale `path` values under `HKLM\SOFTWARE\AtlasOS\Services\*` to point into `%windir%\AtlasDesktop` | custom.yml (end) |
| `SETTABST.ps1` | Registers scheduled tasks `TaskBarPinsDefault` / `TaskBarPins` running `AtlasModules\Scripts\taskbarPins.ps1` at logon (Users group, RunLevel Highest) | (invoked by taskbarPins flow) ⚠️ UNVERIFIED exact invoker — referenced by `tweaks/qol/taskbar/config-pins.yml` flow |
| `SHORTCUTS.ps1` | Creates `Atlas.lnk` (icon `atlas-folder.ico`) on default user desktop + all user desktops + Common Start Menu; creates "Set services to defaults.lnk" | tweaks/misc/create-shortcuts.yml |
| `SOFTWARE.ps1` | curl.exe with `--connect-timeout 10 --retry 5`; downloads+silent-installs: VC++ runtimes 2005/2008/2010/2012/2013/2015-2022 (x86+x64), NanaZip (msixbundle via GitHub API, falls back to 7-Zip from 7-zip.org), legacy DirectX Jun2010 redist; `-Brave/-Firefox/-Chrome/-Toolbox` switches install respective software (Toolbox from `github.com/Atlas-OS/atlas-toolbox/releases/latest/download/AtlasToolbox-Setup.exe`) | atlas/start.yml |
| `STARTMENU.ps1` | Per-HKU-user: copies `Layout.xml` → `LayoutModification.xml`; deletes `start*.bin` (pinned items), `start.tilegrid` cache, `...\CurrentVersion\Start` Config value ("Removing advertisements/stubs from Start Menu (23H2+)") | start menu config flow |
| `STOPFOLDERPROC.ps1` | Kills processes whose image path is under `%windir%\AtlasModules`/`AtlasDesktop`; stops scheduled tasks executing under those roots; ends `Force Timer Resolution` task; verifies `SetTimerResolution.exe` not locked | custom.yml (upgrade only) |
| `TASKBARPINS.ps1` | 29 KB: hard-coded binary `Taskband\FavoritesResolve`/`Favorites` registry blobs to pin File Explorer + chosen browser (Brave/Firefox/LibreWolf/Chrome/Edge) to taskbar; uses temp `.lnk` + `IShellLink` | SETTABST-scheduled task / taskbarPins.ps1 |
| `Themes/atlas-v0.5.x-dark.theme` etc. (5 `.theme` files) | Atlas visual themes copied to `%windir%\Resources\Themes` | custom.yml + tweaks/qol/appearance/atlas-theme.yml (sets `atlas-v0.5.x-dark.theme`, MRU, lockscreen) |
| `ViVeTool-v0.3.3.zip` / `ViVeTool-v0.3.3-ARM64CLR.zip` | ViVeTool binaries (feature velocity toggles) used by CLIENTCBS.ps1 | — |
| `user.png`, `Layout.xml` | assets for PFP.ps1 / STARTMENU.ps1 | — |

### 6.2 `AtlasDesktop/` — the post-install toggle folder (copied to `%windir%\AtlasDesktop`, shortcut "Atlas" on desktop)

Structure (file counts): `1. Software` (4), `2. Drivers` (8), `3. General Configuration` (60), `4. Interface Tweaks` (54), `5. Windows Settings` (11), `6. Advanced Configuration` (33), `7. Security` (16), `8. Additional Tools` (4), `9. Troubleshooting` (11) + 5 `.url` web links + `Install AtlasOS Toolbox.cmd`.

**Toggle pattern** — every toggle is a pair of self-elevating `.cmd` files named `<Action>.cmd` / `<Action> (default).cmd` in its own subfolder. Quoted example (`3. General Configuration/Power-saving/Disable Power-saving.cmd`):

```cmd
@echo off
set "settingName=PowerSaving"
set "stateValue=0"
set "scriptPath=%~f0"
set "script=%windir%\AtlasModules\Scripts\ScriptWrappers\DisablePowerSaving.ps1"

set "___args="%~f0" %*"
fltmc > nul 2>&1 || (
    echo Administrator privileges are required.
    powershell -c "Start-Process -Verb RunAs -FilePath 'cmd' -ArgumentList """/c $env:___args"""" 2> nul || (
        echo You must run this script as admin.
        if "%*"=="" pause
        exit /b 1
    )
    exit /b
)

if not exist "%script%" (
    echo Script not found.
    echo "%script%"
    pause
    exit /b 1
)

reg add "HKLM\SOFTWARE\AtlasOS\Services\%settingName%" /v state /t REG_DWORD /d %stateValue% /f > nul
reg add "HKLM\SOFTWARE\AtlasOS\Services\%settingName%" /v path /t REG_SZ /d "%scriptPath%" /f > nul

powershell -EP Bypass -NoP -File "%script%" %*

if "%~1"=="/silent" exit /b

echo.
echo Power Saving has been disabled.
echo Press any key to exit...
pause > nul
exit /b
```

Conventions (verified across files):
- `fltmc` admin check → self-elevate via `Start-Process -Verb RunAs`.
- Writes state marker `HKLM\SOFTWARE\AtlasOS\Services\<settingName>` → `state` (DWORD) + `path` (this script's path).
- Delegates real work to `%windir%\AtlasModules\Scripts\...` (ScriptWrappers/*.ps1 or inline).
- `/silent` = no prompts/pause; `/noAction` (as `%~2`, passed by DEFAULT.ps1 as `/silent /noAction`) skips side-effects like restarting explorer (e.g. `if /I not "%~2"=="/noAction" powershell -command "stop-process -name explorer –force"` in Copilot/Widgets toggles).
- Toggle topics (folder names under `3. General Configuration`): AI Features (Copilot, Recall), Automatic Updates, Background Apps, CPU Idle (+ desktop context-menu toggle), Delivery Optimization, FSO and Game Bar, File Sharing (incl. Network Navigation Pane, Give Access To), Hibernation, Location, Mobile Devices (Phone Link), Power-saving, Search Indexing (Enable/Disable/Minimal), Sleep, Sleep Study, System Restore, Timer Resolution (with `! MeasureSleep.exe` + `Force Timer Resolution` task), Update Notifications, Web Search, Widgets, Windows Spotlight, Windows Updates (toggle, set/reset deferral), Workplace.
- `4. Interface Tweaks`: context menus (Extract, Send To, Take Ownership, Run With Priority, Terminals, Windows 11 Old/New), Explorer customization (App Icons on Thumbnails, Automatic Folder Discovery, Compact View, Gallery, Quick Access, Removable Drives, Recent Items, Shortcut Icon/Text), Old Flyouts (Volume/Battery/Date-Time), Snap Layouts, Edge Swipe, Lock Screen, Start Menu (Open-Shell install + `Atlas Open-Shell Preset.xml`, StartAllBack/ExplorerPatcher links), Verbose Status Messages, Visual Effects, Restart Explorer.
- `6. Advanced Configuration`: Boot Configuration (boot menu appearance/behavior, `bcdedit`), Driver Configuration (GoInterruptPolicy, MSI Utility V3, AutoGpuAffinity, Interrupt Affinity Tool links), Microsoft Store enable/disable, Process Explorer install/uninstall, Services (Bluetooth, Lanman Workstation/SMB, Network Discovery, NVIDIA Display Container LS + context menu, Printing, Superfetch).
- `7. Security`: Defender (Toggle Defender, Security Health Tray startup, App and Browser Control visibility), Core Isolation (VBS) enable/disable/current-config, Mitigations (enable/disable all, FTH on/off/reset).
- `9. Troubleshooting`: Reset Network to Atlas/Windows Default, Set services to defaults, Telemetry Components, Repair Windows Components, Fix Errors 2502/2503, Safe Mode (4 variants), Reset this PC link.

Full state-marker list written by `DEFAULT.reg` (i.e., the toggle registry): Animation, AppIconThumbnail, AppStoreArchiving, AutomaticFolderDiscovery, AutomaticUpdates, BackgroundApps, Bluetooth, CompactView, ContextMenuTerminals, Copilot, CpuIdle, DefaultAtlasNetwork, DeliveryOptimisation, EdgeSwipe, ExtractContextMenu, FaultTolerantHeap, FileSharing, FSOGameBar, Gallery, GiveAccessToMenu, Hibernation, HideAppBrowserControl, Indexing, LanmanWorkstation, Location, LockScreen, Mitigations, NetworkDiscovery, NetworkNavigationPane, NVidiaDisplayContainer, NVidiaDisplayContainerContextMenu, OldContextMenu, PhoneLink, PowerSaving, Printing, QuickAccess, Recall, RecentItems, RemovableDrivesInSidebar, SecurityHealthTray, ShortcutIcon, ShortcutText, Sleep, SleepStudy, SnapLayouts, SuperFetch, SystemRestore, TakeOwnership, UpdateNotifications, VerboseMessages, WebSearch, Widgets, WindowsSpotlight (+ `HKLM\SOFTWARE\AtlasOS` root).

### 6.3 `AtlasModules/` (copied to `%windir%\AtlasModules`, added to system PATH by start.yml)

- `initPowerShell.ps1` — one-liner adding `AtlasModules\Scripts\Modules` to `$env:PSModulePath`.
- `Scripts/`: `RunAsTI.cmd`, `edgeCheck.cmd`, `fileAssoc.cmd`, `indexConf.cmd`, `installToolbox.ps1`, `newUsers.cmd/.ps1`, `packageInstall.ps1` (394-line TrustedInstaller-only installer for sxsc CABs, modified from he3als/online-sxs; handles Safe Mode reboots: `bcdedit /set {current} safeboot minimal` + Winlogon Shell hijack to resume installs, package lists in `system32\safeModePackagesToInstall.atlasmodule`), `serviceWarning.cmd`, `setSvc.cmd` (sc config helper: `setSvc <name> <4>`), `settingsPages.cmd` (`/hide <page>` via SettingsPageVisibility), `taskbarPins.ps1`, `toggleDev.cmd`, `wingetCheck.cmd`.
- `Scripts/ScriptWrappers/` (the "engine" behind AtlasDesktop toggles): `ConfigVBS.ps1`, `DebloatSendToContextMenu.ps1`, `DefaultPowerSaving.ps1`, `DisableFileSharing.ps1`, `DisablePowerSaving.ps1` (powercfg "Atlas Power Scheme" GUID 11111111-1111-1111-1111-111111111111 duplicated from Ultimate Performance e9a42b02-d5df-448d-aa00-03f14749eb61, NVMe idle timeouts=0, USB selective suspend off, allow-throttle-states off, processor time-check 200ms, NIC advanced-property power savings off (EEE/ULP/uAPSD/GreenEthernet...), device power-save registry renames (`*-OLD` backup) incl. AllowIdleIrpInD3/D3ColdSupported..., `MSPower_DeviceEnable` WMI disable, StorageD3InModernStandby=0, stornvme IdlePowerMode=0, PowerThrottlingOff=1), `EnableFileSharing.ps1`, `InstallSoftware.ps1`, `RemoveEdge.ps1` (he3als' EdgeRemover), `TelemetryComponents.ps1`, `ToggleDefender.ps1` (interactive menu → packageInstall.ps1 with `*Z-Atlas-NoDefender-Package*`), `UpdateDrivers.ps1`.
- `Scripts/Modules/` (PowerShell modules, auto-loaded via PSModulePath): `AllRegistryUsers` (`Get-RegUserPaths` — enumerates real user hives incl. `AME_UserHive_*` pattern), `Debloat`, `Miscellaneous`, `Performance`, `Privacy`, `Qol`, `Scripts`, `Shortcuts` (`New-Shortcut`, `Write-Title`, `Read-Pause`), `Themes` (`Set-Theme`, `Set-ThemeMRU`, `Set-LockscreenImage`), `UserPaths` (`Get-UserPath`), `Utils`.
- `Packages/` — 4 CABs: `Z-Atlas-NoDefender-Package31bf3856ad364e35amd645.0.0.0.cab`, same `arm64`, `Z-Atlas-NoTelemetry-Package...amd64/arm64` (built from sxsc YAMLs by CI; see §8).
- `Tools/` — `SetTimerResolution.exe` (deaglebullet, GPL), `multichoice.exe` (Atlas-OS/Atlas-Utilities, GPL) — SHA256 hashes documented in `AtlasModules/README.md`.
- `Toolbox/` — BETA Atlas Toolbox scripts (Copilot/SuperFetch/NVidia/SecurityHealthTray toggles, `setServicesToDefaults.cmd`, `vbsCurrentConfig.cmd`, Troubleshooting/*, Mitigations_0/1/2.cmd, SafeMode, ContextMenuTerminals, ShortcutIcon, FileSharing).
- `Other/` — `atlas-folder.ico`, `Blank.ico`, `Classic.ico`, `NVIDIA.ico`, `Layout.xml`, `Force Timer Resolution.xml` (scheduled task XML: runs `SetTimerResolution.exe --resolution 5060 --no-console` at logon as SYSTEM `S-1-5-18`, Priority 7).
- `Acknowledgements/`, `Wallpapers/`.

---

## 7. Build system — how the `.apbx` is assembled

### 7.1 `src/dependencies/local-build.ps1` (parameters & behavior, verified by reading)

```powershell
param (
        [switch]$AddLiveLog,
        [switch]$ReplaceOldPlaybook,
        [switch]$DontOpenPbLocation,
        [switch]$NoPassword,
        [ValidateSet('Dependencies', 'Requirements', 'WinverRequirement', 'Verification', IgnoreCase = $true)]
        [array]$Removals,
        [string]$FileName = "Atlas Test"
)
```

- Requires 7-Zip (`7z`/`7zz`/`%ProgramFiles%\7-Zip\7z.exe`).
- **Removals** (test-build conveniences):
  - `Requirements` → strips `<Requirement>` lines from playbook.conf (kept `<Requirements>` tags because "0.6.5 has a bug where it will crash without the 'Requirements' field").
  - `WinverRequirement` → strips `<string>`, `</SupportedBuilds>`, `<SupportedBuilds>` (removes the build gate).
  - `Verification` → strips `<ProductCode>` (no AME verification for test builds).
  - `Dependencies` → deletes the `################ NO LOCAL BUILD ################` … `END` block from `atlas/start.yml` (skips DISM/software installs).
- **`-AddLiveLog`** → injects into `custom.yml` (in temp copy) as the FIRST action after `actions:` a `!cmd` that opens a PowerShell window tailing `%ProgramData%\AME\Logs\<latest>\OutputBuffer.txt` (`Get-Content -Wait`) — live log during install.
- **OEM versioning**: replaces the literal `AtlasVersionUndefined` in `tweaks/misc/config-oem-information.yml` with `v<Version>` from playbook.conf (so winver/Settings/bcdedit description show "Atlas Playbook vX.Y.Z").
- Packaging: builds a file list of everything under `src/playbook` (excluding `local-build.*`, `*.apbx`, and any file it modified), then:
  `& $7zPath a -spf -y -mx1 $pass -tzip "$apbxPath" @"$files"` where `$pass = '-pmalte'` (unless `-NoPassword`), then `7z u` the modified files over the archive. **So Atlas' .apbx is a ZIP-format archive, password `malte`** (amelabs packaging docs suggest 7z format; both are encrypted archives the wizard accepts — ⚠️ UNVERIFIED which formats the GUI accepts besides these two).
- Output name: `<FileName>.apbx` (auto-increments ` (n)` if exists; `-ReplaceOldPlaybook` deletes in-use old file or falls back to new name).

### 7.2 Wrappers (both invoke the same flags)

`src/playbook/build-playbook.cmd`:
```cmd
@echo off
pushd "%~dp0"
echo Building Playbook...
powershell -nop -ep bypass ^& "%cd%\..\dependencies\local-build.ps1" -AddLiveLog -ReplaceOldPlaybook -Removals WinverRequirement, Verification -DontOpenPbLocation
if %errorlevel% neq 0 (
    if "%*"=="" pause
)
popd
```
`build-playbook.sh` is identical but with `pwsh`.

**So the standard dev build = ZIP .apbx, password malte, live-log injected, no build gate, no ProductCode.** Release builds (CI) additionally keep `Verification`? No — see below.

### 7.3 CI `.github/workflows/apbx.yaml` (release path)

- Triggers: push touching `src/**` or `**/*.yaml|.yml`; manual dispatch.
- Steps: (1) `yamllint -d "{extends: relaxed, rules: {empty-lines: disable, line-length: disable, new-line-at-end-of-file: disable, trailing-spaces: disable, new-lines: {type: platform}}}" .` (2) If `src/sxsc/*.yaml` changed (or `src/sxsc/regenAllConfigs` marker file exists): clone `https://github.com/Atlas-OS/sxsc`, copy configs, `pip install -r requirements.txt`, `make-cert.ps1` (self-signed cert), for each config: `python sxsc.py` → `start-build.ps1 -Thumbprint` → copy resulting `.cab` into `src/playbook/Executables/AtlasModules/Packages/`, then **commit+push the CABs back to the repo** as "feat: auto-update CAB packages". (3) Build playbook: `& ..\dependencies\local-build.ps1 -ReplaceOldPlaybook -AddLiveLog -Removals Verification, WinverRequirement -FileName "Atlas Playbook <sha8>"` — note **release builds strip ProductCode (Verification) and the SupportedBuilds gate in the artifact too**, but the pushed repo keeps them. (4) Artifact `src/release-zip/*` (the .apbx is moved into release-zip).

---

## 8. `src/sxsc/` and `src/sxsc-disabled/` — component-store removal packages

- `sxsc` = echnobas' component-store CAB generator (`src/sxsc/sxsc GitHub page (echnobas).url` → https://github.com/echnobas/sxsc). YAML configs list Windows **component-store components** to be superseded by an Atlas-owned "update" package with a huge version (`38655.38527.65535.65535`) so Windows Update always considers the removal newer.
- Files (line counts): `Atlas-Defender-Remover.yaml` (344) + `-Arm.yaml` (398) → package `Z-Atlas-NoDefender-Package` v5.0.0.0; `Atlas-NoTelemetry.yaml` (181) + `-Arm.yaml` (190) → `Z-Atlas-NoTelemetry-Package` v5.0.0.0.
- `Atlas-NoTelemetry.yaml` covers ~60 components: Feedback engines (Microsoft-OneCoreUAP-Feedback-*, Microsoft-Windows-Feedback-*), telemetry (Application-Experience-AIT-Static/AppInv/Core-Inventory-Service, Compat-Appraiser*, CompatTelRunner*, GeneralTel, Compatibility-Aggregator, TelemetryClient (amd64+wow64), Unified-Telemetry-Client* incl. AutoLogger/Decoder-Host/Settings-WindowsClient/WoWOnly, PlatformTelemetryClient, DataCollection-Adm, DeviceCensus-Schedule-ClientServer, KeyboardDiagnostic, MediaFoundationAggregator, PwdlessPlat-Aggregator, SetupPlatform-Telemetry-AutoLogger, SettingsHandlers-SIUF, Update-Aggregators, InputCloudStore). Commented-out entries show care: Bluetooth-Telemetry breaks Bluetooth; DeviceCensus needed for PcaSvc compat.
- `Atlas-Defender-Remover.yaml` removes all `Windows-Defender-*` components (AM-Engine, AM-Sigs, Branding, Events, Global-Config, Group-Policy, Management-MDM/Onecore/Powershell/V1, Offline-Amcore, ApplicationGuard, SecurityCenter, ~45 entries total incl. `Microsoft-Windows-DeviceManagement-*` ADMX definitions).
- Schema: `copyright`, `package` (name), `target_arch` (amd64/arm64), `version`, `updates:` list of `{target_component, target_arch, version}` (+ optional `files:` with `{file, destination, operation: replace, text}` for payload replacement).
- Installed/uninstalled at runtime by `packageInstall.ps1` (must run as TrustedInstaller/S-1-5-18; supports safe-mode reboot flow). NoTelemetry is installed on ALL installs; NoDefender only when `defender-disable`.
- `sxsc-disabled/Atlas-Misc.yaml` (+Arm): `Z-Atlas-Misc-Package` v4.0.0.0 with a custom component `Atlas-Settings-Banner-Remover` that REPLACES `SystemSettingsExtensions.dll` in `SystemApps\MicrosoftWindows.Client.Cw5n1h2txyewy\` and rewrites `SettingsExtensions.json` to `{}` — removes the Settings banner/Accounts ads at component level. **Disabled**: not built by CI (CI globs only `src/sxsc/*.yaml`), but `ONED.cmd`'s comment in components.yml ("OneDrive setup in Windows is stripped at a component-level in the miscellaneous package") references this mechanism ⚠️ note: comment may predate disabling the package.

---

## 9. `src/release-zip/` — what ships alongside the playbook

- `Read the Install Guide First!.url` → https://docs.atlasos.net/ (⚠️ UNVERIFIED exact target; file is a `.url` InternetShortcut).
- `Disable Automatic Driver Installation.reg` — a standalone registry merge for users: sets `ExcludeWUDriversInQualityUpdate=1` (4 locations incl. `HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate`), `PreventDeviceMetadataFromNetwork=1`, `SearchOrderConfig=0`, `DontSearchWindowsUpdate=1`.
- The CI moves the built `.apbx` into this folder and uploads the whole directory as the release artifact.

---

## 10. Full tweak catalog (ground truth = YAML files)

### 10.1 Services — `!service:` actions (all in `atlas/services.yml` except noted)

| Service | Start type | Notes |
|---|---|---|
| OneSyncSvc | 4 (Disabled) | MS 'OK to disable' |
| TrkWks | 4 | ditto |
| PcaSvc | 4 | ditto |
| DiagTrack | 4 | + stopped in `disallow-data-collection.yml` |
| diagnosticshub.standardcollector.service | 4 | MS 'Do not disable' |
| WerSvc | 4 | ditto |
| wercplsupport | 4 | MS 'No guidance' |
| UCPD | 4 | ditto (also a wizard Requirement to disable driver first) |
| **Drivers:** GpuEnergyDrv, NetBT, Telemetry | 4 | NetBT re-enabled by File Sharing toggle |

Other service manipulation outside `!service:`: `DISABLENOTIFS.cmd` (install-time) stops/disables/deletes `WpnService` + `WpnUserService*` (restored at end via `ENABLENOTIFS.cmd`); `ONED.cmd` deletes OneDrive tasks; AtlasDesktop toggles manage LanmanWorkstation (SMB), fdPHost/FDResPub (Network Discovery), NetBT, Spooler (Printing), bthserv (Bluetooth), NVidia Display Container LS, SuperFetch (SysMain) — with enable/disable pairs; `setSvc.cmd` used by Toolbox scripts; `Disable File Sharing` wrapper disables LanmanWorkstation-dependents; `w32time` STARTED in config-time.yml.

### 10.2 Scheduled tasks

Disabled (`tweaks/debloat/disable-scheduled-tasks.yml` + `performance/disable-sleep-study.yml`): `\Microsoft\Windows\Application Experience\PcaPatchDbTask`, `\Microsoft\Windows\AppxDeploymentClient\UCPD velocity`, `\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector`, `\Microsoft\Windows\Customer Experience Improvement Program\Consolidator`, `...\UsbCeip`, `\Microsoft\Windows\Flighting\FeatureConfig\UsageDataReporting` (+ registry removal from UBPM automatic maintenance), `\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem`. Enabled: `\Microsoft\Windows\DiskCleanup\SilentCleanup` (config-storage-sense.yml). Created: `Force Timer Resolution` (logon, SYSTEM, SetTimerResolution 5060 = 0.5ms), `TaskBarPins(Default)` (logon), `LibreWolf WinUpdater (<user>)` (7h+logon). Deleted: OneDrive Reporting/Standalone Update tasks (ONED.cmd).

### 10.3 AppX removals (`atlas/appx.yml`, all `type: family` unless noted)

`MicrosoftTeams*`, `MSTeams*` (24H2 Teams; both preceded by `!taskKill`), `Microsoft.Copilot*`, `Clipchamp.Clipchamp*`, `Disney.37853FC22B2CE*`, `SpotifyAB.SpotifyMusic*`, `Microsoft.549981C3F5F10*` (Cortana), `Microsoft.XboxApp*`, `microsoft.windowscommunicationsapps*` (Mail/Calendar), `Microsoft.MSPaint*` (Paint 3D), `Microsoft.Getstarted*` (Tips), `Microsoft.ZuneVideo*`, `MicrosoftCorporationII.MicrosoftFamily*`, `Microsoft.MixedReality.Portal*`, `Microsoft.Windows.DevHome*`, `Microsoft.BingWeather*`, `Microsoft.BingNews*`, `Microsoft.BingSearch*`, `Microsoft.OutlookForWindows*`, `Microsoft.GetHelp*`, `Microsoft.Microsoft3DViewer*`, `Microsoft.MicrosoftOfficeHub*`, `Microsoft.MicrosoftSolitaireCollection*`, `Microsoft.MicrosoftStickyNotes*`, `Microsoft.Office.OneNote*`, `Microsoft.People*`, `Microsoft.PowerAutomateDesktop*`, `Microsoft.ScreenSketch*` (option `remove-snipping-tool`), `Microsoft.SkypeApp*`, `Microsoft.Todos*`, `Microsoft.WindowsAlarms*`, `Microsoft.WindowsCamera*`, `Microsoft.WindowsFeedbackHub*`, `Microsoft.WindowsMaps*`, `Microsoft.WindowsSoundRecorder*`, `Ink.Handwriting.Main.Store.en-US1.0`, `Microsoft.MicrosoftEdge_8wekyb3d8bbwe` (option `uninstall-edge`, components.yml). `Microsoft.YourPhone*` removed via raw PowerShell (AME appx action causes Cross Device Experience Host reinstall issues). Then a deprovision diff: pre-removal `Get-AppxPackage` family-name list saved to `AtlasModules\AtlasPackagesOld.txt`, post-removal diff keys created under `HKLM:\...\Appx\AppxAllUserStore\Deprovisioned\<family>` → prevents reinstall on updates. Cache clears: `*MicrosoftWindows.Client.CBS*`, `*Microsoft.Windows.Search*`, `*Microsoft.Windows.SecHealthUI*`, plus `Microsoft.Windows.StartMenuExperienceHost*` (config-start-menu.yml).

### 10.4 Key registry changes by category (selection; ~410 `!registryValue` total)

- **Telemetry/privacy**: `AllowTelemetry=0` + `MaxTelemetryAllowed=0` (HKLM Policies\DataCollection ×2 incl. Wow6432Node), `AllowDeviceNameInTelemetry=0`, DiagTrack `ShowedToastAtLevel=1`, EventTranscript off, autologger `Diagtrack-Listener Start=0` + ETL deletion; ConsentStore Deny for appDiagnostics/location/userAccountInformation (+userNotificationListener during install); NoInstrumentation=1 (Start MFU); `DisableInventory`/activity feed/tracking values across privacy/*; Recall disabled via AtlasDesktop toggle; `POWERSHELL_TELEMETRY_OPTOUT=1` (setx); NVIDIA/Office telemetry values.
- **Performance**: `SystemResponsiveness=10` (MMCSS), `Win32PrioritySeparation=38` (0x26), `SvcHostSplitDisable=1` for all non-Xbox services, `fsutil behavior set disablelastaccess 1`, `fsutil 8dot3name set 1`, FTH `Enabled=0` (x64 only) + `rundll32 fthsvc.dll,FthSysprepSpecialize`, background apps off (`GlobalUserDisabled=1`, `BackgroundAppGlobalToggle=0`), Game Bar off, automatic maintenance config, `HiberbootEnabled=0` (fast startup off).
- **Windows Update** (`tweaks/qol/windows-update/`): auto-updates via AtlasDesktop `AUOptions=2` policy (option-gated); `disable-feature-updates`, `disable-insider`, `disable-msrt-telemetry`, `disable-auto-reboot`, `disable-delivery-optimization`, `disable-nagging`; DevHome/Outlook OOBE reinstall blockers (`UScheduler*` keys with `workCompleted=1`).
- **QoL/UI**: old context menu CLSID `{86ca1aa0-...}\InprocServer32`=""; taskbar tweaks (End task, hide Task View/Meet Now/Widgets/Copilot/Chat, taskbar left, desktop peek off); `cmd-win-x`; visual effects (`UserPreferencesMask=9012038010000000` REG_BINARY, `VisualFXSetting=3`...); Explorer (compact mode, open-to-ThisPC, no Gallery, classic search, extend cache, remove shortcut text, check boxes off...); `enable-long-paths`; menu delay 0; aero shake off; UAC secure desktop off (`consentPromptBehaviorAdmin`…); shortcut icon/text toggles; `bcdedit /timeout 10`, `bootmenupolicy legacy`; old flyouts; wallpaper quality; mouse accel off (`MouseSpeed=0`…); spell check off.
- **Security**: `RestrictAnonymousSAM=1`, `RestrictAnonymous`/SMB anonymous enumeration limits, remote assistance off, `DisableUACSecureDesktop`, WPBT off (`disable-wpbt`), crash control QoL, core isolation option-gated, mitigations option-gated, Defender optional.
- **Debloat**: ContentDeliveryManager all-zero (SubscribedContent-338387/88/89/93/338393/353694/353696, SystemPaneSuggestions, SoftLanding, RotatingLockScreenOverlay...), reserved storage off (`disallowed` via DISM ⚠️ see disable-reserved-storage.yml for exact mechanism), Storage Sense config, hidden Settings pages (`SettingsPageVisibility hide:...`), Smart App Control `VerifiedAndReputablePolicyState=0`.
- **Networking**: SMB `DisableBandwidthThrottling=1`, LLMNR disable (file exists but task commented out in tweaks.yml "Needed for compatibility"), Atlas network defaults via `9. Troubleshooting\Network\Reset Network to Atlas Default.cmd`, NIC bindings stripped (`Disable-NetAdapterBinding -ComponentID ms_msclient, ms_server, ms_lldp, ms_lltdio, ms_rspndr`).
- **Branding/OEM**: `OEMInformation` Manufacturer="Atlas Team", Model="Atlas Playbook vX", SupportURL=discord, `RegisteredOrganization`, `bcdedit /set description "AtlasOS 11 v..."`.

### 10.5 `tweaks.yml` order (root of ~180 tweak files)

Category order with `!writeStatus` markers: Networking → Performance (+system) → Privacy (+apps/advertising/cloud/telemetry) → QoL (root + appearance + windows-update + ease-of-access + taskbar + explorer + context-menus + security + shell + startup-shutdown + system) → Security → Debloat → Scripts → Misc. Notable commented-out (disabled) tasks: `disable-llmnr.yml` ("Needed for compatibility"), `disable-game-bar.yml`, `disable-paging.yml` ("no evidence it helps (likely placebo)"), `disable-folders-this-pc.yml`, `force-end-shutdown-apps.yml` ("It confused people"), `enable-verbose-messages.yml`. `script-power.yml` deliberately runs LAST among script tasks ("Done last on purpose"), followed by enable-notifications + OEM info.

---

## 11. Version / edition handling

- **Build gate**: ONLY `<SupportedBuilds>26100, 26200</SupportedBuilds>` in playbook.conf (UBR-agnostic — any 26100.x passes). AME Wizard refuses to run on other builds (the "Winver requirement" that `local-build.ps1 -Removals WinverRequirement` strips for testing). No 26H2 (27xxx) support today.
- **In-YAML build conditions**: `builds: ['>=22000']`, `['>22000']`, `['<22000']` used in 17 files (mostly Win10-vs-Win11 UI differences, Recall, Copilot, taskbar items). Engine supports `>=,<=,>,<`, `!` negation, and `build.ubr` precision — none of the Atlas files currently pin UBR.
- **Upgrades**: `<UpgradableFrom>0.4.1</UpgradableFrom>` + `<AllowUnsupportedUpgrades>false</AllowUnsupportedUpgrades>`; upgrade-only actions (`onUpgrade: true`): old-folder cleanup, revert.yml, DEFAULT.ps1, theme MRU; fresh-only (`onUpgrade: false`): services/components/appx/start(DISM/software) backups, pfp. Re-running same version re-triggers only `onUpgrade: false` actions (docs).
- **Editions (Home vs Pro)**: **no edition-specific logic exists anywhere in the playbook source** (no `Edition`/`Professional`/`Core` gating; rg over playbook.conf + Configuration returns nothing edition-related). All tweaks are edition-agnostic; group-policy-style registry values used work on Home via direct registry writes. `<ISO><DisableHardwareRequirements>true` handles ISO-injection on unsupported hardware, not editions. Atlas docs FAQ may discuss editions, but the playbook does not branch on them (verified).
- **Arch**: amd64 + arm64 both handled (ARM: ViVeTool-ARM64CLR, ARM CABs, `cpuArch:` gates, ARM64-only file deletions).

---

## 12. docs.atlasos.net skim (accessed 2026-10-07, via page_reader + curl)

- `https://docs.atlasos.net/getting-started/installation/` — "Atlas Playbook 0.5.0-hotfix" versioned docs. Two paths: **Fresh Install** (Atlas ≤ v0.4.0, or Windows 10) and **Update Current Install** (requires Atlas v0.4.1 on Win11 24H2). Site licensed CC-BY-SA-4.0.
- `https://docs.atlasos.net/post-install/atlas-folder/` — "Atlas Folder" page currently **"TBD"** (docs lag the source). Subpages exist: configuration (Background Apps, Bluetooth, Diagnostics, Driver Updates, FSO/Game Bar, Game Mode, HAGS, Lanman Workstation, Network Discovery/File Sharing/Navigation Pane, Notifications, Power (CPU Idle/Hibernation/Power Saving/Timer Resolution), Printing, Search Indexing, Start Menu, System Restore, VPN, Visual Effects), security (Mitigations, Defender, Core Isolation, UAC, Firewall), optional-tweaks (Alt-Tab, Delivery Optimization, Explorer customization, Lock Screen, context menus, Explorer Patcher), advanced-configuration, windows-settings. ⚠️ Docs describe an OLDER folder layout ("3. Configuration", ".reg"-based toggles) than the v0.5.0 source ("3. General Configuration", ".cmd"-based toggles) — trust the repo, not the docs, for current naming.
- Sitemap also includes `faq/general-faq/atlas-folder-missing/` (restore guide), `post-install/software/*` (browser comparisons etc.).

---

## 13. What UltraOS should COPY vs IMPROVE (recommendations to build fleet)

### Copy (proven mechanics)
1. **Root-file structure**: `custom.yml` → `atlas/*` core stages → `tweaks.yml` category runner with `!writeStatus` progress markers; per-topic tiny YAML files (easy to audit/toggle, exactly what build agents can generate).
2. **Default-user hive technique**: load `C:\Users\Default\NTUSER.DAT` as `HKU\AME_UserHive_Default` at start; `APPLYDUHIVE.ps1`-style mirror of every HKCU path at end; `newUsers.ps1` RunOnce for per-user dynamic tweaks. This is how HKCU tweaks survive for new users.
3. **The `HKLM\SOFTWARE\AtlasOS\Services\<Name>` state-marker + `(default).cmd` toggle-folder pattern** with `/silent` and `/noAction` conventions — gives users post-install toggles AND lets the playbook reuse the exact same scripts (`DEFAULT.ps1` re-runs all defaults on upgrade).
4. **Option plumbing**: RadioPage/CheckboxPage/RadioImagePage `<Name>`s → `option:`/`'!option'` gating (incl. file-level). Keep `DependsOn` for cascading pages. Negation and `&`/`options` array semantics are free.
5. **AppX deprovision diff trick** (save PackageFamilyName list before removal; create `Deprovisioned` keys for the diff) to stop app reinstall on feature updates; `clearCache` for CBS/Search/SecHealthUI/StartMenuExperienceHost.
6. **Upgrade path**: `UpgradableFrom` + `onUpgrade` true/false split + `revert.yml` pattern for old-version cleanup.
7. **`builds:`/`cpuArch:`/`iso:`/`oobe:` gating** exactly as Atlas uses them; `handleExitCodes: {"!0": halt}` on critical copy operations.
8. **Build pipeline**: local-build.ps1 clone (ZIP, password `malte`, -AddLiveLog live-log injection, Removals for test builds, OEM version substitution); yamllint relaxed config in CI; artifact via release-zip folder.
9. **Security framing**: requirements (DefenderToggled, NoAntivirus, NoPendingUpdates, UCPDDisabled, PluggedIn, Internet), honest "at your own risk" docs, defaults that keep Defender ON.

### Improve (UltraOS differentiators)
1. **Presets**: Atlas forces ~identical defaults + 5 binary choices. UltraOS should map Safe/Balanced/Extreme presets onto the same `option:` mechanism — e.g. a RadioPage choosing `preset-safe|preset-balanced|preset-extreme` plus per-module checkboxes; note the engine's upgrade option-memory pitfall (renamed options re-trigger onUpgrade).
2. **26H2 support**: set `<SupportedBuilds>` to the 26H2 build(s) (expected 27xxx ⚠️ UNVERIFIED exact build number — confirm with T1 recon) and add `builds:` guards where 24H2/25H2/26H2 behavior differs. This is UltraOS's headline gap vs Atlas.
3. **Rollback**: Atlas explicitly does NOT support rollback (CLEANUP.ps1 deletes restore points: "a full Windows reinstall is required"). UltraOS wants rollback support → before destructive actions, export service/appx/registry backups (Atlas already writes `winServices.reg`/`atlasServices.reg` — extend to full backup folder + a "Revert" task file with inverse operations). Do NOT delete restore points; consider a system checkpoint instead.
4. **Post-run report**: Atlas only shows live log. UltraOS can have final `!powerShell` write an HTML/TXT report (options chosen, actions succeeded, services changed, reboot required).
5. **Speed**: Atlas runs mostly serial with `weight` only for progress. UltraOS can: parallelize independent downloads inside scripts (SOFTWARE.ps1 is serial), use `!download` action where possible, and set precise `weight`s so progress% is honest.
6. **Home vs Pro**: opportunity to add edition-conditional tweaks (e.g. skip gpedit-dependent values on Home, or add Home-appropriate equivalents) — Atlas has none.
7. **Housekeeping observations**: Atlas quirks worth avoiding — `auto-updates-default` option wired to nothing (confusing), docs-folder naming drift vs source, `sxsc-disabled` Misc package referenced by stale comments, DEFAULT.reg duplicates marker keys per toggle (keep single source of truth), `!task` paths use backslashes (fine, but keep consistent for yamllint), duplicated `Deprovisioned\Microsoft.MicrosoftEdge...` registryKey lines in components.yml (lines 28-29 — likely a typo'd duplicate of `.Stable_` vs non-Stable; verify before copying).
8. **Verification**: to ship verified, UltraOS must obtain a `ProductCode` from Ameliorated and ship a 256px `playbook.png` (see docs.amelabs.net/developers/verification.html). Until then strip `<ProductCode>` in builds (like Atlas CI does).

---

## Appendix: Source file inventory used for this dossier
- `/home/z/my-project/repos/atlas/src/playbook/playbook.conf` (full read)
- `/home/z/my-project/repos/atlas/src/playbook/Configuration/` — read: custom.yml, tweaks.yml, atlas/{start,services,components,appx,default,revert}.yml, tweaks/privacy/{disable-user-tracking,config-app-permissions,disable-recall-snap}.yml, tweaks/privacy/telemetry/disallow-data-collection.yml, tweaks/performance/{disable-background-apps,config-mmcss,disable-fth,disable-sleep-study}.yml, tweaks/performance/system/{win32-priority-separation,disable-service-host-split,optimize-ntfs}.yml, tweaks/networking/atlas-network-settings.yml, tweaks/networking/shares/disable-smb-bandwidth-throttling.yml, tweaks/debloat/{disable-scheduled-tasks,config-content-delivery}.yml, tweaks/qol/{bcdedit-tweaks,visual-effects,set-hidden-settings-pages,config-powershell,config-start-menu}.yml (partial), tweaks/qol/taskbar/{disable-copilot,end-task,config-pins}.yml (grep), tweaks/qol/shell/restore-old-context-menu.yml, tweaks/qol/explorer/import-power-plan.yml, tweaks/qol/appearance/atlas-theme.yml, tweaks/qol/windows-update/disable-auto-updates.yml, tweaks/scripts/{script-power,script-mitigations,script-core-isolation,script-file-associations,script-devices,script-pfp,script-backup2,script-clientcbs,script-ngen}.yml, tweaks/misc/{create-shortcuts,config-oem-information,config-time,make-measuresleep-admin,rebuild-perf-counters,enable-notifications,add-newUser-script,delete-windows-specific-files}.yml
- `Executables/`: APPLYDUHIVE.ps1, ASSOC.ps1 (partial), BACKUP.ps1, CLEANUP.ps1, CLIENTCBS.ps1, DEFAULT.ps1, DEFAULT.reg (paths), DISABLENOTIFS.cmd, DISABLEPNP.ps1, LIBREWOLF.ps1, NGEN.ps1, ONED.cmd, PFP.ps1, SETPATHS.ps1, SETTABST.ps1, SHORTCUTS.ps1, SOFTWARE.ps1, STARTMENU.ps1, STOPFOLDERPROC.ps1, TASKBARPINS.ps1 (partial), Themes/, AtlasModules/{README.md, initPowerShell.ps1, Scripts/packageInstall.ps1 (partial), ScriptWrappers/{DisablePowerSaving,ToggleDefender,RemoveEdge(header)}.ps1, Modules/AllRegistryUsers/AllRegistryUsers.psm1, Other/Force Timer Resolution.xml, Packages/}, AtlasDesktop/ tree + quoted toggle cmds
- Build: `src/dependencies/local-build.ps1`, `src/playbook/build-playbook.{sh,cmd}`, `.github/workflows/apbx.yaml`
- `src/sxsc/*.yaml` (full NoTelemetry, Defender-Remover partial), `src/sxsc-disabled/Atlas-Misc{,-Arm}.yaml`, `src/release-zip/*`, root `README.md`, `src/README.md`
- Engine (verification of YAML semantics): `/home/z/my-project/repos/trusted-uninstaller-cli/TrustedUninstaller.Shared/Tasks/TaskAction.cs`, `Tasks/UninstallTask.cs`, `AmeliorationUtil.cs`, `Actions/*.cs` aliases, `ProcessPrivilege.cs`
- Web (2026-10-07): docs.atlasos.net/getting-started/installation/ (page_reader), docs.atlasos.net/sitemap.xml, docs.atlasos.net/post-install/atlas-folder/{,configuration,security,optional-tweaks}/ (curl); docs.amelabs.net/developers/{getting-started/creation, configuration, tasks, requirements, verification, upgrades, actions/PowerShell, actions/Service, actions/Appx, actions/Task}.html (curl)
