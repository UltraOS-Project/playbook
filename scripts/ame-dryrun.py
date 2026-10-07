#!/usr/bin/env python3
"""
UltraOS - AME Wizard runtime dry-run harness
============================================
Ports AME Wizard's *actual* playbook load pipeline (rule-for-rule) so the
packaged .apbx can be runtime-tested on Linux before shipping.

Rule provenance (source: AME Wizard engine = TrustedUninstaller codebase,
repos/trusted-uninstaller, mirrored to repos/trusted-uninstaller-cli):

  Stage 0  Container
    - .apbx = ZIP archive, ZipCrypto, password "malte" (Atlas/Revi ship the
      same container; the wizard extracts it with its bundled 7-Zip)
    - playbook.conf + Configuration/main.yml must sit at the ARCHIVE ROOT
  Stage 1  playbook.conf load   (AmeliorationUtil.DeserializePlaybook, L426)
    - strict ReadXml (Core/Miscellaneous/XmlDeserializer.cs): throws
      "Unrecognized element/attribute ..." on unknown names
  Stage 2  Validation           (Playbook.cs, exact source strings)
    - RadioPage   L595-617, CheckboxPage L560-580, RadioImagePage L619-660,
      Package L715-724, Playbook.Validate L162-190,
      IsUpgradeApplicable L339-373, GetVersionNumber L117-150
  Stage 3  YAML action pipeline (Parser/PlaybookParser.cs L23-42 tag map,
      AmeliorationUtil.ParseActions L101+, Tasks/UninstallTask.cs,
      Actions/*.cs field schemas)
  Stage 4  File references      (wizard throws FileNotFoundException for
      missing !task YAMLs; missing icons/scripts break the UI/actions)
  Stage 5  Execution simulation (IsApplicable L66-97, IsApplicableOption
      L1500-1527, IsApplicableWindowsVersion L1443+, option negation "!",
      conjunction "&", builds expressions, oobe/iso gating)

Strictness note: unknown YAML action fields are errors here even though
YamlDotNet silently ignores them - a typo'd field would silently drop a
tweak, which is exactly what a dry run must catch.

Usage:
  python3 scripts/ame-dryrun.py                    # newest dist/*.apbx
  python3 scripts/ame-dryrun.py --apbx <file.apbx>
  python3 scripts/ame-dryrun.py --src              # source tree, no packaging
  python3 scripts/ame-dryrun.py --build 26100      # simulate a different build
  python3 scripts/ame-dryrun.py --selftest         # verify harness catches the
                                                   # v1.0.0 load failure
Exit codes: 0 pass, 1 fail (errors; warnings never fail alone)
"""
import argparse
import json
import re
import shutil
import sys
import tempfile
import uuid
import zipfile
from collections import Counter
from pathlib import Path

import xml.etree.ElementTree as ET

import yaml

ROOT = Path(__file__).resolve().parent.parent
APBX_PASSWORD = b"malte"
DEFAULT_BUILD = 26300  # Windows 11 26H2

C = {
    "g": "\033[92m", "y": "\033[93m", "r": "\033[91m", "b": "\033[96m",
    "d": "\033[2m", "0": "\033[0m", "B": "\033[1m",
}


def _c(code, text):
    return f"{C[code]}{text}{C['0']}" if sys.stdout.isatty() else str(text)


errors = []
warnings = []
notes = []


def err(where, msg):
    errors.append(f"[{where}] {msg}")


def warn(where, msg):
    warnings.append(f"[{where}] {msg}")


def note(where, msg):
    notes.append(f"[{where}] {msg}")


class DryRunError(Exception):
    pass


# ----------------------------------------------------------------------------
# Stage 0 - container
# ----------------------------------------------------------------------------
def stage0_container(apbx: Path, workdir: Path) -> Path:
    hdr = _c("B", f"STAGE 0  Container check - {_c('b', apbx.name)}")
    print(f"\n{hdr}\n" + "-" * len(hdr))
    if not apbx.exists():
        raise DryRunError(f".apbx not found: {apbx}")
    if zipfile.is_zipfile(apbx):
        print("  [ok] valid ZIP container")
    else:
        raise DryRunError("file is not a ZIP archive - wizard cannot open it")

    names = None
    with zipfile.ZipFile(apbx) as z:
        try:
            z.setpassword(APBX_PASSWORD)
            bad = z.testzip()  # full CRC round-trip with password
            if bad is not None:
                raise DryRunError(f"CRC mismatch on '{bad}' - archive corrupt")
            print(f"  [ok] ZipCrypto decrypt with password 'malte' + CRC round-trip "
                  f"({len(z.namelist())} entries)")
            names = z.namelist()
        except NotImplementedError:
            raise DryRunError("archive uses AES encryption - wizard expects ZipCrypto")
        except RuntimeError as e:
            raise DryRunError(f"extraction failed (wrong password?): {e}")
        z.extractall(workdir, pwd=APBX_PASSWORD)

    root_files = [n for n in names if "/" not in n.rstrip("/")]
    nested = [n for n in names if n.rstrip("/").count("/") >= 0 and
              not n.startswith(("Configuration/", "Executables/", "Images/")) and
              "/" in n.rstrip("/")]
    if nested:
        err("stage0", f"suspect non-root nesting: {sorted(set(n.split('/')[0] for n in nested))[:5]}")

    for required in ("playbook.conf", "Configuration/main.yml", "playbook.png"):
        target = workdir / required
        if not target.exists():
            err("stage0", f"'{required}' missing from archive root")
        else:
            print(f"  [ok] {required} present at archive root")

    junk = [n for n in names if n.endswith((".pyc", ".DS_Store", "Thumbs.db")) or "/.git" in n or "__pycache__" in n]
    if junk:
        warn("stage0", f"build junk inside archive: {junk[:5]}")
    else:
        print("  [ok] no build junk in archive")

    if errors:
        raise DryRunError("container check failed")
    print("  [ok] stage 0 PASSED")
    return workdir


