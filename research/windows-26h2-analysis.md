# UltraOS Research Dossier — Windows 11 26H2 Fact Base (Build 26300)

**Task ID:** T1-d2 (retry of timed-out T1-d) · **Date:** 2026-10-07 · **Agent:** T1-d2
**Mission:** Verified 26H2 build number, GA date, rollout channel, UBR range, registry detection values, delta vs 25H2, optimization-relevant changes, early known issues — for UltraOS playbook authors.
**Prior coverage:** `00-recon-briefing.md` (env), `revios-playbook-analysis.md` (Revi SupportedBuilds=26300), `known-issues-compatibility.md` (gating/UCPD/Edge — NOT re-researched here).

## 0. SUMMARY TABLE (top-line facts)

| Fact | Value | Evidence (URL + date) | Status |
|---|---|---|---|
| **Build number** | **26300** (10.0.26300, x64 + ARM64) | learn.microsoft.com/en-us/windows/whats-new/whats-new-windows-11-version-26h2 (updated 2026-09-29); en.wikipedia.org/wiki/Windows_11_version_history (read 2026-10-07) | ✅ VERIFIED |
| **Marketing name** | "Windows 11 **2026 Update**" | tomshardware forum (2026-09-29); windowsforum (2026-10-01); Wikipedia | ✅ VERIFIED |
| **GA date** | **September 29, 2026** | Wikipedia version-history table (26H2: "September 29, 2026"); corroborated by windowsforum.com (2026-10-01), dellenny.com (2026-09-30), blog.thomasmarcussen.com (2026-09-28), forums.tomshardware.com (2026-09-29) — all state Sep 29, 2026 | ✅ VERIFIED (MS Learn "What's new" page last updated 2026-09-29, same date) |
| **Rollout channel** | **Enablement package** (~small, single restart) from 25H2 (26200) and 24H2 (26100); shares servicing branch with 25H2/24H2 | learn.microsoft.com "What's new in 26H2" (official: "Delivered as an enablement package... single restart"); wincdkey.com (2026-07-03): "~200KB enablement package"; windowsphoneinfo.com (2026-07-20) | ✅ VERIFIED (official MS doc) |
| **Rollout pacing** | Controlled/gradual rollout; initially opt-in via "Get the latest updates as soon as they're available" toggle | community.spiceworks.com (2026-09-30); dellenny.com (2026-09-30) | ✅ VERIFIED (secondary sources quoting MS "How to get the Windows 11 2026 Update") |
| **Release Preview** | Build **26300.9278** announced 2026-08-27 | windowsreport.com (2026-08-27); elevenforum.com RP thread | ✅ VERIFIED |
| **GA-era UBR** | 26300.9550 cited as GA build (elevenforum, 2026-09-28); prior agent saw .9457; Beta-era .9032 (2026-08-21), RP .9278 | elevenforum.com (2026-09-28); pureinfotech.com (2026-08-21) | ⚠️ PARTIAL — exact GA KB number still unpinned (MS update-history page is JS/Cloudflare-gated) |
| **Lifecycle (Home/Pro)** | Servicing until ~October 10, 2028 (Enterprise/Edu: Oct 9, 2029) | Wikipedia version-history table (read 2026-10-07) | ✅ VERIFIED |
| Related builds | 26H1 = **28000** (ARM-only, Feb 2026); Dev-Channel 26300.7965 (Mar 2026), 26300.8155 | Wikipedia; itstechbased.com (2026-03-07); thewincentral.com | ✅ (context) |
| Registry detection | `CurrentBuildNumber`="26300", `DisplayVersion`="26H2" (expected; see §2) | ⚠️ UNVERIFIED on live machine (no Windows in sandbox) | ⚠️ UNVERIFIED |

## 1. VERIFICATION: BUILD NUMBER, GA DATE, CHANNEL, UBR

