====================================================================
 U L T R A S O S   v1.1.1  -  READ ME FIRST
 Windows 11 24H2 / 25H2 / 26H2 optimization playbook for AME Wizard
====================================================================

You just downloaded UltraOS. This file gets you from here to a
finished install in about ten minutes. The full guide lives at:

    https://github.com/UltraOS-Project/playbook/blob/main/docs/INSTALL.md


WHAT'S IN THIS DOWNLOAD
-----------------------
- UltraOS-Playbook-v1.1.1.apbx    the playbook (do NOT unzip it -
                                  AME Wizard opens it directly)
- SHA256SUMS.txt                  hashes to verify the download
- README-FIRST.txt                this file
- CHANGELOG.md, LICENSE, NOTICE   release info


REQUIREMENTS (the wizard checks all of these)
---------------------------------------------
- Windows 11 build 26100 (24H2), 26200 (25H2), or 26300 (26H2),
  Home or Pro. Check with: Win+R -> winver
- AME Wizard, free from https://ameliorated.io
- Internet connection, mains power, no pending Windows Updates,
  no third-party antivirus
- Microsoft Defender toggled OFF for the duration of the install
  (Windows Security -> Virus & threat protection -> Manage settings ->
  turn the four protection toggles off). Why: the install writes
  hundreds of registry values and service configs; real-time
  scanning and Tamper Protection make those writes unreliable.
  Defender is turned back ON automatically at the end of the
  install unless you explicitly opt out.


3-STEP QUICK START
------------------
1. Install AME Wizard: https://ameliorated.io
2. Toggle Defender off (see above).
3. Open UltraOS-Playbook-v1.1.1.apbx in AME Wizard, pick a preset
   (Balanced is the recommended default), review the extra options
   (all optional, all off by default), choose a browser, press Start.


AFTER THE INSTALL
-----------------
- Your report of every change: C:\Windows\UltraOS\install-report.html
- On/off toggles for everything: C:\Windows\UltraOS\ (see the
  README.txt inside it)
- Full undo: C:\Windows\UltraOS\Undo.cmd  (or "Uninstall UltraOS")


VERIFY THE DOWNLOAD (recommended)
---------------------------------
Compare the hash of the .apbx against SHA256SUMS.txt:

    Windows PowerShell:  Get-FileHash .\UltraOS-Playbook-v1.1.1.apbx
    Linux/macOS:         sha256sum UltraOS-Playbook-v1.1.1.apbx

If the hash does not match, delete the download and get a fresh
copy from the official releases page.


ANTIVIRUS WARNING? READ THIS
-----------------------------
Windows SmartScreen or your antivirus may flag AME Wizard or this
.apbx file. That is a known false-positive pattern for the whole
playbook ecosystem (unsigned community tool + password-protected
container + system-modification heuristics), not a finding about
this file. UltraOS ships ZERO executables - it is plain-text YAML
and PowerShell you can read at github.com/UltraOS-Project/playbook,
with no obfuscation, no downloaders and no network calls - and
Defender is re-enabled automatically at the end of the install.

The strongest answer is the hash check above: if it matches
SHA256SUMS.txt, you have the authentic file. Full story and the
safe path through any warning (including how to report the false
positive to Microsoft so the flag dies for everyone):

    docs/ANTIVIRUS.md in this repository

Optional: run Test-WithRealWizard.cmd (included in this download) to
verify the checksum, test the container exactly like the engine reads
it, and launch the wizard with the playbook preloaded.


WHAT'S NEW IN 1.1.1
-------------------
CRITICAL HOTFIX
- Fixed the install halting with "error code: 3" while copying the
  UltraOS folder (it was deployed to the wrong location,
  Windows\UltraOSFolder instead of Windows\UltraOS). If your 1.0.x or
  1.1.0 run stopped there: just run this version - it cleans up the
  leftover and completes the install.
- Upgrade runs no longer delete the freshly installed UltraOS folder.
- Undo.cmd now uses Windows (CRLF) line endings like every other .cmd.

WHAT'S NEW IN 1.1.0
-------------------
MORE TUNING
- New "Tuning extras" wizard page: SysMain off, Search indexing off,
  memory compression off, hardware-accelerated GPU scheduling off -
  each an opt-in checkbox with its trade-off documented.
- Sticky Keys shortcut off (opt-in), mouse acceleration off and
  instant menus now actually ship where the docs always promised,
  MMCSS Games profile at Extreme, EPP=performance in the max-power
  scheme.
ANTIVIRUS TRANSPARENCY
- New docs/ANTIVIRUS.md: why AVs flag playbooks, what we ship (and
  never ship), SHA-256 verification, false-positive reporting.
Everything else is unchanged from 1.0.1. Re-running over an older
install is supported and safe.


LINKS
-----
- Documentation .... https://github.com/UltraOS-Project/playbook
- Install guide .... docs/INSTALL.md in this repository
- Troubleshooting .. docs/TROUBLESHOOTING.md
- License .......... GPL-3.0 (see LICENSE) - free to use, study,
                     modify, and share. UltraOS is a community
                     project with no warranty; you are responsible
                     for your own system. Not affiliated with
                     Microsoft or Ameliorated.

Enjoy your faster, quieter Windows.
                                                      - The UltraOS Project
