# UltraOS Architecture — v1.0.0 (LOCKED DESIGN)
**Main agent synthesis of 10 research dossiers. Build fleet: follow this document exactly. Deviations require a worklog note.**

Identity: UltraOS v1.0.1 — GPL-3.0 Windows optimization playbook for **AME Wizard** (.apbx)
Target builds: **26300 (26H2, primary)** + 26200 (25H2) + 26100 (24H2) — all share the servicing branch (T1-d2 verified)
Editions: Home + Pro (registry/policy only, no GPO-only mechanisms without registry equivalents)
Design: Hybrid — Atlas-grade performance rigor + Revi-style daily-use balance, with Safe/Balanced/Extreme presets, opt-in extras, rollback + post-run report, faster execution.

## 1. Repo layout (/home/z/my-project/ultraos/)
```
ultraos/
├── README.md, LICENSE (GPL-3.0), NOTICE, CONTRIBUTING.md, SECURITY.md, CHANGELOG.md
├── .gitignore, .editorconfig, .github/workflows/build.yml
├── scripts/                      # build & validation (run on THIS Linux box)
│   ├── build-playbook.sh         # builds src/playbook → dist/UltraOS-Playbook-v1.0.0.apbx
│   ├── validate-playbook.py      # structure + YAML + playbook.conf checks (pyyaml custom loader)
│   └── make-artifacts.py         # PIL: playbook.png + Images/*.png browser icons
├── docs/                         # user documentation (T3-k)
├── research/                     # the 10 research dossiers (already present — ships in repo)
└── src/
    ├── release-zip/              # files shipped beside .apbx (README-FIRST.txt, CHANGELOG, LICENSE)
    └── playbook/                 # ← contents of this dir are zipped at ARCHIVE ROOT into .apbx
        ├── playbook.conf         # XML metadata (below)
        ├── playbook.png          # 256×256 (PIL-generated)
        ├── Images/               # brave.png firefox.png librewolf.png (128px-high, PIL)
        ├── Configuration/
        │   ├── main.yml          # ENTRY (engine prefers main.yml over custom.yml)
        │   ├── ultraos/          # start.yml (hive load, folders, backups) · revert.yml (stock values)
        │   └── tweaks/           # ALL module files (see §5 file map)
        └── Executables/          # PS1/CMD tooling + UltraOSFolder/ (post-install toggles)
```
**.apbx = `zip -P malte` of src/playbook/* at archive root** (files at top level, NOT nested in a folder). Entry = `Configuration/main.yml`.

## 2. playbook.conf (LOCKED values)
- Name: `UltraOS` · Username: `UltraOS` · Title: `UltraOS v1.0.1` · Version: `1.0.0`
- ShortDescription: `UltraOS Playbook for Windows 11 24H2–26H2` · ProductCode: `64`
- SupportedBuilds: `26100`, `26200`, `26300`
- Requirements: `DefenderToggled`, `NoAntivirus`, `Internet`, `NoPendingUpdates`, `PluggedIn` (same set Atlas+Revi both use — proven; NO UCPDDisabled because UltraOS never writes UserChoice/file-association keys)
- UniqueId: `00000000-0000-4000-556c-7472614f5321` · EstimatedMinutes: `8` · Overhaul: `true` · UseKernelDriver: `false` · AllowUnsupportedUpgrades: `false` · SupportsISO: `true`
- Git: `https://github.com/UltraOS-Project/playbook` (public source repo, Revi-style) · Website: org home · InstallGuide: docs/INSTALL.md anchor
- ISO: DisableBitLocker true, DisableHardwareRequirements true · OOBE: 3 BulletPoints (Rocket Performance / Privacy Privacy / Lock Control), Internet `Force`
- ProgressText: concise, mentions report location `C:\Windows\UltraOS\install-report.html`
- **FeaturePages (5, in order):**
  1. RadioPage `preset` (Required, DefaultOption `preset-balanced`, description explains tiers): `preset-safe` "Safe — disable-only, everything reversible" / `preset-balanced` "Balanced — recommended daily-driver (default)" / `preset-extreme` "Extreme — max performance, removes more apps"
  2. RadioPage `restore point` (Required, DefaultOption `rp-on`): `rp-on` "Create System Restore Point (recommended)" / `rp-off` "Skip restore point"
  3. RadioPage `updates` (Required, DefaultOption `wu-auto`): `wu-auto` "Automatic Windows Updates (recommended)" / `wu-notify` "Notify only (manual install)"
  4. CheckboxPage `extras` (Required, all opt-in, unchecked): `opt-uninstall-edge` "Remove Microsoft Edge" · `opt-disable-defender` "Keep Defender disabled (not recommended)" · `opt-disable-mitigations` "Disable CPU mitigations (older CPUs only)" · `opt-disable-vbs` "Disable Core Isolation/VBS (not recommended)" · `opt-max-performance` "Maximum Performance power scheme (no power saving)" · `opt-disable-hibernation` "Disable Hibernation" · `opt-strip-recall` "Strip Recall/AI features"
     — each with TopLine/BottomLine warning + docs link. Max 4 options per CheckboxPage per engine limits → SPLIT into two CheckboxPages (4 + 3).
  5. RadioImagePage browser (Required, DependsOn `software`, DefaultOption `browser-brave`, CheckDefaultBrowser true): first `<RadioImageOption None="true"/>`, then Brave/Firefox/LibreWolf with FileName + gradient colors. Uses the `<Software><Package Option="browser-X" DefaultWebBrowser="true">` element (Revi pattern — engine installs it; NO custom PS installer).

## 3. Option name registry (STRICT — YAML `option:` gates must use EXACTLY these)
| Option | Type | Semantics |
|---|---|---|
| `preset-safe` / `preset-balanced` / `preset-extreme` | radio | depth tier (exactly one active) |
| `rp-on` / `rp-off` | radio | restore point |
| `wu-auto` / `wu-notify` | radio | update policy |
| `opt-uninstall-edge`, `opt-disable-defender`, `opt-disable-mitigations`, `opt-disable-vbs`, `opt-max-performance`, `opt-disable-hibernation`, `opt-strip-recall` | checkbox | extras (opt-in) |
| `browser-brave`, `browser-firefox`, `browser-librewolf` | radio-image | browser (engine Software section) |

## 4. Preset gate patterns (use on EVERY gated action)
- Level SAFE (runs under every preset): **no `option:` gate**
- Level BALANCED (runs when Balanced or Extreme): `option: '!preset-safe'`
- Level EXTREME: `option: 'preset-extreme'`
- Extras: `option: 'opt-...'` — extras are NEVER preset-gated (explicit user choice wins at any tier)
- Version-specific: file-level `builds: ['>=26100']` style lists (engine supports operators; recall/AI = `>=26100`)
- Module toggling in v1 = include-level (main.yml `!task:` lines, grouped + commented per module — user comments out a line to skip a module; Atlas-style, documented in FAQ)

## 5. Module → file map (OWNERSHIP — each file has EXACTLY one agent; nobody edits others' files)
| Module (agent) | Files under src/playbook/ |
|---|---|
| Debloat (T3-a) | `Configuration/tweaks/debloat/appx-removals.yml`, `debloat/edge-removal.yml`, `debloat/reinstall-blockers.yml`, `Executables/EDGE-UNLOCK.ps1` |
| Privacy (T3-b) | `tweaks/privacy/telemetry-services.yml`, `privacy/telemetry-policies.yml`, `privacy/settings-privacy.yml`, `privacy/cloud-content.yml`, `privacy/ai-features.yml`, `privacy/app-telemetry.yml`, `privacy/extras-extreme.yml` |
| Services (T3-c) | `Configuration/ultraos/services.yml`, `tweaks/services/extreme-services.yml` |
| Tasks (T3-d) | `tweaks/tasks/telemetry-tasks.yml`, `tasks/maintenance-tasks.yml` |
| Network (T3-e) | `tweaks/network/core.yml`, `network/nic-config.yml`, `network/extreme.yml` |
| Performance (T3-f) | `tweaks/performance/gaming.yml`, `performance/system.yml`, `performance/power.yml`, `performance/extreme.yml` |
| Visual+QoL (T3-g) | `tweaks/visual/context-menu.yml`, `visual/taskbar.yml`, `visual/explorer.yml`, `visual/extras.yml`, `tweaks/qol/system-info.yml`, `qol/shortcuts.yml`, `qol/updates.yml` |
| Security (T3-h) | `tweaks/security/defender-reenable.yml`, `security/defender-disable.yml`, `security/mitigations.yml`, `security/vbs.yml` |
| Rollback+Report (T3-i) | `Executables/RESTOREPOINT.ps1`, `BACKUP.ps1`, `APPLYHIVE.ps1`, `REPORT.ps1`, `CLEANUP.ps1`, `UNDO.ps1`, `Undo.cmd`, `Configuration/ultraos/revert.yml`, `tweaks/ultraos/finish.yml` |
| UltraOS folder (T3-j) | `Executables/UltraOSFolder/**` (toggle pairs + PS + docs.url), `tweaks/ultraos/copy-folders.yml` |
| Docs (T3-k) | `README.md`, `docs/**`, `NOTICE`, `CONTRIBUTING.md`, `SECURITY.md`, `CHANGELOG.md`, `src/release-zip/**` |
| Packaging/CI (T3-l) | `.github/workflows/build.yml`, `scripts/build-playbook.sh`, `scripts/validate-playbook.py`, `scripts/make-artifacts.py`, final .apbx build + SHA256SUMS |

## 6. main.yml pipeline (order LOCKED; speed-annotated)
```
1.  reg load HKU\AME_UserHive_Default C:\Users\Default\NTUSER.DAT   (oobe:false, wait)
2.  !writeStatus "Preparing UltraOS"
3.  tweaks/ultraos/copy-folders.yml      → copies Executables\UltraOSFolder + scripts to %WinDir%\UltraOS
4.  ultraos/start.yml                    → STOP-OLD-FOLDERS cleanup, DISABLENOTIFS equivalent (single PS), manifest marker
5.  RESTOREPOINT.ps1                     (option: rp-on, weight 3)
6.  BACKUP.ps1                           → services reg export + appx list + tasks state → %WinDir%\UltraOS\Backups
7.  ultraos/services.yml                 (core service config)
8.  debloat module files (T3-a)
9.  privacy module files (T3-b)
10. tasks module files (T3-d)
11. network module files (T3-e)
12. performance module files (T3-f)
13. visual + qol files (T3-g)
14. security module files (T3-h: defender-disable OR defender-reenable LAST — after all other actions)
15. APPLYHIVE.ps1                        (single-pass default-user hive mirror of all HKCU writes)
16. tweaks/ultraos/finish.yml            → REPORT.ps1 (builds install-report.html/.txt from Backups diff), re-enable notifications, ExecutionPolicy RemoteSigned, final !writeStatus
17. reg unload HKU\AME_UserHive_Default  (oobe:false)
```
Speed rules baked in: ONE `!writeStatus` per module (not per file), zero `!cmd`/`!powerShell` where a native action exists, no scheduled reboots, no TiWorker syncs, no component cleanup in v1, browser via engine `<Software>` (no custom installer), total target < 400 actions (Atlas: 812).

## 7. Key v1 scope decisions (do NOT expand without user request)
1. **No sxsc/CAB component stripping** (Atlas's mechanism needs Windows-only build tooling + code-signing). UltraOS v1 disables at service/registry/package level. Defender/telemetry component removal = v1.1 roadmap.
2. **No kernel driver** (`UseKernelDriver:false`). TrustedInstaller privileges via engine only.
3. **No UCPD fight**: UltraOS never writes UserChoice/file-association keys → no UCPDDisabled requirement.
4. **Edge removal** = `AllowUninstall` unlock + `setup.exe --uninstall --system-level --force-uninstall` + appx sweep + deprovision keys (opt-in only; T1-h2 mechanism; NO code copied from Revi's EDGE.ps1 — CC BY-SA).
5. **Defender**: enters install toggled off (requirement). Default (`!opt-disable-defender`) → re-enable at pipeline end. If `opt-disable-defender` → keep off + double-write `DisableAntiSpyware` policies (2026 gpupdate auto-removal workaround from T1-h2) + post-install toggle in UltraOS folder.
6. **Rejected placebos** (documented in FAQ, never applied): pagefile disable, timer-res gimmicks below 0.5ms, "disable services that Windows re-enables", registry `RunOnce` sprays.
7. **Never-touch list** (T1-h2 §6.3): SecurityHealthService, MDCoreSvc, wuauserv/TrustedInstaller/UsoSvc full-disable, Spooler, AudioSrv/Audiosrv dep, Winmgmt, Schedule, profsvc, UserMgr, cdpsvc CDPUserSvc, StateRepository, InstallService, AppXSvc, ClipSVC, Xbox services when Game Pass used, EFS? — consult dossier; when in doubt leave default.
8. **Windows Update** default stays automatic (`wu-auto`); `wu-notify` = policy-based notify-only (never full disable).

## 8. Registry/state conventions
- Marker root: `HKLM\SOFTWARE\UltraOS\SetupOptions` (preset chosen, version, timestamp — written in start.yml, read by REPORT/UNDO/folder toggles)
- Backups: `%WinDir%\UltraOS\Backups\{services-before.reg, appx-before.txt, tasks-before.csv}` · Report: `%WinDir%\UltraOS\install-report.{html,txt}` · Folder: `%WinDir%\UltraOS\`
- All HKCU tweaks mirrored to default user via APPLYHIVE.ps1 (T3-i owns; pattern derived from Atlas APPLYDUHIVE.ps1 — GPL compatible)

## 9. Licensing & attribution (STRICT)
- UltraOS derives structure/mechanics from **Atlas-OS/Atlas (GPL-3.0)** → allowed, but MUST: keep GPL-3.0, credit in `NOTICE` + README section ("Derived from the Atlas playbook by AtlasOS contributors"), link upstream.
- **ReviOS playbook = CC BY-SA 4.0**: ideas/design patterns ONLY — zero code or YAML copying.
- **Chamber-Playbook = CC BY-NC-SA**: ideas only. **winutil = MIT**: small snippets allowed with NOTICE credit. **trusted-uninstaller-cli / ame-assassin = MIT**: engine, not copied; document how the engine executes our playbook.
- Every dossier-sourced tweak keeps a provenance comment (see style guide).