# ----------------------------------------------------------------------------
# Stage 1 - playbook.conf strict load
#   Mirrors XmlDeserializable.ReadXml strictness for Playbook/FeaturePages/
#   Package; OOBE/ISO/Line/Option go through standard XmlSerializer in the
#   engine (lenient) - enum values are still enforced on parse.
# ----------------------------------------------------------------------------
STRICT_PLAYBOOK_ELEMENTS = {
    "Name", "Username", "Title", "ShortDescription", "Description", "Details",
    "ProgressText", "Version", "SupportedBuilds", "UpgradableFrom",
    "Requirements", "UniqueId", "InstallGuide", "Overhaul", "UseKernelDriver",
    "AllowUnsupportedUpgrades", "ProductCode", "EstimatedMinutes", "Git",
    "Website", "DonateLink", "SupportsISO", "OOBE", "ISO", "Software",
    "FeaturePages",
}
REQ_ENUM = {"Internet", "NoInternet", "DefenderDisabled", "DefenderToggled",
            "NoPendingUpdates", "Activation", "NoAntivirus", "LocalAccounts",
            "PasswordSet", "AdministratorPasswordSet", "PluggedIn",
            "NoTweakware", "FreshInstall", "UCPDDisabled"}
COMPONENT_ICONS = {"Rocket", "Privacy", "Lock"}
OOBE_INTERNET = {"Request", "Force"}

PAGE_ATTRS = {  # FeaturePage base attrs + per-type
    "RadioPage": {"IsRequired", "DefaultOption", "Description", "DependsOn", "WindowsVersion"},
    "CheckboxPage": {"IsRequired", "Description", "DependsOn", "WindowsVersion"},
    "RadioImagePage": {"IsRequired", "DefaultOption", "Description", "DependsOn",
                       "WindowsVersion", "CheckDefaultBrowser"},
}
PAGE_CHILDREN = {"TopLine", "BottomLine", "Options"}
OPT_ELEMENT = {"RadioPage": "RadioOption", "CheckboxPage": "CheckboxOption",
               "RadioImagePage": "RadioImageOption"}
OPT_ATTRS = {"DependsOn", "WindowsVersion", "IsChecked", "IsEnabled", "None"}
OPT_CHILDREN = {"Text", "Name", "FileName", "Fill",
                "GradientTopColor", "GradientBottomColor"}


def _txt(el):
    return (el.text or "").strip()


def stage1_parse_conf(pb_root: Path) -> dict:
    hdr = _c("B", "STAGE 1  playbook.conf load (strict, engine ReadXml semantics)")
    print(f"\n{hdr}\n" + "-" * len(hdr))
    conf = pb_root / "playbook.conf"
    try:
        tree = ET.parse(conf)
    except ET.ParseError as e:
        raise DryRunError(f"playbook.conf XML parse error: {e}")
    root = tree.getroot()
    if root.tag != "Playbook":
        raise DryRunError(f"root element must be <Playbook>, found <{root.tag}>")

    if root.attrib:
        err("playbook.conf", f"Unrecognized attribute '{list(root.attrib)[0]}' (Playbook has no attributes)")

    pb = {"FeaturePages": [], "Software": [], "SupportedBuilds": [],
          "Requirements": [], "UpgradableFrom": [], "oobe": None, "iso": None}

    for el in root:
        tag = el.tag
        if tag not in STRICT_PLAYBOOK_ELEMENTS:
            err("playbook.conf", f"Unrecognized element '{tag}' (line {el.sourceline})")
            continue
        if tag == "UniqueId":
            raw = _txt(el)
            try:
                u = uuid.UUID(raw)
                if u == uuid.UUID(int=0):
                    err("playbook.conf", "UniqueId must be unique, currently it is not unique. "
                                         "Use an online UUIDv4 generator to create a new unique ID.")
                pb["UniqueId"] = raw
            except ValueError:
                err("playbook.conf", f"UniqueId '{raw}' is not a valid GUID")
        elif tag in ("Name", "Username", "Title", "ShortDescription", "Description",
                     "Details", "ProgressText", "Version", "InstallGuide", "Git",
                     "Website", "DonateLink", "ProductCode"):
            pb[tag] = _txt(el)
        elif tag in ("Overhaul", "UseKernelDriver", "AllowUnsupportedUpgrades", "SupportsISO"):
            v = _txt(el)
            if v not in ("true", "false", "True", "False", ""):
                err("playbook.conf", f"<{tag}> must be a boolean, got '{v}'")
            pb[tag] = v.lower() == "true"
        elif tag == "EstimatedMinutes":
            if not _txt(el).isdigit():
                err("playbook.conf", "<EstimatedMinutes> must be an integer")
            else:
                pb[tag] = int(_txt(el))
        elif tag == "SupportedBuilds":
            for item in el:
                if item.tag.lower() != "string":
                    err("playbook.conf", f"Element '{item.tag}' does not match expected type 'string' "
                                         f"(SupportedBuilds, line {item.sourceline})")
                else:
                    pb["SupportedBuilds"].append(_txt(item))
        elif tag == "UpgradableFrom":
            if _txt(el):
                pb["UpgradableFrom"].append(_txt(el))
            for item in el:
                if item.tag.lower() != "string":
                    err("playbook.conf", f"Element '{item.tag}' does not match expected type 'string' "
                                         f"(UpgradableFrom, line {item.sourceline})")
                else:
                    pb["UpgradableFrom"].append(_txt(item))
        elif tag == "Requirements":
            for item in el:
                if item.tag != "Requirement":
                    err("playbook.conf", f"Element '{item.tag}' does not match expected type 'Requirement' "
                                         f"(line {item.sourceline})")
                    continue
                v = _txt(item)
                if v not in REQ_ENUM:
                    err("playbook.conf", f"Unknown Requirement '{v}' (valid: {sorted(REQ_ENUM)})")
                else:
                    pb["Requirements"].append(v)
        elif tag == "OOBE":
            pb["oobe"] = _parse_oobe(el)
        elif tag == "ISO":
            pb["iso"] = _parse_iso(el)
        elif tag == "Software":
            pb["Software"] = _parse_software(el)
        elif tag == "FeaturePages":
            pb["FeaturePages"] = _parse_feature_pages(el)

    # engine: XmlRequired on Name/Username/Version (missing/empty -> throw)
    for req_key in ("Name", "Username", "Version"):
        if not pb.get(req_key):
            err("playbook.conf", f"Required property '{req_key}' must be set.")
    if errors:
        for e in errors:
            print("  " + _c("r", "FAIL") + f" {e}")
        raise DryRunError(f"{len(errors)} load error(s) in playbook.conf "
                          f"(wizard: 'Error while attempting to load Playbook')")
    print(f"  [ok] strict parse clean: {len(pb['FeaturePages'])} feature pages, "
          f"{len(pb['Software'])} software packages, "
          f"builds {', '.join(pb['SupportedBuilds'])}")
    print("  [ok] stage 1 PASSED")
    return pb


