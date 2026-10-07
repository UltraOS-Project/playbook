# Antivirus flags UltraOS or AME Wizard — read this first

Windows SmartScreen, Microsoft Defender or a third-party antivirus may show a
warning when you download or run **AME Wizard** or open the UltraOS
`.apbx` playbook. This page explains exactly why that happens, what UltraOS
actually is (and is not), how to verify your download cryptographically before
you trust any of this, and how to file a false-positive report if you want to
help fix the flag for everyone else.

> Short version: **the warning is a heuristic, not a verdict.** UltraOS ships
> zero executables — it is a ZIP of readable text files (YAML + PowerShell +
> `.cmd`) that instructs AME Wizard to change settings you could change by
> hand in `regedit`, `services.msc` and Settings. Verify the SHA-256, then
> decide.

## Why the warning appears

Antivirus products do not flag UltraOS because they found malicious code in
it. They flag the *shape* of the activity, using heuristics built from what
actual malware does. Three of those heuristics fire here:

1. **A system-tuning tool that changes the registry, services and scheduled
   tasks.** Ransomware, miners and rogues also disable services and write
   `HKLM` policy keys, so scanners score "unsigned tool asks for admin and
   rewrites system settings" as suspicious even when every individual change
   is documented and reversible.
2. **The `.apbx` container is password-protected.** This is the AME Wizard
   playbook *format* (a ZIP the wizard opens with its own password). A
   password-protected archive cannot be scanned inside by antivirus engines,
   and several AV products treat "encrypted archive + system modification" as
   a risk pattern on its own. Every AME Wizard playbook in existence —
   including AtlasOS and ReviOS — trips the same pattern.
3. **AME Wizard itself is an unsigned community tool that runs with
   TrustedInstaller rights.** We do not publish AME Wizard; it is a
   third-party application by the [Ameliorated](https://ameliorated.io) team.
   Its power (and the Defender pre-toggle the wizard asks for) is exactly the
   kind of capability heuristics are designed to catch. This is a known,
   long-standing false-positive class for the whole playbook ecosystem, and
   the AME Wizard team documents it themselves.

SmartScreen adds a fourth, milder variant: "Windows protected your PC" on the
download, simply because the file is not signed and not yet reputation-known.

## What UltraOS actually is (and never is)

- **Zero executables shipped.** No `.exe`, `.dll`, `.sys` or scripts compiled
  to binaries. You can verify this yourself: the full playbook source is in
  [this repository](../src/playbook/) — every action, in plain YAML, with a
  provenance comment citing where the tweak came from.
- **No obfuscation, no encoded commands, no downloaders.** No base64 blobs, no
  `Invoke-Expression`/`IEX`, no `DownloadString`, no `certutil`/`bitsadmin`
  fetch tricks — the patterns real droppers use. The complete audit pattern
  list is at the bottom of this page and can be re-run against any release in
  one command.
- **No phone-home.** The playbook makes no network calls and collects
  nothing. The only URLs inside it are links to documentation (this GitHub
  repository and Microsoft's own sites) printed for you to read.
- **Defender stays ON.** The wizard requires you to toggle real-time
  protection off *before* the install (its `DefenderToggled` requirement —
  the engine's own actions would otherwise be blocked mid-run), but UltraOS
  **re-enables Defender at the end of every default install**. Keeping it off
  is an explicit, warned, opt-in checkbox (`opt-disable-defender`) that we
  recommend leaving unchecked — see the [FAQ](FAQ.md).
- **Everything is reversible.** Pre-change backups, a revert-value inventory,
  one-click `Undo.cmd`, and an install report of every change
  ([rollback documentation](../README.md#rollback-report-and-undo)).

## Verify before you trust (2 minutes, no AV needed)

The strongest answer to any "is this malicious?" question is cryptographic:
confirm you have the exact bytes the maintainers published.

1. Download the release ZIP or `.apbx` **only** from
   [github.com/UltraOS-Project/playbook/releases](https://github.com/UltraOS-Project/playbook/releases).
   Nothing on any mirror, file host or "disc upload" is ours.
2. Download `SHA256SUMS.txt` from the same release.
3. In PowerShell, in your Downloads folder:

   ```powershell
   Get-FileHash .\UltraOS-Playbook-v1.1.0.apbx -Algorithm SHA256
   ```

   (On Linux/macOS: `sha256sum` / `shasum -a 256`.)
4. Compare the hash, character by character, with the matching line in
   `SHA256SUMS.txt`. **Match → you have the authentic file, whatever the AV
   banner says. No match → delete it and re-download from the releases page.**

If the hash matches, any "Trojan:Win32/…" style detection on the file is, by
construction, a false positive about the *activity pattern* described above —
not a finding about anything in the file itself.

## Proceeding safely when a warning appears

You have verified the hash and want to continue:

- **SmartScreen ("Windows protected your PC"):** click *More info* →
  *Run anyway*. This is the standard flow for unsigned community tools.
- **Defender real-time protection:** the wizard's own pre-step (see
  [INSTALL.md](INSTALL.md) step 0) already has you toggle the four Windows
  Security switches off before starting; Defender comes back on by itself at
  the end of the run, and the report tells you to re-arm Tamper Protection by
  hand. If you want to be surgical instead, add a temporary exclusion for
  `AMEWizard.exe`/the `.apbx` in *Virus & threat protection → Manage settings
  → Exclusions*, and remove it after the install.
- **Third-party AV:** the cleanest path is to add a temporary exclusion for
  the wizard's folder, run the install, then remove the exclusion. Avoid the
  "AV quarantine dance" mid-run — letting an AV delete the playbook or block
  the wizard halfway through is how *broken states* happen, which is a far
  worse outcome than a warning.
- **Keep Defender's weekly scan or a second-opinion scanner** if you keep
  Defender disabled long-term via the opt-in toggle. An unprotected always-online
  machine is a real cost, not a badge.

## Help fix the flag for everyone (false-positive reports)

Vendors whitelist on user reports — a handful of clean reports per file is
usually enough to retire a heuristic hit:

- **Microsoft Defender / SmartScreen:**
  [Submit a file for malware analysis](https://www.microsoft.com/wdsi/filesubmission/)
  (select *"Software developer" → false positive*). Attach the `.apbx`, paste
  the SHA-256, and mention: unsigned community playbook for AME Wizard, open
  source at github.com/UltraOS-Project/playbook, hash-verified release.
- **Your AV vendor:** every major vendor has a false-positive page
  (Kaspersky, Avast/ AVG, Bitdefender, ESET…). Submit the same evidence.
- **AME Wizard detections:** report those to the Ameliorated team — their
  tool, their signing story — and always re-download the wizard from the
  official site only ([ameliorated.io](https://ameliorated.io)).

## The audit, reproduced in one command

Run this in a clone of this repository — it greps every shipped script and
module for the classic dropper/downloader/obfuscation patterns; every hit
below is expected to be a comment, never live code:

```bash
grep -RniE 'FromBase64String|DownloadString|DownloadFile|Invoke-Expression|\bIEX\b|-EncodedCommand|certutil|bitsadmin|mshta|Start-BitsTransfer' src/playbook/
```

Zero hits is the expected, maintained state of this repository. If a future
commit ever changes that, the build's validation step and this document are
both designed to make it loud.

## Related reading

- [INSTALL.md](INSTALL.md) — the full safe-install walkthrough (step 0 covers
  the Defender pre-toggle honestly).
- [FAQ.md](FAQ.md) — "Why do I have to turn off Defender to install?" and the
  anti-cheat question.
- [MODULES.md](MODULES.md) — every action by module and preset, with
  trade-offs.
