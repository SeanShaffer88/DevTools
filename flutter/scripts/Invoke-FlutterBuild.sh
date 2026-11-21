#!/usr/bin/env bash
# Invoke-FlutterBuild.sh - build a Flutter project for one target and
# report the artifact (path + size + SHA256). Bash twin of
# Invoke-FlutterBuild.ps1.
#   windows-release   -> build/windows/x64/runner/Release (folder + exe hash)
#   android-aab       -> build/app/outputs/bundle/release/app-release.aab
#   android-apk-debug -> build/app/outputs/flutter-apk/app-debug.apk
#   web               -> build/web (folder + main.dart.js hash)
#
# Usage: bash Invoke-FlutterBuild.sh --target TARGET [--project DIR]
set -euo pipefail

TARGET=""; PROJECT="."
while [ $# -gt 0 ]; do
    case "$1" in
        --target) TARGET="$2"; shift 2 ;;
        --project) PROJECT="$2"; shift 2 ;;
        -h|--help) grep '^#' "$0" | head -10; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done

case "$TARGET" in
    windows-release) BUILD=(build windows --release) ;;
    android-aab) BUILD=(build appbundle --release) ;;
    android-apk-debug) BUILD=(build apk --debug) ;;
    web) BUILD=(build web --release) ;;
    *) echo "usage: Invoke-FlutterBuild.sh --target windows-release|android-aab|android-apk-debug|web [--project DIR]" >&2; exit 2 ;;
esac

command -v flutter >/dev/null 2>&1 || { echo "flutter is not on PATH. Run scripts/Test-FlutterToolchain.sh first." >&2; exit 2; }
[ -f "$PROJECT/pubspec.yaml" ] || { echo "$PROJECT has no pubspec.yaml - not a Flutter project folder." >&2; exit 2; }
PROJECT="$(cd "$PROJECT" && pwd)"

echo "Running: flutter ${BUILD[*]}  (in $PROJECT)"
( cd "$PROJECT" && flutter "${BUILD[@]}" )

sha() { # file -> sha256 (portable)
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}';
    elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}';
    else echo "(no sha256 tool found)"; fi
}
show_file() { printf '%s: %s\nSize  : %s bytes\nSHA256: %s\n' "$1" "$2" "$(stat -c%s "$2" 2>/dev/null || stat -f%z "$2")" "$(sha "$2")"; }
folder_size() { du -sb "$1" 2>/dev/null | awk '{print $1}'; }

case "$TARGET" in
    windows-release)
        DIR="$PROJECT/build/windows/x64/runner/Release"
        if [ ! -d "$DIR" ]; then
            EXE="$(find "$PROJECT/build/windows" -name '*.exe' -type f 2>/dev/null | head -1)"
            [ -n "$EXE" ] && DIR="$(dirname "$EXE")" || { echo "Build reported success but no Release folder/exe found under build/windows." >&2; exit 1; }
        fi
        echo "Artifact folder: $DIR"
        echo "Folder size    : $(folder_size "$DIR") bytes"
        EXE="$(find "$DIR" -maxdepth 1 -name '*.exe' -type f | head -1)"
        [ -n "$EXE" ] && show_file "App exe" "$EXE"
        ;;
    android-aab)
        AAB="$PROJECT/build/app/outputs/bundle/release/app-release.aab"
        [ -f "$AAB" ] || { echo "Build reported success but $AAB was not produced." >&2; exit 1; }
        show_file "AAB" "$AAB"
        ;;
    android-apk-debug)
        APK="$PROJECT/build/app/outputs/flutter-apk/app-debug.apk"
        [ -f "$APK" ] || { echo "Build reported success but $APK was not produced." >&2; exit 1; }
        show_file "APK (debug)" "$APK"
        ;;
    web)
        DIR="$PROJECT/build/web"
        [ -d "$DIR" ] || { echo "Build reported success but $DIR was not produced." >&2; exit 1; }
        echo "Artifact folder: $DIR"
        echo "Folder size    : $(folder_size "$DIR") bytes"
        [ -f "$DIR/main.dart.js" ] && show_file "Web bundle" "$DIR/main.dart.js"
        ;;
esac
