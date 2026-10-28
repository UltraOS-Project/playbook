# Security warnings and UltraOS

Security warnings should be taken seriously. UltraOS is a system-configuration
playbook run by AME Wizard; it changes Windows settings and therefore may be
flagged by security products. That possibility does not establish that a
detection is false, and this document is not a request to bypass protection.

## If a security alert appears

1. **Stop.** Do not run the flagged file, click "Allow" or "Run anyway", turn
   off Defender or another antivirus, or add an exclusion.
2. Record the security product, exact detection name, flagged file path, and
   the action it took (blocked, quarantined, or removed). If AME Wizard was
   already running, save its log and the UltraOS install report if present.
3. Verify that the download came from the official
   [UltraOS releases](https://github.com/UltraOS-Project/playbook/releases)
   and compare its SHA-256 with that release's `SHA256SUMS.txt`. A matching
   hash confirms the file matches the published release; it does **not** prove
   the file is safe or disprove a detection.
4. Submit the exact file and detection details to the security vendor for
   analysis. Microsoft Defender detections can be submitted through
   [Microsoft Security Intelligence](https://www.microsoft.com/wdsi/filesubmission/).
   For an AME Wizard detection, also contact the
   [Ameliorated team](https://ameliorated.io).
5. Proceed only if the vendor resolves the detection or you have independently
   reviewed the exact source and accept the risk. If you are unsure, do not run
   the file.

Do not upload private or organization-managed files to public scanning
services. Follow your organization's security policy when using a managed
device.

## Reviewing the source

The playbook source is available in this repository under `src/playbook/`.
The `.apbx` package is a system-modification playbook, not an ordinary
document; review the configuration and scripts before running it. The
installer does not disable or reconfigure Microsoft Defender or other
antivirus products. A separate, user-invoked recovery command can clear known
Defender overrides left by older UltraOS releases. If a release behaves
differently, stop and report it.

The AME Wizard application is a separate third-party program. Download it
only from the official [Ameliorated site](https://ameliorated.io), and submit
any warning about it to that product's publisher and your security vendor.

## Related documentation

- [INSTALL.md](INSTALL.md) — installation steps and prerequisites.
- [FAQ.md](FAQ.md) — common questions about antivirus alerts and Defender.
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) — diagnosing an interrupted install.
