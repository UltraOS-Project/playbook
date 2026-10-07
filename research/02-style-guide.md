# UltraOS Style Guide — MANDATORY for all build agents (T3-*)

## 1. YAML file conventions
- File header (every file, exactly this shape):
```yaml
---
title: Disable Customer Experience Improvement Program     # human title
description: >-                                            # 1-2 sentences, what & why
  Disables CEIP as it is telemetry-related, for privacy.
# optional file-level gates (only when the WHOLE file is gated):
# option: 'opt-strip-recall'        # exact name from 01-architecture §3
# builds: [ '>=26100' ]             # version gate; recall/AI features = >=26100
# onUpgrade: false                  # when re-running on upgrade must skip
actions:
```
- Paths in `Configuration/tweaks/...` use **backslashes in `!task:` includes** (Atlas convention): `- !task: {path: 'tweaks\privacy\telemetry-policies.yml'}`
- One topic per file · kebab-case filenames · `.yml` (never `.yaml`)
- Registry hives: `HKLM\...` / `HKCU\...` exactly as Atlas writes them (engine maps these); paths single-quoted; data single-quoted strings (`data: '0'`); types: `REG_DWORD` / `REG_SZ` / `REG_QWORD` / `REG_BINARY` / `REG_EXPAND_SZ`
- Every nontrivial action gets a **provenance comment**: `# src: T1-f §2 · https://... · preset: balanced`

## 2. Action usage (speed-first; engine = strictly sequential, every shell action spawns a process)
| Need | Use | Cost |
|---|---|---|
| Registry value | `!registryValue` | ~0 (native) |
| Registry key add/delete | `!registryKey` | ~0 |
| Service config | `!service: {name, operation: change, startup: 4}` (4=disabled, 3=manual, 2=auto, 0=boot) | ~0 |
| Scheduled task | `!scheduledTask: {path, operation: disable}` (+ `ignoreErrors: true` when task may not exist) | ~0 |
| Appx removal | `!appx: {name: 'Microsoft.549981C3F8F10*', type: family}` (each spawns ame-assassin — keep list curated) | 1-3s |
| Kill process | `!taskKill: {name, ignoreErrors: true}` | fast |
| Status text | `!writeStatus: {status: '...'}` — ONE per module file set | ~0 |
| Shell ONLY when no native action exists | `!powerShell` (inline `command: |` block preferred over script file) | 1-3s + |
| File copy | `!file` or one batched PS block | batch! |
- FORBIDDEN: `!cmd` wrappers for registry work · one-PS-per-tweak · `wait: false` on `!cmd`/`!powerShell` (engine respawn bug — T1-j §"engine trap") · reboots · `!download` for anything already in Executables.
- `handleExitCodes: { "!0": halt }` only for critical scripts; `ignoreErrors: true` for may-not-exist targets.
- `runas: currentUserElevated` where a script touches HKCU/user scope; TrustedInstaller is default context.

## 3. Preset gating (recap — see 01-architecture §4)
- safe: no gate · balanced: `option: '!preset-safe'` · extreme: `option: 'preset-extreme'` · extras: `option: 'opt-...'`
- AND-combine when needed: `option: 'opt-uninstall-edge & !preset-safe'` (only if semantically required)

## 4. Honesty & content standards
- Every action must be traceable to a dossier section or URL. If you cannot source it, mark `# ⚠️ UNVERIFIED —` and put it last in the file, commented out.
- No placebo tweaks (01-architecture §7.6). When a tweak is contested (e.g. svchost split), add a one-line trade-off comment.
- Never disable anything on the never-touch list (01-architecture §7.7).
- English only in v1 files · no emojis in code/comments except marker conventions already used by Atlas (⚠️ ok).
- Idempotency: every action must be safe on re-run (engine re-runs on upgrade paths).

## 5. Local validation (run before you finish — must pass)
```bash
python3 /home/z/my-project/ultraos/scripts/validate-playbook.py --files <your files...>
```
(parses with a custom loader that accepts `!tag` action keys; checks header shape, option names against the registry, quoting, duplicate registry paths across the whole tweaks tree, never-touch service names.)

## 6. Worklog + reporting
- Append to `/home/z/my-project/worklog.md` (Task ID: T3-x) — files written, key decisions, anything flagged UNVERIFIED.
- Final reply ≤15 lines.
- Do NOT touch: files owned by other agents (map in 01-architecture §5), main.yml, playbook.conf (main agent owns those; request changes via worklog).
