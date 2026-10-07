# Changelog

All notable changes to UltraOS are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [semantic versioning](https://semver.org/) with the caveat that "breaking" for a playbook means "an install made by an older version may need attention before upgrading" — the wizard's own upgrade flow (`Upgrade`, not *Run again*) handles version-to-version migration.

## [1.1.0] — 2026-10-07

Feature release: a new **Tuning extras** wizard page, five new opt-in switches, the input/mouse module the docs always promised, and a full "antivirus flags this?" transparency package (new doc, honest answers, verification-first flow).

### Added — more tuning

- **Tuning extras wizard page** (fourth checkbox screen): SysMain off, Windows Search indexing off, memory compression off, and hardware-accelerated GPU scheduling off — each an any-preset opt-in with its real trade-off documented in the YAML and in the install report. Extreme-preset users get SysMain/WSearch from their tier regardless; the checkboxes make the same changes available at Safe/Balanced for machines that only want those two.
- **`opt-disable-sticky-keys`** on the "Additional options" page — kills the Shift×5 pop-up trigger only (the accessibility feature itself stays available in Settings). Written through PowerShell on purpose so the preference does **not** leak into future user profiles via `default-user.reg`.
- **Input & MMCSS module** (`tweaks/performance/input.yml`): mouse acceleration off (Atlas-verbatim trio, Safe tier) — this *implements* what README/MODULES already documented — plus `MenuShowDelay 400 → 0` at Balanced for instant menus (ReviOS parity).
- **MMCSS "Games" task profile** at Extreme (`Priority 6`, `Scheduling Category Games`, `SFIO High`) — the classic community profile, honestly labeled as anecdotal-but-harmless; stock values recorded in the revert inventory.
- **EPP = 0 (AC)** folded into the Maximum Performance power scheme — the CPU now prefers performance states in the opt-in scheme instead of stopping at clock-ramp tweaks.

### Fixed — docs/implementation mismatches (found while auditing every module)

- **Mouse acceleration off** was documented as a Safe-tier action since 1.0.0 but never actually shipped. It now runs under every preset, exactly as README and MODULES.md promise.
- **MMCSS `SystemResponsiveness=10`** was documented as Safe-tier but sat behind gaming.yml's file-level `!preset-safe` gate, so it only ran at Balanced+. Moved to `input.yml` ungated (matches the research verdict "Safe in all presets").
- The v1.0.x revert inventory had **no stock entry for `SystemResponsiveness`**, so one-click undo could not restore it. Fixed, along with stock entries for everything new in this release (mouse trio, `MenuShowDelay`, Sticky Keys `Flags=510`, `HwSchMode=2`, MMCSS Games profile).

### Added — "antivirus considers it malicious" transparency package

- **New doc: [docs/ANTIVIRUS.md](docs/ANTIVIRUS.md)** — why Windows SmartScreen or an antivirus may flag AME Wizard or the `.apbx` container, what UltraOS actually ships (zero executables, readable scripts, GPL-3.0 source), how to verify the download against `SHA256SUMS.txt` before doing anything, how to proceed safely when a warning appears, and how to file a false-positive report with Microsoft or your AV vendor.
- README "Quick start" and FAQ now answer the flag question up front and link the doc; INSTALL.md gains an "expect a warning, verify the hash" step; the release README-FIRST.txt carries the same note so the answer ships *with the download*.
- Script-level audit (documented in the doc): the playbook contains no encoded commands, no downloaders, no obfuscation, no binaries, and no non-official URLs — everything an AV sees is plain-text registry/service commands you can read on GitHub.

### Upgrade notes

- Re-running v1.1.0 over a v1.0.x install is supported (`UpgradableFrom=any`). New Safe-tier actions (mouse accel, MMCSS) apply on the next run; all new extras are opt-in checkboxes that default to off, so an upgrade run changes nothing you did not pick.


## [1.0.1] — 2026-10-08

Hotfix release. v1.0.0 failed to load in AME Wizard with
`RadioPage with a TopLine and BottomLine must not have more than 2 options.`
(found by a user at runtime — a class of bug our build pipeline could not see,
because the page-layout rules live in the wizard engine, not in any public spec).

### Fixed — playbook load failures (engine rule violations)

- **Preset `RadioPage`** had 3 options *and* both a `TopLine` and `BottomLine`.
  The engine caps such pages at 2 options (3 are allowed with at most one line).
  The preset guidance text moved into the page `Description`; the "What does
  each preset change?" link stays as the single `BottomLine`.
- **Browser `RadioImagePage` was self-closing** — no `<Options>` at all, which
  would have crashed the engine with a `NullReferenceException` in
  `RadioImagePage.Validate()` right after the first fix. It now defines the
  `None` choice plus Brave / Firefox / LibreWolf with engine-legal gradient
  colors (mirrors the ReviOS/Atlas page grammar).
- **`<UpgradableFrom>none</UpgradableFrom>`** is not a legal value (only
  `any`, a version like `1.0.0`, or a range like `1.0.0-2.0.0`) — it is now
  `any`, matching ReviOS and allowing re-runs over an existing install.
- **Advanced-options `CheckboxPage`** had 4 options with both lines (engine
  cap: 4 options only with no lines). The trade-off warning moved into the
  page `Description`, matching the ReviOS-style no-line checkbox pages.

### Added — runtime testing against the real engine rules

- **`scripts/ame-dryrun.py`** — a runtime dry-run harness that ports the AME
  Wizard's *actual* load pipeline rule-for-rule (sources:
  `AmeliorationUtil.DeserializePlaybook`, `XmlDeserializer.ReadXml` strictness,
  `Playbook.cs` page/playbook validation, `PlaybookParser` tag map, action
  field schemas, `ParseActions` option/build/oobe/iso gating). Stages:
  container (ZipCrypto "malte" + CRC + root layout) → strict `playbook.conf`
  load → page/playbook validation → YAML pipeline (tags, fields, enums,
  `!task` graph, option refs) → file references → execution simulation for
  Safe/Balanced/Extreme/browser/advanced scenarios. `--selftest` proves the
  harness reproduces the v1.0.0 load failure verbatim. CI and the local build
  both run it against the packaged `.apbx`.
