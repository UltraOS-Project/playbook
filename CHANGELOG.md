# Changelog

All notable changes to UltraOS are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [semantic versioning](https://semver.org/) with the caveat that "breaking" for a playbook means "an install made by an older version may need attention before upgrading" — the wizard's own upgrade flow (`Upgrade`, not *Run again*) handles version-to-version migration.

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
