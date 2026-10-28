====================================================================
 U L T R A S O S   v1.2.0  -  READ ME FIRST
 Windows 11 24H2 / 25H2 / 26H2 optimization playbook for AME Wizard
====================================================================

You just downloaded UltraOS. This file gets you from here to a
finished install in about ten minutes. The full guide lives at:

    https://github.com/UltraOS-Project/playbook/blob/main/docs/INSTALL.md


WHAT'S IN THIS DOWNLOAD
-----------------------
- UltraOS-Playbook-v1.2.0.apbx    the playbook (do NOT unzip it -
                                  AME Wizard opens it directly)
- SHA256SUMS.txt                  hashes to verify the download
- README-FIRST.txt                this file
- CHANGELOG.md, LICENSE, NOTICE   release info


REQUIREMENTS (the wizard checks all of these)
---------------------------------------------
- Windows 11 build 26100 (24H2), 26200 (25H2), or 26300 (26H2),
  Home or Pro. Check with: Win+R -> winver
- AME Wizard, free from https://ameliorated.io
- Internet connection, mains power, and no pending Windows Updates
- Keep Microsoft Defender and any other antivirus enabled. UltraOS
  does not disable or reconfigure antivirus protection. If security
  software reports a threat, stop and investigate; do not add an
  exclusion or turn protection off.


2-STEP QUICK START
------------------
1. Install AME Wizard: https://ameliorated.io
2. Open UltraOS-Playbook-v1.2.0.apbx in AME Wizard, pick a preset
   (Balanced is the recommended default), review the extra options
   (all optional, all off by default), choose a browser, press Start.


AFTER THE INSTALL
-----------------
- Your report of every change: C:\Windows\UltraOS\install-report.html
- Post-install settings and recovery commands: C:\Windows\UltraOS\
  (see the README.txt inside it)
- Full undo: C:\Windows\UltraOS\Undo.cmd  (or "Uninstall UltraOS")


VERIFY THE DOWNLOAD (recommended)
---------------------------------
Compare the hash of the .apbx against SHA256SUMS.txt:

    Windows PowerShell:  Get-FileHash .\UltraOS-Playbook-v1.2.0.apbx
    Linux/macOS:         sha256sum UltraOS-Playbook-v1.2.0.apbx

If the hash does not match, delete the download and get a fresh
copy from the official releases page.


ANTIVIRUS WARNING? READ THIS
-----------------------------
Windows SmartScreen or your antivirus may alert on AME Wizard or
this .apbx file. Do not assume the alert is a false positive, click
through it, add an exclusion, or turn protection off. A matching
SHA-256 confirms the file matches the published release; it does not
prove that the file is safe. See the full guidance, including how to
submit the exact detection to the vendor:

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
