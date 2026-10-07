#!/usr/bin/env python3
"""UltraOS scaffold generator — creates all module skeleton YAML files + repo meta files.
Run once from repo root: python3 scripts/gen-skeletons.py  (idempotent, refuses to overwrite non-skeleton content)
"""
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PB = ROOT / "src" / "playbook"
CFG = PB / "Configuration"

# (path relative to Configuration/, title, description, file-level option gate or None, owner, source dossier)
FILES = [
    ("tweaks\\debloat\\appx-removals.yml", "Remove Bloatware Apps", "Removes bloat UWP/AppX packages per preset tier with deprovision protection - see T1-e catalog.", None, "T3-a", "debloat-apps-research.md"),
    ("tweaks\\debloat\\edge-removal.yml", "Remove Microsoft Edge", "Unlocks and removes Microsoft Edge when the user opted in - mechanism per T1-h2 dossier.", "opt-uninstall-edge", "T3-a", "known-issues-compatibility.md"),
    ("tweaks\\debloat\\reinstall-blockers.yml", "Block App Reinstallers", "Prevents Windows from reinstalling DevHome, Outlook and other unwanted apps.", None, "T3-a", "debloat-apps-research.md"),
    ("tweaks\\privacy\\telemetry-services.yml", "Disable Telemetry Services", "Disables DiagTrack and related telemetry services and their autologgers.", None, "T3-b", "privacy-telemetry-research.md"),
    ("tweaks\\privacy\\telemetry-policies.yml", "Telemetry Policies", "Sets diagnostic-data, CEIP, feedback and data-collection policies to their most private values.", None, "T3-b", "privacy-telemetry-research.md"),
    ("tweaks\\privacy\\settings-privacy.yml", "Privacy Settings", "Applies in-Settings privacy toggles via registry - advertising ID, activity history, tracking, personalization.", None, "T3-b", "privacy-telemetry-research.md"),
    ("tweaks\\privacy\\cloud-content.yml", "Disable Cloud Content and Ads", "Turns off suggestions, tips, subscribed content, sync-provider ads and spotlight content.", None, "T3-b", "privacy-telemetry-research.md"),
    ("tweaks\\privacy\\ai-features.yml", "AI Feature Controls", "Disables Recall snapshots and AI data analysis on 24H2+; strips Recall fully when opted in.", None, "T3-b", "privacy-telemetry-research.md"),
    ("tweaks\\privacy\\app-telemetry.yml", "Third-party App Telemetry", "Disables NVIDIA, Office, .NET and PowerShell telemetry.", None, "T3-b", "privacy-telemetry-research.md"),
    ("tweaks\\privacy\\extras-extreme.yml", "Extreme Privacy Extras", "Deeper privacy lockdowns for the Extreme preset - MSA restrictions, location, presence sensing.", "preset-extreme", "T3-b", "privacy-telemetry-research.md"),
    ("ultraos\\services.yml", "Services and Drivers", "Configures services and drivers to reduce background resource use - Atlas-conservative tier.", None, "T3-c", "services-performance-research.md"),
    ("tweaks\\services\\extreme-services.yml", "Extreme Services and Drivers", "Additional service/driver changes for the Extreme preset with honest trade-offs.", "preset-extreme", "T3-c", "services-performance-research.md"),
    ("tweaks\\tasks\\telemetry-tasks.yml", "Disable Telemetry Scheduled Tasks", "Disables CEIP, compatibility-appraiser and other data-collection scheduled tasks.", None, "T3-d", "privacy-telemetry-research.md"),
    ("tweaks\\tasks\\maintenance-tasks.yml", "Maintenance Task Tweaks", "Curated maintenance/compatibility scheduled task changes for the Balanced tier.", None, "T3-d", "services-performance-research.md"),
    ("tweaks\\network\\core.yml", "Network Core", "LLMNR off, SMB hardening and share tweaks - Atlas-parity network security.", None, "T3-e", "services-performance-research.md"),
    ("tweaks\\network\\nic-config.yml", "NIC Configuration", "Applies energy-efficiency-disabling NIC keywords for lower latency.", None, "T3-e", "services-performance-research.md"),
    ("tweaks\\network\\extreme.yml", "Extreme Network Stack", "Aggressive network stack tuning - Extreme preset only, with risk caveats.", "preset-extreme", "T3-e", "services-performance-research.md"),
    ("tweaks\\performance\\gaming.yml", "Gaming", "GameDVR off, MMCSS configuration, background apps off.", None, "T3-f", "services-performance-research.md"),
    ("tweaks\\performance\\system.yml", "System Performance", "FTH, folder discovery, maintenance, service-host split, priority separation.", None, "T3-f", "services-performance-research.md"),
    ("tweaks\\performance\\power.yml", "Power Configuration", "Maximum-performance power scheme and hibernation toggle (opt-in).", None, "T3-f", "services-performance-research.md"),
    ("tweaks\\performance\\extreme.yml", "Extreme Performance", "Timer resolution and further latency-focused tweaks - Extreme preset only.", "preset-extreme", "T3-f", "services-performance-research.md"),
    ("tweaks\\visual\\context-menu.yml", "Classic Context Menu", "Restores the full right-click context menu on Windows 11.", None, "T3-g", "atlas-playbook-analysis.md"),
    ("tweaks\\visual\\taskbar.yml", "Taskbar", "Cleans up the taskbar - chat, widgets button, task view, search.", None, "T3-g", "atlas-playbook-analysis.md"),
    ("tweaks\\visual\\explorer.yml", "File Explorer", "Explorer quality-of-life - This PC view, extensions, recommendations off.", None, "T3-g", "atlas-playbook-analysis.md"),
    ("tweaks\\visual\\extras.yml", "Visual Extras", "Extra visual changes for the Extreme preset - transparency, animations, dynamic lighting.", "preset-extreme", "T3-g", "atlas-playbook-analysis.md"),
    ("tweaks\\qol\\system-info.yml", "System Information", "Sets UltraOS OEM support information shown in Settings > About.", None, "T3-g", "atlas-playbook-analysis.md"),
    ("tweaks\\qol\\shortcuts.yml", "Shortcuts", "Creates UltraOS folder and report shortcuts.", None, "T3-g", "atlas-playbook-analysis.md"),
    ("tweaks\\qol\\updates.yml", "Windows Update Policy", "Notify-only update policy when the user opted in - never disables updates.", None, "T3-g", "known-issues-compatibility.md"),
    ("tweaks\\security\\defender-reenable.yml", "Re-enable Defender", "Restores Defender protections at the end of installation unless the user opted to keep it disabled.", "!opt-disable-defender", "T3-h", "known-issues-compatibility.md"),
    ("tweaks\\security\\defender-disable.yml", "Keep Defender Disabled", "Keeps Defender disabled with 2026-proof double-written policies when the user opted in.", "opt-disable-defender", "T3-h", "known-issues-compatibility.md"),
    ("tweaks\\security\\mitigations.yml", "Disable CPU Mitigations", "Disables CPU security mitigations when the user opted in - older CPUs only.", "opt-disable-mitigations", "T3-h", "services-performance-research.md"),
    ("tweaks\\security\\vbs.yml", "Disable Core Isolation", "Disables VBS/HVCI when the user opted in - not recommended.", "opt-disable-vbs", "T3-h", "services-performance-research.md"),
    ("tweaks\\ultraos\\copy-folders.yml", "Copy UltraOS Folder", "Copies the UltraOS post-install folder and tooling to Windows\\UltraOS.", None, "T3-j", "atlas-playbook-analysis.md"),
    ("tweaks\\ultraos\\finish.yml", "UltraOS Finish", "Generates the install report, re-enables notifications, secures execution policy, writes final markers.", None, "T3-i", "execution-performance-packaging.md"),
]

