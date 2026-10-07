# UltraOS FAQ

The questions we expect most often, answered honestly — including the ones where the honest answer is "no, that tweak is a placebo" or "Microsoft doesn't allow that." If your question isn't here, try [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) or the [module reference](MODULES.md).

## Is UltraOS a virus? My antivirus flags it (or AME Wizard)

No — and the flag has a boring, well-understood explanation. Antivirus engines score *behavior patterns*, not intent, and system-tuning playbooks look statistically like malware to a heuristic: an unsigned community tool running with admin/TrustedInstaller rights, a password-protected playbook container (the AME Wizard `.apbx` format, which scanners cannot look inside), and a burst of registry/service/policy writes. Every playbook in the ecosystem — AtlasOS, ReviOS, us — trips the same heuristics.

What the heuristics cannot see is the content, and the content is fully public: UltraOS ships **zero executables** — it is plain-text YAML and PowerShell on GitHub — with no encoded commands, no downloaders, no network calls, and no obfuscation, and Defender is re-enabled at the end of every default install. The strongest answer to any flag is cryptographic, not rhetorical: **verify the SHA-256 of your download against the `SHA256SUMS.txt` in the release** — if it matches, you have the exact bytes the maintainers published. The full story, the safe path through a warning, and how to file a false-positive report with Microsoft (or your AV vendor) so the flag dies for everyone: [ANTIVIRUS.md](ANTIVIRUS.md).

## Placebos and harmful tweaks we reject

The Windows-optimization scene recycles a set of tweaks that either do nothing on modern Windows or actively harm stability. UltraOS was built by reading the research and the upstream issue trackers first, and several popular rituals failed that review. We do not apply them, and we think you should not either.

**"Disable the pagefile for more RAM."** No. Windows' memory manager uses the pagefile as a safety valve for committed memory, not as a slow RAM substitute — with it gone, heavy games and applications hit commit limits and crash outright (`Out of memory`), while the performance gain is indistinguishable from noise. The pagefile also receives crash dumps; without it, you lose diagnosability. UltraOS leaves pagefile management to Windows at every preset, and the reasoning is recorded in a source comment in `tweaks/performance/system.yml`.

**"Set a 0.5 ms (or lower) system timer resolution for lower latency."** Mostly folklore since Windows 10 2004. Timer resolution is now per-window rather than global: background processes no longer inherit a raised resolution, so the classic "1 ms timer" trick mostly *burns idle power for nothing*, and the exotic sub-0.5 ms claims require injecting tools that hold the resolution globally via an undocumented hook. UltraOS's Extreme preset applies the one legitimate, documented piece of this (the `GlobalTimerResolutionRequests` pattern) with an honest limitations comment — and ships **no bundled binaries** to force resolutions. The service-host-split, MMCSS, and Win32-priority tweaks we *do* apply have measurable mechanisms and documented trade-offs.

**"Disable services that Windows re-enables."** If a servicing stack restores a service on every update, then disabling it is a treadmill: the tweak decays within weeks and the user never knows. UltraOS's policy is to either make the change stick via the correct policy mechanism (which survives servicing) or to not make it at all — and our docs never claim permanence we do not have. The same skepticism applies to registry `RunOnce` sprays and similar persistence gimmicks that re-apply tweaks behind your back: we never install anything that quietly rewrites your system after the install completes.

**What we did instead:** every applied tweak carries a provenance comment citing its source (research dossier section and/or Microsoft documentation), and the never-touch list of services and components is enforced by the build validator. See [docs/MODULES.md](MODULES.md) for the full matrix.

## Why do I have to turn off Defender to install?

Because the install writes several hundred registry values, service configurations, and policy keys in a few minutes, and an active real-time scanner can intercept, delay, or lock those writes — making the install unreliable and the outcome unpredictable. Worse, Tamper Protection blocks writes to Defender's own policy keys *by design*, even for administrators, and the playbook needs those writes even to hand Defender back to you in a clean state at the end.

