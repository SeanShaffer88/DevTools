#!/usr/bin/env bash
# Test-FlutterToolchain.sh - check whether this machine is ready for
# Flutter development. Read-only: installs NOTHING, changes NOTHING.
# Bash twin of Test-FlutterToolchain.ps1 (for Git Bash / WSL / macOS /
# Linux). The Visual Studio check only applies on Windows (Git Bash);
# elsewhere it is reported as SKIP.
#
# Usage: bash Test-FlutterToolchain.sh
set -uo pipefail

PASS=0; MISSING=0
declare -a FIXES=()

check() { # name ok detail fix
    if [ "$2" -eq 0 ]; then
        printf 'PASS    %-32s %s\n' "$1" "$3"; PASS=$((PASS+1))
    else
        printf 'MISSING %-32s %s\n' "$1" "$3"; MISSING=$((MISSING+1))
        FIXES+=("FIX [$1]: $4")
    fi
}

# Flutter / Dart
if command -v flutter >/dev/null 2>&1; then
    check "Flutter" 0 "$(flutter --version 2>/dev/null | head -1)" ""
else
    check "Flutter" 1 "not on PATH" "Install Flutter manually: https://docs.flutter.dev/get-started/install - then add <flutter>/bin to PATH. This script does not install it."
fi
if command -v dart >/dev/null 2>&1; then
    check "Dart" 0 "$(dart --version 2>&1 | head -1)" ""
else
    check "Dart" 1 "not on PATH" "Dart ships with Flutter - a missing dart usually means the Flutter install or PATH is broken."
fi

# Git
if command -v git >/dev/null 2>&1; then
    check "Git" 0 "$(git --version)" ""
else
    check "Git" 1 "not on PATH" "Install Git: https://git-scm.com/downloads"
fi

# Visual Studio C++ workload (Windows only, via Git Bash path to vswhere)
VSWHERE="/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"
if [ -f "$VSWHERE" ]; then
    if "$VSWHERE" -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property displayName >/dev/null 2>&1; then
        check "Visual Studio C++ workload" 0 "found via vswhere" ""
    else
        check "Visual Studio C++ workload" 1 "Visual Studio present, C++ workload missing" "Install Visual Studio 2022 with the 'Desktop development with C++' workload."
    fi
elif [ "$(uname -s)" = "Linux" ] || [ "$(uname -s)" = "Darwin" ]; then
    printf 'SKIP    %-32s %s\n' "Visual Studio C++ workload" "Windows-only check (not applicable on $(uname -s))"
else
    check "Visual Studio C++ workload" 1 "vswhere not found" "Install Visual Studio 2022 with the 'Desktop development with C++' workload: https://visualstudio.microsoft.com/downloads/"
fi

# Android SDK
SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [ -z "$SDK_ROOT" ] && [ -d "$HOME/AppData/Local/Android/Sdk" ]; then SDK_ROOT="$HOME/AppData/Local/Android/Sdk"; fi
if [ -z "$SDK_ROOT" ] && [ -d "$HOME/Android/Sdk" ]; then SDK_ROOT="$HOME/Android/Sdk"; fi
if [ -n "$SDK_ROOT" ] && [ -d "$SDK_ROOT" ]; then
    check "Android SDK (ANDROID_HOME)" 0 "$SDK_ROOT" ""
    [ -d "$SDK_ROOT/cmdline-tools/latest" ] && check "Android cmdline-tools" 0 "cmdline-tools/latest present" "" \
        || check "Android cmdline-tools" 1 "missing" "Android Studio > Settings > Android SDK > SDK Tools > check 'Android SDK Command-line Tools (latest)'."
    [ -e "$SDK_ROOT/platform-tools/adb" ] || [ -e "$SDK_ROOT/platform-tools/adb.exe" ] \
        && check "Android platform-tools (adb)" 0 "present" "" \
        || check "Android platform-tools (adb)" 1 "missing" "Android Studio SDK Manager > SDK Tools > check 'Android SDK Platform-Tools'."
    if [ -d "$SDK_ROOT/platforms" ] && [ -n "$(ls -A "$SDK_ROOT/platforms" 2>/dev/null)" ]; then
        check "Android platforms" 0 "$(ls "$SDK_ROOT/platforms" | tr '\n' ' ')" ""
    else
        check "Android platforms" 1 "no platforms installed" "Android Studio SDK Manager > SDK Platforms > install the latest Android API level."
    fi
else
    check "Android SDK (ANDROID_HOME)" 1 "ANDROID_HOME not set, no default SDK folder" "Install Android Studio (it brings the SDK) or set ANDROID_HOME: https://developer.android.com/studio"
fi

# Chrome (web)
CHROME="${CHROME_EXECUTABLE:-}"
if [ -z "$CHROME" ]; then
    for c in google-chrome google-chrome-stable chromium chromium-browser; do
        command -v "$c" >/dev/null 2>&1 && CHROME="$c" && break
    done
fi
if [ -n "$CHROME" ]; then
    check "Chrome (web builds)" 0 "$CHROME" ""
else
    check "Chrome (web builds)" 1 "not found" "Install Chrome, or set CHROME_EXECUTABLE to a Chromium-based browser."
fi

echo
for f in "${FIXES[@]:-}"; do [ -n "$f" ] && echo "$f"; done
echo "$((PASS + MISSING)) checks, $MISSING missing."

if command -v flutter >/dev/null 2>&1; then
    echo
    echo "--- flutter doctor -v (summary) ---"
    DOCTOR="$(flutter doctor -v 2>&1)"
    echo "$DOCTOR" | grep -E '^\[|Flutter \(Channel|Android toolchain|Visual Studio|Chrome' || true
    echo "doctor summary: $(echo "$DOCTOR" | grep -c '✓' || true) OK marker(s), $(echo "$DOCTOR" | grep -c '✗' || true) error marker(s) (run 'flutter doctor -v' for full detail)."
fi
[ "$MISSING" -eq 0 ]
