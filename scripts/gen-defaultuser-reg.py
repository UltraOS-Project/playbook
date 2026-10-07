#!/usr/bin/env python3
"""Generate Executables/default-user.reg from the playbook's HKCU tweak actions.

Scans src/playbook/Configuration/tweaks/**/*.yml (the tweak tree where all
per-user modules live per 01-architecture section 5) with the SAME custom YAML
loader used by validate-playbook.py (the multi-constructor that turns
`!registryValue:` / `!registryKey:` tags into plain dicts), collects every
action that targets HKCU\\, and compiles them into a single Windows Registry
Editor v5.00 file with [HKEY_USERS\\AME_UserHive_Default\\...] key sections.

SCOPE NOTE (Atlas parity): only tweaks/ is scanned. Configuration/ultraos/*.yml
holds orchestration (start.yml, services.yml) and the INVERSE stock-values
inventory (revert.yml) - mirroring the latter would undo the tweaks in the same
import. Atlas's APPLYDUHIVE.ps1 scanned `Configuration\tweaks` for exactly the
same reason.

The generated .reg is consumed at RUNTIME by Executables/APPLYHIVE.ps1, which
imports it into the default-user hive (loaded by main.yml as
HKU\\AME_UserHive_Default from C:\\Users\\Default\\NTUSER.DAT). This replaces
Atlas's runtime APPLYDUHIVE.ps1 (FXPSYaml module install + re-parse of ~196
YAML files on the user's machine) with a build-time compile - the T1-j
blueprint speed technique S7a.

Usage (run from the repo root or via path; main agent runs this at integration,
after all module files have landed):

    python3 scripts/gen-defaultuser-reg.py            # write the .reg
    python3 scripts/gen-defaultuser-reg.py --check    # CI: exit 1 if the
                                                     # committed .reg is stale

Supported action shapes (see 02-style-guide.md):
    !registryValue {path: 'HKCU\\...\\Key', value: 'Name', data: '1', type: REG_DWORD}
    !registryValue {path: 'HKCU\\...', value: 'Name', operation: delete}
    !registryKey   {path: 'HKCU\\...\\Key'}                          (add)
    !registryKey   {path: 'HKCU\\...\\Key', operation: delete}

KNOWN LIMITATION (honest, see APPLYHIVE.ps1 header): the output is a superset
across presets/options - build-time compilation cannot evaluate runtime wizard
selections, so every HKCU action lands in the default profile. Also, HKCU
writes made inside raw `!powerShell` command blocks (e.g. the notification
mute/unmute in start.yml/finish.yml) are intentionally NOT collected - the
scanner only sees declarative tagged actions.

Exit codes: 0 ok, 1 on YAML parse errors, conflicting duplicates, or
(--check) a stale/missing generated file.
"""

import importlib.util
import re
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parent.parent
TWEAKS = ROOT / "src" / "playbook" / "Configuration" / "tweaks"
OUT = ROOT / "src" / "playbook" / "Executables" / "default-user.reg"
HIVE_PREFIX = "HKEY_USERS\\AME_UserHive_Default"

