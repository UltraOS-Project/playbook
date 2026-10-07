================================================================
 ULTRAOS v1.1.0 - POST-INSTALL FOLDER
================================================================

Welcome to UltraOS! This folder (C:\Windows\UltraOS) was copied
here by the UltraOS playbook. It lets you flip the big opt-in
decisions AFTER installation, without re-running the playbook.

Every "Enable"/"Disable" script asks for administrator rights
automatically - just double-click the one you want. Scripts
marked "(default)" show the state UltraOS recommends (and the
state the Balanced preset installs).

----------------------------------------------------------------
 1. SECURITY
----------------------------------------------------------------
Defender (Enable) (default).cmd / Defender (Disable).cmd
    Turns Microsoft Defender back on or off at the policy level.
    - Enable clears the DisableAntiSpyware policies so real-time
      protection re-arms (reboot recommended, then turn Tamper
      Protection back on).
    - Disable applies the 2026-proof double-write policy set the
      playbook uses (policy hive + core Defender key + gpupdate
      re-apply).
    WARNING: running Windows without antivirus is risky. Keep
    Defender enabled unless you have a replacement.
    NOTE: if Tamper Protection is on, Windows Security may
    revert the disable policies - turn it off first.

Mitigations (Enable) (default).cmd / Mitigations (Disable).cmd
    CPU security mitigations (Spectre/Meltdown family, CFG,
    SEHOP). Disable can help performance on OLD CPUs only - on
    modern CPUs the gain is near zero and the risk is real.
    Valorant keeps its CFG exception automatically; other
    anti-cheats (e.g. Fortnite/EAC) may misbehave while
    mitigations are off. A REBOOT is required.

Core Isolation (Enable) (default).cmd / Core Isolation (Disable).cmd
    Virtualization-Based Security / Memory Integrity (HVCI).
    While disabled, Valorant/Vanguard, FACEIT, WSL2, Docker
    Desktop and Hyper-V do NOT work. Only disable for old CPUs
    or benchmarking. A REBOOT is required.

----------------------------------------------------------------
 2. UPDATES
----------------------------------------------------------------
Automatic Updates (Enable) (default).cmd / Automatic Updates (Disable).cmd
    - Disable = NOTIFY ONLY / MANUAL INSTALL: nothing downloads or
      installs on its own - you check for updates in Settings and
      install them when you want (same policy pair the playbook's
      "Notify only" wizard option applies).
    - Updates are NEVER fully turned off (the update services stay
      untouched) - security fixes are always one manual check away.
    - Enable restores the default fully-automatic behavior.

----------------------------------------------------------------
 3. FEATURES
----------------------------------------------------------------
GameDVR (Disable) (default).cmd / GameDVR (Enable).cmd
    Background game recording (Game Bar capture, Win+G). UltraOS
    disables it by default to avoid the recording overhead.
    Enable restores the Windows defaults. The Xbox Game Bar app
    itself and Game Mode are never touched by this toggle.

Recall (Disable) (default).cmd / Recall (Enable).cmd
    Recall (AI) snapshot saving. Disabling also deletes already
    saved snapshots - that is how the Windows policy works.
    This is the reversible policy layer; it does not remove
    Recall components.

----------------------------------------------------------------
 4. TOOLS
----------------------------------------------------------------
View Install Report.cmd
    Opens the report the playbook generated at the end of the
    install:  C:\Windows\UltraOS\install-report.html
    (a plain-text install-report.txt sits next to it).

Open Backups Folder.cmd
    Opens C:\Windows\UltraOS\Backups - the pre-install backups
    (services, appx list, scheduled tasks) used for rollback.

Uninstall UltraOS.cmd
    Runs the undo tool (restores backed-up service states,
    scheduled tasks and registry values), then removes this
    folder. Partial undo: things Windows itself re-applies
    (e.g. removed appx apps) are only listed in the report with
    reinstall pointers. A reboot is recommended afterwards.

----------------------------------------------------------------
 5. SOFTWARE
----------------------------------------------------------------
Reinstall Microsoft Edge.cmd
    Opens the official Microsoft Edge download page (for users
    who removed Edge with the playbook opt-in and want it back).

Install a Browser.url
    Opens the UltraOS browser install documentation. Quick
    copy-paste (elevated terminal):
        winget install Brave.Brave
        winget install Mozilla.Firefox
        winget install LibreWolf.LibreWolf

----------------------------------------------------------------
 SAFETY NOTES
----------------------------------------------------------------
- Everything here is registry/policy level and reversible
  through the paired script - no Windows components are removed.
- Toggles that touch the kernel (Mitigations, Core Isolation)
  need a reboot to take effect.
- Your install choices and current toggle states are recorded
  under HKLM\SOFTWARE\UltraOS\SetupOptions - the install report
  reads them from there.

UltraOS is GPL-3.0 software. The post-install folder pattern is
derived from the Atlas playbook by AtlasOS contributors.
https://github.com/Atlas-OS/Atlas
