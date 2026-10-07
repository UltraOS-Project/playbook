# UltraOS

**A transparent, reversible Windows 11 optimization playbook for [AME Wizard](https://ameliorated.io) — built Windows 11 26H2-first, licensed GPL-3.0.**

UltraOS makes Windows snappier, more private, and more yours. It removes background bloat, switches off most of Microsoft's tracking, and applies a curated set of performance and usability tweaks — all through the same AME Wizard that runs AtlasOS and ReviOS. Unlike most playbooks, UltraOS is built around three ideas we take seriously: **presets with honest trade-offs** (Safe / Balanced / Extreme), **full reversibility** (restore point, pre-change backups, one-click undo), and **transparency** (a post-install report of every change, at `C:\Windows\UltraOS\install-report.html`).

UltraOS targets **Windows 11 26H2 (build 26300, the "Windows 11 2026 Update", GA September 29, 2026)** as its primary platform, and also supports 25H2 (26200) and 24H2 (26100) — all three share the same servicing branch, so one playbook covers them all. It runs on **both Home and Pro** editions: every tweak is implemented via registry and policy keys that work identically on Home, with no reliance on Group Policy Editor-only mechanisms.

---

## Why UltraOS exists: the 26H2 gap

Windows 11 26H2 shipped on September 29, 2026, and the two best-known playbooks in the ecosystem were not ready for it in a way that matched what we wanted to run on our own machines. That gap is the reason this project exists, and it is also the reason for its license: we believe a community tweak collection that asks you to disable your antivirus for ten minutes should be fully open, freely forkable, and honestly attributed.

| Project | Windows 11 26H2 (26300) | License | Notes |
|---|---|---|---|
| **AtlasOS** | ❌ Not supported (24H2 / 25H2 only, as of Atlas v0.5.0) | GPL-3.0 | 26H2 support has been requested upstream (Atlas issue [#1739](https://github.com/Atlas-OS/Atlas/issues/1739)); Atlas also recommends Pro/Enterprise and excludes Windows Home |
| **ReviOS** | ✅ Supported | **CC BY-SA 4.0** (playbook) | Copyleft-attribution license; derivative playbooks must share alike under the same terms |
| **UltraOS** | ✅ **Supported day one — 26H2 is the primary target** | **GPL-3.0** | Free to fork, bundle, and redistribute under the GPL; see [NOTICE](NOTICE) for attribution |

If you want the maximum-performance, most aggressive approach and you are on 24H2/25H2, Atlas is a great project and we build on its work (see [Attribution](#attribution--license)). If you want a 26H2-first playbook with tiered presets, a full undo story, Home support, and a GPL license you can build on without license-lock-in — that is UltraOS.

## The three presets

Every install starts by choosing a preset. The presets are depth tiers, not different products: **Safe** actions run under every preset, **Balanced** adds the recommended daily-driver set, and **Extreme** adds the aggressive changes with real trade-offs. Anything risky (security-reducing, hardware-specific, or preference-dependent) is *never* silently included in a preset — it lives in the [opt-in extras](#opt-in-extras) instead.

| | **Safe** | **Balanced** (default) | **Extreme** |
|---|---|---|---|
| **Philosophy** | Disable-only; everything individually reversible | Recommended daily-driver; Atlas-grade rigor with Revi-grade usability | Maximum debloat and performance; removes more apps |
| **Apps removed** | Only dead/deprecated packages (e.g. Cortana) | Deprecated apps + the standard bloat catalog (Clips, Bing apps, Teams, Outlook dev-home installs, etc. — keeps Snipping Tool, Paint, Calculator, Xbox, Phone Link, Widgets) | Balanced set + Widgets stack, Phone Link, Solitaire, and the Xbox family (Game Pass users: leave Extreme alone or read [MODULES](docs/MODULES.md) first) |
| **Services** | None touched | Conservative Atlas-parity set (OneSyncSvc, TrkWks, MapsBroker, lfsvc, RemoteRegistry, RetailDemo, Fax, WMPNetworkSvc, diagnostics hubs…), each labelled against Microsoft's own IoT guidance | + WSearch disabled, SysMain offered as a toggle, NDU and telemetry drivers flagged |
| **Telemetry** | DiagTrack stopped; core consent denies; Recall off; Copilot button off | + DiagTrack disabled with autologger off, `AllowTelemetry=0`, WER/CEIP off, cloud-content and sponsored-app blockers, scheduled telemetry tasks disabled | + AI/Copilot app-level removal (Copilot app, CoreAI platform), presence sensing force-deny, MSA connection limits |
| **Network** | — (untouched) | LLMNR off, NIC power-saving tuning, SMB hardening (anonymous-access restrictions, throttling off) | + Experimental TCP stack flags (autotuning, ECN, Nagle) — clearly labelled as such |
| **Performance** | Mouse acceleration off, MMCSS responsiveness, Sticky Keys shortcut off (opt-in) | + GameDVR off, FTH off, service-host split (Xbox excluded), NTFS/battery counters, Win32 priority separation, instant menus (MenuShowDelay 0) | + Fullscreen optimizations off, MPO off (with caution notes), timer-resolution request pattern, MMCSS Games profile |
| **Visual / QoL** | UltraOS folder + report shortcuts, OEM info | Classic (Win10-style) context menu, taskbar cleanup (Chat/Widgets/Task View buttons), Explorer defaults (This PC view, file extensions, no recommendations) | + Transparency off, animations minimized, dynamic lighting off |

The full module-by-module matrix, including exact file names and trade-off notes, lives in [docs/MODULES.md](docs/MODULES.md).

## Quick start

1. **Download AME Wizard** from the official Ameliorated site: <https://ameliorated.io> (the same wizard AtlasOS and ReviOS use).
2. **Temporarily toggle off Microsoft Defender** — Windows Security → *Virus & threat protection* → *Manage settings* → turn the protection toggles off. This is a hard requirement of the wizard (see [Requirements](#requirements) for why, and for the exact steps).
3. **If Windows or your antivirus flags the download, that is a known false-positive pattern for the whole playbook ecosystem** — unsigned community tool + password-protected playbook container + system-modification heuristics. Do not guess: verify the SHA-256 against `SHA256SUMS.txt` from the release, then see [docs/ANTIVIRUS.md](docs/ANTIVIRUS.md) for the full explanation and the safe path.
4. **Open the UltraOS `.apbx` file with AME Wizard** (drag it in or use *Playbook* → *Select...*), pick your preset (Balanced is recommended), and press *Start*. Ten minutes later, read your install report at `C:\Windows\UltraOS\install-report.html`.

The full walkthrough — including the wizard's five pages, the Defender pre-step in detail, and what to do after install — is in [docs/INSTALL.md](docs/INSTALL.md).

## Opt-in extras

On top of your preset, the wizard offers twelve optional checkboxes across three screens. None of them are required, all of them are individually reversible afterwards, and the risky ones carry warnings directly in the wizard UI. They are deliberately **never** preset-gated: an explicit user choice overrides depth tiers.

| Option | What it does | Warning |
|---|---|---|
| `opt-uninstall-edge` | Removes Microsoft Edge (browser only — WebView2 runtime stays, since 15+ apps depend on it) | Windows Update and some Microsoft surfaces prefer Edge; see the [troubleshooting guide](docs/TROUBLESHOOTING.md) before choosing this |
| `opt-disable-defender` | Keeps Defender off after install instead of re-enabling it | **Not recommended.** UltraOS re-enables Defender automatically unless you check this |
| `opt-disable-mitigations` | Disables CPU exploit mitigations (Spectre/Meltdown family, CFG, SEHOP) | Older CPUs only; near-zero gain on modern CPUs; can trigger anti-cheat issues (see [FAQ](docs/FAQ.md)) |
| `opt-disable-vbs` | Disables Core Isolation / Virtualization-Based Security (HVCI) | **Not recommended.** Breaks Vanguard/FACEIT anti-cheat, WSL2, Docker Desktop, Hyper-V |
| `opt-max-performance` | Activates a Maximum Performance power scheme (no power saving, EPP set to performance) | Laptops: expect reduced battery life and more heat |
| `opt-disable-hibernation` | Disables Hibernation (and Fast Startup, which depends on it) | Frees disk space equal to a chunk of your RAM; sleep mode still works |
| `opt-strip-recall` | Strips Recall / AI snapshot features and blocks re-enablement | For privacy-focused users on Copilot+ hardware |
| `opt-disable-sticky-keys` | Disables the Shift×5 Sticky Keys pop-up trigger (the accessibility feature itself stays available in Settings) | None — safe QoL for gamers; does not apply to future user profiles |
| `opt-disable-sysmain` | Disables SysMain/Superfetch | Only for fast-NVMe machines with 16 GB+ RAM; on 8–16 GB systems it *increases* hard faults under memory pressure |
| `opt-disable-search-indexing` | Disables Windows Search indexing (same change Extreme makes) | Start-menu and Explorer file search fall back to slow non-indexed scanning |
| `opt-disable-memory-compression` | Stops Windows compressing standby memory (`Disable-MMAgent -mc`) | 16 GB+ RAM only; frees CPU cycles at the cost of more pagefile traffic under pressure |
| `opt-disable-hags` | Disables hardware-accelerated GPU scheduling | Situational troubleshooting switch — try it only if you see stutter; requires reboot |

Finally, the wizard's browser page lets you install **Brave** (default), **Firefox**, **LibreWolf**, or no browser at all. The browser is installed by the AME Wizard engine itself and set as your default — UltraOS never touches your browser's settings or profile.

## Rollback, report, and undo

Reversibility is a first-class feature, not an afterthought, and it works in layers:

- **System Restore point** — created *before any change* (on by default, skippable, strongly recommended). If anything goes badly wrong, roll back from Windows Recovery.
- **Pre-change backups** — UltraOS always exports your full services configuration (`services-before.reg`), installed-app list (`appx-before.txt`), and scheduled-task states (`tasks-before.csv`) to `C:\Windows\UltraOS\Backups\`, regardless of whether you take the restore point.
- **The install report** — after every run, `C:\Windows\UltraOS\install-report.html` (plus a plain-text `.txt`) lists every change, grouped per module, with a summary of what was skipped and why. There is also a shortcut to it in the UltraOS folder.
- **One-click undo** — `C:\Windows\UltraOS\Undo.cmd` (or "Uninstall UltraOS" in the UltraOS folder) restores services, scheduled tasks, and registry state from the built-in revert data. Removals of app packages are re-installable via pointers the report gives you; UltraOS is honest about which operations are not perfectly reversible.
- **Per-toggle reversal** — every toggle in the post-install `C:\Windows\UltraOS\` folder ships as an on/off *pair* of commands, so you can flip back Defender, updates mode, GameDVR, or Recall without re-running anything.

## What we don't do (no placebos)

The optimization scene is full of tweaks that *sound* good and do nothing — or actively hurt. UltraOS rejects them, documents them, and moves on. Concretely, we do **not**:

- **Disable the pagefile.** Windows' memory manager is good at its job; killing the pagefile causes commit-limit crashes in heavy games and applications while gaining nothing measurable. We leave it managed.
- **Ship "sub-0.5 ms timer resolution" hacks.** Since Windows 10 2004, timer resolution is per-window and background processes don't benefit; the "1 ms gaming timer" ritual is mostly folklore. Extreme does apply the documented `GlobalTimerResolutionRequests` pattern with honest limitations — and no bundled unsigned binaries to force it.
- **"Disable services Windows re-enables."** Disabling a service that servicing stacks restore on every update is a treadmill, not a tweak. Where a change won't stick, we don't pretend otherwise; where policy makes it stick, we use policy.
- **Fully disable Windows Update.** Ever. Security updates are non-negotiable; we offer automatic (default) or notify-only, and nothing else.
- **Spray `RunOnce` registry entries** or other persistence gimmicks that re-apply tweaks behind your back.
- **Ship executables, encoded commands or obfuscation of any kind.** The playbook is plain-text YAML and PowerShell you can read on GitHub; a one-command audit for dropper/downloader patterns is documented in [docs/ANTIVIRUS.md](docs/ANTIVIRUS.md).

Our research dossiers (in [`research/`](research/)) cite sources for every tweak we *do* apply, and the [FAQ](docs/FAQ.md) explains the placebo list in detail.

## Requirements

- **Windows 11 26300 (26H2), 26200 (25H2), or 26100 (24H2)** — Home or Pro. The wizard hard-checks the build number and refuses anything else.
- **AME Wizard** (free, from <https://ameliorated.io>).
- **Microsoft Defender toggled off during install** (`DefenderToggled`), **no third-party antivirus** (`NoAntivirus`), **an internet connection** (`Internet`), **no pending Windows Updates** (`NoPendingUpdates`), and **mains power** (`PluggedIn`). The wizard enforces all five before it starts.

The Defender requirement deserves an explanation, because "please turn off your antivirus" should always be questioned. The playbook needs to make a large number of registry and service writes in a short window; with real-time protection active, Defender can intercept, delay, or lock those writes (and Tamper Protection blocks the Defender-related policy writes outright), which makes installs unreliable and unpredictable. The wizard therefore requires you to toggle off the four primary protections yourself — Windows Security → *Virus & threat protection* → *Manage settings* — before it will proceed. **Defender is turned back on automatically at the end of the install** (it is the very last module that runs), unless you explicitly opt out with `opt-disable-defender`. We never disable Tamper Protection programmatically; that is what it is for.

## Documentation

| Doc | Contents |
|---|---|
| [docs/ANTIVIRUS.md](docs/ANTIVIRUS.md) | Why SmartScreen/antivirus may flag UltraOS or AME Wizard, what we ship (and never ship), SHA-256 verification, safe path through warnings, false-positive reporting |
| [docs/INSTALL.md](docs/INSTALL.md) | Step-by-step install: prerequisites, the Defender pre-step, the five wizard pages, post-install tour, reading the report, undo |
| [docs/MODULES.md](docs/MODULES.md) | Every module × every preset: what runs where, trade-offs, how to skip a module |
| [docs/FAQ.md](docs/FAQ.md) | Placebos we reject, Defender, Windows Updates survival, anti-cheat safety, Home vs Pro, 26H2 notes |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Unsupported builds, UCPD, Edge/update loops, Defender re-enable, restore points, missing reports |
| [docs/COMPARISON.md](docs/COMPARISON.md) | UltraOS vs AtlasOS vs ReviOS, feature by feature, with credits |

## Attribution & license

UltraOS is licensed under the **GNU GPL v3.0** — see [LICENSE](LICENSE). It is free software: you may study, modify, and redistribute it, and we hope you do.

UltraOS is **derived in part from the Atlas playbook by AtlasOS contributors** (GPL-3.0): the playbook structure, `playbook.conf` conventions, and selected tweak implementations come from Atlas, and UltraOS would not exist without it. Our design was additionally informed by **ReviOS** (ideas only, no code copied — their playbook is CC BY-SA 4.0), **Chamber-Playbook** (ideas only, CC BY-NC-SA), **ChrisTitusTech's winutil** (MIT), and the privacy-toggle UX of **O&O ShutUp10++**. Full attribution, including the MIT-licensed AME Wizard engine components we run under, is in the [NOTICE](NOTICE) file, and a feature-by-feature comparison with credits is in [docs/COMPARISON.md](docs/COMPARISON.md).

## Disclaimer

UltraOS is a community project. It is **not affiliated with, endorsed by, or sponsored by Microsoft** (Windows is a trademark of Microsoft Corporation), nor with Ameliorated LLC (AME Wizard), AtlasOS, or MeetRevision/ReviOS beyond the upstream relationships described above.

You are responsible for your own system. Modify your operating system **at your own risk**: UltraOS is provided "as is", without warranty of any kind, in the hope that it will be useful. Backups are taken and a restore point is offered, but no software can guarantee your data or uptime — take your own backups too. Test on non-critical hardware first if you are unsure, and read the [FAQ](docs/FAQ.md) before enabling any extra that mentions anti-cheat, Defender, or mitigations.
