# AME Wizard Playbook Authoring Specification — UltraOS T1-c Dossier

**Agent:** T1-c (format spec) | **Date:** 2026-10-07 | **Status:** COMPLETE
**Purpose:** The authoritative reference manual for building the UltraOS .apbx playbook. Build agents (T3-*) code against this document.

**Primary sources (all accessed 2026-10-07):**
- **ENGINE** = `github.com/Ameliorated-LLC/trusted-uninstaller-cli`, cloned at `/home/z/my-project/repos/trusted-uninstaller`, latest commit `f325e9d` (2026-02-11, **"Update to v0.8.4"** — engine version `Globals.CurrentVersion = "0.8.4"`, MIT license). The AME Wizard GUI is closed-source but *embeds this engine as its backend*; the YAML/XML formats below are parsed by this code.
- **DOCS** = `https://docs.amelaborated` → **https://docs.amelabs.net** (developer section `/developers/...`, 25 pages crawled; all archived as text in `/tmp/amedocs/*.txt`).
- **ATLAS** = Atlas-OS/Atlas playbook source at `/home/z/my-project/repos/atlas/src/playbook/` (v0.5.0, SupportedBuilds 26100+26200) — the real-world reference implementation.
- Quoted snippets are verbatim from these sources. Anything uncertain is marked ⚠️ UNVERIFIED.

---

## 1. Playbook package layout

An .apbx is a **renamed, password-protected archive (password `malte`)** containing a single root-level playbook folder structure. The wizard/CLI extracts it, then reads `playbook.conf` + `Configuration\*.yml`.

```
Playbook (archive root — files at top level of the zip, NOT nested in a folder)
├── playbook.conf          # XML metadata (required) — see §2
├── playbook.png           # optional icon, 256px wide, shown in wizard UI (verified badge also uses it)
├── Images/                # RadioImagePage option icons (128px-high .png) + Software Package icons
│   └── brave.png, firefox.png, ...
├── Configuration/         # YAML task tree (required; CLI errors if empty: "Configuration folder is empty, put YAML files in it and restart the application.")
│   ├── main.yml           # entry point — engine falls back to custom.yml if main.yml absent
│   └── ...arbitrary subfolders of task YAML (Atlas uses atlas/, tweaks/, tweaks/qol/...)
└── Executables/           # scripts/binaries referenced by !run/!cmd/!powerShell with exeDir:true
```

**Engine entry-point resolution** (ENGINE `AmeliorationUtil.RunPlaybook`, lines 775–777):
```csharp
List<ITaskAction> actions = ParseActions($"{Playbook.Path}\\Configuration", isoBuild, isoUpdateBuild, isoArch, Playbook.Options,
    File.Exists($"{Playbook.Path}\\Configuration\\main.yml") ? "main.yml" : "custom.yml", upgradingFrom);
```
If no applicable actions parse, it throws `SerializationException("No applicable tasks were found in the Playbook.")`.

**DOCS reference** (`https://docs.amelabs.net/creating_playbooks.html`): "A playbook requires the following hierarchy… playbook.conf / Configuration (main.yml + Tasks/) / Executables". Docs recommend archiving with **7z format**; Atlas CI (`apbx.yaml`, line 124: "Create playbook (ZIP/APBX password is malte)") builds a **password-protected ZIP** — the wizard accepts both (7-Zip-readable, password `malte`). Docs state encryption is to "protect your playbook from being scanned by browsers or antivirus software for executables."

**Reserved location:** the engine also extracts itself and helper tools next to its own exe (`ame-assassin/`, `ProcessHacker/`), not into the playbook dir. Playbooks are copied to `%ProgramData%\AME\OOBE\Playbook` only in ISO mode.

---

## 2. `playbook.conf` XML reference (complete)

Parsed by `XmlSerializer(typeof(Playbook))` (ENGINE `AmeliorationUtil.DeserializePlaybook`), class `TrustedUninstaller.Shared.Playbook : XmlDeserializable` (ENGINE `Playbook.cs`). **Go beyond Atlas: the class defines every property the wizard understands.**

### 2.1 Top-level elements (element = property; XML is case-insensitive via XmlSerializer)