def _parse_oobe(el) -> dict:
    out = {"Internet": None, "BulletPoints": []}
    for item in el:
        if item.tag == "Internet":
            v = _txt(item)
            if v not in OOBE_INTERNET:
                err("playbook.conf", f"OOBE Internet must be Request|Force, got '{v}'")
            out["Internet"] = v
        elif item.tag == "BulletPoints":
            for b in item:
                if b.tag != "BulletPoint":
                    err("playbook.conf", f"Element '{b.tag}' does not match expected type 'BulletPoint'")
                    continue
                icon = b.attrib.get("Icon")
                if icon not in COMPONENT_ICONS:
                    err("playbook.conf", f"BulletPoint Icon '{icon}' invalid (valid: {sorted(COMPONENT_ICONS)})")
                out["BulletPoints"].append({
                    "Icon": icon,
                    "Title": b.attrib.get("Title", ""),
                    "Description": b.attrib.get("Description", ""),
                })
    return out


def _parse_iso(el) -> dict:
    out = {}
    for item in el:
        if item.tag in ("DisableBitLocker", "DisableHardwareRequirements"):
            out[item.tag] = _txt(item).lower() == "true"
    return out


def _parse_software(el) -> list:
    packages = []
    for item in el:
        if item.tag != "Package":
            err("playbook.conf", f"Element '{item.tag}' does not match expected type 'Package'")
            continue
        allowed_attrs = {"Option", "Local", "DefaultWebBrowser"}
        for a in item.attrib:
            if a not in allowed_attrs:
                err("playbook.conf", f"Unrecognized attribute '{a}' (Package)")
        allowed_children = {"Name", "Title", "Description", "Icon"}
        pkg = {"Option": item.attrib.get("Option"),
               "DefaultWebBrowser": item.attrib.get("DefaultWebBrowser") == "true",
               "Local": item.attrib.get("Local", "true")}
        for child in item:
            if child.tag not in allowed_children:
                err("playbook.conf", f"Unrecognized element '{child.tag}' (Package)")
            else:
                pkg[child.tag] = _txt(child)
        packages.append(pkg)
    return packages


def _parse_feature_pages(el) -> list:
    pages = []
    for page in el:
        ptype = page.tag
        if ptype not in PAGE_ATTRS:
            err("playbook.conf", f"Element '{ptype}' does not match any of the following: "
                                 f"CheckboxPage, RadioPage, RadioImagePage")
            continue
        for a in page.attrib:
            if a not in PAGE_ATTRS[ptype]:
                err("playbook.conf", f"Unrecognized attribute '{a}' ({ptype}, line {page.sourceline})")
        page_data = {
            "type": ptype,
            "IsRequired": page.attrib.get("IsRequired") == "true",
            "DefaultOption": page.attrib.get("DefaultOption"),
            "Description": page.attrib.get("Description"),
            "DependsOn": page.attrib.get("DependsOn"),
            "TopLine": None, "BottomLine": None, "Options": [],
        }
        seen_children = set()
        for child in page:
            if child.tag not in PAGE_CHILDREN:
                err("playbook.conf", f"Unrecognized element '{child.tag}' ({ptype}, line {child.sourceline})")
                continue
            if child.tag in seen_children:
                err("playbook.conf", f"Duplicate assignment for property '{child.tag}' ({ptype})")
            seen_children.add(child.tag)
            if child.tag in ("TopLine", "BottomLine"):
                for a in child.attrib:
                    if a not in ("Text", "Link"):
                        err("playbook.conf", f"Unrecognized attribute '{a}' (Line)")
                if not child.attrib.get("Text"):
                    warn("playbook.conf", f"{child.tag} without Text attribute")
                page_data[child.tag] = {
                    "Text": child.attrib.get("Text"),
                    "Link": child.attrib.get("Link"),
                }
            else:  # Options
                expected = OPT_ELEMENT[ptype]
                for opt in child:
                    if opt.tag != expected:
                        err("playbook.conf", f"Element '{opt.tag}' does not match expected type '{expected}' "
                                             f"({ptype}, line {opt.sourceline})")
                        continue
                    for a in opt.attrib:
                        if a not in OPT_ATTRS:
                            err("playbook.conf", f"Unrecognized attribute '{a}' ({expected})")
                    allowed = {"Text", "Name"} | ({"FileName", "Fill",
                                                   "GradientTopColor", "GradientBottomColor"}
                                                  if ptype == "RadioImagePage" else set())
                    o = {"IsChecked": opt.attrib.get("IsChecked", "true") == "true",
                         "None": opt.attrib.get("None") == "true"}
                    for oc in opt:
                        if oc.tag not in allowed:
                            err("playbook.conf", f"Unrecognized element '{oc.tag}' ({expected})")
                        else:
                            o[oc.tag] = _txt(oc)
                    page_data["Options"].append(o)
        pages.append(page_data)
    return pages

# ----------------------------------------------------------------------------
# Stage 2 - validation (Playbook.cs Validate() rules, exact source strings)
# ----------------------------------------------------------------------------
def get_version_number(text: str):
    """Port of VersionNumber.GetVersionNumber (Playbook.cs L117-150)."""
    if " " in text:
        text = text[:text.index(" ")]
    parts = text.split(".")
    if len(parts) == 0:
        raise ValueError(f"Invalid version number '{text}'")
    nums = [0, 0, 0]
    for i, p in enumerate(parts):
        if i > 2:
            raise ValueError("Version number invalid.")
        nums[i] = int(p)  # int.Parse -> ValueError mirrors FormatException
    return tuple(nums)


