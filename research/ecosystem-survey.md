# Ecosystem Survey — Windows Optimization Projects & UltraOS Feature Backlog

**Agent:** T1-i (competitive intelligence + feature-idea backlog)
**Date:** 2026-10-07 | **Method:** direct shallow clones (`/home/z/my-project/repos/`), GitHub HTML search, z-ai web_search/page_reader
**Rule:** No fabrication. Unverifiable claims marked ⚠️ UNVERIFIED. All sources listed at bottom; accessed 2026-10-07.

---

## 1. Executive Summary

1. **A whole community-playbook ecosystem exists** beyond Atlas/Revi: 12+ live AME-Wizard playbook repos found via GitHub search (Chamber, RapidOS, PLAS/XOS, AtmosphereOS, KiyomizuOS, ThinNekoOS, RivalsOS, Pro+, APEX, Z-LAG-OS, Akati-Os, AME-10). Several already compete on UltraOS's planned differentiators.
2. **Chamber-Playbook is the closest direct competitor** — it already supports **26H2 (26300)**, ships a **CI-generated verification manifest + read-only post-run verifier**, a **post-install companion folder**, phases with status text, and markets itself as "anti-cheat safe, fully verifiable, reversible." License: **CC BY-NC-SA 4.0** (non-commercial — code-sharing restricted; ideas only).
3. **winutil (ChrisTitusTech)** is the best-engineered data model: declarative JSON per tweak with `OriginalValue`/`OriginalType` for **automatic undo**, `UndoScript`, per-tweak docs links, presets (Standard/Minimal/Advanced) runnable headless, Pester tests, and a live "tweaks state report."
4. **O&O ShutUp10++** remains the gold-standard privacy-toggle UX (recommendation levels per toggle; new Premium edition auto-**re-applies settings after Windows updates** — a watchdog idea worth copying). Its exact in-app traffic-light colors are ⚠️ UNVERIFIED from this environment (Windows app UI).
5. **Gap for UltraOS:** Atlas supports **no 26H2** and **no Windows Home edition** (Atlas docs: "With the exception of Windows Home, most other Windows editions are supported"); most community playbooks are single-purpose (one game, one niche). No surveyed project combines 26H2 + Home/Pro + 3 presets + per-module toggles + report + rollback.
6. **"MinOS" and "Raphire/Reclaim" as named in the briefing were NOT found** — Raphire's real tool is **Win11Debloat** (MIT, cloned); MinOS candidates on GitHub are unrelated projects (⚠️ UNVERIFIED / likely defunct or misremembered).

---

## 2. Survey Table

