# Installing UltraOS

This guide walks you through a complete UltraOS install: the prerequisites, the Defender pre-step (and why it exists), the AME Wizard pages one by one, and what to do after the progress bar finishes. It assumes a supported machine and no special prior knowledge. If something goes wrong along the way, [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md) covers the known failure modes and their fixes.

## Prerequisites

Before you open anything, confirm your machine is ready. The wizard checks most of these itself and will refuse to start (politely) if they are not met, but checking first saves you a round trip.

- **A supported Windows build.** UltraOS runs on Windows 11 **26H2 (build 26300)**, **25H2 (26200)**, and **24H2 (26100)**, Home or Pro. Check yours with `winver` (Windows key + R → `winver` → OK) and look at the build number. Anything else — including Windows 10 and Insider builds — is rejected.
- **A stable internet connection.** The wizard needs it (browser downloads, playbook updates), and a connection that drops mid-install is the most avoidable failure there is.
- **No pending Windows Updates.** Install all pending updates and reboot first. A pending update can reboot the machine mid-playbook, which is exactly as unpleasant as it sounds.
- **Mains power (laptops).** Plug in the charger. A playbook that dies at 12% battery halfway through is no fun for anyone.
- **No third-party antivirus.** Uninstall or fully disable any third-party AV before starting. The wizard detects active AV products and will not continue, and an AV that fights the playbook's registry writes makes the install unreliable.
- **A backup of anything you care about.** UltraOS takes its own backups and offers a restore point, but you are always the last line of defense for your own data.

## Step 0 — Toggling off Defender (the pre-step)

This is the step people ask about most, so here it is in full, up front. UltraOS requires **Microsoft Defender to be toggled off before the install starts**. The wizard enforces this requirement (it is called `DefenderToggled` in the playbook metadata) and will not proceed until it is satisfied.

**How to do it:**

1. Open **Windows Security** (Start → type "Windows Security").
2. Go to **Virus & threat protection**.
3. Under *Virus & threat protection settings*, click **Manage settings**.
4. Toggle **off** the primary protections: **Real-time protection**, **Cloud-delivered protection**, **Automatic sample submission**, and **Tamper Protection**.
5. Leave this window open — after the install, Defender comes back on and you will want to verify.

**Why this is required.** The playbook writes several hundred registry values, service configurations, and policy keys in a few minutes. With real-time protection active, Defender can intercept and quarantine parts of that work — and Tamper Protection specifically blocks writes to Defender's own policy keys, which the install needs to perform (even to *re-enable* Defender cleanly at the end). Toggling Defender off by hand, in the UI, is the one thing that cannot be automated away *by design* — Tamper Protection exists precisely so that no software (including us) can silently turn your antivirus off. That is also your guarantee that we turn it back on with your full knowledge.

