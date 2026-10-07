# UltraOS Fleet Briefing — Environment & Verified Facts (Main Agent Recon, 2026-10-07)

## Project decisions (locked by user)
- Name: **UltraOS**. License: GPL-3.0. Target: Windows 11 **26H2**, editions **Home + Pro**.
- Runs on **AME Wizard** (the same wizard app AtlasOS/ReviOS playbooks use). Distribution: **.apbx** playbook.
- Hybrid design: Atlas-style performance + Revi-style usability; wizard presets **Safe / Balanced / Extreme**; per-module toggles.
- Priorities: fast execution (batching/parallelism where possible), rollback support, post-run report.

## Environment facts (verified by main agent)
- Working tree: `/home/z/my-project/ultraos/` (repo), `/home/z/my-project/ultraos/research/` (dossiers), `/home/z/my-project/repos/` (cloned upstream repos), `/home/z/my-project/worklog.md` (shared log).
- Network: `github.com` OK (git clone + curl), `raw.githubusercontent.com` OK, **`api.github.com` BLOCKED (403) — do not use**, `ameliorated.io` 301 → amelabs.net.
- Web search CLI: `z-ai function -n web_search -a '{"query":"...","num":10}' -o out.json` — occasional 429 rate limits; wait ~10s and retry. Result JSON: array of {url, name, snippet, date}.
- Page reader CLI: `z-ai function -n page_reader -a '{"url":"https://..."}' -o out.json` — returns {title, html, text}.
- `curl -s -L` works for most sites. GitHub HTML pages are server-rendered and curl-able (e.g. issue lists, repo pages).
- **No Deno runtime on this box — never try to RUN playbook code; static analysis only.** Node v24 / git 2.47 / python3 available.

## Verified upstream facts (main agent, 2026-10-07)
- DEAD repos (404, do not retry blindly): Atlas-OS/atlas-playbook, MeetRevision/Revi-Playbook, Ameliorated-OSS/*
- LIVE + already cloned: **Atlas-OS/Atlas** → `/home/z/my-project/repos/atlas` (571 files). Playbook source in `src/playbook/`.
- Atlas playbook anatomy (confirmed by direct reading):
  - `src/playbook/playbook.conf` — XML metadata: Name, Username, Title, Version, ShortDescription, Description (CDATA), Details, ProgressText, **SupportedBuilds** (currently `26100` = 24H2, `26200` = 25H2 — **no 26H2 support yet**), UpgradableFrom, Requirements (DefenderToggled, NoAntivirus, Internet, NoPendingUpdates, UCPDDisabled, PluggedIn), UniqueId, InstallGuide, Overhaul, UseKernelDriver, AllowUnsupportedUpgrades, ProductCode, EstimatedMinutes, Git/Website/DonateLink, SupportsISO, OOBE (BulletPoints, Internet), ISO (DisableBitLocker, DisableHardwareRequirements), **FeaturePages** (RadioPage / CheckboxPage / RadioImagePage; option names like `defender-enable`, `uninstall-edge`, `browser-brave`, `disable-power-saving`, `install-toolbox`)
  - `src/playbook/Configuration/` — YAML tweak tree: `atlas/` (appx.yml, components.yml, default.yml, revert.yml, services.yml, start.yml), `tweaks.yml`, `custom.yml`, `tweaks/{debloat,misc,networking,performance,privacy,qol}/...` (dozens of per-topic yml files)
  - `src/playbook/Executables/` — PowerShell scripts + `AtlasDesktop/` shortcuts folder + `AtlasModules/` (with `Packages/*.cab` built by sxsc)
  - Build: `src/dependencies/local-build.ps1` → zips playbook into `.apbx` (renamed ZIP, password `malte`), flags: `-ReplaceOldPlaybook -AddLiveLog -Removals Verification,WinverRequirement -FileName <name>`
  - CI: `.github/workflows/apbx.yaml` — yamllint validation + sxsc CAB package rebuilds + playbook artifact
- AME Wizard developer docs: **https://docs.amelabs.net** (entry point: /developers/getting-started/creation.html)
- AME Wizard backend engine (open source, MIT): **github.com/Ameliorated-LLC/trusted-uninstaller-cli**
- Playbooks are renamed ZIP archives (`.apbx`), password `malte` (per Atlas README + amelabs docs)

## Fleet protocol (ALL agents must follow)
1. Read `/home/z/my-project/worklog.md` + this file BEFORE starting.
2. Work ONLY within `/home/z/my-project/` (throwaway JSON may go to /tmp).
3. Write your complete dossier to your assigned path in `/home/z/my-project/ultraos/research/`.
4. Append your record to worklog.md (append-only, NEVER overwrite) via:
   `cat >> /home/z/my-project/worklog.md << 'EOF'` ... `EOF`
5. Never fabricate. Quote real files/URLs. Mark uncertainty explicitly with `⚠️ UNVERIFIED`.
6. Final reply: ≤15 lines — key findings + your dossier path.
