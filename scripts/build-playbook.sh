#!/usr/bin/env bash
# UltraOS playbook packager (Linux-native).
#
# Packages src/playbook/ into dist/UltraOS-Playbook-v<version>.apbx:
#   - .apbx = ZIP archive, password "malte" (same ZipCrypto container class
#     Atlas ships; AME Wizard extracts it with 7-Zip using that password)
#   - playbook files live at the ARCHIVE ROOT (playbook.conf, Configuration/,
#     Executables/, ... at top level, NOT nested in a folder)
#     Entry point: Configuration/main.yml
#   - verifies the archive (password + CRC round-trip + root layout),
#     writes SHA256SUMS.txt and assembles dist/release/.
#
# Spec: research/execution-performance-packaging.md §4 (toolchain verified on
# this box: zip 3.0 / unzip / sha256sum). Run from anywhere: paths are
# resolved relative to this script.
set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# ---------------------------------------------------------------- version ---
# (no pipes here on purpose: with pipefail, `sed | head` can SIGPIPE-abort)
VERSION="$(sed -n 's:.*<Version>\(.*\)</Version>.*:\1:p' src/playbook/playbook.conf)"
VERSION="${VERSION%%$'\n'*}"   # first match only
VERSION="${VERSION//[[:space:]]/}"
if [ -z "${VERSION}" ]; then
    echo "ERROR: could not parse <Version> from src/playbook/playbook.conf" >&2
    exit 1
fi
APBX="UltraOS-Playbook-v${VERSION}.apbx"
echo "==> UltraOS packager - version ${VERSION}"

mkdir -p dist

# ------------------------------------------- pre-build generation (optional) ---
# default-user.reg is generated at build time from the tweaks tree (T3-i).
# Failure is non-fatal: the playbook still packages, the gap is only a warning.
if [ -f scripts/gen-defaultuser-reg.py ]; then
    echo "==> Generating src/playbook/Executables/default-user.reg"
    if ! python3 scripts/gen-defaultuser-reg.py; then
        echo "WARNING: gen-defaultuser-reg.py failed - packaging WITHOUT a regenerated default-user.reg" >&2
    fi
else
    echo "--> scripts/gen-defaultuser-reg.py not found - skipping default-user.reg generation"
fi

# Safety net: the wizard shows playbook.png + browser tile icons referenced by
# playbook.conf; generate them if they are missing and the generator exists.
if [ ! -f src/playbook/playbook.png ] && [ -f scripts/make-artifacts.py ]; then
    echo "WARNING: src/playbook/playbook.png missing - running scripts/make-artifacts.py" >&2
    python3 scripts/make-artifacts.py || echo "WARNING: make-artifacts.py failed" >&2
fi

# ---------------------------------------------------------------- package ---
# -P malte : password (ZipCrypto, wizard-compatible)
# -r       : recurse
# -X       : strip extra file attributes (portable archive)
# exclusions: never ship previous archives, caches or OS junk
rm -f "dist/${APBX}"
(
    cd src/playbook &&
        zip -q -P malte -r -X "../../dist/${APBX}" . \
            -x '*.apbx' -x '*.zip' -x '*.pyc' -x '__pycache__/*' \
            -x '.git*' -x '.DS_Store' -x 'Thumbs.db' -x '*.log'
)

# ----------------------------------------------------------------- verify ---
# Full decrypt + CRC round-trip (fails on wrong password or corruption).
unzip -t -P malte "dist/${APBX}" > /dev/null
echo "==> Archive verified (password + CRC round-trip)"
echo "==> Archive contents (first 30 entries):"
unzip -l -P malte "dist/${APBX}" | awk 'NR <= 30'   # awk drains stdin: no SIGPIPE under pipefail

# Files must sit at the ARCHIVE ROOT (entry = Configuration/main.yml).
LISTING="$(unzip -Z1 "dist/${APBX}")"
for required in playbook.conf Configuration/main.yml; do
    if grep -qxF "${required}" <<<"${LISTING}"; then
        echo "==> OK: '${required}' present at archive root"
    else
        echo "ERROR: '${required}' missing from archive root" >&2
        exit 1
    fi
done

# ------------------------------------------------------------ checksums ----
( cd dist && sha256sum "${APBX}" > SHA256SUMS.txt )
echo "==> $(cat dist/SHA256SUMS.txt)"

# --------------------------------------------------------- release folder ---
# .apbx + release-zip extras (README-FIRST.txt etc., T3-k) + LICENSE + SHA256SUMS
rm -rf dist/release
mkdir -p dist/release
cp "dist/${APBX}" dist/release/
if [ -d src/release-zip ]; then
    cp -r src/release-zip/. dist/release/
fi
if [ -f LICENSE ]; then
    cp LICENSE dist/release/
else
    echo "WARNING: LICENSE not found at repo root - release folder ships without it" >&2
fi
cp dist/SHA256SUMS.txt dist/release/

# ---------------------------------------------------------------- summary ---
echo "==> Build summary (dist tree):"
find dist -type f -printf '    %10s  %p\n' | sort -k2
echo "==> Total: $(du -sh dist | cut -f1) in dist/"
echo "==> DONE: dist/${APBX}"
