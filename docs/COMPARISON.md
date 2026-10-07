# UltraOS compared: AtlasOS, ReviOS, and the projects we learned from

UltraOS did not appear in a vacuum — it exists because two excellent projects got most of the way there, and because neither combined 26H2-day-one support, tiered presets, Home + Pro, a full undo story, and a GPL-3.0 license in one package. This page compares the three honestly (including where the others win), and credits every project whose ideas informed UltraOS. If we have misrepresented anyone, that is a bug — please file it.

## The headline table

| | **UltraOS** | **AtlasOS** (Atlas playbook v0.5.0) | **ReviOS** (MeetRevision playbook) |
|---|---|---|---|
| **Windows 11 26H2 (26300)** | ✅ Supported — primary target, day one | ❌ Not supported (24H2/25H2 only; 26H2 requested upstream in [Atlas #1739](https://github.com/Atlas-OS/Atlas/issues/1739)) | ✅ Supported |
| **All builds supported** | 26100, 26200, 26300 (24H2/25H2/26H2) | 26100, 26200 (24H2/25H2) | 19044, 19045, 22631, 26100, 26200, 26300, 28000 (Win10 21H2/22H2 → 26H2) |
| **License** | **GPL-3.0** | GPL-3.0 | **CC BY-SA 4.0** (playbook; companion tool separate) |
| **Editions** | **Home + Pro** (registry/policy-only mechanisms) | Pro/Enterprise recommended; **Home excluded** | Home + Pro |
| **Presets** | **Safe / Balanced / Extreme** depth tiers + 7 opt-in extras | No tiers — per-option toggles in the wizard + AtlasDesktop/Toolbox | No tiers — per-option toggles; Defender-disable is the *default* radio |
| **Defender after install** | **On** (re-enabled automatically unless you opt out) | On by default (user picks at install); removal via DISM CAB when chosen | **Off by default** (disable is the default radio) |
| **Install report** | ✅ `C:\Windows\UltraOS\install-report.html` + `.txt`, every run | ❌ None | ❌ None |
| **Rollback** | ✅ Restore point (default on) + full pre-change backups + `Undo.cmd` + per-toggle on/off pairs | ❌ No undo story — actively deletes restore points and shadow copies; revert files exist only to clean up past-version mistakes | Partial — upgrade-time `revert.yml` + companion-tool uninstalls; full uninstall = repair-in-place via Windows Update |
| **Post-install toggles** | `C:\Windows\UltraOS\` folder (Security / Updates / Features / Tools / Software) | AtlasDesktop folder + separate Atlas Toolbox GUI app | Revi "Revision Tool" GUI/CLI companion app |
| **Speed approach** | ~**<400 actions** target (vs Atlas's 812), no `StartComponentCleanup` in the install path, batched registry, one status write per module; wizard ETA **8 min** | 812 actions across 196 YAML files; DISM component cleanup in the critical path; serial software downloads; wizard ETA **15 min** | Companion-binary driven (revitool); per-tweak CLI commands |
| **Browser install** | Wizard-engine `<Software>` packages — Brave / Firefox / LibreWolf / None, engine-set as default via the sanctioned prompt | Custom PowerShell script with direct downloads (Brave/Firefox/Chrome/LibreWolf) | `!download` per-arch from vendor GitHub + Chocolatey for Firefox; Brave pre-configured via preferences file |
| **Component removal (Defender/telemetry bits)** | No (v1 is service/registry/package level; CAB stripping is roadmap) | Yes — sxsc-built DISM CABs | Yes — WinSxS supersede packages via revitool |
| **Kernel driver** | No (`UseKernelDriver: false`) | No | No |
| **Windows Update** | Automatic (default) or notify-only; **never disabled** | Supported; notifications kept when opted out of auto | Supported, with pause/drivers toggles via revitool |

## How to read the differences

**Choose Atlas if** you are on 24H2/25H2, want the most aggressive component-level stripping (Defender and telemetry bits physically removed via DISM CABs), and are comfortable with no undo path beyond reinstalling. Atlas earned its reputation; UltraOS's services and debloat tiers deliberately track its conservative v0.5.0 sets, and our structure is derived from its playbook (see [NOTICE](../NOTICE)). What Atlas doesn't offer: 26H2, Home, presets, a report, or any rollback beyond its post-install toggle folder — and its cleanup actively deletes restore points, on the (defensible for them) theory that component removal can't be reverted anyway.

**Choose ReviOS if** you want Windows 10 support, like a full companion app managing tweaks, or want Defender off with the fewest prompts — their default is the opposite of ours, which is a legitimate philosophical difference we decline to copy. Their playbook is CC BY-SA 4.0, which matters if you plan to build on it: derivatives must carry the same license and attribution. We took ideas only (their browser flow via the engine's Software page, their honest warnings-in-UI style) and wrote all UltraOS code from scratch.

**Choose UltraOS if** you are on 26H2 (or want one playbook for 24H2/25H2/26H2), want tiered presets with honest labels, want Home supported, want to read a report of every change, and want a real undo story. The trade-offs vs the others: no component-level CAB stripping in v1 (Defender is *disabled by policy and toggled*, not deleted — deliberate, for reversibility), and a younger project with a smaller community.

## Why the license matters more than it looks

AtlasOS's GPL-3.0 let us derive from it legally and ethically, with attribution — that is the single biggest reason UltraOS could be built quickly and can be forked by you, today, without asking anyone. ReviOS's CC BY-SA 4.0 is also a fine license, but it is not a software license; mixing its YAML into a GPL codebase creates friction we chose to avoid entirely (hence: ideas only, no code). Chamber-Playbook's CC BY-NC-SA forbids commercial use outright, so nothing from it can be copied into any permissively-licensed downstream — we limited ourselves to UX inspiration (its verification manifest and companion-folder concepts). License hygiene is why the [NOTICE](../NOTICE) file exists and why every tweak in our YAML tree carries a provenance comment.

## Credits: the projects UltraOS learned from

- **[Atlas-OS/Atlas](https://github.com/Atlas-OS/Atlas)** (GPL-3.0) — structural parent: playbook layout, `playbook.conf` conventions, the conservative service sets, deprovisioning patterns, and the desktop-toggle-folder UX. UltraOS is derived from Atlas; see [NOTICE](../NOTICE).
- **[ReviOS / MeetRevision playbook](https://github.com/MeetRevision/playbook)** (CC BY-SA 4.0) — ideas only: the engine-native browser flow, preset-like option UX, and honest warning copy. No code copied.
- **[ChamberTechFPS/Chamber-Playbook](https://github.com/ChamberTechFPS/Chamber-Playbook)** (CC BY-NC-SA 4.0) — ideas only: verification manifest and post-run verification thinking, 26H2-first shipping, anti-cheat-safe positioning.
- **[ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil)** (MIT) — the best-engineered tweak-data model in the ecosystem (per-tweak original values for undo, per-tweak documentation links); our revert data and report design owe it a debt. Small snippets, where used, are credited in [NOTICE](../NOTICE).
- **[O&O ShutUp10++](https://www.oo-software.com/en/shutup10)** (proprietary, freeware) — the gold standard of privacy-toggle UX: per-setting recommendation levels and plain-language trade-offs. Inspiration for our module matrix presentation.
- **[Ameliorated](https://ameliorated.io)** — the AME Wizard and its MIT-licensed backend engine ([trusted-uninstaller-cli](https://github.com/Ameliorated-LLC/trusted-uninstaller-cli), plus ame-assassin), which executes every UltraOS action. Without this ecosystem none of these projects exist.
- **[ShadowWhisperer/Remove-MS-Edge](https://github.com/ShadowWhisperer/Remove-MS-Edge)** (CC0-1.0) — the ecosystem's reference Edge-removal mechanism, studied (not vendored) when designing our opt-in Edge removal.
- **Microsoft's own documentation** — service-disable guidance (Windows IoT/Server docs), the deprovisioning-during-update reference, Policy CSP pages, and the 26H2 "What's new" documentation that our 26H2 fact base is built on.

The full research trail — ten dossiers with sources for every claim in this repository — ships in [`research/`](../research/), because a playbook that asks for trust should show its work.