That is also why the requirement is a **manual toggle you perform in Windows Security** (Virus & threat protection → Manage settings), not something we do for you: Tamper Protection exists precisely so that no software — including ours — can silently disable your antivirus. The wizard verifies the toggles are off before it starts (`DefenderToggled` in the playbook metadata). **Defender is switched back on automatically at the very end of the install** unless you explicitly check *Keep Defender disabled*; and a permanent on/off toggle pair lives in `C:\Windows\UltraOS\1. Security\` afterwards. We never attempt to defeat Tamper Protection programmatically.

## Do the tweaks survive Windows Updates?

**Monthly security updates: yes.** They are fully supported and UltraOS never interferes with them (see below for update modes). This is the normal case and needs no action from you.

**Feature updates (e.g. 25H2 → 26H2): partially, and this is not unique to UltraOS.** In-place feature upgrades re-provision the component store and some app packages, and Microsoft's own documentation confirms that deprovisioning keys do not cover package versions introduced by the new image — so removed bloat can reappear, some scheduled tasks and service states can be reset by servicing, and a handful of Settings values revert to defaults. Registry policy values mostly survive in place. Our research dossier on known issues documents each of these classes with the upstream evidence.

**The guidance is simple: re-run UltraOS after a feature update.** Re-running is safe by design — every action is idempotent, the engine only applies what is missing, and your backups are refreshed. The install report tells you exactly what the new run found and re-applied. UltraOS records its version and the build it ran against in `HKLM\SOFTWARE\UltraOS\SetupOptions`, so a future re-run can tell you whether your machine has taken a feature update since.

## Is UltraOS safe with anti-cheat games?

**By default, yes — because we do not disable the things anti-cheats check for.** The risky options are exclusively opt-in checkboxes with warnings in the wizard, never preset defaults. Specifically, under every preset:

- **CPU mitigations stay ON.** The "playbook broke my game" reports in the ecosystem's issue trackers trace overwhelmingly to mitigations being off — the Atlas project's standing guidance explicitly links mitigations-off to Easy Anti-Cheat crash errors. Mitigations only go off if *you* check `opt-disable-mitigations` (aimed at old CPUs).
- **Core Isolation / VBS / HVCI stays ON.** Valorant's Vanguard *officially requires* TPM, Secure Boot, and Memory Integrity (HVCI); so does FACEIT. Disabling VBS also breaks WSL2, Docker Desktop, and Hyper-V. VBS only goes off if you check `opt-disable-vbs`.
- **TPM/Secure Boot are never touched.** We also do not bypass Windows 11 hardware requirements — that path is a known anti-cheat and update-stability landmine.

**The Valorant CFG note:** if you do enable `opt-disable-mitigations`, Control Flow Guard goes off system-wide — and Valorant (and some EAC titles) refuse to start without CFG for their processes. That is why our mitigations module ships with the exception pattern that re-enables CFG *specifically* for `valorant.exe`, `valorant-win64-shipping.exe`, `vgtray.exe`, and `vgc.exe` while keeping the rest of the mitigations disabled. If you play other anti-cheat titles with mitigations off and hit a crash, the universal fix is to re-enable mitigations from `C:\Windows\UltraOS\1. Security\`.

## Windows 11 Home vs Pro — any differences?

**Functionally, no: every UltraOS tweak is edition-agnostic.** We deliberately use only registry and policy mechanisms (no GPO-only tools), and Windows honors `HKLM\SOFTWARE\Policies\...` keys on Home exactly as on Pro. AtlasOS, by contrast, recommends Pro/Enterprise and excludes Home; UltraOS supports both equally. A few honest footnotes:

- **The telemetry floor is higher on Home/Pro, and we will not pretend otherwise.** Microsoft's policy documentation is explicit: `AllowTelemetry = 0` ("Diagnostic data off") is only honored on Enterprise, Education, and Server editions; on Home and Pro it behaves as level 1 (Required diagnostic data). UltraOS writes the zero anyway (harmless, and future-proof if you upgrade editions) — and then *additionally* stops the DiagTrack service and its autologger at Balanced and above, which is what actually prevents the upload of diagnostic data. Some traffic (Windows Update, licensing, Defender security-intelligence queries) is mandatory plumbing on every edition and every machine, and no tweak collection can honestly claim to remove it.
- BitLocker and Hyper-V UI surfaces differ slightly between editions, but none of UltraOS's actions depend on them.
- If a tweak ever fails on one edition, the report says so — our action list uses tolerant removals (`ignoreErrors`) precisely because editions ship different app packages.

## Anything specific to Windows 11 26H2?

Yes — 26H2 (build 26300, GA September 29, 2026) is our primary target, and it changed several things playbook authors care about. Our research dossiers (`research/windows-26h2-analysis.md` in this repo) document all of it with sources; the user-relevant highlights:

- **Copilot was de-integrated by Microsoft itself.** Throughout 2026 Microsoft walked back Windows 11's built-in Copilot hooks (the Notepad Copilot button was removed, Snipping Tool's AI features dropped, and Settings/File-Explorer integration was abandoned). Net effect for you: fewer Copilot leftovers to remove than 25H2-era tweak lists assume — but new AI surfaces still ship (File Explorer AI actions, taskbar agent monitoring), so UltraOS's AI/privacy lists were re-audited for 26H2 rather than blindly reused, and app removals tolerate packages that no longer exist.
- **Memory Integrity (HVCI) auto-enable expanded.** In September 2026 reports, Microsoft began switching HVCI on by default for more devices, with measured gaming performance costs on some hardware (community measurements range roughly 2–25%). UltraOS's response: detect, document, and offer a clean opt-out (`opt-disable-vbs`, with the anti-cheat warning above) — never disable it silently, because Vanguard/FACEIT/WSL2 users would be broken by a "performance" default.
- **WMIC is fully gone** (not even a Feature on Demand), so any old tweak script calling `wmic` simply fails. All UltraOS tooling uses CIM cmdlets (`Get-CimInstance`) instead.
- **26H2 is an enablement package**, not a re-install: 24H2/25H2 machines flip to 26300 with a single restart and the same servicing branch. That is why one playbook covers all three builds, and why UltraOS runs on a just-flipped 26H2 machine immediately.

## Where is my install report?

At **`C:\Windows\UltraOS\install-report.html`** (with a `.txt` twin beside it), generated at the end of every run — look in the folder, or use the *View Install Report* shortcut in `4. Tools` inside the UltraOS folder. The wizard's progress screen also points there. It lists every change grouped by module, everything skipped and why, and per-module undo notes. If it is missing, see [Troubleshooting](TROUBLESHOOTING.md#the-install-report-is-missing).

## How does UltraOS handle Windows Update?

You choose one of two modes on the wizard's third page, and you can switch anytime from `C:\Windows\UltraOS\2. Updates\`:

- **Automatic (default, recommended):** Windows Update behaves exactly as Microsoft intends — downloads and installs security and feature updates on its normal schedule. UltraOS leaves the update services and components untouched at every preset.
- **Notify only (`wu-notify`):** a policy-based mode where Windows checks for updates and *notifies* you, but installs nothing until you approve. Useful for reviewing updates before they land; also the mode where you deliberately control update timing on a metered or gaming machine.

There is deliberately **no "disable updates" mode, and there never will be** — unpatched Windows is the one clearly worse Windows. Delivery Optimization is left enabled and the update services untouched; at the Balanced tier and above, the privacy module limits Delivery Optimization's peer-sharing behavior (no Internet-peer downloads of updates) rather than blocking updates themselves.
