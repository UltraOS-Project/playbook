# Security Policy

UltraOS modifies core Windows state, so security is a design constraint, not an afterthought. This page documents what UltraOS deliberately never touches, how the playbook is built to stay trustworthy, and how to report problems. It complements [docs/FAQ.md](docs/FAQ.md) (the reasoning) and [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) (the failure modes).

## What UltraOS never disables by default

Every install runs with these **on**, under every preset, unless you personally opt out via an explicitly warned checkbox:

- **Microsoft Defender / real-time protection.** The install requires Defender to be toggled off by hand (the wizard's `DefenderToggled` check — the one step Tamper Protection guarantees only a human can do), and **re-enables it automatically at the end of the install**. Keeping it off requires the clearly-marked `opt-disable-defender` opt-in, and a permanent on/off toggle ships in the post-install folder either way.
- **Core Isolation / VBS / HVCI (Memory Integrity).** On by default from Windows, left on by UltraOS. Disabling it (which breaks Vanguard/FACEIT anti-cheat, WSL2, Docker Desktop, and Hyper-V) is only possible via the warned `opt-disable-vbs` checkbox.
- **CPU exploit mitigations** (Spectre/Meltdown family, CFG, SEHOP). Left at Windows defaults; the `opt-disable-mitigations` extra is aimed at older CPUs, carries a wizard warning, and includes the Valorant CFG exception pattern for anti-cheat compatibility.
- **Windows Update.** Automatic (default) or notify-only — there is no "off", by design and forever. The update services themselves (`wuauserv`, `UsoSvc`, `TrustedInstaller`, `DoSvc`, BITS) sit on the never-touch list enforced by our validator.
- **TPM / Secure Boot / Windows 11 requirement checks.** Never bypassed or weakened. Bypasses are a known anti-cheat and update-stability hazard.
- **UAC, SmartScreen behavior, and the never-touch service set** — the update/servicing services, print spooler, audio, WMI, Task Scheduler, user-profile and app-state services, SecurityHealthService/MDCoreSvc, and the core networking services (the current list is embedded in `scripts/validate-playbook.py`). By design, the Xbox/Game Pass service stack is never touched either — Extreme removes the Xbox *apps*, not the services Game Pass needs.
- **UserChoice / file-association keys (UCPD territory).** UltraOS never writes them, never disables the UCPD driver, and never hijacks your default browser — the wizard's browser flow uses the sanctioned Windows confirmation prompt instead.

We also never: bundle or auto-run unsigned binaries, spray `RunOnce` persistence, block Windows Update endpoints, or modify anything behind your back after the install completes.

## Supply-chain and build integrity

- The playbook ships as an `.apbx` (a password-protected ZIP — the AME ecosystem's standard container, so scanners can flag it; verify against the published **`SHA256SUMS.txt`** before running, as described in the release's README-FIRST.txt).
- The whole build is deterministic and script-driven on Linux from this public repository: `scripts/validate-playbook.py --strict` (structure, gates, never-touch enforcement), then `scripts/build-playbook.sh` (packaging + hash manifest). CI runs the same steps on every push and PR, so the `.apbx` you download is reproducible from the commit you can read.
- UltraOS uses no kernel driver (`UseKernelDriver: false`), no third-party binaries in the install path, and no run-time downloads of executable code except the browser you explicitly select on the wizard's browser page (installed by the AME Wizard engine itself from the vendor's channels).

## Reporting a vulnerability or a safety bug

Please report security-relevant issues — anything about UltraOS weakening a security control beyond what is documented, an unsafe default, a supply-chain concern, or a way the wizard/Defender flow could be abused — **privately and early**, rather than in a public issue:

1. Use GitHub's **"Report a vulnerability"** (private vulnerability reporting) on the UltraOS repository, or
2. Open a regular issue with **no exploit details** and ask for a private channel, or
3. Contact the maintainers via the repository's listed contact points.

Include what you found, how you found it, the affected version (from `playbook.conf` or your install report), and the Windows build you tested on. We aim to acknowledge within a few days, and we will credit reporters unless you prefer otherwise. Non-security bugs and tweak suggestions belong in normal issues — those get faster traction with an `install-report.txt` attached.

## Responsible-use expectations

UltraOS is for machines you own or administer. It requires elevation, modifies system-wide state, and expects an informed operator — the wizard's warnings, the [FAQ](docs/FAQ.md), and the module matrix in [docs/MODULES.md](docs/MODULES.md) exist so that every choice you make is an informed one. If you administer machines for others, do not enable the security-reducing extras on their behalf without their understanding; the defaults are safe precisely so that the dangerous things are always a personal, deliberate decision.
