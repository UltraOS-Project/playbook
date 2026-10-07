====================================================================
 U L T R A S O S   v1.0.0  -  READ ME FIRST
 Windows 11 24H2 / 25H2 / 26H2 optimization playbook for AME Wizard
====================================================================

You just downloaded UltraOS. This file gets you from here to a
finished install in about ten minutes. The full guide lives at:

    https://github.com/UltraOS-Project/UltraOS/blob/main/docs/INSTALL.md


WHAT'S IN THIS DOWNLOAD
-----------------------
- UltraOS-Playbook-v1.0.0.apbx    the playbook (do NOT unzip it -
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
3. Open UltraOS-Playbook-v1.0.0.apbx in AME Wizard, pick a preset
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

    Windows PowerShell:  Get-FileHash .\UltraOS-Playbook-v1.0.0.apbx
    Linux/macOS:         sha256sum UltraOS-Playbook-v1.0.0.apbx

If the hash does not match, delete the download and get a fresh
copy from the official releases page.


LINKS
-----
- Documentation .... https://github.com/UltraOS-Project/UltraOS
- Install guide .... docs/INSTALL.md in this repository
- Troubleshooting .. docs/TROUBLESHOOTING.md
- License .......... GPL-3.0 (see LICENSE) - free to use, study,
                     modify, and share. UltraOS is a community
                     project with no warranty; you are responsible
                     for your own system. Not affiliated with
                     Microsoft or Ameliorated.

Enjoy your faster, quieter Windows.
                                                      - The UltraOS Project