TEMPLATE = """---
title: {title}
description: >-
  {desc}
{option_line}actions: []
# TODO({owner}): implement using research/{src} and the build manifest (research/03-build-manifest.md).
# Replace this skeleton - keep the header shape, follow research/02-style-guide.md.
"""

def main():
    for rel, title, desc, gate, owner, src in FILES:
        p = CFG / rel.replace("\\", "/")
        p.parent.mkdir(parents=True, exist_ok=True)
        if p.exists() and "TODO(" not in p.read_text(encoding="utf-8"):
            print(f"  keep (has content): {rel}")
            continue
        option_line = f"option: '{gate}'\n" if gate else ""
        p.write_text(TEMPLATE.format(title=title, desc=desc, option_line=option_line, owner=owner, src=src), encoding="utf-8")
        print(f"  skeleton: {rel}")

    # revert.yml (owned by T3-i)
    rev = CFG / "ultraos" / "revert.yml"
    if not rev.exists():
        rev.write_text(TEMPLATE.format(title="Stock Values (Revert)", desc="Inventory of stock/default values UltraOS changes - the data source for undo.", option_line="", owner="T3-i", src="services-performance-research.md"), encoding="utf-8")
        print("  skeleton: ultraos\\revert.yml")

    meta = [
        (ROOT / ".gitignore", "dist/\n__pycache__/\n*.pyc\n.DS_Store\nnode_modules/\n*.tmp\n"),
        (ROOT / ".editorconfig", "[*]\ncharset = utf-8\nend_of_line = lf\ninsert_final_newline = true\nindent_style = space\nindent_size = 2\n\n[*.yml]\nindent_size = 2\n\n[*.{cmd,bat}]\nend_of_line = crlf\n"),
        (ROOT / "NOTICE", """UltraOS
Copyright (C) 2026 UltraOS Project

This program is free software: GPL-3.0 (see LICENSE).

ATTRIBUTION
- Derived in part from the Atlas playbook (https://github.com/Atlas-OS/Atlas),
  Copyright (C) AtlasOS contributors, GPL-3.0. Structure, playbook.conf
  conventions and selected tweak implementations are derived from Atlas.
- Executed by AME Wizard; its backend TrustedUninstaller
  (https://github.com/Ameliorated-LLC/trusted-uninstaller-cli, MIT) and
  ame-assassin (MIT) are used unmodified at runtime by the wizard.
- Design informed by ReviOS (https://github.com/MeetRevision/playbook, CC BY-SA 4.0 -
  ideas only, no code copied) and other projects credited in docs/COMPARISON.md.
(Placeholder - finalized by T3-k.)
"""),
    ]
    for p, content in meta:
        if not p.exists():
            p.write_text(content, encoding="utf-8")
            print(f"  meta: {p.name}")

if __name__ == "__main__":
    main()