def stage2_validate(pb: dict) -> dict:
    hdr = _c("B", "STAGE 2  Playbook + page validation (Playbook.cs rules)")
    print(f"\n{hdr}\n" + "-" * len(hdr))
    where = "playbook.conf"

    # --- Playbook.Validate (L162-190) ---
    invalid_chars = set('<>:"/\\|?*') | {chr(i) for i in range(32)}
    bad = [ch for ch in (pb.get("Name") or "") if ch in invalid_chars]
    if bad:
        err(where, "Playbook Name cannot contain invalid file name characters including: \\ / : * ? < > |")
    # MeasureStringWidth(Segoe UI 14.5) > 97px / (Segoe UI 13) > 100px - Linux
    # has no GDI: use conservative ~7.5px/char and ~6.7px/char proxies (warn only)
    if len(pb.get("Name") or "") > 14:
        warn(where, f"Playbook Name is long ({len(pb['Name'])} chars) - could exceed the wizard's 97px "
                    f"Segoe UI width limit; verify on Windows")
    if len(pb.get("Username") or "") > 15:
        warn(where, f"Playbook Username is long ({len(pb['Username'])} chars) - could exceed 100px limit")
    try:
        get_version_number(pb.get("Version") or "")
    except ValueError as e:
        err(where, f"Improper version format '{pb.get('Version')}'. Version must follow one of these "
                   f"formats:\n1\n1.0\n1.0.0 ({e})")

    # IsUpgradeApplicable("1.0.0") (L339-373): entries are 'any' | range | version
    for v in pb["UpgradableFrom"]:
        if v == "any":
            continue
        if "-" in v:
            split = v.split("-")
            if len(split) != 2:
                err(where, f"Invalid version range format '{v}'")
            else:
                for s in split:
                    try:
                        get_version_number(s)
                    except ValueError:
                        err(where, f"Invalid version range format '{v}'")
        else:
            try:
                get_version_number(v)
            except ValueError:
                err(where, f"Invalid 'UpgradableFrom' value '{v}'. Values must follow one of the these "
                           f"formats:\n1.0.0\n1.0.0-2.0.0\nany")

    if pb.get("SupportsISO"):
        bullets = (pb.get("oobe") or {}).get("BulletPoints") or []
        if not bullets:
            err(where, "OOBE BulletPoints must be specified when SupportsISO is true.")
        elif len(bullets) != 3:
            err(where, "There must be exactly three features under OOBEFeatures.")
        else:
            icons = [b["Icon"] for b in bullets]
            if len(set(icons)) != len(icons):
                err(where, "OOBE feature icons must be distinct.")
            if any((not b["Title"]) or not (b["Description"] or "").strip() for b in bullets):
                err(where, "OOBE feature title and description must be non-empty.")
    if pb.get("SupportsISO") and not pb.get("iso"):
        note(where, "SupportsISO=true without <ISO> block - wizard defaults apply (BitLocker/hw-req not disabled)")

    # --- Package.Validate (L715-724) ---
    for pkg in pb["Software"]:
        for field in ("Name", "Title", "Description", "Icon"):
            if not (pkg.get(field) or "").strip():
                err(where, f"Software must have a {field}.")

    # --- Page validation (L560-660, exact conditions) ---
    for page in pb["FeaturePages"]:
        ptype, opts = page["type"], page["Options"]
        top, bottom = page["TopLine"], page["BottomLine"]
        n = len(opts)
        names = [o.get("Name") for o in opts if not o.get("None")]
        if ptype == "RadioPage":
            if n > 2 and top and bottom:
                err(where, "RadioPage with a TopLine and BottomLine must not have more than 2 options.")
            if n > 3 and (top or bottom):
                err(where, "RadioPage with a TopLine or BottomLine must not have more than 3 options.")
            if n > 4:
                err(where, "RadioPage must not have more than 4 options.")
            if page["DefaultOption"] and page["DefaultOption"] not in names:
                err(where, f"No option matching DefaultOption {page['DefaultOption']} in Radio")
            if len(set(names)) != len(names):
                err(where, "Duplicate options found in RadioPage.")
        elif ptype == "CheckboxPage":
            if n > 2 and top and bottom:
                err(where, "CheckboxPage with a TopLine and BottomLine must not have more than 2 options.")
            if n > 3 and (top or bottom):
                err(where, "CheckboxPage with a TopLine or BottomLine must not have more than 3 options.")
            if n > 4:
                err(where, "CheckboxPage must not have more than 4 options.")
            if len(set(names)) != len(names):
                err(where, "Duplicate options found in CheckboxPage.")
        elif ptype == "RadioImagePage":
            if n > 4:
                err(where, "RadioImagePage must not have more than 4 options.")
            if page["DefaultOption"] and page["DefaultOption"] not in names:
                err(where, f"No option matching DefaultOption {page['DefaultOption']} in RadioImagePage.")
            if len(set(names)) != len(names):
                err(where, "Duplicate options found in RadioImagePage.")
            for o in opts:
                if o.get("None"):
                    continue
                gt, gb = o.get("GradientTopColor"), o.get("GradientBottomColor")
                if gt == gb:
                    err(where, "RadioImageOption gradient colors must not be the same.")
                if len(gt or "") != 7 or len(gb or "") != 7:
                    err(where, "RadioImageOption gradient colors must be in the format #RRGGBB.")
                if (gt or "").upper() in ("#FFFFFF", "#000000") or (gb or "").upper() in ("#FFFFFF", "#000000"):
                    err(where, "RadioImageOption gradient colors must not be black or white.")
        if not (page.get("Description") or "").strip():
            note(where, f"{ptype} without Description text")

    # option registry: every choosable option name (pages + software)
    registry = set()
    for page in pb["FeaturePages"]:
        for o in page["Options"]:
            if o.get("Name") and not o.get("None"):
                registry.add(o["Name"])
    for pkg in pb["Software"]:
        if pkg.get("Option"):
            registry.add(pkg["Option"])

    if errors:
        for e in errors:
            print("  " + _c("r", "FAIL") + " " + e)
        raise DryRunError(f"{len(errors)} validation error(s) - wizard refuses to load the playbook")
    n_lines = sum(1 for p in pb["FeaturePages"] for k in ("TopLine", "BottomLine") if p[k])
    print(f"  [ok] {len(pb['FeaturePages'])} pages validated "
          f"({sum(len(p['Options']) for p in pb['FeaturePages'])} options, {n_lines} info lines)")
    print(f"  [ok] option registry ({len(registry)}): {', '.join(sorted(registry))}")
    print("  [ok] stage 2 PASSED")
    return registry


# ----------------------------------------------------------------------------
# Stage 3 - YAML action pipeline
#   Engine tag map: PlaybookParser.cs L23-42; field schemas: Actions/*.cs;
#   file shape: Tasks/UninstallTask.cs.
# ----------------------------------------------------------------------------
ENABLED_TAGS = {"task", "file", "service", "registryKey", "registryValue", "appx",
                "systemPackage", "scheduledTask", "run", "powerShell", "cmd",
                "taskKill", "software", "download", "writeStatus", "status"}
ENGINE_DISABLED_TAGS = {"user", "shortcut", "lineInFile", "update"}

