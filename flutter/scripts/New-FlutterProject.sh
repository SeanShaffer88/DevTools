#!/usr/bin/env bash
# New-FlutterProject.sh - create a new Flutter project with this
# pack's defaults. Bash twin of New-FlutterProject.ps1.
# Defaults: org com.example, platforms windows,android.
# Refuses if flutter is missing or the target folder exists.
# After create, copies pack templates when present:
#   templates/analysis_options.yaml -> <project>/analysis_options.yaml
#   templates/gitignore-flutter     -> <project>/.gitignore
#
# Usage: bash New-FlutterProject.sh NAME [--org com.acme]
#          [--platforms windows,android,web] [--empty] [--path DIR]
set -euo pipefail

NAME=""; ORG="com.example"; PLATFORMS="windows,android"; EMPTY=0; PARENT="."
while [ $# -gt 0 ]; do
    case "$1" in
        --org) ORG="$2"; shift 2 ;;
        --platforms) PLATFORMS="$2"; shift 2 ;;
        --path) PARENT="$2"; shift 2 ;;
        --empty) EMPTY=1; shift ;;
        -h|--help) grep '^#' "$0" | head -12; exit 0 ;;
        -*) echo "unknown option: $1" >&2; exit 2 ;;
        *) [ -z "$NAME" ] && NAME="$1" || { echo "unexpected argument: $1" >&2; exit 2; }; shift ;;
    esac
done

[ -n "$NAME" ] || { echo "usage: New-FlutterProject.sh NAME [--org ...] [--platforms ...] [--empty] [--path DIR]" >&2; exit 2; }
case "$NAME" in
    *[!a-z0-9_]*|[0-9]*) echo "Project name must be lowercase_with_underscores (Dart package rule): '$NAME'" >&2; exit 2 ;;
esac
command -v flutter >/dev/null 2>&1 || { echo "flutter is not on PATH. Run scripts/Test-FlutterToolchain.sh first - this script does not install Flutter." >&2; exit 2; }

mkdir -p "$PARENT"
TARGET="$PARENT/$NAME"
[ -e "$TARGET" ] && { echo "Folder already exists: $TARGET - refusing to overwrite." >&2; exit 1; }

ARGS=(create --org "$ORG" --platforms "$PLATFORMS" --project-name "$NAME")
[ "$EMPTY" -eq 1 ] && ARGS+=(--empty)
ARGS+=("$NAME")
echo "Running: flutter ${ARGS[*]}"
( cd "$PARENT" && flutter "${ARGS[@]}" )

PACK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ -f "$PACK_ROOT/templates/analysis_options.yaml" ]; then
    cp "$PACK_ROOT/templates/analysis_options.yaml" "$TARGET/analysis_options.yaml"
    echo "Applied pack template: analysis_options.yaml"
fi
if [ -f "$PACK_ROOT/templates/gitignore-flutter" ]; then
    cp "$PACK_ROOT/templates/gitignore-flutter" "$TARGET/.gitignore"
    echo "Applied pack template: .gitignore"
fi

cat <<EOF

Project created: $TARGET
Next steps:
  cd $TARGET
  flutter pub get
  flutter run -d windows        # or: flutter run -d android / -d chrome
  bash "$PACK_ROOT/scripts/Invoke-FlutterBuild.sh" --target windows-release --project $TARGET
EOF