| Project | Type | License | Approach | Standout | Weakness | UltraOS should adopt |
|---|---|---|---|---|---|---|
| Atlas-OS/atlas-toolbox | Post-install GUI companion | GPL-3.0 (LICENSE verified) | C# WinUI 3 / WinAppSDK MVVM; ~80 `IConfigurationService` toggles (IsEnabled/Enable/Disable) | Per-toggle class pattern; togglehistory.json; Profiles; Crowdin i18n | Heavy C# codebase, one class per toggle; toolbox ≠ wizard | Toggle-service pattern; companion-app roadmap; history JSON |
| ChrisTitusTech/winutil | Runtime PowerShell GUI | MIT | Single-file compiled PS1 from modular repo; JSON-driven tweaks/apps/DNS | `OriginalValue` undo data; presets incl. headless `-Preset`; 45+ docs-linked tweaks; state report; Pester | WPF/PS perf; no image-level changes | Declarative tweak schema + undo fields; docs-per-tweak; presets as data |
| ntdevlabs/tiny11builder | Offline ISO builder | ⚠️ **No LICENSE file in repo** (README says "open-source") | DISM offline: strip Appx/packages, delete Edge/OneDrive/WinSxS (core), offline reg hives (`HKLM\z...`), rebuild ISO | tiny11 Core variant (extreme strip); unattend MSA bypass | Unserviceable (core), no undo, image-surgery risk | Nothing structural — contrast only (playbook = online + reversible) |
| O&O ShutUp10++ | Freeware privacy toggler | Proprietary freeware (v3.6.1135, 2026-09-29) | Portable GUI; per-toggle recommendations | Recommendation levels ("recommended/limited/not recommended" traffic-light, ⚠️ colors in-app only); Premium auto-restore after updates | Closed source; Windows only app | Risk-level metadata on every toggle; update-drift re-verification |
| MeetRevision/playbook (ReviOS) | AME playbook | CC BY-SA 4.0 | 41 wizard options; enable/disable pairs; revert.yml `onUpgrade: true` | Rollback-tweaks task for version upgrades; browser RadioImage w/ bundled Brave `initial_preferences` | Attribution license blocks code reuse; fewer safety rails | onUpgrade revert task; paired enable/disable options; browser bundling |
| ChamberTechFPS/Chamber-Playbook | AME playbook | **CC BY-NC-SA 4.0** | 10-phase main.yml; security/gaming options; hosts telemetry blocking | **26300 (26H2) support**; CI-generated `verification-manifest.json` + read-only `Verify-Chamber.ps1` (PASS/FAIL/WARN, `-ClientReport` zips report); PostInstall companion (drivers, NVIDIA `.nip` profiles, verify); anti-cheat-safe promise; video tutorial | Non-commercial license = can't copy code; niche (esports) | Phases + status text; manifest + verifier; PostInstall folder; `-ClientReport`; UpgradableFrom any |
| rapid-community/RapidOS | AME playbook (+toolbox) | AGPL-3.0 | Deep customization, community-driven (RU) | "Readme Collection" per-release transparency (UWP/SERVICES READMEs); NetBlock.exe service internet-restriction; Toolbox on desktop | Docs in mixed EN/RU; AGPL virality | Per-release "what changed/removed" docs; service internet-blocking option |
| plasXOC/playbook (PLAS/XOS) | AME playbook | Custom ("plasXOC", © 2026 plasXOC & Solah) | Strip "at the source" not toggle-off | Post-install scripts; Open-Shell integration; optional features | Source not in default branch (readme/LICENSE only in clone) | Post-install script bundle idea |
| Raphire/Win11Debloat | GUI/CLI debloater | MIT | PS GUI + CLI; regfile-driven tweaks | **Regfiles/Undo/*.reg**; registry snapshot/backup/restore windows; TweaksBuilder; import/export config; i18n JSON; 45+ Pester tests incl. TestSuiteSafety | Per-machine tool, no wizard flow | Undo reg files; config import/export; test-suite safety gate |
| Sycnex/Windows10Debloater | Scripts | MIT | 3 variants: interactive, GUI, SysPrep-silent | `-Sysprep -Debloat -Privacy` switch params for deployment | Legacy (Win10), no undo, no report | Switch-parameter silent mode idea |
| Community sentiment (web) | — | — | Reddit/forum comparisons | ReviOS seen as "balanced", Atlas as "deep but risky", skeptics call playbooks "snake oil" | Trust deficit is the #1 objection | Prove value: benchmark docs, verification, reversibility messaging |

---

## 3. Per-Project Detail (verified evidence)

### 3.1 Atlas-OS/atlas-toolbox — Atlas's NEW post-install companion
**Cloned:** `/home/z/my-project/repos/atlas-toolbox` (318 files) · **License:** GPL-3.0 (`LICENSE` verified) · **URL:** https://github.com/Atlas-OS/atlas-toolbox

- **What:** "AtlasOS Toolbox made with C# and WinAppSDK" (README). A desktop GUI that manages post-install toggles after the Atlas playbook runs. The Atlas playbook itself has an `install-toolbox` FeaturePages option (verified in `repos/atlas/src/playbook/playbook.conf`) and ships `Executables/AtlasDesktop/Install AtlasOS Toolbox.cmd` — playbook installs companion.
- **Architecture (verified from source):**
  - MVVM + DI: `Views/`, `ViewModels/`, `Models/`, `Stores/`, `Services/`, `HostBuilder/` (`AddViewModelsHostBuilderExtensions.cs` etc.), `AtlasToolbox-WinUI3.sln`.
  - **Every toggle is an `IConfigurationService`** (`Services/ConfigurationServices/IConfigurationService.cs`): `bool IsEnabled(); void Enable(); void Disable();` — ~80 services (HAGS, VBS, Bluetooth, Copilot, Recall, mitigations, services, boot config...).
  - Example (`HagsConfigurationService.cs`): registry get/set/delete + updates a keyed `ConfigurationStore` so UI reflects live state.
  - Complex toggles delegate to shipped scripts: `Installer/Toolbox/Scripts/*.cmd|reg`, `ConfigurationServices/{Mitigations,SafeMode,ContextMenuTerminals,ShortcutIcon,FIleSharing}/*` (same files the AtlasDesktop folder uses — **one script library serves both desktop-folder and GUI**).
  - `Models/Profiles.cs` + `ProfileModel` (export/import/share configurations), `Installer/Toolbox/togglehistory.json` (DateTime/Key/OldState history log — dev-test data in repo).
  - `Services/{DismService,BcdService}.cs` for DISM/BCD operations; `IncompatibleVersionWindow` guards builds; **Crowdin** translations (README).
  - Distribution: Inno Setup (`Installer/setup.iss`).
- **Standout:** clean enable/disable/IsEnabled triad per toggle; single script library shared between wizard desktop folder and standalone GUI; history + profiles.
- **Weakness:** one hand-written C# class per toggle (high maintenance); no packaged verifier/report; Win-only build complexity.
- **For UltraOS:** adopt the *pattern* (every toggle = probe + enable + disable, backed by shared scripts), and plan a phased companion: v1 scripts-folder (AtlasDesktop-style), v2 GUI. GPL-3.0 also makes it the only major companion we can legitimately study closely (still write our own code).

### 3.2 ChrisTitusTech/winutil — best-practice modular toggle design
**Cloned:** `/home/z/my-project/repos/winutil` (HEAD 9c87c02, 2026-09-30) · **License:** MIT · **URL:** https://github.com/ChrisTitusTech/winutil

- **What:** WPF PowerShell utility ("installs, tweaks, config, updates"); run via `irm christitus.com/win | iex`.
- **Tweak schema (verified `config/tweaks.json`):** every entry has `Content` (title), `Description` (plain-language risk/consequence), `category`, `panel`, `Type` (Checkbox default / `Toggle` for instant-apply / `Button` for actions), `registry[]` with **`OriginalValue`** per value, `service[]` with **`OriginalType`**, `InvokeScript[]`, **`UndoScript[]`**, and `link` to a per-tweak docs page (e.g. `https://winutil.christitus.com/code-reference/tweaks/essential-tweaks/hiber`). Sample: `WPFTweaksHiber` = registry + `powercfg /hibernate off` + UndoScript `powercfg /hibernate on`.
- **Categories (verified):** `Essential Tweaks` (18), `z__Advanced Tweaks - CAUTION` (22 — `z__` prefix forces ordering; CAUTION in the label), `Customize Preferences` (25), `Performance Plans - NOT FOR LAPTOPS` (2). Risk is communicated in category names + descriptions.
- **Presets (verified `config/preset.json` + README):** `Standard` / `Minimal` / `Advanced` + `AppxDefault`; headless apply: `& winutil -Preset Standard`.
- **Engineering (verified):** `SPEC.md` project contract + `AGENTS.md`/`CLAUDE.md`/`GEMINI.md` (AI-agent-friendly repo!); `Compile.ps1` → single distributable `winutil.ps1`; Pester tests (`pester/`); lint; `functions/private/Get-WinUtilTweaksStateReport.ps1` (groups every tweak's **live applied state** by category — "Select Installed Tweaks" detection); `Get-WinUtilEnvironmentReport.ps1` + logs paths (diagnostics); runspace pools for parallelism; `tools/devdocs-generator.ps1` auto-generates the docs site from `config/*.json` (docs can't drift from config); `tools/autounattend.xml` for ISO workflows; `config/dns.json` (DNS switcher + benchmark), `config/themes.json`.
- **Weakness:** PowerShell/WPF runtime weight; undo is per-tweak manual ("Undo" button per selection), no whole-run rollback or report.
- **For UltraOS:** the JSON tweak schema with original-value/undo fields; risk-bearing descriptions; presets-as-data; docs auto-generated from the same source of truth; state detection; environment report; Pester config validation; AI-agent repo docs (SPEC.md pattern).

### 3.3 ntdevlabs/tiny11builder — offline contrast
**Cloned:** `/home/z/my-project/repos/tiny11builder` (HEAD 00e7d8a, 2025-09-12) · **License:** ⚠️ **no LICENSE file in repo** (README claims "open-source") · **URL:** https://github.com/ntdevlabs/tiny11builder

- **What:** PowerShell scripts to build a trimmed Windows 11 **ISO**: `tiny11maker.ps1` (serviceable) vs `tiny11Coremaker.ps1` (bare-minimum; **removes WinSxS → cannot add languages/updates/features afterward**, README warns).
- **How (verified):** mount ISO → DISM `/Remove-ProvisionedAppxPackage` + `/Remove-Package`, delete Edge/OneDrive/winre.wim folders, edit **offline registry hives** (`reg add HKLM\zSOFTWARE\...`), delete scheduled-task files, DISM recovery compression, rebuild bootable ISO with `osdimg`/ADK; `autounattend.xml` bypasses MSA on OOBE.
- **Contrast with playbook approach (the point):** tiny11 = *image surgery, pre-install, irreversible, unserviceable in core mode, no user choices at runtime*. Playbook = *post-install, online, per-user options, reversible, keeps servicing*. UltraOS should stay strictly in the second camp (and say so in marketing); the only transferable idea is the **unattend/OOBE bypass bag of tricks** if UltraOS ever supports ISO flows (Atlas playbook.conf already has `SupportsISO`/`OOBE` fields — briefing).

### 3.4 O&O ShutUp10++ — privacy-toggle UX gold standard
**Web-verified:** https://www.oo-software.com/en/shutup10 — "O&O ShutUp10++: Improve Windows data protection", freeware, **version 3.6.1135 released 09/29/2026**, portable ("does not need to be installed; it runs immediately"), no bundled extras; settings grouped by category in one UI; **"Recommendations guide you and provide tips on which functions can be safely disabled"**. New **Premium** edition: "use our recommended settings with a single click… **continuously monitors your selected settings and automatically restores them, even after Windows updates**."
- **Traffic-light system:** the briefing characterizes it as recommended / limited / not-recommended color coding. Third-party corroboration: Puget Systems — "only apply the ShutUp10 settings that O&O Software recommends be disabled" (2017); BleepingComputer forum (2025-12-24): "go with the default settings… it has pop-up [warnings]"; ElevenForum mentions profile import modes "Add-Only" and "Replace-All". **Exact in-app colors/labels: ⚠️ UNVERIFIED** (Windows GUI, not inspectable from this environment).
- **For UltraOS:** (a) per-toggle recommendation metadata (Safe/Balanced/Caution) baked into wizard option descriptions; (b) "apply recommended with one click" = our presets; (c) the **Premium-style update watchdog** — a scheduled re-verify task that detects Windows-update drift and alerts (we do it transparently + free, as a differentiator).

### 3.5 MeetRevision/playbook — the ReviOS playbook (repo is ALIVE)
**Cloned:** `/home/z/my-project/repos/revi` (HEAD 702a171, 2026-10-05 "new way to prevent CrossDeviceResume from running") · **License:** CC BY-SA 4.0 · **URL:** https://github.com/MeetRevision/playbook
- (Main agent's briefing listed `MeetRevision/Revi-Playbook` as dead — the *current* repo is **MeetRevision/playbook**; note for fleet.)
- **Verified:** `src/playbook.conf` (41 Checkbox/Radio options incl. `disable-defender`/`enable-defender`, `disable-hibernate`/`enable-hibernate` **paired toggles**, `remove-winsxs-ai`, browser RadioImage brave/firefox with bundled `Executables/BraveSoftware/.../initial_preferences`); `Configuration/Tasks/{start,services,software,registry,final,revert}.yml` + `packages/{appx,optional-features,app-win32,win-sxs}.yml`; **`revert.yml` = "Rollback Tweaks… for those who are applying from previous versions", `onUpgrade: true`** — an upgrade-time cleanup task citing per-change issue/PR links; hosts file; wallpapers/theme scripts; `UPDATE-APPX.ps1`.
- **For UltraOS:** paired enable/disable options; `onUpgrade` revert task so re-running/upgrading never leaves stale tweaks; per-change issue-link comments (auditability); CC BY-SA means **no code reuse** in GPL-3.0 project — concepts only.

### 3.6 ChamberTechFPS/Chamber-Playbook — closest competitor (study hard)
**Cloned:** `/home/z/my-project/repos/Chamber-Playbook` · **License:** CC BY-NC-SA 4.0 · **URL:** https://github.com/ChamberTechFPS/Chamber-Playbook
- **Positioning (README):** "One-click competitive gaming optimization for Windows 11… anti-cheat safe, fully verifiable, reversible." **Supports 26100/26200/26300 (26H2)**; commercial upsell at chambertech.net; YouTube install tutorial.
- **Verified standout engineering:**
  - `Configuration/main.yml` = **10 numbered phases** (`1-power` … `10-finalize`), each announced via `!status:` — clear progress UX.
  - `tools/generate_verification_manifest.py` — parses task YAML + scripts → `PostInstall/Verify/verification-manifest.json`; runs **in CI so the manifest can never drift from the playbook**.
  - `PostInstall/Verify/Verify-Chamber.ps1` — standalone, **read-only** verifier: checks every tweak against live system state + hardware checks (Secure Boot, VBS, HAGS, MSI mode); colored `PASS/FAIL/WARN/DISABLED` output; `-Detailed`; **`-ClientReport` zips results + system info to Desktop for support**.
  - `PostInstall/` companion: `START-HERE.bat`, `Drivers/{NVIDIA,AMD,Network,Chipset}` with **NVIDIA `.nip` profiles + nvidiaProfileInspector.exe** and import bats, `tools/` URLs (DDU, MSI Afterburner, CapFrameX, HWiNFO).
  - `playbook.conf`: `UpgradableFrom any` + `<Git>` → AME in-place update check; security page options carry explicit risk text ("Not Recommended — breaks apps that need virtualization").
  - `docs/BENCHMARKING.md`, `AGENTS.md`, `CHANGELOG.md`, `CONTRIBUTING.md`; hosts-file telemetry blocking script (`Update-HostsTelemetryBlocks.ps1`).
- **Weaknesses:** CC **BY-NC-SA** (non-commercial, no code reuse — ideas only); esports-niche focus; no preset tiers (one profile + checkboxes).
- **For UltraOS:** phase structure, CI-generated manifest + read-only verifier, `-ClientReport`-style support bundle, PostInstall driver folders, `UpgradableFrom any`, risk text in option names, benchmark docs. **UltraOS must beat or match: 26H2 support + verification.**

### 3.7 rapid-community/RapidOS — community playbook + toolbox
**Cloned:** `/home/z/my-project/repos/RapidOS` · **License:** AGPL-3.0 · **URL:** https://github.com/rapid-community/RapidOS
- **Verified:** README markets privacy/performance/clean UI; **"Readme Collection"** — per-release docs of exactly *what UWP apps are removed* and *which services changed/disabled/internet-restricted*; `RapidOS Sources/Executables/` incl. `RapidScripts/NetBlock.exe` (per-service internet blocking), `Modules/*.psm1`, `RapidResources/RapidOS Toolbox.lnk`, wallpapers/theme; Configuration split `Core/Customizations/Debloat/Network/Privacy/System` + `Maintenance`; self-deploy instructions; runs via **AME Wizard/Beta**; Russian-community Discord (discord.rapid-community.ru).
- **For UltraOS:** publish per-release "What's removed / what changed" docs (trust!); optional per-service internet blocking belongs in Extreme preset (with big warnings); Maintenance task concept for re-runs.

### 3.8 plasXOC/playbook — "PLAS" (XOS)
**Cloned:** `/home/z/my-project/repos/playbook` (default branch has only readme/LICENSE/.github — sources distributed via releases/other channels) · **License:** custom "plasXOC" (© 2026 plasXOC & Solah) · **URL:** https://github.com/plasXOC/playbook
- **Verified (readme):** "no-nonsense AME Wizard playbook that strips Windows 11 down to what matters… Telemetry… removed at the source — not just toggled off until the next update undoes everything"; **post-install scripts** ("fine-tune Windows behaviour any time after install without ever needing to reinstall"); optional features incl. updates/browser choice/post-install config; Open-Shell Start menu; Discord community. ⚠️ Internal structure unverified (sources not in clone).
- **For UltraOS:** the "post-install scripts available forever" framing; Open-Shell as optional QoL install.

### 3.9 Other live community playbooks (probed HTTP 200 on 2026-10-07; not deep-surveyed — clone if needed)
| Repo | Description (GitHub meta) |
|---|---|
| https://github.com/Ameliorated-LLC/AME-10 | "Windows 10 AME playbook for AME Wizard" (the historical AME) |
| https://github.com/AtmosphereTeam/AtmosphereOS | "AtmosphereOS AME Wizard playbook for Windows 10/11" |
| https://github.com/KiyomizuSuzu/KiyomizuOS | "debloat Windows 11 via PowerShell 7 scripts" |
| https://github.com/MeowBot233/ThinNekoOS | "designed for low performance laptops" (niche targeting!) |
| https://github.com/Rob-QT/RivalsOS-Playbook | "AtlasOS-fork… for Marvel Rivals" (game-specific fork) |
| https://github.com/lucidslab/proplus_playbook | "AME Wizard Pro+ Playbook" |
| https://github.com/MagicTwist541/APEX | ecosystem org: Linux + Android + "AME Wizard playbooks for Windows 11" |
| https://github.com/MrPcGamerYT/Z-LAG-OS | ".apbx for Win10/11… kernel, power & network tuning for competitive gaming, Android emulators and low-end hardware" |
| https://github.com/x2Swiftyouz/Akati-Os | "gaming performance, privacy, debloat and custom themes. Based on AtlasOS" |

**Takeaway:** the market segments by niche (game-specific, laptop-specific, low-end). UltraOS's Safe/Balanced/Extreme + Home/Pro positioning is the unclaimed *general-purpose, trust-first* slot.

### 3.10 Debloat-script ecosystem
- **Raphire/Win11Debloat** — cloned `/home/z/my-project/repos/Win11Debloat` · **MIT** · https://github.com/Raphire/Win11Debloat
  - GUI + CLI + silent modes; **`Regfiles/Undo/*.reg`** dedicated undo files; `Regfiles/Sysprep/` variants; `Scripts/GUI/Show-RestoreBackupWindow.ps1` (registry backup restore dialog) + `MainWindow-TweaksBuilder.ps1` (build custom tweak sets); import/export config; **45+ Pester tests** incl. `Registry-BackupValidation`, `Registry-SnapshotApply`, `Restore-RegistryBackup`, `Invoke-SystemRestorePoint`, `TestSuiteSafety`, `XamlContracts`, i18n `Config/Languages/*/*.json`; `Schemas/`. Best-in-class for a "script" — UltraOS should mirror its test-safety discipline and snapshot/restore UX.
  - ⚠️ Note: briefing said "Raphire/Reclaim" — **no such repo (404)**; Raphire's project is Win11Debloat. A "Reclaim" Windows project could not be located (⚠️ UNVERIFIED).
- **Sycnex/Windows10Debloater** — cloned `/home/z/my-project/repos/Windows10Debloater` · **MIT** · https://github.com/Sycnex/Windows10Debloater — legacy classic; three variants (interactive / GUI app / `Windows10SysPrepDebloater.ps1` silent with `-Sysprep -Debloat -Privacy` switches); functions `Start-Debloat/Remove-Keys/Protect-Privacy`. No undo/report (its known weakness). Idea: silent switch-parameters for unattended runs.
- Also seen in GitHub topic search (not surveyed): farag2/Sophia-Script-for-Windows + Sophia-Community/SophiApp, he3als/EdgeRemover, nyxiereal/XToolbox, Batlez/Batlez-Tweaks (⚠️ details unverified).

### 3.11 MinOS — NOT FOUND ⚠️
GitHub search "MinOS windows" surfaces only unrelated projects (e.g., kv34dev/MinOS = "A Mini Operating System Inside a Window" — a mini desktop app, not a Windows optimization project). Web search returned no relevant Windows-tweak project. **Conclusion: ⚠️ UNVERIFIED / likely defunct, renamed, or misremembered.** If it existed as an AME playbook it has no discoverable live repo as of 2026-10-07.

### 3.12 Community sentiment (web snippets — URLs truncated by search API to domains; treat as directional)
- Neowin forum (2024-03-30): "most of the 'improvements' brought by either ReviOS or AtlasOS are just snake oil" — skepticism UltraOS must answer with verification + benchmarks.
- xp-feed (2026-05-28): "ReviOS is one of the most balanced… improves FPS and input lag without ripping out as many core components as Atlas."
- GitHub-hosted comparison (2026-08-20): "ReviOS Playbook (April 2026 Release): Dropped idle RAM usage down to ~1.5 GB… AtlasOS v0.5.0-hotfix: Pushed it even [lower]" — ReviOS still shipping playbook releases in 2026.
- Steam Community / Guru3D (undated): users recommending "AtlasOS playbook" for game-crash stability — anecdotal, ⚠️ UNVERIFIED claims.
- Atlas docs (https://docs.atlasos.net): "We recommend Windows Pro or Windows Enterprise. With the exception of Windows Home, most other Windows editions are supported." → **Home edition is a real gap UltraOS fills.**

---

## 4. UltraOS Feature Backlog (prioritized, top 15)

Legend — **Effort:** S ≤1 agent-day of playbook work, M = multi-day module, L = phased/track. **What/Why** grounded in survey evidence above.

| # | Feature | What | Why (evidence) | Effort |
|---|---|---|---|---|
| 1 | **Risk-level metadata on every wizard option** | Each playbook.conf option gets `risk: safe|balanced|caution` + "breaks: X" hints embedded in `<Description>` (and stored per-module in YAML comments for the docs) | O&O's recommendation system + winutil's "z__Advanced Tweaks - CAUTION" + Chamber's "Not Recommended —" option text all validate that users need per-toggle risk guidance | **S** |
| 2 | **Safe/Balanced/Extreme presets as wizard pages** | RadioPage preset selection (pre-checked defaults per preset) → subsequent CheckboxPages module toggles pre-set per preset; keep everything overridable | winutil presets (Standard/Minimal/Advanced, incl. headless); Revi radio pages; no playbook surveyed ships *tiered* presets | **S** |
| 3 | **Phase-sequenced main.yml with `!status` progress** | 8–10 numbered phase task files (power→services→privacy→debloat→…→finalize) each announced with status text; set `EstimatedMinutes` | Chamber's 10-phase structure; Atlas `EstimatedMinutes 15` UX | **S** |
| 4 | **Declarative undo metadata everywhere** | Every registry write records prior value / operation delete plan; every service change records original start type; dedicated `revert.yml` with `onUpgrade: true` | winutil `OriginalValue`/`OriginalType`/`UndoScript`; Revi `revert.yml` onUpgrade | **M** |
| 5 | **CI-generated verification manifest** | Python/PS generator parses our tweak YAML → `verification-manifest.json`; regenerated in CI so it can't drift | Chamber `tools/generate_verification_manifest.py` (proven design) | **M** |
| 6 | **Read-only post-run verifier + HTML report** | `Verify-UltraOS.ps1`: PASS/FAIL/WARN per tweak vs manifest, hardware checks, writes `ULTRAOS-REPORT.html` (+ .txt) to Desktop | Chamber `Verify-Chamber.ps1` colored output; winutil `Get-WinUtilTweaksStateReport`; UltraOS's "post-run report" differentiator | **M** |
| 7 | **Post-install companion folder** | Desktop folder: `1 Drivers/` (GPU/chipset links + optional NVIDIA .nip profile import), `2 Verify/` (verifier + report), `3 Toggles/` (Enable/Disable .cmd pairs per module), `START-HERE.bat` | Chamber PostInstall + Atlas AtlasDesktop numbered folders + XOS post-install scripts | **M** |
| 8 | **Toggle = probe + enable + disable triad** | Every toggle ships an "is-applied?" probe script + paired enable/disable scripts shared by wizard and companion folder | atlas-toolbox `IConfigurationService` (IsEnabled/Enable/Disable); winutil `Get-WinUtilToggleStatus` | **M** |
| 9 | **Update checker + drift watchdog** | playbook.conf `<Git>` + `UpgradableFrom any` for AME update check; scheduled task re-runs verifier after cumulative updates and drops a desktop warning on drift | Chamber UpgradableFrom/Git pattern; O&O Premium "automatically restores settings after Windows updates" — do it free + transparent | **M** |
| 10 | **Per-release transparency docs** | Publish `WHAT-CHANGED.md`, `WHAT-IS-REMOVED.md`, `SERVICES.md` (and hosts/telemetry blocklist as data file) every release | RapidOS "Readme Collection"; countering "snake oil" skepticism (Neowin) | **S** |
| 11 | **Config-validation CI gate** | yamllint + schema checks + safety test (forbid unapproved ops: no WinSxS deletion, no offline-hive edits, no driver removals in Safe) + build .apbx artifact | Atlas `apbx.yaml` CI; winutil Pester configs.Tests; Win11Debloat `TestSuiteSafety` | **S** |
| 12 | **Preview/dry-run experience** | "Review selections" wizard recap page (chosen options grouped by module + risk + est. time); standalone `Preview-UltraOS.ps1` (-WhatIf-style) listing what *would* change incl. current-state diff | winutil state detection + report; no playbook has a true dry-run — cheap differentiator for trust | **M** |
| 13 | **Per-tweak auto-generated docs site** | Docs generator reads the same tweak YAML → one page per tweak (description, risk, registry paths, undo behavior); link from wizard text where possible | winutil `devdocs-generator.ps1` + `link` fields (docs can never drift) | **M** |
| 14 | **26H2 (26300) + Windows Home support, anti-cheat-safe promise** | Add 26300 to SupportedBuilds ASAP w/ validation note; explicitly support Home; keep Secure Boot ON, no kernel driver (`UseKernelDriver` false), document EAC/Vanguard/BattlEye posture | Chamber already lists 26300; Atlas has no 26H2 and excludes Home; Chamber's anti-cheat-safe badge is a proven trust signal | **S–M** |
| 15 | **UltraOS Toolbox companion app (roadmap, phase 2)** | v1 = scripts folder (feature 7–8); v2 = WinUI 3 app with `IConfigurationService`-style toggle classes, profiles export/import, history log, Crowdin i18n | atlas-toolbox architecture (GPL-3.0, pattern-proven); RapidOS Toolbox precedent | **L** |

**Sequencing recommendation:** ship 1–4 + 10–11 + 14 with v1.0 (trust + UX baseline, mostly config-level); 5–9 + 12–13 as v1.1–1.2 (the differentiators that beat Chamber at its own game: tiered presets, full undo, dry-run, HTML report); 15 as a separate track.

---

## 5. Sources (all accessed 2026-10-07)

**Cloned & read locally** (`/home/z/my-project/repos/`):
- atlas-toolbox: https://github.com/Atlas-OS/atlas-toolbox (GPL-3.0; README, IConfigurationService.cs, HagsConfigurationService.cs, togglehistory.json, setup.iss)
- winutil: https://github.com/ChrisTitusTech/winutil (MIT; README, SPEC.md, config/tweaks.json, config/preset.json, functions/private/Get-WinUtilTweaksStateReport.ps1, tools/devdocs-generator.ps1, pester/)
- tiny11builder: https://github.com/ntdevlabs/tiny11builder (no LICENSE file; README, tiny11maker.ps1, tiny11Coremaker.ps1, autounattend.xml)
- revi = MeetRevision/playbook: https://github.com/MeetRevision/playbook (CC BY-SA 4.0; src/playbook.conf, src/Configuration/Tasks/revert.yml)
- Chamber-Playbook: https://github.com/ChamberTechFPS/Chamber-Playbook (CC BY-NC-SA 4.0; README.md, playbook.conf, Configuration/main.yml, tools/generate_verification_manifest.py, PostInstall/Verify/*)
- RapidOS: https://github.com/rapid-community/RapidOS (AGPL-3.0; README.md, RapidOS Sources/)
- playbook = plasXOC/playbook (PLAS/XOS): https://github.com/plasXOC/playbook (custom license; readme.md)
- Win11Debloat: https://github.com/Raphire/Win11Debloat (MIT; README, Regfiles/Undo/, Scripts/GUI/, Tests/)
- Windows10Debloater: https://github.com/Sycnex/Windows10Debloater (MIT; README.md)
- (context from briefing: Atlas-OS/Atlas clone at repos/atlas; trusted-uninstaller-cli https://github.com/Ameliorated-LLC/trusted-uninstaller-cli)

**Web (page_reader / curl):**
- O&O ShutUp10++ product page: https://www.oo-software.com/en/shutup10 (v3.6.1135, 2026-09-29; recommendations; Premium auto-restore) — also /en/docs/product/shutup10, /en/shutup10/faq (200 but generic)
- Atlas docs (edition support): https://docs.atlasos.net (Windows Version Support)
- Probed live (HTTP 200) community repos: https://github.com/Ameliorated-LLC/AME-10 · https://github.com/AtmosphereTeam/AtmosphereOS · https://github.com/KiyomizuSuzu/KiyomizuOS · https://github.com/MeowBot233/ThinNekoOS · https://github.com/Rob-QT/RivalsOS-Playbook · https://github.com/lucidslab/proplus_playbook · https://github.com/MagicTwint541/APEX · https://github.com/MrPcGamerYT/Z-LAG-OS · https://github.com/x2Swiftyouz/Akati-Os
- 404/dead as of survey: Raphire/Reclaim (Raphire's real tool = Win11Debloat)

**Web search snippets (search API returned domain-level URLs; snippet-level evidence, directional):**
- Neowin (2024-03-30) "AtlasOS or ReviOS for Win11?" — snake-oil skepticism
- xp-feed (2026-05-28) "ReviOS, AtlasOS, and XOS: Are They Worth It?" — ReviOS balanced vs Atlas deep
- GitHub-hosted comparison (2026-08-20) — ReviOS April 2026 playbook ~1.5 GB idle RAM; Atlas v0.5.0-hotfix lower
- Puget Systems (2017-05-24) — apply only O&O-recommended settings
- BleepingComputer forum (2025-12-24) — ShutUp10++ defaults + pop-up warnings
- ElevenForum (2024-05-21) — ShutUp10 profile "Add-Only"/"Replace-All" import modes
- LinusTechTips forum thread "AME Wizard (Ameliorated)" (found via search; not read in full ⚠️)

**Explicitly unverified (⚠️):** MinOS (no live project found); "Reclaim" as a Raphire repo (404); O&O in-app traffic-light exact colors/labels; deep features of the nine lightly-probed community playbooks in §3.9.
