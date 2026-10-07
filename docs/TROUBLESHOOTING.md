# Troubleshooting UltraOS

The failure modes below are the ones our compatibility research found across the playbook ecosystem (Atlas and ReviOS issue trackers, vendor documentation, and our own 26H2 research) — with UltraOS-specific fixes. Before anything else: the plain-text install report at `C:\Windows\UltraOS\install-report.txt` tells you exactly what ran, what was skipped, and what errored. Attach it when filing an issue; it makes diagnosis dramatically faster.

## The wizard says my Windows build is not supported

**Symptom:** AME Wizard refuses to start the playbook with *"Requirements not met … This Windows build is not supported by this Playbook."* There is no bypass button, by design — the build gate protects you from tweaks aimed at a different Windows.

**Cause and fix:** UltraOS supports exactly three builds: **26100 (24H2), 26200 (25H2), and 26300 (26H2)**. Press Windows key + R, run `winver`, and read the build number. If you are on Windows 10 or an Insider/Dev build, UltraOS cannot help you — downgrade expectations or switch channels first. If you are on 26H1 (28000, the ARM-only interim release), that is a separate branch we do not support in v1. If `winver` shows a supported build and the wizard still complains, you are probably running a different playbook's `.apbx` (each has its own list) — re-download UltraOS from the official releases and verify the file hash against `SHA256SUMS.txt`.

## UCPD / "UserChoice Protection Driver" notes

**Context for the curious:** Windows ships a kernel driver called UCPD that protects your default-browser and file-association choices (the `UserChoice` registry keys) from programmatic hijacking. It is strict: `reg.exe`, `powershell.exe` and friends are simply denied writes to those keys, and it has grown more aggressive with every cumulative update. It is also the reason some playbooks demand a "Prepare System" reboot before installing — they want to *disable* UCPD so they can hard-code file associations at the driver's expense.

**UltraOS does not do that.** We never write UserChoice/file-association keys, so we never need to disable UCPD, and you will never see a UCPD-related preparation step from us. Your default browser is set through the wizard's own browser flow (engine `Software` packages with `DefaultWebBrowser`, plus the Windows confirmation prompt) — the legitimate route that UCPD permits. The only UCPD-adjacent change UltraOS makes is disabling its *velocity* scheduled task (Balanced tier and up, alongside other maintenance-task disables) — that task exists to re-assert UCPD's configuration after servicing, and calming it changes nothing about your protections today; the driver itself stays loaded and protecting. If some *other* tool on your machine is complaining about UCPD or asking you to disable it, that tool is fighting the driver; UltraOS takes no position beyond not joining the fight.

## I removed Edge and Windows Update now loops/fails

**Symptom:** after removing Microsoft Edge (the `opt-uninstall-edge` extra), Windows Update repeatedly fails, hangs at a percentage, or "installs" the same update forever. This is the single most documented Edge-removal consequence in the ecosystem: some Windows Update paths need Edge/WebView bits to complete.