BASE_FIELDS = {"iso", "oobe", "ignoreErrors", "option", "status", "options",
               "builds", "cpuArch", "onUpgrade", "onUpgradeVersions",
               "previousOption", "errorAction", "allowRetries"}
FILE_KEYS = BASE_FIELDS | {"title", "description", "actions", "priority", "privilege", "features", "tasks"}

ENUMS = {
    "service_op": {"stop", "continue", "start", "pause", "delete", "change"},
    "regkey_op": {"delete", "add"},
    "regval_op": {"delete", "add", "set"},
    "reg_type": {"reg_sz", "reg_multi_sz", "reg_expand_sz", "reg_dword",
                 "reg_qword", "reg_binary", "reg_none", "reg_unknown"},
    "appx_op": {"remove", "clearcache"},
    "appx_level": {"family", "package", "app"},
    "task_op": {"delete", "enable", "disable", "deletefolder"},
    "privilege": {"trustedinstaller", "system", "currentusertrustedinstaller",
                  "currentuserelevated", "currentuser"},
    "scope": {"allusers", "currentuser", "activeusers", "defaultuser"},
    "error_action": {"ignore", "log", "notify", "halt"},
    "iso_oobe": {"true", "only", "false"},
}
ACTION_FIELDS = {
    "task": {"path": "required"},
    "service": {"operation": ENUMS["service_op"], "name": "required", "startup": "int",
                "deleteStop": "bool", "deleteUsingRegistry": "bool", "device": "str", "weight": "int"},
    "registryKey": {"path": "required", "scope": ENUMS["scope"],
                    "operation": ENUMS["regkey_op"], "weight": "int"},
    "registryValue": {"path": "required", "value": "required", "data": "any",
                      "type": ENUMS["reg_type"], "scope": ENUMS["scope"],
                      "operation": ENUMS["regval_op"], "weight": "int"},
    "appx": {"name": "required", "type": ENUMS["appx_level"], "operation": ENUMS["appx_op"],
             "verboseOutput": "bool", "unregister": "bool", "weight": "int"},
    "scheduledTask": {"operation": ENUMS["task_op"], "data": "any", "path": "required", "weight": "int"},
    "run": {"runas": ENUMS["privilege"], "path": "str", "exe": "str", "args": "str",
            "baseDir": "bool", "exeDir": "bool", "createWindow": "bool", "hideWindow": "bool",
            "showOutput": "bool", "showError": "bool", "timeout": "int", "wait": "any",
            "handleExitCodes": "dict", "weight": "int"},
    "powerShell": {"runas": ENUMS["privilege"], "command": "required", "timeout": "str",
                   "wait": "bool", "exeDir": "bool", "handleExitCodes": "dict", "weight": "int"},
    "taskKill": {"name": "required", "pathContains": "str", "weight": "int"},
    "writeStatus": {"status": "required"},
    "file": {}, "cmd": {}, "software": {}, "download": {}, "systemPackage": {},
}


class TLoader(yaml.SafeLoader):
    pass


def _yaml_tag(loader, tag_suffix, node):
    tag = tag_suffix.rstrip(":").lstrip("!")
    if isinstance(node, yaml.MappingNode):
        v = loader.construct_mapping(node, deep=True)
        v["__tag__"] = tag
        return v
    if isinstance(node, yaml.SequenceNode):
        return {"__tag__": tag, "__value__": loader.construct_sequence(node, deep=True)}
    return {"__tag__": tag, "__value__": loader.construct_scalar(node)}


TLoader.add_multi_constructor("!", _yaml_tag)


def _norm(v):
    """camelCase normalization for enum comparison (YamlDotNet is case-insensitive)."""
    if isinstance(v, bool):
        return "true" if v else "false"
    return str(v).strip()


def _normpath(p):
    """YAML paths use Windows separators (engine-native); normalize for Linux."""
    return str(p).replace("\\", "/")


