#!/usr/bin/env python3
"""UltraOS playbook validator.

Validates the playbook source tree:
  - playbook.conf XML well-formedness + option-name extraction
  - YAML parse of all Configuration files (custom loader accepts !action tags)
  - Header shape (title/description/actions)
  - Option-gate expressions against the option registry from playbook.conf
  - builds: expressions, registry types, service startups, task paths,
    exeDir script existence, protected appx families, never-touch services,
    duplicate registry writes and service conflicts (conflicts between mutually
    exclusive option gates - e.g. opt-disable-defender vs !opt-disable-defender -
    are recognized as intentional; so are same-file duplicate policy writes in
    files documenting the T1-h2 'double-write' technique)
  - packaging preflight: playbook.png + Images/<icon>.png for every
    <Software><Package> icon referenced by playbook.conf (warns; run
    scripts/make-artifacts.py first)
  - orphan module files not reachable from main.yml via the !task graph
    (warns; suppress intentional standalone files with a '# standalone:'
    header comment)
  - CRLF / UTF-8 BOM inside .yml files (portability warning)
  - --stats: per-module action counts via the same custom YAML loader
Usage: python3 scripts/validate-playbook.py [--strict] [--stats] [--files <path>...]
       (--files limits the scan to the given files; tree-wide checks such as
        duplicate-write detection across modules and orphan detection are
        only meaningful on a full scan, so run without --files before shipping)
Exit codes: 0 ok, 1 errors (warnings do not fail unless --strict)
"""
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path, PurePosixPath

import yaml

ROOT = Path(__file__).resolve().parent.parent
PB = ROOT / "src" / "playbook"
CFG = PB / "Configuration"
EXE = PB / "Executables"
CONF = PB / "playbook.conf"

KNOWN_TAGS = {
    "file", "service", "run", "powerShell", "cmd", "scheduledTask",
    "registryKey", "registryValue", "appx", "systemPackage", "taskKill",
    "software", "download", "writeStatus", "status", "task",
}
ENGINE_DISABLED_TAGS = {"user", "shortcut", "lineInFile", "update"}
REG_TYPES = {"REG_SZ", "REG_DWORD", "REG_QWORD", "REG_BINARY", "REG_EXPAND_SZ", "REG_MULTI_SZ"}
NEVER_TOUCH_SERVICES = {
    "wuauserv", "trustedinstaller", "usosvc", "spooler", "audiosrv", "winmgmt",
    "schedule", "profsvc", "usermgr", "staterepository", "installservice",
    "appxsvc", "clipsvc", "securityhealthservice", "mdcoresvc", "dosvc",
    "wlansvc", "netman", "netprofm", "nlasvc", "cdpsvc", "cdpusersvc",
}
PROTECTED_APPX = (
    "microsoft.windowsstore", "microsoft.desktopappinstaller",
    "microsoft.webruntime", "microsoft.vclibs", "microsoft.xaml",
    "microsoft.xboxidentityprovider", "microsoft.xbox.tcui",
)
NEVER_TOUCH_TASKS = (r"\microsoft\windows\windowsupdate", r"\microsoft\windows\.net")
BUILD_RE = re.compile(r"^\s*(>=|<=|>|<|!)?\s*\d+(\.\d+)?\s*$")
# Module files that are intentionally NOT in the main.yml !task pipeline.
# ultraos/revert.yml = stock-value inventory consumed by UNDO.ps1 at runtime
# (scaffold header: "the data source for undo"; Atlas's counterpart is
# onUpgrade-time - ours is data, not engine-executed).
STANDALONE_OK = {"ultraos/revert.yml"}
STANDALONE_MARKER_RE = re.compile(r"^#\s*standalone", re.IGNORECASE | re.MULTILINE)

errors, warnings = [], []


class TLoader(yaml.SafeLoader):
    pass


def multi_constructor(loader, tag_suffix, node):
    tag = tag_suffix.rstrip(":")  # pyyaml includes the trailing ':' in tag_suffix
    if isinstance(node, yaml.MappingNode):
        value = loader.construct_mapping(node, deep=True)
        value["__tag__"] = tag.lstrip("!")
        return value
    if isinstance(node, yaml.SequenceNode):
        return {"__tag__": tag.lstrip("!"), "__value__": loader.construct_sequence(node, deep=True)}
    return {"__tag__": tag.lstrip("!"), "__value__": loader.construct_scalar(node)}


TLoader.add_multi_constructor("!", multi_constructor)


def err(path, msg):
    errors.append(f"{path}: {msg}")