| Element | Type / default | Req | Meaning (verbatim source evidence) |
|---|---|---|---|
| `Name` | string | ✔ | Playbook name. `Validate()`: cannot contain invalid filename chars (`\ / : * ? < > \|`); rendered width at Segoe UI 14.5pt must be ≤97px ("Playbook Name is too long.") |
| `Username` | string | ✔ | Creator name; width at Segoe UI 13pt ≤100px |
| `Title` | string | ✔ | "Used for the primary pages" (DOCS) |
| `ShortDescription` | string | ✔ | "Used in the Playbooks side-bar" (DOCS) |
| `Description` | string (CDATA) | ✔ | Intro page text (supports `&#xD;&#xA;` newlines / CDATA) |
| `Details` | string | ✔ | "Used in the updates window description box" (DOCS) |
| `Version` | string | ✔ | Formats `1` / `1.0` / `1.0.0`; "0.4 Alpha" style suffix allowed — `VersionNumber.GetVersionNumber()` truncates at first space. Invalid ⇒ `XmlException "Improper version format"` |
| `UniqueId` | GUID | ✔* | UUIDv4. `Validate()`: must not be `Guid.Empty` ("UniqueId must be unique… Use an online UUIDv4 generator"). If omitted entirely, applied-playbook tracking falls back to Name+Username match + numbered folders under `%ProgramData%\AME\AppliedPlaybooks` (max 10 kept) |
| `SupportedBuilds` | string[] (`<string>26100</string>…`) | – | Wizard build gate. Atlas: `26100` (24H2), `26200` (25H2) — **no 26H2 build number known yet; UltraOS must re-verify the 26H2 build ID (likely 26XXX ⚠️ UNVERIFIED) before shipping** |
| `Requirements` | `Requirements.Requirement[]` (`<Requirement>…</Requirement>`) | – | See §2.3 for the full vocabulary (14 names) |
| `FeaturePages` | FeaturePage[] | – | UI pages; see §2.2. XML: `<FeaturePages><RadioPage …>…</RadioPage></FeaturePages>` — `XmlArrayItem` accepts `CheckboxPage`, `RadioPage`, `RadioImagePage` only |
| `Software` | Package[] | – | OOBE software list: `<Package Option="browser-firefox" Local="true" DefaultWebBrowser="true"><Name>firefox</Name><Title>Firefox</Title><Description>…</Description><Icon>firefox.png</Icon></Package>`. Validate: Name/Title/Description/Icon all required. `Icon` = filename inside `Images/`. Used for OOBE visualization + linking `!software`/`!download` via their `package:` key |
| `ProgressText` | string, default `"Deploying the selected Playbook configuration onto the system."` | – | Progress-window text (Atlas wraps in CDATA) |
| `EstimatedMinutes` | int, default `25` | – | ETA shown by wizard UI. Only appears in engine as the property — consumed by the closed-source GUI. Atlas sets `15` |
| `InstallGuide` | string | – | Custom install-doc URL (paired with `FreshInstall` requirement) |
| `Git` | string | – | Update source (GitHub/Gitea/GitLab releases). Also "Source Code" button. Release tag must equal `Version`; release must contain exactly one `.apbx` asset (DOCS /developers/updates.html) |
| `Website` | string | – | Shown on verified-playbook dropdown (DOCS) |
| `DonateLink` | string | – | "Donate" button (DOCS) |
| `ProductCode` | string (int) | – | **Verification code issued by Ameliorated** — verified playbooks show the checkmark. Contact @styris_ame/@actrons on Discord/Telegram (DOCS /developers/verification.html). Atlas ships `64` |
| `PasswordReplace` | string | – | "password to replace Microsoft accounts with after converting them to local accounts" (DOCS) |
| `UpgradableFrom` | string[] (inline items allowed) | – | Values: `"1.0.0"`, range `"1.0.0-2.0.0"`, `"any"`. Engine `IsUpgradeApplicable()` parses all three; invalid ⇒ `XmlException "Invalid 'UpgradableFrom' value … formats: 1.0.0 / 1.0.0-2.0.0 / any"` |
| `AllowUnsupportedUpgrades` | bool?, default `true` | – | Atlas sets `false` to block upgrades from versions not in UpgradableFrom |
| `Overhaul` | bool, default `false` | – | Atlas sets `true`; marks overhaul-class playbooks (affects wizard UX/registry bookkeeping: `Overhaul` value written to `HKLM\SOFTWARE\AME\Playbooks\Applied\{guid}`) |
| `SupportsISO` | bool, default `false` | – | If `true`, `Validate()` REQUIRES `<OOBE>` with exactly 3 BulletPoints, distinct icons (Rocket/Privacy/Lock only), non-empty Title+Description |
| `UseKernelDriver` | bool? | – | `null` = auto-detect (engine enables KPH kernel driver if HVCI off + vulnerable-driver blocklist off + Defender toggles off); `true/false` forces. Only needed for hostile targets (protected processes/services) |
| `ISO` | ISOSettings | – | `<ISO><DisableBitLocker>true</DisableBitLocker><DisableHardwareRequirements>true</DisableHardwareRequirements></ISO>` |
| `OOBE` | OOBESettings | – | `<OOBE><BulletPoints>…3× BulletPoint…</BulletPoints><Internet>Request|Force</Internet></OOBE>` |

### 2.2 FeaturePages (three page types — the wizard's option UI)

Base attributes on every page (class `Playbook.FeaturePage`, XmlAttributes): `DependsOn` (show page only if this option Name from an earlier page was selected), `WindowsVersion` (hide page on other builds — present in class, unused by Atlas, ⚠️ semantics from name only), `IsRequired="true"` (user must interact before continuing), `Description` (page header, DOCS: "length should be between 50 and 85 characters"). Sub-elements: `TopLine` and `BottomLine`, each `[XmlAttribute("Text")]` + optional `[XmlAttribute("Link")]` (clickable hyperlink).

Limits enforced in `Validate()` — **max 4 options per page; ≤2 options if both lines used; ≤3 if either line used; option Names must be unique.**