def stage3_yaml(cfg_root: Path, registry: set) -> dict:
    hdr = _c("B", "STAGE 3  YAML action pipeline (PlaybookParser tag map + field schemas)")
    print(f"\n{hdr}\n" + "-" * len(hdr))
    yml_files = sorted(cfg_root.rglob("*.yml"))
    parsed = {}
    for f in yml_files:
        rel = f.relative_to(cfg_root).as_posix()
        try:
            doc = yaml.load(f.read_text(encoding="utf-8-sig"), Loader=TLoader)
        except yaml.YAMLError as e:
            err("yaml", f"{rel}: YAML parse error: {e}")
            continue
        parsed[rel] = doc

    for rel, doc in parsed.items():
        if not isinstance(doc, dict):
            err("yaml", f"{rel}: file is not a YAML mapping (engine expects UninstallTask)")
            continue
        for key in doc:
            if key not in FILE_KEYS:
                warn("yaml", f"{rel}: unknown file-level key '{key}' (engine ignores unknown keys)")
        fopt, fopts = doc.get("option"), doc.get("options")
        _validate_option_refs(rel, "file header", fopt, fopts, registry, doc.get("builds"))

        actions = doc.get("actions") or []
        if not isinstance(actions, list):
            err("yaml", f"{rel}: 'actions' must be a list")
            continue
        for i, action in enumerate(actions):
            if not isinstance(action, dict) or "__tag__" not in action:
                err("yaml", f"{rel}: actions[{i}] is not an engine action node")
                continue
            tag = action["__tag__"]
            if tag in ENGINE_DISABLED_TAGS:
                err("yaml", f"{rel}: !{tag} is DISABLED in the engine (PlaybookParser.cs) - "
                            f"would throw at runtime")
                continue
            if tag not in ENABLED_TAGS:
                err("yaml", f"{rel}: unknown action tag !{tag} (not in engine tag map)")
                continue
            fields = action.keys() - {"__tag__", "__value__"}
            allowed = BASE_FIELDS | set(ACTION_FIELDS.get(tag, {}))
            for fname in fields:
                if fname not in allowed:
                    err("yaml", f"{rel}: !{tag}[{i}]: unknown field '{fname}' "
                                f"(engine would silently drop it)")
            spec = ACTION_FIELDS.get(tag, {})
            for fname, rule in spec.items():
                if fname not in action:
                    if rule == "required":
                        err("yaml", f"{rel}: !{tag}[{i}]: missing required field '{fname}'")
                    continue
                val = action[fname]
                if isinstance(rule, set):
                    if _norm(val).lower() not in rule:
                        err("yaml", f"{rel}: !{tag}[{i}]: invalid {fname} '{val}' "
                                    f"(valid: {sorted(rule)})")
                elif rule == "bool" and not isinstance(val, bool):
                    err("yaml", f"{rel}: !{tag}[{i}]: {fname} must be a boolean")
                elif rule == "int" and not (isinstance(val, int) and not isinstance(val, bool)):
                    err("yaml", f"{rel}: !{tag}[{i}]: {fname} must be an integer")
                elif rule == "dict" and not isinstance(val, dict):
                    err("yaml", f"{rel}: !{tag}[{i}]: {fname} must be a mapping")
            # base enum fields
            if "iso" in action and _norm(action["iso"]).lower() not in ENUMS["iso_oobe"]:
                err("yaml", f"{rel}: !{tag}[{i}]: invalid iso '{action['iso']}'")
            if "oobe" in action and _norm(action["oobe"]).lower() not in ENUMS["iso_oobe"]:
                err("yaml", f"{rel}: !{tag}[{i}]: invalid oobe '{action['oobe']}'")
            if "errorAction" in action and _norm(action["errorAction"]).lower() not in ENUMS["error_action"]:
                err("yaml", f"{rel}: !{tag}[{i}]: invalid errorAction '{action['errorAction']}'")
            if "startup" in action and tag == "service" and \
                    not (isinstance(action["startup"], int) and 0 <= action["startup"] <= 4):
                err("yaml", f"{rel}: !service[{i}]: startup must be an integer 0-4 "
                            f"(2=auto 3=manual 4=disabled)")
            _validate_option_refs(rel, f"!{tag}[{i}]", action.get("option"),
                                  action.get("options"), registry, action.get("builds"))
            if tag == "task" and "path" in action:
                p = _normpath(action["path"])
                if not (cfg_root / p).is_file():
                    err("yaml", f"{rel}: Could not find YAML file: {action['path']} "
                                f"(engine: FileNotFoundException)")

    # task graph reachability from Configuration/main.yml
    main = parsed.get("main.yml")
    if main is None:
        err("yaml", "Configuration/main.yml missing - playbook has no entry point")
    else:
        reachable, stack, seen = set(), ["main.yml"], set()
        while stack:
            cur = stack.pop()
            if cur in seen:
                continue
            seen.add(cur)
            doc = parsed.get(cur)
            if not isinstance(doc, dict):
                continue
            reachable.add(cur)
            for a in doc.get("actions") or []:
                if isinstance(a, dict) and a.get("__tag__") == "task" and a.get("path"):
                    nxt = _normpath(a["path"])
                    if nxt in seen:
                        continue
                    if (cfg_root / nxt).is_file():
                        stack.append(nxt)
        orphans = [r for r in parsed if r not in reachable]
        for o in orphans:
            text = (cfg_root / o).read_text(encoding="utf-8-sig")
            if re.search(r"^#\s*standalone", text, re.IGNORECASE | re.MULTILINE) \
                    or o == "ultraos/revert.yml":
                note("yaml", f"{o}: standalone data file (not in !task graph - intentional)")
            else:
                warn("yaml", f"{o}: not reachable from main.yml via !task graph")

    if errors:
        for e in errors:
            print("  " + _c("r", "FAIL") + " " + e)
        raise DryRunError(f"{len(errors)} YAML pipeline error(s)")
    total_actions = sum(len((d or {}).get("actions") or []) for d in parsed.values()
                        if isinstance(d, dict))
    print(f"  [ok] {len(parsed)} YAML files, {total_actions} actions - "
          f"tags/fields/enums/refs all valid")
    print("  [ok] stage 3 PASSED")
    return parsed


def _validate_option_refs(rel, where, option, options, registry, builds):
    refs = []
    if option is not None:
        if "&" in str(option) and "!" in str(option):
            err("yaml", f"{rel}: {where}: options item must not contain both & and !")
        refs += [p for p in str(option).split("&")]
    if options is not None:
        if not isinstance(options, list):
            err("yaml", f"{rel}: {where}: 'options' must be a list")
        else:
            positives = [o for o in options if not str(o).startswith("!")]
            if not positives:
                err("yaml", f"{rel}: {where}: negative-only 'options' list never runs "
                            f"(engine requires >=1 positive entry - ParseActions L122)")
            refs += [str(o) for o in options]
    for r in refs:
        name = r.strip().lstrip("!").strip()
        if name and name not in registry:
            err("yaml", f"{rel}: {where}: unknown option '{name}' - not defined in "
                        f"playbook.conf (action would never run)")
    if builds is not None:
        if not isinstance(builds, list):
            err("yaml", f"{rel}: {where}: 'builds' must be a list")
        else:
            positives = [b for b in builds if not str(b).startswith("!")]
            if not positives:
                err("yaml", f"{rel}: {where}: negative-only 'builds' list never runs")
            for b in builds:
                m = re.match(r"^!?>?=?\s*\d+(\.\d+)?$", str(b))
                if not m and not str(b).startswith(("!", "<", ">")):
                    err("yaml", f"{rel}: {where}: unparseable builds expression '{b}'")

# ----------------------------------------------------------------------------
# Stage 4 - file references (icons, scripts, executables)
# ----------------------------------------------------------------------------
def stage4_files(pb_root: Path, pb: dict, parsed_yaml: dict) -> None:
    hdr = _c("B", "STAGE 4  File references (icons / scripts / executables)")
    print(f"\n{hdr}\n" + "-" * len(hdr))
    images = pb_root / "Images"
    exe_dir = pb_root / "Executables"
    checked = 0

    for pkg in pb["Software"]:
        icon = pkg.get("Icon")
        if icon and not (images / icon).is_file():
            err("files", f"Software '{pkg.get('Name')}' icon missing: Images/{icon}")
        else:
            checked += 1
    for page in pb["FeaturePages"]:
        for o in page["Options"]:
            fn = o.get("FileName")
            if fn and not (images / f"{fn}.png").is_file():
                err("files", f"RadioImageOption '{o.get('Name')}' image missing: Images/{fn}.png")
            elif fn:
                checked += 1

    # exeDir powershell commands (.\SCRIPT.ps1 -> Executables/SCRIPT.ps1)
    for rel, doc in parsed_yaml.items():
        for a in (doc or {}).get("actions") or [] if isinstance(doc, dict) else []:
            if not isinstance(a, dict):
                continue
            if a.get("__tag__") == "powerShell" and a.get("exeDir") is True:
                cmd = str(a.get("command", ""))
                m = re.match(r"^\.\\(.+)$", cmd.strip())
                if m and not (exe_dir / m.group(1)).is_file():
                    err("files", f"{rel}: exeDir command '{cmd}' - Executables/{m.group(1)} missing")
                elif m:
                    checked += 1
            if a.get("__tag__") == "run":
                exe = str(a.get("exe", ""))
                if exe.startswith(".\\") and not (exe_dir / exe[2:]).is_file():
                    err("files", f"{rel}: run exe '{exe}' - Executables/{exe[2:]} missing")
                elif exe.startswith(".\\"):
                    checked += 1

    if errors:
        for e in errors:
            print("  " + _c("r", "FAIL") + " " + e)
        raise DryRunError(f"{len(errors)} file-reference error(s)")
    print(f"  [ok] {checked} file references resolved (icons, exeDir scripts)")
    print("  [ok] stage 4 PASSED")