def warn(path, msg):
    warnings.append(f"{path}: {msg}")


def parse_option_expr(expr):
    """'!preset-safe & preset-extreme' -> {(False,'preset-safe'), (True,'preset-extreme')} or None."""
    if not expr:
        return None
    toks = set()
    for part in str(expr).split("&"):
        part = part.strip()
        if not part:
            return None
        toks.add((part.startswith("!"), part.lstrip("!").strip()))
    return toks


def mutually_exclusive(e1, e2):
    """True when the two AND-only option expressions can never hold at once
    (a token required True by one and False by the other). Used to keep the
    service-conflict advisory quiet for intentionally opposite gates, e.g.
    defender-disable (opt-disable-defender) vs defender-reenable (!opt-disable-defender)."""
    t1, t2 = parse_option_expr(e1), parse_option_expr(e2)
    if t1 is None or t2 is None:
        return False
    return any((not a_neg) == b_neg and a_tok == b_tok for (a_neg, a_tok) in t1 for (b_neg, b_tok) in t2)


def check_option_expr(expr, path, allowed):
    for part in str(expr).split("&"):
        tok = part.strip().lstrip("!").strip()
        if not tok:
            err(path, f"empty token in option expression '{expr}'")
        elif tok not in allowed:
            err(path, f"unknown option token '{tok}' (in '{expr}') - not defined in playbook.conf")