1. **`<CheckboxPage>`** — options `<CheckboxOption><Text>…</Text><Name>option-name</Name></CheckboxOption>`; extra attrs on option: `IsChecked="false"` (default true = pre-checked), `IsEnabled` (default true). No DefaultOption (checkboxes are independent).
2. **`<RadioPage>`** — page attr `DefaultOption="option-name"` (must match an option Name, else XmlException); options are `<RadioOption>` (Text+Name).
3. **`<RadioImagePage>`** — page attrs `DefaultOption` + `CheckDefaultBrowser="true"` (lets user skip page if a non-Edge browser is already installed). Options `<RadioImageOption>` with `<Text>`, `<Name>`, `<FileName>brave</FileName>` (→ `Images/brave.png`, "128 pixel height for best results"), `<GradientTopColor>#RRGGBB</GradientTopColor>` + `<GradientBottomColor>` (must differ, must not be #FFFFFF/#000000), and `None="true"` for a built-in "None" choice (no Name → selection means "nothing chosen").

Option Names are the **feature vocabulary** referenced from YAML via `option:` / `options:` keys. The full list of all option Names across pages = the wizard's `AvailableOptions` (persisted in the applied-playbooks registry key; used for upgrade `previousOption` logic).

Atlas example (playbook.conf): browser page `<RadioImagePage CheckDefaultBrowser="true" DependsOn="install-another-browser" DefaultOption="browser-brave" …>` with 4 options brave/librewolf/firefox/chrome.

### 2.3 Requirements — full vocabulary (14 names, engine `Requirements.cs` enum + docs)

`<Requirements>` array. Names are XML-enum strings; only these are valid:

| Requirement | Meaning / check (source) |
|---|---|
| `Internet` | `InternetCheckConnection("http://archlinux.org")` then google.com; user must be online |
| `NoInternet` | inverse (enum exists; docs list it) |
| `Activation` | genuine Windows check (`WinUtil.IsGenuineWindows()`; engine treats as handled upstream/"true") |
| `FreshInstall` | `HKLM\…\CurrentVersion\InstallDate` < 40 hours old ("easily bypassable in the UI", docs) — pair with `InstallGuide` |
| `DefenderToggled` | user must turn off the 4 Defender toggles (realtime, SpyNet reporting, sample submission, tamper protection). Wizard prompts interactively |
| `DefenderDisabled` | Defender must be neutralized via the wizard's **"Prepare System"** step; on CLI this triggers `KillAndDisable` + **automatic reboot** (`shutdown /r /t 0`, CLI.cs lines 130–142) after preparation |
| `UCPDDisabled` | UCPD driver `Start==4`; handled via Prepare System (`DisableUCPD`), may also trigger reboot |
| `NoAntivirus` | no non-Defender AV in WMI `root/SecurityCenter2` `AntivirusProduct` (docs); engine currently short-circuits to true |
| `NoPendingUpdates` | WUApiLib search `IsInstalled=0 And IsHidden=0 And Type='Software' And DeploymentAction=*` in a disposable child process (50s timeout); any downloaded update pending ⇒ blocked |
| `PasswordSet` / `LocalAccounts` | user must set password; MS accounts converted to local (PasswordReplace). NOTE: enum collision — `LocalAccounts = 11` and `PasswordSet = 11` share a value in source; use `PasswordSet` |
| `AdministratorPasswordSet` | set built-in Administrator password |
| `PluggedIn` | AC online / charging / no battery (`GetSystemPowerStatus`) |
| `NoTweakware` | enum exists (value 10); no checker in engine ⚠️ UNVERIFIED behavior — likely wizard-side UI warning |

Docs page: https://docs.amelabs.net/developers/requirements.html. Requirements drive wizard gating UI + Prepare System; `DefenderDisabled`/`UCPDDisabled` additionally inject hardcoded registry writes in ISO mode (RunPlaybook lines 638–730: Defender-disable CAB injection via DISM `/Add-Package`, `DisableRealtimeMonitoring=1`, `SpyNetReporting=0`, `SubmitSamplesConsent=0`, `TamperProtection=4`).

---

## 3. Action / YAML task schema (the DSL)

### 3.1 Task-file structure

Every YAML file under `Configuration/` deserializes to class `UninstallTask` (ENGINE `Tasks/UninstallTask.cs`):

```yaml
title: Services and Drivers          # required (docs) — string
description: Configures services…    # optional
actions:                             # list of tagged action maps
  - !task: {path: 'tweaks/foo.yml'}  # include another task file (recursive, relative to Configuration/)
  - !registryValue: {…}
option: 'opt-a'                      # optional gating keys — see §3.3
options: ['a','!b']
builds: ['>=26100','!>26200']        # build gate, supports comparison + '!' negation + '26100.1265' update-build
cpuArch: 'X64'                       # X64|Arm64|X86|Arm (must match System.Runtime.InteropServices.Architecture names)
priority: 1                          # exists in class; unused by execution order ⚠️ (order = file order)
privilege: Admin                     # UninstallTaskPrivilege: Admin|TrustedInstaller (default Admin; informational)
iso: true|false|only                 # task-level ISO gating (default true)
oobe: true|false|only                # task-level OOBE gating (default true)
onUpgrade: true|false                # upgrade gating
onUpgradeVersions: ['>=1.0','!1.2']
previousOption: 'old-option-name'
tasks: [ 'a.yml', 'b.yml' ]          # ← undocumented: alternate key for included task files (maps to Features/Tasks property)
weight: N                            # NOT valid at task level — only on actions
```

The **tag list** is fixed by `TaskActionResolver` + `PlaybookParser` (ENGINE `Parser/TaskActionResolver.cs`). Active tags (15): `!file`, `!service`, `!run`, `!powerShell`, `!cmd`, `!scheduledTask`, `!registryKey`, `!registryValue`, `!appx`, `!systemPackage`, `!taskKill`, `!software`, `!download`, `!writeStatus` (= alias of `!status`), `!task`. Commented-out/disabled in resolver: `!user:`, `!shortcut:`, `!lineInFile:`, `!update:` — classes exist in `Actions/` but are **not registered; do not use**. Docs list the same 15 (docs call `!status` primary, `!writeStatus` legacy).

**Nesting:** `!task` includes are expanded recursively by `ParseActions()`; child filters are evaluated per file AND per action. A file whose filters don't match returns null (skipped).

### 3.2 Universal keys accepted on EVERY action (base class `Tasks.TaskAction`)

| YAML key | Type / default | Meaning |
|---|---|---|
| `weight` | int (per-action default; see table §3.3) | progress-bar contribution: `GetProgressMaximum(actions) = actions.Sum(GetProgressWeight)`; percentage = 1 − remaining/total |
| `status` | string | inline status message (equivalent to preceding `!status` action; engine runs `WriteStatusAction` automatically before the action) |
| `errorAction` | `Ignore`/`Log`/`Notify`/`Halt` | failure policy; overrides the action's default |
| `ignoreErrors` | bool = false | **undocumented in docs** — when true, failed action produces no error record at all |
| `allowRetries` | bool = null | **undocumented in docs** — overrides action's `GetRetryAllowed()` |
| `option` | string | run only if option selected; `!name` = only if NOT selected; docs: also `a&b` AND-composition (cannot mix `&` and `!` — engine throws `YAMLException "YAML options item must not contain both & and !"`) |
| `options` | string[] | any-of (with `!` per-element negation: non-negated must match ≥1 AND all negated must not match) |
| `builds` | string[] | same comparison syntax as tasks (`>=`,`<=`,`>`,`<`,`!`, `22621.1265`); live system uses BuildNumber.UpdateNumber; ISO uses the target image build |
| `cpuArch` | string | e.g. `X64`, `Arm64` (case-insensitive compare against `SystemArchitecture.ToString()`; `!` negation allowed) |
| `onUpgrade` / `onUpgradeVersions` / `previousOption` | — | upgrade semantics (docs /developers/upgrades.html): `previousOption: ignore` bypasses option-diff logic; same-version re-run triggers ONLY `onUpgrade:false` actions unless current version listed in `onUpgradeVersions` |
| `iso` | `true/false/only`, default `false` (per-action defaults differ: `!download`/`!software` default `iso: true`) | ISO-injection gating. Engine rejects ISO-incompatible actions when `iso != false`: `!cmd`, `!run`, `!powerShell`, `!taskKill`, `!systemPackage`, `!appx`(non-ISO path), `!software` with `iso: only` → SerializationException at parse time (e.g. "For safety reasons, CmdAction does not support iso.") |
| `oobe` | `null/true/false/only`, default null | OOBE gating; null = run in OOBE unless `iso: true/only` |

### 3.3 Every action type — exact keys (source-verified)

Defaults in **bold** = engine property initializers.

**`!file:` FileAction** — delete file/dir/tree.
- `path` (req; env vars expanded; wildcards `*` allowed in LAST segment only — "Parent directories to a given file filter cannot contain wildcards."); ISO mode rewrites `C:` → WIM mount root and deletes inside the image via `WimInstance.DeleteFileOrFolder`.
- `prioritizeExe` (**false**) — in wildcard deletion, delete `.exe` files first; `useNSudoTI` (**false**) — delete via `NSudoLC.exe -U:T -P:E -M:S -Priority:Realtime cmd /c del/rmdir` (TrustedInstaller context).
- `weight` **2**. Retryable. Hardcoded behavior: kills locking processes (loops up to 8×100ms using `WhoIsLocking`), skips killing `TrustedUninstaller.CLI` / `ame?wizard`, kills MsMpEng/NisSrv/SecurityHealthService/smartscreen for Defender file list, stops+deletes `.sys` driver services (ServiceInstaller + ProcessHacker when kernel driver enabled), falls back to `takeown /f … /r /d Y & icacls … /grant Administrators:F`, then `rmdir /Q /S`.

**`!service:` ServiceAction** —
- `name` (req; wildcard `*xxx`/`xxx*`/`*xxx*` matches service name case-insensitively; `device: true` (**false**) searches driver devices instead), `operation` (**`delete`**) ∈ `stop|continue|start|pause|delete|change`, `startup` (int 0–4, required for `change`: 2=Auto,3=Manual,4=Disabled — docs list 2/3/4), `deleteStop` (**true**), `deleteUsingRegistry` (**false**; deletes `HKLM\SYSTEM\CurrentControlSet\Services\{name}` key — "bypass the permissions of a given service"), `weight` **4**.
- `change` = writes `Start` REG_DWORD via RegistryValueAction (`Set` op). Never kills `DcomLaunch` (RegexNoKill). Delete: stops dependents (5s waits) → ServiceInstaller.Uninstall → ProcessHacker delete if kernel driver. ISO: only `delete`/`change` allowed ("ServiceAction only supports Delete and Change operations with iso.").
- Atlas usage (services.yml): `!service: {name: 'DiagTrack', operation: change, startup: 4}`.

**`!run:` RunAction** — run a process.
- `exe` (req; resolved against `path:` dir if given, else `exeDir:` (Playbook's `Executables\`), else `baseDir:` (engine CWD), else PATH), `args`, `runas` (**`trustedInstaller`**) ∈ `trustedInstaller|system|currentUser|currentUserElevated|currentUserTrustedInstaller` (last one source-only, not in docs), `wait` (**true**), `timeout` (ms; kills process + `TimeoutException "Executable run timeout exceeded."`), `createWindow` (**false**), `hideWindow` (**false**; session-0 isolation), `showOutput`/`showError` (**true**), `handleExitCodes` (dict), `weight` **5**. NOT ISO-compatible.

**`!powerShell:` PowerShellAction** — `command` (req), `runas` (**trustedInstaller**), `exeDir` (**false**; working dir = `Playbook.Path\Executables`), `wait` (**true**), `timeout`, `handleExitCodes`, `weight` **1**. Invoked as `PowerShell.exe -NoP -ExecutionPolicy Bypass -NonInteractive -C "{Command}"`. NOT ISO-compatible. (Multi-line YAML `command: |` blocks are standard — Atlas uses them everywhere.)

**`!cmd:` CmdAction** — `command` (req) via `cmd.exe /C`, `runas` (**trustedInstaller**), `exeDir`, `wait` (**true**), `timeout`, `handleExitCodes`, `weight` **1**. Special: commands starting with `start ` skip output redirection (.NET bug workaround, commented in source). NOT ISO-compatible.

**`!registryKey:` RegistryKeyAction** — `path` (req; hive prefix `HKLM/HKCU/HKCR/HKU/HKEY_*`), `operation` (**`delete`**) ∈ `delete|add`, `scope` (**`allUsers`**) ∈ `allUsers|currentUser|activeUsers|defaultUser` (only meaningful for HKCU: enumerates `HKEY_USERS\S-*` hives; `allUsers` also hooks `AME_UserHive_*` offline hives; `defaultUser` targets `AME_UserHive_Default`), `weight` **1**. HKCU default behavior: **applies to every local profile hive** (docs note). Delete falls back to Win32 `RegDeleteKeyEx` tree walk, then to a copied `reg.exe` (`%TEMP%\AME\amereg.exe`) on `UnauthorizedAccessException`.

**`!registryValue:` RegistryValueAction** — `path` (key), `value` (name), `data`, `type` ∈ `REG_SZ|REG_MULTI_SZ|REG_EXPAND_SZ|REG_DWORD|REG_QWORD|REG_BINARY|REG_NONE|REG_UNKNOWN`, `operation` (**`add`**) ∈ `add|delete|set` — **`set` = only modify if the value already exists** (source comment: "This indicates to skip the action if the specified value does not already exist"), `scope` (**allUsers**), `weight` **1**.
- Data encodings (source-verified): DWORD accepts unsigned (e.g. `2962489444`, handled via unchecked cast); **REG_MULTI_SZ uses literal `\0` separators** (`Data.ToString().Split(new[]{"\\0"})`); **REG_BINARY = hex string** (`StringToByteArray`, e.g. `data: '001A'`); REG_EXPAND_SZ data is expanded when compared; empty string data = empty array for MULTI_SZ.

**`!appx:` AppxAction** (internal class, active tag) — `name` (req; wildcard both sides), `type` (**`family`**) ∈ `family|package|app`, `operation` (**`remove`**) ∈ `remove|clearCache`, `verboseOutput` (**false**), `unregister` (**false**; NOTE source bug: `unregister` adds `-Verbose` arg, not an unregister flag — it's effectively decorative ⚠️), `weight` **30**. Live execution = **`ame-assassin.exe -Family|-Package|-App "name" [-Verbose] [-UseKernelDriver]`** or `-ClearCache "name"`. ISO mode: deletes folders under `WindowsApps`/`SystemApps` + rewrites AppxManifest.xml to strip `<Application Id=…>` entries. Canonical cache-clear trio (docs+Atlas): `*Client.CBS*`, `*StartMenuExperienceHost*`, `*Windows.Search*`.

**`!systemPackage:` SystemPackageAction** — removes an OS component by manifest name via `ame-assassin.exe -SystemPackage "name" -Arch {arch} -Language "{lang}" [-xf regex -xdependent dep] [-UseKernelDriver]`. Keys: `name` (req), `arch` (**`all`**) ∈ `amd64|wow64|x86|msil|all`, `language` (**`*`**; e.g. `neutral`), `regexExcludeFiles` (string[]; `-xf`), `excludeDependents` (string[]; `-xdependent`), `weight` **15**. Docs examples: `{name:'Microsoft-Windows-CoreSystem-Bluetooth-Telemetry',arch:amd64,language:'neutral',regexExcludeFiles:['.*\\BthTelemetry.dll']}`. NOT ISO-compatible. (Atlas uses these CAB components instead: sxsc-built `Z-Atlas-NoDefender/NoTelemetry-Package…cab` installed via DISM — see §5.4.)

**`!scheduledTask:` ScheduledTaskAction** — `path` (req; **starts with `\`**, e.g. `\Microsoft\Windows\XblGameSave\XblGameSaveTask`), `operation` (**`delete`**) ∈ `delete|enable|disable|deleteFolder`, `data` (raw task XML — used to create the task if missing when enabling/disabling: `ts.RootFolder.RegisterTask(Path, RawTask)`), `weight` **1**. Deletion does BOTH TaskScheduler API delete **and** manual registry scrub of `SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\TaskCache` (Tree + Boot/Logon/Maintenance/Plain/Tasks + TaskStateFlags ID relations). ISO: delete/deleteFolder work via registry; enable/disable skipped with warning. Default errorAction Log.

**`!taskKill:` TaskKillAction** — `name` (process name, NO `.exe`; wildcards both sides) OR `pathContains` (filter by main-module path), `weight` **2**. Never kills regex list: `lsass, csrss, winlogon, TrustedUninstaller\.CLI, dwm, conhost, ame.?wizard, ame.?assassin`. `svchost` is special-cased: **stops the hosted services instead of killing the process**. Checks `IsProcessCritical` and skips critical processes. Terminate via `TerminateProcess` + ProcessHacker terminate when kernel driver on. NOT ISO-compatible. (Atlas: `- !taskKill: {name: "explorer"}` mid-playbook then restarts explorer with `!run`.)

**`!software:` SoftwareAction** — Chocolatey install. `source` (**`chocolatey`**, only value), `name` (choco package id), `upgrade` (**true**; runs `choco upgrade -y --allow-empty-checksums` after install), `package` (link to playbook.conf `Software/Package` for OOBE), `fallback`/`fallbacks` (`{name, source}` — accepted in source, docs say "more source options are planned"), `weight` **50**. Defaults `iso: true` + `oobe: true` — during ISO injection the package is downloaded+cached into the image; during OOBE it installs from cache (no internet needed). Live flow: ensure `%PROGRAMDATA%\chocolatey\bin\choco.exe` (install if missing) → `choco install -y --allow-empty-checksums "name"` with 5 progressive retries (1s,3s,6s…). `iso: only` is rejected ("SoftwareAction does not support 'iso: only'").

**`!download:` DownloadAction** — `destination` (req; relative ⇒ `Executables\` of active playbook; ISO ⇒ image `ProgramData\AME\OOBE\Playbook\Executables`), `url` XOR `git`+`regex` (req; git = repo releases/latest URL, regex filters asset name; direct-download URLs must use `url`), `overwrite` (**false**; existing file ⇒ skip with "Use 'overwrite: true' to overwrite"), `package` (OOBE link), `weight` **150**. Defaults `iso: true`. Retry: up to 10 attempts with 1s×i backoff on 503/other non-success. Docs examples: Brave standalone download + `!run` silent install; Ungoogled-Chromium via `{git:'https://github.com/macchrome/winchrome', regex:'chromium-.*_Win64\.7z'}`.

**`!status:` / `!writeStatus:` WriteStatusAction** — `status` (req string). Writes `[Status] …` banner into Output.txt and pushes the text to the wizard's live status reporter (top of progress bar). `weight` = 0 (does not advance progress). Docs: "Status messages should be kept short and concise."

**`!task:` TaskAction (include)** — `path` (req; YAML file relative to `Configuration\`; missing ⇒ `FileNotFoundException "Could not find YAML file: …"`). Child file's filters must also match. Atlas nesting depth: custom.yml → tweaks.yml → tweaks/<cat>/<file>.yml (3 levels, works fine).

**handleExitCodes syntax** (Cmd/Run/PowerShell): map of exit-code-filter → handler. Handlers: `log`, `error`, `halt`, `retry` (re-run up to 5× per docs; engine `DoActions` allows the retry loop to run to i=10 with step+2 → ~5 retries), `retryError`. Filters support plain ints and **conditional expressions** `'>='`, `'<='`, `'>'`, `'<'` plus `'!'` negation — e.g. `{ "!0": halt }` (Atlas custom.yml) or `{'>=1':'log'}`. Thrown as `ErrorHandlingException` which the runner maps onto ErrorAction semantics.

---

## 4. Execution model

### 4.1 Privilege / elevation chain
1. **AME Wizard GUI** runs as the (elevated) user; launching a playbook spawns the engine CLI which self-elevates to **Administrator** ("This program must be launched as an Administrator!", CLI.cs) and starts an **InterLink IPC node at Level.Administrator**.
2. It then spawns a **TrustedInstaller-level InterLink node** (`NativeProcess.StartProcessAsTI(...)`); the whole `RunPlaybook` is `[InterprocessMethod(Level.TrustedInstaller)]` — **every action runs as TrustedInstaller by default**. This is why `runas: trustedInstaller` is the default for `!run/!cmd/!powerShell`.
3. Per-action `runas:` selects `currentUser` / `currentUserElevated` / `system` / `currentUserTrustedInstaller` via `ProcessPrivilege.StartPrivilegedTask` (token duplication).
4. No TiWorker/CBS involvement for normal actions — only `!systemPackage` (via ame-assassin) and Atlas's DISM CAB installs touch servicing. There is **no UAC per action**; one elevation at start.

### 4.2 Action ordering & progress
- **Strictly sequential.** `DoActions`: `foreach (ITaskAction action in actions) { … }` — one action at a time, in the order produced by the YAML tree walk (`!task` includes expanded depth-first, in file order). `priority` exists on UninstallTask but is **not consulted**. **No parallelism mechanism exists anywhere in the engine** (no Task.WhenAll across actions, no batching; only intra-action async I/O).
- **Progress** = sum of action `weight`s: `GetProgressMaximum(actions) => actions.Sum(GetProgressWeight)`; after each action, `progressReport(action.GetProgressWeight())` recomputes `1 - remaining/total`. ISO runs scale action progress into 10–85% and reserve 85–100% for "Saving Image/Cleaning WIM/Creating ISO". Status text flows through `WriteStatusAction.StatusReporter` (an `IProgress<string>` IPC channel).
- **Environment vars for scripts**: engine sets process env `OOBE=true|false` and `ISO=true|false` before running actions (AmeliorationUtil lines 857–858) — Executables scripts can branch on them.

### 4.3 Retries, errors, resume
Per action (DoActions, lines 294–424):
- Runs action; if `RunTask` returns null (Cmd/Run/PowerShell main-thread actions) calls `RunTaskOnMainThread`.
- **Retry loop `do { … } while (i < 10)`** — up to 10 attempts when: action threw a non-fatal exception, action is retry-allowed (`GetRetryAllowed()` per type — File/Service/RegistryKey/RegistryValue/ScheduledTask/TaskKill=true; Cmd/Run/PowerShell/Appx/SystemPackage/Software/Download=false unless `allowRetries: true`), and exit isn't in the break-list (`ArgumentException, SecurityException, UnauthorizedAccessException, TimeoutException`). Sleeps 300ms between failures, 50ms between checks. Breaks early when `GetStatus()==Completed` (idempotency check — the engine re-queries real system state after each attempt).
- `errorAction` resolution: `Ignore` (nothing), `Log` (info record), `Notify` (error record; playbook still finishes — "Playbook completed with errors"), `Halt` (throw; playbook aborts: "Playbook halted due to a failed critical action.").
- **Error output**: `Log.yml` (structured, with `PlaybookMetadata`: client version, Windows build, languages, RAM, threads, free space, selected options) + `Output.txt` (human-readable, live) in the run's Logs folder (`%ProgramData%\AME\Logs\<run>\`; the LiveLog build flag tails `OutputBuffer.txt` there). `ErrorLevel` 0/1/2 persisted per applied playbook.
- **Applied-playbook bookkeeping / resume**: on completion (or failure) `WriteAppliedPlaybook` records to `HKLM\SOFTWARE\AME\Playbooks\Applied\{UniqueId}` (Name, Username, Version, ErrorLevel, AvailableOptions, SelectedOptions, AppliedTimeUTC, playbook.png bytes) and/or `%ProgramData%\AME\AppliedPlaybooks\<n>\{playbook.conf, playbook.png, errors.txt?, verified.txt?}` (max 10). **There is no mid-playbook checkpoint file**: reboot-resume works because *every action is written idempotently* (GetStatus pre-checks + Delete/Add semantics) — after a Defender-prep reboot the user simply re-runs the playbook; completed actions report Completed instantly and are skipped (`ParseActions` filters + per-action `GetStatus`). Upgrade flows rely on the registry record (§ upgrade semantics).
- **DefenderDisabled/UCPDDisabled reboot**: Prepare System → `shutdown /r /t 0` immediately, engine exits; the wizard re-offers the playbook after reboot (CLI.cs lines 126–142). Mid-run reboots initiated by playbook scripts (e.g. DISM 3010) are the author's responsibility.

### 4.4 ISO / OOBE pipeline (RunPlaybook ISO branch)
Extract ISO → (optional) patch boot.wim with `LabConfig` Bypass{RAM,SecureBoot,CPU,TPM}Check → (optional) drop `$OEM$\$$\Panther\unattend.xml` (BitLocker bypass) → convert install.esd→wim if needed → `WimInstance.RemoveSuperfluousImages()` → mount hives under `HKLM-<guid>` etc. → Defender CAB injection when `DefenderDisabled` → copy playbook into `ProgramData\AME\OOBE\Playbook` + `oobe.conf` (username/password/admin password/options/bullet-points/software list) + `playbook.apbx` → run ISO-applicable actions against the WIM skeleton → inject AME OOBE (`OOBE.exe` as `msoobe.exe` replacement + `ameoobe` service) → rebuild WIM/ESD → `mkisofs.exe` → ISO. After install, the OOBE runs the playbook on first boot (`LiveISO=true`, env `OOBE=true`), where `!software` installs from cache and `!download` skips (unless `oobe: true`).

---

## 5. Build & packaging (.apbx mechanics)

### 5.1 Atlas `local-build.ps1` (`src/dependencies/local-build.ps1`) — flags
- **`-Removals`** ∈ {`Dependencies`,`Requirements`,`WinverRequirement`,`Verification`} — dev-build convenience, strips elements that block testing:
  - `Requirements` → deletes every `<Requirement>` line ("0.6.5 has a bug where it will crash without the 'Requirements' field, but all of the requirements are removed");
  - `WinverRequirement` → deletes `<string>`, `</SupportedBuilds>`, `<SupportedBuilds>` lines ⇒ **no build gate**;
  - `Verification` → deletes `<ProductCode>` (no verified status needed for local test);
  - `Dependencies` → cuts the block between `### NO LOCAL BUILD ###` markers in `atlas/start.yml`.
- **`-AddLiveLog`** — injects as the FIRST action of `custom.yml`:
  ```yaml
  - !cmd: {command: 'start "AME Wizard Live Log" PowerShell -NoP -C "<script>"'}
  ```
  where script = tail-follow loop of the newest `%ProgramData%\AME\Logs\*\OutputBuffer.txt` (`Get-Content -Wait`, 1s poll). **Live logging therefore = the wizard's own output buffer file; a dev-visible console window, not an engine feature.**
- `-ReplaceOldPlaybook` (delete previous .apbx or auto-increment "name (n).apbx"), `-DontOpenPbLocation`, `-NoPassword` (omit `-pmalte`), `-FileName` (default "Atlas Test").
- It also **injects the version into OEM info**: replaces `AtlasVersionUndefined` in `Configuration\tweaks\misc\config-oem-information.yml` with `v{Version}` from playbook.conf.
- Archive command: `7z a -spf -y -mx1 -pmalte -tzip "$apbxPath" @list` (list = all files except `local-build.*`, `*.apbx`, and any file replaced by an edited copy), then `7z u -pmalte` for the edited overrides. **So: ZIP format (`-tzip`), password `malte`, fastest compression, files at archive ROOT (no wrapping folder), forward-slash relative paths preserved.** CI `.github/workflows/apbx.yaml` line 128: "Making a renamed password protected (malte) ZIP of playbook files…" with flags `-ReplaceOldPlaybook -AddLiveLog -Removals Verification, WinverRequirement`.
- `build-playbook.sh` (for pwsh on Linux/macOS) = same with `-Removals WinverRequirement, Verification`.

### 5.2 Wizard-side .apbx consumption
- "Open playbook": wizard extracts the archive (password `malte`) to a working dir, deserializes `playbook.conf` (XmlSerializer + `Validate()`), lists it in the sidebar with `playbook.png`. Verification = `ProductCode` match against AME's issued codes (server/branding side; engine only carries `verified` bool through IPC and writes `verified.txt`).
- Update check: `Git` URL → platform API (`api.github.com/repos/{repo}/releases`, GitLab `/api/v4/projects/…`, Gitea `/api/v1/repos/…`), first release's first `.apbx` asset; tag must equal `Version` (docs /developers/updates.html). ⚠️ Note GitHub API rate limits are unauthenticated here.

### 5.3 Recommended UltraOS build recipe (from verified mechanics)
Zip root must contain playbook.conf at top level; use `7z a -tzip -pmalte -mx1 UltraOS.apbx @filelist` (or replicate Atlas's script). Never nest a single folder. Keep `main.yml` (engine prefers it) or document `custom.yml` fallback. Ship `Images/` for any RadioImagePage/Software icons; `playbook.png` 256px at root.

### 5.4 CAB components (Atlas-specific, optional pattern)
Atlas removes protected components (Defender/telemetry) via **sxsc-generated, test-signed CAB packages** (`Executables\AtlasModules\Packages\Z-Atlas-No{Defender,Telemetry}-Package…cab`, per-arch, rebuilt in CI via github.com/Atlas-OS/sxsc) installed with `DISM /Image:… /Add-Package` during ISO, or `packageInstall.ps1` live. UltraOS can adopt the same approach for 26H2 protected payloads (GPL-compatible: sxsc is Atlas tooling, check its license before vendoring ⚠️ UNVERIFIED).

---

## 6. Capabilities, limits & performance notes

**What dominates runtime (source-derived):**
1. **Process spawning is the #1 cost.** Every `!powerShell`, `!cmd`, `!run` spawns a fresh console process; PowerShell cold start ≈1–3s each. Atlas's playbook shells out heavily (its `custom.yml` runs ~10 PowerShell scripts + every AtlasDesktop .cmd toggle via `!cmd`). Each also gets output-pipe threads (OutputHandler) and 30s-poll waits (`WaitForExit(30000)` loops).
2. **`!appx` (weight 30) and `!systemPackage` (weight 15)** spawn `ame-assassin.exe` per package — Atlas removes ~30 appx ⇒ 30 process spawns (wildcard names only match per-call; no batch mode). ame-assassin internally uses CBS/Remove-AppxPackage machinery.
3. **ServiceAction waits**: every stop/delete waits up to **5000ms per dependent service** (`WaitForStatus(Stopped, 5000)`), plus 100ms `Task.Delay` at end — a service stuck stopping costs 5s.
4. **FileAction on locked files**: up to 8×100ms kill-retry loops + `takeown/icacls` cmd spawns + GC.Collect/WaitForPendingFinalizers per file.
5. **Downloads** (`!download` weight 150) and Chocolatey (`!software` weight 50) are network-bound; retry backoff can add ~10–55s worst case.
6. **Sequential YAML evaluation is NOT a cost** — parsing happens once up front (ParseActions recursion), then execution is a flat list. Idempotent `GetStatus()` re-checks only run inside retry loops / scheduledTask.
7. ISO mode adds WIM mount/unmount + rebuild + mkisofs (the 85–100% progress band).

**Documented/derived knobs to make UltraOS fast:**
- **Prefer native actions over shelling out**: `!registryValue` (weight 1, in-process API call) is orders of magnitude cheaper than a PowerShell one-liner. Batch many values into one file rather than `!powerShell: reg add…` loops.
- **One PowerShell script > N PowerShell one-liners** — amortize the ~2s startup. Atlas does this correctly (e.g. STOPFOLDERPROC.ps1, CLEANUP.ps1).
- Use `weight` to make the progress bar feel fast — weights are purely cosmetic pacing, they don't change speed.
- `!taskKill` before file ops only when needed; avoid `!service delete` for services you merely want disabled — `operation: change, startup: 4` is a single registry write with no stop-wait.
- `!appx` with `type: family` + wildcards to reduce call count where semantically OK; note each `!appx` is still one ame-assassin spawn.
- **There is NO engine-supported parallelism or batching** — any "parallel" impression must come from launching background processes (`wait: false`) and polling later, exactly like Atlas's CLEANUP.ps1 trick ("Disk Cleanup is run first so it can run in the background" — custom.yml comment). This is the ONLY sanctioned async pattern: `- !run: {exe: …, wait: false}` + later action checks. ⚠️ Use sparingly; unmanaged background work can race subsequent actions.
- `EstimatedMinutes` is display-only; set honestly (Atlas 15).
- Engine hardening worth knowing: engine will not kill itself/AME Wizard processes; `DcomLaunch`, `lsass`, `csrss`, `winlogon`, `dwm`, `conhost` are protected from kills; `svchost` taskKill converts to service stops.

**Format gotchas for build agents (compiled from engine + Atlas):**
- YAML tags are **case-sensitive** (`!registryValue` not `!registryvalue`); keys are camelCase aliases (YamlDotNet `CamelCaseNamingConvention` + explicit `Alias`).
- `type:` is the REGISTRY type name for `!registryValue` but the APPX level for `!appx` — don't mix.
- `'HKCU'` edits fan out to all user hives by default — use `scope: currentUser` for per-user UI tweaks, `scope: defaultUser` inside the Default-hive load pattern (Atlas custom.yml loads/unloads `HKU\AME_UserHive_Default` via `reg load` before/after).
- Registry paths: forward content uses single quotes (docs YAML guide) — double quotes require `\\` escaping.
- `builds:` supports `26100.1265` update-build matching — useful for 26H2 enablement-package deltas.
- The `status:` key on any action can replace standalone `!status` actions.
- Never use disabled tags (`!user:`, `!shortcut:`, `!lineInFile:`, `!update:`) — parse-time failure.
- `!task` path separators: Atlas uses both `tweaks\scripts\…` and `tweaks/qol/…` styles (Windows engine tolerates both; prefer `\` or `/` consistently).
- Engine v0.8.4 (wizard 0.8.x line, "AME Beta" branding in docs). Docs changelog 2025-05-30: ISO mode, `!download`, `!software`, `!status` rename introduced.

---

## 7. Source & URL index (accessed 2026-10-07)
- Engine clone: /home/z/my-project/repos/trusted-uninstaller @ f325e9d (v0.8.4) — key files: `TrustedUninstaller.Shared/{Playbook,Requirements,AmeliorationUtil,OOBE,Globals}.cs`, `Parser/{TaskActionResolver,PlaybookParser}.cs`, `Tasks/{TaskAction,UninstallTask,TaskList,ITaskAction,UninstallTaskPrivilege,OutputProcessor}.cs`, `Actions/*.cs` (18 classes), `TrustedUninstaller.CLI/{CLI,CommandLine}.cs`, README.md
- Docs crawled (25 pages): https://docs.amelabs.net/developers/{actions,tasks,configuration,requirements,verification,updates,upgrades,iso,ntlite,yaml}.html ; …/developers/actions/{Run,RegistryKey,RegistryValue,Appx,File,Service,ScheduledTask,TaskKill,SystemPackage,Cmd,PowerShell,Download,Software,WriteStatus,Task}.html ; …/developers/features/{pages,features-in-yaml}.html ; …/developers/features/pages/{checkboxpage,radiopage,radioimagepage}.html ; https://docs.amelabs.net/creating_playbooks.html ; installing_playbooks{,_playbook_apply}.html ; changelog/2025-05-30.html
- Atlas: /home/z/my-project/repos/atlas/src/playbook/{playbook.conf,Configuration/**,Executables/**}, src/dependencies/local-build.ps1, .github/workflows/apbx.yaml, build-playbook.sh