# ----------------------------------------------------------------------------
# Stage 5 - execution simulation (ParseActions applicability, exact port)
# ----------------------------------------------------------------------------
def is_applicable_option(expr, selected):
    """AmeliorationUtil.IsApplicableOption (L1500-1527)."""
    if expr is None or expr == "":
        return True
    expr = str(expr)
    if "&" in expr:
        if "!" in expr:
            raise DryRunError("YAML options item must not contain both & and !")
        return all(is_applicable_option(p, selected) for p in expr.split("&"))
    negative = expr.startswith("!")
    name = expr.lstrip("!")
    if selected is None:
        return negative
    hit = any(s.lower() == name.lower() for s in selected)
    return (not hit) if negative else hit


def is_applicable_list(opt_list, selected):
    """ParseActions plural 'options' gating (L122-124):
    skip when (positives exist and none apply) or (negatives exist and any applies)."""
    if not opt_list:
        return True
    positives = [o for o in opt_list if not str(o).startswith("!")]
    negatives = [o for o in opt_list if str(o).startswith("!")]
    if positives and not any(is_applicable_option(o, selected) for o in positives):
        return False
    if negatives and any(is_applicable_option(o, selected) for o in negatives):
        return False
    return True


def is_applicable_build(expr, build: float):
    """IsApplicableWindowsVersion (L1443+): !, >=, <=, >, <, exact; decimal builds."""
    expr = str(expr)
    negative = expr.startswith("!")
    if negative:
        expr = expr[1:]
    result = False
    if expr.startswith(">="):
        result = build >= float(expr[2:])
    elif expr.startswith("<="):
        result = build <= float(expr[2:])
    elif expr.startswith(">"):
        result = build > float(expr[1:])
    elif expr.startswith("<"):
        result = build < float(expr[1:])
    else:
        result = build == float(expr)
    return (not result) if negative else result


def _gate_ok(obj, selected, build, upgrading=False):
    """Combined file/action applicability (ParseActions L112-130), fresh install."""
    on_upgrade = obj.get("onUpgrade")
    if not upgrading and (on_upgrade is True):
        return False
    if not is_applicable_option(obj.get("option"), selected):
        return False
    if not is_applicable_list(obj.get("options"), selected):
        return False
    if obj.get("builds"):
        positives = [b for b in obj["builds"] if not str(b).startswith("!")]
        negatives = [b for b in obj["builds"] if str(b).startswith("!")]
        if not any(is_applicable_build(b, build) for b in positives):
            return False
        if any(is_applicable_build(b, build) for b in negatives):
            return False
    if _norm(obj.get("oobe", "null")).lower() == "only":
        return False  # non-OOBE (desktop) run
    if _norm(obj.get("iso", "null")).lower() == "only":
        return False  # non-ISO run
    return True


def stage5_simulate(cfg_root: Path, parsed: dict, build: int) -> dict:
    hdr = _c("B", f"STAGE 5  Execution simulation - fresh install, build {build}")
    print(f"\n{hdr}\n" + "-" * len(hdr))
    scenarios = {
        "Safe preset (defaults)": {"preset-safe", "rp-on", "wu-auto", "browser-brave"},
        "Balanced preset (defaults)": {"preset-balanced", "rp-on", "wu-auto", "browser-brave"},
        "Extreme preset (defaults)": {"preset-extreme", "rp-on", "wu-auto", "browser-brave"},
        "Balanced + no browser": {"preset-balanced", "rp-on", "wu-auto"},
        "Balanced + all advanced opts": {
            "preset-balanced", "rp-on", "wu-auto", "browser-brave",
            "opt-uninstall-edge", "opt-disable-defender", "opt-disable-mitigations",
            "opt-disable-vbs", "opt-max-performance", "opt-disable-hibernation",
            "opt-strip-recall", "opt-disable-sticky-keys", "opt-disable-sysmain",
            "opt-disable-search-indexing", "opt-disable-memory-compression",
            "opt-disable-hags"},
    }
    results = {}
    for name, selected in scenarios.items():
        counts, statuses, stack, visiting = Counter(), [], ["main.yml"], set()
        while stack:
            rel = stack.pop(0)
            if rel in visiting:
                err("sim", f"cycle detected at {rel}")
                continue
            doc = parsed.get(rel)
            if not isinstance(doc, dict):
                continue
            if not _gate_ok({k: v for k, v in doc.items() if k != "actions"},
                            selected, build):
                continue
            for a in doc.get("actions") or []:
                if not isinstance(a, dict) or "__tag__" not in a:
                    continue
                if a["__tag__"] == "task":
                    tp = _normpath(a.get("path", ""))
                    if _gate_ok(a, selected, build) and (cfg_root / tp).is_file():
                        stack.append(tp)
                    continue
                if not _gate_ok(a, selected, build):
                    continue
                counts[a["__tag__"]] += 1
                if a["__tag__"] == "writeStatus":
                    statuses.append(a.get("status"))
        results[name] = {"counts": dict(counts), "statuses": statuses}
        total = sum(counts.values())
        print(f"  [{_c('g', 'ok')}] {name:34} {total:4} actions  "
              f"{dict(counts.most_common())}")

    # sanity: every scenario has a meaningful plan and a finish status
    for name, r in results.items():
        if not r["counts"]:
            err("sim", f"scenario '{name}' resolves to an empty plan")
    finish_ok = any("finish" in (s or "").lower() or "report" in (s or "").lower()
                    for r in results.values() for s in r["statuses"])
    if not finish_ok:
        warn("sim", "no 'finish/report' status reached in any scenario - is finish.yml gated out?")
    if errors:
        for e in errors:
            print("  " + _c("r", "FAIL") + " " + e)
        raise DryRunError("simulation failed")
    print("  [ok] all scenarios resolve to a complete execution plan")
    print("  [ok] stage 5 PASSED")
    return results