# Reuse the validator's custom loader verbatim so both tools interpret the
# playbook tree identically (single source of truth for `!tag` semantics).
def _load_tloader():
    spec = importlib.util.spec_from_file_location(
        "validate_playbook", ROOT / "scripts" / "validate-playbook.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.TLoader


REG_TYPES = {"REG_SZ", "REG_DWORD", "REG_QWORD", "REG_BINARY", "REG_EXPAND_SZ", "REG_MULTI_SZ"}


def reg_escape(text: str) -> str:
    """Escape a string for .reg syntax: backslashes and quotes."""
    return text.replace("\\", "\\\\").replace('"', '\\"')


def hex_bytes(text: str) -> list:
    """UTF-16LE bytes of a string, as a list of ints (for hex(2)/hex(7) values)."""
    return list(text.encode("utf-16-le")) + [0, 0]


def parse_data(action: dict, where: str):
    """Return (kind, payload) for a registryValue set/add action."""
    rtype = str(action.get("type", "REG_SZ")).strip()
    if rtype not in REG_TYPES:
        raise ValueError(f"{where}: unsupported registry type '{rtype}' for default-user generation")
    data = action.get("data", "")
    if rtype == "REG_DWORD":
        try:
            return "dword", int(str(data).strip(), 0)
        except ValueError:
            raise ValueError(f"{where}: REG_DWORD data '{data}' is not an integer")
    if rtype == "REG_QWORD":
        try:
            return "qword", int(str(data).strip(), 0)
        except ValueError:
            raise ValueError(f"{where}: REG_QWORD data '{data}' is not an integer")
    if rtype == "REG_SZ":
        return "sz", "" if data is None else str(data)
    if rtype == "REG_EXPAND_SZ":
        return "expand", "" if data is None else str(data)
    if rtype == "REG_BINARY":
        if isinstance(data, list):
            return "bin", [int(x) & 0xFF for x in data]
        raw = re.sub(r"[\s,]", "", str(data))
        if raw and not re.fullmatch(r"[0-9A-Fa-f]+", raw):
            raise ValueError(f"{where}: REG_BINARY data '{data}' is not hex")
        if len(raw) % 2:
            raw = "0" + raw
        return "bin", [int(raw[i:i + 2], 16) for i in range(0, len(raw), 2)]
    # REG_MULTI_SZ: accept a YAML list or a ;-separated string.
    if isinstance(data, list):
        parts = [str(x) for x in data]
    else:
        parts = ["" if data is None else str(data)]
    return "multi", "\0".join(parts)


def format_value(name: str, kind: str, payload) -> str:
    """Render one .reg value line for a (name, kind, payload) triple."""
    target = "@" if name == "" else f'"{reg_escape(name)}"'
    if kind == "dword":
        return f"{target}=dword:{payload:08x}"
    if kind == "qword":
        return f"{target}=qword:{payload:016x}"
    if kind == "sz":
        return f'{target}="{reg_escape(payload)}"'
    if kind == "expand":
        return f"{target}=hex(2):" + ",".join(f"{b:02x}" for b in hex_bytes(payload))
    if kind == "bin":
        return f"{target}=hex:" + ",".join(f"{b:02x}" for b in payload)
    if kind == "multi":
        sep = payload + "\0"  # items + list terminator (double NUL overall)
        return f"{target}=hex(7):" + ",".join(f"{b:02x}" for b in hex_bytes(sep))
    raise ValueError(f"unhandled value kind '{kind}'")


def collect(tloader):
    """Walk the Configuration tree; return (sections, deletes, stats).

    sections: {relative subkey path: {value name: formatted .reg line}}
    deletes:  {relative subkey path: [value names to delete]}  (registryValue deletes)
    key_deletes: [relative subkey paths]                        (registryKey deletes)
    """
    sections, deletes, key_deletes = {}, {}, []
    stats = {"files": 0, "hkcu": 0, "values": 0, "keys": 0}
    seen = {}  # (subkey, value) -> (data line, where) for conflict detection

    for yml in sorted(TWEAKS.rglob("*.yml")):
        rel = yml.relative_to(TWEAKS)
        try:
            data = yaml.load(yml.read_text(encoding="utf-8"), Loader=tloader)
        except yaml.YAMLError as exc:
            raise ValueError(f"{rel}: YAML parse error: {exc}")
        if not isinstance(data, dict):
            continue
        stats["files"] += 1
        for i, action in enumerate(data.get("actions") or []):
            if not isinstance(action, dict):
                continue
            tag = action.get("__tag__")
            path = str(action.get("path", ""))
            if tag not in ("registryValue", "registryKey") or not path.upper().startswith("HKCU\\"):
                continue
            stats["hkcu"] += 1
            where = f"{rel} [action {i + 1}]"
            subkey = path[5:].strip("\\")
            if not subkey:
                raise ValueError(f"{where}: HKCU path has no subkey: '{path}'")
            op = str(action.get("operation", "")).strip().lower()
            if tag == "registryKey":
                if op == "delete":
                    key_deletes.append(subkey)
                    stats["keys"] += 1
                else:
                    sections.setdefault(subkey, {})
                    stats["keys"] += 1
                continue
            name = str(action.get("value", ""))
            if op == "delete":
                deletes.setdefault(subkey, []).append(name)
                stats["values"] += 1
                continue
            if not action.get("type"):
                raise ValueError(f"{where}: HKCU registryValue without 'type' cannot be compiled")
            kind, payload = parse_data(action, where)
            line = format_value(name, kind, payload)
            prev = seen.get((subkey.lower(), name.lower()))
            if prev is not None:
                if prev[0] != line:
                    raise ValueError(
                        f"{where}: conflicting HKCU write {subkey}\\{name} "
                        f"(also defined in {prev[1]} with different data)"
                    )
                continue
            seen[(subkey.lower(), name.lower())] = (line, where)
            sections.setdefault(subkey, {})[name] = line
            stats["values"] += 1
    return sections, deletes, key_deletes, stats


def build_reg(sections, deletes, key_deletes) -> str:
    out = ["Windows Registry Editor Version 5.00"]
    for subkey in sorted(sections, key=str.casefold):
        values = sections[subkey]
        out += ["", f"[{HIVE_PREFIX}\\{subkey}]"]
        for name in sorted(values, key=str.casefold):
            out.append(values[name])
        for name in sorted(deletes.get(subkey, []), key=str.casefold):
            target = "@" if name == "" else f'"{reg_escape(name)}"'
            out.append(f"{target}=-")
    # Value deletes for keys with no set values still need their own section.
    for subkey in sorted(deletes, key=str.casefold):
        if subkey in sections:
            continue
        out += ["", f"[{HIVE_PREFIX}\\{subkey}]"]
        for name in sorted(deletes[subkey], key=str.casefold):
            target = "@" if name == "" else f'"{reg_escape(name)}"'
            out.append(f"{target}=-")
    # Whole-key deletes go last (reg.exe applies them in file order).
    for subkey in sorted(set(key_deletes), key=str.casefold):
        out += ["", f"[-{HIVE_PREFIX}\\{subkey}]"]
    out.append("")  # trailing newline before CRLF join
    return "\r\n".join(out)


def main() -> int:
    check = "--check" in sys.argv
    try:
        tloader = _load_tloader()
        sections, deletes, key_deletes, stats = collect(tloader)
    except (ValueError, FileNotFoundError) as exc:
        print(f"gen-defaultuser-reg: ERROR: {exc}", file=sys.stderr)
        return 1

    content = build_reg(sections, deletes, key_deletes)

    if check:
        current = None
        if OUT.exists():
            # newline="" keeps \r\n intact so the comparison is byte-faithful.
            with open(OUT, "r", encoding="utf-16", newline="") as fh:
                current = fh.read()
        if current != content:
            print(
                "gen-defaultuser-reg: STALE - Executables/default-user.reg does not match "
                "the playbook's HKCU actions. Regenerate with: python3 scripts/gen-defaultuser-reg.py",
                file=sys.stderr,
            )
            return 1
        print(
            f"gen-defaultuser-reg: OK ({stats['values']} values, {stats['keys']} keys "
            f"from {stats['hkcu']} HKCU actions across {stats['files']} files)"
        )
        return 0

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "w", encoding="utf-16", newline="") as fh:
        fh.write(content)
    print(
        f"gen-defaultuser-reg: wrote {OUT.relative_to(ROOT)} "
        f"({stats['values']} values, {stats['keys']} keys, "
        f"{len(key_deletes)} key deletes from {stats['hkcu']} HKCU actions "
        f"across {stats['files']} files)"
    )
    if stats["hkcu"] == 0:
        print(
            "gen-defaultuser-reg: WARNING - no HKCU actions found. If module files are "
            "still skeletons, re-run this script at integration time.",
            file=sys.stderr,
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
