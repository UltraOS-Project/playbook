# UltraOS Modules & Presets

This document is the complete map of what UltraOS does, organized by module and preset. Use it to decide between Safe, Balanced, and Extreme, to understand a specific change before (or after) applying it, or to build a custom install by skipping modules entirely (see [Skipping a module](#skipping-a-module)). Everything here is also visible after install in `C:\Windows\UltraOS\install-report.html`, and the source YAML for every module ships in this repository under `src/playbook/Configuration/`.

## How the presets gate actions

The three presets are depth tiers applied with strict, mechanical rules — there is no per-tweak judgement call at install time. An action with **no option gate runs under every preset** (that is the Safe tier). An action gated `option: '!preset-safe'` runs when the selected preset is **Balanced or Extreme**. An action gated `option: 'preset-extreme'` runs **only under Extreme**. The twelve extras (`opt-...`) are never preset-gated: an explicit checkbox always wins, at any tier. This gating lives in the YAML itself, which means you can audit any single action's tier by opening the file that contains it.

| Tier | Gate in YAML | Runs under |
|---|---|---|
| Safe | *(no gate)* | Safe, Balanced, Extreme |
| Balanced | `option: '!preset-safe'` | Balanced, Extreme |
| Extreme | `option: 'preset-extreme'` | Extreme |
| Extra | `option: 'opt-...'` | Only when the checkbox is ticked (any preset) |

## The module × preset matrix

Legend: ✅ = applied · ➖ = not applied at this tier. "Extra" columns show the relevant opt-in checkbox name from the wizard, if any.

### Services (`ultraos/services.yml`, `tweaks/services/extreme-services.yml`)

| Action group | Safe | Balanced | Extreme | Trade-off notes |
|---|---|---|---|---|
| Core conservative set: OneSyncSvc, TrkWks, PcaSvc, diagnosticshub.standardcollector.service, wercplsupport, MapsBroker, lfsvc, RemoteRegistry, RetailDemo, Fax, WMPNetworkSvc | ➖ | ✅ | ✅ | Each service is annotated against Microsoft's own IoT/Server "safe to disable" guidance. OneSyncSvc off stops Mail/Calendar sync; PcaSvc off stops program-compatibility troubleshooting. (DiagTrack and the WER services are handled with the [privacy module](#privacy-telemetry-ads-and-ai-tweaksprivacyyml-7-files), not here.) |
| Extreme additions: WSearch disabled, SysMain (toggle, default keep), NDU, telemetry drivers, NetBT, GpuEnergyDrv | ➖ | ➖ | ✅ | **WSearch off disables Start-menu file search and Explorer content indexing** — the single biggest quality-of-life trade in Extreme. NDU disable can zero the Task Manager network column; GPU energy driver off slightly raises idle power draw |

The never-touch list — the update/servicing services (`wuauserv`, `UsoSvc`, `TrustedInstaller`, `DoSvc`), `Spooler`, `AudioSrv`, `Winmgmt`, `Schedule`, `profsvc`, `AppXSvc`, `SecurityHealthService`/`MDCoreSvc`, the networking stack and more — is enforced at validation time by `scripts/validate-playbook.py`, so no preset can disable them and pull requests that try fail CI. By design, the Xbox service stack is never touched either (Extreme removes the Xbox *apps*, with warnings — not the services Game Pass needs).

### Scheduled tasks (`tweaks/tasks/telemetry-tasks.yml`, `tweaks/tasks/maintenance-tasks.yml`)

| Action group | Safe | Balanced | Extreme | Trade-off notes |
|---|---|---|---|---|
| Pure telemetry tasks: CEIP, Appraiser, ProgramDataUpdater, QueueReporting, DiskDiagnostic, UsbCeip, Consolidator, Autochk/Chkdsk proxies | ✅ | ✅ | ✅ | Zero functionality loss; these tasks exist to collect and upload usage data |
| Maintenance/compat extras + UCPD velocity task disable | ➖ | ✅ | ✅ | Curated maintenance tasks that re-run telemetry setup or compatibility scans. `ignoreErrors: true` on tasks that may not exist on all editions |

### Debloat (`tweaks/debloat/appx-removals.yml`, `tweaks/debloat/edge-removal.yml`, `tweaks/debloat/reinstall-blockers.yml`)

| Action group | Safe | Balanced | Extreme | Trade-off notes |
|---|---|---|---|---|
| Dead/deprecated apps only (e.g. Cortana) | ✅ | ✅ | ✅ | Nothing of value is lost; these are functionally dead packages |
| Standard bloat catalog (Clips, Bing News/Weather/Search, Teams, Dev Home/Outlook auto-installs, Feedback Hub, etc.) | ➖ | ✅ | ✅ | Keeps Snipping Tool, Paint, Calculator, Photos, Notepad, Phone Link, Widgets, Xbox. Deprovision keys block re-provisioning for new users |
| Reinstall blockers (DevHome/Outlook OOBE schedulers, sponsored-app CloudContent switches) | ➖ | ✅ | ✅ | Stops Windows re-adding them at sign-in or during feature updates |
| Extreme additions: Widgets stack, Phone Link, Solitaire, Xbox family | ➖ | ➖ | ✅ | **Do not use Extreme on a Game Pass machine.** Xbox Identity Provider and TCUI are on the never-remove list at every tier, but the Xbox apps themselves go |
| Edge removal | `opt-uninstall-edge` (any preset) | | | Browser only — WebView2 runtime is kept (15+ apps depend on it). Read [TROUBLESHOOTING](TROUBLESHOOTING.md) first: Windows Update has known failure loops on some Edge-less systems |

### Privacy: telemetry, ads and AI (`tweaks/privacy/*.yml`, 7 files)

| Action group | Safe | Balanced | Extreme | Trade-off notes |
|---|---|---|---|---|
| Core consent denies: advertising ID, app diagnostics, activity history, location prompts, language-list opt-out, tailored experiences | ✅ | ✅ | ✅ | Pure Settings-page switches, exactly what you would click by hand |
| Recall off (policy) + Copilot button off | ✅ | ✅ | ✅ | Disables the feature; hardware is untouched |
| Telemetry services: DiagTrack (stop → disable + autologger off), WER/diagnostics-hub services | stop only | ✅ | ✅ | Full disable of the Connected User Experiences & Telemetry pipeline from Balanced up. Apps that rely on telemetry channels for licensing/updates are unaffected |
| Telemetry policies: `AllowTelemetry=0` (all paths), CEIP, feedback prompts, WER upload, cloud-content/Spotlight, settings sync, OneSettings | ➖ | ✅ | ✅ | On Home/Pro, `AllowTelemetry=0` is floored to "Required" by Microsoft — see the [FAQ](FAQ.md) for the honest version |
| App telemetry: NVIDIA, Office, PowerShell/.NET CLI opt-outs; Defender sample submission off | ➖ | ✅ | ✅ | Sample submission off means unknown files are not auto-uploaded (defense trade-off, noted in the report) |
| AI feature strip: Copilot app + CoreAI platform package removal, Recall enablement blocked (`AllowRecallEnablement=0`) | ➖ | ➖ | ✅ or `opt-strip-recall` | Extreme-tier privacy deep-clean; app removals are reinstallable from the Store |
| Extreme extras (MSA connection limits, presence-sensing force-deny, dmwappushservice) | ➖ | ➖ | ✅ | Highest trade-off rows from our research; each is individually commented in the YAML |

### Network (`tweaks/network/core.yml`, `tweaks/network/nic-config.yml`, `tweaks/network/extreme.yml`)

| Action group | Safe | Balanced | Extreme | Trade-off notes |
|---|---|---|---|---|
| LLMNR off, SMB anonymous-access restrictions, SMB bandwidth throttling off | ➖ | ✅ | ✅ | These are also security hardening (LLMNR spoofing, null-session enumeration). Safe leaves the network stack untouched |
| NIC power-saving properties (the five advanced-adapter keywords) | ➖ | ✅ | ✅ | NIC tweaks reduce latency-relevant power-saving; laptop battery impact is small but real |
| Experimental TCP stack: autotuning level, ECN, Nagle/TCPAck frequency, throttling index | ➖ | ➖ | ✅ | Atlas ships none of these; we keep them Extreme-only with warnings because they trade robustness for benchmark scores and can misbehave on odd routers |

### Performance (`tweaks/performance/input.yml`, `gaming.yml`, `system.yml`, `power.yml`, `extreme.yml`, `extras.yml`)

| Action group | Safe | Balanced | Extreme | Trade-off notes |
|---|---|---|---|---|
| Mouse acceleration off, MMCSS `SystemResponsiveness=10` (`input.yml`) | ✅ | ✅ | ✅ | The uncontroversial classics; Game Mode stays **on** by design. v1.1.0 made reality match this table: both actions were previously missing/mis-gated |
| GameDVR off (GameConfigStore + policy), background apps off, FTH off, service-host split (Xbox-excluded), Win32 priority separation, NTFS/8.3/battery counters, folder-discovery off, instant menus (`MenuShowDelay=0`) | ➖ | ✅ | ✅ | Service-host split trades a little RAM for fewer processes. **No pagefile disabling — rejected as a placebo**, with the reasoning in a source comment |
| Extreme: fullscreen optimizations off, MPO off, `GlobalTimerResolutionRequests`, MMCSS Games profile (Priority 6 / Games / SFIO High) | ➖ | ➖ | ✅ | MPO off fixes stutter on some setups and breaks frame pacing on others — a debug tool, not a free win. The MMCSS Games profile is the classic community set, honestly labeled anecdotal-but-harmless. No timer-hack binaries are bundled |
| Power scheme extras | `opt-max-performance` (Ultimate-Performance-derived scheme, EPP=performance) · `opt-disable-hibernation` (`powercfg /h off`) | | | Both are any-preset extras; see the warnings in [README](../README.md#opt-in-extras) |
| Tuning extras (`extras.yml`, `input.yml`) | `opt-disable-sysmain` · `opt-disable-search-indexing` · `opt-disable-memory-compression` · `opt-disable-hags` · `opt-disable-sticky-keys` | | | The four system switches mirror Extreme-tier changes as any-preset checkboxes with full trade-off notes; sticky-keys is a PowerShell-only write so it never leaks to future user profiles via `default-user.reg` |

### Visual & QoL (`tweaks/visual/*.yml`, `tweaks/qol/*.yml`)

| Action group | Safe | Balanced | Extreme | Trade-off notes |
|---|---|---|---|---|
| UltraOS folder + report shortcuts, OEM info | ✅ | ✅ | ✅ | Marks your System properties as an UltraOS machine and links the docs |
| Classic (Win10) context menu, taskbar cleanup (Chat/Widgets/Task View buttons, search icon config), Explorer defaults (This PC view, extensions visible, recommendations off, Gallery off) | ➖ | ✅ | ✅ | Pure preference changes; each is reversible via the revert data. No forced taskbar alignment |
| Extreme visuals: transparency off, animations minimized, dynamic lighting off, Settings banners (build-gated) | ➖ | ➖ | ✅ | Frees a little GPU/CPU on weak hardware; makes Windows look flatter |
| Update mode policy (notify-only) | `wu-notify` (any preset) | | | Policy-based notify-only; never a full disable. Switchable later in the folder |

### Security (`tweaks/security/defender-*.yml`, `mitigations.yml`, `vbs.yml`)

| Action group | Gate | Trade-off notes |
|---|---|---|
| **Defender re-enable** (undo the install-time toggled-off state, restore service defaults, clean policies) | default (`!opt-disable-defender`) — runs **last** among modules | The whole reason the install is safe: unless you opt out, Defender comes back on |
| Defender keep-off (double-write `DisableAntiSpyware` policy pattern, 2026-gpupdate-proof) | `opt-disable-defender` | The double-write works around a January 2026 security-update behavior where `gpupdate` strips single policy writes. Folder toggle ships regardless |
| CPU mitigations off (Spectre/Meltdown family overrides, CFG, SEHOP) | `opt-disable-mitigations` | Includes the Valorant CFG re-enable exception pattern (see the [FAQ](FAQ.md)). Older CPUs only |
| Core Isolation/VBS off (HVCI, incl. the 24H2+ forced-value pattern) | `opt-disable-vbs` | Breaks Vanguard/FACEIT, WSL2, Docker, Hyper-V. Never preset-gated |

**By default — under every preset — Defender stays enabled, VBS/HVCI stays on, CPU mitigations stay on, and Windows Update stays enabled.** The security-reducing changes are exclusively opt-in checkboxes with wizard-visible warnings.

## Skipping a module

Module inclusion is controlled in **one place**: the pipeline file `src/playbook/Configuration/main.yml`. Each module is a small block of `!task:` include lines with a comment marking it, in exactly this shape (excerpt from the real file):

```yaml
  # MODULE: services
  - !writeStatus: {status: 'Configuring services'}
  - !task: {path: 'ultraos\services.yml'}
  - !task: {path: 'tweaks\services\extreme-services.yml'}

  # MODULE: debloat
  - !writeStatus: {status: 'Removing bloatware'}
  - !task: {path: 'tweaks\debloat\appx-removals.yml'}
  - !task: {path: 'tweaks\debloat\reinstall-blockers.yml'}
  - !task: {path: 'tweaks\debloat\edge-removal.yml'}
```

To skip a module entirely, comment out (or delete) that module's `!task:` line(s) in `main.yml`, then rebuild the playbook (see [CONTRIBUTING.md](../CONTRIBUTING.md)). For example, to run UltraOS without any debloat, comment out the three `tweaks\debloat\...` lines. Two rules to keep in mind when doing this: keep the pipeline's overall order intact, because later modules assume earlier ones ran (backups happen before any module, and Defender handling must stay last); and run `scripts/validate-playbook.py` after editing, since it catches broken include paths and option mismatches before you ever see them at install time. You can skip individual files within a module the same way — e.g. drop `tweaks\visual\context-menu.yml` alone if the classic context menu isn't for you.

*Related: [docs/FAQ.md](FAQ.md) explains the reasoning (and the rejected placebos) behind these matrices.*