# ----------------------------------------------------------------------------
# Self-test: harness must reproduce the v1.0.0 load failure verbatim
# ----------------------------------------------------------------------------
BROKEN_CONF = """<?xml version="1.0" encoding="utf-8"?>
<Playbook>
\t<Name>UltraOS</Name>
\t<Username>UltraOS</Username>
\t<Version>1.0.0</Version>
\t<SupportsISO>false</SupportsISO>
\t<UpgradableFrom>none</UpgradableFrom>
\t<FeaturePages>
\t\t<RadioPage IsRequired="true" DefaultOption="preset-balanced" Description="x">
\t\t\t<TopLine Text="Not sure? Balanced is the recommended daily-driver preset."/>
\t\t\t<Options>
\t\t\t\t<RadioOption><Text>Safe</Text><Name>preset-safe</Name></RadioOption>
\t\t\t\t<RadioOption><Text>Balanced</Text><Name>preset-balanced</Name></RadioOption>
\t\t\t\t<RadioOption><Text>Extreme</Text><Name>preset-extreme</Name></RadioOption>
\t\t\t</Options>
\t\t\t<BottomLine Text="docs"/>
\t\t</RadioPage>
\t</FeaturePages>
</Playbook>"""


def selftest():
    global errors
    print("SELFTEST: running rule engine against the broken v1.0.0 playbook.conf fixture")
    tmp = Path(tempfile.mkdtemp(prefix="ultraos-selftest-"))
    try:
        (tmp / "playbook.conf").write_text(BROKEN_CONF, encoding="utf-8")
        try:
            pb = stage1_parse_conf(tmp)
            stage2_validate(pb)
        except DryRunError:
            pass
        expected = [
            ("RadioPage with a TopLine and BottomLine must not have more than 2 options.", True),
            ("Invalid 'UpgradableFrom' value 'none'", True),
        ]
        ok = True
        for msg, should_exist in expected:
            found = any(msg in e for e in errors)
            mark = _c("g", "caught") if found == should_exist else _c("r", "MISSED")
            print(f"  [{mark}] {msg}")
            ok &= (found == should_exist)
        if not ok:
            print(_c("r", "SELFTEST FAILED - harness does not reproduce the wizard's errors"))
            return 1
        print(_c("g", "SELFTEST PASSED") + " - harness reproduces the v1.0.0 load failure")
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


# ----------------------------------------------------------------------------
# main
# ----------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser(description="UltraOS AME Wizard runtime dry-run harness")
    ap.add_argument("--apbx", type=Path, default=None, help="path to the .apbx (default: newest in dist/)")
    ap.add_argument("--src", action="store_true", help="validate the source tree instead of an .apbx")
    ap.add_argument("--build", type=int, default=DEFAULT_BUILD, help="simulated Windows build (default 26300)")
    ap.add_argument("--json", action="store_true", help="also write dist/dryrun-report.json")
    ap.add_argument("--selftest", action="store_true", help="verify the harness catches the v1.0.0 bug")
    args = ap.parse_args()

    if args.selftest:
        sys.exit(selftest())

    banner = _c("B", "=" * 72)
    print(banner)
    print(_c("B", " UltraOS - AME Wizard runtime dry run (engine rules ported from source)"))
    print(banner)

    report = {"stages": [], "errors": [], "warnings": [], "notes": []}
    tmpdir = None
    try:
        if args.src:
            pb_root = ROOT / "src" / "playbook"
            if not pb_root.exists():
                print(_c("r", f"source tree not found: {pb_root}"))
                return 1
        else:
            dist = ROOT / "dist"
            apbx = args.apbx or (max(dist.glob("*.apbx"), key=lambda p: p.stat().st_mtime)
                                 if dist.exists() and list(dist.glob("*.apbx")) else None)
            if apbx is None or not Path(apbx).exists():
                print(_c("r", "no .apbx found (build first: bash scripts/build-playbook.sh)"))
                return 1
            tmpdir = Path(tempfile.mkdtemp(prefix="ultraos-dryrun-"))
            stage0_container(Path(apbx), tmpdir)
            report["stages"].append("container: PASS")
            pb_root = tmpdir

        pb = stage1_parse_conf(pb_root)
        report["stages"].append("playbook.conf load: PASS")
        report["meta"] = {k: pb.get(k) for k in ("Name", "Username", "Version", "EstimatedMinutes")}

        registry = stage2_validate(pb)
        report["stages"].append("validation: PASS")
        report["options"] = sorted(registry)

        parsed = stage3_yaml(pb_root / "Configuration", registry)
        report["stages"].append("yaml pipeline: PASS")

        stage4_files(pb_root, pb, parsed)
        report["stages"].append("file references: PASS")

        results = stage5_simulate(pb_root / "Configuration", parsed, args.build)
        report["stages"].append(f"execution simulation (build {args.build}): PASS")
        report["simulation"] = {k: v["counts"] for k, v in results.items()}

        report["errors"], report["warnings"] = list(errors), list(warnings)
        report["notes"] = list(notes)

        print("\n" + "=" * 72)
        print(_c("g", _c("B", f" DRY RUN PASSED - playbook loads and executes cleanly "
                              f"(build {args.build})")))
        print("=" * 72)
        rc = 0
    except DryRunError as e:
        report["errors"] = list(errors)
        print("\n" + "=" * 72)
        print(_c("r", _c("B", f" DRY RUN FAILED - {e}")))
        print("=" * 72)
        for e_ in errors:
            print("  " + _c("r", "ERROR") + " " + e_)
        rc = 1
    finally:
        if tmpdir:
            shutil.rmtree(tmpdir, ignore_errors=True)

    if warnings:
        print(f"\n{_c('y', str(len(warnings)) + ' warning(s)')}:")
        for w in warnings:
            print("  " + _c("y", "WARN") + " " + w)
    if notes:
        print(f"\n{len(notes)} note(s):")
        for n in notes:
            print("  " + _c("d", "NOTE") + " " + n)

    if args.json:
        out = ROOT / "dist" / "dryrun-report.json"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(f"\nreport written to {out}")
    return rc


if __name__ == "__main__":
    sys.exit(main())