def main():
    strict = "--strict" in sys.argv
    stats = "--stats" in sys.argv
    scoped = []
    if "--files" in sys.argv:
        scoped = sys.argv[sys.argv.index("--files") + 1:]
        scoped = [s.replace("\\", "/") for s in scoped if not s.startswith("--")]

    # ---- playbook.conf ----
    allowed_options = set()
    software_icons = []
    if not CONF.exists():
        err("playbook.conf", "missing")
    else:
        try:
            tree = ET.parse(CONF)
            root = tree.getroot()
            for name in root.iter("Name"):
                if (name.text or "").strip():
                    allowed_options.add(name.text.strip())
            for pkg in root.iter("Package"):
                o = pkg.get("Option")
                if o:
                    allowed_options.add(o)
                icon = (pkg.findtext("Icon") or "").strip()
                if icon:
                    software_icons.append(icon)
            builds = {b.text.strip() for b in root.iter("string") if (b.text or "").strip().isdigit()}
            if "26300" not in builds:
                err("playbook.conf", "SupportedBuilds must include 26300 (26H2)")
            if len(allowed_options) < 5:
                err("playbook.conf", "suspiciously few option names extracted")
        except ET.ParseError as e:
            err("playbook.conf", f"XML parse error: {e}")

    # ---- YAML tree ----
    reg_seen = {}       # (path, value, data) -> file
    service_seen = {}   # name -> (startup, file)
    file_actions = {}   # rel path -> action count (for --stats)
    task_graph = {}     # rel path -> set of !task include targets (rel paths)
    yml_files = sorted(CFG.rglob("*.yml"))
    if scoped:
        def _matches(f):
            rel = str(f.relative_to(CFG)).replace("\\", "/")
            base = rel.rsplit("/", 1)[-1]
            return any(
                s == rel or s.endswith("/" + rel) or ("/" not in s and s == base)
                for s in scoped
            )
        yml_files = [f for f in yml_files if _matches(f)]
        print(f"Scoped mode: {len(yml_files)} file(s) matched ({', '.join(scoped)})")
        if not yml_files:
            err("--files", "no Configuration yml files matched the given paths")
    if not yml_files:
        err("Configuration", "no yml files found")

    for f in yml_files:
        rel = f.relative_to(CFG)
        raw = f.read_bytes()
        if raw.startswith(b"\xef\xbb\xbf"):
            warn(rel, "UTF-8 BOM present - strip it (engine/tooling expects plain UTF-8)")
        if b"\r\n" in raw:
            warn(rel, "CRLF line endings - normalize to LF")
        try:
            data = yaml.load(f.read_text(encoding="utf-8"), Loader=TLoader)
        except yaml.YAMLError as e:
            err(rel, f"YAML parse error: {e}")
            continue
        if not isinstance(data, dict):
            err(rel, "file must be a mapping")
            continue
        for key in ("title", "description", "actions"):
            if key not in data:
                err(rel, f"missing header key '{key}'")
        actions = data.get("actions")
        if not isinstance(actions, list):
            err(rel, "'actions' must be a list")
            continue
        if not actions:
            warn(rel, "SKELETON - actions list is empty")
        if "option" in data and data["option"]:
            check_option_expr(data["option"], rel, allowed_options)
        file_option = data.get("option") or None
        # T1-h2 §9.3 documented technique: the same policy written twice on purpose
        # (write -> gpupdate flush -> write again) - same-file duplicate writes in
        # such files are intentional, not copy-paste mistakes.
        double_write_file = b"double-write" in raw.lower()
        if "builds" in data and data["builds"]:
            if not isinstance(data["builds"], list):
                err(rel, "file-level builds: must be a list")
            else:
                for b in data["builds"]:
                    if not BUILD_RE.match(str(b)):
                        err(rel, f"bad builds entry '{b}'")

        for i, action in enumerate(actions):
            where = f"{rel} [action {i + 1}]"
            if not isinstance(action, dict) or "__tag__" not in action:
                err(where, "action is not a tagged mapping")
                continue
            if action["__tag__"] == "task":
                tp = str(action.get("path", "")).replace("\\", "/")
                if tp:
                    task_graph.setdefault(str(rel), set()).add(tp)
            tag = action["__tag__"]
            if tag in ENGINE_DISABLED_TAGS:
                err(where, f"action '!{tag}' is disabled in the current engine (T1-c)")
                continue
            if tag not in KNOWN_TAGS:
                err(where, f"unknown action tag '!{tag}'")
                continue
            if "option" in action and action["option"]:
                check_option_expr(action["option"], where, allowed_options)
            if "builds" in action and action["builds"]:
                bl = action["builds"]
                if not isinstance(bl, list):
                    err(where, "builds must be a list")
                else:
                    for b in bl:
                        if not BUILD_RE.match(str(b)):
                            err(where, f"bad builds entry '{b}'")
            if "weight" in action and not isinstance(action.get("weight"), int):
                err(where, "weight must be an integer")

            if tag == "registryValue":
                p = str(action.get("path", ""))
                v = str(action.get("value", ""))
                t = str(action.get("type", ""))
                op = action.get("operation", "")
                if not (p.startswith("HKLM\\") or p.startswith("HKCU\\") or p.startswith("HKU\\")):
                    err(where, f"registry path must start with HKLM\\ or HKCU\\ (got '{p}')")
                if not v:
                    err(where, "registryValue missing 'value'")
                if t and t not in REG_TYPES:
                    err(where, f"bad registry type '{t}'")
                if "data" not in action and op != "delete":
                    err(where, "registryValue missing 'data' (only allowed when operation: delete)")
                key = (p.lower(), v.lower(), str(action.get("data")))
                if key in reg_seen and reg_seen[key] != str(rel):
                    err(where, f"duplicate registry write (path/value/data) also in {reg_seen[key]}")
                elif key in reg_seen and not double_write_file:
                    warn(where, "duplicate registry write within the same file (path/value/data identical to an earlier action; add a '# double-write' note if intentional)")
                reg_seen[key] = str(rel)

            elif tag == "registryKey":
                p = str(action.get("path", ""))
                if not (p.startswith("HKLM\\") or p.startswith("HKCU\\") or p.startswith("HKU\\")):
                    err(where, f"registryKey path must start with HKLM\\ or HKCU\\ (got '{p}')")

            elif tag == "service":
                name = str(action.get("name", ""))
                if not name:
                    err(where, "service missing 'name'")
                lname = name.lower()
                startup = action.get("startup")
                op = str(action.get("operation", ""))
                if startup is not None and startup not in (0, 1, 2, 3, 4, 5):
                    err(where, f"bad startup '{startup}' (0=boot 1=system 2=auto 3=manual 4=disabled)")
                if lname in NEVER_TOUCH_SERVICES and (startup == 4 or op == "delete"):
                    err(where, f"never-touch service '{name}' must not be disabled/deleted (01-architecture §7.7)")
                if lname and startup is not None:
                    cur_opt = action.get("option") or file_option
                    if lname in service_seen and service_seen[lname][0] != startup:
                        prev_startup, prev_file, prev_opt = service_seen[lname]
                        if not mutually_exclusive(prev_opt, cur_opt):
                            warn(where, f"service '{name}' configured differently in {prev_file} ({prev_startup})")
                    service_seen[lname] = (startup, str(rel), cur_opt)

            elif tag == "scheduledTask":
                p = str(action.get("path", ""))
                if not p.startswith("\\"):
                    err(where, "scheduledTask path must start with '\\'")
                for bad in NEVER_TOUCH_TASKS:
                    if p.lower().startswith(bad):
                        err(where, f"refusing to touch Windows Update/.NET task '{p}'")

            elif tag == "task":
                tp = str(action.get("path", "")).replace("\\", "/")
                if not tp:
                    err(where, "task missing 'path'")
                elif not (CFG / tp).exists():
                    err(where, f"task include target does not exist: {tp}")

            elif tag == "appx":
                name = str(action.get("name", ""))
                if not name:
                    err(where, "appx missing 'name'")
                lname = name.lower()
                for prot in PROTECTED_APPX:
                    if lname.startswith(prot):
                        err(where, f"protected dependency appx '{name}' must never be removed (T1-e)")
                if "type" in action and str(action.get("type")) not in ("family", "name"):
                    warn(where, f"unusual appx type '{action.get('type')}'")

            elif tag == "writeStatus":
                if not action.get("status"):
                    err(where, "writeStatus missing 'status'")

            elif tag in ("powerShell", "cmd"):
                cmd = str(action.get("command", ""))
                if not cmd:
                    err(where, f"{tag} missing 'command'")
                if action.get("wait") is False:
                    err(where, f"{tag} with wait:false triggers the engine respawn bug (T1-j) - forbidden")
                m = re.match(r"^\.\\([\w\- .]+\.(?:ps1|cmd|bat))", cmd)
                if m and action.get("exeDir"):
                    script = EXE / m.group(1)
                    if not script.exists():
                        warn(where, f"exeDir script not found yet: Executables/{m.group(1)} (ok during build)")

        file_actions[str(rel)] = len(actions)

    # ---- packaging preflight (icons referenced by playbook.conf) ----
    if not (PB / "playbook.png").exists():
        warn("packaging", "src/playbook/playbook.png missing - run scripts/make-artifacts.py")
    for icon in software_icons:
        if not (PB / "Images" / icon).exists():
            warn("packaging", f"src/playbook/Images/{icon} (referenced by playbook.conf <Software>) missing - run scripts/make-artifacts.py")

    # ---- orphan module files (not reachable from main.yml !task graph) ----
    # (full scans only - scoping to a subset makes reachability meaningless)
    reachable = set()
    if not scoped:
        reachable, frontier = {"main.yml"}, ["main.yml"]
        while frontier:
            cur = frontier.pop()
            for tgt in task_graph.get(cur,()):
                if tgt not in reachable:
                    reachable.add(tgt)
                    frontier.append(tgt)
        for rel in file_actions:
            if rel == "main.yml" or rel in reachable:
                continue
            if rel in STANDALONE_OK:
                continue
            header = "\n".join((CFG / rel).read_text(encoding="utf-8").splitlines()[:15])
            if STANDALONE_MARKER_RE.search(header):
                continue
            warn(rel, "orphan module file: not reachable from main.yml via !task includes (add it to the pipeline, or mark it '# standalone: <reason>')")

    # ---- report ----
    print(f"Files scanned : {len(yml_files)}")
    print(f"Options registry: {len(allowed_options)} names: {', '.join(sorted(allowed_options))}")
    print(f"Registry writes: {len(reg_seen)} unique | Services configured: {len(service_seen)}")
    for w in warnings:
        print(f"  WARN  {w}")
    for e in errors:
        print(f"  ERROR {e}")
    print(f"RESULT: {len(errors)} errors, {len(warnings)} warnings")

    if stats:
        print("\nAction counts per module (custom YAML loader, same engine tags):")
        modules = {}
        for rel, n in sorted(file_actions.items()):
            mod = str(PurePosixPath(rel).parent)
            mod = "(root)" if mod == "." else mod
            n_files, act = modules.get(mod, (0, 0))
            modules[mod] = (n_files + 1, act + n)
        total = 0
        for mod in sorted(modules):
            n_files, act = modules[mod]
            total += act
            print(f"  {mod:<24} {n_files:>2} file(s) {act:>4} action(s)")
        main_own = file_actions.get("main.yml", 0)
        pipeline = main_own + sum(file_actions.get(t, 0) for t in reachable - {"main.yml"} if t in file_actions)
        print(f"  {'TOTAL (all files)':<24} {'':>11} {total:>4} action(s)")
        print(f"  main.yml: {main_own} own actions, {len(task_graph.get('main.yml', ()))} !task includes")
        print(f"  effective pipeline (main.yml + reachable files): {pipeline} action(s) (target < 400, Atlas v0.4 = 812)")

    if errors or (strict and warnings):
        sys.exit(1)


if __name__ == "__main__":
    main()