**What happens to Defender afterwards.** Unless you explicitly check the `opt-disable-defender` box during the wizard, **UltraOS re-enables Defender automatically at the very end of the install** — it is deliberately the last module that runs, after every other change is complete. You will see it in the install report, and the UltraOS folder contains a permanent on/off toggle pair for it afterwards. If Defender does not come back on by itself, see [Troubleshooting](TROUBLESHOOTING.md#defender-wont-re-enable) — the fix is a ten-second manual step involving Tamper Protection.

## Step 1 — Get AME Wizard

UltraOS is a playbook for **AME Wizard**, the open ecosystem playbook runner maintained by Ameliorated — the same wizard used by AtlasOS and ReviOS. Download it from the official site: **<https://ameliorated.io>** (the site now lives under amelabs.net; the old address redirects). Install it like any Windows application. If your browser or Defender flags the download, that is a false positive on a password-protected archive — the wizard's documentation explains how to allow it.

Next, download the UltraOS playbook (an `.apbx` file) from the [UltraOS releases](https://github.com/UltraOS-Project/UltraOS/releases). If your download ships with a `SHA256SUMS.txt`, verify the hash before running (see [README-FIRST.txt](../src/release-zip/README-FIRST.txt) for the exact commands). You do not need to extract or unzip anything — the wizard opens the file directly.

## Step 2 — Open the playbook and walk the wizard pages

Launch AME Wizard, then drag the `.apbx` onto the window (or use *Select Playbook*). After the wizard reads your system, you will meet **five pages of choices**. This is what each one means and what we recommend:

### Page 1 — Preset

Choose how aggressive UltraOS should be. **Balanced** is the default and our recommendation for daily use; it applies the full services, debloat, privacy, network, and visual stack with honest trade-offs. **Safe** is disable-only, and everything it does is individually reversible — the right choice for a first-timer, a work machine, or a system you cannot afford to experiment on. **Extreme** adds aggressive removals (Widgets, Phone Link, Xbox apps, search indexing off) and experimental network flags — read [docs/MODULES.md](MODULES.md) before choosing it. Everything is changeable afterwards via the UltraOS folder, so when in doubt, start at Balanced.

### Page 2 — Restore point

UltraOS can create a **System Restore Point** before touching anything. This is **on by default and strongly recommended** — it is your instant "get me out" hatch from Windows Recovery if anything ever goes catastrophically wrong. Note that UltraOS writes its own file backups (`C:\Windows\UltraOS\Backups\`) either way, so this choice is purely about the extra safety net. One honest caveat: Windows throttles restore-point creation to once per 24 hours by default, so if Windows or another app made a checkpoint very recently, a new one may be skipped silently — see [Troubleshooting](TROUBLESHOOTING.md#restore-point-was-not-created).

### Page 3 — Windows Updates

Pick how updates are handled after install. **Automatic** (default, recommended) keeps your machine patched without any action from you. **Notify only** downloads nothing until you approve — for people who want to review each update. UltraOS **never fully disables Windows Update** at either setting, and you can switch modes later from the UltraOS folder (`2. Updates`).

### Page 4 — Extras (two screens of checkboxes)

These are the opt-in extras, all unchecked by default. The first screen holds the advanced, trade-off-heavy options: **Remove Microsoft Edge**, **Keep Defender disabled** (not recommended), **Disable CPU mitigations** (older CPUs only), and **Disable Core Isolation/VBS** (breaks Valorant, WSL2, Docker — genuinely not recommended). The second screen holds the safer ones: **Maximum Performance power scheme**, **Disable Hibernation**, and **Strip Recall/AI features**. None are required; each links to the documentation from the wizard itself. Our advice: leave the first screen untouched unless you have read the [FAQ](FAQ.md) entries for the option you are considering.

### Page 5 — Browser

Pick the browser to install and set as default: **Brave** (default), **Firefox**, **LibreWolf**, or **None** to keep what you have. This page is driven by the wizard engine itself — it downloads and installs the browser and offers to make it your default (a Windows confirmation prompt appears; UCPD, the browser-default protection driver, insists that *you* confirm default-browser changes, and we respect that rather than fighting it). UltraOS does not modify your browser's settings or import anything.

When you are happy with the choices, press **Start** and let it run — the wizard shows live progress per module, and the playbook's own status text tells you where it is. Typical duration is around eight minutes on a normal machine, plus a few more if you selected browser downloads. **Do not use the machine while it runs**, and let it finish; the final module re-enables Defender and generates your report. UltraOS schedules no automatic reboots — restart Windows once yourself afterwards so every change settles in.

## Step 3 — After the install: the UltraOS folder tour

When the wizard finishes, restart Windows once (recommended) and you will find a new folder: **`C:\Windows\UltraOS\`**. This is your control panel for everything UltraOS did. Inside you will find:

- **`1. Security\`** — toggle pairs for **Defender** (on/off), **CPU mitigations**, and **Core Isolation (VBS)**. Every toggle is a pair of `.cmd` files (enable/disable) that run elevated with one click.
- **`2. Updates\`** — switch Windows Update between **Automatic** and **Notify only** at any time.
- **`3. Features\`** — flip **GameDVR** and **Recall/AI features** back on or off.
- **`4. Tools\`** — **View Install Report**, **Uninstall UltraOS** (runs the full undo, then cleans up the folder), and a shortcut to your **Backups**.
- **`5. Software\`** — **Reinstall Microsoft Edge** (with guidance) and browser links, for the rare case you need an Edge-dependent feature back.
- **`Backups\`** — the pre-install exports (`services-before.reg`, `appx-before.txt`, `tasks-before.csv`) plus your install report.
- **`install-report.html`** — the report itself (see below).
- **`Undo.cmd`** — one-click undo for the whole playbook.

A `README.txt` inside the folder repeats this tour in short form, so you do not need this document open. A desktop/Start shortcut to the report is also created for convenience.

## Reading the install report

Open `C:\Windows\UltraOS\install-report.html` in any browser. The report is generated from the playbook's own before/after backups and is organized to answer three questions in order:

1. **What changed?** — every applied change, grouped by module (services, debloat, privacy, tasks, network, performance, visual, security), with counts per module so you can skim at a glance.
2. **What didn't change, and why?** — actions skipped because your preset did not include them, because the target did not exist on your machine (common with debloat lists across editions), or because an extra was not selected.
3. **How do I undo this?** — per-module undo notes: which changes are covered by `Undo.cmd` and the revert data, and which operations (app removals, Edge removal) are reversed by reinstalling from the pointers given instead.

A plain-text twin (`install-report.txt`) sits beside it for diffing or pasting into an issue report. If you ever file a bug, attach that `.txt` — it makes diagnosis dramatically faster. If the report is missing entirely, see [Troubleshooting](TROUBLESHOOTING.md#the-install-report-is-missing).

## How to undo UltraOS

There are four levels of undo, from "flip one thing back" to "remove everything":

1. **Per-toggle `.cmd` files** — in the UltraOS folder, every toggle ships as an enable/disable pair. This is the right tool when, say, the classic context menu isn't for you but everything else is fine.
2. **`Undo.cmd`** (a.k.a. *Uninstall UltraOS* in `4. Tools`) — the full undo: restores service startup types from `Backups\services-before.reg`, restores scheduled tasks from `tasks-before.csv`, and imports the playbook's revert data (stock registry values) to walk back policy and privacy changes. Removed apps are not un-removed automatically — the report lists Store/winget pointers to reinstall the ones you actually miss.
3. **System Restore** — if you took the restore point (default), rolling back from Windows Recovery (`rstrui`) reverts the registry/services/tasks state of the entire machine to the pre-install moment. This is the blunt instrument: it does not restore removed app packages either, and it will also undo *anything else* you changed since.
4. **Honest limits** — a few operations are one-way doors by nature: removed AppX packages need reinstalling (pointers provided), and an Edge removal is undone by reinstalling Edge rather than by registry surgery. The report marks these clearly so there are no surprises.

The undo tooling covers the changes UltraOS itself makes; it cannot un-install a browser the wizard installed (uninstall it from Settings → Apps like any application) or un-download a Windows Update that arrived in the meantime.

---

*Next reading: [docs/MODULES.md](MODULES.md) for exactly what each preset changes, or [docs/FAQ.md](FAQ.md) for the reasoning behind the design.*