**Fix (the sequence matters):** reinstall Edge, let Windows Update complete everything, then remove Edge again if you want to. In detail: (1) open `C:\Windows\UltraOS\5. Software\` and use the *Reinstall Microsoft Edge* pointer — or run `winget install Microsoft.Edge` — which restores the current Stable Edge; (2) open Settings → Windows Update and *Check for updates* until everything, including the stuck cumulative, installs cleanly; (3) reboot; (4) re-run UltraOS with the Edge-removal extra if you still want Edge gone. UltraOS's removal already sweeps the EdgeUpdater scheduled tasks and `edgeupdate`/`edgeupdatem` services that would otherwise re-spawn after reboot, which prevents one common recurrence loop. If you rely on Widgets, Outlook (new), or Xbox-app features, know that several of them are WebView-dependent — the *browser* removal keeps the WebView2 Runtime, but full functionality of those apps is not guaranteed on every build.

## Defender won't re-enable

**Symptom:** the install finished but Windows Security still shows real-time protection (or Tamper Protection) off, even though you did not check *Keep Defender disabled*.

**Cause:** Tamper Protection. If it is still off when UltraOS's re-enable module runs, Windows can restore the service and policies but the *tamper* state sometimes requires a human hand — and that is the point of the feature: no software, including a well-meaning playbook, is allowed to silently re-arm your defenses against your will.

**Fix:** open **Windows Security → Virus & threat protection → Manage settings**, and toggle the protections back on by hand: real-time protection, cloud-delivered protection, automatic sample submission, and **Tamper Protection**. Then check the shield icon returns to green. Afterwards, the on/off pair in `C:\Windows\UltraOS\1. Security\` can manage Defender for you normally. If you had checked `opt-disable-defender` and have changed your mind, use that same folder toggle to bring Defender back (it runs the same re-enable path; you may still need the manual Tamper step the first time).

## Apps I removed came back after a feature update

**Symptom:** weeks or months later, a Windows feature update (e.g. 25H2 → 26H2) lands, and bloat apps you had removed are back — or new, differently-named ones appeared.

**Cause:** this is documented Microsoft behavior, not a bug in the removal: deprovisioning keys block re-adding *known package versions* for *new users*, but a feature update's image can ship new package versions and renamed families (Teams → `MSTeams`, new Copilot packages, etc.) that pre-date our blocklist. Our removal lists use wildcards and tolerate missing packages for exactly this reason, but they cannot remove what only exists after the update ships.

**Fix:** re-run UltraOS after any feature update — the run is idempotent (it re-applies only what is missing), refreshes your backups, and re-points the deprovision keys at what the new image introduced. The new install report shows what the re-run found. This is also the answer to "do tweaks survive updates?" in the [FAQ](FAQ.md).

## Restore point was not created

**Symptom:** you chose *Create System Restore Point (recommended)*, but Windows shows no new restore point (or the report notes it was skipped).

**Cause:** one of two things. Most commonly, **Windows throttles restore-point creation to one per 24 hours** by default — if Windows, a driver installer, or another tool created a checkpoint within the last day, `Checkpoint-Computer` is silently skipped rather than duplicated. Less commonly, **System Protection is disabled** on the OS drive, in which case there is nowhere to put a checkpoint.

**Fix and reassurance:** to rule out the throttle, just proceed — your recent checkpoint still covers you. To check protection status: search "Create a restore point" → *Configure*, and ensure protection is **On** for `C:`. Then, if you specifically want an UltraOS-branded checkpoint right now, either delete the day's existing checkpoints first or set the creation-frequency override and re-run (advanced; see `SystemRestorePointCreationFrequency`). Importantly, **your safety net does not depend on this**: UltraOS always writes its full file backups (`services-before.reg`, `appx-before.txt`, `tasks-before.csv`) to `C:\Windows\UltraOS\Backups\` regardless of the restore-point choice, and `Undo.cmd` restores from those.

## The install report is missing

**Symptom:** `C:\Windows\UltraOS\install-report.html` does not exist after the wizard finished.

**Fix:** (1) Make sure you are looking in `C:\Windows\UltraOS\` — not `C:\Program Files`, not your user folder; the folder shortcut on the desktop/Start points to the right place. (2) Check the UltraOS folder exists at all. If `C:\Windows\UltraOS\` itself is missing, the very first module (folder copy) failed — typically antivirus interference (did you skip the Defender pre-step or re-enable a third-party AV mid-install?) or a broken download. Re-run the playbook after fixing the cause. (3) If the folder exists but the report is absent, the report-generation step failed; you can regenerate it by re-running the playbook (safe — idempotent) or by filing an issue with the wizard log attached — logs live under `C:\ProgramData\AME\Logs\<newest>\`. (4) Everything the report would have told you is reconstructable from `Backups\` plus the wizard's own log.

## Something else broke

Start with the layers of undo, cheapest first: the per-toggle `.cmd` pairs in the UltraOS folder; `Undo.cmd` for the full revert; the restore point from Windows Recovery for the nuclear option — in that order. For generic Windows Update errors not related to Edge removal, the ecosystem-standard repair is `DISM /Online /Cleanup-Image /RestoreHealth` followed by `sfc /scannow` (ignore "source files not found" on the first pass and retry). For Store/app problems after heavy debloat, `wsreset -i` re-registers the Store. If a specific game or app misbehaves, check whether you enabled a security-reducing extra (mitigations/VBS) — re-enabling those from `1. Security\` resolves the overwhelming majority of such reports, as covered in the [FAQ's anti-cheat section](FAQ.md#is-ultraos-safe-with-anti-cheat-games). And if you find a genuinely new bug, please file it with `install-report.txt` attached — good reports get fixed fast.