### 1.1 Build number = 26300 (independently verified — CONFIRMED)
- **Microsoft Learn, "What's new in Windows 11, version 26H2 for IT pros"** (https://learn.microsoft.com/en-us/windows/whats-new/whats-new-windows-11-version-26h2, page footer "Last updated on 09/29/2026", read 2026-10-07): "Windows 11, version 26H2 is the next annual feature update... It builds on the same servicing foundation as Windows 11, versions 25H2 and 24H2." Official doc whose canonical URL embeds `whats-new-windows-11-version-26h2`.
- **Wikipedia, "Windows 11 version history"** (https://en.wikipedia.org/wiki/Windows_11_version_history, read 2026-10-07): version table row: "Windows 11 2026 Update | Latest version: 26H2 | **26300** | x64, ARM | **September 29, 2026** | October 10, 2028 | October 9, 2029". Body: "It will be shipped as an **enablement package** for the Windows 11 2025 Update alongside version 26H1, and carry the build number **10.0.26300**."
- News corroboration (GA 2026-09-29): windowsforum.com "Microsoft released Windows 11 version 26H2, also called the Windows 11 2026 Update, on September 29, 2026" (2026-10-01); dellenny.com "generally available on September 29, 2026, with Microsoft using a controlled rollout" (2026-09-30); blog.thomasmarcussen.com "generally available as of September 29, 2026" (2026-09-28); forums.tomshardware.com (2026-09-29).

### 1.2 Rollout channel = enablement package (OFFICIAL, verified)
Microsoft Learn "What's new in 26H2" (2026-09-29), section *Servicing and deployment* — direct quotes:
> "Windows 11, version 26H2 provides a familiar update experience: Delivered as an **enablement package** for eligible devices running Windows 11, versions 25H2 and 24H2. **Fast installation with a single restart** in most scenarios. Reduced validation effort because supported versions share the same underlying platform."

> "Because Windows 11, versions 26H2, 25H2, and 24H2 share a **common servicing branch**, many new features and improvements have already been delivered through monthly servicing updates."

**Playbook consequence (important):** 26H2 = enablement flip of 26100/26200 → same driver/service layout as 24H2/25H2 at flip time; most 25H2 tweak mechanics carry over; UBR resets matter for gating (see §2). WindowsLatest (2026-08-28): Microsoft prepared dedicated **26H2 installation media** (ISO) late Aug 2026.

### 1.3 UBR range as of 2026-10-07
- Dev/Beta line: 26300.7965 (2026-03-07, itstechbased.com) → 26300.8155 (thewincentral.com) → Beta 26300.9032 (2026-08-21, pureinfotech.com) → Release Preview **26300.9278** (2026-08-27, windowsreport.com + blogs.windows.com) → **GA 26300.9550** (elevenforum.com, 2026-09-28: "Windows 11 version 26H2 build 26300.9550 now [available]... slated for October 13, 2026"). Prior agent (T1-a) saw ".9457" (NamuWiki); the .9550 figure is newer and closer to GA day.
- ⚠️ UNVERIFIED: exact GA KB number (support.microsoft.com "Windows 11, version 26H2 update history" page exists — seen 2026-09-22 in search results — but is Cloudflare/JS-gated to both curl and page_reader in this sandbox). **Action for build agent: pin the GA/October-patchday KB from `winget`/`Get-HotFix` on a live 26300 box, or via https://support.microsoft.com/en-us/windows/update-history from a browser.**
- Practical gating guidance: accept `CurrentBuildNumber=26300` with **UBR ≥ 9550** for "GA-patched" checks, or simply gate on build only (ReviOS style — they list only 26300 in SupportedBuilds).


## 2. DETECTION: REGISTRY VALUES FOR PLAYBOOK GATING

Registry hive: `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion`

| Value | Expected on 26H2 | Basis | Status |
|---|---|---|---|
| `CurrentBuildNumber` (and `CurrentBuild`) | **"26300"** | gaijin.at version table ("Windows 11, Version 26H2 | 10.0 | 26300 | 2026-09-29", read 2026-10-07); MS Q&A (learn.microsoft.com, 2026-08-04): "Your build is also 26H2... Build 26300 is now 26300.9032" | ✅ VERIFIED (build=26300; value name standard since Vista) |
| `UBR` (DWORD) | ≥ 9550 at GA (see §1.3); rises with monthly CUs | elevenforum 26300.9550 (2026-09-28) | ⚠️ exact GA UBR unconfirmed (.9457 vs .9550 discrepancy) |
| `DisplayVersion` (REG_SZ) | **"26H2"** | Convention: since Win10 20H2 every enablement release sets DisplayVersion to its marketing name (24H2→"24H2", 25H2→"25H2" — confirmed on real machines in Atlas/Revi ecosystems); Wikipedia + gaijin.at use "26H2" as the version label | ⚠️ UNVERIFIED on a live 26300 box (no Windows in sandbox) — treat as high-confidence inference |
| `ProductName` | "Windows 11 ..." (unchanged pattern) | — | ⚠️ UNVERIFIED |

**Enablement-package semantics (why this matters):** because 26H2 is an enablement flip of the 24H2/25H2 servicing branch, a 25H2 machine (26200.xxxx) becomes 26300.yyyy with `CurrentBuildNumber` changing but the **component store, drivers, services layout staying ~identical** at flip time (MS Learn §1.2). Detection snippets (ReviOS pattern, from `revios-playbook-analysis.md` line 106) read `CurrentBuild` and branch with `if %build% gtr 19045` — these keep working; extend comparisons: `26300 > 26200 > 26100 > 19045`.
**AME Wizard gate:** ReviOS already ships `<string>26300</string>` in SupportedBuilds (revios-playbook-analysis.md lines 72, 102) → the wizard's build gate matches on the 26300 build number, so adding `26300` to UltraOS's `SupportedBuilds` is sufficient; no DisplayVersion check is needed at wizard level. Post-run, prefer `CurrentBuildNumber` + `UBR` for update-state reporting.

## 3. DELTA vs 25H2 (features, for playbook adaptation)

Source unless noted: **Microsoft Learn, "What's new in Windows 11, version 26H2 for IT pros"** (https://learn.microsoft.com/en-us/windows/whats-new/whats-new-windows-11-version-26h2, last updated 2026-09-29, read 2026-10-07). All items below are ✅ per that official page unless marked otherwise.

### 3.1 Rollout/servicing model
- Enablement package from 24H2/25H2, single restart, common servicing branch (24H2+25H2+26H2). Continuous-innovation model: "Some features that organizations associate with 26H2 might already be present on devices before the feature update is installed" — **playbook must not assume feature presence implies 26H2**; gate tweaks on build, not features.

### 3.2 New in 26H2 / enabled by default (IT-pro relevant)
- **Windows settings backup** ON by default for commercial devices (preserves settings + Store app lists) — new telemetry/backup surface; policy-controllable.
- **App-specific taskbar actions** on by default (commercial).
- **File Explorer enhancements** previously behind temporary commercial controls now on by default.
- **Administrator protection** (JIT admin privileges + profile separation) — OFF by default, Intune/GPO enable.
- **Sysmon (System Monitor) built into Windows** — OFF by default; "supports custom configuration files", events to Event Log. ⚠️ exact binary/service name on 26300 not yet enumerated (look for `Sysmon`/`Sysmon64` presence — flag for build agent).
- **Smart App Control can now be toggled without clean install** (previously permanent at install time).
- **Passkey plugin credential managers**; Hello ESS peripheral fingerprint sensors.
- **Driver security change (BIG):** "Windows changes how the Windows kernel trusts third-party drivers. **Default trust for cross-signed drivers is removed.** What remains allowed are drivers from the Windows Hardware Compatibility Program (WHCP) and an allow list of trusted legacy drivers. Windows audits driver compatibility for at least 100 hours and three restarts before enabling enforcement." → Impacts: kernel-driver-based playbook mechanics (Atlas `UseKernelDriver`), driver-signing bypass tools, some anti-cheat/overclock utilities. Enforcement is staged (audit first) — expect broken legacy-driver loads on 26H2 over time.
- **Post-quantum crypto** (ML-KEM/ML-DSA, FIPS 203/204) in CNG/.NET.
- Device association for Autopilot device preparation; first sign-in restore (Entra hybrid, Cloud PCs, multi-user); Enterprise State Roaming managed via settings-backup policies.
- **Point-in-time restore** (rollback PC incl. apps/settings/files to automatic restore point) — new recovery surface, likely new scheduled tasks ⚠️ task names not yet enumerated.
- **Quick machine recovery** one-time scan integration.
- **Policy-based removal of preinstalled Microsoft apps**: GPO to specify additional MSIX/APPX **package family names** for removal — official, supported debloat primitive (useful as an UltraOS complement/alternative to deprovisioning).
- File Explorer: AI actions (edit images/summarize docs; `Summarize` in Copilot for OneDrive/SharePoint, M365+Copilot license required); hover quick actions (`Open file location`, `Ask Copilot`) for work/school; **new archive formats** uu, cpio, xar, nupkg; View/Sort preferences preserved; voice typing on rename; Home launches faster.
- Windows Search: previews, typo-tolerant app search, clearer result typing, **auto-indexing of frequently used folders** (setting: Settings > Privacy & security > Search) — privacy-relevant toggle.
- **Redesigned Start menu**: scrollable `All` section, category/grid views, responsive layout, choose Start size, show/hide Pinned/Recent/All sections.
- **Taskbar: reposition to bottom/top/left/right, smaller taskbar option**, AI-agent monitoring from taskbar (**Researcher in Copilot** is first experience; progress + completion notifications — new AI surface).
- Multi-App Camera + Basic Camera mode (GPO-configurable); Bluetooth LE Audio/mute-sync/reconnection fixes; USB4 dock resume reliability.
- **Windows Update: fewer restarts** — eligible updates install together with monthly security update; "Available updates" page lists individuals; **sleep-respecting behavior** (returns to sleep after update even with auto-sleep=Never).
- Magnifier (zoom %, increments, color tint), Narrator Braille Viewer, Voice access (natural language on Copilot+ PCs, +fr/de/es/ko, Voice Isolation).
- **Task Manager**: NPU/NPU Engine columns (Processes/Users/Details), NPU memory columns, GPU neural engines on Performance page, **Isolation column** (AppContainer visibility).
- **Secure batch file processing mode** (admin opt-in; prevents batch files changing during execution).
- Accessibility/others: see MS Learn page.

### 3.3 Removed / deprecated in 26H2 (official list)
- **WMIC removed** (was removed in 24H2+; in 26H2 "no longer available as a Feature on Demand (FoD)") → any playbook step still invoking `wmic` will fail; use CIM cmdlets (`Get-CimInstance`). (Prior dossiers confirm Atlas/Revi already avoid wmic.)
- The MS Learn page's removed-features list ends at WMIC in the extract we pulled; the full "deprecated features" list lives at learn.microsoft.com Windows client deprecated features page (⚠️ not fetched this run — check https://learn.microsoft.com/en-us/windows/whats-new/deprecated-features at build time).
- Wikipedia 26H2 section lists no additional removals; feature focus is "UI improvements" (taskbar relocation/small taskbar, WinUI porting of legacy interfaces, File Explorer performance, **optimization for 8 GB RAM PCs**).

### 3.4 AI/Copilot/Recall changes (news-verified)
- **Copilot de-integration is a deliberate 26H2 theme** (Wikipedia: "Reducing the integration of Microsoft Copilot within the system"): thurrott.com (2026-01-30) "Microsoft is walking back Windows 11's AI overload — scaling down Copilot and rethinking Recall in a major shift"; hardwarecanucks.com (2026-01-30) (streamline/remove Copilot integrations across in-box apps); windowsphoneinfo.com (2026-03-16) "Microsoft has abandoned plans to integrate Copilot into Windows 11 system interfaces, including notifications, Settings, and File Explorer"; me.pcmag.com (2026-04-10) "Microsoft removes the Copilot button in Notepad and drops all AI from its Snipping Tool".
- Counterpoint: new AI surfaces still ship (File Explorer AI actions, taskbar AI-agent monitoring/Researcher — MS Learn). **Net for UltraOS: Copilot debloat list needs 26H2 re-audit rather than blind reuse of 25H2 lists; expect fewer in-box Copilot hooks, but verify appx names at build time.** ⚠️ exact new/removed appx package names for 26H2 not published in sources read this run — enumerate on a live 26300 install via `Get-AppxPackage` before finalizing UltraOS's appx.yml.
- Recall: "rethinking Recall" (thurrott) — **no verified claim of removal**; assume Recall/Click To Do remain on Copilot+ hardware. ⚠️ UNVERIFIED whether 26H2 changes Recall defaults.

## 4. OPTIMIZATION-RELEVANT CHANGES (26H2 specifics)

| Area | 26H2 status | Evidence | Notes for UltraOS |
|---|---|---|---|
| **HVCI / Memory Integrity** | Microsoft expanding auto-enable/default to more devices; HVCI depends on VBS | betanews.com (2026-09-02) "Windows 11 auto-enables Memory Integrity"; au.pcmag.com (2026-09-03) "Microsoft is set to enable Memory Integrity in Windows 11 by default... might harm your gaming frames"; guru3d.com (2026-09-04) "expansion means more Windows 11 devices will have the feature enabled by default" | Performance playbooks should detect HVCI/VBS state (Win32_DeviceGuard / `HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard`) and offer a toggle; gaming-perf impact up to ~25% claimed on linustechtips.com forums (2026-06-24). ⚠️ Whether upgrades (vs clean installs) get auto-enabled is UNVERIFIED |
| **Kernel driver trust** | Cross-signed driver default trust REMOVED; WHCP + legacy allow list only; ≥100h/3-reboot audit before enforcement | MS Learn "What's new in 26H2" (official) | If UltraOS ever ships a kernel driver (Atlas-style `UseKernelDriver`), it must be WHCP-signed; audit mode gives grace period. Test-driver-based tweaks on 26300 early |
| **UCPD** | Still present on 26H2; dynamic-rules PE policy engine (heavier than 24H2/25H2) | xusheng.dev + binary.ninja 2026 research, as summarized in `known-issues-compatibility.md` §3 (not re-researched) | Keep Atlas-style `UCPDDisabled` requirement decision; ⚠️ UCPD service default Start type on 26300 UNVERIFIED |
| **Edge removal** | No 26H2-specific breakage reported in sources read; tools current as of late Sep 2026 (Remove-MS-Edge 2026-09-23; he3als EdgeRemover v1.9.5 2025-06-13) | `known-issues-compatibility.md` §4 (prior coverage) + absence of 26H2 reports | Enablement-package model ⇒ Edge stack likely identical to 25H2; still re-test on 26300. ⚠️ UNVERIFIED on live 26H2 |
| **WMIC** | Gone (not even FoD) | MS Learn (official) | Audit UltraOS scripts for `wmic` usage (also hits 24H2/25H2) |
| **Windows Update pacing** | Update bundling + restart reduction; controlled GA rollout via "Get the latest updates as soon as they're available" | MS Learn; community.spiceworks.com (2026-09-30) | Playbook prerequisite "No pending updates" still fine; note users on 25H2 won't all see 26H2 immediately |
| **Windows Search auto-indexing** | New: auto-index frequently used folders | MS Learn | New privacy/IO toggle for privacy preset: Settings > Privacy & security > Search |
| **Windows settings backup** | ON by default (commercial devices) | MS Learn | Disable policy candidate for privacy preset |
| **Sysmon built-in** | Off by default | MS Learn | No action needed by default; document as optional hardening |
| **GameDVR / Game Bar** | No 26H2-specific changes found in sources read | (absence) | ⚠️ UNVERIFIED — carry over 25H2 tweaks, re-verify at build time |
| **New Settings hives** | Redesigned Start/taskbar settings; no new documented Settings hive found | MS Learn (UI items listed §3.2) | ⚠️ Enumeration of new Settings URIs/SystemPages on 26300 pending live audit |
| **New services / scheduled tasks** | None named in sources read; Point-in-time restore + quick machine recovery + AI-agent monitoring are candidate new components | (absence; MS Learn feature list) | ⚠️ UNVERIFIED — run `Get-Service`/`Get-ScheduledTask` diff vs 25H2 on live boxes before freezing services.yml/tasks |

## 5. KNOWN ISSUES in early 26H2 (relevant to optimization tools)

1. **HVCI auto-enable vs legacy drivers / gaming perf** — PCMag (2026-09-03) and betanews (2026-09-02) report default Memory Integrity expansion; LinusTechTips forum consensus (2026-06-24): 2–25% perf impact in games. Optimization tools that disable HVCI must also clean the "incompatible driver" list or Windows may re-prompt.
2. **Settings AI agent** — windowsforum.com (2026-09-30): "Windows 11 26H2's Settings agent requires user approval" — new AI agent surface in Settings; debloat/privacy presets should locate its toggle. ⚠️ exact setting name unverified.
3. **Radeon crashes** — windowsforum.com (2026-09-30): reported Radeon crashes "began after a September update for 24H2 and 25H2" — because 26H2 shares the servicing branch, the same driver issue can appear on 26300; not playbook-caused but expect user reports.
4. **Controlled rollout confusion** — spiceworks (2026-09-30): 26H2 initially only offered with "Get latest updates" toggle → support flow: users on 25H2 asking "where is 26H2".
5. ⚠️ **Microsoft's official known-issues table for 26H2** lives behind the JS/Cloudflare-gated support.microsoft.com "Windows 11, version 26H2 update history" + Windows release health pages (both unreachable from this sandbox via curl and page_reader) — **build agent must re-check** https://support.microsoft.com/en-us/windows/update-history and https://learn.microsoft.com/en-us/windows/release-health/ from a browser before release. No KB-listed 26H2 known issue is captured in this dossier.
6. **Cross-signed driver enforcement ramp** (MS Learn): staged enforcement (≥100h/3 reboots audit) means legacy-driver breakage will surface gradually — a rolling support risk for older tools (e.g., unsigned fan-control/OC utilities) on 26H2.

## 6. PLAYBOOK ADAPTATION CHECKLIST FOR 26H2 (UltraOS)

1. **SupportedBuilds**: add `26300` (match ReviOS; Atlas is still 26100/26200 per issue #1739 — market gap). Consider keeping 26100/26200 for the Safe preset.
2. **Gating**: gate on `CurrentBuildNumber` only at wizard level; inside scripts branch with `ge 26100` (24H2 family) vs `ge 26300` (26H2) where behavior differs; treat `DisplayVersion="26H2"` as an inference (verify on live box, don't ship as sole gate).
3. **UBR baseline**: expect GA-era 26300.9550; do NOT hard-require a UBR (patch Tuesday 2026-10-13 will move it — elevenforum snippet: "slated for October 13, 2026").
4. **Driver signing**: verify any helper driver is WHCP-signed or WHQL-attested; add a pre-flight check that warns when cross-signed/legacy drivers are installed (26H2 will progressively block them).
5. **HVCI/VBS preset logic**: add detection + optional disable for the performance presets (Balanced/Extreme) with clear security trade-off messaging; re-enable path in revert.yml.
6. **Appx audit**: enumerate 26300 provisioned appx on a live install before freezing appx.yml — Copilot integration shrank in 26H2 (Notepad Copilot button removed, Snipping Tool AI dropped) so 25H2 removal lists may reference now-nonexistent packages (make removals tolerant of missing packages).
7. **wmic sweep**: confirm zero `wmic` calls in UltraOS scripts/payloads.
8. **New toggle candidates for privacy preset**: Windows settings backup (default ON, commercial), Search auto-indexing of frequent folders, taskbar AI-agent monitoring (Researcher), Settings AI agent approval.
9. **Services/tasks diff**: produce `Get-Service` + `Get-ScheduledTask` diff 25H2→26H2 on live machines before freezing services.yml; expect candidates around point-in-time restore, quick machine recovery, AI agent/taskbar monitoring, built-in Sysmon (off by default — no action unless user enables).
10. **Update-flow note**: 26H2 enablement = single restart; document that UltraOS can run on 26300 immediately after flip; keep "NoPendingUpdates" requirement (Windows Update now bundles updates with the monthly CU — a pending bundle may reboot mid-playbook).
11. **GPO debloat primitive**: consider using the new policy-based preinstalled-app removal (MSIX/APPX package family names) as a *supported* complement to deprovisioning in the Safe preset.
12. **Re-verify before release**: MS known-issues list for 26H2 (support.microsoft.com update history, Cloudflare-gated here), exact GA KB number, UCPD start type on 26300, Recall defaults on Copilot+ hardware, full deprecated-features page.

---
### Sources index (all read/searched 2026-10-07)
- learn.microsoft.com/en-us/windows/whats-new/whats-new-windows-11-version-26h2 (last updated 2026-09-29) — PRIMARY, full text captured
- en.wikipedia.org/wiki/Windows_11_version_history (version table + 26H2 section)
- www.gaijin.at/en/infos/windows-version-numbers (version/build/GA-date table)
- web_search result pages (snippets + dates, URLs domain-level in this backend): windowsforum.com (2026-10-01, 2026-09-30), dellenny.com (2026-09-30), blog.thomasmarcussen.com (2026-09-28), forums.tomshardware.com (2026-09-29), community.spiceworks.com (2026-09-30), ebs.publicnow.com (MS "How to get the Windows 11 2026 Update", 2026-09-28), elevenforum.com (2026-09-28 GA .9550; RP .9278), pureinfotech.com (2026-08-21), windowsreport.com (2026-08-27), windowsphoneinfo.com (2026-07-20, 2026-03-16), wincdkey.com (2026-07-03), itstechbased.com (2026-03-07), thewincentral.com (Dev .8155), systweak.com (2026-08-17), windowslatest.com (2026-08-28), betanews.com (2026-09-02), au.pcmag.com (2026-09-03), guru3d.com (2026-09-04), linustechtips.com (2026-06-24), thurrott.com (2026-01-30 + RP article), me.pcmag.com (2026-04-10), hardwarecanucks.com (2026-01-30), learn.microsoft.com Q&A (2026-08-04, 2026-05-13)
- Prior dossiers cross-referenced (not re-researched): `revios-playbook-analysis.md`, `known-issues-compatibility.md`

### ⚠️ UNVERIFIED items (explicit list)
1. `DisplayVersion`="26H2" (high-confidence inference; not tested on live 26300)
2. Exact GA KB number + final GA UBR (.9457 vs .9550 discrepancy; MS history page gated)
3. UCPD service default Start type on 26300
4. Edge removal behavior on live 26H2 (no reports of breakage; not tested)
5. New/removed appx package names, new services, new scheduled tasks on 26300 (need live diff)
6. Recall defaults on Copilot+ hardware in 26H2 ("rethinking Recall" is a report, not a confirmed spec change)
7. Whether HVCI auto-enable applies to in-place upgrades or only new installs/imaging
8. Full deprecated/removed features list beyond WMIC (page not fetched)
9. GameDVR/Game Bar changes in 26H2 (nothing found — absence of evidence only)
