#!/usr/bin/env bash
# Update-FlutterPack.sh - maintenance helper for THIS Flutter pack.
# Bash twin of Update-FlutterPack.ps1.
# Default: NO network. Prints the Flutter releases manifest URL and
# the pub.dev API endpoint for every package in
# reference/dependencies.md (fallback: tools/package-snapshot.json).
# With --fetch only: downloads the releases manifest (curl + python3
# to parse), prints the current stable Flutter version, and compares
# it with the snapshot in reference/versions.md. Writes nothing.
#
# Usage: bash Update-FlutterPack.sh [--fetch]
set -euo pipefail

FETCH=0
[ "${1:-}" = "--fetch" ] && FETCH=1
PACK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

case "$(uname -s)" in
    Darwin) MANIFEST_NAME="releases_macos.json" ;;
    Linux)  MANIFEST_NAME="releases_linux.json" ;;
    *)      MANIFEST_NAME="releases_windows.json" ;;
esac
RELEASES_URL="https://storage.googleapis.com/flutter_infra_release/releases/$MANIFEST_NAME"

echo "Flutter releases manifest:"
echo "  $RELEASES_URL"
echo

PACKAGES=""
if [ -f "$PACK_ROOT/reference/dependencies.md" ]; then
    PACKAGES="$(grep -o 'pub\.dev/packages/[a-z0-9_]*' "$PACK_ROOT/reference/dependencies.md" | sed 's|pub.dev/packages/||' | sort -u)"
fi
if [ -z "$PACKAGES" ] && [ -f "$PACK_ROOT/tools/package-snapshot.json" ]; then
    PACKAGES="$(python3 -c "import json;d=json.load(open('$PACK_ROOT/tools/package-snapshot.json'));print('\n'.join(sorted(d['packages'])))" 2>/dev/null || true)"
fi
echo "pub.dev API endpoints to re-check:"
if [ -n "$PACKAGES" ]; then
    echo "$PACKAGES" | while IFS= read -r p; do [ -n "$p" ] && echo "  https://pub.dev/api/packages/$p"; done
else
    echo "  (none found - reference/dependencies.md and tools/package-snapshot.json both unavailable)"
fi
echo

SNAPSHOT=""
if [ -f "$PACK_ROOT/reference/versions.md" ]; then
    SNAPSHOT="$(grep -oE 'Flutter [0-9]+\.[0-9]+\.[0-9]+' "$PACK_ROOT/reference/versions.md" | head -1 | awk '{print $2}')"
fi
if [ -n "$SNAPSHOT" ]; then echo "Pack snapshot (reference/versions.md): Flutter $SNAPSHOT";
else echo "Pack snapshot: reference/versions.md not found or no Flutter version parsed."; fi

if [ "$FETCH" -eq 0 ]; then
    echo
    echo "No network calls made. Re-run with --fetch to download the releases manifest and compare the current stable."
    exit 0
fi

echo
echo "Fetching $RELEASES_URL ..."
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
curl -fsSL "$RELEASES_URL" -o "$TMP"
CURRENT="$(python3 - "$TMP" <<'PYEOF'
import json, sys
m = json.load(open(sys.argv[1]))
h = m["current_release"]["stable"]
for r in m["releases"]:
    if r["hash"] == h:
        print(r["version"], r.get("dart_sdk_version", "?"), r.get("release_date", "?"))
        break
PYEOF
)"
echo "Current stable: Flutter $CURRENT"
CUR_VER="$(echo "$CURRENT" | awk '{print $1}')"
if [ -n "$SNAPSHOT" ]; then
    if [ "$CUR_VER" = "$SNAPSHOT" ]; then
        echo "MATCH: the pack snapshot is the current stable."
    else
        echo "STALE: pack snapshot is $SNAPSHOT, current stable is $CUR_VER."
        echo "Update reference/versions.md, reference/dependencies.md and tools/package-snapshot.json, then run tools/build-ai-bundle.py."
    fi
fi