- All five simulated fresh-install plans now resolve end-to-end (Safe 150,
  Balanced 333, Extreme 403 actions on build 26300).

## [1.0.0] — 2026-10-08

Initial public release — a GPL-3.0 playbook targeting Windows 11 26H2 (build 26300, the Windows 11 2026 Update) as its primary platform, alongside 25H2 (26200) and 24H2 (26100), on both Home and Pro. It fills the gap left by Atlas (24H2/25H2 only) and ReviOS (26H2 supported, but under a CC BY-SA playbook license).

### Added

- **Three-preset architecture** — *Safe* (disable-only, everything individually reversible), *Balanced* (recommended daily-driver; default), and *Extreme* (maximum debloat and performance with honest trade-off labels). Preset gating is mechanical and auditable in the YAML: Safe actions are ungated, Balanced actions run on `!preset-safe`, Extreme actions run on `preset-extreme`.
- **Seven opt-in extras** with wizard-level warnings, never preset-gated: Remove Microsoft Edge (`opt-uninstall-edge`, WebView2 runtime preserved), Keep Defender disabled (`opt-disable-defender`), Disable CPU mitigations (`opt-disable-mitigations`, with the Valorant CFG exception), Disable Core Isolation/VBS (`opt-disable-vbs`), Maximum Performance power scheme (`opt-max-performance`), Disable Hibernation (`opt-disable-hibernation`), Strip Recall/AI features (`opt-strip-recall`).
- **Engine-native browser selection** — Brave (default), Firefox, or LibreWolf installed by the AME Wizard engine and offered as default browser through the sanctioned Windows prompt; `None` keeps current browsers. No browser settings are modified.
- **Ten tweak modules** with per-module preset matrices: services, scheduled tasks, debloat, privacy (7 files, incl. 26H2-relevant AI/Copilot/Recall handling), network, performance, visual, quality-of-life, security, and the UltraOS core pipeline. Every nontrivial action carries a provenance comment citing its research source.
- **Post-install report** — every run generates `C:\Windows\UltraOS\install-report.html` (plus `.txt`) from before/after backups: all changes grouped by module, everything skipped and why, and per-module undo notes.
- **Layered rollback** — optional System Restore point (on by default), unconditional pre-change backups (`services-before.reg`, `appx-before.txt`, `tasks-before.csv` in `C:\Windows\UltraOS\Backups\`), one-click `Undo.cmd`, and build-time revert data for registry/policy state.
- **Post-install folder** `C:\Windows\UltraOS\` with on/off toggle pairs: `1. Security` (Defender, mitigations, Core Isolation), `2. Updates` (automatic/notify-only), `3. Features` (GameDVR, Recall), `4. Tools` (report viewer, Uninstall UltraOS, backups), `5. Software` (Edge reinstall pointer, browser docs).
- **Honest update policy** — Windows Update stays automatic by default (`wu-auto`) or policy-based notify-only (`wu-notify`); it is never disabled, and the update services are on the validator-enforced never-touch list.
- **Windows 11 26H2 readiness** — build 26300 in `SupportedBuilds`; AI/Copilot lists re-audited for 26H2's Copilot de-integration; WMIC-free tooling (CIM cmdlets); HVCI default-expansion awareness with an opt-in, warned VBS toggle; no UCPD conflicts (no UserChoice writes, so no UCPDDisabled requirement).
- **Linux-native, reproducible build** — `scripts/build-playbook.sh` packages the `.apbx` with `SHA256SUMS.txt`, `scripts/validate-playbook.py --strict` enforces structure, option gates, protected app families, never-touch services and duplicate writes in CI, and `scripts/make-artifacts.py` deterministically generates the playbook and browser icons.
- **Full documentation suite** — this README, INSTALL / MODULES / FAQ / TROUBLESHOOTING / COMPARISON guides, SECURITY and CONTRIBUTING policies, the NOTICE attribution file, and the ten research dossiers that source every tweak — all shipped in-repo.

### Design decisions worth knowing

- **No component stripping in v1** — Defender and telemetry are disabled at service/policy/package level rather than removed via DISM CABs, keeping every change reversible; CAB-level stripping is on the roadmap with the same reversibility bar.
- **Placebos rejected** — no pagefile disabling, no sub-0.5 ms timer hacks or bundled timer binaries, no treadmill "disable services Windows re-enables", no RunOnce sprays.
- **No kernel driver, no UserChoice writes, no update blocking** — locked design constraints, enforced by review and validator.
- Derived from the Atlas playbook (GPL-3.0, credited in NOTICE); ideas-only from ReviOS (CC BY-SA 4.0), Chamber-Playbook (CC BY-NC-SA), winutil (MIT), and O&O ShutUp10++'s privacy-UX patterns. See [NOTICE](NOTICE) and [docs/COMPARISON.md](docs/COMPARISON.md).
