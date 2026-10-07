# Contributing to UltraOS

UltraOS is built and packaged entirely on Linux — no Windows machine is required to hack on the playbook, only to test it. This document covers the development loop, the conventions every change must follow, and the rules for getting a change merged. The design rationale lives in [`research/01-architecture.md`](research/01-architecture.md) (the locked design), and the compatibility fact base lives in the other nine research dossiers — when in doubt about *why* something is the way it is, the answer is usually in one of those files.

## Development setup

You need `git`, `python3` (3.8+), `pyyaml`, and `zip`/`unzip`. Everything else is self-contained.

```bash
git clone https://github.com/UltraOS-Project/UltraOS.git
cd UltraOS
pip install --user pyyaml          # the only Python dependency

# validate the whole playbook tree (structure, YAML, gates, never-touch rules)
python3 scripts/validate-playbook.py --strict

# build the installable playbook + release artifacts into dist/
bash scripts/build-playbook.sh

# regenerate the icon artifacts (playbook.png, Images/*.png) deterministically
python3 scripts/make-artifacts.py
```

`scripts/build-playbook.sh` packages `src/playbook/` at the archive root into `dist/UltraOS-Playbook-v<version>.apbx` — a ZIP archive with the AME ecosystem's standard password, which the wizard extracts itself — verifies the archive round-trips, emits `SHA256SUMS.txt`, and assembles the release folder. The version is read from `src/playbook/playbook.conf`, so version bumps happen in exactly one place. Testing an install then means copying the `.apbx` to a Windows 11 24H2/25H2/26H2 machine (or VM) and opening it in AME Wizard — do test on a machine you can afford to restore.

## Repository layout

| Path | Contents |
|---|---|
| `src/playbook/playbook.conf` | Playbook metadata: builds, requirements, wizard pages, options — the single source of truth for option names |
| `src/playbook/Configuration/main.yml` | The pipeline: ordered `!task:` includes per module (comment out a line to skip a module) |
| `src/playbook/Configuration/ultraos/` | Core files: startup, services, revert data |
| `src/playbook/Configuration/tweaks/` | All module YAML (`debloat/`, `privacy/`, `services/`, `tasks/`, `network/`, `performance/`, `visual/`, `qol/`, `security/`, `ultraos/`) |
| `src/playbook/Executables/` | PowerShell/CMD tooling and the post-install `UltraOSFolder/` |
| `scripts/` | Build, validation, artifact generation (all Linux-native) |
| `docs/` | User documentation |
| `research/` | The ten research dossiers every tweak cites — they ship with the repo on purpose |

## YAML conventions

The authoritative conventions are in **[`research/02-style-guide.md`](research/02-style-guide.md)** — note that it is our *internal* style guide (written for the build fleet), so treat it as law for any YAML you touch. The essentials, so you cannot miss them:

- **Every file** starts with the standard header (`title:`, `description:`, optional file-level `option:`/`builds:`/`onUpgrade:` gates) followed by `actions:`. One topic per file, kebab-case filenames, `.yml` never `.yaml`.
- **Preset gating is mechanical** (see [`research/01-architecture.md` §4](research/01-architecture.md)): Safe actions carry no gate; Balanced actions use `option: '!preset-safe'`; Extreme actions use `option: 'preset-extreme'`; extras use their `opt-...` name and are never preset-gated. Option names must match `playbook.conf` exactly — the validator checks this.
- **Prefer native actions** (`!registryValue`, `!service`, `!scheduledTask`, `!appx`) over `!powerShell`/`!cmd` — every shell action spawns a process, and the <400-action speed budget depends on native actions. Never use `!cmd` wrappers for registry work, and never `wait: false` on `!cmd`/`!powerShell` (an engine quirk re-runs them up to ten times).
- **Every nontrivial action carries a provenance comment** — `# src: T1-f §2 · https://... · preset: balanced` — and anything you cannot source must be marked `# ⚠️ UNVERIFIED —` and left commented out. If a tweak is contested (e.g. the svchost split), add the one-line trade-off note.
- **Placebos are rejected on principle** (pagefile disabling, sub-0.5 ms timer claims, treadmill service disables — see the [FAQ](docs/FAQ.md)) and the **never-touch list** (update services, spooler, audio, Xbox-with-Game-Pass stack, etc.) is enforced by the validator, not by goodwill.
- Actions must be idempotent (safe on re-run) and honest — if a change only sticks until the next update, say so in a comment rather than pretending.

## Pull request rules

1. **The validator must pass.** `python3 scripts/validate-playbook.py --strict` exits 0 — no exceptions, no "I'll fix it later." CI runs it on every push and PR, and it checks far more than syntax: option-gate expressions against the `playbook.conf` registry, include-path existence, protected AppX families, never-touch services, duplicate registry writes, and service conflicts. A PR that fails validation is not reviewable.
2. **Small and sourced.** One module or one concern per PR, with the provenance comments described above. Tweaks without a traceable source (dossier section, Microsoft doc, or upstream reference) will be asked for one — that is the project's core quality bar.
3. **Document what users will see.** If a PR changes anything user-visible (a preset's behavior, an option, a folder toggle, a path), update the matching doc in `docs/` in the same PR. `docs/MODULES.md` and the wizard copy in `playbook.conf` must never disagree with the YAML.
4. **Security-reducing changes stay opt-in.** Nothing that disables Defender, VBS/HVCI, mitigations, or Windows Update may ever become a preset default; those live behind `opt-...` checkboxes with warnings. Similarly, no kernel-driver usage and no UserChoice/file-association writes (UCPD) — these are locked design decisions, and changing them requires a design discussion first.
5. **Test on real Windows before asking for merge** of anything that touches actions or scripts — the sandbox builds, but only a real 26100/26200/26300 install proves a tweak works. Note in the PR which build (and edition) you tested on.

Issues are welcome even without PRs — good bug reports include the `install-report.txt`, the Windows build (`winver`), and what you expected vs. what happened. For security-relevant reports, see [SECURITY.md](SECURITY.md) instead of a public issue.
