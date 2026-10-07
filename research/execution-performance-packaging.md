# UltraOS Dossier — Execution Model, Performance Blueprint & Packaging Pipeline

Agent: T1-j (speed & packaging) | Compiled: 2026-10-07 | License context: UltraOS is GPL-3.0; engine facts below are from MIT-licensed upstream code (quotable).

Primary sources (accessed 2026-10-07):
- Engine source: `/home/z/my-project/repos/trusted-uninstaller-cli` (clone of https://github.com/Ameliorated-LLC/trusted-uninstaller-cli, MIT)
- ame-assassin source: `/home/z/my-project/repos/ame-assassin` (clone of https://github.com/Ameliorated-LLC/ame-assassin)
- Atlas playbook source: `/home/z/my-project/repos/atlas` (clone of https://github.com/Atlas-OS/Atlas)
- Docs: https://docs.amelabs.net (creation/packaging, actions, tasks, removing-upgrading pages)

---

## 1. EXECUTION MODEL (how AME Wizard runs a playbook)

Verified from `TrustedUninstaller.Shared/AmeliorationUtil.cs` (the engine core AME Wizard uses — "Core functionality used by AME Wizard", README.md).

### 1.1 Parse → flat action list → strictly sequential interpreter
1. Entry: engine reads `playbook.conf` (XML) via `XmlSerializer`, then `ParseActions(...)` starts at `Configuration\custom.yml` (fallback `main.yml`):
   ```csharp
   // AmeliorationUtil.cs:775-777
   List<ITaskAction> actions = ParseActions($"{Playbook.Path}\\Configuration", isoBuild, isoUpdateBuild, isoArch, Playbook.Options,
       File.Exists($"{Playbook.Path}\\Configuration\\main.yml") ? "main.yml" : "custom.yml", upgradingFrom);
   ```
   `!task` actions are recursively inlined (AmeliorationUtil.cs:159-196), producing ONE flat `List<ITaskAction>` in file order. **There is no compiler, no dependency graph, no priority scheduling** — a `Priority` property exists on the YAML task schema (`UninstallTask.cs:32: public int Priority { get; set; } = 1;`) but is **never referenced** anywhere in the engine (repo-wide grep) — order = author order, period.
2. Gating happens at PARSE time (AmeliorationUtil.cs:115-157): tasks/actions with non-matching `option`/`options`/`builds`/`cpuArch`/`onUpgrade`/`iso`/`oobe` are dropped **before execution** — a "no-op skip" that is free at run time, but only at whole-action granularity (conditionals inside scripts still cost run time).
3. Execution loop — `DoActions` (AmeliorationUtil.cs:294-424) is a **plain sequential `foreach`**:
   ```csharp
   // AmeliorationUtil.cs:297-298
   foreach (ITaskAction action in actions)
   {
       var actionName = action.GetType().ToString().Split('.').Last();
   ```
   with a per-action retry `do { … } while (i < 10)` loop; on exception it sleeps `Thread.Sleep(300)` + `Thread.Sleep(50)` per retry (lines 372-375) and retries up to 10 times. Each action also gets a fresh `Output.OutputWriter` opened against `logFolder\Output.txt` + `logFolder\Log.yml` (line 300) — per-action file-writer setup cost.

### 1.2 Process spawning — every "processy" action = one new OS process
- **`!powerShell`** spawns a NEW `PowerShell.exe` (Windows PowerShell 5.1) per action (PowershellAction.cs:94-95):
  ```csharp
  FileName = "PowerShell.exe",
  Arguments = $@"-NoP -ExecutionPolicy Bypass -NonInteractive -C ""{Command}""",
  ```
- **`!cmd`** spawns a NEW `cmd.exe /C` per action (CmdAction.cs:95-96).
- **`!run`** spawns a NEW process per action (RunAction.cs).
- **`!appx`** spawns a NEW `ame-assassin.exe` per package (AppxAction.cs:192-193):
  ```csharp
  Arguments = $@"-{Type.ToString()} ""{Name}""" + verboseArg + unregisterArg + kernelDriverArg,
  FileName = Directory.GetCurrentDirectory() + "\\ame-assassin\\ame-assassin.exe",
  ```
- **`!service`** (Change op) is just a registry write via `RegistryValueAction` on `HKLM\SYSTEM\CurrentControlSet\Services\<name>` (ServiceAction.cs:163-176) — cheap; but `GetService()` enumerates ALL system services per action (ServiceAction.cs:71-72 `ServiceController.GetServices().FirstOrDefault(...)`) and every service action ends with `await Task.Delay(100)` (ServiceAction.cs:497). Stop/Delete ops can additionally spawn ProcessHacker (`-s -elevate -c -ctype service …`) when the kernel-driver path is on (Atlas sets `UseKernelDriver=false`).

### 1.3 What ame-assassin actually does (the `!appx` backend)
From `ame-assassin/Program.cs`: it **bypasses DISM/TiWorker entirely** and edits the AppX state SQLite databases directly:
```csharp
// Program.cs:1480,1487-1489
Hook($@"{Environment.GetEnvironmentVariable("PROGRAMDATA")}\Microsoft\Windows\AppRepository\StateRepository-Machine.srd");
Console.WriteLine("\r\nDropping triggers...");
Triggers.Save();
Triggers.Drop();
```
Per invocation it hooks the DB, saves+drops all triggers, runs its transaction, then restores triggers (also hooks `StateRepository-Deployment.srd`, line 1651). It accepts **exactly ONE package filter per invocation** (`Assassin.PackageFilterList.Add(args[1])`, Program.cs:1528). Repo tagline: "Specialized tool for removing APPX packages bypassing DISM, as well as for removing system components."

### 1.4 TiWorker / CBS dependencies (where they actually appear)
- The engine itself never mentions TiWorker (repo grep = 0 hits). CBS/TiWorker is only reached via:
  - **`!run` of DISM.exe** (Atlas: DirectPlay enable, capability removal, `/StartComponentCleanup` — start.yml) and
  - **`Add-WindowsPackage -Online`** in Atlas's `packageInstall.ps1:320` (`Add-WindowsPackage -Online -PackagePath $cabPath -NoRestart -IgnoreCheck -LogLevel 1`) — CBS queues these through TrustedInstaller/TiWorker servicing; this is the slowest class of operation in any playbook (weights 30–50 in Atlas YAML reflect that).
  - Defender removal path additionally reboots through the wizard's system-prep stage.
- `!software` (engine) uses **Chocolatey**: installs chocolatey itself if missing, then `choco install -y --allow-empty-checksums` (SoftwareAction.cs:122-127) — network + choco bootstrap cost; Atlas deliberately avoids it (see §2.4).

### 1.5 Where reboots come from
1. **Wizard/CLI system preparation** (Defender requirements): `CLI.cs:133-135` runs `"timeout /t 1 & shutdown /r /t 0"` after `PrepareSystemCLI` when DefenderDisable/UCPD prep is required — i.e., only for playbooks whose `playbook.conf` declares those Requirements.
2. **packageInstall.ps1 safe-mode fallback** (Atlas): `shutdown /f /r /t 0` (line 77) — only on failed CBS packages, interactive path; with `-NoInteraction` it schedules a logon message task instead (lines 103-122).
3. **No reboot commands exist in Atlas's Configuration YAML** (verified by grep — only cosmetic tweak names match "shutdown"). DISM calls all use `/NoRestart`.
4. ISO/OOBE mode reboots are separate flows (not used in a live run).

### 1.6 Runtime cost structure of one playbook run (Atlas-shaped)
Per action: engine overhead (writer setup, status query, progress accounting) is ~ms — negligible. The REAL costs, in order:
1. CBS/DISM operations (TiWorker) — tens of seconds to minutes each.
2. Network downloads (software, browsers, FXPSYaml module install at run time!).
3. Process spawn × ~150: 53× PowerShell.exe + 22× cmd.exe + 29× !run + 42× ame-assassin.exe (+ cleanmgr, installers, ngen loop).
4. Per-package ame-assassin trigger drop/restore cycle × 42.
5. Service enumeration + 100ms delay per `!service`; 5s stop-timeouts where services resist.
6. reg load/unload + full-YAML re-parse of the tweaks tree in APPLYDUHIVE.ps1.

---

## 2. ATLAS PLAYBOOK WEIGHT ANALYSIS

Counted on `/home/z/my-project/repos/atlas/src/playbook` (v0.5.0, commit as cloned 2026-10-07).

### 2.1 Inventory
| Metric | Count (rg-verified) |
|---|---|
| Configuration yml files | **196** |
| Total action entries (`- !…`) across tree | **812** |
| `!task` links (file inclusion) | 187 |
| `!registryValue` | 410 |
| `!registryKey` | 37 |
| `!powerShell` | **53** (38 reference `.ps1` scripts) |
| `!run` | 29 (DISM ×4, FILEASSOC.cmd ×5, wevtutil ×3, w32tm ×3, explorer ×3, lodctr ×2, fsutil ×2, bcdedit ×2, winmgmt, rundll32, powercfg, netsh, ONED.cmd) |
| `!cmd` | 22 |
| `!appx` | **42** (39 removals + 3 clearCache) |
| `!service` | 13 (mostly cheap `change` ops) |
| `!scheduledTask` | 8, `!taskKill` 7, `!writeStatus` 36 |
| Option-gated actions (`option:`/`options:`) | ~40 |
| `.ps1` files in Executables | 32 |
| `.cab` packages (AtlasModules/Packages) | 4 (NoDefender + NoTelemetry × amd64/arm64, built by sxsc from `src/sxsc/*.yaml` component lists) |
| PowerShell.exe spawns per default run | ~53 |
| ame-assassin.exe spawns | ~42 |
| `EstimatedMinutes` | **15** (playbook.conf:36) |

### 2.2 Heavyweight steps (by YAML weight + nature)
- `start.yml` — 3× DISM: `/Enable-Feature DirectPlay` (weight 30), `/Remove-Capability App.StepsRecorder` (30), **`/Cleanup-Image /StartComponentCleanup` (weight 50)** — the single most expensive live step class.
- `SOFTWARE.ps1` — network installs of 7-Zip/VC++/DirectX (weight **150**), browsers (weight **120** each, curl + silent installers), Toolbox (100). Direct downloads, deliberately NOT chocolatey ("Software is no longer installed with a package manager anymore to be as fast and as reliable as possible", SOFTWARE.ps1:11-13).
- `components.yml` — `RemoveEdge.ps1` (Edge teardown, option-gated) + `packageInstall.ps1` CBS cab installs for defender-disable option (`Add-WindowsPackage` × 2 cabs → TiWorker).
- `appx.yml` — 39 `!appx` removals = 39 ame-assassin spawns, each doing the StateRepository hook + trigger drop/restore; plus 2 PowerShell passes to snapshot/diff `Get-AppxPackage` for deprovisioning.
- `APPLYDUHIVE.ps1` — **installs a PowerShell module from the internet at run time**:
  ```powershell
  # APPLYDUHIVE.ps1:2-7
  $module = Get-Module -Name "FXPSYaml"
  if (!$module) {
      Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
      Install-Module -Name FXPSYaml -Force
      Import-Module -Name FXPSYaml
  }
  ```
  then re-parses the ENTIRE tweaks YAML tree (196 files) at run time to find HKCU paths and mirror them into the loaded default-user hive. Pure run-time work that is 100% knowable at build time.
- `CLEANUP.ps1` — cleanmgr `/sagerun:64` + temp purges + **`vssadmin delete shadows /all /quiet`** (see §5).
- `NGEN.ps1` — runs `ngen install` per loaded assembly in a loop (smart: pre-JITs PS so the ~50 subsequent PowerShell spawns start faster — keep this trick).
- `services.yml` — BACKUP.ps1 export + `!service change` × ~12 + 3 ScriptWrapper PS calls + 2 .cmd calls.
- `custom.yml` — hive load/unload, STOPFOLDERPROC, file copies, DISABLENOTIFS, explorer kill/restart, DEFAULT.reg bulk import (the one place Atlas already batches registry).

### 2.3 What "EstimatedMinutes = 15" implies
It is display metadata only (playbook.conf), shown by the wizard; real duration is dominated by §2.2. To beat Atlas, UltraOS must attack: DISM StartComponentCleanup (make optional/post-run), run-time FXPSYaml install (move to build), 95 process spawns (batch), serialized network installs (parallelize), 42 ame-assassin cycles (single-host loop), and cleanmgr (fire-and-forget). §3 is that plan.

### 2.4 Slow spots a faster design avoids (concrete)
1. Run-time PowerShell-gallery roundtrips (NuGet provider + FXPSYaml) — eliminate via build-time precomputation.
2. Re-parsing 196 YAML files at run time — build-time.
3. 42 sequential ame-assassin.exe spawns — single PS orchestrator loop (still one assassin call per family — engine accepts one filter per invocation).
4. 53 PowerShell.exe cold starts — collapse into ~8 orchestrator scripts (keep NGEN first, as Atlas does, so even those are faster).
5. Serial downloads — Start-Job fan-out inside one orchestrator.
6. StartComponentCleanup in the critical path — demote to optional post-run action.
7. Chocolatey (`!software` engine path) — never use it.

---

## 3. SPEED BLUEBOOK — numbered techniques (feasibility from engine source, expected impact, risk)

**S1. Batch registry writes into generated `.reg` imports** — FEASIBILITY: HIGH. Engine evidence: Atlas already ships `Executables/DEFAULT.reg` applied via `!cmd: reg import .\DEFAULT.reg` (default.yml:7-10) — the pattern works and CmdAction completes on exit code 0. Plan: at BUILD time, compile the ~410 `!registryValue`/37 `!registryKey` actions into per-hive, per-module `.reg` files (HKLM.reg, HKCU.reg, HKCR.reg, per module: `net.reg`, `privacy.reg`, …); at RUN time ~10 `reg import` calls replace 447 engine actions. Impact: removes 447× (writer setup + status check) overhead and, more importantly, makes progress/status coarser-but-honest; registry write throughput itself is similar, but engine bookkeeping and log spam drop massively. Risk: (a) HKCU must run as `currentUserElevated` (same as Atlas); (b) coarser failure granularity — mitigate with `handleExitCodes: {"!0": Retry}` and per-module split; (c) keep `!registryValue` for the FEW values needing `operation: set`-if-exists semantics or dynamic data (build-time compiler must leave those inline). RegistryValueAction `Set` op semantics: "skip the action if the specified value does not already exist" (Core/Actions/RegistryValueAction.cs:22-23).

**S2. Single-PowerShell-host orchestrator pattern** — FEASIBILITY: HIGH (playbook-level; the engine has NO persistent host — each `!powerShell` = new PowerShell.exe, PowershellAction.cs:94-95). Plan: replace Atlas's ~15 scattered `!powerShell` calls per phase with ONE `UltraOS-<phase>.ps1` per phase (prepare / registry / appx / services / software / finalize). Keep `!status` (`!writeStatus`) actions before each to preserve wizard status text. Impact: ~53 PS spawns → ~8; PS 5.1 cold start is ~0.5–1.5 s per spawn (⚠️ estimate — cannot benchmark Windows in this sandbox; NGEN first, like Atlas NGEN.ps1, cuts this further). Risk: coarser error isolation — use `$ErrorActionPreference='Stop'`, structured try/catch with per-step exit codes, and `handleExitCodes` maps; one bad step must not kill a whole phase (emit step-level failure records to the manifest, continue, and surface in the post-run report).

**S3. Parallelize independent operations** — FEASIBILITY: MEDIUM, engine-quirk-aware.
- Engine-level parallelism: **none**. `DoActions` is a sequential foreach (AmeliorationUtil.cs:297); no `Task.WhenAll` over actions; `Priority` unused. ⚠️ AME Wizard's closed-source front-end may add scheduling, but the OSS engine that executes actions does not — design for sequential.
- BUT three real parallel hooks exist:
  (a) **`!run` with `wait: false` is safe fire-and-forget** — RunAction.cs:131: `return HasExited || !Wait ? UninstallTaskStatus.Completed : UninstallTaskStatus.ToDo;` → engine marks complete and moves on. Use for cleanmgr, background downloads, detached installers (Atlas already does exactly this for explorer: `!run: { exe: "explorer.exe", runas: "currentUser", wait: false }`, custom.yml:54).
  (b) **`!cmd`/`!powerShell` with `wait: false` is a TRAP** — their GetStatus is `ExitCode == null ? ToDo : Completed` (CmdAction.cs:81) and ExitCode is never set when `!Wait` returns early → the retry loop **re-runs the action up to 10 times** (DoActions do/while i<10), spawning up to 10 detached processes. NEVER use `wait:false` on !cmd/!powerShell; wrap fire-and-forget in `!run` of a script/cmd instead.
  (c) **Inside one PS orchestrator**, PS 5.1 supports `Start-Job`/runspaces — use for parallel downloads (browser + runtimes + 7-Zip), parallel registry `.reg` generation, parallel file copies. Impact: wall-clock = max(download) instead of sum; on typical 100 Mbps links saves tens of seconds (⚠️ estimate). Risk: jobs surviving past playbook end (wizard may prompt reboot while a job still writes) — always `Wait-Job`/join before finalize phase; CBS/DISM/appx-servicing must remain serialized (CBS global lock; ame-assassin assumes exclusive StateRepository access — it drops triggers).

**S4. Minimize TiWorker/CBS syncs** — FEASIBILITY: HIGH.
- Atlas's 3 DISM calls + 2 cab `Add-WindowsPackage` are already separate serial CBS transactions; CBS serializes internally, so merging DISM flags into fewer invocations saves process+log overhead but not servicing time.
- The big win is REMOVING work: demote `/StartComponentCleanup` (weight 50) to an optional post-run action (or Extreme preset only). Impact: typically minutes (⚠️ commonly 1–5+ min on updated installs — estimate, hardware-dependent). Risk: leaves WinSxS redundancy on disk (a space/cleanliness tradeoff — document it; offer "Deep Clean" as a post-run Toolbox action).
- Keep `-NoRestart` on every servicing call (Atlas does) so CBS defers reboot requirements to one user-chosen restart.
- Deprovisioned-package keys: Atlas computes them at run time via a before/after `Get-AppxPackage` diff (appx.yml:82-89). UltraOS can precompute the STATIC known-bloat list at build time into a `.reg` and keep only a small dynamic diff for anything else → fewer PS passes.

**S5. Fewer / zero automatic reboots** — FEASIBILITY: HIGH.
- Verified: NO reboot commands in Atlas's Configuration YAML; reboots come only from (a) wizard-level Defender/UCPD system-prep (CLI.cs:135) and (b) packageInstall's interactive safe-mode fallback (packageInstall.ps1:77). 
- UltraOS plan: default presets do NOT require DefenderDisabled/UCPDDisabled prep (Atlas's own default is `defender-enable`), all servicing `/NoRestart`, single "restart recommended" end prompt via the report. Offline registry: the only offline-hive work in Atlas is the default-user hive (`reg load HKU\AME_UserHive_Default`, custom.yml:7) — keep ONE load/apply/unload cycle, fed by build-time-generated `.reg` instead of run-time YAML re-parse (see S7). Impact: avoids the 1 automatic reboot of the Defender path for default users and all mid-run restarts. Risk: some CBS operations (defender-disable cabs) genuinely need a restart to finish — keep those option-gated and document.

**S6. Skip no-op work (conditional tweaks, preset gates, idempotency)** — FEASIBILITY: HIGH.
- Engine gives free parse-time gating on `option/options/builds/cpuArch/onUpgrade/iso/oobe` (AmeliorationUtil.cs:115-157) — UltraOS maps Safe/Balanced/Extreme presets to options so unselected work is never even parsed.
- Add run-time guards inside orchestrators: read the UltraOS state key (`HKLM\SOFTWARE\UltraOS\State\<module>`) and skip already-applied modules (fast repair/re-apply and upgrade flows; also drives the report's "skipped" section). 
- Atlas precedent for gating-by-state: every AtlasDesktop `.cmd` writes `HKLM\SOFTWARE\AtlasOS\Services\<name>\state` before acting (e.g., Disable System Restore.cmd).
- Risk: state keys must be written transactionally with the change; wrong flags = skipped work. Mitigate: state key written by the same orchestrator step that applies the module, after success.

**S7. Move logic from run time to BUILD time** — FEASIBILITY: HIGH (this is UltraOS's structural advantage).
- (a) **Kill APPLYDUHIVE's run-time YAML parse + FXPSYaml gallery install**: our build (python, this box) parses the tweak YAML, extracts every HKCU path, and emits `Executables/Hive-DefaultUser.reg` + a tiny `reg load / reg import / reg unload` action sequence. Removes run-time internet dependency #1. 
- (b) Bake the deprovision key list (S4).
- (c) OEM/version stamping at build (Atlas does this in local-build.ps1's temp-copy step — reimplement in our builder).
- (d) Validate at build: every `!task` path exists, every action tag is in the engine's allowlist, every `option:` exists in playbook.conf FeaturePages — the engine only discovers missing files AT RUN TIME (`throw new FileNotFoundException("Could not find YAML file: " + taskTaskAction.Path)`, AmeliorationUtil.cs:161-162); build-time validation prevents a dead playbook.
- (e) Pre-generate inverse (rollback) data (see §5) — inverse registry from the same source of truth.
- Impact: removes FXPSYaml (NuGet+gallery roundtrips, 15–60 s+ ⚠️ estimate), removes 196-file run-time parse, removes a whole class of run-time failures. Risk: build output must stay byte-stable across presets — version the generated artifacts and diff them in CI.

**S8. Honest progress weights** — `weight` per action drives the wizard's bar (docs: actions page "Optional Parameters"); Atlas sets DISM=30–50, software=100–150 vs default 1–5. UltraOS orchestrators must declare phase-accurate weights (they're the only UX signal since batching collapses 800 actions into ~40). Zero wall-clock effect, big perceived-speed effect.

**S9. Never use `!software` (chocolatey)** — engine bootstrap-installs chocolatey then `choco install` (SoftwareAction.cs:122-127). Use direct downloads (Atlas SOFTWARE.ps1 pattern) with S3(c) parallelism and pinned URLs, or ship the installers inside the .apbx for offline-capable Essential preset (apbx is already a 7z/zip — size tradeoff).

**S10. Reduce explorer/session churn** — Atlas kills explorer twice (custom.yml taskKill + a second restart flow) and runs STOPFOLDERPROC; UltraOS: kill explorer ONCE at the start of the shell-affecting phase, apply everything, restart once at finalize (`!run explorer.exe wait:false`). Minor (~seconds) but improves perceived stability.

**Net effect estimate** (⚠️ estimate only — no Windows benchmark possible in this sandbox): Atlas 15 min → UltraOS default ~8–10 min, primarily S4 (skip StartComponentCleanup), S7 (no FXPSYaml), S2/S1 (spawn collapse), S3 (parallel downloads). State these as targets, not measurements, until T3 benchmarks on real hardware.

---

## 4. PACKAGING PIPELINE — exact .apbx assembly + Linux build spec

### 4.1 How Atlas builds (verbatim mechanics of `src/dependencies/local-build.ps1`)
- Flags: `-AddLiveLog`, `-ReplaceOldPlaybook`, `-DontOpenPbLocation`, `-NoPassword`, `-Removals [Dependencies|Requirements|WinverRequirement|Verification]`, `-FileName`. 
  - `-Removals` strips playbook.conf lines (`<Requirement>`, `<string>`/`<SupportedBuilds>` for Winver, `<ProductCode>` for Verification) in a TEMP COPY so test builds skip checks.
  - `-AddLiveLog` copies `Configuration/custom.yml` to temp and **injects as the FIRST action**:
    ```
    - !cmd: {command: 'start "AME Wizard Live Log" PowerShell -NoP -C "<liveLogText>"'}
    ```
    where liveLogText tails the newest wizard log:
    ```powershell
    # local-build.ps1:131-136
    $a = Join-Path (Get-ChildItem (Join-Path $([Environment]::GetFolderPath('CommonApplicationData')) '\AME\Logs') -Directory |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1).FullName '\OutputBuffer.txt';
    while ($true) { Get-Content -Wait -LiteralPath $a -EA 0 | Write-Output; Start-Sleep 1 }
    ```
  - Version stamping: replaces `AtlasVersionUndefined` in `tweaks\misc\config-oem-information.yml` with the conf Version (dev suffix if Title matches `(dev)`).
- Zip: excludes `local-build.*`, `*.apbx`, plus the ORIGINALS of any temp-modified files, then:
  ```powershell
  # local-build.ps1:208-214
  if (!$NoPassword) { $pass = '-pmalte' }
  & $7zPath a -spf -y -mx1 $pass -tzip "$apbxPath" `@"$files" | Out-Null
  # add edited files
  if (Test-Path $(Separator "$playbookTemp\*")) {
      Push-Location "$playbookTemp"
      & $7zPath u $pass "$apbxPath" * | Out-Null
      Pop-Location
  }
  ```
  i.e., **-tzip, password `malte`, ZipCrypto (7-zip default for zip), -mx1 fastest**; modified files are overlaid with `7z u`.
- `build-playbook.cmd` / `build-playbook.sh` (verbatim): both just call `local-build.ps1 -AddLiveLog -ReplaceOldPlaybook -Removals WinverRequirement, Verification -DontOpenPbLocation` via powershell / pwsh.
- CI (`.github/workflows/apbx.yaml`): runs-on **windows-latest**; `yamllint -d "{extends: relaxed, rules: {empty-lines: disable, line-length: disable, new-line-at-end-of-file: disable, trailing-spaces: disable, new-lines: {type: platform}}}" .`; sxsc CAB rebuild only when `src/sxsc/*.yaml` change (make-cert + `python sxsc.py` + start-build.ps1, cabs committed back); final artifact: `local-build.ps1 -ReplaceOldPlaybook -AddLiveLog -Removals Verification, WinverRequirement -FileName "Atlas Playbook <sha8>"` moved into `src/release-zip/` and uploaded. Release zip extras (repo files): `Read the Install Guide First!.url`, `Disable Automatic Driver Installation.reg`.
- Docs say packaging may be 7z format with password malte (docs.amelabs.net packaging page); Atlas production ships `-tzip` — **both formats are wizard-compatible** (wizard extracts with 7-zip using `malte`).

### 4.2 Verified Linux toolchain on THIS box (2026-10-07)
- `zip` 3.0 at /usr/bin/zip — **password zip works**: built `ultraos-test.apbx` with `zip -P malte -r -X .`, verified encrypted entries (`flag_bits=0x9`, `encrypted=True` via python zipfile) and round-tripped with `unzip -P malte`. This produces the same ZipCrypto container class as `7z a -tzip -pmalte`.
- `unzip`, `python3` 3.12.14, `git`, `curl`, `node` v24 present. **No 7z/7za on box.**
- `yamllint` — was absent; installed via `pip install --user --break-system-packages yamllint` → **1.38.0** (+ PyYAML 6.0.3). Verified: `yamllint -d "<Atlas relaxed config>" src/playbook/Configuration` on the Atlas tree → **exit 0**.
- Python `zipfile` can read but not WRITE encrypted zips (no pyzipper) → use system `zip -P malte`; fallback if `zip` missing: `7z a -tzip -pmalte` when available (CI ubuntu runners have neither by default → `apt-get install zip` or use a container).

### 4.3 UltraOS build script spec (Linux-native, `scripts/build.sh` + `scripts/build.py`)
1. **Stage** `src/playbook/` → `build/staging/` with exclusions: `.git*`, `*.apbx`, `build/`, dev files.
2. **Transform at build** (python): (a) inject LiveLog first-action into `Configuration/custom.yml` (copy of Atlas's, quoted above); (b) OEM version stamp from `playbook.conf` Version; (c) generate `Executables/Generated/*.reg` from tweak YAML (S1/S7a: per-hive batches + `Hive-DefaultUser.reg`); (d) generate `undo/` inverse registry + manifest template (§5); (e) optional `-Removals`-style conf stripping for dev builds (`--dev` flag drops ProductCode/SupportedBuilds like Atlas).
3. **Validate**: yamllint (relaxed config, same string as Atlas CI) + structural checks (PyYAML): every action tag ∈ allowlist {run, registryKey, registryValue, appx, file, service, scheduledTask, taskKill, systemPackage, cmd, powerShell, download, software, writeStatus, task}; every `!task` path resolves; every `option:`/`options:` value exists in playbook.conf FeaturePages; per-file `title:` present (docs require it). Fail build on any error — the engine would only fail at run time (FileNotFoundException path, AmeliorationUtil.cs:161-162).
4. **Package**: `cd build/staging && zip -P malte -r -X "../UltraOS-v<version>.apbx" .` (add `-mx1`-equivalent: zip's default deflate is fine at these sizes; if 7z detected prefer `7z a -tzip -pmalte -mx1`).
5. **Release zip**: `UltraOS-v<ver>.apbx` + `README.url` (install guide) + `Disable Automatic Driver Updates.reg` (optional QoL) → `UltraOS-Playbook-v<ver>.zip` (unencrypted, like Atlas's release-zip).
6. **CI (GitHub Actions, ubuntu-latest)**: `pip install yamllint`; `apt-get install -y zip` (or use `ejkim1997`-style 7zip action); run build; upload artifact. No Windows runner needed **unless** we adopt sxsc cab packages (component-level removal) — then mirror Atlas's windows-latest sxsc job or commit prebuilt cabs (Atlas commits cabs into the repo and regenerates only on sxsc yaml change — same strategy works for us).
7. Reproducibility: emit `build/manifest.sha256` of staging inputs + generated files so CI can diff generated artifacts between runs.

---

## 5. ROLLBACK ENGINEERING

### 5.1 Ground truth
- **AME Wizard does NOT auto-create a restore point** — no restore-point code exists in the engine (repo grep for restorepoint/checkpoint/systemrestore/vssadmin = 0 relevant hits) and docs never mention one. ⚠️ UNVERIFIED for the closed-source wizard UI, but the engine that would run it has none, and Atlas's own troubleshooting page assumes manual recovery.
- Docs (Removing / Upgrading, accessed 2026-10-07): "Currently, AME Beta lacks a standardized way to uninstall playbooks once applied… Universal playbook reversibility is currently under heavy development and is a confirmed feature for future releases before AME v.1.0." Privacy+'s own "uninstall" = **in-place upgrade with an ISO** (repair install).
- Atlas actively **deletes all restore points & shadow copies** (CLEANUP.ps1:100-104):
  ```
  # Delete all system restore points
  # This is so that users can't attempt to revert from Atlas to stock with Restore Points
  # It won't work, a full Windows reinstall is required ^
  vssadmin delete shadows /all /quiet
  ```
  and disables System Restore by policy (`DisableSR=1`, Disable System Restore.cmd). Their position: component-level (cab) removal cannot be reverted by restore points.
- Atlas's ACTUAL rollback primitives: `BACKUP.ps1` exports every service's `Start` value to `%WINDIR%\AtlasModules\Other\winServices.reg` (UTF-8 no BOM, plain `reg add`-compatible .reg) before services.yml runs; "Set services to defaults.cmd" re-enables all "(default)" service toggles; `revert.yml` (atlas/revert.yml) is ONLY an upgrade-time cleaner for past-version leftovers (`onUpgrade: true`, 14 `operation: delete` registry values — NOT a general undo).
- Engine post-run bookkeeping (useful for us): `WriteAppliedPlaybook` records Name/Version/SelectedOptions/ErrorLevel under `HKLM\SOFTWARE\AME\Playbooks\Applied\{UniqueId}` and `%ProgramData%\AME\AppliedPlaybooks\` (AmeliorationUtil.cs:1159-1200) — this is what powers `onUpgrade`/`previousOption` gating.

### 5.2 UltraOS undo design (layered)
- **L0 — System Restore point (optional, first action, Safe default ON)**: enable protection if needed (`Enable-ComputerRestore -Drive "$env:SystemDrive\"`), then `Checkpoint-Computer -Description "UltraOS pre-install" -RestorePointType MODIFY_SETTINGS`. Caveats (documented, Microsoft-documented behavior): requires System Protection on the OS drive (else silently skipped — CHECK and report if skipped); capped frequency (24h default checkpoint throttle via SystemRestorePointCreationFrequency ⚠️ verify registry override at build); takes ~10–60 s; reverts registry/services/tasks/drivers state but does NOT restore removed AppX packages (StateRepository in ProgramData is not monitored by default) nor removed CBS components — partial by design. **UltraOS must NOT run Atlas's `vssadmin delete shadows`.**
- **L1 — Pre-change exports (cheap, always on)**: services `Start` .reg (BACKUP.ps1 pattern, verbatim technique); scheduled tasks XML export per modified task; `Get-AppxPackage` list snapshot; export of every registry key we modify (build-time compiler knows the exact key list → generate one `reg export` script). Stored in `%ProgramData%\UltraOS\Backup\<timestamp>\`.
- **L2 — Build-time inverse registry**: the same build step that compiles tweaks → `.reg` (S1) also emits `undo/<module>.reg` with the INVERSE of every Add (Deletes for added values/keys) — trivially derivable from the tweak source; dynamic/unknown old-values are captured at run time by the orchestrator (old value read before Set, appended to the manifest).
- **L3 — "Undo UltraOS" playbook**: ship `undo/` inside the .apbx and extract to `%WINDIR%\UltraModules\Undo\`; a small generated `undo-manifest.json` (module, options selected, timestamp, per-module inverse ops, appx list snapshot) drives a separate `UltraOS-Undo.apbx` (built alongside) or a desktop "Undo UltraOS" shortcut that runs the inverse: reg import inverses, restore service Starts, restore scheduled tasks, restore deprovision keys, re-register reinstallable AppX from Store, restart explorer. Irreversible ops (defender cabs, Edge teardown) are explicitly listed as "not undoable — restore point/repair-install only" in the report.
- **Honesty requirement**: the post-run report (§6) must show a per-module undoability flag. This beats both Atlas (no undo story; deletes restore points) and Revi (⚠️ no verified per-module revert system — not researched here).

---

## 6. LIVE LOG & POST-RUN REPORT HOOKS

### 6.1 What exists
- Engine per-action logging: every action writes through `Output.OutputWriter` to `<logFolder>\Output.txt` and structured YAML `<logFolder>\Log.yml` (AmeliorationUtil.cs:300) — Log.yml is machine-readable (LogType/Error levels, per-action SourceOverride).
- The wizard passes logFolder (its own `%ProgramData%\AME\Logs\<timestamped>\` directory) and renders a live `OutputBuffer.txt` there — evidenced by Atlas's injected live-log tail script (local-build.ps1:131-136, quoted in §4.1) which polls the newest directory under `%ProgramData%\AME\Logs` for `OutputBuffer.txt`. ⚠️ OutputBuffer.txt itself is produced by the closed-source wizard, not the OSS CLI (repo grep = 0) — treat its format as observed behavior, not contract.
- `-AddLiveLog` (build flag) = the injected first-action popup window (see §4.1). UltraOS build keeps the same flag/behavior.
- `!status`/`!writeStatus` actions set the wizard's status line (WriteStatusAction; docs actions page).

### 6.2 UltraOS report design
- **Manifest (source of truth)**: every orchestrator change appends one JSONL record to `%ProgramData%\UltraOS\manifest.jsonl` — {ts, phase, module, preset/option, kind (reg/service/task/appx/file/net), target, old, new, result, undoable, undo-ref}. Written by the single PS orchestrator (S2), not by 800 engine actions, so it is complete AND cheap.
- **Final playbook actions** (after all modules, before/after explorer restart): `!status: Generating report`, then one `!powerShell` running `UltraModules\Scripts\New-Report.ps1`: reads manifest.jsonl + parses tail of the engine's `Log.yml` (errors) + engine AppliedPlaybooks record (SelectedOptions) → emits:
  - `%USERPROFILE%\Desktop\UltraOS Report.html` (self-contained, GPL-3.0 header, sections: summary counters, per-module changes, warnings/errors, skipped-no-ops, undo instructions, undoability flags)
  - `%ProgramData%\UltraOS\Report\report.txt` (plain-text copy) 
  - `%ProgramData%\UltraOS\Report\report.json` (machine-readable, consumed by future Undo playbook).
- **No engine modification needed** — hooks are: (1) our manifest written during S2 orchestrators, (2) a final report action, (3) engine logs as the error source. This is exactly the "final playbook actions writing a report from a manifest the playbook itself maintains" pattern requested.
- Optional: `report.html` auto-open on desktop at the end (currentUserElevated `Invoke-Item`) gated by an option `open-report` (default on).

---

## 7. Source index (all accessed 2026-10-07)
- Engine: https://github.com/Ameliorated-LLC/trusted-uninstaller-cli — AmeliorationUtil.cs, CLI.cs, PowershellAction.cs, CmdAction.cs, RunAction.cs, AppxAction.cs, ServiceAction.cs, SoftwareAction.cs, UninstallTask.cs, Playbook.cs, Core/Actions/RegistryValueAction.cs, Core/Services/Output.cs (local clones under /home/z/my-project/repos/trusted-uninstaller-cli)
- ame-assassin: https://github.com/Ameliorated-LLC/ame-assassin — Program.cs (local clone /home/z/my-project/repos/ame-assassin)
- Atlas: https://github.com/Atlas-OS/Atlas — playbook.conf, Configuration/** (196 yml), Executables/** (APPLYDUHIVE.ps1, BACKUP.ps1, CLEANUP.ps1, NGEN.ps1, SOFTWARE.ps1, packageInstall.ps1, RemoveEdge.ps1, AtlasDesktop cmd files), src/dependencies/local-build.ps1, build-playbook.sh/.cmd, .github/workflows/apbx.yaml, src/release-zip/ (local clone /home/z/my-project/repos/atlas)
- Docs: https://docs.amelabs.net/developers/getting-started/creation.html (packaging), /developers/actions.html, /developers/tasks.html, /remove_upgrade.html (reversibility), /changelog/2025-05-30.html
- Local toolchain verification: zip/unzip/python3/yamllint tests run in this sandbox, 2026-10-07 (see §4.2).

⚠️ UNVERIFIED items (explicit): PowerShell cold-start timings; StartComponentCleanup & FXPSYaml-install durations; choco bootstrap durations; wizard-UI behaviors not present in OSS engine (OutputBuffer.txt writer, any UI-level scheduling/restore-point features); Revi revert capabilities (out of T1-j scope).
